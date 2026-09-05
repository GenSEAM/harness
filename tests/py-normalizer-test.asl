(module asl-harness/py-normalizer-test
  :d "Unit tests for Python syntax normalizer."
  :x [test-py-colons test-py-indentation test-missing-imports test-traceback-parsing run-tests]
  :i [(py-normalizer :a pyn)])

(df test-py-colons [] -> Bool
  :d "Verifies missing colons are auto-appended to compound statement headers."
  (let [(code "def solve(x)\n    if x > 0\n        return True\n    else\n        return False")
        (fixed (pyn/repair-py-colons code))]
    (and (string-contains? fixed "def solve(x):")
         (and (string-contains? fixed "if x > 0:")
              (string-contains? fixed "else:")))))

(df test-py-indentation [] -> Bool
  :d "Verifies tabbed indentation is replaced with standard 4 spaces."
  (let [(code "def foo():\n\treturn 42")
        (fixed (pyn/normalize-indentation code))]
    (and (string-contains? fixed "    return 42")
         (not (string-contains? fixed "\t")))))

(df test-missing-imports [] -> Bool
  :d "Verifies unimported standard library references are detected and injected."
  (let [(code "def parse(s):\n    return json.loads(s)")
        (fixed (pyn/repair-python-code code))]
    (string-contains? fixed "import json")))

(df test-traceback-parsing [] -> Bool
  :d "Verifies raw Python traceback is parsed into compact receipt."
  (let [(tb "Traceback (most recent call last):\n  File \"test.py\", line 15, in run\n    x = 1 / 0\nZeroDivisionError: division by zero")
        (parsed (pyn/parse-py-traceback tb))]
    (and (string-contains? parsed "line 15")
         (string-contains? parsed "ZeroDivisionError"))))

(df run-tests [] -> Bool
  :d "Executes full Python normalizer test suite."
  (and (test-py-colons)
       (and (test-py-indentation)
            (and (test-missing-imports)
                 (test-traceback-parsing)))))

