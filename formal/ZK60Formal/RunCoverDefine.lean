/-
D63 lane L39 (2026-11-10), part 1a: **the stage slot definitions' claim counts**, by an invariant of L29's slot builder.

L29's stage definitions (`incDefine`, `outcDefine`, `StageVerifyExecInC.lean`, `StageVerifyExecOutC.lean`) build each
slot's tables with the code's slot builder `SB` (`SBM`: a state of the tables pushed and the `A`, `H`, IO sites used).
`finish` checks the site counters against the declared schedule. The builder's invariant `SBInv cmIO cmX`: the `A`, `H`
and IO site counters count the private tables on `A`, on `H` and on the slot's IO commitment `cmIO`, and no table is on
the other IO commitment `cmX`. Every builder action keeps it (`SBTr`, a Hoare triple on `SBM`); so every slot definition
that succeeds has exactly the schedule's claim counts per commitment. (Evaluating a definition by `rfl` costs memory
exponential in its length; the invariant is checked action by action.)

* `rc_cmCount_append`; `SBInv`, `SBTr`, `sbTr_bind`, `sbTr_pure`, `sbTr_pushT`, `sbTr_eqT`, `sbTr_pubT`,
  `sbTr_aSliceT`, `sbTr_aAtT`, `sbTr_aT`, `sbTr_hT`, `sbTr_ioT`, `sbTr_forIn`, `sbTr_finishT`, `rc_build_cnt`;
* `rcCnt`, `rcIncCnt`, **`rc_incDefine`**: every stage IN-C definition that succeeds has the counts `(A, H, In, Out)`
  `(1,0,1,0)`, `(1,1,0,1)`, `(1,1,0,0)`, `(0,1,0,0)`;
* `rcOutcCnt`, **`rc_outcDefine`**: stage OUT-C's, `(1,0,1,0)`, `(1,0,0,0)`, `(11,0,0,0)`, `(1,0,0,0)`, `(1,1,0,0)`,
  `(13,6,0,0)`, `(1,1,0,0)`, `(0,1,0,0)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StageVerifyExecInC
import ZK60Formal.StageVerifyExecOutC
import ZK60Formal.BlockInstRead
import ZK60Formal.ProtocolClassify

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.StageV
open ZK60.Exec.Block (Cm Tab SlotDef cmCount Coord)

/-! ## The builder's invariant -/

theorem rc_cmCount_append (cm : Cm) : ∀ (l₁ l₂ : List Tab), cmCount cm (l₁ ++ l₂) = cmCount cm l₁ + cmCount cm l₂
  | [], l₂ => (Nat.zero_add _).symm
  | .priv p :: l₁, l₂ => by
    show (if p.cm = cm then 1 else 0) + cmCount cm (l₁ ++ l₂)
      = (if p.cm = cm then 1 else 0) + cmCount cm l₁ + cmCount cm l₂
    rw [rc_cmCount_append cm l₁ l₂, Nat.add_assoc]
  | .eq _ _ :: l₁, l₂ => rc_cmCount_append cm l₁ l₂
  | .pub _ :: l₁, l₂ => rc_cmCount_append cm l₁ l₂

/-- **The builder's invariant** for a slot whose IO sites are on `cmIO`: the `A`, `H` and IO site counters count the
private tables on `A`, on `H` and on `cmIO`, and no private table is on `cmX`. -/
def SBInv (cmIO cmX : Cm) (b : SBS) : Prop :=
  cmCount .a b.tabs = b.ak ∧ cmCount .h b.tabs = b.hk ∧ cmCount cmIO b.tabs = b.iok ∧ cmCount cmX b.tabs = 0

theorem sbInv_empty (cmIO cmX : Cm) : SBInv cmIO cmX {} := by
  unfold SBInv
  exact ⟨rfl, rfl, rfl, rfl⟩

/-- **A builder action's triple**: from a state meeting `P`, an accepted run ends in a result and state meeting `Q`. -/
def SBTr {α : Type} (P : SBS → Prop) (m : SBM α) (Q : α → SBS → Prop) : Prop :=
  ∀ b a b', P b → m.run b = .ok (a, b') → Q a b'

theorem sbTr_bind {α β : Type} {P : SBS → Prop} {R : α → SBS → Prop} {Q : β → SBS → Prop} {m : SBM α}
    {f : α → SBM β} (hm : SBTr P m R) (hf : ∀ a, SBTr (R a) (f a) Q) : SBTr P (m >>= f) Q := by
  intro b c b'' hb h
  rw [StateT.run_bind] at h
  obtain ⟨⟨a, b'⟩, h1, h2⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact hf a b' c b'' (hm b a b' hb h1) h2

theorem sbTr_pure {α : Type} {I : SBS → Prop} (a : α) : SBTr I (pure a) (fun _ => I) := by
  intro b a' b' hb h
  rw [StateT.run_pure] at h
  have h' : (a, b) = (a', b') := Except.ok.inj h
  rw [← (Prod.mk.inj h').2]
  exact hb

theorem rc_pushT_run (t : Tab) (b : SBS) : (pushT t).run b = .ok (b.tabs.length, { b with tabs := b.tabs ++ [t] }) :=
  rfl

theorem sbTr_pushT (cmIO cmX : Cm) (t : Tab) (ha : cmCount .a [t] = 0) (hh : cmCount .h [t] = 0)
    (hio : cmCount cmIO [t] = 0) (hx : cmCount cmX [t] = 0) :
    SBTr (SBInv cmIO cmX) (pushT t) (fun _ => SBInv cmIO cmX) := by
  intro b a b' hb h
  rw [rc_pushT_run] at h
  have h' := (Prod.mk.inj (Except.ok.inj h)).2
  subst h'
  unfold SBInv at hb ⊢
  obtain ⟨h1, h2, h3, h4⟩ := hb
  refine ⟨?_, ?_, ?_, ?_⟩
  · show cmCount .a (b.tabs ++ [t]) = b.ak
    rw [rc_cmCount_append, h1, ha, Nat.add_zero]
  · show cmCount .h (b.tabs ++ [t]) = b.hk
    rw [rc_cmCount_append, h2, hh, Nat.add_zero]
  · show cmCount cmIO (b.tabs ++ [t]) = b.iok
    rw [rc_cmCount_append, h3, hio, Nat.add_zero]
  · show cmCount cmX (b.tabs ++ [t]) = 0
    rw [rc_cmCount_append, h4, hx]

theorem sbTr_eqT (cmIO cmX : Cm) (point : List Fp2) (start : ℕ) :
    SBTr (SBInv cmIO cmX) (eqT point start) (fun _ => SBInv cmIO cmX) :=
  sbTr_pushT cmIO cmX _ rfl rfl rfl rfl

theorem sbTr_pubT (cmIO cmX : Cm) (v : List Fp2) : SBTr (SBInv cmIO cmX) (pubT v) (fun _ => SBInv cmIO cmX) :=
  sbTr_pushT cmIO cmX _ rfl rfl rfl rfl

/-- The run of an action that reads the state, asks an `Except` check, sets the state and pushes one table. -/
theorem rc_shape_run {E : Type} (e : SBS → Except String E) (g : SBS → SBS) (t : SBS → E → Tab) (b0 : SBS) :
    (do let b ← get; let r ← (e b : Except String E); set (g b); pushT (t b r) : SBM ℕ).run b0
      = Except.bind (Except.bind (e b0) (fun a => Except.ok (a, b0)))
          (fun p => Except.ok ((g b0).tabs.length, { g b0 with tabs := (g b0).tabs ++ [t b0 p.1] })) :=
  rfl

theorem rc_shape_ok {E : Type} (e : SBS → Except String E) (g : SBS → SBS) (t : SBS → E → Tab) (b0 : SBS) (a : ℕ)
    (b' : SBS) (h : (do let b ← get; let r ← (e b : Except String E); set (g b); pushT (t b r) : SBM ℕ).run b0
      = .ok (a, b')) :
    ∃ r, e b0 = .ok r ∧ b' = { g b0 with tabs := (g b0).tabs ++ [t b0 r] } := by
  rw [rc_shape_run] at h
  cases he : e b0 with
  | error err =>
    rw [he] at h
    cases h
  | ok r =>
    rw [he] at h
    exact ⟨r, rfl, (Prod.mk.inj (Except.ok.inj h)).2.symm⟩

theorem sbTr_aSliceT (cmIO cmX : Cm) (hIO : cmIO ≠ .a) (hX : cmX ≠ .a) (L : Lay) (slot off log : ℕ)
    (coords : List Coord) : SBTr (SBInv cmIO cmX) (aSliceT L slot off log coords) (fun _ => SBInv cmIO cmX) := by
  intro b a b' hb h
  obtain ⟨r, -, rfl⟩ := rc_shape_ok (fun b => L.aSite slot b.ak) (fun b => { b with ak := b.ak + 1 })
    (fun _ r => .priv ⟨.a, [(off, Fp2.one)], log, coords, r, 0⟩) b a b' h
  unfold SBInv at hb ⊢
  obtain ⟨h1, h2, h3, h4⟩ := hb
  have e1 : ∀ cm, cmCount cm [Tab.priv ⟨.a, [(off, Fp2.one)], log, coords, r, 0⟩] = if Cm.a = cm then 1 else 0 :=
    fun _ => rfl
  refine ⟨?_, ?_, ?_, ?_⟩
  · show cmCount .a (b.tabs ++ _) = b.ak + 1
    rw [rc_cmCount_append, h1, e1]
    rfl
  · show cmCount .h (b.tabs ++ _) = b.hk
    rw [rc_cmCount_append, h2, e1]
    rfl
  · show cmCount cmIO (b.tabs ++ _) = b.iok
    rw [rc_cmCount_append, h3, e1, ite_eq_right (Ne.symm hIO), Nat.add_zero]
  · show cmCount cmX (b.tabs ++ _) = 0
    rw [rc_cmCount_append, h4, e1, ite_eq_right (Ne.symm hX)]

theorem sbTr_aAtT (cmIO cmX : Cm) (hIO : cmIO ≠ .a) (hX : cmX ≠ .a) (L : Lay) (slot plane : ℕ)
    (coords : List Coord) : SBTr (SBInv cmIO cmX) (aAtT L slot plane coords) (fun _ => SBInv cmIO cmX) :=
  sbTr_aSliceT cmIO cmX hIO hX L slot _ _ coords

theorem sbTr_aT (cmIO cmX : Cm) (hIO : cmIO ≠ .a) (hX : cmX ≠ .a) (L : Lay) (slot plane : ℕ) :
    SBTr (SBInv cmIO cmX) (aT L slot plane) (fun _ => SBInv cmIO cmX) :=
  sbTr_aSliceT cmIO cmX hIO hX L slot _ _ _

theorem sbTr_hT (cmIO cmX : Cm) (hIO : cmIO ≠ .h) (hX : cmX ≠ .h) (L : Lay) (slot plane : ℕ) :
    SBTr (SBInv cmIO cmX) (hT L slot plane) (fun _ => SBInv cmIO cmX) := by
  intro b a b' hb h
  obtain ⟨r, -, rfl⟩ := rc_shape_ok (fun b => L.hSite slot b.hk) (fun b => { b with hk := b.hk + 1 })
    (fun _ r => .priv ⟨.h, [((L.hOff plane).1, Fp2.one), ((L.hOff plane).2, Block.fp2U)], L.hLog.getD plane 0,
      rhoC 0 (L.hLog.getD plane 0), r, 0⟩) b a b' h
  unfold SBInv at hb ⊢
  obtain ⟨h1, h2, h3, h4⟩ := hb
  have e1 : ∀ cm, cmCount cm [Tab.priv ⟨.h, [((L.hOff plane).1, Fp2.one), ((L.hOff plane).2, Block.fp2U)],
      L.hLog.getD plane 0, rhoC 0 (L.hLog.getD plane 0), r, 0⟩] = if Cm.h = cm then 1 else 0 := fun _ => rfl
  refine ⟨?_, ?_, ?_, ?_⟩
  · show cmCount .a (b.tabs ++ _) = b.ak
    rw [rc_cmCount_append, h1, e1]
    rfl
  · show cmCount .h (b.tabs ++ _) = b.hk + 1
    rw [rc_cmCount_append, h2, e1]
    rfl
  · show cmCount cmIO (b.tabs ++ _) = b.iok
    rw [rc_cmCount_append, h3, e1, ite_eq_right (Ne.symm hIO), Nat.add_zero]
  · show cmCount cmX (b.tabs ++ _) = 0
    rw [rc_cmCount_append, h4, e1, ite_eq_right (Ne.symm hX)]

theorem rc_ioT_run (cm : Cm) (log : ℕ) (coords : List Coord) (maskRow : ℕ) (b : SBS) :
    (ioT cm log coords maskRow).run b
      = .ok (b.tabs.length, ⟨b.tabs ++ [.priv ⟨cm, [(0, Fp2.one)], log, coords, maskRow, 0⟩], b.ak, b.hk, b.iok + 1⟩) :=
  rfl

theorem sbTr_ioT (cmIO cmX : Cm) (ha : cmIO ≠ .a) (hh : cmIO ≠ .h) (hx : cmIO ≠ cmX) (log : ℕ) (coords : List Coord)
    (maskRow : ℕ) : SBTr (SBInv cmIO cmX) (ioT cmIO log coords maskRow) (fun _ => SBInv cmIO cmX) := by
  intro b a b' hb h
  rw [rc_ioT_run] at h
  have h' := (Prod.mk.inj (Except.ok.inj h)).2
  subst h'
  unfold SBInv at hb ⊢
  obtain ⟨h1, h2, h3, h4⟩ := hb
  have e1 : ∀ cm, cmCount cm [Tab.priv ⟨cmIO, [(0, Fp2.one)], log, coords, maskRow, 0⟩]
      = if cmIO = cm then 1 else 0 := fun _ => rfl
  refine ⟨?_, ?_, ?_, ?_⟩
  · show cmCount .a (b.tabs ++ _) = b.ak
    rw [rc_cmCount_append, h1, e1, ite_eq_right ha, Nat.add_zero]
  · show cmCount .h (b.tabs ++ _) = b.hk
    rw [rc_cmCount_append, h2, e1, ite_eq_right hh, Nat.add_zero]
  · show cmCount cmIO (b.tabs ++ _) = b.iok + 1
    rw [rc_cmCount_append, h3, e1, ite_eq_left rfl]
  · show cmCount cmX (b.tabs ++ _) = 0
    rw [rc_cmCount_append, h4, e1, ite_eq_right hx]

theorem sbTr_forIn {γ β : Type} {I : SBS → Prop} (f : γ → β → SBM (ForInStep β))
    (hf : ∀ x r, SBTr I (f x r) (fun _ => I)) : ∀ (l : List γ) (init : β), SBTr I (forIn l init f) (fun _ => I)
  | [], init => by
    rw [List.forIn_nil]
    exact sbTr_pure init
  | x :: l, init => by
    rw [List.forIn_cons]
    refine sbTr_bind (hf x init) fun r => ?_
    cases r with
    | done b => exact sbTr_pure b
    | yield b => exact sbTr_forIn f hf l b

/-- **A finished slot definition's counts**: the private tables on `A`, on `H` and on the slot's IO commitment number
the schedule's sites; none is on the other IO commitment. -/
def SBCnt (cmIO cmX : Cm) (L : Lay) (s : ℕ) (df : SlotDef) : Prop :=
  cmCount .a df.tabs = (L.spec s).aSites ∧ cmCount .h df.tabs = (L.spec s).hSites
    ∧ cmCount cmIO df.tabs = (L.spec s).ioSites ∧ cmCount cmX df.tabs = 0

theorem sbTr_finishT (cmIO cmX : Cm) (L : Lay) (slot : ℕ) (poly : List Fp2 → Fp2) (hosted : List (ℕ × Fp2)) :
    SBTr (SBInv cmIO cmX) (finishT L slot poly hosted) (fun df _ => SBCnt cmIO cmX L slot df) := by
  intro b df b' hb h
  unfold finishT at h
  rw [StateT.run_bind] at h
  obtain ⟨⟨b1, b2⟩, h1, h2⟩ := (ex_bind_ok_iff _ _ _).mp h
  rw [StateT.run_get] at h1
  have e1 : (b, b) = (b1, b2) := Except.ok.inj h1
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj e1
  simp only at h2
  split_ifs at h2 with hc
  · cases h2
  · rw [StateT.run_pure] at h2
    have e2 := (Prod.mk.inj (Except.ok.inj h2)).1
    subst e2
    unfold SBInv at hb
    unfold SBCnt
    obtain ⟨ha, hh, hio, hx⟩ := hb
    simp only [not_or, ne_eq, not_not] at hc
    obtain ⟨c1, c2, c3⟩ := hc
    exact ⟨ha.trans c1, hh.trans c2, hio.trans c3, hx⟩

/-- **A built definition meets what its program's triple gives** (from the empty state). -/
theorem rc_build_cnt {m : SBM SlotDef} {cmIO cmX : Cm} {Q : SlotDef → Prop}
    (hm : SBTr (SBInv cmIO cmX) m (fun df _ => Q df)) {df : SlotDef} (h : build m = .ok df) : Q df := by
  unfold build at h
  cases hr : m.run {} with
  | error e =>
    rw [hr] at h
    cases h
  | ok p =>
    rw [hr] at h
    have h' : p.1 = df := Except.ok.inj h
    subst h'
    exact hm {} p.1 p.2 (sbInv_empty cmIO cmX) hr

/- The builder's actions are opaque to the walk below: a walk step that does not match the program's next action then
fails at once, instead of evaluating the program during unification. -/
attribute [local irreducible] pushT eqT pubT aSliceT aAtT aT hT ioT finishT

/-- One step of the walk through a slot definition's builder program. -/
macro "rc_sb_walk" : tactic => `(tactic| repeat' (first
  | exact sbTr_finishT _ _ _ _ _ _
  | exact sbTr_pure _
  | refine sbTr_bind (sbTr_eqT _ _ _ _) (fun _ => ?_)
  | refine sbTr_bind (sbTr_pubT _ _ _) (fun _ => ?_)
  | refine sbTr_bind (sbTr_aT _ _ (by decide) (by decide) _ _ _) (fun _ => ?_)
  | refine sbTr_bind (sbTr_aAtT _ _ (by decide) (by decide) _ _ _ _) (fun _ => ?_)
  | refine sbTr_bind (sbTr_aSliceT _ _ (by decide) (by decide) _ _ _ _ _) (fun _ => ?_)
  | refine sbTr_bind (sbTr_hT _ _ (by decide) (by decide) _ _ _) (fun _ => ?_)
  | refine sbTr_bind (sbTr_ioT _ _ (by decide) (by decide) (by decide) _ _ _) (fun _ => ?_)
  | refine sbTr_bind (sbTr_forIn _ (fun _ _ => ?_) _ _) (fun _ => ?_)))

/-! ## The counts of stage IN-C's and stage OUT-C's definitions -/

/-- A slot definition's claim counts per commitment: `(A, H, In, Out)`. -/
def rcCnt (df : SlotDef) : ℕ × ℕ × ℕ × ℕ :=
  (cmCount .a df.tabs, cmCount .h df.tabs, cmCount .inp df.tabs, cmCount .out df.tabs)

theorem rc_cnt_inp {L : Lay} {s : ℕ} {df : SlotDef} (h : SBCnt .inp .out L s df) :
    rcCnt df = ((L.spec s).aSites, (L.spec s).hSites, (L.spec s).ioSites, 0) := by
  unfold SBCnt at h
  obtain ⟨h1, h2, h3, h4⟩ := h
  simp only [rcCnt, h1, h2, h3, h4]

theorem rc_cnt_out {L : Lay} {s : ℕ} {df : SlotDef} (h : SBCnt .out .inp L s df) :
    rcCnt df = ((L.spec s).aSites, (L.spec s).hSites, 0, (L.spec s).ioSites) := by
  unfold SBCnt at h
  obtain ⟨h1, h2, h3, h4⟩ := h
  simp only [rcCnt, h1, h2, h3, h4]

/-- **Stage IN-C's claim counts per slot** (stage_in_c.rs:166-238): INC-00 `A tok`, `In end`; INC-01 `A tok`, `H h_q`,
`Out B_in`; INC-02 `A mult`, `H h_tab`; INC-03 `H u`. -/
def rcIncCnt : ℕ → ℕ × ℕ × ℕ × ℕ
  | 0 => (1, 0, 1, 0)
  | 1 => (1, 1, 0, 1)
  | 2 => (1, 1, 0, 0)
  | 3 => (0, 1, 0, 0)
  | _ => (0, 0, 0, 0)

theorem rc_incDefIO (I : IncPub) (G : IncGeo) (dr : List Fp2) (df : SlotDef) (h : incDefIO I G dr = .ok df) :
    rcCnt df = (1, 0, 1, 0) :=
  (rc_cnt_inp (L := incLay I G.bLogN) (s := 0)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_incDefQZC (I : IncPub) (G : IncGeo) (cx : IncCtx) (dr : List Fp2) (df : SlotDef)
    (h : incDefQZC I G cx dr = .ok df) : rcCnt df = (1, 1, 0, 1) := by
  unfold incDefQZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact (rc_cnt_out (L := incLay I G.bLogN) (s := 1)
    (rc_build_cnt (cmIO := .out) (cmX := .inp) (by rc_sb_walk) h)).trans rfl

theorem rc_incDefTZC (I : IncPub) (G : IncGeo) (cx : IncCtx) (dr : List Fp2) (df : SlotDef)
    (h : incDefTZC I G cx dr = .ok df) : rcCnt df = (1, 1, 0, 0) := by
  unfold incDefTZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact (rc_cnt_inp (L := incLay I G.bLogN) (s := 2)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_incDefZS (I : IncPub) (G : IncGeo) (df : SlotDef) (h : incDefZS I G = .ok df) :
    rcCnt df = (0, 1, 0, 0) :=
  (rc_cnt_inp (L := incLay I G.bLogN) (s := 3)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

/-- **Every stage IN-C definition that succeeds has the schedule's claim counts.** -/
theorem rc_incDefine (I : IncPub) (G : IncGeo) (cx : IncCtx) (s : ℕ) (hist : Block.Hist) (dr : List Fp2)
    (df : SlotDef) (h : incDefine I G cx s hist dr = .ok df) : rcCnt df = rcIncCnt s :=
  match s, h with
  | 0, h => rc_incDefIO I G dr df h
  | 1, h => rc_incDefQZC I G cx dr df h
  | 2, h => rc_incDefTZC I G cx dr df h
  | 3, h => rc_incDefZS I G df h
  | _ + 4, h => by cases h

/-- **Stage OUT-C's claim counts per slot** (stage_out_c.rs:283-429): IO `A x`, `In B_out`; SS `A x`; TZC `A D`,
`A Dsq` and nine limb slices; PD `A y`; LZC `A limb`, `H h_lo`; DZC twelve `Do` planes and `A D`, six helpers; TAB
`A mult`, `H h_gu8`; ZS `H u`. -/
def rcOutcCnt : ℕ → ℕ × ℕ × ℕ × ℕ
  | 0 => (1, 0, 1, 0)
  | 1 => (1, 0, 0, 0)
  | 2 => (11, 0, 0, 0)
  | 3 => (1, 0, 0, 0)
  | 4 => (1, 1, 0, 0)
  | 5 => (13, 6, 0, 0)
  | 6 => (1, 1, 0, 0)
  | 7 => (0, 1, 0, 0)
  | _ => (0, 0, 0, 0)

theorem rc_outcDefIO (O : OutcPub) (G : OutcGeo) (dr : List Fp2) (df : SlotDef) (h : outcDefIO O G dr = .ok df) :
    rcCnt df = (1, 0, 1, 0) :=
  (rc_cnt_inp (L := outcLay O G.bLogN) (s := 0)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_outcDefSS (O : OutcPub) (G : OutcGeo) (df : SlotDef) (h : outcDefSS O G = .ok df) :
    rcCnt df = (1, 0, 0, 0) :=
  (rc_cnt_inp (L := outcLay O G.bLogN) (s := 1)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_outcDefTZC (O : OutcPub) (G : OutcGeo) (dr : List Fp2) (df : SlotDef) (h : outcDefTZC O G dr = .ok df) :
    rcCnt df = (11, 0, 0, 0) := by
  unfold outcDefTZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨nu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact (rc_cnt_inp (L := outcLay O G.bLogN) (s := 2)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_outcDefPD (O : OutcPub) (G : OutcGeo) (df : SlotDef) (h : outcDefPD O G = .ok df) :
    rcCnt df = (1, 0, 0, 0) :=
  (rc_cnt_inp (L := outcLay O G.bLogN) (s := 3)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_outcDefLZC (O : OutcPub) (G : OutcGeo) (hist : Block.Hist) (dr : List Fp2) (df : SlotDef)
    (h : outcDefLZC O G hist dr = .ok df) : rcCnt df = (1, 1, 0, 0) := by
  unfold outcDefLZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨nu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact (rc_cnt_inp (L := outcLay O G.bLogN) (s := 4)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_outcDefDZC (O : OutcPub) (G : OutcGeo) (hist : Block.Hist) (dr : List Fp2) (df : SlotDef)
    (h : outcDefDZC O G hist dr = .ok df) : rcCnt df = (13, 6, 0, 0) := by
  unfold outcDefDZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact (rc_cnt_inp (L := outcLay O G.bLogN) (s := 5)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_outcDefTAB (O : OutcPub) (G : OutcGeo) (hist : Block.Hist) (dr : List Fp2) (df : SlotDef)
    (h : outcDefTAB O G hist dr = .ok df) : rcCnt df = (1, 1, 0, 0) := by
  unfold outcDefTAB at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact (rc_cnt_inp (L := outcLay O G.bLogN) (s := 6)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

theorem rc_outcDefZS (O : OutcPub) (G : OutcGeo) (df : SlotDef) (h : outcDefZS O G = .ok df) :
    rcCnt df = (0, 1, 0, 0) :=
  (rc_cnt_inp (L := outcLay O G.bLogN) (s := 7)
    (rc_build_cnt (cmIO := .inp) (cmX := .out) (by rc_sb_walk) h)).trans rfl

/-- **Every stage OUT-C definition that succeeds has the schedule's claim counts.** -/
theorem rc_outcDefine (O : OutcPub) (G : OutcGeo) (s : ℕ) (hist : Block.Hist) (dr : List Fp2) (df : SlotDef)
    (h : outcDefine O G s hist dr = .ok df) : rcCnt df = rcOutcCnt s :=
  match s, h with
  | 0, h => rc_outcDefIO O G dr df h
  | 1, h => rc_outcDefSS O G df h
  | 2, h => rc_outcDefTZC O G dr df h
  | 3, h => rc_outcDefPD O G df h
  | 4, h => rc_outcDefLZC O G hist dr df h
  | 5, h => rc_outcDefDZC O G hist dr df h
  | 6, h => rc_outcDefTAB O G hist dr df h
  | 7, h => rc_outcDefZS O G df h
  | _ + 8, h => by cases h

end ZK60.ProtocolClassify
