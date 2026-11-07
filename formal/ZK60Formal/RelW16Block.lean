/-
D63 lane L21 (2026-11-07), part 4: **`block_knowledge`'s `hRel` and `hLk`, composed**, and their errors against the
approved target.

* `OpenTrue`, **`block_knowledge_mt`** (findings L21-1 … L21-3): L16's `block_knowledge` with `hOpen` covering what `M`
  and the openings check (`OpenTrue`: the claims, `H`'s LogUp sum claim, and EVERY functional `M` receives,
  `acc.fs ++ acc.hostFs`), `hRel`'s event given `OpenTrue`, and `hLk`'s given it, the true claimed sums and the slot
  relations. Same proof: in `block_knowledge`'s case split these hold exactly where `hRel` and `hLk` are used. The
  strengthening is needed: each slot's `pb-scalar` is absorbed AFTER its `define` draws and `c`, so without `M`'s `Γ`
  functionals (which tie every scalar to the masks committed in `M` before the draws; a host's are in `acc.hostFs`) a
  prover can choose the scalars to make every claimed sum true whatever the relation: `hRel` as L16 states it is not
  dischargeable with a small `εrel`.
* `DefSched`, **`rel_of_defines`**: `hRel` (in that form, or any event `Ev`) from define schedules: if every outcome of
  the event is a win against one of `nd` define schedules (`DefWin`, the instance's algebra: unmasking with `M`'s
  functionals, the slot polynomials, the reindexing to `W16Rels`), its probability is at most `nd` times
  `block_defines_fs_knowledge`'s bound.
* `schedBound`, **`sched_le_101`**, **`rel_two_le_target`**: with escape counts `≤ 80` (a host's identity has degree
  `≤ m + 2 ≤ 66` by `RelW16HostDeg.hostPhiAt_deg`; truly `≤ 64`, the `ζ` powers of at most 64 pad planes, every other
  draw linear) and `ℓ ≤ 2^20`, ONE schedule is at most `(q + 1)/2^101` and TWO
  (W16R2's: the hosts and standalone zero-checks; the private slots) are at most `εsTarget q`, for EVERY `q`, with L8's
  count;
* **`lk_le_target`**: LogUp's bound at the 8B T128 parameters (`N + 2M ≤ 35,153,256`, `Kind8B`'s figures) is at most
  `εsTarget q` once `ℓ ≤ 6(q + 1)` (`ℓ = hdrLen + 10`); below that the verifier's own positions, charged LogUp's rate
  by L8's count, exceed the target's constant term (finding L16-1; the per-position count fixes it);
* `defOffW`, `defOff_eq`, `rung_defLen`: at the W16R2 rung `defLen = hdrLen + 1045`.

Facts about the literal prime are stated for a variable `p` within `2^32` below `2^64` (L7-4). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RelW16Define
import ZK60Formal.LookupW16FS

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The block's knowledge statement with the claims' and `M`'s truth in `hRel` and `hLk` -/

section Block

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **What the openings and `M` check, true of the extracted data** (findings L21-1 … L21-3): every claim handed to `A`,
`H` and the endpoints, `H`'s LogUp sum claim (`P.logupSumClaim`, which `blockVerify` appends to `H`'s claims), and EVERY
functional `M`'s test receives, `acc.fs ++ acc.hostFs` (the hosts' `Γ` functionals are in `acc.hostFs`). -/
def OpenTrue (U : K) (P : BlockParams) (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K) (acc : Acc) : Prop :=
  ClaimsTrue U cs acc.claims ∧ MTrue U ms (acc.fs ++ acc.hostFs) ∧ cs .h P.logupSumClaim = P.logupSumClaim.value.toK U

theorem OpenTrue.mfs {U : K} {P : BlockParams} {cs : Cm → ZClaim → K} {ms : List (ℕ × List Fp2) → K} {acc : Acc}
    (h : OpenTrue U P cs ms acc) : MTrue U ms acc.fs :=
  fun mf hmf => h.2.1 mf (List.mem_append_left _ hmf)

variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One W16R2 block's knowledge statement, `hRel` and `hLk` given what the openings and `M` check** (D63 lane L21,
findings L21-1 … L21-3). As `block_knowledge`, for ANY block shape, with `hOpen` covering everything the openings and
`M` check (`OpenTrue`: L16's covered `acc.fs` only, not the hosts' `Γ` functionals in `acc.hostFs`, nor `H`'s sum
claim), `hRel`'s event requiring `OpenTrue`, and `hLk`'s also the true claimed sums and the slot relations. -/
theorem block_knowledge_mt [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn)) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (εopen εrel εlk : ℝ≥0∞)
    (hOpen : prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ εopen)
    (hRel : prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) ≤ εrel)
    (hLk : prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ∧ ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams) ≤ εlk) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εopen + ((((q + blockLen P.draws P.geom.slots hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig) + εrel + εlk := by
  have hsc := block_terminal_knowledge U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval dmax hdp
    hgeom hgt q A hA
  refine le_trans (MeasureTheory.measure_mono ?_)
    ((MeasureTheory.measure_union_le _ _).trans (add_le_add
      ((MeasureTheory.measure_union_le _ _).trans (add_le_add
        ((MeasureTheory.measure_union_le _ _).trans (add_le_add hOpen hsc)) hRel)) hLk))
  intro G hG
  rw [Set.mem_ofPred_eq] at hG
  obtain ⟨bga, rs, acc, hacc, hns⟩ := hG
  by_cases ho : OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
  · by_cases hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U
        = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k))
    · by_cases hrel : ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      · by_cases hlk : ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams
        · exact absurd (ZK60.Layout.blockSat_of_slots Pb Lay B _ fams hF hW h24 hrel hlk) hns
        · exact Or.inr ⟨bga, rs, acc, hacc, ho, hcl, hrel, hlk⟩
      · exact Or.inl (Or.inr ⟨bga, rs, acc, hacc, ho, hcl, hrel⟩)
    · push Not at hcl
      obtain ⟨k, r, hr, hne⟩ := hcl
      exact Or.inl (Or.inl (Or.inr ⟨bga, rs, acc, hacc, ho.1, ho.mfs, k, r, hr, hdeg _ _ _ _, hne⟩))
  · exact Or.inl (Or.inl (Or.inl ⟨bga, rs, acc, hacc, ho⟩))

end Block

/-! ## `hRel` from define schedules -/

section Rel

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A schedule of define claims**: the slots `ks`, their start claims `Gd`, their polynomials `Φ` of the draws and
their individual degrees `dg`. -/
structure DefSched (K : Type) (L : ℕ) (P : BlockParams) where
  ks : List ℕ
  Gd : Cuts3 L → RootsO → ℕ → Hist → Prop
  Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K
  dg : ℕ → ℕ

/-- **`hRel` from define schedules** (D63 lane L21). For ANY block shape and ANY event `Ev` (e.g. `block_knowledge_mt`'s
`hRel` event) whose every outcome is a win against one of `nd` define schedules (`hcover`: the instance's algebra), the
probability of `Ev` is at most `nd` times `block_defines_fs_knowledge`'s bound. -/
theorem rel_of_defines [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L
      ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (nd : ℕ) (D : ℕ → DefSched K L P) (dmax : ℕ)
    (hks : ∀ i, i < nd → ∀ k ∈ (D i).ks, k < P.geom.slots.length)
    (hdg : ∀ i, i < nd → ∀ k ∈ (D i).ks, (D i).dg k ≤ dmax)
    (hdeg : ∀ i, i < nd → ∀ k ∈ (D i).ks, ∀ cu rt h, IndDegLE ((D i).dg k) ((D i).Φ cu rt k h))
    (hΦ : ∀ i, i < nd → ∀ cu rt k h, k ∈ (D i).ks → (∀ x, (D i).Φ cu rt k h x = 0) → (D i).Gd cu rt k h)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (Ev : (QB L → Dig) → Prop)
    (hcover : ∀ G, Ev G → ∃ i, i < nd ∧ DefWin U key domain P hdrLen (D i).ks (D i).Gd (D i).Φ
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G)) :
    prH Ev ≤ (nd : ℝ≥0∞) * ((((q + defLen P hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + defLen P hdrLen + 1) Dig + collBound (q + defLen P hdrLen + 1 + 1) Dig) := by
  have hu := run_blocks_union nd (fun i G => DefWin U key domain P hdrLen (D i).ks (D i).Gd (D i).Φ
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G))
    (fun _ => (((q + defLen P hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + defLen P hdrLen + 1) Dig + collBound (q + defLen P hdrLen + 1 + 1) Dig)
    (fun i hi => block_defines_fs_knowledge U hU hK2 key domain hs hL hL64 hL81 P hdrLen (D i).ks (hks i hi)
      (D i).Gd (D i).Φ (D i).dg dmax (hdg i hi) (hdeg i hi) (hΦ i hi) hgeom hgt q A hA)
  simp only [Finset.sum_const, Finset.card_range, nsmul_eq_mul] at hu
  refine le_trans (MeasureTheory.measure_mono ?_) hu
  intro G hG
  exact hcover G hG

end Rel

/-! ## The numbers against the approved target -/

section Numbers

/-- **A schedule's bound** with `T = q + ℓ + 1` and escape count `e`, over `|K| = p²`. -/
noncomputable def schedBound (p q ℓ e : ℕ) : ℝ≥0∞ :=
  (((q + ℓ + 1) * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
    + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig

theorem bias_frac (p : ℕ) : (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
    = (((2 ^ 128 + p) * (2 ^ 128 + p) : ℕ) : ℝ≥0∞) / ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
  have hN0 : ((2 ^ 128 : ℕ) : ℝ≥0∞) ≠ 0 := by exact_mod_cast (by positivity : (2 ^ 128 : ℕ) ≠ 0)
  have hone : (1 : ℝ≥0∞) + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)
      = ((2 ^ 128 + p : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [Nat.cast_add, ENNReal.add_div, ENNReal.div_self hN0 (ENNReal.natCast_ne_top _)]
  rw [hone, sq, natFrac_mul _ _ _ _ (by positivity)]

/-- The collision term against a fraction of `q + 1`: for `t ≤ c·(q + 1)` and `q < 2^100`, `collBound t ≤ (q + 1)/2^b`
when `c²·2^(100 + b) ≤ 2^256`. -/
theorem coll_le_frac (q t c b : ℕ) (hq : q < 2 ^ 100) (ht : t ≤ c * (q + 1)) (hc : c * c * 2 ^ (100 + b) ≤ 2 ^ 256) :
    collBound t Dig ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ b : ℕ) : ℝ≥0∞) := by
  unfold collBound
  have hcard : (Fintype.card Dig : ℝ≥0∞) = ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
  rw [hcard]
  refine natFrac_le (by positivity) (by positivity) ?_
  have hq1 : q + 1 ≤ 2 ^ 100 := hq
  calc t * (t - 1) / 2 * 2 ^ b ≤ t * t * 2 ^ b := by
        gcongr
        exact (Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _))
    _ ≤ (c * (q + 1)) * (c * (q + 1)) * 2 ^ b := by gcongr
    _ = (q + 1) * ((q + 1) * (c * c * 2 ^ b)) := by ring
    _ ≤ (q + 1) * (2 ^ 100 * (c * c * 2 ^ b)) := by gcongr
    _ = (q + 1) * (c * c * 2 ^ (100 + b)) := by rw [pow_add]; ring
    _ ≤ (q + 1) * 2 ^ 256 := Nat.mul_le_mul_left _ hc
    _ = (q + 1) * (2 ^ 128 * 2 ^ 128) := by norm_num

/-- **One define schedule against half the target** (escape counts `≤ 80`, a run of at most `2^20` items, `q < 2^100`):
at most `(q + 1)/2^101`. The first term is at most `6(q + 1)/2^104`, each collision term at most `(q + 1)/2^104`. -/
theorem sched_le_101 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q ℓ e : ℕ) (hℓ : ℓ ≤ 2 ^ 20)
    (he : e ≤ 80) (hq : q < 2 ^ 100) :
    schedBound p q ℓ e ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 101 : ℕ) : ℝ≥0∞) := by
  have hp0 : p ≠ 0 := by
    intro h
    rw [h] at hp2
    norm_num at hp2
  unfold schedBound
  have hT : q + ℓ + 1 ≤ (2 ^ 20 + 1) * (q + 1) := by omega
  have h1 : (((q + ℓ + 1) * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ ((6 * (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) := by
    rw [bias_frac, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
    refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
    calc (q + ℓ + 1) * e * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 104
        ≤ ((2 ^ 20 + 1) * (q + 1)) * 80 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 104 := by gcongr
      _ = (q + 1) * ((2 ^ 20 + 1) * 80 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 104) := by ring
      _ ≤ (q + 1) * (6 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128))) := Nat.mul_le_mul_left _ (by norm_num)
      _ ≤ (q + 1) * (6 * (p ^ 2 * (2 ^ 128 * 2 ^ 128))) := by gcongr
      _ = 6 * (q + 1) * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by ring
  have hc1 := coll_le_frac q (q + ℓ + 1) (2 ^ 20 + 2) 104 hq (by omega) (by norm_num)
  have hc2 := coll_le_frac q (q + ℓ + 1 + 1) (2 ^ 20 + 2) 104 hq (by omega) (by norm_num)
  calc _ ≤ ((6 * (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) + ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞)
        + ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) := add_le_add (add_le_add h1 hc1) hc2
    _ = ((6 * (q + 1) + (q + 1) + (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) := by
        rw [ENNReal.div_add_div_same, ENNReal.div_add_div_same]
        simp only [Nat.cast_add]
    _ ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 101 : ℕ) : ℝ≥0∞) :=
        natFrac_le (by positivity) (by positivity) (le_of_eq (by ring))

/-- **Two define schedules meet the approved target for EVERY `q`** (W16R2's: the hosts with the standalone
zero-checks, and the private slots), with escape counts `≤ 80` and at most `2^20` items, under L8's count. -/
theorem rel_two_le_target (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q ℓ e : ℕ) (hℓ : ℓ ≤ 2 ^ 20)
    (he : e ≤ 80) (hq : q < 2 ^ 100) :
    ((2 : ℕ) : ℝ≥0∞) * schedBound p q ℓ e ≤ εsTarget q := by
  rw [show ((2 : ℕ) : ℝ≥0∞) = 1 + 1 by norm_num, add_mul, one_mul]
  calc schedBound p q ℓ e + schedBound p q ℓ e
      ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 101 : ℕ) : ℝ≥0∞) + ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 101 : ℕ) : ℝ≥0∞) :=
        add_le_add (sched_le_101 p hp1 hp2 q ℓ e hℓ he hq) (sched_le_101 p hp1 hp2 q ℓ e hℓ he hq)
    _ = ((q + 1 + (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 101 : ℕ) : ℝ≥0∞) := by
        rw [ENNReal.div_add_div_same]
        simp only [Nat.cast_add]
    _ ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 100 : ℕ) : ℝ≥0∞) :=
        natFrac_le (by positivity) (by positivity) (le_of_eq (by ring))
    _ = εsTarget q := (εsTarget_eq q).symm

/-- **LogUp's bound at the 8B T128 W16R2 parameters against the target** (`N + 2M ≤ 35,153,256`: `N_lk = 34,897,920`
lookups, `T_d = 127,668` distinct table tuples, `Kind8B`): at most `εsTarget q` whenever the verifier's chain is at most
`6(q + 1)` items (`ℓ = hdrLen + 10`) and `q < 2^100`. The first term is at most `15(q + 1)/2^104`. -/
theorem lk_le_target (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q ℓ e : ℕ) (hℓ : ℓ ≤ 6 * (q + 1))
    (he : e ≤ 35153256) (hq : q < 2 ^ 100) :
    schedBound p q ℓ e ≤ εsTarget q := by
  have hp0 : p ≠ 0 := by
    intro h
    rw [h] at hp2
    norm_num at hp2
  unfold schedBound
  have hT : q + ℓ + 1 ≤ 7 * (q + 1) := by omega
  have h1 : (((q + ℓ + 1) * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ ((30 * (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 105 : ℕ) : ℝ≥0∞) := by
    rw [bias_frac, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
    refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
    calc (q + ℓ + 1) * e * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 105
        ≤ (7 * (q + 1)) * 35153256 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 105 := by gcongr
      _ = (q + 1) * (7 * 35153256 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 105) := by ring
      _ ≤ (q + 1) * (30 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128))) := Nat.mul_le_mul_left _ (by norm_num)
      _ ≤ (q + 1) * (30 * (p ^ 2 * (2 ^ 128 * 2 ^ 128))) := by gcongr
      _ = 30 * (q + 1) * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by ring
  have hc1 := coll_le_frac q (q + ℓ + 1) 8 105 hq (by omega) (by norm_num)
  have hc2 := coll_le_frac q (q + ℓ + 1 + 1) 8 105 hq (by omega) (by norm_num)
  calc _ ≤ ((30 * (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 105 : ℕ) : ℝ≥0∞) + ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 105 : ℕ) : ℝ≥0∞)
        + ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 105 : ℕ) : ℝ≥0∞) := add_le_add (add_le_add h1 hc1) hc2
    _ = ((30 * (q + 1) + (q + 1) + (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 105 : ℕ) : ℝ≥0∞) := by
        rw [ENNReal.div_add_div_same, ENNReal.div_add_div_same]
        simp only [Nat.cast_add]
    _ ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 100 : ℕ) : ℝ≥0∞) :=
        natFrac_le (by positivity) (by positivity) (le_of_eq (by ring))
    _ = εsTarget q := (εsTarget_eq q).symm

/-- `defOff` as a function of the draws and the slot list. -/
def defOffW (draws : ℕ → ℕ) (slots : List (ℕ × ℕ × ℕ)) : ℕ → ℕ → ℕ
  | _, 0 => 0
  | j, m + 1 => draws j + 4 + 2 * ((slots.getD j (0, 0, 0)).1 + (slots.getD j (0, 0, 0)).2.1)
      + defOffW draws slots (j + 1) m

theorem defOff_eq (P : BlockParams) : ∀ j m, defOff P j m = defOffW P.draws P.geom.slots j m
  | _, 0 => rfl
  | j, m + 1 => by
    rw [defOff, defOffW, defOff_eq P (j + 1) m]
    rfl

/-- **At the W16R2 rung** (L9's schedule): the verifier's operations up to the end of the slot loop number
`hdrLen + 1045`. -/
theorem rung_defLen (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (h : ℕ) : defLen P h = h + 1045 := by
  have e : defOffW W16R2.rungDraws W16R2.rungSlots 0 W16R2.rungSlots.length = 1035 := by decide
  rw [defLen, defOff_eq, hdr, hsl, e]

end Numbers

/-! ## `hRel` at the approved target -/

section Target

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **`hRel` at the approved target, for EVERY `q`** (D63 lane L21): for any block shape whose operations up to the end of
the slot loop number at most `2^20` (`defLen`; at the rung `hdrLen + 1045`, so any header of `≤ 2^19` operations) and
any event covered by TWO define schedules with escape counts `≤ 80` (W16R2's hosts with the standalone zero-checks, and
its private slots), the event's probability is at most `εsTarget q = q·2^-100 + 2^-100`. -/
theorem rel_of_defines_target [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L
      ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (hlen : defLen P hdrLen ≤ 2 ^ 20) (D : ℕ → DefSched K L P)
    (dmax : ℕ) (hdm : dmax ≤ 80)
    (hks : ∀ i, i < 2 → ∀ k ∈ (D i).ks, k < P.geom.slots.length)
    (hdg : ∀ i, i < 2 → ∀ k ∈ (D i).ks, (D i).dg k ≤ dmax)
    (hdeg : ∀ i, i < 2 → ∀ k ∈ (D i).ks, ∀ cu rt h, IndDegLE ((D i).dg k) ((D i).Φ cu rt k h))
    (hΦ : ∀ i, i < 2 → ∀ cu rt k h, k ∈ (D i).ks → (∀ x, (D i).Φ cu rt k h x = 0) → (D i).Gd cu rt k h)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (Ev : (QB L → Dig) → Prop)
    (hcover : ∀ G, Ev G → ∃ i, i < 2 ∧ DefWin U key domain P hdrLen (D i).ks (D i).Gd (D i).Φ
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G)) :
    prH Ev ≤ εsTarget q := by
  by_cases hq : q < 2 ^ 100
  · have h := rel_of_defines U hU hK2 key domain hs hL hL64 hL81 P hdrLen hgeom hgt 2 D dmax hks hdg hdeg hΦ q A hA Ev
      hcover
    have hF : Fintype.card K = gP ^ 2 :=
      card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
    refine h.trans ?_
    rw [hF]
    exact rel_two_le_target gP (by norm_num [gP]) (by norm_num [gP]) q (defLen P hdrLen) dmax hlen hdm hq
  · exact (prH_le_one Ev).trans (one_le_εsTarget (by omega))

/-- **`hLk` against the approved target** (D63 lane L21): at the 8B T128 LogUp figures (`N + 2M ≤ 35,153,256`), the
slots accept while LogUp's conclusion fails on the extracted planes with probability at most `εhelp + εsTarget q`,
whenever the verifier's chain up to the `H` root, `hdrLen + 10` items, is at most `6(q + 1)` (finding L21-5). -/
theorem lk_of_logup_target [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (Bad : Cuts3 L → RootsO → Prop) (Hx : Cuts3 L → RootsO → Helpers ι π κ K)
    (hlook : ∀ cu rt, Bad cu rt → ∃ l, ∀ j, T j ≠ Alk cu.1 l)
    (q : ℕ) (hq : q < 2 ^ 100) (hhd : hdrLen + 10 ≤ 6 * (q + 1)) (A : OC (QB L) Dig (List Op × Core))
    (hA : A.Bounded q) (εhelp : ℝ≥0∞)
    (hHelp : prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
          (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          (Hx (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) ≤ εhelp) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Bad (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) ≤ εhelp + εsTarget q := by
  have h := lk_of_logup U hU hK2 key domain hs hL hL64 hL81 P hdrLen Alk T mlk hN Bad Hx hlook q A hA εhelp hHelp
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  refine h.trans (add_le_add le_rfl ?_)
  rw [hF]
  exact lk_le_target gP (by norm_num [gP]) (by norm_num [gP]) q (hdrLen + 10) _ hhd he hq

end Target

end ZK60.Exec.Block
