(module asl-harness/deps
  :d "Lockfile Introspection & Version-Pinned Type Extractor eliminating Ghost API hallucinations."
  :x [LockfileKind PinnedDependency PackageSpec
      detect-lockfile-kind lockfile-kind-to-ecosystem
      extract-npm-version extract-pnpm-version extract-cargo-version
      extract-poetry-version extract-pip-version
      parse-pinned-version check-anti-cheating-policy
      resolve-type-skeleton is-ghost-api?
      deps-resolve-from-lockfile deps-resolve format-package-spec]
  :i [])

(dfe LockfileKind
  (:c lockfile-npm [] "package.json or package-lock.json (NPM package manager)")
  (:c lockfile-pnpm [] "pnpm-lock.yaml (pnpm package manager)")
  (:c lockfile-cargo [] "Cargo.lock (Rust Crates package manager)")
  (:c lockfile-poetry [] "poetry.lock (Python Poetry package manager)")
  (:c lockfile-pip [] "requirements.txt (Python Pip package manager)")
  (:c lockfile-unknown [] "Unsupported or unrecognized lockfile format"))

(dfs PinnedDependency
  (:f name Str "Normalized package or crate identifier")
  (:f version Str "Exact semantic pinned version")
  (:f lockfile-kind LockfileKind "Originating lockfile classification")
  (:f direct Bool "True if dependency is direct, false if transitive"))

(dfs PackageSpec
  (:f package-name Str "Target package name")
  (:f version Str "Pinned resolved version string")
  (:f symbol Str "Queried symbol, method, hook, or schema function")
  (:f signature Str "Canonical typed interface skeleton / parameter schema")
  (:f is-deprecated Bool "True if symbol is deprecated or a Ghost API in pinned version")
  (:f replacement Str "Canonical replacement symbol if deprecated"))

(dfs NpmScanState
  (:f in-target-block Bool "True if inside target package JSON block")
  (:f found (Option Str) "Extracted pinned version if matched"))

(dfs TomlScanState
  (:f in-target-pkg Bool "True if inside target [[package]] block")
  (:f found (Option Str) "Extracted pinned version if matched"))

(dfs PnpmScanState
  (:f in-target-block Bool "True if inside package dependencies block")
  (:f found (Option Str) "Extracted pinned version if matched"))

(dfs PipScanState
  (:f found (Option Str) "Extracted pinned version if matched"))

(df detect-lockfile-kind [(filename Str)] -> LockfileKind
  :d "Detects the lockfile kind from filename or path."
  (cond
    ((or (string-ends-with? filename "pnpm-lock.yaml") (string-contains? filename "pnpm-lock.yaml"))
     (lockfile-pnpm))
    ((or (string-ends-with? filename "package-lock.json") (string-contains? filename "package-lock.json"))
     (lockfile-npm))
    ((or (string-ends-with? filename "package.json") (string-contains? filename "package.json"))
     (lockfile-npm))
    ((or (string-ends-with? filename "Cargo.lock") (string-contains? filename "Cargo.lock"))
     (lockfile-cargo))
    ((or (string-ends-with? filename "poetry.lock") (string-contains? filename "poetry.lock"))
     (lockfile-poetry))
    ((or (string-ends-with? filename "requirements.txt") (string-contains? filename "requirements.txt"))
     (lockfile-pip))
    (:else
     (lockfile-unknown))))

(df lockfile-kind-to-ecosystem [(kind LockfileKind)] -> Str
  :d "Maps LockfileKind to canonical ecosystem identifier."
  (mt kind
    ((lockfile-npm) "npm")
    ((lockfile-pnpm) "pnpm")
    ((lockfile-cargo) "cargo")
    ((lockfile-poetry) "poetry")
    ((lockfile-pip) "pip")
    ((lockfile-unknown) "unknown")))

(df strip-quotes [(s Str)] -> Str
  :d "Strips single and double quotes from string."
  (string-replace (string-replace s "\"" "") "'" ""))

(df clean-version [(raw Str)] -> Str
  :d "Cleans version string by removing ranges, quotes, and whitespace."
  (let [(s0 (string-trim (strip-quotes raw)))
        (s1 (if (string-starts-with? s0 "==") (option-or (string-slice s0 2 (string-length s0)) "") s0))
        (s2 (if (string-starts-with? s1 ">=") (option-or (string-slice s1 2 (string-length s1)) "") s1))
        (s3 (if (string-starts-with? s2 "<=") (option-or (string-slice s2 2 (string-length s2)) "") s2))
        (s4 (if (string-starts-with? s3 "~=") (option-or (string-slice s3 2 (string-length s3)) "") s3))
        (s5 (if (string-starts-with? s4 "^") (option-or (string-slice s4 1 (string-length s4)) "") s4))
        (s6 (if (string-starts-with? s5 "~") (option-or (string-slice s5 1 (string-length s5)) "") s5))
        (s7 (if (string-starts-with? s6 ">") (option-or (string-slice s6 1 (string-length s6)) "") s6))
        (s8 (if (string-starts-with? s7 "<") (option-or (string-slice s7 1 (string-length s7)) "") s7))
        (s9 (if (string-starts-with? s8 "=") (option-or (string-slice s8 1 (string-length s8)) "") s8))
        (s10 (if (string-starts-with? s9 "v") (option-or (string-slice s9 1 (string-length s9)) "") s9))
        (s11 (string-trim s10))
        (s12 (if (string-ends-with? s11 ",") (option-or (string-slice s11 0 (- (string-length s11) 1)) "") s11))
        (s13 (if (string-ends-with? s12 ";") (option-or (string-slice s12 0 (- (string-length s12) 1)) "") s12))]
    (string-trim s13)))

(df parse-major-version [(version Str)] -> I64
  :d "Extracts major version integer from semantic version string."
  (let [(clean (clean-version version))
        (parts (string-split clean "."))
        (head (option-or (list-head parts) "0"))]
    (option-or (string-to-int64 head) 0)))

(df scan-npm-line [(acc NpmScanState) (line Str) (pkg-name Str)] -> NpmScanState
  :d "Scans a single line of package.json or package-lock.json."
  (mt (.-found acc)
    ((some _) acc)
    ((none)
     (let [(trimmed (string-trim line))
           (pkg-key (str "\"" pkg-name "\""))
           (nm-key (str "\"node_modules/" pkg-name "\""))]
       (if (or (string-contains? trimmed pkg-key) (string-contains? trimmed nm-key))
           (if (string-contains? trimmed ":")
               (let [(after-colon (option-or (list-head (option-or (list-tail (string-split trimmed ":")) (list))) ""))]
                 (if (string-contains? after-colon "\"")
                     (let [(val-clean (clean-version after-colon))]
                       (if (not (string-empty? val-clean))
                           (NpmScanState :in-target-block false :found (some val-clean))
                           (NpmScanState :in-target-block true :found (none))))
                     (NpmScanState :in-target-block true :found (none))))
               (NpmScanState :in-target-block true :found (none)))
           (if (.-in-target-block acc)
               (if (string-contains? trimmed "\"version\":")
                   (let [(after-ver (option-or (list-head (option-or (list-tail (string-split trimmed "\"version\":")) (list))) ""))
                         (val-clean (clean-version after-ver))]
                     (if (not (string-empty? val-clean))
                         (NpmScanState :in-target-block false :found (some val-clean))
                         acc))
                   (if (and (string-contains? trimmed "}") (not (string-contains? trimmed "{")))
                       (NpmScanState :in-target-block false :found (none))
                       acc))
               acc))))))

(df extract-npm-version [(content Str) (pkg-name Str)] -> (Option Str)
  :d "Extracts pinned package version from package.json or package-lock.json."
  (let [(lines (string-split content "\n"))
        (init (NpmScanState :in-target-block false :found (none)))
        (final-st (fold (fn [(st NpmScanState) (l Str)] -> NpmScanState (scan-npm-line st l pkg-name)) init lines))]
    (.-found final-st)))

(df extract-version-after-at [(line Str) (pkg-name Str)] -> (Option Str)
  :d "Extracts version from a pnpm package@version string."
  (let [(needle (str pkg-name "@"))
        (idx (string-index-of line needle))]
    (mt idx
      ((none) (none))
      ((some i)
       (let [(prefix-str (option-or (string-slice line 0 i) ""))
             (valid-prefix (if (= i 0)
                               true
                               (let [(prev-char (option-or (string-slice line (- i 1) i) ""))]
                                 (and (or (= prev-char "/") (or (= prev-char "'") (or (= prev-char "\"") (= prev-char " "))))
                                      (not (string-contains? prefix-str "@"))))))]
         (if valid-prefix
             (let [(after-start (+ i (string-length needle)))
                   (tail (option-or (string-slice line after-start (string-length line)) ""))
                   (c1 (option-or (list-head (string-split tail ":")) tail))
                   (c2 (option-or (list-head (string-split c1 "(")) c1))
                   (c3 (option-or (list-head (string-split c2 "'")) c2))
                   (c4 (option-or (list-head (string-split c3 "\"")) c3))
                   (c5 (option-or (list-head (string-split c4 " ")) c4))
                   (ver (clean-version c5))]
               (if (not (string-empty? ver))
                   (some ver)
                   (none)))
             (none)))))))

(df scan-pnpm-line [(acc PnpmScanState) (line Str) (pkg-name Str)] -> PnpmScanState
  :d "Scans a single line of pnpm-lock.yaml."
  (mt (.-found acc)
    ((some _) acc)
    ((none)
     (let [(trimmed (string-trim line))
           (at-opt (extract-version-after-at trimmed pkg-name))]
       (mt at-opt
         ((some v)
          (PnpmScanState :in-target-block false :found (some v)))
         ((none)
          (if (or (= trimmed (str pkg-name ":")) (or (= trimmed (str "'" pkg-name "':")) (= trimmed (str "\"" pkg-name "\":"))))
              (PnpmScanState :in-target-block true :found (none))
              (if (.-in-target-block acc)
                  (if (string-starts-with? trimmed "version:")
                      (let [(after-col (option-or (list-head (option-or (list-tail (string-split trimmed ":")) (list))) ""))
                            (ver (clean-version after-col))]
                        (if (not (string-empty? ver))
                            (PnpmScanState :in-target-block false :found (some ver))
                            acc))
                      (if (and (not (string-starts-with? line " ")) (not (string-starts-with? line "\t")))
                          (PnpmScanState :in-target-block false :found (none))
                          acc))
                  acc))))))))

(df extract-pnpm-version [(content Str) (pkg-name Str)] -> (Option Str)
  :d "Extracts pinned package version from pnpm-lock.yaml content."
  (let [(lines (string-split content "\n"))
        (init (PnpmScanState :in-target-block false :found (none)))
        (final-st (fold (fn [(st PnpmScanState) (l Str)] -> PnpmScanState (scan-pnpm-line st l pkg-name)) init lines))]
    (.-found final-st)))

(df scan-toml-line [(acc TomlScanState) (line Str) (pkg-name Str)] -> TomlScanState
  :d "Scans a single line of Cargo.lock or poetry.lock for exact package name and version."
  (mt (.-found acc)
    ((some _) acc)
    ((none)
     (let [(trimmed (string-trim line))]
       (if (or (string-starts-with? trimmed "[[") (and (string-starts-with? trimmed "[") (not (string-starts-with? trimmed "[[package"))))
           (TomlScanState :in-target-pkg false :found (none))
           (if (or (string-contains? trimmed (str "name = \"" pkg-name "\""))
                   (string-contains? trimmed (str "name = '" pkg-name "'")))
               (TomlScanState :in-target-pkg true :found (none))
               (if (.-in-target-pkg acc)
                   (if (string-starts-with? trimmed "version =")
                       (let [(after-eq (option-or (list-head (option-or (list-tail (string-split trimmed "=")) (list))) ""))
                             (ver (clean-version after-eq))]
                         (if (not (string-empty? ver))
                             (TomlScanState :in-target-pkg false :found (some ver))
                             acc))
                       acc)
                   acc)))))))

(df extract-cargo-version [(content Str) (pkg-name Str)] -> (Option Str)
  :d "Extracts pinned package version from Cargo.lock content."
  (let [(lines (string-split content "\n"))
        (init (TomlScanState :in-target-pkg false :found (none)))
        (final-st (fold (fn [(st TomlScanState) (l Str)] -> TomlScanState (scan-toml-line st l pkg-name)) init lines))]
    (.-found final-st)))

(df extract-poetry-version [(content Str) (pkg-name Str)] -> (Option Str)
  :d "Extracts pinned package version from poetry.lock content."
  (extract-cargo-version content pkg-name))

(df is-pip-delim [(c Str)] -> Bool
  :d "Returns true if char is an operator delimiter or whitespace."
  (or (= c "=") (or (= c ">") (or (= c "<") (or (= c "~") (or (= c "!") (or (= c " ") (or (= c "\t") (= c "@")))))))))

(df scan-pip-line [(acc PipScanState) (line Str) (pkg-name Str)] -> PipScanState
  :d "Scans a single requirements.txt line for exact package pinning."
  (mt (.-found acc)
    ((some _) acc)
    ((none)
     (let [(c-idx (string-index-of line "#"))
           (no-comment (mt c-idx
                         ((none) line)
                         ((some idx) (option-or (string-slice line 0 idx) ""))))
           (m-idx (string-index-of no-comment ";"))
           (no-marker (mt m-idx
                        ((none) no-comment)
                        ((some idx2) (option-or (string-slice no-comment 0 idx2) ""))))
           (trimmed (string-trim no-marker))]
       (if (string-starts-with? trimmed pkg-name)
           (let [(pkg-len (string-length pkg-name))
                 (tail (option-or (string-slice trimmed pkg-len (string-length trimmed)) ""))]
             (if (string-empty? tail)
                 acc
                 (let [(first-char (option-or (string-slice tail 0 1) ""))]
                   (if (is-pip-delim first-char)
                       (let [(ver (clean-version tail))]
                         (if (not (string-empty? ver))
                             (PipScanState :found (some ver))
                             acc))
                       acc))))
           acc)))))

(df extract-pip-version [(content Str) (pkg-name Str)] -> (Option Str)
  :d "Extracts pinned package version from requirements.txt content."
  (let [(lines (string-split content "\n"))
        (init (PipScanState :found (none)))
        (final-st (fold (fn [(st PipScanState) (l Str)] -> PipScanState (scan-pip-line st l pkg-name)) init lines))]
    (.-found final-st)))

(df parse-pinned-version [(kind LockfileKind) (content Str) (pkg-name Str)] -> (Option Str)
  :d "Parses exact pinned version from lockfile content based on LockfileKind."
  (mt kind
    ((lockfile-npm) (extract-npm-version content pkg-name))
    ((lockfile-pnpm) (extract-pnpm-version content pkg-name))
    ((lockfile-cargo) (extract-cargo-version content pkg-name))
    ((lockfile-poetry) (extract-poetry-version content pkg-name))
    ((lockfile-pip) (extract-pip-version content pkg-name))
    ((lockfile-unknown) (none))))

(df check-anti-cheating-policy [(network-requested Bool)] -> Bool
  :d "Enforces hermetic benchmark invariant: network requests are blocked."
  (if network-requested
      false
      true))

(df normalize-symbol [(sym Str)] -> Str
  :d "Normalizes symbol query by stripping leading dot and trailing parentheses."
  (let [(s1 (if (string-starts-with? sym ".") (option-or (string-slice sym 1 (string-length sym)) "") sym))
        (s2 (if (string-ends-with? s1 "()") (option-or (string-slice s1 0 (- (string-length s1) 2)) "") s1))]
    (string-trim s2)))

(df resolve-type-skeleton [(package Str) (version Str) (symbol Str)] -> PackageSpec
  :d "Resolves canonical typed interface skeleton and flags version-skewed Ghost APIs."
  (let [(major (parse-major-version version))
        (clean-sym (normalize-symbol symbol))]
    (cond
      ((or (= package "pydantic") (= package "pydantic-core"))
       (if (>= major 2)
           (cond
             ((= clean-sym "dict")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "(self, *, mode: str = 'python', include = None, exclude = None, by_alias: bool = False, exclude_unset: bool = False, exclude_defaults: bool = False, exclude_none: bool = False, round_trip: bool = False, warnings: bool = True) -> dict[str, Any]"
                :is-deprecated true
                :replacement "model_dump()"))
             ((= clean-sym "model_dump")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "(self, *, mode: str = 'python', include = None, exclude = None, by_alias: bool = False, exclude_unset: bool = False, exclude_defaults: bool = False, exclude_none: bool = False, round_trip: bool = False, warnings: bool = True) -> dict[str, Any]"
                :is-deprecated false
                :replacement ""))
             ((= clean-sym "model_dump_json")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "(self, *, indent: int | None = None, include = None, exclude = None, by_alias: bool = False, exclude_unset: bool = False, exclude_defaults: bool = False, exclude_none: bool = False, round_trip: bool = False, warnings: bool = True) -> str"
                :is-deprecated false
                :replacement ""))
             ((= clean-sym "parse_obj")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "(cls, obj: Any, *, strict: bool | None = None, from_attributes: bool | None = None, context: dict[str, Any] | None = None) -> Self"
                :is-deprecated true
                :replacement "model_validate()"))
             (:else
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "unknown"
                :is-deprecated false
                :replacement "")))
           (cond
             ((= clean-sym "dict")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "(self, *, include = None, exclude = None, by_alias: bool = False, skip_defaults: bool = None, exclude_unset: bool = False, exclude_defaults: bool = False, exclude_none: bool = False) -> dict[str, Any]"
                :is-deprecated false
                :replacement ""))
             ((= clean-sym "model_dump")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "unknown"
                :is-deprecated true
                :replacement "dict()"))
             (:else
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "unknown"
                :is-deprecated false
                :replacement "")))))
      ((or (= package "react") (= package "react-dom"))
       (if (>= major 19)
           (cond
             ((= clean-sym "useFormState")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "<State, Payload>(action: (state: Awaited<State>, payload: Payload) => State | Promise<State>, initialState: Awaited<State>, permalink?: string) => [state: Awaited<State>, formAction: (payload: Payload) => void, isPending: boolean]"
                :is-deprecated true
                :replacement "useActionState"))
             ((= clean-sym "useActionState")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "<State, Payload>(action: (state: Awaited<State>, payload: Payload) => State | Promise<State>, initialState: Awaited<State>, permalink?: string) => [state: Awaited<State>, formAction: (payload: Payload) => void, isPending: boolean]"
                :is-deprecated false
                :replacement ""))
             (:else
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "unknown"
                :is-deprecated false
                :replacement "")))
           (cond
             ((= clean-sym "useFormState")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "<State, Payload>(action: (state: Awaited<State>, payload: Payload) => State | Promise<State>, initialState: Awaited<State>, permalink?: string) => [state: Awaited<State>, formAction: (payload: Payload) => void]"
                :is-deprecated false
                :replacement ""))
             ((= clean-sym "useActionState")
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "unknown"
                :is-deprecated true
                :replacement "useFormState"))
             (:else
              (PackageSpec
                :package-name package
                :version version
                :symbol symbol
                :signature "unknown"
                :is-deprecated false
                :replacement "")))))
      ((= package "zod")
       (cond
         ((= clean-sym "safeParse")
          (PackageSpec
            :package-name package
            :version version
            :symbol symbol
            :signature "(data: unknown) => SafeParseReturnType<Output, Output>"
            :is-deprecated false
            :replacement ""))
         ((= clean-sym "parse")
          (PackageSpec
            :package-name package
            :version version
            :symbol symbol
            :signature "(data: unknown) => Output"
            :is-deprecated false
            :replacement ""))
         (:else
          (PackageSpec
            :package-name package
            :version version
            :symbol symbol
            :signature "unknown"
            :is-deprecated false
            :replacement ""))))
      ((= package "tokio")
       (cond
         ((= clean-sym "spawn")
          (PackageSpec
            :package-name package
            :version version
            :symbol symbol
            :signature "pub fn spawn<T>(future: T) -> JoinHandle<T::Output> where T: Future + Send + 'static, T::Output: Send + 'static"
            :is-deprecated false
            :replacement ""))
         (:else
          (PackageSpec
            :package-name package
            :version version
            :symbol symbol
            :signature "unknown"
            :is-deprecated false
            :replacement ""))))
      (:else
       (PackageSpec
         :package-name package
         :version version
         :symbol symbol
         :signature "unknown"
         :is-deprecated false
         :replacement "")))))

(df is-ghost-api? [(spec PackageSpec)] -> Bool
  :d "Predicate indicating whether queried symbol is deprecated or obsolete in pinned version."
  (.-is-deprecated spec))

(df deps-resolve-from-lockfile [(lockfile-content Str) (kind LockfileKind) (pkg-name Str) (symbol Str)] -> PackageSpec
  :d "Resolves package version from lockfile content and generates version-pinned type skeleton."
  (let [(opt-ver (parse-pinned-version kind lockfile-content pkg-name))
        (ver (option-or opt-ver "unknown"))]
    (resolve-type-skeleton pkg-name ver symbol)))

(df deps-resolve [(package Str) (symbol Str)] -> PackageSpec
  :d "Universal tool interface for version-pinned dependency inspection."
  (let [(default-ver (cond
                       ((= package "pydantic") "2.6.1")
                       ((= package "react") "19.0.0")
                       ((= package "zod") "3.22.4")
                       ((= package "tokio") "1.38.0")
                       (:else "1.0.0")))]
    (resolve-type-skeleton package default-ver symbol)))

(df format-package-spec [(spec PackageSpec)] -> Str
  :d "Formats PackageSpec into token-dense S-expression for agent prompt and blackboard."
  (str "(:pkg-spec :package \"" (.-package-name spec)
       "\" :version \"" (.-version spec)
       "\" :symbol \"" (.-symbol spec)
       "\" :sig \"" (.-signature spec)
       "\" :is-deprecated " (if (.-is-deprecated spec) "true" "false")
       " :replacement \"" (.-replacement spec) "\")"))
