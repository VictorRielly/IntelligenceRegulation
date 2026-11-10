/-
D63 lane L36 (2026-11-09), part 6b: **the lookup bridge `hbr` at W16R2 from a cover of the logical lookups** (as
`BlockAlgLkR13.lean` does at R13: L21's `hbr_of_cover` instantiated for `W16Lookups`).

* `W16LookupsG`: `W16Lookups` with the table predicate a parameter (`w16LookupsG_code`: at `CodeTable fams …` it IS
  `W16Lookups`); `w16LookupsG_mono`;
* `W16Query`: **the logical queries of `W16Lookups`**; `w16LookupsG_query`: every field's query is one;
* **`w16Lookups_of_queries`**: if every logical query is a table tuple, `W16Lookups` holds;
* **`hbr_w16_of_cover`**: `hTtab` (every entry of the table enumeration is a tuple of `CodeTable fams …`) and `hcov`
  (every logical query is an entry of the lookup list) give `hbr`'s conclusion.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgLkR13

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound (Tup)
open ZK60.Circuit (gP GF rangeQuery tagW expQuery actQuery CodeTable)
open ZK60.Layout

section LkW16

variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type}

/-- **`W16Lookups` with the table predicate a parameter `T`** (its fields word for word, `CodeTable fams …` replaced
by `T`). -/
structure W16LookupsG (T : Tup GF → Prop) (P : ZK60.Block.BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf)
    (B : W16Pub S P L) (E : W16Data Ct Cw Cg Cj Cd Cf) : Prop where
  la : ∀ t i k, T (rangeQuery (tagW 8) (E.la i k (L.tok.emb t)))
  lm : ∀ t i k, T (rangeQuery (tagW 8) (E.lm i k (L.tok.emb t)))
  dW : ∀ p, ∀ w ∈ [E.X, E.Y, E.AO, E.X1, E.YM, E.Z, E.X2], T (rangeQuery (tagW 16) (w (L.dPos p) + 32768))
  dR : ∀ p, (∀ q ∈ remLk 24 (E.nr.lo (L.dPos p)) (E.nr.hi (L.dPos p)), T q) ∧
    (∀ q ∈ remLk 24 (E.ns.lo (L.dPos p)) (E.ns.hi (L.dPos p)), T q) ∧
    (∀ q ∈ remLk 24 (E.mr.lo (L.dPos p)) (E.mr.hi (L.dPos p)), T q) ∧
    (∀ q ∈ remLk 24 (E.ms.lo (L.dPos p)) (E.ms.hi (L.dPos p)), T q) ∧
    (∀ q ∈ remLk S.sao (E.rao.lo (L.dPos p)) (E.rao.hi (L.dPos p)), T q) ∧
    (∀ q ∈ remLk S.sdown (E.rd.lo (L.dPos p)) (E.rd.hi (L.dPos p)), T q)
  qW : ∀ p, ∀ w ∈ [E.Q, E.QR, E.O], T (rangeQuery (tagW 16) (w (L.qPos p) + 32768))
  qR : ∀ p, (∀ q ∈ remLk S.sq (E.rq.lo (L.qPos p)) (E.rq.hi (L.qPos p)), T q) ∧
    (∀ q ∈ remLk 7 (E.rqr.lo (L.qPos p)) (E.rqr.hi (L.qPos p)), T q) ∧
    (∀ q ∈ remLk S.spv (E.ro.lo (L.qPos p)) (E.ro.hi (L.qPos p)), T q)
  kW : ∀ p, ∀ w ∈ [E.K, E.V, E.KR], T (rangeQuery (tagW 16) (w (L.kPos p) + 32768))
  kR : ∀ p, (∀ q ∈ remLk S.sk (E.rk.lo (L.kPos p)) (E.rk.hi (L.kPos p)), T q) ∧
    (∀ q ∈ remLk S.sv (E.rv.lo (L.kPos p)) (E.rv.hi (L.kPos p)), T q) ∧
    (∀ q ∈ remLk 7 (E.rkr.lo (L.kPos p)) (E.rkr.hi (L.kPos p)), T q)
  sB : ∀ p, T (rangeQuery (tagW 8) (E.S8 (L.sPos p) + 127)) ∧ T (rangeQuery (tagW 8) (-E.S8 (L.sPos p) + 127))
  sR : ∀ p, (∀ q ∈ remLk S.ss (E.rs.lo (L.sPos p)) (E.rs.hi (L.sPos p)), T q) ∧
    T (rangeQuery (tagW (S.fp + 1)) (E.PP (L.sPos p))) ∧
    (∀ q ∈ remLk S.wrho (E.sr.lo (L.sPos p)) (E.sr.hi (L.sPos p)), T q) ∧
    (∀ q ∈ remLk S.wrho (E.sg.lo (L.sPos p)) (E.sg.hi (L.sPos p)), T q)
  sExp : ∀ p, T (expQuery (E.MX (L.slot p.1, L.tok.emb p.2.1) - B.mask (L.sPos p) * (E.S8 (L.sPos p) + 127) + 127)
    (E.E (L.sPos p)))
  fR : ∀ p, (∀ q ∈ remLk S.sgate (E.rg.lo (L.fPos p)) (E.rg.hi (L.fPos p)), T q) ∧
    T (rangeQuery (tagW 16) (E.U (L.fPos p) + 32768)) ∧
    (∀ q ∈ remLk S.sup (E.ru.lo (L.fPos p)) (E.ru.hi (L.fPos p)), T q) ∧
    T (rangeQuery (tagW 16) (E.H (L.fPos p) - 2 ^ 16 * E.Htop (L.fPos p))) ∧
    T (rangeQuery (tagW 8) (E.Htop (L.fPos p) + 128)) ∧
    (∀ q ∈ remLk S.sprod (E.rh.lo (L.fPos p)) (E.rh.hi (L.fPos p)), T q)
  fAct : ∀ p, T (actQuery (E.G (L.fPos p)) (E.A (L.fPos p)) (P.grpF p.2))

variable {P : ZK60.Block.BlockPublic S} {L : W16Layout S Ct Cw Cg Cj Cd Cf} {B : W16Pub S P L}
  {E : W16Data Ct Cw Cg Cj Cd Cf}

/-- **`W16LookupsG` at the block's table is `W16Lookups`.** -/
theorem w16LookupsG_code {fams : List (ℕ × ℕ)} (h : W16LookupsG (CodeTable fams P.exp P.act S.nG) P L B E) :
    W16Lookups S P L B E fams :=
  ⟨h.la, h.lm, h.dW, h.dR, h.qW, h.qR, h.kW, h.kR, h.sB, h.sR, h.sExp, h.fR, h.fAct⟩

/-- `W16LookupsG` is monotone in the table predicate. -/
theorem w16LookupsG_mono {T1 T2 : Tup GF → Prop} (hT : ∀ t, T1 t → T2 t) (h : W16LookupsG T1 P L B E) :
    W16LookupsG T2 P L B E where
  la t i k := hT _ (h.la t i k)
  lm t i k := hT _ (h.lm t i k)
  dW p w hw := hT _ (h.dW p w hw)
  dR p := ⟨fun q hq => hT _ ((h.dR p).1 q hq), fun q hq => hT _ ((h.dR p).2.1 q hq),
    fun q hq => hT _ ((h.dR p).2.2.1 q hq), fun q hq => hT _ ((h.dR p).2.2.2.1 q hq),
    fun q hq => hT _ ((h.dR p).2.2.2.2.1 q hq), fun q hq => hT _ ((h.dR p).2.2.2.2.2 q hq)⟩
  qW p w hw := hT _ (h.qW p w hw)
  qR p := ⟨fun q hq => hT _ ((h.qR p).1 q hq), fun q hq => hT _ ((h.qR p).2.1 q hq),
    fun q hq => hT _ ((h.qR p).2.2 q hq)⟩
  kW p w hw := hT _ (h.kW p w hw)
  kR p := ⟨fun q hq => hT _ ((h.kR p).1 q hq), fun q hq => hT _ ((h.kR p).2.1 q hq),
    fun q hq => hT _ ((h.kR p).2.2 q hq)⟩
  sB p := ⟨hT _ (h.sB p).1, hT _ (h.sB p).2⟩
  sR p := ⟨fun q hq => hT _ ((h.sR p).1 q hq), hT _ (h.sR p).2.1, fun q hq => hT _ ((h.sR p).2.2.1 q hq),
    fun q hq => hT _ ((h.sR p).2.2.2 q hq)⟩
  sExp p := hT _ (h.sExp p)
  fR p := ⟨fun q hq => hT _ ((h.fR p).1 q hq), hT _ (h.fR p).2.1, fun q hq => hT _ ((h.fR p).2.2.1 q hq),
    hT _ (h.fR p).2.2.2.1, hT _ (h.fR p).2.2.2.2.1, fun q hq => hT _ ((h.fR p).2.2.2.2.2 q hq)⟩
  fAct p := hT _ (h.fAct p)

/-- **The logical queries of `W16Lookups`**: `q` is one exactly when not every field's query differs from `q`. -/
def W16Query (P : ZK60.Block.BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L)
    (E : W16Data Ct Cw Cg Cj Cd Cf) (q : Tup GF) : Prop :=
  ¬ W16LookupsG (fun t => t ≠ q) P L B E

/-- **Every field's query is a logical query.** -/
theorem w16LookupsG_query : W16LookupsG (W16Query P L B E) P L B E where
  la t i k := fun h => h.la t i k rfl
  lm t i k := fun h => h.lm t i k rfl
  dW p w hw := fun h => h.dW p w hw rfl
  dR p := ⟨fun q hq h => (h.dR p).1 q hq rfl, fun q hq h => (h.dR p).2.1 q hq rfl,
    fun q hq h => (h.dR p).2.2.1 q hq rfl, fun q hq h => (h.dR p).2.2.2.1 q hq rfl,
    fun q hq h => (h.dR p).2.2.2.2.1 q hq rfl, fun q hq h => (h.dR p).2.2.2.2.2 q hq rfl⟩
  qW p w hw := fun h => h.qW p w hw rfl
  qR p := ⟨fun q hq h => (h.qR p).1 q hq rfl, fun q hq h => (h.qR p).2.1 q hq rfl,
    fun q hq h => (h.qR p).2.2 q hq rfl⟩
  kW p w hw := fun h => h.kW p w hw rfl
  kR p := ⟨fun q hq h => (h.kR p).1 q hq rfl, fun q hq h => (h.kR p).2.1 q hq rfl,
    fun q hq h => (h.kR p).2.2 q hq rfl⟩
  sB p := ⟨fun h => (h.sB p).1 rfl, fun h => (h.sB p).2 rfl⟩
  sR p := ⟨fun q hq h => (h.sR p).1 q hq rfl, fun h => (h.sR p).2.1 rfl, fun q hq h => (h.sR p).2.2.1 q hq rfl,
    fun q hq h => (h.sR p).2.2.2 q hq rfl⟩
  sExp p := fun h => h.sExp p rfl
  fR p := ⟨fun q hq h => (h.fR p).1 q hq rfl, fun h => (h.fR p).2.1 rfl, fun q hq h => (h.fR p).2.2.1 q hq rfl,
    fun h => (h.fR p).2.2.2.1 rfl, fun h => (h.fR p).2.2.2.2.1 rfl, fun q hq h => (h.fR p).2.2.2.2.2 q hq rfl⟩
  fAct p := fun h => h.fAct p rfl

/-- **If every logical query of `W16Lookups` is a table tuple, `W16Lookups` holds.** -/
theorem w16Lookups_of_queries {fams : List (ℕ × ℕ)}
    (h : ∀ q, W16Query P L B E q → CodeTable fams P.exp P.act S.nG q) : W16Lookups S P L B E fams := by
  refine w16LookupsG_code (w16LookupsG_mono (fun q hq => h q hq) w16LookupsG_query)

/-- **`hbr` at W16R2 from a cover of the logical lookups** (L21's `hbr_of_cover` for `W16Lookups`). -/
theorem hbr_w16_of_cover {K : Type} [Field K] [Algebra GF K] {ι π κ : Type} {fams : List (ℕ × ℕ)}
    (Alk : ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (hTtab : ∀ j, ∃ t0, CodeTable fams P.exp P.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ q, W16Query P L B E q → ∃ l, Alk l = tupK q) (hn : ¬ W16Lookups S P L B E fams) :
    ∃ l, ∀ j, T j ≠ Alk l := by
  refine hbr_of_cover (fun u => ∃ t0, CodeTable fams P.exp P.act S.nG t0 ∧ u = tupK t0) Alk T hTtab _ ?_ hn
  intro hall
  refine w16Lookups_of_queries (fun q hq => ?_)
  obtain ⟨l, hl⟩ := hcov q hq
  obtain ⟨t0, ht0, he⟩ := hall l
  rw [hl] at he
  rw [tupK_injective he]
  exact ht0

end LkW16

end ZK60.Exec.Block
