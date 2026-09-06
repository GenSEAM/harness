(module asl-harness/tests/svg-bench-test
  :d "Unit tests for pure ASL SVG benchmark evaluation engine."
  :x [test-svg-tasks
      test-svg-syntax
      test-svg-eval
      test-svg-table
      test-baseline-run
      run-tests]
  :i [(svg-bench :a bench)
      (eval-runner :a runner)])

(df test-svg-tasks [] -> Bool
  :d "Verifies standard SVG benchmark task registry."
  (let [(tasks (bench/standard-svg-tasks))]
    (and (= (list-length tasks) 4)
         (and (= (.-id (option-or (bench/find-svg-task tasks "SVG-001") (bench/SvgTask :id "" :title "" :prompt "" :complexity "" :expected-tags (list)))) "SVG-001")
              (and (= (.-id (option-or (bench/find-svg-task tasks "SVG-002") (bench/SvgTask :id "" :title "" :prompt "" :complexity "" :expected-tags (list)))) "SVG-002")
                   (= (.-id (option-or (bench/find-svg-task tasks "SVG-004") (bench/SvgTask :id "" :title "" :prompt "" :complexity "" :expected-tags (list)))) "SVG-004"))))))

(df test-svg-syntax [] -> Bool
  :d "Verifies SVG syntax validator correctly distinguishes valid from malformed XML."
  (let [(valid "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><circle cx=\"50\" cy=\"50\" r=\"40\"/></svg>")
        (unclosed "<svg viewBox=\"0 0 100 100\"><rect width=\"100\" height=\"100\">")
        (empty "")]
    (and (bench/validate-svg-syntax valid)
         (and (not (bench/validate-svg-syntax unclosed))
              (not (bench/validate-svg-syntax empty))))))

(df test-svg-eval [] -> Bool
  :d "Verifies evaluation of sample rendered SVG against SVG-001 task."
  (let [(tasks (bench/standard-svg-tasks))
        (task (option-or (bench/find-svg-task tasks "SVG-001") (bench/SvgTask :id "" :title "" :prompt "" :complexity "" :expected-tags (list))))
        (sample "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 400 300\"><rect width=\"400\" height=\"300\" fill=\"#0f172a\"/><circle cx=\"200\" cy=\"120\" r=\"50\" fill=\"#f59e0b\"/><polygon points=\"50,300 200,160 350,300\" fill=\"#334155\"/></svg>")
        (result (bench/evaluate-svg-task task sample))]
    (and (.-success result)
         (and (.-valid-xml result)
              (and (.-has-viewbox result)
                   (and (>= (.-element-count result) 3)
                        (>= (.-savings-percent result) 25.0)))))))

(df test-svg-table [] -> Bool
  :d "Verifies markdown table rendering of benchmark results."
  (let [(res1 (bench/SvgEvalResult :task-id "SVG-001" :valid-xml true :has-viewbox true :element-count 3 :raw-tokens 65 :asn-tokens 38 :savings-percent 41.5 :aesthetic-score 0.85 :success true))
        (table (bench/format-svg-report (list res1)))]
    (and (string-contains? table "| Task ID | Valid XML |")
         (and (string-contains? table "SVG-001")
              (string-contains? table "✓ PASS")))))

(df test-baseline-run [] -> Bool
  :d "Verifies end-to-end execution of baseline benchmark runner across all 4 tasks."
  (let [(report (runner/run-baseline-benchmark))]
    (and (string-contains? report "SVG-001")
         (and (string-contains? report "SVG-002")
              (and (string-contains? report "SVG-003")
                   (string-contains? report "SVG-004"))))))

(df run-tests [] -> Bool
  :d "Executes complete SVG benchmark test suite."
  (and (test-svg-tasks)
       (and (test-svg-syntax)
            (and (test-svg-eval)
                 (and (test-svg-table)
                      (test-baseline-run))))))
