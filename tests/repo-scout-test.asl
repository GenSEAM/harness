(module asl-harness/repo-scout-test
  :d "Unit verification test suite for Autonomous Repository Scout"
  :x [test-scout-react-19
      test-scout-pydantic-v2
      test-audit-code-clean
      test-audit-code-forbidden
      test-format-profile-asn
      run-repo-scout-tests]
  :i [(repo-scout :a rs)])

(df test-scout-react-19 [] -> Bool
  :d "Tests repository scouting on React 19 lockfile"
  (let [(pkg-json "{\n  \"dependencies\": {\n    \"react\": \"19.0.0\"\n  }\n}")
        (prof (rs/scout-repo "/app" "package.json" pkg-json))]
    (and (= (.-ecosystem prof) "js-ts")
         (and (= (.-primary-framework prof) "react")
              (and (list-contains? (.-forbidden-apis prof) "useFormState")
                   (list-contains? (.-recommended-apis prof) "useActionState"))))))

(df test-scout-pydantic-v2 [] -> Bool
  :d "Tests repository scouting on Pydantic v2 poetry lockfile"
  (let [(poetry-lock "[[package]]\nname = \"pydantic\"\nversion = \"2.6.1\"\n")
        (prof (rs/scout-repo "/backend" "poetry.lock" poetry-lock))]
    (and (= (.-ecosystem prof) "python")
         (and (= (.-primary-framework prof) "pydantic")
              (and (list-contains? (.-forbidden-apis prof) ".dict()")
                   (list-contains? (.-recommended-apis prof) ".model_dump()"))))))

(df test-audit-code-clean [] -> Bool
  :d "Tests that idiomatic code passing all forbidden API checks is approved"
  (let [(pkg-json "{\n  \"dependencies\": {\n    \"react\": \"19.0.0\"\n  }\n}")
        (prof (rs/scout-repo "/app" "package.json" pkg-json))
        (clean-code "export function Form() { const [state, action] = useActionState(submitHandler, null); return <form action={action}/>; }")
        (res (rs/audit-code-diff clean-code prof))]
    (.-allowed res)))

(df test-audit-code-forbidden [] -> Bool
  :d "Tests that code calling forbidden APIs is blocked with violations"
  (let [(pkg-json "{\n  \"dependencies\": {\n    \"react\": \"19.0.0\"\n  }\n}")
        (prof (rs/scout-repo "/app" "package.json" pkg-json))
        (bad-code "export function Form() { const [state, action] = useFormState(submitHandler, null); return <form action={action}/>; }")
        (res (rs/audit-code-diff bad-code prof))]
    (and (not (.-allowed res))
         (list-contains? (.-violations res) "useFormState"))))

(df test-format-profile-asn [] -> Bool
  :d "Tests formatting profile into dense ASN S-expression"
  (let [(prof (rs/make-empty-profile))
        (asn-str (rs/format-profile-asn prof))]
    (and (string-contains? asn-str "(:repo-profile")
         (string-contains? asn-str ":eco \"generic\""))))

(df run-repo-scout-tests [] -> Bool
  :d "Runs all repository scout unit test cases"
  (and (test-scout-react-19)
       (and (test-scout-pydantic-v2)
            (and (test-audit-code-clean)
                 (and (test-audit-code-forbidden)
                      (test-format-profile-asn))))))
