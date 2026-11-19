/-
D63 lane L63 (2026-11-19), L63 leg 12, part 84: **OUT-C's byte slots' facts at every reading of a run with no doomed
R0 entrant, and `hLO_stg`'s conclusion from them and the two sum facts** (pieces (iii) and (v) of step 1 of
HANDOFF_20261119_1.md joined; the OUT-C twin of `shd_inc_qt_run` / `shd_hLI_run`, RunStgShieldIncAt.lean).

* **`shd_outc_slots_run`**: at stage OUT-C's registered numbers (`llo = ldo = ltab = 12`, `bLogN = 14`, `A_out` of
  `76` rows), at every OUT-C reading with no doomed `rtKR0` entrant, `ShdOutcSlotsT` at `τ`'s view
  (`stg_outc_def_zero_tau` at slots `4`, `5`, `6`, moved from the view's schedule `vdWout F (τ.take n0)` to `F b` by
  `hW`; `outc_lzc_clauses` / `outc_lzc_vals`, `outc_dzc_pairs` / `outc_dzc_vals`, `outc_tab_clauses` /
  `outc_tab_vals`);
* **`shd_hLO_runR`**: with the two sum facts at the readings (`OutCSum` of the `H_out` helpers and the zero-sum row),
  `hLO_stg`'s conclusion `StgLkAtV … shd_ΛO …` (`shd_hLO_of_slotsT`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutDzcV

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Run

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **NO DOOMED R0 ENTRANT: OUT-C'S BYTE SLOTS' FACTS AT EVERY READING**, at stage OUT-C's registered numbers (the
`A_out` planes and the `H_out` helpers at `τ`'s view). -/
theorem shd_outc_slots_run (hU : U ^ 2 = algebraMap GF K 7) (n Lb : ℕ) (hi : Lb + 1 < pf.parts.length)
    (hin : Lb + 1 < n) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (P0 : Block.BlockParams) (F : ℕ → OutcV)
    (b n0 hdrLen rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (hn0 : n0 ≤ hdrLen + (7 + 2))
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
    have h := stg_outc_def_zero_tau key domain hs Lq hL pf rd hL64 hv U hbij D hD n Lb hi hin tag h64 P0 F b n0 hdrLen
      ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH csIO hIOl hn0 hR G lg τ hno hdr core ch rs hrd hP hgt hgeom k hk y
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

/-- **`hLO_stg`'S CONCLUSION AT A RUN WITH NO DOOMED R0 ENTRANT, GIVEN THE TWO SUM FACTS AT THE READINGS**:
`StgLkAtV … shd_ΛO …`, at stage OUT-C's registered numbers. -/
theorem shd_hLO_runR (hU : U ^ 2 = algebraMap GF K 7) (n Lb : ℕ) (hi : Lb + 1 < pf.parts.length)
    (hin : Lb + 1 < n) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (P0 : Block.BlockParams) (F : ℕ → OutcV)
    (b n0 hdrLen rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (hn0 : n0 ≤ hdrLen + (7 + 2))
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
    (shd_outc_slots_run key domain hs Lq hL pf rd hL64 hv U hbij D hD hU n Lb hi hin tag h64 O P0 F b n0 hdrLen rH
      csIO hIOl hn0 hR hP hgt hgeom hsl hGb hOL hllo hldo hltab hlt hlc G lg τ hW hno) hsum

end Run

end ZK60.ProtocolClassify
