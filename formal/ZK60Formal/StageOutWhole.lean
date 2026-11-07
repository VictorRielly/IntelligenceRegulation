/-
D63, Lean lane L15 (2026-11-07): **stage OUT (the next-token run's last stage) as ONE theorem**, the interactive form,
as `outc_stage_sound` (StageOutCWhole.lean) does for stage OUT-C.

The code (hashline src/private_block/token_io/stage_out.rs, `verify` at :771, `define` at :336-542): after `A_out`
and `M`, `γ, α` (`g_u8 = γ·TAG_U8`), then `H_out`, then eleven slots:
* OUTC-00 IO-in, OUT-01 SS, OUT-02 TZC, OUT-05 DZC, OUT-08 TAB, OUT-09 ZS: as stage OUT-C's (the same closures);
* OUT-03 LZC (STANDALONE here: the limb plane's single byte-lookup helper and the pad, batched by `μ[2]`, no host);
* OUT-04 HEAD (private, `d_bits`, degree 2; draws `r_j` on `Vo`): `Σ_i y(i)·W'(r_j, i)`,
  `W'(r_j, i) = Σ_{z<V} eq(r_j, z)·m_z·W[z][i]` (`head_fold`, token_io.rs:708);
* OUT-06 VZC (host of HEAD, `Vo`, degree 5; draws `τ, μ[1 + hv + 1], ν, ζ`): `e(1 − e)`, the keyed limbs' helpers
  (`hv = ⌈l/2⌉`: pairs, the last a single when `l` is odd), the pad `(1 − s)·zeta_fold(e, λ_0 … λ_{l−1})`, and the host
  term `ν·eq(r_j, z)·l*(z)`, `l*(z) = s(z)·(M + 2^{−v}·(ι(z) − tok − δ(z)))`, `δ = Σ_k 256^k·λ_k`;
* OUT-07 RSEL (standalone, NO eq factor, claim 0; draws `c[3]`): `s·e·(c₁ + c₂·ι + c₃·δ) − u0·(c₁ + c₂·tok)`;
* OUT-10 IO-out (standalone, the output endpoint's words, degree 3): `eq·(end − u0·tok)`;
* the `H` opening's value-0 LogUp sum claim.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `vzcW`, `vzcPz`, `vzcHost`, `rselF`, `iooR`: VZC's, RSEL's and IO-out's closures on the tables' extensions, with
  their degrees;
* `head_vzc_sound`: HEAD (private) hosted by VZC (a host with a pad), with ANY coordinates between them (DZC's), and
  `r_j`'s Schwartz–Zippel step: the keyed values `l*` and the head values `l` (both fixed before `r_j`) differ, or a
  VZC clause or pad fails, and yet both slots accept, with probability at most
  `nv/|K| + nd·2/|K| + ((1 + l − 1) + (2 + nv + 5nv))/|K|`;
* `rsel_sound`: RSEL accepts while one of its three identities fails with probability at most `1/|K| + 4·nv/|K|`;
* `out_of_facts`: every looked value a byte and the slots' facts at the logical positions give `OutSat` (CircuitOut.lean)
  on `B_out`'s last row for the token word `tok`, and the output endpoint holds `tok` at its word 0 and zero elsewhere;
* `outCube`: the slots' relations on their cubes, the pads and the `H` sum claim give the byte LogUp's relations at
  the logical positions and the facts;
* **`out_stage_sound`**: the WHOLE stage. Over `(γ, α)` and then the eleven slots' challenges, for ANY helpers, ANY
  published scalars and ANY sumcheck provers, the stage accepts while `OutSat` or the output endpoint's identity FAILS
  with probability at most the byte LogUp's `(|ι| + 2·|π| + 2·256 − 1)/|K|` plus the slots' terms (`outSlotsErr`);
* `out_numerator_8B`: at the 8B shape (`V_pad = 2^17`, every other stage domain `2^12`, `l = 7`, `To = 2`, the output
  endpoint `2^8` words) the numerator is `971,826` (`≈ 2^19.89`, the byte LogUp's VZC limbs over the whole `Vo` cube
  dominate): about `2^-108.1` over `|Fp2| ≈ 2^128` [ESTIMATE].

The stage OUT-C machinery (TZC, DZC, TAB, the cube lemmas) is reused through `toCData` / `toCPub` / `toCLay`: stage
OUT's shared planes and layout as an OUT-C instance with no margin (`limbs = 0`, `w_Δ = 0`, `b = c = 0`). Modelling
boundary: as `outc_stage_sound`.
-/
import ZK60Formal.StageOutCWhole
import ZK60Formal.StageOutExtract

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

/-! ## VZC, RSEL and IO-out as the code writes them -/

section Closures

variable {K : Type} [Field K]

/-- VZC's keyed limbs recomposed, `δ = Σ_k 2^(8k)·λ_k`. -/
def vzcDelta {n l : ℕ} (lam : Fin l → (Fin n → Bool) → K) (x : Fin n → K) : K :=
  ∑ k : Fin l, (2 : K) ^ (8 * k.val) * mleAt (lam k) x

/-- VZC's lookup denominator of limb `j`: `α − (λ_j + g)`. -/
def vzcDen {n l : ℕ} (lam : Fin l → (Fin n → Bool) → K) (α g : K) (j : Fin l) (x : Fin n → K) : K :=
  α - (mleAt (lam j) x + g)

/-- VZC's clauses: `e(1 − e)`, then the `l/2 + l%2` helpers (helper `k` covers limbs `2k`, `2k + 1`; the last is a single
when `l` is odd: `helper_sum`'s `None` branch). -/
def vzcW {n l : ℕ} (e : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K)
    (hv : Fin (l / 2 + l % 2) → (Fin n → Bool) → K) (α g : K) : Unit ⊕ Fin (l / 2 + l % 2) → (Fin n → K) → K
  | .inl _ => fun x => mleAt e x * (1 - mleAt e x)
  | .inr k => fun x =>
    if h : 2 * k.val + 1 < l then
      mleAt (hv k) x * vzcDen lam α g ⟨2 * k.val, by omega⟩ x * vzcDen lam α g ⟨2 * k.val + 1, h⟩ x
        - (vzcDen lam α g ⟨2 * k.val, by omega⟩ x + vzcDen lam α g ⟨2 * k.val + 1, h⟩ x)
    else if h' : 2 * k.val < l then mleAt (hv k) x * vzcDen lam α g ⟨2 * k.val, h'⟩ x - 1 else 0

/-- VZC's pad planes `(1 − s)·e`, `(1 − s)·λ_j` (`zeta_fold` of `e, λ_0 …`). -/
def vzcPz {n l : ℕ} (s e : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K) : Fin (1 + l) → (Fin n → K) → K :=
  fun i x => (1 - mleAt s x) * (if h : i.val = 0 then mleAt e x else mleAt (lam ⟨i.val - 1, by omega⟩) x)

/-- VZC's host term `eq(r_j, x)·s(x)·(M + 2^{−v}·(ι(x) − tok − δ(x)))` (`v[i_rj]·lstar`). -/
def vzcHost {n l : ℕ} (r : Fin n → K) (s io : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K) (Mc tokc iv : K)
    (x : Fin n → K) : K :=
  eqPoly r x * (mleAt s x * (Mc + iv * (mleAt io x - tokc - vzcDelta lam x)))

/-- RSEL's polynomial `s·e·(c₁ + c₂·ι + c₃·δ) − u0·(c₁ + c₂·tok)` (stage_out.rs:503-506). -/
def rselF {n l : ℕ} (s e io u0 : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K) (tokc : K) (c : Fin 3 → K)
    (x : Fin n → K) : K :=
  mleAt s x * mleAt e x * (c 0 + c 1 * mleAt io x + c 2 * vzcDelta lam x) - mleAt u0 x * (c 0 + c 1 * tokc)

/-- IO-out's clause `end − u0·tok` (stage_out.rs:538). -/
def iooR {n : ℕ} (ep u0 : (Fin n → Bool) → K) (tokc : K) (x : Fin n → K) : K := mleAt ep x - mleAt u0 x * tokc

theorem vzcDelta_deg {n l : ℕ} (lam : Fin l → (Fin n → Bool) → K) : IndDegLE 1 (vzcDelta lam) :=
  IndDegLE.wsum (fun k => mle_deg (lam k) (d := 1) le_rfl) (fun k : Fin l => (2 : K) ^ (8 * k.val))

theorem vzcDen_deg {n l : ℕ} (lam : Fin l → (Fin n → Bool) → K) (α g : K) (j : Fin l) :
    IndDegLE 1 (vzcDen lam α g j) :=
  IndDegLE.sub (IndDegLE.const α) (IndDegLE.add (mle_deg _ le_rfl) (IndDegLE.const g))

theorem vzcW_deg {n l : ℕ} (e : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K)
    (hv : Fin (l / 2 + l % 2) → (Fin n → Bool) → K) (α g : K) : ∀ j, IndDegLE 4 (vzcW e lam hv α g j)
  | .inl _ => by
      show IndDegLE 4 (fun x => mleAt e x * (1 - mleAt e x))
      exact IndDegLE.mono (IndDegLE.mul (mle_deg e le_rfl) (IndDegLE.sub (IndDegLE.const 1) (mle_deg e le_rfl)))
        (by norm_num)
  | .inr k => by
      by_cases h : 2 * k.val + 1 < l
      · have e1 : vzcW e lam hv α g (.inr k) = fun x =>
            mleAt (hv k) x * vzcDen lam α g ⟨2 * k.val, by omega⟩ x * vzcDen lam α g ⟨2 * k.val + 1, h⟩ x
              - (vzcDen lam α g ⟨2 * k.val, by omega⟩ x + vzcDen lam α g ⟨2 * k.val + 1, h⟩ x) := by
          funext x
          simp only [vzcW, h, ↓reduceDIte]
        rw [e1]
        exact IndDegLE.sub (IndDegLE.mono (IndDegLE.mul (IndDegLE.mul (mle_deg _ le_rfl) (vzcDen_deg _ _ _ _))
          (vzcDen_deg _ _ _ _)) (by norm_num))
          (IndDegLE.mono (IndDegLE.add (vzcDen_deg _ _ _ _) (vzcDen_deg _ _ _ _)) (by norm_num))
      · by_cases h' : 2 * k.val < l
        · have e1 : vzcW e lam hv α g (.inr k) = fun x =>
              mleAt (hv k) x * vzcDen lam α g ⟨2 * k.val, h'⟩ x - 1 := by
            funext x
            simp only [vzcW, h, h', ↓reduceDIte]
          rw [e1]
          exact IndDegLE.sub (IndDegLE.mono (IndDegLE.mul (mle_deg _ le_rfl) (vzcDen_deg _ _ _ _)) (by norm_num))
            (IndDegLE.const 1)
        · have e1 : vzcW e lam hv α g (.inr k) = fun _ => 0 := by
            funext x
            simp only [vzcW, h, h', ↓reduceDIte]
          rw [e1]
          exact IndDegLE.const 0

theorem vzcPz_deg {n l : ℕ} (s e : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K) :
    ∀ i, IndDegLE 4 (vzcPz s e lam i) := by
  intro i
  by_cases h : i.val = 0
  · have e1 : vzcPz s e lam i = fun x => (1 - mleAt s x) * mleAt e x := by
      funext x
      simp only [vzcPz, h, ↓reduceDIte]
    rw [e1]
    exact padPl_deg s e (by norm_num)
  · have e1 : vzcPz s e lam i = fun x => (1 - mleAt s x) * mleAt (lam ⟨i.val - 1, by omega⟩) x := by
      funext x
      simp only [vzcPz, h, ↓reduceDIte]
    rw [e1]
    exact padPl_deg s _ (by norm_num)

theorem vzcHost_deg {n l : ℕ} (r : Fin n → K) (s io : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K)
    (Mc tokc iv : K) : IndDegLE (4 + 1) (vzcHost r s io lam Mc tokc iv) := by
  have h : IndDegLE 2 (fun x => mleAt s x * (Mc + iv * (mleAt io x - tokc - vzcDelta lam x))) :=
    IndDegLE.mul (mle_deg s le_rfl) (IndDegLE.add (IndDegLE.const Mc) (IndDegLE.cmul iv
      (IndDegLE.sub (IndDegLE.sub (mle_deg io le_rfl) (IndDegLE.const tokc)) (vzcDelta_deg lam))))
  exact IndDegLE.mono (h.eq_mul r) (by norm_num)

theorem rselF_deg {n l : ℕ} (s e io u0 : (Fin n → Bool) → K) (lam : Fin l → (Fin n → Bool) → K) (tokc : K)
    (c : Fin 3 → K) : IndDegLE 4 (rselF s e io u0 lam tokc c) := by
  have h1 : IndDegLE 3 (fun x => mleAt s x * mleAt e x * (c 0 + c 1 * mleAt io x + c 2 * vzcDelta lam x)) :=
    IndDegLE.mul (IndDegLE.mul (mle_deg s le_rfl) (mle_deg e le_rfl))
      (IndDegLE.add (IndDegLE.add (IndDegLE.const _) (IndDegLE.cmul _ (mle_deg io le_rfl)))
        (IndDegLE.cmul _ (vzcDelta_deg lam)))
  have h2 : IndDegLE 3 (fun x => mleAt u0 x * (c 0 + c 1 * tokc)) :=
    IndDegLE.mono (IndDegLE.mul (mle_deg u0 le_rfl) (IndDegLE.const (d := 0) _)) (by norm_num)
  exact IndDegLE.mono (IndDegLE.sub h1 h2) (by norm_num)

theorem iooR_deg {n : ℕ} (ep u0 : (Fin n → Bool) → K) (tokc : K) : IndDegLE 2 (iooR ep u0 tokc) :=
  IndDegLE.mono (IndDegLE.sub (mle_deg ep le_rfl)
    (IndDegLE.mono (IndDegLE.mul (mle_deg u0 le_rfl) (IndDegLE.const (d := 0) tokc)) (by norm_num))) (by norm_num)

end Closures

/-! ## HEAD hosted by VZC, with `r_j`'s Schwartz–Zippel step; RSEL -/

section Pairs

variable {K : Type} [Field K]

/-- **HEAD (private) hosted by VZC (a host with a pad), with any middle coordinates (DZC's), and `r_j`'s step.** For
the head values `Lh` and the keyed values `Ls` (fixed before `r_j`, as base-field tables through `φ`), HEAD's table
`Wp r` and VZC's host term `Hs r` functions of `r_j` with `Σ HEAD = mle(Lh)(r_j)` and `Σ Hs = mle(Ls)(r_j)`, ANY
published scalar and ANY provers: HEAD accepts `S`, VZC accepts `ν·S`, and yet `Ls ≠ Lh` or a VZC clause or pad
fails, with probability at most `nv/|K| + np·2/|K| + ((m − 1) + (2 + nv + nv·(4 + 1)))/|K|`. -/
theorem head_vzc_sound [Fintype K] [DecidableEq K] {B : Type} [Field B] (φ : B →+* K) {ι : Type} [Fintype ι]
    [DecidableEq ι] {Mid : Type} [Fintype Mid] [Nonempty Mid] {np nv m : ℕ} (hK : 4 + 1 < ringChar K)
    (Y : (Fin np → Bool) → K) (Wp : (Fin nv → K) → (Fin np → Bool) → K) (Ls Lh : (Fin nv → Bool) → B)
    (hWp : ∀ r, ∑ b, Y b * Wp r b = mleAt (fun c => φ (Lh c)) r)
    (W : ι → (Fin nv → K) → K) (Pz : Fin m → (Fin nv → K) → K) (hW : ∀ j, IndDegLE 4 (W j))
    (hP : ∀ i, IndDegLE 4 (Pz i)) (Hs : (Fin nv → K) → (Fin nv → K) → K) (hHs : ∀ r, IndDegLE (4 + 1) (Hs r))
    (hHsum : ∀ r, cubeSum (Hs r) = mleAt (fun c => φ (Ls c)) r)
    (S : (Fin nv → K) → K) (Pp : (Fin nv → K) → Prover K 2 np)
    (Ph : (Fin nv → K) × (Fin np → K) → Mid → K → ((Option ι → K) × K) × (Fin nv → K) → Prover K (4 + 1) nv) :
    pr (fun ω : ((Fin nv → K) × (Fin np → K)) × (Mid × (K × ((((Option ι → K) × K) × (Fin nv → K)) × (Fin nv → K)))) =>
        Accepts np (fun x => mleAt Y x * mleAt (Wp ω.1.1) x) (S ω.1.1) (Pp ω.1.1) ω.1.2 ∧
        accHostPad W Pz (Hs ω.1.1) (S ω.1.1) (Ph ω.1 ω.2.1) ω.2.2 ∧
        ¬ (Ls = Lh ∧ (∀ j, ∀ b : Fin nv → Bool, W j (bitv b) = 0) ∧ ∀ i, ∀ b : Fin nv → Bool, Pz i (bitv b) = 0))
      ≤ (nv : ℝ≥0∞) / Fintype.card K + (((np * 2 : ℕ) : ℝ≥0∞) / Fintype.card K
        + (((m - 1) + (2 + (nv + nv * (4 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K) := by
  classical
  have hd2 : 2 < ringChar K := lt_trans (by norm_num) hK
  have hsub : ∀ ω : ((Fin nv → K) × (Fin np → K)) × (Mid × (K × ((((Option ι → K) × K) × (Fin nv → K)) ×
      (Fin nv → K)))),
      (Accepts np (fun x => mleAt Y x * mleAt (Wp ω.1.1) x) (S ω.1.1) (Pp ω.1.1) ω.1.2 ∧
        accHostPad W Pz (Hs ω.1.1) (S ω.1.1) (Ph ω.1 ω.2.1) ω.2.2 ∧
        ¬ (Ls = Lh ∧ (∀ j, ∀ b : Fin nv → Bool, W j (bitv b) = 0) ∧ ∀ i, ∀ b : Fin nv → Bool, Pz i (bitv b) = 0)) →
      (mleAt (fun c => φ (Ls c)) ω.1.1 = mleAt (fun c => φ (Lh c)) ω.1.1 ∧ Ls ≠ Lh) ∨
      ((Accepts np (fun x => mleAt Y x * mleAt (Wp ω.1.1) x) (S ω.1.1) (Pp ω.1.1) ω.1.2 ∧
          S ω.1.1 ≠ cubeSum (fun x => mleAt Y x * mleAt (Wp ω.1.1) x)) ∨
        (accHostPad W Pz (Hs ω.1.1) (S ω.1.1) (Ph ω.1 ω.2.1) ω.2.2 ∧
          ((∃ j, ∃ b : Fin nv → Bool, W j (bitv b) ≠ 0) ∨ (∃ i, ∃ b : Fin nv → Bool, Pz i (bitv b) ≠ 0) ∨
            cubeSum (Hs ω.1.1) ≠ S ω.1.1))) := by
    rintro ω ⟨hp, hh, hn⟩
    by_cases hS : S ω.1.1 = cubeSum (fun x => mleAt Y x * mleAt (Wp ω.1.1) x)
    · by_cases hb : (∃ j, ∃ b : Fin nv → Bool, W j (bitv b) ≠ 0) ∨ (∃ i, ∃ b : Fin nv → Bool, Pz i (bitv b) ≠ 0) ∨
          cubeSum (Hs ω.1.1) ≠ S ω.1.1
      · exact Or.inr (Or.inr ⟨hh, hb⟩)
      · push Not at hb
        obtain ⟨hW0, hP0, hHS⟩ := hb
        refine Or.inl ⟨?_, fun he => hn ⟨he, hW0, hP0⟩⟩
        rw [← hHsum, hHS, hS, pd_sum, hWp]
    · exact Or.inr (Or.inl ⟨hp, hS⟩)
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans (add_le_add ?_ ((pr_or_le _ _).trans (add_le_add ?_ ?_))))
  · -- `r_j`'s step
    refine (pr_fst_le (fun a : (Fin nv → K) × (Fin np → K) =>
      mleAt (fun c => φ (Ls c)) a.1 = mleAt (fun c => φ (Lh c)) a.1 ∧ Ls ≠ Lh)).trans ?_
    exact (pr_fst_le (fun r : Fin nv → K => mleAt (fun c => φ (Ls c)) r = mleAt (fun c => φ (Lh c)) r ∧ Ls ≠ Lh)).trans
      (head_sz_prob φ Ls Lh)
  · -- HEAD: a false published sum
    refine (pr_fst_le (fun a : (Fin nv → K) × (Fin np → K) =>
      Accepts np (fun x => mleAt Y x * mleAt (Wp a.1) x) (S a.1) (Pp a.1) a.2 ∧
        S a.1 ≠ cubeSum (fun x => mleAt Y x * mleAt (Wp a.1) x))).trans ?_
    refine pr_prod_le _ (fun r => ?_)
    by_cases hS : S r = cubeSum (fun x => mleAt Y x * mleAt (Wp r) x)
    · exact pr_le_of_not _ (fun ρ hρ => hρ.2 hS) _
    · exact (pr_mono (E' := fun ρ => Accepts np (fun x => mleAt Y x * mleAt (Wp r) x) (S r) (Pp r) ρ)
        (fun ρ hρ => hρ.1)).trans (sumcheck_sound hd2 (IndDegLE.mul (mle_deg Y le_rfl) (mle_deg _ le_rfl)) hS (Pp r))
  · -- VZC: at every HEAD challenge and middle coordinate
    refine pr_prod_le _ (fun a => pr_prod_le _ (fun md => ?_))
    by_cases hb : (∃ j, ∃ b : Fin nv → Bool, W j (bitv b) ≠ 0) ∨ (∃ i, ∃ b : Fin nv → Bool, Pz i (bitv b) ≠ 0) ∨
        cubeSum (Hs a.1) ≠ S a.1
    · refine (pr_mono (E' := fun ω => accHostPad W Pz (Hs a.1) (S a.1) (Ph a md) ω) (fun ω hω => hω.1)).trans ?_
      exact host_pad_sound hK W Pz hW hP (Hs a.1) (hHs a.1) (S a.1) hb (Ph a md)
    · exact pr_le_of_not _ (fun ω hω => hb hω.2) _

/-- **RSEL, sound**: for tables fixed before RSEL's challenges, over its `c` and rounds, RSEL accepts the claim `0`
while one of the three identities fails with probability at most `1/|K| + 4·n/|K|`. -/
theorem rsel_sound [Fintype K] [DecidableEq K] {V n : ℕ} (hK : 4 < ringChar K) (F : (Fin 3 → K) → (Fin n → K) → K)
    (hF : ∀ c, IndDegLE 4 (F c)) (e δ : Fin V → K) (tok : K)
    (hsum : ∀ c, cubeSum (F c) = ∑ k, c k * rselRes e δ tok k) (P : (Fin 3 → K) → Prover K 4 n) :
    pr (fun ω : (Fin 3 → K) × (Fin n → K) => Accepts n (F ω.1) 0 (P ω.1) ω.2 ∧ ¬ ∀ k, rselRes e δ tok k = 0)
      ≤ (1 : ℝ≥0∞) / Fintype.card K + ((n * 4 : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  have hsub : ∀ ω : (Fin 3 → K) × (Fin n → K), (Accepts n (F ω.1) 0 (P ω.1) ω.2 ∧ ¬ ∀ k, rselRes e δ tok k = 0) →
      (∑ k, ω.1 k * rselRes e δ tok k = 0 ∧ ¬ ∀ k, rselRes e δ tok k = 0) ∨
        (∑ k, ω.1 k * rselRes e δ tok k ≠ 0 ∧ Accepts n (F ω.1) 0 (P ω.1) ω.2) := by
    rintro ω ⟨ha, hn⟩
    by_cases h0 : ∑ k, ω.1 k * rselRes e δ tok k = 0
    · exact Or.inl ⟨h0, hn⟩
    · exact Or.inr ⟨h0, ha⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans (add_le_add ?_ ?_))
  · exact (pr_fst_le (fun c : Fin 3 → K => ∑ k, c k * rselRes e δ tok k = 0 ∧ ¬ ∀ k, rselRes e δ tok k = 0)).trans
      (rsel_batch_sound e δ tok)
  · refine pr_prod_le _ (fun c => ?_)
    by_cases h0 : ∑ k, c k * rselRes e δ tok k = 0
    · exact pr_le_of_not _ (fun ρ hρ => hρ.1 h0) _
    · refine (pr_mono (E' := fun ρ => Accepts n (F c) 0 (P c) ρ) (fun ρ hρ => hρ.2)).trans ?_
      refine sumcheck_sound hK (hF c) ?_ (P c)
      rw [hsum c]
      exact Ne.symm h0

end Pairs

/-! ## Stage OUT's data, layout and the facts at the logical positions -/

section Stage

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out

variable {K : Type} [Field K]

/-- **What stage OUT commits on `A_out`** (stage_out.rs:24-35) and the boundary row and output endpoint it reads: the
`To` planes `D, Dsq, TOK, M`; the limb plane; the twelve `Do` planes; the selector `e` and the keyed limbs `λ_j` on
`Vo`; the byte histogram; `B_out`'s last row; the output token endpoint's words. -/
structure OutData (n₀ nd ndo nl nv nt nep l : ℕ) where
  D : (Fin n₀ → Bool) → GF
  Dsq : (Fin n₀ → Bool) → GF
  tok : (Fin n₀ → Bool) → GF
  M : (Fin n₀ → Bool) → GF
  limb : (Fin nl → Bool) → GF
  pl : Fin 12 → (Fin ndo → Bool) → GF
  e : (Fin nv → Bool) → GF
  lam : Fin l → (Fin nv → Bool) → GF
  mult : (Fin nt → Bool) → GF
  bout : (Fin nd → Bool) → GF
  ep : (Fin nep → Bool) → GF

/-- The planes stage OUT shares with stage OUT-C. -/
def OutData.toC {n₀ nd ndo nl nv nt nep l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) : OutCData n₀ nd ndo nl nt :=
  ⟨Dt.D, Dt.Dsq, Dt.limb, Dt.pl, Dt.mult, Dt.bout⟩

/-- Stage OUT's final-norm constants as an OUT-C public record with no margin. -/
def toCPub {d : ℕ} (P : OutPublic d) : OutCPublic d := ⟨fun _ => 0, 0, P.g0, P.cn, P.ceps, P.tn, 0⟩

/-- **Stage OUT's public tables and layout map** (stage_out.rs:336-542): OUT-C's shared ones (`To`'s entry 0, the limb
sub-planes, the `d_pad` cube in `Do`, the live channels, the byte table's rows, `u0`, `supp(d)`, LZC's live selector,
the table's selector and values), and stage OUT's own: the vocabulary entries `vpos z` on `Vo`, the output endpoint's
word 0, `supp(V)` (`sV`), the index column `ι` (`io`), RSEL's `u0` (`uV`), IO-out's `u0` (`uE`), and HEAD's table
`W'(r_j, ·)` (`Wp`, the code's `head_fold` of `eq(r_j)`). -/
structure OutLayout (φ : GF →+* K) {d : ℕ} (P : OutPublic d) (n₀ nd ndo nl nv nt nep : ℕ) where
  z0 : Fin n₀ → Bool
  lpos : Fin 9 → (Fin n₀ → Bool) → (Fin nl → Bool)
  dlift : (Fin nd → Bool) → (Fin ndo → Bool)
  dpos : Fin d → (Fin nd → Bool)
  tpos : Fin 256 → (Fin nt → Bool)
  vpos : Fin P.V → (Fin nv → Bool)
  zv0 : Fin nv → Bool
  epw0 : Fin nep → Bool
  dpos_inj : Function.Injective dpos
  live_inj : Function.Injective (fun i => dlift (dpos i))
  tpos_inj : Function.Injective tpos
  vpos_inj : Function.Injective vpos
  u0 : (Fin n₀ → Bool) → K
  sD : (Fin ndo → Bool) → K
  sL : (Fin nl → Bool) → K
  sT : (Fin nt → Bool) → K
  tv : K → (Fin nt → Bool) → K
  sV : (Fin nv → Bool) → GF
  io : (Fin nv → Bool) → GF
  uV : (Fin nv → Bool) → GF
  uE : (Fin nep → Bool) → GF
  Wp : (Fin nv → K) → (Fin nd → Bool) → K
  u0_eq : ∀ z, u0 z = if z = z0 then 1 else 0
  sD1 : ∀ i, sD (dlift (dpos i)) = 1
  sD0 : ∀ c, c ∉ Set.range (fun i => dlift (dpos i)) → sD c = 0
  sT1 : ∀ j, sT (tpos j) = 1
  sT0 : ∀ c, c ∉ Set.range tpos → sT c = 0
  tv_pos : ∀ g j, tv g (tpos j) = ((j : ℕ) : K) + g
  sV1 : ∀ z, sV (vpos z) = 1
  sV0 : ∀ c, c ∉ Set.range vpos → sV c = 0
  io_pos : ∀ z, io (vpos z) = ((z : ℕ) : GF)
  uV_eq : ∀ c, uV c = if c = zv0 then 1 else 0
  uE_eq : ∀ w, uE w = if w = epw0 then 1 else 0
  Wp_pos : ∀ r i, Wp r (dpos i) = ∑ z : Fin P.V, eqPoly r (bitv (vpos z)) * φ (((P.mult z : ℤ) * P.head z i : ℤ) : GF)
  Wp0 : ∀ r c, c ∉ Set.range dpos → Wp r c = 0

variable (φ : GF →+* K) {d n₀ nd ndo nl nv nt nep : ℕ} (P : OutPublic d)

/-- Stage OUT's shared layout as an OUT-C layout with no margin (`b = 0`). -/
def toCLay (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : OutCLayout φ (toCPub P) 0 n₀ nd ndo nl nt where
  z0 := L.z0
  lpos := L.lpos
  mpos := fun j => j.elim0
  zl0 := fun _ => false
  dlift := L.dlift
  dpos := L.dpos
  tpos := L.tpos
  mpos_inj := fun a => a.elim0
  dpos_inj := L.dpos_inj
  live_inj := L.live_inj
  tpos_inj := L.tpos_inj
  u0 := L.u0
  sD := L.sD
  sL := L.sL
  Gm := fun _ => 0
  uL := fun z => if z = (fun _ => false) then 1 else 0
  wd := fun _ => 0
  sT := L.sT
  tv := L.tv
  u0_eq := L.u0_eq
  sD1 := L.sD1
  sD0 := L.sD0
  Gm_pos := fun j => j.elim0
  Gm0 := fun _ _ => rfl
  uL_eq := fun _ => rfl
  wd_pos := fun i => by simp [toCPub]
  wd0 := fun _ _ => rfl
  sT1 := L.sT1
  sT0 := L.sT0
  tv_pos := L.tv_pos

/-- The keyed difference's limbs recomposed at a `Vo` entry. -/
def deltaB {l : ℕ} (lam : Fin l → (Fin nv → Bool) → GF) (c : Fin nv → Bool) : GF :=
  ∑ k : Fin l, (2 : GF) ^ (8 * k.val) * lam k c

/-- The keyed values `l*(c) = s(c)·(M + 2^{−v}·(ι(c) − tok − δ(c)))` on `Vo` (`lstar`, stage_out.rs:483). -/
def lstarB (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (c : Fin nv → Bool) : GF :=
  L.sV c * (Dt.M L.z0 + ((2 : GF) ^ P.vlog)⁻¹ * (L.io c - Dt.tok L.z0 - deltaB Dt.lam c))

/-- The head values `l(vpos z) = Σ_i y_i·m_z·W[z][i]` on `Vo` (zero off the vocabulary). -/
def lheadB (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (c : Fin nv → Bool) : GF :=
  ∑ z : Fin P.V, if L.vpos z = c then ∑ i, Dt.pl 3 (L.dlift (L.dpos i)) * (((P.mult z : ℤ) * P.head z i : ℤ) : GF)
    else 0

/-- **The facts the slots establish at the logical positions** (besides the byte lookups): OUT-C's IO-in, TZC, SS and
DZC facts on the shared planes; VZC's `e(1 − e)` at the vocabulary entries and its hosted identity (the keyed values are
the head values on the whole `Vo` cube); RSEL's three identities; IO-out's endpoint identity. -/
def OutFacts (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : Prop :=
  (∀ c, Dt.pl 0 (L.dlift c) = Dt.bout c) ∧
  Dt.Dsq L.z0 - Dt.D L.z0 * Dt.D L.z0 = 0 ∧
  Dt.D L.z0 - l3 (tzcLimbs φ (toCPub P) 0 Dt.toC (toCLay φ P L) 0) = 0 ∧
  2 * Dt.D L.z0 - l3 (tzcLimbs φ (toCPub P) 0 Dt.toC (toCLay φ P L) 1)
    - l3 (tzcLimbs φ (toCPub P) 0 Dt.toC (toCLay φ P L) 2) = 0 ∧
  Dt.Dsq L.z0 + l3 (tzcLimbs φ (toCPub P) 0 Dt.toC (toCLay φ P L) 1) - (P.ceps : GF)
    = ∑ i, liveW φ (toCPub P) 0 Dt.toC (toCLay φ P L) 0 i * liveW φ (toCPub P) 0 Dt.toC (toCLay φ P L) 0 i ∧
  (∀ i (j : Fin 3), dzcCB (toCPub P) Dt.toC (Dt.D L.z0) j (L.dlift (L.dpos i)) = 0) ∧
  (∀ z, Dt.e (L.vpos z) * (1 - Dt.e (L.vpos z)) = 0) ∧
  lstarB φ P Dt L = lheadB φ P Dt L ∧
  (∀ k, rselRes (fun z => Dt.e (L.vpos z)) (fun z => deltaB Dt.lam (L.vpos z)) (Dt.tok L.z0) k = 0) ∧
  (∀ w, Dt.ep w - L.uE w * Dt.tok L.z0 = 0)

/-! ### The byte lookups of stage OUT -/

/-- The singles: `Lo`'s limb plane (LZC) and, when `l` is odd, VZC's last limb at every `Vo` entry. -/
def outA {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) : (Fin nl → Bool) ⊕ (Fin (l % 2) × (Fin nv → Bool)) → GF
  | .inl z => Dt.limb z
  | .inr jc => Dt.lam ⟨l - 1, by have := jc.1.isLt; omega⟩ jc.2

/-- The pairs: DZC's six helpers on `Do`, VZC's `⌊l/2⌋` pair helpers on `Vo`. -/
def outP1 {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) :
    (Fin 6 × (Fin ndo → Bool)) ⊕ (Fin (l / 2) × (Fin nv → Bool)) → GF
  | .inl kc => outcP1 Dt.toC kc
  | .inr kc => Dt.lam ⟨2 * kc.1.val, by have := kc.1.isLt; omega⟩ kc.2

def outP2 {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) :
    (Fin 6 × (Fin ndo → Bool)) ⊕ (Fin (l / 2) × (Fin nv → Bool)) → GF
  | .inl kc => outcP2 Dt.toC kc
  | .inr kc => Dt.lam ⟨2 * kc.1.val + 1, by have := kc.1.isLt; omega⟩ kc.2

/-- The helpers stage OUT commits in `H_out`: `Lo`'s, `Do`'s six, `Vo`'s `l/2 + l%2`, the byte table's, the zero-sum row. -/
abbrev OutHelpers (K : Type) (nl ndo nv nt nu l : ℕ) :=
  ((Fin nl → Bool) → K) × ((Fin 6 → (Fin ndo → Bool) → K) × ((Fin (l / 2 + l % 2) → (Fin nv → Bool) → K) ×
    (((Fin nt → Bool) → K) × ((Fin nu → Bool) → K))))

/-- The `H` opening's value-0 LogUp sum claim (the table helper with sign `−1`). -/
def OutSum {nl ndo nv nt nu l : ℕ} (hd : OutHelpers K nl ndo nv nt nu l) : Prop :=
  ∑ z, hd.1 z + ∑ k, ∑ c, hd.2.1 k c + ∑ k, ∑ c, hd.2.2.1 k c - ∑ c, hd.2.2.2.1 c + ∑ j, hd.2.2.2.2 j = 0

/-- The logical helpers of `HelperRel`. -/
def outHelpers {nu l : ℕ} (L : OutLayout φ P n₀ nd ndo nl nv nt nep) (hd : OutHelpers K nl ndo nv nt nu l) :
    Helpers ((Fin nl → Bool) ⊕ (Fin (l % 2) × (Fin nv → Bool))) ((Fin 6 × (Fin ndo → Bool)) ⊕
      (Fin (l / 2) × (Fin nv → Bool))) (Fin 256) K where
  single
    | .inl z => hd.1 z
    | .inr jc => hd.2.2.1 ⟨l / 2, by have := jc.1.isLt; omega⟩ jc.2
  pair
    | .inl kc => hd.2.1 kc.1 kc.2
    | .inr kc => hd.2.2.1 ⟨kc.1.val, by have := kc.1.isLt; omega⟩ kc.2
  table j := hd.2.2.2.1 (L.tpos j)

/-- The byte table's multiplicities at its live rows. -/
def outMult {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) :
    Fin 256 → K := fun j => φ (Dt.mult (L.tpos j))

/-- Every keyed limb is a byte once every VZC lookup is (the pairs `2k, 2k + 1`, the odd last single). -/
theorem lam_byte {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (hA : ∀ s, IsByte (outA Dt s))
    (hP : ∀ p, IsByte (outP1 Dt p) ∧ IsByte (outP2 Dt p)) (j : Fin l) (c : Fin nv → Bool) : IsByte (Dt.lam j c) := by
  by_cases hj : j.val < 2 * (l / 2)
  · have hk : j.val / 2 < l / 2 := by omega
    rcases Nat.even_or_odd j.val with he | ho
    · have e : (⟨2 * (j.val / 2), by omega⟩ : Fin l) = j := by
        ext
        show 2 * (j.val / 2) = j.val
        obtain ⟨r, hr⟩ := he
        omega
      have := (hP (.inr (⟨j.val / 2, hk⟩, c))).1
      simp only [outP1] at this
      rwa [e] at this
    · have e : (⟨2 * (j.val / 2) + 1, by omega⟩ : Fin l) = j := by
        ext
        show 2 * (j.val / 2) + 1 = j.val
        obtain ⟨r, hr⟩ := ho
        omega
      have := (hP (.inr (⟨j.val / 2, hk⟩, c))).2
      simp only [outP2] at this
      rwa [e] at this
  · have hodd : 0 < l % 2 := by omega
    have e : (⟨l - 1, by omega⟩ : Fin l) = j := by
      ext
      show l - 1 = j.val
      omega
    have := hA (.inr (⟨0, hodd⟩, c))
    simp only [outA] at this
    rwa [e] at this

/-- The head values at a vocabulary entry. -/
theorem lheadB_pos (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (z : Fin P.V) :
    lheadB φ P Dt L (L.vpos z) = ∑ i, Dt.pl 3 (L.dlift (L.dpos i)) * (((P.mult z : ℤ) * P.head z i : ℤ) : GF) := by
  classical
  unfold lheadB
  rw [Finset.sum_eq_single z (fun z' _ hz' => by rw [ite_eq_right (fun h => hz' (L.vpos_inj h))])
    (fun h => absurd (Finset.mem_univ z) h), ite_eq_left rfl]

theorem lheadB_off (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (c : Fin nv → Bool) (hc : c ∉ Set.range L.vpos) : lheadB φ P Dt L c = 0 := by
  classical
  unfold lheadB
  exact Finset.sum_eq_zero (fun z _ => by rw [ite_eq_right (fun h => hc ⟨z, h⟩)])

/-- **Every looked value a byte and the facts at the logical positions give `OutSat`** on `B_out`'s last row for the
token word, and SO_IOOUT's identity (`out_endpoint_word`): the output endpoint holds the token word at word 0. -/
theorem out_of_facts (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (hB : AllBytes (outA Dt) (outP1 Dt) (outP2 Dt)) (hF : OutFacts φ P Dt L) :
    OutSat P (fun i => Dt.bout (L.dpos i)) (Dt.tok L.z0)
      ∧ (Dt.ep L.epw0 = Dt.tok L.z0 ∧ ∀ w, w ≠ L.epw0 → Dt.ep w = 0) := by
  obtain ⟨hio, hsq, hdl, ha, hss, hdz, hbool, hls, hrs, hioo⟩ := hF
  obtain ⟨hA, hP⟩ := hB
  have hpairC : ∀ kc, IsByte (outcP1 Dt.toC kc) ∧ IsByte (outcP2 Dt.toC kc) := fun kc => hP (.inl kc)
  have hby : ∀ (j : Fin 12) i, InRange 8 (dLookB Dt.pl j (L.dlift (L.dpos i))) := fun j i =>
    isByte_inRange (dLook_byte Dt.toC hpairC j _)
  have hlb : ∀ (k j : Fin 3), InRange 8 (Dt.limb (L.lpos (slIdx k j) L.z0)) := fun k j =>
    isByte_inRange (hA (.inl _))
  have hc0 : ∀ i (j : Fin 3), dzcCB (toCPub P) Dt.toC (Dt.D L.z0) j (L.dlift (L.dpos i)) = 0 := hdz
  obtain ⟨hs1, hsz, hsd⟩ := rselRes_zero hrs
  refine ⟨out_sat_of_clauses P _ _
    { D := Dt.D L.z0
      Dsq := Dt.Dsq L.z0
      dl := fun j => Dt.limb (L.lpos (slIdx 0 j) L.z0)
      al := fun j => Dt.limb (L.lpos (slIdx 1 j) L.z0)
      bl := fun j => Dt.limb (L.lpos (slIdx 2 j) L.z0)
      xl0 := fun i => Dt.pl 1 (L.dlift (L.dpos i))
      xl1 := fun i => Dt.pl 2 (L.dlift (L.dpos i))
      y := fun i => Dt.pl 3 (L.dlift (L.dpos i))
      rho := fun i k => Dt.pl ⟨4 + k.val, by omega⟩ (L.dlift (L.dpos i))
      sig := fun i k => Dt.pl ⟨8 + k.val, by omega⟩ (L.dlift (L.dpos i))
      tzc_sq := hsq
      tzc_d := hdl
      tzc_a := ha
      host_ss := hss.trans (Finset.sum_congr rfl (fun i _ => by
        show Dt.pl 0 (L.dlift (L.dpos i)) * Dt.pl 0 (L.dlift (L.dpos i)) = Dt.bout (L.dpos i) * Dt.bout (L.dpos i)
        rw [hio]))
      c0 := fun i => by
        have h := hc0 i 0
        unfold dzcCB at h
        rw [ite_eq_left (by decide)] at h
        show Dt.bout (L.dpos i) * ((2 * P.g0 * P.cn : ℤ) : GF) + Dt.D L.z0 * 2 ^ P.tn
          - Dt.D L.z0 * 2 ^ (P.tn + 1) * Dt.pl 3 (L.dlift (L.dpos i))
          - limbSum (fun k : Fin 4 => Dt.pl ⟨4 + k.val, by omega⟩ (L.dlift (L.dpos i))) = 0
        rw [← hio (L.dpos i)]
        exact h
      c1 := fun i => by
        have h := hc0 i 1
        unfold dzcCB at h
        rw [ite_eq_right (by decide), ite_eq_left (by decide)] at h
        exact h
      c2 := fun i => by
        have h := hc0 i 2
        unfold dzcCB at h
        rw [ite_eq_right (by decide), ite_eq_right (by decide)] at h
        show Dt.bout (L.dpos i) + 32768 - Dt.pl 1 (L.dlift (L.dpos i)) - 2 ^ 8 * Dt.pl 2 (L.dlift (L.dpos i)) = 0
        rw [← hio (L.dpos i)]
        exact h
      b_dl := hlb 0
      b_al := hlb 1
      b_bl := hlb 2
      b_xl0 := fun i => by
        have h := hby 0 i
        rwa [dLookB_0] at h
      b_xl1 := fun i => by
        have h := hby 1 i
        rwa [dLookB_1] at h
      b_yp := fun i => by
        have h := hby 2 i
        rwa [dLookB_2] at h
      b_ym := fun i => by
        have h := hby 3 i
        rwa [dLookB_3] at h
      b_rho := fun i k => by
        have h := hby ⟨4 + k.val, by omega⟩ i
        rwa [dLookB_hi Dt.pl ⟨4 + k.val, by omega⟩ (by show 4 ≤ 4 + k.val; omega)] at h
      b_sig := fun i k => by
        have h := hby ⟨8 + k.val, by omega⟩ i
        rwa [dLookB_hi Dt.pl ⟨8 + k.val, by omega⟩ (by show 4 ≤ 8 + k.val; omega)] at h
      M := Dt.M L.z0
      e := fun z => Dt.e (L.vpos z)
      lam := fun z j => Dt.lam j (L.vpos z)
      bool := hbool
      host := fun z => by
        have h := congrFun hls (L.vpos z)
        rw [lheadB_pos] at h
        unfold lstarB at h
        rw [L.sV1, L.io_pos, one_mul] at h
        exact h
      sum1 := hs1
      sumz := hsz
      sumd := hsd
      b_lam := fun z j => isByte_inRange (lam_byte Dt hA hP j (L.vpos z)) }, ?_⟩
  exact out_endpoint_word L.epw0 Dt.ep (Dt.tok L.z0) L.uE L.uE_eq hioo

/-! ### Stage OUT's own slots' tables and relations -/

/-- `e`, the `λ_j`, `supp(V)`, `ι`, RSEL's `u0` in `K`; `M` and `tok` read at `To`'s entry 0 (`a_at(.., f0)`); `2^{−v}`;
HEAD's `y`; IO-out's endpoint and `u0`. -/
def vzE {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) : (Fin nv → Bool) → K := fun c => φ (Dt.e c)
def vzLam {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) : Fin l → (Fin nv → Bool) → K := fun k c => φ (Dt.lam k c)
def vzS (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : (Fin nv → Bool) → K := fun c => φ (L.sV c)
def vzIo (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : (Fin nv → Bool) → K := fun c => φ (L.io c)
def vzU (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : (Fin nv → Bool) → K := fun c => φ (L.uV c)
def vzM {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : K :=
  mleAt (fun z => φ (Dt.M z)) (bitv L.z0)
def vzTok {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : K :=
  mleAt (fun z => φ (Dt.tok z)) (bitv L.z0)
def vzIv : K := φ ((2 : GF) ^ P.vlog)⁻¹
def hdY {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) :
    (Fin nd → Bool) → K := fun c => φ (Dt.pl 3 (L.dlift c))
def ioE {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) : (Fin nep → Bool) → K := fun w => φ (Dt.ep w)
def ioU (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : (Fin nep → Bool) → K := fun w => φ (L.uE w)

/-- OUT-03 LZC's relation (standalone: its two clauses vanish on `Lo`). -/
def RelLZO {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) (α g : K)
    (hlo : (Fin nl → Bool) → K) : Prop :=
  LzcHolds (fun z => φ (Dt.limb z)) hlo L.sL α g

/-- HEAD and VZC's relation: the keyed values are the head values on `Vo`, VZC's clauses and pads vanish. -/
def RelHV (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) (α g : K)
    (hv : Fin (P.limbs / 2 + P.limbs % 2) → (Fin nv → Bool) → K) : Prop :=
  lstarB φ P Dt L = lheadB φ P Dt L ∧
    (∀ j, ∀ c : Fin nv → Bool, vzcW (vzE φ Dt) (vzLam φ Dt) hv α g j (bitv c) = 0) ∧
    ∀ i, ∀ c : Fin nv → Bool, vzcPz (vzS φ P L) (vzE φ Dt) (vzLam φ Dt) i (bitv c) = 0

/-- RSEL's relation: its three residues vanish. -/
def RelRS (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : Prop :=
  ∀ k, rselRes (fun z => vzE φ Dt (L.vpos z)) (fun z => φ (deltaB Dt.lam (L.vpos z))) (vzTok φ P Dt L) k = 0

/-- IO-out's relation on the endpoint's whole plane. -/
def RelIOO {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) : Prop :=
  ∀ w : Fin nep → Bool, iooR (ioE φ Dt) (ioU φ P L) (vzTok φ P Dt L) (bitv w) = 0

theorem vzM_eq {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) :
    vzM φ P Dt L = φ (Dt.M L.z0) := mleAt_bitv _ _

theorem vzTok_eq {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (L : OutLayout φ P n₀ nd ndo nl nv nt nep) :
    vzTok φ P Dt L = φ (Dt.tok L.z0) := mleAt_bitv _ _

theorem vzcDelta_cube {l : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep l) (c : Fin nv → Bool) :
    vzcDelta (vzLam φ Dt) (bitv c) = φ (deltaB Dt.lam c) := by
  simp only [vzcDelta, vzLam, mleAt_bitv, deltaB, map_sum, map_mul, map_pow, map_ofNat]

/-- **HEAD's sum is the head values' extension at `r_j`**: `Σ_b y(b)·W'(r_j, b) = l~(r_j)`. -/
theorem head_sum_eq [DecidableEq K] (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs)
    (L : OutLayout φ P n₀ nd ndo nl nv nt nep) (r : Fin nv → K) :
    ∑ b, hdY φ P Dt L b * L.Wp r b = mleAt (fun c => φ (lheadB φ P Dt L c)) r := by
  classical
  have h1 : ∑ b, hdY φ P Dt L b * L.Wp r b = ∑ i, hdY φ P Dt L (L.dpos i) * L.Wp r (L.dpos i) :=
    cube_sum_of_pad L.dpos L.dpos_inj (fun b => hdY φ P Dt L b * L.Wp r b) (fun b hb => by rw [L.Wp0 r b hb, mul_zero])
  have h2 : mleAt (fun c => φ (lheadB φ P Dt L c)) r
      = ∑ z, eqPoly r (bitv (L.vpos z)) * φ (lheadB φ P Dt L (L.vpos z)) := by
    unfold mleAt
    exact cube_sum_of_pad L.vpos L.vpos_inj (fun c => eqPoly r (fun i => bit (c i)) * φ (lheadB φ P Dt L c))
      (fun c hc => by rw [lheadB_off φ P Dt L c hc, map_zero, mul_zero])
  rw [h1, h2]
  simp only [L.Wp_pos, lheadB_pos, map_sum, map_mul, Finset.mul_sum, hdY]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl (fun z _ => Finset.sum_congr rfl (fun i _ => ?_))
  ring

/-- **VZC's hosted sum is the keyed values' extension at `r_j`**: `Σ_x eq(r_j, x)·l*~(x) = l*~(r_j)`. -/
theorem vzc_host_sum (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (r : Fin nv → K) :
    cubeSum (vzcHost r (vzS φ P L) (vzIo φ P L) (vzLam φ Dt) (vzM φ P Dt L) (vzTok φ P Dt L) (vzIv φ P))
      = mleAt (fun c => φ (lstarB φ P Dt L c)) r := by
  unfold vzcHost
  rw [cubeSum_eq_mul]
  congr 1
  funext c
  have hd : vzcDelta (vzLam φ Dt) (fun i => bit (c i)) = φ (deltaB Dt.lam c) := vzcDelta_cube φ Dt c
  simp only [mleAt_bit, vzS, vzIo, hd, vzM_eq, vzTok_eq, vzIv, lstarB, map_mul, map_add, map_sub]

/-- RSEL's residues in `K` are the base field's through `φ`. -/
theorem rselRes_map {V : ℕ} (e δ : Fin V → GF) (t : GF) (k : Fin 3) :
    φ (rselRes e δ t k) = rselRes (fun z => φ (e z)) (fun z => φ (δ z)) (φ t) k := by
  fin_cases k <;> simp [rselRes, map_sum, map_sub, map_mul, map_natCast]

/-- RSEL's cube sum (`rsel_cube_sum` at the layout). -/
theorem rsel_sum (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (c : Fin 3 → K) :
    cubeSum (rselF (vzS φ P L) (vzE φ Dt) (vzIo φ P L) (vzU φ P L) (vzLam φ Dt) (vzTok φ P Dt L) c)
      = ∑ k, c k * rselRes (fun z => vzE φ Dt (L.vpos z)) (fun z => φ (deltaB Dt.lam (L.vpos z)))
          (vzTok φ P Dt L) k := by
  classical
  have e1 : cubeSum (rselF (vzS φ P L) (vzE φ Dt) (vzIo φ P L) (vzU φ P L) (vzLam φ Dt) (vzTok φ P Dt L) c)
      = ∑ b, (vzS φ P L b * vzE φ Dt b * (c 0 + c 1 * vzIo φ P L b + c 2 * φ (deltaB Dt.lam b))
        - vzU φ P L b * (c 0 + c 1 * vzTok φ P Dt L)) := by
    unfold cubeSum
    refine Finset.sum_congr rfl (fun b _ => ?_)
    have hd : vzcDelta (vzLam φ Dt) (fun i => bit (b i)) = φ (deltaB Dt.lam b) := vzcDelta_cube φ Dt b
    simp only [rselF, mleAt_bit, hd]
  rw [e1]
  exact rsel_cube_sum L.vpos L.vpos_inj L.zv0 (vzS φ P L) (vzIo φ P L) (vzU φ P L) (vzE φ Dt)
    (fun b => φ (deltaB Dt.lam b)) (vzTok φ P Dt L) c (fun z => by simp [vzS, L.sV1])
    (fun b hb => by simp [vzS, L.sV0 b hb]) (fun z => by simp [vzIo, L.io_pos])
    (fun b => by simp only [vzU, L.uV_eq]; split_ifs <;> simp)

/-- `Σ_{k < l/2 + l%2} F k` splits into the pair helpers and (for odd `l`) the last single. -/
theorem sum_hv {M : Type} [AddCommMonoid M] (l : ℕ) (F : Fin (l / 2 + l % 2) → M) :
    ∑ k, F k = ∑ k : Fin (l / 2), F ⟨k.val, by omega⟩
      + ∑ j : Fin (l % 2), F ⟨l / 2, by have := j.isLt; omega⟩ := by
  rw [Fin.sum_univ_add]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => congrArg F (Fin.ext ?_))
  simp only [Fin.natAdd]
  have := j.isLt
  have : l % 2 ≤ 1 := by omega
  omega

/-- **The slots' relations on their cubes, the pads and the sum claims give the byte LogUp's relations at the logical
positions and `OutFacts`.** Stage OUT-C's facts lemma (`outcFacts_of_cube`, through `toCLay`, whose margin part is
vacuous) gives the shared facts. -/
theorem outCube [DecidableEq K] {nu : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs)
    (L : OutLayout φ P n₀ nd ndo nl nv nt nep) (gT : K → K) (ω₁ : K × K) (hd : OutHelpers K nl ndo nv nt nu P.limbs)
    (hio : RelIO φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (hss : RelSS φ (toCPub P) 0 Dt.toC (toCLay φ P L))
    (hlz : RelLZO φ P Dt L ω₁.2 (gT ω₁.1) hd.1)
    (hhv : RelHV φ P Dt L ω₁.2 (gT ω₁.1) hd.2.2.1)
    (hdz : RelDZC φ (toCPub P) 0 Dt.toC (toCLay φ P L) ω₁.2 (gT ω₁.1) hd.2.1)
    (hrs : RelRS φ P Dt L) (htb : RelTAB φ (toCPub P) 0 Dt.toC (toCLay φ P L) ω₁.2 (gT ω₁.1) hd.2.2.2.1)
    (hzs : ∑ j, hd.2.2.2.2 j = 0) (hioo : RelIOO φ P Dt L) (hsum : OutSum hd) :
    ByteLogUp φ (outA Dt) (outP1 Dt) (outP2 Dt) (outMult φ P Dt L) gT ω₁ (outHelpers φ P L hd)
      ∧ OutFacts φ P Dt L := by
  classical
  obtain ⟨hls, hvW, -⟩ := hhv
  obtain ⟨hdzW, -⟩ := hdz
  have hmar : ∑ c, pdY φ (toCPub P) 0 Dt.toC (toCLay φ P L) c * (toCLay φ P L).wd c
      = ∑ z, ((toCLay φ P L).Gm z * φ (Dt.toC.limb z) + (toCLay φ P L).uL z * kcK φ (toCPub P) 0) := by
    simp [toCLay, kcK, toCPub]
  obtain ⟨f1, f2, f3, f4, f5, f6, -⟩ :=
    outcFacts_of_cube φ (toCPub P) 0 Dt.toC (toCLay φ P L) ω₁.2 (gT ω₁.1) hd.2.1 hio hss hmar hdzW
  -- the byte table
  have htab : ∀ j : Fin 256, hd.2.2.2.1 (L.tpos j) * (ω₁.2 - byteTab (gT ω₁.1) j) = outMult φ P Dt L j := by
    intro j
    obtain ⟨e1, -, -⟩ := tzc_cube htb (L.tpos j)
    simp only [tabT, toCLay, OutData.toC] at e1
    rw [L.tv_pos] at e1
    exact sub_eq_zero.mp e1
  have htpad : ∀ c, c ∉ Set.range L.tpos → hd.2.2.2.1 c = 0 := by
    intro c hc
    obtain ⟨-, -, e5⟩ := tzc_cube htb c
    simp only [tabT, toCLay] at e5
    rw [L.sT0 c hc, sub_zero, one_mul] at e5
    exact e5
  refine ⟨⟨fun s => ?_, fun p => ?_, htab, ?_⟩, f1, f2, f3, f4, f5, f6, fun z => ?_, hls, fun k => ?_, fun w => ?_⟩
  · -- singles: LZC's helper on `Lo`; VZC's last (single) helper on `Vo` when `l` is odd
    rcases s with z | ⟨j, c⟩
    · have h := hlz .helper z
      simp only [lzcW, mleAt_bitv] at h
      show hd.1 z * (ω₁.2 - (φ (Dt.limb z) + gT ω₁.1)) = 1
      exact sub_eq_zero.mp h
    · have hj := j.isLt
      have h := hvW (.inr ⟨P.limbs / 2, by omega⟩) c
      simp only [vzcW, show ¬ (2 * (P.limbs / 2) + 1 < P.limbs) by omega, show 2 * (P.limbs / 2) < P.limbs by omega,
        ↓reduceDIte, vzcDen, vzLam, mleAt_bitv] at h
      have e : (⟨2 * (P.limbs / 2), by omega⟩ : Fin P.limbs) = ⟨P.limbs - 1, by omega⟩ :=
        Fin.ext (by show 2 * (P.limbs / 2) = P.limbs - 1; omega)
      rw [e] at h
      show hd.2.2.1 ⟨P.limbs / 2, by omega⟩ c * (ω₁.2 - (φ (Dt.lam ⟨P.limbs - 1, by omega⟩ c) + gT ω₁.1)) = 1
      exact sub_eq_zero.mp h
  · -- pairs: DZC's six helpers on `Do`; VZC's pair helpers on `Vo`
    rcases p with kc | ⟨k, c⟩
    · have h := hdzW (.inr kc.1) kc.2
      simp only [dzcW, mleAt_bitv, dzcDen_cube] at h
      show hd.2.1 kc.1 kc.2 * ((ω₁.2 - (φ (outcP1 Dt.toC kc) + gT ω₁.1)) * (ω₁.2 - (φ (outcP2 Dt.toC kc) + gT ω₁.1)))
        = (ω₁.2 - (φ (outcP1 Dt.toC kc) + gT ω₁.1)) + (ω₁.2 - (φ (outcP2 Dt.toC kc) + gT ω₁.1))
      simp only [outcP1, outcP2] at h ⊢
      linear_combination h
    · have hk := k.isLt
      have h := hvW (.inr ⟨k.val, by omega⟩) c
      simp only [vzcW, show 2 * k.val + 1 < P.limbs by omega, ↓reduceDIte, vzcDen, vzLam, mleAt_bitv] at h
      show hd.2.2.1 ⟨k.val, by omega⟩ c * ((ω₁.2 - (φ (Dt.lam ⟨2 * k.val, by omega⟩ c) + gT ω₁.1))
          * (ω₁.2 - (φ (Dt.lam ⟨2 * k.val + 1, by omega⟩ c) + gT ω₁.1)))
        = (ω₁.2 - (φ (Dt.lam ⟨2 * k.val, by omega⟩ c) + gT ω₁.1))
          + (ω₁.2 - (φ (Dt.lam ⟨2 * k.val + 1, by omega⟩ c) + gT ω₁.1))
      linear_combination h
  · -- the sum claim, the zero-sum row and the table's pad
    have hs := hsum
    unfold OutSum at hs
    rw [hzs, add_zero, cube_sum_of_pad L.tpos L.tpos_inj hd.2.2.2.1 htpad,
      sum_hv P.limbs (fun k => ∑ c, hd.2.2.1 k c)] at hs
    show ∑ s, (outHelpers φ P L hd).single s + ∑ p, (outHelpers φ P L hd).pair p - ∑ j, hd.2.2.2.1 (L.tpos j) = 0
    rw [Fintype.sum_sum_type, Fintype.sum_sum_type, Fintype.sum_prod_type, Fintype.sum_prod_type,
      Fintype.sum_prod_type]
    simp only [outHelpers]
    linear_combination hs
  · -- VZC's `e(1 − e)` at the vocabulary entries
    have h := hvW (.inl ()) (L.vpos z)
    simp only [vzcW, vzE, mleAt_bitv] at h
    refine φ.injective ?_
    rw [map_mul, map_sub, map_one, map_zero]
    exact h
  · -- RSEL's identities, in the base field
    refine φ.injective ?_
    rw [rselRes_map, map_zero, ← vzTok_eq]
    exact hrs k
  · -- IO-out's identity
    have h := hioo w
    simp only [iooR, ioE, ioU, mleAt_bitv, vzTok_eq] at h
    refine φ.injective ?_
    rw [map_sub, map_mul, map_zero]
    exact h

/-! ## The whole stage -/

/-- The six groups of the eleven slots' challenges after `H_out`, in the code's order and hosting: IO's `(τ, ρ)`; SS's
rounds and TZC's `(ζ, ((μ, ν), τ), ρ)`; LZC's `(μ, (τ, ρ))`; HEAD's `(r_j, ρ)`, DZC's and VZC's; RSEL's `(c, ρ)`; TAB's,
ZS's rounds and IO-out's `(τ, ρ)`. -/
abbrev OutG1 (K : Type) (nd : ℕ) := (Fin nd → K) × (Fin nd → K)
abbrev OutG2 (K : Type) (n₀ ndo : ℕ) :=
  (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) × (Fin n₀ → K)))
abbrev OutG3 (K : Type) (nl : ℕ) := (LzcClause → K) × ((Fin nl → K) × (Fin nl → K))
abbrev OutG4 (K : Type) (nd ndo nv l : ℕ) :=
  ((Fin nv → K) × (Fin nd → K)) × (ZcChal (Fin 3 ⊕ Fin 6) K ndo ×
    (K × ((((Option (Unit ⊕ Fin (l / 2 + l % 2)) → K) × K) × (Fin nv → K)) × (Fin nv → K))))
abbrev OutG5 (K : Type) (nv : ℕ) := (Fin 3 → K) × (Fin nv → K)
abbrev OutG6 (K : Type) (nt nu nep : ℕ) := ZcChal Unit K nt × ((Fin nu → K) × ((Fin nep → K) × (Fin nep → K)))

/-- The eleven slots' challenges after `H_out`. -/
abbrev OutChal2 (K : Type) (n₀ nd ndo nl nv nt nu nep l : ℕ) :=
  OutG1 K nd × (OutG2 K n₀ ndo × (OutG3 K nl × (OutG4 K nd ndo nv l × (OutG5 K nv × OutG6 K nt nu nep))))

instance instNonemptyOutChal2 {K' : Type} [Field K'] (n₀ nd ndo nl nv nt nu nep l : ℕ) :
    Nonempty (OutChal2 K' n₀ nd ndo nl nv nt nu nep l) :=
  haveI : Nonempty K' := ⟨0⟩
  inferInstance

/-! The challenge space and its tails are finite, stated group by group: the instance search on a whole tail exceeds
its size bound. -/

section Fin

variable {K' : Type} [Fintype K']

instance instFintypeOutG4 (nd ndo nv l : ℕ) : Fintype (OutG4 K' nd ndo nv l) :=
  let a : Fintype ((Fin nv → K') × (Fin nd → K')) := inferInstance
  let b : Fintype (ZcChal (Fin 3 ⊕ Fin 6) K' ndo) := inferInstance
  let c : Fintype (K' × ((((Option (Unit ⊕ Fin (l / 2 + l % 2)) → K') × K') × (Fin nv → K')) × (Fin nv → K'))) :=
    inferInstance
  @instFintypeProd _ _ a (@instFintypeProd _ _ b c)

instance instFintypeOutT5 (nv nt nu nep : ℕ) : Fintype (OutG5 K' nv × OutG6 K' nt nu nep) :=
  @instFintypeProd _ _ (inferInstanceAs (Fintype (OutG5 K' nv))) (inferInstanceAs (Fintype (OutG6 K' nt nu nep)))

instance instFintypeOutT4 (nd ndo nv nt nu nep l : ℕ) :
    Fintype (OutG4 K' nd ndo nv l × (OutG5 K' nv × OutG6 K' nt nu nep)) :=
  @instFintypeProd _ _ (instFintypeOutG4 nd ndo nv l) (instFintypeOutT5 nv nt nu nep)

instance instFintypeOutT3 (nd ndo nl nv nt nu nep l : ℕ) :
    Fintype (OutG3 K' nl × (OutG4 K' nd ndo nv l × (OutG5 K' nv × OutG6 K' nt nu nep))) :=
  @instFintypeProd _ _ (inferInstanceAs (Fintype (OutG3 K' nl))) (instFintypeOutT4 nd ndo nv nt nu nep l)

instance instFintypeOutT2 (n₀ nd ndo nl nv nt nu nep l : ℕ) :
    Fintype (OutG2 K' n₀ ndo × (OutG3 K' nl × (OutG4 K' nd ndo nv l × (OutG5 K' nv × OutG6 K' nt nu nep)))) :=
  @instFintypeProd _ _ (inferInstanceAs (Fintype (OutG2 K' n₀ ndo))) (instFintypeOutT3 nd ndo nl nv nt nu nep l)

instance instFintypeOutChal2 (n₀ nd ndo nl nv nt nu nep l : ℕ) :
    Fintype (OutChal2 K' n₀ nd ndo nl nv nt nu nep l) :=
  @instFintypeProd _ _ (inferInstanceAs (Fintype (OutG1 K' nd))) (instFintypeOutT2 n₀ nd ndo nl nv nt nu nep l)

end Fin

/-- **The provers** of stage OUT: each slot's published scalar and round messages, a function of everything drawn
before them. -/
structure OutProvers (K : Type) (n₀ nd ndo nl nv nt nu nep l : ℕ) where
  io : (Fin nd → K) → Prover K (1 + 1) nd
  ssS : (Fin nd → K) × (Fin nd → K) → K
  ss : (Fin nd → K) × (Fin nd → K) → Prover K 4 ndo
  tzc : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) → K → ((Option TzcClause → K) × K) × (Fin n₀ → K) →
    Prover K (2 + 1) n₀
  lzc : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) → (Fin nl → K) → Prover K (3 + 1) nl
  hdS : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) → (Fin nv → K) → K
  hd : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) → (Fin nv → K) → Prover K 2 nd
  dzc : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) → (Fin nv → K) × (Fin nd → K) →
    K → (Option (Fin 3 ⊕ Fin 6) → K) → (Fin ndo → K) → Prover K (4 + 1) ndo
  vzc : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) → (Fin nv → K) × (Fin nd → K) →
    ZcChal (Fin 3 ⊕ Fin 6) K ndo → K → ((Option (Unit ⊕ Fin (l / 2 + l % 2)) → K) × K) × (Fin nv → K) →
    Prover K (4 + 1) nv
  rsel : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) →
    ((Fin nv → K) × (Fin nd → K)) × (ZcChal (Fin 3 ⊕ Fin 6) K ndo ×
      (K × ((((Option (Unit ⊕ Fin (l / 2 + l % 2)) → K) × K) × (Fin nv → K)) × (Fin nv → K)))) →
    (Fin 3 → K) → Prover K 4 nv
  tab : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) →
    ((Fin nv → K) × (Fin nd → K)) × (ZcChal (Fin 3 ⊕ Fin 6) K ndo ×
      (K × ((((Option (Unit ⊕ Fin (l / 2 + l % 2)) → K) × K) × (Fin nv → K)) × (Fin nv → K)))) →
    (Fin 3 → K) × (Fin nv → K) → K → (Option Unit → K) → (Fin nt → K) → Prover K (2 + 1) nt
  zs : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) →
    ((Fin nv → K) × (Fin nd → K)) × (ZcChal (Fin 3 ⊕ Fin 6) K ndo ×
      (K × ((((Option (Unit ⊕ Fin (l / 2 + l % 2)) → K) × K) × (Fin nv → K)) × (Fin nv → K)))) →
    (Fin 3 → K) × (Fin nv → K) → ZcChal Unit K nt → Prover K 2 nu
  ioo : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) →
    ((Fin nv → K) × (Fin nd → K)) × (ZcChal (Fin 3 ⊕ Fin 6) K ndo ×
      (K × ((((Option (Unit ⊕ Fin (l / 2 + l % 2)) → K) × K) × (Fin nv → K)) × (Fin nv → K)))) →
    (Fin 3 → K) × (Fin nv → K) → ZcChal Unit K nt → (Fin nu → K) → (Fin nep → K) → Prover K (2 + 1) nep

/-- **Stage OUT's verifier accepts** after `(γ, α) = ω₁` and the committed helpers `hd`: the eleven slots and the `H`
opening's sum claim. -/
def OutAcc {nu : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs) (L : OutLayout φ P n₀ nd ndo nl nv nt nep)
    (gT : K → K) (ω₁ : K × K) (hd : OutHelpers K nl ndo nv nt nu P.limbs)
    (Pv : OutProvers K n₀ nd ndo nl nv nt nu nep P.limbs) (ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs) : Prop :=
  Accepts nd (fun x => eqPoly ω.1.1 x * ioR (ioX φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (ioB φ Dt.toC) x) 0
    (Pv.io ω.1.1) ω.1.2 ∧
  (Accepts ndo (ssF (toCLay φ P L).sD (fun c => φ (Dt.toC.pl 0 c))) (Pv.ssS ω.1) (Pv.ss ω.1) ω.2.1.1 ∧
    accHostPad (tzcCW (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L))) (tzcCPz (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)))
      (tzcCHost (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (cepsK φ (toCPub P))) (Pv.ssS ω.1)
      (Pv.tzc ω.1 ω.2.1.1) ω.2.1.2) ∧
  Accepts nl (fun x => eqPoly ω.2.2.1.2.1 x * batched (lzcW (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1))
      ω.2.2.1.1 x) 0 (Pv.lzc ω.1 ω.2.1 ω.2.2.1.1 ω.2.2.1.2.1) ω.2.2.1.2.2 ∧
  (Accepts nd (fun x => mleAt (hdY φ P Dt L) x * mleAt (L.Wp ω.2.2.2.1.1.1) x) (Pv.hdS ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1.1)
      (Pv.hd ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1.1) ω.2.2.2.1.1.2 ∧
    accZc (dzcW (plK φ Dt.toC) (toCLay φ P L).sD hd.2.1 (dzcD φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (knK φ (toCPub P))
        (kdvK φ (toCPub P)) (kdenK φ (toCPub P)) ω₁.2 (gT ω₁.1)) (dzcPz (plK φ Dt.toC) (toCLay φ P L).sD)
      (Pv.dzc ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1) ω.2.2.2.1.2.1 ∧
    accHostPad (vzcW (vzE φ Dt) (vzLam φ Dt) hd.2.2.1 ω₁.2 (gT ω₁.1)) (vzcPz (vzS φ P L) (vzE φ Dt) (vzLam φ Dt))
      (vzcHost ω.2.2.2.1.1.1 (vzS φ P L) (vzIo φ P L) (vzLam φ Dt) (vzM φ P Dt L) (vzTok φ P Dt L) (vzIv φ P))
      (Pv.hdS ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1.1) (Pv.vzc ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1 ω.2.2.2.1.2.1)
      ω.2.2.2.1.2.2) ∧
  Accepts nv (rselF (vzS φ P L) (vzE φ Dt) (vzIo φ P L) (vzU φ P L) (vzLam φ Dt) (vzTok φ P Dt L) ω.2.2.2.2.1.1) 0
    (Pv.rsel ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1.1) ω.2.2.2.2.1.2 ∧
  accZc (tzcW (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1) ω₁.2)
    (tzcPz (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1))
    (Pv.tab ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1) ω.2.2.2.2.2.1 ∧
  Accepts nu (fun x => mleAt (fun _ => (1 : K)) x * mleAt hd.2.2.2.2 x) 0
    (Pv.zs ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1 ω.2.2.2.2.2.1) ω.2.2.2.2.2.2.1 ∧
  Accepts nep (fun x => eqPoly ω.2.2.2.2.2.2.2.1 x * iooR (ioE φ Dt) (ioU φ P L) (vzTok φ P Dt L) x) 0
    (Pv.ioo ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1 ω.2.2.2.2.2.1 ω.2.2.2.2.2.2.1 ω.2.2.2.2.2.2.2.1)
    ω.2.2.2.2.2.2.2.2 ∧
  OutSum hd

/-- **The slots' error** of stage OUT (each slot's proved bound, without the code's extension round): IO, SS + TZC,
LZC, (HEAD + VZC with `r_j`'s step, and DZC), RSEL, TAB, ZS, IO-out. -/
noncomputable def outSlotsErr (K : Type) [Fintype K] (n₀ nd ndo nl nv nt nu nep l : ℕ) : ℝ≥0∞ :=
  ((nd + nd * (1 + 1) : ℕ) : ℝ≥0∞) / Fintype.card K
  + ((((ndo * 4 : ℕ) : ℝ≥0∞) / Fintype.card K
        + (((2 - 1) + (2 + (n₀ + n₀ * (2 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K)
  + (((1 + (nl + nl * (3 + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K
  + ((((nv : ℝ≥0∞) / Fintype.card K + (((nd * 2 : ℕ) : ℝ≥0∞) / Fintype.card K
          + ((((1 + l) - 1) + (2 + (nv + nv * (4 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K))
        + (((12 - 1) + (1 + (ndo + ndo * (4 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K)
  + (((1 : ℝ≥0∞) / Fintype.card K + ((nv * 4 : ℕ) : ℝ≥0∞) / Fintype.card K)
  + ((((2 - 1) + (1 + (nt + nt * (2 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K
  + (((nu * 2 : ℕ) : ℝ≥0∞) / Fintype.card K
  + ((nep + nep * (2 + 1) : ℕ) : ℝ≥0∞) / Fintype.card K))))))

/-- **Stage OUT, the whole stage, sound** (the interactive form). For data fixed before the challenges, fewer lookups
than the characteristic and `5 < char K`: over uniform `(γ, α)` and then the eleven slots' challenges, for ANY helpers
`h (γ, α)`, ANY published scalars and ANY sumcheck provers `Pv (γ, α)`, the stage accepts while `OutSat` on `B_out`'s
last row for the token word, or the output endpoint's identity, FAILS with probability at most the byte LogUp's
`(|ι| + 2·|π| + 2·256 − 1)/|K|` (`|ι| = 2^nl + (l mod 2)·2^nv`, `|π| = 6·2^ndo + ⌊l/2⌋·2^nv`) plus `outSlotsErr`. -/
theorem out_stage_sound [Fintype K] [DecidableEq K] {nu : ℕ} (Dt : OutData n₀ nd ndo nl nv nt nep P.limbs)
    (L : OutLayout φ P n₀ nd ndo nl nv nt nep) (gT : K → K) (hK : 4 + 1 < ringChar K)
    (hN : (2 ^ nl + P.limbs % 2 * 2 ^ nv) + 2 * (6 * 2 ^ ndo + P.limbs / 2 * 2 ^ nv) < ringChar K)
    (Pv : K × K → OutProvers K n₀ nd ndo nl nv nt nu nep P.limbs)
    (h : K × K → OutHelpers K nl ndo nv nt nu P.limbs) :
    pr (fun ω : (K × K) × OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        OutAcc φ P Dt L gT ω.1 (h ω.1) (Pv ω.1) ω.2 ∧
        ¬ (OutSat P (fun i => Dt.bout (L.dpos i)) (Dt.tok L.z0)
          ∧ (Dt.ep L.epw0 = Dt.tok L.z0 ∧ ∀ w, w ≠ L.epw0 → Dt.ep w = 0)))
      ≤ ((((2 ^ nl + P.limbs % 2 * 2 ^ nv) + 2 * (6 * 2 ^ ndo + P.limbs / 2 * 2 ^ nv)) + 2 * 256 - 1 : ℕ) : ℝ≥0∞)
          / Fintype.card K
        + outSlotsErr K n₀ nd ndo nl nv nt nu nep P.limbs := by
  classical
  have : Nonempty K := ⟨0⟩
  have hK2 : 1 + 1 < ringChar K := lt_trans (by norm_num) hK
  have hK3 : 2 + 1 < ringChar K := lt_trans (by norm_num) hK
  have hK4 : 3 + 1 < ringChar K := lt_trans (by norm_num) hK
  have hK4' : 4 < ringChar K := lt_trans (by norm_num) hK
  have hK2' : 2 < ringChar K := lt_trans (by norm_num) hK
  have hcard1 : Fintype.card ((Fin nl → Bool) ⊕ (Fin (P.limbs % 2) × (Fin nv → Bool))) = 2 ^ nl + P.limbs % 2 * 2 ^ nv := by
    simp [Fintype.card_sum, Fintype.card_prod]
  have hcard2 : Fintype.card ((Fin 6 × (Fin ndo → Bool)) ⊕ (Fin (P.limbs / 2) × (Fin nv → Bool)))
      = 6 * 2 ^ ndo + P.limbs / 2 * 2 ^ nv := by
    simp [Fintype.card_sum, Fintype.card_prod]
  have hN' : Fintype.card ((Fin nl → Bool) ⊕ (Fin (P.limbs % 2) × (Fin nv → Bool)))
      + 2 * Fintype.card ((Fin 6 × (Fin ndo → Bool)) ⊕ (Fin (P.limbs / 2) × (Fin nv → Bool))) < ringChar K := by
    rw [hcard1, hcard2]
    exact hN
  have hbyte := byte_logup_sound φ (outA Dt) (outP1 Dt) (outP2 Dt) (outMult φ P Dt L) gT hN'
  rw [hcard1, hcard2] at hbyte
  refine two_phase_sound (fun ω₁ hd => ByteLogUp φ (outA Dt) (outP1 Dt) (outP2 Dt) (outMult φ P Dt L) gT ω₁
      (outHelpers φ P L hd) ∧ OutFacts φ P Dt L)
    (OutSat P (fun i => Dt.bout (L.dpos i)) (Dt.tok L.z0) ∧ (Dt.ep L.epw0 = Dt.tok L.z0 ∧ ∀ w, w ≠ L.epw0 → Dt.ep w = 0))
    (fun ω₁ hd ω₂ => OutAcc φ P Dt L gT ω₁ hd (Pv ω₁) ω₂) h ?_ ?_
  · -- phase 1: the byte LogUp
    refine (pr_mono ?_).trans hbyte
    rintro ω₁ ⟨⟨hd, hrel, hF⟩, hg⟩
    exact ⟨⟨_, hrel⟩, fun hB => hg (out_of_facts φ P Dt L hB hF)⟩
  · -- phase 2: a relation failing is caught by a slot
    intro ω₁ hd hpre
    have hcase : ¬ RelIO φ (toCPub P) 0 Dt.toC (toCLay φ P L) ∨ ¬ RelSS φ (toCPub P) 0 Dt.toC (toCLay φ P L) ∨
        ¬ RelLZO φ P Dt L ω₁.2 (gT ω₁.1) hd.1 ∨ ¬ RelHV φ P Dt L ω₁.2 (gT ω₁.1) hd.2.2.1 ∨
        ¬ RelDZC φ (toCPub P) 0 Dt.toC (toCLay φ P L) ω₁.2 (gT ω₁.1) hd.2.1 ∨ ¬ RelRS φ P Dt L ∨
        ¬ RelTAB φ (toCPub P) 0 Dt.toC (toCLay φ P L) ω₁.2 (gT ω₁.1) hd.2.2.2.1 ∨ ¬ (∑ j, hd.2.2.2.2 j = 0) ∨
        ¬ RelIOO φ P Dt L ∨ ¬ OutSum hd := by
      by_contra hc
      push Not at hc
      obtain ⟨h1, h2, h3, h4, h5, h6, h7, h8, h9, h10⟩ := hc
      exact hpre (outCube φ P Dt L gT ω₁ hd h1 h2 h3 h4 h5 h6 h7 h8 h9 h10)
    unfold outSlotsErr
    rcases hcase with hc | hc | hc | hc | hc | hc | hc | hc | hc | hc
    · -- IO-in
      have hnz : ∃ c : Fin nd → Bool,
          ioR (ioX φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (ioB φ Dt.toC) (bitv c) ≠ 0 := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        Accepts nd (fun x => eqPoly ω.1.1 x * ioR (ioX φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (ioB φ Dt.toC) x) 0
          ((Pv ω₁).io ω.1.1) ω.1.2) (fun ω hω => hω.1)).trans ?_
      refine (pr_fst_le (fun ω : (Fin nd → K) × (Fin nd → K) =>
        Accepts nd (fun x => eqPoly ω.1 x * ioR (ioX φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (ioB φ Dt.toC) x) 0
          ((Pv ω₁).io ω.1) ω.2)).trans ?_
      exact (zerocheck_sound hK2 (ioR_deg _ _) hnz (Pv ω₁).io).trans le_self_add
    · -- SS / TZC
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        Accepts ndo (ssF (toCLay φ P L).sD (fun c => φ (Dt.toC.pl 0 c))) ((Pv ω₁).ssS ω.1) ((Pv ω₁).ss ω.1) ω.2.1.1 ∧
        accHostPad (tzcCW (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)))
          (tzcCPz (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)))
          (tzcCHost (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (cepsK φ (toCPub P)))
          ((Pv ω₁).ssS ω.1) ((Pv ω₁).tzc ω.1 ω.2.1.1) ω.2.1.2 ∧ ¬ RelSS φ (toCPub P) 0 Dt.toC (toCLay φ P L))
        (fun ω hω => ⟨hω.2.1.1, hω.2.1.2, hc⟩)).trans ?_
      refine (pr_prod_le _ (fun a => ?_)).trans (le_add_left le_self_add)
      refine (pr_fst_le (fun ω : (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
        (Fin n₀ → K))) =>
        Accepts ndo (ssF (toCLay φ P L).sD (fun c => φ (Dt.toC.pl 0 c))) ((Pv ω₁).ssS a) ((Pv ω₁).ss a) ω.1 ∧
        accHostPad (tzcCW (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)))
          (tzcCPz (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)))
          (tzcCHost (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (cepsK φ (toCPub P)))
          ((Pv ω₁).ssS a) ((Pv ω₁).tzc a ω.1) ω.2 ∧ ¬ RelSS φ (toCPub P) 0 Dt.toC (toCLay φ P L))).trans ?_
      exact priv_hostpad_sound hK4' hK3 (ssF (toCLay φ P L).sD (fun c => φ (Dt.toC.pl 0 c))) (ssF_deg _ _)
        ((Pv ω₁).ssS a) ((Pv ω₁).ss a) (tzcCW (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)))
        (tzcCPz (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L))) (tzcCW_deg _) (tzcCPz_deg _)
        (tzcCHost (tzcT φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (cepsK φ (toCPub P))) (tzcCHost_deg _ _)
        ((Pv ω₁).tzc a)
    · -- LZC (standalone)
      have hnz : ∃ j, ∃ c : Fin nl → Bool, lzcW (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1) j (bitv c) ≠ 0 := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        Accepts nl (fun x => eqPoly ω.2.2.1.2.1 x * batched (lzcW (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1))
          ω.2.2.1.1 x) 0 ((Pv ω₁).lzc ω.1 ω.2.1 ω.2.2.1.1 ω.2.2.1.2.1) ω.2.2.1.2.2)
        (fun ω hω => hω.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => ?_))).trans (le_add_left (le_add_left le_self_add))
      refine (pr_fst_le (fun ω : (LzcClause → K) × ((Fin nl → K) × (Fin nl → K)) =>
        Accepts nl (fun x => eqPoly ω.2.1 x * batched (lzcW (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1)) ω.1 x) 0
          ((Pv ω₁).lzc a a2 ω.1 ω.2.1) ω.2.2)).trans ?_
      exact zc_batched_sound hK4 _ (lzcW_deg _ _ _ _ _) hnz ((Pv ω₁).lzc a a2)
    · -- HEAD / VZC with `r_j`'s step
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        Accepts nd (fun x => mleAt (hdY φ P Dt L) x * mleAt (L.Wp ω.2.2.2.1.1.1) x)
          ((Pv ω₁).hdS ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1.1) ((Pv ω₁).hd ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1.1) ω.2.2.2.1.1.2 ∧
        accHostPad (vzcW (vzE φ Dt) (vzLam φ Dt) hd.2.2.1 ω₁.2 (gT ω₁.1)) (vzcPz (vzS φ P L) (vzE φ Dt) (vzLam φ Dt))
          (vzcHost ω.2.2.2.1.1.1 (vzS φ P L) (vzIo φ P L) (vzLam φ Dt) (vzM φ P Dt L) (vzTok φ P Dt L) (vzIv φ P))
          ((Pv ω₁).hdS ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1.1)
          ((Pv ω₁).vzc ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1 ω.2.2.2.1.2.1) ω.2.2.2.1.2.2 ∧
        ¬ RelHV φ P Dt L ω₁.2 (gT ω₁.1) hd.2.2.1)
        (fun ω hω => ⟨hω.2.2.2.1.1, hω.2.2.2.1.2.2, hc⟩)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => ?_)))).trans
        (le_add_left (le_add_left (le_add_left (le_self_add.trans le_self_add))))
      refine (pr_fst_le (fun ω : ((Fin nv → K) × (Fin nd → K)) × (ZcChal (Fin 3 ⊕ Fin 6) K ndo ×
          (K × ((((Option (Unit ⊕ Fin (P.limbs / 2 + P.limbs % 2)) → K) × K) × (Fin nv → K)) × (Fin nv → K)))) =>
        Accepts nd (fun x => mleAt (hdY φ P Dt L) x * mleAt (L.Wp ω.1.1) x)
          ((Pv ω₁).hdS a a2 a3 ω.1.1) ((Pv ω₁).hd a a2 a3 ω.1.1) ω.1.2 ∧
        accHostPad (vzcW (vzE φ Dt) (vzLam φ Dt) hd.2.2.1 ω₁.2 (gT ω₁.1)) (vzcPz (vzS φ P L) (vzE φ Dt) (vzLam φ Dt))
          (vzcHost ω.1.1 (vzS φ P L) (vzIo φ P L) (vzLam φ Dt) (vzM φ P Dt L) (vzTok φ P Dt L) (vzIv φ P))
          ((Pv ω₁).hdS a a2 a3 ω.1.1) ((Pv ω₁).vzc a a2 a3 ω.1 ω.2.1) ω.2.2 ∧
        ¬ RelHV φ P Dt L ω₁.2 (gT ω₁.1) hd.2.2.1)).trans ?_
      exact head_vzc_sound φ hK (hdY φ P Dt L) L.Wp (lstarB φ P Dt L) (lheadB φ P Dt L)
        (head_sum_eq φ P Dt L) (vzcW (vzE φ Dt) (vzLam φ Dt) hd.2.2.1 ω₁.2 (gT ω₁.1))
        (vzcPz (vzS φ P L) (vzE φ Dt) (vzLam φ Dt)) (vzcW_deg _ _ _ _ _) (vzcPz_deg _ _ _)
        (fun r => vzcHost r (vzS φ P L) (vzIo φ P L) (vzLam φ Dt) (vzM φ P Dt L) (vzTok φ P Dt L) (vzIv φ P))
        (fun r => vzcHost_deg _ _ _ _ _ _ _) (vzc_host_sum φ P Dt L) (fun r => (Pv ω₁).hdS a a2 a3 r)
        (fun r => (Pv ω₁).hd a a2 a3 r) (fun hc' md => (Pv ω₁).vzc a a2 a3 hc' md)
    · -- DZC
      have hnz : (∃ j, ∃ c : Fin ndo → Bool, dzcW (plK φ Dt.toC) (toCLay φ P L).sD hd.2.1
            (dzcD φ (toCPub P) 0 Dt.toC (toCLay φ P L)) (knK φ (toCPub P)) (kdvK φ (toCPub P)) (kdenK φ (toCPub P))
            ω₁.2 (gT ω₁.1) j (bitv c) ≠ 0)
          ∨ (∃ i, ∃ c : Fin ndo → Bool, dzcPz (plK φ Dt.toC) (toCLay φ P L).sD i (bitv c) ≠ 0) := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        accZc (dzcW (plK φ Dt.toC) (toCLay φ P L).sD hd.2.1 (dzcD φ (toCPub P) 0 Dt.toC (toCLay φ P L))
            (knK φ (toCPub P)) (kdvK φ (toCPub P)) (kdenK φ (toCPub P)) ω₁.2 (gT ω₁.1))
          (dzcPz (plK φ Dt.toC) (toCLay φ P L).sD) ((Pv ω₁).dzc ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1.1) ω.2.2.2.1.2.1)
        (fun ω hω => hω.2.2.2.1.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => ?_)))).trans
        (le_add_left (le_add_left (le_add_left (le_add_self.trans le_self_add))))
      refine (pr_fst_le (fun ω : ((Fin nv → K) × (Fin nd → K)) × (ZcChal (Fin 3 ⊕ Fin 6) K ndo ×
          (K × ((((Option (Unit ⊕ Fin (P.limbs / 2 + P.limbs % 2)) → K) × K) × (Fin nv → K)) × (Fin nv → K)))) =>
        accZc (dzcW (plK φ Dt.toC) (toCLay φ P L).sD hd.2.1 (dzcD φ (toCPub P) 0 Dt.toC (toCLay φ P L))
            (knK φ (toCPub P)) (kdvK φ (toCPub P)) (kdenK φ (toCPub P)) ω₁.2 (gT ω₁.1))
          (dzcPz (plK φ Dt.toC) (toCLay φ P L).sD) ((Pv ω₁).dzc a a2 a3 ω.1) ω.2.1)).trans ?_
      refine pr_prod_le _ (fun a4 => ?_)
      refine (pr_fst_le (fun ω : ZcChal (Fin 3 ⊕ Fin 6) K ndo =>
        accZc (dzcW (plK φ Dt.toC) (toCLay φ P L).sD hd.2.1 (dzcD φ (toCPub P) 0 Dt.toC (toCLay φ P L))
            (knK φ (toCPub P)) (kdvK φ (toCPub P)) (kdenK φ (toCPub P)) ω₁.2 (gT ω₁.1))
          (dzcPz (plK φ Dt.toC) (toCLay φ P L).sD) ((Pv ω₁).dzc a a2 a3 a4) ω)).trans ?_
      exact zc_pad_sound hK _ _ (dzcW_deg _ _ _ _ _ _ _ _ _) (dzcPz_deg _ _) hnz ((Pv ω₁).dzc a a2 a3 a4)
    · -- RSEL
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        Accepts nv (rselF (vzS φ P L) (vzE φ Dt) (vzIo φ P L) (vzU φ P L) (vzLam φ Dt) (vzTok φ P Dt L)
          ω.2.2.2.2.1.1) 0 ((Pv ω₁).rsel ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1.1) ω.2.2.2.2.1.2 ∧
        ¬ RelRS φ P Dt L) (fun ω hω => ⟨hω.2.2.2.2.1, hc⟩)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => pr_prod_le _
        (fun a4 => ?_))))).trans (le_add_left (le_add_left (le_add_left (le_add_left le_self_add))))
      refine (pr_fst_le (fun ω : (Fin 3 → K) × (Fin nv → K) =>
        Accepts nv (rselF (vzS φ P L) (vzE φ Dt) (vzIo φ P L) (vzU φ P L) (vzLam φ Dt) (vzTok φ P Dt L) ω.1) 0
          ((Pv ω₁).rsel a a2 a3 a4 ω.1) ω.2 ∧ ¬ RelRS φ P Dt L)).trans ?_
      exact rsel_sound hK4' _ (fun c => rselF_deg _ _ _ _ _ _ c) _ _ _ (rsel_sum φ P Dt L)
        ((Pv ω₁).rsel a a2 a3 a4)
    · -- TAB
      have hnz : (∃ j, ∃ c : Fin nt → Bool, tzcW (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1) ω₁.2 j
            (bitv c) ≠ 0)
          ∨ (∃ i, ∃ c : Fin nt → Bool, tzcPz (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1) i
            (bitv c) ≠ 0) := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        accZc (tzcW (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1) ω₁.2)
          (tzcPz (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1))
          ((Pv ω₁).tab ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1) ω.2.2.2.2.2.1)
        (fun ω hω => hω.2.2.2.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => pr_prod_le _
        (fun a4 => pr_prod_le _ (fun a5 => ?_)))))).trans
        (le_add_left (le_add_left (le_add_left (le_add_left (le_add_left le_self_add)))))
      refine (pr_fst_le (fun ω : ZcChal Unit K nt =>
        accZc (tzcW (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1) ω₁.2)
          (tzcPz (tabT φ (toCPub P) 0 Dt.toC (toCLay φ P L) (gT ω₁.1) hd.2.2.2.1))
          ((Pv ω₁).tab a a2 a3 a4 a5) ω)).trans ?_
      exact zc_pad_sound hK3 _ _ (tabW_deg _ _) (tabPz_deg _) hnz ((Pv ω₁).tab a a2 a3 a4 a5)
    · -- ZS
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        Accepts nu (fun x => mleAt (fun _ => (1 : K)) x * mleAt hd.2.2.2.2 x) 0
          ((Pv ω₁).zs ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1 ω.2.2.2.2.2.1) ω.2.2.2.2.2.2.1)
        (fun ω hω => hω.2.2.2.2.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => pr_prod_le _
        (fun a4 => pr_prod_le _ (fun a5 => pr_prod_le _ (fun a6 => ?_))))))).trans
        (le_add_left (le_add_left (le_add_left (le_add_left (le_add_left (le_add_left le_self_add))))))
      exact (pr_fst_le (fun ρ : Fin nu → K => Accepts nu (fun x => mleAt (fun _ => (1 : K)) x * mleAt hd.2.2.2.2 x) 0
        ((Pv ω₁).zs a a2 a3 a4 a5 a6) ρ)).trans (zs_sound hK2' hd.2.2.2.2 hc ((Pv ω₁).zs a a2 a3 a4 a5 a6))
    · -- IO-out
      have hnz : ∃ w : Fin nep → Bool, iooR (ioE φ Dt) (ioU φ P L) (vzTok φ P Dt L) (bitv w) ≠ 0 := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutChal2 K n₀ nd ndo nl nv nt nu nep P.limbs =>
        Accepts nep (fun x => eqPoly ω.2.2.2.2.2.2.2.1 x * iooR (ioE φ Dt) (ioU φ P L) (vzTok φ P Dt L) x) 0
          ((Pv ω₁).ioo ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1 ω.2.2.2.2.2.1 ω.2.2.2.2.2.2.1 ω.2.2.2.2.2.2.2.1)
          ω.2.2.2.2.2.2.2.2)
        (fun ω hω => hω.2.2.2.2.2.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => pr_prod_le _
        (fun a4 => pr_prod_le _ (fun a5 => pr_prod_le _ (fun a6 => pr_prod_le _ (fun a7 => ?_)))))))).trans
        (le_add_left (le_add_left (le_add_left (le_add_left (le_add_left (le_add_left le_add_self))))))
      exact zerocheck_sound hK3 (iooR_deg _ _ _) hnz ((Pv ω₁).ioo a a2 a3 a4 a5 a6 a7)
    · -- the sum claim fails: the `H` opening rejects
      exact pr_le_of_not _ (fun ω hω => hc hω.2.2.2.2.2.2.2.2) _

/-- **The numerator at the 8B shape** (`V_pad = 2^17`, every other stage domain `2^12`, `To` two entries, `l = 7` keyed
limbs, the output endpoint `2^8` words): the byte LogUp's `|ι| + 2|π| + 511 = 135,168 + 2·417,792 + 511 = 971,263`
and the slots' `36 + 55 + 61 + (152 + 84) + 69 + 50 + 24 + 32 = 563`, together `971,826 ≈ 2^19.89`. -/
theorem out_numerator_8B :
    (((2 ^ 12 + 7 % 2 * 2 ^ 17) + 2 * (6 * 2 ^ 12 + 7 / 2 * 2 ^ 17)) + 2 * 256 - 1)
      + ((12 + 12 * (1 + 1)) + ((12 * 4) + ((2 - 1) + (2 + (1 + 1 * (2 + 1))))) + (1 + (12 + 12 * (3 + 1)))
        + (17 + 12 * 2 + (((1 + 7) - 1) + (2 + (17 + 17 * (4 + 1)))) + ((12 - 1) + (1 + (12 + 12 * (4 + 1)))))
        + (1 + 17 * 4) + ((2 - 1) + (1 + (12 + 12 * (2 + 1)))) + 12 * 2 + (8 + 8 * (2 + 1))) = 971826
      ∧ 971826 < 2 ^ 20 := by
  norm_num

end Stage

end ZK60.StageX
