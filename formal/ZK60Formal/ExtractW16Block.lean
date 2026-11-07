/-
D63 lane L16 (2026-11-07), part 4: **one block's knowledge statement**, composed.

For ANY block verifier (`BlockParams`: any admissible W16R2 block shape, its plane list and range families included;
the rung is one instance) and any prover making `q` hash queries, this file bounds the probability that the block
verifier accepts while the planes EXTRACTED from the prover's log (cut at the first absorption of each of the core's
three roots, `cuts3`) do not satisfy CircuitBlock's `BlockSat` at the logical positions:

* `SlotsAcc`: `blockSlots` accepts a canonical core of the verifier's shape after a header (the decoder's guarantees);
* `blockSlots_fin_canon`: every slot's final value is canonical;
* `BlockWinT`, **`blockWinT_blockWin`**: the slots' win with the claims and `M` functionals TRUE of the extracted data
  (instead of the terminal premise) is L9's `BlockWin` (`blockSlots_terminal`);
* **`block_terminal_knowledge`**: so its probability is at most L9's bound for polynomials over the extracted tables
  (`block_sumchecks_fs_knowledge`); **`block_terminal_knowledge_shape`**: at most `2^-61` at any shape of degree `≤ 7`
  with `T = q + ℓ + 1 ≤ 2^64 + 2^20` (the W16R2 rung, Shieldstral and 8B blocks alike);
* **`block_knowledge`**: the block's knowledge statement. With three NAMED hypotheses of the shapes the other lanes
  prove or must prove:
  - `hOpen` (the openings' and `M`'s knowledge on the code's chain; this lane's `ExtractW16Open.lean` proves `M`'s
    rounds and the Merkle extraction failure, the regular opening's two rounds are L10's): the probability that the slots
    accept and some claim handed to `A`/`H`/an endpoint, or some `M` functional, is false of the extracted data is at most
    `εopen`;
  - `hRel` (L13's composed bound): the probability that the slots accept, every claimed sum is true of the slot
    polynomials over the extracted tables, and yet a slot relation fails on the extracted planes, is at most `εrel`;
  - `hLk` (LogUp's): the probability that the slots accept and LogUp's conclusion fails on the extracted planes is at
    most `εlk`,
  and `hdeg` (the slot polynomials have the shape's degrees, L13's builders), the probability that the slots accept
  while the extracted planes do not satisfy `BlockSat` is at most `εopen + εsc + εrel + εlk`, `εsc` L9's sumcheck bound
  (`2^-61` at the shapes above).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExtractW16Terminal
import ZK60Formal.LayoutW16
import ZK60Formal.BindingW16

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Acc

variable {L : ℕ}

/-- **The slots accept** a canonical core of the verifier's shape after a header of `hdrLen` operations (each hash
input within `L` bytes), with the slot loop's result `(bga, rs, acc)`. -/
def SlotsAcc (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ) (G : QB L → Dig)
    (out : List Op × Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) : Prop :=
  out.1.length = hdrLen ∧ (∀ op ∈ out.1, op.len ≤ L) ∧ CoreCanon out.2 ∧ CoreShape P.geom out.2
  ∧ ∃ t', blockSlots (liftH G) P out.2 (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) out.1) = .ok (bga, rs, acc, t')

/-- The prover's log cut at the first absorption of each of its core's three roots: what the extractor reads. -/
def cutsOf (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) {α : Type} (A : OC (QB L) Dig (α × Core)) (G : QB L → Dig) : Cuts3 L :=
  cuts3 (absOfC (chainEncB key domain hs L hL)) (A.runLog G).2 (rootsOf (A.run G).2)

end Acc

/-- Every slot's final value of an accepting slot loop on a canonical core is canonical. -/
theorem blockSlots_fin_canon (H : HIn → Dig) (P : BlockParams) (core : Core) (t : Tr) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) (acc : Acc) (t' : Tr) (hacc : blockSlots H P core t = .ok (bga, rs, acc, t'))
    (hcan : CoreCanon core) (hsh : CoreShape P.geom core)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2) : ∀ r ∈ rs, r.fin.Canon := by
  have hslen : core.slots.length = P.geom.slots.length := by
    rw [hsh.1]
  rw [blockSlots_eq] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨-, hres⟩ := hacc
    subst hres
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]; exact hgeom i (by omega)
    obtain ⟨rs', hrs', hlen, hall⟩ := slotsLoop_ok H P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    intro r hr
    obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hr
    have hil : i < core.slots.length := by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hi).1
    obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q := ⟨_, List.getElem?_eq_getElem hil⟩
    obtain ⟨-, -, ⟨df, -, hcl⟩, hsv⟩ := hall i q r hq hi
    have hcc : r.claimed.Canon := hostedSum_canon _ q.scalar _ _ (hcan.1 q (List.mem_of_getElem? hq)).1 hcl
    exact scVerify_fin_canon H r.claimed hcc _ _ (hd1 i hil) _ _ _ _ hsv
  · cases hacc

section Compose

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The slots' win with the openings' and `M`'s claims TRUE of some data** (`cs`, `ms`): the slots accept, every
claim handed on and every `M` functional is true of the data, and some slot's claimed sum is false of its polynomial
`f k` of individual degree `≤ d`. -/
def BlockWinT (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (cs : Cm → ZClaim → K)
    (ms : List (ℕ × List Fp2) → K) (G : QB L → Dig) (out : List Op × Core) : Prop :=
  ∃ bga rs acc, SlotsAcc key domain P hdrLen G out bga rs acc ∧ ClaimsTrue U cs acc.claims ∧ MTrue U ms acc.fs
    ∧ ∃ k r, rs[k]? = some r ∧ IndDegLE (slotShape P k).2.2 (f k (seenOf bga rs k))
      ∧ r.claimed.toK U ≠ cubeSum (f k (seenOf bga rs k))

/-- **The claims' truth discharges the terminal premise** (L10-6 (b), (c)): `BlockWinT` is L9's `BlockWin`, for slot
polynomials that are the slots' over the data (`SlotEval`) and definitions whose polynomials return canonical
words. -/
theorem blockWinT_blockWin (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P : BlockParams) (hdrLen : ℕ) (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : SlotEval U P cs ms f) (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2)
    (G : QB L → Dig) (out : List Op × Core) (h : BlockWinT U key domain P hdrLen f cs ms G out) :
    BlockWin U key domain L P hdrLen f G out := by
  obtain ⟨bga, rs, acc, ⟨h1, h2, h3, h4, t', hacc⟩, hcl, hm, hfalse⟩ := h
  refine ⟨h1, h2, h3, h4, bga, rs, acc, t', hacc, ?_, hfalse⟩
  exact blockSlots_terminal U hU _ P _ _ bga rs acc t' hacc cs ms hcl hm hpolyC
    (blockSlots_fin_canon _ P _ _ bga rs acc t' hacc h3 h4 hgeom) f hEval

/-- **The block's slots, knowledge version with the claims' truth** (D63 lane L16). For slot polynomials, claim
semantics and `M` semantics that are ANY functions `F`, `csX`, `msX` of the prover's log cut at the roots' absorption
(the extracted tables) and of the roots, with `F` the slot polynomial over that data (`SlotEval`): the probability
that the slots accept, every claim handed on and every `M` functional is true of the extracted data, and yet some
slot's claimed sum is false, is at most L9's bound. -/
theorem block_terminal_knowledge [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt)) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWinT U key domain P hdrLen
        (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) G (A.run G))
      ≤ (((q + blockLen P.draws P.geom.slots hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (block_sumchecks_fs_knowledge U hU hK2 key domain hs hL hL64 hL81 P hdrLen F dmax hdp hgeom hgt q A hA)
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact blockWinT_blockWin U hU key domain P hdrLen _ _ _ hpolyC (hEval _ _) (fun k hk => (hgeom k hk).1) G (A.run G) hG

/-- **At the block's shape** (any shape of round degree `≤ 7` and `T = q + ℓ + 1 ≤ 2^64 + 2^20`): at most `2^-61`. -/
theorem block_terminal_knowledge_shape [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt)) (dmax : ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (hd7 : dmax ≤ 7) (hT : q + blockLen P.draws P.geom.slots hdrLen + 1 ≤ 2 ^ 64 + 2 ^ 20) :
    prH (fun G : QB L → Dig => BlockWinT U key domain P hdrLen
        (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (block_sumchecks_fs_knowledge_shape U hU hK2 key domain hs hL hL64 hL81 P hdrLen F dmax hgeom hgt q A hA hd7 hT)
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact blockWinT_blockWin U hU key domain P hdrLen _ _ _ hpolyC (hEval _ _) (fun k hk => (hgeom k hk).1) G (A.run G) hG

end Compose

/-! ## The slots' part against the approved target -/

/-- **The slots' bound is below the approved target `εsTarget q = q·2^-100 + 2^-100`** for every `q < 2^100`, at round
degree `≤ 7` and a run of at most `2^20` items (stated for a variable `p` within `2^32` below `2^64`, L7-4): the first
term is at most `(q + 1)·2^-101`, each collision term at most `(q + 1)·2^-102`. -/
theorem slots_bound_le_target (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q ℓ d : ℕ) (hℓ : ℓ ≤ 2 ^ 20)
    (hd : d ≤ 7) (hq : q < 2 ^ 100) :
    (((q + ℓ + 1) * d : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig ≤ εsTarget q := by
  have hp0 : p ≠ 0 := by
    intro h
    rw [h] at hp2
    norm_num at hp2
  have hN0 : ((2 ^ 128 : ℕ) : ℝ≥0∞) ≠ 0 := by exact_mod_cast (by positivity : (2 ^ 128 : ℕ) ≠ 0)
  have hone : (1 : ℝ≥0∞) + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)
      = ((2 ^ 128 + p : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [Nat.cast_add, ENNReal.add_div, ENNReal.div_self hN0 (ENNReal.natCast_ne_top _)]
  have hsq : (((2 ^ 128 + p : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      = (((2 ^ 128 + p) * (2 ^ 128 + p) : ℕ) : ℝ≥0∞) / ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [sq, natFrac_mul _ _ _ _ (by positivity)]
  have hcard : (Fintype.card Dig : ℝ≥0∞) = ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
  have hT : q + ℓ + 1 ≤ 2 ^ 21 * (q + 1) := by omega
  have h1 : (((q + ℓ + 1) * d : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ ((2 * (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 102 : ℕ) : ℝ≥0∞) := by
    rw [hone, hsq, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
    refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
    calc (q + ℓ + 1) * d * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 102
        ≤ (2 ^ 21 * (q + 1)) * 7 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 102 := by gcongr
      _ = (q + 1) * (2 ^ 21 * 7 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 102) := by ring
      _ ≤ (q + 1) * (2 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128))) := Nat.mul_le_mul_left _ (by norm_num)
      _ ≤ (q + 1) * (2 * (p ^ 2 * (2 ^ 128 * 2 ^ 128))) := by gcongr
      _ = 2 * (q + 1) * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by ring
  have hcoll : ∀ t : ℕ, t ≤ 2 ^ 22 * (q + 1) →
      collBound t Dig ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 102 : ℕ) : ℝ≥0∞) := by
    intro t ht
    unfold collBound
    rw [hcard]
    refine natFrac_le (by positivity) (by positivity) ?_
    have hq1 : q + 1 ≤ 2 ^ 100 := hq
    calc t * (t - 1) / 2 * 2 ^ 102 ≤ t * t * 2 ^ 102 := by
          gcongr
          exact (Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _))
      _ ≤ (2 ^ 22 * (q + 1)) * (2 ^ 22 * (q + 1)) * 2 ^ 102 := by gcongr
      _ = (q + 1) * ((q + 1) * 2 ^ 146) := by ring
      _ ≤ (q + 1) * (2 ^ 100 * 2 ^ 146) := by gcongr
      _ = (q + 1) * 2 ^ 246 := by ring
      _ ≤ (q + 1) * 2 ^ 256 := Nat.mul_le_mul_left _ (by norm_num)
      _ = (q + 1) * (2 ^ 128 * 2 ^ 128) := by ring
  calc _ ≤ ((2 * (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 102 : ℕ) : ℝ≥0∞) + ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 102 : ℕ) : ℝ≥0∞)
        + ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 102 : ℕ) : ℝ≥0∞) :=
        add_le_add (add_le_add h1 (hcoll _ (by omega))) (hcoll _ (by omega))
    _ = ((2 * (q + 1) + (q + 1) + (q + 1) : ℕ) : ℝ≥0∞) / ((2 ^ 102 : ℕ) : ℝ≥0∞) := by
        rw [ENNReal.div_add_div_same, ENNReal.div_add_div_same]
        simp only [Nat.cast_add]
    _ ≤ ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 100 : ℕ) : ℝ≥0∞) :=
        natFrac_le (by positivity) (by positivity) (le_of_eq (by ring))
    _ = εsTarget q := (εsTarget_eq q).symm

/-- **The W16R2 rung block's slots, knowledge version, at the approved target, for EVERY `q`** (D63 lane L16): with
the claims and `M` functionals true of the extracted data, a false claimed sum in any of the 23 slots of polynomials
over the extracted tables passes with probability at most `εsTarget q = q·2^-100 + 2^-100` (a header of at most `2^19`
operations). -/
theorem rung_block_terminal_knowledge_target {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) {L : ℕ} (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (htm : P.geom.terms = W16R2.rungTerms) (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWinT U key domain P hdrLen
        (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) G (A.run G)) ≤ εsTarget q := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  have hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ 5
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L := by
    intro k hk
    rw [hsl] at hk
    have hk' : k < 23 := by simpa [W16R2.rungSlots] using hk
    obtain ⟨h1, h2, h3, h4⟩ := W16R2.rung_slot_facts k hk'
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by
    rw [hsl, htm]
    rfl
  by_cases hq : q < 2 ^ 100
  · refine (block_terminal_knowledge U hU hK2 key domain hs hL hL64 (by omega) P hdrLen F csX msX hpolyC hEval 5
      (by norm_num [gP]) hgeom hgt q A hA).trans ?_
    rw [hF, hdr, hsl, W16R2.rung_len]
    exact slots_bound_le_target gP (by norm_num [gP]) (by norm_num [gP]) q (hdrLen + 1044) 5 (by omega) (by norm_num)
      hq
  · refine le_trans ?_ (one_le_εsTarget (by omega))
    calc _ ≤ (PMF.uniformOfFintype (QB L → Dig)).toOuterMeasure Set.univ :=
          MeasureTheory.measure_mono (Set.subset_univ _)
      _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff _ Set.univ).mpr (Set.subset_univ _)

/-! ## The block's knowledge statement -/

section Block

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One W16R2 block's knowledge statement** (D63 lane L16; L10-6 discharged up to the named hypotheses). For any
block verifier `P` (any admissible block shape), any prover making `q` hash queries, the extracted planes
`xtE (cuts) (roots)` (any function of the prover's log cut at the roots' first absorption and of the roots: the
layout's reading of the extracted committed tables), the extracted claim and `M` semantics `csX`, `msX` and the slot
polynomials `F` over them (`SlotEval`, degrees `hdeg`): the probability that the slots accept while the extracted
planes do NOT satisfy CircuitBlock's `BlockSat` at the logical positions is at most `εopen + εsc + εrel + εlk`, where
* `εsc` is L9's sumcheck bound for polynomials over the extracted tables (proved: `block_terminal_knowledge`),
* `εopen` bounds the openings' and `M`'s knowledge failures (`hOpen`),
* `εrel` bounds L13's slot relations given true claimed sums (`hRel`),
* `εlk` bounds LogUp's conclusion (`hLk`). -/
theorem block_knowledge [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
      ∧ ¬ (ClaimsTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.claims
        ∧ MTrue U (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.fs)) ≤ εopen)
    (hRel : prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) ≤ εrel)
    (hLk : prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
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
  by_cases ho : ClaimsTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.claims
      ∧ MTrue U (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.fs
  · by_cases hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U
        = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k))
    · by_cases hrel : ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      · by_cases hlk : ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams
        · exact absurd (ZK60.Layout.blockSat_of_slots Pb Lay B _ fams hF hW h24 hrel hlk) hns
        · exact Or.inr ⟨bga, rs, acc, hacc, hlk⟩
      · exact Or.inl (Or.inr ⟨bga, rs, acc, hacc, hcl, hrel⟩)
    · push Not at hcl
      obtain ⟨k, r, hr, hne⟩ := hcl
      exact Or.inl (Or.inl (Or.inr ⟨bga, rs, acc, hacc, ho.1, ho.2, k, r, hr, hdeg _ _ _ _, hne⟩))
  · exact Or.inl (Or.inl (Or.inl ⟨bga, rs, acc, hacc, ho⟩))

end Block

/-! ## Several blocks, each with its own shape -/

/-- **A run's blocks, each with its own shape and its own bound** (the union over the blocks; A25: at W16R2 a real
model's blocks carry different plane lists and range families, so each block `i` has its own `BlockParams` and its own
knowledge event `Ev i`, e.g. `block_knowledge` at block `i`'s shape): the probability that SOME block's extracted
planes fail is at most the sum of the blocks' bounds. The sharper count (one schedule over the run's chain or the D55
tree) is left (§5 of the lane doc). -/
theorem run_blocks_union {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] (nb : ℕ) (Ev : ℕ → (Q → D) → Prop)
    (ε : ℕ → ℝ≥0∞) (h : ∀ i, i < nb → prH (Ev i) ≤ ε i) :
    prH (fun H => ∃ i, i < nb ∧ Ev i H) ≤ ∑ i ∈ Finset.range nb, ε i := by
  induction nb with
  | zero =>
    have he : {H : Q → D | ∃ i, i < 0 ∧ Ev i H} = ∅ :=
      Set.eq_empty_iff_forall_notMem.mpr (fun H hH => by
        obtain ⟨i, hi, -⟩ := hH
        exact absurd hi (Nat.not_lt_zero _))
    show (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | ∃ i, i < 0 ∧ Ev i H} ≤ _
    rw [he, MeasureTheory.measure_empty]
    exact zero_le
  | succ n ih =>
    rw [Finset.sum_range_succ]
    refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans
      (add_le_add (ih (fun i hi => h i (by omega))) (h n (by omega))))
    intro H hH
    obtain ⟨i, hi, hE⟩ := hH
    by_cases hin : i < n
    · exact Or.inl ⟨i, hin, hE⟩
    · have hin' : i = n := by omega
      subst hin'
      exact Or.inr hE

end ZK60.Exec.Block
