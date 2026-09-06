(module asl-harness/polyglot-ast
  :d "Polyglot AST Outline Extractor for Python, TypeScript, Go, Rust, and PHP in Pure ASL"
  :x [SourceLanguage
      PolyglotSymbol
      PolyglotOutline
      detect-source-language
      extract-python-symbols
      extract-typescript-symbols
      extract-go-symbols
      extract-rust-symbols
      extract-php-symbols
      extract-ast-outline
      format-ast-outline]
  :i [(core/strings :a s)])

(dfe SourceLanguage
  (:c lang-python [] "Python source (.py)")
  (:c lang-typescript [] "TypeScript / JavaScript source (.ts, .tsx, .js, .jsx)")
  (:c lang-go [] "Go source (.go)")
  (:c lang-rust [] "Rust source (.rs)")
  (:c lang-php [] "PHP source (.php)")
  (:c lang-unknown [] "Unrecognized or unsupported language"))

(dfs PolyglotSymbol
  (:f name Str "Symbol identifier e.g. function or class name")
  (:f kind Str "Classification: fn, class, interface, type, struct, enum")
  (:f line I64 "1-indexed line number in source")
  (:f signature Str "Brief declaration line / signature")
  (:f docstring Str "Associated doc comment or empty"))

(dfs PolyglotOutline
  (:f language SourceLanguage "Detected source language")
  (:f file-path Str "Originating source file path")
  (:f symbols (List PolyglotSymbol) "Extracted top-level and type symbols")
  (:f total-symbols I64 "Count of extracted symbols"))

(df detect-source-language [(path Str)] -> SourceLanguage
  :d "Determines SourceLanguage from file path extension."
  (cond
    ((string-ends-with? path ".py") (lang-python))
    ((or (string-ends-with? path ".ts")
         (string-ends-with? path ".tsx")
         (string-ends-with? path ".js")
         (string-ends-with? path ".jsx")) (lang-typescript))
    ((string-ends-with? path ".go") (lang-go))
    ((string-ends-with? path ".rs") (lang-rust))
    ((string-ends-with? path ".php") (lang-php))
    (true (lang-unknown))))

(df extract-word-after [(line Str) (keyword Str)] -> Str
  :d "Extracts the word immediately following keyword."
  (let [(idx (string-index-of line keyword))]
    (mt idx
      ((none) "")
      ((some pos)
       (let [(rest (option-or (string-slice line (+ pos (string-length keyword)) (string-length line)) ""))
             (trimmed (string-trim rest))
             (first-space (string-index-of trimmed " "))
             (first-paren (string-index-of trimmed "("))
             (first-colon (string-index-of trimmed ":"))
             (first-brace (string-index-of trimmed "{"))
             (first-bracket (string-index-of trimmed "<"))
             (stop-idx (min-positive-index (list first-space first-paren first-colon first-brace first-bracket)))]
         (if (> stop-idx 0)
             (option-or (string-slice trimmed 0 stop-idx) trimmed)
             trimmed))))))

(df min-positive-index [(candidates (List (Option I64)))] -> I64
  :d "Finds the minimum non-negative index among optional positions."
  (foldl (fn [(acc I64) (cand (Option I64))] -> I64
           (mt cand
             ((none) acc)
             ((some v)
              (if (and (>= v 0) (or (= acc 0) (< v acc)))
                  v
                  acc))))
         0
         candidates))

(df extract-python-symbols [(code Str) (path Str)] -> (List PolyglotSymbol)
  :d "Extracts def and class symbols from Python code."
  (let [(lines (string-split code "\n"))
        (syms (list))]
    (foldl (fn [(acc (List PolyglotSymbol)) (pair (Tuple2 I64 Str))] -> (List PolyglotSymbol)
             (let [(line-num (+ (tuple2-first pair) 1))
                   (raw-line (tuple2-second pair))
                   (trimmed (string-trim raw-line))]
               (cond
                 ((string-starts-with? trimmed "def ")
                  (let [(name (extract-word-after trimmed "def "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "fn" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((string-starts-with? trimmed "async def ")
                  (let [(name (extract-word-after trimmed "async def "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "fn" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((string-starts-with? trimmed "class ")
                  (let [(name (extract-word-after trimmed "class "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "class" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 (true acc))))
           syms
           (enumerate lines))))

(df extract-typescript-symbols [(code Str) (path Str)] -> (List PolyglotSymbol)
  :d "Extracts function, class, interface, and type symbols from TS/JS code."
  (let [(lines (string-split code "\n"))
        (syms (list))]
    (foldl (fn [(acc (List PolyglotSymbol)) (pair (Tuple2 I64 Str))] -> (List PolyglotSymbol)
             (let [(line-num (+ (tuple2-first pair) 1))
                   (raw-line (tuple2-second pair))
                   (trimmed (string-trim raw-line))]
               (cond
                 ((or (string-starts-with? trimmed "export function ")
                      (string-starts-with? trimmed "function "))
                  (let [(name (if (string-starts-with? trimmed "export function ")
                                  (extract-word-after trimmed "export function ")
                                  (extract-word-after trimmed "function ")))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "fn" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((or (string-starts-with? trimmed "export class ")
                      (string-starts-with? trimmed "class "))
                  (let [(name (if (string-starts-with? trimmed "export class ")
                                  (extract-word-after trimmed "export class ")
                                  (extract-word-after trimmed "class ")))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "class" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((or (string-starts-with? trimmed "export interface ")
                      (string-starts-with? trimmed "interface "))
                  (let [(name (if (string-starts-with? trimmed "export interface ")
                                  (extract-word-after trimmed "export interface ")
                                  (extract-word-after trimmed "interface ")))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "interface" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((or (string-starts-with? trimmed "export type ")
                      (string-starts-with? trimmed "type "))
                  (let [(name (if (string-starts-with? trimmed "export type ")
                                  (extract-word-after trimmed "export type ")
                                  (extract-word-after trimmed "type ")))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "type" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 (true acc))))
           syms
           (enumerate lines))))

(df extract-go-symbols [(code Str) (path Str)] -> (List PolyglotSymbol)
  :d "Extracts func, type struct, and interface symbols from Go code."
  (let [(lines (string-split code "\n"))
        (syms (list))]
    (foldl (fn [(acc (List PolyglotSymbol)) (pair (Tuple2 I64 Str))] -> (List PolyglotSymbol)
             (let [(line-num (+ (tuple2-first pair) 1))
                   (raw-line (tuple2-second pair))
                   (trimmed (string-trim raw-line))]
               (cond
                 ((string-starts-with? trimmed "func ")
                  (let [(name (extract-word-after trimmed "func "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "fn" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((and (string-starts-with? trimmed "type ") (string-contains? trimmed " struct"))
                  (let [(name (extract-word-after trimmed "type "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "struct" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((and (string-starts-with? trimmed "type ") (string-contains? trimmed " interface"))
                  (let [(name (extract-word-after trimmed "type "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "interface" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 (true acc))))
           syms
           (enumerate lines))))

(df extract-rust-symbols [(code Str) (path Str)] -> (List PolyglotSymbol)
  :d "Extracts fn, struct, enum, and impl symbols from Rust code."
  (let [(lines (string-split code "\n"))
        (syms (list))]
    (foldl (fn [(acc (List PolyglotSymbol)) (pair (Tuple2 I64 Str))] -> (List PolyglotSymbol)
             (let [(line-num (+ (tuple2-first pair) 1))
                   (raw-line (tuple2-second pair))
                   (trimmed (string-trim raw-line))]
               (cond
                 ((or (string-starts-with? trimmed "pub fn ")
                      (string-starts-with? trimmed "fn "))
                  (let [(name (if (string-starts-with? trimmed "pub fn ")
                                  (extract-word-after trimmed "pub fn ")
                                  (extract-word-after trimmed "fn ")))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "fn" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((or (string-starts-with? trimmed "pub struct ")
                      (string-starts-with? trimmed "struct "))
                  (let [(name (if (string-starts-with? trimmed "pub struct ")
                                  (extract-word-after trimmed "pub struct ")
                                  (extract-word-after trimmed "struct ")))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "struct" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((or (string-starts-with? trimmed "pub enum ")
                      (string-starts-with? trimmed "enum "))
                  (let [(name (if (string-starts-with? trimmed "pub enum ")
                                  (extract-word-after trimmed "pub enum ")
                                  (extract-word-after trimmed "enum ")))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "enum" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((string-starts-with? trimmed "impl ")
                  (let [(name (extract-word-after trimmed "impl "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "impl" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 (true acc))))
           syms
           (enumerate lines))))

(df extract-php-symbols [(code Str) (path Str)] -> (List PolyglotSymbol)
  :d "Extracts function, class, interface, and enum symbols from PHP code."
  (let [(lines (string-split code "\n"))
        (syms (list))]
    (foldl (fn [(acc (List PolyglotSymbol)) (pair (Tuple2 I64 Str))] -> (List PolyglotSymbol)
             (let [(line-num (+ (tuple2-first pair) 1))
                   (raw-line (tuple2-second pair))
                   (trimmed (string-trim raw-line))]
               (cond
                 ((or (string-starts-with? trimmed "function ")
                      (string-starts-with? trimmed "public function ")
                      (string-starts-with? trimmed "protected function ")
                      (string-starts-with? trimmed "private function ")
                      (string-starts-with? trimmed "public static function "))
                  (let [(name (cond
                                ((string-starts-with? trimmed "public static function ") (extract-word-after trimmed "public static function "))
                                ((string-starts-with? trimmed "public function ") (extract-word-after trimmed "public function "))
                                ((string-starts-with? trimmed "protected function ") (extract-word-after trimmed "protected function "))
                                ((string-starts-with? trimmed "private function ") (extract-word-after trimmed "private function "))
                                (true (extract-word-after trimmed "function "))))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "fn" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((or (string-starts-with? trimmed "class ")
                      (string-starts-with? trimmed "final class ")
                      (string-starts-with? trimmed "abstract class "))
                  (let [(name (cond
                                ((string-starts-with? trimmed "final class ") (extract-word-after trimmed "final class "))
                                ((string-starts-with? trimmed "abstract class ") (extract-word-after trimmed "abstract class "))
                                (true (extract-word-after trimmed "class "))))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "class" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((string-starts-with? trimmed "interface ")
                  (let [(name (extract-word-after trimmed "interface "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "interface" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 ((string-starts-with? trimmed "enum ")
                  (let [(name (extract-word-after trimmed "enum "))]
                    (if (> (string-length name) 0)
                        (append acc (PolyglotSymbol :name name :kind "enum" :line line-num :signature trimmed :docstring ""))
                        acc)))
                 (true acc))))
           syms
           (enumerate lines))))

(df extract-ast-outline [(code Str) (path Str)] -> PolyglotOutline
  :d "Detects language and extracts symbols into unified PolyglotOutline."
  (let [(lang (detect-source-language path))
        (syms (mt lang
                ((lang-python) (extract-python-symbols code path))
                ((lang-typescript) (extract-typescript-symbols code path))
                ((lang-go) (extract-go-symbols code path))
                ((lang-rust) (extract-rust-symbols code path))
                ((lang-php) (extract-php-symbols code path))
                ((lang-unknown) (list))))]
    (PolyglotOutline
      :language lang
      :file-path path
      :symbols syms
      :total-symbols (length syms))))

(df format-ast-outline [(outline PolyglotOutline)] -> Str
  :d "Renders a compact markdown representation of the PolyglotOutline."
  (let [(header (str "### Outline: " (.-file-path outline) " (" (show (.-total-symbols outline)) " symbols)\n"))]
    (foldl (fn [(acc Str) (sym PolyglotSymbol)] -> Str
             (str acc "- [" (.-kind sym) "] `" (.-name sym) "` (line " (show (.-line sym)) "): `" (.-signature sym) "`\n"))
           header
           (.-symbols outline))))
