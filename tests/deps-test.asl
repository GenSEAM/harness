(module asl-harness/tests/deps-test
  :d "Unit tests for Lockfile Introspection, Version-Pinned Type Extractor, and Ghost API Guard."
  :x [test-detect-lockfile-kind
      test-parse-pinned-version-npm
      test-parse-pinned-version-pnpm
      test-parse-pinned-version-cargo
      test-parse-pinned-version-poetry
      test-parse-pinned-version-pip
      test-anti-cheating-policy
      test-ghost-api-pydantic-v2
      test-ghost-api-react-19
      test-ghost-api-elimination
      test-deps-resolve-from-lockfile
      test-deps-resolve-e2e
      run-tests]
  :i [(deps :a d)])

(df test-detect-lockfile-kind [] -> Bool
  :d "Verifies lockfile kind detection across 5 ecosystems and unknown fallback."
  (let [(k-pnpm (d/detect-lockfile-kind "pnpm-lock.yaml"))
        (k-pnpm-path (d/detect-lockfile-kind "/repo/frontend/pnpm-lock.yaml"))
        (k-npm (d/detect-lockfile-kind "package-lock.json"))
        (k-pkg (d/detect-lockfile-kind "package.json"))
        (k-cargo (d/detect-lockfile-kind "Cargo.lock"))
        (k-cargo-path (d/detect-lockfile-kind "backend/Cargo.lock"))
        (k-poetry (d/detect-lockfile-kind "poetry.lock"))
        (k-pip (d/detect-lockfile-kind "requirements.txt"))
        (k-unk (d/detect-lockfile-kind "yarn.lock"))]
    (assert (= (d/lockfile-kind-to-ecosystem k-pnpm) "pnpm") "pnpm matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-pnpm-path) "pnpm") "pnpm path matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-npm) "npm") "npm matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-pkg) "npm") "pkg matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-cargo) "cargo") "cargo matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-cargo-path) "cargo") "cargo path matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-poetry) "poetry") "poetry matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-pip) "pip") "pip matches")
    (assert (= (d/lockfile-kind-to-ecosystem k-unk) "unknown") "unknown matches")
    true))

(df test-parse-pinned-version-npm [] -> Bool
  :d "Verifies exact NPM version extraction with substring collision prevention."
  (let [(json-content "{\n  \"dependencies\": {\n    \"react-dom\": \"^19.0.0\",\n    \"@types/react\": \"^18.2.0\",\n    \"react\": \"^19.0.0\",\n    \"zod\": \"3.22.4\"\n  }\n}")
        (react-ver (d/parse-pinned-version (d/lockfile-npm) json-content "react"))
        (zod-ver (d/parse-pinned-version (d/lockfile-npm) json-content "zod"))
        (dom-ver (d/parse-pinned-version (d/lockfile-npm) json-content "react-dom"))
        (none-ver (d/parse-pinned-version (d/lockfile-npm) json-content "vue"))]
    (assert (= (option-or react-ver "") "19.0.0") "npm react ver is 19.0.0")
    (assert (= (option-or zod-ver "") "3.22.4") "npm zod ver is 3.22.4")
    (assert (= (option-or dom-ver "") "19.0.0") "npm dom ver is 19.0.0")
    (assert (not (option-is-some? none-ver)) "npm vue ver is none")
    true))

(df test-parse-pinned-version-pnpm [] -> Bool
  :d "Verifies PNPM lockfile parsing for slash and at-version packages."
  (let [(pnpm-content "packages:\n  /react@19.0.0:\n    resolution: {integrity: sha512-...}\n  /zod@3.22.4:\n    resolution: {integrity: sha512-...}\n  /react-dom@19.0.0:\n    resolution: {integrity: sha512-...}\n")
        (react-ver (d/parse-pinned-version (d/lockfile-pnpm) pnpm-content "react"))
        (zod-ver (d/parse-pinned-version (d/lockfile-pnpm) pnpm-content "zod"))
        (none-ver (d/parse-pinned-version (d/lockfile-pnpm) pnpm-content "tokio"))]
    (assert (= (option-or react-ver "") "19.0.0") "pnpm react ver is 19.0.0")
    (assert (= (option-or zod-ver "") "3.22.4") "pnpm zod ver is 3.22.4")
    (assert (not (option-is-some? none-ver)) "pnpm none ver is none")
    true))

(df test-parse-pinned-version-cargo [] -> Bool
  :d "Verifies Cargo.lock TOML table parsing."
  (let [(cargo-content "[[package]]\nname = \"tokio-util\"\nversion = \"0.7.10\"\n\n[[package]]\nname = \"tokio\"\nversion = \"1.38.0\"\nsource = \"registry+https://github.com/rust-lang/crates.io-index\"\n")
        (tokio-ver (d/parse-pinned-version (d/lockfile-cargo) cargo-content "tokio"))
        (util-ver (d/parse-pinned-version (d/lockfile-cargo) cargo-content "tokio-util"))
        (none-ver (d/parse-pinned-version (d/lockfile-cargo) cargo-content "serde"))]
    (assert (= (option-or tokio-ver "") "1.38.0") "cargo tokio ver is 1.38.0")
    (assert (= (option-or util-ver "") "0.7.10") "cargo util ver is 0.7.10")
    (assert (not (option-is-some? none-ver)) "cargo none ver is none")
    true))

(df test-parse-pinned-version-poetry [] -> Bool
  :d "Verifies poetry.lock package table parsing."
  (let [(poetry-content "[[package]]\nname = \"pydantic-core\"\nversion = \"2.16.3\"\n\n[[package]]\nname = \"pydantic\"\nversion = \"2.6.1\"\ndescription = \"Data validation\"\n")
        (pyd-ver (d/parse-pinned-version (d/lockfile-poetry) poetry-content "pydantic"))
        (core-ver (d/parse-pinned-version (d/lockfile-poetry) poetry-content "pydantic-core"))
        (none-ver (d/parse-pinned-version (d/lockfile-poetry) poetry-content "flask"))]
    (assert (= (option-or pyd-ver "") "2.6.1") "poetry pyd ver is 2.6.1")
    (assert (= (option-or core-ver "") "2.16.3") "poetry core ver is 2.16.3")
    (assert (not (option-is-some? none-ver)) "poetry none ver is none")
    true))

(df test-parse-pinned-version-pip [] -> Bool
  :d "Verifies requirements.txt exact version and operator parsing."
  (let [(pip-content "pydantic-core==2.16.3\npydantic==2.6.1\nreact>=19.0.0\nzod~=3.22.4 # pin\n")
        (pyd-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "pydantic"))
        (core-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "pydantic-core"))
        (react-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "react"))
        (zod-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "zod"))
        (none-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "fastapi"))]
    (assert (= (option-or pyd-ver "") "2.6.1") "pip pyd ver is 2.6.1")
    (assert (= (option-or core-ver "") "2.16.3") "pip core ver is 2.16.3")
    (assert (= (option-or react-ver "") "19.0.0") "pip react ver is 19.0.0")
    (assert (= (option-or zod-ver "") "3.22.4") "pip zod ver is 3.22.4")
    (assert (not (option-is-some? none-ver)) "pip none ver is none")
    true))

(df test-anti-cheating-policy [] -> Bool
  :d "Verifies hermetic benchmark invariant: network access is blocked, offline access allowed."
  (let [(offline-ok (d/check-anti-cheating-policy false))
        (network-blocked (not (d/check-anti-cheating-policy true)))]
    (assert offline-ok "offline is allowed")
    (assert network-blocked "network is blocked")
    true))

(df test-ghost-api-pydantic-v2 [] -> Bool
  :d "Verifies Ghost API detection for Pydantic v1 vs v2."
  (let [(v2-dict (d/resolve-type-skeleton "pydantic" "2.6.1" ".dict()"))
        (v2-model-dump (d/resolve-type-skeleton "pydantic" "2.6.1" "model_dump"))
        (v1-dict (d/resolve-type-skeleton "pydantic" "1.10.12" "dict"))]
    (assert (.-is-deprecated v2-dict) "v2 dict is deprecated")
    (assert (= (.-replacement v2-dict) "model_dump()") "v2 dict replacement is model_dump()")
    (assert (not (.-is-deprecated v2-model-dump)) "v2 model dump is not deprecated")
    (assert (= (.-replacement v2-model-dump) "") "v2 model dump replacement empty")
    (assert (not (.-is-deprecated v1-dict)) "v1 dict is not deprecated")
    (assert (= (.-replacement v1-dict) "") "v1 dict replacement empty")
    true))

(df test-ghost-api-react-19 [] -> Bool
  :d "Verifies Ghost API detection for React 18 vs 19."
  (let [(r19-form (d/resolve-type-skeleton "react" "19.0.0" "useFormState"))
        (r19-action (d/resolve-type-skeleton "react" "19.0.0" "useActionState"))
        (r18-form (d/resolve-type-skeleton "react" "18.2.0" "useFormState"))]
    (assert (.-is-deprecated r19-form) "r19 form is deprecated")
    (assert (= (.-replacement r19-form) "useActionState") "r19 form replacement is useActionState")
    (assert (not (.-is-deprecated r19-action)) "r19 action is not deprecated")
    (assert (= (.-replacement r19-action) "") "r19 action replacement empty")
    (assert (not (.-is-deprecated r18-form)) "r18 form is not deprecated")
    (assert (= (.-replacement r18-form) "") "r18 form replacement empty")
    true))

(df test-ghost-api-elimination [] -> Bool
  :d "Aggregates Ghost API elimination across Pydantic v2 and React 19."
  (do
    (assert (test-ghost-api-pydantic-v2) "pydantic v2 ghost api passes")
    (assert (test-ghost-api-react-19) "react 19 ghost api passes")
    true))

(df test-deps-resolve-from-lockfile [] -> Bool
  :d "Verifies end-to-end lockfile resolution into version-pinned type skeleton."
  (let [(lock-src "pydantic==2.6.1\nreact==19.0.0\nzod==3.22.4\n")
        (spec-dict (d/deps-resolve-from-lockfile lock-src (d/lockfile-pip) "pydantic" "dict"))
        (spec-react (d/deps-resolve-from-lockfile lock-src (d/lockfile-pip) "react" "useActionState"))
        (spec-zod (d/deps-resolve-from-lockfile lock-src (d/lockfile-pip) "zod" "safeParse"))
        (fmt (d/format-package-spec spec-dict))]
    (assert (.-is-deprecated spec-dict) "spec-dict is deprecated")
    (assert (= (.-version spec-dict) "2.6.1") "spec-dict version is 2.6.1")
    (assert (= (.-replacement spec-dict) "model_dump()") "spec-dict replacement is model_dump()")
    (assert (not (.-is-deprecated spec-react)) "spec-react is not deprecated")
    (assert (not (.-is-deprecated spec-zod)) "spec-zod is not deprecated")
    (assert (string-contains? fmt ":pkg-spec") "fmt contains :pkg-spec")
    (assert (string-contains? fmt "model_dump()") "fmt contains model_dump()")
    true))

(df test-deps-resolve-e2e [] -> Bool
  :d "Verifies universal deps-resolve entry point and lockfile resolution."
  (let [(spec (d/deps-resolve "pydantic" "dict"))
        (spec-zod (d/deps-resolve "zod" "safeParse"))]
    (assert (.-is-deprecated spec) "spec is deprecated")
    (assert (= (.-replacement spec) "model_dump()") "spec replacement is model_dump()")
    (assert (not (.-is-deprecated spec-zod)) "spec-zod is not deprecated")
    (assert (test-deps-resolve-from-lockfile) "resolve from lockfile passes")
    true))

(df run-tests [] -> Bool
  :d "Executes full deps and lockfile test suite."
  (do
    (test-detect-lockfile-kind)
    (test-parse-pinned-version-npm)
    (test-parse-pinned-version-pnpm)
    (test-parse-pinned-version-cargo)
    (test-parse-pinned-version-poetry)
    (test-parse-pinned-version-pip)
    (test-anti-cheating-policy)
    (test-ghost-api-elimination)
    (test-deps-resolve-e2e)
    true))
