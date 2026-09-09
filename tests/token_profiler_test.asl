(module asl-harness/token-profiler-test
  :d "Unit and falsifiable verification suite for lexical token profiling and hierarchical decomposition."
  :x [test-word-token-estimation
      test-token-category-predicates
      test-token-stream-extraction
      test-token-breakdown-and-snr
      test-frequency-sorting-descending
      test-full-token-profile-and-asn-formatting
      run-tests]
  :i [(token_profiler :a tp)])

(df test-word-token-estimation [] -> Bool
  :d "Verifies subword token estimation across empty, short, and long strings."
  (let [(tok-empty (tp/estimate-word-tokens ""))
        (tok-short (tp/estimate-word-tokens "cat"))
        (tok-four (tp/estimate-word-tokens "four"))
        (tok-eight (tp/estimate-word-tokens "eightlet"))
        (tok-long (tp/estimate-word-tokens "supercalifragilistic"))]
    (do
      (assert (= tok-empty 0) "Empty string must yield 0 tokens")
      (assert (= tok-short 1) "3-char word must yield 1 token")
      (assert (= tok-four 1) "4-char word must yield 1 token")
      (assert (>= tok-eight 2) "8-char word must yield at least 2 tokens")
      (assert (<= tok-eight 3) "8-char word must yield at most 3 tokens")
      (assert (>= tok-long 4) "Long word must yield at least 4 tokens")
      true)))

(df test-token-category-predicates [] -> Bool
  :d "Verifies categorization predicates for keywords, delimiters, and literals."
  (let [(kw (tp/is-keyword-token? ":action"))
        (not-kw (tp/is-keyword-token? "action"))
        (delim (tp/is-delimiter-token? "("))
        (not-delim (tp/is-delimiter-token? "foo"))
        (lit-str (tp/is-literal-token? "\"hello\""))
        (lit-num (tp/is-literal-token? "42"))
        (not-lit (tp/is-literal-token? "my-func"))]
    (do
      (assert kw "Colon prefixed word must be keyword")
      (assert (not not-kw) "Normal word is not keyword")
      (assert delim "Paren must be delimiter")
      (assert (not not-delim) "Word is not delimiter")
      (assert lit-str "Quoted string must be literal")
      (assert lit-num "Number must be literal")
      (assert (not not-lit) "Identifier is not literal")
      true)))

(df test-token-stream-extraction [] -> Bool
  :d "Verifies cleaning and token isolation from structured text."
  (let [(text "(:finding :cat \"crutch\" :line 10)")
        (tokens (tp/clean-token-stream text))]
    (do
      (assert (> (list-length tokens) 5) "Clean token stream must extract isolated tokens")
      (assert (= (option-or (list-head tokens) "") "(") "First token must be open paren")
      (assert (tp/is-keyword-token? (option-or (list-head (option-or (list-tail tokens) (list))) "")) "Second token must be keyword")
      true)))

(df test-token-breakdown-and-snr [] -> Bool
  :d "Verifies category breakdown calculation and non-zero counts."
  (let [(tokens (tp/clean-token-stream "(:op :id \"find\" :count 5) (run-test)"))
        (bd (tp/compute-token-breakdown tokens))]
    (do
      (assert (> (.-keywords bd) 0) "Must count keywords")
      (assert (> (.-delimiters bd) 0) "Must count delimiters")
      (assert (> (.-literals bd) 0) "Must count literals")
      (assert (> (.-identifiers bd) 0) "Must count identifiers")
      true)))

(df test-frequency-sorting-descending [] -> Bool
  :d "Verifies that token frequency sorting orders from highest occurrence to lowest."
  (let [(text ":tag :tag :tag :tag :sec :sec :other")
        (tokens (tp/clean-token-stream text))
        (freqs (tp/compute-word-frequencies tokens))
        (sorted (tp/sort-word-frequencies-desc freqs))
        (first-item (option-or (list-head sorted) (tp/make-word-frequency "" 0 0)))
        (second-item (option-or (list-head (option-or (list-tail sorted) (list))) (tp/make-word-frequency "" 0 0)))]
    (do
      (assert (= (.-word first-item) ":tag") "Top word must be :tag with highest frequency")
      (assert (= (.-count first-item) 4) "Top word count must be 4")
      (assert (= (.-word second-item) ":sec") "Second word must be :sec with count 2")
      (assert (= (.-count second-item) 2) "Second word count must be 2")
      (assert (>= (.-count first-item) (.-count second-item)) "Frequency must be strictly descending")
      true)))

(df test-full-token-profile-and-asn-formatting [] -> Bool
  :d "Verifies complete token profile construction and canonical ASN serialization."
  (let [(input "(:task :id \"t-01\" :status :ready :count 10)")
        (prof (tp/compute-token-profile "test-payload" input 3))
        (asn-str (tp/format-token-profile-asn prof))]
    (do
      (assert (> (.-total-tokens prof) 0) "Total tokens must be positive")
      (assert (> (.-total-chars prof) 0) "Total chars must be positive")
      (assert (> (.-unique-words prof) 0) "Unique words must be positive")
      (assert (> (.-snr-score prof) 0.0) "SNR must be positive")
      (assert (string-contains? asn-str "(:token-profile") "ASN output must contain :token-profile")
      (assert (string-contains? asn-str ":total-tokens") "ASN output must contain :total-tokens")
      (assert (string-contains? asn-str ":breakdown (:keywords") "ASN output must contain breakdown")
      (assert (string-contains? asn-str ":top-words [") "ASN output must contain top-words array")
      true)))

(df run-tests [] -> Bool
  :d "Executes all token profiler verification test suites."
  (do
    (assert (test-word-token-estimation))
    (assert (test-token-category-predicates))
    (assert (test-token-stream-extraction))
    (assert (test-token-breakdown-and-snr))
    (assert (test-frequency-sorting-descending))
    (assert (test-full-token-profile-and-asn-formatting))
    true))
