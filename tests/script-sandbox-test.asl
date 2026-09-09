(module asl-harness/script-sandbox-test
  :d "Unit verification test suite for In-Memory Sandboxed Script Runners"
  :x [test-create-sandbox-config
      test-sandbox-safety-detection
      test-run-sandboxed-python-script
      test-run-sandboxed-wasm
      test-sandbox-memory-limit
      test-evaluate-expression
      run-sandbox-tests
      run-tests]
  :i [(script-sandbox :a ss)])

(df test-create-sandbox-config [] -> Bool
  :d "Tests default configuration of sandbox bounds"
  (let [(cfg (ss/create-sandbox-config (ss/runtime-python) 1000 1048576))]
    (assert (= (.-timeout-ms cfg) 1000) "timeout is 1000")
    (assert (= (.-memory-limit-bytes cfg) 1048576) "memory limit is 1048576")
    (assert (not (.-allow-fs-write cfg)) "fs write disabled")
    true))

(df test-sandbox-safety-detection [] -> Bool
  :d "Tests rejection of dangerous filesystem patterns"
  (let [(cfg (ss/create-sandbox-config (ss/runtime-python) 1000 1048576))
        (unsafe-script "import os\nos.system('rm -rf /')\n")
        (safe-script "print('hello')\n")
        (audit-bad (ss/audit-sandbox-safety unsafe-script cfg))
        (audit-good (ss/audit-sandbox-safety safe-script cfg))]
    (assert (match audit-bad ((some _) true) ((none) false)) "audit-bad detected")
    (assert (match audit-good ((none) true) ((some _) false)) "audit-good passed")
    true))

(df test-run-sandboxed-python-script [] -> Bool
  :d "Tests execution of safe Python snippet"
  (let [(cfg (ss/create-sandbox-config (ss/runtime-python) 1000 1048576))
        (script "def fib(n):\n    return n if n <= 1 else fib(n-1) + fib(n-2)\nprint(fib(10))\n")
        (res (ss/run-sandboxed-script script cfg))]
    (assert (= (.-exit-code res) 0) "exit code 0")
    (assert (.-isolated res) "is isolated")
    (assert (> (string-length (.-stdout res)) 0) "stdout non-empty")
    (assert (> (string-length (ss/format-sandbox-result res)) 0) "format non-empty")
    true))

(df test-run-sandboxed-wasm [] -> Bool
  :d "Tests execution of safe WASM bytecode snippet"
  (let [(cfg (ss/create-sandbox-config (ss/runtime-wasm) 500 524288))
        (script "(module (func (export \"add\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))")
        (res (ss/run-sandboxed-script script cfg))]
    (assert (= (.-exit-code res) 0) "wasm exit code 0")
    (assert (.-isolated res) "wasm is isolated")
    true))

(df test-sandbox-memory-limit [] -> Bool
  :d "Tests enforcement of memory quota limits"
  (let [(cfg (ss/create-sandbox-config (ss/runtime-rust) 500 100))
        (huge-script (str "fn main() {\n"
                          "    let v = vec![0; 100000];\n"
                          "}\n"))
        (res (ss/run-sandboxed-script huge-script cfg))]
    (assert (= (.-exit-code res) 137) "memory limit exit code 137")
    (assert (not (= (.-exit-code res) 0)) "exit code must not be 0")
    true))

(df test-evaluate-expression [] -> Bool
  :d "Tests fast in-memory expression evaluation"
  (let [(res1 (ss/evaluate-expression "2 + 2" (ss/runtime-python)))
        (res2 (ss/evaluate-expression "10 * 10" (ss/runtime-go)))]
    (assert (= res1 "4") "res1 is 4")
    (assert (= res2 "100") "res2 is 100")
    true))

(df run-sandbox-tests [] -> Bool
  :d "Runs complete test suite for in-memory script sandbox"
  (do
    (test-create-sandbox-config)
    (test-sandbox-safety-detection)
    (test-run-sandboxed-python-script)
    (test-run-sandboxed-wasm)
    (test-sandbox-memory-limit)
    (test-evaluate-expression)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-sandbox-tests"
  (run-sandbox-tests))
