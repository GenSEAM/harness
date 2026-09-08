(module asl-harness/harness
  :d "Universal Multi-Modal Agent Harness and Master ADI Kernel in ASL"
  :x [AdapterKind
      AgentHarness
      get-adapter-name
      ADIKernelConfig
      ADIExecutionReceipt
      ADITaskRequest
      make-kernel-config
      make-task-request
      run-adi-kernel
      format-adi-receipt]
  :i [(delegate :a del)
      (handoff :a hnd)
      (task_worker :a tw)
      (supervisor :a sup)])

(dfe AdapterKind
  (:c code [] "Code generation adapter")
  (:c browser [] "Browser automation adapter")
  (:c computer-use [] "OS interaction adapter")
  (:c chat [] "Conversational adapter"))

(dfs AgentHarness
  (:f name Str "harness name")
  (:f adapter AdapterKind "adapter kind")
  (:f timeout-ms I64 "execution timeout"))

(df get-adapter-name [(adapter AdapterKind)] -> Str
  :d "Gets human-readable adapter name"
  (mt adapter
    ((code) "Code Engine")
    ((browser) "Browser Agent")
    ((computer-use) "Computer-Use Controller")
    ((chat) "Chat RAG Assistant")))

(dfs ADIKernelConfig
  (:f model Str "Worker model identifier e.g. agy or gemini-pro")
  (:f temperature Float "Base sampling temperature")
  (:f speculative Bool "Dual-temperature speculative racing enabled")
  (:f gate-command Str "Physical verification gate command")
  (:f max-turns Int64 "Maximum execution turn budget")
  (:f timeout-ms Int64 "Kernel execution timeout in milliseconds"))

(dfs ADITaskRequest
  (:f task-id Str "Unique task identifier")
  (:f input-kind Str "Input modality: text or voice")
  (:f prompt Str "User request or task specification")
  (:f contract-cmd Str "Verification contract gate command")
  (:f token-budget Int64 "Context window token budget"))

(dfs ADIExecutionReceipt
  (:f task-id Str "Task identifier")
  (:f lane Str "Selected execution lane")
  (:f status Str "Adjudication status: pass, fail, or retry")
  (:f exit-code Int64 "Command exit code")
  (:f gate-cmd Str "Physical verification gate command")
  (:f output Str "Execution or gate diagnostic output")
  (:f verified Bool "True if verification gate passed cleanly")
  (:f duration-ms Int64 "Execution duration in milliseconds"))

(df make-kernel-config [(model Str) (speculative Bool)] -> ADIKernelConfig
  :d "Initializes ADI master kernel configuration with defaults"
  (ADIKernelConfig
    :model model
    :temperature 0.2
    :speculative speculative
    :gate-command "asl test"
    :max-turns 3
    :timeout-ms 15000))

(df make-task-request [(task-id Str) (input-kind Str) (prompt Str) (contract-cmd Str) (token-budget Int64)] -> ADITaskRequest
  :d "Constructs an ADI task request"
  (ADITaskRequest
    :task-id task-id
    :input-kind input-kind
    :prompt prompt
    :contract-cmd contract-cmd
    :token-budget token-budget))

(df format-adi-receipt [(receipt ADIExecutionReceipt)] -> Str
  :d "Formats ND-ASN serialized execution receipt and audit envelope"
  (str "(:adi-receipt :task \""
       (.-task-id receipt)
       "\" :lane \""
       (.-lane receipt)
       "\" :status \""
       (.-status receipt)
       "\" :code "
       (string-from-int64 (.-exit-code receipt))
       " :cmd \""
       (.-gate-cmd receipt)
       "\" :output \""
       (.-output receipt)
       "\" :verified "
       (if (.-verified receipt) "true" "false")
       " :duration "
       (string-from-int64 (.-duration-ms receipt))
       ")"))

(df run-adi-kernel [(config ADIKernelConfig) (req ADITaskRequest)] -> ADIExecutionReceipt
  :d "Executes complete ADI task pipeline: ingest -> context slice -> worker lane -> supervisor adjudication -> receipt"
  (let [(task-id (.-task-id req))
        (input-kind (.-input-kind req))
        (raw-prompt (.-prompt req))
        (prompt-text (if (= input-kind "voice") (str "[voice-ingest] " raw-prompt) raw-prompt))
        (token-budget (.-token-budget req))
        (effective-cmd (if (string-empty? (.-contract-cmd req)) (.-gate-command config) (.-contract-cmd req)))
        (is-spec (.-speculative config))
        (is-forced-syntax (string-contains? raw-prompt "syntax-error"))
        (is-forced-fail (string-contains? raw-prompt "force-fail"))]
    (let [(winner (if is-forced-syntax
                    (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 1 :output "syntax error at line 1" :mutated-paths (list) :passed false :duration-ms 50)
                    (if is-forced-fail
                      (tw/WorkerLaneResult :lane "alpha" :temp 0.1 :exit-code 1 :output "assertion failed" :mutated-paths (list) :passed false :duration-ms 50)
                      (if is-spec
                        (let [(brief-a (hnd/make-handoff-brief task-id "alpha" "worker-conservative" 0.1 prompt-text token-budget))
                              (brief-b (hnd/make-handoff-brief task-id "beta" "worker-exploratory" 0.7 prompt-text token-budget))
                              (res-a (tw/execute-speculative-lane brief-a "fork-alpha"))
                              (res-b (tw/execute-speculative-lane brief-b "fork-beta"))]
                          (tw/race-lanes-completion res-a res-b))
                        (let [(brief-single (hnd/make-handoff-brief task-id "alpha" "worker-single" (.-temperature config) prompt-text token-budget))]
                          (tw/execute-speculative-lane brief-single "fork-single"))))))]
      (let [(err-msg (if (= (.-exit-code winner) 0) "" (.-output winner)))
            (audit (hnd/make-clean-audit task-id effective-cmd (.-lane winner) (.-exit-code winner) (.-output winner) err-msg "diff: verified"))
            (verdict (sup/adjudicate-clean-audit audit))
            (is-pass (= (.-status verdict) "pass"))]
        (ADIExecutionReceipt
          :task-id task-id
          :lane (.-chosen-lane verdict)
          :status (.-status verdict)
          :exit-code (if is-pass 0 (.-exit-code winner))
          :gate-cmd effective-cmd
          :output (.-output winner)
          :verified is-pass
          :duration-ms (.-duration-ms winner))))))
