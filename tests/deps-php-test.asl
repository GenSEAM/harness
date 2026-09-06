(module asl-harness/tests/deps-php-test
  :d "Unit tests for modern PHP 8.x attributes, lockfile inspection, and compatibility auditing."
  :x [run-tests]
  :i [(deps-php :a php)])

(df test-extract-composer-version [] -> Bool
  :d "Verifies extraction of package versions from composer.lock JSON."
  (let [(sample "{\n  \"packages\": [\n    {\n      \"name\": \"monolog/monolog\",\n      \"version\": \"3.4.0\"\n    }\n  ]\n}")
        (ver (php/extract-composer-version sample "monolog/monolog"))]
    (mt ver
      ((none) false)
      ((some v) (= v "3.4.0")))))

(df test-extract-php-attributes [] -> Bool
  :d "Verifies extraction of PHP 8.x attributes from source."
  (let [(code "<?php\n#[Route('/api/v1', methods: ['GET'])]\nclass ApiController {}\n#[ORM\\Id]\nprivate int $id;")
        (attrs (php/extract-php-attributes code))]
    (and (>= (list-length attrs) 2)
         (= (.-attribute-name (option-or (list-get attrs 0) (php/PhpAttribute :target-symbol "" :attribute-name "" :arguments "" :line 0))) "Route"))))

(df test-audit-php-compatibility [] -> Bool
  :d "Verifies detection of deprecated PHP 7 functions under PHP 8+."
  (let [(clean-code "<?php\n$fn = fn($x) => $x * 2;\necho $fn(5);")
        (dirty-code "<?php\n$f = create_function('$a', 'return $a * 2;');")
        (clean-rep (php/audit-php-compatibility clean-code "8.2"))
        (dirty-rep (php/audit-php-compatibility dirty-code "8.2"))]
    (and (.-compatible clean-rep)
         (and (not (.-compatible dirty-rep))
              (> (list-length (.-violations dirty-rep)) 0)))))

(df test-format-php-compatibility [] -> Bool
  :d "Verifies formatting of compatibility audit reports."
  (let [(clean-rep (php/PhpCompatibilityReport :target-version "8.2" :violations (list) :compatible true))
        (dirty-rep (php/PhpCompatibilityReport :target-version "8.2" :violations (list "Deprecated create_function") :compatible false))
        (fmt-c (php/format-php-compatibility clean-rep))
        (fmt-d (php/format-php-compatibility dirty-rep))]
    (and (string-contains? fmt-c "Fully Compatible")
         (string-contains? fmt-d "Violations Found"))))

(df run-tests [] -> Bool
  :d "Runs all PHP dependency and attribute tests."
  (and (test-extract-composer-version)
       (and (test-extract-php-attributes)
            (and (test-audit-php-compatibility)
                 (test-format-php-compatibility)))))
