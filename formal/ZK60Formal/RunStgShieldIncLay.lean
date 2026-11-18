/-
D63 lane L63 (2026-11-18), part 51: **stage IN-C's cube layout for the `K`-valued data** (item 4a of
HANDOFF_20261118_1.md, at the corrected data of `RunStgShieldLuK.lean`).

* `shdTokOf`, `shdTokOf_pos`: the token row of a position on the `ti_log = 12` cube (`msbIndex mod 128`, the low
  seven bits: `B_in`'s row that SIC_QZC reads at `rhoC (tl − tBits) tl`);
* **`shdIncLay`**: `IncLayout (RingHom.id K) (shdIncDataK …) 12 17`. Positions `t ↦ msbBits 12 t`, table rows
  `j ↦ msbBits 17 j` (the bits `shdIncData` reads at); the token words and the multiplicities are the `A_in` planes
  themselves (`tok_pos`, `m_pos` by definition); `B_in` at the position's token row, read at `r_emb`; the public tables
  as stage IN-C's `define` writes them, read at `msbIndex`: `supp_T` (`I.tokens`), `u0`, `π` (`isTemplate`), `κ`,
  `β²·[ctl_q]`, `γ·TAG_EMB`, BOS, `supp_V` (`I.v`), and `τ` at the data's table tuple. Hypotheses: `I.tokens = 128`,
  `I.v = P.V ≤ 2^17` (the vocabulary cube is the table), and `ctl_q` is the public data's control class (`hcq`);
* `shdIncLay_bosTmpl`: the layout's BOS and template facts are the public data's (`I.bos = P.bos`, the template and
  `κ` the public data's);
* **`shd_inSat_of_goodK`**: a `K`-valued good lookup with the BOS and template facts gives stage IN's relation `InSat`
  of the PROJECTED data (`in_inSat` through `inGood_proj`), the hypothesis of `hdinX` at the plane `bndPlanes … 0`;
* `shdP_incPub_lay`: the hypotheses at the registered stage (`shdP_incPub`), except `Rp.inp.V = 131072`, which is a
  public-data fact the registered stage fixes (`shdP_incPub.v := 131072`; see HANDOFF_20261118_2.md, finding L63-7).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldLuK
import ZK60Formal.RunShieldInstP

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.Exec.StageV (IncPub incLay incA_TOK incA_MULT tagEmb)
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

/-! ## 1. Positions -/

/-- The token row of a position on the `12`-bit position cube: its index modulo `128` (the low seven bits). -/
def shdTokOf (b : Fin 12 → Bool) : shieldS0.Tok :=
  ⟨msbIndex 12 b % 128, Nat.mod_lt _ (by norm_num)⟩

theorem shdTokOf_pos (t : shieldS0.Tok) : shdTokOf (msbBits 12 t.val) = t := by
  have ht : t.val < 128 := t.isLt
  refine Fin.ext ?_
  show msbIndex 12 (msbBits 12 t.val) % 128 = t.val
  rw [msbIndex_msbBits 12 t.val (by omega)]
  exact Nat.mod_eq_of_lt ht

theorem shdPos_inj : Function.Injective (fun t : shieldS0.Tok => msbBits 12 t.val) := by
  intro a b h
  have ha : a.val < 128 := a.isLt
  have hb : b.val < 128 := b.isLt
  have e := congrArg (msbIndex 12) h
  simp only at e
  rw [msbIndex_msbBits 12 a.val (by omega), msbIndex_msbBits 12 b.val (by omega)] at e
  exact Fin.ext e

theorem shdVpos_inj {V : ℕ} (hV : V ≤ 2 ^ 17) : Function.Injective (fun j : Fin V => msbBits 17 j.val) := by
  intro a b h
  have ha : a.val < V := a.isLt
  have hb : b.val < V := b.isLt
  have e := congrArg (msbIndex 17) h
  simp only at e
  rw [msbIndex_msbBits 17 a.val (by omega), msbIndex_msbBits 17 b.val (by omega)] at e
  exact Fin.ext e

/-- A `dite` on a bound read at an index equal to `j`'s is the `then` branch at `j`. -/
theorem lay_dite_idx {V : ℕ} {β : Type} (f : Fin V → β) (z : β) (j : Fin V) (n : ℕ) (hn : n = j.val) :
    (if h : n < V then f ⟨n, h⟩ else z) = f j := by
  subst hn
  exact dite_eq_left j.isLt

/-- The two values of the public control word `ctlPos`. -/
theorem ctlPos_cases {S : Block.BlockShape} (P : InPublic S) (t : S.Tok) :
    (ctlPos P t = 1 ∧ ((ctlPos P t : ℕ) : GF) = 1) ∨ (ctlPos P t ≠ 1 ∧ ((ctlPos P t : ℕ) : GF) = 0) := by
  unfold ctlPos ctl
  split_ifs <;> simp

/-! ## 2. The layout -/

section Lay

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}
  (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
  (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ) (v : StgVw Lq)

/-- **Stage IN-C's cube layout for the `K`-valued data.** -/
noncomputable def shdIncLay (hv : I.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : I.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, I.ctlQ t.val = decide (ctlPos P t = 1)) :
    IncLayout (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) 12 17 where
  pos := fun t => msbBits 12 t.val
  vpos := fun j => msbBits 17 j.val
  pos_inj := shdPos_inj
  vpos_inj := shdVpos_inj hV
  tok := fun b => stgPlK U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA
    ((incLay I 14).aOff incA_TOK) 12 v b
  bq := fun ω b => mleAt (fun c => (shdIncDataK U tag h64 P I Epad iB iA v).X (shdTokOf b) c) ω.2
  supp := fun b => if msbIndex 12 b < I.tokens then 1 else 0
  u0 := fun b => if msbIndex 12 b < 1 then 1 else 0
  pt := fun b => if I.isTemplate (msbIndex 12 b) then 1 else 0
  kap := fun b => ((I.kappa (msbIndex 12 b) : ℕ) : K)
  cq := fun ω b => if I.ctlQ (msbIndex 12 b) then ω.1.1.1 ^ 2 else 0
  g := fun ω => ω.1.1.2 * algebraMap GF K ((tagEmb : ℕ) : GF)
  bos := ((I.bos : ℕ) : K)
  m := fun b => stgPlK U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA
    ((incLay I 14).aOff incA_MULT) 17 v b
  suppv := fun b => if msbIndex 17 b < I.v then 1 else 0
  tau := fun ω b => if h : msbIndex 17 b < P.V then
      fold ω.1.1.1 ω.1.1.2 (tTup (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) ω.2 ⟨msbIndex 17 b, h⟩)
    else 0
  supp1 := by
    intro t
    have ht : t.val < 128 := t.isLt
    show (if msbIndex 12 (msbBits 12 t.val) < I.tokens then (1 : K) else 0) = 1
    rw [msbIndex_msbBits 12 t.val (by omega), htok]
    exact ite_eq_left ht
  supp0 := by
    intro b hb
    show (if msbIndex 12 b < I.tokens then (1 : K) else 0) = 0
    refine ite_eq_right (fun h => hb ⟨⟨msbIndex 12 b, ?_⟩, msbBits_msbIndex 12 b⟩)
    show msbIndex 12 b < 128
    rw [← htok]
    exact h
  tok_pos := fun _ => rfl
  bq_pos := by
    intro ω t
    show mleAt (fun c => (shdIncDataK U tag h64 P I Epad iB iA v).X (shdTokOf (msbBits 12 t.val)) c) ω.2 = _
    rw [shdTokOf_pos]
    rfl
  cq_pos := by
    intro ω t
    have ht : t.val < 128 := t.isLt
    show (if I.ctlQ (msbIndex 12 (msbBits 12 t.val)) then ω.1.1.1 ^ 2 else 0)
      = ω.1.1.1 ^ 2 * algebraMap GF K ((ctlPos P t : ℕ) : GF)
    rw [msbIndex_msbBits 12 t.val (by omega), hcq t]
    rcases ctlPos_cases P t with ⟨h1, h2⟩ | ⟨h1, h2⟩
    · rw [h2, map_one, mul_one]
      exact ite_eq_left (decide_eq_true h1)
    · rw [h2, map_zero, mul_zero]
      exact ite_eq_right (fun h => h1 (of_decide_eq_true h))
  g_eq := fun _ => rfl
  suppv1 := by
    intro j
    have hj : j.val < P.V := j.isLt
    show (if msbIndex 17 (msbBits 17 j.val) < I.v then (1 : K) else 0) = 1
    rw [msbIndex_msbBits 17 j.val (by omega), hv]
    exact ite_eq_left hj
  suppv0 := by
    intro c hc
    show (if msbIndex 17 c < I.v then (1 : K) else 0) = 0
    refine ite_eq_right (fun h => hc ⟨⟨msbIndex 17 c, ?_⟩, msbBits_msbIndex 17 c⟩)
    rw [← hv]
    exact h
  m_pos := fun _ => rfl
  tau_pos := by
    intro ω j
    have hj : j.val < P.V := j.isLt
    exact lay_dite_idx (fun j' => fold ω.1.1.1 ω.1.1.2
      (tTup (RingHom.id K) (shdIncDataK U tag h64 P I Epad iB iA v) ω.2 j')) 0 j _
      (msbIndex_msbBits 17 j.val (by omega))

variable (hv : I.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : I.tokens = 128)
  (hcq : ∀ t : shieldS0.Tok, I.ctlQ t.val = decide (ctlPos P t = 1))

/-! The fields at a free point (`rfl`; stating them at a concrete `msbBits` point makes `whnf` evaluate the index). -/

theorem shdIncLay_pos (t : shieldS0.Tok) :
    (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).pos t = msbBits 12 t.val := rfl

theorem shdIncLay_u0 (b : Fin 12 → Bool) :
    (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).u0 b = if msbIndex 12 b < 1 then 1 else 0 := rfl

theorem shdIncLay_pt (b : Fin 12 → Bool) :
    (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).pt b = if I.isTemplate (msbIndex 12 b) then 1 else 0 := rfl

theorem shdIncLay_kap (b : Fin 12 → Bool) :
    (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).kap b = ((I.kappa (msbIndex 12 b) : ℕ) : K) := rfl

theorem shdIncLay_bos :
    (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).bos = ((I.bos : ℕ) : K) := rfl

/-- **The layout's BOS and template facts are the public data's.** -/
theorem shdIncLay_bosTmpl (hbos : I.bos = P.bos) (hT : ∀ t : shieldS0.Tok, I.isTemplate t.val = P.isT t)
    (hk : ∀ t : shieldS0.Tok, I.kappa t.val = P.kap t)
    (h : IncBosTmpl (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq)) :
    (∀ t : shieldS0.Tok, (t : ℕ) = 0 → (shdIncDataK U tag h64 P I Epad iB iA v).tok t = ((P.bos : ℕ) : K))
      ∧ (∀ t : shieldS0.Tok, P.isT t = true →
        (shdIncDataK U tag h64 P I Epad iB iA v).tok t = ((P.kap t : ℕ) : K)) := by
  obtain ⟨hb, htm⟩ := h
  refine ⟨fun t h0 => ?_, fun t hi => ?_⟩
  · have ht : t.val < 128 := t.isLt
    have hu : (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).u0
        ((shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).pos t) = 1 := by
      rw [shdIncLay_pos, shdIncLay_u0, msbIndex_msbBits 12 t.val (by omega)]
      exact ite_eq_left (by omega)
    have e := hb t hu
    rw [shdIncLay_bos, RingHom.id_apply, hbos] at e
    exact e
  · have ht : t.val < 128 := t.isLt
    have hp : (shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).pt
        ((shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq).pos t) = 1 := by
      rw [shdIncLay_pos, shdIncLay_pt, msbIndex_msbBits 12 t.val (by omega), hT t]
      exact ite_eq_left hi
    have e := htm t hp
    rw [shdIncLay_pos, shdIncLay_kap, msbIndex_msbBits 12 t.val (by omega), hk t, RingHom.id_apply] at e
    exact e

omit [Algebra GF K] in
/-- `(n : K)` is the image of `(n : GF)`. -/
theorem lay_natCast_alg [Algebra GF K] (n : ℕ) : ((n : ℕ) : K) = algebraMap GF K ((n : ℕ) : GF) :=
  (map_natCast (algebraMap GF K) n).symm

/-- **A `K`-valued good lookup with the BOS and template facts gives `InSat` of the projected data**: the token words
`shdIncData`'s, the plane `X (t, i)` the projected `B_in` row at the column bits `msbBits 12 i`. -/
theorem shd_inSat_of_goodK (hP : P.Valid)
    (hE : ∀ (j : Fin P.V) (i : shieldS0.Wid), Epad j (msbBits 12 i.val) = (P.emb j i : GF))
    (hg : InGood (shdIncDataK U tag h64 P I Epad iB iA v))
    (hb : ∀ t : shieldS0.Tok, (t : ℕ) = 0 → (shdIncDataK U tag h64 P I Epad iB iA v).tok t = ((P.bos : ℕ) : K))
    (ht : ∀ t : shieldS0.Tok, P.isT t = true →
      (shdIncDataK U tag h64 P I Epad iB iA v).tok t = ((P.kap t : ℕ) : K)) :
    InSat P (fun t => (shdIncData U tag h64 P I Epad iB iA v).tok t)
      (fun p => (shdIncData U tag h64 P I Epad iB iA v).X p.1 (msbBits 12 p.2.val)) := by
  have _ := hP
  refine in_inSat P 12 (tagEmb : GF) (fun t => (shdIncData U tag h64 P I Epad iB iA v).tok t)
    (fun t c => (shdIncData U tag h64 P I Epad iB iA v).X t c) Epad
    (fun j => (shdIncData U tag h64 P I Epad iB iA v).m j) (fun i => msbBits 12 i.val) hE
    (inGood_proj U tag h64 P I Epad iB iA v hg) (fun t h0 => ?_) (fun t hi => ?_)
  · show Exec.Block.Join.W16.piB K ((shdIncDataK U tag h64 P I Epad iB iA v).tok t) = _
    rw [hb t h0, lay_natCast_alg, Exec.Block.Join.W16.piB_alg]
  · show Exec.Block.Join.W16.piB K ((shdIncDataK U tag h64 P I Epad iB iA v).tok t) = _
    rw [ht t hi, lay_natCast_alg, Exec.Block.Join.W16.piB_alg]

end Lay

/-! ## 3. The hypotheses at the registered stage -/

/-- **The registered stage's public data meets the layout's hypotheses**, except the vocabulary size: `tokens = 128`,
`ctl_q` the public control class, BOS, the template and `κ` the public data's. -/
theorem shdP_incPub_lay (Rp : ZK60.RunShape.ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2) :
    (shdP_incPub Rp embDigest embFold).tokens = 128
      ∧ (∀ t : shieldS0.Tok, (shdP_incPub Rp embDigest embFold).ctlQ t.val = decide (ctlPos Rp.inp t = 1))
      ∧ (shdP_incPub Rp embDigest embFold).bos = Rp.inp.bos
      ∧ (∀ t : shieldS0.Tok, (shdP_incPub Rp embDigest embFold).isTemplate t.val = Rp.inp.isT t)
      ∧ (∀ t : shieldS0.Tok, (shdP_incPub Rp embDigest embFold).kappa t.val = Rp.inp.kap t)
      ∧ (shdP_incPub Rp embDigest embFold).v = 131072 := by
  have hT : ∀ t : shieldS0.Tok, (shdP_incPub Rp embDigest embFold).isTemplate t.val = Rp.inp.isT t := by
    intro t
    have ht : t.val < 128 := t.isLt
    show (if h : t.val < 128 then Rp.inp.isT ⟨t.val, h⟩ else false) = Rp.inp.isT t
    exact dite_eq_left ht
  have hk : ∀ t : shieldS0.Tok, (shdP_incPub Rp embDigest embFold).kappa t.val = Rp.inp.kap t := by
    intro t
    have ht : t.val < 128 := t.isLt
    show (if h : t.val < 128 then Rp.inp.kap ⟨t.val, h⟩ else 0) = Rp.inp.kap t
    exact dite_eq_left ht
  refine ⟨rfl, fun t => ?_, rfl, hT, hk, rfl⟩
  show ((shdP_incPub Rp embDigest embFold).isTemplate t.val
      && decide ((shdP_incPub Rp embDigest embFold).kappa t.val < (shdP_incPub Rp embDigest embFold).numSpecial))
    = decide (ctlPos Rp.inp t = 1)
  rw [hT t, hk t]
  show (Rp.inp.isT t && decide (Rp.inp.kap t < Rp.inp.ns)) = decide (ctlPos Rp.inp t = 1)
  unfold ctlPos ctl
  cases Rp.inp.isT t <;> by_cases h : Rp.inp.kap t < Rp.inp.ns <;> simp [h]

end ZK60.ProtocolClassify
