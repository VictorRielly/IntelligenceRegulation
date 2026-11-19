/-
D63 lane L63 (2026-11-19), L63 leg 13, part 88: **OUT-C's byte slots and `hLO_stg`'s conclusion WITHOUT the window
bound `n0 ≤ hdrLen + 9`** (decision D3 of leg 13). The leg-12 lemmas `vwLoc_sshΦO`, `stg_outc_def_zero_tau`,
`shd_outc_slots_run`, `shd_hLO_runR` (RunStgShieldOutZero.lean, RunStgShieldOutAt.lean) ask `hn0 : n0 ≤ hdrLen + 9`;
at the concrete top `n0 = off 27 + pre` with `pre = 11 + shapeLen …` (`RtOutc.hpre`), so that bound cannot be met.
It is not needed: the verdict window `vdWout F (v.2.take n0)` reads only the byte at position `6`, for every `n0`
(`vwLoc_vdWout`). The twins below drop it; the leg-12 files are not edited.

* **`vwLoc_sshΦO_any`**: `sshΦO` reads the view below `hdrLen + 9`, for every `n0`;
* `stg_outc_def_zero_tauN`, `shd_outc_slots_runN`, **`shd_hLO_runRN`**: the leg-12 proofs without `hn0`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutAt

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section LocOutN

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **`sshΦO` reads the view below `hdrLen + 9`, for every verdict window `n0`** (the window reads byte `6` only). -/
theorem vwLoc_sshΦO_any (P0 : Block.BlockParams) (F : ℕ → OutcV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (k : ℕ) (hh : List Fp2 × List (List Fp2)) (y : Fin (P0.draws k) → K) :
    VwLoc (hdrLen + (7 + 2)) (fun v => sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO v k hh y) := by
  intro v v' h1 h2
  have hc := vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) _ (by omega) (by omega) csIO hIOl
    v v' h1 h2
  have hw : (vdWout F (v.2.take n0)).bp = (vdWout F (v'.2.take n0)).bp :=
    congrFun (vwLoc_vdWout (L := Lq) F n0 (hdrLen + (7 + 2)) (by omega) v v' h1 h2) hh.1
  show stgΦR U hbij P0 (fun v _ => (vdWout F (v.2.take n0)).bp) OutcV.bga
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO) v k hh y
    = stgΦR U hbij P0 (fun v _ => (vdWout F (v.2.take n0)).bp) OutcV.bga
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO) v' k hh y
  unfold stgΦR
  beta_reduce
  rw [hc, hw]

end LocOutN

section ZeroOutTN

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **`stg_outc_def_zero_tau` without the window bound `hn0`.** -/
theorem stg_outc_def_zero_tauN (n Lb : ℕ) (hi : Lb + 1 < pf.parts.length) (hin : Lb + 1 < n) (tag : MTag)
    (h64 : 64 ≤ Lq) (P0 : Block.BlockParams) (F : ℕ → OutcV) (b n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (hR : D.r0 (Lb + 1) = stgDefsV P0 2 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (k : ℕ) (hk : k ∈ stgDrawing P0) :
    ∀ y, sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) k
        (ch, (rs.take k).map Block.SlotRec.draws) y = 0 := by
  intro y
  have hz := stg_outc_def_zero key domain hs Lq hL pf rd hL64 hv U hbij D hD n Lb hi hin tag h64 P0 F b n0 hdrLen
    lc h Q e rA rH csIO hR G lg τ hno hdr core ch rs hrd hP hgt hgeom k hk y
  have hslen : core.slots.length = (F b).bp.geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← hP.2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
  obtain ⟨h1, -⟩ := stg_rd_def key domain (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs hrd hgt k q hq
  have hmv := vw_take (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg (hdrLen + (7 + 2))
    (stgDefPos (F b).bp 2 hdrLen k) (by unfold stgDefPos; omega) _
    (vwLoc_sshΦO_any U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO hIOl k
      (ch, (rs.take k).map Block.SlotRec.draws) y) τ
  rw [← hmv, h1]
  exact hz

/-- **`shd_outc_slots_run` without the window bound `hn0`.** -/
theorem shd_outc_slots_runN (hU : U ^ 2 = algebraMap GF K 7) (n Lb : ℕ) (hi : Lb + 1 < pf.parts.length)
    (hin : Lb + 1 < n) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (P0 : Block.BlockParams) (F : ℕ → OutcV)
    (b n0 hdrLen rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (hR : D.r0 (Lb + 1) = stgDefsV P0 2 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦO U hbij tag h64 P0 F n0 hdrLen ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH csIO) sshDgO)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (hsl : 7 ≤ P0.geom.slots.length)
    (hGb : (F b).geo.bLogN = 14) (hOL : outcLay (F b).pub 14 = outcLay O 14)
    (hllo : (F b).pub.llo = 12) (hldo : (F b).pub.ldo = 12) (hltab : (F b).pub.ltab = 12)
    (hlt : (F b).pub.lt ≤ ogStage.lc) (hlc : 0 < (F b).bp.logCols)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hW : vdWout F (τ.take n0) = F b)
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) :
    ShdOutcSlotsT U key domain (fun _ => (F b).bp) hdrLen OutcV.bga tag h64 O 76 hdrLen
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ)
      (shdOutcHd U tag h64 O rH (hdrLen + 4 + 2) (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ))
      G τ := by
  intro hdr core ch rs hrd
  obtain ⟨hch, hl⟩ := stg_rd_chal key domain _ 2 hdrLen _ G τ hdr core ch rs hrd
  have hslen : core.slots.length = (F b).bp.geom.slots.length := hrd.2.2.2.1.1
  obtain ⟨acc, t', hacc⟩ := hrd.2.2.2.2.1
  have hrsl : rs.length = core.slots.length :=
    (ssh_rd_facts key domain _ 2 hdrLen _ G τ hdr core ch rs hrd hgt hgeom acc t' hacc).1
  have hrs7 : 7 ≤ rs.length := by rw [hrsl, hslen, ← hP.2]; exact hsl
  have hmem : ∀ k, k < 7 → 0 < P0.draws k → k ∈ stgDrawing P0 := fun k hk hdk =>
    List.mem_filter.mpr ⟨List.mem_range.mpr (by omega), by simpa using hdk⟩
  have hd4 : 0 < P0.draws 4 := by rw [hP.1]; show 0 < (F b).pub.llo + 2 + 1; omega
  have hd5 : 0 < P0.draws 5 := by rw [hP.1]; show 0 < (F b).pub.ldo + 10 + 1; omega
  have hd6 : 0 < P0.draws 6 := by rw [hP.1]; show 0 < (F b).pub.ltab + 2 + 1; omega
  have hN4 : stgN P0 4 = 13 := by unfold stgN; rw [stg_slotShape hP]; show (F b).pub.llo + 1 = 13; omega
  have hN5 : stgN P0 5 = 13 := by unfold stgN; rw [stg_slotShape hP]; show (F b).pub.ldo + 1 = 13; omega
  have hN6 : stgN P0 6 = 13 := by unfold stgN; rw [stg_slotShape hP]; show (F b).pub.ltab + 1 = 13; omega
  set w := stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ with hw
  -- the define polynomial at slot `k` vanishes at every draw, on the schedule `F b`
  have hzk : ∀ k, k ∈ stgDrawing P0 → ∀ y : Fin (P0.draws k) → K,
      stgΦB U hbij P0 (F b).bp
        (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
        (OutcV.bga ch) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 := by
    intro k hk y
    have h := stg_outc_def_zero_tauN key domain hs Lq hL pf rd hL64 hv U hbij D hD n Lb hi hin tag h64 P0 F b n0
      hdrLen ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH csIO hIOl hR G lg τ hno hdr core ch rs hrd hP hgt hgeom
      k hk y
    have h' : stgΦB U hbij P0 (vdWout F (τ.take n0)).bp
        (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
        (OutcV.bga ch) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 := h
    rw [hW] at h'
    exact h'
  have hlen : ∀ k, k ≤ 7 → ((rs.take k).map Block.SlotRec.draws).length = k := fun k hk => by
    rw [List.length_map, List.length_take]; omega
  refine ⟨hl, fun z => ?_, fun k c => ?_, fun c => ?_, fun c => ?_⟩
  · -- LZC's single relation
    obtain ⟨e1, -⟩ := outc_lzc_clauses U hbij hU tag h64 P0 (F b) hP ch hch ogStage.lc ogStage.h ogStage.Q ogStage.e
      76 rH hdrLen (hdrLen + 4 + 2) csIO w hlt ((rs.take 4).map Block.SlotRec.draws) (hlen 4 (by norm_num))
      (hzk 4 (hmem 4 (by norm_num) hd4)) 12 hllo z
    obtain ⟨v3, v4⟩ := outc_lzc_vals U hbij tag h64 hU O (F b) 76 rH hdrLen (hdrLen + 4 + 2) csIO w hGb hOL hllo hlc
      (N := stgN P0 4) hN4 z
    have e1' : shdLzcR U hbij (F b)
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
          (stgN P0 4) z 4
        * ((ch.getD 1 Fp2.zero).toK U - (shdLzcR U hbij (F b)
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
          (stgN P0 4) z 3 + (ch.getD 0 Fp2.zero).toK U * algebraMap GF K (tagU8 : GF))) - 1 = 0 := e1
    rw [v3, v4] at e1'
    exact e1'
  · -- DZC's pair relations
    have e := outc_dzc_pairs U hbij hU tag h64 P0 (F b) hP ch hch ogStage.lc ogStage.h ogStage.Q ogStage.e
      76 rH hdrLen (hdrLen + 4 + 2) csIO w hlt ((rs.take 5).map Block.SlotRec.draws) (hlen 5 (by norm_num))
      (hzk 5 (hmem 5 (by norm_num) hd5)) 12 hldo c k.val k.isLt
    rw [outc_dzc_vals U hbij tag h64 hU O (F b) 76 rH hdrLen (hdrLen + 4 + 2) csIO w ch hGb hOL hldo hlc
      (N := stgN P0 5) hN5 c k] at e
    exact e
  · -- TAB's relation
    obtain ⟨t1, -, -⟩ := outc_tab_clauses U hbij hU tag h64 P0 (F b) hP ch hch ogStage.lc ogStage.h ogStage.Q
      ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w hlt ((rs.take 6).map Block.SlotRec.draws) (hlen 6 (by norm_num))
      (hzk 6 (hmem 6 (by norm_num) hd6)) 12 hltab c
    obtain ⟨-, v1, v2, v3⟩ := outc_tab_vals U hbij tag h64 hU O (F b) 76 rH hdrLen (hdrLen + 4 + 2) csIO w ch hGb hOL
      hltab hlc (N := stgN P0 6) hN6 c
    have t1' : shdTabR U hbij (F b) ch
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
          (stgN P0 6) c 3
        * ((ch.getD 1 Fp2.zero).toK U - shdTabR U hbij (F b) ch
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
          (stgN P0 6) c 1)
        - shdTabR U hbij (F b) ch
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
          (stgN P0 6) c 2 = 0 := t1
    rw [v1, v2, v3] at t1'
    exact t1'
  · -- TAB's helper pad
    obtain ⟨-, -, t3⟩ := outc_tab_clauses U hbij hU tag h64 P0 (F b) hP ch hch ogStage.lc ogStage.h ogStage.Q
      ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w hlt ((rs.take 6).map Block.SlotRec.draws) (hlen 6 (by norm_num))
      (hzk 6 (hmem 6 (by norm_num) hd6)) 12 hltab c
    obtain ⟨v0, -, -, v3⟩ := outc_tab_vals U hbij tag h64 hU O (F b) 76 rH hdrLen (hdrLen + 4 + 2) csIO w ch hGb hOL
      hltab hlc (N := stgN P0 6) hN6 c
    have t3' : (1 - shdTabR U hbij (F b) ch
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
          (stgN P0 6) c 0)
        * shdTabR U hbij (F b) ch
          (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2) csIO w)
          (stgN P0 6) c 3 = 0 := t3
    rw [v0, v3] at t3'
    exact t3'

/-- **`shd_hLO_runR` without the window bound `hn0`**: with the two sum facts at the readings, `hLO_stg`'s
conclusion `StgLkAtV … shd_ΛO …`, at stage OUT-C's registered numbers. -/
theorem shd_hLO_runRN (hU : U ^ 2 = algebraMap GF K 7) (n Lb : ℕ) (hi : Lb + 1 < pf.parts.length)
    (hin : Lb + 1 < n) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (P0 : Block.BlockParams) (F : ℕ → OutcV)
    (b n0 hdrLen rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (hR : D.r0 (Lb + 1) = stgDefsV P0 2 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦO U hbij tag h64 P0 F n0 hdrLen ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH csIO) sshDgO)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (hsl : 7 ≤ P0.geom.slots.length)
    (hGb : (F b).geo.bLogN = 14) (hOL : outcLay (F b).pub 14 = outcLay O 14)
    (hllo : (F b).pub.llo = 12) (hldo : (F b).pub.ldo = 12) (hltab : (F b).pub.ltab = 12)
    (hlt : (F b).pub.lt ≤ ogStage.lc) (hlc : 0 < (F b).bp.logCols)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hW : vdWout F (τ.take n0) = F b)
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (hsum : ∀ hdr core ch rs, StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs →
      OutCSum (shdOutcHd U tag h64 O rH (hdrLen + 4 + 2)
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ))
      ∧ ∑ j, (shdOutcHd U tag h64 O rH (hdrLen + 4 + 2)
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ)).2.2.2 j = 0) :
    StgLkAtV U key domain (fun _ => (F b).bp) 2 hdrLen OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (shd_ΛO U tag h64 O hdrLen) G lg τ :=
  shd_hLO_of_slotsT U tag h64 O hdrLen hdrLen (by omega) rH (hdrLen + 4 + 2) key domain (fun _ => (F b).bp) OutcV.bga
    (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G lg τ
    (shd_outc_slots_runN key domain hs Lq hL pf rd hL64 hv U hbij D hD hU n Lb hi hin tag h64 O P0 F b n0 hdrLen rH
      csIO hIOl hR hP hgt hgeom hsl hGb hOL hllo hldo hltab hlt hlc G lg τ hW hno) hsum

end ZeroOutTN

end ZK60.ProtocolClassify
