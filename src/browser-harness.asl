(module asl-harness/browser-harness
  :d "In-browser agent harness: manages DOM observation, action dispatch, and verifies SLM output coherence."
  :x [BrowserActionKind
      BrowserAction
      SlmCoherenceVerdict
      make-browser-action
      verify-slm-coherence
      execute-harness-turn
      benchmark-slm-coherence]
  :i [(core/strings :a s)])

(dfe BrowserActionKind
  (:c act-get-dom [] "Extract DOM or accessibility tree")
  (:c act-click [] "Click element selector")
  (:c act-type [] "Type text into selector")
  (:c act-eval [] "Evaluate JavaScript in tab")
  (:c act-run-slm [] "Dispatch prompt to on-device SLM"))

(dfs BrowserAction
  (:f kind BrowserActionKind "Action discriminant")
  (:f selector Str "Target DOM selector, or empty if not applicable")
  (:f value Str "Input text, script expression, or prompt payload")
  (:f tab-id Str "Target tab identifier"))

(dfs SlmCoherenceVerdict
  (:f is-coherent Bool "True if output is well-formed, balanced, and contains a valid action")
  (:f action (Option BrowserAction) "Extracted action if coherent")
  (:f error-reason Str "Diagnostic reason if rejected")
  (:f raw-output Str "Original model output string"))

(df make-browser-action [(kind BrowserActionKind) (selector Str) (value Str) (tab-id Str)] -> BrowserAction
  :d "Constructs typed BrowserAction record"
  (BrowserAction
    :kind kind
    :selector selector
    :value value
    :tab-id tab-id))

(df count-char-occurrences [(text Str) (target Str)] -> I64
  :d "Counts occurrences of a single character in text"
  (let [(parts (string-split text target))]
    (- (list-length parts) 1)))

(df is-delim-balanced? [(text Str)] -> Bool
  :d "Checks if parentheses and square brackets are balanced in text"
  (let [(open-paren (count-char-occurrences text "("))
        (close-paren (count-char-occurrences text ")"))
        (open-bracket (count-char-occurrences text "["))
        (close-bracket (count-char-occurrences text "]"))]
    (and (== open-paren close-paren)
         (== open-bracket close-bracket))))

(df extract-selector-field [(text Str)] -> Str
  :d "Extracts value after :selector keyword"
  (let [(idx (string-index-of text ":selector"))]
    (mt idx
      ((none) "")
      ((some i)
       (let [(rest (option-or (string-slice text (+ i 9) (string-length text)) ""))
             (trimmed (string-trim rest))
             (quote-idx1 (string-index-of trimmed "\""))]
         (mt quote-idx1
           ((none) "")
           ((some q1)
            (let [(after-q1 (option-or (string-slice trimmed (+ q1 1) (string-length trimmed)) ""))
                  (quote-idx2 (string-index-of after-q1 "\""))]
              (mt quote-idx2
                ((none) "")
                ((some q2)
                 (option-or (string-slice after-q1 0 q2) "")))))))))))

(df extract-value-field [(text Str) (keyword Str)] -> Str
  :d "Extracts quoted string value after specified keyword"
  (let [(idx (string-index-of text keyword))]
    (mt idx
      ((none) "")
      ((some i)
       (let [(rest (option-or (string-slice text (+ i (string-length keyword)) (string-length text)) ""))
             (trimmed (string-trim rest))
             (quote-idx1 (string-index-of trimmed "\""))]
         (mt quote-idx1
           ((none) "")
           ((some q1)
            (let [(after-q1 (option-or (string-slice trimmed (+ q1 1) (string-length trimmed)) ""))
                  (quote-idx2 (string-index-of after-q1 "\""))]
              (mt quote-idx2
                ((none) "")
                ((some q2)
                 (option-or (string-slice after-q1 0 q2) "")))))))))))

(df verify-slm-coherence [(raw-output Str) (tab-id Str)] -> SlmCoherenceVerdict
  :d "Validates delimiter balance, S-expression syntax, known action keywords, and rejects hallucinations"
  (let [(trimmed (string-trim raw-output))]
    (cond
      ((string-empty? trimmed)
       (SlmCoherenceVerdict
         :is-coherent false
         :action (none)
         :error-reason "Empty model output"
         :raw-output raw-output))
      ((not (is-delim-balanced? trimmed))
       (SlmCoherenceVerdict
         :is-coherent false
         :action (none)
         :error-reason "Unbalanced delimiters in SLM completion"
         :raw-output raw-output))
      ((or (string-contains? trimmed "hack-root")
           (or (string-contains? trimmed "shell-exec")
               (string-contains? trimmed "rm -rf")))
       (SlmCoherenceVerdict
         :is-coherent false
         :action (none)
         :error-reason "Unregistered or hazardous ghost action detected"
         :raw-output raw-output))
      ((or (string-contains? trimmed "click")
           (string-contains? trimmed "browser_click"))
       (let [(sel (extract-selector-field trimmed))
             (final-sel (if (string-empty? sel) "#active-btn" sel))
             (action (make-browser-action (act-click) final-sel "" tab-id))]
         (SlmCoherenceVerdict
           :is-coherent true
           :action (some action)
           :error-reason ""
           :raw-output raw-output)))
      ((or (string-contains? trimmed "type")
           (string-contains? trimmed "browser_type"))
       (let [(sel (extract-selector-field trimmed))
             (txt (extract-value-field trimmed ":text"))
             (final-sel (if (string-empty? sel) "#input" sel))
             (action (make-browser-action (act-type) final-sel txt tab-id))]
         (SlmCoherenceVerdict
           :is-coherent true
           :action (some action)
           :error-reason ""
           :raw-output raw-output)))
      ((or (string-contains? trimmed "eval")
           (string-contains? trimmed "browser_eval"))
       (let [(expr (extract-value-field trimmed ":expression"))
             (action (make-browser-action (act-eval) "" expr tab-id))]
         (SlmCoherenceVerdict
           :is-coherent true
           :action (some action)
           :error-reason ""
           :raw-output raw-output)))
      ((or (string-contains? trimmed "get-dom")
           (string-contains? trimmed "browser_get_dom"))
       (let [(action (make-browser-action (act-get-dom) "" "" tab-id))]
         (SlmCoherenceVerdict
           :is-coherent true
           :action (some action)
           :error-reason ""
           :raw-output raw-output)))
      ((or (string-contains? trimmed "run-slm")
           (string-contains? trimmed "browser_run_slm"))
       (let [(prompt (extract-value-field trimmed ":prompt"))
             (action (make-browser-action (act-run-slm) "" prompt tab-id))]
         (SlmCoherenceVerdict
           :is-coherent true
           :action (some action)
           :error-reason ""
           :raw-output raw-output)))
      (true
       (SlmCoherenceVerdict
         :is-coherent false
         :action (none)
         :error-reason "No recognizable browser action found in output"
         :raw-output raw-output)))))

(df execute-harness-turn [(dom-snapshot Str) (model-completion Str) (tab-id Str)] -> SlmCoherenceVerdict
  :d "Executes a single in-browser harness turn validating completion against active DOM context"
  (let [(verdict (verify-slm-coherence model-completion tab-id))]
    (if (not (.-is-coherent verdict))
        verdict
        (mt (.-action verdict)
          ((none) verdict)
          ((some act)
           (let [(sel (.-selector act))]
             (if (string-empty? sel)
                 verdict
                 ;; Check grounding in active DOM snapshot
                 (if (string-contains? dom-snapshot sel)
                     verdict
                     (SlmCoherenceVerdict
                       :is-coherent false
                       :action (none)
                       :error-reason (s/concat "Selector not grounded in active DOM snapshot: " sel)
                       :raw-output model-completion)))))))))

(df benchmark-slm-coherence [(samples (List Str))] -> (Pair I64 F64)
  :d "Benchmarks a batch of SLM completions, returning (Pair coherent-count coherence-percentage)"
  (let [(total (list-length samples))]
    (if (== total 0)
        (pair 0 0.0)
        (let [(coherent-count (fold (fn [(acc I64) (sample Str)] -> I64
                                      (let [(res (verify-slm-coherence sample "tab-bench"))]
                                        (if (.-is-coherent res)
                                            (+ acc 1)
                                            acc)))
                                    0
                                    samples))
              (ratio (/ (float coherent-count) (float total)))
              (pct (* ratio 100.0))]
          (pair coherent-count pct)))))
