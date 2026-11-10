/-
D63 lane L41 (2026-11-10), part 3: **a host slot's polynomial on the cube, and a host's named identity from it**
(generic in the block shape).

* **`cubeSum_host`**: if a slot's polynomial is, at every point, the code's three host terms (`hostTerms`, L13) of a
  value list whose `τ`, `p₁`, `p₂` entries vanish off the zero extension and are `eq(τ, b)`, `eq(p_i, b)` at the
  cube point `b` with the zero extension, then its cube sum is `Σ_b hostPoly(τ, Z, ν, P, 1, h)(b)` with `Z` and the
  gated hosted terms read at the zero extension (L13's `hostTerms_hostPoly₂`);
* **`formAt_host_of`**: lane L36's named identity `FormAt` of a host from the slot's kind, its hosted slots' kinds and
  the identity `Φ(draws) = Σ Poly_k − Σ_h κ_h·Σ Poly_h` (L36's `formAt_host`, the kind taken per outcome);
* **`slotFns_of_accT`**, **`kind_of_accT`**: on an accepting outcome every verified slot's kind is "host" exactly when
  its definition hosts slots (`slotDefChecks`, through L28's `blockSlots_fns`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinCube
import ZK60Formal.BlockAlgShapes
import ZK60Formal.SlotW16Compose

set_option autoImplicit false

namespace ZK60.Exec.Block.Join

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Slot.Build (hostTerms gV)
open ZK60.Exec.Slot.Compose (hostTerms_hostPoly₂)
open ZK60.Circuit (gP GF)
open Finset

section Host

variable {K : Type} [Field K]

/-- **A host-shaped slot polynomial on the cube.** -/
theorem cubeSum_host (n e : ℕ) (vals : (Fin (n + e) → K) → List K) (tau p1 p2 : ℕ) (g1 g2 : Option ℕ)
    (nu : List K) (Z H1 H2 : List K → K) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = hostTerms (vals x) tau p1 p2 g1 g2 nu (Z (vals x)) (H1 (vals x)) (H2 (vals x)))
    (hoff : ∀ b y, y ≠ (fun _ => false) → (vals (bpt n e b y)).getD tau 0 = 0
      ∧ (vals (bpt n e b y)).getD p1 0 = 0 ∧ (vals (bpt n e b y)).getD p2 0 = 0)
    (τ : Fin n → K) (P : Fin 2 → Fin n → K)
    (hτ : ∀ b, (vals (cpt n e b)).getD tau 0 = eqPoly τ (fun i => bit (b i)))
    (hp1 : ∀ b, (vals (cpt n e b)).getD p1 0 = eqPoly (P 0) (fun i => bit (b i)))
    (hp2 : ∀ b, (vals (cpt n e b)).getD p2 0 = eqPoly (P 1) (fun i => bit (b i))) :
    cubeSum f = ∑ b, hostPoly τ (fun b => Z (vals (cpt n e b))) ![nu.getD 0 0, nu.getD 1 0] P (fun _ => 1)
      (fun i b => if i = 0 then gV (vals (cpt n e b)) g1 * H1 (vals (cpt n e b))
        else gV (vals (cpt n e b)) g2 * H2 (vals (cpt n e b))) b := by
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt n e b) = _
    rw [hf]
    exact hostTerms_hostPoly₂ _ tau p1 p2 g1 g2 nu _ _ _ τ P (fun b => Z (vals (cpt n e b))) _ b (hτ b) (hp1 b)
      (hp2 b) rfl (by simp) (by simp)
  · show f (bpt n e b y) = 0
    obtain ⟨h0, h1, h2⟩ := hoff b y hy
    rw [hf]
    unfold hostTerms
    rw [h0, h1, h2]
    ring

/-- `hostPoly` with pointwise equal batched relations and hosted terms. -/
theorem hostPoly_congr {n : ℕ} (τ : Fin n → K) (Z Z' : (Fin n → Bool) → K) (ν : Fin 2 → K) (p : Fin 2 → Fin n → K)
    (g : (Fin n → Bool) → K) (h h' : Fin 2 → (Fin n → Bool) → K) (b : Fin n → Bool) (hZ : Z b = Z' b)
    (hh : ∀ i, h i b = h' i b) : hostPoly τ Z ν p g h b = hostPoly τ Z' ν p g h' b := by
  unfold hostPoly
  rw [hZ]
  simp only [hh]

/-- `hostPoly` with pointwise equal arguments. -/
theorem hostPoly_ext {n : ℕ} (τ τ' : Fin n → K) (Z Z' : (Fin n → Bool) → K) (ν ν' : Fin 2 → K)
    (p p' : Fin 2 → Fin n → K) (g : (Fin n → Bool) → K) (h h' : Fin 2 → (Fin n → Bool) → K) (b : Fin n → Bool)
    (hτ : ∀ i, τ i = τ' i) (hZ : Z b = Z' b) (hν : ∀ i, ν i = ν' i) (hp : ∀ i j, p i j = p' i j)
    (hh : ∀ i, h i b = h' i b) : hostPoly τ Z ν p g h b = hostPoly τ' Z' ν' p' g h' b := by
  have e1 : τ = τ' := funext hτ
  have e2 : ν = ν' := funext hν
  have e3 : p = p' := funext fun i => funext (hp i)
  subst e1 e2 e3
  exact hostPoly_congr τ Z Z' ν p g h h' b hZ hh

end Host

/-! ## A host's named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ} {P : BlockParams} (U : K) (sh : AlgShape P)
  (dt : AlgData K L sh) [Fintype K] [DecidableEq K] (hcard : 78 < Fintype.card K)

/-- **A host's named identity from its kinds and its identity at each outcome's draws.** -/
theorem formAt_host_of (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (hk : k ∈ algHosts)
    (h : ∀ r df, rs[k]? = some r → P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df →
      P.kind k = SlotKind.host ∧ (∀ hk' ∈ df.hosted, P.kind hk'.1 ≠ SlotKind.host)
      ∧ (hostSp U sh dt hcard k hk cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))).Φ
          (fun i => (r.draws.getD i.val Fp2.zero).toK U)
        = spSum P Poly bga rs k - (df.hosted.map (fun hk' => hk'.2.toK U * spSum P Poly bga rs hk'.1)).sum) :
    FormAt U P Poly (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k := by
  intro r df hr hdf
  exact formAt_host U sh dt hcard Poly cu rt bga rs k hk (h r df hr hdf).1
    (fun r' df' hr' hdf' => ⟨(h r' df' hr' hdf').2.1, _, _, rfl, rfl, (h r' df' hr' hdf').2.2⟩) r df hr hdf

end Form

/-! ## The kinds on an accepting outcome -/

section Kinds

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Every verified slot of an accepting outcome passed `run_slot`'s checks** (L28's `blockSlots_fns`). -/
theorem slotFns_of_accT (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc) (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) :
    ∃ sp, SlotFns P k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (rs.take k) sp r acc := by
  obtain ⟨hacc, -, -⟩ := hT
  obtain ⟨-, -, -, -, t', hbs⟩ := hacc.1
  obtain ⟨hlen, hall⟩ := blockSlots_fns (liftH G) P (A.run G).2 _ bga rs acc t' hbs
  have hk : k < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨sp, hsp⟩ : ∃ sp, (A.run G).2.slots[k]? = some sp :=
    ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact hk)⟩
  exact ⟨sp, hall k sp r hsp hr⟩

/-- **On an accepting outcome a verified slot is a host exactly when its definition hosts slots.** -/
theorem kind_of_accT (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc) (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r)
    (df : SlotDef) (hdf : P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df) :
    (P.kind k = SlotKind.host ↔ df.hosted ≠ []) := by
  obtain ⟨sp, df', hdf', -, -, -, hkind, -, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen F csX msX A G bga rs acc
    hT k r hr
  rw [hdf] at hdf'
  cases hdf'
  exact hkind

end Kinds

end ZK60.Exec.Block.Join
