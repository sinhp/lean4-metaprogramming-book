import Lean
open Lean Meta Elab

-- set_option autoImplicit false

/-
we want to write a function which takes a lambda term and returns a string of de Bruijn indices
for example,
- `fun x => fun y => y` should return `λλ0`
- `fun x => fun y => x` should return `λλ1`
- `fun x => fun y => fun z => x` should return `λλ2`
- `fun x => fun y => x y` should return `λλ21`
- `fun x => fun y => y x` should return `λλ12`
- `fun x => fun y => fun z => x y z` should return `λλλ210`
- `fun x => x (fun y => x y)` should return `λ1(λ21)`
we will use the Lean syntax tree to do this.
-/

/-
In first order type systems, we maintain the binder types:
- `fun (x : A) => fun (y : B) => x y` should return `λAλB10`
- `fun (x : A) => fun (y : B) => x` should return `λAλB1`

Similarly, the de Bruijn indices corresponding to the following judgments are:
- `x : A, y : B ⊢ x y (fun u => x y u)`  should return `A, B ⊢ 10(λ210)`
- `x : A, z : C, y : B ⊢ x y (fun u => x y u)` should return `A, C, B ⊢ 20(λ310)`
-/

example : (λ f (x : Nat) => f x x) (λ x y => x + y) = λ x => x + x :=
  rfl

#eval (λ f x => f x x) (λ x y => x + y) 5

elab "#stx" "[" t:term "]" : command => do
  logInfo m!"Syntax: {t};\n{repr t}"

#stx [(λ f x => f x x) (λ x y => x + y) 5]


/-
-- `(λ f x => f x x) (λ x y => x + y) 5` should return `λλ100 λλ1+0`
-/


-- ``app (app (lam `f _ (lam `x _ (app (app #1 #0) #0))) (lam `x _ (lam `y _ (app (app plus #1) #0)))) five``
