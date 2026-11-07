/-
D63, Lean lane L15 (2026-11-07): **stage OUT-C (the classifier's last stage) as ONE theorem**, the interactive form, as
`inc_stage_sound` (StageInExtractSlots.lean, lane L12) does for stage IN-C.

The code (hashline src/private_block/token_io/stage_out_c.rs, `verify` at :658, `define` at :283-429; the slot runner
`run_stage_slot`, token_io.rs:997-1135): after `A_out` and `M` the verifier draws `γ, α` (`g_u8 = γ·TAG_U8`), then
absorbs `H_out`, then runs eight slots, each `define`'s draws then a masked sumcheck:
* OUTC-00 IO-in (standalone, `main = d_bits`, degree 2): `eq(τ, ·)·(x − B_out(row, ·))`, ONE clause, no batching;
* OUTC-01 SS (private, `Do`, degree 4): `Σ supp·x·x`, published scalar `S_SS`;
* OUTC-02 TZC (host of SS, `To`, degree 3; draws `τ, μ[4], ν, ζ`): `dsq − d²`, `d − l3(dl)`, `2d − l3(a1) − l3(a2)`,
  the pad `(1 − u0)·(d + ζ·dsq)`, the host term `ν·u0·(dsq + l3(a1) − ceps)`, on the claim `ν·S_SS`;
* OUTC-03 PD (private, `d_bits`, degree 2): the margin `Σ y·w_Δ`, published scalar `S_PD`;
* OUTC-04 LZC (host of PD, `Lo`, degree 4; draws `τ, μ[2], ν`): L12's `margin_sound`;
* OUTC-05 DZC (standalone, `Do`, degree 5; draws `τ, μ[10], ζ`): the gated division clauses `g·c0`, `g·c1`, `g·c2`, six
  pair helpers `h·d1·d2 − (d1 + d2)` (not gated), the pad `(1 − g)·Σ_j ζ^j·plane_j` over the twelve `Do` planes;
* OUTC-06 TAB (standalone, `Tab`, degree 3; draws `τ, μ[2], ζ`): `h·(α − tv) − m`, the pad `(1 − s)·(m + ζ·h)`;
* OUTC-07 ZS (`Σ 1·u` on the claim 0, degree 2);
* then the `H` opening's value-0 LogUp sum claim (`logup_sum_claim`).

What is proved here (only `propext`, `Classical.choice`, `Quot.sound`):
* the slots' closures as the code writes them, on the committed tables' multilinear extensions: `ioR`, `ssF`,
  `tzcCW` / `tzcCPz` / `tzcCHost` (TZC), `dzcW` / `dzcPz` (DZC, with the code's lookup list `lookups_do`: `dLookPl`,
  `dLookCst`, `dLookCoef`), L12's `lzcW` / `lzcHost` (LZC) and `tzcW` / `tzcPz` (TAB is IN-C's SIC_TZC form); their
  individual degrees (each at most the code's declared round degree minus one: the eq factor);
* `priv_hostpad_sound`: a private slot hosted by a host slot WITH a pad (SS by TZC), as L12's `margin_sound` is for a
  host without one (PD by LZC);
* `outC_of_facts`: every looked value a byte (`AllBytes`) and the slots' facts at the logical positions
  (`OutCFacts`) give the stage relation `OutCSat` (CircuitOut.lean) on `B_out`'s verdict row;
* `outcCube`: the slots' relations on their cubes, the pads and the `H` sum claim give the byte LogUp's relations at the
  logical positions (`ByteLogUp`) and `OutCFacts`;
* **`outc_stage_sound`**: the WHOLE stage. Over `(γ, α)` and then the eight slots' challenges, for ANY helpers the
  prover commits in `H_out` after `(γ, α)`, ANY published scalars and ANY sumcheck provers (each a function of
  everything drawn before its messages), the stage accepts while `OutCSat` FAILS with probability at most the byte
  LogUp's `(|Lo| + 2·6·|Do| + 2·256 − 1)/|K|` plus the slots' terms (`outcSlotsErr`);
* `outc_numerator_shape`: at the classifier's R1 shape (every stage domain `2^12`, `To = 2`) the numerator is
  `54,094` (`2^15.72`): about `2^-112.3` over `|Fp2| ≈ 2^128` [ESTIMATE: the arithmetic of `p²`].

Modelling boundary (as for every slot lemma of L3 / L12): each slot's terminal values are the true tables' extensions
at its point (the openings, lane L10); the CFS mask and the extension round are `sumcheck_sound_masked` /
`sumcheck_sound_extended` (they leave the bound, or add one round of the declared degree); the masked scalars cancel by
`M`'s functionals (L12-4); Fiat–Shamir is `StageFS.lean` (L8's composition on the code's chain). The layout facts
(`OutCLayout`: where the public indicator tables are 1, the margin and table rows) are hypotheses: finite checks of a
registered profile, checked against the code by `StageCheckOutC.lean` on a real receipt.
-/
import ZK60Formal.StageOutCExtractSlots

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

/-! ## The slots' closures as the code writes them -/

/-- TZC's three clauses (stage_out_c.rs:331). -/
inductive TzcClause
  | sq
  | d
  | a
  deriving DecidableEq

instance : Fintype TzcClause :=
  ⟨{.sq, .d, .a}, fun x => by cases x <;> simp⟩

/-- The limb slice `3k + j` of TZC's nine (`i_l0 + 3k + j`, stage_out_c.rs:322-329). -/
def slIdx (k j : Fin 3) : Fin 9 := ⟨3 * k.val + j.val, by omega⟩

/-- The pair helper `k` of DZC covers the lookups `2k`, `2k + 1` (`helper_sum`, token_io.rs:1230-1246). -/
def pIdx1 (k : Fin 6) : Fin 12 := ⟨2 * k.val, by omega⟩

def pIdx2 (k : Fin 6) : Fin 12 := ⟨2 * k.val + 1, by omega⟩

/-- `lookups_do()` (stage_out_c.rs:124-129) over the twelve `Do` planes `X, XL0, XL1, Y, RHO0..3, SIG0..3` (`C_X ..`):
the plane each lookup reads, ... -/
def dLookPl (j : Fin 12) : Fin 12 :=
  if j.val = 0 then 1 else if j.val = 1 then 2 else if j.val ≤ 3 then 3 else j

/-- ... its constant (`y + 127`, `−y + 127`), ... -/
def dLookCst (j : Fin 12) : ℤ := if j.val = 2 ∨ j.val = 3 then 127 else 0

/-- ... and its coefficient. -/
def dLookCoef (j : Fin 12) : ℤ := if j.val = 3 then -1 else 1

section Clauses

variable {K : Type} [Field K]

/-- The isqrt limbs `k` recomposed on the extensions, `l3` (stage_out_c.rs:328). -/
structure TzcCTabs (K : Type) (n : ℕ) where
  D : (Fin n → Bool) → K
  Dsq : (Fin n → Bool) → K
  sl : Fin 9 → (Fin n → Bool) → K
  u0 : (Fin n → Bool) → K

def tzcL3 {n : ℕ} (T : TzcCTabs K n) (k : Fin 3) (x : Fin n → K) : K :=
  mleAt (T.sl (slIdx k 0)) x + 2 ^ 8 * mleAt (T.sl (slIdx k 1)) x + 2 ^ 16 * mleAt (T.sl (slIdx k 2)) x

/-- TZC's clauses (`zc`, stage_out_c.rs:331, without its pad). -/
def tzcCW {n : ℕ} (T : TzcCTabs K n) : TzcClause → (Fin n → K) → K
  | .sq => fun x => mleAt T.Dsq x - mleAt T.D x * mleAt T.D x
  | .d => fun x => mleAt T.D x - tzcL3 T 0 x
  | .a => fun x => 2 * mleAt T.D x - tzcL3 T 1 x - tzcL3 T 2 x

/-- TZC's pad planes, folded by `ζ` as `(1 − u0)·(d + ζ·dsq)` (stage_out_c.rs:330). -/
def tzcCPz {n : ℕ} (T : TzcCTabs K n) : Fin 2 → (Fin n → K) → K :=
  fun i x => (1 - mleAt T.u0 x) * (if (i : ℕ) = 0 then mleAt T.D x else mleAt T.Dsq x)

/-- TZC's host term `u0·(dsq + l3(a1) − ceps)` (stage_out_c.rs:332). -/
def tzcCHost {n : ℕ} (T : TzcCTabs K n) (ceps : K) (x : Fin n → K) : K :=
  mleAt T.u0 x * (mleAt T.Dsq x + tzcL3 T 1 x - ceps)

/-- OUTC-00's clause `x − B_out` (stage_out_c.rs:305). -/
def ioR {n : ℕ} (X B : (Fin n → Bool) → K) (x : Fin n → K) : K := mleAt X x - mleAt B x

/-- OUTC-01's private polynomial `supp·x·x` (stage_out_c.rs:310). -/
def ssF {n : ℕ} (s X : (Fin n → Bool) → K) (x : Fin n → K) : K := mleAt s x * mleAt X x * mleAt X x

/-- DZC's denominator of lookup `j`: `α − ((cst + g) + plane·coef)` (`resolve`, `helper_sum`). -/
def dzcDen {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (α g : K) (j : Fin 12) (x : Fin n → K) : K :=
  α - (((dLookCst j : ℤ) : K) + g + mleAt (pl (dLookPl j)) x * ((dLookCoef j : ℤ) : K))

/-- DZC's byte limbs recomposed, `lb(p0) = Σ_k 2^(8k)·plane_{p0+k}` (stage_out_c.rs:392). -/
def dzcLb {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (p0 : ℕ) (hp : p0 + 3 < 12) (x : Fin n → K) : K :=
  ∑ k : Fin 4, (2 : K) ^ (8 * k.val) * mleAt (pl ⟨p0 + k.val, by omega⟩) x

/-- DZC's three division clauses `c0`, `c1`, `c2` (stage_out_c.rs:396-398); `Dc` is `D` read at `To`'s entry 0. -/
def dzcC {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (Dc kn kdv kden : K) (j : Fin 3) (x : Fin n → K) : K :=
  if j.val = 0 then mleAt (pl 0) x * kn + Dc * kdv - Dc * kden * mleAt (pl 3) x - dzcLb pl 4 (by norm_num) x
  else if j.val = 1 then dzcLb pl 8 (by norm_num) x + dzcLb pl 4 (by norm_num) x + 1 - Dc * kden
  else mleAt (pl 0) x + 32768 - mleAt (pl 1) x - mleAt (pl 2) x * 256

/-- DZC's clauses: the three gated division clauses, then the six pair helpers (not gated). -/
def dzcW {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (s : (Fin n → Bool) → K) (H : Fin 6 → (Fin n → Bool) → K)
    (Dc kn kdv kden α g : K) : Fin 3 ⊕ Fin 6 → (Fin n → K) → K
  | .inl j => fun x => mleAt s x * dzcC pl Dc kn kdv kden j x
  | .inr k => fun x => mleAt (H k) x * dzcDen pl α g (pIdx1 k) x * dzcDen pl α g (pIdx2 k) x
      - (dzcDen pl α g (pIdx1 k) x + dzcDen pl α g (pIdx2 k) x)

/-- DZC's pad planes `(1 − g)·plane_i` (`zeta_fold` of the twelve planes, stage_out_c.rs:401). -/
def dzcPz {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (s : (Fin n → Bool) → K) : Fin 12 → (Fin n → K) → K :=
  fun i x => (1 - mleAt s x) * mleAt (pl i) x

/-! ### Degrees -/

theorem tzcL3_deg {n : ℕ} (T : TzcCTabs K n) (k : Fin 3) : IndDegLE 1 (tzcL3 T k) :=
  IndDegLE.add (IndDegLE.add (mle_deg _ le_rfl) (IndDegLE.cmul _ (mle_deg _ le_rfl)))
    (IndDegLE.cmul _ (mle_deg _ le_rfl))

theorem tzcCW_deg {n : ℕ} (T : TzcCTabs K n) : ∀ j, IndDegLE 2 (tzcCW T j)
  | .sq => by
      show IndDegLE 2 (fun x => mleAt T.Dsq x - mleAt T.D x * mleAt T.D x)
      exact IndDegLE.sub (mle_deg _ (by norm_num)) (IndDegLE.mono (IndDegLE.mul (mle_deg _ le_rfl)
        (mle_deg _ le_rfl)) (by norm_num))
  | .d => by
      show IndDegLE 2 (fun x => mleAt T.D x - tzcL3 T 0 x)
      exact IndDegLE.mono (IndDegLE.sub (mle_deg _ le_rfl) (tzcL3_deg T 0)) (by norm_num)
  | .a => by
      show IndDegLE 2 (fun x => 2 * mleAt T.D x - tzcL3 T 1 x - tzcL3 T 2 x)
      exact IndDegLE.mono (IndDegLE.sub (IndDegLE.sub (IndDegLE.cmul 2 (mle_deg _ le_rfl)) (tzcL3_deg T 1))
        (tzcL3_deg T 2)) (by norm_num)

/-- A pad plane `(1 − s)·a` has individual degree `≤ 2`. -/
theorem padPl_deg {n : ℕ} (s a : (Fin n → Bool) → K) {d : ℕ} (hd : 2 ≤ d) :
    IndDegLE d (fun x => (1 - mleAt s x) * mleAt a x) :=
  IndDegLE.mono (IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (mle_deg s le_rfl)) (mle_deg a le_rfl)) hd

/-- A two-plane pad `(1 − s)·(a + ζ·h)`'s planes have individual degree `≤ 2`. -/
theorem pad2_deg2 {n : ℕ} (s a h : (Fin n → Bool) → K) :
    ∀ i : Fin 2, IndDegLE 2 (fun x => (1 - mleAt s x) * (if (i : ℕ) = 0 then mleAt a x else mleAt h x)) := by
  intro i
  by_cases hi : (i : ℕ) = 0
  · simp only [hi, ↓reduceIte]
    exact padPl_deg s a le_rfl
  · simp only [hi, ↓reduceIte]
    exact padPl_deg s h le_rfl

theorem tzcCPz_deg {n : ℕ} (T : TzcCTabs K n) : ∀ i, IndDegLE 2 (tzcCPz T i) :=
  pad2_deg2 T.u0 T.D T.Dsq

theorem tzcCHost_deg {n : ℕ} (T : TzcCTabs K n) (ceps : K) : IndDegLE (2 + 1) (tzcCHost T ceps) :=
  IndDegLE.mono (IndDegLE.mul (mle_deg T.u0 le_rfl) (IndDegLE.sub (IndDegLE.add (mle_deg T.Dsq le_rfl)
    (tzcL3_deg T 1)) (IndDegLE.const ceps))) (by norm_num)

theorem ioR_deg {n : ℕ} (X B : (Fin n → Bool) → K) : IndDegLE 1 (ioR X B) :=
  IndDegLE.sub (mle_deg X le_rfl) (mle_deg B le_rfl)

theorem ssF_deg {n : ℕ} (s X : (Fin n → Bool) → K) : IndDegLE 4 (ssF s X) :=
  IndDegLE.mono (IndDegLE.mul (IndDegLE.mul (mle_deg s le_rfl) (mle_deg X le_rfl)) (mle_deg X le_rfl))
    (by norm_num)

/-- A table's extension times a constant on the right has individual degree `≤ 1`. -/
theorem mle_mulc_deg {n : ℕ} (T : (Fin n → Bool) → K) (c : K) : IndDegLE 1 (fun x => mleAt T x * c) :=
  IndDegLE.mono (IndDegLE.mul (mle_deg T le_rfl) (IndDegLE.const (d := 0) c)) (by norm_num)

theorem dzcDen_deg {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (α g : K) (j : Fin 12) :
    IndDegLE 1 (dzcDen pl α g j) := by
  show IndDegLE 1 (fun x => α - (((dLookCst j : ℤ) : K) + g + mleAt (pl (dLookPl j)) x * ((dLookCoef j : ℤ) : K)))
  exact IndDegLE.sub (IndDegLE.const α) (IndDegLE.add (IndDegLE.const _) (mle_mulc_deg _ _))

theorem dzcLb_deg {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (p0 : ℕ) (hp : p0 + 3 < 12) :
    IndDegLE 1 (dzcLb pl p0 hp) :=
  IndDegLE.wsum (fun k : Fin 4 => mle_deg (pl ⟨p0 + k.val, by omega⟩) (d := 1) le_rfl)
    (fun k : Fin 4 => (2 : K) ^ (8 * k.val))

theorem dzcC_deg {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (Dc kn kdv kden : K) (j : Fin 3) :
    IndDegLE 1 (dzcC pl Dc kn kdv kden j) := by
  by_cases h0 : j.val = 0
  · have e : dzcC pl Dc kn kdv kden j = fun x => mleAt (pl 0) x * kn + Dc * kdv - Dc * kden * mleAt (pl 3) x
        - dzcLb pl 4 (by norm_num) x := by
      funext x
      simp only [dzcC, h0, ↓reduceIte]
    rw [e]
    exact IndDegLE.sub (IndDegLE.sub (IndDegLE.add (mle_mulc_deg _ _) (IndDegLE.const _))
      (IndDegLE.cmul _ (mle_deg _ le_rfl))) (dzcLb_deg pl 4 (by norm_num))
  · by_cases h1 : j.val = 1
    · have e : dzcC pl Dc kn kdv kden j = fun x => dzcLb pl 8 (by norm_num) x + dzcLb pl 4 (by norm_num) x + 1
          - Dc * kden := by
        funext x
        simp only [dzcC, h1, one_ne_zero, ↓reduceIte]
      rw [e]
      exact IndDegLE.sub (IndDegLE.add (IndDegLE.add (dzcLb_deg pl 8 (by norm_num)) (dzcLb_deg pl 4 (by norm_num)))
        (IndDegLE.const 1)) (IndDegLE.const _)
    · have e : dzcC pl Dc kn kdv kden j = fun x => mleAt (pl 0) x + 32768 - mleAt (pl 1) x - mleAt (pl 2) x * 256 := by
        funext x
        simp only [dzcC, h0, h1, ↓reduceIte]
      rw [e]
      exact IndDegLE.sub (IndDegLE.sub (IndDegLE.add (mle_deg _ le_rfl) (IndDegLE.const _)) (mle_deg _ le_rfl))
        (mle_mulc_deg _ _)

theorem dzcW_deg {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (s : (Fin n → Bool) → K)
    (H : Fin 6 → (Fin n → Bool) → K) (Dc kn kdv kden α g : K) : ∀ j, IndDegLE 4 (dzcW pl s H Dc kn kdv kden α g j)
  | .inl j => by
      show IndDegLE 4 (fun x => mleAt s x * dzcC pl Dc kn kdv kden j x)
      exact IndDegLE.mono (IndDegLE.mul (mle_deg s le_rfl) (dzcC_deg pl Dc kn kdv kden j)) (by norm_num)
  | .inr k => by
      show IndDegLE 4 (fun x => mleAt (H k) x * dzcDen pl α g (pIdx1 k) x * dzcDen pl α g (pIdx2 k) x
        - (dzcDen pl α g (pIdx1 k) x + dzcDen pl α g (pIdx2 k) x))
      exact IndDegLE.sub (IndDegLE.mono (IndDegLE.mul (IndDegLE.mul (mle_deg (H k) le_rfl) (dzcDen_deg pl α g _))
        (dzcDen_deg pl α g _)) (by norm_num))
        (IndDegLE.mono (IndDegLE.add (dzcDen_deg pl α g _) (dzcDen_deg pl α g _)) (by norm_num))

theorem dzcPz_deg {n : ℕ} (pl : Fin 12 → (Fin n → Bool) → K) (s : (Fin n → Bool) → K) :
    ∀ i, IndDegLE 4 (dzcPz pl s i) := fun i => padPl_deg s (pl i) (by norm_num)

/-- TAB's relation (`tzcW`, IN-C's SIC_TZC form) has individual degree `≤ 2` (the code declares TAB's round degree 3). -/
theorem tabW_deg {n : ℕ} (T : TzcTabs K n) (α : K) : ∀ j, IndDegLE 2 (tzcW T α j) := fun _ =>
  IndDegLE.sub (IndDegLE.mono (IndDegLE.mul (mle_deg T.ht le_rfl)
    (IndDegLE.sub (IndDegLE.const α) (mle_deg T.tau le_rfl))) (by norm_num)) (mle_deg T.m (by norm_num))

theorem tabPz_deg {n : ℕ} (T : TzcTabs K n) : ∀ i, IndDegLE 2 (tzcPz T i) :=
  pad2_deg2 T.supp T.m T.ht

theorem ssF_sum {n : ℕ} (s X : (Fin n → Bool) → K) : cubeSum (ssF s X) = ∑ b, s b * X b * X b := by
  simp only [cubeSum, ssF, mleAt_bit]

theorem tzcCHost_sum {n : ℕ} (T : TzcCTabs K n) (ceps : K) :
    cubeSum (tzcCHost T ceps) = ∑ z, T.u0 z * (T.Dsq z + (T.sl (slIdx 1 0) z + 2 ^ 8 * T.sl (slIdx 1 1) z
      + 2 ^ 16 * T.sl (slIdx 1 2) z) - ceps) := by
  simp only [cubeSum, tzcCHost, tzcL3, mleAt_bit]

end Clauses

/-! ## The private slot hosted by a host with a pad (SS by TZC) -/

section Pair

variable {K : Type} [Field K]

/-- A host slot with a pad accepts (`host_pad_sound`'s event): its challenges `(ζ, ((μ, ν), τ), ρ)`. -/
def accHostPad {ι : Type} [Fintype ι] {n m d : ℕ} (W : ι → (Fin n → K) → K) (Pz : Fin m → (Fin n → K) → K)
    (Hs : (Fin n → K) → K) (S : K) (P : K → ((Option ι → K) × K) × (Fin n → K) → Prover K (d + 1) n)
    (ω : K × ((((Option ι → K) × K) × (Fin n → K)) × (Fin n → K))) : Prop :=
  Accepts n (fun x => eqPoly ω.2.1.2 x * batched (withPad W Pz ω.1) ω.2.1.1.1 x + ω.2.1.1.2 * Hs x)
    (ω.2.1.1.2 * S) (P ω.1 ω.2.1) ω.2.2

/-- **A private slot hosted by a host slot with a pad, sound** (OUTC-01 SS hosted by OUTC-02 TZC). For tables fixed
before both slots' challenges, ANY published scalar `S` and ANY provers (the host's may depend on the private slot's
rounds): the private slot accepts `S`, the host accepts `ν·S`, and yet the hosting identity `Σ Hs = Σ f` or a clause
or a pad plane of the host fails, with probability at most `np·dp/|K| + ((m − 1) + (2 + nh + nh·(dh + 1)))/|K|`. -/
theorem priv_hostpad_sound [Fintype K] [DecidableEq K] {ι : Type} [Fintype ι] [DecidableEq ι]
    {np nh dp dh m : ℕ} (hdp : dp < ringChar K) (hdh : dh + 1 < ringChar K)
    (f : (Fin np → K) → K) (hf : IndDegLE dp f) (S : K) (Pp : Prover K dp np)
    (W : ι → (Fin nh → K) → K) (Pz : Fin m → (Fin nh → K) → K) (hW : ∀ j, IndDegLE dh (W j))
    (hP : ∀ i, IndDegLE dh (Pz i)) (Hs : (Fin nh → K) → K) (hHs : IndDegLE (dh + 1) Hs)
    (Ph : (Fin np → K) → K → ((Option ι → K) × K) × (Fin nh → K) → Prover K (dh + 1) nh) :
    pr (fun ω : (Fin np → K) × (K × ((((Option ι → K) × K) × (Fin nh → K)) × (Fin nh → K))) =>
        Accepts np f S Pp ω.1 ∧ accHostPad W Pz Hs S (Ph ω.1) ω.2 ∧
        ¬ (cubeSum Hs = cubeSum f ∧ (∀ j, ∀ b : Fin nh → Bool, W j (bitv b) = 0) ∧
          ∀ i, ∀ b : Fin nh → Bool, Pz i (bitv b) = 0))
      ≤ ((np * dp : ℕ) : ℝ≥0∞) / Fintype.card K
        + (((m - 1) + (2 + (nh + nh * (dh + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  have hsub : ∀ ω : (Fin np → K) × (K × ((((Option ι → K) × K) × (Fin nh → K)) × (Fin nh → K))),
      (Accepts np f S Pp ω.1 ∧ accHostPad W Pz Hs S (Ph ω.1) ω.2 ∧
        ¬ (cubeSum Hs = cubeSum f ∧ (∀ j, ∀ b : Fin nh → Bool, W j (bitv b) = 0) ∧
          ∀ i, ∀ b : Fin nh → Bool, Pz i (bitv b) = 0)) →
      (Accepts np f S Pp ω.1 ∧ S ≠ cubeSum f) ∨
      (accHostPad W Pz Hs S (Ph ω.1) ω.2 ∧ ((∃ j, ∃ b : Fin nh → Bool, W j (bitv b) ≠ 0) ∨
        (∃ i, ∃ b : Fin nh → Bool, Pz i (bitv b) ≠ 0) ∨ cubeSum Hs ≠ S)) := by
    rintro ω ⟨hp, hh, hn⟩
    by_cases hS : S = cubeSum f
    · refine Or.inr ⟨hh, ?_⟩
      by_contra hc
      push Not at hc
      exact hn ⟨hc.2.2.trans hS, hc.1, hc.2.1⟩
    · exact Or.inl ⟨hp, hS⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans (add_le_add ?_ ?_))
  · refine (pr_fst_le (fun ρ => Accepts np f S Pp ρ ∧ S ≠ cubeSum f)).trans ?_
    by_cases hS : S = cubeSum f
    · exact pr_le_of_not _ (fun ρ hρ => hρ.2 hS) _
    · exact (pr_mono (E' := fun ρ => Accepts np f S Pp ρ) (fun ρ hρ => hρ.1)).trans (sumcheck_sound hdp hf hS Pp)
  · refine pr_prod_le _ (fun ρ => ?_)
    by_cases hb : (∃ j, ∃ b : Fin nh → Bool, W j (bitv b) ≠ 0) ∨ (∃ i, ∃ b : Fin nh → Bool, Pz i (bitv b) ≠ 0) ∨
        cubeSum Hs ≠ S
    · refine (pr_mono (E' := fun ω => accHostPad W Pz Hs S (Ph ρ) ω) (fun ω hω => hω.1)).trans ?_
      exact host_pad_sound hdh W Pz hW hP Hs hHs S hb (Ph ρ)
    · exact pr_le_of_not _ (fun ω hω => hb hω.2) _

end Pair

/-! ## The stage's data, layout, helpers, and the facts at the logical positions -/

section Stage

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out

variable {K : Type} [Field K]

/-- **What stage OUT-C commits on `A_out`** (the base field `GF`, stage_out_c.rs:210-252), and `B_out`'s verdict row:
the `To` planes `D`, `Dsq`; the limb plane on `Lo`; the twelve `Do` planes `X, XL0, XL1, Y, RHO0..3, SIG0..3`; the
byte histogram on `Tab`; and the boundary row `B_out(row, ·)` on the `d_pad` cube (the extracted plane). -/
structure OutCData (n₀ nd ndo nl nt : ℕ) where
  D : (Fin n₀ → Bool) → GF
  Dsq : (Fin n₀ → Bool) → GF
  limb : (Fin nl → Bool) → GF
  pl : Fin 12 → (Fin ndo → Bool) → GF
  mult : (Fin nt → Bool) → GF
  bout : (Fin nd → Bool) → GF

/-- **Stage OUT-C's public tables and layout map** (stage_out_c.rs:283-429): `To`'s entry 0 (`z0`); the nine isqrt
limb sub-planes (`lpos k z`: entry `2k + z` of `Lo`); the margin limbs (`mpos j`: entry `32 + j`); `Lo`'s entry 0
(`zl0`, LZC's `u0`); the `d_pad` cube in `Do` with the lift bits zero (`dlift`); the live channels (`dpos i`); the byte
table's live rows (`tpos j`); and the public tables: `u0` on `To`, `supp(d, do_n)` on `Do` (`sD`), the limb plane's live
selector (`sL`, LZC's pad: never needed below), `G` (`Gm`) and `u0` (`uL`) on `Lo`, the margin vector (`wd`), the table's
live selector (`sT`) and its values `tv(g) = (z mod 256) + g` (`tv`). -/
structure OutCLayout (φ : GF →+* K) {d : ℕ} (P : OutCPublic d) (b : ℕ) (n₀ nd ndo nl nt : ℕ) where
  z0 : Fin n₀ → Bool
  lpos : Fin 9 → (Fin n₀ → Bool) → (Fin nl → Bool)
  mpos : Fin P.limbs → (Fin nl → Bool)
  zl0 : Fin nl → Bool
  dlift : (Fin nd → Bool) → (Fin ndo → Bool)
  dpos : Fin d → (Fin nd → Bool)
  tpos : Fin 256 → (Fin nt → Bool)
  mpos_inj : Function.Injective mpos
  dpos_inj : Function.Injective dpos
  live_inj : Function.Injective (fun i => dlift (dpos i))
  tpos_inj : Function.Injective tpos
  u0 : (Fin n₀ → Bool) → K
  sD : (Fin ndo → Bool) → K
  sL : (Fin nl → Bool) → K
  Gm : (Fin nl → Bool) → K
  uL : (Fin nl → Bool) → K
  wd : (Fin nd → Bool) → K
  sT : (Fin nt → Bool) → K
  tv : K → (Fin nt → Bool) → K
  u0_eq : ∀ z, u0 z = if z = z0 then 1 else 0
  sD1 : ∀ i, sD (dlift (dpos i)) = 1
  sD0 : ∀ c, c ∉ Set.range (fun i => dlift (dpos i)) → sD c = 0
  Gm_pos : ∀ j, Gm (mpos j) = φ (sigOf b * (2 : GF) ^ (8 * (j : ℕ)))
  Gm0 : ∀ z, z ∉ Set.range mpos → Gm z = 0
  uL_eq : ∀ z, uL z = if z = zl0 then 1 else 0
  wd_pos : ∀ i, wd (dpos i) = φ (P.wΔ i : GF)
  wd0 : ∀ c, c ∉ Set.range dpos → wd c = 0
  sT1 : ∀ j, sT (tpos j) = 1
  sT0 : ∀ c, c ∉ Set.range tpos → sT c = 0
  tv_pos : ∀ g j, tv g (tpos j) = ((j : ℕ) : K) + g

/-- The helpers stage OUT-C commits in `H_out` after `(γ, α)`: `Lo`'s single helper, `Do`'s six pair helpers, the
byte table's helper, the zero-sum row. -/
abbrev OutCHelpers (K : Type) (nl ndo nt nu : ℕ) :=
  ((Fin nl → Bool) → K) × ((Fin 6 → (Fin ndo → Bool) → K) × (((Fin nt → Bool) → K) × ((Fin nu → Bool) → K)))

/-- The `H` opening's value-0 LogUp sum claim (`logup_sum_claim`, the signs `h_sign`: the table helper `−1`). -/
def OutCSum {nl ndo nt nu : ℕ} (hd : OutCHelpers K nl ndo nt nu) : Prop :=
  ∑ z, hd.1 z + ∑ k, ∑ c, hd.2.1 k c - ∑ c, hd.2.2.1 c + ∑ j, hd.2.2.2 j = 0

variable (φ : GF →+* K) {d n₀ nd ndo nl nt nu : ℕ} (P : OutCPublic d) (b : ℕ)

/-- The isqrt limbs `k` of the output row (`dl`, `al`, `bl` at `To`'s entry 0). -/
def tzcLimbs (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (k : Fin 3) : Fin 3 → GF :=
  fun j => Dt.limb (L.lpos (slIdx k j) L.z0)

/-- Live channel `i`'s word of plane `p` (`Do` at `dlift (dpos i)`). -/
def liveW (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (p : Fin 12) (i : Fin d) : GF :=
  Dt.pl p (L.dlift (L.dpos i))

/-- DZC's division clauses at a `Do` entry, in the base field (FNormClauses' `c0`, `c1`, `c2`). -/
def dzcCB (Dt : OutCData n₀ nd ndo nl nt) (Dz : GF) (j : Fin 3) (c : Fin ndo → Bool) : GF :=
  if j.val = 0 then Dt.pl 0 c * ((2 * P.g0 * P.cn : ℤ) : GF) + Dz * 2 ^ P.tn - Dz * 2 ^ (P.tn + 1) * Dt.pl 3 c
    - limbSum (fun k : Fin 4 => Dt.pl ⟨4 + k.val, by omega⟩ c)
  else if j.val = 1 then limbSum (fun k : Fin 4 => Dt.pl ⟨8 + k.val, by omega⟩ c)
    + limbSum (fun k : Fin 4 => Dt.pl ⟨4 + k.val, by omega⟩ c) + 1 - Dz * 2 ^ (P.tn + 1)
  else Dt.pl 0 c + 32768 - Dt.pl 1 c - 2 ^ 8 * Dt.pl 2 c

/-- **The facts the slots establish at the logical positions** (besides the byte lookups): OUTC-00's `x = B_out`;
TZC's three clauses at `To`'s entry 0 and its hosted sum of squares; DZC's three clauses at the live channels; LZC's
hosted margin. -/
def OutCFacts (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : Prop :=
  (∀ c, Dt.pl 0 (L.dlift c) = Dt.bout c) ∧
  Dt.Dsq L.z0 - Dt.D L.z0 * Dt.D L.z0 = 0 ∧
  Dt.D L.z0 - l3 (tzcLimbs φ P b Dt L 0) = 0 ∧
  2 * Dt.D L.z0 - l3 (tzcLimbs φ P b Dt L 1) - l3 (tzcLimbs φ P b Dt L 2) = 0 ∧
  Dt.Dsq L.z0 + l3 (tzcLimbs φ P b Dt L 1) - (P.ceps : GF) = ∑ i, liveW φ P b Dt L 0 i * liveW φ P b Dt L 0 i ∧
  (∀ i (j : Fin 3), dzcCB P Dt (Dt.D L.z0) j (L.dlift (L.dpos i)) = 0) ∧
  sigOf b * limbSum (fun j => Dt.limb (L.mpos j)) + ((b : GF) + (P.c : GF))
    = ∑ i, liveW φ P b Dt L 3 i * (P.wΔ i : GF)

/-- DZC's looked value `j` at a `Do` entry, in the base field. -/
def dLookB {n : ℕ} (Q : Fin 12 → (Fin n → Bool) → GF) (j : Fin 12) (c : Fin n → Bool) : GF :=
  ((dLookCst j : ℤ) : GF) + Q (dLookPl j) c * ((dLookCoef j : ℤ) : GF)

/-- The byte LogUp's pairs: DZC's six helpers at every `Do` entry, lookups `2k` and `2k + 1`. -/
def outcP1 (Dt : OutCData n₀ nd ndo nl nt) : Fin 6 × (Fin ndo → Bool) → GF := fun kc => dLookB Dt.pl (pIdx1 kc.1) kc.2

def outcP2 (Dt : OutCData n₀ nd ndo nl nt) : Fin 6 × (Fin ndo → Bool) → GF := fun kc => dLookB Dt.pl (pIdx2 kc.1) kc.2

/-- The byte table's multiplicities at its live rows. -/
def outcMult (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : Fin 256 → K :=
  fun j => φ (Dt.mult (L.tpos j))

/-- The logical helpers of `HelperRel` read off the committed helper planes. -/
def outcHelpers (L : OutCLayout φ P b n₀ nd ndo nl nt) (hd : OutCHelpers K nl ndo nt nu) :
    Helpers (Fin nl → Bool) (Fin 6 × (Fin ndo → Bool)) (Fin 256) K :=
  ⟨hd.1, fun kc => hd.2.1 kc.1 kc.2, fun j => hd.2.2.1 (L.tpos j)⟩

theorem dLookB_hi {n : ℕ} (Q : Fin 12 → (Fin n → Bool) → GF) (j : Fin 12) (hj : 4 ≤ j.val) (c : Fin n → Bool) :
    dLookB Q j c = Q j c := by
  have h1 : dLookPl j = j := by
    unfold dLookPl
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]
  have h2 : dLookCst j = 0 := by
    unfold dLookCst
    rw [ite_eq_right (by omega)]
  have h3 : dLookCoef j = 1 := by
    unfold dLookCoef
    rw [ite_eq_right (by omega)]
  simp [dLookB, h1, h2, h3]

theorem dLookB_0 {n : ℕ} (Q : Fin 12 → (Fin n → Bool) → GF) (c : Fin n → Bool) : dLookB Q 0 c = Q 1 c := by
  simp [dLookB, dLookPl, dLookCst, dLookCoef]

theorem dLookB_1 {n : ℕ} (Q : Fin 12 → (Fin n → Bool) → GF) (c : Fin n → Bool) : dLookB Q 1 c = Q 2 c := by
  simp [dLookB, dLookPl, dLookCst, dLookCoef]

theorem dLookB_2 {n : ℕ} (Q : Fin 12 → (Fin n → Bool) → GF) (c : Fin n → Bool) :
    dLookB Q 2 c = Q 3 c + 127 := by
  simp [dLookB, dLookPl, dLookCst, dLookCoef]
  ring

theorem dLookB_3 {n : ℕ} (Q : Fin 12 → (Fin n → Bool) → GF) (c : Fin n → Bool) :
    dLookB Q 3 c = -Q 3 c + 127 := by
  simp [dLookB, dLookPl, dLookCst, dLookCoef]
  ring

/-- Every one of DZC's twelve looked values is a byte once every pair's two lookups are. -/
theorem dLook_byte (Dt : OutCData n₀ nd ndo nl nt) (h : ∀ kc, IsByte (outcP1 Dt kc) ∧ IsByte (outcP2 Dt kc))
    (j : Fin 12) (c : Fin ndo → Bool) : IsByte (dLookB Dt.pl j c) := by
  have hk : j.val / 2 < 6 := by omega
  rcases Nat.even_or_odd j.val with he | ho
  · have e : pIdx1 ⟨j.val / 2, hk⟩ = j := by
      ext
      simp only [pIdx1]
      obtain ⟨r, hr⟩ := he
      omega
    have := (h (⟨j.val / 2, hk⟩, c)).1
    simpa [outcP1, e] using this
  · have e : pIdx2 ⟨j.val / 2, hk⟩ = j := by
      ext
      simp only [pIdx2]
      obtain ⟨r, hr⟩ := ho
      omega
    have := (h (⟨j.val / 2, hk⟩, c)).2
    simpa [outcP2, e] using this

/-- **Every looked value a byte and the facts at the logical positions give `OutCSat`** on `B_out`'s verdict row
(`outC_sat_of_clauses`, StageOutCExtract.lean). -/
theorem outC_of_facts (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt)
    (hB : AllBytes Dt.limb (outcP1 Dt) (outcP2 Dt)) (hF : OutCFacts φ P b Dt L) :
    OutCSat P (fun i => Dt.bout (L.dpos i)) b := by
  obtain ⟨hio, hsq, hdl, ha, hss, hdz, hpd⟩ := hF
  obtain ⟨hlimb, hpair⟩ := hB
  have hx : ∀ i, liveW φ P b Dt L 0 i = Dt.bout (L.dpos i) := fun i => hio (L.dpos i)
  have hby : ∀ (j : Fin 12) i, InRange 8 (dLookB Dt.pl j (L.dlift (L.dpos i))) := fun j i =>
    isByte_inRange (dLook_byte Dt hpair j _)
  have hlb : ∀ k j, InRange 8 (tzcLimbs φ P b Dt L k j) := fun k j => isByte_inRange (hlimb _)
  refine outC_sat_of_clauses P b _
    { D := Dt.D L.z0
      Dsq := Dt.Dsq L.z0
      dl := tzcLimbs φ P b Dt L 0
      al := tzcLimbs φ P b Dt L 1
      bl := tzcLimbs φ P b Dt L 2
      xl0 := liveW φ P b Dt L 1
      xl1 := liveW φ P b Dt L 2
      y := liveW φ P b Dt L 3
      rho := fun i k => Dt.pl ⟨4 + k.val, by omega⟩ (L.dlift (L.dpos i))
      sig := fun i k => Dt.pl ⟨8 + k.val, by omega⟩ (L.dlift (L.dpos i))
      tzc_sq := hsq
      tzc_d := hdl
      tzc_a := ha
      host_ss := by
        rw [hss]
        exact Finset.sum_congr rfl (fun i _ => by rw [hx])
      c0 := fun i => by
        have h := hdz i 0
        unfold dzcCB at h
        rw [ite_eq_left (by decide), hio (L.dpos i)] at h
        exact h
      c1 := fun i => by
        have h := hdz i 1
        unfold dzcCB at h
        rw [ite_eq_right (by decide), ite_eq_left (by decide)] at h
        exact h
      c2 := fun i => by
        have h := hdz i 2
        unfold dzcCB at h
        rw [ite_eq_right (by decide), ite_eq_right (by decide), hio (L.dpos i)] at h
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
      ml := fun j => Dt.limb (L.mpos j)
      host_pd := hpd
      b_ml := fun j => isByte_inRange (hlimb _) }

/-! ### The slots' tables at the committed data -/

/-- TZC's tables: `D`, `Dsq`, the nine limb slices of the limb plane, `u0`. -/
def tzcT (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : TzcCTabs K n₀ :=
  ⟨fun z => φ (Dt.D z), fun z => φ (Dt.Dsq z), fun k z => φ (Dt.limb (L.lpos k z)), L.u0⟩

/-- The `Do` planes in `K`. -/
def plK (Dt : OutCData n₀ nd ndo nl nt) : Fin 12 → (Fin ndo → Bool) → K := fun p c => φ (Dt.pl p c)

/-- OUTC-00's `x` (`X` read at its natural `d_pad`, the lift bits fixed) and `B_out`'s row. -/
def ioX (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : (Fin nd → Bool) → K :=
  fun c => φ (Dt.pl 0 (L.dlift c))

def ioB (Dt : OutCData n₀ nd ndo nl nt) : (Fin nd → Bool) → K := fun c => φ (Dt.bout c)

/-- OUTC-03's `y` (`Y` read at its natural `d_pad`). -/
def pdY (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : (Fin nd → Bool) → K :=
  fun c => φ (Dt.pl 3 (L.dlift c))

/-- The constants of the norm: `ceps`, `2·g0·Cn`, `2^tn`, `2^(tn+1)`, and LZC's `b + c`. -/
def cepsK : K := φ (P.ceps : GF)
def knK : K := φ ((2 * P.g0 * P.cn : ℤ) : GF)
def kdvK : K := φ ((2 : GF) ^ P.tn)
def kdenK : K := φ ((2 : GF) ^ (P.tn + 1))
def kcK : K := φ ((b : GF) + (P.c : GF))

/-- DZC's `D` read at `To`'s entry 0 (`a_at(C_D, f0)`). -/
def dzcD (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : K :=
  mleAt (fun z => φ (Dt.D z)) (bitv L.z0)

/-- TAB's tables (IN-C's SIC_TZC form): the multiplicities, the helper, the live selector, the values `tv(g)`. -/
def tabT (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (g : K) (ht : (Fin nt → Bool) → K) :
    TzcTabs K nt :=
  ⟨fun c => φ (Dt.mult c), ht, L.sT, L.tv g⟩

/-! ### The slots' relations on their cubes -/

def RelIO (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : Prop :=
  ∀ c : Fin nd → Bool, ioR (ioX φ P b Dt L) (ioB φ Dt) (bitv c) = 0

def RelSS (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) : Prop :=
  cubeSum (tzcCHost (tzcT φ P b Dt L) (cepsK φ P)) = cubeSum (ssF L.sD (fun c => φ (Dt.pl 0 c))) ∧
    (∀ j, ∀ c : Fin n₀ → Bool, tzcCW (tzcT φ P b Dt L) j (bitv c) = 0) ∧
    ∀ i, ∀ c : Fin n₀ → Bool, tzcCPz (tzcT φ P b Dt L) i (bitv c) = 0

def RelPD (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (α g : K)
    (hlo : (Fin nl → Bool) → K) : Prop :=
  (∑ c, pdY φ P b Dt L c * L.wd c = ∑ z, (L.Gm z * φ (Dt.limb z) + L.uL z * kcK φ P b)) ∧
    LzcHolds (fun z => φ (Dt.limb z)) hlo L.sL α g

def RelDZC (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (α g : K)
    (hdo : Fin 6 → (Fin ndo → Bool) → K) : Prop :=
  (∀ j, ∀ c : Fin ndo → Bool,
      dzcW (plK φ Dt) L.sD hdo (dzcD φ P b Dt L) (knK φ P) (kdvK φ P) (kdenK φ P) α g j (bitv c) = 0) ∧
    ∀ i, ∀ c : Fin ndo → Bool, dzcPz (plK φ Dt) L.sD i (bitv c) = 0

def RelTAB (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (α g : K)
    (ht : (Fin nt → Bool) → K) : Prop :=
  TzcHolds (tabT φ P b Dt L g ht) α

/-! ### Cube values -/

theorem tzcL3_cube (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (k : Fin 3)
    (z : Fin n₀ → Bool) :
    tzcL3 (tzcT φ P b Dt L) k (bitv z) = φ (l3 (fun j => Dt.limb (L.lpos (slIdx k j) z))) := by
  simp only [tzcL3, tzcT, mleAt_bitv, l3, map_add, map_mul, map_pow, map_ofNat]

theorem dzcLb_cube (Dt : OutCData n₀ nd ndo nl nt) (p0 : ℕ) (hp : p0 + 3 < 12) (c : Fin ndo → Bool) :
    dzcLb (plK φ Dt) p0 hp (bitv c) = φ (limbSum (fun k : Fin 4 => Dt.pl ⟨p0 + k.val, by omega⟩ c)) := by
  simp only [dzcLb, plK, mleAt_bitv, limbSum, map_sum, map_mul, map_pow, map_ofNat]

theorem dzcD_eq (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) :
    dzcD φ P b Dt L = φ (Dt.D L.z0) := mleAt_bitv _ _

theorem dzcC_cube (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (j : Fin 3)
    (c : Fin ndo → Bool) :
    dzcC (plK φ Dt) (dzcD φ P b Dt L) (knK φ P) (kdvK φ P) (kdenK φ P) j (bitv c)
      = φ (dzcCB P Dt (Dt.D L.z0) j c) := by
  rw [dzcD_eq]
  by_cases h0 : j.val = 0
  · simp only [dzcC, dzcCB, h0, ↓reduceIte, dzcLb_cube, knK, kdvK, kdenK, plK, mleAt_bitv, map_sub, map_add,
      map_mul]
  · by_cases h1 : j.val = 1
    · simp only [dzcC, dzcCB, h1, one_ne_zero, ↓reduceIte, dzcLb_cube, kdenK, map_sub, map_add, map_mul, map_one]
    · simp only [dzcC, dzcCB, h0, h1, ↓reduceIte, plK, mleAt_bitv, map_sub, map_add, map_mul, map_pow, map_ofNat]
      ring

theorem dzcDen_cube (Dt : OutCData n₀ nd ndo nl nt) (α g : K) (j : Fin 12) (c : Fin ndo → Bool) :
    dzcDen (plK φ Dt) α g j (bitv c) = α - (φ (dLookB Dt.pl j c) + g) := by
  simp only [dzcDen, plK, mleAt_bitv, dLookB, map_add, map_mul, map_intCast]
  ring

/-! ### The cube relations give the byte LogUp's relations and the facts -/

/-- **The facts at the logical positions from the slots' cube relations** (IO-in, TZC with its hosted sum, DZC at the
live channels, and the margin through `margin_host_pd`); the sum claim is not needed for them. -/
theorem outcFacts_of_cube (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (α g : K)
    (hdo : Fin 6 → (Fin ndo → Bool) → K) (hio : RelIO φ P b Dt L) (hss : RelSS φ P b Dt L)
    (hmar : ∑ c, pdY φ P b Dt L c * L.wd c = ∑ z, (L.Gm z * φ (Dt.limb z) + L.uL z * kcK φ P b))
    (hdzW : ∀ j, ∀ c : Fin ndo → Bool,
      dzcW (plK φ Dt) L.sD hdo (dzcD φ P b Dt L) (knK φ P) (kdvK φ P) (kdenK φ P) α g j (bitv c) = 0) :
    OutCFacts φ P b Dt L := by
  obtain ⟨hhost, hcl, -⟩ := hss
  have hz0 := fun (j : TzcClause) => hcl j L.z0
  refine ⟨fun c => ?_, ?_, ?_, ?_, ?_, fun i j => ?_, ?_⟩
  · have h := hio c
    simp only [ioR, ioX, ioB, mleAt_bitv] at h
    exact φ.injective (sub_eq_zero.mp h)
  · have h := hz0 .sq
    simp only [tzcCW, tzcT, mleAt_bitv] at h
    refine φ.injective ?_
    rw [map_sub, map_mul, map_zero]
    exact h
  · have h := hz0 .d
    simp only [tzcCW, tzcL3_cube] at h
    simp only [tzcT, mleAt_bitv] at h
    refine φ.injective ?_
    rw [map_sub, map_zero]
    exact h
  · have h := hz0 .a
    simp only [tzcCW, tzcL3_cube] at h
    simp only [tzcT, mleAt_bitv] at h
    refine φ.injective ?_
    rw [map_sub, map_sub, map_mul, map_ofNat, map_zero]
    exact h
  · -- the hosted sum of squares
    rw [tzcCHost_sum, ssF_sum] at hhost
    simp only [tzcT, L.u0_eq, ite_mul, one_mul, zero_mul, Finset.sum_ite_eq', Finset.mem_univ, ite_true] at hhost
    rw [cube_sum_of_pad (fun i => L.dlift (L.dpos i)) L.live_inj
      (fun c => L.sD c * φ (Dt.pl 0 c) * φ (Dt.pl 0 c)) (fun c hc => by rw [L.sD0 c hc, zero_mul, zero_mul])]
      at hhost
    simp only [L.sD1, one_mul] at hhost
    refine φ.injective ?_
    rw [map_sum]
    simp only [map_sub, map_add, map_mul, map_intCast, liveW, tzcLimbs, l3, map_pow, map_ofNat, cepsK] at hhost ⊢
    linear_combination hhost
  · -- DZC's clauses at the live channels
    have h := hdzW (.inl j) (L.dlift (L.dpos i))
    simp only [dzcW, mleAt_bitv, L.sD1, one_mul, dzcC_cube] at h
    exact φ.injective (by rw [h, map_zero])
  · -- the margin
    refine margin_host_pd φ b P.c (liveW φ P b Dt L 3) P.wΔ L.dpos L.dpos_inj (pdY φ P b Dt L) L.wd
      (fun i => rfl) L.wd_pos L.wd0 L.mpos L.mpos_inj L.zl0 L.Gm L.uL (fun z => φ (Dt.limb z))
      (fun j => Dt.limb (L.mpos j)) L.Gm_pos L.Gm0 L.uL_eq (fun j => rfl) hmar

/-- **The slots' relations on their cubes, the pads and the two sum claims give the byte LogUp's relations at the
logical positions and `OutCFacts`.** -/
theorem outcCube [DecidableEq K] (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt)
    (gT : K → K) (ω₁ : K × K) (hd : OutCHelpers K nl ndo nt nu)
    (hio : RelIO φ P b Dt L) (hss : RelSS φ P b Dt L) (hpd : RelPD φ P b Dt L ω₁.2 (gT ω₁.1) hd.1)
    (hdz : RelDZC φ P b Dt L ω₁.2 (gT ω₁.1) hd.2.1) (htb : RelTAB φ P b Dt L ω₁.2 (gT ω₁.1) hd.2.2.1)
    (hzs : ∑ j, hd.2.2.2 j = 0) (hsum : OutCSum hd) :
    ByteLogUp φ Dt.limb (outcP1 Dt) (outcP2 Dt) (outcMult φ P b Dt L) gT ω₁ (outcHelpers φ P b L hd)
      ∧ OutCFacts φ P b Dt L := by
  classical
  obtain ⟨hhost, hcl, hpz⟩ := hss
  obtain ⟨hmar, hlzc⟩ := hpd
  obtain ⟨hdzW, -⟩ := hdz
  -- the byte table: its relation at the live rows, zero helpers off them
  have htab : ∀ j : Fin 256, hd.2.2.1 (L.tpos j) * (ω₁.2 - byteTab (gT ω₁.1) j) = outcMult φ P b Dt L j := by
    intro j
    obtain ⟨e1, -, -⟩ := tzc_cube htb (L.tpos j)
    simp only [tabT] at e1
    rw [L.tv_pos] at e1
    exact sub_eq_zero.mp e1
  have htpad : ∀ c, c ∉ Set.range L.tpos → hd.2.2.1 c = 0 := by
    intro c hc
    obtain ⟨-, -, e5⟩ := tzc_cube htb c
    simp only [tabT] at e5
    rw [L.sT0 c hc, sub_zero, one_mul] at e5
    exact e5
  refine ⟨⟨fun z => ?_, fun kc => ?_, htab, ?_⟩, ?_⟩
  · -- singles: LZC's helper clause at every `Lo` entry
    have h := hlzc .helper z
    simp only [lzcW, mleAt_bitv] at h
    show hd.1 z * (ω₁.2 - (φ (Dt.limb z) + gT ω₁.1)) = 1
    exact sub_eq_zero.mp h
  · -- pairs: DZC's helper clause `k` at every `Do` entry
    have h := hdzW (.inr kc.1) kc.2
    simp only [dzcW, mleAt_bitv, dzcDen_cube] at h
    show hd.2.1 kc.1 kc.2 * ((ω₁.2 - (φ (outcP1 Dt kc) + gT ω₁.1)) * (ω₁.2 - (φ (outcP2 Dt kc) + gT ω₁.1)))
      = (ω₁.2 - (φ (outcP1 Dt kc) + gT ω₁.1)) + (ω₁.2 - (φ (outcP2 Dt kc) + gT ω₁.1))
    simp only [outcP1, outcP2]
    linear_combination h
  · -- the sum claim, the zero-sum row and the table's pad
    have hs := hsum
    unfold OutCSum at hs
    rw [hzs, add_zero, cube_sum_of_pad L.tpos L.tpos_inj hd.2.2.1 htpad] at hs
    show ∑ z, hd.1 z + ∑ kc : Fin 6 × (Fin ndo → Bool), hd.2.1 kc.1 kc.2 - ∑ j, hd.2.2.1 (L.tpos j) = 0
    rw [Fintype.sum_prod_type]
    exact hs
  · exact outcFacts_of_cube φ P b Dt L ω₁.2 (gT ω₁.1) hd.2.1 hio ⟨hhost, hcl, hpz⟩ hmar hdzW

/-! ## The whole stage -/

/-- The eight slots' challenges after `H_out`, grouped as the code's hosting pairs: IO's `(τ, ρ)`; SS's rounds and TZC's
`(ζ, ((μ, ν), τ), ρ)`; PD's rounds and LZC's `(((μ, ν), τ), ρ)`; DZC's `(ζ, μ, τ, ρ)`; TAB's; ZS's rounds. -/
abbrev OutCChal2 (K : Type) (n₀ nd ndo nl nt nu : ℕ) :=
  ((Fin nd → K) × (Fin nd → K)) ×
  (((Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) × (Fin n₀ → K)))) ×
  (((Fin nd → K) × ((((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K))) ×
  (ZcChal (Fin 3 ⊕ Fin 6) K ndo × (ZcChal Unit K nt × (Fin nu → K)))))

/-- The challenge space is nonempty (stated once: the instance search on the whole product is slow). -/
instance instNonemptyOutCChal2 {K' : Type} [Field K'] (n₀ nd ndo nl nt nu : ℕ) :
    Nonempty (OutCChal2 K' n₀ nd ndo nl nt nu) :=
  haveI : Nonempty K' := ⟨0⟩
  inferInstance

/-- **The provers**: each slot's published scalar and round messages, a function of everything drawn before them
(earlier slots' challenges; within its slot, its own draws and earlier rounds through `Prover`). -/
structure OutCProvers (K : Type) (n₀ nd ndo nl nt nu : ℕ) where
  io : (Fin nd → K) → Prover K (1 + 1) nd
  ssS : (Fin nd → K) × (Fin nd → K) → K
  ss : (Fin nd → K) × (Fin nd → K) → Prover K 4 ndo
  tzc : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) → K → ((Option TzcClause → K) × K) × (Fin n₀ → K) →
    Prover K (2 + 1) n₀
  pdS : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → K
  pd : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → Prover K 2 nd
  lzc : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (Fin nd → K) → ((LzcClause → K) × K) × (Fin nl → K) → Prover K (3 + 1) nl
  dzc : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (Fin nd → K) × ((((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K)) →
    K → (Option (Fin 3 ⊕ Fin 6) → K) → (Fin ndo → K) → Prover K (4 + 1) ndo
  tab : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (Fin nd → K) × ((((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K)) →
    ZcChal (Fin 3 ⊕ Fin 6) K ndo → K → (Option Unit → K) → (Fin nt → K) → Prover K (2 + 1) nt
  zs : (Fin nd → K) × (Fin nd → K) → (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
    (Fin n₀ → K))) → (Fin nd → K) × ((((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K)) →
    ZcChal (Fin 3 ⊕ Fin 6) K ndo → ZcChal Unit K nt → Prover K 2 nu

/-- A standalone zero-check with a pad accepts (`zc_pad_sound`'s event). -/
def accZc {ι : Type} [Fintype ι] {n m d : ℕ} (W : ι → (Fin n → K) → K) (Pz : Fin m → (Fin n → K) → K)
    (P : K → (Option ι → K) → (Fin n → K) → Prover K (d + 1) n) (ω : ZcChal ι K n) : Prop :=
  Accepts n (fun x => eqPoly ω.2.2.1 x * batched (withPad W Pz ω.1) ω.2.1 x) 0 (P ω.1 ω.2.1 ω.2.2.1) ω.2.2.2

/-- **Stage OUT-C's verifier accepts** after `(γ, α) = ω₁` and the committed helpers `hd`: the eight slots (each
`Accepts` its claim: `0`, the published scalar, or the host's `ν·scalar`) and the `H` opening's sum claim. -/
def OutCAcc (Dt : OutCData n₀ nd ndo nl nt) (L : OutCLayout φ P b n₀ nd ndo nl nt) (gT : K → K)
    (ω₁ : K × K) (hd : OutCHelpers K nl ndo nt nu) (Pv : OutCProvers K n₀ nd ndo nl nt nu)
    (ω : OutCChal2 K n₀ nd ndo nl nt nu) : Prop :=
  Accepts nd (fun x => eqPoly ω.1.1 x * ioR (ioX φ P b Dt L) (ioB φ Dt) x) 0 (Pv.io ω.1.1) ω.1.2 ∧
  (Accepts ndo (ssF L.sD (fun c => φ (Dt.pl 0 c))) (Pv.ssS ω.1) (Pv.ss ω.1) ω.2.1.1 ∧
    accHostPad (tzcCW (tzcT φ P b Dt L)) (tzcCPz (tzcT φ P b Dt L)) (tzcCHost (tzcT φ P b Dt L) (cepsK φ P))
      (Pv.ssS ω.1) (Pv.tzc ω.1 ω.2.1.1) ω.2.1.2) ∧
  (Accepts nd (fun x => mleAt (pdY φ P b Dt L) x * mleAt L.wd x) (Pv.pdS ω.1 ω.2.1) (Pv.pd ω.1 ω.2.1) ω.2.2.1.1 ∧
    Accepts nl (fun x => eqPoly ω.2.2.1.2.1.2 x * batched (lzcW (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1))
        ω.2.2.1.2.1.1.1 x + ω.2.2.1.2.1.1.2 * lzcHost L.Gm L.uL (fun z => φ (Dt.limb z)) (kcK φ P b) x)
      (ω.2.2.1.2.1.1.2 * Pv.pdS ω.1 ω.2.1) (Pv.lzc ω.1 ω.2.1 ω.2.2.1.1 ω.2.2.1.2.1) ω.2.2.1.2.2) ∧
  accZc (dzcW (plK φ Dt) L.sD hd.2.1 (dzcD φ P b Dt L) (knK φ P) (kdvK φ P) (kdenK φ P) ω₁.2 (gT ω₁.1))
    (dzcPz (plK φ Dt) L.sD) (Pv.dzc ω.1 ω.2.1 ω.2.2.1) ω.2.2.2.1 ∧
  accZc (tzcW (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1) ω₁.2) (tzcPz (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1))
    (Pv.tab ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1) ω.2.2.2.2.1 ∧
  Accepts nu (fun x => mleAt (fun _ => (1 : K)) x * mleAt hd.2.2.2 x) 0
    (Pv.zs ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1) ω.2.2.2.2.2 ∧
  OutCSum hd

/-- **The slots' error** (each slot's proved bound, without the code's extension round): IO `(nd + 2nd)`, SS and TZC
`4ndo + ((2 − 1) + (2 + n₀ + 3n₀))`, PD and LZC `2nd + (2 + nl + 4nl)`, DZC `(12 − 1) + (1 + ndo + 5ndo)`, TAB
`(2 − 1) + (1 + nt + 3nt)`, ZS `2nu`, each over `|K|`. -/
noncomputable def outcSlotsErr (K : Type) [Fintype K] (n₀ nd ndo nl nt nu : ℕ) : ℝ≥0∞ :=
  ((nd + nd * (1 + 1) : ℕ) : ℝ≥0∞) / Fintype.card K +
    ((((ndo * 4 : ℕ) : ℝ≥0∞) / Fintype.card K + (((2 - 1) + (2 + (n₀ + n₀ * (2 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K) +
      ((((nd * 2 : ℕ) : ℝ≥0∞) / Fintype.card K + ((2 + (nl + nl * (3 + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K) +
        ((((12 - 1) + (1 + (ndo + ndo * (4 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K +
          ((((2 - 1) + (1 + (nt + nt * (2 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K +
            ((nu * 2 : ℕ) : ℝ≥0∞) / Fintype.card K))))

/-- **Stage OUT-C, the whole stage, sound** (the interactive form). For data fixed before the challenges (the code
commits `A_out` and `M`, and `B_out` is block `L − 1`'s, before `γ, α`), fewer lookups than the characteristic and
`5 < char K`: over uniform `(γ, α)` and then the eight slots' challenges, for ANY helpers `h (γ, α)` the prover commits
in `H_out`, ANY published scalars and ANY sumcheck provers `Pv (γ, α)`, the stage accepts while the stage relation
`OutCSat` FAILS on `B_out`'s verdict row with probability at most the byte LogUp's `(2^nl + 2·(6·2^ndo) + 2·256 − 1)/|K|`
plus the slots' `outcSlotsErr`. -/
theorem outc_stage_sound [Fintype K] [DecidableEq K] (Dt : OutCData n₀ nd ndo nl nt)
    (L : OutCLayout φ P b n₀ nd ndo nl nt) (gT : K → K) (hK : 4 + 1 < ringChar K)
    (hN : 2 ^ nl + 2 * (6 * 2 ^ ndo) < ringChar K)
    (Pv : K × K → OutCProvers K n₀ nd ndo nl nt nu) (h : K × K → OutCHelpers K nl ndo nt nu) :
    pr (fun ω : (K × K) × OutCChal2 K n₀ nd ndo nl nt nu =>
        OutCAcc φ P b Dt L gT ω.1 (h ω.1) (Pv ω.1) ω.2 ∧ ¬ OutCSat P (fun i => Dt.bout (L.dpos i)) b)
      ≤ ((2 ^ nl + 2 * (6 * 2 ^ ndo) + 2 * 256 - 1 : ℕ) : ℝ≥0∞) / Fintype.card K
        + outcSlotsErr K n₀ nd ndo nl nt nu := by
  classical
  have : Nonempty K := ⟨0⟩
  have hK2 : 1 + 1 < ringChar K := lt_trans (by norm_num) hK
  have hK3 : 2 + 1 < ringChar K := lt_trans (by norm_num) hK
  have hK4 : 3 + 1 < ringChar K := lt_trans (by norm_num) hK
  have hK4' : 4 < ringChar K := lt_trans (by norm_num) hK
  have hK2' : 2 < ringChar K := lt_trans (by norm_num) hK
  have hcard1 : Fintype.card (Fin nl → Bool) = 2 ^ nl := by simp
  have hcard2 : Fintype.card (Fin 6 × (Fin ndo → Bool)) = 6 * 2 ^ ndo := by simp
  have hN' : Fintype.card (Fin nl → Bool) + 2 * Fintype.card (Fin 6 × (Fin ndo → Bool)) < ringChar K := by
    rw [hcard1, hcard2]
    exact hN
  have hbyte := byte_logup_sound φ Dt.limb (outcP1 Dt) (outcP2 Dt) (outcMult φ P b Dt L) gT hN'
  rw [hcard1, hcard2] at hbyte
  refine two_phase_sound (fun ω₁ hd => ByteLogUp φ Dt.limb (outcP1 Dt) (outcP2 Dt) (outcMult φ P b Dt L) gT ω₁
      (outcHelpers φ P b L hd) ∧ OutCFacts φ P b Dt L) (OutCSat P (fun i => Dt.bout (L.dpos i)) b)
    (fun ω₁ hd ω₂ => OutCAcc φ P b Dt L gT ω₁ hd (Pv ω₁) ω₂) h ?_ ?_
  · -- phase 1: the byte LogUp
    refine (pr_mono ?_).trans hbyte
    rintro ω₁ ⟨⟨hd, hrel, hF⟩, hg⟩
    exact ⟨⟨_, hrel⟩, fun hB => hg (outC_of_facts φ P b Dt L hB hF)⟩
  · -- phase 2: helpers failing the relations, or a fact failing, are caught by a slot
    intro ω₁ hd hpre
    have hcase : ¬ RelIO φ P b Dt L ∨ ¬ RelSS φ P b Dt L ∨ ¬ RelPD φ P b Dt L ω₁.2 (gT ω₁.1) hd.1 ∨
        ¬ RelDZC φ P b Dt L ω₁.2 (gT ω₁.1) hd.2.1 ∨ ¬ RelTAB φ P b Dt L ω₁.2 (gT ω₁.1) hd.2.2.1 ∨
        ¬ (∑ j, hd.2.2.2 j = 0) ∨ ¬ OutCSum hd := by
      by_contra hc
      push Not at hc
      obtain ⟨h1, h2, h3, h4, h5, h6, h7⟩ := hc
      exact hpre (outcCube φ P b Dt L gT ω₁ hd h1 h2 h3 h4 h5 h6 h7)
    unfold outcSlotsErr
    rcases hcase with hc | hc | hc | hc | hc | hc | hc
    · -- OUTC-00 IO catches it
      have hnz : ∃ c : Fin nd → Bool, ioR (ioX φ P b Dt L) (ioB φ Dt) (bitv c) ≠ 0 := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutCChal2 K n₀ nd ndo nl nt nu =>
        Accepts nd (fun x => eqPoly ω.1.1 x * ioR (ioX φ P b Dt L) (ioB φ Dt) x) 0 ((Pv ω₁).io ω.1.1) ω.1.2)
        (fun ω hω => hω.1)).trans ?_
      refine (pr_fst_le (fun ω : (Fin nd → K) × (Fin nd → K) =>
        Accepts nd (fun x => eqPoly ω.1 x * ioR (ioX φ P b Dt L) (ioB φ Dt) x) 0 ((Pv ω₁).io ω.1) ω.2)).trans ?_
      exact (zerocheck_sound hK2 (ioR_deg _ _) hnz (Pv ω₁).io).trans le_self_add
    · -- OUTC-01 SS / OUTC-02 TZC catch it
      refine (pr_mono (E' := fun ω : OutCChal2 K n₀ nd ndo nl nt nu =>
        Accepts ndo (ssF L.sD (fun c => φ (Dt.pl 0 c))) ((Pv ω₁).ssS ω.1) ((Pv ω₁).ss ω.1) ω.2.1.1 ∧
        accHostPad (tzcCW (tzcT φ P b Dt L)) (tzcCPz (tzcT φ P b Dt L)) (tzcCHost (tzcT φ P b Dt L) (cepsK φ P))
          ((Pv ω₁).ssS ω.1) ((Pv ω₁).tzc ω.1 ω.2.1.1) ω.2.1.2 ∧ ¬ RelSS φ P b Dt L)
        (fun ω hω => ⟨hω.2.1.1, hω.2.1.2, hc⟩)).trans ?_
      refine (pr_prod_le _ (fun a => ?_)).trans (le_add_left le_self_add)
      refine (pr_fst_le (fun ω : (Fin ndo → K) × (K × ((((Option TzcClause → K) × K) × (Fin n₀ → K)) ×
        (Fin n₀ → K))) =>
        Accepts ndo (ssF L.sD (fun c => φ (Dt.pl 0 c))) ((Pv ω₁).ssS a) ((Pv ω₁).ss a) ω.1 ∧
        accHostPad (tzcCW (tzcT φ P b Dt L)) (tzcCPz (tzcT φ P b Dt L)) (tzcCHost (tzcT φ P b Dt L) (cepsK φ P))
          ((Pv ω₁).ssS a) ((Pv ω₁).tzc a ω.1) ω.2 ∧ ¬ RelSS φ P b Dt L)).trans ?_
      exact priv_hostpad_sound hK4' hK3 (ssF L.sD (fun c => φ (Dt.pl 0 c))) (ssF_deg _ _) ((Pv ω₁).ssS a)
        ((Pv ω₁).ss a) (tzcCW (tzcT φ P b Dt L)) (tzcCPz (tzcT φ P b Dt L)) (tzcCW_deg _) (tzcCPz_deg _)
        (tzcCHost (tzcT φ P b Dt L) (cepsK φ P)) (tzcCHost_deg _ _) ((Pv ω₁).tzc a)
    · -- OUTC-03 PD / OUTC-04 LZC catch it (`margin_sound`)
      refine (pr_mono (E' := fun ω : OutCChal2 K n₀ nd ndo nl nt nu =>
        Accepts nd (fun x => mleAt (pdY φ P b Dt L) x * mleAt L.wd x) ((Pv ω₁).pdS ω.1 ω.2.1)
          ((Pv ω₁).pd ω.1 ω.2.1) ω.2.2.1.1 ∧
        Accepts nl (fun x => eqPoly ω.2.2.1.2.1.2 x * batched (lzcW (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1))
            ω.2.2.1.2.1.1.1 x + ω.2.2.1.2.1.1.2 * lzcHost L.Gm L.uL (fun z => φ (Dt.limb z)) (kcK φ P b) x)
          (ω.2.2.1.2.1.1.2 * (Pv ω₁).pdS ω.1 ω.2.1) ((Pv ω₁).lzc ω.1 ω.2.1 ω.2.2.1.1 ω.2.2.1.2.1) ω.2.2.1.2.2 ∧
        ¬ ((∑ c, pdY φ P b Dt L c * L.wd c = ∑ z, (L.Gm z * φ (Dt.limb z) + L.uL z * kcK φ P b)) ∧
          LzcHolds (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1)))
        (fun ω hω => ⟨hω.2.2.1.1, hω.2.2.1.2, hc⟩)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => ?_))).trans (le_add_left (le_add_left le_self_add))
      refine (pr_fst_le (fun ω : (Fin nd → K) × ((((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K)) =>
        Accepts nd (fun x => mleAt (pdY φ P b Dt L) x * mleAt L.wd x) ((Pv ω₁).pdS a a2) ((Pv ω₁).pd a a2) ω.1 ∧
        Accepts nl (fun x => eqPoly ω.2.1.2 x * batched (lzcW (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1))
            ω.2.1.1.1 x + ω.2.1.1.2 * lzcHost L.Gm L.uL (fun z => φ (Dt.limb z)) (kcK φ P b) x)
          (ω.2.1.1.2 * (Pv ω₁).pdS a a2) ((Pv ω₁).lzc a a2 ω.1 ω.2.1) ω.2.2 ∧
        ¬ ((∑ c, pdY φ P b Dt L c * L.wd c = ∑ z, (L.Gm z * φ (Dt.limb z) + L.uL z * kcK φ P b)) ∧
          LzcHolds (fun z => φ (Dt.limb z)) hd.1 L.sL ω₁.2 (gT ω₁.1)))).trans ?_
      exact margin_sound hK4 (pdY φ P b Dt L) L.wd ((Pv ω₁).pdS a a2) ((Pv ω₁).pd a a2) (fun z => φ (Dt.limb z))
        hd.1 L.sL L.Gm L.uL ω₁.2 (gT ω₁.1) (kcK φ P b) ((Pv ω₁).lzc a a2)
    · -- OUTC-05 DZC catches it
      have hnz : (∃ j, ∃ c : Fin ndo → Bool,
          dzcW (plK φ Dt) L.sD hd.2.1 (dzcD φ P b Dt L) (knK φ P) (kdvK φ P) (kdenK φ P) ω₁.2 (gT ω₁.1) j (bitv c) ≠ 0)
          ∨ (∃ i, ∃ c : Fin ndo → Bool, dzcPz (plK φ Dt) L.sD i (bitv c) ≠ 0) := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutCChal2 K n₀ nd ndo nl nt nu =>
        accZc (dzcW (plK φ Dt) L.sD hd.2.1 (dzcD φ P b Dt L) (knK φ P) (kdvK φ P) (kdenK φ P) ω₁.2 (gT ω₁.1))
          (dzcPz (plK φ Dt) L.sD) ((Pv ω₁).dzc ω.1 ω.2.1 ω.2.2.1) ω.2.2.2.1)
        (fun ω hω => hω.2.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => ?_)))).trans
        (le_add_left (le_add_left (le_add_left le_self_add)))
      refine (pr_fst_le (fun ω : ZcChal (Fin 3 ⊕ Fin 6) K ndo =>
        accZc (dzcW (plK φ Dt) L.sD hd.2.1 (dzcD φ P b Dt L) (knK φ P) (kdvK φ P) (kdenK φ P) ω₁.2 (gT ω₁.1))
          (dzcPz (plK φ Dt) L.sD) ((Pv ω₁).dzc a a2 a3) ω)).trans ?_
      exact zc_pad_sound hK _ _ (dzcW_deg _ _ _ _ _ _ _ _ _) (dzcPz_deg _ _) hnz ((Pv ω₁).dzc a a2 a3)
    · -- OUTC-06 TAB catches it
      have hnz : (∃ j, ∃ c : Fin nt → Bool, tzcW (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1) ω₁.2 j (bitv c) ≠ 0)
          ∨ (∃ i, ∃ c : Fin nt → Bool, tzcPz (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1) i (bitv c) ≠ 0) := by
        by_contra hn
        push Not at hn
        exact hc hn
      refine (pr_mono (E' := fun ω : OutCChal2 K n₀ nd ndo nl nt nu =>
        accZc (tzcW (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1) ω₁.2) (tzcPz (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1))
          ((Pv ω₁).tab ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1) ω.2.2.2.2.1)
        (fun ω hω => hω.2.2.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => pr_prod_le _
        (fun a4 => ?_))))).trans (le_add_left (le_add_left (le_add_left (le_add_left le_self_add))))
      refine (pr_fst_le (fun ω : ZcChal Unit K nt =>
        accZc (tzcW (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1) ω₁.2) (tzcPz (tabT φ P b Dt L (gT ω₁.1) hd.2.2.1))
          ((Pv ω₁).tab a a2 a3 a4) ω)).trans ?_
      exact zc_pad_sound hK3 _ _ (tabW_deg _ _) (tabPz_deg _) hnz ((Pv ω₁).tab a a2 a3 a4)
    · -- OUTC-07 ZS catches it
      refine (pr_mono (E' := fun ω : OutCChal2 K n₀ nd ndo nl nt nu =>
        Accepts nu (fun x => mleAt (fun _ => (1 : K)) x * mleAt hd.2.2.2 x) 0
          ((Pv ω₁).zs ω.1 ω.2.1 ω.2.2.1 ω.2.2.2.1 ω.2.2.2.2.1) ω.2.2.2.2.2)
        (fun ω hω => hω.2.2.2.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun a2 => pr_prod_le _ (fun a3 => pr_prod_le _
        (fun a4 => pr_prod_le _ (fun a5 => zs_sound hK2' hd.2.2.2 hc ((Pv ω₁).zs a a2 a3 a4 a5))))))).trans
        (le_add_left (le_add_left (le_add_left (le_add_left le_add_self))))
    · -- the sum claim fails: the `H` opening rejects
      exact pr_le_of_not _ (fun ω hω => hc hω.2.2.2.2.2.2) _

/-- **The numerator at the classifier's R1 shape** (every stage domain lifted to `2^12`, `To` two entries): the byte
LogUp's `2^12 + 12·2^12 + 511 = 53,759` and the slots' `36 + 55 + 86 + 84 + 50 + 24 = 335`, together `54,094`
(`≈ 2^15.72`; with the code's extension round, one more round of each slot's declared degree, `54,119`). -/
theorem outc_numerator_shape :
    (2 ^ 12 + 2 * (6 * 2 ^ 12) + 2 * 256 - 1) + ((12 + 12 * (1 + 1)) + ((12 * 4) + ((2 - 1) + (2 + (1 + 1 * (2 + 1)))))
      + ((12 * 2) + (2 + (12 + 12 * (3 + 1)))) + ((12 - 1) + (1 + (12 + 12 * (4 + 1))))
      + ((2 - 1) + (1 + (12 + 12 * (2 + 1)))) + 12 * 2) = 54094 ∧ 54094 < 2 ^ 16 := by
  norm_num

end Stage

end ZK60.StageX
