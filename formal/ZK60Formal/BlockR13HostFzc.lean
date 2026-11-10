/-
D63 lane L49 (2026-11-10), sub-agent `fzc`, part 1: **`SC_FZC` at R13, generic in the configuration**: the IR's
value, the raw slots written out, the configuration premise `FzcCfg`, the batch's other entries and the slot's cube
sum (the R13 counterpart of lane L44's `BlockHostFzc.lean`, items 1 to 3).

R13's `SC_FZC` (host `18`, `slot_ir_accuracy.rs::fzc`, `DefR13.r13FzcIr`) batches three named clauses at `μ_0 … μ_2`
(`f0 = a·u − 2^r·h − rh + 2^(r−1)` with the product fold `r = c.p.fold`, `f1 = u + 32768 − ul`, `f2 = h + 2^23 − hl`;
byte limbs `Σ 256^k·t_k`), the ACT tuple's relation at `μ_3`, seven LogUp helpers over `DefR13.lksS c shaped .F` at
`μ_4 … μ_10`, and the sixteen `Dom::F` pad planes at `μ_11` (`ζ` is draw `14`); it hosts `SC_GMM` (slot `11`) and
`SC_UMM` (slot `12`) with the requantizations `2^gate·G + rg − 2^(gate−1)` and `2^up·U + ru − 2^(up−1)`.

* `reqBV`, `r13FzcClauses`, `r13FzcAct`, `post2B_vals`, **`r13FzcIr_eval`** (in any commutative ring, at any
  constants), `r13FzcIr_map` (naturality);
* `aF`, `hF`, `eqFR`, `aFR`, `hFR`, `tabsFR`, `rrFR`, `shFR`, `grpFR`, `irFR`, `tabsGU`: the raw slots `18`, `11`,
  `12` written out, generic in `c` and `ls`;
* **`FzcCfg c ls`**: the facts about the configuration the proof reads (the raw slots are the written-out ones,
  slot `18`'s draw list, fourteen `Dom::F` lookups, the three shifts below `64`); proved at the rung and at every
  Shieldstral layer in `BlockR13HostFzcCfg.lean`;
* `restFR`, `valsFR`, `lksFR`, `muFR`, **`xcFzcR`** (the ACT relation at `κ = 3`, LogUp's helper relations at
  `κ = 4 … 10`, read without the draws), **`pwFzcR`** (`(1 − supp(F))·plane_j`, `j < 16`), `zIRR`;
* `fzcR_vals`, `fzcR_off`, `fzcR_irEval`, **`fzcR_cube`**: the slot's cube sum is `Σ_b hostPoly(…)(b)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostBase
import ZK60Formal.BlockHostFzc

set_option autoImplicit false
set_option linter.unusedSimpArgs false

namespace ZK60.Exec.Block.Join.R13H.Fzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl hPl tabK_ph_cpt hTab_eval tabK_pa_cpt eqT_eval pubT_eval cstS_map cstK)
open ZK60.Exec.Block.Join.W16.Fzc (drR drR_length amqS nbS nb2S)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV L256 reqB limbsB batchV batchB st gatedSt threeTerms zcIr zcIr_vals
  zcIr_map LkD logupSem padSem bodyVal_limbs256 bodyVal_req bodyVal_sum bodyVal_affine nodeVals_length getD_lt
  getD_len_add threeTerms_eval stVal_gated stVal)
open ZK60.Exec.Slot.Compose (cstW_map_std getD_map_f)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The R13 IR's value -/

section IrEval

open ZK60.Exec.Slot

variable {R : Type} [CommRing R]

/-- **A requantization host with byte limbs** `2^s·x + Σ_k 256^k·l_k − 2^(s−1)` (`reqB` after a `limbsB` node). -/
def reqBV (c : Cst R) (v : List R) (s x : ℕ) (l : List ℕ) : R :=
  c.base (2 ^ s) * v.getD x 0 + L256 c v l + c.base (-(2 ^ (s - 1) : ℤ))

/-- **R13 `SC_FZC`'s three named clauses** (slot_ir_accuracy.rs:226-238): `f0 = a·u − 2^r·h − rh + 2^(r−1)`,
`f1 = u + 32768 − ul`, `f2 = h + 2^(pb−1) − hl`, the limb groups as byte sums. -/
def r13FzcClauses (c : Cst R) (Rr : DefR13.FzcR13) (r pb : ℕ) (v : List R) : List R :=
  [v.getD Rr.a 0 * v.getD Rr.u 0 + c.base (-(2 ^ r : ℤ)) * v.getD Rr.h 0 - L256 c v Rr.rh + c.base (2 ^ (r - 1)),
    v.getD Rr.u 0 + c.base 32768 - L256 c v Rr.ul,
    v.getD Rr.h 0 + c.base (2 ^ (pb - 1)) - L256 c v Rr.hl]

/-- **The ACT tuple's relation** `fact·(α − 2048 − g_act − g − β·a − β²·group) − 1`. -/
def r13FzcAct (v : List R) (Rr : DefR13.FzcR13) (amqK nb nb2 : R) : R :=
  v.getD Rr.fact 0 * (amqK - v.getD Rr.g 0 + nb * v.getD Rr.a 0 + nb2 * v.getD Rr.group 0) - 1

/-- **The two byte-limb requantization hosts after the zero-check node.** -/
theorem post2B_vals (c : Cst R) (hc : c.Std) (v A : List R) (z : R) (l₁ : List ℕ) (s₁ x₁ : ℕ) (l₂ : List ℕ)
    (s₂ x₂ : ℕ) :
    nodeVals v [limbsB c l₁, reqB c s₁ x₁ (A.length + 1), limbsB c l₂, reqB c s₂ x₂ (A.length + 1 + 2)] (A ++ [z])
      = A ++ [z, L256 c v l₁, reqBV c v s₁ x₁ l₁, L256 c v l₂, reqBV c v s₂ x₂ l₂] := by
  simp only [nodeVals, bodyVal_limbs256 c hc, bodyVal_req c hc, List.append_assoc, List.singleton_append,
    List.cons_append, List.nil_append, Nat.add_assoc, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, reqBV]

/-- **R13 `SC_FZC`'s polynomial** (`DefR13.r13FzcIr`, slot_ir_accuracy.rs:196-240): the host terms with
`Z = logup + μ_3·ACT + pad + gate·Σ_{j<3} μ_j·f_j` and the byte-limb hosts `SC_GMM`, `SC_UMM`. -/
theorem r13FzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : DefR13.FzcR13) (r pb sgate sup : ℕ)
    (lks : List (LkD R)) (mu nu : List R) (amqK nb nb2 : R) (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (DefR13.r13FzcIr c Rr r pb sgate sup lks mu nu amqK nb nb2 zp groups) v
      = hostTerms v 0 1 2 Rr.gate Rr.gate nu
          (logupSem c v Rr.h0 (fun k => mu.getD (4 + k) 0) 0 lks + mu.getD 3 0 * r13FzcAct v Rr amqK nb nb2
            + padSem c v (mu.getD (4 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gate * batchV mu (r13FzcClauses c Rr r pb v))
          (reqBV c v sgate Rr.g Rr.rg) (reqBV c v sup Rr.u Rr.ru) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (DefR13.r13FzcPre c Rr r pb mu amqK nb nb2) lks Rr.h0
    (fun k => mu.getD (4 + k) c.zero) [st (mu.getD 3 c.zero) [.node 7]]
    (mu.getD (4 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c Rr.gate 8] (DefR13.r13FzcPost c Rr sgate sup)
    (fun o => threeTerms c (0, 1, 2) Rr.gate o nu (o + 2) (o + 4))
  have hlen : (nodeVals v (DefR13.r13FzcPre c Rr r pb mu amqK nb nb2) []).length = 9 := by
    rw [nodeVals_length]; simp [DefR13.r13FzcPre]
  have h7 : A.getD 7 0 = r13FzcAct v Rr amqK nb nb2 := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    simp only [DefR13.r13FzcPre, DefR13.int16B, nodeVals, List.nil_append, List.append_assoc,
      List.singleton_append, List.cons_append, List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc,
      bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons,
      List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, r13FzcAct, hc.one,
      hc.negOne, hc.zero]
    ring
  have h8 : A.getD 8 0 = batchV mu (r13FzcClauses c Rr r pb v) := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    simp only [DefR13.r13FzcPre, DefR13.int16B, nodeVals, List.nil_append, List.append_assoc,
      List.singleton_append, List.cons_append, List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc,
      bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons,
      List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, batchV, r13FzcClauses,
      hc.one, hc.negOne, hc.zero]
    ring
  unfold DefR13.r13FzcIr irEval
  rw [hnv, ht]
  simp only [DefR13.r13FzcPost]
  rw [post2B_vals c hc v A _ Rr.rg sgate Rr.g Rr.ru sup Rr.u, threeTerms_eval c hc]
  simp only [List.map_nil, List.sum_nil, add_zero, List.map_cons, List.sum_cons, stVal_gated c hc, h8, hc.zero]
  simp only [stVal, st, fval, List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, mul_one, h7, hc.zero]

end IrEval

section IrMap

open ZK60.Exec.Slot

/-- **R13 `SC_FZC`'s builder commutes with reading its coefficients elsewhere.** -/
theorem r13FzcIr_map {α β : Type} (f : α → β) (c : Cst α) (Rr : DefR13.FzcR13) (r pb sg su : ℕ)
    (lks : List (LkD α)) (mu nu : List α) (amqK nb nb2 : α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (DefR13.r13FzcIr c Rr r pb sg su lks mu nu amqK nb nb2 zp groups).map f
      = DefR13.r13FzcIr (c.map f) Rr r pb sg su (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f amqK) (f nb)
          (f nb2) (f ∘ zp) groups := by
  unfold DefR13.r13FzcIr
  rw [zcIr_map]
  simp only [DefR13.r13FzcPre, DefR13.r13FzcPost, DefR13.int16B, threeTerms, gatedSt, limbsB, reqB, batchB, st,
    List.map_cons, List.map_nil, Body.map, SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def,
    getD_map_f, List.length_map]
  rfl

end IrMap

/-! ## The raw slots, written out -/

/-- `SC_FZC`'s `A` table of plane `q`, on `Dom::F`'s own coordinates. -/
def aF (c : W16Cfg) (q : ℕ) : TabS :=
  .priv ⟨.a, [(DefR13.aOff c q, false)], c.sh.logs .F, DefW16.rhoC 0 (c.sh.logs .F), 0, 0⟩

/-- `SC_FZC`'s `H` table of helper plane `hp`, on `Dom::F`'s own coordinates. -/
def hF (c : W16Cfg) (hp : ℕ) : TabS :=
  .priv ⟨.h, [((DefR13.hOff c hp).1, false), ((DefR13.hOff c hp).2, true)], c.sh.logs .F,
    DefW16.rhoC 0 (c.sh.logs .F), 0, 0⟩

/-- The three `eq` tables: `τ` (draws `15 …`), `SC_GMM`'s claim point (its draws `0 … lt + lf − 1`), `SC_UMM`'s (`SC_GMM`'s
first `lt` draws, then its own `lf`). -/
def eqFR (c : W16Cfg) : List TabS :=
  [.eq (drR 18 15 (c.sh.logs .F)) 0, .eq (drR 11 0 c.sh.lt ++ drR 11 c.sh.lt c.sh.lf) 0,
    .eq (drR 11 0 c.sh.lt ++ drR 12 0 c.sh.lf) 0]

/-- The sixteen `Dom::F` planes `G`, `rg₀ … rg₂`, `A`, `U`, `ul₀`, `ul₁`, `ru₀`, `ru₁`, `H`, `hl₀ … hl₂`, `rh₀`, `rh₁`
(plane ids `86 + 2·ls + j`, written as `xtR` writes them). -/
def aFR (c : W16Cfg) (ls : ℕ) : List TabS :=
  [aF c (86 + 2 * ls), aF c (86 + 2 * ls + 1), aF c (86 + 2 * ls + 1 + 1), aF c (86 + 2 * ls + 1 + 2),
    aF c (86 + 2 * ls + 4), aF c (86 + 2 * ls + 5), aF c (86 + 2 * ls + 6), aF c (86 + 2 * ls + 6 + 1),
    aF c (86 + 2 * ls + 8), aF c (86 + 2 * ls + 8 + 1), aF c (86 + 2 * ls + 10), aF c (86 + 2 * ls + 11),
    aF c (86 + 2 * ls + 11 + 1), aF c (86 + 2 * ls + 11 + 2), aF c (86 + 2 * ls + 14), aF c (86 + 2 * ls + 14 + 1)]

/-- The seven LogUp helpers. -/
def hFR (c : W16Cfg) : List TabS :=
  [hF c (DefR13.fh c 6), hF c (DefR13.fh c 6 + 1), hF c (DefR13.fh c 6 + 2), hF c (DefR13.fh c 6 + 3),
    hF c (DefR13.fh c 6 + 4), hF c (DefR13.fh c 6 + 5), hF c (DefR13.fh c 6 + 6)]

/-- **`SC_FZC`'s raw tables**: the `eq` tables, the planes, the helpers, the `fact` helper, the group column, the gate. -/
def tabsFR (c : W16Cfg) (ls : ℕ) : List TabS :=
  eqFR c ++ aFR c ls ++ hFR c ++ [hF c (DefR13.fh c 7), .pub 0] ++ [.pub 0]

/-- `SC_FZC`'s table positions (`g`, `a`, `u`, `h`, `fact`, `group`, `h0`, `rh`, `hl`, `ul`, `rg`, `ru`, the gate). -/
def rrFR : DefR13.FzcR13 :=
  ⟨3, 7, 8, 13, 26, 27, 19, [17, 18], [14, 15, 16], [9, 10], [4, 5, 6], [11, 12], some 28⟩

/-- The plane-to-table map `q ↦ 3 + (q − f0)`. -/
def shFR (ls q : ℕ) : ℕ := 3 + (q - (86 + 2 * ls))

/-- The pad group: the gate at table `28`, the sixteen planes. -/
def grpFR : List (ℕ × List ℕ) := [(28, [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18])]

/-- **`SC_FZC`'s raw IR**: `μ` draws `0 … 11`, `ν` draws `12`, `13`, `ζ` draw `14`. -/
def irFR (c : W16Cfg) (ls : ℕ) : ZK60.Exec.Slot.Ir Sym :=
  DefR13.r13FzcIr DefW16.cstS rrFR c.p.fold c.p.prodbits c.p.gate c.p.up (DefR13.lksS c (shFR ls) .F)
    (drR 18 0 12) (drR 18 12 2) amqS nbS nb2S (fun j => Sym.pow (.dr 18 14) j) grpFR

/-- **`SC_GMM`'s and `SC_UMM`'s raw tables**: `YM` (plane `29`) with its token coordinates fixed at `SC_GMM`'s first
`lt` draws, and the folded weight. -/
def tabsGU (c : W16Cfg) : List TabS :=
  [.priv ⟨.a, [(DefR13.aOff c 29, false)], c.sh.lt + c.sh.ld,
      (drR 11 0 c.sh.lt).map CoordS.fixed ++ DefW16.rhoC 0 c.sh.ld, 0, 0⟩, .pub 0]

/-- **The facts about the configuration `SC_FZC`'s proof reads**: the raw slots `18`, `11`, `12` are the written-out
ones (tables, IR, hosted list), slot `18` draws `μ` 12, `ν` 2, `ζ` 1, `τ` `|Dom::F|`, `Dom::F` has fourteen lookups,
and the product fold, gate and up shifts are below `64`. Proved at the R13 rung and at every Shieldstral layer
(`fzcCfg_rung`, `fzcCfg_shield`). -/
structure FzcCfg (c : W16Cfg) (ls : ℕ) : Prop where
  tabs18 : (DefR13.rawSlot c 18).tabs = tabsFR c ls
  ir18 : (DefR13.rawSlot c 18).ir = irFR c ls
  host18 : (DefR13.rawSlot c 18).hosted = [(11, .dr 18 12), (12, .dr 18 13)]
  tabs11 : (DefR13.rawSlot c 11).tabs = tabsGU c
  ir11 : (DefR13.rawSlot c 11).ir = ZK60.Exec.Slot.Build.mmIr DefW16.cstS 0 1
  host11 : (DefR13.rawSlot c 11).hosted = []
  tabs12 : (DefR13.rawSlot c 12).tabs = tabsGU c
  ir12 : (DefR13.rawSlot c 12).ir = ZK60.Exec.Slot.Build.mmIr DefW16.cstS 0 1
  host12 : (DefR13.rawSlot c 12).hosted = []
  dl18 : ZK60.Exec.Slot.R13.draws c.sh 18 = [(.mu, 12), (.nu, 2), (.zeta, 1), (.tau, c.sh.logs .F)]
  nlk : (DefR13.lookups c .F).length = 14
  fold : c.p.fold < 64
  gate : c.p.gate < 64
  up : c.p.up < 64

/-- The numbering keeps a slot's IR. -/
theorem numSlot_ir (aB hB ioIn ioOut ak hk : ℕ) (s : SlotS) :
    (DefW16.numSlot aB hB ioIn ioOut ak hk s).ir = s.ir := rfl

/-- The numbering keeps a slot's hosted list. -/
theorem numSlot_hosted (aB hB ioIn ioOut ak hk : ℕ) (s : SlotS) :
    (DefW16.numSlot aB hB ioIn ioOut ak hk s).hosted = s.hosted := rfl

/-- The numbering numbers a slot's tables. -/
theorem numSlot_tabs (aB hB ioIn ioOut ak hk : ℕ) (s : SlotS) :
    (DefW16.numSlot aB hB ioIn ioOut ak hk s).tabs = DefW16.numTabs aB hB ioIn ioOut ak hk 0 s.tabs := rfl

/-- The main variables of slots `18`, `11`, `12` (`Shape::slots`: `Dom::F`'s log, the width). -/
theorem sched18 (sh : ZK60.Exec.Slot.W16R2.ShapeW) : (ZK60.Exec.Slot.W16R2.sched sh 18).1 = sh.logs .F := rfl
theorem sched11 (sh : ZK60.Exec.Slot.W16R2.ShapeW) : (ZK60.Exec.Slot.W16R2.sched sh 11).1 = sh.ld := rfl
theorem sched12 (sh : ZK60.Exec.Slot.W16R2.ShapeW) : (ZK60.Exec.Slot.W16R2.sched sh 12).1 = sh.ld := rfl

/-! ## The value list and the batch's other entries -/

section Defs

variable {K : Type} [Field K] [Algebra GF K]

/-- **`SC_FZC`'s value list from position `3` on**, at a cube point: the sixteen `Dom::F` planes, the seven LogUp
helpers and the `fact` helper, the group column, the gate `supp(F)`. -/
noncomputable def restFR (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
    (b : Fin (c.sh.logs .F) → Bool) : List K :=
  [aPl U P D (DefR13.aOff c (86 + 2 * ls)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 1)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 1 + 1)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 1 + 2)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 4)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 5)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 6)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 6 + 1)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 8)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 8 + 1)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 10)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 11)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 11 + 1)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 11 + 2)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 14)) (c.sh.logs .F) b,
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 14 + 1)) (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 6)).1 (DefR13.hOff c (DefR13.fh c 6)).2 (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 6 + 1)).1 (DefR13.hOff c (DefR13.fh c 6 + 1)).2 (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 6 + 2)).1 (DefR13.hOff c (DefR13.fh c 6 + 2)).2 (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 6 + 3)).1 (DefR13.hOff c (DefR13.fh c 6 + 3)).2 (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 6 + 4)).1 (DefR13.hOff c (DefR13.fh c 6 + 4)).2 (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 6 + 5)).1 (DefR13.hOff c (DefR13.fh c 6 + 5)).2 (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 6 + 6)).1 (DefR13.hOff c (DefR13.fh c 6 + 6)).2 (c.sh.logs .F) b,
    hPl U P D (DefR13.hOff c (DefR13.fh c 7)).1 (DefR13.hOff c (DefR13.fh c 7)).2 (c.sh.logs .F) b,
    algebraMap GF K (B.grpCol (splitF c (castB G.logF b))), algebraMap GF K (B.gF (splitF c (castB G.logF b)))]

/-- The value list without the draws: the `eq` entries `0`. -/
noncomputable def valsFR (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
    (b : Fin (c.sh.logs .F) → Bool) : List K :=
  0 :: 0 :: 0 :: restFR U G P D B b

/-- The LogUp lookups read in the field at a history (they read only `α`, `γ`). -/
noncomputable def lksFR (U : K) (c : W16Cfg) (ls : ℕ) (hist : Hist) (dr : List Fp2) : List (LkD K) :=
  ((DefR13.lksS c (shFR ls) .F).map (LkD.map (Sym.eval hist 18 dr))).map (LkD.map (Fp2.toK U))

/-- The batch weights `μ` the IR reads (draws `0 … 11`). -/
noncomputable def muFR (U : K) (hist : Hist) (dr : List Fp2) : List K :=
  ((drR 18 0 12).map (Sym.eval hist 18 dr)).map (Fp2.toK U)

/-- **The batch's entries past the three named clauses**, read without the draws: entry `3` the ACT tuple's
relation, entries `4 … 10` LogUp's seven helper relations over `DefR13.lksS c shaped .F`. -/
noncomputable def xcFzcR (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
    (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin (tauLen c 18) → Bool) : K :=
  if κ = 3 then
    r13FzcAct (valsFR U G P D B b) rrFR ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] amqS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] nbS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] nb2S).toK U)
  else (lkRels (cstK U) (valsFR U G P D B b) 19 0 (lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD (κ - 4) 0

/-- **The pad planes**: `(1 − supp(F))·plane_j`, `j < 16`. -/
noncomputable def pwFzcR (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
    (j : ℕ) (b : Fin (tauLen c 18) → Bool) : K :=
  (padPls (valsFR U G P D B b) grpFR).getD j 0

/-- **The IR's zero-check sum at a value list.** -/
noncomputable def zIRR (U : K) (c : W16Cfg) (ls : ℕ) (hist : Hist) (dr : List Fp2) (v : List K) : K :=
  logupSem (cstK U) v 19 (fun k => (muFR U hist dr).getD (4 + k) 0) 0 (lksFR U c ls hist dr)
    + (muFR U hist dr).getD 3 0 * r13FzcAct v rrFR ((Sym.eval hist 18 dr amqS).toK U)
      ((Sym.eval hist 18 dr nbS).toK U) ((Sym.eval hist 18 dr nb2S).toK U)
    + padSem (cstK U) v ((muFR U hist dr).getD 11 0) (fun j => (Sym.eval hist 18 dr (Sym.pow (.dr 18 14) j)).toK U)
      0 grpFR
    + gV v (some 28) * batchV (muFR U hist dr) (r13FzcClauses (cstK U) rrFR c.p.fold c.p.prodbits v)

/-- The `eq` points of the three `eq` tables, read in the field. -/
noncomputable def tauFR (U : K) (c : W16Cfg) (ev : Sym → Fp2) : Fin (c.sh.logs .F) → K :=
  fun a => (((drR 18 15 (c.sh.logs .F)).map ev).getD a Fp2.zero).toK U

noncomputable def p0FR (U : K) (c : W16Cfg) (ev : Sym → Fp2) : Fin (c.sh.logs .F) → K :=
  fun a => (((drR 11 0 c.sh.lt ++ drR 11 c.sh.lt c.sh.lf).map ev).getD a Fp2.zero).toK U

noncomputable def p1FR (U : K) (c : W16Cfg) (ev : Sym → Fp2) : Fin (c.sh.logs .F) → K :=
  fun a => (((drR 11 0 c.sh.lt ++ drR 12 0 c.sh.lf).map ev).getD a Fp2.zero).toK U

/-- **The value list `SC_FZC`'s IR reads at a cube point with the zero extension.** -/
noncomputable def vFR (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay) (ev : Sym → Fp2)
    (b : Fin (c.sh.logs .F) → Bool) : List K :=
  eqPoly (tauFR U c ev) (fun a => bit (b a)) :: eqPoly (p0FR U c ev) (fun a => bit (b a))
    :: eqPoly (p1FR U c ev) (fun a => bit (b a)) :: restFR U G P D B b

end Defs

/-! ## The value list at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A numbered `A` table on its own `n` coordinates, at the zero extension of a cube of `n` main variables.** -/
theorem tabK_aSet (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool)
    (hn : 0 < n) (aB hB ioIn ioOut ak hk off : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
      ⟨.a, [(off, false)], n, DefW16.rhoC 0 n, 0, 0⟩))) = aPl U P D off n b := by
  show tabK U P D n e (cpt n e b)
    (TabS.eval ev pub (.priv ⟨.a, [(off, false)], n, DefW16.rhoC 0 n, aB + 2 * ak, 0⟩)) = _
  rw [aTab_eval, tabK_pa_cpt U P D hrl n e b n hn rfl, castB_rfl]

/-- **A numbered `H` table on its own `n` coordinates, at the zero extension.** -/
theorem tabK_hSet (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .h) (n e : ℕ) (b : Fin n → Bool)
    (hn : 0 < n) (aB hB ioIn ioOut ak hk re im : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
      ⟨.h, [(re, false), (im, true)], n, DefW16.rhoC 0 n, 0, 0⟩))) = hPl U P D re im n b := by
  show tabK U P D n e (cpt n e b)
    (TabS.eval ev pub (.priv ⟨.h, [(re, false), (im, true)], n, DefW16.rhoC 0 n, hB + 2 * hk, 0⟩)) = _
  rw [hTab_eval, tabK_ph_cpt U P D hrl n e b n hn rfl, castB_rfl]

variable {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
  {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

include G in
/-- `Dom::F` has at least one variable. -/
theorem logF_pos : 0 < c.sh.logs .F := by
  rw [G.logF]
  have := G.lt_pos
  show 0 < c.sh.lt + c.sh.lf
  omega

/-- **`SC_FZC`'s value list at a cube point with the zero extension.** -/
theorem fzcR_vals (hrl : 0 < rowLog P .a) (aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2)
    (hg0 : ∀ b : Fin (c.sh.logs .F) → Bool, ((pub 0).getD (msbIndex (c.sh.logs .F) b) Fp2.zero).toK U
      = algebraMap GF K (B.grpCol (splitF c (castB G.logF b))))
    (hg1 : ∀ b : Fin (c.sh.logs .F) → Bool, ((pub 1).getD (msbIndex (c.sh.logs .F) b) Fp2.zero).toK U
      = algebraMap GF K (B.gF (splitF c (castB G.logF b))))
    (b : Fin (c.sh.logs .F) → Bool) :
    ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabsFR c ls)).map (TabS.eval ev pub)).map
        (tabK U P D (c.sh.logs .F) e (cpt (c.sh.logs .F) e b))
      = vFR U G P D B ev b := by
  have hT : 0 < c.sh.logs .F := logF_pos G
  have hrlh : 0 < rowLog P .h := hrl
  have l1 : ((drR 18 15 (c.sh.logs .F)).map ev).length = c.sh.logs .F := by rw [List.length_map, drR_length]
  have l2 : ((drR 11 0 c.sh.lt ++ drR 11 c.sh.lt c.sh.lf).map ev).length = c.sh.logs .F := by
    rw [List.length_map, List.length_append, drR_length, drR_length, G.logF]
  have l3 : ((drR 11 0 c.sh.lt ++ drR 12 0 c.sh.lf).map ev).length = c.sh.logs .F := by
    rw [List.length_map, List.length_append, drR_length, drR_length, G.logF]
  simp only [tabsFR, eqFR, aFR, hFR, aF, hF, List.cons_append, List.nil_append, DefW16.numTabs, List.map_cons,
    List.map_nil, eqT_eval, pubT_eval, tabK_aSet U P D hrl _ e b hT, tabK_hSet U P D hrlh _ e b hT,
    tabK_pub_cpt, hg0, hg1, tabK_eqFull_cpt U P D _ e b _ l1, tabK_eqFull_cpt U P D _ e b _ l2,
    tabK_eqFull_cpt U P D _ e b _ l3]
  rfl

/-- Off the zero extension the three `eq` entries are `0`. -/
theorem fzcR_off (aB hB ioIn ioOut ak hk n e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin n → Bool)
    (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabsFR c ls)).map (TabS.eval ev pub)).map
        (tabK U P D n e (bpt n e b y))).getD 0 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabsFR c ls)).map (TabS.eval ev pub)).map
        (tabK U P D n e (bpt n e b y))).getD 1 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabsFR c ls)).map (TabS.eval ev pub)).map
        (tabK U P D n e (bpt n e b y))).getD 2 0 = 0 :=
  ⟨tabK_eq_off U P D n e b y hy _ _, tabK_eq_off U P D n e b y hy _ _, tabK_eq_off U P D n e b y hy _ _⟩

end Vals

/-! ## The IR and the slot's cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_FZC`'s IR read in the field**: L13's host terms with `Z` the zero-check sum `zIRR`. -/
theorem fzcR_irEval (c : W16Cfg) (ls : ℕ) (hnlk : (DefR13.lookups c .F).length = 14) (hist : Hist)
    (dr : List Fp2) (v : List K) :
    irEval (((irFR c ls).map (Sym.eval hist 18 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 (some 28) (some 28) (((drR 18 12 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U))
          (zIRR U c ls hist dr v) (reqBV (cstK U) v c.p.gate 3 [4, 5, 6])
          (reqBV (cstK U) v c.p.up 8 [11, 12]) := by
  unfold irFR
  rw [r13FzcIr_map, r13FzcIr_map, cstS_map, r13FzcIr_eval _ (cstW_map_std U)]
  have hl : (((DefR13.lksS c (shFR ls) .F).map (LkD.map (Sym.eval hist 18 dr))).map
      (LkD.map (Fp2.toK U))).length = 14 := by
    rw [List.length_map, List.length_map, DefR13.lksS, List.length_map, hnlk]
  simp only [hl]
  rfl

variable {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
  {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

/-- **`SC_FZC`'s cube sum** (`n = |Dom::F|` main variables). -/
theorem fzcR_cube (hrl : 0 < rowLog P .a) (hnlk : (DefR13.lookups c .F).length = 14) (n e : ℕ)
    (hn : n = c.sh.logs .F) (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hg0 : ∀ b : Fin (c.sh.logs .F) → Bool, ((pub 0).getD (msbIndex (c.sh.logs .F) b) Fp2.zero).toK U
      = algebraMap GF K (B.grpCol (splitF c (castB G.logF b))))
    (hg1 : ∀ b : Fin (c.sh.logs .F) → Bool, ((pub 1).getD (msbIndex (c.sh.logs .F) b) Fp2.zero).toK U
      = algebraMap GF K (B.gF (splitF c (castB G.logF b))))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((irFR c ls).map (Sym.eval hist 18 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabsFR c ls)).map (TabS.eval (Sym.eval hist 18 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin (c.sh.logs .F) → Bool, hostPoly (tauFR U c (Sym.eval hist 18 dr))
      (fun b => zIRR U c ls hist dr (vFR U G P D B (Sym.eval hist 18 dr) b))
      ![(((drR 18 12 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 0 0,
        (((drR 18 12 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 1 0]
      ![p0FR U c (Sym.eval hist 18 dr), p1FR U c (Sym.eval hist 18 dr)] (fun _ => 1)
      (fun i b => if i = 0
        then gV (vFR U G P D B (Sym.eval hist 18 dr) b) (some 28)
          * reqBV (cstK U) (vFR U G P D B (Sym.eval hist 18 dr) b) c.p.gate 3 [4, 5, 6]
        else gV (vFR U G P D B (Sym.eval hist 18 dr) b) (some 28)
          * reqBV (cstK U) (vFR U G P D B (Sym.eval hist 18 dr) b) c.p.up 8 [11, 12]) b := by
  subst hn
  have hv := fzcR_vals U G P D B hrl aB hB ioIn ioOut ak hk e (Sym.eval hist 18 dr) pub hg0 hg1
  rw [cubeSum_host (c.sh.logs .F) e (fun x => ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabsFR c ls)).map
      (TabS.eval (Sym.eval hist 18 dr) pub)).map (tabK U P D (c.sh.logs .F) e x))
    0 1 2 (some 28) (some 28) (((drR 18 12 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)) (zIRR U c ls hist dr)
    (fun v => reqBV (cstK U) v c.p.gate 3 [4, 5, 6]) (fun v => reqBV (cstK U) v c.p.up 8 [11, 12]) f
    (fun x => by rw [hf x, fzcR_irEval U c ls hnlk hist dr])
    (fun b y hy => fzcR_off U P D aB hB ioIn ioOut ak hk (c.sh.logs .F) e (Sym.eval hist 18 dr) pub b y hy)
    (tauFR U c (Sym.eval hist 18 dr)) ![p0FR U c (Sym.eval hist 18 dr), p1FR U c (Sym.eval hist 18 dr)]
    (fun b => (congrArg (fun l : List K => l.getD 0 0) (hv b)).trans rfl)
    (fun b => (congrArg (fun l : List K => l.getD 1 0) (hv b)).trans rfl)
    (fun b => (congrArg (fun l : List K => l.getD 2 0) (hv b)).trans rfl)]
  simp only [hv]

end Cube

end ZK60.Exec.Block.Join.R13H.Fzc
