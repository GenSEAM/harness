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
    (and (= (d/lockfile-kind-to-ecosystem k-pnpm) "pnpm")
         (and (= (d/lockfile-kind-to-ecosystem k-pnpm-path) "pnpm")
              (and (= (d/lockfile-kind-to-ecosystem k-npm) "npm")
                   (and (= (d/lockfile-kind-to-ecosystem k-pkg) "npm")
                        (and (= (d/lockfile-kind-to-ecosystem k-cargo) "cargo")
                             (and (= (d/lockfile-kind-to-ecosystem k-cargo-path) "cargo")
                                  (and (= (d/lockfile-kind-to-ecosystem k-poetry) "poetry")
                                       (and (= (d/lockfile-kind-to-ecosystem k-pip) "pip")
                                            (= (d/lockfile-kind-to-ecosystem k-unk) "unknown")))))))))))

(df test-parse-pinned-version-npm [] -> Bool
  :d "Verifies exact NPM version extraction with substring collision prevention."
  (let [(json-content "{\n  \"dependencies\": {\n    \"react-dom\": \"^19.0.0\",\n    \"@types/react\": \"^18.2.0\",\n    \"react\": \"^19.0.0\",\n    \"zod\": \"3.22.4\"\n  }\n}")
        (react-ver (d/parse-pinned-version (d/lockfile-npm) json-content "react"))
        (zod-ver (d/parse-pinned-version (d/lockfile-npm) json-content "zod"))
        (dom-ver (d/parse-pinned-version (d/lockfile-npm) json-content "react-dom"))
        (none-ver (d/parse-pinned-version (d/lockfile-npm) json-content "vue"))]
    (and (= (option-or react-ver "") "19.0.0")
         (and (= (option-or zod-ver "") "3.22.4")
              (and (= (option-or dom-ver "") "19.0.0")
                   (not (option-is-some? none-ver)))))))

(df test-parse-pinned-version-pnpm [] -> Bool
  :d "Verifies PNPM lockfile parsing for slash and at-version packages."
  (let [(pnpm-content "packages:\n  /react@19.0.0:\n    resolution: {integrity: sha512-...}\n  /zod@3.22.4:\n    resolution: {integrity: sha512-...}\n  /react-dom@19.0.0:\n    resolution: {integrity: sha512-...}\n")
        (react-ver (d/parse-pinned-version (d/lockfile-pnpm) pnpm-content "react"))
        (zod-ver (d/parse-pinned-version (d/lockfile-pnpm) pnpm-content "zod"))
        (none-ver (d/parse-pinned-version (d/lockfile-pnpm) pnpm-content "tokio"))]
    (and (= (option-or react-ver "") "19.0.0")
         (and (= (option-or zod-ver "") "3.22.4")
              (not (option-is-some? none-ver))))))

(df test-parse-pinned-version-cargo [] -> Bool
  :d "Verifies Cargo.lock TOML table parsing."
  (let [(cargo-content "[[package]]\nname = \"tokio-util\"\nversion = \"0.7.10\"\n\n[[package]]\nname = \"tokio\"\nversion = \"1.38.0\"\nsource = \"registry+https://github.com/rust-lang/crates.io-index\"\n")
        (tokio-ver (d/parse-pinned-version (d/lockfile-cargo) cargo-content "tokio"))
        (util-ver (d/parse-pinned-version (d/lockfile-cargo) cargo-content "tokio-util"))
        (none-ver (d/parse-pinned-version (d/lockfile-cargo) cargo-content "serde"))]
    (and (= (option-or tokio-ver "") "1.38.0")
         (and (= (option-or util-ver "") "0.7.10")
              (not (option-is-some? none-ver))))))

(df test-parse-pinned-version-poetry [] -> Bool
  :d "Verifies poetry.lock package table parsing."
  (let [(poetry-content "[[package]]\nname = \"pydantic-core\"\nversion = \"2.16.3\"\n\n[[package]]\nname = \"pydantic\"\nversion = \"2.6.1\"\ndescription = \"Data validation\"\n")
        (pyd-ver (d/parse-pinned-version (d/lockfile-poetry) poetry-content "pydantic"))
        (core-ver (d/parse-pinned-version (d/lockfile-poetry) poetry-content "pydantic-core"))
        (none-ver (d/parse-pinned-version (d/lockfile-poetry) poetry-content "flask"))]
    (and (= (option-or pyd-ver "") "2.6.1")
         (and (= (option-or core-ver "") "2.16.3")
              (not (option-is-some? none-ver))))))

(df test-parse-pinned-version-pip [] -> Bool
  :d "Verifies requirements.txt exact version and operator parsing."
  (let [(pip-content "pydantic-core==2.16.3\npydantic==2.6.1\nreact>=19.0.0\nzod~=3.22.4 # pin\n")
        (pyd-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "pydantic"))
        (core-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "pydantic-core"))
        (react-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "react"))
        (zod-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "zod"))
        (none-ver (d/parse-pinned-version (d/lockfile-pip) pip-content "fastapi"))]
    (and (= (option-or pyd-ver "") "2.6.1")
         (and (= (option-or core-ver "") "2.16.3")
              (and (= (option-or react-ver "") "19.0.0")
                   (and (= (option-or zod-ver "") "3.22.4")
                        (not (option-is-some? none-ver))))))))

(df test-anti-cheating-policy [] -> Bool
  :d "Verifies hermetic benchmark invariant: network access is blocked, offline access allowed."
  (let [(offline-ok (d/check-anti-cheating-policy false))
        (network-blocked (not (d/check-anti-cheating-policy true)))]
    (and offline-ok network-blocked)))

(df test-ghost-api-pydantic-v2 [] -> Bool
  :d "Verifies Ghost API detection for Pydantic v1 vs v2."
  (let [(v2-dict (d/resolve-type-skeleton "pydantic" "2.6.1" ".dict()"))
        (v2-model-dump (d/resolve-type-skeleton "pydantic" "2.6.1" "model_dump"))
        (v1-dict (d/resolve-type-skeleton "pydantic" "1.10.12" "dict"))]
    (and (.-is-deprecated v2-dict)
         (and (= (.-replacement v2-dict) "model_dump()")
              (and (not (.-is-deprecated v2-model-dump))
                   (and (= (.-replacement v2-model-dump) "")
                        (and (not (.-is-deprecated v1-dict))
                             (= (.-replacement v1-dict) ""))))))))

(df test-ghost-api-react-19 [] -> Bool
  :d "Verifies Ghost API detection for React 18 vs 19."
  (let [(r19-form (d/resolve-type-skeleton "react" "19.0.0" "useFormState"))
        (r19-action (d/resolve-type-skeleton "react" "19.0.0" "useActionState"))
        (r18-form (d/resolve-type-skeleton "react" "18.2.0" "useFormState"))]
    (and (.-is-deprecated r19-form)
         (and (= (.-replacement r19-form) "useActionState")
              (and (not (.-is-deprecated r19-action))
                   (and (= (.-replacement r19-action) "")
                        (and (not (.-is-deprecated r18-form))
                             (= (.-replacement r18-form) ""))))))))

(df test-ghost-api-elimination [] -> Bool
  :d "Aggregates Ghost API elimination across Pydantic v2 and React 19."
  (and (test-ghost-api-pydantic-v2)
       (test-ghost-api-react-19)))

(df test-deps-resolve-from-lockfile [] -> Bool
  :d "Verifies end-to-end lockfile resolution into version-pinned type skeleton."
  (let [(lock-src "pydantic==2.6.1\nreact==19.0.0\nzod==3.22.4\n")
        (spec-dict (d/deps-resolve-from-lockfile lock-src (d/lockfile-pip) "pydantic" "dict"))
        (spec-react (d/deps-resolve-from-lockfile lock-src (d/lockfile-pip) "react" "useActionState"))
        (spec-zod (d/deps-resolve-from-lockfile lock-src (d/lockfile-pip) "zod" "safeParse"))
        (fmt (d/format-package-spec spec-dict))]
    (and (.-is-deprecated spec-dict)
         (and (= (.-version spec-dict) "2.6.1")
              (and (= (.-replacement spec-dict) "model_dump()")
                   (and (not (.-is-deprecated spec-react))
                        (and (not (.-is-deprecated spec-zod))
                             (and (string-contains? fmt ":pkg-spec")
                                  (string-contains? fmt "model_dump()")))))))))

(df test-deps-resolve-e2e [] -> Bool
  :d "Verifies universal deps-resolve entry point and lockfile resolution."
  (let [(spec (d/deps-resolve "pydantic" "dict"))
        (spec-zod (d/deps-resolve "zod" "safeParse"))]
    (and (.-is-deprecated spec)
         (and (= (.-replacement spec) "model_dump()")
              (and (not (.-is-deprecated spec-zod))
                   (test-deps-resolve-from-lockfile))))))

(df run-tests [] -> Bool
  :d "Executes full deps and lockfile test suite."
  (and (test-detect-lockfile-kind)
       (and (test-parse-pinned-version-npm)
            (and (test-parse-pinned-version-pnpm)
                 (and (test-parse-pinned-version-cargo)
                      (and (test-parse-pinned-version-poetry)
                           (and (test-parse-pinned-version-pip)
                                (and (test-anti-cheating-policy)
                                     (and (test-ghost-api-elimination)
                                          (test-deps-resolve-e2e))))))))))
