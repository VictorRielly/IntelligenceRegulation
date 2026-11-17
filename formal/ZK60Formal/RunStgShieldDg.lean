/-
D63 lane L65 (2026-11-17), part 2: **11 of the 12 stage `define` unfoldings (the twelfth, `incDefZS`, draws nothing),
`OffZero` + `IndDegLE` bridges for all 3 active IN-C define slots (including the L63-5 per-slot IO-width `sshΦIC`) and
all 5 active OUT-C define slots (including host slots TZC/LZC and degree-11 DZC), and the concrete round-by-round
soundness theorems `ssh_inc_rbrC` and `ssh_outc_rbr`**.

* `IncPrivIO`, `OutcPrivIO`, `tabPrivOK_*`: `TabPrivOK` certificates for every private/public table built by IN-C and OUT-C;
* `incDefIO_ok`, `incDefQZC_ok`/`err`, `incDefTZC_ok`/`err`, `outcDefIO_ok`, `outcDefSS_ok`, `outcDefTZC_ok`/`err`,
  `outcDefPD_ok`, `outcDefLZC_ok`/`err`, `outcDefDZC_ok`/`err`, `outcDefTAB_ok`/`err`, `outcDefZS_ok`: exact unfoldings
  of 11 of the 12 executable stage `define` builders (`incDefZS` has `n = 0` draws);
* `outc_ss_spT_deg`, `outc_pd_spT_deg`: individual degree bounds on the hosted private slots OUTC-01 (SS) and OUTC-03 (PD);
* **`ssh_inc_rbrC`**: `∀ k, (stgDefSqV P0 m hdrLen absOf (sshΦIC …) sshDgI k).Rbr` at `sshDgI = [2, 2, 2, 1, …]`;
* **`ssh_outc_rbr`**: `∀ k, (stgDefSqV P0 2 hdrLen absOf (sshΦO …) sshDgO k).Rbr` at `sshDgO = [2, 1, 2, 1, 2, 12, 2, 1, …]`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldToK

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

/-! ## 1. Multivariate degree and monad error helpers -/

section Helpers

variable {K : Type} [Field K]

theorem indDegLE_mu_pad {M : ℕ} (j1 j2 : Fin M) (hne : j1 ≠ j2) (c1 c2 c3 : K) :
    IndDegLE 1 (fun y : Fin M → K => y j1 * (c1 * (c2 + y j2 * c3))) := by
  refine indDegLE_mul_disjoint _ _ (indDegLE_coord j1)
    (IndDegLE.cmul c1 (IndDegLE.add (IndDegLE.const c2) (IndDegLE_mulc (indDegLE_coord j2) c3)))
    (fun i => ?_)
  by_cases hi : i = j1
  · subst hi
    refine Or.inr (fun y t => ?_)
    dsimp only
    rw [Function.update_of_ne (Ne.symm hne)]
  · exact Or.inl (constAt_coord_ne i j1 hi)

theorem indDegLE_eq_mul_upper {M N : ℕ} (m n e d : ℕ) (hd1 : 1 ≤ d)
    (hm : m ≤ M) (x : Fin N → K) (F : (Fin M → K) → K)
    (hF : IndDegLE d F) (hFc : ∀ i : Fin M, i.val < m → Block.ConstAt i F) :
    IndDegLE d (fun y : Fin M → K => eqDrawK m n e hm y x * F y) := by
  refine indDegLE_mul_disjoint _ _ (IndDegLE.mono (indDegLE_eqDrawK m n e hm x) hd1) hF (fun i => ?_)
  by_cases hi : i.val < m
  · exact Or.inr (hFc i hi)
  · exact Or.inl (constAt_eqDrawK_ge m n e hm x i (by omega))

omit [Field K] in
theorem update_lt_get {M : ℕ} (y : Fin M → K) (t : K) (i : Fin M) (m k : ℕ)
    (hi : i.val < m) (hmk : m ≤ k) (hk : k < M) :
    Function.update y i t ⟨k, hk⟩ = y ⟨k, hk⟩ :=
  Function.update_of_ne (by
    intro he
    have hval := congrArg Fin.val he
    dsimp only at hval
    omega) t y

end Helpers

theorem Z_range_subset {M off1 len1 off2 len2 : ℕ}
    (h1 : off2 ≤ off1) (h2 : off1 + len1 ≤ off2 + len2) :
    Z_range M off1 len1 ⊆ Z_range M off2 len2 := by
  intro i hi
  simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi ⊢
  omega

theorem Z_range_split {M off a b : ℕ} {i : Fin M}
    (hi : i ∈ Z_range M off (a + b)) :
    i ∈ Z_range M off a ∨ i ∈ Z_range M (off + a) b := by
  simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi ⊢
  omega

theorem except_err_2 {α β γ : Type} (m1 : Except String α) (m2 : Except String β)
    (f : α → β → Except String γ)
    (h : (∃ msg, m1 = .error msg) ∨ (∃ msg, m2 = .error msg)) :
    ∃ msg', (m1 >>= fun a => m2 >>= fun b => f a b) = .error msg' := by
  rcases h with ⟨msg, h1⟩ | ⟨msg, h2⟩
  · exact ⟨msg, by rw [h1]; rfl⟩
  · cases m1 with
    | error e => exact ⟨e, rfl⟩
    | ok _ => exact ⟨msg, by dsimp only [Bind.bind, Except.bind]; rw [h2]⟩

theorem except_err_3 {α β γ δ : Type} (m1 : Except String α) (m2 : Except String β)
    (m3 : Except String γ) (f : α → β → γ → Except String δ)
    (h : (∃ msg, m1 = .error msg) ∨ (∃ msg, m2 = .error msg) ∨ (∃ msg, m3 = .error msg)) :
    ∃ msg', (m1 >>= fun a => m2 >>= fun b => m3 >>= fun c => f a b c) = .error msg' := by
  rcases h with ⟨msg, h1⟩ | ⟨msg, h2⟩ | ⟨msg, h3⟩
  · exact ⟨msg, by rw [h1]; rfl⟩
  · cases m1 with
    | error e => exact ⟨e, rfl⟩
    | ok _ => exact ⟨msg, by dsimp only [Bind.bind, Except.bind]; rw [h2]⟩
  · cases m1 with
    | error e => exact ⟨e, rfl⟩
    | ok _ =>
      cases m2 with
      | error e => exact ⟨e, rfl⟩
      | ok _ => exact ⟨msg, by dsimp only [Bind.bind, Except.bind]; rw [h3]⟩

/-! ## 2. `TabPrivOK` constructors and `toK` sub-expression bridges -/

def IncPrivIO0 (I : IncPub) (p : Block.Priv) : Prop :=
  p.cm = .inp ∧ p.log = clog2 I.inEpWords

def IncPrivIO1 (I : IncPub) (p : Block.Priv) : Prop :=
  p.cm = .out ∧ p.log = I.bInLog

def OutcPrivIO (O : OutcPub) (p : Block.Priv) : Prop :=
  p.cm = .inp ∧ p.log = O.bOutLog

theorem tabPrivOK_pub (pOk : Block.Priv → Prop) (pv : List Fp2) :
    TabPrivOK pOk (.pub pv) := by
  intro p hp; cases hp

theorem tabPrivOK_a_rho (pOk : Block.Priv → Prop) (off log mr : ℕ) :
    TabPrivOK pOk (.priv ⟨.a, [(off, Fp2.one)], log, rhoC 0 log, mr, 0⟩) := by
  intro p hp; injection hp with hp; subst hp
  refine ⟨?_, List.cons_ne_nil _ _, ?_, ?_⟩
  · intro h; rcases h with h | h <;> cases h
  · simpa using varsOKb_fixed_rho_fixed [] [] 0 log
      (fun _ h => absurd h List.not_mem_nil) (fun _ h => absurd h List.not_mem_nil)
  · intro c hc w hw
    obtain ⟨_, _, h⟩ := List.mem_map.mp hc
    rw [hw] at h; cases h

theorem tabPrivOK_a_fixed_rho (pOk : Block.Priv → Prop) (off log k lw mr : ℕ) :
    TabPrivOK pOk (.priv ⟨.a, [(off, Fp2.one)], log,
      fixedC (List.replicate k Fp2.zero) ++ rhoC 0 lw, mr, 0⟩) := by
  intro p hp; injection hp with hp; subst hp
  refine ⟨?_, List.cons_ne_nil _ _, ?_, ?_⟩
  · intro h; rcases h with h | h <;> cases h
  · simpa using varsOKb_fixed_rho_fixed (fixedC (List.replicate k Fp2.zero)) [] 0 lw
      (fun _ hc => coordVar_fixedC hc) (fun _ h => absurd h List.not_mem_nil)
  · intro c hc w hw
    rcases List.mem_append.mp hc with hc1 | hc2
    · obtain ⟨a, ha, hca⟩ := List.mem_map.mp hc1
      rw [hw] at hca; injection hca with hca; subst hca
      rw [List.eq_of_mem_replicate ha]; exact Fp2.canon_zero
    · obtain ⟨_, _, h⟩ := List.mem_map.mp hc2
      rw [hw] at h; cases h

theorem tabPrivOK_a_fixed (pOk : Block.Priv → Prop) (off log k mr : ℕ) :
    TabPrivOK pOk (.priv ⟨.a, [(off, Fp2.one)], log,
      fixedC (List.replicate k Fp2.zero), mr, 0⟩) := by
  have hr0 : rhoC 0 0 = [] := rfl
  simpa [hr0] using tabPrivOK_a_fixed_rho pOk off log k 0 mr

theorem tabPrivOK_h_rho (pOk : Block.Priv → Prop) (o1 o2 log mr : ℕ) :
    TabPrivOK pOk (.priv ⟨.h, [(o1, Fp2.one), (o2, Block.fp2U)], log, rhoC 0 log, mr, 0⟩) := by
  intro p hp; injection hp with hp; subst hp
  refine ⟨?_, List.cons_ne_nil _ _, ?_, ?_⟩
  · intro h; rcases h with h | h <;> cases h
  · simpa using varsOKb_fixed_rho_fixed [] [] 0 log
      (fun _ h => absurd h List.not_mem_nil) (fun _ h => absurd h List.not_mem_nil)
  · intro c hc w hw
    obtain ⟨_, _, h⟩ := List.mem_map.mp hc
    rw [hw] at h; cases h

theorem tabPrivOK_inc_io0 (I : IncPub) (mr : ℕ) :
    TabPrivOK (IncPrivIO0 I) (.priv ⟨.inp, [(0, Fp2.one)], clog2 I.inEpWords, rhoC 0 (clog2 I.inEpWords), mr, 0⟩) := by
  intro p hp; injection hp with hp; subst hp
  refine ⟨fun _ => ⟨rfl, rfl⟩, List.cons_ne_nil _ _, ?_, ?_⟩
  · simpa using varsOKb_fixed_rho_fixed [] [] 0 (clog2 I.inEpWords)
      (fun _ h => absurd h List.not_mem_nil) (fun _ h => absurd h List.not_mem_nil)
  · intro c hc w hw
    obtain ⟨_, _, h⟩ := List.mem_map.mp hc
    rw [hw] at h; cases h

theorem tabPrivOK_inc_io1 (I : IncPub) (lo hi mr : ℕ) (rEmb : List Fp2) (hr : ∀ a ∈ rEmb, a.Canon) :
    TabPrivOK (IncPrivIO1 I) (.priv ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC lo hi ++ fixedC rEmb, mr, 0⟩) := by
  intro p hp; injection hp with hp; subst hp
  refine ⟨fun _ => ⟨rfl, rfl⟩, List.cons_ne_nil _ _, ?_, ?_⟩
  · simpa using varsOKb_fixed_rho_fixed [] (fixedC rEmb) lo hi
      (fun _ h => absurd h List.not_mem_nil) (fun _ hc => coordVar_fixedC hc)
  · intro c hc w hw
    rcases List.mem_append.mp hc with hc1 | hc2
    · obtain ⟨_, _, h⟩ := List.mem_map.mp hc1
      rw [hw] at h; cases h
    · obtain ⟨a, ha, hca⟩ := List.mem_map.mp hc2
      rw [hw] at hca; injection hca with hca; subst hca
      exact hr a ha

theorem tabPrivOK_outc_io0 (O : OutcPub) (mr : ℕ) :
    TabPrivOK (OutcPrivIO O) (.priv ⟨.inp, [(0, Fp2.one)], O.bOutLog,
      fixedBits O.verdictRow O.tBits ++ rhoC 0 O.dBits, mr, 0⟩) := by
  intro p hp; injection hp with hp; subst hp
  refine ⟨fun _ => ⟨rfl, rfl⟩, List.cons_ne_nil _ _, ?_, ?_⟩
  · simpa using varsOKb_fixed_rho_fixed (fixedBits O.verdictRow O.tBits) [] 0 O.dBits
      (fun _ hc => coordVar_fixedBits hc) (fun _ h => absurd h List.not_mem_nil)
  · intro c hc w hw
    rcases List.mem_append.mp hc with hc1 | hc2
    · unfold fixedBits at hc1
      obtain ⟨b, _, hcb⟩ := List.mem_map.mp hc1
      rw [hw] at hcb; injection hcb with hcb; rw [← hcb]
      split_ifs <;> [exact Fp2.canon_one; exact Fp2.canon_zero]
    · obtain ⟨_, _, h⟩ := List.mem_map.mp hc2
      rw [hw] at h; cases h

def mbC {K : Type} [Field K] [Algebra GF K] (r : ℕ) : K :=
  algebraMap GF K (Fp.new (UInt64.ofNat r)).toGF

theorem mb_toK {K : Type} [Field K] [Algebra GF K] (U : K) (a : Fp2) (r : ℕ) :
    (mb a r).toK U = a.toK U * mbC r :=
  Fp2.toK_mulBase U a _

theorem mb_canon (a : Fp2) (r : ℕ) : (mb a r).Canon :=
  Fp2.canon_mulBase a _

def l3K {K : Type} [Field K] [Algebra GF K] (g : ℕ → K) (o : ℕ) : K :=
  (g o + g (o + 1) * mbC 256) + g (o + 2) * mbC 65536

theorem l3W_canon (v : List Fp2) (o : ℕ) : (l3W v o).Canon :=
  Fp2.canon_add _ _

theorem l3W_toK {K : Type} [Field K] [Algebra GF K] (U : K) (vals : List Fp2)
    (hv : ∀ a ∈ vals, a.Canon) (o : ℕ) :
    (l3W vals o).toK U = l3K (fun idx => (vals.map (Fp2.toK U)).getD idx 0) o := by
  unfold l3W l3K
  rw [Fp2.toK_add U _ _ (Fp2.canon_add _ _) (mb_canon _ _),
      Fp2.toK_add U _ _ (vg_canon hv o) (mb_canon _ _),
      mb_toK, mb_toK, vg_toK_map, vg_toK_map, vg_toK_map]

theorem indDegLE_l3K {K : Type} [Field K] [Algebra GF K] {N : ℕ}
    (g : ℕ → (Fin N → K) → K) (hg : ∀ idx, IndDegLE 1 (g idx)) (o : ℕ) :
    IndDegLE 1 (fun x => l3K (fun idx => g idx x) o) :=
  IndDegLE.add (IndDegLE.add (hg o) (IndDegLE_mulc (hg (o + 1)) _))
    (IndDegLE_mulc (hg (o + 2)) _)

def denK {K : Type} [Field K] [Algebra GF K] (U : K) (alphaK gK : K) (g : ℕ → K)
    (i : ℕ) (c cst : ℤ) : K :=
  alphaK - (((kI cst).toK U + gK) + g i * algebraMap GF K (Fp.fromI64 c).toGF)

theorem denW_canon (v : List Fp2) (alpha g : Fp2) (ha : alpha.Canon) (i : ℕ) (c cst : ℤ) :
    (denW v alpha g i c cst).Canon :=
  Fp2.canon_sub _ _ ha (Fp2.canon_add _ _)

theorem denW_toK {K : Type} [Field K] [Algebra GF K] (U : K) (vals : List Fp2)
    (alpha g : Fp2) (ha : alpha.Canon) (hg : g.Canon)
    (i : ℕ) (c cst : ℤ) :
    (denW vals alpha g i c cst).toK U
      = denK U (alpha.toK U) (g.toK U) (fun idx => (vals.map (Fp2.toK U)).getD idx 0) i c cst := by
  unfold denW denK
  rw [Fp2.toK_sub U _ _ ha (Fp2.canon_add _ _),
      Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mulBase _ _),
      Fp2.toK_add U _ _ (kI_canon cst) hg,
      Fp2.toK_mulBase U, vg_toK_map]

theorem indDegLE_denK {K : Type} [Field K] [Algebra GF K] {N : ℕ} (U : K)
    (alphaK gK : K) (g : ℕ → (Fin N → K) → K) (hg : ∀ idx, IndDegLE 1 (g idx))
    (i : ℕ) (c cst : ℤ) :
    IndDegLE 1 (fun x => denK U alphaK gK (fun idx => g idx x) i c cst) :=
  IndDegLE.sub (IndDegLE.const _)
    (IndDegLE.add (IndDegLE.const _) (IndDegLE_mulc (hg i) _))

def lbK {K : Type} [Field K] [Algebra GF K] (g : ℕ → K) (p0 : ℕ) : K :=
  ∑ kk ∈ Finset.range 4, g (2 + (p0 + kk)) * mbC (2 ^ (8 * kk))

theorem foldl_add_canon (f : ℕ → Fp2) :
    ∀ m, ((List.range m).foldl (fun acc j => acc.add (f j)) Fp2.zero).Canon
  | 0 => Fp2.canon_zero
  | m + 1 => by
    rw [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    exact Fp2.canon_add _ _

theorem lbW_canon (v : List Fp2) (p0 : ℕ) : (lbW v p0).Canon :=
  foldl_add_canon _ 4

theorem lbW_toK {K : Type} [Field K] [Algebra GF K] (U : K) (vals : List Fp2) (p0 : ℕ) :
    (lbW vals p0).toK U = lbK (fun idx => (vals.map (Fp2.toK U)).getD idx 0) p0 := by
  unfold lbW lbK
  obtain ⟨_, heq⟩ := foldl_range_add_toK U
    (fun kk => mb (vg vals (2 + (p0 + kk))) (2 ^ (8 * kk))) (fun _ => mb_canon _ _) 4
  rw [heq]
  refine Finset.sum_congr rfl (fun kk _ => ?_)
  rw [mb_toK, vg_toK_map]

theorem indDegLE_lbK {K : Type} [Field K] [Algebra GF K] {N : ℕ}
    (g : ℕ → (Fin N → K) → K) (hg : ∀ idx, IndDegLE 1 (g idx)) (p0 : ℕ) :
    IndDegLE 1 (fun x => lbK (fun idx => g idx x) p0) :=
  indDegLE_finset_sum (Finset.range 4) _ (fun _ _ => IndDegLE_mulc (hg _) _)

/-! ## 3. All 11 `define` unfoldings (3 IN-C + 8 OUT-C) -/

section UnfoldDefs

variable {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

theorem incDefIO_ok (I : IncPub) (G : IncGeo) (dr : List Fp2) :
    let L := incLay I G.bLogN
    let lw := clog2 I.inEpWords
    incDefIO I G dr = .ok ⟨[
      .eq (dr.take lw) 0,
      .pub (supp I.tokens I.inEpWords),
      .priv ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
        fixedC (List.replicate (I.tiLog - lw) Fp2.zero) ++ rhoC 0 lw,
        L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩,
      .priv ⟨.inp, [(0, Fp2.one)], lw, rhoC 0 lw, G.epDataRows, 0⟩
    ], (fun v => (vg v 0).mul ((vg v 3).sub ((vg v 1).mul (vg v 2)))), []⟩ := by
  intro L lw; unfold incDefIO; refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aAtT L 0 incA_TOK _ _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_ioT _ _ _ _ _) ?_
  exact sbm_finishT L 0 _ [] _ rfl rfl rfl

theorem incDefQZC_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (I : IncPub) (G : IncGeo) (cx : IncCtx)
    (hM : M = I.tiLog + 5) (y : Fin M → K) (hZ : ∀ i ∈ Z_range M I.tiLog 5, y i ≠ 0) :
    let L := incLay I G.bLogN
    let tl := I.tiLog
    let sn := 2 ^ tl
    let b2 := cx.beta.mul cx.beta
    let dr := stgWords U hbij y
    let mu := (dr.drop tl).take 4
    let zeta := (((dr.drop (tl + 4)).take 1).getD 0 Fp2.zero)
    incDefQZC I G cx dr = .ok ⟨[
      .eq (dr.take tl) 0,
      .pub (supp I.tokens sn),
      .pub (supp 1 sn),
      .pub ((List.range sn).map (fun t => if I.isTemplate t then Fp2.one else Fp2.zero)),
      .pub ((List.range sn).map (fun t => kI (I.kappa t))),
      .pub ((List.range sn).map (fun t => if I.ctlQ t then b2 else Fp2.zero)),
      .priv ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
        rhoC 0 (L.aLog.getD incA_TOK 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff incH_Q).1, Fp2.one), ((L.hOff incH_Q).2, Block.fp2U)],
        L.hLog.getD incH_Q 0, rhoC 0 (L.hLog.getD incH_Q 0), L.hMaskBase + 2 * (L.prefixH 1 + 0), 0⟩,
      .priv ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (tl - I.tBits) tl ++ fixedC cx.rEmb, G.bInRow, 0⟩
    ], (fun v =>
      let q := (((vg v 6).add (cx.beta.mul (vg v 8))).add (vg v 5)).add cx.gEmb
      let logup := ((vg v 7).mul (cx.alpha.sub q)).sub (vg v 1)
      let bosC := (vg v 2).mul ((vg v 6).sub (kI I.bos))
      let tmpl := (vg v 3).mul ((vg v 6).sub (vg v 4))
      let pad := (Fp2.one.sub (vg v 1)).mul ((vg v 6).add (zeta.mul (vg v 7)))
      (vg v 0).mul (((((vg mu 0).mul logup).add ((vg mu 1).mul bosC)).add ((vg mu 2).mul tmpl)).add
        ((vg mu 3).mul pad))), []⟩ := by
  intro L tl sn b2 dr mu zeta; unfold incDefQZC
  have h1 := nonzeroE_stgWords_ok U hbij hU tl 4 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  have h2 := nonzeroE_stgWords_ok U hbij hU (tl + 4) 1 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  change (StageV.nonzeroE ((dr.drop tl).take 4) >>= fun mu' =>
    ((StageV.nonzeroE ((dr.drop (tl + 4)).take 1)).map (fun z => z.getD 0 Fp2.zero)) >>= fun zeta' => _) = _
  rw [h1, h2]; dsimp only [Bind.bind, Except.bind, Functor.map, Except.map]
  refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aT L 1 incA_TOK _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_hT L 1 incH_Q _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_ioT _ _ _ _ _) ?_
  exact sbm_finishT L 1 _ [] _ rfl rfl rfl

theorem incDefQZC_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (I : IncPub) (G : IncGeo) (cx : IncCtx)
    (y : Fin M → K) (hZ : ∃ i ∈ Z_range M I.tiLog 5, y i = 0) :
    ∃ msg, incDefQZC I G cx (stgWords U hbij y) = .error msg := by
  obtain ⟨i, hi, hy0⟩ := hZ; unfold incDefQZC
  rcases Z_range_split (a := 4) (b := 1) hi with hi1 | hi2
  · exact except_err_2 _ _ _ (Or.inl ⟨_, nonzeroE_stgWords_err U hbij hU I.tiLog 4 y i hi1 hy0⟩)
  · refine except_err_2 _ _ _ (Or.inr ⟨"zero batching challenge; discard attempt", ?_⟩)
    rw [nonzeroE_stgWords_err U hbij hU (I.tiLog + 4) 1 y i hi2 hy0]; rfl

theorem incDefTZC_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (I : IncPub) (G : IncGeo) (cx : IncCtx)
    (hM : M = I.vocLog + 3) (y : Fin M → K) (hZ : ∀ i ∈ Z_range M I.vocLog 3, y i ≠ 0) :
    let L := incLay I G.bLogN
    let lv := I.vocLog
    let dr := stgWords U hbij y
    let mu := (dr.drop lv).take 2
    let zeta := (((dr.drop (lv + 2)).take 1).getD 0 Fp2.zero)
    incDefTZC I G cx dr = .ok ⟨[
      .eq (dr.take lv) 0,
      .pub (supp I.v (2 ^ lv)),
      .pub cx.tauTab,
      .priv ⟨.a, [(L.aOff incA_MULT, Fp2.one)], L.aLog.getD incA_MULT 0,
        rhoC 0 (L.aLog.getD incA_MULT 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff incH_TAB).1, Fp2.one), ((L.hOff incH_TAB).2, Block.fp2U)],
        L.hLog.getD incH_TAB 0, rhoC 0 (L.hLog.getD incH_TAB 0), L.hMaskBase + 2 * (L.prefixH 2 + 0), 0⟩
    ], (fun v =>
      let rel := ((vg v 4).mul (cx.alpha.sub (vg v 2))).sub (vg v 3)
      let pad := (Fp2.one.sub (vg v 1)).mul ((vg v 3).add (zeta.mul (vg v 4)))
      (vg v 0).mul (((vg mu 0).mul rel).add ((vg mu 1).mul pad))), []⟩ := by
  intro L lv dr mu zeta; unfold incDefTZC
  have h1 := nonzeroE_stgWords_ok U hbij hU lv 2 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  have h2 := nonzeroE_stgWords_ok U hbij hU (lv + 2) 1 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  change (StageV.nonzeroE ((dr.drop lv).take 2) >>= fun mu' =>
    ((StageV.nonzeroE ((dr.drop (lv + 2)).take 1)).map (fun z => z.getD 0 Fp2.zero)) >>= fun zeta' => _) = _
  rw [h1, h2]; dsimp only [Bind.bind, Except.bind, Functor.map, Except.map]
  refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aT L 2 incA_MULT _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_hT L 2 incH_TAB _ (show 0 < 1 by norm_num)) ?_
  exact sbm_finishT L 2 _ [] _ rfl rfl rfl

theorem incDefTZC_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (I : IncPub) (G : IncGeo) (cx : IncCtx)
    (y : Fin M → K) (hZ : ∃ i ∈ Z_range M I.vocLog 3, y i = 0) :
    ∃ msg, incDefTZC I G cx (stgWords U hbij y) = .error msg := by
  obtain ⟨i, hi, hy0⟩ := hZ; unfold incDefTZC
  rcases Z_range_split (a := 2) (b := 1) hi with hi1 | hi2
  · exact except_err_2 _ _ _ (Or.inl ⟨_, nonzeroE_stgWords_err U hbij hU I.vocLog 2 y i hi1 hy0⟩)
  · refine except_err_2 _ _ _ (Or.inr ⟨"zero batching challenge; discard attempt", ?_⟩)
    rw [nonzeroE_stgWords_err U hbij hU (I.vocLog + 2) 1 y i hi2 hy0]; rfl

theorem outcDefIO_ok (O : OutcPub) (G : OutcGeo) (dr : List Fp2) :
    let L := outcLay O G.bLogN
    outcDefIO O G dr = .ok ⟨[
      .eq (dr.take O.dBits) 0,
      .priv ⟨.a, [(L.aOff ocC_X, Fp2.one)], L.aLog.getD ocC_X 0,
        fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits,
        L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩,
      .priv ⟨.inp, [(0, Fp2.one)], O.bOutLog,
        fixedBits O.verdictRow O.tBits ++ rhoC 0 O.dBits, G.bOutRow, 0⟩
    ], ioPoly, []⟩ := by
  intro L; unfold outcDefIO; refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aAtT L 0 ocC_X _ _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_ioT _ _ _ _ _) ?_
  exact sbm_finishT L 0 ioPoly [] _ rfl rfl rfl

theorem outcDefSS_ok (O : OutcPub) (G : OutcGeo) :
    let L := outcLay O G.bLogN
    outcDefSS O G = .ok ⟨[
      .pub (supp O.d (2 ^ O.ldo)),
      .priv ⟨.a, [(L.aOff ocC_X, Fp2.one)], L.aLog.getD ocC_X 0,
        rhoC 0 (L.aLog.getD ocC_X 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩
    ], ssPoly, []⟩ := by
  intro L; unfold outcDefSS; refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aT L 1 ocC_X _ (show 0 < 1 by norm_num)) ?_
  exact sbm_finishT L 1 ssPoly [] _ rfl rfl rfl

theorem outcDefTZC_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo)
    (hM : M = 7) (y : Fin M → K) (hZ : ∀ i ∈ Z_range M 1 6, y i ≠ 0) :
    let L := outcLay O G.bLogN
    let dr := stgWords U hbij y
    let mu := (dr.drop 1).take 4
    let nu := dr.getD 5 Fp2.zero
    let zeta := dr.getD 6 Fp2.zero
    outcDefTZC O G dr = .ok ⟨
      .eq (dr.take OutcPub.toLog) 0 :: (
        [.pub (supp 1 (2 ^ OutcPub.toLog)),
         .priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
           rhoC 0 (L.aLog.getD ocC_D 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩,
         .priv ⟨.a, [(L.aOff ocC_DSQ, Fp2.one)], L.aLog.getD ocC_DSQ 0,
           rhoC 0 (L.aLog.getD ocC_DSQ 0), L.aMaskBase + 2 * (L.prefixA 2 + 1), 0⟩]
        ++ ((List.range (3 * OutcPub.limbsIsqrt)).zipIdx 2).map (fun p =>
          Block.Tab.priv ⟨.a, [(L.aOff ocC_LIMB + 2 * p.1, Fp2.one)], OutcPub.toLog,
            rhoC 0 OutcPub.toLog, L.aMaskBase + 2 * (L.prefixA 2 + p.2), 0⟩)),
      tzcPoly mu nu zeta (kI O.ceps), [(1, nu)]⟩ := by
  intro L dr mu nu zeta; unfold outcDefTZC
  have h1 := nonzeroE_stgWords_ok U hbij hU 1 4 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  have h2 := nz1_stgWords_ok U hbij hU 5 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  have h3 := nz1_stgWords_ok U hbij hU 6 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  change (StageV.nonzeroE ((dr.drop 1).take 4) >>= fun mu' =>
    StageV.nz1 dr 5 >>= fun nu' => StageV.nz1 dr 6 >>= fun zeta' => _) = _
  rw [h1, h2, h3]; dsimp only [Bind.bind, Except.bind]
  refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aT L 2 ocC_D _ (show 0 < 11 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aT L 2 ocC_DSQ _ (show 1 < 11 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_forIn_aSlice L 2 (fun kk => L.aOff ocC_LIMB + 2 * kk)
    (fun _ => OutcPub.toLog) (fun _ => rhoC 0 OutcPub.toLog) (List.range (3 * OutcPub.limbsIsqrt)) _
    (show 2 + (List.range (3 * OutcPub.limbsIsqrt)).length ≤ 11 by simp [OutcPub.limbsIsqrt])) ?_
  exact sbm_finishT L 2 (tzcPoly mu nu zeta (kI O.ceps)) [(1, nu)] _
      (show 2 + (List.range (3 * OutcPub.limbsIsqrt)).length = 11 by simp [OutcPub.limbsIsqrt]) rfl rfl

theorem outcDefTZC_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo)
    (y : Fin M → K) (hZ : ∃ i ∈ Z_range M 1 6, y i = 0) :
    ∃ msg, outcDefTZC O G (stgWords U hbij y) = .error msg := by
  obtain ⟨i, hi, hy0⟩ := hZ; unfold outcDefTZC
  rcases Z_range_split (a := 4) (b := 2) hi with hi1 | hi23
  · exact except_err_3 _ _ _ _ (Or.inl ⟨_, nonzeroE_stgWords_err U hbij hU 1 4 y i hi1 hy0⟩)
  · rcases Z_range_split (a := 1) (b := 1) hi23 with hi2 | hi3
    · exact except_err_3 _ _ _ _ (Or.inr (Or.inl ⟨_, nz1_stgWords_err U hbij hU 5 y i hi2 hy0⟩))
    · exact except_err_3 _ _ _ _ (Or.inr (Or.inr ⟨_, nz1_stgWords_err U hbij hU 6 y i hi3 hy0⟩))

theorem outcDefPD_ok (O : OutcPub) (G : OutcGeo) :
    let L := outcLay O G.bLogN
    outcDefPD O G = .ok ⟨[
      .priv ⟨.a, [(L.aOff ocC_Y, Fp2.one)], L.aLog.getD ocC_Y 0,
        fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits,
        L.aMaskBase + 2 * (L.prefixA 3 + 0), 0⟩,
      .pub (wTab O.dPad (O.wDelta.take O.d))
    ], pdPoly, []⟩ := by
  intro L; unfold outcDefPD; refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aAtT L 3 ocC_Y _ _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  exact sbm_finishT L 3 pdPoly [] _ rfl rfl rfl

theorem outcDefLZC_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo) (hist : Block.Hist)
    (hM : M = O.llo + 3) (y : Fin M → K) (hZ : ∀ i ∈ Z_range M O.llo 3, y i ≠ 0) :
    let L := outcLay O G.bLogN
    let dr := stgWords U hbij y
    let mu := (dr.drop O.llo).take 2
    let nu := dr.getD (O.llo + 2) Fp2.zero
    let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
    let loN := 2 ^ O.llo
    outcDefLZC O G hist dr = .ok ⟨[
      .eq (dr.take O.llo) 0,
      .pub (liveTab loN OutcPub.lamBase O.limbs),
      .pub (gTab loN OutcPub.lamBase O.limbs O.verdict),
      .pub (supp 1 loN),
      .priv ⟨.a, [(L.aOff ocC_LIMB, Fp2.one)], L.aLog.getD ocC_LIMB 0,
        rhoC 0 (L.aLog.getD ocC_LIMB 0), L.aMaskBase + 2 * (L.prefixA 4 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff ocH_LO).1, Fp2.one), ((L.hOff ocH_LO).2, Block.fp2U)],
        L.hLog.getD ocH_LO 0, rhoC 0 (L.hLog.getD ocH_LO 0), L.hMaskBase + 2 * (L.prefixH 4 + 0), 0⟩
    ], lzcPoly mu nu hist.alpha gU8 ((kI O.verdict).add (kI O.c)), [(3, nu)]⟩ := by
  intro L dr mu nu gU8 loN; unfold outcDefLZC
  have h1 := nonzeroE_stgWords_ok U hbij hU O.llo 2 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  have h2 := nz1_stgWords_ok U hbij hU (O.llo + 2) (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  change (StageV.nonzeroE ((dr.drop O.llo).take 2) >>= fun mu' =>
    StageV.nz1 dr (O.llo + 2) >>= fun nu' => _) = _
  rw [h1, h2]; dsimp only [Bind.bind, Except.bind]
  refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aT L 4 ocC_LIMB _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_hT L 4 ocH_LO _ (show 0 < 1 by norm_num)) ?_
  exact sbm_finishT L 4 _ [(3, nu)] _ rfl rfl rfl

theorem outcDefLZC_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo) (hist : Block.Hist)
    (y : Fin M → K) (hZ : ∃ i ∈ Z_range M O.llo 3, y i = 0) :
    ∃ msg, outcDefLZC O G hist (stgWords U hbij y) = .error msg := by
  obtain ⟨i, hi, hy0⟩ := hZ; unfold outcDefLZC
  rcases Z_range_split (a := 2) (b := 1) hi with hi1 | hi2
  · exact except_err_2 _ _ _ (Or.inl ⟨_, nonzeroE_stgWords_err U hbij hU O.llo 2 y i hi1 hy0⟩)
  · exact except_err_2 _ _ _ (Or.inr ⟨_, nz1_stgWords_err U hbij hU (O.llo + 2) y i hi2 hy0⟩)

theorem outcDefDZC_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo) (hist : Block.Hist)
    (hM : M = O.ldo + 11) (y : Fin M → K) (hZ : ∀ i ∈ Z_range M O.ldo 11, y i ≠ 0) :
    let L := outcLay O G.bLogN
    let dr := stgWords U hbij y
    let mu := (dr.drop O.ldo).take 10
    let zeta := dr.getD (O.ldo + 10) Fp2.zero
    let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
    outcDefDZC O G hist dr = .ok ⟨
      .eq (dr.take O.ldo) 0 :: (
        .pub (supp O.d (2 ^ O.ldo)) :: (
          ((List.range' ocC_X (ocC_MULT - ocC_X)).zipIdx 0).map (fun p =>
            Block.Tab.priv ⟨.a, [(L.aOff p.1, Fp2.one)], L.aLog.getD p.1 0,
              rhoC 0 (L.aLog.getD p.1 0), L.aMaskBase + 2 * (L.prefixA 5 + p.2), 0⟩)
          ++ [.priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
              fixedC (List.replicate OutcPub.toLog Fp2.zero),
              L.aMaskBase + 2 * (L.prefixA 5 + (0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length)), 0⟩]
          ++ ((List.range 6).zipIdx 0).map (fun p =>
            let pl := ocH_D0 + p.1
            Block.Tab.priv ⟨.h, [((L.hOff pl).1, Fp2.one), ((L.hOff pl).2, Block.fp2U)],
              L.hLog.getD pl 0, rhoC 0 (L.hLog.getD pl 0),
              L.hMaskBase + 2 * (L.prefixH 5 + p.2), 0⟩))),
      dzcPoly mu zeta hist.alpha gU8 (kI (2 * O.g0 * O.cn)) (kI (2 ^ O.tn)) (kI (2 ^ (O.tn + 1))), []⟩ := by
  intro L dr mu zeta gU8; unfold outcDefDZC
  have h1 := nonzeroE_stgWords_ok U hbij hU O.ldo 10 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  have h2 := nz1_stgWords_ok U hbij hU (O.ldo + 10) (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  change (StageV.nonzeroE ((dr.drop O.ldo).take 10) >>= fun mu' =>
    StageV.nz1 dr (O.ldo + 10) >>= fun zeta' => _) = _
  rw [h1, h2]; dsimp only [Bind.bind, Except.bind]
  refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_forIn_aT L 5 (List.range' ocC_X (ocC_MULT - ocC_X)) _
    (show 0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length ≤ 13 by simp [ocC_X, ocC_MULT])) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aAtT L 5 ocC_D _ _
    (show 0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length < 13 by simp [ocC_X, ocC_MULT])) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_forIn_hT L 5 (fun j => ocH_D0 + j) (List.range 6) _
    (show 0 + (List.range 6).length ≤ 6 by simp)) ?_
  simpa only [List.nil_append, List.cons_append, List.append_assoc] using
    sbm_finishT L 5 _ [] _
      (show 0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length + 1 = 13 by simp [ocC_X, ocC_MULT])
      (show 0 + (List.range 6).length = 6 by simp) rfl

theorem outcDefDZC_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo) (hist : Block.Hist)
    (y : Fin M → K) (hZ : ∃ i ∈ Z_range M O.ldo 11, y i = 0) :
    ∃ msg, outcDefDZC O G hist (stgWords U hbij y) = .error msg := by
  obtain ⟨i, hi, hy0⟩ := hZ; unfold outcDefDZC
  rcases Z_range_split (a := 10) (b := 1) hi with hi1 | hi2
  · exact except_err_2 _ _ _ (Or.inl ⟨_, nonzeroE_stgWords_err U hbij hU O.ldo 10 y i hi1 hy0⟩)
  · exact except_err_2 _ _ _ (Or.inr ⟨_, nz1_stgWords_err U hbij hU (O.ldo + 10) y i hi2 hy0⟩)

theorem outcDefTAB_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo) (hist : Block.Hist)
    (hM : M = O.ltab + 3) (y : Fin M → K) (hZ : ∀ i ∈ Z_range M O.ltab 3, y i ≠ 0) :
    let L := outcLay O G.bLogN
    let dr := stgWords U hbij y
    let mu := (dr.drop O.ltab).take 2
    let zeta := dr.getD (O.ltab + 2) Fp2.zero
    let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
    outcDefTAB O G hist dr = .ok ⟨[
      .eq (dr.take O.ltab) 0,
      .pub (supp OutcPub.u8Len (2 ^ O.ltab)),
      .pub (tvTab (2 ^ O.ltab) gU8),
      .priv ⟨.a, [(L.aOff ocC_MULT, Fp2.one)], L.aLog.getD ocC_MULT 0,
        rhoC 0 (L.aLog.getD ocC_MULT 0), L.aMaskBase + 2 * (L.prefixA 6 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff ocH_GU8).1, Fp2.one), ((L.hOff ocH_GU8).2, Block.fp2U)],
        L.hLog.getD ocH_GU8 0, rhoC 0 (L.hLog.getD ocH_GU8 0), L.hMaskBase + 2 * (L.prefixH 6 + 0), 0⟩
    ], tabPoly mu zeta hist.alpha, []⟩ := by
  intro L dr mu zeta gU8; unfold outcDefTAB
  have h1 := nonzeroE_stgWords_ok U hbij hU O.ltab 2 (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  have h2 := nz1_stgWords_ok U hbij hU (O.ltab + 2) (by omega) y
    (fun i hi => hZ i (Z_range_subset (by omega) (by omega) hi))
  change (StageV.nonzeroE ((dr.drop O.ltab).take 2) >>= fun mu' =>
    StageV.nz1 dr (O.ltab + 2) >>= fun zeta' => _) = _
  rw [h1, h2]; dsimp only [Bind.bind, Except.bind]
  refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_eqT _ _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_aT L 6 ocC_MULT _ (show 0 < 1 by norm_num)) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_hT L 6 ocH_GU8 _ (show 0 < 1 by norm_num)) ?_
  exact sbm_finishT L 6 _ [] _ rfl rfl rfl

theorem outcDefTAB_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (O : OutcPub) (G : OutcGeo) (hist : Block.Hist)
    (y : Fin M → K) (hZ : ∃ i ∈ Z_range M O.ltab 3, y i = 0) :
    ∃ msg, outcDefTAB O G hist (stgWords U hbij y) = .error msg := by
  obtain ⟨i, hi, hy0⟩ := hZ; unfold outcDefTAB
  rcases Z_range_split (a := 2) (b := 1) hi with hi1 | hi2
  · exact except_err_2 _ _ _ (Or.inl ⟨_, nonzeroE_stgWords_err U hbij hU O.ltab 2 y i hi1 hy0⟩)
  · exact except_err_2 _ _ _ (Or.inr ⟨_, nz1_stgWords_err U hbij hU (O.ltab + 2) y i hi2 hy0⟩)

theorem outcDefZS_ok (O : OutcPub) (G : OutcGeo) :
    let L := outcLay O G.bLogN
    outcDefZS O G = .ok ⟨[
      .pub (List.replicate (2 ^ L.hLog.getD ocH_U 0) Fp2.one),
      .priv ⟨.h, [((L.hOff ocH_U).1, Fp2.one), ((L.hOff ocH_U).2, Block.fp2U)],
        L.hLog.getD ocH_U 0, rhoC 0 (L.hLog.getD ocH_U 0), L.hMaskBase + 2 * (L.prefixH 7 + 0), 0⟩
    ], zsPoly, []⟩ := by
  intro L; unfold outcDefZS; refine build_of_run_ex ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_pubT _ _) ?_
  refine sbm_bind_ok _ _ _ _ _ _ (sbm_hT L 7 ocH_U _ (show 0 < 1 by norm_num)) ?_
  exact sbm_finishT L 7 zsPoly [] _ rfl rfl rfl

end UnfoldDefs

/-! ## 4. Stage IN-C (`sshΦIC` at per-slot IO widths) `OffZero` and `ssh_inc_rbrC` -/

section IncRbr

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {L : ℕ}
variable (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (h64 : 64 ≤ L)

omit [Fintype K] [DecidableEq K] in
theorem inc_slot0_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vi : IncV) (ch : List Fp2)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vi.pub.lt ≤ lc) (hIO0 : StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) csIO)
    (hd : List (List Fp2)) (hhd : hd.length = 0) :
    ∃ Pp : (Fin (P0.draws 0) → K) → K,
      IndDegLE 1 Pp ∧ OffZero ∅ (fun y => stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch))
        (incElog Vi.pub Vi.geo.bLogN) (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (Fp2.zero, Fp2.zero, Fp2.zero) hd 0 (stgWords U hbij y)) Pp := by
  let I := Vi.pub
  let G := Vi.geo
  let L0 := incLay I G.bLogN
  let lw := clog2 I.inEpWords
  have hdraws : P0.draws 0 = lw := by rw [hP.1]; rfl
  refine offZero_standalone_drawC U hbij hU tag h64 P0 (Vi.bp (incCtx I ch)) (incElog I G.bLogN) hP
    lc h Q eC rA rH iA iH (IncPrivIO0 I) csIO v hlc (Fp2.zero, Fp2.zero, Fp2.zero) hd
    0 lw 1 3 lw 1 hIO0 hhd (by omega) le_rfl rfl rfl ∅
    [.pub (supp I.tokens I.inEpWords),
     .priv ⟨.a, [(L0.aOff incA_TOK, Fp2.one)], L0.aLog.getD incA_TOK 0,
       fixedC (List.replicate (I.tiLog - lw) Fp2.zero) ++ rhoC 0 lw,
       L0.aMaskBase + 2 * (L0.prefixA 0 + 0), 0⟩,
     .priv ⟨.inp, [(0, Fp2.one)], lw, rhoC 0 lw, G.epDataRows, 0⟩]
    (fun _ vals => (vg vals 0).mul ((vg vals 3).sub ((vg vals 1).mul (vg vals 2))))
    (fun y _ => incDefIO_ok I G (stgWords U hbij y))
    (fun _ ⟨_, hi, _⟩ => by simp at hi)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht
      · exact tabPrivOK_pub _ _
      · rcases List.mem_cons.mp ht with rfl | ht
        · exact tabPrivOK_a_fixed_rho _ _ _ _ _ _
        · rcases List.mem_cons.mp ht with rfl | ht
          · exact tabPrivOK_inc_io0 I _
          · exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun _ g => g 0 * (g 3 - g 1 * g 2))
    (fun _ _ vals hv => by
      rw [Fp2.toK_mul U hU, Fp2.toK_sub U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, vg_toK_map, vg_toK_map, vg_toK_map, vg_toK_map])
    (fun _ _ g hg => by
      have hsub : IndDegLE 2 (fun x => g 3 x - g 1 x * g 2 x) :=
        IndDegLE.sub (IndDegLE.mono (hg 3) (by norm_num)) (IndDegLE.mul (hg 1) (hg 2))
      simpa using IndDegLE.mul (hg 0) hsub)
    (fun x rt => IndDegLE_mulc (indDegLE_eqDrawK lw lw 1 (by omega) x) (rt 2 - rt 0 * rt 1))

omit [Fintype K] [DecidableEq K] in
theorem inc_slot1_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vi : IncV) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vi.pub.lt ≤ lc) (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO)
    (hd : List (List Fp2)) (hhd : hd.length = 1) :
    ∃ Pp : (Fin (P0.draws 1) → K) → K,
      IndDegLE 1 Pp ∧ OffZero (Z_range (P0.draws 1) Vi.pub.tiLog 5)
        (fun y => stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch))
          (incElog Vi.pub Vi.geo.bLogN) (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          (Fp2.zero, Fp2.zero, Fp2.zero) hd 1 (stgWords U hbij y)) Pp := by
  let I := Vi.pub
  let G := Vi.geo
  let cx := incCtx I ch
  let L0 := incLay I G.bLogN
  let tl := I.tiLog
  let sn := 2 ^ tl
  let b2 := cx.beta.mul cx.beta
  have hdraws : P0.draws 1 = tl + 5 := by rw [hP.1]; show tl + 4 + 1 = tl + 5; omega
  have hbeta : cx.beta.Canon := Fp2.canon_getD hch 0
  have halpha : cx.alpha.Canon := Fp2.canon_getD hch 2
  have hgemb : cx.gEmb.Canon := Fp2.canon_mulBase _ _
  have hremb : ∀ a ∈ cx.rEmb, a.Canon := fun a ha => hch a (List.mem_of_mem_drop ha)
  have hj0 : tl < P0.draws 1 := by omega
  have hj1 : tl + 1 < P0.draws 1 := by omega
  have hj2 : tl + 2 < P0.draws 1 := by omega
  have hj3 : tl + 3 < P0.draws 1 := by omega
  have hj4 : tl + 4 < P0.draws 1 := by omega
  refine offZero_standalone_drawC U hbij hU tag h64 P0 (Vi.bp cx) (incElog I G.bLogN) hP
    lc h Q eC rA rH iA iH (IncPrivIO1 I) csIO v hlc (Fp2.zero, Fp2.zero, Fp2.zero) hd
    1 tl 1 4 tl 1 hIO1 hhd (by omega) le_rfl rfl rfl (Z_range (P0.draws 1) tl 5)
    [.pub (supp I.tokens sn),
     .pub (supp 1 sn),
     .pub ((List.range sn).map (fun t => if I.isTemplate t then Fp2.one else Fp2.zero)),
     .pub ((List.range sn).map (fun t => kI (I.kappa t))),
     .pub ((List.range sn).map (fun t => if I.ctlQ t then b2 else Fp2.zero)),
     .priv ⟨.a, [(L0.aOff incA_TOK, Fp2.one)], L0.aLog.getD incA_TOK 0,
       rhoC 0 (L0.aLog.getD incA_TOK 0), L0.aMaskBase + 2 * (L0.prefixA 1 + 0), 0⟩,
     .priv ⟨.h, [((L0.hOff incH_Q).1, Fp2.one), ((L0.hOff incH_Q).2, Block.fp2U)],
       L0.hLog.getD incH_Q 0, rhoC 0 (L0.hLog.getD incH_Q 0), L0.hMaskBase + 2 * (L0.prefixH 1 + 0), 0⟩,
     .priv ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (tl - I.tBits) tl ++ fixedC cx.rEmb, G.bInRow, 0⟩]
    (fun y vals =>
      let dr := stgWords U hbij y
      let mu := (dr.drop tl).take 4
      let zeta := (((dr.drop (tl + 4)).take 1).getD 0 Fp2.zero)
      let q := (((vg vals 6).add (cx.beta.mul (vg vals 8))).add (vg vals 5)).add cx.gEmb
      let logup := ((vg vals 7).mul (cx.alpha.sub q)).sub (vg vals 1)
      let bosC := (vg vals 2).mul ((vg vals 6).sub (kI I.bos))
      let tmpl := (vg vals 3).mul ((vg vals 6).sub (vg vals 4))
      let pad := (Fp2.one.sub (vg vals 1)).mul ((vg vals 6).add (zeta.mul (vg vals 7)))
      (vg vals 0).mul (((((vg mu 0).mul logup).add ((vg mu 1).mul bosC)).add ((vg mu 2).mul tmpl)).add
        ((vg mu 3).mul pad)))
    (fun y hZ => incDefQZC_ok U hbij hU I G cx hdraws y hZ)
    (fun y hZ => incDefQZC_err U hbij hU I G cx y hZ)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_inc_io1 I _ _ _ _ hremb
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun y g =>
      let qK := ((g 6 + cx.beta.toK U * g 8) + g 5) + cx.gEmb.toK U
      let logupK := g 7 * (cx.alpha.toK U - qK) - g 1
      let bosK := g 2 * (g 6 - (kI I.bos).toK U)
      let tmplK := g 3 * (g 6 - g 4)
      let padK := (1 - g 1) * (g 6 + y ⟨tl + 4, hj4⟩ * g 7)
      g 0 * ((((y ⟨tl, hj0⟩ * logupK) + (y ⟨tl + 1, hj1⟩ * bosK)) + (y ⟨tl + 2, hj2⟩ * tmplK))
        + (y ⟨tl + 3, hj3⟩ * padK)))
    (fun y _ vals hv => by
      have hz_eq : ((((stgWords U hbij y).drop (tl + 4)).take 1).getD 0 Fp2.zero).toK U = y ⟨tl + 4, hj4⟩ := by
        rw [getD_take_lt _ 1 0 (by norm_num), getD_drop]
        exact stgWords_getD_toK U hbij y (tl + 4) hj4
      dsimp only
      rw [Fp2.toK_mul U hU,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y tl 4 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y tl 4 1 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y tl 4 2 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y tl 4 3 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (vg_canon hv 1),
          Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ halpha (Fp2.canon_add _ _),
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) hgemb,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (vg_canon hv 5),
          Fp2.toK_add U _ _ (vg_canon hv 6) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (vg_canon hv 6) (kI_canon _),
          Fp2.toK_sub U _ _ (vg_canon hv 6) (vg_canon hv 4),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 6) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          hz_eq]
      simp only [vg_toK_map]
      rfl)
    (fun y _ g hg => by
      have hq : IndDegLE 1 (fun x => ((g 6 x + cx.beta.toK U * g 8 x) + g 5 x) + cx.gEmb.toK U) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.add (hg 6) (IndDegLE.cmul _ (hg 8))) (hg 5)) (IndDegLE.const _)
      have hl : IndDegLE 2 (fun x => g 7 x * (cx.alpha.toK U - (((g 6 x + cx.beta.toK U * g 8 x) + g 5 x) + cx.gEmb.toK U)) - g 1 x) :=
        IndDegLE.sub (IndDegLE.mul (hg 7) (IndDegLE.sub (IndDegLE.const _) hq)) (IndDegLE.mono (hg 1) (by norm_num))
      have hb : IndDegLE 2 (fun x => g 2 x * (g 6 x - (kI I.bos).toK U)) :=
        IndDegLE.mul (hg 2) (IndDegLE.sub (hg 6) (IndDegLE.const _))
      have htm : IndDegLE 2 (fun x => g 3 x * (g 6 x - g 4 x)) :=
        IndDegLE.mul (hg 3) (IndDegLE.sub (hg 6) (hg 4))
      have hpd : IndDegLE 2 (fun x => (1 - g 1 x) * (g 6 x + y ⟨tl + 4, hj4⟩ * g 7 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1))
          (IndDegLE.add (hg 6) (IndDegLE.cmul _ (hg 7)))
      have hsum : IndDegLE 2 (fun x =>
          (((y ⟨tl, hj0⟩ * (g 7 x * (cx.alpha.toK U - (((g 6 x + cx.beta.toK U * g 8 x) + g 5 x) + cx.gEmb.toK U)) - g 1 x))
            + (y ⟨tl + 1, hj1⟩ * (g 2 x * (g 6 x - (kI I.bos).toK U))))
            + (y ⟨tl + 2, hj2⟩ * (g 3 x * (g 6 x - g 4 x))))
            + (y ⟨tl + 3, hj3⟩ * ((1 - g 1 x) * (g 6 x + y ⟨tl + 4, hj4⟩ * g 7 x)))) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.add (IndDegLE.cmul _ hl) (IndDegLE.cmul _ hb)) (IndDegLE.cmul _ htm))
          (IndDegLE.cmul _ hpd)
      exact IndDegLE.mono (IndDegLE.mul (hg 0) hsum) (by norm_num))
    (fun x rt => by
      dsimp only
      refine indDegLE_eq_mul_upper tl tl 1 1 le_rfl (by omega) x _ ?_ (fun i hi y t => ?_)
      · refine IndDegLE.add (IndDegLE.add (IndDegLE.add
            (IndDegLE_mulc (indDegLE_coord ⟨tl, hj0⟩) _)
            (IndDegLE_mulc (indDegLE_coord ⟨tl + 1, hj1⟩) _))
            (IndDegLE_mulc (indDegLE_coord ⟨tl + 2, hj2⟩) _))
          (indDegLE_mu_pad ⟨tl + 3, hj3⟩ ⟨tl + 4, hj4⟩
            (fun he => by have := congrArg Fin.val he; dsimp only at this; omega) _ _ _)
      · rw [update_lt_get y t i tl tl hi le_rfl hj0,
            update_lt_get y t i tl (tl + 1) hi (by omega) hj1,
            update_lt_get y t i tl (tl + 2) hi (by omega) hj2,
            update_lt_get y t i tl (tl + 3) hi (by omega) hj3,
            update_lt_get y t i tl (tl + 4) hi (by omega) hj4])

omit [Fintype K] [DecidableEq K] in
theorem inc_slot2_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vi : IncV) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vi.pub.lt ≤ lc) (hd : List (List Fp2)) (hhd : hd.length = 2) :
    ∃ Pp : (Fin (P0.draws 2) → K) → K,
      IndDegLE 1 Pp ∧ OffZero (Z_range (P0.draws 2) Vi.pub.vocLog 3)
        (fun y => stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch))
          (incElog Vi.pub Vi.geo.bLogN) (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          (Fp2.zero, Fp2.zero, Fp2.zero) hd 2 (stgWords U hbij y)) Pp := by
  let I := Vi.pub
  let G := Vi.geo
  let cx := incCtx I ch
  let L0 := incLay I G.bLogN
  let lv := I.vocLog
  have hdraws : P0.draws 2 = lv + 3 := by rw [hP.1]; show lv + 2 + 1 = lv + 3; omega
  have halpha : cx.alpha.Canon := Fp2.canon_getD hch 2
  have hj0 : lv < P0.draws 2 := by omega
  have hj1 : lv + 1 < P0.draws 2 := by omega
  have hj2 : lv + 2 < P0.draws 2 := by omega
  have hIO_vac : StgCsIODeg U hbij (incElog I G.bLogN 2) (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  refine offZero_standalone_drawC U hbij hU tag h64 P0 (Vi.bp cx) (incElog I G.bLogN) hP
    lc h Q eC rA rH iA iH (fun _ => False) csIO v hlc (Fp2.zero, Fp2.zero, Fp2.zero) hd
    2 lv 1 4 lv 1 hIO_vac hhd (by omega) le_rfl rfl rfl (Z_range (P0.draws 2) lv 3)
    [.pub (supp I.v (2 ^ lv)),
     .pub cx.tauTab,
     .priv ⟨.a, [(L0.aOff incA_MULT, Fp2.one)], L0.aLog.getD incA_MULT 0,
       rhoC 0 (L0.aLog.getD incA_MULT 0), L0.aMaskBase + 2 * (L0.prefixA 2 + 0), 0⟩,
     .priv ⟨.h, [((L0.hOff incH_TAB).1, Fp2.one), ((L0.hOff incH_TAB).2, Block.fp2U)],
       L0.hLog.getD incH_TAB 0, rhoC 0 (L0.hLog.getD incH_TAB 0), L0.hMaskBase + 2 * (L0.prefixH 2 + 0), 0⟩]
    (fun y vals =>
      let dr := stgWords U hbij y
      let mu := (dr.drop lv).take 2
      let zeta := (((dr.drop (lv + 2)).take 1).getD 0 Fp2.zero)
      let rel := ((vg vals 4).mul (cx.alpha.sub (vg vals 2))).sub (vg vals 3)
      let pad := (Fp2.one.sub (vg vals 1)).mul ((vg vals 3).add (zeta.mul (vg vals 4)))
      (vg vals 0).mul (((vg mu 0).mul rel).add ((vg mu 1).mul pad)))
    (fun y hZ => incDefTZC_ok U hbij hU I G cx hdraws y hZ)
    (fun y hZ => incDefTZC_err U hbij hU I G cx y hZ)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun y g =>
      g 0 * ((y ⟨lv, hj0⟩ * (g 4 * (cx.alpha.toK U - g 2) - g 3))
        + (y ⟨lv + 1, hj1⟩ * ((1 - g 1) * (g 3 + y ⟨lv + 2, hj2⟩ * g 4)))))
    (fun y _ vals hv => by
      have hz_eq : ((((stgWords U hbij y).drop (lv + 2)).take 1).getD 0 Fp2.zero).toK U = y ⟨lv + 2, hj2⟩ := by
        rw [getD_take_lt _ 1 0 (by norm_num), getD_drop]
        exact stgWords_getD_toK U hbij y (lv + 2) hj2
      dsimp only
      rw [Fp2.toK_mul U hU, Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y lv 2 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y lv 2 1 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (vg_canon hv 3),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ halpha (vg_canon hv 2),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _), Fp2.toK_mul U hU, hz_eq]
      simp only [vg_toK_map]
      rfl)
    (fun y _ g hg => by
      have hrel : IndDegLE 2 (fun x => g 4 x * (cx.alpha.toK U - g 2 x) - g 3 x) :=
        IndDegLE.sub (IndDegLE.mul (hg 4) (IndDegLE.sub (IndDegLE.const _) (hg 2)))
          (IndDegLE.mono (hg 3) (by norm_num))
      have hpad : IndDegLE 2 (fun x => (1 - g 1 x) * (g 3 x + y ⟨lv + 2, hj2⟩ * g 4 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1))
          (IndDegLE.add (hg 3) (IndDegLE.cmul _ (hg 4)))
      exact IndDegLE.mono
        (IndDegLE.mul (hg 0) (IndDegLE.add (IndDegLE.cmul _ hrel) (IndDegLE.cmul _ hpad))) (by norm_num))
    (fun x rt => by
      dsimp only
      refine indDegLE_eq_mul_upper lv lv 1 1 le_rfl (by omega) x _ ?_ (fun i hi y t => ?_)
      · exact IndDegLE.add (IndDegLE_mulc (indDegLE_coord ⟨lv, hj0⟩) _)
          (indDegLE_mu_pad ⟨lv + 1, hj1⟩ ⟨lv + 2, hj2⟩
            (fun he => by have := congrArg Fin.val he; dsimp only at this; omega) _ _ _)
      · rw [update_lt_get y t i lv lv hi le_rfl hj0,
            update_lt_get y t i lv (lv + 1) hi (by omega) hj1,
            update_lt_get y t i lv (lv + 2) hi (by omega) hj2])

/-- **ROUND-BY-ROUND SOUNDNESS FOR ALL STAGE IN-C DEFINE DRAWS (`sshΦIC` at `sshDgI`)**. -/
theorem ssh_inc_rbrC (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8))
    (hPin : ∀ cx, StgSame P0 (Vi.bp cx))
    (hlc : Vi.pub.lt ≤ lc)
    (hIO0 : StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) csIO)
    (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO) :
    ∀ k, (stgDefSqV P0 m hdrLen absOf (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO) sshDgI k).Rbr := by
  intro k
  rcases k with _ | _ | _ | k
  · exact ssh_rbrIC_canon U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO absOf sshDgI 0 1 ∅ rfl
      (fun v hh _ _ hk => inc_slot0_offZero U hbij tag h64 hU P0 Vi hh.1 (hPin _) lc h Q e rA rH
        hdrLen (hdrLen + 4 + m) csIO v hlc hIO0 hh.2 hk)
  · exact ssh_rbrIC_canon U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO absOf sshDgI 1 1
      (Z_range (P0.draws 1) Vi.pub.tiLog 5) rfl
      (fun v hh hcan _ hk => inc_slot1_offZero U hbij tag h64 hU P0 Vi hh.1 hcan (hPin _) lc h Q e rA rH
        hdrLen (hdrLen + 4 + m) csIO v hlc hIO1 hh.2 hk)
  · exact ssh_rbrIC_canon U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO absOf sshDgI 2 1
      (Z_range (P0.draws 2) Vi.pub.vocLog 3) rfl
      (fun v hh hcan _ hk => inc_slot2_offZero U hbij tag h64 hU P0 Vi hh.1 hcan (hPin _) lc h Q e rA rH
        hdrLen (hdrLen + 4 + m) csIO v hlc hh.2 hk)
  · intro _ _ τ _ hτ
    have hn : (stgDefSqV P0 m hdrLen absOf
        (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO) sshDgI (k + 1 + 1 + 1)).n = 0 := by
      show P0.draws (k + 3) = 0
      rw [(hPin (incCtx Vi.pub [])).1]; rfl
    rw [hn] at hτ
    exact absurd hτ (Nat.not_lt_zero _)

end IncRbr

/-! ## 5. Stage OUT-C (`sshΦO`) hosted slot degrees, `OffZero` bridges, and `ssh_outc_rbr` -/

section OutcRbr

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {L : ℕ}
variable (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (h64 : 64 ≤ L)

omit [Fintype K] [DecidableEq K] in
theorem outc_ss_spT_deg (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) :
    IndDegLE (Block.slotShape P0 1).2.2
      (stgSpT U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd 1) := by
  let O := Vo.pub; let G := Vo.geo; let L0 := outcLay O G.bLogN
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  exact (stgSpT_eval_and_deg U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v
    hlc hIO_vac bga hd 1 O.ldo 1 4 rfl
    [.pub (supp O.d (2 ^ O.ldo)),
     .priv ⟨.a, [(L0.aOff ocC_X, Fp2.one)], L0.aLog.getD ocC_X 0,
       rhoC 0 (L0.aLog.getD ocC_X 0), L0.aMaskBase + 2 * (L0.prefixA 1 + 0), 0⟩]
    ssPoly [] (outcDefSS_ok O G)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun g => (g 0 * g 1) * g 1)
    (fun vals _ => by unfold ssPoly; rw [Fp2.toK_mul U hU, Fp2.toK_mul U hU, vg_toK_map, vg_toK_map])
    (fun g hg => IndDegLE.mono (IndDegLE.mul (IndDegLE.mul (hg 0) (hg 1)) (hg 1)) (by norm_num))).2

omit [Fintype K] [DecidableEq K] in
theorem outc_pd_spT_deg (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) :
    IndDegLE (Block.slotShape P0 3).2.2
      (stgSpT U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd 3) := by
  let O := Vo.pub; let G := Vo.geo; let L0 := outcLay O G.bLogN
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  exact (stgSpT_eval_and_deg U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v
    hlc hIO_vac bga hd 3 O.dBits 1 2 rfl
    [.priv ⟨.a, [(L0.aOff ocC_Y, Fp2.one)], L0.aLog.getD ocC_Y 0,
       fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits,
       L0.aMaskBase + 2 * (L0.prefixA 3 + 0), 0⟩,
     .pub (wTab O.dPad (O.wDelta.take O.d))]
    pdPoly [] (outcDefPD_ok O G)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_fixed_rho _ _ _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun g => g 0 * g 1)
    (fun vals _ => by unfold pdPoly; rw [Fp2.toK_mul U hU, vg_toK_map, vg_toK_map])
    (fun g hg => IndDegLE.mul (hg 0) (hg 1))).2

omit [Fintype K] [DecidableEq K] in
theorem outc_slot0_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (hIO : StgCsIODeg U hbij Vo.geo.bLogN (OutcPrivIO Vo.pub) csIO)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (hhd : hd.length = 0) :
    ∃ Pp : (Fin (P0.draws 0) → K) → K,
      IndDegLE 1 Pp ∧ OffZero ∅
        (fun y => stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd 0 (stgWords U hbij y)) Pp := by
  let O := Vo.pub; let G := Vo.geo; let L0 := outcLay O G.bLogN
  have hdraws : P0.draws 0 = O.dBits := by rw [hP.1]; rfl
  refine offZero_standalone_draw U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (OutcPrivIO O) csIO v
    hlc hIO bga hd 0 O.dBits 1 2 O.dBits 1 hhd (by omega) le_rfl rfl rfl ∅
    [.priv ⟨.a, [(L0.aOff ocC_X, Fp2.one)], L0.aLog.getD ocC_X 0,
       fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits,
       L0.aMaskBase + 2 * (L0.prefixA 0 + 0), 0⟩,
     .priv ⟨.inp, [(0, Fp2.one)], O.bOutLog,
       fixedBits O.verdictRow O.tBits ++ rhoC 0 O.dBits, G.bOutRow, 0⟩]
    (fun _ => ioPoly)
    (fun y _ => outcDefIO_ok O G (stgWords U hbij y))
    (fun _ ⟨_, hi, _⟩ => by simp at hi)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_fixed_rho _ _ _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_outc_io0 O _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun _ g => g 0 * (g 1 - g 2))
    (fun _ _ vals hv => by
      unfold ioPoly
      rw [Fp2.toK_mul U hU, Fp2.toK_sub U _ _ (vg_canon hv 1) (vg_canon hv 2),
          vg_toK_map, vg_toK_map, vg_toK_map])
    (fun _ _ g hg => IndDegLE.mul (hg 0) (IndDegLE.sub (hg 1) (hg 2)))
    (fun x rt => IndDegLE_mulc (indDegLE_eqDrawK O.dBits O.dBits 1 (by omega) x) (rt 0 - rt 1))

omit [Fintype K] [DecidableEq K] in
theorem outc_slot2_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (hhd : hd.length = 2) :
    ∃ Pp : (Fin (P0.draws 2) → K) → K,
      IndDegLE 1 Pp ∧ OffZero (Z_range (P0.draws 2) 1 6)
        (fun y => stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd 2 (stgWords U hbij y)) Pp := by
  let O := Vo.pub; let G := Vo.geo; let L0 := outcLay O G.bLogN
  have hdraws : P0.draws 2 = 7 := by rw [hP.1]; rfl
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have hj1 : 1 < P0.draws 2 := by omega
  have hj2 : 2 < P0.draws 2 := by omega
  have hj3 : 3 < P0.draws 2 := by omega
  have hj4 : 4 < P0.draws 2 := by omega
  have hj5 : 5 < P0.draws 2 := by omega
  have hj6 : 6 < P0.draws 2 := by omega
  refine offZero_host_draw U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v
    hlc hIO_vac bga hd 2 1 5 OutcPub.toLog 1 3 OutcPub.toLog 1 hhd (by norm_num) hj5 le_rfl
    (show OutcPub.toLog ≤ P0.draws 2 by show 1 ≤ P0.draws 2; omega) le_rfl rfl rfl
    (outc_ss_spT_deg U hbij tag h64 hU P0 Vo hP lc h Q eC rA rH iA iH csIO v hlc bga hd)
    (Z_range (P0.draws 2) 1 6)
    ([.pub (supp 1 (2 ^ OutcPub.toLog)),
      .priv ⟨.a, [(L0.aOff ocC_D, Fp2.one)], L0.aLog.getD ocC_D 0,
        rhoC 0 (L0.aLog.getD ocC_D 0), L0.aMaskBase + 2 * (L0.prefixA 2 + 0), 0⟩,
      .priv ⟨.a, [(L0.aOff ocC_DSQ, Fp2.one)], L0.aLog.getD ocC_DSQ 0,
        rhoC 0 (L0.aLog.getD ocC_DSQ 0), L0.aMaskBase + 2 * (L0.prefixA 2 + 1), 0⟩]
     ++ ((List.range (3 * OutcPub.limbsIsqrt)).zipIdx 2).map (fun p =>
       Block.Tab.priv ⟨.a, [(L0.aOff ocC_LIMB + 2 * p.1, Fp2.one)], OutcPub.toLog,
         rhoC 0 OutcPub.toLog, L0.aMaskBase + 2 * (L0.prefixA 2 + p.2), 0⟩))
    (fun y =>
      let dr := stgWords U hbij y
      tzcPoly ((dr.drop 1).take 4) (dr.getD 5 Fp2.zero) (dr.getD 6 Fp2.zero) (kI O.ceps))
    (fun y hZ => by dsimp only; exact outcDefTZC_ok U hbij hU O G hdraws y hZ)
    (fun y hZ => outcDefTZC_err U hbij hU O G y hZ)
    (fun t ht => by
      rcases List.mem_append.mp ht with ht1 | ht2
      · rcases List.mem_cons.mp ht1 with rfl | ht1; · exact tabPrivOK_pub _ _
        rcases List.mem_cons.mp ht1 with rfl | ht1; · exact tabPrivOK_a_rho _ _ _ _
        rcases List.mem_cons.mp ht1 with rfl | ht1; · exact tabPrivOK_a_rho _ _ _ _
        exact absurd ht1 List.not_mem_nil
      · obtain ⟨p, _, rfl⟩ := List.mem_map.mp ht2
        exact tabPrivOK_a_rho _ _ _ _)
    (fun t ht pt s he => by
      rcases List.mem_append.mp ht with ht1 | ht2
      · rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
        rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
        rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
        exact absurd ht1 List.not_mem_nil
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht2; cases he)
    (fun y g =>
      let dl := l3K g 4
      let a1 := l3K g 7
      let a2 := l3K g 10
      let pad := (1 - g 1) * (g 2 + y ⟨6, hj6⟩ * g 3)
      let zc := (((y ⟨1, hj1⟩ * (g 3 - g 2 * g 2)) + (y ⟨2, hj2⟩ * (g 2 - dl)))
        + (y ⟨3, hj3⟩ * (((g 2 + g 2) - a1) - a2))) + (y ⟨4, hj4⟩ * pad)
      (g 0 * zc) + ((y ⟨5, hj5⟩ * g 1) * ((g 3 + a1) - (kI O.ceps).toK U)))
    (fun y _ vals hv => by
      unfold tzcPoly
      rw [Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y 1 4 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y 1 4 1 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y 1 4 2 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y 1 4 3 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (vg_canon hv 2) (l3W_canon _ _),
          Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (l3W_canon _ _)) (l3W_canon _ _),
          Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (l3W_canon _ _),
          Fp2.toK_add U _ _ (vg_canon hv 2) (vg_canon hv 2),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 2) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (kI_canon _),
          Fp2.toK_add U _ _ (vg_canon hv 3) (l3W_canon _ _),
          stgWords_getD_toK U hbij y 5 hj5, stgWords_getD_toK U hbij y 6 hj6,
          l3W_toK U vals hv 4, l3W_toK U vals hv 7, l3W_toK U vals hv 10]
      simp only [vg_toK_map])
    (fun y _ g hg => by
      have hdl := indDegLE_l3K g hg 4
      have ha1 := indDegLE_l3K g hg 7
      have ha2 := indDegLE_l3K g hg 10
      have hc0 : IndDegLE 2 (fun x => g 3 x - g 2 x * g 2 x) :=
        IndDegLE.sub (IndDegLE.mono (hg 3) (by norm_num)) (IndDegLE.mul (hg 2) (hg 2))
      have hc1 : IndDegLE 2 (fun x => g 2 x - l3K (fun idx => g idx x) 4) :=
        IndDegLE.mono (IndDegLE.sub (hg 2) hdl) (by norm_num)
      have hc2 : IndDegLE 2 (fun x => ((g 2 x + g 2 x) - l3K (fun idx => g idx x) 7) - l3K (fun idx => g idx x) 10) :=
        IndDegLE.mono (IndDegLE.sub (IndDegLE.sub (IndDegLE.add (hg 2) (hg 2)) ha1) ha2) (by norm_num)
      have hpad : IndDegLE 2 (fun x => (1 - g 1 x) * (g 2 x + y ⟨6, hj6⟩ * g 3 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1))
          (IndDegLE.add (hg 2) (IndDegLE.cmul _ (hg 3)))
      have hzc : IndDegLE 2 (fun x =>
          (((y ⟨1, hj1⟩ * (g 3 x - g 2 x * g 2 x)) + (y ⟨2, hj2⟩ * (g 2 x - l3K (fun idx => g idx x) 4)))
            + (y ⟨3, hj3⟩ * (((g 2 x + g 2 x) - l3K (fun idx => g idx x) 7) - l3K (fun idx => g idx x) 10)))
            + (y ⟨4, hj4⟩ * ((1 - g 1 x) * (g 2 x + y ⟨6, hj6⟩ * g 3 x)))) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.add (IndDegLE.cmul _ hc0) (IndDegLE.cmul _ hc1)) (IndDegLE.cmul _ hc2))
          (IndDegLE.cmul _ hpad)
      have hhost : IndDegLE 2 (fun x => (y ⟨5, hj5⟩ * g 1 x) * ((g 3 x + l3K (fun idx => g idx x) 7) - (kI O.ceps).toK U)) :=
        IndDegLE.mul (IndDegLE.cmul _ (hg 1)) (IndDegLE.sub (IndDegLE.add (hg 3) ha1) (IndDegLE.const _))
      exact IndDegLE.add (IndDegLE.mul (hg 0) hzc) (IndDegLE.mono hhost (by norm_num)))
    (fun x rt => by
      dsimp only [l3K]
      have hto : OutcPub.toLog = 1 := rfl
      refine IndDegLE.add ?_ (IndDegLE_mulc (IndDegLE_mulc (indDegLE_coord ⟨5, hj5⟩) _) _)
      refine indDegLE_eq_mul_upper OutcPub.toLog OutcPub.toLog 1 1 le_rfl (by omega) x _ ?_ (fun i hi y t => ?_)
      · exact IndDegLE.add (IndDegLE.add (IndDegLE.add
            (IndDegLE_mulc (indDegLE_coord ⟨1, hj1⟩) _)
            (IndDegLE_mulc (indDegLE_coord ⟨2, hj2⟩) _))
            (IndDegLE_mulc (indDegLE_coord ⟨3, hj3⟩) _))
          (indDegLE_mu_pad ⟨4, hj4⟩ ⟨6, hj6⟩
            (fun he => by have := congrArg Fin.val he; dsimp only at this; omega) _ _ _)
      · rw [hto] at hi
        rw [update_lt_get y t i 1 1 hi le_rfl hj1,
            update_lt_get y t i 1 2 hi (by omega) hj2,
            update_lt_get y t i 1 3 hi (by omega) hj3,
            update_lt_get y t i 1 4 hi (by omega) hj4,
            update_lt_get y t i 1 6 hi (by omega) hj6])

omit [Fintype K] [DecidableEq K] in
theorem outc_slot4_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hd : List (List Fp2)) (hhd : hd.length = 4) :
    ∃ Pp : (Fin (P0.draws 4) → K) → K,
      IndDegLE 1 Pp ∧ OffZero (Z_range (P0.draws 4) Vo.pub.llo 3)
        (fun y => stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          (OutcV.bga ch) hd 4 (stgWords U hbij y)) Pp := by
  let O := Vo.pub; let G := Vo.geo; let L0 := outcLay O G.bLogN
  let llo := O.llo
  let loN := 2 ^ llo
  let bga := OutcV.bga ch
  let alpha := ch.getD 1 Fp2.zero
  let gU8 := (ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))
  let kc := (kI O.verdict).add (kI O.c)
  have hdraws : P0.draws 4 = llo + 3 := by rw [hP.1]; show llo + 2 + 1 = llo + 3; omega
  have halpha : alpha.Canon := Fp2.canon_getD hch 1
  have hgU8 : gU8.Canon := Fp2.canon_mulBase _ _
  have hkc : kc.Canon := Fp2.canon_add _ _
  have hj0 : llo < P0.draws 4 := by omega
  have hj1 : llo + 1 < P0.draws 4 := by omega
  have hj2 : llo + 2 < P0.draws 4 := by omega
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  refine offZero_host_draw U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v
    hlc hIO_vac bga hd 4 3 (llo + 2) llo 1 4 llo 1 hhd (by norm_num) hj2 le_rfl (by omega) le_rfl rfl rfl
    (outc_pd_spT_deg U hbij tag h64 hU P0 Vo hP lc h Q eC rA rH iA iH csIO v hlc bga hd)
    (Z_range (P0.draws 4) llo 3)
    [.pub (liveTab loN OutcPub.lamBase O.limbs),
     .pub (gTab loN OutcPub.lamBase O.limbs O.verdict),
     .pub (supp 1 loN),
     .priv ⟨.a, [(L0.aOff ocC_LIMB, Fp2.one)], L0.aLog.getD ocC_LIMB 0,
       rhoC 0 (L0.aLog.getD ocC_LIMB 0), L0.aMaskBase + 2 * (L0.prefixA 4 + 0), 0⟩,
     .priv ⟨.h, [((L0.hOff ocH_LO).1, Fp2.one), ((L0.hOff ocH_LO).2, Block.fp2U)],
       L0.hLog.getD ocH_LO 0, rhoC 0 (L0.hLog.getD ocH_LO 0), L0.hMaskBase + 2 * (L0.prefixH 4 + 0), 0⟩]
    (fun y =>
      let dr := stgWords U hbij y
      lzcPoly ((dr.drop llo).take 2) (dr.getD (llo + 2) Fp2.zero) alpha gU8 kc)
    (fun y hZ => outcDefLZC_ok U hbij hU O G ⟨bga.1, bga.2.1, bga.2.2, hd⟩ hdraws y hZ)
    (fun y hZ => outcDefLZC_err U hbij hU O G ⟨bga.1, bga.2.1, bga.2.2, hd⟩ y hZ)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun y g =>
      let helperK := 0 + 1 * ((g 5 * denK U (alpha.toK U) (gU8.toK U) g 4 1 0) - 1)
      let padK := (1 - g 1) * g 4
      let hostK := (g 2 * g 4) + (g 3 * kc.toK U)
      (g 0 * ((y ⟨llo, hj0⟩ * helperK) + (y ⟨llo + 1, hj1⟩ * padK))) + (y ⟨llo + 2, hj2⟩ * hostK))
    (fun y _ vals hv => by
      unfold lzcPoly
      rw [Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y llo 2 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y llo 2 1 (by norm_num) (by omega),
          Fp2.toK_add U _ _ Fp2.canon_zero (Fp2.canon_mul _ _), Fp2.toK_zero,
          Fp2.toK_mul U hU, Fp2.toK_one,
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) Fp2.canon_one, Fp2.toK_one,
          Fp2.toK_mul U hU, denW_toK U vals alpha gU8 halpha hgU8 4 1 0,
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_mul U hU, stgWords_getD_toK U hbij y (llo + 2) hj2,
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU]
      simp only [vg_toK_map, Nat.add_zero])
    (fun y _ g hg => by
      have hh : IndDegLE 2 (fun x => (0 : K) + 1 * ((g 5 x * denK U (alpha.toK U) (gU8.toK U) (fun idx => g idx x) 4 1 0) - 1)) :=
        IndDegLE.add (IndDegLE.const 0)
          (IndDegLE.cmul 1 (IndDegLE.sub (IndDegLE.mul (hg 5) (indDegLE_denK U _ _ g hg 4 1 0)) (IndDegLE.const 1)))
      have hp : IndDegLE 2 (fun x => (1 - g 1 x) * g 4 x) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1)) (hg 4)
      have hho : IndDegLE 2 (fun x => (g 2 x * g 4 x) + (g 3 x * kc.toK U)) :=
        IndDegLE.add (IndDegLE.mul (hg 2) (hg 4)) (IndDegLE.mono (IndDegLE_mulc (hg 3) _) (by norm_num))
      exact IndDegLE.mono (IndDegLE.add
        (IndDegLE.mul (hg 0) (IndDegLE.add (IndDegLE.cmul _ hh) (IndDegLE.cmul _ hp)))
        (IndDegLE.mono (IndDegLE.cmul _ hho) (by norm_num))) (by norm_num))
    (fun x rt => by
      dsimp only [denK]
      refine IndDegLE.add ?_ (IndDegLE_mulc (indDegLE_coord ⟨llo + 2, hj2⟩) _)
      refine indDegLE_eq_mul_upper llo llo 1 1 le_rfl (by omega) x _ ?_ (fun i hi y t => ?_)
      · exact IndDegLE.add (IndDegLE_mulc (indDegLE_coord ⟨llo, hj0⟩) _)
          (IndDegLE_mulc (indDegLE_coord ⟨llo + 1, hj1⟩) _)
      · rw [update_lt_get y t i llo llo hi le_rfl hj0,
            update_lt_get y t i llo (llo + 1) hi (by omega) hj1])

omit [Fintype K] [DecidableEq K] in
theorem outc_slot5_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hd : List (List Fp2)) (hhd : hd.length = 5) :
    ∃ Pp : (Fin (P0.draws 5) → K) → K,
      IndDegLE 11 Pp ∧ OffZero (Z_range (P0.draws 5) Vo.pub.ldo 11)
        (fun y => stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          (OutcV.bga ch) hd 5 (stgWords U hbij y)) Pp := by
  let O := Vo.pub; let G := Vo.geo; let L0 := outcLay O G.bLogN
  let ldo := O.ldo
  let bga := OutcV.bga ch
  let alpha := ch.getD 1 Fp2.zero
  let gU8 := (ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))
  let kNum := kI (2 * O.g0 * O.cn)
  let kDv := kI (2 ^ O.tn)
  let kDen := kI (2 ^ (O.tn + 1))
  have hdraws : P0.draws 5 = ldo + 11 := by rw [hP.1]; show ldo + 10 + 1 = ldo + 11; omega
  have halpha : alpha.Canon := Fp2.canon_getD hch 1
  have hgU8 : gU8.Canon := Fp2.canon_mulBase _ _
  have hmu_lt : ∀ kk, kk < 10 → ldo + kk < P0.draws 5 := fun kk hkk => by omega
  have hzeta_lt : ldo + 10 < P0.draws 5 := by omega
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  refine offZero_standalone_draw U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v
    hlc hIO_vac bga hd 5 ldo 1 5 ldo 11 hhd (by omega) le_rfl rfl rfl (Z_range (P0.draws 5) ldo 11)
    (.pub (supp O.d (2 ^ ldo)) :: (
      ((List.range' ocC_X (ocC_MULT - ocC_X)).zipIdx 0).map (fun p =>
        Block.Tab.priv ⟨.a, [(L0.aOff p.1, Fp2.one)], L0.aLog.getD p.1 0,
          rhoC 0 (L0.aLog.getD p.1 0), L0.aMaskBase + 2 * (L0.prefixA 5 + p.2), 0⟩)
      ++ [.priv ⟨.a, [(L0.aOff ocC_D, Fp2.one)], L0.aLog.getD ocC_D 0,
          fixedC (List.replicate OutcPub.toLog Fp2.zero),
          L0.aMaskBase + 2 * (L0.prefixA 5 + (0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length)), 0⟩]
      ++ ((List.range 6).zipIdx 0).map (fun p =>
        let pl := ocH_D0 + p.1
        Block.Tab.priv ⟨.h, [((L0.hOff pl).1, Fp2.one), ((L0.hOff pl).2, Block.fp2U)],
          L0.hLog.getD pl 0, rhoC 0 (L0.hLog.getD pl 0),
          L0.hMaskBase + 2 * (L0.prefixH 5 + p.2), 0⟩)))
    (fun y =>
      let dr := stgWords U hbij y
      dzcPoly ((dr.drop ldo).take 10) (dr.getD (ldo + 10) Fp2.zero) alpha gU8 kNum kDv kDen)
    (fun y hZ => by
      dsimp only
      exact outcDefDZC_ok U hbij hU O G ⟨bga.1, bga.2.1, bga.2.2, hd⟩ hdraws y hZ)
    (fun y hZ => outcDefDZC_err U hbij hU O G ⟨bga.1, bga.2.1, bga.2.2, hd⟩ y hZ)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht
      · exact tabPrivOK_pub _ _
      · rcases List.mem_append.mp ht with ht12 | ht3
        · rcases List.mem_append.mp ht12 with ht1 | ht2
          · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht1
            exact tabPrivOK_a_rho _ _ _ _
          · rcases List.mem_cons.mp ht2 with rfl | ht2
            · exact tabPrivOK_a_fixed _ _ _ _ _
            · exact absurd ht2 List.not_mem_nil
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht3
          exact tabPrivOK_h_rho _ _ _ _ _)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_append.mp ht with ht12 | ht3
      · rcases List.mem_append.mp ht12 with ht1 | ht2
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht1; cases he
        · rcases List.mem_cons.mp ht2 with rfl | ht2; · cases he
          exact absurd ht2 List.not_mem_nil
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht3; cases he)
    (fun y g =>
      let rh := lbK g 4
      let sg := lbK g 8
      let kd := g 14 * kDen.toK U
      let c0 := (((g 2 * kNum.toK U) + (g 14 * kDv.toK U)) - (kd * g 5)) - rh
      let c1 := ((sg + rh) + 1) - kd
      let c2 := ((g 2 + (kI 32768).toK U) - g 3) - (g 4 * mbC 256)
      let clauses := (((y ⟨ldo + 0, hmu_lt 0 (by norm_num)⟩ * c0)
        + (y ⟨ldo + 1, hmu_lt 1 (by norm_num)⟩ * c1))
        + (y ⟨ldo + 2, hmu_lt 2 (by norm_num)⟩ * c2))
      let denAt := fun (l : ℕ × ℤ × ℤ) => denK U (alpha.toK U) (gU8.toK U) g (2 + l.1) l.2.1 l.2.2
      let hsK := ∑ kk ∈ Finset.range 6,
        if hkk : kk < 6 then
          let d1 := denAt (dzcLks.getD (2 * kk) (0, 0, 0))
          let d2 := denAt (dzcLks.getD (2 * kk + 1) (0, 0, 0))
          y ⟨ldo + (3 + kk), hmu_lt (3 + kk) (by omega)⟩ * (((g (15 + kk) * d1) * d2) - (d1 + d2))
        else 0
      let padK := (1 - g 1) * (∑ r ∈ Finset.range 12, g (2 + r) * (y ⟨ldo + 10, hzeta_lt⟩) ^ r)
      g 0 * (((g 1 * clauses) + hsK) + (y ⟨ldo + 9, hmu_lt 9 (by norm_num)⟩ * padK)))
    (fun y _ vals hv => by
      unfold dzcPoly
      obtain ⟨hzc, hzeq⟩ := zfoldW_toK U hU vals ((stgWords U hbij y).getD (ldo + 10) Fp2.zero)
      let muW := ((stgWords U hbij y).drop ldo).take 10
      let denF := fun (l : ℕ × ℤ × ℤ) => denW vals alpha gU8 (2 + l.1) l.2.1 l.2.2
      obtain ⟨hhsc, hhseq⟩ := foldl_range_add_toK U
        (fun kk =>
          let d1 := denF (dzcLks.getD (2 * kk) (0, 0, 0))
          let d2 := denF (dzcLks.getD (2 * kk + 1) (0, 0, 0))
          (vg muW (3 + kk)).mul ((((vg vals (15 + kk)).mul d1).mul d2).sub (d1.add d2)))
        (fun _ => Fp2.canon_mul _ _) 6
      rw [Fp2.toK_mul U hU,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) hhsc,
          Fp2.toK_mul U hU,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y ldo 10 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y ldo 10 1 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y ldo 10 2 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _)) (lbW_canon _ _),
          Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) Fp2.canon_one,
          Fp2.toK_add U _ _ (lbW_canon _ _) (lbW_canon _ _), Fp2.toK_one, Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (vg_canon hv 3)) (mb_canon _ _),
          Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (vg_canon hv 3),
          Fp2.toK_add U _ _ (vg_canon hv 2) (kI_canon _), mb_toK,
          hhseq,
          Fp2.toK_mul U hU, vg_drop_take_toK U hbij y ldo 10 9 (by norm_num) (by omega),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          hzeq, stgWords_getD_toK U hbij y (ldo + 10) hzeta_lt,
          lbW_toK U vals 4, lbW_toK U vals 8]
      simp only [vg_toK_map]
      congr 2
      congr 1
      refine Finset.sum_congr rfl (fun kk hkk => ?_)
      have hk6 : kk < 6 := Finset.mem_range.mp hkk
      simp only [hk6, ↓reduceDIte]
      rw [Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y ldo 10 (3 + kk) (by omega) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (Fp2.canon_add _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          Fp2.toK_add U _ _ (denW_canon _ _ _ halpha _ _ _) (denW_canon _ _ _ halpha _ _ _),
          denW_toK U vals alpha gU8 halpha hgU8, denW_toK U vals alpha gU8 halpha hgU8, vg_toK_map])
    (fun y _ g hg => by
      have hrh := indDegLE_lbK g hg 4
      have hsg := indDegLE_lbK g hg 8
      have hkd : IndDegLE 1 (fun x => g 14 x * kDen.toK U) := IndDegLE_mulc (hg 14) _
      have hc0 : IndDegLE 2 (fun x => (((g 2 x * kNum.toK U) + (g 14 x * kDv.toK U)) - ((g 14 x * kDen.toK U) * g 5 x)) - lbK (fun idx => g idx x) 4) :=
        IndDegLE.sub (IndDegLE.sub
          (IndDegLE.mono (IndDegLE.add (IndDegLE_mulc (hg 2) _) (IndDegLE_mulc (hg 14) _)) (by norm_num))
          (IndDegLE.mul hkd (hg 5))) (IndDegLE.mono hrh (by norm_num))
      have hc1 : IndDegLE 2 (fun x => ((lbK (fun idx => g idx x) 8 + lbK (fun idx => g idx x) 4) + 1) - (g 14 x * kDen.toK U)) :=
        IndDegLE.mono (IndDegLE.sub (IndDegLE.add (IndDegLE.add hsg hrh) (IndDegLE.const 1)) hkd) (by norm_num)
      have hc2 : IndDegLE 2 (fun x => ((g 2 x + (kI 32768).toK U) - g 3 x) - (g 4 x * mbC 256)) :=
        IndDegLE.mono (IndDegLE.sub (IndDegLE.sub (IndDegLE.add (hg 2) (IndDegLE.const _)) (hg 3)) (IndDegLE_mulc (hg 4) _)) (by norm_num)
      have hcl : IndDegLE 2 (fun x =>
          (((y ⟨ldo + 0, hmu_lt 0 (by norm_num)⟩ * ((((g 2 x * kNum.toK U) + (g 14 x * kDv.toK U)) - ((g 14 x * kDen.toK U) * g 5 x)) - lbK (fun idx => g idx x) 4))
            + (y ⟨ldo + 1, hmu_lt 1 (by norm_num)⟩ * (((lbK (fun idx => g idx x) 8 + lbK (fun idx => g idx x) 4) + 1) - (g 14 x * kDen.toK U))))
            + (y ⟨ldo + 2, hmu_lt 2 (by norm_num)⟩ * (((g 2 x + (kI 32768).toK U) - g 3 x) - (g 4 x * mbC 256))))) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.cmul _ hc0) (IndDegLE.cmul _ hc1)) (IndDegLE.cmul _ hc2)
      have hhs : IndDegLE 3 (fun x => ∑ kk ∈ Finset.range 6,
          if hkk : kk < 6 then
            let d1 := denK U (alpha.toK U) (gU8.toK U) (fun idx => g idx x) (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2
            let d2 := denK U (alpha.toK U) (gU8.toK U) (fun idx => g idx x) (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2
            y ⟨ldo + (3 + kk), hmu_lt (3 + kk) (by omega)⟩ * (((g (15 + kk) x * d1) * d2) - (d1 + d2))
          else 0) := by
        refine indDegLE_finset_sum (Finset.range 6) _ (fun kk hkk => ?_)
        have hk6 : kk < 6 := Finset.mem_range.mp hkk
        simp only [hk6, ↓reduceDIte]
        have hd1 := indDegLE_denK U (alpha.toK U) (gU8.toK U) g hg
          (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2
        have hd2 := indDegLE_denK U (alpha.toK U) (gU8.toK U) g hg
          (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2
        exact IndDegLE.cmul _ (IndDegLE.sub (IndDegLE.mul (IndDegLE.mul (hg (15 + kk)) hd1) hd2)
          (IndDegLE.mono (IndDegLE.add hd1 hd2) (by norm_num)))
      have hzf : IndDegLE 1 (fun x => ∑ r ∈ Finset.range 12, g (2 + r) x * (y ⟨ldo + 10, hzeta_lt⟩) ^ r) :=
        indDegLE_finset_sum (Finset.range 12) _ (fun r _ => IndDegLE_mulc (hg (2 + r)) _)
      have hpad : IndDegLE 3 (fun x => y ⟨ldo + 9, hmu_lt 9 (by norm_num)⟩ * ((1 - g 1 x) * (∑ r ∈ Finset.range 12, g (2 + r) x * (y ⟨ldo + 10, hzeta_lt⟩) ^ r))) :=
        IndDegLE.mono (IndDegLE.cmul _ (IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1)) hzf)) (by norm_num)
      have hall : IndDegLE 3 (fun x => ((g 1 x *
          (((y ⟨ldo + 0, hmu_lt 0 (by norm_num)⟩ * ((((g 2 x * kNum.toK U) + (g 14 x * kDv.toK U)) - ((g 14 x * kDen.toK U) * g 5 x)) - lbK (fun idx => g idx x) 4))
            + (y ⟨ldo + 1, hmu_lt 1 (by norm_num)⟩ * (((lbK (fun idx => g idx x) 8 + lbK (fun idx => g idx x) 4) + 1) - (g 14 x * kDen.toK U))))
            + (y ⟨ldo + 2, hmu_lt 2 (by norm_num)⟩ * (((g 2 x + (kI 32768).toK U) - g 3 x) - (g 4 x * mbC 256)))))
          + _) + _) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.mul (hg 1) hcl) hhs) hpad
      exact IndDegLE.mono (IndDegLE.mul (hg 0) hall) (by norm_num))
    (fun x rt => by
      let grt : ℕ → K := fun idx => match idx with | 0 => 0 | j + 1 => rt j
      have hg_ge1 : ∀ (a : K) (idx : ℕ), 1 ≤ idx →
          (match idx with | 0 => a | j + 1 => rt j) = grt idx := by
        intro a idx h1
        cases idx with
        | zero => omega
        | succ j => rfl
      have hlb4 : ∀ a : K, lbK (fun idx => match idx with | 0 => a | j + 1 => rt j) 4 = lbK grt 4 := by
        intro a; unfold lbK; refine Finset.sum_congr rfl (fun kk _ => ?_)
        dsimp only; rw [hg_ge1 a (2 + (4 + kk)) (by omega)]
      have hlb8 : ∀ a : K, lbK (fun idx => match idx with | 0 => a | j + 1 => rt j) 8 = lbK grt 8 := by
        intro a; unfold lbK; refine Finset.sum_congr rfl (fun kk _ => ?_)
        dsimp only; rw [hg_ge1 a (2 + (8 + kk)) (by omega)]
      have hden : ∀ (a : K) (l : ℕ × ℤ × ℤ),
          denK U (alpha.toK U) (gU8.toK U) (fun idx => match idx with | 0 => a | j + 1 => rt j) (2 + l.1) l.2.1 l.2.2
            = denK U (alpha.toK U) (gU8.toK U) grt (2 + l.1) l.2.1 l.2.2 := by
        intro a l; unfold denK; dsimp only; rw [hg_ge1 a (2 + l.1) (by omega)]
      let c0r : K := (((rt 1 * kNum.toK U) + (rt 13 * kDv.toK U)) - ((rt 13 * kDen.toK U) * rt 4)) - lbK grt 4
      let c1r : K := ((lbK grt 8 + lbK grt 4) + 1) - (rt 13 * kDen.toK U)
      let c2r : K := ((rt 1 + (kI 32768).toK U) - rt 2) - (rt 3 * mbC 256)
      let denAtr := fun (l : ℕ × ℤ × ℤ) => denK U (alpha.toK U) (gU8.toK U) grt (2 + l.1) l.2.1 l.2.2
      let Fr : (Fin (P0.draws 5) → K) → K := fun y =>
        ((rt 0 * (((y ⟨ldo + 0, hmu_lt 0 (by norm_num)⟩ * c0r)
          + (y ⟨ldo + 1, hmu_lt 1 (by norm_num)⟩ * c1r))
          + (y ⟨ldo + 2, hmu_lt 2 (by norm_num)⟩ * c2r)))
        + (∑ kk ∈ Finset.range 6,
            if hkk : kk < 6 then
              let d1 := denAtr (dzcLks.getD (2 * kk) (0, 0, 0))
              let d2 := denAtr (dzcLks.getD (2 * kk + 1) (0, 0, 0))
              y ⟨ldo + (3 + kk), hmu_lt (3 + kk) (by omega)⟩ * (((grt (15 + kk) * d1) * d2) - (d1 + d2))
            else 0))
        + (y ⟨ldo + 9, hmu_lt 9 (by norm_num)⟩ *
            ((1 - rt 0) * (∑ r ∈ Finset.range 12, grt (2 + r) * (y ⟨ldo + 10, hzeta_lt⟩) ^ r)))
      suffices hdegFr : IndDegLE 11 (fun y => eqDrawK ldo ldo 1 (by omega) y x * Fr y) by
        have heq_f : (fun y : Fin (P0.draws 5) → K =>
            (fun y g =>
              let rh := lbK g 4
              let sg := lbK g 8
              let kd := g 14 * kDen.toK U
              let c0 := (((g 2 * kNum.toK U) + (g 14 * kDv.toK U)) - (kd * g 5)) - rh
              let c1 := ((sg + rh) + 1) - kd
              let c2 := ((g 2 + (kI 32768).toK U) - g 3) - (g 4 * mbC 256)
              let clauses := (((y ⟨ldo + 0, hmu_lt 0 (by norm_num)⟩ * c0)
                + (y ⟨ldo + 1, hmu_lt 1 (by norm_num)⟩ * c1))
                + (y ⟨ldo + 2, hmu_lt 2 (by norm_num)⟩ * c2))
              let denAt := fun (l : ℕ × ℤ × ℤ) => denK U (alpha.toK U) (gU8.toK U) g (2 + l.1) l.2.1 l.2.2
              let hsK := ∑ kk ∈ Finset.range 6,
                if hkk : kk < 6 then
                  let d1 := denAt (dzcLks.getD (2 * kk) (0, 0, 0))
                  let d2 := denAt (dzcLks.getD (2 * kk + 1) (0, 0, 0))
                  y ⟨ldo + (3 + kk), hmu_lt (3 + kk) (by omega)⟩ * (((g (15 + kk) * d1) * d2) - (d1 + d2))
                else 0
              let padK := (1 - g 1) * (∑ r ∈ Finset.range 12, g (2 + r) * (y ⟨ldo + 10, hzeta_lt⟩) ^ r)
              g 0 * (((g 1 * clauses) + hsK) + (y ⟨ldo + 9, hmu_lt 9 (by norm_num)⟩ * padK)))
            y (fun idx => match idx with | 0 => eqDrawK ldo ldo 1 (by omega) y x | j + 1 => rt j))
          = (fun y => eqDrawK ldo ldo 1 (by omega) y x * Fr y) := by
          funext y
          dsimp only
          refine congrArg (HMul.hMul (eqDrawK ldo ldo 1 (by omega) y x)) ?_
          unfold Fr c0r c1r c2r denAtr
          rw [hlb4, hlb8]
          refine congrArg₂ HAdd.hAdd (congrArg₂ HAdd.hAdd rfl ?_) ?_
          · refine Finset.sum_congr rfl (fun kk hkk => ?_)
            have hk6 : kk < 6 := Finset.mem_range.mp hkk
            simp only [hk6, ↓reduceDIte]
            rw [hg_ge1 _ (15 + kk) (by omega),
                hden _ (dzcLks.getD (2 * kk) (0, 0, 0)),
                hden _ (dzcLks.getD (2 * kk + 1) (0, 0, 0))]
          · refine congrArg (HMul.hMul _) (congrArg (HMul.hMul _) ?_)
            refine Finset.sum_congr rfl (fun r _ => ?_)
            rw [hg_ge1 _ (2 + r) (by omega)]
        exact heq_f.symm ▸ hdegFr
      refine indDegLE_eq_mul_upper ldo ldo 1 11 (by norm_num) (by omega) x Fr ?_ (fun i hi y t => ?_)
      · refine IndDegLE.add (IndDegLE.add ?_ ?_) ?_
        · exact IndDegLE.cmul (rt 0) (IndDegLE.add (IndDegLE.add
            (IndDegLE.mono (d := 1) (d' := 11) (IndDegLE_mulc (indDegLE_coord _) c0r) (by norm_num))
            (IndDegLE.mono (d := 1) (d' := 11) (IndDegLE_mulc (indDegLE_coord _) c1r) (by norm_num)))
            (IndDegLE.mono (d := 1) (d' := 11) (IndDegLE_mulc (indDegLE_coord _) c2r) (by norm_num)))
        · refine indDegLE_finset_sum (Finset.range 6) _ (fun kk hkk => ?_)
          have hk6 : kk < 6 := Finset.mem_range.mp hkk
          simp only [hk6, ↓reduceDIte]
          exact IndDegLE.mono (d := 1) (d' := 11) (IndDegLE_mulc (indDegLE_coord _) _) (by norm_num)
        · refine indDegLE_mul_disjoint
            (fun y => y ⟨ldo + 9, hmu_lt 9 (by norm_num)⟩)
            (fun y => (1 - rt 0) * ∑ r ∈ Finset.range 12, grt (2 + r) * (y ⟨ldo + 10, hzeta_lt⟩) ^ r)
            (IndDegLE.mono (d := 1) (d' := 11) (indDegLE_coord _) (by norm_num))
            (IndDegLE.cmul (1 - rt 0) (indDegLE_zfold ⟨ldo + 10, hzeta_lt⟩ (fun r => grt (2 + r))))
            (fun i => ?_)
          by_cases hi9 : i = ⟨ldo + 9, hmu_lt 9 (by norm_num)⟩
          · subst hi9
            refine Or.inr ((Block.constAt_const _ (1 - rt 0)).mul
              (constAt_zfold_ne _ _ (fun he => by have := congrArg Fin.val he; dsimp only at this; omega) _))
          · exact Or.inl (constAt_coord_ne i _ hi9)
      · unfold Fr
        have hu0 := update_lt_get y t i ldo (ldo + 0) hi (by omega) (hmu_lt 0 (by norm_num))
        have hu1 := update_lt_get y t i ldo (ldo + 1) hi (by omega) (hmu_lt 1 (by norm_num))
        have hu2 := update_lt_get y t i ldo (ldo + 2) hi (by omega) (hmu_lt 2 (by norm_num))
        have hu9 := update_lt_get y t i ldo (ldo + 9) hi (by omega) (hmu_lt 9 (by norm_num))
        have hu10 := update_lt_get y t i ldo (ldo + 10) hi (by omega) hzeta_lt
        rw [hu0, hu1, hu2, hu9, hu10]
        congr 2
        refine Finset.sum_congr rfl (fun kk hkk => ?_)
        have hk6 : kk < 6 := Finset.mem_range.mp hkk
        simp only [hk6, ↓reduceDIte]
        have hukk := update_lt_get y t i ldo (ldo + (3 + kk)) hi (by omega) (hmu_lt (3 + kk) (by omega))
        rw [hukk])

omit [Fintype K] [DecidableEq K] in
theorem outc_slot6_offZero (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hd : List (List Fp2)) (hhd : hd.length = 6) :
    ∃ Pp : (Fin (P0.draws 6) → K) → K,
      IndDegLE 1 Pp ∧ OffZero (Z_range (P0.draws 6) Vo.pub.ltab 3)
        (fun y => stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
          (OutcV.bga ch) hd 6 (stgWords U hbij y)) Pp := by
  let O := Vo.pub; let G := Vo.geo; let L0 := outcLay O G.bLogN
  let ltab := O.ltab
  let bga := OutcV.bga ch
  let alpha := ch.getD 1 Fp2.zero
  let gU8 := (ch.getD 0 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagU8))
  have hdraws : P0.draws 6 = ltab + 3 := by rw [hP.1]; show ltab + 2 + 1 = ltab + 3; omega
  have halpha : alpha.Canon := Fp2.canon_getD hch 1
  have hj0 : ltab < P0.draws 6 := by omega
  have hj1 : ltab + 1 < P0.draws 6 := by omega
  have hj2 : ltab + 2 < P0.draws 6 := by omega
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  refine offZero_standalone_draw U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v
    hlc hIO_vac bga hd 6 ltab 1 3 ltab 1 hhd (by omega) le_rfl rfl rfl (Z_range (P0.draws 6) ltab 3)
    [.pub (supp OutcPub.u8Len (2 ^ ltab)),
     .pub (tvTab (2 ^ ltab) gU8),
     .priv ⟨.a, [(L0.aOff ocC_MULT, Fp2.one)], L0.aLog.getD ocC_MULT 0,
       rhoC 0 (L0.aLog.getD ocC_MULT 0), L0.aMaskBase + 2 * (L0.prefixA 6 + 0), 0⟩,
     .priv ⟨.h, [((L0.hOff ocH_GU8).1, Fp2.one), ((L0.hOff ocH_GU8).2, Block.fp2U)],
       L0.hLog.getD ocH_GU8 0, rhoC 0 (L0.hLog.getD ocH_GU8 0), L0.hMaskBase + 2 * (L0.prefixH 6 + 0), 0⟩]
    (fun y =>
      let dr := stgWords U hbij y
      tabPoly ((dr.drop ltab).take 2) (dr.getD (ltab + 2) Fp2.zero) alpha)
    (fun y hZ => outcDefTAB_ok U hbij hU O G ⟨bga.1, bga.2.1, bga.2.2, hd⟩ hdraws y hZ)
    (fun y hZ => outcDefTAB_err U hbij hU O G ⟨bga.1, bga.2.1, bga.2.2, hd⟩ y hZ)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_h_rho _ _ _ _ _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun y g =>
      g 0 * ((y ⟨ltab, hj0⟩ * (g 4 * (alpha.toK U - g 2) - g 3))
        + (y ⟨ltab + 1, hj1⟩ * ((1 - g 1) * (g 3 + y ⟨ltab + 2, hj2⟩ * g 4)))))
    (fun y _ vals hv => by
      unfold tabPoly
      rw [Fp2.toK_mul U hU, Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y ltab 2 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y ltab 2 1 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (Fp2.canon_mul _ _) (vg_canon hv 3),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ halpha (vg_canon hv 2),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          stgWords_getD_toK U hbij y (ltab + 2) hj2]
      simp only [vg_toK_map]
      rfl)
    (fun y _ g hg => by
      have hrel : IndDegLE 2 (fun x => g 4 x * (alpha.toK U - g 2 x) - g 3 x) :=
        IndDegLE.sub (IndDegLE.mul (hg 4) (IndDegLE.sub (IndDegLE.const _) (hg 2)))
          (IndDegLE.mono (hg 3) (by norm_num))
      have hpad : IndDegLE 2 (fun x => (1 - g 1 x) * (g 3 x + y ⟨ltab + 2, hj2⟩ * g 4 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1))
          (IndDegLE.add (hg 3) (IndDegLE.cmul _ (hg 4)))
      exact IndDegLE.mul (hg 0) (IndDegLE.add (IndDegLE.cmul _ hrel) (IndDegLE.cmul _ hpad)))
    (fun x rt => by
      dsimp only
      refine indDegLE_eq_mul_upper ltab ltab 1 1 le_rfl (by omega) x _ ?_ (fun i hi y t => ?_)
      · exact IndDegLE.add (IndDegLE_mulc (indDegLE_coord ⟨ltab, hj0⟩) _)
          (indDegLE_mu_pad ⟨ltab + 1, hj1⟩ ⟨ltab + 2, hj2⟩
            (fun he => by have := congrArg Fin.val he; dsimp only at this; omega) _ _ _)
      · rw [update_lt_get y t i ltab ltab hi le_rfl hj0,
            update_lt_get y t i ltab (ltab + 1) hi (by omega) hj1,
            update_lt_get y t i ltab (ltab + 2) hi (by omega) hj2])

/-- **ROUND-BY-ROUND SOUNDNESS FOR ALL STAGE OUT-C DEFINE DRAWS (`sshΦO` at `sshDgO`)**. -/
theorem ssh_outc_rbr (hU : U ^ 2 = algebraMap GF K 7)
    (P0 : Block.BlockParams) (F : ℕ → OutcV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8))
    (hPout : ∀ b, StgSame P0 (F b).bp)
    (hlc : ∀ b, (F b).pub.lt ≤ lc)
    (hIO : ∀ b, StgCsIODeg U hbij (F b).geo.bLogN (OutcPrivIO (F b).pub) csIO) :
    ∀ k, (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO k).Rbr := by
  intro k
  rcases k with _ | _ | _ | _ | _ | _ | _ | k
  · -- k = 0: OUTC-00 IO-in
    exact ssh_rbrO_canon U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO absOf sshDgO 0 1 ∅ rfl
      (fun v hh _ _ hk => outc_slot0_offZero U hbij tag h64 hU P0 (vdWout F (v.2.take n0)) (hPout _)
        lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO v (hlc _) (hIO _) (OutcV.bga hh.1) hh.2 hk)
  · -- k = 1: OUTC-01 SS (0 draws)
    intro _ _ τ _ hτ
    have hn : (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO (0 + 1)).n = 0 := by
      show P0.draws 1 = 0; rw [(hPout 0).1]; rfl
    rw [hn] at hτ; exact absurd hτ (Nat.not_lt_zero _)
  · -- k = 2: OUTC-02 TZC (hosts SS)
    exact ssh_rbrO_canon U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO absOf sshDgO 2 1
      (Z_range (P0.draws 2) 1 6) rfl
      (fun v hh _ _ hk => outc_slot2_offZero U hbij tag h64 hU P0 (vdWout F (v.2.take n0)) (hPout _)
        lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO v (hlc _) (OutcV.bga hh.1) hh.2 hk)
  · -- k = 3: OUTC-03 PD (0 draws)
    intro _ _ τ _ hτ
    have hn : (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO (0 + 1 + 1 + 1)).n = 0 := by
      show P0.draws 3 = 0; rw [(hPout 0).1]; rfl
    rw [hn] at hτ; exact absurd hτ (Nat.not_lt_zero _)
  · -- k = 4: OUTC-04 LZC (hosts PD)
    exact ssh_rbrO_canon U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO absOf sshDgO 4 1
      (Z_range (P0.draws 4) (vdWout F ([] : List (TItem × Dig))).pub.llo 3) rfl
      (fun v hh hcan _ hk => by
        let Vo := vdWout F (v.2.take n0)
        have hllo : Vo.pub.llo = (vdWout F ([] : List (TItem × Dig))).pub.llo := by
          have e1 : P0.draws 4 = Vo.pub.llo + 2 + 1 := (hPout _).1 ▸ rfl
          have e2 : P0.draws 4 = (vdWout F ([] : List (TItem × Dig))).pub.llo + 2 + 1 := (hPout _).1 ▸ rfl
          omega
        rw [← hllo]
        exact outc_slot4_offZero U hbij tag h64 hU P0 Vo (hPout _) lc h Q e rA rH
          hdrLen (hdrLen + 4 + 2) csIO v (hlc _) hh.1 hcan hh.2 hk)
  · -- k = 5: OUTC-05 DZC (degree 11)
    exact ssh_rbrO_canon U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO absOf sshDgO 5 11
      (Z_range (P0.draws 5) (vdWout F ([] : List (TItem × Dig))).pub.ldo 11) rfl
      (fun v hh hcan _ hk => by
        let Vo := vdWout F (v.2.take n0)
        have hldo : Vo.pub.ldo = (vdWout F ([] : List (TItem × Dig))).pub.ldo := by
          have e1 : P0.draws 5 = Vo.pub.ldo + 10 + 1 := (hPout _).1 ▸ rfl
          have e2 : P0.draws 5 = (vdWout F ([] : List (TItem × Dig))).pub.ldo + 10 + 1 := (hPout _).1 ▸ rfl
          omega
        rw [← hldo]
        exact outc_slot5_offZero U hbij tag h64 hU P0 Vo (hPout _) lc h Q e rA rH
          hdrLen (hdrLen + 4 + 2) csIO v (hlc _) hh.1 hcan hh.2 hk)
  · -- k = 6: OUTC-06 TAB
    exact ssh_rbrO_canon U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO absOf sshDgO 6 1
      (Z_range (P0.draws 6) (vdWout F ([] : List (TItem × Dig))).pub.ltab 3) rfl
      (fun v hh hcan _ hk => by
        let Vo := vdWout F (v.2.take n0)
        have hltab : Vo.pub.ltab = (vdWout F ([] : List (TItem × Dig))).pub.ltab := by
          have e1 : P0.draws 6 = Vo.pub.ltab + 2 + 1 := (hPout _).1 ▸ rfl
          have e2 : P0.draws 6 = (vdWout F ([] : List (TItem × Dig))).pub.ltab + 2 + 1 := (hPout _).1 ▸ rfl
          omega
        rw [← hltab]
        exact outc_slot6_offZero U hbij tag h64 hU P0 Vo (hPout _) lc h Q e rA rH
          hdrLen (hdrLen + 4 + 2) csIO v (hlc _) hh.1 hcan hh.2 hk)
  · -- k ≥ 7: OUTC-07 ZS and out-of-range (0 draws)
    intro _ _ τ _ hτ
    have hn : (stgDefSqV P0 2 hdrLen absOf
        (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO (k + 1 + 1 + 1 + 1 + 1 + 1 + 1)).n = 0 := by
      show P0.draws (k + 7) = 0; rw [(hPout 0).1]; rfl
    rw [hn] at hτ; exact absurd hτ (Nat.not_lt_zero _)

end OutcRbr

end ZK60.ProtocolClassify
