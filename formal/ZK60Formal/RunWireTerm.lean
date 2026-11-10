/-
D63 lane L54 (2026-11-10), part 2: **the block slots' terminal identity at the run, from the run-level `hsem`**
(the brief's deliverable 2, its slots' half: lane L50's `RaTermAt` at the 26 blocks).

Lane L16's `blockSlots_terminal` gives every slot's terminal identity `fin = F(ρ ‖ es)` on the block's own trace from
(i) every claim of the accumulator TRUE of some data `cs`, (ii) every `M` functional TRUE of some data `ms`, (iii) the
slot polynomials meeting the evaluation interface `SlotEval` over that data, (iv) `define`'s polynomials returning
canonical words. At the run, (i) and (ii) are the run-level `hsem` (`wr_hsem_acc`, part 1) with the run's own data
(`wrCs`, `wrMs`). So `RaTermAt` at a block part reduces to the slot polynomials' interface at the run's data:

* **`wr_term`**: `RaTermAt` at block `P`'s reading of a transcript, from the claims' and functionals' truth at every
  reading (`hsem`), `SlotEval` of the polynomial `F` at every reading's roots over the same data (`hEv`), and
  `define`'s canonical words (`hpolyC`). The restated top theorem (`RunWireTop.lean`) uses it with `hsem :=
  wr_hsem_acc`: the run-level link is PROVED there, and the slot polynomials' interface `SlotEval` over the run's data
  (`wrCs`, `wrMs`) is what remains of `hsl_blk`;
* **`wr_shield_slots`**: every one of the 26 Shieldstral layers' R13 programs has the one Shieldstral slot shape, and
  that shape meets the kinds data's slot conditions (finding L50-2).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunWireSem
import ZK60Formal.BlockR13StmtDone

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

/-- **`RaTermAt` FROM THE CLAIMS' TRUTH AND THE SLOT POLYNOMIALS' INTERFACE.** At every reading of block `P` (at
`hdrLen`) on the transcript `τ`: if the reading's accumulator has every claim true of `cs` and every functional true of
`ms` (`hsem`), the polynomial `F` at the reading's roots meets `SlotEval` over `cs`, `ms` (`hEv`), and `define`'s
polynomials return canonical words (`hpolyC`), then every slot's final value is `F` at its point (L16's
`blockSlots_terminal`; the final values canonical by `blockSlots_fin_canon`). -/
theorem wr_term {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig)
    (domain : List UInt8) {L : ℕ} (P : Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Block.Cuts3 L → Block.RootsO → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P j).1 + (Block.slotShape P j).2.1) → K) → K)
    (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (cs : Block.Cm → Block.ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hd : ∀ j, j < P.geom.slots.length → 1 ≤ (Block.slotShape P j).2.2)
    (hpolyC : ∀ (j : ℕ) (hist : Block.Hist) (dr : List Fp2) (df : Block.SlotDef), P.define j hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hsem : ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      Block.ClaimsTrue U cs acc.claims ∧ Block.MTrue U ms (acc.fs ++ acc.hostFs))
    (hEv : ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      Block.SlotEval U P cs ms (fun j sn pt => F (Block.cuts3 absOf lg (Block.rootsOf core)) (Block.rootsOf core) j sn pt)) :
    RaTermAt U key domain P hdrLen absOf F G lg τ := by
  intro hdr core bga rs acc T hsa _ htr j r hr
  obtain ⟨hcl, hm⟩ := hsem hdr core bga rs acc T hsa htr
  have hev := hEv hdr core bga rs acc T hsa htr
  obtain ⟨-, -, hcan, hsh, t', hbs⟩ := hsa
  exact Block.blockSlots_terminal U hU (liftH G) P core _ bga rs acc t' hbs cs ms hcl
    (fun mf h => hm mf (List.mem_append_left _ h)) hpolyC
    (Block.blockSlots_fin_canon (liftH G) P core _ bga rs acc t' hbs hcan hsh hd) _ hev j r hr

/-- **Every one of the 26 Shieldstral layers' R13 programs has the ONE Shieldstral slot shape, and that shape meets
the kinds data's slot conditions** (finding L50-2, answered at the layers' programs): lane L49's `progR13_shield_ok`
(L44's program check `progOKb` against `R13.shieldSlots`, evaluated layer by layer at each layer's own calibration
`cfgShieldR13 L`) and lane L50's `ra_shield_slot_conds` (degrees `1 … 7`, rounds × degree `≤ 7·370`). So the block
parts' slot schedules `blockSchedX (Pk k) …` meet `hD`'s `slDeg` at all 26 layers once `Pk k` is layer `k`'s verifier
(`IsShieldR13`'s `hsl`). -/
theorem wr_shield_slots (ioIn ioOut : ℕ) :
    (∀ L ∈ ZK60.RunShape.Shield.shieldExport,
      Block.progOKb (fun _ => 1) (Block.DefR13.progR13 (Block.DefR13.cfgShieldR13 L) ioIn ioOut)
        Block.R13.shieldSlots = true)
    ∧ ∀ k, k < 23 → 1 ≤ (Block.R13.shieldSlots.getD k (0, 0, 0)).2.2 ∧ (Block.R13.shieldSlots.getD k (0, 0, 0)).2.2 ≤ 7
      ∧ ((Block.R13.shieldSlots.getD k (0, 0, 0)).1 + (Block.R13.shieldSlots.getD k (0, 0, 0)).2.1)
        * (Block.R13.shieldSlots.getD k (0, 0, 0)).2.2 ≤ 7 * 370 :=
  ⟨Block.Join.R13H.progR13_shield_ok ioIn ioOut, ra_shield_slot_conds⟩

end ZK60.ProtocolClassify
