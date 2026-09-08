(module asl-harness/component-mapper-test
  :d "Unit verification test suite for Component Usage Mapper and Design Policy Guard"
  :x [test-scan-component-usages
      test-batch-transform-classes
      test-audit-design-policy
      test-hunt-library-residues
      test-format-component-map
      run-component-tests
      run-tests]
  :i [(component-mapper :a cm)])

(df sample-jsx-code [] -> Str
  :d "Sample React JSX component source"
  (str "import React from 'react';\n"
       "import { Modal, Button } from '@/components/ui';\n"
       "import _ from 'lodash';\n\n"
       "export function UserPage() {\n"
       "  return (\n"
       "    <div className=\"container p-4\">\n"
       "      <Modal title=\"User Form\">\n"
       "        <input type=\"text\" className=\"btn-old input-text\" />\n"
       "        <Button className=\"btn-old\">Submit</Button>\n"
       "      </Modal>\n"
       "    </div>\n"
       "  );\n"
       "}\n"))

(df test-scan-component-usages [] -> Bool
  :d "Tests scanning JSX to distinguish custom components from native tags"
  (let [(cmap (cm/scan-component-usages (sample-jsx-code) "src/pages/UserPage.tsx"))]
    (assert (= (.-total-components cmap) 2) "two custom components found")
    (assert (= (.-total-native cmap) 2) "two native tags found")
    true))

(df test-batch-transform-classes [] -> Bool
  :d "Tests 1-tool-call batch replacement of classes across code"
  (let [(rule (cm/BatchTransformRule
                :target-tag ""
                :old-class "btn-old"
                :new-class "btn-primary"
                :scope-pattern "/pages/"))
        (res (cm/batch-transform-classes (sample-jsx-code) rule))
        (rule-collision (cm/BatchTransformRule
                          :target-tag ""
                          :old-class "btn"
                          :new-class "btn-new"
                          :scope-pattern ""))
        (res-collision (cm/batch-transform-classes "<div className=\"btn-primary\">" rule-collision))]
    (assert (= (.-occurrences-replaced res) 2) "two occurrences replaced")
    (assert (string-contains? (.-modified-content res) "btn-primary") "modified contains btn-primary")
    (assert (not (string-contains? (.-modified-content res) "btn-old")) "btn-old removed")
    (assert (= (.-occurrences-replaced res-collision) 0) "zero collision replaced")
    (assert (= (.-modified-content res-collision) "<div className=\"btn-primary\">") "collision untouched")
    true))

(df test-audit-design-policy [] -> Bool
  :d "Tests design policy check flagging raw native inputs"
  (let [(cmap (cm/scan-component-usages (sample-jsx-code) "src/pages/UserPage.tsx"))
        (report (cm/audit-design-policy cmap (list "input" "button") "Input"))]
    (assert (not (.-passed report)) "native inputs fail design policy")
    (let [(v (option-or (list-head (.-violations report))
                        (cm/PolicyViolation :file-path "" :line 0 :forbidden-tag "" :recommended-replacement "" :rule-name "")))]
      (assert (= (.-forbidden-tag v) "input") "violation forbidden tag is input"))
    true))

(df test-hunt-library-residues [] -> Bool
  :d "Tests detection of decommissioned library remnants"
  (let [(report (cm/hunt-library-residues (sample-jsx-code) "src/pages/UserPage.tsx" "lodash" (list "debounce" "throttle")))]
    (assert (not (.-clean report)) "lodash import detected as unclean")
    (assert (> (list-length (.-matches report)) 0) "matches found")
    true))

(df test-format-component-map [] -> Bool
  :d "Tests formatting component map as dense ASN"
  (let [(cmap (cm/scan-component-usages (sample-jsx-code) "src/pages/UserPage.tsx"))
        (asn-str (cm/format-component-map cmap))]
    (assert (string-contains? asn-str "(:component-map") "contains :component-map")
    (assert (string-contains? asn-str ":components 2") "contains :components 2")
    (assert (string-contains? asn-str ":native 2") "contains :native 2")
    true))

(df run-component-tests [] -> Bool
  :d "Runs all component mapper unit test cases"
  (do
    (test-scan-component-usages)
    (test-batch-transform-classes)
    (test-audit-design-policy)
    (test-hunt-library-residues)
    (test-format-component-map)
    true))

(df run-tests [] -> Bool
  (run-component-tests))
