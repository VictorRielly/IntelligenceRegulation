/-
D63 lane L69, Milestone A Part 2e-1 (`HonestShieldZKCountShape.lean`):
discharges ALL counting, visibility, pure `v`-only refusal, and unopened-leaf salt-invariance
obligations of `HonestShieldZK.ShdZKCountWitness` for the concrete 28-segment Shieldstral T128 R13
fixed-schedule honest prover `shdP_runFixedProg` (`shdP_honestRunP_zk`):
1. **Atomic `.res` determinism & `ptAt` equality lemmas**:
   exact `.res` transcript-state/counter determinism and wire-output-determined `ptAt` equality across
   `trAbsorbKeyed`, `trSqueezeKeyed`, `trChallengeFp2VecKeyed`, `trSqueezeVecKeyed`, `posTagKeyed`,
   `absorbRootKeyed`, `shdP_hdrPProgF`, `scProveFixedProg`, `trAbsorbVecsFixed`, `slotProveFixedProg`,
   `slotsProveFixedProg`, `stSlotsProveFixedProg`, `zkBMaskFixedProg`, and `openingAuditFixedProg`.
2. **Pure `v`-only refusal invariance (`shdRunRefused`, `shdP_runFixedProg_active_indep`)**:
   proves that every refusal check across `IN-C`, all `26` interior R13 blocks, and `OUT-C` (including
   verdict-independent `outcDefine` tab shapes) depends ONLY on `v` — completely independent of `(x, c)`!
3. **Unopened-leaf salt invariance (`shdP_runFixedProg_setLeaf_outOf`)**:
   proves `PProg.outOf (shdP_runFixedProg x (shdCoinsSetLeaf c id d)) v = PProg.outOf (shdP_runFixedProg x c) v`
   for every unopened leaf `id.2.val ∉ shdOpenedCols v id.1` across all 112 Merkle trees.
4. **Active-run wire recovery (`decodeStage_enc`, `decodeSegment_enc`), visibility (`shdP_runVisSpec`),
   and master `ShdZKCountWitness` (`shdP_zkCountWitness`)**:
   proves `outOf (x₁, c₁) v = outOf (x₂, c₂) v → ptsOf (x₁, c₁) H v i = ptsOf (x₂, c₂) H v i` for every
   visible index `i` (all non-leaves + opened leaves) and calls `shdZKCountWitness_of_schedule`!

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKFixedProg

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun ZK60.ZKHonest
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldShape ShieldRun shieldS0)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec Segment SegGeom
  CoreCanon CoreShape HidingCanon HidingShape MaskCanon SlotCanon
  labA labH labM labRows labLogCols labPbSlot labPbScalar labPbTerm)
open ZK60.Circuit (gP GF)

/-! ## 1. Atomic `.res` Transcript Determinism & `ptAt` Equality Lemmas -/

section AtomicResAndPtAt

theorem _root_.ZK60.ZKHonest.PProg.PtLen.congr {Q D α : Type} {p : PProg Q D α} {m n : ℕ}
    (h : p.PtLen m) (heq : m = n) : p.PtLen n := heq ▸ h

private theorem uint64_add_ofNat_succ (c : UInt64) (n : ℕ) :
    c + 1 + UInt64.ofNat n = c + UInt64.ofNat (n + 1) := by
  rw [UInt64.add_assoc, UInt64.ofNat_add, UInt64.add_comm 1]; rfl

private theorem uint64_add_ofNat_zero (c : UInt64) : c + UInt64.ofNat 0 = c :=
  UInt64.add_zero c

theorem res_andThen_same {Q D α β₁ β₂ : Type}
    {p₁ p₂ : PProg Q D α} {f₁ : α → PProg Q D β₁} {f₂ : α → PProg Q D β₂}
    {n : ℕ} (hp₁ : p₁.PtLen n) (hp₂ : p₂.PtLen n)
    {H : Q → D} {v : ℕ → D} {base : ℕ} {a : α}
    (ha₁ : p₁.res H v base = a) (ha₂ : p₂.res H v base = a)
    {B : β₁ → β₂ → Prop}
    (hf : B ((f₁ a).res H v (base + n)) ((f₂ a).res H v (base + n))) :
    B ((p₁.andThen f₁).res H v base) ((p₂.andThen f₂).res H v base) := by
  rw [PProg.res_andThen H v p₁ f₁ n base hp₁, PProg.res_andThen H v p₂ f₂ n base hp₂, ha₁, ha₂]
  exact hf

theorem res_andThen_rel {Q D α₁ α₂ β₁ β₂ : Type}
    {p₁ : PProg Q D α₁} {f₁ : α₁ → PProg Q D β₁}
    {p₂ : PProg Q D α₂} {f₂ : α₂ → PProg Q D β₂}
    {n : ℕ} (hp₁ : p₁.PtLen n) (hp₂ : p₂.PtLen n)
    {H : Q → D} {v : ℕ → D} {base : ℕ}
    {A : α₁ → α₂ → Prop} {B : β₁ → β₂ → Prop}
    (ha : A (p₁.res H v base) (p₂.res H v base))
    (hf : ∀ a₁ a₂, A a₁ a₂ → B ((f₁ a₁).res H v (base + n)) ((f₂ a₂).res H v (base + n))) :
    B ((p₁.andThen f₁).res H v base) ((p₂.andThen f₂).res H v base) := by
  rw [PProg.res_andThen H v p₁ f₁ n base hp₁, PProg.res_andThen H v p₂ f₂ n base hp₂]
  exact hf _ _ ha

theorem res_andThen_self {Q D α β₁ β₂ : Type}
    {p : PProg Q D α} {f₁ : α → PProg Q D β₁} {f₂ : α → PProg Q D β₂}
    {n : ℕ} (hp : p.PtLen n) {H : Q → D} {v : ℕ → D} {base : ℕ}
    {B : β₁ → β₂ → Prop}
    (hf : ∀ a, B ((f₁ a).res H v (base + n)) ((f₂ a).res H v (base + n))) :
    B ((p.andThen f₁).res H v base) ((p.andThen f₂).res H v base) :=
  res_andThen_rel (A := Eq) hp hp rfl (fun _ _ h => h ▸ hf _)

theorem res_andThen_eq {Q D α β : Type}
    {p₁ p₂ : PProg Q D α} {f₁ f₂ : α → PProg Q D β}
    {n : ℕ} (hp₁ : p₁.PtLen n) (hp₂ : p₂.PtLen n)
    {H : Q → D} {v : ℕ → D} {base : ℕ}
    (ha : p₁.res H v base = p₂.res H v base)
    (hf : ∀ a, (f₁ a).res H v (base + n) = (f₂ a).res H v (base + n)) :
    (p₁.andThen f₁).res H v base = (p₂.andThen f₂).res H v base :=
  res_andThen_rel (A := Eq) (B := Eq) hp₁ hp₂ ha fun _ _ h => h ▸ hf _

theorem res_andThen_hyp {Q D α β : Type} {H : Q → D} {v : ℕ → D} {base n : ℕ}
    {p : PProg Q D α} {k : α → PProg Q D β} {r : α} {y : β}
    (hp : p.PtLen n) (hr : p.res H v base = r)
    (h : (p.andThen k).res H v base = y) :
    (k r).res H v (base + n) = y := by
  rwa [PProg.res_andThen H v p k n base hp, hr] at h

theorem res_andThen_hyp_id {Q D α β : Type} {H : Q → D} {v : ℕ → D} {base n : ℕ}
    {p : PProg Q D α} {k : α → PProg Q D β} {y : β}
    (hp : p.PtLen n) (h : (p.andThen k).res H v base = y) :
    (k (p.res H v base)).res H v (base + n) = y :=
  res_andThen_hyp hp rfl h

theorem res_andThen_hyp_bind {Q D α β : Type} {H : Q → D} {v : ℕ → D} {base n : ℕ}
    {p : PProg Q D α} {k : α → PProg Q D β} {y : β}
    (hp : p.PtLen n) (h : (p.andThen k).res H v base = y) :
    ∃ r, p.res H v base = r ∧ (k r).res H v (base + n) = y :=
  ⟨p.res H v base, rfl, res_andThen_hyp hp rfl h⟩

theorem ptAt_andThen_step {Q D α β : Type} {H : Q → D} {v : ℕ → D} {base j n : ℕ}
    {p₁ p₂ : PProg Q D α} {k₁ k₂ : α → PProg Q D β}
    (h1 : p₁.PtLen n) (h2 : p₂.PtLen n)
    (hL : j < base + n → p₁.ptAt H v base j = p₂.ptAt H v base j)
    (hR : base + n ≤ j → (k₁ (p₁.res H v base)).ptAt H v (base + n) j = (k₂ (p₂.res H v base)).ptAt H v (base + n) j) :
    (p₁.andThen k₁).ptAt H v base j = (p₂.andThen k₂).ptAt H v base j := by
  by_cases hj : j < base + n
  · rw [PProg.ptAt_andThen_left H v p₁ k₁ n base j h1 hj, PProg.ptAt_andThen_left H v p₂ k₂ n base j h2 hj]
    exact hL hj
  · rw [PProg.ptAt_andThen_right H v p₁ k₁ n base j h1 (Nat.not_lt.mp hj),
        PProg.ptAt_andThen_right H v p₂ k₂ n base j h2 (Nat.not_lt.mp hj)]
    exact hR (Nat.not_lt.mp hj)

theorem ptAt_andThen_same {Q D α β : Type} {H : Q → D} {v : ℕ → D} {base j n : ℕ}
    {p₁ p₂ : PProg Q D α} {k₁ k₂ : α → PProg Q D β} {r : α}
    (h1 : p₁.PtLen n) (h2 : p₂.PtLen n)
    (hr₁ : p₁.res H v base = r) (hr₂ : p₂.res H v base = r)
    (hL : j < base + n → p₁.ptAt H v base j = p₂.ptAt H v base j)
    (hR : base + n ≤ j → (k₁ r).ptAt H v (base + n) j = (k₂ r).ptAt H v (base + n) j) :
    (p₁.andThen k₁).ptAt H v base j = (p₂.andThen k₂).ptAt H v base j :=
  ptAt_andThen_step h1 h2 hL fun hj => by rw [hr₁, hr₂]; exact hR hj

theorem ptAt_andThen_step_res {Q D α β : Type} {H : Q → D} {v : ℕ → D} {base j n : ℕ}
    {p₁ p₂ : PProg Q D α} {k₁ k₂ : α → PProg Q D β} {r₁ r₂ : α}
    (h1 : p₁.PtLen n) (h2 : p₂.PtLen n)
    (hr₁ : p₁.res H v base = r₁) (hr₂ : p₂.res H v base = r₂)
    (hL : j < base + n → p₁.ptAt H v base j = p₂.ptAt H v base j)
    (hR : base + n ≤ j → (k₁ r₁).ptAt H v (base + n) j = (k₂ r₂).ptAt H v (base + n) j) :
    (p₁.andThen k₁).ptAt H v base j = (p₂.andThen k₂).ptAt H v base j :=
  ptAt_andThen_step h1 h2 hL fun hj => by rw [hr₁, hr₂]; exact hR hj

theorem ptAt_andThen_self {Q D α β : Type} {H : Q → D} {v : ℕ → D} {base j n : ℕ}
    {p : PProg Q D α} {k₁ k₂ : α → PProg Q D β} {r : α}
    (hp : p.PtLen n) (hr : p.res H v base = r)
    (hR : base + n ≤ j → (k₁ r).ptAt H v (base + n) j = (k₂ r).ptAt H v (base + n) j) :
    (p.andThen k₁).ptAt H v base j = (p.andThen k₂).ptAt H v base j :=
  ptAt_andThen_same hp hp hr hr (fun _ => rfl) hR

def PProgResIndepH {Q D α : Type} (p : PProg Q D α) : Prop :=
  ∀ (H₁ H₂ : Q → D) (v : ℕ → D) (base : ℕ), p.res H₁ v base = p.res H₂ v base

theorem PProgResIndepH.ret {Q D α : Type} (a : α) : PProgResIndepH (PProg.ret (Q := Q) (D := D) a) :=
  fun _ _ _ _ => rfl

theorem PProgResIndepH.of_eq {Q D α : Type} {p : PProg Q D α} {g : (ℕ → D) → ℕ → α}
    (h : ∀ H v b, p.res H v b = g v b) : PProgResIndepH p :=
  fun H₁ H₂ v b => (h H₁ v b).trans (h H₂ v b).symm

theorem PProgResIndepH.andThen {Q D α β : Type} {p : PProg Q D α} {f : α → PProg Q D β}
    {n : ℕ} (hpt : p.PtLen n) (hp : PProgResIndepH p) (hf : ∀ a, PProgResIndepH (f a)) :
    PProgResIndepH (p.andThen f) := fun H₁ H₂ v base => by
  rw [PProg.res_andThen H₁ v p f n base hpt, PProg.res_andThen H₂ v p f n base hpt,
      hp H₁ H₂ v base]
  exact hf _ H₁ H₂ v (base + n)

theorem merkleLevels_path_length : ∀ {d : ℕ} (tr : MerkleLevels d) (j : ℕ) (hj : j < 2 ^ d),
    (tr.path j hj).length = d
  | 0, .root _, _, _ => rfl
  | d + 1, .layer _ up, j, hj => by
    simp only [MerkleLevels.path, List.length_cons, merkleLevels_path_length up]

theorem merkleLevels_pathD_length {d : ℕ} (tr : MerkleLevels d) (j : ℕ) (hj : j < 2 ^ d) :
    (tr.pathD j).length = d := by
  unfold MerkleLevels.pathD; rw [dite_eq_left hj]; exact merkleLevels_path_length tr j hj

theorem trSqueezeKeyed_res (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trSqueezeKeyed Lq h47 key t).res H v i = (v i, { t with state := v i, counter := t.counter + 1, key := key }) := rfl

theorem trChallengeFp2Keyed_res (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr)
    (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trChallengeFp2Keyed Lq h47 key t).res H v i
      = (challengeFp2Of (v i), { t with state := v i, counter := t.counter + 1, key := key }) := rfl

theorem trChallengeFp2Keyed_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) :
    (trChallengeFp2Keyed Lq h47 key t).PtLen 1 :=
  (trSqueezeKeyed_ptLen Lq h47 key t).andThen (n := 0) (fun _ => rfl)

theorem trChallengeFp2VecKeyed_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) :
    ∀ (n : ℕ) (t : Tr), (trChallengeFp2VecKeyed Lq h47 key n t).PtLen n
  | 0, _ => rfl
  | n + 1, t => by
    unfold trChallengeFp2VecKeyed
    rw [show n + 1 = 1 + (n + 0) by omega]
    exact (trChallengeFp2Keyed_ptLen Lq h47 key t).andThen fun r =>
      (trChallengeFp2VecKeyed_ptLen Lq h47 key n r.2).andThen (n := 0) (fun _ => rfl)

theorem trChallengeFp2VecKeyed_res (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (n : ℕ) (t : Tr) (base : ℕ),
      (trChallengeFp2VecKeyed Lq h47 key n t).res H v base =
        ((List.range n).map (fun k => challengeFp2Of (v (base + k))),
          if n = 0 then t else ⟨v (base + n - 1), t.counter + UInt64.ofNat n, key⟩)
  | 0, t, _ => rfl
  | n + 1, t, base => by
    unfold trChallengeFp2VecKeyed
    rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq h47 key t),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ n (base + 1) (trChallengeFp2VecKeyed_ptLen Lq h47 key n _),
      trChallengeFp2VecKeyed_res Lq h47 key H v n _ (base + 1)]
    simp only [PProg.res, List.range_succ_eq_map, List.map_cons, List.map_map, Nat.add_zero]
    refine Prod.ext (congrArg (challengeFp2Of (v base) :: ·) (List.map_congr_left fun k _ => ?_)) ?_
    · show challengeFp2Of (v (base + 1 + k)) = challengeFp2Of (v (base + (k + 1))); congr 2; omega
    · rw [ite_eq_right (Nat.succ_ne_zero n)]
      cases n with
      | zero => rfl
      | succ m =>
        rw [ite_eq_right (Nat.succ_ne_zero m)]
        show Tr.mk (v (base + 1 + (m + 1) - 1)) (t.counter + 1 + UInt64.ofNat (m + 1)) key
          = Tr.mk (v (base + (m + 1 + 1) - 1)) (t.counter + UInt64.ofNat (m + 1 + 1)) key
        rw [show base + 1 + (m + 1) - 1 = base + (m + 1 + 1) - 1 by omega,
          uint64_add_ofNat_succ t.counter (m + 1)]

theorem trSqueezeVecKeyed_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) :
    ∀ (n : ℕ) (t : Tr), (trSqueezeVecKeyed Lq h47 key n t).PtLen n
  | 0, _ => rfl
  | n + 1, t => by
    unfold trSqueezeVecKeyed
    rw [show n + 1 = 1 + (n + 0) by omega]
    exact (trSqueezeKeyed_ptLen Lq h47 key t).andThen fun r =>
      (trSqueezeVecKeyed_ptLen Lq h47 key n r.2).andThen (n := 0) (fun _ => rfl)

theorem trSqueezeVecKeyed_res (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (n : ℕ) (t : Tr) (base : ℕ),
      (trSqueezeVecKeyed Lq h47 key n t).res H v base =
        ((List.range n).map (fun k => v (base + k)),
          if n = 0 then t else ⟨v (base + n - 1), t.counter + UInt64.ofNat n, key⟩)
  | 0, t, _ => rfl
  | n + 1, t, base => by
    unfold trSqueezeVecKeyed
    rw [PProg.res_andThen H v _ _ 1 base (trSqueezeKeyed_ptLen Lq h47 key t),
      trSqueezeKeyed_res,
      PProg.res_andThen H v _ _ n (base + 1) (trSqueezeVecKeyed_ptLen Lq h47 key n _),
      trSqueezeVecKeyed_res Lq h47 key H v n _ (base + 1)]
    simp only [PProg.res, List.range_succ_eq_map, List.map_cons, List.map_map, Nat.add_zero]
    refine Prod.ext (congrArg (v base :: ·) (List.map_congr_left fun k _ => ?_)) ?_
    · show v (base + 1 + k) = v (base + (k + 1)); congr 1; omega
    · rw [ite_eq_right (Nat.succ_ne_zero n)]
      cases n with
      | zero => rfl
      | succ m =>
        rw [ite_eq_right (Nat.succ_ne_zero m)]
        show Tr.mk (v (base + 1 + (m + 1) - 1)) (t.counter + 1 + UInt64.ofNat (m + 1)) key
          = Tr.mk (v (base + (m + 1 + 1) - 1)) (t.counter + UInt64.ofNat (m + 1 + 1)) key
        rw [show base + 1 + (m + 1) - 1 = base + (m + 1 + 1) - 1 by omega,
          uint64_add_ofNat_succ t.counter (m + 1)]

theorem posTagKeyed_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr) :
    (posTagKeyed Lq h47 key t).PtLen 2 := by
  unfold posTagKeyed
  rw [show (2 : ℕ) = 1 + (1 + 0) from rfl]
  exact (trChallengeFp2Keyed_ptLen Lq h47 key t).andThen fun a =>
    (trChallengeFp2Keyed_ptLen Lq h47 key a.2).andThen (n := 0) (fun _ => rfl)

theorem posTagKeyed_res (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (t : Tr)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    (posTagKeyed Lq h47 key t).res H v base = posTagOfV v base := by
  unfold posTagKeyed posTagOfV
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq h47 key t),
    trChallengeFp2Keyed_res,
    PProg.res_andThen H v _ _ 1 (base + 1) (trChallengeFp2Keyed_ptLen Lq h47 key _),
    trChallengeFp2Keyed_res]
  rfl

theorem absorbRootKeyed_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (root : Dig) (rows logCols : ℕ) :
    (absorbRootKeyed Lq hL20 key t label hlab root rows logCols).PtLen 3 := by
  unfold absorbRootKeyed
  rw [show (3 : ℕ) = 1 + (1 + 1) by norm_num]
  exact (trAbsorbKeyed_ptLen Lq hL20 key t label hlab _).andThen fun _ =>
    (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
      trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _

theorem absorbRootKeyed_res (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (t : Tr)
    (label : List UInt8) (hlab : label.length ≤ 64) (root : Dig) (rows logCols : ℕ)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    (absorbRootKeyed Lq hL20 key t label hlab root rows logCols).res H v base
      = { t with state := v (base + 2), key := key } := by
  unfold absorbRootKeyed
  rw [PProg.res_andThen H v _ _ 1 base (trAbsorbKeyed_ptLen Lq hL20 key t label hlab _),
    trAbsorbKeyed_res,
    PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbKeyed_res, trAbsorbKeyed_res]

theorem shdP_hdrPProgF_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) :
    (shdP_hdrPProgF Lq hL20 key w hfit inRoot verdict).PtLen 7 := by
  unfold shdP_hdrPProgF
  intro _ _
  refine ⟨6, rfl, fun _ => ?_⟩
  rw [show (6 : ℕ) = 1 + (1 + (1 + (1 + (1 + 1)))) by norm_num]
  exact (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
    (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
      (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
        (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
          (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
            trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _

theorem shdP_hdrPProgF_res (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    (shdP_hdrPProgF Lq hL20 key w hfit inRoot verdict).res H v base = ⟨v (base + 6), 0, key⟩ := by
  unfold shdP_hdrPProgF
  dsimp only [PProg.res]
  rw [PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _), trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _), trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + 1) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _), trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + 1 + 1) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _), trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + 1 + 1 + 1) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _), trAbsorbKeyed_res,
      trAbsorbKeyed_res]

theorem trAbsorbVecsFixed_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) :
    ∀ (k : ℕ) (vs : List (List Fp2)) (t : Tr), (trAbsorbVecsFixed Lq hL20 key k vs t).PtLen k
  | 0, _, _ => rfl
  | k + 1, vs, t => by
    unfold trAbsorbVecsFixed
    rw [show k + 1 = 1 + k by omega]
    exact (trAbsorbFp2Keyed_ptLen Lq hL20 key t pcsVecLabel (by decide) _).andThen fun t1 =>
      trAbsorbVecsFixed_ptLen Lq hL20 key k vs.tail t1

theorem trAbsorbVecsFixed_res (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (k : ℕ) (vs : List (List Fp2)) (t : Tr) (base : ℕ),
      (trAbsorbVecsFixed Lq hL20 key k vs t).res H v base =
        if k = 0 then t else { t with state := v (base + k - 1), key := key }
  | 0, _, t, _ => rfl
  | k + 1, vs, t, base => by
    unfold trAbsorbVecsFixed
    rw [PProg.res_andThen H v _ _ 1 base (trAbsorbFp2Keyed_ptLen Lq hL20 key t pcsVecLabel (by decide) _),
      trAbsorbFp2Keyed_res, trAbsorbVecsFixed_res Lq hL20 key H v k vs.tail _ (base + 1),
      ite_eq_right (Nat.succ_ne_zero k)]
    cases k with
    | zero => simp
    | succ m =>
      rw [ite_eq_right (Nat.succ_ne_zero m)]
      simp only [show base + 1 + (m + 1) - 1 = base + (m + 1 + 1) - 1 by omega]

theorem scProveFixedProg_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) :
    ∀ (n : ℕ) (active : Bool) (wp : WProver n) (t : Tr),
      (scProveFixedProg Lq hL20 key n active wp t).PtLen (2 * n)
  | 0, _, _, _ => rfl
  | n + 1, active, wp, t => by
    unfold scProveFixedProg
    rw [show 2 * (n + 1) = 1 + (1 + (2 * n + 0)) by omega]
    exact (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _).andThen fun t1 =>
      (trChallengeFp2Keyed_ptLen Lq (by omega) key t1).andThen fun rt =>
        (scProveFixedProg_ptLen Lq hL20 key n active (wp.2 rt.1) rt.2).andThen (n := 0) (fun _ => rfl)

theorem scProveFixedProg_res_spec (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (n : ℕ) (active : Bool) (wp : WProver n) (t : Tr) (base : ℕ),
      let r := (scProveFixedProg Lq hL20 key n active wp t).res H v base
      r.1.length = n
        ∧ r.2.1 = (List.range n).map (fun j => challengeFp2Of (v (base + 2 * j + 1)))
        ∧ r.2.2 = (if n = 0 then t else ⟨v (base + 2 * n - 1), t.counter + UInt64.ofNat n, key⟩)
  | 0, _, _, t, _ => ⟨rfl, rfl, rfl⟩
  | n + 1, active, wp, t, base => by
    dsimp only
    unfold scProveFixedProg
    rw [PProg.res_andThen H v _ _ 1 base (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * n) (base + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key n active _ _)]
    have ih := scProveFixedProg_res_spec Lq hL20 key H v n active (wp.2 (challengeFp2Of (v (base + 1))))
      ⟨v (base + 1), t.counter + 1, key⟩ (base + 1 + 1)
    dsimp only at ih
    refine ⟨by simp [PProg.res, ih.1], ?_, ?_⟩
    · simp only [PProg.res, ih.2.1, List.range_succ_eq_map, List.map_cons, List.map_map]
      congr 1
      refine List.map_congr_left fun k _ => ?_
      show challengeFp2Of (v (base + 1 + 1 + 2 * k + 1)) = challengeFp2Of (v (base + 2 * (k + 1) + 1))
      congr 2; omega
    · simp only [PProg.res, ih.2.2, ite_eq_right (Nat.succ_ne_zero n)]
      cases n with
      | zero => rfl
      | succ m =>
        rw [ite_eq_right (Nat.succ_ne_zero m)]
        congr 1
        · congr 1; omega
        · exact uint64_add_ofNat_succ t.counter (m + 1)

theorem scProveFixedProg_ptAt_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (n : ℕ) (active₁ active₂ : Bool) (wp₁ wp₂ : WProver n) (t : Tr) (base j : ℕ),
      ((scProveFixedProg Lq hL20 key n active₁ wp₁ t).res H v base).1 =
        ((scProveFixedProg Lq hL20 key n active₂ wp₂ t).res H v base).1 →
      (scProveFixedProg Lq hL20 key n active₁ wp₁ t).ptAt H v base j =
        (scProveFixedProg Lq hL20 key n active₂ wp₂ t).ptAt H v base j
  | 0, _, _, _, _, _, _, _, _ => rfl
  | n + 1, active₁, active₂, wp₁, wp₂, t, base, j, hEq => by
    unfold scProveFixedProg at hEq ⊢
    rw [PProg.res_andThen H v _ _ 1 base (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _),
        trAbsorbFp2Keyed_res,
        PProg.res_andThen H v _ _ 1 (base + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
        trChallengeFp2Keyed_res,
        PProg.res_andThen H v _ _ (2 * n) (base + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key n active₁ _ _),
        PProg.res_andThen H v _ _ 1 base (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _),
        trAbsorbFp2Keyed_res,
        PProg.res_andThen H v _ _ 1 (base + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
        trChallengeFp2Keyed_res,
        PProg.res_andThen H v _ _ (2 * n) (base + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key n active₂ _ _)] at hEq
    simp only [PProg.res, List.cons.injEq] at hEq
    obtain ⟨hmEq, hrestEq⟩ := hEq
    by_cases hj1 : j < base + 1
    · rw [PProg.ptAt_andThen_left H v _ _ 1 base j (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _) hj1,
          PProg.ptAt_andThen_left H v _ _ 1 base j (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _) hj1]
      rw [hmEq]
    · rw [PProg.ptAt_andThen_right H v _ _ 1 base j (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _) (by omega),
          PProg.ptAt_andThen_right H v _ _ 1 base j (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _) (by omega),
          trAbsorbFp2Keyed_res, trAbsorbFp2Keyed_res]
      by_cases hj2 : j < base + 1 + 1
      · rw [PProg.ptAt_andThen_left H v _ _ 1 (base + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) hj2,
            PProg.ptAt_andThen_left H v _ _ 1 (base + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) hj2]
      · rw [PProg.ptAt_andThen_right H v _ _ 1 (base + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (by omega),
            PProg.ptAt_andThen_right H v _ _ 1 (base + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (by omega),
            trChallengeFp2Keyed_res]
        by_cases hj3 : j < base + 1 + 1 + 2 * n
        · rw [PProg.ptAt_andThen_left H v _ _ (2 * n) (base + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key n active₁ _ _) hj3,
              PProg.ptAt_andThen_left H v _ _ (2 * n) (base + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key n active₂ _ _) hj3]
          exact scProveFixedProg_ptAt_eq Lq hL20 key H v n active₁ active₂ _ _ _ (base + 1 + 1) j hrestEq
        · rw [PProg.ptAt_andThen_right H v _ _ (2 * n) (base + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key n active₁ _ _) (by omega),
              PProg.ptAt_andThen_right H v _ _ (2 * n) (base + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key n active₂ _ _) (by omega)]
          rfl

theorem scProveFixedProg_res_honestW_canon (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) (d : ℕ) :
    ∀ (n : ℕ) (f : (Fin n → shdP_K) → shdP_K) (t : Tr) (base : ℕ),
      let rds := ((scProveFixedProg Lq hL20 key n true (honestW shdP_U shdP_hbij d n f) t).res H v base).1
      ∀ rd ∈ rds, rd.length = d + 1 ∧ ∀ w ∈ rd, w.Canon
  | 0, _, _, _, _, hr => by simp [scProveFixedProg, PProg.res] at hr
  | n + 1, f, t, base, rd, hr => by
    unfold scProveFixedProg honestW at hr
    rw [PProg.res_andThen H v _ _ 1 base (trAbsorbFp2Keyed_ptLen Lq hL20 key t scLabel (by decide) _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * n) (base + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key n true _ _)] at hr
    simp only [PProg.res, ↓reduceIte, List.mem_cons] at hr
    rcases hr with rfl | hr'
    · refine ⟨honestWords_length shdP_U shdP_hbij d f, fun w hw => ?_⟩
      unfold honestWords at hw
      obtain ⟨_, rfl⟩ := List.mem_ofFn.mp hw
      exact ofK_canon shdP_U shdP_hbij _
    · exact scProveFixedProg_res_honestW_canon Lq hL20 key H v d n _ _ (base + 1 + 1) rd hr'

theorem combVec_canon_len (len : ℕ) (rho : List Fp2) (rows : List (List Fp)) :
    (combVec len rho rows).length = len ∧ ∀ w ∈ combVec len rho rows, w.Canon := by
  refine ⟨combVec_length len rho rows, fun w hw => ?_⟩
  unfold combVec at hw
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hw
  unfold combAt dotB
  have hfold : ∀ (l : List (Fp2 × Fp)) (acc : Fp2), acc.Canon →
      (l.foldl (fun a p => a.add (p.1.mulBase p.2)) acc).Canon := by
    intro l; induction l with
    | nil => intro acc ha; exact ha
    | cons _ tl ih => intro acc _; exact ih _ (Fp2.canon_add _ _)
  exact hfold _ Fp2.zero Fp2.canon_zero

theorem polyWords_canon_len (p : Polynomial shdP_K) :
    (polyWords shdP_U shdP_hbij p).length = 2 * mMsg ∧ ∀ w ∈ polyWords shdP_U shdP_hbij p, w.Canon :=
  ⟨polyWords_length shdP_U shdP_hbij p, polyWords_canon shdP_U shdP_hbij p⟩

theorem zkBMaskFixedProg_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (active : Bool) (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    (zkBMaskFixedProg Lq hL20 key U hbij active M S tree fs t).PtLen (zkBMaskFixedLen S) := by
  unfold zkBMaskFixedProg zkBMaskFixedLen
  rw [show 2 * S + 69 = 1 + (1 + ((2 * S + 2) + (1 + (((mQ + 3) / 4) + 0)))) by unfold mQ; omega]
  exact (trChallengeFp2Keyed_ptLen Lq (by omega) key t).andThen fun _ =>
    (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
      (trChallengeFp2VecKeyed_ptLen Lq (by omega) key (2 * S + 2) _).andThen fun _ =>
        (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
          (trSqueezeVecKeyed_ptLen Lq (by omega) key ((mQ + 3) / 4) _).andThen fun _ => rfl

theorem zkBMaskFixedProg_res_tr (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (active : Bool) (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    ((zkBMaskFixedProg Lq hL20 key U hbij active M S tree fs t).res H v base).2
      = ⟨v (base + zkBMaskFixedLen S - 1), t.counter + UInt64.ofNat (2 * S + 67), key⟩ := by
  have hmQ64 : (mQ + 3) / 4 = 64 := by decide
  unfold zkBMaskFixedProg
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t),
    trChallengeFp2Keyed_res,
    PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res,
    PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key (2 * S + 2) _),
    trChallengeFp2VecKeyed_res,
    PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res,
    PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _),
    trSqueezeVecKeyed_res]
  simp only [PProg.res, hmQ64, ite_eq_right (by omega : 2 * S + 2 ≠ 0), ite_eq_right (by omega : (64 : ℕ) ≠ 0)]
  unfold zkBMaskFixedLen
  rw [show base + 1 + 1 + (2 * S + 2) + 1 + 64 - 1 = base + (2 * S + 69) - 1 by omega,
    uint64_add_ofNat_succ, UInt64.add_assoc, ← UInt64.ofNat_add,
    show 2 * S + 2 + 1 + 64 = 2 * S + 67 by omega]

theorem zkBMaskFixedProg_res_spec (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    let res := (zkBMaskFixedProg Lq hL20 key U hbij true M S tree fs t).res H v base
    MaskCanon res.1
      ∧ res.2 = ⟨v (base + zkBMaskFixedLen S - 1), t.counter + UInt64.ofNat (2 * S + 67), key⟩
      ∧ res.1.q.length = 2 * mMsg
      ∧ res.1.prox.length = 2 * mMsg
      ∧ res.1.columns.length = mQ
      ∧ ∀ col ∈ res.1.columns, col.j < mDom ∧ col.col.length = 2 * S + 4 ∧ col.path.length = 12 := by
  dsimp only
  have hmQ64 : (mQ + 3) / 4 = 64 := by decide
  unfold zkBMaskFixedProg
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t),
    trChallengeFp2Keyed_res,
    PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res,
    PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key (2 * S + 2) _),
    trChallengeFp2VecKeyed_res,
    PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res,
    PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _),
    trSqueezeVecKeyed_res]
  simp only [PProg.res, ↓reduceIte, hmQ64]
  have hqL := polyWords_length U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF)
    ((challengeFp2Of (v base)).toK U))
  have hqC := polyWords_canon U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S (fs.map toMF)
    ((challengeFp2Of (v base)).toK U))
  have hpL := polyWords_length U hbij (pPoly U M S ((List.range (2 * S + 2)).map (fun k => challengeFp2Of (v (base + 1 + 1 + k)))))
  have hpC := polyWords_canon U hbij (pPoly U M S ((List.range (2 * S + 2)).map (fun k => challengeFp2Of (v (base + 1 + 1 + k)))))
  refine ⟨⟨hqC, hpC, fun col hcol => ?_⟩, ?_, hqL, hpL, ?_, fun col hcol => ?_⟩
  · obtain ⟨j, _, rfl⟩ := List.mem_map.mp hcol
    exact ZK60.HonestOpen.mCol_canon S (cosetPt (rootFp 12)) M j
  · simp only [ite_eq_right (by omega : 2 * S + 2 ≠ 0), ite_eq_right (by omega : (64 : ℕ) ≠ 0)]
    unfold zkBMaskFixedLen
    rw [show base + 1 + 1 + (2 * S + 2) + 1 + 64 - 1 = base + (2 * S + 69) - 1 by omega,
      uint64_add_ofNat_succ, UInt64.add_assoc, ← UInt64.ofNat_add,
      show 2 * S + 2 + 1 + 64 = 2 * S + 67 by omega]
  · rw [List.length_map, idxOf_length, List.length_map, List.length_range]; rfl
  · obtain ⟨j, hj, rfl⟩ := List.mem_map.mp hcol
    have hlt : j < mDom := idxOf_lt mDom mQ (by decide) _ j hj
    exact ⟨hlt, mCol_length S (cosetPt (rootFp 12)) M j, merkleLevels_pathD_length tree j hlt⟩

theorem openingAuditFixedProg_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom) (T : Table) (tree : MerkleLevels depth)
    (active hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr) :
    (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t).PtLen
      (openingAuditFixedLen nClaims rows nGroups prm.nQ) := by
  unfold openingAuditFixedProg openingAuditFixedLen
  rw [show nClaims + rows + nGroups + 1 + (prm.nQ + 3) / 4 = nClaims + (rows + (nGroups + (1 + ((prm.nQ + 3) / 4 + 0)))) by omega]
  exact (trChallengeFp2VecKeyed_ptLen Lq (by omega) key nClaims t).andThen fun _ =>
    (trChallengeFp2VecKeyed_ptLen Lq (by omega) key rows _).andThen fun _ =>
      (trAbsorbVecsFixed_ptLen Lq hL20 key nGroups _ _).andThen fun _ =>
        (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
          (trSqueezeVecKeyed_ptLen Lq (by omega) key ((prm.nQ + 3) / 4) _).andThen fun _ => rfl

theorem openingAuditFixedProg_res_spec (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : prm.nQ = 256)
    (g : OpenGeom) (T : Table) (hTrows : T.rows.length = rows)
    (hTlen : ∀ j, (T.cols j).length = rows) (hTcan : ∀ j, ∀ w ∈ T.cols j, w.Canon)
    (tree : MerkleLevels depth) (active hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) (o : Exec.Block.OpeningZk)
    (ho : ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t).res H v base).1 = some o) :
    HidingCanon o
      ∧ o.groupVecs.length = nGroups
      ∧ (∀ gv ∈ o.groupVecs, gv.length = prm.n + prm.qPad)
      ∧ o.proxVec.length = prm.n + prm.qPad
      ∧ o.columns.length = 256
      ∧ ∀ col ∈ o.columns, col.j < 2 ^ depth ∧ col.col.length = rows ∧ col.path.length = depth := by
  have h64 : (prm.nQ + 3) / 4 = 64 := by rw [hnQ]
  unfold openingAuditFixedProg at ho
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key nClaims t),
    trChallengeFp2VecKeyed_res,
    PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key rows _),
    trChallengeFp2VecKeyed_res,
    PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key nGroups _ _),
    trAbsorbVecsFixed_res,
    PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res,
    PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _),
    trSqueezeVecKeyed_res] at ho
  simp only [PProg.res, h64] at ho
  split_ifs at ho with hp
  simp only [Option.some.injEq] at ho
  subst ho
  have hpre : (pGroups prm T (cl.map toZClaim)).length = nGroups := by
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hp
    exact hp.1.2
  refine ⟨?_, by rw [List.length_map, groupRhosAux_length, hpre],
    fun vec hvec => by obtain ⟨rho, _, rfl⟩ := List.mem_map.mp hvec; exact (combVec_canon_len _ rho T.rows).1,
    (combVec_canon_len _ _ T.rows).1,
    by rw [List.length_map, hnQ, idxOf_length, List.length_map, List.length_range]; rfl,
    fun col hcol => ?_⟩
  · refine ⟨fun vec hvec => ?_, (combVec_canon_len (prm.n + prm.qPad) _ T.rows).2, fun col hcol => ?_⟩
    · obtain ⟨rho, _, rfl⟩ := List.mem_map.mp hvec
      exact (combVec_canon_len (prm.n + prm.qPad) rho T.rows).2
    · obtain ⟨j, _, rfl⟩ := List.mem_map.mp hcol
      exact hTcan j
  · obtain ⟨j, hj, rfl⟩ := List.mem_map.mp hcol
    have hlt : j < 2 ^ depth := by
      rw [hnn, hnQ] at hj
      exact idxOf_lt (2 ^ depth) 256 (Nat.two_pow_pos depth) _ j hj
    exact ⟨hlt, hTlen j, merkleLevels_pathD_length tree j hlt⟩

theorem openingAuditFixedProg_res_tr (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom) (T : Table)
    (tree : MerkleLevels depth) (active hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t).res H v base).2
      = ⟨v (base + nClaims + rows + nGroups + (prm.nQ + 3) / 4),
          t.counter + UInt64.ofNat nClaims + UInt64.ofNat rows + UInt64.ofNat ((prm.nQ + 3) / 4), key⟩ := by
  unfold openingAuditFixedProg
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key nClaims t),
    trChallengeFp2VecKeyed_res,
    PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key rows _),
    trChallengeFp2VecKeyed_res,
    PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key nGroups _ _),
    trAbsorbVecsFixed_res,
    PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res,
    PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _),
    trSqueezeVecKeyed_res]
  simp only [PProg.res]
  have hctr : (if nGroups = 0 then (if rows = 0 then (if nClaims = 0 then t else ⟨v (base + nClaims - 1), t.counter + UInt64.ofNat nClaims, key⟩)
      else ⟨v (base + nClaims + rows - 1), (if nClaims = 0 then t else ⟨v (base + nClaims - 1), t.counter + UInt64.ofNat nClaims, key⟩).counter + UInt64.ofNat rows, key⟩)
      else { (if rows = 0 then (if nClaims = 0 then t else ⟨v (base + nClaims - 1), t.counter + UInt64.ofNat nClaims, key⟩)
        else ⟨v (base + nClaims + rows - 1), (if nClaims = 0 then t else ⟨v (base + nClaims - 1), t.counter + UInt64.ofNat nClaims, key⟩).counter + UInt64.ofNat rows, key⟩) with
        state := v (base + nClaims + rows + nGroups - 1), key := key }).counter = t.counter + UInt64.ofNat nClaims + UInt64.ofNat rows := by
    split_ifs <;> simp_all [uint64_add_ofNat_zero]
  by_cases hq : (prm.nQ + 3) / 4 = 0
  · rw [ite_eq_left hq, hq, Nat.add_zero, uint64_add_ofNat_zero]
    exact congrArg (fun c => (⟨v (base + nClaims + rows + nGroups), c, key⟩ : Tr)) hctr
  · rw [ite_eq_right hq, hctr]
    congr 1; congr 1; omega

theorem slotProveFixedProg_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (active : Bool) (hist : Hist) (acc : Acc) (t : Tr) :
    (slotProveFixedProg Lq hL20 key P D s active hist acc t).PtLen (slotFixedLen P s) := by
  unfold slotProveFixedProg slotFixedLen
  rw [show P.draws s + 4 + 2 * slotN P s = P.draws s + (1 + (1 + (1 + (2 * slotN P s + (1 + 0))))) by omega]
  exact (trChallengeFp2VecKeyed_ptLen Lq (by omega) key (P.draws s) t).andThen fun _ =>
    (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
      (trChallengeFp2Keyed_ptLen Lq (by omega) key _).andThen fun _ =>
        (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
          (scProveFixedProg_ptLen Lq hL20 key (slotN P s) _ _ _).andThen fun _ =>
            (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ => rfl

theorem slotProveFixedProg_res_tr (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (active : Bool) (hist : Hist) (acc : Acc) (t : Tr)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    ((slotProveFixedProg Lq hL20 key P D s active hist acc t).res H v base).2 =
      ⟨v (base + slotFixedLen P s - 1), t.counter + UInt64.ofNat (P.draws s) + 1 + UInt64.ofNat (slotN P s), key⟩ := by
  unfold slotProveFixedProg
  rw [PProg.res_andThen H v _ _ (P.draws s) base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key (P.draws s) t),
    trChallengeFp2VecKeyed_res,
    PProg.res_andThen H v _ _ 1 (base + P.draws s) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbKeyed_res,
    PProg.res_andThen H v _ _ 1 (base + P.draws s + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
    trChallengeFp2Keyed_res,
    PProg.res_andThen H v _ _ 1 (base + P.draws s + 1 + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res,
    PProg.res_andThen H v _ _ (2 * slotN P s) (base + P.draws s + 1 + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key (slotN P s) _ _ _),
    PProg.res_andThen H v _ _ 1 (base + P.draws s + 1 + 1 + 1 + 2 * slotN P s) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
    trAbsorbFp2Keyed_res]
  have hsc := fun act wp t' => (scProveFixedProg_res_spec Lq hL20 key H v (slotN P s) act wp t' (base + P.draws s + 1 + 1 + 1)).2.2
  simp only [PProg.res, hsc]
  have hctr0 : (if P.draws s = 0 then t else ⟨v (base + P.draws s - 1), t.counter + UInt64.ofNat (P.draws s), key⟩).counter
      = t.counter + UInt64.ofNat (P.draws s) := by split_ifs <;> simp_all [uint64_add_ofNat_zero]
  rw [hctr0]
  unfold slotFixedLen
  split_ifs with h0
  · congr 1
    · congr 1; omega
    · simp only [h0, uint64_add_ofNat_zero]
  · congr 1
    · congr 1; omega

private theorem scProveFixedProg_ptAt_eq_n (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) {n₁ n₂ : ℕ} (hn : n₁ = n₂) (a₁ a₂ : Bool)
    (wp₁ : WProver n₁) (wp₂ : WProver n₂) (t : Tr) (base j : ℕ)
    (h : ((scProveFixedProg Lq hL20 key n₁ a₁ wp₁ t).res H v base).1
      = ((scProveFixedProg Lq hL20 key n₂ a₂ wp₂ t).res H v base).1) :
    (scProveFixedProg Lq hL20 key n₁ a₁ wp₁ t).ptAt H v base j
      = (scProveFixedProg Lq hL20 key n₂ a₂ wp₂ t).ptAt H v base j := by
  subst hn; exact scProveFixedProg_ptAt_eq Lq hL20 key H v n₁ a₁ a₂ wp₁ wp₂ t base j h

theorem slotProveFixedProg_ptAt_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P₁ P₂ : BlockParams) (D₁ : SlotData P₁) (D₂ : SlotData P₂) (s : ℕ)
    (hDr : P₁.draws s = P₂.draws s) (hN : slotN P₁ s = slotN P₂ s)
    (hist₁ hist₂ : Hist) (acc₁ acc₂ : Acc) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base j : ℕ)
    (sp : SlotProof) (r₁ r₂ : SlotRec) (a₁ a₂ : Acc) (t₁ t₂ : Tr)
    (h1 : (slotProveFixedProg Lq hL20 key P₁ D₁ s true hist₁ acc₁ t).res H v base = (some (sp, r₁, a₁), t₁))
    (h2 : (slotProveFixedProg Lq hL20 key P₂ D₂ s true hist₂ acc₂ t).res H v base = (some (sp, r₂, a₂), t₂)) :
    (slotProveFixedProg Lq hL20 key P₁ D₁ s true hist₁ acc₁ t).ptAt H v base j =
      (slotProveFixedProg Lq hL20 key P₂ D₂ s true hist₂ acc₂ t).ptAt H v base j := by
  -- Extract equality of `scalar`, `rounds`, and `terms` from `sp`!
  unfold slotProveFixedProg at h1 h2 ⊢
  rw [PProg.res_andThen H v _ _ (P₁.draws s) base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t),
      trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + P₁.draws s) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + P₁.draws s + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + P₁.draws s + 1 + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * slotN P₁ s) (base + P₁.draws s + 1 + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key _ _ _ _),
      PProg.res_andThen H v _ _ 1 (base + P₁.draws s + 1 + 1 + 1 + 2 * slotN P₁ s) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res] at h1
  rw [PProg.res_andThen H v _ _ (P₂.draws s) base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t),
      trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + P₂.draws s) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + P₂.draws s + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + P₂.draws s + 1 + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * slotN P₂ s) (base + P₂.draws s + 1 + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key _ _ _ _),
      PProg.res_andThen H v _ _ 1 (base + P₂.draws s + 1 + 1 + 1 + 2 * slotN P₂ s) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res] at h2
  simp only [PProg.res, Prod.mk.injEq, ↓reduceIte, Bool.true_and] at h1 h2
  -- Extract the active `ok` branches from `h1.1` and `h2.1`
  have h1s := h1.1; have h2s := h2.1
  cases hdf₁ : P₁.define s hist₁ ((List.range (P₁.draws s)).map (fun k => challengeFp2Of (v (base + k)))) with
  | error _ => rw [hdf₁] at h1s; cases h1s
  | ok df₁ =>
    rw [hdf₁] at h1s; dsimp only at h1s
    by_cases hc1 : (challengeFp2Of (v (base + P₁.draws s + 1))).isZero = true
    · simp only [hc1, Bool.not_true, Bool.not_false, ↓reduceIte] at h1s; cases h1s
    · have hc1f : (challengeFp2Of (v (base + P₁.draws s + 1))).isZero = false := Bool.eq_false_iff.mpr hc1
      simp only [hc1f, Bool.not_false, Bool.not_true, Bool.false_eq_true, ↓reduceIte] at h1s
      cases hes1 : (((scProveFixedProg Lq hL20 key (slotN P₁ s) true
          (D₁.strat s hist₁ acc₁ df₁ (challengeFp2Of (v (base + P₁.draws s + 1)))) _).res H v
          (base + P₁.draws s + 1 + 1 + 1)).2.1.drop (Exec.Block.slotShape P₁ s).1).any
          (fun x => x.isZero || decide (x = Fp2.one)) with
      | true => rw [hes1] at h1s; simp only [↓reduceIte] at h1s; cases h1s
      | false =>
        rw [hes1] at h1s; simp only [Bool.false_eq_true, ↓reduceIte] at h1s
        cases hchk1 : Exec.Block.slotDefChecks P₁ s acc₁ df₁ with
        | error _ => rw [hchk1] at h1s; cases h1s
        | ok _ =>
          rw [hchk1] at h1s; dsimp only at h1s
          cases hho1 : Exec.Block.hostedSum acc₁.scalars _ df₁.hosted with
          | error _ => rw [hho1] at h1s; cases h1s
          | ok _ =>
            rw [hho1] at h1s; dsimp only at h1s
            cases htv1 : Exec.Block.tabVals _ _ _ df₁.tabs 0 with
            | error _ => rw [htv1] at h1s; cases h1s
            | ok _ =>
              rw [htv1] at h1s; simp only [Option.some.injEq, Prod.mk.injEq] at h1s
              obtain ⟨hsp1, -, -⟩ := h1s
              cases hdf₂ : P₂.define s hist₂ ((List.range (P₂.draws s)).map (fun k => challengeFp2Of (v (base + k)))) with
              | error _ => rw [hdf₂] at h2s; cases h2s
              | ok df₂ =>
                rw [hdf₂] at h2s; dsimp only at h2s
                have hc2f : (challengeFp2Of (v (base + P₂.draws s + 1))).isZero = false := by rw [← hDr]; exact hc1f
                simp only [hc2f, Bool.not_false, Bool.not_true, Bool.false_eq_true, ↓reduceIte] at h2s
                cases hes2 : (((scProveFixedProg Lq hL20 key (slotN P₂ s) true
                    (D₂.strat s hist₂ acc₂ df₂ (challengeFp2Of (v (base + P₂.draws s + 1)))) _).res H v
                    (base + P₂.draws s + 1 + 1 + 1)).2.1.drop (Exec.Block.slotShape P₂ s).1).any
                    (fun x => x.isZero || decide (x = Fp2.one)) with
                | true => rw [hes2] at h2s; simp only [↓reduceIte] at h2s; cases h2s
                | false =>
                  rw [hes2] at h2s; simp only [Bool.false_eq_true, ↓reduceIte] at h2s
                  cases hchk2 : Exec.Block.slotDefChecks P₂ s acc₂ df₂ with
                  | error _ => rw [hchk2] at h2s; cases h2s
                  | ok _ =>
                    rw [hchk2] at h2s; dsimp only at h2s
                    cases hho2 : Exec.Block.hostedSum acc₂.scalars _ df₂.hosted with
                    | error _ => rw [hho2] at h2s; cases h2s
                    | ok _ =>
                      rw [hho2] at h2s; dsimp only at h2s
                      cases htv2 : Exec.Block.tabVals _ _ _ df₂.tabs 0 with
                      | error _ => rw [htv2] at h2s; cases h2s
                      | ok _ =>
                        rw [htv2] at h2s; simp only [Option.some.injEq, Prod.mk.injEq] at h2s
                        obtain ⟨hsp2, -, -⟩ := h2s
                        have hscEq : D₁.scalar s hist₁ acc₁ df₁ (challengeFp2Of (v (base + P₁.draws s + 1)))
                            = D₂.scalar s hist₂ acc₂ df₂ (challengeFp2Of (v (base + P₂.draws s + 1))) := by
                          have h1' := congrArg SlotProof.scalar hsp1
                          have h2' := congrArg SlotProof.scalar hsp2
                          dsimp only at h1' h2'
                          exact h1'.trans h2'.symm
                        have hrdEq := (congrArg SlotProof.rounds hsp1).trans (congrArg SlotProof.rounds hsp2).symm
                        dsimp only at hrdEq
                        have htmEq := (congrArg SlotProof.terms hsp1).trans (congrArg SlotProof.terms hsp2).symm
                        dsimp only at htmEq
                        -- Now compare `ptAt` segment-by-segment across `[base, base + slotFixedLen)`!
                        by_cases hj0 : j < base + P₁.draws s
                        · rw [PProg.ptAt_andThen_left H v _ _ (P₁.draws s) base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) hj0,
                              PProg.ptAt_andThen_left H v _ _ (P₂.draws s) base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) (by omega), hDr]
                        · rw [PProg.ptAt_andThen_right H v _ _ (P₁.draws s) base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) (by omega),
                              PProg.ptAt_andThen_right H v _ _ (P₂.draws s) base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) (by omega),
                              trChallengeFp2VecKeyed_res, trChallengeFp2VecKeyed_res, hDr]
                          by_cases hj1 : j < base + P₂.draws s + 1
                          · rw [PProg.ptAt_andThen_left H v _ _ 1 (base + P₂.draws s) j (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) hj1,
                                PProg.ptAt_andThen_left H v _ _ 1 (base + P₂.draws s) j (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) hj1]
                          · rw [PProg.ptAt_andThen_right H v _ _ 1 (base + P₂.draws s) j (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (by omega),
                                PProg.ptAt_andThen_right H v _ _ 1 (base + P₂.draws s) j (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (by omega),
                                trAbsorbKeyed_res]
                            by_cases hj2 : j < base + P₂.draws s + 1 + 1
                            · rw [PProg.ptAt_andThen_left H v _ _ 1 (base + P₂.draws s + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) hj2,
                                  PProg.ptAt_andThen_left H v _ _ 1 (base + P₂.draws s + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) hj2]
                            · rw [PProg.ptAt_andThen_right H v _ _ 1 (base + P₂.draws s + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (by omega),
                                  PProg.ptAt_andThen_right H v _ _ 1 (base + P₂.draws s + 1) j (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (by omega),
                                  trChallengeFp2Keyed_res]
                              simp only [↓reduceIte, Bool.true_and]
                              rw [← hDr] at hdf₂ hes2 hho2 htv2 htmEq ⊢
                              simp only [hdf₁, hdf₂, hc1f, Bool.not_false, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
                              by_cases hj3 : j < base + P₁.draws s + 1 + 1 + 1
                              · rw [PProg.ptAt_andThen_left H v _ _ 1 (base + P₁.draws s + 1 + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj3,
                                    PProg.ptAt_andThen_left H v _ _ 1 (base + P₁.draws s + 1 + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj3]
                                rw [← hDr] at hscEq; rw [hscEq]
                              · rw [PProg.ptAt_andThen_right H v _ _ 1 (base + P₁.draws s + 1 + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
                                    PProg.ptAt_andThen_right H v _ _ 1 (base + P₁.draws s + 1 + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
                                    trAbsorbFp2Keyed_res, trAbsorbFp2Keyed_res]
                                by_cases hj4 : j < base + P₁.draws s + 1 + 1 + 1 + 2 * slotN P₁ s
                                · rw [PProg.ptAt_andThen_left H v _ _ (2 * slotN P₁ s) (base + P₁.draws s + 1 + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key _ _ _ _) hj4,
                                      PProg.ptAt_andThen_left H v _ _ (2 * slotN P₂ s) (base + P₁.draws s + 1 + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key _ _ _ _) (by omega)]
                                  exact scProveFixedProg_ptAt_eq_n Lq hL20 key H v hN true true _ _ _ _ j (by simpa [hDr] using hrdEq)
                                · rw [PProg.ptAt_andThen_right H v _ _ (2 * slotN P₁ s) (base + P₁.draws s + 1 + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key _ _ _ _) (by omega),
                                      PProg.ptAt_andThen_right H v _ _ (2 * slotN P₂ s) (base + P₁.draws s + 1 + 1 + 1) j (scProveFixedProg_ptLen Lq hL20 key _ _ _ _) (by omega)]
                                  have hsc1 := fun act wp t' => (scProveFixedProg_res_spec Lq hL20 key H v (slotN P₁ s) act wp t' (base + P₁.draws s + 1 + 1 + 1)).2.2
                                  have hsc2 := fun act wp t' => (scProveFixedProg_res_spec Lq hL20 key H v (slotN P₂ s) act wp t' (base + P₁.draws s + 1 + 1 + 1)).2.2
                                  rw [hsc1, hsc2]
                                  have h2n : base + P₁.draws s + 1 + 1 + 1 + 2 * slotN P₁ s = base + P₁.draws s + 1 + 1 + 1 + 2 * slotN P₂ s := by rw [hN]
                                  have htEq : ∀ (t' : Tr),
                                      (if slotN P₁ s = 0 then t'
                                       else ⟨v (base + P₁.draws s + 1 + 1 + 1 + 2 * slotN P₁ s - 1),
                                             t'.counter + UInt64.ofNat (slotN P₁ s), key⟩)
                                      = (if slotN P₂ s = 0 then t'
                                         else ⟨v (base + P₁.draws s + 1 + 1 + 1 + 2 * slotN P₂ s - 1),
                                               t'.counter + UInt64.ofNat (slotN P₂ s), key⟩) := fun _ => by rw [hN]
                                  rw [htEq, h2n]
                                  by_cases hj5 : j < base + P₁.draws s + 1 + 1 + 1 + 2 * slotN P₂ s + 1
                                  · rw [PProg.ptAt_andThen_left H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj5,
                                        PProg.ptAt_andThen_left H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj5]
                                    simp only [hes1, hes2, Bool.false_eq_true, ↓reduceIte,
                                      hchk1, hho1, htv1, hchk2, hho2, htv2]
                                    exact congrArg (fun x => (trAbsorbFp2Keyed Lq hL20 key _ labPbTerm (by decide) x).ptAt H v _ j) htmEq
                                  · rw [PProg.ptAt_andThen_right H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
                                        PProg.ptAt_andThen_right H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega)]
                                    dsimp only [PProg.ptAt]

theorem zkBMaskFixedProg_ptAt_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (M₁ M₂ : MTable) (S : ℕ) (tree₁ tree₂ : MerkleLevels 12) (fs₁ fs₂ : List Exec.Block.MaskFunctional)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base j : ℕ)
    (hEq : ((zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M₁ S tree₁ fs₁ t).res H v base).1
        = ((zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M₂ S tree₂ fs₂ t).res H v base).1) :
    (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M₁ S tree₁ fs₁ t).ptAt H v base j
      = (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M₂ S tree₂ fs₂ t).ptAt H v base j := by
  unfold zkBMaskFixedProg at hEq ⊢
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res,
      PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res] at hEq
  simp only [PProg.res, ↓reduceIte] at hEq
  have hqEq := congrArg Exec.Block.MaskOpening.q hEq
  have hpEq := congrArg Exec.Block.MaskOpening.prox hEq
  dsimp only at hqEq hpEq
  by_cases hj0 : j < base + 1
  · rw [PProg.ptAt_andThen_left H v _ _ 1 base j (trChallengeFp2Keyed_ptLen Lq (by omega) key t) hj0,
        PProg.ptAt_andThen_left H v _ _ 1 base j (trChallengeFp2Keyed_ptLen Lq (by omega) key t) hj0]
  · rw [PProg.ptAt_andThen_right H v _ _ 1 base j (trChallengeFp2Keyed_ptLen Lq (by omega) key t) (by omega),
        PProg.ptAt_andThen_right H v _ _ 1 base j (trChallengeFp2Keyed_ptLen Lq (by omega) key t) (by omega),
        trChallengeFp2Keyed_res]
    by_cases hj1 : j < base + 1 + 1
    · rw [PProg.ptAt_andThen_left H v _ _ 1 (base + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj1,
          PProg.ptAt_andThen_left H v _ _ 1 (base + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj1]
      dsimp only [↓reduceIte]; rw [hqEq]
    · rw [PProg.ptAt_andThen_right H v _ _ 1 (base + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
          PProg.ptAt_andThen_right H v _ _ 1 (base + 1) j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
          trAbsorbFp2Keyed_res, trAbsorbFp2Keyed_res]
      by_cases hj2 : j < base + 1 + 1 + (2 * S + 2)
      · rw [PProg.ptAt_andThen_left H v _ _ (2 * S + 2) (base + 1 + 1) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) hj2,
            PProg.ptAt_andThen_left H v _ _ (2 * S + 2) (base + 1 + 1) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) hj2]
      · rw [PProg.ptAt_andThen_right H v _ _ (2 * S + 2) (base + 1 + 1) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) (by omega),
            PProg.ptAt_andThen_right H v _ _ (2 * S + 2) (base + 1 + 1) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) (by omega),
            trChallengeFp2VecKeyed_res]
        by_cases hj3 : j < base + 1 + 1 + (2 * S + 2) + 1
        · rw [PProg.ptAt_andThen_left H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj3,
              PProg.ptAt_andThen_left H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj3]
          dsimp only [↓reduceIte]; rw [hpEq]
        · rw [PProg.ptAt_andThen_right H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
              PProg.ptAt_andThen_right H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
              trAbsorbFp2Keyed_res, trAbsorbFp2Keyed_res]
          by_cases hj4 : j < base + 1 + 1 + (2 * S + 2) + 1 + (mQ + 3) / 4
          · rw [PProg.ptAt_andThen_left H v _ _ ((mQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) hj4,
                PProg.ptAt_andThen_left H v _ _ ((mQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) hj4]
          · rw [PProg.ptAt_andThen_right H v _ _ ((mQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) (by omega),
                PProg.ptAt_andThen_right H v _ _ ((mQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) (by omega)]
            dsimp only [PProg.ptAt]

theorem openingAuditFixedProg_ptAt_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom)
    (T₁ T₂ : Table) (tree₁ tree₂ : MerkleLevels depth) (a₁ a₂ h₁ h₂ : Bool)
    (cl₁ cl₂ : List Exec.Block.ZClaim) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base j : ℕ)
    (o : Exec.Block.OpeningZk)
    (ho1 : ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₁ tree₁ a₁ h₁ cl₁ t).res H v base).1 = some o)
    (ho2 : ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₂ tree₂ a₂ h₂ cl₂ t).res H v base).1 = some o) :
    (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₁ tree₁ a₁ h₁ cl₁ t).ptAt H v base j
      = (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₂ tree₂ a₂ h₂ cl₂ t).ptAt H v base j := by
  unfold openingAuditFixedProg at ho1 ho2 ⊢
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _), trAbsorbVecsFixed_res,
      PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res] at ho1
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _), trAbsorbVecsFixed_res,
      PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res] at ho2
  simp only [PProg.res] at ho1 ho2
  split_ifs at ho1 with hp1; simp only [Option.some.injEq] at ho1
  split_ifs at ho2 with hp2; simp only [Option.some.injEq] at ho2
  have hvEq : (groupRhosAux rows (pGroups prm T₁ (cl₁.map toZClaim)) ((List.range nClaims).map (fun k => challengeFp2Of (v (base + k))))).map
        (fun rho => combVec (prm.n + prm.qPad) rho T₁.rows)
      = (groupRhosAux rows (pGroups prm T₂ (cl₂.map toZClaim)) ((List.range nClaims).map (fun k => challengeFp2Of (v (base + k))))).map
        (fun rho => combVec (prm.n + prm.qPad) rho T₂.rows) :=
    (congrArg Exec.Block.OpeningZk.groupVecs ho1).trans (congrArg Exec.Block.OpeningZk.groupVecs ho2).symm
  have hprEq : combVec (prm.n + prm.qPad) ((List.range rows).map (fun k => challengeFp2Of (v (base + nClaims + k)))) T₁.rows
      = combVec (prm.n + prm.qPad) ((List.range rows).map (fun k => challengeFp2Of (v (base + nClaims + k)))) T₂.rows :=
    (congrArg Exec.Block.OpeningZk.proxVec ho1).trans (congrArg Exec.Block.OpeningZk.proxVec ho2).symm
  by_cases hj0 : j < base + nClaims
  · rw [PProg.ptAt_andThen_left H v _ _ nClaims base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) hj0,
        PProg.ptAt_andThen_left H v _ _ nClaims base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) hj0]
  · rw [PProg.ptAt_andThen_right H v _ _ nClaims base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) (by omega),
        PProg.ptAt_andThen_right H v _ _ nClaims base j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) (by omega),
        trChallengeFp2VecKeyed_res]
    by_cases hj1 : j < base + nClaims + rows
    · rw [PProg.ptAt_andThen_left H v _ _ rows (base + nClaims) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) hj1,
          PProg.ptAt_andThen_left H v _ _ rows (base + nClaims) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) hj1]
    · rw [PProg.ptAt_andThen_right H v _ _ rows (base + nClaims) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) (by omega),
          PProg.ptAt_andThen_right H v _ _ rows (base + nClaims) j (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) (by omega),
          trChallengeFp2VecKeyed_res]
      simp only [hp1, hp2, ↓reduceIte]
      by_cases hj2 : j < base + nClaims + rows + nGroups
      · rw [PProg.ptAt_andThen_left H v _ _ nGroups (base + nClaims + rows) j (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _) hj2,
            PProg.ptAt_andThen_left H v _ _ nGroups (base + nClaims + rows) j (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _) hj2, hvEq]
      · rw [PProg.ptAt_andThen_right H v _ _ nGroups (base + nClaims + rows) j (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _) (by omega),
            PProg.ptAt_andThen_right H v _ _ nGroups (base + nClaims + rows) j (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _) (by omega),
            trAbsorbVecsFixed_res, trAbsorbVecsFixed_res]
        by_cases hj3 : j < base + nClaims + rows + nGroups + 1
        · rw [PProg.ptAt_andThen_left H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj3,
              PProg.ptAt_andThen_left H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) hj3, hprEq]
        · rw [PProg.ptAt_andThen_right H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
              PProg.ptAt_andThen_right H v _ _ 1 _ j (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (by omega),
              trAbsorbFp2Keyed_res, trAbsorbFp2Keyed_res]
          by_cases hj4 : j < base + nClaims + rows + nGroups + 1 + (prm.nQ + 3) / 4
          · rw [PProg.ptAt_andThen_left H v _ _ ((prm.nQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) hj4,
                PProg.ptAt_andThen_left H v _ _ ((prm.nQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) hj4]
          · rw [PProg.ptAt_andThen_right H v _ _ ((prm.nQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) (by omega),
                PProg.ptAt_andThen_right H v _ _ ((prm.nQ + 3) / 4) _ j (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) (by omega)]
            rfl

end AtomicResAndPtAt

/-! ## 2. Pure `v`-Only Refusal Invariance (`shdRunRefused`, `shdP_runFixedProg_active_indep`) -/

section PureRefusal

/-- Shape equivalence of two `List Exec.Block.Tab`s: identical `.eq` parameters, equal-length `.pub` tables,
and identical `.priv` descriptors (ignoring public table field values). -/
def TabsShapeEq : List Exec.Block.Tab → List Exec.Block.Tab → Prop :=
  List.Forall₂ fun t₁ t₂ =>
    match t₁, t₂ with
    | .eq τ₁ s₁, .eq τ₂ s₂ => τ₁ = τ₂ ∧ s₁ = s₂
    | .pub v₁, .pub v₂ => v₁.length = v₂.length
    | .priv p₁, .priv p₂ => p₁ = p₂
    | _, _ => False

theorem TabsShapeEq.refl : ∀ ts : List Exec.Block.Tab, TabsShapeEq ts ts
  | [] => List.Forall₂.nil
  | .eq _ _ :: ts => List.Forall₂.cons ⟨rfl, rfl⟩ (TabsShapeEq.refl ts)
  | .pub _ :: ts => List.Forall₂.cons rfl (TabsShapeEq.refl ts)
  | .priv _ :: ts => List.Forall₂.cons rfl (TabsShapeEq.refl ts)

/-- Claim-parts equivalence of two `Claims4` (ignoring `ZClaim.val`). -/
def ClaimsPartsEq (c₁ c₂ : Exec.Block.Claims4) : Prop :=
  c₁.a.map Exec.Block.ZClaim.parts = c₂.a.map Exec.Block.ZClaim.parts
    ∧ c₁.h.map Exec.Block.ZClaim.parts = c₂.h.map Exec.Block.ZClaim.parts
    ∧ c₁.inp.map Exec.Block.ZClaim.parts = c₂.inp.map Exec.Block.ZClaim.parts
    ∧ c₁.out.map Exec.Block.ZClaim.parts = c₂.out.map Exec.Block.ZClaim.parts

/-- Shape equivalence of two slot accumulators `Acc` (ignoring `Fp2` values). -/
def AccShapeEq (a₁ a₂ : Acc) : Prop :=
  a₁.cs.length = a₂.cs.length
    ∧ a₁.scalars.length = a₂.scalars.length
    ∧ a₁.fs.length = a₂.fs.length
    ∧ a₁.hostFs.length = a₂.hostFs.length
    ∧ ClaimsPartsEq a₁.claims a₂.claims

private theorem isPriv_count_of_tabsShapeEq : ∀ {ts₁ ts₂ : List Exec.Block.Tab},
    TabsShapeEq ts₁ ts₂ → (ts₁.filter Exec.Block.Tab.isPriv).length = (ts₂.filter Exec.Block.Tab.isPriv).length
  | [], [], _ => rfl
  | t₁ :: ts₁, t₂ :: ts₂, h => by
    obtain ⟨h1, h2⟩ := List.forall₂_cons.mp h
    cases t₁ <;> cases t₂ <;> first | exact False.elim h1 | skip
    · simp only [List.filter_cons, Exec.Block.Tab.isPriv, Bool.false_eq_true, ↓reduceIte]; exact isPriv_count_of_tabsShapeEq h2
    · simp only [List.filter_cons, Exec.Block.Tab.isPriv, Bool.false_eq_true, ↓reduceIte]; exact isPriv_count_of_tabsShapeEq h2
    · simp only [List.filter_cons, Exec.Block.Tab.isPriv, ↓reduceIte, List.length_cons, isPriv_count_of_tabsShapeEq h2]

private theorem list_any_eq_of_tabsShapeEq (f : Exec.Block.Tab → Bool)
    (hfPub : ∀ v₁ v₂, v₁.length = v₂.length → f (.pub v₁) = f (.pub v₂)) :
    ∀ {ts₁ ts₂ : List Exec.Block.Tab}, TabsShapeEq ts₁ ts₂ → ts₁.any f = ts₂.any f
  | [], [], _ => rfl
  | t₁ :: ts₁, t₂ :: ts₂, h => by
    obtain ⟨h1, h2⟩ := List.forall₂_cons.mp h
    cases t₁ <;> cases t₂ <;> first | exact False.elim h1 | skip
    · rcases h1 with ⟨rfl, rfl⟩; simp only [List.any_cons, list_any_eq_of_tabsShapeEq f hfPub h2]
    · simp only [List.any_cons, hfPub _ _ h1, list_any_eq_of_tabsShapeEq f hfPub h2]
    · subst h1; simp only [List.any_cons, list_any_eq_of_tabsShapeEq f hfPub h2]

private theorem slotDefChecks_eq_of_shape {P₁ P₂ : BlockParams} (hG : P₁.geom = P₂.geom) (hK : P₁.kind = P₂.kind)
    (s : ℕ) {acc₁ acc₂ : Acc} (hAcc : AccShapeEq acc₁ acc₂) {df₁ df₂ : SlotDef}
    (hT : TabsShapeEq df₁.tabs df₂.tabs) (hH : df₁.hosted = df₂.hosted) :
    Exec.Block.slotDefChecks P₁ s acc₁ df₁ = Exec.Block.slotDefChecks P₂ s acc₂ df₂ := by
  have hsh : Exec.Block.slotShape P₁ s = Exec.Block.slotShape P₂ s := by unfold Exec.Block.slotShape; rw [hG]
  have htm : Exec.Block.slotTerms P₁ s = Exec.Block.slotTerms P₂ s := by unfold Exec.Block.slotTerms; rw [hG]
  unfold Exec.Block.slotDefChecks
  dsimp only
  rw [hsh, htm, hK, hAcc.1, hH, isPriv_count_of_tabsShapeEq hT,
    list_any_eq_of_tabsShapeEq _ (fun _ _ _ => rfl) hT,
    list_any_eq_of_tabsShapeEq _ (fun _ _ hl => by dsimp only; rw [hl]) hT]

private theorem hostedSum_isOk_of_len {sc₁ sc₂ : List Fp2} (hlen : sc₁.length = sc₂.length) :
    ∀ (hs : List (ℕ × Fp2)) (a₁ a₂ : Fp2),
      (Exec.Block.hostedSum sc₁ a₁ hs).isOk = (Exec.Block.hostedSum sc₂ a₂ hs).isOk
  | [], _, _ => rfl
  | (i, c) :: rest, a₁, a₂ => by
    unfold Exec.Block.hostedSum
    rw [hlen]
    split_ifs
    · exact hostedSum_isOk_of_len hlen rest _ _
    · rfl

private theorem tabVals_isOk_of_tabsShapeEq (sel₁ sel₂ : Fp2) (rho tms₁ tms₂ : List Fp2) :
    ∀ {ts₁ ts₂ : List Exec.Block.Tab} (k : ℕ), TabsShapeEq ts₁ ts₂ →
      (Exec.Block.tabVals sel₁ rho tms₁ ts₁ k).isOk = (Exec.Block.tabVals sel₂ rho tms₂ ts₂ k).isOk
  | [], [], _, _ => rfl
  | t₁ :: ts₁, t₂ :: ts₂, k, h => by
    obtain ⟨h1, h2⟩ := List.forall₂_cons.mp h
    unfold Exec.Block.tabVals
    cases t₁ <;> cases t₂ <;> first | exact False.elim h1 | skip
    · rcases h1 with ⟨rfl, rfl⟩
      dsimp only [Exec.Block.tabVal]
      split_ifs
      · cases eqPoint _ _ with
        | none => rfl
        | some _ =>
          dsimp only
          have ih := tabVals_isOk_of_tabsShapeEq sel₁ sel₂ rho tms₁ tms₂ k h2
          cases hv1 : Exec.Block.tabVals sel₁ rho tms₁ ts₁ k <;>
            cases hv2 : Exec.Block.tabVals sel₂ rho tms₂ ts₂ k <;>
            rw [hv1, hv2] at ih <;>
            simp_all [Except.isOk, Except.toBool]
      · rfl
    · dsimp only [Exec.Block.tabVal, evalMleExt]
      rw [h1]
      split_ifs
      · dsimp only
        have ih := tabVals_isOk_of_tabsShapeEq sel₁ sel₂ rho tms₁ tms₂ k h2
        cases hv1 : Exec.Block.tabVals sel₁ rho tms₁ ts₁ k <;>
          cases hv2 : Exec.Block.tabVals sel₂ rho tms₂ ts₂ k <;>
          rw [hv1, hv2] at ih <;>
          simp_all [Except.isOk, Except.toBool]
      · rfl
    · subst h1
      dsimp only [Exec.Block.tabVal]
      have ih := tabVals_isOk_of_tabsShapeEq sel₁ sel₂ rho tms₁ tms₂ (k + 1) h2
      cases hv1 : Exec.Block.tabVals sel₁ rho tms₁ ts₁ (k + 1) <;>
        cases hv2 : Exec.Block.tabVals sel₂ rho tms₂ ts₂ (k + 1) <;>
        rw [hv1, hv2] at ih <;>
        simp_all [Except.isOk, Except.toBool]

private theorem slotClaims_parts_of_tabsShapeEq {P₁ P₂ : BlockParams}
    (hLC : P₁.logCols = P₂.logCols) (hEL : P₁.endpointLogN = P₂.endpointLogN)
    (rho es tms₁ tms₂ : List Fp2) :
    ∀ {ts₁ ts₂ : List Exec.Block.Tab} (k : ℕ) {c₁ c₂ : Exec.Block.Claims4},
      TabsShapeEq ts₁ ts₂ → ClaimsPartsEq c₁ c₂ →
      ClaimsPartsEq (Exec.Block.slotClaims P₁ rho es tms₁ ts₁ k c₁) (Exec.Block.slotClaims P₂ rho es tms₂ ts₂ k c₂)
  | [], [], _, _, _, _, hc => hc
  | t₁ :: ts₁, t₂ :: ts₂, k, c₁, c₂, h, hc => by
    obtain ⟨h1, h2⟩ := List.forall₂_cons.mp h
    cases t₁ <;> cases t₂ <;> first | exact False.elim h1 | skip
    · dsimp only [Exec.Block.slotClaims]; exact slotClaims_parts_of_tabsShapeEq hLC hEL rho es tms₁ tms₂ k h2 hc
    · dsimp only [Exec.Block.slotClaims]; exact slotClaims_parts_of_tabsShapeEq hLC hEL rho es tms₁ tms₂ k h2 hc
    · subst h1
      rename_i p
      dsimp only [Exec.Block.slotClaims]
      refine slotClaims_parts_of_tabsShapeEq hLC hEL rho es tms₁ tms₂ (k + 1) h2 ?_
      have hrl : Exec.Block.rowLog P₁ p.cm = Exec.Block.rowLog P₂ p.cm := by
        cases p.cm <;> simp [Exec.Block.rowLog, hLC, hEL]
      have hbp : (Exec.Block.buildClaim P₁ p (Exec.Block.claimPoint p rho) (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) (tms₁.getD k Fp2.zero)).parts
          = (Exec.Block.buildClaim P₂ p (Exec.Block.claimPoint p rho) (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) (tms₂.getD k Fp2.zero)).parts := by
        unfold Exec.Block.buildClaim; rw [hrl]
      rcases hc with ⟨ha, hh, hi, ho⟩
      cases p.cm <;>
        simp only [Exec.Block.Claims4.push, ClaimsPartsEq, ha, hh, hi, ho, hbp,
          List.map_append, List.map_cons, List.map_nil, and_self]

private theorem openingHdrOk_of_parts (g : OpenGeom) (logCols : ℕ) {cl₁ cl₂ : List Exec.Block.ZClaim}
    (hp : cl₁.map Exec.Block.ZClaim.parts = cl₂.map Exec.Block.ZClaim.parts) :
    openingHdrOk g logCols cl₁ = openingHdrOk g logCols cl₂ := by
  have haud : auditClaims cl₁ (2 ^ logCols) g.rows g.siteRows g.sumRows g.prox
      = auditClaims cl₂ (2 ^ logCols) g.rows g.siteRows g.sumRows g.prox := by
    have hloop : ∀ (nC ci : ℕ) (cs₁ cs₂ : List Exec.Block.ZClaim) (uses : List ℕ),
        cs₁.map Exec.Block.ZClaim.parts = cs₂.map Exec.Block.ZClaim.parts →
        auditLoop (2 ^ logCols) g.rows g.prox g.siteRows g.sumRows nC ci cs₁ uses
          = auditLoop (2 ^ logCols) g.rows g.prox g.siteRows g.sumRows nC ci cs₂ uses := by
      intro nC ci cs₁ cs₂ uses hcs
      induction cs₁ generalizing ci cs₂ uses with
      | nil => cases cs₂ with | nil => rfl | cons _ _ => simp at hcs
      | cons c₁ rest₁ ih =>
        cases cs₂ with
        | nil => simp at hcs
        | cons c₂ rest₂ =>
          simp only [List.map_cons, List.cons.injEq] at hcs
          have hone : auditOne (2 ^ logCols) g.rows g.prox g.siteRows g.sumRows nC ci c₁ uses
              = auditOne (2 ^ logCols) g.rows g.prox g.siteRows g.sumRows nC ci c₂ uses := by
            unfold auditOne claimTouched claimWeight; rw [hcs.1]
          unfold auditLoop; rw [hone]
          cases auditOne (2 ^ logCols) g.rows g.prox g.siteRows g.sumRows nC ci c₂ uses with
          | error _ => rfl
          | ok u => exact ih (ci + 1) rest₂ u hcs.2
    have hlen : cl₁.length = cl₂.length := by
      have := congrArg List.length hp; simpa using this
    unfold auditClaims; rw [hlen, hloop cl₂.length 0 cl₁ cl₂ _ hp]
  have hog : openingGroupsAt cl₁ logCols = openingGroupsAt cl₂ logCols := by
    have hfold : ∀ (cs₁ cs₂ : List Exec.Block.ZClaim) (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)),
        cs₁.map Exec.Block.ZClaim.parts = cs₂.map Exec.Block.ZClaim.parts →
        cs₁.foldlM (m := Except String) (fun acc c =>
          let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logCols
          if c.parts.any (fun p => partKeyAt p logCols ≠ key) then
            throw "private block: claim parts with different column weights"
          else pure (bumpKey key acc)) gs
        = cs₂.foldlM (m := Except String) (fun acc c =>
          let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logCols
          if c.parts.any (fun p => partKeyAt p logCols ≠ key) then
            throw "private block: claim parts with different column weights"
          else pure (bumpKey key acc)) gs := by
      intro cs₁ cs₂ gs hcs
      induction cs₁ generalizing cs₂ gs with
      | nil => cases cs₂ with | nil => rfl | cons _ _ => simp at hcs
      | cons c₁ rest₁ ih =>
        cases cs₂ with
        | nil => simp at hcs
        | cons c₂ rest₂ =>
          simp only [List.map_cons, List.cons.injEq] at hcs
          simp only [List.foldlM_cons, hcs.1]
          split_ifs
          · rfl
          · exact ih rest₂ _ hcs.2
    exact hfold cl₁ cl₂ [] hp
  unfold openingHdrOk; rw [haud, hog]

private theorem tokenEpHdrOk_of_parts (data n : ℕ) {cl₁ cl₂ : List Exec.Block.ZClaim}
    (hp : cl₁.map Exec.Block.ZClaim.parts = cl₂.map Exec.Block.ZClaim.parts) :
    tokenEpHdrOk cl₁ data n = tokenEpHdrOk cl₂ data n := by
  cases cl₁ with
  | nil => cases cl₂ with | nil => rfl | cons _ _ => simp at hp
  | cons c₁ r₁ =>
    cases cl₂ with
    | nil => simp at hp
    | cons c₂ r₂ =>
      simp only [List.map_cons, List.cons.injEq] at hp
      cases r₁ with
      | cons _ _ => cases r₂ with | nil => simp at hp | cons _ _ => rfl
      | nil =>
        cases r₂ with
        | cons _ _ => simp at hp
        | nil => dsimp only [tokenEpHdrOk]; rw [hp.1]

private theorem groupZclaims_sizes_of_parts (rows logN : ℕ) {cl₁ cl₂ : List Exec.Block.ZClaim}
    (hp : cl₁.map Exec.Block.ZClaim.parts = cl₂.map Exec.Block.ZClaim.parts) :
    (groupZclaims (cl₁.map toZClaim) rows logN).map (fun x => x.2.length)
      = (groupZclaims (cl₂.map toZClaim) rows logN).map (fun x => x.2.length) := by
  have hpl : ∀ {α β : Type} (l₁ l₂ : List (α × List β)) (i : ℕ) (m₁ m₂ : β),
      l₁.map (fun x => x.2.length) = l₂.map (fun x => x.2.length) →
      (pushAt l₁ i m₁).map (fun x => x.2.length) = (pushAt l₂ i m₂).map (fun x => x.2.length) := by
    intro α β l₁; induction l₁ with
    | nil => intro l₂ _ _ _ h; cases l₂ with | nil => rfl | cons _ _ => simp at h
    | cons a₁ tl₁ ihp =>
      intro l₂ i m₁ m₂ h; cases l₂ with
      | nil => simp at h
      | cons a₂ tl₂ =>
        simp only [List.map_cons, List.cons.injEq] at h
        cases i with
        | zero => simp [pushAt, h.1, h.2]
        | succ i' => simp [pushAt, h.1, ihp tl₂ i' m₁ m₂ h.2]
  have haux : ∀ (cs₁ cs₂ : List Exec.Block.ZClaim)
      (ks : List ZKey) (gs₁ gs₂ : List (List Fp2 × List (List Fp2 × Fp2))),
      cs₁.map Exec.Block.ZClaim.parts = cs₂.map Exec.Block.ZClaim.parts →
      gs₁.map (fun x => x.2.length) = gs₂.map (fun x => x.2.length) →
      ((cs₁.map toZClaim).foldl (groupStep rows logN) (ks, gs₁)).2.map (fun x => x.2.length)
        = ((cs₂.map toZClaim).foldl (groupStep rows logN) (ks, gs₂)).2.map (fun x => x.2.length) := by
    intro cs₁ cs₂ ks gs₁ gs₂ hcs hlen
    induction cs₁ generalizing cs₂ ks gs₁ gs₂ with
    | nil => cases cs₂ with | nil => exact hlen | cons _ _ => simp at hcs
    | cons c₁ rest₁ ih =>
      cases cs₂ with
      | nil => simp at hcs
      | cons c₂ rest₂ =>
        simp only [List.map_cons, List.cons.injEq] at hcs
        have hcw : claimWeights (toZClaim c₁) rows logN = claimWeights (toZClaim c₂) rows logN := by
          unfold claimWeights toZClaim; rw [hcs.1]
        simp only [List.map_cons, List.foldl_cons, groupStep, hcw]
        cases keyIdx ks (claimWeights (toZClaim c₂) rows logN).2 with
        | none =>
          exact ih rest₂ _ _ _ hcs.2 (by simp [hlen])
        | some idx =>
          exact ih rest₂ _ _ _ hcs.2 (hpl gs₁ gs₂ idx _ _ hlen)
  exact haux cl₁ cl₂ [] [] [] hp rfl

private theorem slotBody_shape_indep {P₁ P₂ : BlockParams}
    (hG : P₁.geom = P₂.geom) (hK : P₁.kind = P₂.kind)
    (hLC : P₁.logCols = P₂.logCols) (hEL : P₁.endpointLogN = P₂.endpointLogN)
    (s : ℕ) (active : Bool) (dr : List Fp2) (c : Fp2) (rhoFull : List Fp2)
    (def₁ def₂ : Except String SlotDef)
    (hDef : match def₁, def₂ with
      | .error _, .error _ => True
      | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
      | _, _ => False)
    (acc₁ acc₂ : Acc) (hAcc : AccShapeEq acc₁ acc₂)
    (sc₁ sc₂ : Fp2) (tm₁ tm₂ : SlotDef → List Fp2)
    (rds₁ rds₂ : List (List Fp2)) :
    let cOk := active && !c.isZero
    let mk := fun (P : BlockParams) (defR : Except String SlotDef) (acc : Acc)
        (sc : Fp2) (tm : SlotDef → List Fp2) (rds : List (List Fp2)) =>
      (match defR with
      | .error _ => (none, [])
      | .ok df =>
        if !cOk then (none, [])
        else
          let rho := rhoFull.take (Exec.Block.slotShape P s).1
          let es := rhoFull.drop (Exec.Block.slotShape P s).1
          if es.any (fun x => x.isZero || decide (x = Fp2.one)) then (none, [])
          else
            let tms := tm df
            match Exec.Block.slotDefChecks P s acc df with
            | .error _ => (none, tms)
            | .ok _ =>
              match Exec.Block.hostedSum acc.scalars sc df.hosted with
              | .error _ => (none, tms)
              | .ok claimed =>
                match Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho tms df.tabs 0 with
                | .error _ => (none, tms)
                | .ok vals =>
                  let fin := scFinalExec rds rhoFull claimed
                  let sp : SlotProof := ⟨sc, rds, tms⟩
                  let rec_ : SlotRec := ⟨dr, c, sc, claimed, rho, es, tms, fin⟩
                  let acc' := Exec.Block.slotAcc P s acc df c sc
                    ((fin.sub (df.poly vals)).mul c.inv) rhoFull tms
                  (some (sp, rec_, acc'), tms)).1
    match mk P₁ def₁ acc₁ sc₁ tm₁ rds₁, mk P₂ def₂ acc₂ sc₂ tm₂ rds₂ with
    | none, none => True
    | some (_, rec₁, a₁'), some (_, rec₂, a₂') => rec₁.draws = rec₂.draws ∧ AccShapeEq a₁' a₂'
    | _, _ => False := by
  dsimp only
  cases def₁ with
  | error _ =>
    cases def₂ with
    | error _ => trivial
    | ok _ => cases hDef
  | ok df₁ =>
    cases def₂ with
    | error _ => cases hDef
    | ok df₂ =>
      obtain ⟨hT, hH⟩ := hDef
      have hsh : Exec.Block.slotShape P₁ s = Exec.Block.slotShape P₂ s := by unfold Exec.Block.slotShape; rw [hG]
      rw [hsh]
      cases hcOk : !(active && !c.isZero) with
      | true => simp only [↓reduceIte]
      | false =>
        simp only [Bool.false_eq_true, ↓reduceIte]
        cases hes : (rhoFull.drop (Exec.Block.slotShape P₂ s).1).any (fun x => x.isZero || decide (x = Fp2.one)) with
        | true => simp only [↓reduceIte]
        | false =>
          simp only [Bool.false_eq_true, ↓reduceIte]
          have hchkEq := slotDefChecks_eq_of_shape hG hK s hAcc hT hH
          rw [hchkEq]
          cases Exec.Block.slotDefChecks P₂ s acc₂ df₂ with
          | error _ => trivial
          | ok _ =>
            have hhoEq := hostedSum_isOk_of_len hAcc.2.1 df₁.hosted sc₁ sc₂
            rw [hH] at hhoEq ⊢
            cases hho1 : Exec.Block.hostedSum acc₁.scalars sc₁ df₂.hosted <;>
              cases hho2 : Exec.Block.hostedSum acc₂.scalars sc₂ df₂.hosted <;>
              rw [hho1, hho2] at hhoEq <;> simp [Except.isOk, Except.toBool] at hhoEq
            · trivial
            · have htvEq := tabVals_isOk_of_tabsShapeEq
                (Exec.Block.oneMinusProd (rhoFull.drop (Exec.Block.slotShape P₂ s).1))
                (Exec.Block.oneMinusProd (rhoFull.drop (Exec.Block.slotShape P₂ s).1))
                (rhoFull.take (Exec.Block.slotShape P₂ s).1) (tm₁ df₁) (tm₂ df₂) 0 hT
              cases htv1 : Exec.Block.tabVals (Exec.Block.oneMinusProd (rhoFull.drop (Exec.Block.slotShape P₂ s).1))
                  (rhoFull.take (Exec.Block.slotShape P₂ s).1) (tm₁ df₁) df₁.tabs 0 <;>
                cases htv2 : Exec.Block.tabVals (Exec.Block.oneMinusProd (rhoFull.drop (Exec.Block.slotShape P₂ s).1))
                  (rhoFull.take (Exec.Block.slotShape P₂ s).1) (tm₂ df₂) df₂.tabs 0 <;>
                rw [htv1, htv2] at htvEq <;> simp [Except.isOk, Except.toBool] at htvEq
              · trivial
              · refine ⟨rfl, ?_⟩
                unfold Exec.Block.slotAcc
                dsimp only
                rw [hK, hsh]
                refine ⟨by simp [hAcc.1], by simp [hAcc.2.1], ?_, ?_,
                  slotClaims_parts_of_tabsShapeEq hLC hEL _ _ _ _ 0 hT hAcc.2.2.2.2⟩
                · cases P₂.kind s <;> simp [hAcc.2.2.1]
                · cases P₂.kind s <;> simp [hAcc.2.2.2.1]

/-- `slotProveFixedProg` active flag, `rec_.draws`, `AccShapeEq`, and output `Tr` are invariant
under `SlotData` changes and verdict-independent `P` shape agreements! -/
theorem slotProveFixedProg_shape_indep (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P₁ P₂ : BlockParams) (D₁ : SlotData P₁) (D₂ : SlotData P₂) (s : ℕ)
    (hDr : P₁.draws s = P₂.draws s) (hG : P₁.geom = P₂.geom) (hK : P₁.kind = P₂.kind)
    (hLC : P₁.logCols = P₂.logCols) (hEL : P₁.endpointLogN = P₂.endpointLogN)
    (hDef : ∀ hist dr, match P₁.define s hist dr, P₂.define s hist dr with
      | .error _, .error _ => True
      | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
      | _, _ => False)
    (active : Bool) (hist : Hist) (acc₁ acc₂ : Acc) (hAcc : AccShapeEq acc₁ acc₂)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    let r₁ := (slotProveFixedProg Lq hL20 key P₁ D₁ s active hist acc₁ t).res H v base
    let r₂ := (slotProveFixedProg Lq hL20 key P₂ D₂ s active hist acc₂ t).res H v base
    r₁.2 = r₂.2 ∧
      match r₁.1, r₂.1 with
      | none, none => True
      | some (_, rec₁, a₁'), some (_, rec₂, a₂') => rec₁.draws = rec₂.draws ∧ AccShapeEq a₁' a₂'
      | _, _ => False := by
  have hN : slotN P₁ s = slotN P₂ s := by unfold slotN Exec.Block.slotShape; rw [hG]
  have hLen : slotFixedLen P₁ s = slotFixedLen P₂ s := by unfold slotFixedLen; rw [hDr, hN]
  have hTr : ((slotProveFixedProg Lq hL20 key P₁ D₁ s active hist acc₁ t).res H v base).2
      = ((slotProveFixedProg Lq hL20 key P₂ D₂ s active hist acc₂ t).res H v base).2 := by
    rw [slotProveFixedProg_res_tr, slotProveFixedProg_res_tr, hLen, hDr, hN]
  refine ⟨hTr, ?_⟩
  let B : Option (SlotProof × SlotRec × Acc) × Tr → Option (SlotProof × SlotRec × Acc) × Tr → Prop :=
    fun r₁ r₂ => match r₁.1, r₂.1 with
      | none, none => True
      | some (_, rec₁, a₁'), some (_, rec₂, a₂') => rec₁.draws = rec₂.draws ∧ AccShapeEq a₁' a₂'
      | _, _ => False
  change B _ _
  unfold slotProveFixedProg
  refine res_andThen_same (B := B)
    ((trChallengeFp2VecKeyed_ptLen Lq _ key (P₁.draws s) t).congr hDr)
    (trChallengeFp2VecKeyed_ptLen Lq _ key (P₂.draws s) t)
    (by rw [trChallengeFp2VecKeyed_res, hDr]) (trChallengeFp2VecKeyed_res ..) ?_
  refine res_andThen_same (B := B) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := B) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_res ..) (trChallengeFp2Keyed_res ..) ?_
  refine res_andThen_same (B := B) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbFp2Keyed_res ..) (trAbsorbFp2Keyed_res ..) ?_
  let rhoFull := (List.range (slotN P₂ s)).map (fun j => challengeFp2Of (v (base + P₂.draws s + 1 + 1 + 1 + 2 * j + 1)))
  refine res_andThen_rel (B := B)
    (A := fun s₁ s₂ : List (List Fp2) × List Fp2 × Tr => s₁.2.1 = rhoFull ∧ s₂.2.1 = rhoFull)
    ((scProveFixedProg_ptLen Lq hL20 key (slotN P₁ s) _ _ _).congr (by rw [hN]))
    (scProveFixedProg_ptLen Lq hL20 key (slotN P₂ s) _ _ _)
    ⟨by rw [(scProveFixedProg_res_spec Lq hL20 key H v (slotN P₁ s) _ _ _ _).2.1, hN],
     (scProveFixedProg_res_spec Lq hL20 key H v (slotN P₂ s) _ _ _ _).2.1⟩
    fun scr₁ scr₂ ⟨hr1, hr2⟩ => ?_
  refine res_andThen_rel (B := B) (A := fun _ _ : Tr => True)
    (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _)
    (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) trivial fun _ _ _ => ?_
  dsimp only [B, PProg.res]
  rw [hr1, hr2]
  let dr := (List.range (P₂.draws s)).map (fun k => challengeFp2Of (v (base + k)))
  have hDefAct : match (if active then P₁.define s hist dr else .error "inactive"),
      (if active then P₂.define s hist dr else .error "inactive") with
    | .error _, .error _ => True
    | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
    | _, _ => False := by
    cases active with
    | false => trivial
    | true => exact hDef hist dr
  exact slotBody_shape_indep hG hK hLC hEL s active dr (challengeFp2Of (v (base + P₂.draws s + 1))) rhoFull
    (if active then P₁.define s hist dr else .error "inactive")
    (if active then P₂.define s hist dr else .error "inactive") hDefAct acc₁ acc₂ hAcc
    _ _
    (fun df => D₁.terms s hist acc₁ df (challengeFp2Of (v (base + P₂.draws s + 1))) rhoFull)
    (fun df => D₂.terms s hist acc₂ df (challengeFp2Of (v (base + P₂.draws s + 1))) rhoFull)
    scr₁.1 scr₂.1

theorem stSlotsProveFixedProg_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (active : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      (stSlotsProveFixedProg Lq hL20 key P elog D b g a m active recs s acc t).PtLen (slotsFixedLen P s m)
  | 0, _, _, _, _, _ => rfl
  | m + 1, active, recs, s, acc, t => by
    unfold stSlotsProveFixedProg slotsFixedLen
    exact (slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) (sdAt D (elog s)) s active _ acc t).andThen fun r => by
      cases r.1 with
      | none =>
        rw [show slotsFixedLen P (s + 1) m = slotsFixedLen P (s + 1) m + 0 by omega]
        exact (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m false recs (s + 1) acc r.2).andThen fun _ => rfl
      | some v1 =>
        rw [show slotsFixedLen P (s + 1) m = slotsFixedLen P (s + 1) m + 0 by omega]
        exact (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m true (recs ++ [v1.2.1]) (s + 1) v1.2.2 r.2).andThen
          fun rest => by cases rest.1 <;> rfl

theorem slotsProveFixedProg_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (active : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      (slotsProveFixedProg Lq hL20 key P D b g a m active recs s acc t).PtLen (slotsFixedLen P s m)
  | 0, _, _, _, _, _ => rfl
  | m + 1, active, recs, s, acc, t => by
    unfold slotsProveFixedProg slotsFixedLen
    exact (slotProveFixedProg_ptLen Lq hL20 key P D s active _ acc t).andThen fun r => by
      cases r.1 with
      | none =>
        rw [show slotsFixedLen P (s + 1) m = slotsFixedLen P (s + 1) m + 0 by omega]
        exact (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m false recs (s + 1) acc r.2).andThen fun _ => rfl
      | some v1 =>
        rw [show slotsFixedLen P (s + 1) m = slotsFixedLen P (s + 1) m + 0 by omega]
        exact (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m true (recs ++ [v1.2.1]) (s + 1) v1.2.2 r.2).andThen
          fun rest => by cases rest.1 <;> rfl

theorem stSlotsProveFixedProg_shape_indep (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D₁ D₂ : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs₁ recs₂ : List SlotRec) (s : ℕ) (acc₁ acc₂ : Acc) (t : Tr) (base : ℕ),
      recs₁.map SlotRec.draws = recs₂.map SlotRec.draws → AccShapeEq acc₁ acc₂ →
      let r₁ := (stSlotsProveFixedProg Lq hL20 key P elog D₁ b g a m active recs₁ s acc₁ t).res H v base
      let r₂ := (stSlotsProveFixedProg Lq hL20 key P elog D₂ b g a m active recs₂ s acc₂ t).res H v base
      r₁.2 = r₂.2 ∧
        match r₁.1, r₂.1 with
        | none, none => True
        | some (_, _, a₁'), some (_, _, a₂') => AccShapeEq a₁' a₂'
        | _, _ => False
  | 0, active, _, _, _, _, _, t, _, _, hAcc => by
    cases active <;> exact ⟨rfl, by simp [stSlotsProveFixedProg, PProg.res, hAcc]⟩
  | m + 1, active, recs₁, recs₂, s, acc₁, acc₂, t, base, hRecs, hAcc => by
    dsimp only
    unfold stSlotsProveFixedProg
    have hhist : Exec.Block.histOf b g a recs₁ = Exec.Block.histOf b g a recs₂ := by
      unfold Exec.Block.histOf; rw [hRecs]
    rw [hhist,
      PProg.res_andThen H v _ _ (slotFixedLen (atLog P (elog s)) s) base (slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) (sdAt D₁ (elog s)) s active _ acc₁ t),
      PProg.res_andThen H v _ _ (slotFixedLen (atLog P (elog s)) s) base (slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) (sdAt D₂ (elog s)) s active _ acc₂ t)]
    have h1 := slotProveFixedProg_shape_indep Lq hL20 key (atLog P (elog s)) (atLog P (elog s))
      (sdAt D₁ (elog s)) (sdAt D₂ (elog s)) s rfl rfl rfl rfl rfl
      (fun hist dr => by cases (atLog P (elog s)).define s hist dr <;> simp [TabsShapeEq.refl])
      active (Exec.Block.histOf b g a recs₂) acc₁ acc₂ hAcc t H v base
    dsimp only at h1
    rw [h1.1]
    cases hr1 : ((slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D₁ (elog s)) s active (Exec.Block.histOf b g a recs₂) acc₁ t).res H v base).1 <;>
      cases hr2 : ((slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D₂ (elog s)) s active (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base).1 <;>
      rw [hr1, hr2] at h1
    · dsimp only
      have hSL : slotFixedLen (atLog P (elog s)) s = slotFixedLen P s := rfl
      rw [hSL]
      let t' := ((slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D₂ (elog s)) s active (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base).2
      have ih := stSlotsProveFixedProg_shape_indep Lq hL20 key P elog D₁ D₂ b g a H v m false
        recs₁ recs₂ (s + 1) acc₁ acc₂ t' (base + slotFixedLen P s) hRecs hAcc
      dsimp only at ih
      rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) (base + slotFixedLen P s)
            (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₁ b g a m false recs₁ (s + 1) acc₁ t'),
          PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) (base + slotFixedLen P s)
            (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₂ b g a m false recs₂ (s + 1) acc₂ t')]
      exact ⟨ih.1, trivial⟩
    · cases h1.2
    · cases h1.2
    · dsimp only
      have hSL : slotFixedLen (atLog P (elog s)) s = slotFixedLen P s := rfl
      rw [hSL]
      rename_i v1 v2
      rcases v1 with ⟨sp₁, rec₁, acc₁'⟩
      rcases v2 with ⟨sp₂, rec₂, acc₂'⟩
      obtain ⟨hDrEq, hAcc'⟩ := h1.2
      have hRecs' : (recs₁ ++ [rec₁]).map SlotRec.draws = (recs₂ ++ [rec₂]).map SlotRec.draws := by
        simp [hRecs, hDrEq]
      let t' := ((slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D₂ (elog s)) s active (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base).2
      have ih := stSlotsProveFixedProg_shape_indep Lq hL20 key P elog D₁ D₂ b g a H v m true
        (recs₁ ++ [rec₁]) (recs₂ ++ [rec₂]) (s + 1) acc₁' acc₂' t' (base + slotFixedLen P s) hRecs' hAcc'
      dsimp only at ih
      rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) (base + slotFixedLen P s)
            (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t'),
          PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) (base + slotFixedLen P s)
            (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t')]
      cases hst1 : ((stSlotsProveFixedProg Lq hL20 key P elog D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t').res H v (base + slotFixedLen P s)).1 <;>
        cases hst2 : ((stSlotsProveFixedProg Lq hL20 key P elog D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t').res H v (base + slotFixedLen P s)).1 <;>
        rw [hst1, hst2] at ih
      · exact ⟨ih.1, trivial⟩
      · cases ih.2
      · cases ih.2
      · exact ⟨ih.1, ih.2⟩

theorem slotsProveFixedProg_shape_indep (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P₁ P₂ : BlockParams) (D₁ : SlotData P₁) (D₂ : SlotData P₂)
    (hDr : ∀ s, P₁.draws s = P₂.draws s) (hG : P₁.geom = P₂.geom) (hK : P₁.kind = P₂.kind)
    (hLC : P₁.logCols = P₂.logCols) (hEL : P₁.endpointLogN = P₂.endpointLogN)
    (hDef : ∀ s hist dr, match P₁.define s hist dr, P₂.define s hist dr with
      | .error _, .error _ => True
      | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
      | _, _ => False)
    (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs₁ recs₂ : List SlotRec) (s : ℕ) (acc₁ acc₂ : Acc) (t : Tr) (base : ℕ),
      recs₁.map SlotRec.draws = recs₂.map SlotRec.draws → AccShapeEq acc₁ acc₂ →
      let r₁ := (slotsProveFixedProg Lq hL20 key P₁ D₁ b g a m active recs₁ s acc₁ t).res H v base
      let r₂ := (slotsProveFixedProg Lq hL20 key P₂ D₂ b g a m active recs₂ s acc₂ t).res H v base
      r₁.2 = r₂.2 ∧
        match r₁.1, r₂.1 with
        | none, none => True
        | some (_, _, a₁'), some (_, _, a₂') => AccShapeEq a₁' a₂'
        | _, _ => False
  | 0, active, _, _, _, _, _, t, _, _, hAcc => by
    cases active <;> exact ⟨rfl, by simp [slotsProveFixedProg, PProg.res, hAcc]⟩
  | m + 1, active, recs₁, recs₂, s, acc₁, acc₂, t, base, hRecs, hAcc => by
    dsimp only
    unfold slotsProveFixedProg
    have hhist : Exec.Block.histOf b g a recs₁ = Exec.Block.histOf b g a recs₂ := by
      unfold Exec.Block.histOf; rw [hRecs]
    have hLen1 : slotFixedLen P₁ s = slotFixedLen P₂ s := by
      unfold slotFixedLen slotN Exec.Block.slotShape; rw [hDr s, hG]
    rw [hhist,
      PProg.res_andThen H v _ _ (slotFixedLen P₁ s) base (slotProveFixedProg_ptLen Lq hL20 key P₁ D₁ s active _ acc₁ t),
      PProg.res_andThen H v _ _ (slotFixedLen P₂ s) base (slotProveFixedProg_ptLen Lq hL20 key P₂ D₂ s active _ acc₂ t)]
    have h1 := slotProveFixedProg_shape_indep Lq hL20 key P₁ P₂ D₁ D₂ s (hDr s) hG hK hLC hEL (hDef s)
      active (Exec.Block.histOf b g a recs₂) acc₁ acc₂ hAcc t H v base
    dsimp only at h1
    rw [h1.1, hLen1]
    cases hr1 : ((slotProveFixedProg Lq hL20 key P₁ D₁ s active (Exec.Block.histOf b g a recs₂) acc₁ t).res H v base).1 <;>
      cases hr2 : ((slotProveFixedProg Lq hL20 key P₂ D₂ s active (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base).1 <;>
      rw [hr1, hr2] at h1
    · let t' := ((slotProveFixedProg Lq hL20 key P₂ D₂ s active (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base).2
      have ih := slotsProveFixedProg_shape_indep Lq hL20 key P₁ P₂ D₁ D₂ hDr hG hK hLC hEL hDef b g a H v m false
        recs₁ recs₂ (s + 1) acc₁ acc₂ t' (base + slotFixedLen P₂ s) hRecs hAcc
      dsimp only at ih
      rw [PProg.res_andThen H v _ _ (slotsFixedLen P₁ (s + 1) m) (base + slotFixedLen P₂ s)
            (slotsProveFixedProg_ptLen Lq hL20 key P₁ D₁ b g a m false recs₁ (s + 1) acc₁ t'),
          PProg.res_andThen H v _ _ (slotsFixedLen P₂ (s + 1) m) (base + slotFixedLen P₂ s)
            (slotsProveFixedProg_ptLen Lq hL20 key P₂ D₂ b g a m false recs₂ (s + 1) acc₂ t')]
      exact ⟨ih.1, trivial⟩
    · cases h1.2
    · cases h1.2
    · rename_i v1 v2
      rcases v1 with ⟨sp₁, rec₁, acc₁'⟩
      rcases v2 with ⟨sp₂, rec₂, acc₂'⟩
      obtain ⟨hDrEq, hAcc'⟩ := h1.2
      have hRecs' : (recs₁ ++ [rec₁]).map SlotRec.draws = (recs₂ ++ [rec₂]).map SlotRec.draws := by
        simp [hRecs, hDrEq]
      let t' := ((slotProveFixedProg Lq hL20 key P₂ D₂ s active (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base).2
      have ih := slotsProveFixedProg_shape_indep Lq hL20 key P₁ P₂ D₁ D₂ hDr hG hK hLC hEL hDef b g a H v m true
        (recs₁ ++ [rec₁]) (recs₂ ++ [rec₂]) (s + 1) acc₁' acc₂' t' (base + slotFixedLen P₂ s) hRecs' hAcc'
      dsimp only at ih
      rw [PProg.res_andThen H v _ _ (slotsFixedLen P₁ (s + 1) m) (base + slotFixedLen P₂ s)
            (slotsProveFixedProg_ptLen Lq hL20 key P₁ D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t'),
          PProg.res_andThen H v _ _ (slotsFixedLen P₂ (s + 1) m) (base + slotFixedLen P₂ s)
            (slotsProveFixedProg_ptLen Lq hL20 key P₂ D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t')]
      cases hst1 : ((slotsProveFixedProg Lq hL20 key P₁ D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t').res H v (base + slotFixedLen P₂ s)).1 <;>
        cases hst2 : ((slotsProveFixedProg Lq hL20 key P₂ D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t').res H v (base + slotFixedLen P₂ s)).1 <;>
        rw [hst1, hst2] at ih
      · exact ⟨ih.1, trivial⟩
      · cases ih.2
      · cases ih.2
      · exact ⟨ih.1, ih.2⟩

private theorem build_lzc_tabsShapeEq (L : Lay) (tau : List Fp2) (live g1 g2 supp1 : List Fp2)
    (hg : g1.length = g2.length) (poly1 poly2 : List Fp2 → Fp2) (hosted : List (ℕ × Fp2)) :
    match
      build (do let _ ← eqT tau 0; let _ ← pubT live; let _ ← pubT g1; let _ ← pubT supp1
                let _ ← aT L 4 ocC_LIMB; let _ ← hT L 4 ocH_LO; finishT L 4 poly1 hosted),
      build (do let _ ← eqT tau 0; let _ ← pubT live; let _ ← pubT g2; let _ ← pubT supp1
                let _ ← aT L 4 ocC_LIMB; let _ ← hT L 4 ocH_LO; finishT L 4 poly2 hosted) with
    | .error _, .error _ => True
    | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
    | _, _ => False := by
  dsimp only [build, eqT, pubT, aT, aAtT, aSliceT, hT, pushT, finishT,
    Bind.bind, Except.bind, Pure.pure, Except.pure,
    StateT.bind, StateT.pure, StateT.get, StateT.set, StateT.run, StateT.lift,
    MonadLift.monadLift, MonadLiftT.monadLift, liftM,
    MonadState.get, MonadStateOf.get, MonadStateOf.set, getThe,
    throw, MonadExcept.throw, MonadExceptOf.throw, throwThe, Except.map]
  cases L.aSite 4 0 with
  | error _ => trivial
  | ok rA =>
    dsimp only
    cases L.hSite 4 0 with
    | error _ => trivial
    | ok rH =>
      dsimp only
      split_ifs
      · trivial
      · exact ⟨List.Forall₂.cons ⟨rfl, rfl⟩ (List.Forall₂.cons rfl (List.Forall₂.cons hg
          (List.Forall₂.cons rfl (List.Forall₂.cons rfl (List.Forall₂.cons rfl List.Forall₂.nil))))), rfl⟩

/-- Verdict-independence of Stage OUT-C `define` tab shapes and `hosted` lists!
Only slot 4 (`outcDefLZC`) reads `O.verdict`, and solely inside `gTab` values (fixed length `2^O.llo`)
and `lzcPoly`. -/
theorem outcDefine_tabsShapeEq (O : OutcPub) (G : OutcGeo) (v₁ v₂ s : ℕ) (hist : Hist) (dr : List Fp2) :
    match outcDefine (rcVerdict O v₁) G s hist dr, outcDefine (rcVerdict O v₂) G s hist dr with
    | .error _, .error _ => True
    | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
    | _, _ => False := by
  have hlay : outcLay (rcVerdict O v₁) G.bLogN = outcLay (rcVerdict O v₂) G.bLogN := by
    rw [rc_outcLay_verdict, rc_outcLay_verdict]
  match s with
  | 0 =>
    have heq : outcDefine (rcVerdict O v₁) G 0 hist dr = outcDefine (rcVerdict O v₂) G 0 hist dr := by
      show outcDefIO (rcVerdict O v₁) G dr = outcDefIO (rcVerdict O v₂) G dr
      unfold outcDefIO; rw [hlay]; rfl
    rw [heq]; cases outcDefine (rcVerdict O v₂) G 0 hist dr <;> simp [TabsShapeEq.refl]
  | 1 =>
    have heq : outcDefine (rcVerdict O v₁) G 1 hist dr = outcDefine (rcVerdict O v₂) G 1 hist dr := by
      show outcDefSS (rcVerdict O v₁) G = outcDefSS (rcVerdict O v₂) G
      unfold outcDefSS; rw [hlay]; rfl
    rw [heq]; cases outcDefine (rcVerdict O v₂) G 1 hist dr <;> simp [TabsShapeEq.refl]
  | 2 =>
    have heq : outcDefine (rcVerdict O v₁) G 2 hist dr = outcDefine (rcVerdict O v₂) G 2 hist dr := by
      show outcDefTZC (rcVerdict O v₁) G dr = outcDefTZC (rcVerdict O v₂) G dr
      unfold outcDefTZC; rw [hlay]; rfl
    rw [heq]; cases outcDefine (rcVerdict O v₂) G 2 hist dr <;> simp [TabsShapeEq.refl]
  | 3 =>
    have heq : outcDefine (rcVerdict O v₁) G 3 hist dr = outcDefine (rcVerdict O v₂) G 3 hist dr := by
      show outcDefPD (rcVerdict O v₁) G = outcDefPD (rcVerdict O v₂) G
      unfold outcDefPD; rw [hlay]; rfl
    rw [heq]; cases outcDefine (rcVerdict O v₂) G 3 hist dr <;> simp [TabsShapeEq.refl]
  | 5 =>
    have heq : outcDefine (rcVerdict O v₁) G 5 hist dr = outcDefine (rcVerdict O v₂) G 5 hist dr := by
      show outcDefDZC (rcVerdict O v₁) G hist dr = outcDefDZC (rcVerdict O v₂) G hist dr
      unfold outcDefDZC; rw [hlay]; rfl
    rw [heq]; cases outcDefine (rcVerdict O v₂) G 5 hist dr <;> simp [TabsShapeEq.refl]
  | 6 =>
    have heq : outcDefine (rcVerdict O v₁) G 6 hist dr = outcDefine (rcVerdict O v₂) G 6 hist dr := by
      show outcDefTAB (rcVerdict O v₁) G hist dr = outcDefTAB (rcVerdict O v₂) G hist dr
      unfold outcDefTAB; rw [hlay]; rfl
    rw [heq]; cases outcDefine (rcVerdict O v₂) G 6 hist dr <;> simp [TabsShapeEq.refl]
  | 7 =>
    have heq : outcDefine (rcVerdict O v₁) G 7 hist dr = outcDefine (rcVerdict O v₂) G 7 hist dr := by
      show outcDefZS (rcVerdict O v₁) G = outcDefZS (rcVerdict O v₂) G
      unfold outcDefZS; rw [hlay]
    rw [heq]; cases outcDefine (rcVerdict O v₂) G 7 hist dr <;> simp [TabsShapeEq.refl]
  | 4 =>
    change match outcDefLZC (rcVerdict O v₁) G hist dr, outcDefLZC (rcVerdict O v₂) G hist dr with
      | .error _, .error _ => True
      | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
      | _, _ => False
    unfold outcDefLZC
    have hllo (v : ℕ) : (rcVerdict O v).llo = O.llo := rfl
    have hlimbs (v : ℕ) : (rcVerdict O v).limbs = O.limbs := rfl
    rw [hlay, hllo, hllo, hlimbs, hlimbs]
    dsimp only [Bind.bind, Except.bind]
    cases nonzeroE ((dr.drop O.llo).take 2) with
    | error _ => trivial
    | ok mu =>
      cases nz1 dr (O.llo + 2) with
      | error _ => trivial
      | ok nu =>
        exact build_lzc_tabsShapeEq (outcLay (rcVerdict O v₂) G.bLogN) _ _ _ _ _
          (by unfold ZK60.Exec.StageCheck.gTab; simp only [List.length_map, List.length_range]) _ _ _
  | _ + 8 => trivial

theorem openingAuditFixedProg_res_shape_indep (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom)
    (T₁ T₂ : Table) (hTR : T₁.rows.length = T₂.rows.length)
    (tree₁ tree₂ : MerkleLevels depth) (active hdrOk : Bool)
    (cl₁ cl₂ : List Exec.Block.ZClaim) (hParts : cl₁.map Exec.Block.ZClaim.parts = cl₂.map Exec.Block.ZClaim.parts)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    let r₁ := (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₁ tree₁ active hdrOk cl₁ t).res H v base
    let r₂ := (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₂ tree₂ active hdrOk cl₂ t).res H v base
    r₁.2 = r₂.2 ∧ r₁.1.isSome = r₂.1.isSome := by
  dsimp only
  unfold openingAuditFixedProg
  have hsz : (pGroups prm T₁ (cl₁.map toZClaim)).map (fun x => x.2.length)
      = (pGroups prm T₂ (cl₂.map toZClaim)).map (fun x => x.2.length) := by
    unfold pGroups; rw [hTR]; exact groupZclaims_sizes_of_parts T₂.rows.length prm.logCols hParts
  have hsum : ((pGroups prm T₁ (cl₁.map toZClaim)).map (fun x => x.2.length)).sum
      = ((pGroups prm T₂ (cl₂.map toZClaim)).map (fun x => x.2.length)).sum := congrArg List.sum hsz
  have hlen : (pGroups prm T₁ (cl₁.map toZClaim)).length = (pGroups prm T₂ (cl₂.map toZClaim)).length := by
    have := congrArg List.length hsz; simpa using this
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _), trAbsorbVecsFixed_res,
      PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res]
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _), trAbsorbVecsFixed_res,
      PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res]
  simp only [PProg.res, hsum, hlen]
  refine ⟨trivial, ?_⟩
  split_ifs <;> rfl

private theorem openingAuditFixedProg_res_shape_indep' (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g₁ g₂ : OpenGeom) (hg : g₁ = g₂)
    (T₁ T₂ : Table) (hTR : T₁.rows.length = T₂.rows.length)
    (tree₁ tree₂ : MerkleLevels depth) (active₁ active₂ : Bool) (hAct : active₁ = active₂)
    (hdrOk₁ hdrOk₂ : Bool) (hHdr : hdrOk₁ = hdrOk₂)
    (cl₁ cl₂ : List Exec.Block.ZClaim) (hParts : cl₁.map Exec.Block.ZClaim.parts = cl₂.map Exec.Block.ZClaim.parts)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    let r₁ := (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g₁ T₁ tree₁ active₁ hdrOk₁ cl₁ t).res H v base
    let r₂ := (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g₂ T₂ tree₂ active₂ hdrOk₂ cl₂ t).res H v base
    r₁.2 = r₂.2 ∧ r₁.1.isSome = r₂.1.isSome := by
  subst hg; subst hAct; subst hHdr
  exact openingAuditFixedProg_res_shape_indep Lq hL20 key prm depth nClaims rows nGroups g₁ T₁ T₂ hTR tree₁ tree₂ active₁ hdrOk₁ cl₁ cl₂ hParts t H v base

theorem merkleTableProg_ptLen (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) :
    (merkleTableProg Lq h64 tag d rows hrows T hT).PtLen (2 ^ d + (2 ^ d - 1)) :=
  merkleTreeProg_ptLen Lq h64 tag d _ _ _

theorem merkleTableProg_res (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    (merkleTableProg Lq h64 tag d rows hrows T hT).res H v base = levelsOfV v d base :=
  merkleTreeProg_res_eq Lq h64 tag d _ _ _ H v base

theorem incSegFixedProg_ptLen {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : shieldS0.Tok → ℕ) (c : ShdCoins)
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (t : Tr) :
    (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t).PtLen incSegFixedLen := by
  unfold incSegFixedProg incSegFixedLen
  have h167 := shdP_inc_slotsFixedLen tag Rp embDigest (embFoldL Rp.inp) bInRow
  refine ((merkleTableProg_ptLen Lq _ tag 16 38 _ _ _).andThen fun _ =>
    (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
      (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
        (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
          (merkleTableProg_ptLen Lq _ tag 14 41 _ _ _).andThen fun _ =>
            (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
              (merkleTableProg_ptLen Lq _ tag 12 12 _ _ _).andThen fun _ =>
                (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
                  (trChallengeFp2VecKeyed_ptLen Lq _ key 15 _).andThen fun chR =>
                    (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _).andThen fun _ =>
                      (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
                        ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _).congr
                            (h167 (incCtx _ chR.1))).andThen fun slR =>
                          (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _).andThen fun _ =>
                            (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _).andThen fun aOR =>
                              (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _).andThen fun hOR =>
                                (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _).andThen fun eOR => by
                                  cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases eOR.1 <;> (try split_ifs) <;> exact rfl).congr
    (by unfold zkBMaskFixedLen openingAuditFixedLen shdP_stgPrm shdP_epPrm; norm_num)

theorem blkSegFixedProg_ptLen {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k : Fin 26) (active : Bool) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) :
    (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c k active cr treeBPrev bnd startTag t).PtLen blkSegFixedLen := by
  unfold blkSegFixedProg blkSegFixedLen
  have h1283 := shdP_blk_slotsFixedLen tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt
  refine ((merkleTableProg_ptLen Lq _ tag 16 38 _ _ _).andThen fun _ =>
    (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
      (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
        (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
          (merkleTableProg_ptLen Lq _ tag 16 4577 _ _ _).andThen fun _ =>
            (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
              (merkleTableProg_ptLen Lq _ tag 12 50 _ _ _).andThen fun _ =>
                (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
                  (trChallengeFp2Keyed_ptLen Lq _ key _).andThen fun _ =>
                    (trChallengeFp2Keyed_ptLen Lq _ key _).andThen fun _ =>
                      (trChallengeFp2Keyed_ptLen Lq _ key _).andThen fun _ =>
                        (merkleTableProg_ptLen Lq _ tag 16 4390 _ _ _).andThen fun _ =>
                          (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
                            ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283).andThen fun slR =>
                              (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _).andThen fun _ =>
                                (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _).andThen fun aOR =>
                                  (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _).andThen fun hOR =>
                                    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _).andThen fun bOR => by
                                      cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases bOR.1 <;> (try split_ifs) <;> exact rfl).congr
    (by unfold zkBMaskFixedLen openingAuditFixedLen Exec.R13.r13Prm; norm_num)

theorem blkChainFixedProg_ptLen {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
      (active : Bool) (cr : Carry) (treeB : MerkleLevels 16) (bnd startTag : Dig) (t : Tr),
      (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c startIdx count hEnd active cr treeB bnd startTag t).PtLen (blkStepFixedLen * count)
  | _, 0, _, _, _, _, _, _, _ => by simp [blkChainFixedProg]; rfl
  | startIdx, count + 1, hEnd, active, cr, treeB, bnd, startTag, t => by
    unfold blkChainFixedProg
    refine ((blkSegFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c ⟨startIdx, by omega⟩ active cr treeB bnd startTag t).andThen fun bR =>
      (posTagKeyed_ptLen Lq (by omega) key bR.2.2).andThen fun endTag =>
        (blkChainFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x hx c (startIdx + 1) count (by omega) bR.1.isSome _ bR.2.1 bnd endTag bR.2.2).andThen fun rest => by
            cases bR.1 <;> cases rest.1 <;> exact rfl).congr
      (by unfold blkStepFixedLen; ring)

theorem outcSegFixedProg_ptLen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (active : Bool) (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) :
    (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx c active cr treeB26 bnd startTag t).PtLen outcSegFixedLen := by
  unfold outcSegFixedProg outcSegFixedLen
  have h290 := shdP_outc_slotsFixedLen tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
  refine ((trAbsorbKeyed_ptLen Lq hL20 key t _ _ _).andThen fun _ =>
    (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
      (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _).andThen fun _ =>
        (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
          (merkleTableProg_ptLen Lq _ tag 12 20 _ _ _).andThen fun _ =>
            (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _).andThen fun _ =>
              (trChallengeFp2VecKeyed_ptLen Lq _ key 2 _).andThen fun _ =>
                (merkleTableProg_ptLen Lq _ tag 14 38 _ _ _).andThen fun _ =>
                  (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _).andThen fun _ =>
                    ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _).congr h290).andThen fun slR =>
                      (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _).andThen fun _ =>
                        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _).andThen fun aOR =>
                          (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _).andThen fun hOR =>
                            (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _).andThen fun bOR => by
                              cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases bOR.1 <;> (try split_ifs) <;> exact rfl).congr
    (by unfold zkBMaskFixedLen openingAuditFixedLen shdP_stgPrm Exec.R13.r13Prm; norm_num)

/-- Reusable carry-pending shape relation for `Option (α × Carry)` (avoids distinct matchers in `isDefEq`). -/
def CarryOptRel {α : Type} (o₁ o₂ : Option (α × Carry)) : Prop :=
  match o₁, o₂ with
  | none, none => True
  | some (_, cr₁), some (_, cr₂) => cr₁.pending.map Exec.Block.ZClaim.parts = cr₂.pending.map Exec.Block.ZClaim.parts
  | _, _ => False

def SegShapeRel (r₁ r₂ : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr) : Prop :=
  r₁.2.1 = r₂.2.1 ∧ r₁.2.2 = r₂.2.2 ∧ CarryOptRel r₁.1 r₂.1

def ChainShapeRel (r₁ r₂ : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig) : Prop :=
  r₁.2 = r₂.2 ∧ CarryOptRel r₁.1 r₂.1

def OutcShapeRel (r₁ r₂ : Option (Dig → List UInt8) × Tr) : Prop :=
  r₁.2 = r₂.2 ∧ r₁.1.isSome = r₂.1.isSome

theorem incSegFixedProg_shape_indep {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ)
    (x₁ x₂ : shieldS0.Tok → ℕ) (c₁ c₂ : ShdCoins)
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    SegShapeRel
      ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₁ c₁ treeTE bnd startTag t).res H v base)
      ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₂ c₂ treeTE bnd startTag t).res H v base) := by
  unfold incSegFixedProg
  have h167 := shdP_inc_slotsFixedLen tag Rp embDigest (embFoldL Rp.inp) bInRow
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 14 41 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 14 41 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 12 (2 * 4 + 4) _ _ _)
    (merkleTableProg_ptLen Lq _ tag 12 (2 * 4 + 4) _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trChallengeFp2VecKeyed_ptLen Lq _ key 15 _) (trChallengeFp2VecKeyed_ptLen Lq _ key 15 _) (trChallengeFp2VecKeyed_res ..) (trChallengeFp2VecKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_rel (B := SegShapeRel)
    (A := fun r₁ r₂ : Option (List SlotProof × List SlotRec × Acc) × Tr =>
      r₁.2 = r₂.2 ∧ match r₁.1, r₂.1 with | none, none => True | some (_, _, a₁'), some (_, _, a₂') => AccShapeEq a₁' a₂' | _, _ => False)
    ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _).congr (h167 _))
    ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _).congr (h167 _))
    (stSlotsProveFixedProg_shape_indep Lq hL20 key _ _ _ _ Fp2.zero Fp2.zero Fp2.zero H v 4 _ [] [] 0 {} {} _ _ rfl
      ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩)
    fun slR₁ slR₂ ⟨hslTr, hslOpt⟩ => ?_
  rcases slR₁ with ⟨so₁, st₁⟩
  rcases slR₂ with ⟨so₂, st₂⟩
  dsimp only at hslTr hslOpt
  subst hslTr
  refine res_andThen_rel (B := SegShapeRel)
    (A := fun m₁ m₂ : Exec.Block.MaskOpening × Tr => m₁.2 = m₂.2)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _)
    ((zkBMaskFixedProg_res_tr Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _ H v _).trans
      (zkBMaskFixedProg_res_tr Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _ H v _).symm)
    fun mR₁ mR₂ hmTr => ?_
  rcases mR₁ with ⟨mo₁, mt₁⟩
  rcases mR₂ with ⟨mo₂, mt₂⟩
  dsimp only at hmTr
  subst hmTr
  cases so₁ with
  | none =>
    cases so₂ with
    | some _ => cases hslOpt
    | none =>
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun a₁ a₂ : Option Exec.Block.OpeningZk × Tr => a₁.2 = a₂.2 ∧ a₁.1.isSome = a₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ rfl _ _
          (by rw [shdP_incTA_rows_len, shdP_incTA_rows_len]) _ _ _ _ rfl _ _ rfl [] [] rfl _ H v _)
        fun aR₁ aR₂ ⟨haTr, haS⟩ => ?_
      rcases aR₁ with ⟨ao₁, at₁⟩; rcases aR₂ with ⟨ao₂, at₂⟩
      dsimp only at haTr haS; subst haTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun h₁ h₂ : Option Exec.Block.OpeningZk × Tr => h₁.2 = h₂.2 ∧ h₁.1.isSome = h₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ rfl _ _
          (by rw [shdP_incTH_rows_len, shdP_incTH_rows_len]) _ _ _ _ (by simp [haS]) _ _ rfl [] [] rfl _ H v _)
        fun hR₁ hR₂ ⟨hhTr, hhS⟩ => ?_
      rcases hR₁ with ⟨ho₁, ht₁⟩; rcases hR₂ with ⟨ho₂, ht₂⟩
      dsimp only at hhTr hhS; subst hhTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun e₁ e₂ : Option Exec.Block.OpeningZk × Tr => e₁.2 = e₂.2 ∧ e₁.1.isSome = e₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_epPrm 11 1 6 1 _ _ rfl _ _
          (by rw [shdP_epTable_rows_length, shdP_epTable_rows_length]) treeTE treeTE _ _ (by simp [haS, hhS]) _ _ rfl [] [] rfl _ H v _)
        fun eR₁ eR₂ ⟨heTr, _⟩ => ?_
      rcases eR₁ with ⟨eo₁, et₁⟩; rcases eR₂ with ⟨eo₂, et₂⟩
      dsimp only at heTr; subst heTr
      exact ⟨rfl, rfl, trivial⟩
  | some v1 =>
    cases so₂ with
    | none => cases hslOpt
    | some v2 =>
      rcases v1 with ⟨sps₁, recs₁, acc₁⟩
      rcases v2 with ⟨sps₂, recs₂, acc₂⟩
      dsimp only at hslOpt
      have hact2 : decide ((acc₁.fs ++ acc₁.hostFs).length = (shdVi tag Rp embDigest bInRow).lay.nFunctionals)
          = decide ((acc₂.fs ++ acc₂.hostFs).length = (shdVi tag Rp embDigest bInRow).lay.nFunctionals) := by
        simp [hslOpt.2.2.1, hslOpt.2.2.2.1]
      have hhA : openingHdrOk (shdP_incOpenGeomA (shdVi tag Rp embDigest bInRow)) 12 acc₁.claims.a
          = openingHdrOk (shdP_incOpenGeomA (shdVi tag Rp embDigest bInRow)) 12 acc₂.claims.a :=
        openingHdrOk_of_parts _ 12 hslOpt.2.2.2.2.1
      have hPartsH : (acc₁.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]).map Exec.Block.ZClaim.parts
          = (acc₂.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]).map Exec.Block.ZClaim.parts := by
        simp [hslOpt.2.2.2.2.2.1]
      have hhH : openingHdrOk (shdP_incOpenGeomH (shdVi tag Rp embDigest bInRow)) 12 (acc₁.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim])
          = openingHdrOk (shdP_incOpenGeomH (shdVi tag Rp embDigest bInRow)) 12 (acc₂.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]) :=
        openingHdrOk_of_parts _ 12 hPartsH
      have hhE : tokenEpHdrOk acc₁.claims.inp (shdVi tag Rp embDigest bInRow).geo.epDataRows (shdVi tag Rp embDigest bInRow).pub.epN
          = tokenEpHdrOk acc₂.claims.inp (shdVi tag Rp embDigest bInRow).geo.epDataRows (shdVi tag Rp embDigest bInRow).pub.epN :=
        tokenEpHdrOk_of_parts _ _ hslOpt.2.2.2.2.2.2.1
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun a₁ a₂ : Option Exec.Block.OpeningZk × Tr => a₁.2 = a₂.2 ∧ a₁.1.isSome = a₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ rfl _ _
          (by rw [shdP_incTA_rows_len, shdP_incTA_rows_len]) _ _ _ _ hact2 _ _ hhA acc₁.claims.a acc₂.claims.a hslOpt.2.2.2.2.1 _ H v _)
        fun aR₁ aR₂ ⟨haTr, haS⟩ => ?_
      rcases aR₁ with ⟨ao₁, at₁⟩; rcases aR₂ with ⟨ao₂, at₂⟩
      dsimp only at haTr haS; subst haTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun h₁ h₂ : Option Exec.Block.OpeningZk × Tr => h₁.2 = h₂.2 ∧ h₁.1.isSome = h₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ rfl _ _
          (by rw [shdP_incTH_rows_len, shdP_incTH_rows_len]) _ _ _ _ (by simp only [hact2, haS]) _ _ hhH _ _ hPartsH _ H v _)
        fun hR₁ hR₂ ⟨hhTr, hhS⟩ => ?_
      rcases hR₁ with ⟨ho₁, ht₁⟩; rcases hR₂ with ⟨ho₂, ht₂⟩
      dsimp only at hhTr hhS; subst hhTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun e₁ e₂ : Option Exec.Block.OpeningZk × Tr => e₁.2 = e₂.2 ∧ e₁.1.isSome = e₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_epPrm 11 1 6 1 _ _ rfl _ _
          (by rw [shdP_epTable_rows_length, shdP_epTable_rows_length]) treeTE treeTE _ _ (by simp only [hact2, haS, hhS]) _ _ hhE acc₁.claims.inp acc₂.claims.inp hslOpt.2.2.2.2.2.2.1 _ H v _)
        fun eR₁ eR₂ ⟨heTr, heS⟩ => ?_
      rcases eR₁ with ⟨eo₁, et₁⟩; rcases eR₂ with ⟨eo₂, et₂⟩
      dsimp only at heTr heS; subst heTr
      cases ao₁ <;> cases ao₂ <;> try (simp at haS)
      · exact ⟨rfl, rfl, trivial⟩
      · cases ho₁ <;> cases ho₂ <;> try (simp at hhS)
        · exact ⟨rfl, rfl, trivial⟩
        · cases eo₁ <;> cases eo₂ <;> try (simp at heS)
          · exact ⟨rfl, rfl, trivial⟩
          · simp only [SegShapeRel, Option.isSome_some, Bool.and_true, hact2]
            by_cases hc : decide ((acc₂.fs ++ acc₂.hostFs).length = (shdVi tag Rp embDigest bInRow).lay.nFunctionals) = true
            · rw [if_pos hc, if_pos hc]; exact ⟨rfl, rfl, hslOpt.2.2.2.2.2.2.2⟩
            · rw [if_neg hc, if_neg hc]; exact ⟨rfl, rfl, trivial⟩

theorem blkSegFixedProg_shape_indep {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x₁ x₂ : shieldS0.Tok → ℕ) (hx₁ : (classifyModelP Rp).admissible x₁) (hx₂ : (classifyModelP Rp).admissible x₂)
    (c₁ c₂ : ShdCoins) (k : Fin 26) (active : Bool)
    (cr₁ cr₂ : Carry) (hCr : cr₁.pending.map Exec.Block.ZClaim.parts = cr₂.pending.map Exec.Block.ZClaim.parts)
    (treeBPrev : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    SegShapeRel
      ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x₁ hx₁ c₁ k active cr₁ treeBPrev bnd startTag t).res H v base)
      ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x₂ hx₂ c₂ k active cr₂ treeBPrev bnd startTag t).res H v base) := by
  unfold blkSegFixedProg
  have h1283 := shdP_blk_slotsFixedLen tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt
  have hTRB : (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).rows.length
      = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).rows.length := by
    rw [(shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ _).rows_len,
        (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ _).rows_len]
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 16 4577 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 16 4577 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 12 (2 * 23 + 4) _ _ _)
    (merkleTableProg_ptLen Lq _ tag 12 (2 * 23 + 4) _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_res ..) (trChallengeFp2Keyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_res ..) (trChallengeFp2Keyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_res ..) (trChallengeFp2Keyed_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (merkleTableProg_ptLen Lq _ tag 16 4390 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 16 4390 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := SegShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_rel (B := SegShapeRel)
    (A := fun r₁ r₂ : Option (List SlotProof × List SlotRec × Acc) × Tr =>
      r₁.2 = r₂.2 ∧ match r₁.1, r₂.1 with | none, none => True | some (_, _, a₁'), some (_, _, a₂') => AccShapeEq a₁' a₂' | _, _ => False)
    ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283)
    ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283)
    (slotsProveFixedProg_shape_indep Lq hL20 key _ _ _ _ (fun _ => rfl) rfl rfl rfl rfl
      (fun s hist dr => by cases (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).define s hist dr <;> simp [TabsShapeEq.refl])
      _ _ _ H v 23 _ [] [] 0 {} {} _ _ rfl ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩)
    fun slR₁ slR₂ ⟨hslTr, hslOpt⟩ => ?_
  rcases slR₁ with ⟨so₁, st₁⟩
  rcases slR₂ with ⟨so₂, st₂⟩
  dsimp only at hslTr hslOpt
  subst hslTr
  refine res_andThen_rel (B := SegShapeRel)
    (A := fun m₁ m₂ : Exec.Block.MaskOpening × Tr => m₁.2 = m₂.2)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _)
    ((zkBMaskFixedProg_res_tr Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _ H v _).trans
      (zkBMaskFixedProg_res_tr Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _ H v _).symm)
    fun mR₁ mR₂ hmTr => ?_
  rcases mR₁ with ⟨mo₁, mt₁⟩
  rcases mR₂ with ⟨mo₂, mt₂⟩
  dsimp only at hmTr
  subst hmTr
  cases so₁ with
  | none =>
    cases so₂ with
    | some _ => cases hslOpt
    | none =>
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun a₁ a₂ : Option Exec.Block.OpeningZk × Tr => a₁.2 = a₂.2 ∧ a₁.1.isSome = a₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ rfl _ _
          (by rw [blkTA_rows_len, blkTA_rows_len]) _ _ _ _ rfl _ _ rfl [] [] rfl _ H v _)
        fun aR₁ aR₂ ⟨haTr, haS⟩ => ?_
      rcases aR₁ with ⟨ao₁, at₁⟩; rcases aR₂ with ⟨ao₂, at₂⟩
      dsimp only at haTr haS; subst haTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun h₁ h₂ : Option Exec.Block.OpeningZk × Tr => h₁.2 = h₂.2 ∧ h₁.1.isSome = h₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ rfl _ _
          (by rw [blkTH_rows_len, blkTH_rows_len]) _ _ _ _ (by simp [haS]) _ _ rfl [] [] rfl _ H v _)
        fun hR₁ hR₂ ⟨hhTr, hhS⟩ => ?_
      rcases hR₁ with ⟨ho₁, ht₁⟩; rcases hR₂ with ⟨ho₂, ht₂⟩
      dsimp only at hhTr hhS; subst hhTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun b₁ b₂ : Option Exec.Block.OpeningZk × Tr => b₁.2 = b₂.2 ∧ b₁.1.isSome = b₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ rfl _ _
          hTRB treeBPrev treeBPrev _ _ (by simp [haS, hhS]) _ _ rfl [] [] rfl _ H v _)
        fun bR₁ bR₂ ⟨hbTr, _⟩ => ?_
      rcases bR₁ with ⟨bo₁, bt₁⟩; rcases bR₂ with ⟨bo₂, bt₂⟩
      dsimp only at hbTr; subst hbTr
      exact ⟨rfl, rfl, trivial⟩
  | some v1 =>
    cases so₂ with
    | none => cases hslOpt
    | some v2 =>
      rcases v1 with ⟨sps₁, recs₁, acc₁⟩
      rcases v2 with ⟨sps₂, recs₂, acc₂⟩
      dsimp only at hslOpt
      have hact2 : decide ((acc₁.fs ++ acc₁.hostFs).length = (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).nFunctionals)
          = decide ((acc₂.fs ++ acc₂.hostFs).length = (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).nFunctionals) := by
        simp [hslOpt.2.2.1, hslOpt.2.2.2.1]
      have hhA := openingHdrOk_of_parts shdP_blkOpenGeomA 14 hslOpt.2.2.2.2.1
      have hPartsH : (acc₁.claims.h ++ [(shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).logupSumClaim]).map Exec.Block.ZClaim.parts
          = (acc₂.claims.h ++ [(shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).logupSumClaim]).map Exec.Block.ZClaim.parts := by
        simp [hslOpt.2.2.2.2.2.1]
      have hhH := openingHdrOk_of_parts shdP_blkOpenGeomH 14 hPartsH
      have hPartsB : (cr₁.pending ++ acc₁.claims.inp).map Exec.Block.ZClaim.parts
          = (cr₂.pending ++ acc₂.claims.inp).map Exec.Block.ZClaim.parts := by
        simp [hCr, hslOpt.2.2.2.2.2.2.1]
      have hhB := openingHdrOk_of_parts shdP_bndOpenGeom 14 hPartsB
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun a₁ a₂ : Option Exec.Block.OpeningZk × Tr => a₁.2 = a₂.2 ∧ a₁.1.isSome = a₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ rfl _ _
          (by rw [blkTA_rows_len, blkTA_rows_len]) _ _ _ _ hact2 _ _ hhA acc₁.claims.a acc₂.claims.a hslOpt.2.2.2.2.1 _ H v _)
        fun aR₁ aR₂ ⟨haTr, haS⟩ => ?_
      rcases aR₁ with ⟨ao₁, at₁⟩; rcases aR₂ with ⟨ao₂, at₂⟩
      dsimp only at haTr haS; subst haTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun h₁ h₂ : Option Exec.Block.OpeningZk × Tr => h₁.2 = h₂.2 ∧ h₁.1.isSome = h₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ rfl _ _
          (by rw [blkTH_rows_len, blkTH_rows_len]) _ _ _ _ (by simp only [hact2, haS]) _ _ hhH _ _ hPartsH _ H v _)
        fun hR₁ hR₂ ⟨hhTr, hhS⟩ => ?_
      rcases hR₁ with ⟨ho₁, ht₁⟩; rcases hR₂ with ⟨ho₂, ht₂⟩
      dsimp only at hhTr hhS; subst hhTr
      refine res_andThen_rel (B := SegShapeRel)
        (A := fun b₁ b₂ : Option Exec.Block.OpeningZk × Tr => b₁.2 = b₂.2 ∧ b₁.1.isSome = b₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ rfl _ _
          hTRB treeBPrev treeBPrev _ _ (by simp only [hact2, haS, hhS]) _ _ hhB _ _ hPartsB _ H v _)
        fun bR₁ bR₂ ⟨hbTr, hbS⟩ => ?_
      rcases bR₁ with ⟨bo₁, bt₁⟩; rcases bR₂ with ⟨bo₂, bt₂⟩
      dsimp only at hbTr hbS; subst hbTr
      cases ao₁ <;> cases ao₂ <;> try (simp at haS)
      · exact ⟨rfl, rfl, trivial⟩
      · cases ho₁ <;> cases ho₂ <;> try (simp at hhS)
        · exact ⟨rfl, rfl, trivial⟩
        · cases bo₁ <;> cases bo₂ <;> try (simp at hbS)
          · exact ⟨rfl, rfl, trivial⟩
          · simp only [SegShapeRel, Option.isSome_some, Bool.and_true, hact2]
            by_cases hc : decide ((acc₂.fs ++ acc₂.hostFs).length = (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).nFunctionals) = true
            · rw [if_pos hc, if_pos hc]; exact ⟨rfl, rfl, hslOpt.2.2.2.2.2.2.2⟩
            · rw [if_neg hc, if_neg hc]; exact ⟨rfl, rfl, trivial⟩

theorem blkChainFixedProg_shape_indep {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x₁ x₂ : shieldS0.Tok → ℕ) (hx₁ : (classifyModelP Rp).admissible x₁) (hx₂ : (classifyModelP Rp).admissible x₂)
    (c₁ c₂ : ShdCoins) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26) (active : Bool)
      (cr₁ cr₂ : Carry) (treeB : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (base : ℕ),
      cr₁.pending.map Exec.Block.ZClaim.parts = cr₂.pending.map Exec.Block.ZClaim.parts →
      ChainShapeRel
        ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x₁ hx₁ c₁ startIdx count hEnd active cr₁ treeB bnd startTag t).res H v base)
        ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x₂ hx₂ c₂ startIdx count hEnd active cr₂ treeB bnd startTag t).res H v base)
  | _, 0, _, active, cr₁, cr₂, _, _, _, _, _, hCr => by
    cases active <;> exact ⟨by simp only [blkChainFixedProg, PProg.res], by simp only [blkChainFixedProg, PProg.res, CarryOptRel, ↓reduceIte, hCr]; try trivial⟩
  | startIdx, count + 1, hEnd, active, cr₁, cr₂, treeB, bnd, startTag, t, base, hCr => by
    unfold blkChainFixedProg
    refine res_andThen_rel (B := ChainShapeRel) (A := SegShapeRel)
      (blkSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ ⟨startIdx, by omega⟩ active cr₁ treeB bnd startTag t)
      (blkSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ ⟨startIdx, by omega⟩ active cr₂ treeB bnd startTag t)
      (blkSegFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x₁ x₂ hx₁ hx₂ c₁ c₂ ⟨startIdx, by omega⟩ active cr₁ cr₂ hCr treeB bnd startTag t H v base)
      fun bR₁ bR₂ ⟨hbt, hbtr, hbopt⟩ => ?_
    rcases bR₁ with ⟨bo₁, btr₁, bt₁⟩
    rcases bR₂ with ⟨bo₂, btr₂, bt₂⟩
    dsimp only at hbt hbtr hbopt
    subst hbt; subst hbtr
    refine res_andThen_same (B := ChainShapeRel) (posTagKeyed_ptLen Lq (by omega) key bt₁) (posTagKeyed_ptLen Lq (by omega) key bt₁)
      (posTagKeyed_res ..) (posTagKeyed_res ..) ?_
    cases bo₁ with
    | none =>
      cases bo₂ with
      | some _ => cases hbopt
      | none =>
        refine res_andThen_rel (B := ChainShapeRel) (A := ChainShapeRel)
          (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ (startIdx + 1) count (by omega) false carry0 btr₁ bnd _ bt₁)
          (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ (startIdx + 1) count (by omega) false carry0 btr₁ bnd _ bt₁)
          (blkChainFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
            x₁ x₂ hx₁ hx₂ c₁ c₂ H v (startIdx + 1) count (by omega) false carry0 carry0 btr₁ bnd _ bt₁ _ rfl)
          fun rest₁ rest₂ ⟨hr2, _⟩ => ⟨hr2, trivial⟩
    | some v1 =>
      cases bo₂ with
      | none => cases hbopt
      | some v2 =>
        refine res_andThen_rel (B := ChainShapeRel) (A := ChainShapeRel)
          (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ (startIdx + 1) count (by omega) true v1.2 btr₁ bnd _ bt₁)
          (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ (startIdx + 1) count (by omega) true v2.2 btr₁ bnd _ bt₁)
          (blkChainFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
            x₁ x₂ hx₁ hx₂ c₁ c₂ H v (startIdx + 1) count (by omega) true v1.2 v2.2 btr₁ bnd _ bt₁ _ hbopt)
          fun rest₁ rest₂ ⟨hr2, hropt⟩ => ?_
        rcases rest₁ with ⟨ro₁, rrest₁⟩
        rcases rest₂ with ⟨ro₂, rrest₂⟩
        cases ro₁ <;> cases ro₂ <;> first | exact False.elim hropt | exact ⟨hr2, hropt⟩

private theorem shdVo_fields (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v₁ v₂ : ℕ) :
    (shdVo tag Rp wDigest bOutRow v₁).lay = (shdVo tag Rp wDigest bOutRow v₂).lay
      ∧ (∀ s, (shdVo tag Rp wDigest bOutRow v₁).bp.draws s = (shdVo tag Rp wDigest bOutRow v₂).bp.draws s)
      ∧ (shdVo tag Rp wDigest bOutRow v₁).bp.geom = (shdVo tag Rp wDigest bOutRow v₂).bp.geom
      ∧ (shdVo tag Rp wDigest bOutRow v₁).bp.kind = (shdVo tag Rp wDigest bOutRow v₂).bp.kind
      ∧ (shdVo tag Rp wDigest bOutRow v₁).bp.logCols = (shdVo tag Rp wDigest bOutRow v₂).bp.logCols
      ∧ (shdVo tag Rp wDigest bOutRow v₁).bp.endpointLogN = (shdVo tag Rp wDigest bOutRow v₂).bp.endpointLogN
      ∧ shdP_outcOpenGeomA (shdVo tag Rp wDigest bOutRow v₁) = shdP_outcOpenGeomA (shdVo tag Rp wDigest bOutRow v₂)
      ∧ shdP_outcOpenGeomH (shdVo tag Rp wDigest bOutRow v₁) = shdP_outcOpenGeomH (shdVo tag Rp wDigest bOutRow v₂)
      ∧ (∀ s hist dr,
          match (shdVo tag Rp wDigest bOutRow v₁).bp.define s hist dr,
                (shdVo tag Rp wDigest bOutRow v₂).bp.define s hist dr with
          | .error _, .error _ => True
          | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
          | _, _ => False) := by
  have hLay : (shdVo tag Rp wDigest bOutRow v₁).lay = (shdVo tag Rp wDigest bOutRow v₂).lay := by
    change outcLay (rcVerdict (shdP_outcPub Rp wDigest) v₁) 14 = outcLay (rcVerdict (shdP_outcPub Rp wDigest) v₂) 14
    rw [rc_outcLay_verdict, rc_outcLay_verdict]
  have hBlk : (shdVo tag Rp wDigest bOutRow v₁).blk = (shdVo tag Rp wDigest bOutRow v₂).blk := rfl
  have hDr : ∀ s, (shdVo tag Rp wDigest bOutRow v₁).bp.draws s = (shdVo tag Rp wDigest bOutRow v₂).bp.draws s := fun s => by
    change outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v₁) s = outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v₂) s
    rw [rc_outcDraws_verdict, rc_outcDraws_verdict]
  have hGeom : (shdVo tag Rp wDigest bOutRow v₁).bp.geom = (shdVo tag Rp wDigest bOutRow v₂).bp.geom := by
    change mGeom (shdVo tag Rp wDigest bOutRow v₁).lay (shdVo tag Rp wDigest bOutRow v₁).blk outcAGroups outcHGroups
      = mGeom (shdVo tag Rp wDigest bOutRow v₂).lay (shdVo tag Rp wDigest bOutRow v₂).blk outcAGroups outcHGroups
    rw [hLay, hBlk]
  have hKind : (shdVo tag Rp wDigest bOutRow v₁).bp.kind = (shdVo tag Rp wDigest bOutRow v₂).bp.kind := by
    change (fun s => ((shdVo tag Rp wDigest bOutRow v₁).lay.sched.slots.getD s _).kind)
      = (fun s => ((shdVo tag Rp wDigest bOutRow v₂).lay.sched.slots.getD s _).kind)
    rw [hLay]
  have hLC : (shdVo tag Rp wDigest bOutRow v₁).bp.logCols = (shdVo tag Rp wDigest bOutRow v₂).bp.logCols := by
    change (shdVo tag Rp wDigest bOutRow v₁).lay.logN = (shdVo tag Rp wDigest bOutRow v₂).lay.logN; rw [hLay]
  have hEL : (shdVo tag Rp wDigest bOutRow v₁).bp.endpointLogN = (shdVo tag Rp wDigest bOutRow v₂).bp.endpointLogN := by
    unfold OutcV.bp stageBP shdVo shdP_outcV outcVAt; rfl
  have hOGa : shdP_outcOpenGeomA (shdVo tag Rp wDigest bOutRow v₁) = shdP_outcOpenGeomA (shdVo tag Rp wDigest bOutRow v₂) := by
    unfold shdP_outcOpenGeomA; rw [hLay]
  have hOGh : shdP_outcOpenGeomH (shdVo tag Rp wDigest bOutRow v₁) = shdP_outcOpenGeomH (shdVo tag Rp wDigest bOutRow v₂) := by
    unfold shdP_outcOpenGeomH; rw [hLay]
  have hDef : ∀ s hist dr,
      match (shdVo tag Rp wDigest bOutRow v₁).bp.define s hist dr,
            (shdVo tag Rp wDigest bOutRow v₂).bp.define s hist dr with
      | .error _, .error _ => True
      | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
      | _, _ => False := fun s hist dr => by
    change match outcDefine (rcVerdict (shdP_outcPub Rp wDigest) v₁) (shdP_outcGeo bOutRow) s hist dr,
                 outcDefine (rcVerdict (shdP_outcPub Rp wDigest) v₂) (shdP_outcGeo bOutRow) s hist dr with
      | .error _, .error _ => True
      | .ok df₁, .ok df₂ => TabsShapeEq df₁.tabs df₂.tabs ∧ df₁.hosted = df₂.hosted
      | _, _ => False
    exact outcDefine_tabsShapeEq (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow) v₁ v₂ s hist dr
  exact ⟨hLay, hDr, hGeom, hKind, hLC, hEL, hOGa, hOGh, hDef⟩

theorem outcSegFixedProg_shape_indep (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x₁ x₂ : shieldS0.Tok → ℕ) (hx₁ : (classifyModelP Rp).admissible x₁) (hx₂ : (classifyModelP Rp).admissible x₂)
    (c₁ c₂ : ShdCoins) (active : Bool)
    (cr₁ cr₂ : Carry) (hCr : cr₁.pending.map Exec.Block.ZClaim.parts = cr₂.pending.map Exec.Block.ZClaim.parts)
    (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    OutcShapeRel
      ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x₁ hx₁ c₁ active cr₁ treeB26 bnd startTag t).res H v base)
      ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x₂ hx₂ c₂ active cr₂ treeB26 bnd startTag t).res H v base) := by
  unfold outcSegFixedProg
  set v₁ := (classifySpecP Rp x₁).getD 0
  set v₂ := (classifySpecP Rp x₂).getD 0
  obtain ⟨hLay, hDr, hGeom, hKind, hLC, hEL, hOGa, hOGh, hDef⟩ := shdVo_fields tag Rp wDigest bOutRow v₁ v₂
  have h290₁ := shdP_outc_slotsFixedLen tag Rp wDigest bOutRow v₁
  have h290₂ := shdP_outc_slotsFixedLen tag Rp wDigest bOutRow v₂
  have hTRB : (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨26, by omega⟩).rows.length
      = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨26, by omega⟩).rows.length := by
    rw [(shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨26, by omega⟩).rows_len,
        (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨26, by omega⟩).rows_len]
  refine res_andThen_same (B := OutcShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (merkleTableProg_ptLen Lq _ tag 12 (2 * 8 + 4) _ _ _)
    (merkleTableProg_ptLen Lq _ tag 12 (2 * 8 + 4) _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (trChallengeFp2VecKeyed_ptLen Lq _ key 2 _) (trChallengeFp2VecKeyed_ptLen Lq _ key 2 _) (trChallengeFp2VecKeyed_res ..) (trChallengeFp2VecKeyed_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (merkleTableProg_ptLen Lq _ tag 14 38 _ _ _)
    (merkleTableProg_ptLen Lq _ tag 14 38 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := OutcShapeRel) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_rel (B := OutcShapeRel)
    (A := fun r₁ r₂ : Option (List SlotProof × List SlotRec × Acc) × Tr =>
      r₁.2 = r₂.2 ∧ match r₁.1, r₂.1 with | none, none => True | some (_, _, a₁'), some (_, _, a₂') => AccShapeEq a₁' a₂' | _, _ => False)
    ((slotsProveFixedProg_ptLen Lq hL20 key (shdVo tag Rp wDigest bOutRow v₁).bp _ _ _ _ 8 _ [] 0 {} _).congr h290₁)
    ((slotsProveFixedProg_ptLen Lq hL20 key (shdVo tag Rp wDigest bOutRow v₂).bp _ _ _ _ 8 _ [] 0 {} _).congr h290₂)
    (slotsProveFixedProg_shape_indep Lq hL20 key (shdVo tag Rp wDigest bOutRow v₁).bp (shdVo tag Rp wDigest bOutRow v₂).bp _ _
      hDr hGeom hKind hLC hEL hDef _ _ _ H v 8 _ [] [] 0 {} {} _ _ rfl ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩)
    fun slR₁ slR₂ ⟨hslTr, hslOpt⟩ => ?_
  rcases slR₁ with ⟨so₁, st₁⟩
  rcases slR₂ with ⟨so₂, st₂⟩
  dsimp only at hslTr hslOpt
  subst hslTr
  refine res_andThen_rel (B := OutcShapeRel)
    (A := fun m₁ m₂ : Exec.Block.MaskOpening × Tr => m₁.2 = m₂.2)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _)
    ((zkBMaskFixedProg_res_tr Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _ H v _).trans
      (zkBMaskFixedProg_res_tr Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _ H v _).symm)
    fun mR₁ mR₂ hmTr => ?_
  rcases mR₁ with ⟨mo₁, mt₁⟩
  rcases mR₂ with ⟨mo₂, mt₂⟩
  dsimp only at hmTr
  subst hmTr
  cases so₁ with
  | none =>
    cases so₂ with
    | some _ => cases hslOpt
    | none =>
      refine res_andThen_rel (B := OutcShapeRel)
        (A := fun a₁ a₂ : Option Exec.Block.OpeningZk × Tr => a₁.2 = a₂.2 ∧ a₁.1.isSome = a₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ hOGa _ _
          (by rw [shdP_outcTA_rows_len, shdP_outcTA_rows_len]) _ _ _ _ rfl _ _ (by rw [hOGa]) [] [] rfl _ H v _)
        fun aR₁ aR₂ ⟨haTr, haS⟩ => ?_
      rcases aR₁ with ⟨ao₁, at₁⟩; rcases aR₂ with ⟨ao₂, at₂⟩
      dsimp only at haTr haS; subst haTr
      refine res_andThen_rel (B := OutcShapeRel)
        (A := fun h₁ h₂ : Option Exec.Block.OpeningZk × Tr => h₁.2 = h₂.2 ∧ h₁.1.isSome = h₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ hOGh _ _
          (by rw [shdP_outcTH_rows_len, shdP_outcTH_rows_len]) _ _ _ _ (by simp [haS]) _ _ (by rw [hOGh]) [] [] rfl _ H v _)
        fun hR₁ hR₂ ⟨hhTr, hhS⟩ => ?_
      rcases hR₁ with ⟨ho₁, ht₁⟩; rcases hR₂ with ⟨ho₂, ht₂⟩
      dsimp only at hhTr hhS; subst hhTr
      refine res_andThen_rel (B := OutcShapeRel)
        (A := fun b₁ b₂ : Option Exec.Block.OpeningZk × Tr => b₁.2 = b₂.2 ∧ b₁.1.isSome = b₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ rfl _ _
          hTRB treeB26 treeB26 _ _ (by simp [haS, hhS]) _ _ rfl [] [] rfl _ H v _)
        fun bR₁ bR₂ ⟨hbTr, _⟩ => ?_
      rcases bR₁ with ⟨bo₁, bt₁⟩; rcases bR₂ with ⟨bo₂, bt₂⟩
      dsimp only at hbTr; subst hbTr
      exact ⟨rfl, rfl⟩
  | some v1 =>
    cases so₂ with
    | none => cases hslOpt
    | some v2 =>
      rcases v1 with ⟨sps₁, recs₁, acc₁⟩
      rcases v2 with ⟨sps₂, recs₂, acc₂⟩
      dsimp only at hslOpt
      have houtNil : (acc₁.claims.out = []) ↔ (acc₂.claims.out = []) := by
        have hlen : acc₁.claims.out.length = acc₂.claims.out.length := by
          have := congrArg List.length hslOpt.2.2.2.2.2.2.2; simpa using this
        rw [← List.length_eq_zero_iff, ← List.length_eq_zero_iff, hlen]
      have hact2 : decide ((acc₁.fs ++ acc₁.hostFs).length = (shdVo tag Rp wDigest bOutRow v₁).lay.nFunctionals ∧ acc₁.claims.out = [])
          = decide ((acc₂.fs ++ acc₂.hostFs).length = (shdVo tag Rp wDigest bOutRow v₂).lay.nFunctionals ∧ acc₂.claims.out = []) := by
        rw [hLay]; simp [hslOpt.2.2.1, hslOpt.2.2.2.1, houtNil]
      have hhA : openingHdrOk (shdP_outcOpenGeomA (shdVo tag Rp wDigest bOutRow v₁)) 12 acc₁.claims.a
          = openingHdrOk (shdP_outcOpenGeomA (shdVo tag Rp wDigest bOutRow v₂)) 12 acc₂.claims.a := by
        rw [hOGa]; exact openingHdrOk_of_parts _ 12 hslOpt.2.2.2.2.1
      have hPartsH : (acc₁.claims.h ++ [(shdVo tag Rp wDigest bOutRow v₁).lay.logupSumClaim]).map Exec.Block.ZClaim.parts
          = (acc₂.claims.h ++ [(shdVo tag Rp wDigest bOutRow v₂).lay.logupSumClaim]).map Exec.Block.ZClaim.parts := by
        rw [hLay]; simp [hslOpt.2.2.2.2.2.1]
      have hhH : openingHdrOk (shdP_outcOpenGeomH (shdVo tag Rp wDigest bOutRow v₁)) 12 (acc₁.claims.h ++ [(shdVo tag Rp wDigest bOutRow v₁).lay.logupSumClaim])
          = openingHdrOk (shdP_outcOpenGeomH (shdVo tag Rp wDigest bOutRow v₂)) 12 (acc₂.claims.h ++ [(shdVo tag Rp wDigest bOutRow v₂).lay.logupSumClaim]) := by
        rw [hOGh]; exact openingHdrOk_of_parts _ 12 hPartsH
      have hPartsB : (cr₁.pending ++ acc₁.claims.inp).map Exec.Block.ZClaim.parts
          = (cr₂.pending ++ acc₂.claims.inp).map Exec.Block.ZClaim.parts := by
        simp [hCr, hslOpt.2.2.2.2.2.2.1]
      have hhB := openingHdrOk_of_parts shdP_bndOpenGeom 14 hPartsB
      refine res_andThen_rel (B := OutcShapeRel)
        (A := fun a₁ a₂ : Option Exec.Block.OpeningZk × Tr => a₁.2 = a₂.2 ∧ a₁.1.isSome = a₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ hOGa _ _
          (by rw [shdP_outcTA_rows_len, shdP_outcTA_rows_len]) _ _ _ _ hact2 _ _ hhA acc₁.claims.a acc₂.claims.a hslOpt.2.2.2.2.1 _ H v _)
        fun aR₁ aR₂ ⟨haTr, haS⟩ => ?_
      rcases aR₁ with ⟨ao₁, at₁⟩; rcases aR₂ with ⟨ao₂, at₂⟩
      dsimp only at haTr haS; subst haTr
      refine res_andThen_rel (B := OutcShapeRel)
        (A := fun h₁ h₂ : Option Exec.Block.OpeningZk × Tr => h₁.2 = h₂.2 ∧ h₁.1.isSome = h₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ hOGh _ _
          (by rw [shdP_outcTH_rows_len, shdP_outcTH_rows_len]) _ _ _ _ (by simp only [hact2, haS]) _ _ hhH _ _ hPartsH _ H v _)
        fun hR₁ hR₂ ⟨hhTr, hhS⟩ => ?_
      rcases hR₁ with ⟨ho₁, ht₁⟩; rcases hR₂ with ⟨ho₂, ht₂⟩
      dsimp only at hhTr hhS; subst hhTr
      refine res_andThen_rel (B := OutcShapeRel)
        (A := fun b₁ b₂ : Option Exec.Block.OpeningZk × Tr => b₁.2 = b₂.2 ∧ b₁.1.isSome = b₂.1.isSome)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _)
        (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _)
        (openingAuditFixedProg_res_shape_indep' Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ rfl _ _
          hTRB treeB26 treeB26 _ _ (by simp only [hact2, haS, hhS]) _ _ hhB _ _ hPartsB _ H v _)
        fun bR₁ bR₂ ⟨hbTr, hbS⟩ => ?_
      rcases bR₁ with ⟨bo₁, bt₁⟩; rcases bR₂ with ⟨bo₂, bt₂⟩
      dsimp only at hbTr hbS; subst hbTr
      cases ao₁ <;> cases ao₂ <;> try (simp at haS)
      · exact ⟨rfl, rfl⟩
      · cases ho₁ <;> cases ho₂ <;> try (simp at hhS)
        · exact ⟨rfl, rfl⟩
        · cases bo₁ <;> cases bo₂ <;> try (simp at hbS)
          · exact ⟨rfl, rfl⟩
          · simp only [OutcShapeRel, Option.isSome_some, Bool.and_true, hact2]
            by_cases hc : decide ((acc₂.fs ++ acc₂.hostFs).length = (shdVo tag Rp wDigest bOutRow v₂).lay.nFunctionals ∧ acc₂.claims.out = []) = true
            · rw [if_pos hc, if_pos hc]; exact ⟨rfl, rfl⟩
            · rw [if_neg hc, if_neg hc]; exact ⟨rfl, rfl⟩

def carryOf {α : Type} (o : Option (α × Carry)) : Carry :=
  match o with | some (_, cr) => cr | none => carry0

def shdRunActiveOf {α β γ : Type}
    (inc : Option (α × Carry) × MerkleLevels 16 × Tr)
    (blk : Bool → Carry → MerkleLevels 16 → Tr → Option (β × Carry) × MerkleLevels 16 × Tr × Dig)
    (out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option γ × Tr) : Prop :=
  let b := blk inc.1.isSome (carryOf inc.1) inc.2.1 inc.2.2
  let o := out b.1.isSome (carryOf b.1) b.2.1 b.2.2.2 b.2.2.1
  inc.1.isSome = true ∧ b.1.isSome = true ∧ o.1.isSome = true

def shdRunOutOf {Hdr : Type}
    (hdr : Hdr) (refused : ClsStmt Hdr) (v : Fin shdP_zkResPts → Dig) (verdict : ℕ)
    (inc : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr)
    (blk : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig)
    (out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr) :
    ClsStmt Hdr × List (List UInt8) :=
  let vf := shdExtV v
  let b := blk inc.1.isSome (carryOf inc.1) inc.2.1 inc.2.2
  let o := out b.1.isSome (carryOf b.1) b.2.1 b.2.2.2 b.2.2.1
  match inc.1, b.1, o.1 with
  | some (incEnc, _), some (blkBytes, _), some outEnc =>
    (honestStmt hdr (levelsOfV vf 11 0).getRoot verdict,
      incEnc (posTagOfV vf (4104 + incSegFixedLen)) ::
        (blkBytes ++ [outEnc (posTagOfV vf (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 + outcSegFixedLen))]))
  | _, _, _ => (refused, [])

/-- Active-run predicate for `(x, c)` at oracle-output stream `v : ℕ → Dig`: all 28 segments succeed. -/
def shdRunActive {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (v : ℕ → Dig) : Prop :=
  shdRunActiveOf
    ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c
      (levelsOfV v 11 0) (v 4101) (posTagOfV v 4102) ⟨v 4101, 0, key⟩).res (fun _ => default) v 4104)
    (fun act cr trB t => (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x.1 x.2 c 0 26 (by omega) act cr trB (v 4101) (posTagOfV v (4104 + incSegFixedLen)) t).res
      (fun _ => default) v (4104 + incSegFixedLen + 2))
    (fun act cr trB st t => (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x.1 x.2 c act cr trB (v 4101) st t).res
      (fun _ => default) v (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26))

private theorem eq_shdRunOutOf {Hdr : Type}
    (hdr : Hdr) (refused : ClsStmt Hdr) (v : Fin shdP_zkResPts → Dig) (verdict : ℕ)
    (inc : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr)
    (blk : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig)
    (out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr)
    {incV : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr}
    {blkV : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig}
    {outV : Option (Dig → List UInt8) × Tr}
    {lhs : ClsStmt Hdr × List (List UInt8)}
    (hInc : incV = inc)
    (hBlk : blkV = blk incV.1.isSome (carryOf incV.1) incV.2.1 incV.2.2)
    (hOut : outV = out blkV.1.isSome (carryOf blkV.1) blkV.2.1 blkV.2.2.2 blkV.2.2.1)
    (hlhs : lhs =
      match incV.1, blkV.1, outV.1 with
      | some (incEnc, _), some (blkBytes, _), some outEnc =>
        (honestStmt hdr (levelsOfV (shdExtV v) 11 0).getRoot verdict,
          incEnc (posTagOfV (shdExtV v) (4104 + incSegFixedLen)) ::
            (blkBytes ++ [outEnc (posTagOfV (shdExtV v) (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 + outcSegFixedLen))]))
      | _, _, _ => (refused, [])) :
    lhs = shdRunOutOf hdr refused v verdict inc blk out := by
  subst hInc; subst hBlk; subst hOut; exact hlhs

theorem shdRunOutOf_eq_some {Hdr : Type}
    (hdr : Hdr) (refused : ClsStmt Hdr) (v : Fin shdP_zkResPts → Dig) (verdict : ℕ)
    {inc : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr}
    {blk : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig}
    {out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr}
    {incEnc : Dig → List UInt8} {cr0 : Carry} {trB0 : MerkleLevels 16} {tInc : Tr}
    {blkBs : List (List UInt8)} {cr26 : Carry} {trB26 : MerkleLevels 16} {tBlk : Tr} {eBlk : Dig}
    {outEnc : Dig → List UInt8}
    (hInc1 : inc.1 = some (incEnc, cr0)) (hIncTr : inc.2.1 = trB0) (hIncT : inc.2.2 = tInc)
    (hBlk1 : (blk true cr0 trB0 tInc).1 = some (blkBs, cr26))
    (hBlkTr : (blk true cr0 trB0 tInc).2.1 = trB26)
    (hBlkT : (blk true cr0 trB0 tInc).2.2.1 = tBlk)
    (hBlkE : (blk true cr0 trB0 tInc).2.2.2 = eBlk)
    (hOut1 : (out true cr26 trB26 eBlk tBlk).1 = some outEnc) :
    shdRunOutOf hdr refused v verdict inc blk out =
      (honestStmt hdr (levelsOfV (shdExtV v) 11 0).getRoot verdict,
        incEnc (posTagOfV (shdExtV v) (4104 + incSegFixedLen)) ::
          (blkBs ++ [outEnc (posTagOfV (shdExtV v) (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 + outcSegFixedLen))])) := by
  unfold shdRunOutOf
  rcases inc with ⟨o1, tr1, t1⟩; dsimp only at hInc1 hIncTr hIncT; rw [hInc1, hIncTr, hIncT]
  dsimp only [Option.isSome_some, carryOf]
  rcases hB : blk true cr0 trB0 tInc with ⟨o2, tr2, t2, e2⟩
  rw [hB] at hBlk1 hBlkTr hBlkT hBlkE; dsimp only at hBlk1 hBlkTr hBlkT hBlkE; rw [hBlk1, hBlkTr, hBlkT, hBlkE]
  dsimp only [Option.isSome_some, carryOf]
  rcases hO : out true cr26 trB26 eBlk tBlk with ⟨o3, t3⟩
  rw [hO] at hOut1; dsimp only at hOut1; rw [hOut1]

private theorem shdRunOutOf_of_not_active {Hdr : Type}
    (hdr : Hdr) (refused : ClsStmt Hdr) (v : Fin shdP_zkResPts → Dig) (verdict : ℕ)
    (inc : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr)
    (blk : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig)
    (out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr)
    (hna : ¬ shdRunActiveOf inc blk out) :
    shdRunOutOf hdr refused v verdict inc blk out = (refused, []) := by
  unfold shdRunActiveOf shdRunOutOf at *
  rcases inc with ⟨o1, tr1, t1⟩
  cases o1 with
  | none => rfl
  | some incV =>
    dsimp only [Option.isSome_some, carryOf] at hna ⊢
    rcases hB : blk true incV.2 tr1 t1 with ⟨o2, tr2, t2, e2⟩
    rw [hB] at hna; dsimp only at hna
    cases o2 with
    | none => rfl
    | some blkV =>
      dsimp only [Option.isSome_some, carryOf] at hna ⊢
      rcases hO : out true blkV.2 tr2 e2 t2 with ⟨o3, t3⟩
      rw [hO] at hna; dsimp only at hna
      cases o3 with
      | none => rfl
      | some outV => exact absurd ⟨rfl, rfl, rfl⟩ hna

private theorem shdRunOutOf_congr {Hdr : Type}
    (hdr : Hdr) (refused : ClsStmt Hdr) (v : Fin shdP_zkResPts → Dig) (verdict : ℕ)
    {inc₁ inc₂ : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr}
    {blk₁ blk₂ : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig}
    {out₁ out₂ : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr}
    (hInc : inc₁ = inc₂)
    (hBlk : ∀ act cr trB t, blk₁ act cr trB t = blk₂ act cr trB t)
    (hOut : ∀ act cr trB st t, out₁ act cr trB st t = out₂ act cr trB st t) :
    shdRunOutOf hdr refused v verdict inc₁ blk₁ out₁
      = shdRunOutOf hdr refused v verdict inc₂ blk₂ out₂ := by
  subst hInc
  have hb : blk₁ = blk₂ := funext fun a => funext fun b => funext fun c => funext fun d => hBlk a b c d
  have ho : out₁ = out₂ := funext fun a => funext fun b => funext fun c => funext fun d => funext fun e => hOut a b c d e
  subst hb ho; rfl

theorem shdRunOutOf_active_eq {Hdr : Type}
    (hdr : Hdr) (refused : ClsStmt Hdr) (v : Fin shdP_zkResPts → Dig) (verdict₁ verdict₂ : ℕ)
    (inc₁ inc₂ : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr)
    (blk₁ blk₂ : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig)
    (out₁ out₂ : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr)
    (ha₁ : shdRunActiveOf inc₁ blk₁ out₁) (ha₂ : shdRunActiveOf inc₂ blk₂ out₂)
    (heq : shdRunOutOf hdr refused v verdict₁ inc₁ blk₁ out₁ = shdRunOutOf hdr refused v verdict₂ inc₂ blk₂ out₂) :
    ∃ (incEnc₁ incEnc₂ : Dig → List UInt8) (cr0₁ cr0₂ : Carry) (trB0₁ trB0₂ : MerkleLevels 16) (tInc₁ tInc₂ : Tr)
      (blkBs₁ blkBs₂ : List (List UInt8)) (cr26₁ cr26₂ : Carry) (trB26₁ trB26₂ : MerkleLevels 16) (tBlk₁ tBlk₂ : Tr) (eBlk₁ eBlk₂ : Dig)
      (outEnc₁ outEnc₂ : Dig → List UInt8) (tOut₁ tOut₂ : Tr),
      inc₁ = (some (incEnc₁, cr0₁), trB0₁, tInc₁)
      ∧ inc₂ = (some (incEnc₂, cr0₂), trB0₂, tInc₂)
      ∧ blk₁ true cr0₁ trB0₁ tInc₁ = (some (blkBs₁, cr26₁), trB26₁, tBlk₁, eBlk₁)
      ∧ blk₂ true cr0₂ trB0₂ tInc₂ = (some (blkBs₂, cr26₂), trB26₂, tBlk₂, eBlk₂)
      ∧ out₁ true cr26₁ trB26₁ eBlk₁ tBlk₁ = (some outEnc₁, tOut₁)
      ∧ out₂ true cr26₂ trB26₂ eBlk₂ tBlk₂ = (some outEnc₂, tOut₂)
      ∧ verdict₁ = verdict₂
      ∧ incEnc₁ (posTagOfV (shdExtV v) (4104 + incSegFixedLen)) = incEnc₂ (posTagOfV (shdExtV v) (4104 + incSegFixedLen))
      ∧ blkBs₁ = blkBs₂
      ∧ outEnc₁ (posTagOfV (shdExtV v) (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 + outcSegFixedLen))
        = outEnc₂ (posTagOfV (shdExtV v) (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 + outcSegFixedLen)) := by
  unfold shdRunActiveOf at ha₁ ha₂
  unfold shdRunOutOf at heq
  rcases inc₁ with ⟨oInc1, trB0_1, tInc1⟩
  rcases inc₂ with ⟨oInc2, trB0_2, tInc2⟩
  dsimp only at ha₁ ha₂ heq
  cases oInc1 with | none => simp at ha₁ | some vInc1 =>
  cases oInc2 with | none => simp at ha₂ | some vInc2 =>
  rcases vInc1 with ⟨incEnc1, cr0_1⟩; rcases vInc2 with ⟨incEnc2, cr0_2⟩
  dsimp only [Option.isSome_some, carryOf] at ha₁ ha₂ heq
  rcases hB1 : blk₁ true cr0_1 trB0_1 tInc1 with ⟨oBlk1, trB26_1, tBlk1, eBlk1⟩
  rcases hB2 : blk₂ true cr0_2 trB0_2 tInc2 with ⟨oBlk2, trB26_2, tBlk2, eBlk2⟩
  rw [hB1] at ha₁ heq; rw [hB2] at ha₂ heq; dsimp only at ha₁ ha₂ heq
  cases oBlk1 with | none => simp at ha₁ | some vBlk1 =>
  cases oBlk2 with | none => simp at ha₂ | some vBlk2 =>
  rcases vBlk1 with ⟨blkBs1, cr26_1⟩; rcases vBlk2 with ⟨blkBs2, cr26_2⟩
  dsimp only [Option.isSome_some, carryOf] at ha₁ ha₂ heq
  rcases hO1 : out₁ true cr26_1 trB26_1 eBlk1 tBlk1 with ⟨oOut1, tOut1⟩
  rcases hO2 : out₂ true cr26_2 trB26_2 eBlk2 tBlk2 with ⟨oOut2, tOut2⟩
  rw [hO1] at ha₁ heq; rw [hO2] at ha₂ heq; dsimp only at ha₁ ha₂ heq
  cases oOut1 with | none => simp at ha₁ | some outEnc1 =>
  cases oOut2 with | none => simp at ha₂ | some outEnc2 =>
  simp only [Prod.mk.injEq, List.cons.injEq] at heq
  obtain ⟨hStmt, hIncB, hTail⟩ := heq
  have hRev := congrArg List.reverse hTail
  simp only [List.reverse_append, List.reverse_singleton, List.singleton_append, List.cons.injEq] at hRev
  exact ⟨incEnc1, incEnc2, cr0_1, cr0_2, trB0_1, trB0_2, tInc1, tInc2,
    blkBs1, blkBs2, cr26_1, cr26_2, trB26_1, trB26_2, tBlk1, tBlk2, eBlk1, eBlk2,
    outEnc1, outEnc2, tOut1, tOut2,
    rfl, rfl, hB1, hB2, hO1, hO2, congrArg ClsStmt.verdict hStmt, hIncB,
    List.reverse_injective hRev.2, hRev.1⟩

private theorem res_andThen_eq_at {Q D α β : Type} {H : Q → D} {v : ℕ → D}
    {p : PProg Q D α} {k : α → PProg Q D β} {n base base' : ℕ} {a : α} {y : β}
    (hp : p.PtLen n) (hb : base + n = base') (ha : p.res H v base = a) (hk : (k a).res H v base' = y) :
    (p.andThen k).res H v base = y := by
  rw [PProg.res_andThen H v p k n base hp, hb, ha, hk]

private theorem res_andThen_step {Q D α β : Type} {H : Q → D} {v : ℕ → D}
    {p : PProg Q D α} {k : α → PProg Q D β} {n base base' : ℕ} {y : β}
    (hp : p.PtLen n) (hb : base + n = base')
    (hk : ∀ a, a = p.res H v base → (k a).res H v base' = y) :
    (p.andThen k).res H v base = y := by
  rw [PProg.res_andThen H v p k n base hp, hb]
  exact hk _ rfl

/-- Exact `.outOf` expansion of `shdP_runFixedProg` at any `(x, c, v)`. -/
theorem shdP_runFixedProg_outOf_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (v : Fin shdP_zkResPts → Dig) :
    PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c) v =
      shdRunOutOf hdr refused v ((classifySpecP Rp x.1).getD 0)
        ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c
          (levelsOfV (shdExtV v) 11 0) (shdExtV v 4101) (posTagOfV (shdExtV v) 4102) ⟨shdExtV v 4101, 0, key⟩).res
          (fun _ => default) (shdExtV v) 4104)
        (fun act cr trB t => (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x.1 x.2 c 0 26 (by omega) act cr trB (shdExtV v 4101) (posTagOfV (shdExtV v) (4104 + incSegFixedLen)) t).res
          (fun _ => default) (shdExtV v) (4104 + incSegFixedLen + 2))
        (fun act cr trB st t => (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
          x.1 x.2 c act cr trB (shdExtV v 4101) st t).res
          (fun _ => default) (shdExtV v) (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26)) := by
  change (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
    ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c).res (fun _ => default) (shdExtV v) 0 = _
  unfold shdP_runFixedProg
  refine res_andThen_eq_at (merkleTableProg_ptLen Lq _ tag 11 6 _ _ _) (by norm_num : 0 + (2 ^ 11 + (2 ^ 11 - 1)) = 4095)
    (merkleTableProg_res ..) ?_
  refine res_andThen_eq_at (shdP_hdrPProgF_ptLen Lq hL20 key (hw hdr) hfit _ _) (by norm_num : 4095 + 7 = 4102)
    (a := ⟨shdExtV v 4101, 0, key⟩) (shdP_hdrPProgF_res ..) ?_
  rw [show ({ state := shdExtV v 4101, counter := 0, key := key } : Tr).state = shdExtV v 4101 from rfl]
  refine res_andThen_eq_at (posTagKeyed_ptLen Lq _ key _) (by norm_num : 4102 + 2 = 4104)
    (posTagKeyed_res ..) ?_
  refine res_andThen_step (incSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c _ _ _ _)
    rfl fun ⟨oInc, trB0, tInc⟩ hIncV => ?_
  refine res_andThen_eq_at (posTagKeyed_ptLen Lq _ key _) rfl (posTagKeyed_res ..) ?_
  rcases oInc with _ | ⟨incEnc, cr0⟩ <;> (
    dsimp only [Option.isSome_none, Option.isSome_some]
    refine res_andThen_step
      (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c 0 26 (by omega) _ _ _ _ _ _)
      rfl fun ⟨oBlk, trB26, tBlk, eBlk⟩ hBlkV => ?_
    rcases oBlk with _ | ⟨blkBs, cr26⟩ <;> (
      dsimp only [Option.isSome_none, Option.isSome_some]
      refine res_andThen_step
        (outcSegFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
          x.1 x.2 c _ _ _ _ _ _)
        rfl fun ⟨oOut, tOut⟩ hOutV => ?_
      refine res_andThen_eq_at (posTagKeyed_ptLen Lq _ key _) rfl (posTagKeyed_res ..) ?_
      apply eq_shdRunOutOf
      · exact hIncV
      · exact hBlkV
      · exact hOutV
      · cases oOut <;> rfl))

private theorem option_carry_of_match {α : Type} {o₁ o₂ : Option (α × Carry)}
    (h : CarryOptRel o₁ o₂) :
    o₁.isSome = o₂.isSome
      ∧ (carryOf o₁).pending.map Exec.Block.ZClaim.parts
        = (carryOf o₂).pending.map Exec.Block.ZClaim.parts := by
  cases o₁ <;> cases o₂ <;> first | exact False.elim h | exact ⟨rfl, rfl⟩ | exact ⟨rfl, h⟩

private theorem shdRunActive_congr
    (inc1 inc2 : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr)
    (blk1 blk2 : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig)
    (out1 out2 : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr)
    (hInc : SegShapeRel inc1 inc2)
    (hBlk : ∀ (act : Bool) (c1 c2 : Carry) (trB : MerkleLevels 16) (t : Tr),
      c1.pending.map Exec.Block.ZClaim.parts = c2.pending.map Exec.Block.ZClaim.parts →
      ChainShapeRel (blk1 act c1 trB t) (blk2 act c2 trB t))
    (hOut : ∀ (act : Bool) (c1 c2 : Carry) (trB : MerkleLevels 16) (st : Dig) (t : Tr),
      c1.pending.map Exec.Block.ZClaim.parts = c2.pending.map Exec.Block.ZClaim.parts →
      OutcShapeRel (out1 act c1 trB st t) (out2 act c2 trB st t)) :
    shdRunActiveOf inc1 blk1 out1 ↔ shdRunActiveOf inc2 blk2 out2 := by
  unfold shdRunActiveOf
  unfold SegShapeRel at hInc
  dsimp only
  obtain ⟨hIncSome, hCr0⟩ := option_carry_of_match hInc.2.2
  rw [hInc.1, hInc.2.1, hIncSome]
  have hb := hBlk inc2.1.isSome (carryOf inc1.1) (carryOf inc2.1) inc2.2.1 inc2.2.2 hCr0
  unfold ChainShapeRel at hb
  obtain ⟨hBlkSome, hCr26⟩ := option_carry_of_match hb.2
  set b1 := blk1 inc2.1.isSome (carryOf inc1.1) inc2.2.1 inc2.2.2
  set b2 := blk2 inc2.1.isSome (carryOf inc2.1) inc2.2.1 inc2.2.2
  rw [hb.1, hBlkSome]
  have ho := hOut b2.1.isSome (carryOf b1.1) (carryOf b2.1) b2.2.1 b2.2.2.2 b2.2.2.1 hCr26
  unfold OutcShapeRel at ho
  rw [ho.2]

/-- **`shdRunActive` is 100% independent of `(x, c)`** (depends ONLY on `v`)! -/
theorem shdP_runFixedProg_active_indep {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x₁ x₂ : {x // (classifyModelP Rp).admissible x}) (c₁ c₂ : ShdCoins) (v : ℕ → Dig) :
    shdRunActive (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₁ c₁ v
      ↔ shdRunActive (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₂ c₂ v := by
  unfold shdRunActive
  refine shdRunActive_congr _ _ _ _ _ _ ?_ ?_ ?_
  · exact incSegFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₁.1 x₂.1 c₁ c₂
      (levelsOfV v 11 0) (v 4101) (posTagOfV v 4102) ⟨v 4101, 0, key⟩ (fun _ => default) v 4104
  · intro act cr1 cr2 trB t hCr
    exact blkChainFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x₁.1 x₂.1 x₁.2 x₂.2 c₁ c₂ (fun _ => default) v 0 26 (by omega) act cr1 cr2 trB
      (v 4101) (posTagOfV v (4104 + incSegFixedLen)) t (4104 + incSegFixedLen + 2) hCr
  · intro act cr1 cr2 trB st t hCr
    exact outcSegFixedProg_shape_indep Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x₁.1 x₂.1 x₁.2 x₂.2 c₁ c₂ act cr1 cr2 hCr trB (v 4101) st t (fun _ => default) v
      (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26)

/-- **Pure `v`-only refusal event `G v`** for `shdP_runFixedProg`. -/
def shdRunRefused {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (v : Fin shdP_zkResPts → Dig) : Prop :=
  ∀ (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins),
    ¬ shdRunActive (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c (shdExtV v)

theorem shdRunRefused_href {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (v : Fin shdP_zkResPts → Dig)
    (hg : shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v) :
    PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c) v = (refused, []) := by
  rw [shdP_runFixedProg_outOf_eq]
  exact shdRunOutOf_of_not_active hdr refused v _ _ _ _ (hg x c)

theorem not_shdRunRefused_active {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (v : Fin shdP_zkResPts → Dig)
    (hng : ¬ shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v) :
    shdRunActive (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c (shdExtV v) := by
  unfold shdRunRefused at hng
  push_neg at hng
  obtain ⟨x₀, c₀, ha₀⟩ := hng
  exact (shdP_runFixedProg_active_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub
    ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x x₀ c c₀ (shdExtV v)).mpr ha₀

end PureRefusal

/-! ## 3. Unopened-Leaf Salt Invariance (`shdP_runFixedProg_setLeaf_outOf`) -/

section SaltInvariance

private theorem eqRec_ah_fst_eq {P₁ P₂ : PcsAHSpec} (hP : P₁ = P₂) (x y : PcsAHCoins GF P₁)
    (h1 : x.1 = y.1) : (hP ▸ x : PcsAHCoins GF P₂).1 = (hP ▸ y : PcsAHCoins GF P₂).1 := by
  subst hP; exact h1

theorem shdEpTable_setLeaf_rows_cols {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ)
    (c : ShdCoins) (id : ShdLeafId) (d : Dig) :
    (shdP_epTable (Hdr := Hdr) tag x (shdEpBase (shdCoinsSetLeaf c id d))).rows
        = (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)).rows
      ∧ (shdP_epTable (Hdr := Hdr) tag x (shdEpBase (shdCoinsSetLeaf c id d))).cols
        = (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)).cols := by
  have hm : (shdEpBase (shdCoinsSetLeaf c id d)).msgs = (shdEpBase c).msgs := by
    funext r col; simp only [shdEpBase, shdCoinsSetLeaf_te_poly]
  have hp : (shdEpBase (shdCoinsSetLeaf c id d)).pads = (shdEpBase c).pads := by
    funext r p; simp only [shdEpBase, shdCoinsSetLeaf_te_poly]
  refine ⟨?_, ?_⟩
  · unfold shdP_epTable epxMsg; dsimp only; rw [hm, hp]
  · funext j; unfold shdP_epTable shdP_cin PlaneCommit.column PlaneCommit.word epTokenCommit epPlaneCommit epxMsg; dsimp only; rw [hm, hp]

theorem shdBndRndOf_setLeaf_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) (k : Fin 27) :
    (shdBndRndOf (shdCoinsSetLeaf c id d) k).bMask = (shdBndRndOf c k).bMask
      ∧ (shdBndRndOf (shdCoinsSetLeaf c id d) k).bProx = (shdBndRndOf c k).bProx
      ∧ (shdBndRndOf (shdCoinsSetLeaf c id d) k).bPads = (shdBndRndOf c k).bPads := by
  have h1 := shdCoinsSetLeaf_bnd_poly c id d k
  refine ⟨?_, ?_, ?_⟩ <;> (simp only [shdBndRndOf, h1]; try rfl)

theorem shdIncRndOf_setLeaf_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) :
    (shdIncRndOf (shdCoinsSetLeaf c id d)).aMask = (shdIncRndOf c).aMask
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).aProx = (shdIncRndOf c).aProx
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).aPads = (shdIncRndOf c).aPads
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).hMask = (shdIncRndOf c).hMask
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).hProx = (shdIncRndOf c).hProx
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).hURaw = (shdIncRndOf c).hURaw
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).hPads = (shdIncRndOf c).hPads
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).bMask = (shdIncRndOf c).bMask
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).bProx = (shdIncRndOf c).bProx
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).bPads = (shdIncRndOf c).bPads
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).mA = (shdIncRndOf c).mA
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).mBRe = (shdIncRndOf c).mBRe
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).mBIm = (shdIncRndOf c).mBIm
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).mURe = (shdIncRndOf c).mURe
      ∧ (shdIncRndOf (shdCoinsSetLeaf c id d)).mUIm = (shdIncRndOf c).mUIm := by
  have hah := shdCoinsSetLeaf_ah_poly c id d ⟨0, by decide⟩
  have hb := shdBndRndOf_setLeaf_poly c id d ⟨0, by decide⟩
  have hl2 := shdCoinsSetLeaf_l2_poly c id d ⟨0, by decide⟩
  have hmA : packSegMA ⟨0, by decide⟩ ((shdCoinsSetLeaf c id d).2 ⟨0, by decide⟩)
      = packSegMA ⟨0, by decide⟩ (c.2 ⟨0, by decide⟩) := by
    funext t j; unfold packSegMA; rw [hl2]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, hb.1, hb.2.1, hb.2.2, hmA, ?_, ?_, ?_, ?_⟩ <;>
    (simp only [shdIncRndOf, hah, hl2]; try rfl)

theorem shdBlkRndOf_setLeaf_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) (k : Fin 26) :
    (shdBlkRndOf (shdCoinsSetLeaf c id d) k).aMask = (shdBlkRndOf c k).aMask
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).aProx = (shdBlkRndOf c k).aProx
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).aPads = (shdBlkRndOf c k).aPads
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).hMask = (shdBlkRndOf c k).hMask
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).hProx = (shdBlkRndOf c k).hProx
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).hURaw = (shdBlkRndOf c k).hURaw
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).hPads = (shdBlkRndOf c k).hPads
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).mA = (shdBlkRndOf c k).mA
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).mBRe = (shdBlkRndOf c k).mBRe
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).mBIm = (shdBlkRndOf c k).mBIm
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).mURe = (shdBlkRndOf c k).mURe
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).mUIm = (shdBlkRndOf c k).mUIm
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).bnd.bMask = (shdBlkRndOf c k).bnd.bMask
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).bnd.bProx = (shdBlkRndOf c k).bnd.bProx
      ∧ (shdBlkRndOf (shdCoinsSetLeaf c id d) k).bnd.bPads = (shdBlkRndOf c k).bnd.bPads := by
  have hah0 := shdCoinsSetLeaf_ah_poly c id d ⟨k.val + 1, by omega⟩
  have hahCast : ∀ hP : shdP_L1Spec.ah ⟨k.val + 1, by omega⟩ = ⟨shdP_blkASpec, shdP_blkHSpec⟩,
      (hP ▸ (shdCoinsSetLeaf c id d).1.2.2 ⟨k.val + 1, by omega⟩ : PcsAHCoins GF ⟨shdP_blkASpec, shdP_blkHSpec⟩).1
        = (hP ▸ c.1.2.2 ⟨k.val + 1, by omega⟩ : PcsAHCoins GF ⟨shdP_blkASpec, shdP_blkHSpec⟩).1 :=
    fun hP => eqRec_ah_fst_eq hP _ _ hah0
  have hl2 := shdCoinsSetLeaf_l2_poly c id d ⟨k.val + 1, by omega⟩
  have hmA : (shdBlkRndOf (shdCoinsSetLeaf c id d) k).mA = (shdBlkRndOf c k).mA := by
    funext t j; unfold shdBlkRndOf packSegMA; dsimp only; rw [hl2]
  have hb := shdBndRndOf_setLeaf_poly c id d ⟨k.val + 1, by omega⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, hmA, ?_, ?_, ?_, ?_, hb.1, hb.2.1, hb.2.2⟩ <;>
    (simp only [shdBlkRndOf, hahCast, hl2]; try rfl)

theorem shdOutcRndOf_setLeaf_poly (c : ShdCoins) (id : ShdLeafId) (d : Dig) :
    (shdOutcRndOf (shdCoinsSetLeaf c id d)).aMask = (shdOutcRndOf c).aMask
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).aProx = (shdOutcRndOf c).aProx
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).aPads = (shdOutcRndOf c).aPads
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).hMask = (shdOutcRndOf c).hMask
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).hProx = (shdOutcRndOf c).hProx
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).hURaw = (shdOutcRndOf c).hURaw
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).hPads = (shdOutcRndOf c).hPads
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).mA = (shdOutcRndOf c).mA
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).mBRe = (shdOutcRndOf c).mBRe
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).mBIm = (shdOutcRndOf c).mBIm
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).mURe = (shdOutcRndOf c).mURe
      ∧ (shdOutcRndOf (shdCoinsSetLeaf c id d)).mUIm = (shdOutcRndOf c).mUIm := by
  have hah := shdCoinsSetLeaf_ah_poly c id d ⟨27, by decide⟩
  have hl2 := shdCoinsSetLeaf_l2_poly c id d ⟨27, by decide⟩
  have hmA : packSegMA ⟨27, by decide⟩ ((shdCoinsSetLeaf c id d).2 ⟨27, by decide⟩)
      = packSegMA ⟨27, by decide⟩ (c.2 ⟨27, by decide⟩) := by
    funext t j; unfold packSegMA; rw [hl2]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, hmA, ?_, ?_, ?_, ?_⟩ <;>
    (simp only [shdOutcRndOf, hah, hl2]; try rfl)

theorem shdP_bndTableAt_setLeaf_rows_cols (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : ShdCoins) (id : ShdLeafId) (d : Dig) (idx : Fin 27) :
    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (shdCoinsSetLeaf c id d)) (shdBlkRndOf (shdCoinsSetLeaf c id d)) x hx idx).rows
        = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx).rows
      ∧ (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (shdCoinsSetLeaf c id d)) (shdBlkRndOf (shdCoinsSetLeaf c id d)) x hx idx).cols
        = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx).cols := by
  rcases idx with ⟨i, hi⟩
  cases i with
  | zero =>
    have h := shdIncRndOf_setLeaf_poly c id d
    have hD : shdP_incTBData Rp x (shdIncRndOf (shdCoinsSetLeaf c id d)) = shdP_incTBData Rp x (shdIncRndOf c) := by
      funext r col; unfold shdP_incTBData; rw [h.2.2.2.2.2.2.2.1, h.2.2.2.2.2.2.2.2.1]
    refine ⟨?_, ?_⟩ <;> simp only [shdP_bndTableAt, shdP_incTB, mkPcsTable, hD, h.2.2.2.2.2.2.2.2.2.1]
  | succ k =>
    have h := shdBlkRndOf_setLeaf_poly c id d ⟨k, by omega⟩
    have hD : shdP_outcBndData (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, hi⟩) (shdBlkRndOf (shdCoinsSetLeaf c id d) ⟨k, by omega⟩).bnd
        = shdP_outcBndData (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, hi⟩) (shdBlkRndOf c ⟨k, by omega⟩).bnd := by
      funext r col; unfold shdP_outcBndData; rw [h.2.2.2.2.2.2.2.2.2.2.2.2.1, h.2.2.2.2.2.2.2.2.2.2.2.2.2.1]
    refine ⟨?_, ?_⟩ <;> simp only [shdP_bndTableAt, shdP_blkBndTable, shdP_outcBndTable, mkPcsTable, hD, h.2.2.2.2.2.2.2.2.2.2.2.2.2.2]

theorem shdP_bndTableAt_salts_eq_shdLeafSalt (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : ShdCoins) (idx : Fin 27) (j : Fin (2 ^ 16)) :
    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx).salts j.val
      = shdLeafSalt c ⟨.bnd idx, j⟩ := by
  rcases idx with ⟨i, hi⟩
  cases i with
  | zero =>
    simp only [shdP_bndTableAt, shdP_incTB, mkPcsTable, shdIncRndOf, shdBndRndOf, shdLeafSalt]
    exact extSalt_lt _ j.isLt
  | succ k =>
    simp only [shdP_bndTableAt, shdP_blkBndTable, shdP_outcBndTable, mkPcsTable, shdBlkRndOf, shdBndRndOf, shdLeafSalt]
    exact extSalt_lt _ j.isLt

/-- `openingAuditFixedProg.res` is identical whenever `T₁, T₂` share `.rows`, `.cols`, and agree on
`.salts` at every opened column index `j ∈ idxOf (2^depth) 256 (sqDigs)`! -/
theorem openingAuditFixedProg_res_eq_of_salts (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : prm.nQ = 256)
    (g : OpenGeom) (T₁ T₂ : Table) (hRows : T₁.rows = T₂.rows) (hCols : T₁.cols = T₂.cols)
    (tree : MerkleLevels depth) (active hdrOk : Bool) (cl : List Exec.Block.ZClaim)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ)
    (hSalts : ∀ j ∈ idxOf (2 ^ depth) 256 ((List.range 64).map (fun k => v (base + nClaims + rows + nGroups + 1 + k))),
      T₁.salts j = T₂.salts j) :
    (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₁ tree active hdrOk cl t).res H v base
      = (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₂ tree active hdrOk cl t).res H v base := by
  unfold openingAuditFixedProg
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _), trAbsorbVecsFixed_res,
      PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res]
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _), trAbsorbVecsFixed_res,
      PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res]
  have hpG : pGroups prm T₁ (cl.map toZClaim) = pGroups prm T₂ (cl.map toZClaim) := by
    unfold pGroups; rw [hRows]
  simp only [PProg.res, hpG, hRows, hCols]
  refine Prod.ext ?_ rfl
  by_cases hcond : ((active && hdrOk && decide ((List.map (fun x => x.2.length) (pGroups prm T₂ (cl.map toZClaim))).sum = nClaims) && decide ((pGroups prm T₂ (cl.map toZClaim)).length = nGroups)) &&
      openingAuditOk ((List.range nClaims).map (fun i => challengeFp2Of (v (base + i))))
        ((List.range rows).map (fun i => challengeFp2Of (v (base + nClaims + i)))) g.rows g.prox) = true
  · simp only [hcond, ↓reduceIte, Option.some.injEq]
    congr 1
    refine List.map_congr_left fun j hj => ?_
    have hj' : j ∈ idxOf (2 ^ depth) 256 ((List.range 64).map (fun k => v (base + nClaims + rows + nGroups + 1 + k))) := by
      rwa [hnn, hnQ] at hj
    rw [hSalts j hj']
  · simp only [hcond, Bool.false_eq_true, ↓reduceIte]

/-- `zkBMaskFixedProg.res` is identical whenever `M₁, M₂` share `.row` and agree on
`.salts` at every opened column index `j ∈ idxOf 4096 256 (sqDigs)`! -/
theorem zkBMaskFixedProg_res_eq_of_salts (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (active : Bool) (M₁ M₂ : MTable) (S : ℕ)
    (hRow : M₁.row = M₂.row)
    (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ)
    (hSalts : ∀ j ∈ idxOf (2 ^ 12) 256 ((List.range 64).map (fun k => v (base + 2 * S + 5 + k))),
      M₁.salts j = M₂.salts j) :
    (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active M₁ S tree fs t).res H v base
      = (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active M₂ S tree fs t).res H v base := by
  have hmCol : ∀ j, mCol S (cosetPt (rootFp 12)) M₁ j = mCol S (cosetPt (rootFp 12)) M₂ j := fun j => by
    unfold mCol; rw [hRow]
  have hmQ : mQ = 256 := rfl
  have hmDom : mDom = 2 ^ 12 := by decide
  unfold zkBMaskFixedProg
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res]
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res]
  have hqPoly : ∀ z, qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M₁ S (fs.map toMF) z
      = qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M₂ S (fs.map toMF) z := fun z => by
    unfold qPoly mA mB pairK; rw [hRow]
  have hpPoly : ∀ rho, pPoly shdP_U M₁ S rho = pPoly shdP_U M₂ S rho := fun rho => by
    unfold pPoly mUp pairK; rw [hRow]
  simp only [PProg.res, hqPoly, hpPoly]
  refine Prod.ext ?_ rfl
  dsimp only
  congr 1
  refine List.map_congr_left fun j hj => ?_
  have hj' : j ∈ idxOf (2 ^ 12) 256 ((List.range 64).map (fun k => v (base + 2 * S + 5 + k))) := by
    have hidx : base + 1 + 1 + (2 * S + 2) + 1 = base + 2 * S + 5 := by omega
    rwa [hmDom, hmQ, hidx] at hj
  rw [hmCol j, hSalts j hj']

/-- Helper: whenever `id.2.val ∉ shdOpenedCols v tid`, every opened column `j ∈ shdOpenedCols v tid`
has `id ≠ ⟨tid, ⟨j, hj⟩⟩`, so `shdLeafSalt (shdCoinsSetLeaf c id d)` equals `shdLeafSalt c` there! -/
private theorem shdLeafSalt_setLeaf_eq_of_not_opened (c : ShdCoins) (id : ShdLeafId) (d : Dig)
    (v : Fin shdP_zkResPts → Dig) (hnot : id.2.val ∉ shdOpenedCols v id.1)
    (tid : ShdTreeId) (j : ℕ) (hj : j ∈ shdOpenedCols v tid) :
    shdLeafSalt (shdCoinsSetLeaf c id d) ⟨tid, ⟨j, shdOpenedCols_lt v tid j hj⟩⟩
      = shdLeafSalt c ⟨tid, ⟨j, shdOpenedCols_lt v tid j hj⟩⟩ := by
  apply shdLeafSalt_setLeaf_ne
  intro heq
  rcases id with ⟨tid', j'⟩
  have ht : tid = tid' := congrArg Sigma.fst heq
  subst ht
  have hv : j = j'.val := by
    have := eq_of_heq (Sigma.mk.inj heq).2
    exact congrArg Fin.val this
  exact hnot (hv ▸ hj)

/-- **`incSegFixedProg.res` is invariant under `shdCoinsSetLeaf c id d`** for any unopened leaf `id`! -/
theorem incSegFixedProg_res_setLeaf_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : shieldS0.Tok → ℕ)
    (c : ShdCoins) (id : ShdLeafId) (d : Dig)
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (t : Tr) (H : QB Lq → Dig)
    (v : Fin shdP_zkResPts → Dig) (hnot : id.2.val ∉ shdOpenedCols v id.1) :
    (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x (shdCoinsSetLeaf c id d) treeTE bnd startTag t).res
        H (shdExtV v) 4104
      = (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t).res
        H (shdExtV v) 4104 := by
  have hp := shdIncRndOf_setLeaf_poly c id d
  have hTE := shdEpTable_setLeaf_rows_cols (Hdr := Hdr) tag x c id d
  set c' := shdCoinsSetLeaf c id d
  have hTA_rc : (shdP_incTA x (shdIncRndOf c')).rows = (shdP_incTA x (shdIncRndOf c)).rows
      ∧ (shdP_incTA x (shdIncRndOf c')).cols = (shdP_incTA x (shdIncRndOf c)).cols := by
    have hD : shdP_incTAData x (shdIncRndOf c') = shdP_incTAData x (shdIncRndOf c) := by
      funext r col; unfold shdP_incTAData; rw [hp.1, hp.2.1]
    refine ⟨?_, ?_⟩ <;> (simp only [shdP_incTA, mkPcsTable, hD, hp.2.2.1]; try rfl)
  have hTB_rc : (shdP_incTB Rp x (shdIncRndOf c')).rows = (shdP_incTB Rp x (shdIncRndOf c)).rows
      ∧ (shdP_incTB Rp x (shdIncRndOf c')).cols = (shdP_incTB Rp x (shdIncRndOf c)).cols := by
    have hD : shdP_incTBData Rp x (shdIncRndOf c') = shdP_incTBData Rp x (shdIncRndOf c) := by
      funext r col; unfold shdP_incTBData; rw [hp.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.1]
    refine ⟨?_, ?_⟩ <;> (simp only [shdP_incTB, mkPcsTable, hD, hp.2.2.2.2.2.2.2.2.2.1]; try rfl)
  have hTH_rc : ∀ ch, (shdP_incTH Rp embDigest x (shdIncRndOf c') ch).rows = (shdP_incTH Rp embDigest x (shdIncRndOf c) ch).rows
      ∧ (shdP_incTH Rp embDigest x (shdIncRndOf c') ch).cols = (shdP_incTH Rp embDigest x (shdIncRndOf c) ch).cols := by
    intro ch
    have hHU : shdP_incHUVal (shdIncRndOf c') = shdP_incHUVal (shdIncRndOf c) := by
      funext col; unfold shdP_incHUVal; rw [hp.2.2.2.2.2.1]
    have hD : shdP_incTHData Rp embDigest x (shdIncRndOf c') ch = shdP_incTHData Rp embDigest x (shdIncRndOf c) ch := by
      funext r col; unfold shdP_incTHData; rw [hHU, hp.2.2.2.1, hp.2.2.2.2.1]
    refine ⟨?_, ?_⟩ <;> (simp only [shdP_incTH, mkPcsTable, hD, hp.2.2.2.2.2.2.1]; try rfl)
  have hSlD : ∀ ch,
      shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c'))
        (shdP_incTH Rp embDigest x (shdIncRndOf c') ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c'))
        (shdP_incTB Rp x (shdIncRndOf c')) (shdIncRndOf c')
      = shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
        (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
        (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c) := by
    intro ch
    have hcs : incCs (shdP_incTA x (shdIncRndOf c')) (shdP_incTH Rp embDigest x (shdIncRndOf c') ch)
          (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c')) (shdP_incTB Rp x (shdIncRndOf c'))
        = incCs (shdP_incTA x (shdIncRndOf c)) (shdP_incTH Rp embDigest x (shdIncRndOf c) ch)
          (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) (shdP_incTB Rp x (shdIncRndOf c)) := by
      funext cm z; cases cm <;> simp [incCs, hTA_rc.1, (hTH_rc ch).1, hTE.1, hTB_rc.1]
    unfold shdP_incSlotData; rw [hcs, hp.2.2.2.2.2.2.2.2.2.2.1]
  have h167 := shdP_inc_slotsFixedLen tag Rp embDigest (embFoldL Rp.inp) bInRow
  have hM : ∀ act trM fs tM' baseM,
      baseM = 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 →
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij act (shdP_incM (shdIncRndOf c')) 4 trM fs tM').res H (shdExtV v) baseM
      = (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij act (shdP_incM (shdIncRndOf c)) 4 trM fs tM').res H (shdExtV v) baseM := by
    intro act trM fs tM' baseM hbM
    refine zkBMaskFixedProg_res_eq_of_salts Lq hL20 key act _ _ 4
      (by
        funext i; unfold shdP_incM mkMTable; dsimp only
        rw [hp.2.2.2.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.2.2.2.2.1,
            hp.2.2.2.2.2.2.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.2.2.2.2.2.2])
      trM fs tM' H (shdExtV v) baseM fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.m ⟨0, by decide⟩) := by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase; dsimp only; simp only [↓reduceIte]
      rw [hbM] at hj
      have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + 2 * 4 + 5
          = 4104 + 205401 - 73 - 149 - 112 - 64 := by norm_num
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 12 := shdOpenedCols_lt v (.m ⟨0, by decide⟩) j hjO
    simp only [shdP_incM, mkMTable, shdIncRndOf]
    change (if h : j < 2 ^ 12 then (c'.2 ⟨0, by decide⟩).2 ⟨j, h⟩ else zeroDig)
      = (if h : j < 2 ^ 12 then (c.2 ⟨0, by decide⟩).2 ⟨j, h⟩ else zeroDig)
    rw [dif_pos hlt, dif_pos hlt]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.m ⟨0, by decide⟩) j hjO
  have hA : ∀ gA trA act hdr cl tA' baseA,
      baseA = 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 3 41 3 gA (shdP_incTA x (shdIncRndOf c')) trA act hdr cl tA').res H (shdExtV v) baseA
      = (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 3 41 3 gA (shdP_incTA x (shdIncRndOf c)) trA act hdr cl tA').res H (shdExtV v) baseA := by
    intro gA trA act hdr cl tA' baseA hbA
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key shdP_stgPrm 14 3 41 3
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gA _ _ hTA_rc.1 hTA_rc.2 trA act hdr cl tA' H (shdExtV v) baseA fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.a ⟨0, by decide⟩) := by
      unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase; dsimp only; simp only [↓reduceIte]
      rw [hbA] at hj
      have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + 3 + 41 + 3 + 1
          = 4104 + 205401 - 73 - 149 - 64 := by norm_num [zkBMaskFixedLen]
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 14 := shdOpenedCols_lt v (.a ⟨0, by decide⟩) j hjO
    change (shdIncRndOf c').aSalts j = (shdIncRndOf c).aSalts j
    rw [(incSalts_eq_shdLeafSalt c').1 ⟨j, hlt⟩, (incSalts_eq_shdLeafSalt c).1 ⟨j, hlt⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.a ⟨0, by decide⟩) j hjO
  have hH : ∀ ch gH trH act hdr cl tH' baseH,
      baseH = 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + openingAuditFixedLen 3 41 3 shdP_stgPrm.nQ →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 4 76 4 gH (shdP_incTH Rp embDigest x (shdIncRndOf c') ch) trH act hdr cl tH').res H (shdExtV v) baseH
      = (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 4 76 4 gH (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) trH act hdr cl tH').res H (shdExtV v) baseH := by
    intro ch gH trH act hdr cl tH' baseH hbH
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key shdP_stgPrm 14 4 76 4
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gH _ _ (hTH_rc ch).1 (hTH_rc ch).2 trH act hdr cl tH' H (shdExtV v) baseH fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.h ⟨0, by decide⟩) := by
      unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase; dsimp only; simp only [↓reduceIte]
      rw [hbH] at hj
      have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + openingAuditFixedLen 3 41 3 shdP_stgPrm.nQ + 4 + 76 + 4 + 1
          = 4104 + 205401 - 73 - 64 := by norm_num [zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm]
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 14 := shdOpenedCols_lt v (.h ⟨0, by decide⟩) j hjO
    change (shdIncRndOf c').hSalts j = (shdIncRndOf c).hSalts j
    rw [(incSalts_eq_shdLeafSalt c').2 ⟨j, hlt⟩, (incSalts_eq_shdLeafSalt c).2 ⟨j, hlt⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.h ⟨0, by decide⟩) j hjO
  have hE : ∀ gE act hdr cl tE' baseE,
      baseE = 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + openingAuditFixedLen 3 41 3 shdP_stgPrm.nQ + openingAuditFixedLen 4 76 4 shdP_stgPrm.nQ →
      (openingAuditFixedProg Lq hL20 key shdP_epPrm 11 1 6 1 gE (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c')) treeTE act hdr cl tE').res H (shdExtV v) baseE
      = (openingAuditFixedProg Lq hL20 key shdP_epPrm 11 1 6 1 gE (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) treeTE act hdr cl tE').res H (shdExtV v) baseE := by
    intro gE act hdr cl tE' baseE hbE
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key shdP_epPrm 11 1 6 1
      (by norm_num [shdP_epPrm, PcsPrm.nn]) rfl gE _ _ hTE.1 hTE.2 treeTE act hdr cl tE' H (shdExtV v) baseE fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v .te := by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase; dsimp only
      rw [hbE] at hj
      have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + openingAuditFixedLen 3 41 3 shdP_stgPrm.nQ + openingAuditFixedLen 4 76 4 shdP_stgPrm.nQ + 1 + 6 + 1 + 1
          = 4104 + 205401 - 64 := by norm_num [zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm]
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 11 := shdOpenedCols_lt v .te j hjO
    simp only [shdP_epTable, shdEpBase, hlt, ↓reduceDIte]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot .te j hjO
  unfold incSegFixedProg
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _) (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 14 41 _ _ _) (merkleTableProg_ptLen Lq _ tag 14 41 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 12 12 _ _ _) (merkleTableProg_ptLen Lq _ tag 12 12 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trChallengeFp2VecKeyed_ptLen Lq _ key 15 _) (trChallengeFp2VecKeyed_ptLen Lq _ key 15 _) (trChallengeFp2VecKeyed_res ..) (trChallengeFp2VecKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _) (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_eq ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _).congr (h167 _))
    ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _).congr (h167 _)) (by rw [hSlD]) fun slR => ?_
  refine res_andThen_eq (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _) (hM _ _ _ _ _ rfl) fun mR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _) (hA _ _ _ _ _ _ _ rfl) fun aR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _) (hH _ _ _ _ _ _ _ _ rfl) fun hR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _) (hE _ _ _ _ _ _ rfl) fun eR => ?_
  rfl

/-- **`blkSegFixedProg.res` is invariant under `shdCoinsSetLeaf c id d`** for any unopened leaf `id`! -/
theorem blkSegFixedProg_res_setLeaf_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : ShdCoins) (id : ShdLeafId) (d : Dig) (k : Fin 26)
    (active : Bool) (cr : Carry) (treeBPrev : MerkleLevels 16) (bnd startTag : Dig) (t : Tr)
    (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig) (hnot : id.2.val ∉ shdOpenedCols v id.1) :
    let base := 209507 + blkStepFixedLen * k.val
    (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx (shdCoinsSetLeaf c id d) k active cr treeBPrev bnd startTag t).res H (shdExtV v) base
      = (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c k active cr treeBPrev bnd startTag t).res H (shdExtV v) base := by
  intro base
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  have hp := shdBlkRndOf_setLeaf_poly c id d k
  have hBP := shdP_bndTableAt_setLeaf_rows_cols Rp hR hweights hinPub x hx c id d ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  have hBN := shdP_bndTableAt_setLeaf_rows_cols Rp hR hweights hinPub x hx c id d ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
  set c' := shdCoinsSetLeaf c id d
  set w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k.val k.isLt
  have hTA_rc : (blkTA w (shdBlkRndOf c' k)).rows = (blkTA w (shdBlkRndOf c k)).rows
      ∧ (blkTA w (shdBlkRndOf c' k)).cols = (blkTA w (shdBlkRndOf c k)).cols := by
    have hD : blkTAData w (shdBlkRndOf c' k) = blkTAData w (shdBlkRndOf c k) := by
      funext r col; unfold blkTAData; rw [hp.1, hp.2.1]
    refine ⟨?_, ?_⟩ <;> (simp only [blkTA, mkPcsTable, hD, hp.2.2.1]; try rfl)
  have hTH_rc : ∀ bga, (blkTH w (shdBlkRndOf c' k) bga).rows = (blkTH w (shdBlkRndOf c k) bga).rows
      ∧ (blkTH w (shdBlkRndOf c' k) bga).cols = (blkTH w (shdBlkRndOf c k) bga).cols := by
    intro bga
    have hHU : blkHUVal (shdBlkRndOf c' k) = blkHUVal (shdBlkRndOf c k) := by
      funext col; unfold blkHUVal; rw [hp.2.2.2.2.2.1]
    have hHV : blkHValK w (shdBlkRndOf c' k) bga = blkHValK w (shdBlkRndOf c k) bga := by
      funext hpl idx; unfold blkHValK; simp only [hHU]
    have hD : blkTHData w (shdBlkRndOf c' k) bga = blkTHData w (shdBlkRndOf c k) bga := by
      funext r col; unfold blkTHData; rw [hHV, hp.2.2.2.1, hp.2.2.2.2.1]
    refine ⟨?_, ?_⟩ <;> (simp only [blkTH, mkPcsTable, hD, hp.2.2.2.2.2.2.1]; try rfl)
  have hSlD : blkSlotData (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) w
        (blkTA w (shdBlkRndOf c' k))
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        (shdBlkRndOf c' k)
      = blkSlotData (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) w
        (blkTA w (shdBlkRndOf c k))
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        (shdBlkRndOf c k) := by
    have hcs : ∀ bga, blkCs (blkTA w (shdBlkRndOf c' k)) (blkTH w (shdBlkRndOf c' k) bga)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        = blkCs (blkTA w (shdBlkRndOf c k)) (blkTH w (shdBlkRndOf c k) bga)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩) := by
      intro bga; funext cm z; cases cm <;> simp [blkCs, hTA_rc.1, (hTH_rc bga).1, hBP.1, hBN.1]
    unfold blkSlotData; simp only [hcs, hp.2.2.2.2.2.2.2.1]
  have h1283 := shdP_blk_slotsFixedLen tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt
  have hs0 : s.val ≠ 0 := by dsimp [s]; omega
  have hs27 : s.val ≠ 27 := by dsimp [s]; omega
  have hM : ∀ act trM fs tM' baseM,
      baseM = base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 →
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij act (blkTM (shdBlkRndOf c' k)) 23 trM fs tM').res H (shdExtV v) baseM
      = (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij act (blkTM (shdBlkRndOf c k)) 23 trM fs tM').res H (shdExtV v) baseM := by
    intro act trM fs tM' baseM hbM
    refine zkBMaskFixedProg_res_eq_of_salts Lq hL20 key act _ _ 23
      (by
        funext i; unfold blkTM mkMTable; dsimp only
        rw [hp.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.2.1,
            hp.2.2.2.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.2.2.2.1])
      trM fs tM' H (shdExtV v) baseM fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.m s) := by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase; dsimp only
      rw [ite_eq_right hs0, ite_eq_right hs27]
      rw [hbM] at hj
      have hidx : base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + 2 * 23 + 5
          = 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 4518 - 4824 - 64 := by
        simp only [base, s, Nat.add_sub_cancel, blkSegFixedLen]; omega
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 12 := shdOpenedCols_lt v (.m s) j hjO
    simp only [blkTM, mkMTable, shdBlkRndOf]
    change (if h : j < 2 ^ 12 then (c'.2 s).2 ⟨j, h⟩ else zeroDig)
      = (if h : j < 2 ^ 12 then (c.2 s).2 ⟨j, h⟩ else zeroDig)
    rw [dif_pos hlt, dif_pos hlt]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.m s) j hjO
  have hA : ∀ gA trA act hdr cl tA' baseA,
      baseA = base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 gA (blkTA w (shdBlkRndOf c' k)) trA act hdr cl tA').res H (shdExtV v) baseA
      = (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 gA (blkTA w (shdBlkRndOf c k)) trA act hdr cl tA').res H (shdExtV v) baseA := by
    intro gA trA act hdr cl tA' baseA hbA
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gA _ _ hTA_rc.1 hTA_rc.2 trA act hdr cl tA' H (shdExtV v) baseA fun j hj => ?_
    have hdA : shdTreeDepthOf (.a s) = 16 := by
      unfold shdTreeDepthOf shdAHDepth; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
    have hjO : j ∈ shdOpenedCols v (.a s) := by
      unfold shdOpenedCols shdTreeSqBase; dsimp only; rw [hdA, ite_eq_right hs0, ite_eq_right hs27]; rw [hbA] at hj
      have hidx : base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + 146 + 4577 + 36 + 1
          = 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 4518 - 64 := by
        simp only [base, s, Nat.add_sub_cancel, blkSegFixedLen, zkBMaskFixedLen, mQ]; omega
      simpa only [hidx] using hj
    have hlt := shdOpenedCols_lt v (.a s) j hjO
    have hlt16 : j < 2 ^ 16 := by rwa [hdA] at hlt
    change (shdBlkRndOf c' k).aSalts j = (shdBlkRndOf c k).aSalts j
    rw [(blkSalts_eq_shdLeafSalt c' k).1 ⟨j, hlt16⟩, (blkSalts_eq_shdLeafSalt c k).1 ⟨j, hlt16⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.a s) j hjO
  have hH : ∀ bga gH trH act hdr cl tH' baseH,
      baseH = base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + openingAuditFixedLen 146 4577 36 Exec.R13.r13Prm.nQ →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 gH (blkTH w (shdBlkRndOf c' k) bga) trH act hdr cl tH').res H (shdExtV v) baseH
      = (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 gH (blkTH w (shdBlkRndOf c k) bga) trH act hdr cl tH').res H (shdExtV v) baseH := by
    intro bga gH trH act hdr cl tH' baseH hbH
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gH _ _ (hTH_rc bga).1 (hTH_rc bga).2 trH act hdr cl tH' H (shdExtV v) baseH fun j hj => ?_
    have hdH : shdTreeDepthOf (.h s) = 16 := by
      unfold shdTreeDepthOf shdAHDepth; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
    have hjO : j ∈ shdOpenedCols v (.h s) := by
      unfold shdOpenedCols shdTreeSqBase; dsimp only; rw [hdH, ite_eq_right hs0, ite_eq_right hs27]; rw [hbH] at hj
      have hidx : base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + openingAuditFixedLen 146 4577 36 Exec.R13.r13Prm.nQ + 54 + 4390 + 9 + 1
          = 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 64 := by
        simp only [base, s, Nat.add_sub_cancel, blkSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, Exec.R13.r13Prm, mQ]; omega
      simpa only [hidx] using hj
    have hlt := shdOpenedCols_lt v (.h s) j hjO
    have hlt16 : j < 2 ^ 16 := by rwa [hdH] at hlt
    change (shdBlkRndOf c' k).hSalts j = (shdBlkRndOf c k).hSalts j
    rw [(blkSalts_eq_shdLeafSalt c' k).2 ⟨j, hlt16⟩, (blkSalts_eq_shdLeafSalt c k).2 ⟨j, hlt16⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.h s) j hjO
  have hB : ∀ gB act hdr cl tB' baseB,
      baseB = base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + openingAuditFixedLen 146 4577 36 Exec.R13.r13Prm.nQ + openingAuditFixedLen 54 4390 9 Exec.R13.r13Prm.nQ →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 gB
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        treeBPrev act hdr cl tB').res H (shdExtV v) baseB
      = (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 gB
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        treeBPrev act hdr cl tB').res H (shdExtV v) baseB := by
    intro gB act hdr cl tB' baseB hbB
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key Exec.R13.r13Prm 16 2 38 2
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gB _ _ hBP.1 hBP.2 treeBPrev act hdr cl tB' H (shdExtV v) baseB fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩) := by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase; dsimp only; rw [ite_eq_left k.isLt]; rw [hbB] at hj
      have hidx : base + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + openingAuditFixedLen 146 4577 36 Exec.R13.r13Prm.nQ + openingAuditFixedLen 54 4390 9 Exec.R13.r13Prm.nQ + 2 + 38 + 2 + 1
          = 209507 + blkStepFixedLen * k.val + blkSegFixedLen - 64 := by
        simp only [base, blkSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, Exec.R13.r13Prm, mQ]; omega
      simpa only [hidx] using hj
    have hlt := shdOpenedCols_lt v (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩) j hjO
    rw [shdP_bndTableAt_salts_eq_shdLeafSalt Rp hR hweights hinPub x hx c' _ ⟨j, hlt⟩,
        shdP_bndTableAt_salts_eq_shdLeafSalt Rp hR hweights hinPub x hx c _ ⟨j, hlt⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩) j hjO
  unfold blkSegFixedProg
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _) (merkleTableProg_ptLen Lq _ tag 16 38 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 16 4577 _ _ _) (merkleTableProg_ptLen Lq _ tag 16 4577 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 12 50 _ _ _) (merkleTableProg_ptLen Lq _ tag 12 50 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_res ..) (trChallengeFp2Keyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_res ..) (trChallengeFp2Keyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_ptLen Lq _ key _) (trChallengeFp2Keyed_res ..) (trChallengeFp2Keyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 16 4390 _ _ _) (merkleTableProg_ptLen Lq _ tag 16 4390 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_eq ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283)
    ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283) (by rw [hSlD]) fun slR => ?_
  refine res_andThen_eq (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _) (hM _ _ _ _ _ rfl) fun mR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _) (hA _ _ _ _ _ _ _ rfl) fun aR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _) (hH _ _ _ _ _ _ _ _ rfl) fun hR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _) (hB _ _ _ _ _ _ rfl) fun bR => ?_
  rfl

theorem blkChainFixedProg_res_setLeaf_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : ShdCoins) (id : ShdLeafId) (d : Dig) (H : QB Lq → Dig)
    (v : Fin shdP_zkResPts → Dig) (hnot : id.2.val ∉ shdOpenedCols v id.1) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
      (active : Bool) (cr : Carry) (treeB : MerkleLevels 16) (bnd startTag : Dig) (t : Tr),
      (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx (shdCoinsSetLeaf c id d) startIdx count hEnd active cr treeB bnd startTag t).res
        H (shdExtV v) (209507 + blkStepFixedLen * startIdx)
      = (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c startIdx count hEnd active cr treeB bnd startTag t).res
        H (shdExtV v) (209507 + blkStepFixedLen * startIdx)
  | _, 0, _, _, _, _, _, _, _ => rfl
  | startIdx, count + 1, hEnd, active, cr, treeB, bnd, startTag, t => by
    unfold blkChainFixedProg
    refine res_andThen_eq
      (blkSegFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx _ _ active cr treeB bnd startTag t)
      (blkSegFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx _ _ active cr treeB bnd startTag t)
      (blkSegFixedProg_res_setLeaf_eq (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c id d ⟨startIdx, by omega⟩ active cr treeB bnd startTag t H v hnot)
      fun bR => ?_
    refine res_andThen_same (B := Eq) (posTagKeyed_ptLen Lq _ key _) (posTagKeyed_ptLen Lq _ key _)
      (posTagKeyed_res ..) (posTagKeyed_res ..) ?_
    have hidx : 209507 + blkStepFixedLen * startIdx + blkSegFixedLen + 2 = 209507 + blkStepFixedLen * (startIdx + 1) := by
      unfold blkStepFixedLen; ring
    refine res_andThen_eq
      (blkChainFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx _ (startIdx + 1) count (by omega) _ _ _ bnd _ _)
      (blkChainFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx _ (startIdx + 1) count (by omega) _ _ _ bnd _ _)
      (by
        rw [hidx]
        exact blkChainFixedProg_res_setLeaf_eq (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x hx c id d H v hnot (startIdx + 1) count (by omega) _ _ _ bnd _ _)
      fun _ => rfl

/-- **`outcSegFixedProg.res` is invariant under `shdCoinsSetLeaf c id d`** for any unopened leaf `id`! -/
theorem outcSegFixedProg_res_setLeaf_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : ShdCoins) (id : ShdLeafId) (d : Dig)
    (active : Bool) (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr)
    (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig) (hnot : id.2.val ∉ shdOpenedCols v id.1) :
    let base := 209507 + blkStepFixedLen * 26
    (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx (shdCoinsSetLeaf c id d) active cr treeB26 bnd startTag t).res H (shdExtV v) base
      = (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x hx c active cr treeB26 bnd startTag t).res H (shdExtV v) base := by
  intro base
  let s : Fin 28 := ⟨27, by decide⟩
  have hp := shdOutcRndOf_setLeaf_poly c id d
  have hB26 := shdP_bndTableAt_setLeaf_rows_cols Rp hR hweights hinPub x hx c id d ⟨26, by omega⟩
  set c' := shdCoinsSetLeaf c id d
  set w := outcWitness_of_adm Rp houtPub x hx
  have hTA_rc : (shdP_outcTA Rp w (shdOutcRndOf c')).rows = (shdP_outcTA Rp w (shdOutcRndOf c)).rows
      ∧ (shdP_outcTA Rp w (shdOutcRndOf c')).cols = (shdP_outcTA Rp w (shdOutcRndOf c)).cols := by
    have hD : shdP_outcTAData Rp w (shdOutcRndOf c') = shdP_outcTAData Rp w (shdOutcRndOf c) := by
      funext r col; unfold shdP_outcTAData; rw [hp.1, hp.2.1]
    refine ⟨?_, ?_⟩ <;> (simp only [shdP_outcTA, mkPcsTable, hD, hp.2.2.1]; try rfl)
  have hTH_rc : ∀ g a, (shdP_outcTH Rp w (shdOutcRndOf c') g a).rows = (shdP_outcTH Rp w (shdOutcRndOf c) g a).rows
      ∧ (shdP_outcTH Rp w (shdOutcRndOf c') g a).cols = (shdP_outcTH Rp w (shdOutcRndOf c) g a).cols := by
    intro g a
    have hHU : shdP_outcHUVal (shdOutcRndOf c') = shdP_outcHUVal (shdOutcRndOf c) := by
      funext col; unfold shdP_outcHUVal; rw [hp.2.2.2.2.2.1]
    have hD : shdP_outcTHData Rp w (shdOutcRndOf c') g a = shdP_outcTHData Rp w (shdOutcRndOf c) g a := by
      funext r col; unfold shdP_outcTHData; rw [hHU, hp.2.2.2.1, hp.2.2.2.2.1]
    refine ⟨?_, ?_⟩ <;> (simp only [shdP_outcTH, mkPcsTable, hD, hp.2.2.2.2.2.2.1]; try rfl)
  have hSlD : shdP_outcSlotData tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0) w
        (shdP_outcTA Rp w (shdOutcRndOf c'))
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨26, by omega⟩)
        (shdOutcRndOf c')
      = shdP_outcSlotData tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0) w
        (shdP_outcTA Rp w (shdOutcRndOf c))
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩)
        (shdOutcRndOf c) := by
    have hcs : ∀ g a, outcCs (shdP_outcTA Rp w (shdOutcRndOf c')) (shdP_outcTH Rp w (shdOutcRndOf c') g a)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨26, by omega⟩)
        = outcCs (shdP_outcTA Rp w (shdOutcRndOf c)) (shdP_outcTH Rp w (shdOutcRndOf c) g a)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩) := by
      intro g a; funext cm z; cases cm <;> simp only [outcCs, hTA_rc.1, (hTH_rc g a).1, hB26.1]
    unfold shdP_outcSlotData; simp only [hcs, hp.2.2.2.2.2.2.2.1]
  have h290 := shdP_outc_slotsFixedLen tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
  have hM : ∀ act trM fs tM' baseM,
      baseM = base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 →
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij act (shdP_outcM (shdOutcRndOf c')) 8 trM fs tM').res H (shdExtV v) baseM
      = (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij act (shdP_outcM (shdOutcRndOf c)) 8 trM fs tM').res H (shdExtV v) baseM := by
    intro act trM fs tM' baseM hbM
    refine zkBMaskFixedProg_res_eq_of_salts Lq hL20 key act _ _ 8
      (by
        funext i; unfold shdP_outcM mkMTable; dsimp only
        rw [hp.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.2.1,
            hp.2.2.2.2.2.2.2.2.2.2.1, hp.2.2.2.2.2.2.2.2.2.2.2])
      trM fs tM' H (shdExtV v) baseM fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.m s) := by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase; dsimp only [s]
      simp only [Nat.reduceEqDiff, ↓reduceIte]; rw [hbM] at hj
      have hidx : base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + 2 * 8 + 5
          = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 118 - 186 - 64 := by
        simp only [base, outcSegFixedLen]; omega
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 12 := shdOpenedCols_lt v (.m s) j hjO
    simp only [shdP_outcM, mkMTable, shdOutcRndOf]
    change (if h : j < 2 ^ 12 then (c'.2 s).2 ⟨j, h⟩ else zeroDig)
      = (if h : j < 2 ^ 12 then (c.2 s).2 ⟨j, h⟩ else zeroDig)
    rw [dif_pos hlt, dif_pos hlt]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.m s) j hjO
  have hA : ∀ gA trA act hdr cl tA' baseA,
      baseA = base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA (shdP_outcTA Rp w (shdOutcRndOf c')) trA act hdr cl tA').res H (shdExtV v) baseA
      = (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA (shdP_outcTA Rp w (shdOutcRndOf c)) trA act hdr cl tA').res H (shdExtV v) baseA := by
    intro gA trA act hdr cl tA' baseA hbA
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key shdP_stgPrm 14 29 76 16
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gA _ _ hTA_rc.1 hTA_rc.2 trA act hdr cl tA' H (shdExtV v) baseA fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.a s) := by
      unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase; dsimp only [s]
      simp only [Nat.reduceEqDiff, ↓reduceIte]; rw [hbA] at hj
      have hidx : base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + 29 + 76 + 16 + 1
          = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 118 - 64 := by
        simp only [base, outcSegFixedLen, zkBMaskFixedLen, mQ]; omega
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 14 := shdOpenedCols_lt v (.a s) j hjO
    change (shdOutcRndOf c').aSalts j = (shdOutcRndOf c).aSalts j
    rw [(outcSalts_eq_shdLeafSalt c').1 ⟨j, hlt⟩, (outcSalts_eq_shdLeafSalt c).1 ⟨j, hlt⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.a s) j hjO
  have hH : ∀ g a gH trH act hdr cl tH' baseH,
      baseH = base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + openingAuditFixedLen 29 76 16 shdP_stgPrm.nQ →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH (shdP_outcTH Rp w (shdOutcRndOf c') g a) trH act hdr cl tH').res H (shdExtV v) baseH
      = (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH (shdP_outcTH Rp w (shdOutcRndOf c) g a) trH act hdr cl tH').res H (shdExtV v) baseH := by
    intro g a gH trH act hdr cl tH' baseH hbH
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key shdP_stgPrm 14 10 38 5
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gH _ _ (hTH_rc g a).1 (hTH_rc g a).2 trH act hdr cl tH' H (shdExtV v) baseH fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.h s) := by
      unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase; dsimp only [s]
      simp only [Nat.reduceEqDiff, ↓reduceIte]; rw [hbH] at hj
      have hidx : base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + openingAuditFixedLen 29 76 16 shdP_stgPrm.nQ + 10 + 38 + 5 + 1
          = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 64 := by
        simp only [base, outcSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm, mQ]; omega
      simpa only [hidx] using hj
    have hlt : j < 2 ^ 14 := shdOpenedCols_lt v (.h s) j hjO
    change (shdOutcRndOf c').hSalts j = (shdOutcRndOf c).hSalts j
    rw [(outcSalts_eq_shdLeafSalt c').2 ⟨j, hlt⟩, (outcSalts_eq_shdLeafSalt c).2 ⟨j, hlt⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.h s) j hjO
  have hB : ∀ gB act hdr cl tB' baseB,
      baseB = base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + openingAuditFixedLen 29 76 16 shdP_stgPrm.nQ + openingAuditFixedLen 10 38 5 shdP_stgPrm.nQ →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 gB
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c') (shdBlkRndOf c') x hx ⟨26, by omega⟩)
        treeB26 act hdr cl tB').res H (shdExtV v) baseB
      = (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 gB
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩)
        treeB26 act hdr cl tB').res H (shdExtV v) baseB := by
    intro gB act hdr cl tB' baseB hbB
    refine openingAuditFixedProg_res_eq_of_salts Lq hL20 key Exec.R13.r13Prm 16 2 38 2
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gB _ _ hB26.1 hB26.2 treeB26 act hdr cl tB' H (shdExtV v) baseB fun j hj => ?_
    have hjO : j ∈ shdOpenedCols v (.bnd ⟨26, by omega⟩) := by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase; dsimp only; rw [ite_eq_right (by omega)]; rw [hbB] at hj
      have hidx : base + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + openingAuditFixedLen 29 76 16 shdP_stgPrm.nQ + openingAuditFixedLen 10 38 5 shdP_stgPrm.nQ + 2 + 38 + 2 + 1
          = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 64 := by
        simp only [base, outcSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm, Exec.R13.r13Prm, mQ]; omega
      simpa only [hidx] using hj
    have hlt := shdOpenedCols_lt v (.bnd ⟨26, by omega⟩) j hjO
    rw [shdP_bndTableAt_salts_eq_shdLeafSalt Rp hR hweights hinPub x hx c' _ ⟨j, hlt⟩,
        shdP_bndTableAt_salts_eq_shdLeafSalt Rp hR hweights hinPub x hx c _ ⟨j, hlt⟩]
    exact shdLeafSalt_setLeaf_eq_of_not_opened c id d v hnot (.bnd ⟨26, by omega⟩) j hjO
  unfold outcSegFixedProg
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _) (merkleTableProg_ptLen Lq _ tag 14 76 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 12 20 _ _ _) (merkleTableProg_ptLen Lq _ tag 12 20 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) (trAbsorbKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (trChallengeFp2VecKeyed_ptLen Lq _ key 2 _) (trChallengeFp2VecKeyed_ptLen Lq _ key 2 _) (trChallengeFp2VecKeyed_res ..) (trChallengeFp2VecKeyed_res ..) ?_
  refine res_andThen_same (B := Eq) (merkleTableProg_ptLen Lq _ tag 14 38 _ _ _) (merkleTableProg_ptLen Lq _ tag 14 38 _ _ _) (merkleTableProg_res ..) (merkleTableProg_res ..) ?_
  refine res_andThen_same (B := Eq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) (absorbRootKeyed_res ..) ?_
  refine res_andThen_eq ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _).congr h290)
    ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _).congr h290) (by rw [hSlD]) fun slR => ?_
  refine res_andThen_eq (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _) (hM _ _ _ _ _ rfl) fun mR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _) (hA _ _ _ _ _ _ _ rfl) fun aR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _) (hH _ _ _ _ _ _ _ _ _ rfl) fun hR => ?_
  refine res_andThen_eq (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _) (hB _ _ _ _ _ _ rfl) fun bR => ?_
  rfl

/-- **Whole-run unopened-leaf salt invariance (`hhid_inv`)**: overwriting ANY unopened leaf salt
`id` (`id.2.val ∉ shdOpenedCols v id.1`) across all 112 Merkle trees leaves `PProg.outOf` unchanged! -/
theorem shdP_runFixedProg_setLeaf_outOf {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (id : ShdLeafId) (d : Dig)
    (v : Fin shdP_zkResPts → Dig) (hnot : id.2.val ∉ shdOpenedCols v id.1) :
    PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x (shdCoinsSetLeaf c id d)) v
    = PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c) v := by
  rw [shdP_runFixedProg_outOf_eq, shdP_runFixedProg_outOf_eq]
  have hB0 : 4104 + incSegFixedLen + 2 = 209507 + blkStepFixedLen * 0 := by unfold incSegFixedLen; norm_num
  have hB26 : 4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 = 209507 + blkStepFixedLen * 26 := by
    unfold incSegFixedLen; omega
  refine shdRunOutOf_congr hdr refused v _ ?_ ?_ ?_
  · exact incSegFixedProg_res_setLeaf_eq (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c id d
      (levelsOfV (shdExtV v) 11 0) (shdExtV v 4101) (posTagOfV (shdExtV v) 4102) ⟨shdExtV v 4101, 0, key⟩
      (fun _ => default) v hnot
  · intro act cr trB t
    rw [hB0]
    exact blkChainFixedProg_res_setLeaf_eq (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub
      ioIn ioOut blkDig x.1 x.2 c id d (fun _ => default) v hnot 0 26 (by omega) act cr trB
      (shdExtV v 4101) (posTagOfV (shdExtV v) (4104 + incSegFixedLen)) t
  · intro act cr trB st t
    rw [hB26]
    exact outcSegFixedProg_res_setLeaf_eq Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x.1 x.2 c id d act cr trB (shdExtV v 4101) st t (fun _ => default) v hnot

end SaltInvariance

end ZK60.HonestShield
