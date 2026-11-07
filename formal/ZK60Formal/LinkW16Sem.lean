/-
D63 lane L22 (2026-11-07), part 6: **the claims' index map** (L20-3's `hsem`).

`block_open_knowledge` needs: on acceptance, the openings' and `M`'s good predicates on the extracted data make every
claim and every `M` functional TRUE of the extracted data (L21's `OpenTrue`: the claims, `H`'s LogUp sum claim, and
every functional `M` receives, `acc.fs ++ acc.hostFs`, findings L21-2, L21-3). This file gives the semantics and the map:

* `M`: `mRhOf` (the decoding of the extracted mask table, unique at `2·1024 + 1023 < 4096`), `msOfTab` (a functional's
  terms on the decoded mask polynomials: `M`'s claim semantics, a function of the extracted table alone), and
  **`mGood_mTrue`**: `MGood` of `mDataOf fs cols` makes EVERY functional of `fs` true (`fs = acc.fs ++ acc.hostFs`, so
  the hosts' functionals are covered, L21-2);
* the regular openings: `claimRw`, `claimCw` (a claim's row weights and column weights read in `K`, `claim_weights` /
  `zkey_weights`), `claimSem` (a claim's value on a message matrix: `Σ_i rw_i·⟨X_i, cw⟩`), `memsOf` (the members of
  `group_zclaims`' groups in the code's draw order, `zk_rhos`'), `oclOf` (the `OClaims` `opA`/`opB` state, indexed
  by draw position: `grp` the member's group, `cw` the group's column weights), the invariant `GInv` of
  `group_zclaims`, and **`groupsGood_claimSem`**: `GroupsGood` of `oclOf` makes EVERY claim of the list true of the
  decoded matrix (the list `H` opens is `acc.claims.h ++ [P.logupSumClaim]`, so `H`'s sum claim is covered, L21-3).

The endpoint claims (`acc.claims.inp`, `acc.claims.out`) are opened by the run, not the block (L16-5): they stay a
run-level premise of the block statement (`LinkW16Block.lean`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Mask

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Polynomial

/-! ## `M`'s semantics -/

section MSem

variable {K : Type} [Field K] [Fintype K] [Algebra GF K] (U : K)

omit [Fintype K] in
/-- **The decoding of an extracted mask table** (`2S + 2` base rows and `u`), when one exists. -/
noncomputable def mRhOf (S : ℕ) (cols : Fin (2 ^ 12) → List Fp) : Fin (2 * S + 2) → K[X] :=
  haveI := Classical.propDecidable (∃ Rh, MDec (mEtaE (K := K)) 1024 1023 (mDataOf U S 0 [] cols).Ub
    (mDataOf U S 0 [] cols).u Rh)
  if h : ∃ Rh, MDec (mEtaE (K := K)) 1024 1023 (mDataOf U S 0 [] cols).Ub (mDataOf U S 0 [] cols).u Rh then h.choose
  else 0

omit [Fintype K] in
/-- **`M`'s claim semantics**: a functional's terms, on the decoded mask polynomials of the extracted table. -/
noncomputable def msOfTab (S : ℕ) (cols : Fin (2 ^ 12) → List Fp) (ts : List (ℕ × List Fp2)) : K :=
  ∑ s : Fin S, ∑ j : Fin 512, fwt U ⟨ts, Fp2.zero⟩ s j
    * (mDecA (mDataOf U S 0 [] cols).La (mRhOf U S cols) s).eval (mPts (mOmega (K := K)) j)

/-- **`M`'s good case makes every functional it received true** (`hsem` for `M`): `MGood` of the data `M`'s
sub-protocol states (`mDataOf fs cols`) gives `msOfTab cols mf.terms = mf.value` for EVERY `mf ∈ fs`. -/
theorem mGood_mTrue (S : ℕ) (fs : List Block.MaskFunctional) (cols : Fin (2 ^ 12) → List Fp)
    (hg : MGood (mEtaE (K := K)) (mOmega (K := K)) 1 1024 1023 (mDataOf U S fs.length fs cols).wt
      (mDataOf U S fs.length fs cols).val (mDataOf U S fs.length fs cols).Ub (mDataOf U S fs.length fs cols).u
      (mDataOf U S fs.length fs cols).La (mDataOf U S fs.length fs cols).Lb) :
    ∀ mf ∈ fs, msOfTab U S cols mf.terms = mf.value.toK U := by
  obtain ⟨Rh, hdec, hval⟩ := mGood_val_eq_true (mEtaE (K := K)) (mOmega (K := K)) (mDataOf U S fs.length fs cols) hg
  have hex : ∃ Rh, MDec (mEtaE (K := K)) 1024 1023 (mDataOf U S 0 [] cols).Ub (mDataOf U S 0 [] cols).u Rh :=
    ⟨Rh, hdec⟩
  have hR : mRhOf U S cols = Rh := by
    unfold mRhOf
    rw [dite_eq_left hex]
    exact MDec.unique (by simp) hex.choose_spec hdec
  intro mf hmf
  obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hmf
  have hv := hval ⟨i, hi⟩
  have hgd : fs.getD i mf0 = fs[i] := getD_eq_get _ _ _ hi
  rw [show (mDataOf U S fs.length fs cols).val ⟨i, hi⟩ = (fs.getD i mf0).value.toK U from rfl, hgd] at hv
  rw [hv, msOfTab, hR]
  unfold mTrue
  refine Finset.sum_congr rfl (fun s _ => Finset.sum_congr rfl (fun j _ => ?_))
  show fwt U ⟨fs[i].terms, Fp2.zero⟩ s j * _ = fwt U (toMF (fs.getD i mf0)) s j * _
  rw [hgd]
  rfl

end MSem

/-! ## The regular openings' semantics and the index map -/

section OSem

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A claim's row weights in `K` (`claim_weights`' first part, over `rows` rows, `2^logCols` columns). -/
noncomputable def claimRw (rows logCols : ℕ) (z : Block.ZClaim) : Fin rows → K :=
  fun i => (((claimWeights (toZClaim z) rows logCols).1).getD i Fp2.zero).toK U

/-- A column-weight list in `K`, on the message coordinates `Fin (2^logCols + Q)` (the pads weigh `0`). -/
noncomputable def cwK (logCols Q : ℕ) (cw : List Fp2) : Fin (2 ^ logCols + Q) → K :=
  fun t => if (t : ℕ) < 2 ^ logCols then (cw.getD t Fp2.zero).toK U else 0

/-- A claim's column weights in `K` (`zkey_weights` of its key). -/
noncomputable def claimCw (rows logCols Q : ℕ) (z : Block.ZClaim) : Fin (2 ^ logCols + Q) → K :=
  cwK U logCols Q (zkeyWeights (claimWeights (toZClaim z) rows logCols).2 logCols)

/-- **A claim's value on a message matrix** `X`: `Σ_i rw_i·⟨X_i, cw⟩` (`SoundGroups.lean`'s `claimValue` of one
claim). -/
noncomputable def claimSem (rows logCols Q : ℕ) (X : Fin rows → Fin (2 ^ logCols + Q) → K) (z : Block.ZClaim) : K :=
  ∑ i, claimRw U rows logCols z i * ∑ t, X i t * claimCw U rows logCols Q z t

/-- The members of the groups, in the code's draw order (`zk_rhos`: group by group, member by member), with their
group's index. -/
def memsFrom : ℕ → List (List Fp2 × List (List Fp2 × Fp2)) → List (ℕ × (List Fp2 × Fp2))
  | _, [] => []
  | g, x :: xs => x.2.map (fun m => (g, m)) ++ memsFrom (g + 1) xs

def memsOf (gs : List (List Fp2 × List (List Fp2 × Fp2))) : List (ℕ × (List Fp2 × Fp2)) := memsFrom 0 gs

/-- **The `OClaims` the regular opening's sub-protocols state**, indexed by draw position `p` (`λ_p` is the `p`-th
batching challenge): `p`'s row weights, value, group, and the group's column weights. -/
noncomputable def oclOf (rows logCols Q nC : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) :
    OClaims (Fin nC) ℕ (Fin rows) (Fin (2 ^ logCols + Q)) K where
  rw p i := ((((memsOf gs).getD p (0, ([], Fp2.zero))).2.1).getD i Fp2.zero).toK U
  cw g := cwK U logCols Q ((gs.getD g ([], [])).1)
  grp p := ((memsOf gs).getD p (0, ([], Fp2.zero))).1
  val p := (((memsOf gs).getD p (0, ([], Fp2.zero))).2.2).toK U

/-- The invariant of `group_zclaims`' fold: one key per group, each group's column weights its key's, every claim
folded so far a member of the group of its key. -/
def GInv (rows logCols : ℕ) (done : List ZClaim) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))) : Prop :=
  st.1.length = st.2.length
    ∧ (∀ g, g < st.2.length → (st.2.getD g ([], [])).1 = zkeyWeights (st.1.getD g ⟨[], 0, 0⟩) logCols)
    ∧ ∀ c ∈ done, ∃ g, g < st.2.length ∧ st.1.getD g ⟨[], 0, 0⟩ = (claimWeights c rows logCols).2
      ∧ ((claimWeights c rows logCols).1, c.value) ∈ (st.2.getD g ([], [])).2

theorem keyIdx_spec {keys : List ZKey} {k : ZKey} {gi : ℕ} (h : keyIdx keys k = some gi) :
    gi < keys.length ∧ keys.getD gi ⟨[], 0, 0⟩ = k := by
  unfold keyIdx at h
  obtain ⟨hlt, hk, -⟩ := List.findIdx?_eq_some_iff_getElem.mp h
  refine ⟨hlt, ?_⟩
  rw [getD_eq_get _ _ _ hlt]
  simpa using hk

theorem pushAt_getD {α β : Type} (d : α × List β) : ∀ (l : List (α × List β)) (gi : ℕ) (m : β) (g : ℕ),
    (pushAt l gi m).getD g d = if g = gi ∧ gi < l.length then ((l.getD g d).1, (l.getD g d).2 ++ [m]) else l.getD g d
  | [], gi, m, g => by simp [pushAt]
  | x :: l, 0, m, 0 => by simp [pushAt]
  | x :: l, 0, m, g + 1 => by simp [pushAt]
  | x :: l, i + 1, m, 0 => by simp [pushAt]
  | x :: l, i + 1, m, g + 1 => by
    simp only [pushAt, List.getD_cons_succ, List.length_cons]
    rw [pushAt_getD d l i m g]
    by_cases h : g = i ∧ i < l.length
    · rw [ite_eq_left h, ite_eq_left ⟨by omega, by omega⟩]
    · rw [ite_eq_right h, ite_eq_right (fun h' => h ⟨by omega, by omega⟩)]

theorem gInv_step (rows logCols : ℕ) (done : List ZClaim) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2)))
    (c : ZClaim) (h : GInv rows logCols done st) : GInv rows logCols (done ++ [c]) (groupStep rows logCols st c) := by
  obtain ⟨hl, hcw, hmem⟩ := h
  rcases hk : keyIdx st.1 (claimWeights c rows logCols).2 with _ | gi
  · have e : groupStep rows logCols st c = (st.1 ++ [(claimWeights c rows logCols).2],
        st.2 ++ [(zkeyWeights (claimWeights c rows logCols).2 logCols,
          [((claimWeights c rows logCols).1, c.value)])]) := by
      simp only [groupStep, hk]
    rw [e]
    refine ⟨by simp [hl], ?_, ?_⟩
    · intro g hg
      simp only [List.length_append, List.length_singleton] at hg
      by_cases hg' : g < st.2.length
      · rw [getD_append' _ _ _ _ hg', getD_append' _ _ _ _ (by omega)]
        exact hcw g hg'
      · have hge : g = st.2.length := by omega
        subst hge
        rw [getD_append_right' st.2 _ _ st.2.length le_rfl, getD_append_right' st.1 _ _ st.2.length (by omega),
          Nat.sub_self, ← hl, Nat.sub_self]
        rfl
    · intro c' hc'
      rcases List.mem_append.mp hc' with hc' | hc'
      · obtain ⟨g, hg, hkey, hm⟩ := hmem c' hc'
        refine ⟨g, by simp; omega, ?_, ?_⟩
        · rw [getD_append' _ _ _ _ (by omega)]
          exact hkey
        · rw [getD_append' _ _ _ _ hg]
          exact hm
      · rw [List.mem_singleton] at hc'
        subst hc'
        refine ⟨st.2.length, by simp, ?_, ?_⟩
        · rw [getD_append_right' _ _ _ _ (by omega), ← hl, Nat.sub_self]
          rfl
        · rw [getD_append_right' _ _ _ _ le_rfl, Nat.sub_self]
          simp
  · have e : groupStep rows logCols st c = (st.1, pushAt st.2 gi ((claimWeights c rows logCols).1, c.value)) := by
      simp only [groupStep, hk]
    obtain ⟨hgi, hkey⟩ := keyIdx_spec hk
    rw [e]
    refine ⟨by simp only [pushAt_length]; exact hl, ?_, ?_⟩
    · intro g hg
      simp only [pushAt_length] at hg
      simp only [pushAt_getD]
      split_ifs
      · exact hcw g hg
      · exact hcw g hg
    · intro c' hc'
      rcases List.mem_append.mp hc' with hc' | hc'
      · obtain ⟨g, hg, hkey', hm⟩ := hmem c' hc'
        refine ⟨g, by simpa [pushAt_length] using hg, hkey', ?_⟩
        simp only [pushAt_getD]
        split_ifs
        · exact List.mem_append_left _ hm
        · exact hm
      · rw [List.mem_singleton] at hc'
        subst hc'
        refine ⟨gi, by simp only [pushAt_length]; omega, hkey, ?_⟩
        rw [pushAt_getD, ite_eq_left ⟨rfl, by omega⟩]
        exact List.mem_append_right _ (List.mem_singleton_self _)

theorem gInv_foldl (rows logCols : ℕ) : ∀ (cl done : List ZClaim)
    (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))), GInv rows logCols done st →
    GInv rows logCols (done ++ cl) (cl.foldl (groupStep rows logCols) st)
  | [], done, st, h => by simpa using h
  | c :: cl, done, st, h => by
    rw [List.foldl_cons, show done ++ c :: cl = (done ++ [c]) ++ cl by simp]
    exact gInv_foldl rows logCols cl _ _ (gInv_step rows logCols done st c h)

/-- **`group_zclaims`' groups**: each group's column weights are its key's, and every claim is a member of the group
of its key. -/
theorem groupZclaims_mem (rows logCols : ℕ) (cl : List ZClaim) :
    ∀ c ∈ cl, ∃ g, g < (groupZclaims cl rows logCols).length
      ∧ ((groupZclaims cl rows logCols).getD g ([], [])).1
        = zkeyWeights (claimWeights c rows logCols).2 logCols
      ∧ ((claimWeights c rows logCols).1, c.value) ∈ ((groupZclaims cl rows logCols).getD g ([], [])).2 := by
  unfold groupZclaims
  have hI := gInv_foldl rows logCols cl [] ([], []) ⟨rfl, fun g hg => absurd hg (by simp), fun c hc => by simp at hc⟩
  obtain ⟨-, hcw, hmem⟩ := hI
  intro c hc
  obtain ⟨g, hg, hkey, hm⟩ := hmem c (by simpa using hc)
  refine ⟨g, hg, ?_, hm⟩
  rw [hcw g hg, hkey]

theorem memsFrom_length : ∀ (g : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))),
    (memsFrom g gs).length = (gs.map (·.2.length)).sum
  | _, [] => rfl
  | g, x :: xs => by
    rw [memsFrom, List.length_append, List.length_map, memsFrom_length (g + 1) xs, List.map_cons, List.sum_cons]

theorem memsOf_length (gs : List (List Fp2 × List (List Fp2 × Fp2))) :
    (memsOf gs).length = (gs.map (·.2.length)).sum := memsFrom_length 0 gs

theorem mem_memsFrom : ∀ (g0 : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (g : ℕ), g < gs.length →
    ∀ m ∈ (gs.getD g ([], [])).2, (g0 + g, m) ∈ memsFrom g0 gs
  | _, [], g, hg, _, _ => absurd hg (by simp)
  | g0, x :: xs, 0, _, m, hm => by
    rw [memsFrom, Nat.add_zero]
    exact List.mem_append_left _ (List.mem_map.mpr ⟨m, hm, rfl⟩)
  | g0, x :: xs, g + 1, hg, m, hm => by
    rw [memsFrom]
    refine List.mem_append_right _ ?_
    rw [show g0 + (g + 1) = (g0 + 1) + g by omega]
    exact mem_memsFrom (g0 + 1) xs g (by simpa using hg) m (by simpa using hm)

theorem mem_memsOf (gs : List (List Fp2 × List (List Fp2 × Fp2))) (g : ℕ) (hg : g < gs.length)
    (m : List Fp2 × Fp2) (hm : m ∈ (gs.getD g ([], [])).2) : (g, m) ∈ memsOf gs := by
  have := mem_memsFrom 0 gs g hg m hm
  rwa [Nat.zero_add] at this

/-- **The regular opening's good case makes every claim true** (`hsem` for `A` and `H`): `GroupsGood` of the `OClaims`
the sub-protocols state (`oclOf` of `group_zclaims` of the opened claims, `nC` of them) gives, for EVERY claim `z` of
the list, its value on the decoded extracted matrix. -/
theorem groupsGood_claimSem {ι : Type} [Fintype ι] (rows logCols Q : ℕ)
    (enc : (Fin (2 ^ logCols + Q) → K) →ₗ[K] (ι → K)) (e : ℕ) (Ux : Fin rows → ι → K) (cl : List Block.ZClaim)
    (nC : ℕ) (hnC : cl.length = nC)
    (hg : GroupsGood enc e Ux (oclOf U rows logCols Q nC (groupZclaims (cl.map toZClaim) rows logCols)).rw
      (oclOf U rows logCols Q nC (groupZclaims (cl.map toZClaim) rows logCols)).cw
      (oclOf U rows logCols Q nC (groupZclaims (cl.map toZClaim) rows logCols)).grp
      (oclOf U rows logCols Q nC (groupZclaims (cl.map toZClaim) rows logCols)).val) :
    ∀ z ∈ cl, claimSem U rows logCols Q (decodeRows enc e Ux) z = z.value.toK U := by
  intro z hz
  obtain ⟨g, hglt, hcw, hm⟩ := groupZclaims_mem rows logCols (cl.map toZClaim) (toZClaim z) (List.mem_map_of_mem hz)
  have hmem := mem_memsOf (groupZclaims (cl.map toZClaim) rows logCols) g hglt _ hm
  obtain ⟨p, hp, hpe⟩ := List.getElem_of_mem hmem
  have hpl : p < nC := by
    rw [← hnC]
    have := memsOf_length (groupZclaims (cl.map toZClaim) rows logCols)
    rw [groupZclaims_count, List.length_map] at this
    omega
  have hget : (memsOf (groupZclaims (cl.map toZClaim) rows logCols)).getD p (0, ([], Fp2.zero))
      = (g, ((claimWeights (toZClaim z) rows logCols).1, z.value)) := by
    rw [getD_eq_get _ _ _ hp]
    exact hpe
  have hc := groupsGood_claims enc e Ux _ _ _ _ hg ⟨p, hpl⟩
  unfold claimValue at hc
  simp only [oclOf, hget] at hc
  rw [hcw] at hc
  unfold claimSem claimRw claimCw
  exact hc

end OSem

end ZK60.Exec.Link
