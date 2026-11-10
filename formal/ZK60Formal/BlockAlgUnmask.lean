/-
D63 lane L36 (2026-11-09), part 1: **the unmasking on an accepting outcome, in the form the block's final statements
use, and a schedule's vanishing from its slots' named identities** (generic in the block shape).

L31's final statements (`block_knowledge_final_*`) take the per-outcome fact `hvR` / `hvH`: on an accepting outcome
(`AccT`, with `F = Poly + c·mask`) each layer's certified polynomials vanish at the drawn challenges. For the layer of
the hosts and standalone zero-checks this file reduces it to ONE named fact per slot:

* `spSum`: a slot's unmasked cube sum `Σ_b Poly_k(b)` at an outcome;
* **`accT_unmask`**: on an accepting outcome, every verified slot has a definition, a standalone slot's unmasked sum
  is `0`, and a host's (whose hosted slots are not hosts) is `Σ_h κ_h·(slot h's unmasked sum)`. It is L23's
  `unmask_slots` with its premises discharged from `AccT`: `hcl` by L31's `claimed_unmasked`, `MTrue` by `OpenTrue`,
  the definition by `blockSlots_fns`;
* `FormAt`: **the named identity of slot `k`** (L23 §5 item 3): its certified polynomial at the drawn challenges IS
  the slot's unmasked residual, `Σ Poly_k` for a standalone slot and `Σ Poly_k − Σ_h κ_h·Σ Poly_h` for a host;
* **`schedVan_of_form`**: a define schedule whose slots meet `FormAt` vanishes at the drawn challenges of every
  accepting outcome (`SchedVan`): `hvR`'s layer `0` and `hvH`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstFinal

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)

section Unmask

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A slot's unmasked cube sum at an outcome**: `Σ_b Poly_k(b)`, with the trace's view of slot `k`. -/
def spSum (P : BlockParams)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) : K :=
  cubeSum (Poly k (seenOf bga rs k))

/-- **The unmasking on an accepting outcome** (L23's `unmask_slots` on `AccT`, with `F = Poly + c·mask` over mask
rows `R` that `M`'s semantics reads linearly). Every verified slot `k` has a definition `df`; if it is standalone its
unmasked sum is `0`; if it is a host whose hosted slots are not hosts, its unmasked sum is `Σ_h κ_h·Sp_h`. -/
theorem accT_unmask (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (R : Cuts3 L → RootsO → ℕ → ℕ → K) (Wd : ℕ)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hlin : ∀ cu rt, MLin U (msX cu rt) (R cu rt) Wd)
    (hN : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ Wd)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen (fun cu rt => maskedF U (R cu rt) P (Poly cu rt)) csX msX A G bga rs acc)
    (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) :
    ∃ df, P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df
      ∧ (P.kind k = SlotKind.standalone →
          spSum P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) bga rs k = 0)
      ∧ (P.kind k = SlotKind.host → (∀ hk ∈ df.hosted, P.kind hk.1 ≠ SlotKind.host) →
          spSum P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) bga rs k
            = (df.hosted.map (fun hk => hk.2.toK U
                * spSum P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) bga rs hk.1)).sum) := by
  obtain ⟨hacc, ho, hcl⟩ := hT
  obtain ⟨-, -, hcan, hsh, t', hbs⟩ := hacc.1
  obtain ⟨hlen, hall⟩ := blockSlots_fns (liftH G) P (A.run G).2 _ bga rs acc t' hbs
  have hk : k < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨sp, hsp⟩ : ∃ sp, (A.run G).2.slots[k]? = some sp :=
    ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact hk)⟩
  obtain ⟨df, hdf, -⟩ := hall k sp r hsp hr
  refine ⟨df, hdf, ?_⟩
  have hclS : ∀ j r', rs[j]? = some r' → r'.claimed.toK U
      = spSum P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) bga rs j
        + r'.c.toK U * mdot U (R (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) Wd (j, swk P j) := by
    intro j r' hr'
    have hj : j < P.geom.slots.length := by
      rw [← hsh.1, ← hlen]
      exact (List.getElem?_eq_some_iff.mp hr').1
    obtain ⟨h0, h64, hW⟩ := hN j hj
    exact claimed_unmasked U hU hbij _ Wd P _ bga rs j r' hr' h0 h64 hW (hcl j r' hr')
  exact unmask_slots U hU (liftH G) P (A.run G).2 _ bga rs acc t' hbs hcan _ _ Wd (hlin _ _) ho.2.1
    (fun j => spSum P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) bga rs j) hclS k r hr df hdf

/-- **The named identity of slot `k` at an outcome** (L23 §5 item 3, "the unmasked cube sum of each slot is its named
identity"): the polynomial `Φ` at the slot's drawn challenges is the slot's unmasked residual. A standalone slot's
residual is its unmasked sum; a host's is its unmasked sum minus its hosted slots' (none of them a host), each with
its coefficient. -/
def FormAt (U : K) (P : BlockParams)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) : Prop :=
  ∀ r df, rs[k]? = some r → P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df →
    (P.kind k = SlotKind.standalone
      ∧ Φ k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (fun i => (r.draws.getD i.val Fp2.zero).toK U)
        = spSum P Poly bga rs k)
    ∨ (P.kind k = SlotKind.host ∧ (∀ hk ∈ df.hosted, P.kind hk.1 ≠ SlotKind.host)
      ∧ Φ k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (fun i => (r.draws.getD i.val Fp2.zero).toK U)
        = spSum P Poly bga rs k - (df.hosted.map (fun hk => hk.2.toK U * spSum P Poly bga rs hk.1)).sum)

/-- **A schedule whose slots meet their named identities vanishes at the drawn challenges of an accepting outcome**
(`hvR`'s layer `0`, and `hvH`). -/
theorem schedVan_of_form (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (R : Cuts3 L → RootsO → ℕ → ℕ → K) (Wd : ℕ)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hlin : ∀ cu rt, MLin U (msX cu rt) (R cu rt) Wd)
    (hN : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ Wd)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen (fun cu rt => maskedF U (R cu rt) P (Poly cu rt)) csX msX A G bga rs acc)
    (D : DefSched K L P)
    (hform : ∀ k ∈ D.ks, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (D.Φ (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) bga rs k) :
    SchedVan U P D (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs := by
  intro k hk r hr
  obtain ⟨df, hdf, hst, hho⟩ := accT_unmask U hU hbij key domain hs hL P hdrLen R Wd Poly csX msX hlin hN A G bga rs
    acc hT k r hr
  rcases hform k hk r df hr hdf with ⟨hks, hΦ⟩ | ⟨hkh, hpriv, hΦ⟩
  · rw [hΦ]
    exact hst hks
  · rw [hΦ, hho hkh hpriv, sub_self]

end Unmask

end ZK60.Exec.Block
