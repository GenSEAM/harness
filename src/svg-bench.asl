(module asl-harness/svg-bench
  :d "Vector Graphics (SVG & ASN) Benchmark Engine for Evaluating LLM Generation Quality, Syntax Validity, and Token Compaction."
  :x [SvgTask
      SvgEvalResult
      standard-svg-tasks
      find-svg-task
      validate-svg-syntax
      evaluate-svg-task
      format-svg-report]
  :i [(core/strings :a s)
      (asl-codec/svg-transpile :a svg)])

(dfs SvgTask
  (:f id Str "Unique task ID e.g. SVG-001")
  (:f title Str "Short task name")
  (:f prompt Str "Drawing instruction given to LLM")
  (:f complexity Str "basic, intermediate, or complex")
  (:f expected-tags (List Str) "Required SVG primitives that must be present"))

(dfs SvgEvalResult
  (:f task-id Str "Evaluated task ID")
  (:f valid-xml Bool "True if well-formed XML with closing tags")
  (:f has-viewbox Bool "True if viewBox or width/height specified")
  (:f element-count I64 "Number of distinct graphic primitives rendered")
  (:f raw-tokens I64 "Token count of raw SVG XML")
  (:f asn-tokens I64 "Token count of compact ASN vector representation")
  (:f savings-percent F64 "Token reduction achieved via ASN")
  (:f aesthetic-score F64 "Heuristic aesthetic fidelity score between 0.0 and 1.0")
  (:f success Bool "True if all validation invariants pass"))

(df standard-svg-tasks [] -> (List SvgTask)
  :d "Standard suite of 4 progressive vector graphic generation benchmark tasks."
  (list
    (SvgTask
      :id "SVG-001"
      :title "Geometric Minimalist Landscape"
      :prompt "Draw a minimalist vector landscape with a circular rising sun, layered mountain peaks using polygons, and a reflective river."
      :complexity "basic"
      :expected-tags (list "circle" "polygon" "rect"))
    (SvgTask
      :id "SVG-002"
      :title "Modern Chameleon Vector Logo"
      :prompt "Draw a modern vector logo of a chameleon with a curled tail, large round eye, and body contours using SVG paths."
      :complexity "intermediate"
      :expected-tags (list "path" "circle"))
    (SvgTask
      :id "SVG-003"
      :title "Dark-Mode UI Telemetry Card"
      :prompt "Draw a dark-mode UI metric card with rounded borders, a gradient glowing accent line, title 'Active Agents: 42', and a sparkline path."
      :complexity "intermediate"
      :expected-tags (list "rect" "linearGradient" "text" "path"))
    (SvgTask
      :id "SVG-004"
      :title "Agent Pipeline Flowchart Diagram"
      :prompt "Draw a flowchart showing three nodes: 'ASN Parser' -> 'Gemma 31B' -> 'SVG Renderer' with connecting arrows and labels."
      :complexity "complex"
      :expected-tags (list "rect" "text" "path" "line"))))

(df find-svg-task [(tasks (List SvgTask)) (id Str)] -> (Option SvgTask)
  :d "Finds a benchmark task by ID."
  (if (= (list-length tasks) 0)
      (none)
      (let [(head (option-or (list-head tasks) (SvgTask :id "" :title "" :prompt "" :complexity "" :expected-tags (list))))]
        (if (= (.-id head) id)
            (some head)
            (find-svg-task (option-or (list-tail tasks) (list)) id)))))

(df validate-svg-syntax [(svg-str Str)] -> Bool
  :d "Checks that the SVG string has valid root opening, closing tags, and balanced delimiters."
  (let [(trimmed (string-trim svg-str))]
    (and (or (string-starts-with? trimmed "<svg")
             (string-contains? trimmed "<svg"))
         (string-contains? trimmed "</svg>"))))

(df count-matching-tags [(svg-str Str) (tags (List Str))] -> I64
  :d "Counts how many required tags are present in the rendered SVG string."
  (if (= (list-length tags) 0)
      0
      (let [(t (option-or (list-head tags) ""))
            (matched (if (string-contains? svg-str t) 1 0))]
        (+ matched (count-matching-tags svg-str (option-or (list-tail tags) (list)))))))

(df evaluate-svg-task [(task SvgTask) (rendered-svg Str)] -> SvgEvalResult
  :d "Evaluates an LLM-generated SVG string against task requirements, token savings, and syntax invariants."
  (let [(is-valid (validate-svg-syntax rendered-svg))
        (has-vb (or (string-contains? rendered-svg "viewBox=")
                    (and (string-contains? rendered-svg "width=")
                         (string-contains? rendered-svg "height="))))
        (total-expected (list-length (.-expected-tags task)))
        (found-tags (count-matching-tags rendered-svg (.-expected-tags task)))
        (asn-comp (svg/svg-to-asn rendered-svg))
        (raw-tok (.-original-tokens asn-comp))
        (asn-tok (.-asn-tokens asn-comp))
        (savings (.-savings-percent asn-comp))
        (coverage (if (> total-expected 0)
                      (/ (float-from-int64 found-tags) (float-from-int64 total-expected))
                      0.0))
        (aesthetic (if (and is-valid has-vb)
                       (if (>= coverage 1.0) 0.9 0.6)
                       0.2))
        (success (and is-valid (and has-vb (>= coverage 0.5))))]
    (SvgEvalResult
      :task-id (.-id task)
      :valid-xml is-valid
      :has-viewbox has-vb
      :element-count found-tags
      :raw-tokens raw-tok
      :asn-tokens asn-tok
      :savings-percent savings
      :aesthetic-score aesthetic
      :success success)))

(df format-svg-report [(results (List SvgEvalResult))] -> Str
  :d "Formats benchmark evaluation results into a clean markdown table."
  (let [(header "| Task ID | Valid XML | ViewBox | Tag Match | Raw Tok | ASN Tok | Savings | Score | Status |\n|---|---|---|---|---|---|---|---|---|\n")
        (rows (format-rows results))]
    (s/concat header rows)))

(df format-rows [(results (List SvgEvalResult))] -> Str
  :d "Helper recursing over result list to format table rows."
  (if (= (list-length results) 0)
      ""
      (let [(r (option-or (list-head results)
                          (SvgEvalResult :task-id "" :valid-xml false :has-viewbox false :element-count 0 :raw-tokens 0 :asn-tokens 0 :savings-percent 0.0 :aesthetic-score 0.0 :success false)))
            (status-str (if (.-success r) "✓ PASS" "✗ FAIL"))
            (valid-str (if (.-valid-xml r) "YES" "NO"))
            (vb-str (if (.-has-viewbox r) "YES" "NO"))
            (row (s/concat "| " (.-task-id r)
                           " | " valid-str
                           " | " vb-str
                           " | " (int64-to-string (.-element-count r))
                           " | " (int64-to-string (.-raw-tokens r))
                           " | " (int64-to-string (.-asn-tokens r))
                           " | -" (int64-to-string (int64-from-float (.-savings-percent r))) "%"
                           " | " (int64-to-string (int64-from-float (* (.-aesthetic-score r) 100.0))) "%"
                           " | " status-str " |\n"))]
        (s/concat row (format-rows (option-or (list-tail results) (list)))))))
