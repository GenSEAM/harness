(module asl-harness/repo-scout-test
  :d "Unit verification test suite for Autonomous Repository Scout"
  :x [test-scout-react-19
      test-scout-pydantic-v2
      test-audit-code-clean
      test-audit-code-forbidden
      test-format-profile-asn
      run-repo-scout-tests
      run-tests]
  :i [(repo-scout :a rs)])

(df test-scout-react-19 [] -> Bool
  :d "Tests repository scouting on React 19 lockfile"
  (let [(pkg-json "{\n  \"dependencies\": {\n    \"react\": \"19.0.0\"\n  }\n}")
        (prof (rs/scout-repo "/app" "package.json" pkg-json))]
    (assert (= (.-ecosystem prof) "js-ts") "ecosystem is js-ts")
    (assert (= (.-primary-framework prof) "react") "framework is react")
    (assert (list-contains? (.-forbidden-apis prof) "useFormState") "has forbidden useFormState")
    (assert (list-contains? (.-recommended-apis prof) "useActionState") "has recommended useActionState")
    true))

(df test-scout-pydantic-v2 [] -> Bool
  :d "Tests repository scouting on Pydantic v2 poetry lockfile"
  (let [(poetry-lock "[[package]]\nname = \"pydantic\"\nversion = \"2.6.1\"\n")
        (prof (rs/scout-repo "/backend" "poetry.lock" poetry-lock))]
    (assert (= (.-ecosystem prof) "python") "ecosystem is python")
    (assert (= (.-primary-framework prof) "pydantic") "framework is pydantic")
    (assert (list-contains? (.-forbidden-apis prof) ".dict()") "has forbidden .dict()")
    (assert (list-contains? (.-recommended-apis prof) ".model_dump()") "has recommended .model_dump()")
    true))

(df test-audit-code-clean [] -> Bool
  :d "Tests that idiomatic code passing all forbidden API checks is approved"
  (let [(pkg-json "{\n  \"dependencies\": {\n    \"react\": \"19.0.0\"\n  }\n}")
        (prof (rs/scout-repo "/app" "package.json" pkg-json))
        (clean-code "export function Form() { const [state, action] = useActionState(submitHandler, null); return <form action={action}/>; }")
        (res (rs/audit-code-diff clean-code prof))]
    (assert (.-allowed res) "clean code allowed")
    (assert (not (list-contains? (.-violations res) "useFormState")) "no violations in clean code")
    true))

(df test-audit-code-forbidden [] -> Bool
  :d "Tests that code calling forbidden APIs is blocked with violations"
  (let [(pkg-json "{\n  \"dependencies\": {\n    \"react\": \"19.0.0\"\n  }\n}")
        (prof (rs/scout-repo "/app" "package.json" pkg-json))
        (bad-code "export function Form() { const [state, action] = useFormState(submitHandler, null); return <form action={action}/>; }")
        (res (rs/audit-code-diff bad-code prof))]
    (assert (not (.-allowed res)) "forbidden code blocked")
    (assert (list-contains? (.-violations res) "useFormState") "violations contains useFormState")
    true))

(df test-format-profile-asn [] -> Bool
  :d "Tests formatting profile into dense ASN S-expression"
  (let [(prof (rs/make-empty-profile))
        (asn-str (rs/format-profile-asn prof))]
    (assert (string-contains? asn-str "(:repo-profile") "contains :repo-profile")
    (assert (string-contains? asn-str ":eco \"generic\"") "contains :eco generic")
    true))

(df run-repo-scout-tests [] -> Bool
  :d "Runs all repository scout unit test cases"
  (do
    (test-scout-react-19)
    (test-scout-pydantic-v2)
    (test-audit-code-clean)
    (test-audit-code-forbidden)
    (test-format-profile-asn)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-repo-scout-tests"
  (run-repo-scout-tests))
