(module asl-harness/tests/corpus-bench-test
  :d "Unit verification suite for active learning corpus, SFT/DPO pairs, benchcases, and routing audit logging"
  :x [run-tests
      test-corpus-recording
      test-corpus-retention-and-pruning
      test-sft-dpo-pair-extraction
      test-benchcases-evaluation
      test-benchcases-parameter-sweep
      test-routing-audit-logger]
  :i [(corpus :a cp) (benchcases :a bc) (routinglog :a rl)])

(df test-corpus-recording [] -> Bool
  :d "Verifies utterance and audio segment recording with speaker verification filtering."
  (let [(store (cp/make-corpus-store 14))
        (u1 (cp/TranscriptUtterance
              :utterance-id "utt-1"
              :timestamp-ms 1757300000000
              :speaker-id "operator"
              :speaker-score 0.92
              :verified-speaker false
              :text "list files in src"
              :intent "file-search"))
        (u2 (cp/TranscriptUtterance
              :utterance-id "utt-2"
              :timestamp-ms 1757300001000
              :speaker-id "impostor"
              :speaker-score 0.45
              :verified-speaker false
              :text "format hard drive"
              :intent "unknown"))
        (seg (cp/AudioSegment
               :segment-id "seg-1"
               :timestamp-ms 1757300000000
               :duration-ms 2500
               :speaker-score 0.92
               :sample-count 40000
               :pcm-digest "sha256-audio-dummy-digest"))
        (s1 (cp/record-utterance store u1))
        (s2 (cp/record-utterance s1 u2))
        (s3 (cp/record-audio-segment s2 seg))
        (recorded-u1 (option-or (list-head (.-utterances s3)) u1))
        (recorded-u2 (option-or (list-head (option-or (list-tail (.-utterances s3)) (list))) u2))
        (recorded-seg (option-or (list-head (.-audio-segments s3)) seg))]
    (do
      (assert (= (list-length (.-utterances s3)) 2))
      (assert (.-verified-speaker recorded-u1))
      (assert (not (.-verified-speaker recorded-u2)))
      (assert (= (list-length (.-audio-segments s3)) 1))
      (assert (= (.-sample-count recorded-seg) 40000))
      true)))

(df test-corpus-retention-and-pruning [] -> Bool
  :d "Verifies 14-day rolling window retention and temporal pruning."
  (let [(now-ts 1757300000000)
        (win-ms 1209600000)
        (u-fresh (cp/TranscriptUtterance :utterance-id "u-fresh" :timestamp-ms (- now-ts 500000000) :speaker-id "op" :speaker-score 0.9 :verified-speaker true :text "recent" :intent "file-search"))
        (u-expired (cp/TranscriptUtterance :utterance-id "u-old" :timestamp-ms (- now-ts 1300000000) :speaker-id "op" :speaker-score 0.9 :verified-speaker true :text "stale" :intent "file-search"))
        (u-boundary (cp/TranscriptUtterance :utterance-id "u-edge" :timestamp-ms (- now-ts 1209600000) :speaker-id "op" :speaker-score 0.9 :verified-speaker true :text "edge" :intent "file-search"))
        (u-future (cp/TranscriptUtterance :utterance-id "u-fut" :timestamp-ms (+ now-ts 5000) :speaker-id "op" :speaker-score 0.9 :verified-speaker true :text "ahead" :intent "file-search"))
        (seg-fresh (cp/AudioSegment :segment-id "seg-fresh" :timestamp-ms (- now-ts 1000) :duration-ms 1000 :speaker-score 0.9 :sample-count 16000 :pcm-digest "d1"))
        (seg-old (cp/AudioSegment :segment-id "seg-old" :timestamp-ms (- now-ts 1400000000) :duration-ms 1000 :speaker-score 0.9 :sample-count 16000 :pcm-digest "d2"))
        (pair (cp/PreferencePair :pair-id "p-1" :prompt "task" :chosen "good" :rejected "bad" :gate-verdict-chosen "pass" :gate-verdict-rejected "fail" :timestamp-ms (- now-ts 1500000000)))
        (store (cp/CorpusStore
                 :window-days 14
                 :utterances (list u-fresh u-expired u-boundary u-future)
                 :audio-segments (list seg-fresh seg-old)
                 :preference-pairs (list pair)))
        (pruned (cp/prune-corpus-window store now-ts))]
    (do
      (assert (cp/is-within-window? (.-timestamp-ms u-fresh) now-ts win-ms))
      (assert (not (cp/is-within-window? (.-timestamp-ms u-expired) now-ts win-ms)))
      (assert (= (list-length (.-utterances pruned)) 3))
      (assert (= (list-length (.-audio-segments pruned)) 1))
      (assert (= (list-length (.-preference-pairs pruned)) 1))
      true)))

(df test-sft-dpo-pair-extraction [] -> Bool
  :d "Verifies SFT/DPO contrastive preference pair extraction from gate receipts."
  (let [(prompt "write a pure asl parser")
        (receipts (list "pass" "fail"))
        (completions (list "pure recursive parser" "foreign js parser"))
        (pairs (cp/extract-sft-dpo-pairs prompt receipts completions))
        (p0 (option-or (list-head pairs) (cp/PreferencePair :pair-id "" :prompt "" :chosen "" :rejected "" :gate-verdict-chosen "" :gate-verdict-rejected "" :timestamp-ms 0)))
        (asn-repr (cp/format-preference-pair-asn p0))
        (homo-pairs (cp/extract-sft-dpo-pairs prompt (list "pass" "pass") (list "c1" "c2")))]
    (do
      (assert (= (list-length pairs) 1))
      (assert (= (.-chosen p0) "pure recursive parser"))
      (assert (= (.-rejected p0) "foreign js parser"))
      (assert (and (string-contains? asn-repr ":chosen") (string-contains? asn-repr ":rejected")))
      (assert (and (> (.-timestamp-ms p0) 0) (= (list-length homo-pairs) 0)))
      true)))

(df test-benchcases-evaluation [] -> Bool
  :d "Verifies benchmark case suite loading, intent filtering, and suite metric evaluation."
  (let [(cases (bc/canonical-benchcases))
        (edits (bc/filter-benchcases-by-intent cases "code-edit"))
        (c0 (option-or (list-head edits) (bc/BenchCase :case-id "" :input-prompt "" :expected-intent "" :expected-tier "" :difficulty "")))
        (r-good (bc/evaluate-classification-case c0 "code-edit" (.-expected-tier c0) 5))
        (r-bad (bc/evaluate-classification-case c0 "wrong-intent" "wrong-tier" 10))
        (rep-suite (bc/evaluate-benchmark-suite (list r-good r-bad)))
        (rep-empty (bc/evaluate-benchmark-suite (list)))]
    (do
      (assert (>= (list-length cases) 10))
      (assert (>= (list-length edits) 2))
      (assert (and (.-matched-intent r-good) (.-matched-tier r-good)))
      (assert (and (not (.-matched-intent r-bad)) (not (.-matched-tier r-bad))))
      (assert (and (= (.-intent-accuracy rep-suite) 50.0) (= (.-intent-accuracy rep-empty) 0.0)))
      true)))

(df test-benchcases-parameter-sweep [] -> Bool
  :d "Verifies multi-temperature parameter sweep and report formatting."
  (let [(cases (bc/canonical-benchcases))
        (temps (list 0.0 0.5 0.7))
        (reports (bc/sweep-benchmark cases temps))
        (rep0 (option-or (list-head reports) (bc/BenchReport :total-cases 0 :intent-accuracy 0.0 :tier-accuracy 0.0 :exact-match-count 0 :exact-match-rate 0.0)))
        (rep1 (option-or (list-head (option-or (list-tail reports) (list))) rep0))
        (asn-rep (bc/format-bench-report rep0))]
    (do
      (assert (= (list-length reports) 3))
      (assert (= (.-total-cases rep0) (list-length cases)))
      (assert (= (.-exact-match-count rep0) (.-exact-match-count rep1)))
      (assert (and (string-contains? asn-rep ":bench-report") (string-contains? asn-rep ":intent-accuracy")))
      (assert (= (.-exact-match-rate rep0) 100.0))
      true)))

(df test-routing-audit-logger [] -> Bool
  :d "Verifies routing audit entry creation, misroute filtering, summary telemetry, and ASN serialization."
  (let [(e1 (rl/make-routing-entry "r-1" 1757300000000 "task-10" "read file" 1.2 "fast-path" true 650 2 "pass" false))
        (e2 (rl/make-routing-entry "r-2" 1757300001000 "task-11" "complex refactor" 4.5 "fast-path" false 0 450 "fallback" true))
        (log0 (list e1))
        (log1 (rl/append-routing-entry log0 e2))
        (misrouted (rl/filter-misrouted log1))
        (summary (rl/summarize-routing-log log1))
        (summary-empty (rl/summarize-routing-log (list)))
        (asn-str (rl/format-routing-asn e1))]
    (do
      (assert (= (list-length log1) 2))
      (assert (= (list-length misrouted) 1))
      (assert (= (.-total-tokens-saved summary) 650))
      (assert (and (= (.-local-ratio summary) 50.0) (= (.-misroute-rate summary-empty) 0.0)))
      (assert (and (string-contains? asn-str "(:routing-entry") (string-contains? asn-str ":tokens-saved 650")))
      true)))

(df run-tests [] -> Bool
  :d "Sequentially executes all unit verification functions in the suite."
  (do
    (test-corpus-recording)
    (test-corpus-retention-and-pruning)
    (test-sft-dpo-pair-extraction)
    (test-benchcases-evaluation)
    (test-benchcases-parameter-sweep)
    (test-routing-audit-logger)
    true))
