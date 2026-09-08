(module asl-harness/prompt-cache
  :doc "Deterministic KV-cache prefix aligner and prompt cache locker for 95%+ LLM hit rates."
  :x [PromptPrefix
      freeze-system-prefix
      assemble-cached-prompt
      verify-prefix-stability]
  :i [])

(dfs PromptPrefix
  (:f axioms-hash Str "Content hash of sorted system axioms")
  (:f tools-hash Str "Content hash of sorted tool definitions")
  (:f canonical-prefix Str "Deterministic canonical frozen prefix text"))

(df insert-str [(item Str) (sorted (List Str))] -> (List Str)
  :doc "Inserts string into sorted list in ascending lexicographic order."
  (if (list-empty? sorted)
      (list item)
      (let [(head-s (option-or (list-head sorted) ""))
            (tail-s (option-or (list-tail sorted) (list)))]
        (if (<= item head-s)
            (list-cons item sorted)
            (list-cons head-s (insert-str item tail-s))))))

(df sort-str-list-loop [(unsorted (List Str)) (sorted (List Str))] -> (List Str)
  :doc "Loop sorting string list in ascending lexicographical order."
  (if (list-empty? unsorted)
      sorted
      (let [(item (option-or (list-head unsorted) ""))
            (rest (option-or (list-tail unsorted) (list)))]
        (sort-str-list-loop rest (insert-str item sorted)))))

(df sort-strings [(strings (List Str))] -> (List Str)
  :doc "Sorts string list in ascending lexicographical order."
  (sort-str-list-loop strings (list)))

(df char-val [(ch Str)] -> I64
  :doc "Maps single character to integer code."
  (let [(charset "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ !\"#$%&'()*+,-./:<=>?@[\\]^_`{|}~\t\n\r")]
    (mt (string-index-of charset ch)
      ((none) 127)
      ((some idx) (+ idx 32)))))

(df fast-str-hash-loop [(chars (List Str)) (h I64)] -> I64
  :doc "Computes rolling 64-bit hash over character list."
  (if (list-empty? chars)
      h
      (let [(ch (option-or (list-head chars) ""))
            (rest (option-or (list-tail chars) (list)))
            (cv (char-val ch))
            (next-h (mod (+ (* h 1099511628211) cv) 9223372036854775807))]
        (fast-str-hash-loop rest next-h))))

(df fast-str-hash [(text Str)] -> Str
  :doc "Computes deterministic 64-bit integer hash string for given text."
  (let [(chars (string-chars text))
        (final-h (fast-str-hash-loop chars 1469598103934))]
    (string-from-int64 final-h)))

(df freeze-system-prefix [(axioms (List Str)) (tools (List Str))] -> PromptPrefix
  :doc "Serializes canonical sorted axioms and tools into a frozen prompt prefix record."
  (let [(sorted-axioms (sort-strings axioms))
        (sorted-tools (sort-strings tools))
        (ax-body (string-join sorted-axioms "\n"))
        (tl-body (string-join sorted-tools "\n"))
        (ax-hash (fast-str-hash ax-body))
        (tl-hash (fast-str-hash tl-body))
        (prefix-str (str "(:system-prefix\n  :axioms [\n"
                         (if (list-empty? sorted-axioms) "" (str "    \"" (string-join sorted-axioms "\"\n    \"") "\"\n"))
                         "  ]\n  :tools [\n"
                         (if (list-empty? sorted-tools) "" (str "    \"" (string-join sorted-tools "\"\n    \"") "\"\n"))
                         "  ])\n(:dynamic-turn-marker)\n"))]
    (PromptPrefix
      :axioms-hash ax-hash
      :tools-hash tl-hash
      :canonical-prefix prefix-str)))

(df assemble-cached-prompt [(prefix PromptPrefix) (dynamic-turns (List Str))] -> Str
  :doc "Assembles full prompt by appending dynamic dialogue turns after the frozen prefix boundary."
  (let [(frozen (.-canonical-prefix prefix))
        (turns-str (string-join dynamic-turns "\n"))]
    (str frozen turns-str)))

(df extract-frozen-prefix [(prompt Str)] -> Str
  :doc "Extracts frozen prefix text preceding the dynamic turn marker."
  (let [(marker "(:dynamic-turn-marker)")
        (parts (string-split prompt marker))]
    (option-or (list-head parts) prompt)))

(df verify-prefix-stability [(p1 Str) (p2 Str)] -> Bool
  :doc "Verifies bit-for-bit stability of the frozen prefix across different prompt variations."
  (let [(pref-1 (extract-frozen-prefix p1))
        (pref-2 (extract-frozen-prefix p2))]
    (= pref-1 pref-2)))
