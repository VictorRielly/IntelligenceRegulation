/-
D63 lane L49 (2026-11-10), sub-agent `look`, round 2, part 1: **LogUp's helper relations at R13, the generic half** (for
lane L36's `hhr` at R13), by lane L47's fork C pattern (`BlockLookRelBase.lean`, `BlockLookRelHost.lean`).

* `RelCfg c ls`: the further facts about the configuration (`ls ≤ 2`, the hosts' helper counts in the shape), PROVED at
  the R13 rung and at every Shieldstral layer;
* `okNil`, `okCons`, `okB`, `okP`, `okApp`, `okMapRange`, **`lkOK_R`**: every lookup of R13's lists is a word
  (`W16.Look.LkOK`: constants, coefficients, tags below `2^64`), at every configuration of `LookCfg` and `RelCfg`;
* `lkTupR_eq`, `aPl_castB'`, `hPl_castB`: a lookup tuple on a plane reader (`W16.Look.lkTupP`), and the casts;
* **`bga_canon_R`**: on an accepting outcome `α` and `β` are canonical (lane L47's `bga_canon_of_accT` for any slot
  schedule with a first slot);
* **`relL_pairR`**: `SC_LZC`'s limb relation (`Help.cLzcR`), vanishing, IS `HelperRel`'s pair relation of `Dom::L`'s two
  byte lookups;
* **`relTabR`**: `SC_TAB`'s relation (`R13T.cTabR`), vanishing, IS `HelperRel`'s table relation of `TR13`, `mlkR13`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookCov
import ZK60Formal.BlockR13LookSum
import ZK60Formal.BlockLookRelPer
import ZK60Formal.BlockR13LookHelpSlot

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.LookRel

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.Join.W16 (aPl piB hPl cstK)
open ZK60.Exec.Block.Join.W16.Tab (tabTupE)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Exec.Slot.W16R2 (Dom segLn)
open ZK60.Layout
open ZK60.Circuit (gP GF tagW)

/-! ## The configuration's further facts -/

/-- **The further facts about the configuration the helper relations read**: at most three softmax limbs, and each
LogUp host's batch (`μ`, past its pad entry) is long enough for its named clauses and its helper relations (`SC_DZC`
`13 + 17`, `SC_QZC` and `SC_KVZC` `4 + 7`, `SC_SZC` `5 + (7 + ls) + 1`, `SC_FZC` `4 + 7`). PROVED at the R13 rung and
at every Shieldstral layer (`relCfg_rung`, `relCfg_shield`). -/
structure RelCfg (c : W16Cfg) (ls : ℕ) : Prop where
  ls2 : ls ≤ 2
  bD : 30 ≤ segLn (ZK60.Exec.Slot.R13.draws c.sh 14) .mu - segLn (ZK60.Exec.Slot.R13.draws c.sh 14) .zeta
  bQ : 11 ≤ segLn (ZK60.Exec.Slot.R13.draws c.sh 15) .mu - segLn (ZK60.Exec.Slot.R13.draws c.sh 15) .zeta
  bK : 11 ≤ segLn (ZK60.Exec.Slot.R13.draws c.sh 16) .mu - segLn (ZK60.Exec.Slot.R13.draws c.sh 16) .zeta
  bS : 13 + ls ≤ segLn (ZK60.Exec.Slot.R13.draws c.sh 17) .mu - segLn (ZK60.Exec.Slot.R13.draws c.sh 17) .zeta
  bF : 11 ≤ segLn (ZK60.Exec.Slot.R13.draws c.sh 18) .mu - segLn (ZK60.Exec.Slot.R13.draws c.sh 18) .zeta

theorem relCfg_rung : RelCfg DefR13.cfgRungR13 2 := ⟨by norm_num, by decide, by decide, by decide, by decide, by decide⟩

local notation "shS" => ZK60.Exec.Slot.R13.shShieldR13

theorem relCfg_shield (L : ZK60.RunShape.Shield.ShieldLayer) : RelCfg (DefR13.cfgShieldR13 L) 1 :=
  ⟨by norm_num,
    (by decide : 30 ≤ segLn (ZK60.Exec.Slot.R13.draws (shS) 14) .mu - segLn (ZK60.Exec.Slot.R13.draws (shS) 14) .zeta),
    (by decide : 11 ≤ segLn (ZK60.Exec.Slot.R13.draws (shS) 15) .mu - segLn (ZK60.Exec.Slot.R13.draws (shS) 15) .zeta),
    (by decide : 11 ≤ segLn (ZK60.Exec.Slot.R13.draws (shS) 16) .mu - segLn (ZK60.Exec.Slot.R13.draws (shS) 16) .zeta),
    (by decide : 13 + 1 ≤ segLn (ZK60.Exec.Slot.R13.draws (shS) 17) .mu
      - segLn (ZK60.Exec.Slot.R13.draws (shS) 17) .zeta),
    (by decide : 11 ≤ segLn (ZK60.Exec.Slot.R13.draws (shS) 18) .mu - segLn (ZK60.Exec.Slot.R13.draws (shS) 18) .zeta)⟩

/-! ## The code's lookups are words -/

section OK

theorem okNil : ∀ l ∈ ([] : List LkW), W16.Look.LkOK l := fun _ h => absurd h List.not_mem_nil

theorem okCons (l : LkW) (h : W16.Look.LkOK l) (L : List LkW) (hL : ∀ l ∈ L, W16.Look.LkOK l) :
    ∀ l' ∈ l :: L, W16.Look.LkOK l' := by
  intro l' hl'
  rcases List.mem_cons.mp hl' with rfl | h'
  · exact h
  · exact hL l' h'

theorem okB_one (q : ℕ) : W16.Look.LkOK (bLk q) := by
  refine ⟨by show (-2 ^ 64 : ℤ) < 0; norm_num, by show (0 : ℤ) < 2 ^ 64; norm_num,
    by show tagW 8 < 2 ^ 64; decide, fun t ht => ?_⟩
  simp only [bLk, List.mem_singleton] at ht
  subst ht
  show -(2 : ℤ) ^ 64 < -1 ∧ -(1 : ℤ) < 2 ^ 64
  constructor <;> norm_num

theorem okP_one (q e : ℕ) (he : e < 64) : W16.Look.LkOK (pLk q e) := by
  have h1 : (2 : ℤ) ^ e < 2 ^ 64 := pow_lt_pow_right₀ (by norm_num) he
  have h2 : (0 : ℤ) < 2 ^ e := by positivity
  refine ⟨by show (-2 ^ 64 : ℤ) < 0; norm_num, by show (0 : ℤ) < 2 ^ 64; norm_num,
    by show tagW 8 < 2 ^ 64; decide, fun t ht => ?_⟩
  simp only [pLk, List.mem_singleton] at ht
  subst ht
  show -(2 : ℤ) ^ 64 < -2 ^ e ∧ -(2 : ℤ) ^ e < 2 ^ 64
  constructor <;> linarith

theorem okB (q : ℕ) (L : List LkW) (hL : ∀ l ∈ L, W16.Look.LkOK l) : ∀ l ∈ bLk q :: L, W16.Look.LkOK l :=
  okCons _ (okB_one q) L hL

theorem okP (q e : ℕ) (L : List LkW) (hL : ∀ l ∈ L, W16.Look.LkOK l) (he : e < 64) :
    ∀ l ∈ pLk q e :: L, W16.Look.LkOK l :=
  okCons _ (okP_one q e he) L hL

theorem okApp (L L' : List LkW) (h : ∀ l ∈ L, W16.Look.LkOK l) (h' : ∀ l ∈ L', W16.Look.LkOK l) :
    ∀ l ∈ L ++ L', W16.Look.LkOK l := by
  intro l hl
  rcases List.mem_append.mp hl with h1 | h1
  · exact h l h1
  · exact h' l h1

theorem okMapRange (s n : ℕ) : ∀ l ∈ (List.range' s n).map bLk, W16.Look.LkOK l := by
  intro l hl
  obtain ⟨q, -, rfl⟩ := List.mem_map.mp hl
  exact okB_one q

/-- **Every lookup of R13's lists is a word** (the pins' exponents are at most `24`). -/
theorem lkOK_R {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) (hr : RelCfg c ls) (d : Dm) :
    ∀ l ∈ DefR13.lookups c d.dom, W16.Look.LkOK l := by
  have h2 := hr.ls2
  cases d
  · rw [show Dm.L.dom = Dom.L from rfl, hc.lkL]
    unfold lkLe
    repeat (first | apply okB | exact okNil)
  · rw [show Dm.D.dom = Dom.D from rfl, hc.lkD]
    unfold lkDe
    repeat (first | apply okB | apply okP | exact okNil)
    all_goals omega
  · rw [show Dm.Q.dom = Dom.Q from rfl, hc.lkQ]
    unfold lkQe
    repeat (first | apply okB | apply okP | exact okNil)
    all_goals omega
  · rw [show Dm.Kv.dom = Dom.Kv from rfl, hc.lkK]
    unfold lkKe
    repeat (first | apply okB | apply okP | exact okNil)
    all_goals omega
  · rw [show Dm.S.dom = Dom.S from rfl, hc.lkS]
    unfold lkSe
    refine okApp _ _ (okApp _ _ ?_ (okApp _ _ (okMapRange _ _) (okP _ _ _ okNil (by omega))))
      (okApp _ _ (okMapRange _ _) (okP _ _ _ okNil (by omega)))
    refine okCons _ (by decide) _ (okCons _ (by decide) _ ?_)
    repeat (first | apply okB | apply okP | exact okNil)
    all_goals omega
  · rw [show Dm.F.dom = Dom.F from rfl, hc.lkF]
    unfold lkFe
    repeat (first | apply okB | apply okP | exact okNil)
    all_goals omega

end OK

/-! ## Tuples and casts -/

section Casts

variable {K : Type} [Field K] [Algebra GF K] (U : K) (c : W16Cfg) (P : BlockParams) (D : CmData K P)

/-- A lookup tuple read off `A` is lane L47's tuple on the plane reader. -/
theorem lkTupR_eq (log : ℕ) (l : LkW) (b : Fin log → Bool) :
    lkTupR U c P D log l b = W16.Look.lkTupP (fun q => aPl U P D (DefR13.aOff c q) log b) l := rfl

/-- An `A` plane at a cast point. -/
theorem aPl_castB' (off : ℕ) {m n : ℕ} (h : m = n) (v : Fin m → Bool) :
    aPl U P D off n (castB h v) = aPl U P D off m v := by
  subst h
  rfl

/-- An `H` plane at a cast point. -/
theorem hPl_castB (re im : ℕ) {m n : ℕ} (h : m = n) (v : Fin m → Bool) :
    hPl U P D re im n (castB h v) = hPl U P D re im m v := by
  subst h
  rfl

end Casts

/-! ## `α`, `β` are canonical on an accepting outcome -/

section Canon

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **On an accepting outcome `α` and `β` are canonical words** (lane L47's `bga_canon_of_accT`, for any slot schedule
with a first slot). -/
theorem bga_canon_R (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hsl : 0 < P.geom.slots.length)
    (prog : List SlotS) (pubs : PubTabs) (hdef : P.define = defineS prog pubs) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc) : bga.2.2.Canon ∧ bga.1.Canon := by
  have hT' := hT
  obtain ⟨hacc, -, -⟩ := hT'
  obtain ⟨-, -, -, hsh, t', hbs⟩ := hacc.1
  obtain ⟨hlen, -⟩ := blockSlots_fns (liftH G) P (A.run G).2 _ bga rs acc t' hbs
  have h0 : 0 < rs.length := by
    rw [hlen, hsh.1]
    exact hsl
  obtain ⟨r, hr⟩ : ∃ r, rs[0]? = some r := ⟨_, List.getElem?_eq_getElem h0⟩
  obtain ⟨sp, df, hdf, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen F csX msX A G bga rs acc hT 0 r hr
  rw [hdef] at hdf
  have hc := (defineS_ok hdf).1
  exact ⟨hc.1, hc.2.1⟩

end Canon

/-! ## `SC_LZC` and `SC_TAB` -/

section LT

variable {K : Type} [Field K] [Algebra GF K] (U : K) (c : W16Cfg) (P : BlockParams) (D : CmData K P)
variable (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)

theorem lkL_W16 : DefW16.lookupsN DefW16.cfgRungW16 ZK60.Exec.Block.Join.W16.Look.LkDom.L.dom = [bLk 6, bLk 7] :=
  rfl

theorem planesL_W16 : ∀ l ∈ DefW16.lookupsN DefW16.cfgRungW16 ZK60.Exec.Block.Join.W16.Look.LkDom.L.dom,
    ∀ t ∈ l.terms, t.1 = 6 ∨ t.1 = 7 := by
  decide

include hα in
/-- **`SC_LZC`'s relation at R13**, vanishing at a point of `Dom::L`'s cube, IS `HelperRel`'s pair relation of the two
limb lookups (helper plane `0`). -/
theorem relL_pairR (gL : (Fin 14 → Bool) → GF) (b : Fin 14 → Bool) (h0 : Help.cLzcR U c P D gL bga b = 0) :
    W16.Look.PairR U bga (hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 14 b)
      (W16.Look.lkTupP (fun q => aPl U P D (DefR13.aOff c q) 14 b) (bLk 6))
      (W16.Look.lkTupP (fun q => aPl U P D (DefR13.aOff c q) 14 b) (bLk 7)) := by
  unfold Help.cLzcR at h0
  have hlen : (W16.Lk.lksLK U bga).length = 2 := by
    unfold W16.Lk.lksLK
    simp only [List.length_map]
    decide
  rw [W16.Look.logupSem_two _ _ _ _ _ hlen] at h0
  simp only [(ZK60.Exec.Slot.Compose.cstW_map_std U).one, one_mul] at h0
  have hp := W16.Look.host_pair U bga hα 3 W16.Lk.shapedL
    (DefW16.lookupsN DefW16.cfgRungW16 ZK60.Exec.Block.Join.W16.Look.LkDom.L.dom) (Help.valsLR U c P D gL b)
    (fun q => aPl U P D (DefR13.aOff c q) 14 b) 3 _ 0 (by rw [lkL_W16]; simp)
    (W16.Look.lkOK_all .L)
    (fun l hl t ht => by
      rcases planesL_W16 l hl t ht with h | h <;> rw [h] <;> rfl)
    rfl h0
  rw [lkL_W16] at hp
  exact hp

/-- **`SC_TAB`'s relation `k` at R13**, vanishing at a point of `Dom::Tab`, IS `HelperRel`'s table relation of
`TR13`, `mlkR13`. -/
theorem relTabR (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (k : Fin 3) (b : Fin 14 → Bool)
    (h : R13T.cTabR U c P D exp act nG bga k b = 0) :
    R13T.helpTabR U c P D k b * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TR13 exp act nG (k, b)))
      = R13T.multTabR U c P D k b := by
  unfold R13T.cTabR at h
  show _ * (_ - ZK60.Sound.fold _ _ (tupK (tabTupE exp act nG k (msbIndex 14 b)))) = _
  linear_combination h

end LT

end ZK60.Exec.Block.Join.R13H.LookRel
