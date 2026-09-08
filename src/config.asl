(module asl-harness/config
  :d "Configurable constructor, model profiles, hierarchical config cascading, and pluggable extension registry for ASL Harness."
  :x [ModelProfile PluginHook HarnessPlugin HarnessConfig HookPredicate CoverageConfig
      AsnValue AsnField
      asn-nil asn-bool asn-unit asn-int asn-float asn-str asn-kw asn-sym
      asn-vec asn-map asn-rec asn-ctor asn-rows asn-table asn-case asn-pair
      WorkspaceScope RepoKind WorktreeInfo StorageConfig WorkspaceContext
      profile-gemma-31b profile-qwen-05b profile-default default-harness-config
      benchmark-harness-config production-harness-config
      default-coverage-config coverage-config-to-asn-node coverage-config-from-asn-node
      toggle-feature feature-enabled? register-plugin
      enable-experimental experimental-enabled? make-plugin
      detect-repo-kind parse-gitdir-file extract-worktree-id detect-worktree
      default-storage-config route-storage-target resolve-cascaded-config
      model-profile-from-asn-node model-profile-to-asn-node
      storage-config-from-asn-node storage-config-to-asn-node
      harness-config-from-asn-tree evaluate-hook-predicate]
  :i [])

(dfs ModelProfile
  (:f name Str "Model profile identifier e.g. gemma-4-31b-it")
  (:f family Str "Model architecture family e.g. gemma, claude, deepseek, qwen")
  (:f strict-firewall Bool "Enable strict action boundary and lease firewall")
  (:f strict-normalizer Bool "Enable single-pass FSM syntax and delimiter normalizer")
  (:f in-memory-repl Bool "Enable sub-millisecond in-memory REPL inspector")
  (:f max-tokens I64 "Default context token ceiling"))

(dfe PluginHook
  (:c hook-pre-call [] "Hook executed before tool call dispatch")
  (:c hook-post-call [] "Hook executed after tool call completion")
  (:c hook-model-response [] "Hook executed on raw model output stream")
  (:c hook-error [] "Hook executed on execution boundary failure"))

(dfs HookPredicate
  (:f hook-type PluginHook "Target execution lifecycle hook")
  (:f name Str "Identifier for the predicate condition")
  (:f target-pattern Str "Regex/substring match pattern for tool/file")
  (:f action-override Str "Action to apply when matched e.g. allow, deny, audit"))

(dfs AsnField
  (:f key Str "Field key, including its leading colon")
  (:f val AsnValue "Field value"))

(dfe AsnValue
  (:c asn-nil   []                "The nil sentinel `_`")
  (:c asn-bool  [(b Bool)]        "true or false")
  (:c asn-unit  []                "The unit literal `()`")
  (:c asn-int   [(lex Str)]       "Integer literal, held as its source lexeme")
  (:c asn-float [(lex Str)]       "Float literal, held as its source lexeme")
  (:c asn-str   [(lex Str)]       "String literal, held as its source lexeme with quotes")
  (:c asn-kw    [(k Str)]         "Keyword scalar, including its leading colon")
  (:c asn-sym   [(name Str)]      "A bare name. Legal as a head, never as a value")
  (:c asn-vec   [(items (List AsnValue))] "A bracketed vector")
  (:c asn-map   [(entries (List AsnField))] "A brace map")
  (:c asn-rec   [(fields (List AsnField))] "An anonymous record `(:k v ...)`")
  (:c asn-ctor  [(name Str) (fields (List AsnField))] "Named construction `(Name :k v ...)`")
  (:c asn-rows  [(name Str) (rows (List AsnValue))] "Schema-grouped rows `(Name [..] ..)`")
  (:c asn-table [(cols (List AsnValue)) (rows (List AsnValue))] "Ad-hoc table `([:c ..] [[..]])`")
  (:c asn-case  [(name Str) (args (List AsnValue))] "Union case value `(name v ..)`")
  (:c asn-pair  [(key AsnValue) (val AsnValue)] "A parenthesised map entry, legal only in a map"))

(dfs HarnessPlugin
  (:f id Str "Unique plugin identifier e.g. plugin-sec-audit")
  (:f name Str "Human-readable plugin name")
  (:f version Str "Semantic version string")
  (:f enabled Bool "Activation flag")
  (:f description Str "Functional plugin description"))

(dfs CoverageConfig
  (:f desired-coverage Float "Target test qualification coverage percentage")
  (:f min-assertions-per-test I64 "Minimum assertions per test case")
  (:f discount-zero-asserts Bool "Strictly discount tests without assertions from coverage"))

(dfs HarnessConfig
  (:f profile ModelProfile "Active model optimization profile")
  (:f flags (Map Str Bool) "Granular feature flag toggles")
  (:f plugins (List HarnessPlugin) "Registered extension plugins")
  (:f experimental (List Str) "Active experimental feature identifiers")
  (:f custom-settings (Map Str Str) "Arbitrary string configuration key-values")
  (:f coverage CoverageConfig "Configured test coverage thresholds and metrics"))

(dfe WorkspaceScope
  (:c scope-global [] "Global fallback defaults")
  (:c scope-master [] "Master workspace root (asex)")
  (:c scope-subrepo [] "Sub-repository scope")
  (:c scope-worktree [] "Isolated git worktree local override"))

(dfe RepoKind
  (:c repo-main [] "Standard Git repository root with .git directory")
  (:c repo-worktree [] "Git worktree with .git file pointing to worktrees/")
  (:c repo-submodule [] "Git submodule with .git file pointing to modules/")
  (:c repo-none [] "Directory is not a git repository"))

(dfs WorktreeInfo
  (:f is-worktree Bool "True if active scope is an isolated git worktree")
  (:f git-dir Str "Resolved git directory path")
  (:f common-dir Str "Resolved common repository git directory")
  (:f worktree-id Str "Unique worktree identifier string"))

(dfs StorageConfig
  (:f master-research-root Str "Canonical master research notes root e.g. asex/.research")
  (:f master-scratch-root Str "Canonical master shared scratch root e.g. asex/scratch")
  (:f worktree-scratch-root Str "Canonical per-worktree scratch root e.g. asex/.worktree-scratch")
  (:f local-repo-root Str "Active local repository or worktree root path"))

(dfs WorkspaceContext
  (:f scope WorkspaceScope "Active workspace tier scope")
  (:f repo-kind RepoKind "Detected git repository kind")
  (:f name Str "Human-readable workspace or sub-repo name")
  (:f worktree-id Str "Unique worktree ID if running in worktree; empty otherwise")
  (:f is-worktree Bool "True if active scope is an isolated git worktree")
  (:f parent-repo-root Str "Resolved parent repository root path")
  (:f test-runner Str "Verification test command for active scope")
  (:f pre-execution-gate Bool "Enable pre-execution gate checks")
  (:f storage StorageConfig "Dual-scope storage routing configuration"))

(df profile-gemma-31b [] -> ModelProfile
  :d "Optimal out-of-the-box profile calibrated for Gemma 31B (gemma-4-31b-it)."
  (ModelProfile
    :name "gemma-4-31b-it"
    :family "gemma"
    :strict-firewall true
    :strict-normalizer true
    :in-memory-repl true
    :max-tokens 8192))

(df profile-qwen-05b [] -> ModelProfile
  :d "Ultra-compact model calibration profile for Qwen 2.5 0.5B (qwen2.5:0.5b)."
  (ModelProfile
    :name "qwen-2.5-0.5b"
    :family "qwen"
    :strict-firewall true
    :strict-normalizer true
    :in-memory-repl true
    :max-tokens 2048))

(df profile-default [] -> ModelProfile
  :d "Standard baseline model profile."
  (ModelProfile
    :name "generic-llm"
    :family "generic"
    :strict-firewall true
    :strict-normalizer false
    :in-memory-repl false
    :max-tokens 4096))

(df make-plugin [(id Str) (name Str) (version Str) (enabled Bool) (description Str)] -> HarnessPlugin
  :d "Constructs a new HarnessPlugin definition record."
  (HarnessPlugin
    :id id
    :name name
    :version version
    :enabled enabled
    :description description))

(df default-harness-config [] -> HarnessConfig
  :d "Constructs default harness configuration with optimal out-of-the-box settings for Gemma 31B."
  (let [(prof (profile-gemma-31b))
        (init-flags (map-set (map-set (map-set (map-empty)
                                               "firewall" true)
                                        "fsm-normalizer" true)
                              "repl-in-memory" true))]
    (HarnessConfig
      :profile prof
      :flags init-flags
      :plugins (list)
      :experimental (list)
      :custom-settings (map-empty)
      :coverage (default-coverage-config))))

(df benchmark-harness-config [] -> HarnessConfig
  :d "Constructs hermetic benchmark harness configuration: airgapped, strict falsifiable gates, CTRF tracking, and L7 gateway nexus."
  (let [(prof (profile-gemma-31b))
        (flags-1 (map-set (map-empty) "airgap" true))
        (flags-2 (map-set flags-1 "strict-falsification" true))
        (flags-3 (map-set flags-2 "ctrf-tracking" true))
        (flags-4 (map-set flags-3 "fsm-normalizer" true))
        (flags-5 (map-set flags-4 "firewall" true))
        (sets-1 (map-set (map-empty) "gateway-url" "http://127.0.0.1:8765/v1"))
        (sets-2 (map-set sets-1 "timeout-seconds" "300"))]
    (HarnessConfig
      :profile prof
      :flags flags-5
      :plugins (list)
      :experimental (list "hermetic-sandbox" "scalar-loss")
      :custom-settings sets-2
      :coverage (default-coverage-config))))

(df production-harness-config [] -> HarnessConfig
  :d "Constructs production engineering harness configuration: full 5-stage epistemic loop, git worktrees, self-healing, and L7 gateway nexus."
  (let [(prof (profile-gemma-31b))
        (flags-1 (map-set (map-empty) "airgap" false))
        (flags-2 (map-set flags-1 "epistemic-cycle" true))
        (flags-3 (map-set flags-2 "git-worktrees" true))
        (flags-4 (map-set flags-3 "compiler-feedback" true))
        (flags-5 (map-set flags-4 "repl-in-memory" true))
        (sets-1 (map-set (map-empty) "gateway-url" "http://127.0.0.1:8765/v1"))
        (sets-2 (map-set sets-1 "epistemic-pipeline" "scout->plan->gap-audit->implement->reconcile"))]
    (HarnessConfig
      :profile prof
      :flags flags-5
      :plugins (list)
      :experimental (list "ast-patch" "worktree-isolation")
      :custom-settings sets-2
      :coverage (default-coverage-config))))

(df toggle-feature [(cfg HarnessConfig) (feature-name Str) (enable Bool)] -> HarnessConfig
  :d "Toggles a specific feature flag on or off in the harness configuration."
  (let [(updated-flags (map-set (.-flags cfg) feature-name enable))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags updated-flags
      :plugins (.-plugins cfg)
      :experimental (.-experimental cfg)
      :custom-settings (.-custom-settings cfg)
      :coverage (.-coverage cfg))))

(df feature-enabled? [(cfg HarnessConfig) (feature-name Str)] -> Bool
  :d "Checks if a specific feature flag is actively enabled."
  (let [(val (map-get (.-flags cfg) feature-name))]
    (option-or val false)))

(df register-plugin [(cfg HarnessConfig) (plugin HarnessPlugin)] -> HarnessConfig
  :d "Registers a user-defined or third-party plugin into the harness pipeline."
  (let [(updated-plugins (list-cons plugin (.-plugins cfg)))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags (.-flags cfg)
      :plugins updated-plugins
      :experimental (.-experimental cfg)
      :custom-settings (.-custom-settings cfg)
      :coverage (.-coverage cfg))))

(df enable-experimental [(cfg HarnessConfig) (flag Str)] -> HarnessConfig
  :d "Enables an experimental opt-in feature flag."
  (let [(existing (.-experimental cfg))
        (updated (list-cons flag existing))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags (.-flags cfg)
      :plugins (.-plugins cfg)
      :experimental updated
      :custom-settings (.-custom-settings cfg)
      :coverage (.-coverage cfg))))

(df experimental-enabled? [(cfg HarnessConfig) (flag Str)] -> Bool
  :d "Checks whether an experimental feature flag is active."
  (let [(active (filter (fn [(f Str)] -> Bool (= f flag)) (.-experimental cfg)))]
    (not (list-empty? active))))

(df detect-repo-kind [(git-path-type Str) (git-content Str)] -> RepoKind
  :d "Detects whether repository is main git repo, worktree, submodule, or non-git."
  (cond
    ((= git-path-type "dir") (repo-main))
    ((= git-path-type "file")
     (let [(clean (string-trim git-content))]
       (cond
         ((string-contains? clean "/worktrees/") (repo-worktree))
         ((string-contains? clean "/modules/") (repo-submodule))
         ((string-starts-with? clean "gitdir:") (repo-worktree))
         (:else (repo-none)))))
    (:else (repo-none))))

(df parse-gitdir-file [(dot-git-content Str) (workspace-path Str)] -> (Option Str)
  :d "Extracts and canonicalizes gitdir path from .git file, resolving relative paths."
  (let [(trimmed (string-trim dot-git-content))]
    (if (string-starts-with? trimmed "gitdir:")
        (let [(raw-path (string-trim (option-or (string-slice trimmed 7 (string-length trimmed)) "")))]
          (if (string-starts-with? raw-path "/")
              (some raw-path)
              (some (str workspace-path "/" raw-path))))
        (none))))

(df extract-worktree-id [(normalized-gitdir Str)] -> Str
  :d "Extracts unique worktree identifier from canonical gitdir path."
  (let [(segments (string-split normalized-gitdir "/"))]
    (if (list-empty? segments)
        "default"
        (fold (fn [(acc Str) (seg Str)] -> Str
                (if (string-empty? seg) acc seg))
              "default"
              segments))))

(df detect-worktree [(git-path-type Str) (git-content Str) (workspace-path Str)] -> WorktreeInfo
  :d "Detects git worktree status and resolves gitdir and worktree ID."
  (let [(kind (detect-repo-kind git-path-type git-content))]
    (mt kind
      ((repo-worktree)
       (let [(parsed (parse-gitdir-file git-content workspace-path))
             (gdir (option-or parsed (str workspace-path "/.git")))
             (wt-id (extract-worktree-id gdir))]
         (WorktreeInfo
           :is-worktree true
           :git-dir gdir
           :common-dir (str gdir "/../../..")
           :worktree-id wt-id)))
      ((_)
       (WorktreeInfo
         :is-worktree false
         :git-dir (str workspace-path "/.git")
         :common-dir (str workspace-path "/.git")
         :worktree-id "")))))

(df default-storage-config [(workspace-root Str)] -> StorageConfig
  :d "Constructs dual-scope storage paths grounded in master workspace root."
  (StorageConfig
    :master-research-root (str workspace-root "/.research")
    :master-scratch-root (str workspace-root "/scratch")
    :worktree-scratch-root (str workspace-root "/.worktree-scratch")
    :local-repo-root workspace-root))

(df route-storage-target [(scope-type Str) (relative-filename Str) (storage StorageConfig)] -> Str
  :d "Resolves canonical absolute path for storage: :research -> master/.research, :scratch -> master/scratch, :worktree-scratch -> master/.worktree-scratch."
  (let [(clean-file (if (string-starts-with? relative-filename "/")
                        (string-slice relative-filename 1 (string-length relative-filename))
                        relative-filename))]
    (cond
      ((or (= scope-type ":research") (= scope-type "research"))
       (str (.-master-research-root storage) "/" clean-file))
      ((or (= scope-type ":worktree-scratch") (= scope-type "worktree-scratch"))
       (str (.-worktree-scratch-root storage) "/" clean-file))
      (:else
       (str (.-master-scratch-root storage) "/" clean-file)))))

(df find-field-val [(fields (List AsnField)) (target-key Str)] -> (Option AsnValue)
  :d "Finds value of field matching target keyword in field list."
  (fold (fn [(acc (Option AsnValue)) (f AsnField)] -> (Option AsnValue)
          (mt acc
            ((some _) acc)
            ((none) (if (= (.-key f) target-key) (some (.-val f)) (none)))))
        (none)
        fields))

(df strip-quotes [(s Str)] -> Str
  :d "Strips quotes from string literal if present."
  (let [(len (string-length s))]
    (if (and (>= len 2) (and (string-starts-with? s "\"") (string-ends-with? s "\"")))
        (option-or (string-slice s 1 (- len 1)) "")
        s)))

(df asn-extract-str [(v AsnValue) (default-val Str)] -> Str
  :d "Extracts string content from ASN value."
  (mt v
    ((asn-str s) (strip-quotes s))
    ((asn-sym s) s)
    ((asn-kw k) (if (string-starts-with? k ":") (option-or (string-slice k 1 (string-length k)) "") k))
    (_ default-val)))

(df asn-extract-bool [(v AsnValue) (default-val Bool)] -> Bool
  :d "Extracts boolean from ASN value."
  (mt v
    ((asn-bool b) b)
    (_ default-val)))

(df asn-extract-int [(v AsnValue) (default-val I64)] -> I64
  :d "Extracts integer from ASN value."
  (mt v
    ((asn-int s) (option-or (string-to-int64 s) default-val))
    (_ default-val)))

(df asn-extract-float [(v AsnValue) (default-val Float)] -> Float
  :d "Extracts float from ASN value."
  (mt v
    ((asn-float s) (option-or (string-to-float64 s) default-val))
    ((asn-int s) (int64-to-float64 (option-or (string-to-int64 s) (option-unwrap (float64-to-int64 default-val)))))
    (_ default-val)))

(df default-coverage-config [] -> CoverageConfig
  :d "Constructs default coverage configuration with 80% target and dual-case (pos+neg) threshold."
  (CoverageConfig
    :desired-coverage 80.0
    :min-assertions-per-test 2
    :discount-zero-asserts true))

(df coverage-config-to-asn-node [(cfg CoverageConfig)] -> AsnValue
  :d "Serializes CoverageConfig struct into canonical ASN constructor AST node."
  (asn-ctor "CoverageConfig"
    (list (AsnField :key ":desired" :val (asn-float (string-from-float64 (.-desired-coverage cfg))))
          (AsnField :key ":min-assertions" :val (asn-int (string-from-int64 (.-min-assertions-per-test cfg))))
          (AsnField :key ":discount-zero-asserts" :val (asn-bool (.-discount-zero-asserts cfg))))))

(df coverage-config-from-asn-node [(node AsnValue)] -> (Option CoverageConfig)
  :d "Directly instantiates typed CoverageConfig struct from ASN AST node."
  (let [(fields-opt (mt node
                      ((asn-ctor _ fs) (some fs))
                      ((asn-rec fs) (some fs))
                      (_ (none))))]
    (mt fields-opt
      ((none) (none))
      ((some fields)
       (let [(opt-des (find-field-val fields ":desired"))
             (opt-min (find-field-val fields ":min-assertions"))
             (opt-disc (find-field-val fields ":discount-zero-asserts"))
             (des-val (mt opt-des
                        ((some v) (asn-extract-float v 80.0))
                        ((none) 80.0)))
             (min-val (mt opt-min
                        ((some v) (asn-extract-int v 2))
                        ((none) 2)))
             (disc-val (mt opt-disc
                         ((some v) (asn-extract-bool v true))
                         ((none) true)))]
         (some (CoverageConfig
                 :desired-coverage des-val
                 :min-assertions-per-test min-val
                 :discount-zero-asserts disc-val)))))))

(df model-profile-to-asn-node [(prof ModelProfile)] -> AsnValue
  :d "Serializes ModelProfile struct into canonical ASN constructor AST node."
  (asn-ctor "ModelProfile"
    (list (AsnField :key ":name" :val (asn-str (str "\"" (.-name prof) "\"")))
          (AsnField :key ":family" :val (asn-str (str "\"" (.-family prof) "\"")))
          (AsnField :key ":strict-firewall" :val (asn-bool (.-strict-firewall prof)))
          (AsnField :key ":strict-normalizer" :val (asn-bool (.-strict-normalizer prof)))
          (AsnField :key ":in-memory-repl" :val (asn-bool (.-in-memory-repl prof)))
          (AsnField :key ":max-tokens" :val (asn-int (string-from-int64 (.-max-tokens prof)))))))

(df model-profile-from-asn-node [(node AsnValue)] -> (Option ModelProfile)
  :d "Directly instantiates typed ModelProfile struct from ASN AST node without DTO mapping."
  (let [(fields-opt (mt node
                      ((asn-ctor _ fs) (some fs))
                      ((asn-rec fs) (some fs))
                      (_ (none))))]
    (mt fields-opt
      ((none) (none))
      ((some fields)
       (let [(opt-name (find-field-val fields ":name"))
             (opt-family (find-field-val fields ":family"))
             (opt-firewall (find-field-val fields ":strict-firewall"))
             (opt-normalizer (find-field-val fields ":strict-normalizer"))
             (opt-repl (find-field-val fields ":in-memory-repl"))
             (opt-tokens (find-field-val fields ":max-tokens"))]
         (if (or (option-is-none? opt-name) (option-is-none? opt-family))
             (none)
             (some (ModelProfile
                     :name (asn-extract-str (option-unwrap opt-name) "generic-llm")
                     :family (asn-extract-str (option-unwrap opt-family) "generic")
                     :strict-firewall (if (option-is-some? opt-firewall) (asn-extract-bool (option-unwrap opt-firewall) true) true)
                     :strict-normalizer (if (option-is-some? opt-normalizer) (asn-extract-bool (option-unwrap opt-normalizer) false) false)
                     :in-memory-repl (if (option-is-some? opt-repl) (asn-extract-bool (option-unwrap opt-repl) false) false)
                     :max-tokens (if (option-is-some? opt-tokens) (asn-extract-int (option-unwrap opt-tokens) 4096) 4096)))))))))

(df storage-config-to-asn-node [(cfg StorageConfig)] -> AsnValue
  :d "Serializes StorageConfig struct into canonical ASN constructor AST node."
  (asn-ctor "StorageConfig"
    (list (AsnField :key ":master-research-root" :val (asn-str (str "\"" (.-master-research-root cfg) "\"")))
          (AsnField :key ":master-scratch-root" :val (asn-str (str "\"" (.-master-scratch-root cfg) "\"")))
          (AsnField :key ":worktree-scratch-root" :val (asn-str (str "\"" (.-worktree-scratch-root cfg) "\"")))
          (AsnField :key ":local-repo-root" :val (asn-str (str "\"" (.-local-repo-root cfg) "\""))))))

(df storage-config-from-asn-node [(node AsnValue)] -> (Option StorageConfig)
  :d "Directly instantiates typed StorageConfig struct from ASN AST node without DTO mapping."
  (let [(fields-opt (mt node
                      ((asn-ctor _ fs) (some fs))
                      ((asn-rec fs) (some fs))
                      (_ (none))))]
    (mt fields-opt
      ((none) (none))
      ((some fields)
       (let [(opt-res (find-field-val fields ":master-research-root"))
             (opt-scratch (find-field-val fields ":master-scratch-root"))
             (opt-wt (find-field-val fields ":worktree-scratch-root"))
             (opt-local (find-field-val fields ":local-repo-root"))]
         (if (and (option-is-some? opt-res) (option-is-some? opt-scratch))
             (some (StorageConfig
                     :master-research-root (asn-extract-str (option-unwrap opt-res) "")
                     :master-scratch-root (asn-extract-str (option-unwrap opt-scratch) "")
                     :worktree-scratch-root (if (option-is-some? opt-wt) (asn-extract-str (option-unwrap opt-wt) "") "")
                     :local-repo-root (if (option-is-some? opt-local) (asn-extract-str (option-unwrap opt-local) "") "")))
             (none)))))))

(df harness-config-from-asn-tree [(root AsnValue)] -> (Option HarnessConfig)
  :d "Instantiates typed HarnessConfig directly from ASN configuration tree."
  (let [(fields-opt (mt root
                      ((asn-ctor _ fs) (some fs))
                      ((asn-rec fs) (some fs))
                      (_ (none))))]
    (mt fields-opt
      ((none) (none))
      ((some fields)
       (let [(base (default-harness-config))
             (prof-node (find-field-val fields ":profile"))
             (prof (mt prof-node
                     ((some pn) (option-or (model-profile-from-asn-node pn) (.-profile base)))
                     ((none) (.-profile base))))
             (fw-node (find-field-val fields ":firewall"))
             (norm-node (find-field-val fields ":fsm-normalizer"))
             (repl-node (find-field-val fields ":repl-in-memory"))
             (c1 (mt fw-node
                   ((some fn) (toggle-feature base "firewall" (asn-extract-bool fn true)))
                   ((none) base)))
             (c2 (mt norm-node
                   ((some nn) (toggle-feature c1 "fsm-normalizer" (asn-extract-bool nn true)))
                   ((none) c1)))
             (c3 (mt repl-node
                   ((some rn) (toggle-feature c2 "repl-in-memory" (asn-extract-bool rn true)))
                   ((none) c2)))
             (cov-node (find-field-val fields ":coverage"))
             (cov-cfg (mt cov-node
                        ((some cn) (option-or (coverage-config-from-asn-node cn) (.-coverage base)))
                        ((none) (.-coverage base))))]
         (some (HarnessConfig
                 :profile prof
                 :flags (.-flags c3)
                 :plugins (.-plugins base)
                 :experimental (.-experimental base)
                 :custom-settings (.-custom-settings base)
                 :coverage cov-cfg)))))))

(df evaluate-hook-predicate [(pred HookPredicate) (target-name Str) (context-tag Str)] -> Bool
  :d "Evaluates whether a hook predicate matches the target tool/file and execution context."
  (let [(pat (.-target-pattern pred))
        (target-match (or (string-empty? pat)
                          (or (= pat "*")
                              (or (= pat target-name)
                                  (string-contains? target-name pat)))))
        (ctx-match (or (string-empty? context-tag)
                       (or (= context-tag "*")
                           (or (string-contains? (.-name pred) context-tag)
                               (string-contains? (.-action-override pred) context-tag)))))]
    (and target-match ctx-match)))

(df apply-config-tier [(cfg HarnessConfig) (raw-input Str)] -> HarnessConfig
  :d "Applies single tier configuration overrides safely handling empty strings and AST nodes."
  (let [(clean (string-trim raw-input))]
    (if (string-empty? clean)
        cfg
        (let [(c1 (if (or (string-contains? clean "fsm-normalizer: false")
                          (string-contains? clean ":fsm-normalizer false"))
                      (toggle-feature cfg "fsm-normalizer" false)
                      (if (or (string-contains? clean "fsm-normalizer: true")
                              (string-contains? clean ":fsm-normalizer true"))
                          (toggle-feature cfg "fsm-normalizer" true)
                          cfg)))
              (c2 (if (or (string-contains? clean "firewall: false")
                          (string-contains? clean ":firewall false"))
                      (toggle-feature c1 "firewall" false)
                      (if (or (string-contains? clean "firewall: true")
                              (string-contains? clean ":firewall true"))
                          (toggle-feature c1 "firewall" true)
                          c1)))
              (c3 (if (or (string-contains? clean "repl-in-memory: false")
                          (string-contains? clean ":repl-in-memory false"))
                      (toggle-feature c2 "repl-in-memory" false)
                      (if (or (string-contains? clean "repl-in-memory: true")
                              (string-contains? clean ":repl-in-memory true"))
                          (toggle-feature c2 "repl-in-memory" true)
                          c2)))]
          c3))))

(df resolve-cascaded-config [(global-cfg HarnessConfig) (workspace-raw Str) (subrepo-raw Str) (worktree-raw Str)] -> HarnessConfig
  :d "Cascades configuration across 4 tiers with monotonic feature flag inheritance."
  (let [(c1 (apply-config-tier global-cfg workspace-raw))
        (c2 (apply-config-tier c1 subrepo-raw))
        (c3 (apply-config-tier c2 worktree-raw))]
    c3))
