/-
# Expressions

Expressions (terms of type `Expr`) are an abstract syntax tree for Lean programs.
This means that each term which can be written in Lean has a corresponding `Expr`.
For example, the application `f e` is represented by the expression `Expr.app ⟦f⟧ ⟦e⟧`,
where `⟦f⟧` is a representation of `f` and `⟦e⟧` a representation of `e`.
Similarly, the term `Nat` is represented by the expression ``Expr.const `Nat []``.
(The backtick and empty list are discussed below.)

The ultimate purpose of a Lean tactic block
is to generate a term which serves as a proof of the theorem we want to prove.
Thus, the purpose of a tactic is to produce (part of) an `Expr` of the right type.
Much metaprogramming therefore comes down to manipulating expressions:
constructing new ones and taking apart existing ones.

Once a tactic block is finished, the `Expr` is sent to the kernel,
which checks whether it is well-typed and whether it really has the type claimed by the theorem.
As a result, tactic bugs are not fatal:
if you make a mistake, the kernel will ultimately catch it.
However, many internal Lean functions also assume that expressions are well-typed,
so you may crash Lean before the expression ever reaches the kernel.
To avoid this, Lean provides many functions which help with the manipulation of expressions.
This chapter and the next survey the most important ones.

Let's get concrete and look at the
[`Expr`](https://github.com/leanprover/lean4/blob/master/src/Lean/Expr.lean)
type:
-/

import Lean

namespace Playground

inductive Expr where
  | bvar    : Nat → Expr                              -- bound variables
  | fvar    : FVarId → Expr                           -- free variables
  | mvar    : MVarId → Expr                           -- meta variables
  | sort    : Level → Expr                            -- Sort
  | const   : Name → List Level → Expr                -- constants
  | app     : Expr → Expr → Expr                      -- application
  | lam     : Name → Expr → Expr → BinderInfo → Expr  -- lambda abstraction
  | forallE : Name → Expr → Expr → BinderInfo → Expr  -- (dependent) arrow
  | letE    : Name → Expr → Expr → Expr → Bool → Expr -- let expressions
  -- less essential constructors:
  | lit     : Literal → Expr                          -- literals
  | mdata   : MData → Expr → Expr                     -- metadata
  | proj    : Name → Nat → Expr → Expr                -- projection

end Playground

/-! What is each of these constructors doing?

- `bvar` is a __bound variable__.
  For example, the `x` in `fun x => x + 2` or `∑ x, x²`.
  This is any occurrence of a variable in an expression where there is a binder above it.
  Why is the argument a `Nat`? This is called a de Bruijn index and will be explained later.
  You can figure out the type of a bound variable by looking at its binder,
  since the binder always has the type information for it.
- `fvar` is a __free variable__.
  These are variables which are not bound by a binder.
  An example is `x` in `x + 2`.
  Note that you can't just look at a free variable `x` and tell what its type is,
  there needs to be a context which contains a declaration for `x` and its type.
  A free variable has an ID that tells you where to look for it in a `LocalContext`.
  In Lean 3, free variables were called "local constants" or "locals".
- `mvar` is a __metavariable__.
  There will be much more on these later,
  but you can think of it as a placeholder or a 'hole' in an expression
  that needs to be filled at a later point.
- `sort` is used for `Type u`, `Prop` etc.
- `const` is a constant that has been defined earlier in the Lean document.
- `app` is a function application.
  Multiple arguments are done using _partial application_: `f x y ↝ app (app f x) y`.
- `lam n t b` is a lambda expression (`fun ($n : $t) => $b`).
  The `b` argument is called the __body__.
  Note that you have to give the type of the variable you are binding.
- `forallE n t b` is a dependent arrow expression (`($n : $t) → $b`).
  This is also sometimes called a Π-type or Π-expression
  and is often written `∀ $n : $t, $b`.
  Note that the non-dependent arrow `α → β` is a special case of `(a : α) → β`
  where `β` doesn't depend on `a`.
  The `E` on the end of `forallE` is to distinguish it from the `forall` keyword.
- `letE n t v b` is a __let binder__ (`let ($n : $t) := $v in $b`).
- `lit` is a __literal__, this is a number or string literal like `4` or `"hello world"`.
  Literals help with performance:
  we don't want to represent the expression `(10000 : Nat)`
  as `Nat.succ $ ... $ Nat.succ Nat.zero`.
- `mdata` is just a way of storing extra information on expressions that might be useful,
  without changing the nature of the expression.
- `proj` is for projection.
  Suppose you have a structure such as `p : α × β`,
  rather than storing the projection `π₁ p` as `app π₁ p`, it is expressed as `proj Prod 0 p`.
  This is for efficiency reasons ([todo] find link to docstring explaining this).

You've probably noticed
that you can write many Lean programs which do not have an obvious corresponding `Expr`.
For example, what about `match` statements, `do` blocks or `by` blocks?
These constructs, and many more, must indeed first be translated into expressions.
The part of Lean which performs this (substantial) task is called the elaborator
and is discussed in its own chapter.
The benefit of this setup is that once the translation to `Expr` is done,
we have a relatively simple structure to work with.
(The downside is that going back from `Expr` to a high-level Lean program can be challenging.)

The elaborator also fills in any implicit or typeclass instance arguments
which you may have omitted from your Lean program.
Thus, at the `Expr` level, constants are always applied to all their arguments, implicit or not.
This is both a blessing
(because you get a lot of information which is not obvious from the source code)
and a curse
(because when you build an `Expr`, you must supply any implicit or instance arguments yourself).

## De Bruijn Indexes

Consider the following lambda expression `(λ f x => f x x) (λ x y => x + y) 5`,
we have to be very careful when we reduce this,
because we get a clash in the variable `x`.

To avoid variable name-clash carnage,
`Expr`s use a nifty trick called __de Bruijn indexes__.
In de Bruijn indexing,
each variable bound by a `lam` or a `forallE` is converted into a number `#n`.
The number says how many binders up the `Expr` tree we should look
to find the binder which binds this variable.
So our above example would become
(putting wildcards `_` in the type arguments for now for brevity):
``app (app (lam `f _ (lam `x _ (app (app #1 #0) #0))) (lam `x _ (lam `y _ (app (app plus #1) #0)))) five``
Now we don't need to rename variables when we perform β-reduction.
We also really easily check if two `Expr`s containing bound expressions are equal.
This is why the signature of the `bvar` case is `Nat → Expr` and not `Name → Expr`.

If a de Bruijn index is too large for the number of binders preceding it,
we say it is a __loose `bvar`__;
otherwise we say it is __bound__.
For example, in the expression ``lam `x _ (app #0 #1)``
the `bvar` `#0` is bound by the preceding binder and `#1` is loose.
The fact that Lean calls all de Bruijn indexes `bvar`s ("bound variables")
points to an important invariant:
outside of some very low-level functions,
Lean expects that expressions do not contain any loose `bvar`s.
Instead, whenever we would be tempted to introduce a loose `bvar`,
we immediately convert it into an `fvar` ("free variable").
Precisely how that works is discussed in the next chapter.

If there are no loose `bvar`s in an expression, we say that the expression is __closed__.
The process of replacing all instances of a loose `bvar` with an `Expr`
is called __instantiation__.
Going the other way is called __abstraction__.

If you are familiar with the standard terminology around variables,
Lean's terminology may be confusing,
so here's a map:
Lean's "bvars" are usually called just "variables";
Lean's "loose" is usually called "free";
and Lean's "fvars" might be called "local hypotheses".

## Universe Levels

Some expressions involve universe levels, represented by the `Lean.Level` type.
A universe level is a natural number,
a universe parameter (introduced with a `universe` declaration),
a universe metavariable or the maximum of two universes.
They are relevant for two kinds of expressions.

First, sorts are represented by `Expr.sort u`, where `u` is a `Level`.
`Prop` is `sort Level.zero`; `Type` is `sort (Level.succ Level.zero)`.

Second, universe-polymorphic constants have universe arguments.
A universe-polymorphic constant is one whose type contains universe parameters.
For example, the `List.map` function is universe-polymorphic,
as the `pp.universes` pretty-printing option shows:
-/

set_option pp.universes true in
#check @List.map

/-!
The `.{u_1,u_2}` suffix after `List.map`
means that `List.map` has two universe arguments, `u_1` and `u_2`.
The `.{u_1}` suffix after `List` (which is itself a universe-polymorphic constant)
means that `List` is applied to the universe argument `u_1`, and similar for `.{u_2}`.

In fact, whenever you use a universe-polymorphic constant,
you must apply it to the correct universe arguments.
This application is represented by the `List Level` argument of `Expr.const`.
When we write regular Lean code, Lean infers the universes automatically,
so we do not need think about them much.
But when we construct `Expr`s,
we must be careful to apply each universe-polymorphic constant to the right universe arguments.

## Constructing Expressions

### Constants

The simplest expressions we can construct are constants.
We use the `const` constructor and give it a name and a list of universe levels.
Most of our examples only involve non-universe-polymorphic constants,
in which case the list is empty.

We also show a second form where we write the name with double backticks.
This checks that the name in fact refers to a defined constant,
which is useful to avoid typos.
-/

open Lean

def z' := Expr.const `Nat.zero [] -- arguments are a name and a list of universe levels.
#eval z' -- Lean.Expr.const `Nat.zero []

def z := Expr.const ``Nat.zero []

#check z
#eval z -- Lean.Expr.const `Nat.zero []

-- **Q**: what is the difference between single and double backticks?

/-
The double-backtick variant also resolves the given name, making it fully-qualified.
To illustrate this mechanism, here are two further examples.
The first expression, `z₁`, is unsafe:
if we use it in a context where the `Nat` namespace is not open,
Lean will complain that there is no constant called `zero` in the environment.
In contrast, the second expression, `z₂`,
contains the fully-qualified name `Nat.zero` and does not have this problem.

-- **Note**: the above explanation is not entirely correct. check this with removing the `open Nat` command.
-/

open Nat

def z₁ := Expr.const `zero []
#eval z₁ -- Lean.Expr.const `zero []

def z₂ := Expr.const ``zero []
#eval z₂ -- Lean.Expr.const `Nat.zero []

/-
### Function Applications

The next class of expressions we consider are function applications.
These can be built using the `app` constructor,
with the first argument being an expression for the function
and the second being an expression for the argument.

Here are two examples.
The first is simply a constant applied to another.
The second is a recursive definition giving an expression as a function of a natural number.
-/

def one := Expr.app (.const ``succ []) z
#eval one
-- Lean.Expr.app (Lean.Expr.const `Nat.succ []) (Lean.Expr.const `Nat.zero [])



-- succ (succ 1)

def two := Expr.app (.const ``Nat.succ []) one
/-
Lean.Expr.app
  (Lean.Expr.const `Nat.succ [])
  (Lean.Expr.app (Lean.Expr.const `Nat.succ []) (Lean.Expr.const `Nat.zero []))
-/
#eval two

/-- The expression associated to a natural number. -/
def natExpr: Nat → Expr
| 0     => z
| n + 1 => .app (.const ``Nat.succ []) (natExpr n)

#eval natExpr 2


/-
Next we use the variant `mkAppN` which allows application with multiple arguments.
-/

def sumExpr : Nat → Nat → Expr
| n, m => mkAppN (.const ``Nat.add []) #[natExpr n, natExpr m]

/-
def mkAppN (f : Expr) (args : Array Expr) : Expr :=
  args.foldl mkApp f

@[match_pattern] def mkApp (f a : Expr) : Expr :=
  .app f a
-/


#check Lean.mkApp
--**Q**: why do we need `.mkApp` if `.app` already exists?

#check sumExpr

#eval zero

#eval sumExpr 0 1 --
-- .app (.app (.const add) (.const zero)) (.app (.const succ) (.const zero))

/-
As you may have noticed, we didn't show `#eval` outputs for the two last functions.
That's because the resulting expressions can grow so large
that it's hard to make sense of them.

### Lambda Abstractions

We next use the constructor `lam`
to construct a simple function which takes any natural number `x` and returns `Nat.zero`.
The argument `BinderInfo.default` says that `x` is an explicit argument
(rather than an implicit or typeclass argument).
-/

-- the expression for `λ (x : Nat). 0`
def constZero : Expr :=
  .lam `x (.const ``Nat []) (.const ``Nat.zero []) BinderInfo.default

-- binderName = x
-- binderType = (.const ``Nat [])
-- body = (.const ``Nat.zero [])
-- binderInfo = BinderInfo.default

/-
| lam (binderName : Name) (binderType : Expr) (body : Expr) (binderInfo : BinderInfo)
-/
def constZero' : Expr :=
  .lam `x (.const ``Nat []) (.bvar 0) .default

#eval constZero
-- Lean.Expr.lam `x (Lean.Expr.const `Nat []) (Lean.Expr.const `Nat.zero [])
--   (Lean.BinderInfo.default)

/-!
As a more elaborate example which also involves universe levels,
here is the `Expr` that represents `List.map (λ x => Nat.add x 1) []`
(broken up into several definitions to make it somewhat readable):
-/

def nat : Expr := .const ``Nat []

def addOne : Expr :=
  .lam `x nat
    (mkAppN (.const ``Nat.add []) #[.bvar 0, mkNatLit 1])
    BinderInfo.default

#check addOne
/-
Lean.Expr.lam
  `x
  (Lean.Expr.const `Nat [])
  (Lean.Expr.app
    (Lean.Expr.app (Lean.Expr.const `Nat.add []) (Lean.Expr.bvar 0))
    (Lean.Expr.app
      (Lean.Expr.app
        (Lean.Expr.app (Lean.Expr.const `OfNat.ofNat [Lean.Level.zero]) (Lean.Expr.const `Nat []))
        (Lean.Expr.lit (Lean.Literal.natVal 1)))
      (Lean.Expr.app (Lean.Expr.const `instOfNatNat []) (Lean.Expr.lit (Lean.Literal.natVal 1)))))
  (Lean.BinderInfo.default)

-/
#eval addOne

/-- Tail-recursive version of `List.map`. -/
@[inline] def mapTR (f : α → β) (as : List α) : List β :=
  loop as []
where
  @[specialize] loop : List α → List β → List β
  | [],    bs => bs.reverse
  | a::as, bs => loop as (f a :: bs)

#check mapTR.loop
#eval mapTR.loop (fun x => x + 1) [1,2,3] [40,50,60]

#check List.mapTR


#eval List.mapTR (fun x => x + 1) [1,2,3]

def mapAddOneNil : Expr :=
  mkAppN (.const ``List.map [levelZero, levelZero])
    #[nat, nat, addOne, .app (.const ``List.nil [levelZero]) nat]

/-!
With a little trick (more about which in the Elaboration chapter),
we can turn our `Expr` into a Lean term, which allows us to inspect it more easily.
-/

elab "mapAddOneNil" : term => return mapAddOneNil

#check mapAddOneNil
-- List.map (fun x => Nat.add x 1) [] : List Nat

set_option pp.universes true in
set_option pp.explicit true in
#check mapAddOneNil
-- @List.map.{0, 0} Nat Nat (fun x => x.add 1) (@List.nil.{0} Nat) : List.{0} Nat

#reduce mapAddOneNil
-- []

/-
In the next chapter we explore the `MetaM` monad,
which, among many other things,
allows us to more conveniently construct and destruct larger expressions.

## Exercises

1. Create expression `1 + 2` with `Expr.app`.
2. Create expression `1 + 2` with `Lean.mkAppN`.
3. Create expression `fun x => 1 + x`.
4. [**De Bruijn Indexes**] Create expression `fun a, fun b, fun c, (b * a) + c`.
5. Create expression `fun x y => x + y`.
6. Create expression `fun x, String.append "hello, " x`.
7. Create expression `∀ x : Prop, x ∧ x`.
8. Create expression `Nat → String`.
9. Create expression `fun (p : Prop) => (λ hP : p => hP)`.
10. [**Universe levels**] Create expression `Type 6`.
-/

/-
`1 + 2`
-/

#check Expr.app

def onePlusTwo : Expr :=
Expr.app (Expr.app (.const ``Nat.add []) (mkNatLit 1)) (mkNatLit 2)

elab "onePlusTwo'" : term => return onePlusTwo

#check onePlusTwo'
#reduce onePlusTwo'

def onePlusTwoFold : Expr :=
#[mkNatLit 1, mkNatLit 2].foldl mkApp (.const ``Nat.add [])

def onePlusTwoN : Expr :=
mkAppN (Expr.const ``Nat.add []) #[mkNatLit 1, mkNatLit 2]
--Expr.app (Expr.app (.const ``Nat.add []) (mkNatLit 1)) (mkNatLit 2)

elab "onePlusTwoN'" : term => return onePlusTwoN

#check onePlusTwoN'
#reduce onePlusTwoN'


/-
Create expression `fun x => 1 + x`.
-/

def onePlusX : Expr :=
  Expr.lam `x (Expr.const `Nat []) (mkAppN (Expr.const ``Nat.add []) #[mkNatLit 1, .bvar 0]) .default

elab "onePlusX'" : term => return onePlusX

#check onePlusX'
#eval onePlusX' 3


/-
[**De Bruijn Indexes**] Create expression `fun a, fun b, fun c, (b * a) + c`.
-/

def mulSum : Expr :=
  Expr.lam `a (Expr.const `Nat []) (Expr.lam `b (Expr.const `Nat []) (Expr.lam `c (Expr.const `Nat []) (mkAppN (Expr.const ``Nat.add []) #[(mkAppN (Expr.const ``Nat.mul []) #[.bvar 1, .bvar 2]), .bvar 0] ) .default) .default) .default


elab "mulSum'" : term  => return mulSum

#check mulSum'



/-
5. Create expression `fun x y => x + y`.
-/

def lamSum : Expr :=
  Expr.lam `x (Expr.const `Nat []) (Expr.lam `y (Expr.const `Nat []) (mkAppN (Expr.const ``Nat.add []) #[Expr.bvar 1, Expr.bvar 0]) .default) .default


elab "lamSum'" : term  => return lamSum

#check lamSum'

#reduce lamSum'


/-
6. Create expression `fun x, String.append "hello, " x`.
-/

#check String.append

def stringAppend : Expr :=
  Expr.lam `x (Expr.const `String []) (mkAppN (Expr.const ``String.append []) #[mkStrLit "hello, ", .bvar 0]) .default

elab "stringAppend'" : term  => return stringAppend

#check stringAppend'

/-
maximum recursion depth has been reached (use `set_option maxRecDepth <num>` to increase limit)
-/
#reduce stringAppend' "world"

#eval stringAppend' "world"

def stringAppend_full :=
  Expr.lam `x (Expr.const `String [])
  (Lean.mkAppN (Expr.const `String.append []) #[Lean.mkStrLit "Hello, ", Expr.bvar 0])
  BinderInfo.default

/-
7. Create expression `∀ x : Prop, x ∧ x`.
-/

-- Note: `(Expr.const `Prop [])` does not work; unknown constant 'Prop'
-- instead, use `Expr.sort Lean.Level.zero`
def propAndProp : Expr :=
  Expr.forallE `x  (Expr.sort Lean.Level.zero) (mkAppN (Expr.const ``And []) #[Expr.bvar 0, Expr.bvar 0]) .default

elab "propAndProp'" : term  => return propAndProp

#reduce propAndProp'
#eval propAndProp'

def seven : Expr :=
  Expr.forallE `x (Expr.sort Lean.Level.zero)
  (Expr.app (Expr.app (Expr.const `And []) (Expr.bvar 0)) (Expr.bvar 0))
  BinderInfo.default

elab "seven'" : term => return seven

#check seven'
#eval seven'


/-
8. Create expression `Nat → String`.
-/

def natToString : Expr :=
  Expr.forallE `x (Expr.const `Nat []) (Expr.const `String []) BinderInfo.default

elab "natToString'" : term => return natToString

#reduce natToString'


/- ### 8. -/
def eight : Expr :=
  Expr.forallE `notUsed
  (Expr.const `Nat []) (Expr.const `String [])
  BinderInfo.default


elab "eight'" : term => return eight

#check eight'

#reduce eight'

/-
9. Create expression `fun (p : Prop) => (fun (hP : p) => hP)`.
-/

def proofProp : Expr :=
  Expr.lam `p (Expr.sort Lean.Level.zero) (Expr.lam `hP (Expr.bvar 1) (.bvar 0) .default) .default

elab "proofProp'" : term => return proofProp

#check proofProp'
#reduce proofProp'


/- ### 9. -/
def nine : Expr :=
  Expr.lam `p (Expr.sort Lean.Level.zero)
  (
    Expr.lam `hP (Expr.bvar 0)
    (Expr.bvar 0)
    BinderInfo.default
  )
  BinderInfo.default

elab "nine" : term => return nine

#check nine
#reduce nine

/-
10. [**Universe levels**] Create expression `Type 6`.
-/

def type6 : Expr :=
  Expr.sort (Lean.Level.succ (Lean.Level.succ (Lean.Level.succ (Lean.Level.succ (Lean.Level.succ (Lean.Level.succ Lean.Level.zero))))))

elab "type6'" : term => return type6

#check type6'
