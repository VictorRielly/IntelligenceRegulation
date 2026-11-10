/-
D63 lane L57 (2026-11-10), part 1: **the stages' hosting, PROVED from the code's `define`s** (deliverable 1, the
premises `hhIn`, `hhOut` of lane L53's top theorems).

Lane L53's lists read each stage slot's claimed sum as the verifier does: its scalar plus, for each slot `j` it hosts,
slot `j`'s scalar times one of its own draws (`stgClaim`, with the hosting as data `hostOf k : List (ℕ × ℕ)`, pairs
`(j, draw index)`). The top theorem asked, as premises `hhIn`, `hhOut`, that `define`'s hosted list IS that data with
the drawn coefficients. Here the data is fixed and the premises are PROVED from lane L29's executable `define`s
(`incDefine`, `outcDefine`, line for line hashline's `stage_in_c.rs`, `stage_out_c.rs`):

* `stgHostIn`: stage IN-C hosts nothing (`sched.hosts = []`; every `finish(…, [])`);
* `stgHostOut P0`: stage OUT-C's TZC (slot 2) hosts SS (slot 1) with draw 5 (`ν`, after `τ` (1) and `μ` (4)); LZC
  (slot 4) hosts PD (slot 3) with draw `llo + 2` (`ν`, after `τ` (`llo`) and `μ` (2)), read off the lists' schedule
  `P0` as `P0.draws 4 − 1` (LZC draws `llo + 3`);
* the builder's last action fixes the hosted list (`sah_finishT`, `sah_build`, by the walk `sah_walk` over L29's
  slot builder, as lane L39's `rc_sb_walk`); `nz1`'s coefficient is the draw at its index (`sah_nz1`);
* **`sah_incDefine`**, **`sah_outcDefine`**: every definition that succeeds has that hosted list;
* **`stg_hhIn`**: `hhIn` for EVERY stage IN-C verifier (`inc : Hdr → IncV`), with `hostIn := stgHostIn`;
* **`stg_hhOut`**: `hhOut` for every stage OUT-C verifier whose lists' schedule `P0` has its draws (`hPout`, already a
  premise of the top theorem), with `hostOut := stgHostOut P0`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCoverDefine
import ZK60Formal.RunStgAlive

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.StageV
open ZK60.Exec.Block (SlotDef)

/-! ## The builder's last action fixes the hosted list -/

/-- Any builder action meets the trivial triple. -/
theorem sah_any {α : Type} (m : SBM α) : SBTr (fun _ => True) m (fun _ _ => True) :=
  fun _ _ _ _ _ => trivial

/-- **`finish(poly, hosted)` returns `hosted`** (when it accepts). -/
theorem sah_finishT (L : Lay) (slot : ℕ) (poly : List Fp2 → Fp2) (hosted : List (ℕ × Fp2)) :
    SBTr (fun _ => True) (finishT L slot poly hosted) (fun df _ => df.hosted = hosted) := by
  intro b df b' _ h
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
    rfl

/-- **A built definition meets what its program's triple gives.** -/
theorem sah_build {m : SBM SlotDef} {Q : SlotDef → Prop} (hm : SBTr (fun _ => True) m (fun df _ => Q df))
    {df : SlotDef} (h : build m = .ok df) : Q df := by
  unfold build at h
  cases hr : m.run {} with
  | error e =>
    rw [hr] at h
    cases h
  | ok p =>
    rw [hr] at h
    have h' : p.1 = df := Except.ok.inj h
    subst h'
    exact hm {} p.1 p.2 trivial hr

/- The builder's actions are opaque to the walk: only the program's binds are taken apart. -/
attribute [local irreducible] pushT eqT pubT aSliceT aAtT aT hT ioT finishT

/-- One step of the walk through a slot definition's builder program, to its `finish`. -/
macro "sah_walk" : tactic => `(tactic| repeat' (first
  | exact sah_finishT _ _ _ _
  | refine sbTr_bind (sah_any _) (fun _ => ?_)))

/-- **`nz1`'s coefficient is the draw at its index.** -/
theorem sah_nz1 (dr : List Fp2) (off : ℕ) (nu : Fp2) (h : nz1 dr off = .ok nu) : nu = dr.getD off Fp2.zero := by
  unfold nz1 nonzeroE at h
  split_ifs at h with hz
  · cases h
  · have h' : (Except.ok (((dr.drop off).take 1).getD 0 Fp2.zero) : Except String Fp2) = Except.ok nu := h
    rw [← Except.ok.inj h', List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD,
      List.getElem?_take_of_lt (by norm_num), List.getElem?_drop, Nat.add_zero]

/-! ## Stage IN-C hosts nothing -/

theorem sah_incDefIO (I : IncPub) (G : IncGeo) (dr : List Fp2) (df : SlotDef) (h : incDefIO I G dr = .ok df) :
    df.hosted = [] :=
  sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

theorem sah_incDefQZC (I : IncPub) (G : IncGeo) (cx : IncCtx) (dr : List Fp2) (df : SlotDef)
    (h : incDefQZC I G cx dr = .ok df) : df.hosted = [] := by
  unfold incDefQZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

theorem sah_incDefTZC (I : IncPub) (G : IncGeo) (cx : IncCtx) (dr : List Fp2) (df : SlotDef)
    (h : incDefTZC I G cx dr = .ok df) : df.hosted = [] := by
  unfold incDefTZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

theorem sah_incDefZS (I : IncPub) (G : IncGeo) (df : SlotDef) (h : incDefZS I G = .ok df) : df.hosted = [] :=
  sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

/-- **Every stage IN-C definition that succeeds hosts nothing** (stage_in_c.rs: `hosts: vec![]`, `finish(…, [])`). -/
theorem sah_incDefine (I : IncPub) (G : IncGeo) (cx : IncCtx) (s : ℕ) (hist : Block.Hist) (dr : List Fp2)
    (df : SlotDef) (h : incDefine I G cx s hist dr = .ok df) : df.hosted = [] :=
  match s, h with
  | 0, h => sah_incDefIO I G dr df h
  | 1, h => sah_incDefQZC I G cx dr df h
  | 2, h => sah_incDefTZC I G cx dr df h
  | 3, h => sah_incDefZS I G df h
  | _ + 4, h => by cases h

/-! ## Stage OUT-C: TZC hosts SS, LZC hosts PD -/

theorem sah_outcDefIO (O : OutcPub) (G : OutcGeo) (dr : List Fp2) (df : SlotDef) (h : outcDefIO O G dr = .ok df) :
    df.hosted = [] :=
  sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

theorem sah_outcDefSS (O : OutcPub) (G : OutcGeo) (df : SlotDef) (h : outcDefSS O G = .ok df) : df.hosted = [] :=
  sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

/-- **TZC hosts SS with `ν = draws[5]`.** -/
theorem sah_outcDefTZC (O : OutcPub) (G : OutcGeo) (dr : List Fp2) (df : SlotDef) (h : outcDefTZC O G dr = .ok df) :
    df.hosted = [(1, dr.getD 5 Fp2.zero)] := by
  unfold outcDefTZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨nu, hnu, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  rw [← sah_nz1 dr 5 nu hnu]
  exact sah_build (Q := fun df => df.hosted = [(1, nu)]) (by sah_walk) h

theorem sah_outcDefPD (O : OutcPub) (G : OutcGeo) (df : SlotDef) (h : outcDefPD O G = .ok df) : df.hosted = [] :=
  sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

/-- **LZC hosts PD with `ν = draws[llo + 2]`.** -/
theorem sah_outcDefLZC (O : OutcPub) (G : OutcGeo) (hist : Block.Hist) (dr : List Fp2) (df : SlotDef)
    (h : outcDefLZC O G hist dr = .ok df) : df.hosted = [(3, dr.getD (O.llo + 2) Fp2.zero)] := by
  unfold outcDefLZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨nu, hnu, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  rw [← sah_nz1 dr (O.llo + 2) nu hnu]
  exact sah_build (Q := fun df => df.hosted = [(3, nu)]) (by sah_walk) h

theorem sah_outcDefDZC (O : OutcPub) (G : OutcGeo) (hist : Block.Hist) (dr : List Fp2) (df : SlotDef)
    (h : outcDefDZC O G hist dr = .ok df) : df.hosted = [] := by
  unfold outcDefDZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

theorem sah_outcDefTAB (O : OutcPub) (G : OutcGeo) (hist : Block.Hist) (dr : List Fp2) (df : SlotDef)
    (h : outcDefTAB O G hist dr = .ok df) : df.hosted = [] := by
  unfold outcDefTAB at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

theorem sah_outcDefZS (O : OutcPub) (G : OutcGeo) (df : SlotDef) (h : outcDefZS O G = .ok df) : df.hosted = [] :=
  sah_build (Q := fun df => df.hosted = []) (by sah_walk) h

/-- **Stage OUT-C's hosting as data**: TZC (slot 2) hosts SS (slot 1) with draw 5; LZC (slot 4) hosts PD (slot 3) with
draw `P0.draws 4 − 1` (`llo + 2`, LZC drawing `llo + 3`). -/
def stgHostOut (P0 : Block.BlockParams) (k : ℕ) : List (ℕ × ℕ) :=
  if k = 2 then [(1, 5)] else if k = 4 then [(3, P0.draws 4 - 1)] else []

/-- **Stage IN-C's hosting as data**: none. -/
def stgHostIn (_k : ℕ) : List (ℕ × ℕ) := []

/-- **Every stage OUT-C definition that succeeds hosts as `stgHostOut` says**, at a schedule `P0` with the stage's
draws. -/
theorem sah_outcDefine (O : OutcPub) (G : OutcGeo) (P0 : Block.BlockParams) (hP0 : P0.draws = outcDraws O) (s : ℕ)
    (hist : Block.Hist) (dr : List Fp2) (df : SlotDef) (h : outcDefine O G s hist dr = .ok df) :
    df.hosted = (stgHostOut P0 s).map (fun x => (x.1, dr.getD x.2 Fp2.zero)) :=
  match s, h with
  | 0, h => by rw [sah_outcDefIO O G dr df h]; simp [stgHostOut]
  | 1, h => by rw [sah_outcDefSS O G df h]; simp [stgHostOut]
  | 2, h => by rw [sah_outcDefTZC O G dr df h]; simp [stgHostOut]
  | 3, h => by rw [sah_outcDefPD O G df h]; simp [stgHostOut]
  | 4, h => by
    rw [sah_outcDefLZC O G hist dr df h]
    have e : P0.draws 4 - 1 = O.llo + 2 := by
      rw [hP0]
      show O.llo + 2 + 1 - 1 = O.llo + 2
      omega
    simp [stgHostOut, e]
  | 5, h => by rw [sah_outcDefDZC O G hist dr df h]; simp [stgHostOut]
  | 6, h => by rw [sah_outcDefTAB O G hist dr df h]; simp [stgHostOut]
  | 7, h => by rw [sah_outcDefZS O G df h]; simp [stgHostOut]
  | _ + 8, h => by cases h

/-! ## The top theorem's premises `hhIn`, `hhOut` -/

theorem sah_incBp_define (V : IncV) (cx : IncCtx) : (V.bp cx).define = incDefine V.pub V.geo cx := rfl

theorem sah_outcBp_define (V : OutcV) : V.bp.define = outcDefine V.pub V.geo := rfl

/-- **`hhIn`, PROVED for every stage IN-C verifier**, with `hostIn := stgHostIn`. -/
theorem stg_hhIn {Hdr : Type} (inc : Hdr → IncV) :
    ∀ hd cx k hist dr df, ((inc hd).bp cx).define k hist dr = .ok df →
      df.hosted = (stgHostIn k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)) := by
  intro hd cx k hist dr df h
  rw [sah_incBp_define] at h
  exact sah_incDefine _ _ cx k hist dr df h

/-- **`hhOut`, PROVED for every stage OUT-C verifier** whose lists' schedule `P0` has its draws (`hPout`, a premise
of the top theorem), with `hostOut := stgHostOut P0`. -/
theorem stg_hhOut {Hdr : Type} (outc : Hdr → ℕ → OutcV) (P0 : Block.BlockParams)
    (hPout : ∀ hd v, StgSame P0 (outc hd v).bp) :
    ∀ hd v k hist dr df, (outc hd v).bp.define k hist dr = .ok df →
      df.hosted = (stgHostOut P0 k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)) := by
  intro hd v k hist dr df h
  rw [sah_outcBp_define] at h
  exact sah_outcDefine _ _ P0 (hPout hd v).1 k hist dr df h

end ZK60.ProtocolClassify
