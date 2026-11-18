/-
D63 lane L63 (2026-11-18), part 63: **SIC_QZC's and SIC_TZC's conclusions at every reading of a run with no doomed
R0 entrant, and `hLI_stg`'s conclusion from them and the two sum facts** (item 4b, the run-level assembly; generic in
the stage's `IncV` under the registered stage's numbers, which the concrete top supplies).

* `stg_rd_chal`: a reading's head challenges are canonical and `m` of them;
* **`shd_inc_qt_run`**: at every reading of stage IN-C on `τ`, `QzcHolds` and `TzcHolds` of `shdIncLay` and
  `shdIncHd` at `τ`'s view (`stg_inc_def_zero` at slots `1` and `2`, `shd_inc_qt`);
* **`shd_hLI_run`**: with `ShdIncSumAt` at `τ`'s view, `hLI_stg`'s conclusion `StgLkAtV … shd_ΛI …`
  (`shd_hLI_of_sum`);
* `shd_hEmb_exists`: the announced premise `hEmb` (finding L63-8) is not vacuous.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncJoin

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

/-- **A reading's head challenges are canonical and `m` of them.** -/
theorem stg_rd_chal {L : ℕ} (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs) :
    (∀ a ∈ ch, a.Canon) ∧ ch.length = m := by
  obtain ⟨-, -, -, -, ⟨acc, t', hacc⟩, -⟩ := hrd
  rw [StageFS.stageSlots_eq] at hacc
  split at hacc
  · simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, -⟩ := hacc
    rw [← hch]
    exact ssh_chalVec (liftH G) m _
  · cases hacc

section Emb

variable {K : Type} [Field K] [Algebra GF K]

/-- **The premise `hEmb` is not vacuous**: for every padded embedding there is a public fold meeting it (its words
the field values `E~(v, r)` of the multilinear extension, through the bijection `fp2 U`). -/
theorem shd_hEmb_exists (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (V : ℕ)
    (Epad : Fin V → (Fin 12 → Bool) → GF) :
    ∃ embFold : List Fp2 → List Fp2, ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) →
      ∀ v : Fin V, ((embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U) := by
  refine ⟨fun rEmb => List.ofFn (fun v : Fin V => ZK60.HonestClassify.ofK U hbij
    (mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))), ?_⟩
  intro rEmb _ _ v
  rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn, dite_eq_left v.isLt, Option.getD_some,
    ZK60.HonestClassify.toK_ofK U hbij]

end Emb

section Run

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **NO DOOMED R0 ENTRANT: SIC_QZC'S AND SIC_TZC'S CONCLUSIONS AT EVERY READING**, at stage IN-C's registered
numbers (the layout and the helpers at `τ`'s view). -/
theorem shd_inc_qt_run (hU : U ^ 2 = algebraMap GF K 7) (n : ℕ) (hi : 0 < pf.parts.length) (hin : 0 < n)
    (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (P0 : Block.BlockParams) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (n0 hdrLen iB rA rH rX : ℕ) (hrA : rA = 41) (hrX : rX = 38)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 15)) csIO)
    (hcsO : ∀ w z, csIO w .out z = claimSem U rX 14 256 (bxUxV tag Lq h64 rX iB w) z)
    (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO)
    (hR : D.r0 0 = stgDefsV P0 15 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH csIO) sshDgI)
    (hP : ∀ ch, StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hgt : ∀ ch, (Vi.bp (incCtx Vi.pub ch)).geom.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.terms.length)
    (hgeom : ∀ ch k, k < (Vi.bp (incCtx Vi.pub ch)).geom.slots.length →
      1 ≤ (Block.slotShape (Vi.bp (incCtx Vi.pub ch)) k).2.2)
    (hsl : 3 ≤ P0.geom.slots.length) (hd1 : 0 < P0.draws 1) (hd2 : 0 < P0.draws 2)
    (hti : Vi.pub.tiLog = 12) (hvoc : Vi.pub.vocLog = 17) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19)
    (hGb : Vi.geo.bLogN = 14) (hlt : Vi.pub.lt ≤ ogStage.lc) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hbos : Vi.pub.bos < 2 ^ 63) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hvP : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) :
    ∀ hdr core ch rs, StgRd key domain Lq (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G τ hdr core ch rs →
      ch.length = 15
      ∧ QzcHolds (incQ (shdIncLay U tag h64 P Vi.pub Epad iB hdrLen
            (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) hvP hV htok hcq) (incChalOf U ch)
          (shdIncHd U tag h64 Vi.pub ogStage.lc ogStage.h ogStage.Q ogStage.e rH (hdrLen + 4 + 15)
            (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ)))
        (incChalOf U ch).1.2 (incChalOf U ch).1.1.1
        ((shdIncLay U tag h64 P Vi.pub Epad iB hdrLen
          (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) hvP hV htok hcq).g (incChalOf U ch))
        (shdIncLay U tag h64 P Vi.pub Epad iB hdrLen
          (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) hvP hV htok hcq).bos
      ∧ TzcHolds (incT (shdIncLay U tag h64 P Vi.pub Epad iB hdrLen
            (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) hvP hV htok hcq) (incChalOf U ch)
          (shdIncHd U tag h64 Vi.pub ogStage.lc ogStage.h ogStage.Q ogStage.e rH (hdrLen + 4 + 15)
            (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ)))
        (incChalOf U ch).1.2 := by
  intro hdr core ch rs hrd
  obtain ⟨hch, hl⟩ := stg_rd_chal key domain _ 15 hdrLen _ G τ hdr core ch rs hrd
  have hmem : ∀ k, k < 3 → 0 < P0.draws k → k ∈ stgDrawing P0 := fun k hk hdk =>
    List.mem_filter.mpr ⟨List.mem_range.mpr (by omega), by simpa using hdk⟩
  have hslen : core.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.slots.length := hrd.2.2.2.1.1
  obtain ⟨acc, t', hacc⟩ := hrd.2.2.2.2.1
  have hrsl : rs.length = core.slots.length :=
    (ssh_rd_facts key domain _ 15 hdrLen _ G τ hdr core ch rs hrd (hgt ch) (hgeom ch) acc t' hacc).1
  have hcore3 : 3 ≤ rs.length := by rw [hrsl, hslen, ← (hP ch).2]; exact hsl
  have hz1 := stg_inc_def_zero key domain hs Lq hL pf rd hL64 hv U hbij D hD n hi hin tag h64 P0 Vi n0 hdrLen
    ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH csIO hIOl hR G lg τ hno hdr core ch rs hrd (hP ch) (hgt ch)
    (hgeom ch) 1 (hmem 1 (by norm_num) hd1)
  have hz2 := stg_inc_def_zero key domain hs Lq hL pf rd hL64 hv U hbij D hD n hi hin tag h64 P0 Vi n0 hdrLen
    ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH csIO hIOl hR G lg τ hno hdr core ch rs hrd (hP ch) (hgt ch)
    (hgeom ch) 2 (hmem 2 (by norm_num) hd2)
  refine ⟨hl, shd_inc_qt U hbij tag h64 hU P P0 Vi Epad iB hdrLen rA rH (hdrLen + 4 + 15) rX hrA hrX csIO _
    (hcsO _) hIO1 ch hl hch (hP ch) hti hvoc htB hbIn hGb hlt hlc hbos hkap hns hVV hEmb hvP hV htok hcq
    ((rs.take 1).map Block.SlotRec.draws) ((rs.take 2).map Block.SlotRec.draws)
    (by rw [List.length_map, List.length_take]; omega) (by rw [List.length_map, List.length_take]; omega) hz1 hz2⟩

/-- **`hLI_stg`'S CONCLUSION AT A RUN WITH NO DOOMED R0 ENTRANT, GIVEN THE TWO SUM FACTS** (`ShdIncSumAt` at `τ`'s
view): `StgLkAtV … shd_ΛI …`, at stage IN-C's registered numbers. -/
theorem shd_hLI_run (hU : U ^ 2 = algebraMap GF K 7) (n : ℕ) (hi : 0 < pf.parts.length) (hin : 0 < n)
    (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (P0 : Block.BlockParams) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (n0 hdrLen iB rA rH rX : ℕ) (hB : iB < hdrLen + 4)
    (hrA : rA = 41) (hrX : rX = 38)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 15)) csIO)
    (hcsO : ∀ w z, csIO w .out z = claimSem U rX 14 256 (bxUxV tag Lq h64 rX iB w) z)
    (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO)
    (hR : D.r0 0 = stgDefsV P0 15 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH csIO) sshDgI)
    (hP : ∀ ch, StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hgt : ∀ ch, (Vi.bp (incCtx Vi.pub ch)).geom.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.terms.length)
    (hgeom : ∀ ch k, k < (Vi.bp (incCtx Vi.pub ch)).geom.slots.length →
      1 ≤ (Block.slotShape (Vi.bp (incCtx Vi.pub ch)) k).2.2)
    (hsl : 3 ≤ P0.geom.slots.length) (hd1 : 0 < P0.draws 1) (hd2 : 0 < P0.draws 2)
    (hti : Vi.pub.tiLog = 12) (hvoc : Vi.pub.vocLog = 17) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19)
    (hGb : Vi.geo.bLogN = 14) (hlt : Vi.pub.lt ≤ ogStage.lc) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hbos : Vi.pub.bos < 2 ^ 63) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hvP : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (hsum : ShdIncSumAt U tag h64 Vi.pub rH (hdrLen + 4 + 15)
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ)) :
    StgLkAtV U key domain (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (shd_ΛI U tag h64 P Vi.pub Epad iB hdrLen) G lg τ :=
  shd_hLI_of_sum U tag h64 P Vi.pub Epad iB hdrLen rH (hdrLen + 4 + 15) hB hvP hV htok hcq key domain
    (fun ch => Vi.bp (incCtx Vi.pub ch)) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
    (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G lg τ
    (shd_inc_qt_run key domain hs Lq hL pf rd hL64 hv U hbij D hD hU n hi hin tag h64 P P0 Vi Epad n0 hdrLen iB rA rH
      rX hrA hrX csIO hIOl hcsO hIO1 hR hP hgt hgeom hsl hd1 hd2 hti hvoc htB hbIn hGb hlt hlc hbos hkap hns hVV hEmb
      hvP hV htok hcq G lg τ hno) hsum

end Run

end ZK60.ProtocolClassify
