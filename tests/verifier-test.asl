(module asl-harness/verifier-test
  :d "Unit tests for universal polyglot pre-execution verifier and anti-hallucination guardrails."
  :x [test-detect-language test-validate-delimiter-balance test-validate-markup-tags
      test-validate-yaml-syntax test-resolve-test-runner test-verify-chunk-match
      test-verify-structural-action test-execute-verification-gate test-format-gate-rejection
      test-python-structural-validation run-tests]
  :i [(verifier :a v)])

(df test-detect-language [] -> Bool
  :d "Verifies polyglot language detection across modern tech stack."
  (assert (= (v/detect-language "src/main.asl") "asl") "asl detection must match")
  (assert (= (v/detect-language "components/Button.tsx") "tsx") "tsx detection must match")
  (assert (= (v/detect-language "utils/format.ts") "typescript") "ts detection must match")
  (assert (= (v/detect-language "scripts/calc.py") "python") "python detection must match")
  (assert (= (v/detect-language "engine/lib.rs") "rust") "rust detection must match")
  (assert (= (v/detect-language "ios/App.swift") "swift") "swift detection must match")
  (assert (= (v/detect-language "android/Main.kt") "kotlin") "kotlin detection must match")
  (assert (= (v/detect-language "server/App.java") "java") "java detection must match")
  (assert (= (v/detect-language "config/ci.yaml") "yaml") "yaml detection must match")
  (assert (= (v/detect-language "data/feed.xml") "xml") "xml detection must match")
  (assert (= (v/detect-language "public/index.html") "html") "html detection must match")
  true)

(df test-validate-delimiter-balance [] -> Bool
  :d "Verifies universal delimiter matching across TS, Java, Swift, Python, and Rust."
  (let [(valid-ts "const f = (x: number): number[] => [x * 2];")
        (invalid-ts "const f = (x: number): number[] => [x * 2;")
        (valid-swift "func greet(name: String) -> String { return \"Hello, \\(name)\" }")
        (valid-java "public static void main(String[] args) { System.out.println(1); }")]
    (assert (v/validate-delimiter-balance valid-ts) "valid-ts must be balanced")
    (assert (not (v/validate-delimiter-balance invalid-ts)) "invalid-ts must be flagged unbalanced")
    (assert (v/validate-delimiter-balance valid-swift) "valid-swift must be balanced")
    (assert (v/validate-delimiter-balance valid-java) "valid-java must be balanced")
    true))

(df test-validate-markup-tags [] -> Bool
  :d "Verifies tag balancing for TSX, HTML, and XML."
  (let [(valid-tsx "<button className=\"btn\"><span className=\"icon\">+</span>Add</button>")
        (invalid-tsx "<button className=\"btn\"><span className=\"icon\">+Add</button>")
        (valid-xml "<package name=\"asl\"><version>1.0</version></package>")]
    (assert (v/validate-markup-tags valid-tsx) "valid-tsx must be balanced")
    (assert (not (v/validate-markup-tags invalid-tsx)) "invalid-tsx must be flagged unbalanced")
    (assert (v/validate-markup-tags valid-xml) "valid-xml must be balanced")
    true))

(df test-validate-yaml-syntax [] -> Bool
  :d "Verifies YAML rejects forbidden tabs and enforces valid collections."
  (let [(valid-yaml "name: genseam\nversion: 1.0.0\ntags:\n  - core\n  - harness\n")
        (tabbed-yaml "name: genseam\n\tversion: 1.0.0\n")]
    (assert (v/validate-yaml-syntax valid-yaml) "valid-yaml must pass")
    (assert (not (v/validate-yaml-syntax tabbed-yaml)) "tabbed-yaml must be rejected")
    true))

(df test-resolve-test-runner [] -> Bool
  :d "Verifies canonical test command resolution across languages."
  (assert (= (v/resolve-test-runner "asl") "asl test") "asl runner must match")
  (assert (= (v/resolve-test-runner "tsx") "pnpm test") "tsx runner must match")
  (assert (= (v/resolve-test-runner "typescript") "pnpm test") "ts runner must match")
  (assert (= (v/resolve-test-runner "python") "pytest") "py runner must match")
  (assert (= (v/resolve-test-runner "rust") "cargo test") "rust runner must match")
  (assert (= (v/resolve-test-runner "swift") "swift test") "swift runner must match")
  (assert (= (v/resolve-test-runner "kotlin") "gradle test") "kotlin runner must match")
  true)

(df test-verify-chunk-match [] -> Bool
  :d "Verifies chunk match validation for surgical edits."
  (let [(content "def add(a, b):\n    return a + b\n")
        (good-chunk "return a + b")
        (bad-chunk "return a * b")
        (res-good (v/verify-chunk-match content good-chunk))
        (res-bad (v/verify-chunk-match content bad-chunk))]
    (assert (.-allowed res-good) "good chunk must match")
    (assert (not (.-allowed res-bad)) "bad chunk must not match")
    true))

(df test-verify-structural-action [] -> Bool
  :d "Verifies pre-execution structural action gate across languages."
  (let [(res-good-ts (v/verify-structural-action "str-replace" "main.ts" "const x = { a: 1 };"))
        (res-bad-tsx (v/verify-structural-action "str-replace" "App.tsx" "<div className=\"box\"><span>hi</div>"))
        (res-bad-yaml (v/verify-structural-action "str-replace" "ci.yaml" "build:\n\tsteps:\n"))]
    (assert (.-allowed res-good-ts) "good ts must be allowed")
    (assert (not (.-allowed res-bad-tsx)) "bad tsx markup must be rejected")
    (assert (not (.-allowed res-bad-yaml)) "bad yaml tabs must be rejected")
    true))

(df test-execute-verification-gate [] -> Bool
  :d "Verifies independent automated verification gate prevents self-declaration hallucination."
  (let [(res-pass (v/execute-verification-gate "pnpm test" true))
        (res-fail (v/execute-verification-gate "pnpm test" false))
        (res-empty (v/execute-verification-gate "" true))]
    (assert (.-allowed res-pass) "gate pass must be allowed")
    (assert (not (.-allowed res-fail)) "gate fail must not be allowed")
    (assert (not (.-allowed res-empty)) "empty gate must not be allowed")
    true))

(df test-format-gate-rejection [] -> Bool
  :d "Verifies gate rejection formats structured diagnostic message."
  (let [(msg (v/format-gate-rejection "cargo test" "exit 1"))]
    (assert (string-contains? msg ":gate-rejected") "msg must contain :gate-rejected")
    (assert (string-contains? msg "cargo test") "msg must contain command")
    true))

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
    (assert (= py-lang "python") "py-lang must match python")
    (assert (= py-runner "pytest") "py-runner must match pytest")
    (assert (v/validate-delimiter-balance py-valid-code) "py-valid-code must be balanced")
    (assert (not (v/validate-delimiter-balance py-unbalanced-code)) "py-unbalanced-code must be rejected")
    (assert (.-allowed py-clean-edit) "py-clean-edit must be allowed")
    (assert (not (.-allowed py-tab-edit)) "py-tab-edit must be rejected")
    (assert (string-contains? (.-reason py-tab-edit) "Forbidden tab characters") "reason must mention tab")
    (assert (.-allowed py-chunk-match) "py-chunk-match must match")
    (assert (not (.-allowed py-chunk-mismatch)) "py-chunk-mismatch must not match")
    (assert (.-allowed gate-ok) "gate-ok must pass")
    (assert (not (.-allowed gate-failed)) "gate-failed must fail")
    true))

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
