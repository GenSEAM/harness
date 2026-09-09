(module asl-harness/paradigm-spec-test
  :d "Unit tests verifying harness epistemic paradigm specification conformance to decisions d40 through d49 and action ontology completeness."
  :x [validate-paradigm-spec
      verify-action-ontology
      run-tests]
  :i [])

(df contains-id? [(items (List Str)) (target Str)] -> Bool
  :d "Checks if a target identifier exists in the list."
  (fold (fn [(acc Bool) (item Str)] -> Bool
          (if acc true (= item target)))
        false
        items))

(df has-all-ids? [(collection (List Str)) (expected (List Str))] -> Bool
  :d "Checks if all expected identifiers exist within the collection."
  (fold (fn [(acc Bool) (target Str)] -> Bool
          (if acc (contains-id? collection target) false))
        true
        expected))

(df has-sigil-token? [(text Str)] -> Bool
  :d "Checks if a string contains prohibited sigils."
  (or (string-contains? text "@")
      (string-contains? text "#")))

(df conforms-to-decisions? [(decisions (List Str))] -> Bool
  :d "Verifies that a list of decisions covers all 10 canonical decisions d40 through d49 without sigils."
  (let [(expected (list "d40" "d41" "d42" "d43" "d44" "d45" "d46" "d47" "d48" "d49"))
        (has-sigils (fold (fn [(acc Bool) (item Str)] -> Bool
                            (if acc true (has-sigil-token? item)))
                          false
                          decisions))]
    (and (= (list-length decisions) 10)
         (and (not has-sigils)
              (has-all-ids? decisions expected)))))

(df has-valid-ontology? [(actions (List Str)) (roles (List Str))] -> Bool
  :d "Verifies the canonical 7 action ontology primitives and agent teleological roles."
  (let [(exp-acts (list "perceive" "transliterate" "deliberate" "mutate" "verify" "reconcile" "compress"))
        (exp-roles (list "scout" "transliterator" "planner" "implementer" "auditor" "meta-audit" "compactor"))
        (has-co-author (contains-id? roles "co-author"))]
    (and (= (list-length actions) 7)
         (and (= (list-length roles) 7)
              (and (not has-co-author)
                   (and (has-all-ids? actions exp-acts)
                        (has-all-ids? roles exp-roles)))))))

(df validate-paradigm-spec [] -> Bool
  :d "Validates that the epistemic paradigm conforms to decisions d40 through d49 with dual-case checks."
  (let [(canonical-decisions (list "d40" "d41" "d42" "d43" "d44" "d45" "d46" "d47" "d48" "d49"))
        (incomplete-decisions (list "d40" "d41" "d42" "d43"))
        (sigil-tainted (list "d40" "@d41" "d42" "d43" "d44" "d45" "d46" "d47" "d48" "d49"))
        (empty-decisions (list))]
    (assert (= (list-length canonical-decisions) 10) "Paradigm must synchronize exactly 10 decisions d40-d49")
    (assert (conforms-to-decisions? canonical-decisions) "Canonical decisions d40-d49 must pass validation")
    (assert (not (conforms-to-decisions? incomplete-decisions)) "Incomplete decisions must fail validation")
    (assert (not (conforms-to-decisions? sigil-tainted)) "Sigil-tainted decisions must fail validation")
    (assert (not (conforms-to-decisions? empty-decisions)) "Empty decision set must fail validation")
    true))

(df verify-action-ontology [] -> Bool
  :d "Verifies the 7 action ontology roles and primitives with dual-case checks."
  (let [(actions (list "perceive" "transliterate" "deliberate" "mutate" "verify" "reconcile" "compress"))
        (roles (list "scout" "transliterator" "planner" "implementer" "auditor" "meta-audit" "compactor"))
        (invalid-actions (list "perceive" "arbitrary-code-exec" "mutate"))
        (forbidden-roles (list "scout" "transliterator" "planner" "implementer" "auditor" "meta-audit" "co-author"))]
    (assert (= (list-length actions) 7) "Ontology must define exactly 7 canonical action primitives")
    (assert (= (list-length roles) 7) "Ontology must define exactly 7 teleological agent roles")
    (assert (has-valid-ontology? actions roles) "Canonical actions and roles must verify cleanly")
    (assert (not (has-valid-ontology? invalid-actions roles)) "Invalid action primitive must be rejected")
    (assert (not (has-valid-ontology? actions forbidden-roles)) "Forbidden co-author role must be rejected")
    true))

(df run-tests [] -> Bool
  :d "Runs all paradigm specification tests under strict falsification."
  (do
    (assert (validate-paradigm-spec) "validate-paradigm-spec must pass")
    (assert (verify-action-ontology) "verify-action-ontology must pass")
    true))

(run-tests)
