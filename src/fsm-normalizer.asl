(module asl-harness/fsm-normalizer
  :d "Deterministic Finite State Machine (FSM) grammar normalizer and delimiter balancer."
  :x [FsmState FsmResult normalize-keywords balance-delimiters-fsm repair-syntax-fsm]
  :i [])

(dfe FsmState
  (:c fsm-idle [] "FSM is idle outside of any form or string")
  (:c fsm-in-form [] "FSM is inside an active S-expression form")
  (:c fsm-in-str [] "FSM is inside a string literal")
  (:c fsm-in-escape [] "FSM is processing an escaped character in a string"))

(dfs FsmResult
  (:f repaired Str "Repaired source string with balanced delimiters")
  (:f open-parens I64 "Number of unclosed opening parentheses before repair")
  (:f open-brackets I64 "Number of unclosed opening brackets before repair")
  (:f balanced? Bool "True if delimiters and strings were already balanced"))

(dfs FsmTracker
  (:f state FsmState "Current state of the FSM")
  (:f stack (List Str) "Stack of open opening delimiters")
  (:f open-parens I64 "Count of unclosed open parentheses")
  (:f open-brackets I64 "Count of unclosed open brackets")
  (:f in-comment Bool "True if processing line comment until newline"))

(df pop-matching-delim [(stack (List Str)) (target Str)] -> (List Str)
  :d "Pops the topmost matching opening delimiter from the stack."
  (if (list-empty? stack)
    (list)
    (let [(h (option-or (list-head stack) ""))
          (t (option-or (list-tail stack) (list)))]
      (if (= h target)
        t
        (list-cons h (pop-matching-delim t target))))))

(df delims-to-closers [(stack (List Str))] -> Str
  :d "Converts stack of unclosed delimiters into string of matching closing delimiters."
  (if (list-empty? stack)
    ""
    (let [(h (option-or (list-head stack) ""))
          (t (option-or (list-tail stack) (list)))
          (closer (if (= h "(") ")" (if (= h "[") "]" "")))]
      (str closer (delims-to-closers t)))))

(df fsm-step [(st FsmTracker) (c Str)] -> FsmTracker
  :d "Processes a single character transition for delimiter tracking."
  (if (.-in-comment st)
      (if (= c "\n")
          (FsmTracker
            :state (.-state st)
            :stack (.-stack st)
            :open-parens (.-open-parens st)
            :open-brackets (.-open-brackets st)
            :in-comment false)
          st)
      (mt (.-state st)
        ((fsm-in-escape)
         (FsmTracker
           :state (fsm-in-str)
           :stack (.-stack st)
           :open-parens (.-open-parens st)
           :open-brackets (.-open-brackets st)
           :in-comment false))
        ((fsm-in-str)
         (cond
           ((= c "\\")
            (FsmTracker
              :state (fsm-in-escape)
              :stack (.-stack st)
              :open-parens (.-open-parens st)
              :open-brackets (.-open-brackets st)
              :in-comment false))
           ((= c "\"")
            (let [(p (.-open-parens st))
                  (b (.-open-brackets st))
                  (next-st (if (and (= p 0) (= b 0)) (fsm-idle) (fsm-in-form)))]
              (FsmTracker
                :state next-st
                :stack (.-stack st)
                :open-parens p
                :open-brackets b
                :in-comment false)))
           (:else st)))
        (_
         (cond
           ((= c ";")
            (FsmTracker
              :state (.-state st)
              :stack (.-stack st)
              :open-parens (.-open-parens st)
              :open-brackets (.-open-brackets st)
              :in-comment true))
           ((= c "\"")
            (FsmTracker
              :state (fsm-in-str)
              :stack (.-stack st)
              :open-parens (.-open-parens st)
              :open-brackets (.-open-brackets st)
              :in-comment false))
           ((= c "(")
            (FsmTracker
              :state (fsm-in-form)
              :stack (list-cons "(" (.-stack st))
              :open-parens (+ (.-open-parens st) 1)
              :open-brackets (.-open-brackets st)
              :in-comment false))
           ((= c "[")
            (FsmTracker
              :state (fsm-in-form)
              :stack (list-cons "[" (.-stack st))
              :open-parens (.-open-parens st)
              :open-brackets (+ (.-open-brackets st) 1)
              :in-comment false))
           ((= c ")")
            (let [(new-p (if (> (.-open-parens st) 0) (- (.-open-parens st) 1) 0))
                  (new-b (.-open-brackets st))
                  (new-stack (pop-matching-delim (.-stack st) "("))
                  (next-st (if (and (= new-p 0) (= new-b 0)) (fsm-idle) (fsm-in-form)))]
              (FsmTracker
                :state next-st
                :stack new-stack
                :open-parens new-p
                :open-brackets new-b
                :in-comment false)))
           ((= c "]")
            (let [(new-p (.-open-parens st))
                  (new-b (if (> (.-open-brackets st) 0) (- (.-open-brackets st) 1) 0))
                  (new-stack (pop-matching-delim (.-stack st) "["))
                  (next-st (if (and (= new-p 0) (= new-b 0)) (fsm-idle) (fsm-in-form)))]
              (FsmTracker
                :state next-st
                :stack new-stack
                :open-parens new-p
                :open-brackets new-b
                :in-comment false)))
           (:else st))))))

(df balance-delimiters-fsm [(source Str)] -> FsmResult
  :d "Tracks open delimiters via FSM and appends matching closing delimiters to produce balanced code."
  (let [(chars (string-chars source))
        (init-tracker (FsmTracker
                        :state (fsm-idle)
                        :stack (list)
                        :open-parens 0
                        :open-brackets 0
                        :in-comment false))
        (final-tracker (fold (fn [(acc FsmTracker) (ch Str)] (fsm-step acc ch)) init-tracker chars))
        (st (.-state final-tracker))
        (p-count (.-open-parens final-tracker))
        (b-count (.-open-brackets final-tracker))
        (unclosed-stack (.-stack final-tracker))
        (quote-closer (mt st
                        ((fsm-in-escape) "\\\"\"")
                        ((fsm-in-str) "\"")
                        (_ "")))
        (delim-closers (delims-to-closers unclosed-stack))
        (suffix (str quote-closer delim-closers))
        (is-balanced (and (= p-count 0)
                          (and (= b-count 0)
                               (mt st
                                 ((fsm-idle) true)
                                 (_ false)))))]
    (FsmResult
      :repaired (str source suffix)
      :open-parens p-count
      :open-brackets b-count
      :balanced? is-balanced)))

(df replace-keyword-patterns [(s Str)] -> Str
  :d "Performs ordered substring replacements for hallucinated keywords, types, and forms."
  (let [(s1 (string-replace s "(defun " "(df "))
        (s2 (string-replace s1 "(defun\n" "(df\n"))
        (s3 (string-replace s2 "(defun\t" "(df\t"))
        (s4 (string-replace s3 "(defun[" "(df ["))
        (s5 (string-replace s4 "(defun(" "(df ("))
        (s6 (string-replace s5 "(defn " "(df "))
        (s7 (string-replace s6 "(defn\n" "(df\n"))
        (s8 (string-replace s7 "(defn\t" "(df\t"))
        (s9 (string-replace s8 "(defn[" "(df ["))
        (s10 (string-replace s9 "(defn(" "(df ("))
        (s11 (string-replace s10 "(lambda " "(fn "))
        (s12 (string-replace s11 "(lambda\n" "(fn\n"))
        (s13 (string-replace s12 "(lambda\t" "(fn\t"))
        (s14 (string-replace s13 "(lambda[" "(fn ["))
        (s15 (string-replace s14 "(lambda(" "(fn ("))
        (s16 (string-replace s15 " defun " " df "))
        (s17 (string-replace s16 " defn " " df "))
        (s18 (string-replace s17 " lambda " " fn "))
        (s19 (string-replace s18 "\ndefun " "\ndf "))
        (s20 (string-replace s19 "\ndefn " "\ndf "))
        (s21 (string-replace s20 "\nlambda " "\nfn "))
        (s22 (string-replace s21 "\tdefun " "\tdf "))
        (s23 (string-replace s22 "\tdefn " "\tdf "))
        (s24 (string-replace s23 "\tlambda " "\tfn "))
        (s25 (string-replace s24 "(defstruct " "(dfs "))
        (s26 (string-replace s25 "(defrecord " "(dfs "))
        (s27 (string-replace s26 "(defenum " "(dfe "))
        (s28 (string-replace s27 " String " " Str "))
        (s29 (string-replace s28 " Int64 " " I64 "))
        (s30 (string-replace s29 " Boolean " " Bool "))
        (s31 (string-replace s30 " Float64 " " F64 "))]
    s31))

(df normalize-keywords [(source Str)] -> Str
  :d "Replaces hallucinated keywords (defun -> df, defn -> df, lambda -> fn)."
  (cond
    ((= source "defun") "df")
    ((= source "defn") "df")
    ((= source "lambda") "fn")
    (:else
     (let [(step1 (replace-keyword-patterns source))
           (step2 (if (string-starts-with? step1 "defun ")
                      (str "df " (option-or (string-slice step1 6 (string-length step1)) ""))
                      step1))
           (step3 (if (string-starts-with? step2 "defn ")
                      (str "df " (option-or (string-slice step2 5 (string-length step2)) ""))
                      step2))
           (step4 (if (string-starts-with? step3 "lambda ")
                      (str "fn " (option-or (string-slice step3 7 (string-length step3)) ""))
                      step3))
           (step5 (if (string-ends-with? step4 " defun")
                      (str (option-or (string-slice step4 0 (- (string-length step4) 6)) "") " df")
                      step4))
           (step6 (if (string-ends-with? step5 " defn")
                      (str (option-or (string-slice step5 0 (- (string-length step5) 5)) "") " df")
                      step5))
           (step7 (if (string-ends-with? step6 " lambda")
                      (str (option-or (string-slice step6 0 (- (string-length step6) 7)) "") " fn")
                      step6))]
        step7))))

(df strip-fences-local [(s Str)] -> Str
  :d "Internal helper stripping markdown backticks before FSM delimiter balancing."
  (let [(s1 (string-replace s "```asl\n" ""))
        (s2 (string-replace s1 "```asl" ""))
        (s3 (string-replace s2 "```\n" ""))
        (s4 (string-replace s3 "```" ""))]
    (string-trim s4)))

(df repair-syntax-fsm [(source Str)] -> Str
  :d "Runs fence stripping, keyword normalization, and delimiter balancing to produce valid ASL."
  (let [(unfenced (strip-fences-local source))
        (kw-repaired (normalize-keywords unfenced))
        (fsm-res (balance-delimiters-fsm kw-repaired))]
    (.-repaired fsm-res)))
