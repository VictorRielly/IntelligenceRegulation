/-
D63 lane L68c, part 3a (`HonestShieldRefusal.lean`):
concrete Shieldstral T128 R13 refusal-site machinery built directly on `HonestShieldProgBase.lean`:
1. **`classifyP_refuse_of_cover`**: O9 bridge for `classifyProtocolUExecP` / `classifyModelP`
   (exact twin of `HonestClassifyRun.classify_refuse_of_cover` for `classifySpecP`).
2. **`opsP` & `shdP_hdrProg`**: `TProg Unit` executing the 8 header absorbs of `clsStart` (plus `rootOfP`
   for `shdP_epTable`, matching `honestRoot` via `shdP_epTable_root`) with `TProg.Sep key`, `SqLE 0`,
   and exact `final_shdP_hdrProg`.
3. **`mleAt_update_zero` & `shdP_incAlphaStartSite` (`Fin 13 → Site`, `k = 131072 = 2^17`, `δ = 0`) +
   `shdP_incAlphaBad_cover`**: builds the 13 concrete Stage IN-C D66(3) refusal sites (`α` draw +
   12 `r_emb` coordinate draws via `HonestRunCount.seq_zero` + `embFoldL_hEmb`), completely closing
   Finding L32-5!
4. **`shdP_outcAlphaStartSite`** (`k = 256`, `δ = 0`) + **`shdP_outcAlphaBad_cover`** via
   `startSite_fires_iff_tprogSite` + `outcAlphaSite_fires`.
5. **`shdP_openStartSite`** + **`shdP_checkOpening_startCover`**: `startSite` lift of
   `HonestRun.checkOpening_cover` (`Option (Fin n ⊕ Unit)`, `k ∈ {1, gP}`, `δ = 0`).

Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldCore
import ZK60Formal.HonestShieldMTable
import ZK60Formal.HonestShieldProgBase
import ZK60Formal.HonestShieldStages
import ZK60Formal.HonestRunCover
import ZK60Formal.RunStgShieldEmbFold
import ZK60Formal.RunStgShieldIncVals
import ZK60Formal.RunShapeProtocol

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Exec.StageCheck ZK60.Sound ZK60.TokenRun
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestOracle ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (shieldS0)
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (labA labM labH absorbRoot)

/-! ## 1. `classifyP_refuse_of_cover` (`O.refuse` bridge for `classifyModelP` / `classifySpecP`) -/

section ClassifyPRefuse

/-- **`ClassifyOpenP`'s `O.refuse` field from a site cover**: if whenever `honestSegs` refuses some site fires,
then whenever no site fires `honestSegs` succeeds. -/
theorem shdP_classifyP_refuse_of_cover {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Rp : ClassifyRunPublicP shieldS0) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (Cin : PlaneCommit (shieldS0.Tok → ℕ) (ClsStmt Hdr) Salt)
    (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    {ι : Type} (site : (shieldS0.Tok → ℕ) → ι → ProtocolClassify.Site (QB Lq) Coins K)
    (hcover : ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP Rp x).getD 0) x c = .error () →
        ∃ i, (site x i).fires U G c) :
    ∀ x, (classifyModelP Rp).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP Rp x).getD 0) x c = .ok r := by
  intro x hx G c hno
  cases hs : honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP Rp x).getD 0) x c with
  | ok r => exact ⟨r, rfl⟩
  | error e =>
    cases e
    obtain ⟨i, hi⟩ := hcover x hx G c hs
    have hfalse : False := hno i hi
    cases hfalse

end ClassifyPRefuse

/-! ## 2. `opsP` and `shdP_hdrProg` (header transcript program from `Tr.newKeyed`) -/

section HeaderProg

/-- Convert a list of `Op`s into a `TProg Unit`. -/
def opsP : List Op → TProg Unit
  | [] => .done ()
  | .absorb l d :: rest => .absorb l d (opsP rest)
  | .squeeze :: rest => .squeeze (fun _ => opsP rest)

theorem final_opsP (H : HIn → Dig) : ∀ (ops : List Op) (t : Tr),
    (opsP ops).final H t = (runOps H t ops, ())
  | [], _ => rfl
  | .absorb _ _ :: rest, t => final_opsP H rest _
  | .squeeze :: rest, t => final_opsP H rest _

theorem sep_opsP (key : Option Dig) : ∀ (ops : List Op), TProg.Sep key (opsP ops)
  | [] => trivial
  | .absorb _ _ :: rest => sep_opsP key rest
  | .squeeze :: rest => fun _ => sep_opsP key rest

theorem sqLE_opsP : ∀ (ops : List Op), SqLE (sqN ops) (opsP ops)
  | [] => trivial
  | .absorb _ _ :: rest => sqLE_opsP rest
  | .squeeze :: rest => fun _ => sqLE_opsP rest

/-- **Header transcript program**: computes `inRoot` via `rootOfP` on `shdP_epTable` (`honestRoot`), then
runs the 8 header absorbs `clsHdrOps (hw hdr) inRoot verdict`. Zero squeezes (`SqLE 0`), separated from
47-byte squeezes for every `key`. -/
noncomputable def shdP_hdrProg {Hdr : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr) (verdict : ℕ)
    (x : shieldS0.Tok → ℕ) (epR : EpxSalt 6) : TProg Unit :=
  bindP (rootOfP tag 11 (shdP_epTable (Hdr := Hdr) tag x epR)).p (fun inRoot =>
    opsP (clsHdrOps (hw hdr) inRoot verdict))

theorem final_shdP_hdrProg {Hdr : Type} (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (hw : Hdr → ClsHdrW) (hdr : Hdr) (verdict : ℕ) (domain : List UInt8) (key : Option Dig)
    (G : QB Lq → Dig) (x : shieldS0.Tok → ℕ) (epR : EpxSalt 6) :
    let inRoot := honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr (Hdr := Hdr) tag hL20) G x epR
    ((shdP_hdrProg tag hw hdr verdict x epR).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      = clsStart domain key hw (liftH G) (honestStmt hdr inRoot verdict) := by
  intro inRoot
  unfold shdP_hdrProg
  rw [final_bindP, (rootOfP tag 11 (shdP_epTable (Hdr := Hdr) tag x epR)).final_eq, final_opsP]
  dsimp only
  rw [shdP_epTable_root (Hdr := Hdr) tag Lq hL20 G x epR]
  rfl

theorem sep_shdP_hdrProg {Hdr : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr) (verdict : ℕ)
    (x : shieldS0.Tok → ℕ) (epR : EpxSalt 6) (key : Option Dig) :
    TProg.Sep key (shdP_hdrProg tag hw hdr verdict x epR) :=
  sep_bindP key _ _ ((rootOfP tag 11 _).sep key) (fun _ => sep_opsP key _)

theorem sqLE_shdP_hdrProg {Hdr : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr) (verdict : ℕ)
    (x : shieldS0.Tok → ℕ) (epR : EpxSalt 6) :
    SqLE 0 (shdP_hdrProg tag hw hdr verdict x epR) := by
  unfold shdP_hdrProg
  exact sqLE_mono _ (0 + 0) 0 (sqLE_bindP _ _ 0 0 (rootOfP tag 11 _).sq
    (fun r => by simpa only [clsHdrOps_sqN] using sqLE_opsP (clsHdrOps (hw hdr) r verdict))) (by norm_num)

end HeaderProg

/-! ## 3. Multilinear step identity & 13 concrete Stage IN-C `incAlphaBad` sites (closes Finding L32-5!) -/

section IncAlphaSites

/-- Prefix vector `(r_0, …, r_{k-1}, 0, …, 0)` in `Fin n → K`. -/
def vecPref {K : Type} [Zero K] {n : ℕ} (r : Fin n → K) (k : ℕ) : Fin n → K :=
  fun j => if j.val < k then r j else 0

/-- **Multilinear coordinate step identity**: updating coordinate `i` from `0` to `t` advances `mleAt f`
affinely: `mleAt f (update z i t) = mleAt f (update z i 0) + t * (mleAt f (update z i 1) - mleAt f (update z i 0))`. -/
theorem mleAt_update_zero {K : Type} [Field K] {n : ℕ} (f : (Fin n → Bool) → K)
    (z : Fin n → K) (i : Fin n) (t : K) :
    mleAt f (Function.update z i t)
      = mleAt f (Function.update z i 0)
        + t * (mleAt f (Function.update z i 1) - mleAt f (Function.update z i 0)) := by
  have heq : ∀ (b : Fin n → Bool) (u : K),
      eqPoly (fun a => (bit (b a) : K)) (Function.update z i u)
        = (if b i = true then u else 1 - u)
          * ∏ a ∈ Finset.univ.erase i,
              ((bit (b a) : K) * z a + (1 - (bit (b a) : K)) * (1 - z a)) := by
    intro b u
    unfold eqPoly
    rw [← Finset.mul_prod_erase Finset.univ _ (Finset.mem_univ i)]
    congr 1
    · rw [Function.update_self]
      cases hbi : b i <;> simp [bit]
    · refine Finset.prod_congr rfl (fun a ha => ?_)
      have hne : a ≠ i := (Finset.mem_erase.mp ha).1
      rw [Function.update_of_ne hne]
  unfold mleAt
  have hlin : ∀ (b : Fin n → Bool),
      f b * eqPoly (fun a => (bit (b a) : K)) (Function.update z i t)
      = f b * eqPoly (fun a => (bit (b a) : K)) (Function.update z i 0)
        + t * (f b * eqPoly (fun a => (bit (b a) : K)) (Function.update z i 1)
             - f b * eqPoly (fun a => (bit (b a) : K)) (Function.update z i 0)) := by
    intro b
    rw [heq b t, heq b 0, heq b 1]
    cases hbi : b i <;> simp <;> ring
  simp_rw [hlin]
  rw [Finset.sum_add_distrib, ← Finset.mul_sum, Finset.sum_sub_distrib]

/-- Corollary on `vecPref`: advancing `vecPref r k` to `vecPref r (k + 1)` (`k < n`). -/
theorem mleAt_vecPref_succ {K : Type} [Field K] {n : ℕ} (f : (Fin n → Bool) → K)
    (r : Fin n → K) (k : ℕ) (hk : k < n) :
    mleAt f (vecPref r (k + 1))
      = mleAt f (vecPref r k)
        + r ⟨k, hk⟩ * (mleAt f (Function.update (vecPref r k) ⟨k, hk⟩ 1) - mleAt f (vecPref r k)) := by
  have h0 : Function.update (vecPref r k) ⟨k, hk⟩ 0 = vecPref r k := by
    funext j; by_cases hj : j = ⟨k, hk⟩
    · subst hj; simp [vecPref]
    · rw [Function.update_of_ne hj]
  have h1 : Function.update (vecPref r k) ⟨k, hk⟩ (r ⟨k, hk⟩) = vecPref r (k + 1) := by
    funext j; by_cases hj : j = ⟨k, hk⟩
    · subst hj; simp [vecPref]
    · rw [Function.update_of_ne hj]
      unfold vecPref
      have hne : j.val ≠ k := fun h => hj (Fin.ext h)
      by_cases hlt : j.val < k
      · rw [ite_eq_left hlt, ite_eq_left (by omega)]
      · rw [ite_eq_right hlt, ite_eq_right (by omega)]
  have h := mleAt_update_zero f (vecPref r k) ⟨k, hk⟩ (r ⟨k, hk⟩)
  rwa [h0, h1] at h

/-- Stage IN-C head prefix up to draw `j` (`j < 15`, AFTER `frame`, `absorbRoot A`, `absorb M`),
returning the `j` draws collected so far (`[β, γ, …]`). -/
def incHeadDrawProg {α : Type} (V : IncV) {rB rA rM : (HIn → Dig) → Dig} (pre : TProg α)
    (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM) (j : ℕ) : TProg (List Fp2) :=
  bindP pre (fun _ =>
    .absorb Block.labRunStage (le64 0)
      (.absorb Block.labRunBlock V.pub.embDigest.toList
        (absorbRootP RB Block.labB V.geo.bRows V.geo.bLogN (fun _ =>
          absorbRootP RA labA V.lay.aRows V.lay.logN (fun _ =>
            bindP RM.p (fun mRoot => .absorb labM mRoot.toList (drawsP j (fun ch => .done ch))))))))

theorem final_incHeadDrawProg {α : Type} (H : HIn → Dig) (V : IncV) {rB rA rM : (HIn → Dig) → Dig}
    (pre : TProg α) (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM) (j : ℕ) (t : Tr) :
    let T0 := (absorbRoot H (V.frame H (rB H) (pre.final H t).1) labA (rA H) V.lay.aRows V.lay.logN).absorb H labM (rM H).toList
    (incHeadDrawProg V pre RB RA RM j).final H t = ((T0.challengeFp2Vec H j).2, (T0.challengeFp2Vec H j).1) := by
  unfold incHeadDrawProg
  rw [final_bindP]
  change (absorbRootP RB Block.labB V.geo.bRows V.geo.bLogN (fun _ =>
    absorbRootP RA labA V.lay.aRows V.lay.logN (fun _ =>
      bindP RM.p (fun mRoot => .absorb labM mRoot.toList (drawsP j (fun ch => .done ch)))))).final H
      (((pre.final H t).1.absorbU64 H Block.labRunStage 0).absorb H Block.labRunBlock V.pub.embDigest.toList) = _
  rw [final_absorbRootP, final_absorbRootP, final_bindP, RM.final_eq, final_absorb, final_drawsP]
  rfl

theorem sep_incHeadDrawProg {α : Type} (key : Option Dig) (V : IncV) {rB rA rM : (HIn → Dig) → Dig}
    (pre : TProg α) (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM) (j : ℕ)
    (hp : TProg.Sep key pre) :
    TProg.Sep key (incHeadDrawProg V pre RB RA RM j) :=
  sep_bindP key pre _ hp (fun _ =>
    sep_absorbRootP key RB _ _ _ _ (fun _ =>
      sep_absorbRootP key RA _ _ _ _ (fun _ =>
        sep_bindP key RM.p _ (RM.sep key) (fun _ => sep_drawsP key j _ (fun _ => trivial)))))

theorem sqLE_incHeadDrawProg {α : Type} (V : IncV) {rB rA rM : (HIn → Dig) → Dig}
    (pre : TProg α) (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM) (j m : ℕ)
    (hp : SqLE m pre) :
    SqLE (m + j) (incHeadDrawProg V pre RB RA RM j) := by
  unfold incHeadDrawProg
  exact sqLE_bindP pre _ m j hp (fun _ =>
    sqLE_absorbRootP RB _ _ _ j _ (fun _ =>
      sqLE_absorbRootP RA _ _ _ j _ (fun _ => by
        have h := sqLE_bindP RM.p _ 0 j RM.sq (fun _ =>
          sqLE_mono _ (j + 0) j (sqLE_drawsP j 0 _ (fun _ => trivial)) (by omega))
        rwa [Nat.zero_add] at h)))

/-- Base offset `v + β²·ctl(v) + γ·TAG_EMB` in `shdP_K` (independent of `α` and `r_emb`). -/
noncomputable def incTauBase (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (beta gamma : Fp2) (v : Fin 131072) : shdP_K :=
  let I := shdP_incPub Rp embDigest (embFoldL Rp.inp)
  let β := beta.toK shdP_U
  let gEmb := (gamma.mulBase (Fp.new (UInt64.ofNat tagEmb))).toK shdP_U
  (v.val : shdP_K) + (if I.ctl v.val then β * β else 0) + gEmb

/-- Partial `f_v(k)` after `k` coordinates of `r_emb` (`0 ≤ k ≤ 12`):
`incTauBase(v) + β · mleAt(E_v, rPref k) - α`. -/
noncomputable def incTauDiff (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072) (embDigest : Dig)
    (ch : List Fp2) (k : ℕ) (v : Fin 131072) : shdP_K :=
  let beta := ch.getD 0 Fp2.zero
  let gamma := ch.getD 1 Fp2.zero
  let alpha := ch.getD 2 Fp2.zero
  let r : Fin 12 → shdP_K := fun j => (ch.getD (3 + j.val) Fp2.zero).toK shdP_U
  let ev : (Fin 12 → Bool) → shdP_K := fun c => algebraMap GF shdP_K (shdEpad Rp.inp ⟨v.val, by omega⟩ c)
  incTauBase Rp embDigest beta gamma v + beta.toK shdP_U * mleAt ev (vecPref r k) - alpha.toK shdP_U

/-- Slope `s_v(k)` at coordinate `k < 12` (depends ONLY on `ch[0..3+k-1]`, NOT on `ch[3+k]`). -/
noncomputable def incTauSlope (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072)
    (ch : List Fp2) (k : ℕ) (hk : k < 12) (v : Fin 131072) : shdP_K :=
  let beta := ch.getD 0 Fp2.zero
  let r : Fin 12 → shdP_K := fun j => (ch.getD (3 + j.val) Fp2.zero).toK shdP_U
  let ev : (Fin 12 → Bool) → shdP_K := fun c => algebraMap GF shdP_K (shdEpad Rp.inp ⟨v.val, by omega⟩ c)
  beta.toK shdP_U * (mleAt ev (Function.update (vecPref r k) ⟨k, hk⟩ 1) - mleAt ev (vecPref r k))

/-- Bad set for Stage IN-C D66(3) site `idx : Fin 13` (card `≤ 131072 = 2^17`):
- `idx = 0` (`α`, draw 2): `{ incTauBase v + β · mleAt E_v 0 | v : Fin 131072 }`
- `idx = k + 1` (`r_k`, draw `3 + k`, `k < 12`): `{ -f_v(k) / s_v(k) | v : Fin 131072, s_v(k) ≠ 0 }`. -/
noncomputable def incAlphaBadSet (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072) (embDigest : Dig)
    (idx : Fin 13) (ch : List Fp2) : Finset shdP_K :=
  if h0 : idx.val = 0 then
    Finset.univ.image (fun v : Fin 131072 =>
      let beta := ch.getD 0 Fp2.zero
      let gamma := ch.getD 1 Fp2.zero
      let ev : (Fin 12 → Bool) → shdP_K := fun c => algebraMap GF shdP_K (shdEpad Rp.inp ⟨v.val, by omega⟩ c)
      incTauBase Rp embDigest beta gamma v + beta.toK shdP_U * mleAt ev (fun _ => 0))
  else
    let k := idx.val - 1
    have hk : k < 12 := by have := idx.isLt; omega
    Finset.univ.image (fun v : Fin 131072 => -(incTauDiff Rp hV embDigest ch k v) / incTauSlope Rp hV ch k hk v)

theorem incAlphaBadSet_card (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072) (embDigest : Dig)
    (idx : Fin 13) (ch : List Fp2) :
    (incAlphaBadSet Rp hV embDigest idx ch).card ≤ 2 ^ 17 := by
  unfold incAlphaBadSet
  split_ifs
  · exact (Finset.card_image_le).trans (by simp)
  · exact (Finset.card_image_le).trans (by simp)

/-- **The 13 concrete Stage IN-C D66(3) `startSite`s** (`k = 2^17`, `δ = 0` PROVED — closes Finding L32-5!). -/
noncomputable def shdP_incAlphaStartSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    {rB rA rM : Coins → (HIn → Dig) → Dig}
    (pre : Coins → TProg α) (RB : ∀ c, RootProg (rB c)) (RA : ∀ c, RootProg (rA c)) (RM : ∀ c, RootProg (rM c))
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ (idx : Fin 13) c dg,
      TProg.NoWrap (incHeadDrawProg (shdVi tag Rp embDigest bInRow) (pre c) (RB c) (RA c) (RM c) (2 + idx.val)) ⟨dg, 0, key⟩)
    (idx : Fin 13) : ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  startSite Lq hLq key domain hdom
    (fun c => incHeadDrawProg (shdVi tag Rp embDigest bInRow) (pre c) (RB c) (RA c) (RM c) (2 + idx.val))
    (incAlphaBadSet Rp hV embDigest idx) (2 ^ 17) (incAlphaBadSet_card Rp hV embDigest idx)
    (fun c => sep_incHeadDrawProg key (shdVi tag Rp embDigest bInRow) (pre c) (RB c) (RA c) (RM c) (2 + idx.val) (hs c))
    (hn idx)

theorem shdP_incAlphaStartSite_k_delta {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    {rB rA rM : Coins → (HIn → Dig) → Dig}
    (pre : Coins → TProg α) (RB : ∀ c, RootProg (rB c)) (RA : ∀ c, RootProg (rA c)) (RM : ∀ c, RootProg (rM c))
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ (idx : Fin 13) c dg,
      TProg.NoWrap (incHeadDrawProg (shdVi tag Rp embDigest bInRow) (pre c) (RB c) (RA c) (RM c) (2 + idx.val)) ⟨dg, 0, key⟩)
    (idx : Fin 13) :
    (shdP_incAlphaStartSite Lq hLq key domain hdom tag Rp hV embDigest bInRow pre RB RA RM hs hn idx).k = 2 ^ 17
    ∧ (shdP_incAlphaStartSite Lq hLq key domain hdom tag Rp hV embDigest bInRow pre RB RA RM hs hn idx).δ = 0 :=
  ⟨rfl, rfl⟩

/-- **Stage IN-C D66(3) refusal cover (Finding L32-5 CLOSED)**: whenever `incAlphaBad (incCtx I ch) = true`
on the 15 head draws of `incCh`, at least one of the 13 `shdP_incAlphaStartSite` sites fires! -/
theorem shdP_incAlphaBad_cover {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hIn : Rp.inp.Valid) (hV : Rp.inp.V = 131072)
    (embDigest : Dig) (bInRow : ℕ)
    {rB rA rM : Coins → (HIn → Dig) → Dig}
    (pre : Coins → TProg α) (RB : ∀ c, RootProg (rB c)) (RA : ∀ c, RootProg (rA c)) (RM : ∀ c, RootProg (rM c))
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ (idx : Fin 13) c dg,
      TProg.NoWrap (incHeadDrawProg (shdVi tag Rp embDigest bInRow) (pre c) (RB c) (RA c) (RM c) (2 + idx.val)) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins)
    (D : IncData (shdVi tag Rp embDigest bInRow))
    (hB : D.bRoot = rB c (liftH G)) (hA : D.aRoot = rA c (liftH G)) (hM : D.maskRoot = rM c (liftH G))
    (hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp))
      (incCh (liftH G) (shdVi tag Rp embDigest bInRow) D
        ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1) = true) :
    ∃ idx : Fin 13,
      (shdP_incAlphaStartSite Lq hLq key domain hdom tag Rp hV embDigest bInRow pre RB RA RM hs hn idx).fires shdP_U G c := by
  let V := shdVi tag Rp embDigest bInRow
  let I := shdP_incPub Rp embDigest (embFoldL Rp.inp)
  let t0 := Tr.newKeyed (liftH G) domain key
  let T0 := (absorbRoot (liftH G) (V.frame (liftH G) (rB c (liftH G)) ((pre c).final (liftH G) t0).1)
      labA (rA c (liftH G)) V.lay.aRows V.lay.logN).absorb (liftH G) labM (rM c (liftH G)).toList
  have h15 : incHeadDraws I = 15 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.2.2
  have hvoc : I.vocLog = 17 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.1
  have hch_eq : (incCh (liftH G) V D ((pre c).final (liftH G) t0).1).1 = (T0.challengeFp2Vec (liftH G) 15).1 := by
    unfold incCh; rw [hB, hA, hM, show incHeadDraws V.pub = 15 from h15]
  rw [hch_eq] at hbad
  set ch := (T0.challengeFp2Vec (liftH G) 15).1 with hch_def
  have hchLen : ch.length = 15 := chalVec_length (liftH G) 15 T0
  have hchCan : ∀ a ∈ ch, a.Canon := chalVec_canon (liftH G) 15 T0
  -- Unpack `incAlphaBad = true`: there exists `v < 131072` with `α = τ[v]` in `shdP_K`
  change (incCtx I ch).tauTab.any (fun z => ((incCtx I ch).alpha.sub z).isZero) = true at hbad
  obtain ⟨z, hzMem, hzZero⟩ := List.any_eq_true.mp hbad
  unfold incCtx tauTable at hzMem
  obtain ⟨vNat, hvRng, hzEq⟩ := List.mem_map.mp hzMem
  have hvLt : vNat < 131072 := by rw [List.mem_range, hvoc] at hvRng; exact lt_of_lt_of_eq hvRng (by norm_num)
  let v : Fin 131072 := ⟨vNat, hvLt⟩
  have hvIv : vNat < I.v := by change vNat < Rp.inp.V; omega
  rw [ite_eq_left hvIv] at hzEq
  have hzCan : z.Canon := by rw [← hzEq]; exact Fp2.canon_add _ _
  have halphaCan : (ch.getD 2 Fp2.zero).Canon := Fp2.canon_getD hchCan 2
  have hsub0 : ((ch.getD 2 Fp2.zero).sub z).toK shdP_U = 0 :=
    (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_sub _ _ halphaCan hzCan)).mp hzZero
  rw [Fp2.toK_sub shdP_U _ _ halphaCan hzCan, sub_eq_zero] at hsub0
  -- Compute `z.toK shdP_U = incTauBase v + β · mleAt E_v r`
  have hrLen : (ch.drop 3).length = 12 := by rw [List.length_drop, hchLen]
  have hrCan : ∀ a ∈ ch.drop 3, a.Canon := fun a ha => hchCan a (List.mem_of_mem_drop ha)
  have hemb := embFoldL_hEmb shdP_U shdP_hU Rp.inp hIn (ch.drop 3) hrLen hrCan ⟨v.val, by omega⟩
  have hdrop_getD : ∀ j : Fin 12, ((ch.drop 3).getD j.val Fp2.zero).toK shdP_U = (ch.getD (3 + j.val) Fp2.zero).toK shdP_U := by
    intro j; rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_drop]
  have hfull : vecPref (fun j : Fin 12 => (ch.getD (3 + j.val) Fp2.zero).toK shdP_U) 12
      = fun j : Fin 12 => (ch.getD (3 + j.val) Fp2.zero).toK shdP_U := by
    funext j; unfold vecPref; exact ite_eq_left j.isLt
  have hf12 : incTauDiff Rp hV embDigest ch 12 v = 0 := by
    unfold incTauDiff incTauBase
    rw [hfull, ← hsub0, ← hzEq]
    dsimp only
    rw [Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mulBase _ _),
      Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (by split_ifs <;> [exact Fp2.canon_mul _ _; exact Fp2.canon_zero]),
      Fp2.toK_add shdP_U _ _ (kI_canon _) (Fp2.canon_mul _ _),
      Fp2.toK_mul shdP_U shdP_hU, kI_nat_toK shdP_U v.val (by omega)]
    have hemb' : ((embFoldL Rp.inp (ch.drop 3)).getD v.val Fp2.zero).toK shdP_U
        = mleAt (fun c => algebraMap GF shdP_K (shdEpad Rp.inp ⟨v.val, by omega⟩ c))
            (fun j : Fin 12 => (ch.getD (3 + j.val) Fp2.zero).toK shdP_U) := by
      simpa only [hdrop_getD] using hemb
    rw [hemb']
    have hctl : (if I.ctl v.val = true then (ch.getD 0 Fp2.zero).mul (ch.getD 0 Fp2.zero) else Fp2.zero).toK shdP_U
        = if I.ctl v.val = true then (ch.getD 0 Fp2.zero).toK shdP_U * (ch.getD 0 Fp2.zero).toK shdP_U else 0 := by
      split_ifs
      · exact Fp2.toK_mul shdP_U shdP_hU _ _
      · exact Fp2.toK_zero shdP_U
    rw [hctl]; ring
  -- Apply `HonestRunCount.seq_zero` to `k ↦ incTauDiff ... ch k v`!
  have hstep : ∀ k, k < 12 →
      incTauDiff Rp hV embDigest ch (k + 1) v
        = incTauDiff Rp hV embDigest ch k v
          + (ch.getD (3 + k) Fp2.zero).toK shdP_U
            * (if hk : k < 12 then incTauSlope Rp hV ch k hk v else 0) := by
    intro k hk
    rw [dite_eq_left hk]
    unfold incTauDiff incTauSlope
    dsimp only
    rw [mleAt_vecPref_succ _ _ k hk]
    ring
  rcases seq_zero (fun k => incTauDiff Rp hV embDigest ch k v)
      (fun k => (ch.getD (3 + k) Fp2.zero).toK shdP_U)
      (fun k => if hk : k < 12 then incTauSlope Rp hV ch k hk v else 0) 12 hstep hf12 with
    hf0 | ⟨k, hk, _, hsne, hrk⟩
  · -- Site 0 (`α`, draw 2) fires!
    refine ⟨⟨0, by norm_num⟩, ?_⟩
    rw [shdP_incAlphaStartSite, startSite_fires, final_incHeadDrawProg]
    dsimp only
    rw [Nat.add_zero]
    have hsq2 : challengeFp2Of (liftH G ⟨(T0.challengeFp2Vec (liftH G) 2).2.key,
        squeezeMsg (T0.challengeFp2Vec (liftH G) 2).2.state (T0.challengeFp2Vec (liftH G) 2).2.counter⟩)
        = ch.getD 2 Fp2.zero := (challengeFp2Vec_getD (liftH G) 15 2 T0 (by norm_num)).symm
    rw [hsq2]
    unfold incAlphaBadSet; rw [dite_eq_left rfl, Finset.mem_image]
    refine ⟨v, Finset.mem_univ v, ?_⟩
    have h0eq : (T0.challengeFp2Vec (liftH G) 2).1.getD 0 Fp2.zero = ch.getD 0 Fp2.zero := by
      rw [challengeFp2Vec_getD (liftH G) 2 0 T0 (by norm_num), challengeFp2Vec_getD (liftH G) 15 0 T0 (by norm_num)]
    have h1eq : (T0.challengeFp2Vec (liftH G) 2).1.getD 1 Fp2.zero = ch.getD 1 Fp2.zero := by
      rw [challengeFp2Vec_getD (liftH G) 2 1 T0 (by norm_num), challengeFp2Vec_getD (liftH G) 15 1 T0 (by norm_num)]
    rw [h0eq, h1eq]
    unfold incTauDiff at hf0
    have hpref0 : vecPref (fun j : Fin 12 => (ch.getD (3 + j.val) Fp2.zero).toK shdP_U) 0 = fun _ => 0 := by
      funext j; simp [vecPref]
    rw [hpref0, sub_eq_zero] at hf0
    exact hf0
  · -- Site `k + 1` (`r_k`, draw `3 + k`) fires!
    refine ⟨⟨k + 1, by omega⟩, ?_⟩
    rw [shdP_incAlphaStartSite, startSite_fires, final_incHeadDrawProg]
    dsimp only
    have hidx : 2 + (k + 1) = 3 + k := by omega
    rw [hidx]
    have hsqk : challengeFp2Of (liftH G ⟨(T0.challengeFp2Vec (liftH G) (3 + k)).2.key,
        squeezeMsg (T0.challengeFp2Vec (liftH G) (3 + k)).2.state (T0.challengeFp2Vec (liftH G) (3 + k)).2.counter⟩)
        = ch.getD (3 + k) Fp2.zero := (challengeFp2Vec_getD (liftH G) 15 (3 + k) T0 (by omega)).symm
    rw [hsqk]
    unfold incAlphaBadSet; rw [dite_eq_right (by omega), Finset.mem_image]
    refine ⟨v, Finset.mem_univ v, ?_⟩
    -- Prefix agreement: `(T0.challengeFp2Vec (3 + k)).1` agrees with `ch` on all indices `< 3 + k`!
    have hget : ∀ m, m < 3 + k → (T0.challengeFp2Vec (liftH G) (3 + k)).1.getD m Fp2.zero = ch.getD m Fp2.zero := fun m hm => by
      rw [challengeFp2Vec_getD (liftH G) (3 + k) m T0 hm, challengeFp2Vec_getD (liftH G) 15 m T0 (by omega)]
    have hpref_eq : vecPref (fun j : Fin 12 => ((T0.challengeFp2Vec (liftH G) (3 + k)).1.getD (3 + j.val) Fp2.zero).toK shdP_U) k
        = vecPref (fun j : Fin 12 => (ch.getD (3 + j.val) Fp2.zero).toK shdP_U) k := by
      funext j; unfold vecPref
      by_cases hj : j.val < k
      · rw [ite_eq_left hj, ite_eq_left hj, hget (3 + j.val) (by omega)]
      · rw [ite_eq_right hj, ite_eq_right hj]
    have hdiff_eq : incTauDiff Rp hV embDigest (T0.challengeFp2Vec (liftH G) (3 + k)).1 k v
        = incTauDiff Rp hV embDigest ch k v := by
      unfold incTauDiff
      rw [hget 0 (by omega), hget 1 (by omega), hget 2 (by omega), hpref_eq]
    have hslope_eq : incTauSlope Rp hV (T0.challengeFp2Vec (liftH G) (3 + k)).1 k hk v
        = incTauSlope Rp hV ch k hk v := by
      unfold incTauSlope
      rw [hget 0 (by omega), hpref_eq]
    rw [dite_eq_left hk] at hrk
    change -(incTauDiff Rp hV embDigest (T0.challengeFp2Vec (liftH G) (3 + k)).1 k v)
        / incTauSlope Rp hV (T0.challengeFp2Vec (liftH G) (3 + k)).1 k hk v = _
    rw [hdiff_eq, hslope_eq, ← hrk]

end IncAlphaSites

/-! ## 4. `startSite` lifts for `outcAlphaSite` and `checkOpening_cover` -/

section StartSiteLifts

variable {α Coins : Type} [Fintype Coins] [Nonempty Coins]
  (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)

/-- **`startSite` lift of `outcAlphaSite`** (`k = 256`, `δ = 0` PROVED). -/
noncomputable def shdP_outcAlphaStartSite (V : OutcV)
    {rA rM : Coins → (HIn → Dig) → Dig} (pre : Coins → TProg α)
    (RA : ∀ c, RootProg (rA c)) (RM : ∀ c, RootProg (rM c))
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ c dg, TProg.NoWrap (outcAlphaProg V (pre c) (RA c) (RM c)) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  startSite Lq hLq key domain hdom
    (fun c => outcAlphaProg V (pre c) (RA c) (RM c)) (u8Bad shdP_U) 256 (u8Bad_card shdP_U)
    (fun c => sep_outcAlphaProg V key (pre c) (RA c) (RM c) (hs c)) hn

theorem shdP_outcAlphaBad_cover (V : OutcV)
    {rA rM : Coins → (HIn → Dig) → Dig} (pre : Coins → TProg α)
    (RA : ∀ c, RootProg (rA c)) (RM : ∀ c, RootProg (rM c))
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ c dg, TProg.NoWrap (outcAlphaProg V (pre c) (RA c) (RM c)) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) (D : OutcData V)
    (hA : D.aRoot = rA c (liftH G)) (hM : D.maskRoot = rM c (liftH G))
    (hbad : outcAlphaBad (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1 = true) :
    (shdP_outcAlphaStartSite Lq hLq key domain hdom V pre RA RM hs hn).fires shdP_U G c := by
  unfold shdP_outcAlphaStartSite
  rw [startSite_fires_iff_tprogSite]
  -- Match `outcAlphaSite` at constant `(fun _ => pre c)`, `RA c`, `RM c`
  have hf := (outcAlphaSite_fires Lq hLq V shdP_U shdP_hU (fun _ => pre c) (RA c) (RM c)
    (fun _ => Tr.newKeyed (liftH G) domain key) (fun _ => hs c) (fun _ => hn c _) G c D hA hM).mpr hbad
  rw [tprogSite_fires] at hf ⊢
  exact hf

/-- **`startSite` lift of `HonestRun.openSite`** (`Option (Fin n ⊕ Unit)`, `k ∈ {1, gP}`, `δ = 0` PROVED). -/
noncomputable def shdP_openStartSite (n prox : ℕ) (pre : Coins → TProg α)
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ (j : ℕ) (c : Coins) (dg : Dig), TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩) :
    Option (Fin n ⊕ Unit) → ProtocolClassify.Site (QB Lq) Coins shdP_K
  | some (.inl i) =>
      startSite Lq hLq key domain hdom (fun c => drawProg i.val (pre c)) (fun _ => {0}) 1
        (fun _ => by simp) (fun c => sep_drawProg key i.val (pre c) (hs c)) (hn i.val)
  | some (.inr _) =>
      startSite Lq hLq key domain hdom (fun c => drawProg (n + prox) (pre c)) (fun _ => {0}) 1
        (fun _ => by simp) (fun c => sep_drawProg key (n + prox) (pre c) (hs c)) (hn (n + prox))
  | none =>
      startSite Lq hLq key domain hdom (fun c => drawProg (n + prox + 1) (pre c))
        (fun a => lineBad shdP_U (a.2.getD (n + prox) Fp2.zero))
        gP (fun _ => lineBad_card shdP_U _)
        (fun c => sep_drawProg key (n + prox + 1) (pre c) (hs c)) (hn (n + prox + 1))

theorem shdP_openStartSite_k_delta (n prox : ℕ) (pre : Coins → TProg α)
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ (j : ℕ) (c : Coins) (dg : Dig), TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩) :
    ∀ i, (shdP_openStartSite Lq hLq key domain hdom n prox pre hs hn i).k = openK i
      ∧ (shdP_openStartSite Lq hLq key domain hdom n prox pre hs hn i).δ = 0
  | some (.inl _) => ⟨rfl, rfl⟩
  | some (.inr _) => ⟨rfl, rfl⟩
  | none => ⟨rfl, rfl⟩

/-- **`startSite` lift of `HonestRun.checkOpening_cover`**: transports `checkOpening_cover` to `startSite`
in 10 lines via `startSite_fires_iff_tprogSite`! -/
theorem shdP_checkOpening_startCover (g : OpenGeom) (logN n : ℕ) (pre : Coins → TProg α)
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ (j : ℕ) (c : Coins) (dg : Dig), TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) (claims : List Exec.Block.ZClaim) (hcl : claims.length = n) (e : String)
    (h : checkOpeningExec (liftH G) g logN claims ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 = .error e) :
    (∃ e', auditClaims claims (2 ^ logN) g.rows g.siteRows g.sumRows g.prox = .error e')
      ∨ (∃ e', openingGroupsAt claims logN = .error e')
      ∨ (∃ groups, openingGroupsAt claims logN = .ok groups ∧ groups.length ≠ g.groups)
      ∨ g.rows ≤ g.prox + 1
      ∨ ∃ i, (shdP_openStartSite Lq hLq key domain hdom n g.prox pre hs hn i).fires shdP_U G c := by
  rcases checkOpening_cover Lq hLq shdP_U shdP_hU g logN n pre (fun _ => Tr.newKeyed (liftH G) domain key)
      hs (fun j c' => hn j c' _) G c claims hcl e h with h1 | h2 | h3 | h4 | ⟨i, hi⟩
  · exact Or.inl h1
  · exact Or.inr (Or.inl h2)
  · exact Or.inr (Or.inr (Or.inl h3))
  · exact Or.inr (Or.inr (Or.inr (Or.inl h4)))
  · refine Or.inr (Or.inr (Or.inr (Or.inr ⟨i, ?_⟩)))
    cases i with
    | none =>
      unfold shdP_openStartSite
      rw [startSite_fires_iff_tprogSite]
      exact hi
    | some u =>
      cases u with
      | inl j =>
        unfold shdP_openStartSite
        rw [startSite_fires_iff_tprogSite]
        exact hi
      | inr _ =>
        unfold shdP_openStartSite
        rw [startSite_fires_iff_tprogSite]
        exact hi

end StartSiteLifts

end ZK60.HonestShield
