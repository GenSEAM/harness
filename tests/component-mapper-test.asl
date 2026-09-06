(module asl-harness/component-mapper-test
  :d "Unit verification test suite for Component Usage Mapper and Design Policy Guard"
  :x [test-scan-component-usages
      test-batch-transform-classes
      test-audit-design-policy
      test-hunt-library-residues
      test-format-component-map
      run-component-tests]
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
    (and (= (.-total-components cmap) 2)
         (= (.-total-native cmap) 2))))

(df test-batch-transform-classes [] -> Bool
  :d "Tests 1-tool-call batch replacement of classes across code"
  (let [(rule (cm/BatchTransformRule
                :target-tag ""
                :old-class "btn-old"
                :new-class "btn-primary"
                :scope-pattern "/pages/"))
        (res (cm/batch-transform-classes (sample-jsx-code) rule))
        ;; Substring collision guard test
        (rule-collision (cm/BatchTransformRule
                          :target-tag ""
                          :old-class "btn"
                          :new-class "btn-new"
                          :scope-pattern ""))
        (res-collision (cm/batch-transform-classes "<div className=\"btn-primary\">" rule-collision))]
    (and (= (.-occurrences-replaced res) 2)
         (string-contains? (.-modified-content res) "btn-primary")
         (not (string-contains? (.-modified-content res) "btn-old"))
         (= (.-occurrences-replaced res-collision) 0)
         (= (.-modified-content res-collision) "<div className=\"btn-primary\">"))))

(df test-audit-design-policy [] -> Bool
  :d "Tests design policy check flagging raw native inputs"
  (let [(cmap (cm/scan-component-usages (sample-jsx-code) "src/pages/UserPage.tsx"))
        (report (cm/audit-design-policy cmap (list "input" "button") "Input"))]
    (and (not (.-passed report))
         (let [(v (option-or (list-head (.-violations report))
                             (cm/PolicyViolation :file-path "" :line 0 :forbidden-tag "" :recommended-replacement "" :rule-name "")))]
           (= (.-forbidden-tag v) "input")))))

(df test-hunt-library-residues [] -> Bool
  :d "Tests detection of decommissioned library remnants"
  (let [(report (cm/hunt-library-residues (sample-jsx-code) "src/pages/UserPage.tsx" "lodash" (list "debounce" "throttle")))]
    (and (not (.-clean report))
         (> (list-length (.-matches report)) 0))))

(df test-format-component-map [] -> Bool
  :d "Tests formatting component map as dense ASN"
  (let [(cmap (cm/scan-component-usages (sample-jsx-code) "src/pages/UserPage.tsx"))
        (asn-str (cm/format-component-map cmap))]
    (and (string-contains? asn-str "(:component-map")
         (and (string-contains? asn-str ":components 2")
              (string-contains? asn-str ":native 2")))))

(df run-component-tests [] -> Bool
  :d "Runs all component mapper unit test cases"
  (and (test-scan-component-usages)
       (and (test-batch-transform-classes)
            (and (test-audit-design-policy)
                 (and (test-hunt-library-residues)
                      (test-format-component-map))))))
