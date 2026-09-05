(module asl-harness/config
  :d "Configurable constructor, model profiles, hierarchical config cascading, and pluggable extension registry for ASL Harness."
  :x [ModelProfile PluginHook HarnessPlugin HarnessConfig
      WorkspaceScope RepoKind WorktreeInfo StorageConfig WorkspaceContext
      profile-gemma-31b profile-qwen-05b profile-default default-harness-config
      toggle-feature feature-enabled? register-plugin
      enable-experimental experimental-enabled? make-plugin
      detect-repo-kind parse-gitdir-file extract-worktree-id detect-worktree
      default-storage-config route-storage-target resolve-cascaded-config]
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

(dfs HarnessPlugin
  (:f id Str "Unique plugin identifier e.g. plugin-sec-audit")
  (:f name Str "Human-readable plugin name")
  (:f version Str "Semantic version string")
  (:f enabled Bool "Activation flag")
  (:f description Str "Functional plugin description"))

(dfs HarnessConfig
  (:f profile ModelProfile "Active model optimization profile")
  (:f flags (Map Str Bool) "Granular feature flag toggles")
  (:f plugins (List HarnessPlugin) "Registered extension plugins")
  (:f experimental (List Str) "Active experimental feature identifiers")
  (:f custom-settings (Map Str Str) "Arbitrary string configuration key-values"))

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
      :custom-settings (map-empty))))

(df toggle-feature [(cfg HarnessConfig) (feature-name Str) (enable Bool)] -> HarnessConfig
  :d "Toggles a specific feature flag on or off in the harness configuration."
  (let [(updated-flags (map-set (.-flags cfg) feature-name enable))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags updated-flags
      :plugins (.-plugins cfg)
      :experimental (.-experimental cfg)
      :custom-settings (.-custom-settings cfg))))

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
      :custom-settings (.-custom-settings cfg))))

(df enable-experimental [(cfg HarnessConfig) (flag Str)] -> HarnessConfig
  :d "Enables an experimental opt-in feature flag."
  (let [(existing (.-experimental cfg))
        (updated (list-cons flag existing))]
    (HarnessConfig
      :profile (.-profile cfg)
      :flags (.-flags cfg)
      :plugins (.-plugins cfg)
      :experimental updated
      :custom-settings (.-custom-settings cfg))))

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
        (let [(raw-path (string-trim (string-slice trimmed 7 (string-length trimmed))))]
          (if (string-starts-with? raw-path "/")
              (some raw-path)
              (some (str workspace-path "/" raw-path))))
        (none))))

(df extract-worktree-id [(normalized-gitdir Str)] -> Str
  :d "Extracts unique worktree identifier from canonical gitdir path."
  (let [(segments (string-split "/" normalized-gitdir))]
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

(df resolve-cascaded-config [(global-cfg HarnessConfig) (workspace-raw Str) (subrepo-raw Str) (worktree-raw Str)] -> HarnessConfig
  :d "Cascades configuration across 4 tiers with monotonic feature flag inheritance."
  (let [(c1 (if (string-contains? workspace-raw "fsm-normalizer: false")
                (toggle-feature global-cfg "fsm-normalizer" false)
                global-cfg))
        (c2 (if (string-contains? subrepo-raw "firewall: false")
                (toggle-feature c1 "firewall" false)
                c1))
        (c3 (if (string-contains? worktree-raw "repl-in-memory: false")
                (toggle-feature c2 "repl-in-memory" false)
                c2))]
    c3))
