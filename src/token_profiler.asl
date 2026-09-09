(module asl-harness/token-profiler
  :d "Deterministic lexical token profiling, subword decomposition, category breakdown, and SNR calculation."
  :x [WordFrequency
      TokenBreakdown
      TokenProfile
      make-word-frequency
      make-token-breakdown
      make-token-profile
      estimate-word-tokens
      is-keyword-token?
      is-delimiter-token?
      is-literal-token?
      clean-token-stream
      compute-token-breakdown
      compute-word-frequencies
      sort-word-frequencies-desc
      take-top-frequencies
      compute-token-profile
      format-word-frequency-asn
      format-token-profile-asn]
  :i [(asl-text/escape :a esc)])

(dfs WordFrequency
  (:f word Str "Normalized token or word literal")
  (:f count I64 "Occurrence frequency in input payload")
  (:f tokens I64 "Estimated token cost for this token across all occurrences"))

(dfs TokenBreakdown
  (:f keywords I64 "Count of keyword tokens starting with colon")
  (:f identifiers I64 "Count of identifier or symbol tokens")
  (:f literals I64 "Count of string number and boolean literals")
  (:f delimiters I64 "Count of structural parentheses brackets and braces"))

(dfs TokenProfile
  (:f source-desc Str "Descriptive source label or snippet")
  (:f total-tokens I64 "Total estimated token weight")
  (:f total-chars I64 "Total character length of analyzed text")
  (:f unique-words I64 "Number of distinct tokens identified")
  (:f snr-score F64 "Signal to noise ratio: semantic tokens divided by total tokens")
  (:f breakdown TokenBreakdown "Categorical breakdown of token distribution")
  (:f top-words (List WordFrequency) "Ranked list of top tokens ordered from highest frequency to lowest"))

(df make-word-frequency [(word Str) (count I64) (tokens I64)] -> WordFrequency
  :d "Constructs a WordFrequency entry."
  (WordFrequency
    :word word
    :count count
    :tokens tokens))

(df make-token-breakdown [(keywords I64) (identifiers I64) (literals I64) (delimiters I64)] -> TokenBreakdown
  :d "Constructs a TokenBreakdown record."
  (TokenBreakdown
    :keywords keywords
    :identifiers identifiers
    :literals literals
    :delimiters delimiters))

(df make-token-profile [(source Str) (total I64) (chars I64) (unique I64) (snr F64) (breakdown TokenBreakdown) (top-words (List WordFrequency))] -> TokenProfile
  :d "Constructs a TokenProfile record."
  (TokenProfile
    :source-desc source
    :total-tokens total
    :total-chars chars
    :unique-words unique
    :snr-score snr
    :breakdown breakdown
    :top-words top-words))

(df estimate-word-tokens [(w Str)] -> I64
  :d "Calculates estimated token weight using subword length heuristics."
  (let [(len (string-length w))]
    (if (= len 0)
      0
      (if (<= len 4)
        1
        (/ (+ len 3) 4)))))

(df is-keyword-token? [(w Str)] -> Bool
  :d "Checks if token represents an S-expression keyword starting with colon."
  (and (> (string-length w) 1)
       (string-starts-with? w ":")))

(df is-delimiter-token? [(w Str)] -> Bool
  :d "Checks if token represents structural delimiter punctuation."
  (or (= w "(")
      (or (= w ")")
          (or (= w "[")
              (or (= w "]")
                  (or (= w "{")
                      (= w "}")))))))

(df is-literal-token? [(w Str)] -> Bool
  :d "Checks if token represents string numeric or boolean literal."
  (or (string-starts-with? w "\"")
      (or (= w "true")
          (or (= w "false")
              (or (string-starts-with? w "0")
                  (or (string-starts-with? w "1")
                      (or (string-starts-with? w "2")
                          (or (string-starts-with? w "3")
                              (or (string-starts-with? w "4")
                                  (or (string-starts-with? w "5")
                                      (or (string-starts-with? w "6")
                                          (or (string-starts-with? w "7")
                                              (or (string-starts-with? w "8")
                                                  (string-starts-with? w "9"))))))))))))))

(df clean-token-stream [(text Str)] -> (List Str)
  :d "Normalizes delimiters and extracts flat token stream from input text."
  (let [(s1 (string-replace text "\n" " "))
        (s2 (string-replace s1 "\t" " "))
        (s3 (string-replace s2 "\r" " "))
        (s4 (string-replace s3 "(" " ( "))
        (s5 (string-replace s4 ")" " ) "))
        (s6 (string-replace s5 "[" " [ "))
        (s7 (string-replace s6 "]" " ] "))
        (s8 (string-replace s7 "{" " { "))
        (s9 (string-replace s8 "}" " } "))
        (raw-words (string-split s9 " "))]
    (filter (fn [(w Str)] -> Bool (not (string-empty? (string-trim w)))) raw-words)))

(df compute-token-breakdown [(tokens (List Str))] -> TokenBreakdown
  :d "Calculates counts across keyword, identifier, literal, and delimiter categories."
  (let [(kw-count (list-length (filter (fn [(w Str)] -> Bool (is-keyword-token? w)) tokens)))
        (delim-count (list-length (filter (fn [(w Str)] -> Bool (is-delimiter-token? w)) tokens)))
        (lit-count (list-length (filter (fn [(w Str)] -> Bool (and (not (is-delimiter-token? w)) (is-literal-token? w))) tokens)))
        (id-count (list-length (filter (fn [(w Str)] -> Bool (and (not (is-keyword-token? w)) (and (not (is-delimiter-token? w)) (not (is-literal-token? w))))) tokens)))]
    (TokenBreakdown
      :keywords kw-count
      :identifiers id-count
      :literals lit-count
      :delimiters delim-count)))

(df insert-word-freq [(w Str) (acc (List WordFrequency))] -> (List WordFrequency)
  :d "Increments frequency of existing word or appends new word frequency record."
  (if (list-empty? acc)
    (list (make-word-frequency w 1 (estimate-word-tokens w)))
    (let [(head-f (option-or (list-head acc) (make-word-frequency "" 0 0)))
          (tail-f (option-or (list-tail acc) (list)))]
      (if (= (.-word head-f) w)
        (let [(new-cnt (+ (.-count head-f) 1))
              (tok-unit (estimate-word-tokens w))
              (new-toks (* new-cnt tok-unit))]
          (list-cons (make-word-frequency w new-cnt new-toks) tail-f))
        (list-cons head-f (insert-word-freq w tail-f))))))

(df compute-word-frequencies-loop [(tokens (List Str)) (acc (List WordFrequency))] -> (List WordFrequency)
  :d "Tail-recursive loop building frequency aggregation list."
  (if (list-empty? tokens)
    acc
    (let [(head-w (option-or (list-head tokens) ""))
          (tail-w (option-or (list-tail tokens) (list)))]
      (compute-word-frequencies-loop tail-w (insert-word-freq head-w acc)))))

(df compute-word-frequencies [(tokens (List Str))] -> (List WordFrequency)
  :d "Aggregates unique word frequencies across token stream."
  (compute-word-frequencies-loop tokens (list)))

(df insert-freq-desc [(item WordFrequency) (sorted (List WordFrequency))] -> (List WordFrequency)
  :d "Inserts WordFrequency item into descending frequency sorted list."
  (if (list-empty? sorted)
    (list item)
    (let [(head-f (option-or (list-head sorted) (make-word-frequency "" 0 0)))
          (tail-f (option-or (list-tail sorted) (list)))]
      (if (>= (.-count item) (.-count head-f))
        (list-cons item sorted)
        (list-cons head-f (insert-freq-desc item tail-f))))))

(df sort-word-frequencies-desc-loop [(unsorted (List WordFrequency)) (sorted (List WordFrequency))] -> (List WordFrequency)
  :d "Tail-recursive loop sorting word frequencies in descending order."
  (if (list-empty? unsorted)
    sorted
    (let [(head-f (option-or (list-head unsorted) (make-word-frequency "" 0 0)))
          (tail-f (option-or (list-tail unsorted) (list)))]
      (sort-word-frequencies-desc-loop tail-f (insert-freq-desc head-f sorted)))))

(df sort-word-frequencies-desc [(freqs (List WordFrequency))] -> (List WordFrequency)
  :d "Sorts word frequencies descending from highest occurrence to lowest."
  (sort-word-frequencies-desc-loop freqs (list)))

(df take-top-frequencies [(sorted (List WordFrequency)) (n I64)] -> (List WordFrequency)
  :d "Extracts first n items from sorted frequency list."
  (if (or (<= n 0) (list-empty? sorted))
    (list)
    (let [(head-f (option-or (list-head sorted) (make-word-frequency "" 0 0)))
          (tail-f (option-or (list-tail sorted) (list)))]
      (list-cons head-f (take-top-frequencies tail-f (- n 1))))))

(df compute-token-profile [(source Str) (text Str) (top-n I64)] -> TokenProfile
  :d "Analyzes input text and computes hierarchical token profile with top words from highest to lowest."
  (let [(tokens (clean-token-stream text))
        (tot-chars (string-length text))
        (token-weights (map (fn [(w Str)] -> I64 (estimate-word-tokens w)) tokens))
        (tot-tokens (list-sum token-weights))
        (breakdown (compute-token-breakdown tokens))
        (raw-freqs (compute-word-frequencies tokens))
        (sorted-freqs (sort-word-frequencies-desc raw-freqs))
        (top-words (take-top-frequencies sorted-freqs top-n))
        (unique-cnt (list-length raw-freqs))
        (semantic-tokens (+ (.-keywords breakdown) (+ (.-identifiers breakdown) (.-literals breakdown))))
        (snr (if (= tot-tokens 0) 1.0 (/ (int64-to-float64 semantic-tokens) (int64-to-float64 tot-tokens))))]
    (TokenProfile
      :source-desc source
      :total-tokens tot-tokens
      :total-chars tot-chars
      :unique-words unique-cnt
      :snr-score snr
      :breakdown breakdown
      :top-words top-words)))

(df format-word-frequency-asn [(wf WordFrequency)] -> Str
  :d "Formats single WordFrequency entry into canonical ASN."
  (str "(:w :word \"" (esc/escape-asn-str (.-word wf)) "\""
       " :count " (string-from-int64 (.-count wf))
       " :tokens " (string-from-int64 (.-tokens wf)) ")"))

(df format-token-profile-asn [(p TokenProfile)] -> Str
  :d "Formats complete TokenProfile into canonical ASN representation with top words."
  (let [(bd (.-breakdown p))
        (wf-strs (map (fn [(wf WordFrequency)] -> Str (format-word-frequency-asn wf)) (.-top-words p)))
        (words-body (string-join wf-strs " "))]
    (str "(:token-profile\n"
         "  :source \"" (esc/escape-asn-str (.-source-desc p)) "\"\n"
         "  :total-tokens " (string-from-int64 (.-total-tokens p)) "\n"
         "  :total-chars " (string-from-int64 (.-total-chars p)) "\n"
         "  :unique-words " (string-from-int64 (.-unique-words p)) "\n"
         "  :snr " (string-from-float64 (.-snr-score p)) "\n"
         "  :breakdown (:keywords " (string-from-int64 (.-keywords bd))
         " :identifiers " (string-from-int64 (.-identifiers bd))
         " :literals " (string-from-int64 (.-literals bd))
         " :delimiters " (string-from-int64 (.-delimiters bd)) ")\n"
         "  :top-words [" words-body "])\n")))
