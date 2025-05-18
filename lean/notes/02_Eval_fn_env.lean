import Lean

open Lean

/-- A simple metaprogram that evaluate functions from the environment. -/

def foo : Nat → Nat := fun x => x + 1
def bar : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n+2 => bar n + bar (n+1)

unsafe
def baz (name : Name) (input : Nat) : MetaM Nat := do
  let e := mkAppN (mkConst name) #[mkNatLit input]
  Lean.Meta.evalExpr Nat (.const `Nat []) e

#eval baz `foo 1 -- 2
#eval baz `bar 1 -- 1
