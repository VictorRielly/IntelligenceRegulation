/-
D63 lane L36 (2026-11-09), part 6: **the lookup bridge `hbr` at R13 from a cover of the logical lookups** (L23's item
4, the `hbr` half: L21's `hbr_of_cover` instantiated for `R13Lookups`).

`hbr` asks: on an accepting outcome, if `R13Lookups` fails then some extracted lookup tuple is outside the table
enumeration. This file reduces it to two facts about the code's lists, with no probability and no outcome in them:

* `hTtab`: every entry of the table enumeration `T` is (the image in `K` of) a tuple of the R13 table
  `CodeTable r13Fams` (the code's u8 and exp columns repeat their rows `i mod 256` over the table domain, and the
  ACT column's padding rows are group 0's row at `i = 2048`: argument.rs:1953-1971, accuracy_act.rs);
* `hcov`: every logical query of `R13Lookups` (each byte limb, each pin, the score's two byte queries, the exp and ACT
  tuples, at every logical position) is some entry of the lookup list `Alk`.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `tupK`, `tupK_injective`: a tuple over `GF` read in `K`;
* `R13LookupsG`: `R13Lookups` with the table predicate a parameter (`r13LookupsG_code`: at `CodeTable r13Fams` it IS
  `R13Lookups`); `r13LookupsG_mono`;
* `R13Query`: **the logical queries of `R13Lookups`** (a tuple is one exactly when some field of `R13LookupsG` asks
  it); `r13LookupsG_query`: every field's query is one; `r13Query_of`: a predicate that every field meets holds of
  every logical query;
* **`r13Lookups_of_queries`**: if every logical query is a table tuple, `R13Lookups` holds;
* **`hbr_r13_of_cover`**: `hTtab` and `hcov` give `hbr`'s conclusion.
-/
import ZK60Formal.BlockAlgR13

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound (Tup)
open ZK60.Circuit (gP GF rangeQuery tagW expQuery actQuery CodeTable)
open ZK60.Layout
open ZK60.Layout.R13 (R13Data R13Lookups Bytes BytesPin r13Fams)

/-- A lookup tuple over `GF`, read in a field `K` over `GF`. -/
def tupK {K : Type} [Field K] [Algebra GF K] (u : Tup GF) : Tup K :=
  ⟨algebraMap GF K u.x, algebraMap GF K u.tag, algebraMap GF K u.y, algebraMap GF K u.z⟩

theorem tupK_injective {K : Type} [Field K] [Algebra GF K] : Function.Injective (tupK (K := K)) := by
  intro u w h
  have hinj := (algebraMap GF K).injective
  have hx := hinj (congrArg Tup.x h)
  have ht := hinj (congrArg Tup.tag h)
  have hy := hinj (congrArg Tup.y h)
  have hz := hinj (congrArg Tup.z h)
  exact ZK60.Sound.Tup.ext' hx ht hy hz

section Lk

variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} {ls : ℕ}

/-- **`R13Lookups` with the table predicate a parameter `T`** (its fields word for word, `CodeTable r13Fams …`
replaced by `T`). -/
structure R13LookupsG (T : Tup GF → Prop) (P : ZK60.Block.BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf)
    (B : W16Pub S P L) (E : R13Data Ct Cw Cg Cj Cd Cf ls) : Prop where
  la : ∀ t i k, T (rangeQuery (tagW 8) (E.la i k (L.tok.emb t)))
  lm : ∀ t i k, T (rangeQuery (tagW 8) (E.lm i k (L.tok.emb t)))
  xl : ∀ p, Bytes T E.xl (L.dPos p)
  yl : ∀ p, Bytes T E.yl (L.dPos p)
  aol : ∀ p, Bytes T E.aol (L.dPos p)
  x1l : ∀ p, Bytes T E.x1l (L.dPos p)
  yml : ∀ p, Bytes T E.yml (L.dPos p)
  zl : ∀ p, Bytes T E.zl (L.dPos p)
  x2l : ∀ p, Bytes T E.x2l (L.dPos p)
  nr : ∀ p, Bytes T E.nr (L.dPos p)
  ns : ∀ p, Bytes T E.ns (L.dPos p)
  mr : ∀ p, Bytes T E.mr (L.dPos p)
  ms : ∀ p, Bytes T E.ms (L.dPos p)
  ral : ∀ p, BytesPin T E.ral S.sao (L.dPos p)
  rdl : ∀ p, BytesPin T E.rdl S.sdown (L.dPos p)
  ql : ∀ p, Bytes T E.ql (L.qPos p)
  qrl : ∀ p, Bytes T E.qrl (L.qPos p)
  ol : ∀ p, Bytes T E.ol (L.qPos p)
  rql : ∀ p, BytesPin T E.rql S.sq (L.qPos p)
  rqrl : ∀ p, BytesPin T E.rqrl 7 (L.qPos p)
  ro : ∀ p, BytesPin T E.ro S.spv (L.qPos p)
  kl : ∀ p, Bytes T E.kl (L.kPos p)
  krl : ∀ p, Bytes T E.krl (L.kPos p)
  vl : ∀ p, Bytes T E.vl (L.kPos p)
  rkl : ∀ p, BytesPin T E.rkl S.sk (L.kPos p)
  rkrl : ∀ p, BytesPin T E.rkrl 7 (L.kPos p)
  rvl : ∀ p, BytesPin T E.rvl S.sv (L.kPos p)
  sB : ∀ p, T (rangeQuery (tagW 8) (E.S8 (L.sPos p) + 127)) ∧ T (rangeQuery (tagW 8) (-E.S8 (L.sPos p) + 127))
  rsl : ∀ p, BytesPin T E.rsl S.ss (L.sPos p)
  pl : ∀ p, BytesPin T E.pl (S.fp + 1) (L.sPos p)
  sr : ∀ p, BytesPin T E.sr S.wrho (L.sPos p)
  sg : ∀ p, BytesPin T E.sg S.wrho (L.sPos p)
  sExp : ∀ p, T (expQuery (E.MX (L.slot p.1, L.tok.emb p.2.1) - B.mask (L.sPos p) * (E.S8 (L.sPos p) + 127) + 127)
    (E.E (L.sPos p)))
  rgl : ∀ p, BytesPin T E.rgl S.sgate (L.fPos p)
  ul : ∀ p, Bytes T E.ul (L.fPos p)
  ru : ∀ p, BytesPin T E.ru S.sup (L.fPos p)
  hl : ∀ p, Bytes T E.hl (L.fPos p)
  rh : ∀ p, Bytes T E.rh (L.fPos p)
  fAct : ∀ p, T (actQuery (E.G (L.fPos p)) (E.A (L.fPos p)) (P.grpF p.2))

variable {P : ZK60.Block.BlockPublic S} {L : W16Layout S Ct Cw Cg Cj Cd Cf} {B : W16Pub S P L}
  {E : R13Data Ct Cw Cg Cj Cd Cf ls}

/-- **`R13LookupsG` at the R13 table is `R13Lookups`.** -/
theorem r13LookupsG_code (h : R13LookupsG (CodeTable r13Fams P.exp P.act S.nG) P L B E) : R13Lookups S P L B E :=
  ⟨h.la, h.lm, h.xl, h.yl, h.aol, h.x1l, h.yml, h.zl, h.x2l, h.nr, h.ns, h.mr, h.ms, h.ral, h.rdl, h.ql, h.qrl,
    h.ol, h.rql, h.rqrl, h.ro, h.kl, h.krl, h.vl, h.rkl, h.rkrl, h.rvl, h.sB, h.rsl, h.pl, h.sr, h.sg, h.sExp, h.rgl,
    h.ul, h.ru, h.hl, h.rh, h.fAct⟩

theorem bytes_mono {T1 T2 : Tup GF → Prop} (hT : ∀ t, T1 t → T2 t) {C : Type} {n : ℕ} (l : Fin n → C → GF) (x : C)
    (h : Bytes T1 l x) : Bytes T2 l x := fun k => hT _ (h k)

theorem bytesPin_mono {T1 T2 : Tup GF → Prop} (hT : ∀ t, T1 t → T2 t) {C : Type} {n : ℕ} (l : Fin (n + 1) → C → GF)
    (b : ℕ) (x : C) (h : BytesPin T1 l b x) : BytesPin T2 l b x :=
  ⟨bytes_mono hT l x h.1, hT _ h.2⟩

/-- `R13LookupsG` is monotone in the table predicate. -/
theorem r13LookupsG_mono {T1 T2 : Tup GF → Prop} (hT : ∀ t, T1 t → T2 t) (h : R13LookupsG T1 P L B E) :
    R13LookupsG T2 P L B E where
  la t i k := hT _ (h.la t i k)
  lm t i k := hT _ (h.lm t i k)
  xl p := bytes_mono hT _ _ (h.xl p)
  yl p := bytes_mono hT _ _ (h.yl p)
  aol p := bytes_mono hT _ _ (h.aol p)
  x1l p := bytes_mono hT _ _ (h.x1l p)
  yml p := bytes_mono hT _ _ (h.yml p)
  zl p := bytes_mono hT _ _ (h.zl p)
  x2l p := bytes_mono hT _ _ (h.x2l p)
  nr p := bytes_mono hT _ _ (h.nr p)
  ns p := bytes_mono hT _ _ (h.ns p)
  mr p := bytes_mono hT _ _ (h.mr p)
  ms p := bytes_mono hT _ _ (h.ms p)
  ral p := bytesPin_mono hT _ _ _ (h.ral p)
  rdl p := bytesPin_mono hT _ _ _ (h.rdl p)
  ql p := bytes_mono hT _ _ (h.ql p)
  qrl p := bytes_mono hT _ _ (h.qrl p)
  ol p := bytes_mono hT _ _ (h.ol p)
  rql p := bytesPin_mono hT _ _ _ (h.rql p)
  rqrl p := bytesPin_mono hT _ _ _ (h.rqrl p)
  ro p := bytesPin_mono hT _ _ _ (h.ro p)
  kl p := bytes_mono hT _ _ (h.kl p)
  krl p := bytes_mono hT _ _ (h.krl p)
  vl p := bytes_mono hT _ _ (h.vl p)
  rkl p := bytesPin_mono hT _ _ _ (h.rkl p)
  rkrl p := bytesPin_mono hT _ _ _ (h.rkrl p)
  rvl p := bytesPin_mono hT _ _ _ (h.rvl p)
  sB p := ⟨hT _ (h.sB p).1, hT _ (h.sB p).2⟩
  rsl p := bytesPin_mono hT _ _ _ (h.rsl p)
  pl p := bytesPin_mono hT _ _ _ (h.pl p)
  sr p := bytesPin_mono hT _ _ _ (h.sr p)
  sg p := bytesPin_mono hT _ _ _ (h.sg p)
  sExp p := hT _ (h.sExp p)
  rgl p := bytesPin_mono hT _ _ _ (h.rgl p)
  ul p := bytes_mono hT _ _ (h.ul p)
  ru p := bytesPin_mono hT _ _ _ (h.ru p)
  hl p := bytes_mono hT _ _ (h.hl p)
  rh p := bytes_mono hT _ _ (h.rh p)
  fAct p := hT _ (h.fAct p)

/-- **The logical queries of `R13Lookups`**: `q` is one exactly when not every field's query differs from `q`. -/
def R13Query (P : ZK60.Block.BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L)
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) (q : Tup GF) : Prop :=
  ¬ R13LookupsG (fun t => t ≠ q) P L B E

/-- **Every field's query is a logical query.** -/
theorem r13LookupsG_query : R13LookupsG (R13Query P L B E) P L B E where
  la t i k := fun h => h.la t i k rfl
  lm t i k := fun h => h.lm t i k rfl
  xl p k := fun h => h.xl p k rfl
  yl p k := fun h => h.yl p k rfl
  aol p k := fun h => h.aol p k rfl
  x1l p k := fun h => h.x1l p k rfl
  yml p k := fun h => h.yml p k rfl
  zl p k := fun h => h.zl p k rfl
  x2l p k := fun h => h.x2l p k rfl
  nr p k := fun h => h.nr p k rfl
  ns p k := fun h => h.ns p k rfl
  mr p k := fun h => h.mr p k rfl
  ms p k := fun h => h.ms p k rfl
  ral p := ⟨fun k h => (h.ral p).1 k rfl, fun h => (h.ral p).2 rfl⟩
  rdl p := ⟨fun k h => (h.rdl p).1 k rfl, fun h => (h.rdl p).2 rfl⟩
  ql p k := fun h => h.ql p k rfl
  qrl p k := fun h => h.qrl p k rfl
  ol p k := fun h => h.ol p k rfl
  rql p := ⟨fun k h => (h.rql p).1 k rfl, fun h => (h.rql p).2 rfl⟩
  rqrl p := ⟨fun k h => (h.rqrl p).1 k rfl, fun h => (h.rqrl p).2 rfl⟩
  ro p := ⟨fun k h => (h.ro p).1 k rfl, fun h => (h.ro p).2 rfl⟩
  kl p k := fun h => h.kl p k rfl
  krl p k := fun h => h.krl p k rfl
  vl p k := fun h => h.vl p k rfl
  rkl p := ⟨fun k h => (h.rkl p).1 k rfl, fun h => (h.rkl p).2 rfl⟩
  rkrl p := ⟨fun k h => (h.rkrl p).1 k rfl, fun h => (h.rkrl p).2 rfl⟩
  rvl p := ⟨fun k h => (h.rvl p).1 k rfl, fun h => (h.rvl p).2 rfl⟩
  sB p := ⟨fun h => (h.sB p).1 rfl, fun h => (h.sB p).2 rfl⟩
  rsl p := ⟨fun k h => (h.rsl p).1 k rfl, fun h => (h.rsl p).2 rfl⟩
  pl p := ⟨fun k h => (h.pl p).1 k rfl, fun h => (h.pl p).2 rfl⟩
  sr p := ⟨fun k h => (h.sr p).1 k rfl, fun h => (h.sr p).2 rfl⟩
  sg p := ⟨fun k h => (h.sg p).1 k rfl, fun h => (h.sg p).2 rfl⟩
  sExp p := fun h => h.sExp p rfl
  rgl p := ⟨fun k h => (h.rgl p).1 k rfl, fun h => (h.rgl p).2 rfl⟩
  ul p k := fun h => h.ul p k rfl
  ru p := ⟨fun k h => (h.ru p).1 k rfl, fun h => (h.ru p).2 rfl⟩
  hl p k := fun h => h.hl p k rfl
  rh p k := fun h => h.rh p k rfl
  fAct p := fun h => h.fAct p rfl

/-- **A predicate that every field of `R13LookupsG` meets holds of every logical query.** -/
theorem r13Query_of {T : Tup GF → Prop} (hT : R13LookupsG T P L B E) {q : Tup GF} (hq : R13Query P L B E q) :
    T q := by
  by_contra hn
  exact hq (r13LookupsG_mono (fun t ht e => hn (e ▸ ht)) hT)

/-- **If every logical query of `R13Lookups` is a table tuple, `R13Lookups` holds.** -/
theorem r13Lookups_of_queries (h : ∀ q, R13Query P L B E q → CodeTable r13Fams P.exp P.act S.nG q) :
    R13Lookups S P L B E :=
  r13LookupsG_code (r13LookupsG_mono h r13LookupsG_query)

/-- **`hbr` at R13 from a cover of the logical lookups** (L21's `hbr_of_cover` for `R13Lookups`): if every entry of the
table enumeration is a tuple of the R13 table (`hTtab`) and every logical query of `R13Lookups` is an entry of the
lookup list (`hcov`), a failing `R13Lookups` gives a lookup outside the table enumeration. -/
theorem hbr_r13_of_cover {K : Type} [Field K] [Algebra GF K] {ι π κ : Type} (Alk : ι ⊕ (π ⊕ π) → Tup K)
    (T : κ → Tup K) (hTtab : ∀ j, ∃ t0, CodeTable r13Fams P.exp P.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ q, R13Query P L B E q → ∃ l, Alk l = tupK q) (hn : ¬ R13Lookups S P L B E) :
    ∃ l, ∀ j, T j ≠ Alk l := by
  refine hbr_of_cover (fun u => ∃ t0, CodeTable r13Fams P.exp P.act S.nG t0 ∧ u = tupK t0) Alk T hTtab _ ?_ hn
  intro hall
  refine r13Lookups_of_queries (fun q hq => ?_)
  obtain ⟨l, hl⟩ := hcov q hq
  obtain ⟨t0, ht0, he⟩ := hall l
  rw [hl] at he
  rw [tupK_injective he]
  exact ht0

end Lk

end ZK60.Exec.Block
