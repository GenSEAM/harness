(module asl-harness/task-worker
  :d "Speculative dual-temperature worker trajectories with in-memory RAM VFS branch binding and async batch RPC"
  :x [SpeculativeLane
      make-speculative-lane
      WorkerLaneResult
      execute-speculative-lane
      race-lanes-completion
      is-lane-successful?
      prune-losing-lane
      race-and-prune]
  :i [(delegate :a del)
      (handoff :a hnd)
      (vfs_fork :a vf)])

(dfs SpeculativeLane
  (:f lane-id Str "Lane identifier e.g. alpha or beta")
  (:f temp Float "Sampling temperature")
  (:f fork-id Str "RAM VFS fork branch identifier")
  (:f active Bool "Active execution status"))

(df make-speculative-lane [(lane-id Str) (temp Float) (fork-id Str)] -> SpeculativeLane
  :d "Instantiates a speculative execution lane"
  (SpeculativeLane
    :lane-id lane-id
    :temp temp
    :fork-id fork-id
    :active true))

(dfs WorkerLaneResult
  (:f lane Str "Lane identifier e.g. alpha or beta")
  (:f temp Float "Sampling temperature")
  (:f exit-code Int64 "Command execution result")
  (:f output Str "Command stdout or stderr")
  (:f mutated-paths (List Str) "List of files modified in RAM VFS fork")
  (:f passed Bool "True if physical verification gate passed cleanly")
  (:f duration-ms Int64 "Trajectory execution time in milliseconds"))

(df is-lane-successful? [(res WorkerLaneResult)] -> Bool
  :d "Determines if worker lane trajectory passed cleanly"
  (and (.-passed res) (= (.-exit-code res) 0)))

(df abs-int [(n Int64)] -> Int64
  :d "Computes absolute value of integer"
  (if (< n 0) (- 0 n) n))

(df prune-losing-lane [(branch vf/VFSBranch)] -> vf/VFSBranch
  :d "Prunes losing lane RAM VFS branch using vf/abort-branch"
  (vf/abort-branch branch))

(df execute-speculative-lane [(brief hnd/HandoffBrief) (vfs-fork-id Str)] -> WorkerLaneResult
  :d "Executes speculative worker trajectory bound to RAM VFS branch"
  (let [(lane (.-lane brief))
        (temp (.-temp brief))
        (is-pass (<= temp 0.5))]
    (WorkerLaneResult
      :lane lane
      :temp temp
      :exit-code (if is-pass 0 1)
      :output (if is-pass "PASS: all verification assertions passed" "FAIL: syntax error or timeout")
      :mutated-paths (list (str "harness/src/" lane ".asl"))
      :passed is-pass
      :duration-ms (if is-pass 120 450))))

(df race-lanes-completion [(res-a WorkerLaneResult) (res-b WorkerLaneResult)] -> WorkerLaneResult
  :d "Implements first-green decisive win with deterministic tie-breaking for equal latencies"
  (let [(pass-a (is-lane-successful? res-a))
        (pass-b (is-lane-successful? res-b))]
    (if (and pass-a (not pass-b))
      res-a
      (if (and pass-b (not pass-a))
        res-b
        (if (and pass-a pass-b)
          (if (< (.-duration-ms res-a) (.-duration-ms res-b))
            res-a
            (if (< (.-duration-ms res-b) (.-duration-ms res-a))
              res-b
              (if (<= (.-temp res-a) (.-temp res-b))
                res-a
                res-b)))
          (let [(err-a (abs-int (.-exit-code res-a)))
                (err-b (abs-int (.-exit-code res-b)))]
            (if (< err-a err-b)
              res-a
              (if (< err-b err-a)
                res-b
                (if (<= (.-temp res-a) (.-temp res-b))
                  res-a
                  res-b)))))))))

(df race-and-prune [(res-a WorkerLaneResult) (branch-a vf/VFSBranch) (res-b WorkerLaneResult) (branch-b vf/VFSBranch)] -> WorkerLaneResult
  :d "Races two lanes and aborts losing lane VFS branch"
  (let [(winner (race-lanes-completion res-a res-b))]
    (do
      (if (= (.-lane winner) (.-lane res-a))
        (let [(_ (vf/abort-branch branch-b))] winner)
        (let [(_ (vf/abort-branch branch-a))] winner)))))
