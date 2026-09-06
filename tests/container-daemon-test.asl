(module asl-harness/tests/container-daemon-test
  :d "Unit tests for in-container autonomous daemon execution engine."
  :x [run-tests]
  :i [(container-daemon :a d)])

(df test-make-daemon-config [] -> Bool
  :d "Verifies daemon configuration initialization."
  (let [(cfg (d/make-daemon-config 300 30 "/app"))]
    (and (= (.-max-tokens-tail cfg) 300)
         (and (= (.-default-timeout cfg) 30)
              (= (.-work-dir cfg) "/app")))))

(df test-bounded-read [] -> Bool
  :d "Verifies line-ranged bounded file reading logic."
  (let [(raw "line 1\nline 2\nline 3\nline 4\nline 5")
        (res (d/read-bounded-lines raw 2 4))]
    (and (string-contains? res "2: line 2")
         (and (string-contains? res "3: line 3")
              (and (string-contains? res "4: line 4")
                   (not (string-contains? res "1: line 1")))))))

(df test-apply-replacement [] -> Bool
  :d "Verifies exact string replacement."
  (let [(code "def solve(): return False")
        (res-ok (d/apply-string-replacement code "False" "True"))
        (res-bad (d/apply-string-replacement code "Nonexistent" "True"))]
    (and (mt res-ok ((ok v) (= v "def solve(): return True") ((err _) false))
         (mt res-bad ((ok _) false) ((err msg) (string-contains? msg "not found")))))))

(df test-daemon-evaluation [] -> Bool
  :d "Verifies command dispatch and validation."
  (let [(cfg (d/make-daemon-config 300 30 "/app"))
        (cmd-write (d/make-daemon-command "write" "/app/solve.py" "print(42)" 0 0 "" 0))
        (cmd-bad (d/make-daemon-command "unknown-action" "" "" 0 0 "" 0))
        (cmd-settle (d/make-daemon-command "settle" "" "" 0 0 "" 0))
        (res-w (d/evaluate-daemon-command cfg cmd-write))
        (res-b (d/evaluate-daemon-command cfg cmd-bad))
        (res-s (d/evaluate-daemon-command cfg cmd-settle))]
    (and (.-success res-w)
         (and (not (.-success res-b))
              (and (.-success res-s)
                   (string-contains? (.-output res-s) ":task-finished-success"))))))

(df test-format-result [] -> Bool
  :d "Verifies serialization of DaemonResult into ASN S-expression."
  (let [(res-ok (d/make-daemon-result true 0 "payload" ""))
        (res-err (d/make-daemon-result false 1 "" "some error"))
        (asn-ok (d/format-daemon-result res-ok))
        (asn-err (d/format-daemon-result res-err))]
    (and (string-contains? asn-ok ":status :ok")
         (string-contains? asn-err ":status :error"))))

(df run-tests [] -> Bool
  :d "Runs all in-container daemon unit tests."
  (and (test-make-daemon-config)
       (and (test-bounded-read)
            (and (test-apply-replacement)
                 (and (test-daemon-evaluation)
                      (test-format-result))))))
