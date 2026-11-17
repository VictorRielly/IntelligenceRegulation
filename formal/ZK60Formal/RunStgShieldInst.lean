/-
D63 lane L63 (2026-11-16), part 3: **the real `ΦI`, `ΦO` and the premises `hDI_stg`, `hDO_stg` at the app's two stages**
(deliverable 1).

* **`sshΦI`**, **`sshΦO`**: THE REAL DEFINE POLYNOMIALS of stage IN-C and stage OUT-C over the view: `stgΦR` at the
  schedule the header reader reads (`vdWin`, `vdWout`, as in `stgFstI`, `stgFstO`) and the claims' semantics at the
  stage's roots (`stgCsv`, as in `stgFstI`, `stgFstO`);
* `ssh_hostOut2`: OUT-C's hosted slots (SS, PD) host nothing;
* **`ssh_hDI`**, **`ssh_hDO`**: `StgDefAtV` at the real polynomials for stage IN-C (part `0`) and stage OUT-C, from
  `¬ rtKsl.Dm`, the part's slots being the stage's (`hb0`, `hbL`), `StgTrueAt` (`hTrI`, `hTrO`), for OUT-C also `M`'s host
  functionals (`StgHostTrueAt`), the IO semantics reading the view below the stage's head (`VwLoc`), and every stage
  slot's variable count below `64` (the code's `1 << n`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldRd

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV OutcV incCtx)
open ZK60.Circuit (gP GF)

section Phi

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **THE REAL `ΦI`**: stage IN-C's define polynomial over the view, at the schedule `Win` reads (as `stgFstI`). -/
noncomputable def sshΦI (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K :=
  stgΦR U hbij P0 (fun v ch => (vdWin Vi (v.2.take n0)).bp (incCtx (vdWin Vi (v.2.take n0)).pub ch))
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO)

/-- **THE REAL `ΦO`**: stage OUT-C's define polynomial over the view, at the schedule `Wout` reads (as `stgFstO`). -/
noncomputable def sshΦO (P0 : Block.BlockParams) (F : ℕ → OutcV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K :=
  stgΦR U hbij P0 (fun v _ => (vdWout F (v.2.take n0)).bp) OutcV.bga
    (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO)

end Phi

/-- **OUT-C's hosted slots host nothing** (TZC hosts SS = slot `1`, LZC hosts PD = slot `3`). -/
theorem ssh_hostOut2 (P0 : Block.BlockParams) : ∀ k, ∀ x ∈ stgHostOut P0 k, stgHostOut P0 x.1 = [] := by
  intro k x hx
  simp only [stgHostOut] at hx
  split_ifs at hx
  · rw [List.mem_singleton] at hx
    subst hx
    simp [stgHostOut]
  · rw [List.mem_singleton] at hx
    subst hx
    simp [stgHostOut]
  · simp at hx

section Run

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)
  (tag : MTag) (h64 : 64 ≤ Lq)

/-- **`hDI_stg` AT THE REAL `ΦI`** (stage IN-C, part `0`). -/
theorem ssh_hDI (hU : U ^ 2 = algebraMap GF K 7) (n : ℕ) (hi : 0 < pf.parts.length) (hin : 0 < n)
    (Pof : List Fp2 → Block.BlockParams) (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen m lc h Q e rA rH S : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K)
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hhost : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (stgHostIn k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ 512)
    (hN64 : ∀ k, k < P0.geom.slots.length → stgN P0 k < 64)
    (hIOl : VwLoc (hdrLen + (7 + m)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hS : D.sls 0 = stgSchedV P0 m hdrLen stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgFstI U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO))
    (hns : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (htrue : StgTrueAt U key domain Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (fun v ch => ((vdWin Vi) (v.2.take n0)).bp (incCtx ((vdWin Vi) (v.2.take n0)).pub ch))
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO) (stgMsv U tag h64 S (hdrLen + 3)) G lg τ) :
    StgDefAtV U key domain P0 Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (sshΦI U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO)
      G lg τ := by
  have hslot := ssh_slotStart key domain hs Lq hL pf rd hL64 hv U hbij D hD n 0 hi hin P0 Pof m hdrLen
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (stgFstI U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO) G lg τ hP hgt hS hns
  exact ssh_defAtV U hbij hU key domain P0 Pof m hdrLen _ stgHostIn _ _ _ (stgRv U tag h64 S (hdrLen + 3))
    (stgMsv U tag h64 S (hdrLen + 3)) 512 G lg τ hP hgt hd hhost (fun _ _ _ => rfl)
    (fun k hk => ⟨(hN k hk).1, hN64 k hk, (hN k hk).2⟩) (stgMsv_mlin U tag h64 S (hdrLen + 3))
    (hdrLen + (7 + m)) le_rfl (vwLoc_vdWin Vi n0 _)
    (vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) _ (by omega) (by omega) csIO hIOl)
    (vwLoc_stgRv U tag h64 S (hdrLen + 3) _ (by omega)) (vwLoc_stgMsv U tag h64 S (hdrLen + 3) _ (by omega))
    hslot htrue (Or.inl (fun _ => rfl))

/-- **`hDO_stg` AT THE REAL `ΦO`** (stage OUT-C, part `i = Lb + 1`). -/
theorem ssh_hDO (hU : U ^ 2 = algebraMap GF K 7) (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n)
    (Pof : List Fp2 → Block.BlockParams) (P0 : Block.BlockParams) (F : ℕ → OutcV) (n0 hdrLen lc h Q e rA rH S : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K)
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hhost : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (stgHostOut P0 k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ 512)
    (hN64 : ∀ k, k < P0.geom.slots.length → stgN P0 k < 64)
    (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hS : D.sls i = stgSchedV P0 2 hdrLen (stgHostOut P0) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgFstO U hbij tag h64 P0 (vdWout F) n0 hdrLen lc h Q e rA rH S csIO))
    (hns : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (htrue : StgTrueAt U key domain Pof 2 hdrLen OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (fun v _ => ((vdWout F) (v.2.take n0)).bp)
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO) (stgMsv U tag h64 S (hdrLen + 3)) G lg τ)
    (hhf : StgHostTrueAt U key domain Pof 2 hdrLen OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgMsv U tag h64 S (hdrLen + 3)) G lg τ) :
    StgDefAtV U key domain P0 Pof 2 hdrLen OutcV.bga
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO)
      G lg τ := by
  have hslot := ssh_slotStart key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin P0 Pof 2 hdrLen
    OutcV.bga (stgHostOut P0) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (stgFstO U hbij tag h64 P0 (vdWout F) n0 hdrLen lc h Q e rA rH S csIO) G lg τ hP hgt hS hns
  exact ssh_defAtV U hbij hU key domain P0 Pof 2 hdrLen _ (stgHostOut P0) _ _ _ (stgRv U tag h64 S (hdrLen + 3))
    (stgMsv U tag h64 S (hdrLen + 3)) 512 G lg τ hP hgt hd hhost (ssh_hostOut2 P0)
    (fun k hk => ⟨(hN k hk).1, hN64 k hk, (hN k hk).2⟩) (stgMsv_mlin U tag h64 S (hdrLen + 3))
    (hdrLen + (7 + 2)) le_rfl (vwLoc_vdWout F n0 _ (by omega))
    (vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) _ (by omega) (by omega) csIO hIOl)
    (vwLoc_stgRv U tag h64 S (hdrLen + 3) _ (by omega)) (vwLoc_stgMsv U tag h64 S (hdrLen + 3) _ (by omega))
    hslot htrue (Or.inr hhf)

end Run

end ZK60.ProtocolClassify
