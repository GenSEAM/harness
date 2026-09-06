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
      run-polyglot-tests]
  :i [(polyglot-ast :a pa)
      (deps-php :a dp)])

(df test-detect-source-language [] -> Bool
  :d "Tests detection of source language by file path extension"
  (let [(l-py (pa/detect-source-language "server/main.py"))
        (l-ts (pa/detect-source-language "src/components/App.tsx"))
        (l-go (pa/detect-source-language "cmd/daemon/main.go"))
        (l-rs (pa/detect-source-language "crates/core/src/lib.rs"))
        (l-php (pa/detect-source-language "app/Http/Controllers/UserController.php"))]
    (and (mt l-py ((lang-python) true) (_ false))
         (mt l-ts ((lang-typescript) true) (_ false))
         (mt l-go ((lang-go) true) (_ false))
         (mt l-rs ((lang-rust) true) (_ false))
         (mt l-php ((lang-php) true) (_ false)))))

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
    (and (= (.-total-symbols outline) 4)
         (> (string-length (pa/format-ast-outline outline)) 0))))

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
    (= (.-total-symbols outline) 3)))

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
    (= (.-total-symbols outline) 3)))

(df test-extract-polyglot-rust-ast [] -> Bool
  :d "Tests Rust fn, struct, and enum extraction"
  (let [(code (str "pub struct Config {\n"
                   "    pub port: u16,\n"
                   "}\n\n"
                   "pub enum Status {\n"
                   "    Active,\n"
                   "    Idle,\n"
                   "}\n\n"
                   "pub fn initialize() -> Config {\n"
                   "    Config { port: 8080 }\n"
                   "}\n"))
        (outline (pa/extract-ast-outline code "src/lib.rs"))]
    (= (.-total-symbols outline) 3)))

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
    (= (.-total-symbols outline) 3)))

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
    (mt v
      ((none) false)
      ((some ver) (= ver "7.8.1")))))

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
    (and (= (length attrs) 1)
         (let [(first-attr (option-or (list-get attrs 0) (dp/PhpAttribute :target-symbol "" :attribute-name "" :arguments "" :line 0)))]
           (= (.-attribute-name first-attr) "Route")))))

(df test-audit-php-compatibility [] -> Bool
  :d "Tests detection of deprecated functions in PHP 8+"
  (let [(code (str "<?php\n"
                   "$fn = create_function('$a', 'return $a * 2;');\n"
                   "echo $fn(5);\n"))
        (report8 (dp/audit-php-compatibility code "8.2"))
        (report7 (dp/audit-php-compatibility code "7.4"))]
    (and (not (.-compatible report8))
         (= (length (.-violations report8)) 1)
         (.-compatible report7))))

(df run-polyglot-tests [] -> Bool
  :d "Runs complete test suite for Polyglot AST and PHP engine"
  (and (test-detect-source-language)
       (test-extract-polyglot-python-ast)
       (test-extract-polyglot-typescript-ast)
       (test-extract-polyglot-go-ast)
       (test-extract-polyglot-rust-ast)
       (test-extract-polyglot-php-ast)
       (test-extract-composer-version)
       (test-extract-php-attributes)
       (test-audit-php-compatibility)))
