(module asl-harness/verifier-test
  :d "Unit tests for universal polyglot pre-execution verifier and anti-hallucination guardrails."
  :x [test-detect-language test-validate-delimiter-balance test-validate-markup-tags
      test-validate-yaml-syntax test-resolve-test-runner test-verify-chunk-match
      test-verify-structural-action test-execute-verification-gate test-format-gate-rejection
      test-python-structural-validation run-tests]
  :i [(verifier :a v)])

(df test-detect-language [] -> Bool
  :d "Verifies polyglot language detection across modern tech stack."
  (and (= (v/detect-language "src/main.asl") "asl")
       (and (= (v/detect-language "components/Button.tsx") "tsx")
            (and (= (v/detect-language "utils/format.ts") "typescript")
                 (and (= (v/detect-language "scripts/calc.py") "python")
                      (and (= (v/detect-language "engine/lib.rs") "rust")
                           (and (= (v/detect-language "ios/App.swift") "swift")
                                (and (= (v/detect-language "android/Main.kt") "kotlin")
                                     (and (= (v/detect-language "server/App.java") "java")
                                          (and (= (v/detect-language "config/ci.yaml") "yaml")
                                               (and (= (v/detect-language "data/feed.xml") "xml")
                                                    (= (v/detect-language "public/index.html") "html"))))))))))))

(df test-validate-delimiter-balance [] -> Bool
  :d "Verifies universal delimiter matching across TS, Java, Swift, Python, and Rust."
  (let [(valid-ts "const f = (x: number): number[] => [x * 2];")
        (invalid-ts "const f = (x: number): number[] => [x * 2;")
        (valid-swift "func greet(name: String) -> String { return \"Hello, \\(name)\" }")
        (valid-java "public static void main(String[] args) { System.out.println(1); }")]
    (and (v/validate-delimiter-balance valid-ts)
         (and (not (v/validate-delimiter-balance invalid-ts))
              (and (v/validate-delimiter-balance valid-swift)
                   (v/validate-delimiter-balance valid-java))))))

(df test-validate-markup-tags [] -> Bool
  :d "Verifies tag balancing for TSX, HTML, and XML."
  (let [(valid-tsx "<button className=\"btn\"><span className=\"icon\">+</span>Add</button>")
        (invalid-tsx "<button className=\"btn\"><span className=\"icon\">+Add</button>")
        (valid-xml "<package name=\"asl\"><version>1.0</version></package>")]
    (and (v/validate-markup-tags valid-tsx)
         (and (not (v/validate-markup-tags invalid-tsx))
              (v/validate-markup-tags valid-xml)))))

(df test-validate-yaml-syntax [] -> Bool
  :d "Verifies YAML rejects forbidden tabs and enforces valid collections."
  (let [(valid-yaml "name: genseam\nversion: 1.0.0\ntags:\n  - core\n  - harness\n")
        (tabbed-yaml "name: genseam\n\tversion: 1.0.0\n")]
    (and (v/validate-yaml-syntax valid-yaml)
         (not (v/validate-yaml-syntax tabbed-yaml)))))

(df test-resolve-test-runner [] -> Bool
  :d "Verifies canonical test command resolution across languages."
  (and (= (v/resolve-test-runner "asl") "asl test")
       (and (= (v/resolve-test-runner "tsx") "pnpm test")
            (and (= (v/resolve-test-runner "typescript") "pnpm test")
                 (and (= (v/resolve-test-runner "python") "pytest")
                      (and (= (v/resolve-test-runner "rust") "cargo test")
                           (and (= (v/resolve-test-runner "swift") "swift test")
                                (= (v/resolve-test-runner "kotlin") "gradle test"))))))))

(df test-verify-chunk-match [] -> Bool
  :d "Verifies chunk match validation for surgical edits."
  (let [(content "def add(a, b):\n    return a + b\n")
        (good-chunk "return a + b")
        (bad-chunk "return a * b")
        (res-good (v/verify-chunk-match content good-chunk))
        (res-bad (v/verify-chunk-match content bad-chunk))]
    (and (.-allowed res-good)
         (not (.-allowed res-bad)))))

(df test-verify-structural-action [] -> Bool
  :d "Verifies pre-execution structural action gate across languages."
  (let [(res-good-ts (v/verify-structural-action "str-replace" "main.ts" "const x = { a: 1 };"))
        (res-bad-tsx (v/verify-structural-action "str-replace" "App.tsx" "<div className=\"box\"><span>hi</div>"))
        (res-bad-yaml (v/verify-structural-action "str-replace" "ci.yaml" "build:\n\tsteps:\n"))]
    (and (.-allowed res-good-ts)
         (and (not (.-allowed res-bad-tsx))
              (not (.-allowed res-bad-yaml))))))

(df test-execute-verification-gate [] -> Bool
  :d "Verifies independent automated verification gate prevents self-declaration hallucination."
  (let [(res-pass (v/execute-verification-gate "pnpm test" true))
        (res-fail (v/execute-verification-gate "pnpm test" false))
        (res-empty (v/execute-verification-gate "" true))]
    (and (.-allowed res-pass)
         (and (not (.-allowed res-fail))
              (not (.-allowed res-empty))))))

(df test-format-gate-rejection [] -> Bool
  :d "Verifies gate rejection formats structured diagnostic message."
  (let [(msg (v/format-gate-rejection "cargo test" "exit 1"))]
    (and (string-contains? msg ":gate-rejected")
         (string-contains? msg "cargo test"))))

(df test-python-structural-validation [] -> Bool
  :d "Verifies end-to-end Python validation: dialect detection, pytest resolution, delimiter balance, tab rejection, chunk matching, and gate enforcement."
  (let [(py-lang (v/detect-language "server/app.py"))
        (py-runner (v/resolve-test-runner "python"))
        (py-valid-code "def parse_records(items):\n    return {'data': [x.strip() for x in items if len(x) > 0]}\n")
        (py-unbalanced-code "def parse_records(items):\n    return {'data': [x.strip() for x in items\n")
        (py-clean-edit (v/verify-structural-action "str-replace" "calc.py" "def add(x, y):\n    return x + y\n"))
        (py-tab-edit (v/verify-structural-action "str-replace" "calc.py" "def add(x, y):\n\treturn x + y\n"))
        (py-source "def run():\n    value = 42\n    return value\n")
        (py-chunk-match (v/verify-chunk-match py-source "    value = 42"))
        (py-chunk-mismatch (v/verify-chunk-match py-source "    value = 99"))
        (gate-ok (v/execute-verification-gate "pytest" true))
        (gate-failed (v/execute-verification-gate "pytest" false))]
    (and (= py-lang "python")
         (and (= py-runner "pytest")
              (and (v/validate-delimiter-balance py-valid-code)
                   (and (not (v/validate-delimiter-balance py-unbalanced-code))
                        (and (.-allowed py-clean-edit)
                             (and (not (.-allowed py-tab-edit))
                                  (and (string-contains? (.-reason py-tab-edit) "Forbidden tab characters")
                                       (and (.-allowed py-chunk-match)
                                            (and (not (.-allowed py-chunk-mismatch))
                                                 (and (.-allowed gate-ok)
                                                      (not (.-allowed gate-failed))))))))))))))

(df run-tests [] -> Bool
  :d "Executes full polyglot verifier test suite."
  (and (test-detect-language)
       (and (test-validate-delimiter-balance)
            (and (test-validate-markup-tags)
                 (and (test-validate-yaml-syntax)
                      (and (test-resolve-test-runner)
                           (and (test-verify-chunk-match)
                                (and (test-verify-structural-action)
                                     (and (test-execute-verification-gate)
                                          (and (test-format-gate-rejection)
                                               (test-python-structural-validation)))))))))))

