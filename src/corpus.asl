(module asl-harness/corpus
  :d "14-day rolling window transcript and audio segment recorder, and self-feeding SFT/DPO preference pair extractor from gate receipts"
  :x [AudioSegment
      TranscriptUtterance
      PreferencePair
      CorpusStore
      make-corpus-store
      record-utterance
      record-audio-segment
      is-within-window?
      prune-corpus-window
      extract-sft-dpo-pairs
      format-preference-pair-asn]
  :i [])

(dfs AudioSegment
  (:f segment-id Str "Unique audio segment identifier")
  (:f timestamp-ms Int64 "Monotonic millisecond timestamp")
  (:f duration-ms Int64 "Audio segment duration in milliseconds")
  (:f speaker-score Float "Speaker match confidence score")
  (:f sample-count Int64 "Total PCM samples in segment")
  (:f pcm-digest Str "Content hash or digest of recorded audio"))

(dfs TranscriptUtterance
  (:f utterance-id Str "Unique utterance identifier")
  (:f timestamp-ms Int64 "Monotonic millisecond timestamp")
  (:f speaker-id Str "Identified speaker ID or operator")
  (:f speaker-score Float "Speaker verification match score")
  (:f verified-speaker Bool "True if speaker score meets or exceeds 0.75 threshold")
  (:f text Str "Transcript utterance text content")
  (:f intent Str "Extracted or classified intent label"))

(dfs PreferencePair
  (:f pair-id Str "Unique preference sample identifier")
  (:f prompt Str "Task prompt or instruction specification")
  (:f chosen Str "Accepted positive completion from pass gate receipt")
  (:f rejected Str "Rejected negative completion from fail gate receipt")
  (:f gate-verdict-chosen Str "Gate receipt identifier or pass status")
  (:f gate-verdict-rejected Str "Gate receipt identifier or fail status")
  (:f timestamp-ms Int64 "Millisecond timestamp of pair formation"))

(dfs CorpusStore
  (:f window-days Int64 "Rolling window retention duration in days")
  (:f utterances (List TranscriptUtterance) "Chronologically ordered transcripts")
  (:f audio-segments (List AudioSegment) "Chronologically ordered audio segments")
  (:f preference-pairs (List PreferencePair) "Extracted SFT/DPO training pairs"))

(df make-corpus-store [(window-days Int64)] -> CorpusStore
  :d "Instantiates empty corpus store with designated rolling window in days."
  (CorpusStore
    :window-days window-days
    :utterances (list)
    :audio-segments (list)
    :preference-pairs (list)))

(df record-utterance [(store CorpusStore) (utt TranscriptUtterance)] -> CorpusStore
  :d "Appends utterance tagging verified-speaker flag based on speaker-score >= 0.75."
  (let [(is-verified (>= (.-speaker-score utt) 0.75))
        (tagged-utt (TranscriptUtterance
                      :utterance-id (.-utterance-id utt)
                      :timestamp-ms (.-timestamp-ms utt)
                      :speaker-id (.-speaker-id utt)
                      :speaker-score (.-speaker-score utt)
                      :verified-speaker is-verified
                      :text (.-text utt)
                      :intent (.-intent utt)))]
    (CorpusStore
      :window-days (.-window-days store)
      :utterances (list-append (.-utterances store) (list tagged-utt))
      :audio-segments (.-audio-segments store)
      :preference-pairs (.-preference-pairs store))))

(df record-audio-segment [(store CorpusStore) (seg AudioSegment)] -> CorpusStore
  :d "Appends audio segment metadata to the corpus store."
  (CorpusStore
    :window-days (.-window-days store)
    :utterances (.-utterances store)
    :audio-segments (list-append (.-audio-segments store) (list seg))
    :preference-pairs (.-preference-pairs store)))

(df is-within-window? [(item-ts Int64) (current-ts Int64) (window-ms Int64)] -> Bool
  :d "Computes temporal validity relative to rolling window duration."
  (<= (- current-ts item-ts) window-ms))

(df filter-utterances-window [(utts (List TranscriptUtterance)) (now-ts Int64) (win-ms Int64)] -> (List TranscriptUtterance)
  :d "Filters utterances retaining only those within retention window."
  (if (list-empty? utts)
      (list)
      (let [(head (option-or (list-head utts) (TranscriptUtterance :utterance-id "" :timestamp-ms 0 :speaker-id "" :speaker-score 0.0 :verified-speaker false :text "" :intent "")))
            (tail (option-or (list-tail utts) (list)))]
        (if (is-within-window? (.-timestamp-ms head) now-ts win-ms)
            (list-cons head (filter-utterances-window tail now-ts win-ms))
            (filter-utterances-window tail now-ts win-ms)))))

(df filter-audio-window [(segs (List AudioSegment)) (now-ts Int64) (win-ms Int64)] -> (List AudioSegment)
  :d "Filters audio segments retaining only those within retention window."
  (if (list-empty? segs)
      (list)
      (let [(head (option-or (list-head segs) (AudioSegment :segment-id "" :timestamp-ms 0 :duration-ms 0 :speaker-score 0.0 :sample-count 0 :pcm-digest "")))
            (tail (option-or (list-tail segs) (list)))]
        (if (is-within-window? (.-timestamp-ms head) now-ts win-ms)
            (list-cons head (filter-audio-window tail now-ts win-ms))
            (filter-audio-window tail now-ts win-ms)))))

(df prune-corpus-window [(store CorpusStore) (now-ts Int64)] -> CorpusStore
  :d "Prunes utterances and audio segments older than 14 days while preserving preference pairs."
  (let [(win-ms (* (.-window-days store) 86400000))
        (active-utts (filter-utterances-window (.-utterances store) now-ts win-ms))
        (active-segs (filter-audio-window (.-audio-segments store) now-ts win-ms))]
    (CorpusStore
      :window-days (.-window-days store)
      :utterances active-utts
      :audio-segments active-segs
      :preference-pairs (.-preference-pairs store))))

(df is-pass-verdict? [(v Str)] -> Bool
  :d "Checks if receipt indicates a pass verdict."
  (or (= v "pass") (or (= v ":pass") (string-contains? v "pass"))))

(df is-fail-verdict? [(v Str)] -> Bool
  :d "Checks if receipt indicates a fail verdict."
  (or (= v "fail") (or (= v ":fail") (string-contains? v "fail"))))

(df filter-chosen-completions [(receipts (List Str)) (completions (List Str))] -> (List Str)
  :d "Extracts completions with pass receipts."
  (if (or (list-empty? receipts) (list-empty? completions))
      (list)
      (let [(rec (option-or (list-head receipts) ""))
            (comp (option-or (list-head completions) ""))
            (rec-tail (option-or (list-tail receipts) (list)))
            (comp-tail (option-or (list-tail completions) (list)))]
        (if (is-pass-verdict? rec)
            (list-cons comp (filter-chosen-completions rec-tail comp-tail))
            (filter-chosen-completions rec-tail comp-tail)))))

(df filter-rejected-completions [(receipts (List Str)) (completions (List Str))] -> (List Str)
  :d "Extracts completions with fail receipts."
  (if (or (list-empty? receipts) (list-empty? completions))
      (list)
      (let [(rec (option-or (list-head receipts) ""))
            (comp (option-or (list-head completions) ""))
            (rec-tail (option-or (list-tail receipts) (list)))
            (comp-tail (option-or (list-tail completions) (list)))]
        (if (is-fail-verdict? rec)
            (list-cons comp (filter-rejected-completions rec-tail comp-tail))
            (filter-rejected-completions rec-tail comp-tail)))))

(df build-preference-pairs [(task-prompt Str) (chosen-list (List Str)) (rejected-list (List Str)) (idx Int64)] -> (List PreferencePair)
  :d "Pairs chosen and rejected completions sequentially into PreferencePair records."
  (if (or (list-empty? chosen-list) (list-empty? rejected-list))
      (list)
      (let [(c-head (option-or (list-head chosen-list) ""))
            (r-head (option-or (list-head rejected-list) ""))
            (c-tail (option-or (list-tail chosen-list) (list)))
            (r-tail (option-or (list-tail rejected-list) (list)))
            (pair (PreferencePair
                    :pair-id (str "pref-" (string-from-int64 idx))
                    :prompt task-prompt
                    :chosen c-head
                    :rejected r-head
                    :gate-verdict-chosen "pass"
                    :gate-verdict-rejected "fail"
                    :timestamp-ms 1757300000000))]
        (list-cons pair (build-preference-pairs task-prompt c-tail r-tail (+ idx 1))))))

(df extract-sft-dpo-pairs [(task-prompt Str) (receipts (List Str)) (completions (List Str))] -> (List PreferencePair)
  :d "Correlates completions with pass/fail gate receipts producing SFT/DPO preference pairs."
  (if (or (!= (list-length receipts) (list-length completions)) (<= (list-length receipts) 0))
      (list)
      (let [(chosen (filter-chosen-completions receipts completions))
            (rejected (filter-rejected-completions receipts completions))]
        (if (or (list-empty? chosen) (list-empty? rejected))
            (list)
            (build-preference-pairs task-prompt chosen rejected 1)))))

(df format-preference-pair-asn [(pair PreferencePair)] -> Str
  :d "Formats a preference pair into canonical ASN S-expression notation."
  (str "(:preference-pair :id \"" (.-pair-id pair)
       "\" :prompt \"" (.-prompt pair)
       "\" :chosen \"" (.-chosen pair)
       "\" :rejected \"" (.-rejected pair)
       "\" :gate-verdict-chosen \"" (.-gate-verdict-chosen pair)
       "\" :gate-verdict-rejected \"" (.-gate-verdict-rejected pair)
       "\" :timestamp-ms " (string-from-int64 (.-timestamp-ms pair)) ")"))
