(module asl-harness/anti-hallucination
  :d "Pure AgentScript In-Memory Anti-Hallucination FSM and Delimiter Balancer"
  :x [ThinkingResult ToolCallResult FsmRepairReport repair-and-normalize]
  :i [(asl-parser/balance :a bal)])

(dfs ThinkingResult
  (:f thinking Str "Chain-of-thought tokens extracted from <think>")
  (:f code Str "Clean executable code without thinking preamble"))

(dfs ToolCallResult
  (:f code Str "Extracted payload or raw code")
  (:f tool-kind Str "Detected format: svg, html, or direct"))

(dfs FsmRepairReport
  (:f raw Str "Original raw streaming response from LLM")
  (:f clean-code Str "Sanitized, balanced and normalized code")
  (:f thinking Str "Isolated chain-of-thought analysis")
  (:f tool-kind Str "Target execution environment")
  (:f open-delta I64 "Parentheses balance delta")
  (:f repaired Bool "Whether structural repairs were applied"))

(df extract-thinking [(raw Str)] -> ThinkingResult
  :d "Separates reasoning thoughts inside <think>...</think> from code"
  (if (and (string-contains? raw "<think>") (string-contains? raw "</think>"))
    (let [(p1 (string-split raw "<think>"))
          (pre (option-or (list-head p1) ""))
          (rest (option-or (list-head (list-drop p1 1)) ""))
          (p2 (string-split rest "</think>"))
          (think (option-or (list-head p2) ""))
          (post (option-or (list-head (list-drop p2 1)) ""))
          (code (str pre post))]
      (ThinkingResult :thinking (string-trim think) :code (string-trim code)))
    (if (string-contains? raw "<think>")
      (let [(p1 (string-split raw "<think>"))
            (think (option-or (list-head (list-drop p1 1)) ""))]
        (ThinkingResult :thinking (string-trim think) :code ""))
      (ThinkingResult :thinking "" :code raw))))

(df strip-markdown-fences [(raw Str)] -> Str
  :d "Cleans code blocks and extracts raw content from markdown code fences"
  (let [(th (extract-thinking raw))
        (text (string-trim (.-code th)))
        (clean1 (string-replace text "```asn" ""))
        (clean2 (string-replace clean1 "```asl" ""))
        (clean3 (string-replace clean2 "```html" ""))
        (clean4 (string-replace clean3 "```svg" ""))
        (clean5 (string-replace clean4 "```javascript" ""))
        (clean6 (string-replace clean5 "```js" ""))
        (clean7 (string-replace clean6 "```css" ""))
        (clean8 (string-replace clean7 "```json" ""))
        (clean9 (string-replace clean8 "```" ""))]
    (string-trim clean9)))

(df balance-delimiters [(raw Str)] -> Str
  :d "Balances unclosed parentheses in S-expressions with quote and escape awareness via canonical asl-parser/balance."
  (let [(delta (bal/count-unclosed-parens raw))]
    (if (> delta 0)
      (string-concat raw (string-repeat ")" delta))
      raw)))

(df extract-toolcall-kind [(raw Str)] -> ToolCallResult
  :d "Identifies format: svg, html, or direct"
  (let [(clean (strip-markdown-fences raw))]
    (cond
      [(string-contains? clean "(:svg") (ToolCallResult :code clean :tool-kind "svg")]
      [(string-contains? clean "<svg") (ToolCallResult :code clean :tool-kind "svg")]
      [(or (string-contains? clean "<html") (string-contains? clean "<!DOCTYPE")) (ToolCallResult :code clean :tool-kind "html")]
      [(string-contains? clean "<canvas") (ToolCallResult :code clean :tool-kind "html")]
      [(string-contains? clean ":call") (ToolCallResult :code clean :tool-kind "html")]
      [true (ToolCallResult :code clean :tool-kind "direct")])))

(df repair-and-normalize [(raw Str)] -> FsmRepairReport
  :d "Full anti-hallucination normalization pipeline"
  (let [(th (extract-thinking raw))
        (stripped (strip-markdown-fences (.-code th)))
        (tc (extract-toolcall-kind stripped))
        (delta (bal/count-unclosed-parens (.-code tc)))
        (balanced (balance-delimiters (.-code tc)))
        (was-repaired (or (> delta 0) (not (= raw balanced))))]
    (FsmRepairReport
      :raw raw
      :clean-code balanced
      :thinking (.-thinking th)
      :tool-kind (.-tool-kind tc)
      :open-delta delta
      :repaired was-repaired)))
