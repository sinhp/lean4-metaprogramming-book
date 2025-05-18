import Tactic

open Lean

open Expr

-- the tactic monad

#check Tactic

meta def test (hyp tgt : Expr) : Tactic Bool := sorry


-- elab "custom_sorry_1" : tactic =>
--   Lean.Elab.Tactic.withMainContext do
--     let goal ← Lean.Elab.Tactic.getMainGoal
--     let goalDecl ← goal.getDecl
--     let goalType := goalDecl.type
--     dbg_trace f!"goal type: {goalType}"
