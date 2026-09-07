(module asl-harness/checkpoint
  :d "Task checkpoint and safe state serialization."
  :x [CheckpointRecord
      create-checkpoint is-checkpoint-valid?]
  :i [])

(dfs CheckpointRecord
  (:f id Str "Unique checkpoint identifier")
  (:f snapshot Str "Serialized checkpoint payload string")
  (:f valid Bool "Integrity validity flag"))

(df create-checkpoint [(id Str) (data Str)] -> CheckpointRecord
  :d "Creates a valid checkpoint record containing serialized state."
  (CheckpointRecord
    :id id
    :snapshot data
    :valid (not (string-empty? data))))

(df is-checkpoint-valid? [(cp CheckpointRecord)] -> Bool
  :d "Validates checkpoint record integrity."
  (and (.-valid cp)
       (not (string-empty? (.-id cp)))))
