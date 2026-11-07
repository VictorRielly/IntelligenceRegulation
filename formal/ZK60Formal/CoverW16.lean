/-
D63 lane L23 (2026-11-07), part 1: **the covers `hcoverR`, `hcoverH` and the split `hsplit` of
`block_knowledge_target_mt`, from per-outcome facts** (generic in the block shape).

`block_knowledge_target_mt` (L21, `RelW16Pos.lean`) asks the instance for three covers of events by wins against define
schedules or LogUp. This file reduces each to facts about ONE accepting outcome, in the order the slots' algebra
supplies them:

* `AccT`: the outcomes `hRel` and `hLk` speak of (the block verifier accepts, `OpenTrue` of the extracted data, every
  claimed sum is its slot polynomial's cube sum);
* `first_fail`, **`cover_layers`**: `n` layered define schedules cover a failing goal at one outcome, given that each
  layer's polynomials vanish at the drawn challenges once the earlier layers' start claims hold (`hv`: layer 0, the hosts
  and standalone zero-checks, from the unmasked claimed sums; layer 1, the private slots' hosted differences at their
  own claim points, checked by their hosts; later layers, claim-point coordinates drawn by ANOTHER slot, finding L23-2),
  and that all start claims give the goal (`hgd`): the first failing layer wins;
* **`hcoverR_layers`**: `hcoverR` (for `n` schedules) from those facts with the goal `W16Rels`;
* **`hcoverH_layers`**, `EvHlpOf`: the helpers' event (accepting outcomes whose helpers' start claims `HGd` fail) and
  its cover, with the goal `HGd`;
* **`hsplit_two`**: `hsplit` from the lookup-list bridge (`hbr`: a failing `W16Lookups` gives an extracted tuple outside
  the table) and the helpers' start claims giving LogUp's `HelperRel` at the transcript's `β`, `γ`, `α` (`hhr`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RelW16Pos

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Cover

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The accepting outcomes `hRel` and `hLk` speak of**: the block verifier accepts, the openings' and `M`'s checks
are true of the extracted data (`OpenTrue`), and every claimed sum is its slot polynomial's cube sum. -/
def AccT (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) :
    Prop :=
  BlockAcc key domain P hdrLen G (A.run G) bga rs acc
    ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
    ∧ ∀ k r, rs[k]? = some r → r.claimed.toK U
        = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k))

/-- A schedule's polynomials vanish at the drawn challenges of an outcome. -/
def SchedVan (U : K) (P : BlockParams) (D : DefSched K L P) (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) : Prop :=
  ∀ k ∈ D.ks, ∀ r, rs[k]? = some r →
    D.Φ cu rt k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0

/-- A schedule's start claims hold at an outcome. -/
def SchedGd {P : BlockParams} (D : DefSched K L P) (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) : Prop :=
  ∀ k ∈ D.ks, D.Gd cu rt k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))

/-- The first failing layer: either every layer below `m` holds, or some layer `i < m` fails while all below it hold. -/
theorem first_fail (Q : ℕ → Prop) : ∀ m, (∀ i, i < m → Q i) ∨ ∃ i, i < m ∧ (∀ j, j < i → Q j) ∧ ¬ Q i
  | 0 => Or.inl (fun i hi => absurd hi (Nat.not_lt_zero i))
  | m + 1 => by
    rcases first_fail Q m with h | ⟨i, hi, hb, hn⟩
    · by_cases hm : Q m
      · exact Or.inl (fun i hi => by
          by_cases him : i < m
          · exact h i him
          · have him' : i = m := by omega
            subst him'
            exact hm)
      · exact Or.inr ⟨m, Nat.lt_succ_self m, h, hm⟩
    · exact Or.inr ⟨i, Nat.lt_succ_of_lt hi, hb, hn⟩

/-- **Layered define schedules cover a failing goal at one accepting outcome.** If each schedule's polynomials vanish
at the drawn challenges once every earlier schedule's start claims hold (`hv`: layer 0, the hosts and standalone
zero-checks, from the unmasked claimed sums alone; layer 1, the private slots' own-point differences, checked by their
hosts; a later layer, a claim-point coordinate drawn by ANOTHER slot), and all start claims give the goal, then a
failing goal is a win against the first schedule whose start claims fail. -/
theorem cover_layers (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ) (n : ℕ)
    (D : ℕ → DefSched K L P) (cu : Cuts3 L) (rt : RootsO) (G : QB L → Dig) (out : List Op × Core)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) (Goal : Prop)
    (hacc : SlotsAcc key domain P hdrLen G out bga rs acc)
    (hv : ∀ i, i < n → (∀ j, j < i → SchedGd (D j) cu rt bga rs) → SchedVan U P (D i) cu rt bga rs)
    (hgd : (∀ i, i < n → SchedGd (D i) cu rt bga rs) → Goal) (hng : ¬ Goal) :
    ∃ i, i < n ∧ DefWin U key domain P hdrLen (D i).ks (D i).Gd (D i).Φ cu rt G out := by
  rcases first_fail (fun i => SchedGd (D i) cu rt bga rs) n with hall | ⟨i, hi, hb, hn⟩
  · exact absurd (hgd hall) hng
  · refine ⟨i, hi, bga, rs, acc, hacc, ?_, hv i hi hb⟩
    by_contra hno
    apply hn
    intro k hk
    by_contra hgk
    exact hno ⟨k, hk, hgk⟩

variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf]

/-- **`hcoverR` from per-outcome facts, for `n` layered schedules**: on every accepting outcome (`AccT`), each
schedule's polynomials vanish at the drawn challenges once the earlier schedules' start claims hold, and all start
claims give `W16Rels` of the extracted planes. -/
theorem hcoverR_layers (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (A : OC (QB L) Dig (List Op × Core)) (n : ℕ) (DR : ℕ → DefSched K L P)
    (hv : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc → ∀ i, i < n →
      (∀ j, j < i → SchedGd (DR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (DR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgd : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      (∀ i, i < n → SchedGd (DR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) :
    ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
      → ∃ i, i < n ∧ DefWin U key domain P hdrLen (DR i).ks (DR i).Gd (DR i).Φ
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G) := by
  intro G hG
  obtain ⟨bga, rs, acc, hacc, ho, hcl, hng⟩ := hG
  have hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc := ⟨hacc, ho, hcl⟩
  exact cover_layers U key domain P hdrLen n DR _ _ G (A.run G) bga rs acc _ hacc.1 (hv G bga rs acc hT)
    (hgd G bga rs acc hT) hng

/-- **The helpers' event**: an accepting outcome (`AccT`) whose helpers' start claims `HGd` (of the extracted data and
the transcript's `β`, `γ`, `α`) fail. -/
def EvHlpOf (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop) (G : QB L → Dig) : Prop :=
  ∃ bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc
    ∧ ¬ HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga

/-- **`hcoverH` for the helpers' event `EvHlpOf`, for `n` layered schedules**, from the same per-outcome facts with
the goal `HGd`. -/
theorem hcoverH_layers (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop) (n : ℕ)
    (DH : ℕ → DefSched K L P)
    (hv : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc → ∀ i, i < n →
      (∀ j, j < i → SchedGd (DH j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (DH i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgd : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      (∀ i, i < n → SchedGd (DH i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga) :
    ∀ G, EvHlpOf U key domain hs hL P hdrLen F csX msX A HGd G → ∃ i, i < n ∧ DefWin U key domain P hdrLen
      (DH i).ks (DH i).Gd (DH i).Φ (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G) := by
  intro G hG
  obtain ⟨bga, rs, acc, hT, hng⟩ := hG
  exact cover_layers U key domain P hdrLen n DH _ _ G (A.run G) bga rs acc _ hT.1.1 (hv G bga rs acc hT)
    (hgd G bga rs acc hT) hng

/-- **`block_knowledge_target_mt`'s `hsplit` from the lookup-list bridge.** If on every accepting outcome a failing
`W16Lookups` of the extracted planes gives an extracted tuple of the lookup list outside the table (`hbr`), and the
helpers' start claims give LogUp's `HelperRel` at the transcript's `β`, `γ`, `α` for some helpers (`hhr`), then every
outcome of `hLk`'s event is in the helpers' event or a win against LogUp. -/
theorem hsplit_two {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (U : K) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (A : OC (QB L) Dig (List Op × Core)) (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh) :
    ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ∧ ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams)
      → EvHlpOf U key domain hs hL P hdrLen F csX msX A HGd G
        ∨ LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G) := by
  intro G hG
  obtain ⟨bga, rs, acc, hacc, ho, hcl, -, hnl⟩ := hG
  have hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc := ⟨hacc, ho, hcl⟩
  by_cases hh : HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga
  · exact Or.inr ⟨bga, rs, acc, hacc.1, hbr G bga rs acc hT hnl, hhr G bga rs acc hT hh⟩
  · exact Or.inl ⟨bga, rs, acc, hT, hh⟩

omit [Field K] [Algebra GF K] in
/-- **The lookup-list bridge from a cover of the lookups** (item 4's shape): if the table enumeration's entries are
table tuples (`hT`), and an extracted lookup list all of whose tuples are table tuples gives the lookups' conclusion
(`hcov`: the per-domain reading of the code's lookup list, L11's `word16_of_lk` … backwards), then a failing conclusion
gives an extracted tuple outside the table: `hsplit_two`'s `hbr`. -/
theorem hbr_of_cover {ι π κ : Type} (InT : Tup K → Prop) (Alk : ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (hT : ∀ j, InT (T j)) (Lk : Prop) (hcov : (∀ l, InT (Alk l)) → Lk) (hn : ¬ Lk) : ∃ l, ∀ j, T j ≠ Alk l := by
  by_contra hno
  apply hn
  apply hcov
  intro l
  by_contra hl
  apply hno
  refine ⟨l, fun j hj => hl ?_⟩
  rw [← hj]
  exact hT j

end Cover

end ZK60.Exec.Block
