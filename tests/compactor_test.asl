(module asl-harness/compactor-test-proxy
  :d "Unit tests for compactor watermark thresholds and history compaction."
  :x [test-watermark-compaction run-tests]
  :i [(compactor :a comp)])

(df test-watermark-compaction [] -> Bool
  :d "Verifies deterministic watermark compaction with assertions."
  (let [(hist (list "turn 1" "turn 2" "turn 3" "turn 4" "ast-patch: file.asl" "exec-cmd: gate pass"))
        (under (comp/compact-at-watermark hist 40 100))
        (soft (comp/compact-at-watermark hist 70 100))
        (hard (comp/compact-at-watermark hist 90 100))]
    (assert (= (list-length under) 6) "under watermark unchanged")
    (assert (string-contains? (option-or (list-last soft) "") "exec-cmd verified gate") "soft watermark compacted")
    (assert (string-contains? (option-or (list-last hard) "") "exec-cmd verified gate") "hard watermark compacted")
    true))

(df run-tests [] -> Bool
  :d "Runs watermark compaction test."
  (test-watermark-compaction))
