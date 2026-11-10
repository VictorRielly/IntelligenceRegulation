/-
D63 lane L35 (2026-11-09), part 4: **a block's `define` as DATA** (a slot program) and the function that runs it.

`argument::define` builds, per slot, a table list, a round polynomial and a hosted list out of (a) the block's layout,
which is a function of the shape alone, and (b) the transcript's own values: the LogUp challenges and the draws of this
slot and of the earlier ones (L9-3). Here (a) is a value, `SlotS`, in which every coefficient and every challenge
word is an EXPRESSION `Sym` in the transcript's values, and (b) is `Sym.eval`. So

* a profile's `define` is `defineS prog pubs`: `prog` the profile's slot programs (a list, closed data), `pubs` its
  public tables (a function of the block's public statement, left opaque);
* every fact that does not depend on the challenges' values is a fact about `prog`, checkable by evaluation:
  how many private tables sit in each commitment (`cmCountS`, `cmCount_eval`), the tables' shapes (`tabOKb`,
  `tabOK_eval`), the round polynomial's degree in its tables (`irDeg`, which `Ir.map` does not change);
* every challenge word is canonical when the transcript's are (`Sym.eval_canon`), so the slot IR is canonical
  (`Ir.canon_map`) and its word evaluation is its evaluation in the field (L11's `toK_irEvalW`).

`defineS` refuses a non-canonical challenge word (`HistCanon`). The code's field type holds reduced words only, so the
code never meets one, and the verifier's own challenges are canonical: the verdict on every transcript is the code's
(finding L35-1). It also carries the code's `nonzero(ν)`, `nonzero(ζ)` refusals (`SlotS.nonzero`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockDefineTab

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Slot
open ZK60.Circuit (gP GF)

/-! ## Expressions in the transcript's values -/

/-- **A coefficient or a challenge word, as the code computes it**: the constants a builder writes (`Coef::one`,
`neg_one`, `zero`, `Fp2::from_i64`, the `2^(16k)` and `256^k` limb weights, `Fp2::from_u64`), the LogUp challenges
`α`, `β` and a table tag `γ·tag`, a draw of this slot's or an earlier slot's `define`, and the field operations. -/
inductive Sym where
  | one
  | negOne
  | zero
  | base (v : ℤ)
  | p16 (k : ℕ)
  | p256 (k : ℕ)
  | u64 (n : ℕ)
  | alpha
  | beta
  | gtag (tag : ℕ)
  | dr (slot i : ℕ)
  | add (a b : Sym)
  | sub (a b : Sym)
  | mul (a b : Sym)
  | neg (a : Sym)
  | pow (a : Sym) (j : ℕ)

/-- `ζ^j` as `IrPad` computes it: `ONE` multiplied `j` times. -/
def zpowW (z : Fp2) (j : ℕ) : Fp2 := (List.range j).foldl (fun a _ => a.mul z) Fp2.one

/-- Draw `i` of slot `slot`'s `define`, at slot `k` (whose own draws are `dr`; the earlier ones are the history's). -/
def drawAt (hist : Hist) (k : ℕ) (dr : List Fp2) (slot i : ℕ) : Fp2 :=
  if slot = k then dr.getD i Fp2.zero else (hist.draws.getD slot []).getD i Fp2.zero

/-- **The word an expression denotes** at slot `k`, on the history and the slot's draws. -/
def Sym.eval (hist : Hist) (k : ℕ) (dr : List Fp2) : Sym → Fp2
  | .one => Fp2.one
  | .negOne => Fp2.one.neg
  | .zero => Fp2.zero
  | .base v => Fp2.fromBase (Fp.fromI64 v)
  | .p16 j => Fp2.fromBase (Fp.new (UInt64.ofNat (2 ^ (16 * j))))
  | .p256 j => Fp2.fromU64 (UInt64.ofNat (2 ^ (8 * j)))
  | .u64 n => Fp2.fromU64 (UInt64.ofNat n)
  | .alpha => hist.alpha
  | .beta => hist.beta
  | .gtag t => hist.gamma.mulBase (Fp.new (UInt64.ofNat t))
  | .dr slot i => drawAt hist k dr slot i
  | .add a b => (a.eval hist k dr).add (b.eval hist k dr)
  | .sub a b => (a.eval hist k dr).sub (b.eval hist k dr)
  | .mul a b => (a.eval hist k dr).mul (b.eval hist k dr)
  | .neg a => (a.eval hist k dr).neg
  | .pow a j => zpowW (a.eval hist k dr) j

/-- **The transcript's values `define` reads are canonical words**: `α`, `β`, the earlier draws and this slot's.
(`γ` enters only through `mul_base`, whose output is canonical on any word.) -/
def HistCanon (hist : Hist) (dr : List Fp2) : Prop :=
  hist.alpha.Canon ∧ hist.beta.Canon ∧ (∀ l ∈ hist.draws, ∀ x ∈ l, x.Canon) ∧ ∀ x ∈ dr, x.Canon

instance (hist : Hist) (dr : List Fp2) : Decidable (HistCanon hist dr) := by
  unfold HistCanon
  infer_instance

theorem drawAt_canon {hist : Hist} {k : ℕ} {dr : List Fp2} (h : HistCanon hist dr) (slot i : ℕ) :
    (drawAt hist k dr slot i).Canon := by
  unfold drawAt
  by_cases hs : slot = k
  · rw [ite_eq_left hs]
    exact Fp2.canon_getD h.2.2.2 i
  · rw [ite_eq_right hs]
    refine Fp2.canon_getD (fun x hx => ?_) i
    rw [List.getD_eq_getElem?_getD] at hx
    cases hl : hist.draws[slot]? with
    | none =>
      rw [hl] at hx
      simp at hx
    | some l =>
      rw [hl] at hx
      exact h.2.2.1 l (List.mem_of_getElem? hl) x hx

/-- **Every expression denotes a canonical word** on a canonical transcript. -/
theorem Sym.eval_canon {hist : Hist} {k : ℕ} {dr : List Fp2} (h : HistCanon hist dr) (s : Sym) :
    (s.eval hist k dr).Canon := by
  induction s with
  | one => exact Fp2.canon_one
  | negOne =>
    show (Fp2.one.neg).Canon
    exact And.intro (Fp.neg_canon _ Fp2.canon_one.1) (Fp.neg_canon _ Fp2.canon_one.2)
  | zero => exact Fp2.canon_zero
  | base v =>
    show (Fp2.fromBase (Fp.fromI64 v)).Canon
    refine Fp2.canon_fromBase _ ?_
    unfold Fp.fromI64
    split_ifs <;> exact Fp.new_canon _
  | p16 j =>
    show (Fp2.fromBase (Fp.new (UInt64.ofNat (2 ^ (16 * j))))).Canon
    exact Fp2.canon_fromBase _ (Fp.new_canon _)
  | p256 j =>
    show (Fp2.fromU64 (UInt64.ofNat (2 ^ (8 * j)))).Canon
    exact Fp2.canon_fromU64 _
  | u64 n =>
    show (Fp2.fromU64 (UInt64.ofNat n)).Canon
    exact Fp2.canon_fromU64 _
  | alpha => exact h.1
  | beta => exact h.2.1
  | gtag t =>
    show (hist.gamma.mulBase (Fp.new (UInt64.ofNat t))).Canon
    exact Fp2.canon_mulBase _ _
  | dr slot i => exact drawAt_canon h slot i
  | add a b _ _ =>
    show ((a.eval hist k dr).add (b.eval hist k dr)).Canon
    exact Fp2.canon_add _ _
  | sub a b iha ihb =>
    show ((a.eval hist k dr).sub (b.eval hist k dr)).Canon
    exact Fp2.canon_sub _ _ iha ihb
  | mul a b _ _ =>
    show ((a.eval hist k dr).mul (b.eval hist k dr)).Canon
    exact Fp2.canon_mul _ _
  | neg a ih =>
    show ((a.eval hist k dr).neg).Canon
    exact And.intro (Fp.neg_canon _ ih.1) (Fp.neg_canon _ ih.2)
  | pow a j _ =>
    show (zpowW (a.eval hist k dr) j).Canon
    exact canon_foldl_mul (fun _ => a.eval hist k dr) _ _ Fp2.canon_one

/-- An IR whose coefficients are read by a map into canonical words is canonical. -/
theorem Ir.canon_map {α : Type} (f : α → Fp2) (hf : ∀ a, (f a).Canon) (ir : Ir α) : (ir.map f).Canon := by
  refine And.intro (fun b hb => ?_) (fun t ht => ?_)
  · obtain ⟨b', -, rfl⟩ := List.mem_map.mp hb
    cases b' with
    | affine c ts => exact hf c
    | sum ss =>
      show ∀ s ∈ ss.map (SubTerm.map f), s.coef.Canon
      intro s hs
      obtain ⟨s', -, rfl⟩ := List.mem_map.mp hs
      exact hf s'.coef
  · obtain ⟨t', -, rfl⟩ := List.mem_map.mp ht
    exact hf t'.coef

/-! ## A slot program -/

/-- A coordinate of a private table's claim point. -/
inductive CoordS where
  | rho (k : ℕ)
  | flip (k : ℕ)
  | fixed (v : Sym)

/-- A private table: its commitment, its slices `(offset, is the imaginary half)` (coefficient `1`, or `u` for the
imaginary half of an `H` plane), its log size, its coordinates, its reserved mask pair's first row, its extension
round. -/
structure PrivS where
  cm : Cm
  slices : List (ℕ × Bool)
  log : ℕ
  coords : List CoordS
  maskRow : ℕ
  extRound : ℕ

/-- A table of a slot: `eq` over a point of expressions, the slot's `i`-th public table, or a private table. -/
inductive TabS where
  | eq (point : List Sym) (start : ℕ)
  | pub (i : ℕ)
  | priv (p : PrivS)

/-- **One slot's program**: its tables, its round polynomial's IR, its hosted slots with their coefficients, and the
draws `define` refuses when zero (`nonzero(ν)`, `nonzero(ζ)`). -/
structure SlotS where
  tabs : List TabS
  ir : Ir Sym
  hosted : List (ℕ × Sym)
  nonzero : List Sym

/-- The slot past a program's end: nothing. -/
def SlotS.empty : SlotS := ⟨[], ⟨[], []⟩, [], []⟩

def CoordS.eval (ev : Sym → Fp2) : CoordS → Coord
  | .rho k => .rho k
  | .flip k => .flip k
  | .fixed v => .fixed (ev v)

def PrivS.eval (ev : Sym → Fp2) (p : PrivS) : Priv :=
  ⟨p.cm, p.slices.map fun s => (s.1, if s.2 then fp2U else Fp2.one), p.log, p.coords.map (CoordS.eval ev), p.maskRow,
    p.extRound⟩

def TabS.eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) : TabS → Tab
  | .eq point start => .eq (point.map ev) start
  | .pub i => .pub (pub i)
  | .priv p => .priv (p.eval ev)

/-- **A block's public tables**: table `i` of slot `k`, from the history and the slot's draws (the folded weights
read `eq(r_j)`, the table value columns read `β` and the tags). A function of the block's public statement. -/
abbrev PubTabs := ℕ → Hist → List Fp2 → ℕ → List Fp2

/-- **`define`, run on a program.** -/
def defineS (prog : List SlotS) (pubs : PubTabs) (k : ℕ) (hist : Hist) (dr : List Fp2) : Except String SlotDef :=
  if HistCanon hist dr then
    if (prog.getD k SlotS.empty).nonzero.any (fun s => (s.eval hist k dr).isZero) then
      .error "zero batching challenge; discard attempt"
    else
      .ok ⟨(prog.getD k SlotS.empty).tabs.map (TabS.eval (Sym.eval hist k dr) (pubs k hist dr)),
        irEvalW ((prog.getD k SlotS.empty).ir.map (Sym.eval hist k dr)),
        (prog.getD k SlotS.empty).hosted.map fun h => (h.1, h.2.eval hist k dr)⟩
  else .error "noncanonical challenge word"

/-- **An accepted definition**: the transcript's values are canonical and the definition is the program's. -/
theorem defineS_ok {prog : List SlotS} {pubs : PubTabs} {k : ℕ} {hist : Hist} {dr : List Fp2} {df : SlotDef}
    (h : defineS prog pubs k hist dr = .ok df) :
    HistCanon hist dr
      ∧ df = ⟨(prog.getD k SlotS.empty).tabs.map (TabS.eval (Sym.eval hist k dr) (pubs k hist dr)),
        irEvalW ((prog.getD k SlotS.empty).ir.map (Sym.eval hist k dr)),
        (prog.getD k SlotS.empty).hosted.map fun h => (h.1, h.2.eval hist k dr)⟩ := by
  unfold defineS at h
  by_cases hc : HistCanon hist dr
  · rw [ite_eq_left hc] at h
    by_cases hz : ((prog.getD k SlotS.empty).nonzero.any fun s => (s.eval hist k dr).isZero) = true
    · rw [ite_eq_left hz] at h
      cases h
    · rw [ite_eq_right hz] at h
      exact And.intro hc (Except.ok.inj h).symm
  · rw [ite_eq_right hc] at h
    cases h

/-! ## What does not depend on the challenges -/

/-- How many of a slot program's private tables sit in commitment `cm`. -/
def cmCountS (cm : Cm) : List TabS → ℕ
  | [] => 0
  | .priv p :: ts => (if p.cm = cm then 1 else 0) + cmCountS cm ts
  | .eq _ _ :: ts => cmCountS cm ts
  | .pub _ :: ts => cmCountS cm ts

theorem cmCount_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (cm : Cm) :
    ∀ ts : List TabS, cmCount cm (ts.map (TabS.eval ev pub)) = cmCountS cm ts
  | [] => rfl
  | .priv p :: ts => by
    show (if p.cm = cm then 1 else 0) + cmCount cm (ts.map (TabS.eval ev pub)) = _
    rw [cmCount_eval ev pub cm ts]
    rfl
  | .eq _ _ :: ts => cmCount_eval ev pub cm ts
  | .pub _ :: ts => cmCount_eval ev pub cm ts

/-- The challenge a coordinate reads, if any. -/
def coordVarS : CoordS → Option ℕ
  | .rho k => some k
  | .flip k => some k
  | .fixed _ => none

theorem coordVar_eval (ev : Sym → Fp2) (cs : List CoordS) :
    (cs.map (CoordS.eval ev)).map coordVar = cs.map coordVarS := by
  rw [List.map_map]
  refine List.map_congr_left (fun c _ => ?_)
  cases c <;> rfl

/-- **The shape check of a private table** (`rl` the commitments' row logs): a slice, a nonempty point of the
slice's length, a positive row log, each challenge read at most once. -/
def privOKb (rl : Cm → ℕ) (p : PrivS) : Bool :=
  !p.slices.isEmpty && decide (0 < p.log) && decide (p.coords.length = p.log) && decide (0 < rl p.cm)
    && varsOKb (p.coords.map coordVarS)

def tabOKb (rl : Cm → ℕ) : TabS → Bool
  | .priv p => privOKb rl p
  | _ => true

/-- **The check of one slot program** against the slot's declared degree `d`. -/
def slotOKb (rl : Cm → ℕ) (d : ℕ) (s : SlotS) : Bool := s.tabs.all (tabOKb rl) && decide (irDeg s.ir ≤ d)

/-- **The check of a program** against the schedule `(n, e, d)` per slot: one program per slot, each passing. -/
def progOKb (rl : Cm → ℕ) : List SlotS → List (ℕ × ℕ × ℕ) → Bool
  | [], [] => true
  | s :: ss, d :: ds => slotOKb rl d.2.2 s && progOKb rl ss ds
  | _, _ => false

theorem progOK_getD (rl : Cm → ℕ) : ∀ (prog : List SlotS) (slots : List (ℕ × ℕ × ℕ)), progOKb rl prog slots = true →
    ∀ k, slotOKb rl (slots.getD k (0, 0, 0)).2.2 (prog.getD k SlotS.empty) = true
  | [], [], _, k => by
    rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_nil, List.getElem?_nil]
    rfl
  | [], _ :: _, h, _ => by simp [progOKb] at h
  | _ :: _, [], h, _ => by simp [progOKb] at h
  | s :: ss, d :: ds, h, k => by
    simp only [progOKb, Bool.and_eq_true] at h
    cases k with
    | zero => exact h.1
    | succ k =>
      rw [List.getD_cons_succ, List.getD_cons_succ]
      exact progOK_getD rl ss ds h.2 k

theorem tabOK_eval (P : BlockParams) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (t : TabS)
    (h : tabOKb (rowLog P) t = true) : TabOK P (t.eval ev pub) := by
  cases t with
  | eq point start => exact trivial
  | pub i => exact trivial
  | priv p =>
    simp only [tabOKb, privOKb, Bool.and_eq_true, Bool.not_eq_true', decide_eq_true_eq] at h
    obtain ⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h5⟩ := h
    refine ⟨?_, h2, ?_, h4, ?_⟩
    · show p.slices.map (fun s => (s.1, if s.2 then fp2U else Fp2.one)) ≠ []
      intro he
      rw [List.map_eq_nil_iff] at he
      rw [he] at h1
      simp at h1
    · show (p.coords.map (CoordS.eval ev)).length = p.log
      rw [List.length_map]
      exact h3
    · show varsOKb ((p.coords.map (CoordS.eval ev)).map coordVar) = true
      rw [coordVar_eval]
      exact h5

theorem tabCanon_eval {hist : Hist} {k : ℕ} {dr : List Fp2} (h : HistCanon hist dr) (pub : ℕ → List Fp2)
    (t : TabS) : TabCanon (t.eval (Sym.eval hist k dr) pub) := by
  cases t with
  | eq point start =>
    show ∀ a ∈ point.map (Sym.eval hist k dr), a.Canon
    intro a ha
    obtain ⟨s, -, rfl⟩ := List.mem_map.mp ha
    exact Sym.eval_canon h s
  | pub i => exact trivial
  | priv p =>
    show ∀ c ∈ p.coords.map (CoordS.eval (Sym.eval hist k dr)), ∀ v, c = Coord.fixed v → v.Canon
    intro c hc v hv
    obtain ⟨c', -, rfl⟩ := List.mem_map.mp hc
    cases c' with
    | rho j => cases hv
    | flip j => cases hv
    | fixed s =>
      have e : Sym.eval hist k dr s = v := Coord.fixed.inj hv
      rw [← e]
      exact Sym.eval_canon h s

end ZK60.Exec.Block
