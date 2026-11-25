/-
D63 lane L69, Milestone A Part 2a (`HonestShieldZKFixedLib.lean`):
generic fixed-schedule `PProg` point-accounting, `2^-256` transcript/dep-set freshness, and
single-theorem `ShdZKCountWitness` builder (`shdZKCountWitness_of_schedule`) discharging ALL
16 counting, freshness, collision, dep-hit, and conditional hidden-leaf fields of
`HonestShieldZK.ShdZKCountWitness` from a static schedule descriptor `ShdPtSpec`!

What this file defines and proves (only standard Lean foundations; zero `sorry`):
1. **`qLastDig` & `qLastDig_abLabExp`**: extracts the trailing 32-byte `inRoot` digest out of
   `absorbMsg d₁ abLabExp (abExpMsg inDig inRoot)` (index `4095`, right after `TE`'s 4095-query
   Merkle tree sets `inRoot = v 4094`).
2. **`exposed_card_dig` & `absorb_hit_depSet_card`**:
   - `2^-256` hit bound for any point exposing a single uniform `v`-coordinate (`hfreshT`),
   - `2^-256` dep-set hit bound for ANY `trAbsorbProg` query `(key, absorbMsg (v m) label data)`
     with `label ≠ abLabShape` (`label.length < 2^64`), regardless of `data.length` (in particular
     covering arbitrary-length `abLabPar` and `abLabChk`).
3. **Static point schedule (`ShdTrKind`, `ShdPtSpec`, `ShdScheduleMatch`) & master builder
   `shdZKCountWitness_of_schedule`**:
   uniformly discharges `kOf`, `hkind`, `hcntT`, `hcntL`, `hcntN`, `hcntD`, `hfreshT`, `hfreshL`,
   `hfreshN`, `hpairs`, `hdeps`, `hleaf_hid`, `hhid_card`, and `hcond_hid` of `ShdZKCountWitness`.
4. **Fixed-length `PProg` combinators (`trAbsorbProgF`, `scProveFixedProg`, `tokenEpAuditProveProg`)**:
   exact `PtLen`, `QLE`, `DepStrict`, `KCount`, and `.run` / `.ptAt` / `.res` theorems ready for
   full 28-segment assembly in `HonestShieldZKFixedProg.lean`.
-/
import ZK60Formal.HonestShieldZKSaltSplit

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.ZKHonest ZK60.ProtocolClassify ZK60.HonestClassify
open ZK60.RunShape (ClassifyRunPublicP classifyModelP)
open ZK60.ProtocolClassify.RunShapeP (classifyProtocolP)

/-! ## 1. Trailing-digest extractor (`qLastDig`) and single-coordinate freshness / dep-set hit bounds -/

section FreshnessAndDepHit

/-- Extract the trailing 32 bytes of a query message as a `Dig` (returns `zeroDig` if shorter than 32 bytes). -/
def qLastDig {Lq : ℕ} (z : QB Lq) : Dig :=
  if h : 32 ≤ z.2.1.length then
    ⟨z.2.1.drop (z.2.1.length - 32), by rw [List.length_drop]; omega⟩
  else zeroDig

private theorem drop_append_suffix {α : Type} (l₁ l₂ : List α) :
    (l₁ ++ l₂).drop ((l₁ ++ l₂).length - l₂.length) = l₂ := by
  rw [List.length_append, Nat.add_sub_cancel]
  exact List.drop_left' rfl

/-- `qLastDig` recovers `inRoot` directly from `shdP_hdrPProg`'s `"expected-IO"` absorb (`abLabExp`). -/
theorem qLastDig_abLabExp {Lq : ℕ} (key : Option Dig) (d₁ inDig inRoot : Dig)
    (ha : (absorbMsg d₁ abLabExp (abExpMsg inDig inRoot)).length ≤ Lq) :
    qLastDig (key, ⟨absorbMsg d₁ abLabExp (abExpMsg inDig inRoot), ha⟩) = inRoot := by
  have hlen_r : inRoot.toList.length = 32 := List.Vector.toList_length inRoot
  have hsplit : absorbMsg d₁ abLabExp (abExpMsg inDig inRoot)
      = (d₁.toList ++ le64 (UInt64.ofNat abLabExp.length) ++ abLabExp
          ++ le64 (UInt64.ofNat (abExpMsg inDig inRoot).length) ++ abExpTag ++ inDig.toList) ++ inRoot.toList := by
    simp only [absorbMsg, abExpMsg, List.append_assoc]
  have h32 : 32 ≤ (absorbMsg d₁ abLabExp (abExpMsg inDig inRoot)).length := by
    rw [hsplit, List.length_append, hlen_r]; omega
  simp only [qLastDig, h32, ↓reduceDIte]
  apply Subtype.ext
  change (absorbMsg d₁ abLabExp (abExpMsg inDig inRoot)).drop
      ((absorbMsg d₁ abLabExp (abExpMsg inDig inRoot)).length - 32) = inRoot.toList
  rw [hsplit]
  simpa [hlen_r] using drop_append_suffix
    (d₁.toList ++ le64 (UInt64.ofNat abLabExp.length) ++ abLabExp
      ++ le64 (UInt64.ofNat (abExpMsg inDig inRoot).length) ++ abExpTag ++ inDig.toList)
    inRoot.toList

/-- **Single-coordinate `2^-256` freshness (`exposed_card_dig`)**: any point exposing `v m` via `g`
equals a fixed query `z` for at most `|C × Dig^k| / 2^256` pairs. -/
theorem exposed_card_dig {C Q : Type} [Fintype C] [DecidableEq Q] {k : ℕ}
    (P : C × (Fin k → Dig) → Q) (m : Fin k) (g : Q → Dig)
    (hg : ∀ s, g (P s) = s.2 m) (z : Q) :
    2 ^ 256 * (univ.filter (fun s : C × (Fin k → Dig) => P s = z)).card
      ≤ Fintype.card (C × (Fin k → Dig)) := by
  let f : Dig × {s : C × (Fin k → Dig) // P s = z} → C × (Fin k → Dig) :=
    fun p => (p.2.1.1, Function.update p.2.1.2 m p.1)
  have hf : Function.Injective f := by
    intro p p' heq
    have hc : p.2.1.1 = p'.2.1.1 := (Prod.mk.inj heq).1
    have hu : Function.update p.2.1.2 m p.1 = Function.update p'.2.1.2 m p'.1 := (Prod.mk.inj heq).2
    have hd : p.1 = p'.1 := by
      have h := congrFun hu m; rwa [Function.update_self, Function.update_self] at h
    have hm1 : p.2.1.2 m = g z := by rw [← hg p.2.1, p.2.2]
    have hm2 : p'.2.1.2 m = g z := by rw [← hg p'.2.1, p'.2.2]
    have hv : p.2.1.2 = p'.2.1.2 := by
      funext r
      by_cases hr : r = m
      · rw [hr, hm1, hm2]
      · have h := congrFun hu r; rwa [Function.update_of_ne hr, Function.update_of_ne hr] at h
    exact Prod.ext hd (Subtype.ext (Prod.ext hc hv))
  have hle := Fintype.card_le_of_injective f hf
  rw [Fintype.card_prod, card_dig_eq, Fintype.card_subtype] at hle
  simpa [Finset.filter_congr_decidable] using hle

open Classical in
/-- **`2^-256` dep-set hit bound for ANY `absorbMsg (v m) label data` with `label ≠ abLabShape`**:
discharges `hdeps` for every transcript absorb (including arbitrary-length `abLabPar` and `abLabChk`)
regardless of `data.length`. -/
theorem absorb_hit_depSet_card {C : Type} [Fintype C] {Lq k : ℕ}
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (domain shape : List UInt8)
    (P : C × (Fin k → Dig) → QB Lq) (m : Fin k)
    (habs : ∀ s, ∃ (label data : List UInt8) (ha : (absorbMsg (s.2 m) label data).length ≤ Lq),
      label ≠ abLabShape ∧ label.length < 2 ^ 64 ∧ P s = (key, ⟨absorbMsg (s.2 m) label data, ha⟩)) :
    2 ^ 256 * (univ.filter (fun s : C × (Fin k → Dig) =>
        P s ∈ ShdRunDepSet Lq tag key domain shape)).card
      ≤ Fintype.card (C × (Fin k → Dig)) := by
  by_cases hdom : (startMsg domain).length ≤ Lq
  · let z₀ : QB Lq := (key, ⟨startMsg domain, hdom⟩)
    have hsub : univ.filter (fun s : C × (Fin k → Dig) => P s ∈ ShdRunDepSet Lq tag key domain shape)
        ⊆ univ.filter (fun s : C × (Fin k → Dig) => P s = z₀) := by
      intro s hs
      have hmem := (mem_filter.mp hs).2
      obtain ⟨label, data, ha, hne, hlt, hPs⟩ := habs s
      rw [hPs] at hmem
      rcases hmem with ⟨_, hst⟩ | ⟨_, d, hab⟩ | ⟨hc, _⟩
      · refine mem_filter.mpr ⟨mem_univ _, ?_⟩
        rw [hPs]
        exact Prod.ext rfl (Subtype.ext hst)
      · have hshape_lt : abLabShape.length < 2 ^ 64 := by decide
        exact absurd (absorbMsg_injective_parts hlt hshape_lt hab).2.1 hne
      · exact absurd hc.symm hsep.col_ne_key
    have hle := Nat.mul_le_mul_left (2 ^ 256) (Finset.card_le_card hsub)
    refine hle.trans (exposed_card_dig P m qHeadDig (fun s => ?_) z₀)
    obtain ⟨label, data, ha, _, _, hPs⟩ := habs s
    rw [hPs]
    exact qHeadDig_absorb key (s.2 m) label data ha
  · have hemp : univ.filter (fun s : C × (Fin k → Dig) => P s ∈ ShdRunDepSet Lq tag key domain shape) = ∅ := by
      refine Finset.filter_eq_empty_iff.mpr fun s _ hmem => ?_
      obtain ⟨label, data, ha, hne, hlt, hPs⟩ := habs s
      rw [hPs] at hmem
      rcases hmem with ⟨_, hst⟩ | ⟨_, d, hab⟩ | ⟨hc, _⟩
      · exact hdom (by rw [← hst]; exact ha)
      · have hshape_lt : abLabShape.length < 2 ^ 64 := by decide
        exact hne (absorbMsg_injective_parts hlt hshape_lt hab).2.1
      · exact hsep.col_ne_key hc.symm
    rw [hemp, Finset.card_empty, Nat.mul_zero]
    exact Nat.zero_le _

end FreshnessAndDepHit

/-! ## 2. Static point schedule (`ShdPtSpec`) & single-theorem `ShdZKCountWitness` builder -/

section ScheduleBuilder

/-- Sub-kind of a `.tr` point for deterministic collision separation (`47`-byte squeeze vs `≥ 48`-byte
absorb vs `49`-byte `shdP_zkPad`). -/
inductive ShdTrKind where
  | absorb
  | squeeze
  | pad
  deriving DecidableEq

/-- Static per-index specification for a fixed-schedule Shieldstral `PProg` at `k = shdP_zkResPts`. -/
inductive ShdPtSpec (Lq : ℕ) where
  | leaf (id : ShdLeafId)
  | node (L R : Fin shdP_zkResPts) (hLR : L ≠ R)
  | tr (tk : ShdTrKind) (m : Fin shdP_zkResPts) (ext : QB Lq → Dig)

/-- `ShdQKind` of a static schedule entry (never `.dep`). -/
def ShdPtSpec.kind {Lq : ℕ} : ShdPtSpec Lq → ShdQKind
  | .leaf _ => .leaf
  | .node _ _ _ => .node
  | .tr _ _ _ => .tr

theorem ShdPtSpec.kind_ne_dep {Lq : ℕ} (e : ShdPtSpec Lq) : e.kind ≠ .dep := by
  cases e <;> simp [ShdPtSpec.kind]

/-- Pointwise behavioral contract linking `ptsOf` at `(x, H)` to a static schedule `sched`. -/
structure ShdScheduleMatch {X Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (prog : X → ShdCoins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (sched : Fin shdP_zkResPts → ShdPtSpec Lq) : Prop where
  hcntT : (univ.filter (fun i => (sched i).kind = .tr)).card ≤ shdP_zkResT
  hcntL : (univ.filter (fun i => (sched i).kind = .leaf)).card ≤ shdP_zkLeaves
  hcntN : (univ.filter (fun i => (sched i).kind = .node)).card ≤ shdP_zkNodes
  hleaf_inj : ∀ i j id₁ id₂, sched i = .leaf id₁ → sched j = .leaf id₂ → i ≠ j → id₁ ≠ id₂
  hnode_inj : ∀ i j L₁ R₁ h₁ L₂ R₂ h₂,
    sched i = .node L₁ R₁ h₁ → sched j = .node L₂ R₂ h₂ → i ≠ j → L₁ ≠ L₂
  htr_order : ∀ (i j : Fin shdP_zkResPts) tk₁ m₁ ext₁ tk₂ m₂ ext₂,
    i.val < j.val → sched i = .tr tk₁ m₁ ext₁ → sched j = .tr tk₂ m₂ ext₂ →
    tk₂ = .pad ∨ i.val ≤ m₂.val ∨ (tk₁ = .squeeze ∧ tk₂ = .absorb)
  hleaf_pt : ∀ x H (s : ShdCoins × (Fin shdP_zkResPts → Dig)) i id,
    sched i = .leaf id →
    ∃ (cd : Dig) (hl : (cd.toList ++ (shdLeafSalt s.1 id).toList).length ≤ Lq),
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
        = (tag.leaf, ⟨cd.toList ++ (shdLeafSalt s.1 id).toList, hl⟩)
  hnode_pt : ∀ x H (s : ShdCoins × (Fin shdP_zkResPts → Dig)) i L R hLR,
    sched i = .node L R hLR →
    ∃ (hn : ((s.2 L).toList ++ (s.2 R).toList).length ≤ Lq),
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
        = (tag.node, ⟨(s.2 L).toList ++ (s.2 R).toList, hn⟩)
  hsqueeze_pt : ∀ x H (s : ShdCoins × (Fin shdP_zkResPts → Dig)) i m ext,
    sched i = .tr .squeeze m ext →
    ∃ (ctr : UInt64) (hs : (squeezeMsg (s.2 m) ctr).length ≤ Lq),
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = (key, ⟨squeezeMsg (s.2 m) ctr, hs⟩)
        ∧ ext (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) = s.2 m
  habsorb_pt : ∀ x H i m ext,
    sched i = .tr .absorb m ext →
    (∀ (s : ShdCoins × (Fin shdP_zkResPts → Dig)),
      ∃ (st : Dig) (label data : List UInt8) (ha : (absorbMsg st label data).length ≤ Lq),
        label ≠ abLabShape ∧ label.length < 2 ^ 64
        ∧ PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = (key, ⟨absorbMsg st label data, ha⟩)
        ∧ ext (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) = s.2 m)
    ∧ ((∀ (s : ShdCoins × (Fin shdP_zkResPts → Dig)),
          ∃ (label data : List UInt8) (ha : (absorbMsg (s.2 m) label data).length ≤ Lq),
          label ≠ abLabShape ∧ label.length < 2 ^ 64
          ∧ PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = (key, ⟨absorbMsg (s.2 m) label data, ha⟩))
        ∨ (∀ (s : ShdCoins × (Fin shdP_zkResPts → Dig)),
            PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
              ∉ ShdRunDepSet Lq tag key domain shape))
  hpad_pt : ∀ x H (s : ShdCoins × (Fin shdP_zkResPts → Dig)) i m ext,
    sched i = .tr .pad m ext →
    PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = shdP_zkPad Lq hL20 i.val (s.2 m)
      ∧ ext (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) = s.2 m

private theorem squeeze_ne_absorb_qb {Lq : ℕ} (k₁ k₂ : Option Dig) (st₁ st₂ : Dig)
    (ctr : UInt64) (label data : List UInt8)
    (hs : (squeezeMsg st₁ ctr).length ≤ Lq) (ha : (absorbMsg st₂ label data).length ≤ Lq) :
    ((k₁, ⟨squeezeMsg st₁ ctr, hs⟩) : QB Lq) ≠ (k₂, ⟨absorbMsg st₂ label data, ha⟩) := by
  intro h
  have hlen : (squeezeMsg st₁ ctr).length = (absorbMsg st₂ label data).length :=
    congrArg (fun q : QB Lq => q.2.1.length) h
  rw [squeezeMsg_length] at hlen
  have habs_len : (absorbMsg st₂ label data).length = 48 + label.length + data.length := by
    simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length]; omega
  omega

open Classical in
/-- **Master `ShdZKCountWitness` builder (`shdZKCountWitness_of_schedule`)**:
discharges ALL 16 counting, freshness, pairwise-collision, dep-hit, and hidden-leaf obligations of
`ShdZKCountWitness` directly from `ShdScheduleMatch`, `KeySep`, and unopened-leaf output invariance! -/
noncomputable def shdZKCountWitness_of_schedule {S : ZK60.Block.BlockShape} {Hdr Salt : Type}
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (domain shape : List UInt8)
    (hsep : KeySep tag key) (hdom35 : domain.length ≠ 35) (hdom37 : domain.length ≠ 37)
    (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) ShdCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : ShdCoins → Salt)
    (prog : {x // (classifyModelP R).admissible x} → ShdCoins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hprog : ∀ H (x : {x // (classifyModelP R).admissible x}) c,
      (prog x c).run H = (classifyProtocolP R Lq V P Cin h64 hr base).prove H () x.1 c)
    (hk : ∀ x c, (prog x c).PtLE shdP_zkPts)
    (habs : ∀ x c, DepAbsorbed (prog x c))
    (hq : ∀ x c, (prog x c).QLE shdP_zkQueries)
    (hdep : ∀ x c, (prog x c).DepIn (ShdRunDepSet Lq tag key domain shape))
    (visSpec : ShdRunVisSpec Lq hL20 prog P.refused)
    (hkCount : ∀ x c, (prog x c).KCount tag key shdP_zkResT shdP_zkLeaves shdP_zkNodes)
    (sched : Fin shdP_zkResPts → ShdPtSpec Lq)
    (hsm : ShdScheduleMatch Lq hL20 tag key domain shape prog sched)
    (hhid_leaf : ∀ v, ¬ visSpec.G v → ∀ i, ¬ visSpec.vis v i → ∃ id, sched i = .leaf id)
    (hhid_inv : ∀ x v, ¬ visSpec.G v → ∀ i id, ¬ visSpec.vis v i → sched i = .leaf id →
      ∀ c d, PProg.outOf (prog x (shdCoinsSetLeaf c id d)) v = PProg.outOf (prog x c) v) :
    ShdZKCountWitness R Lq hL20 tag key domain shape V P Cin h64 hr base where
  prog := prog
  hprog := hprog
  hk := hk
  habs := habs
  hq := hq
  hdep := hdep
  h512 := shdCoins_h512
  visSpec := visSpec
  hkCount := hkCount
  kOf := fun _ _ i => (sched i).kind
  hkind := fun x H s i => by
    cases hsi : sched i with
    | leaf id =>
      obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H s i id hsi
      rw [hpt, shdQKind_leaf]; rfl
    | node L R hLR =>
      obtain ⟨hn, hpt⟩ := hsm.hnode_pt x H s i L R hLR hsi
      rw [hpt, shdQKind_node hsep]; rfl
    | tr tk m ext =>
      cases tk with
      | squeeze =>
        obtain ⟨ctr, hs, hpt, _⟩ := hsm.hsqueeze_pt x H s i m ext hsi
        rw [hpt, shdQKind_key hsep]; rfl
      | absorb =>
        obtain ⟨st, label, data, ha, _, _, hpt, _⟩ := (hsm.habsorb_pt x H i m ext hsi).1 s
        rw [hpt, shdQKind_key hsep]; rfl
      | pad =>
        rw [(hsm.hpad_pt x H s i m ext hsi).1, shdQKind_zkPad]; rfl
  hcntT := fun _ _ => hsm.hcntT
  hcntL := fun _ _ => hsm.hcntL
  hcntN := fun _ _ => hsm.hcntN
  hcntD := fun _ _ => by
    refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun i _ h => ?_)
    exact ShdPtSpec.kind_ne_dep (sched i) h
  hfreshT := fun x H i hki z => by
    cases hsi : sched i with
    | leaf _ => rw [hsi] at hki; cases hki
    | node _ _ _ => rw [hsi] at hki; cases hki
    | tr tk m ext =>
      refine exposed_card_dig (fun s => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) m ext (fun s => ?_) z
      cases tk with
      | squeeze => exact (hsm.hsqueeze_pt x H s i m ext hsi).choose_spec.choose_spec.2
      | absorb => exact ((hsm.habsorb_pt x H i m ext hsi).1 s).choose_spec.choose_spec.choose_spec.choose_spec.2.2.2
      | pad => exact (hsm.hpad_pt x H s i m ext hsi).2
  hfreshL := fun x H i hki z => by
    cases hsi : sched i with
    | leaf id =>
      refine freshLeafSalt_card (fun s => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) id qTailDig (fun s => ?_) z
      obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H s i id hsi
      rw [hpt, qTailDig_digPair]
    | node _ _ _ => rw [hsi] at hki; cases hki
    | tr _ _ _ => rw [hsi] at hki; cases hki
  hfreshN := fun x H i hki z => by
    cases hsi : sched i with
    | leaf _ => rw [hsi] at hki; cases hki
    | node L R hLR =>
      have h512 : 2 ^ 512 = Fintype.card Dig * Fintype.card Dig := by rw [card_dig_eq, ← pow_add]
      rw [h512]
      refine exposed2_card (fun s => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i)
        L R hLR qHeadDig qTailDig (fun s => ?_) (fun s => ?_) z
      · obtain ⟨hn, hpt⟩ := hsm.hnode_pt x H s i L R hLR hsi
        rw [hpt, qHeadDig_digPair]
      · obtain ⟨hn, hpt⟩ := hsm.hnode_pt x H s i L R hLR hsi
        rw [hpt, qTailDig_digPair]
    | tr _ _ _ => rw [hsi] at hki; cases hki
  hpairs := fun x H i j hij => by
    have hpt_kind : ∀ (s : ShdCoins × (Fin shdP_zkResPts → Dig)) r,
        shdQKind tag key (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 r) = (sched r).kind := by
      intro s r
      cases hsr : sched r with
      | leaf id => obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H s r id hsr; rw [hpt, shdQKind_leaf]; rfl
      | node L R hLR => obtain ⟨hn, hpt⟩ := hsm.hnode_pt x H s r L R hLR hsr; rw [hpt, shdQKind_node hsep]; rfl
      | tr tk m ext =>
        cases tk with
        | squeeze => obtain ⟨ctr, hs, hpt, _⟩ := hsm.hsqueeze_pt x H s r m ext hsr; rw [hpt, shdQKind_key hsep]; rfl
        | absorb => obtain ⟨st, lab, dat, ha, _, _, hpt, _⟩ := (hsm.habsorb_pt x H r m ext hsr).1 s; rw [hpt, shdQKind_key hsep]; rfl
        | pad => rw [(hsm.hpad_pt x H s r m ext hsr).1, shdQKind_zkPad]; rfl
    by_cases hkeq : (sched i).kind = (sched j).kind
    · -- Same `ShdQKind`: handle `.leaf`, `.node`, `.tr`
      cases hsi : sched i with
      | leaf id₁ =>
        cases hsj : sched j with
        | leaf id₂ =>
          have hid : id₁ ≠ id₂ := hsm.hleaf_inj i j id₁ id₂ hsi hsj hij
          refine coll_pair_twoLeafSalts_card
            (fun s r => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 r) hid qTailDig
            (fun s => ?_) (fun s => ?_)
          · obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H s i id₁ hsi; rw [hpt, qTailDig_digPair]
          · obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H s j id₂ hsj; rw [hpt, qTailDig_digPair]
        | node _ _ _ => rw [hsi, hsj] at hkeq; cases hkeq
        | tr _ _ _ => rw [hsi, hsj] at hkeq; cases hkeq
      | node L₁ R₁ h₁ =>
        cases hsj : sched j with
        | leaf _ => rw [hsi, hsj] at hkeq; cases hkeq
        | node L₂ R₂ h₂ =>
          have hL : L₁ ≠ L₂ := hsm.hnode_inj i j L₁ R₁ h₁ L₂ R₂ h₂ hsi hsj hij
          rw [← card_dig_eq]
          refine coll_pair_diff_exposed_card
            (fun s r => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 r) hL qHeadDig
            (fun s => ?_) (fun s => ?_)
          · obtain ⟨hn, hpt⟩ := hsm.hnode_pt x H s i L₁ R₁ h₁ hsi; rw [hpt, qHeadDig_digPair]
          · obtain ⟨hn, hpt⟩ := hsm.hnode_pt x H s j L₂ R₂ h₂ hsj; rw [hpt, qHeadDig_digPair]
        | tr _ _ _ => rw [hsi, hsj] at hkeq; cases hkeq
      | tr tk₁ m₁ ext₁ =>
        cases hsj : sched j with
        | leaf _ => rw [hsi, hsj] at hkeq; cases hkeq
        | node _ _ _ => rw [hsi, hsj] at hkeq; cases hkeq
        | tr tk₂ m₂ ext₂ =>
          -- Helper for ordered pair `a < b` of `.tr` entries
          have hord : ∀ (a b : Fin shdP_zkResPts) tka ma exta tkb mb extb,
              a.val < b.val → sched a = .tr tka ma exta → sched b = .tr tkb mb extb →
              2 ^ 256 * (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
                PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 a
                  = PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 b)).card
                ≤ Fintype.card (ShdCoins × (Fin shdP_zkResPts → Dig)) := by
            intro a b tka ma exta tkb mb extb hab hsa hsb
            rcases hsm.htr_order a b tka ma exta tkb mb extb hab hsa hsb with rfl | hle | ⟨rfl, rfl⟩
            · -- `b` is `.pad`: 0 collisions deterministically!
              have h0 : (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
                  PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 a
                    = PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 b)).card = 0 := by
                refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ heq => ?_)
                rw [(hsm.hpad_pt x H s b mb extb hsb).1] at heq
                cases tka with
                | squeeze =>
                  obtain ⟨ctr, hs, hpta, _⟩ := hsm.hsqueeze_pt x H s a ma exta hsa
                  rw [hpta] at heq
                  exact shdP_zkPad_ne_squeeze Lq hL20 b.val (s.2 mb) key (s.2 ma) ctr hs heq.symm
                | absorb =>
                  obtain ⟨st, lab, dat, ha, _, _, hpta, _⟩ := (hsm.habsorb_pt x H a ma exta hsa).1 s
                  rw [hpta] at heq
                  exact shdP_zkPad_ne_absorb Lq hL20 b.val (s.2 mb) key st lab dat ha heq.symm
                | pad =>
                  rw [(hsm.hpad_pt x H s a ma exta hsa).1] at heq
                  have hlt64 := shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.2
                  have hEqIdx := (shdP_zkPad_injective_idx Lq hL20 (lt_trans a.isLt hlt64) (lt_trans b.isLt hlt64) heq).1
                  omega
              rw [h0, Nat.mul_zero]; exact Nat.zero_le _
            · -- `a.val ≤ mb.val`: causal exposed collision `≤ 1/2^256`!
              rw [← card_dig_eq]
              refine coll_pair_causal_exposed_card
                (fun c v r => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v r)
                (fun c => PProg.ptsOf_causal (shdP_zkPad Lq hL20) (prog x c) H) hle extb (fun c v => ?_)
              cases tkb with
              | squeeze => exact (hsm.hsqueeze_pt x H (c, v) b mb extb hsb).choose_spec.choose_spec.2
              | absorb => exact ((hsm.habsorb_pt x H b mb extb hsb).1 (c, v)).choose_spec.choose_spec.choose_spec.choose_spec.2.2.2
              | pad => exact (hsm.hpad_pt x H (c, v) b mb extb hsb).2
            · -- `a` is `47`-byte squeeze, `b` is `≥ 48`-byte absorb: 0 collisions deterministically!
              have h0 : (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
                  PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 a
                    = PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 b)).card = 0 := by
                refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ heq => ?_)
                obtain ⟨ctr, hs, hpta, _⟩ := hsm.hsqueeze_pt x H s a ma exta hsa
                obtain ⟨st, lab, dat, ha, _, _, hptb, _⟩ := (hsm.habsorb_pt x H b mb extb hsb).1 s
                rw [hpta, hptb] at heq
                exact squeeze_ne_absorb_qb key key (s.2 ma) st ctr lab dat hs ha heq
              rw [h0, Nat.mul_zero]; exact Nat.zero_le _
          rcases Nat.lt_or_gt_of_ne (Fin.val_ne_of_ne hij) with hlt | hgt
          · exact hord i j tk₁ m₁ ext₁ tk₂ m₂ ext₂ hlt hsi hsj
          · have hsymm : univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
                PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
                  = PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 j)
                = univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
                  PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 j
                    = PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) := by
              ext s; simp [eq_comm]
            rw [hsymm]
            exact hord j i tk₂ m₂ ext₂ tk₁ m₁ ext₁ hgt hsj hsi
    · -- Distinct `ShdQKind`: 0 collisions!
      have h0 := coll_pair_disjoint_kind_card tag key
        (fun (s : ShdCoins × (Fin shdP_zkResPts → Dig)) r =>
          PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 r)
        (i := i) (j := j) (fun s => by rw [hpt_kind s i, hpt_kind s j]; exact hkeq)
      rw [h0, Nat.mul_zero]; exact Nat.zero_le _
  hdeps := fun x H i => by
    cases hsi : sched i with
    | leaf id =>
      have h0 : (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
          PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
            ∈ ShdRunDepSet Lq tag key domain shape)).card = 0 := by
        refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ hmem => ?_)
        obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H s i id hsi
        rw [hpt] at hmem; exact leaf_notMem_depSet hsep domain shape cd _ hl hmem
      rw [h0, Nat.mul_zero]; exact Nat.zero_le _
    | node L R hLR =>
      have h0 : (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
          PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
            ∈ ShdRunDepSet Lq tag key domain shape)).card = 0 := by
        refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ hmem => ?_)
        obtain ⟨hn, hpt⟩ := hsm.hnode_pt x H s i L R hLR hsi
        rw [hpt] at hmem; exact node_notMem_depSet hsep domain shape _ _ hn hmem
      rw [h0, Nat.mul_zero]; exact Nat.zero_le _
    | tr tk m ext =>
      cases tk with
      | squeeze =>
        have h0 : (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
            PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
              ∈ ShdRunDepSet Lq tag key domain shape)).card = 0 := by
          refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ hmem => ?_)
          obtain ⟨ctr, hs, hpt, _⟩ := hsm.hsqueeze_pt x H s i m ext hsi
          rw [hpt] at hmem; exact squeeze_notMem_depSet hsep domain shape hdom35 _ ctr hs hmem
        rw [h0, Nat.mul_zero]; exact Nat.zero_le _
      | absorb =>
        rcases (hsm.habsorb_pt x H i m ext hsi).2 with habs_vm | hnot_mem
        · exact absorb_hit_depSet_card hsep domain shape
            (fun s => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i) m habs_vm
        · have h0 : (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
              PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
                ∈ ShdRunDepSet Lq tag key domain shape)).card = 0 :=
            Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ hmem => hnot_mem s hmem)
          rw [h0, Nat.mul_zero]; exact Nat.zero_le _
      | pad =>
        have h0 : (univ.filter (fun s : ShdCoins × (Fin shdP_zkResPts → Dig) =>
            PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
              ∈ ShdRunDepSet Lq tag key domain shape)).card = 0 := by
          refine Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun s _ hmem => ?_)
          rw [(hsm.hpad_pt x H s i m ext hsi).1] at hmem
          exact shdP_zkPad_notMem_depSet Lq hL20 tag key domain shape hdom37 i.val (s.2 m) hmem
        rw [h0, Nat.mul_zero]; exact Nat.zero_le _
  hleaf_hid := fun x H v hg c i hni => by
    obtain ⟨id, hsi⟩ := hhid_leaf v hg i hni
    obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H (c, v) i id hsi
    rw [hpt, shdQKind_leaf]
  hhid_card := fun v hg => by
    have hsub : univ.filter (fun i : Fin shdP_zkResPts => ¬ visSpec.vis v i)
        ⊆ univ.filter (fun i : Fin shdP_zkResPts => (sched i).kind = .leaf) := by
      intro i hi
      obtain ⟨id, hsi⟩ := hhid_leaf v hg i (mem_filter.mp hi).2
      exact mem_filter.mpr ⟨mem_univ _, by rw [hsi]; rfl⟩
    exact (Finset.card_le_card hsub).trans hsm.hcntL
  hcond_hid := fun x H v hg i hni o z => by
    obtain ⟨id, hsi⟩ := hhid_leaf v hg i hni
    have h := cond_freshLeafSalt_card id (fun c => PProg.outOf (prog x c) v)
      (hhid_inv x v hg i id hni hsi)
      (fun c => PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v i) qTailDig
      (fun c => by
        obtain ⟨cd, hl, hpt⟩ := hsm.hleaf_pt x H (c, v) i id hsi
        rw [hpt, qTailDig_digPair])
      o z
    convert h

end ScheduleBuilder

/-! ## 3. Fixed-length `PProg` combinators (`trAbsorbProgF`, `scProveFixedProg`, `tokenEpAuditProveProg`) -/

section FixedCombinators

/-- Fixed-1-point transcript absorb (`PtLen 1`, `QLE 1`, `DepStrict`, `KCount 1 0 0`) when the
encoded message length fits `Lq`. -/
def trAbsorbProgF (Lq : ℕ) (t : Tr) (label data : List UInt8)
    (hfit : (absorbMsg t.state label data).length ≤ Lq) : PProg (QB Lq) Dig Tr :=
  .pt (t.key, ⟨absorbMsg t.state label data, hfit⟩) fun dg => .ret { t with state := dg }

theorem trAbsorbProgF_run (Lq : ℕ) (t : Tr) (label data : List UInt8)
    (hfit : (absorbMsg t.state label data).length ≤ Lq) (G : QB Lq → Dig) :
    (trAbsorbProgF Lq t label data hfit).run G = t.absorb (liftH G) label data := by
  unfold trAbsorbProgF Tr.absorb liftH
  dsimp only [PProg.run]
  rw [dite_eq_left hfit]

theorem trAbsorbProgF_ptLen (Lq : ℕ) (t : Tr) (label data : List UInt8)
    (hfit : (absorbMsg t.state label data).length ≤ Lq) :
    (trAbsorbProgF Lq t label data hfit).PtLen 1 :=
  ⟨0, rfl, fun _ => rfl⟩

theorem trAbsorbProgF_ptAt (Lq : ℕ) (t : Tr) (label data : List UInt8)
    (hfit : (absorbMsg t.state label data).length ≤ Lq) (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trAbsorbProgF Lq t label data hfit).ptAt H v i i = some (t.key, ⟨absorbMsg t.state label data, hfit⟩) := by
  simp [trAbsorbProgF, PProg.ptAt]

theorem trAbsorbProgF_res (Lq : ℕ) (t : Tr) (label data : List UInt8)
    (hfit : (absorbMsg t.state label data).length ≤ Lq) (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trAbsorbProgF Lq t label data hfit).res H v i = { t with state := v i } := rfl

theorem trAbsorbProgF_kCount (Lq : ℕ) {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (t : Tr) (ht : t.key = key) (label data : List UInt8)
    (hfit : (absorbMsg t.state label data).length ≤ Lq) :
    (trAbsorbProgF Lq t label data hfit).KCount tag key 1 0 0 := by
  unfold trAbsorbProgF PProg.KCount
  rw [ht, shdQKind_key hsep _ hfit]
  exact ⟨Nat.zero_lt_one, fun _ => trivial⟩

theorem trSqueezeProg_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) :
    (trSqueezeProg Lq h47 t).PtLen 1 :=
  ⟨0, rfl, fun _ => rfl⟩

theorem trSqueezeProg_ptAt (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trSqueezeProg Lq h47 t).ptAt H v i i
      = some (t.key, ⟨squeezeMsg t.state t.counter, by rw [squeezeMsg_length]; exact h47⟩) := by
  simp [trSqueezeProg, PProg.ptAt]

theorem trSqueezeProg_res (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (i : ℕ) :
    (trSqueezeProg Lq h47 t).res H v i = (v i, { t with state := v i, counter := t.counter + 1 }) := rfl

theorem trChallengeFp2Prog_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) :
    (trChallengeFp2Prog Lq h47 t).PtLen 1 :=
  (trSqueezeProg_ptLen Lq h47 t).andThen (n := 0) (fun _ => rfl)

theorem posTagProg_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) :
    (posTagProg Lq h47 t).PtLen 2 := by
  unfold posTagProg
  rw [show (2 : ℕ) = 1 + (1 + 0) by omega]
  exact (trChallengeFp2Prog_ptLen Lq h47 t).andThen fun a =>
    (trChallengeFp2Prog_ptLen Lq h47 a.2).andThen (n := 0) (fun _ => rfl)

theorem trSqueezeVecProg_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) :
    ∀ (n : ℕ) (t : Tr), (trSqueezeVecProg Lq h47 n t).PtLen n
  | 0, _ => rfl
  | n + 1, t => by
    unfold trSqueezeVecProg
    rw [show n + 1 = 1 + (n + 0) by omega]
    exact (trSqueezeProg_ptLen Lq h47 t).andThen fun r =>
      (trSqueezeVecProg_ptLen Lq h47 n r.2).andThen (n := 0) (fun _ => rfl)

theorem trChallengeFp2VecProg_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) :
    ∀ (n : ℕ) (t : Tr), (trChallengeFp2VecProg Lq h47 n t).PtLen n
  | 0, _ => rfl
  | n + 1, t => by
    unfold trChallengeFp2VecProg
    rw [show n + 1 = 1 + (n + 0) by omega]
    exact (trChallengeFp2Prog_ptLen Lq h47 t).andThen fun r =>
      (trChallengeFp2VecProg_ptLen Lq h47 n r.2).andThen (n := 0) (fun _ => rfl)

theorem zkRhosProg_ptLen (Lq : ℕ) (h47 : 47 ≤ Lq) (rows : ℕ) :
    ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr),
      (zkRhosProg Lq h47 rows gs t).PtLen ((gs.map (fun g => g.2.length)).sum + rows)
  | [], t => by
    simp only [zkRhosProg, List.map_nil, List.sum_nil, Nat.zero_add]
    rw [show rows = rows + 0 by omega]
    exact (trChallengeFp2VecProg_ptLen Lq h47 rows t).andThen (n := 0) (fun _ => rfl)
  | g :: gs, t => by
    simp only [zkRhosProg, List.map_cons, List.sum_cons]
    rw [show g.2.length + (List.map (fun g => g.2.length) gs).sum + rows
      = g.2.length + ((List.map (fun g => g.2.length) gs).sum + rows + 0) by omega]
    exact (trChallengeFp2VecProg_ptLen Lq h47 g.2.length t).andThen fun l =>
      (zkRhosProg_ptLen Lq h47 rows gs l.2).andThen (n := 0) (fun _ => rfl)

end FixedCombinators

end ZK60.HonestShield
