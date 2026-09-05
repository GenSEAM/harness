(module asl-harness/repo-scout
  :d "Autonomous Repository Scouting & Version-Pinned Framework Profile Extractor"
  :x [RepoProfile
      RepoAuditResult
      scout-repo
      format-profile-asn
      audit-code-diff
      make-empty-profile]
  :i [(deps :a d) (core/strings :a s)])

(dfs RepoProfile
  (:f workspace-root Str "Absolute or relative root path of repository")
  (:f ecosystem Str "Detected ecosystem: js-ts, python, rust, or generic")
  (:f primary-framework Str "Detected primary framework or library name")
  (:f framework-version Str "Exact or semver-pinned version string")
  (:f forbidden-apis (List Str) "List of deprecated or hallucinated APIs in this version")
  (:f recommended-apis (List Str) "List of modern idiomatic replacement APIs")
  (:f rules (List Str) "Workspace architecture invariants"))

(dfs RepoAuditResult
  (:f allowed Bool "True if code contains zero forbidden APIs")
  (:f violations (List Str) "Identified forbidden API symbols used")
  (:f remediations (List Str) "Replacement suggestions"))

(df make-empty-profile [] -> RepoProfile
  :d "Constructs an empty fallback repository profile."
  (RepoProfile
    :workspace-root "."
    :ecosystem "generic"
    :primary-framework "unknown"
    :framework-version "0.0.0"
    :forbidden-apis (list)
    :recommended-apis (list)
    :rules (list "pure-asl" "zero-foreign-files")))

(df scout-repo [(root-path Str) (lockfile-name Str) (lockfile-content Str)] -> RepoProfile
  :d "Scouts repository lockfile and extracts version-pinned framework profile."
  (let [(kind (d/detect-lockfile-kind lockfile-name))]
    (cond
      ;; React ecosystem check
      ((or (string-contains? lockfile-content "\"react\"")
           (or (string-contains? lockfile-content "name: react")
               (string-contains? lockfile-content "/react@")))
       (let [(react-ver (option-or (d/parse-pinned-version kind lockfile-content "react") "18.2.0"))]
         (if (or (string-starts-with? react-ver "19.")
                 (string-contains? react-ver "^19."))
             (RepoProfile
               :workspace-root root-path
               :ecosystem "js-ts"
               :primary-framework "react"
               :framework-version react-ver
               :forbidden-apis (list "useFormState" "componentWillMount")
               :recommended-apis (list "useActionState")
               :rules (list "server-actions" "zero-client-side-secrets"))
             (RepoProfile
               :workspace-root root-path
               :ecosystem "js-ts"
               :primary-framework "react"
               :framework-version react-ver
               :forbidden-apis (list "componentWillMount")
               :recommended-apis (list "useEffect")
               :rules (list "functional-components")))))

      ;; Pydantic ecosystem check
      ((or (string-contains? lockfile-content "pydantic")
           (string-contains? lockfile-content "pydantic-core"))
       (let [(pyd-ver (option-or (d/parse-pinned-version kind lockfile-content "pydantic") "2.5.0"))]
         (if (or (string-starts-with? pyd-ver "2.")
                 (string-contains? pyd-ver "^2."))
             (RepoProfile
               :workspace-root root-path
               :ecosystem "python"
               :primary-framework "pydantic"
               :framework-version pyd-ver
               :forbidden-apis (list ".dict()" ".parse_obj()")
               :recommended-apis (list ".model_dump()" ".model_validate()")
               :rules (list "type-strict" "v2-validation"))
             (RepoProfile
               :workspace-root root-path
               :ecosystem "python"
               :primary-framework "pydantic"
               :framework-version pyd-ver
               :forbidden-apis (list ".model_dump()")
               :recommended-apis (list ".dict()")
               :rules (list "v1-legacy")))))

      ;; Cargo / Rust ecosystem check
      ((or (string-contains? lockfile-content "name = \"tokio\"")
           (string-contains? lockfile-content "name = \"axum\""))
       (RepoProfile
         :workspace-root root-path
         :ecosystem "rust"
         :primary-framework "tokio"
         :framework-version "1.38.0"
         :forbidden-apis (list "block_on_inside_async")
         :recommended-apis (list "spawn_blocking")
         :rules (list "async-safety")))

      (:else
       (make-empty-profile)))))

(df format-profile-asn [(profile RepoProfile)] -> Str
  :d "Formats repository profile as dense ASN S-expression for LLM context injection."
  (let [(f-str (s/join " " (map (fn [(x Str)] -> Str (s/concat "\"" x "\"")) (.-forbidden-apis profile))))
        (r-str (s/join " " (map (fn [(x Str)] -> Str (s/concat "\"" x "\"")) (.-recommended-apis profile))))]
    (s/concat "(:repo-profile :root \"" (.-workspace-root profile) "\" "
              ":eco \"" (.-ecosystem profile) "\" "
              ":framework \"" (.-primary-framework profile) "\" "
              ":version \"" (.-framework-version profile) "\" "
              ":forbidden [" f-str "] "
              ":recommended [" r-str "])")))

(df audit-code-diff [(code Str) (profile RepoProfile)] -> RepoAuditResult
  :d "Audits code diff against repository profile and flags forbidden API calls."
  (let [(forbid (.-forbidden-apis profile))
        (violations (filter (fn [(api Str)] -> Bool (string-contains? code api)) forbid))
        (remeds (.-recommended-apis profile))]
    (if (list-empty? violations)
        (RepoAuditResult :allowed true :violations (list) :remediations (list))
        (RepoAuditResult :allowed false :violations violations :remediations remeds))))
