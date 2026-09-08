(module asl-harness/polyglot-ast-test
  :d "Unit verification test suite for Polyglot AST Engine and Modern PHP 8.x Support"
  :x [test-detect-source-language
      test-extract-polyglot-python-ast
      test-extract-polyglot-typescript-ast
      test-extract-polyglot-go-ast
      test-extract-polyglot-rust-ast
      test-extract-polyglot-php-ast
      test-extract-composer-version
      test-extract-php-attributes
      test-audit-php-compatibility
      run-polyglot-tests
      run-tests]
  :i [(polyglot-ast :a pa)
      (deps-php :a dp)])

(df test-detect-source-language [] -> Bool
  :d "Tests detection of source language by file path extension"
  (let [(l-py (pa/detect-source-language "server/main.py"))
        (l-ts (pa/detect-source-language "src/components/App.tsx"))
        (l-go (pa/detect-source-language "cmd/daemon/main.go"))
        (l-rs (pa/detect-source-language "crates/core/src/lib.rs"))
        (l-php (pa/detect-source-language "app/Http/Controllers/UserController.php"))]
    (assert (match l-py ((lang-python) true) (_ false)) "py is lang-python")
    (assert (match l-ts ((lang-typescript) true) (_ false)) "ts is lang-typescript")
    (assert (match l-go ((lang-go) true) (_ false)) "go is lang-go")
    (assert (match l-rs ((lang-rust) true) (_ false)) "rs is lang-rust")
    (assert (match l-php ((lang-php) true) (_ false)) "php is lang-php")
    true))

(df test-extract-polyglot-python-ast [] -> Bool
  :d "Tests Python function and class outline extraction"
  (let [(code (str "import os\n\n"
                   "class DataPipeline:\n"
                   "    def __init__(self):\n"
                   "        pass\n\n"
                   "    def process_records(self, batch):\n"
                   "        return batch\n\n"
                   "def main():\n"
                   "    p = DataPipeline()\n"))
        (outline (pa/extract-ast-outline code "pipeline.py"))]
    (assert (= (.-total-symbols outline) 4) "python total symbols is 4")
    (assert (> (string-length (pa/format-ast-outline outline)) 0) "formatted outline non-empty")
    true))

(df test-extract-polyglot-typescript-ast [] -> Bool
  :d "Tests TypeScript function, class, and interface extraction"
  (let [(code (str "import React from 'react';\n\n"
                   "export interface UserProfile {\n"
                   "  id: string;\n"
                   "  email: string;\n"
                   "}\n\n"
                   "export type UserRole = 'admin' | 'viewer';\n\n"
                   "export function renderHeader(profile: UserProfile): JSX.Element {\n"
                   "  return <div>{profile.email}</div>;\n"
                   "}\n"))
        (outline (pa/extract-ast-outline code "src/UserProfile.tsx"))]
    (assert (= (.-total-symbols outline) 3) "ts total symbols is 3")
    true))

(df test-extract-polyglot-go-ast [] -> Bool
  :d "Tests Go function, struct, and interface extraction"
  (let [(code (str "package main\n\n"
                   "type WorkerPool struct {\n"
                   "    size int\n"
                   "}\n\n"
                   "type TaskRunner interface {\n"
                   "    Run() error\n"
                   "}\n\n"
                   "func StartServer(port int) error {\n"
                   "    return nil\n"
                   "}\n"))
        (outline (pa/extract-ast-outline code "main.go"))]
    (assert (= (.-total-symbols outline) 3) "go total symbols is 3")
    true))

(df test-extract-polyglot-rust-ast [] -> Bool
  :d "Tests Rust fn, struct, enum, and generic fn extraction"
  (let [(code (str "pub struct Config {\n"
                   "    pub port: u16,\n"
                   "}\n\n"
                   "pub enum Status {\n"
                   "    Active,\n"
                   "    Idle,\n"
                   "}\n\n"
                   "pub fn initialize() -> Config {\n"
                   "    Config { port: 8080 }\n"
                   "}\n\n"
                   "pub fn solve<T>(input: T) -> T {\n"
                   "    input\n"
                   "}\n"))
        (outline (pa/extract-ast-outline code "src/lib.rs"))
        (last-sym (option-or (list-get (.-symbols outline) 3)
                             (pa/PolyglotSymbol :name "" :kind "" :line 0 :signature "" :docstring "")))]
    (assert (= (.-total-symbols outline) 4) "rust total symbols is 4")
    (assert (= (.-name last-sym) "solve") "last sym is solve")
    true))

(df test-extract-polyglot-php-ast [] -> Bool
  :d "Tests PHP function, class, and interface extraction"
  (let [(code (str "<?php\n\n"
                   "namespace App\\Services;\n\n"
                   "interface PaymentGateway {\n"
                   "    public function charge(int $amount): bool;\n"
                   "}\n\n"
                   "class StripeGateway implements PaymentGateway {\n"
                   "    public function charge(int $amount): bool {\n"
                   "        return true;\n"
                   "    }\n"
                   "}\n"))
        (outline (pa/extract-ast-outline code "app/Services/StripeGateway.php"))]
    (assert (= (.-total-symbols outline) 3) "php total symbols is 3")
    true))

(df test-extract-composer-version [] -> Bool
  :d "Tests extracting pinned package version from composer.lock"
  (let [(composer-lock (str "{\n"
                           "    \"packages\": [\n"
                           "        {\n"
                           "            \"name\": \"symfony/http-foundation\",\n"
                           "            \"version\": \"v6.3.2\"\n"
                           "        },\n"
                           "        {\n"
                           "            \"name\": \"guzzlehttp/guzzle\",\n"
                           "            \"version\": \"7.8.1\"\n"
                           "        }\n"
                           "    ]\n"
                           "}\n"))
        (v (dp/extract-composer-version composer-lock "guzzlehttp/guzzle"))]
    (assert (match v
              ((none) false)
              ((some ver) (= ver "7.8.1"))) "composer version is 7.8.1")
    true))

(df test-extract-php-attributes [] -> Bool
  :d "Tests PHP 8.x attribute extraction"
  (let [(code (str "<?php\n\n"
                   "class ApiController {\n"
                   "    #[Route('/api/v1/users', methods: ['GET'])]\n"
                   "    public function getUsers() {\n"
                   "        return [];\n"
                   "    }\n"
                   "}\n"))
        (attrs (dp/extract-php-attributes code))]
    (assert (= (length attrs) 1) "1 php attribute found")
    (let [(first-attr (option-or (list-get attrs 0) (dp/PhpAttribute :target-symbol "" :attribute-name "" :arguments "" :line 0)))]
      (assert (= (.-attribute-name first-attr) "Route") "attribute is Route"))
    true))

(df test-audit-php-compatibility [] -> Bool
  :d "Tests detection of deprecated functions in PHP 8+"
  (let [(code (str "<?php\n"
                   "$fn = create_function('$a', 'return $a * 2;');\n"
                   "echo $fn(5);\n"))
        (report8 (dp/audit-php-compatibility code "8.2"))
        (report7 (dp/audit-php-compatibility code "7.4"))]
    (assert (not (.-compatible report8)) "report8 not compatible")
    (assert (= (length (.-violations report8)) 1) "1 violation in report8")
    (assert (.-compatible report7) "report7 compatible")
    true))

(df run-polyglot-tests [] -> Bool
  :d "Runs complete test suite for Polyglot AST and PHP engine"
  (do
    (test-detect-source-language)
    (test-extract-polyglot-python-ast)
    (test-extract-polyglot-typescript-ast)
    (test-extract-polyglot-go-ast)
    (test-extract-polyglot-rust-ast)
    (test-extract-polyglot-php-ast)
    (test-extract-composer-version)
    (test-extract-php-attributes)
    (test-audit-php-compatibility)
    true))

(df run-tests [] -> Bool
  :d "Alias for run-polyglot-tests"
  (run-polyglot-tests))
