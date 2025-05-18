import Lean
open Lean Meta Elab

-- The `Imp` language
-- (small imperative language)

-- has **statements** formed by assignments, conditionals, and while-loops
-- assignments are of the form `x := e` where `x` is a variable and `e` is an expression, e.g. `i:= 0`
-- a simple program in `Imp` is:
-- ```
-- x := 0;
-- y := 0;
-- while (x < n) {
-- y := y +  m;
-- x := x + 1;
-- }
-- ```

-- if (x < y) {
-- min  := x;
-- } else {
-- min := y;
-- }

-- has **expressions** formed by constants, variables, addition, less-than comparisons

-- memory is flat, untyped, and mutable.
-- no types, everything is a 32-bit integer.

-- **Goals**:

-- embedd the syntax of `Imp` into Lean
-- implement a simple optimization and its proof correctness in Lean

namespace Imp

-- internal representation of the syntax in Lean: define a AST



-- the type of values, everything is a 32-bit integer.
abbrev V : Type := BitVec 32

#synth OfNat V 10 -- instance instOfNat : OfNat (BitVec n) i where ofNat := .ofNat n i

-- an inductiev type of expressions
inductive Expr where
  | const (v : V)
  | var (s : String) --named variables  identified by their names
  | lt (e₁ : Expr) (e₂ : Expr) -- recursive constructor
  | add (e₁ : Expr) (e₂ : Expr) -- recursive constructor

-- an inductive type of statements
inductive Stmt where
  | asg (lhs : String) (rhs : Expr) -- assignment
  | seq (s₁ : Stmt) (s₂ : Stmt) -- sequential composition
  | ifThenElse (c : Expr) (t : Stmt) (e : Stmt) -- conditional
  | while (c : Expr) (s : Stmt) -- while loop


#check Stmt.asg "i" (.const 0)


-- extend the language live as we use it
-- for the parser we introduce new non-terminals by declaring a new syntax category

/- Syntax declaration -/

declare_syntax_cat expr
declare_syntax_cat stmt

syntax num : expr
syntax ident : expr
syntax expr "<" expr : expr
syntax expr "+" expr : expr

syntax ident ":=" expr ";" : stmt -- `y := y + 10` is a statement
syntax stmt stmt : stmt -- `y := y + 10; x := x + 1` is a statement
syntax "if" "(" expr ")" "{" stmt "}" "else" "{" stmt "}" : stmt -- `if (x < y) { min := x; } else { min := y; }` is a statement
syntax "while" "{" stmt "}" : stmt -- `while (x < n) { y := y + m; x := x + 1; }` is a statement

-- add-on: we can set precendes for binding strenght/priorities.


syntax "expr" "{" expr "}" : term
syntax "stmt" "{" stmt "}" : term


#check expr { i < j } -- Lean has already parsed this, but it does not yet know how to equip it with a meaning. We need to write elaboration; we need to reflect the declared ACT to AST .
#check expr { i := 0; } -- not even parsed, wrong syntax categories
#check stmt { i := 0; } -- Lean has already parsed this, but it does not yet know how to equip it with a meaning. We need to write elaboration; we need to reflect the declared ACT to AST .




macro_rules
  | `(expr| $n:num) => `(Expr.const $n)
  | `(expr )
