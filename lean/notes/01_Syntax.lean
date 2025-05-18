import Lean
open Lean Meta Elab

elab "#stx" "[" t:term "]" : command => do
  logInfo m!"Syntax: {t};\n{repr t}"


#print Syntax

/-
Syntax: 1;
{ raw := Lean.Syntax.node
           (Lean.SourceInfo.none)
           `num
           #[Lean.Syntax.atom
               (Lean.SourceInfo.original "".toSubstring { byteIdx := 121 } "".toSubstring { byteIdx := 122 })
               "1"] }
-/
#stx [1] -- this is a numeral



/-
Syntax: 1;
{ raw := Lean.Syntax.node
           (Lean.SourceInfo.none)
           `num
           #[Lean.Syntax.atom
               (Lean.SourceInfo.original "".toSubstring { byteIdx := 409 } " ".toSubstring { byteIdx := 410 })
               "1"] }
-/
#stx [1]


/-
unexpected token '+'; expected term
-/
#stx [+] -- gives error unexpected token '+' because it is not a term

/-
function expected at
  1
term has type
  ?m.597
-/
#check 1 3 + 4 -- gives error because `1` is not a function.


/-
Syntax: 1 3 + 4;
{ raw := Lean.Syntax.node
           (Lean.SourceInfo.none)
           `«term_+_»
           #[Lean.Syntax.node
               (Lean.SourceInfo.none)
               `Lean.Parser.Term.app
               #[Lean.Syntax.node
                   (Lean.SourceInfo.none)
                   `num
                   #[Lean.Syntax.atom
                       (Lean.SourceInfo.original "".toSubstring { byteIdx := 801 } " ".toSubstring { byteIdx := 802 })
                       "1"],
                 Lean.Syntax.node
                   (Lean.SourceInfo.none)
                   `null
                   #[Lean.Syntax.node
                       (Lean.SourceInfo.none)
                       `num
                       #[Lean.Syntax.atom
                           (Lean.SourceInfo.original
                             "".toSubstring
                             { byteIdx := 803 }
                             " ".toSubstring
                             { byteIdx := 804 })
                           "3"]]],
             Lean.Syntax.atom
               (Lean.SourceInfo.original "".toSubstring { byteIdx := 805 } " ".toSubstring { byteIdx := 806 })
               "+",
             Lean.Syntax.node
               (Lean.SourceInfo.none)
               `num
               #[Lean.Syntax.atom
                   (Lean.SourceInfo.original "".toSubstring { byteIdx := 807 } "".toSubstring { byteIdx := 808 })
                   "4"]] }
-/
#stx [1 3 + 4]

/-
Syntax: f 1 + 3;
{ raw := Lean.Syntax.node
           (Lean.SourceInfo.none)
           `«term_+_»
           #[Lean.Syntax.node
               (Lean.SourceInfo.none)
               `Lean.Parser.Term.app
               #[Lean.Syntax.ident
                   (Lean.SourceInfo.original "".toSubstring { byteIdx := 2269 } " ".toSubstring { byteIdx := 2270 })
                   "f".toSubstring
                   `f
                   [],
                 Lean.Syntax.node
                   (Lean.SourceInfo.none)
                   `null
                   #[Lean.Syntax.node
                       (Lean.SourceInfo.none)
                       `num
                       #[Lean.Syntax.atom
                           (Lean.SourceInfo.original
                             "".toSubstring
                             { byteIdx := 2271 }
                             " ".toSubstring
                             { byteIdx := 2272 })
                           "1"]]],
             Lean.Syntax.atom
               (Lean.SourceInfo.original "".toSubstring { byteIdx := 2273 } " ".toSubstring { byteIdx := 2274 })
               "+",
             Lean.Syntax.node
               (Lean.SourceInfo.none)
               `num
               #[Lean.Syntax.atom
                   (Lean.SourceInfo.original "".toSubstring { byteIdx := 2275 } "".toSubstring { byteIdx := 2276 })
                   "3"]] }
-/
#stx [f 1 + 3]


#stx [1 + 3]
