/-
D63 lane L36 (2026-11-09), part 4: **`hgdR` at W16R2: the start claims give `W16Rels`** (the reindexing of the
slots' cube relations to L11's named relations on the product cubes).

`BlockAlgInst.algGood_of_gd` turns all four layers' start claims into facts about the block's tables on the hosts'
flat cubes (`AlgGood`): every clause vanishes, every hosted identity holds at every cube point. `W16Rels` (L11,
`LayoutW16.lean`) states the same relations of the extracted planes `E` on the PRODUCT cubes (`Ct`, `Ct × Cw`, …).
This file joins them through the cubes' encodings:

* `W16Pos`: a position of one of the seven padded product cubes (`Dom::T`, `D`, `Q`, `Kv`, `S`, `Ht`, `F`);
* `relCl`, `relGh`, `relMm`, `relRsA`, `relRsB`: `W16Rels`'s relations as tables on those positions: the gated
  clauses of each host (in `W16Rels`'s order), each hosted pair's gated host term and contraction, `SC_RS`'s two row
  differences;
* `W16Spec`: **the tables of an `AlgData` are those relation tables read through encodings of the flat cubes**
  (`enc k`, `encHt`), each encoding onto its product cube: clause `j` of host `k` sits somewhere in the host's batch;
  `gh`, `mm`, `rsA`, `rsB` are the tables' pullbacks;
* **`w16Rels_of_algGood`**: `AlgGood` and `W16Spec` give `W16Rels` of the extracted planes, at a layout whose token
  and head-dimension axes do not pad (the two pad-rule fields `pp_pad`, `kr_pad` are then empty);
* `relCl_count`: the clause counts `6, 6, 1, 1, 4, 1` (`W16Rels`'s gated clauses per host).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgInst

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open ZK60.Layout
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)

/-- **A position of one of the block's seven padded product cubes.** -/
inductive W16Pos (Ct Cw Cg Cj Cd Cf : Type)
  | t (x : Ct)
  | d (x : Ct × Cw)
  | q (x : Ct × ((Cg × Cj) × Cd))
  | kv (x : Ct × (Cg × Cd))
  | s (x : (Cg × Cj) × Ct × Ct)
  | ht (x : (Cg × Cj) × Ct)
  | f (x : Ct × Cf)

section Tables

variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf]

/-- **`W16Rels`'s gated clauses as a table**: clause `j` of host `k` at a position of the host's cube (`SC_TZC`'s six
on `Dom::T`, `dzc_w16`'s six on `Dom::D`, the RoPE clause on `Dom::Q` and on `Dom::Kv`, the four softmax clauses on
`Dom::S`, the product clause on `Dom::F`; `0` elsewhere). -/
def relCl (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : W16Data Ct Cw Cg Cj Cd Cf) : ℕ → ℕ → W16Pos Ct Cw Cg Cj Cd Cf → GF
  | 2, 0, .t t => E.dsqA t - E.dA t * E.dA t
  | 2, 1, .t t => E.dA t - (E.la 0 0 t + 2 ^ 8 * E.la 0 1 t + 2 ^ 16 * E.la 0 2 t)
  | 2, 2, .t t => 2 * E.dA t - (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t)
      - (E.la 2 0 t + 2 ^ 8 * E.la 2 1 t + 2 ^ 16 * E.la 2 2 t)
  | 2, 3, .t t => E.dsqM t - E.dM t * E.dM t
  | 2, 4, .t t => E.dM t - (E.lm 0 0 t + 2 ^ 8 * E.lm 0 1 t + 2 ^ 16 * E.lm 0 2 t)
  | 2, 5, .t t => 2 * E.dM t - (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t)
      - (E.lm 2 0 t + 2 ^ 8 * E.lm 2 1 t + 2 ^ 16 * E.lm 2 2 t)
  | 14, 0, .d x => B.gD x * (B.gamA x * E.X x * (2 * (S.cnA : GF)) + E.dA x.1 * 2 ^ S.tn
      - 2 ^ (S.tn + 1) * E.dA x.1 * E.Y x - remVal 24 (E.nr.lo x) (E.nr.hi x))
  | 14, 1, .d x => B.gD x * (remVal 24 (E.nr.lo x) (E.nr.hi x) + remVal 24 (E.ns.lo x) (E.ns.hi x) + 1
      - 2 ^ (S.tn + 1) * E.dA x.1)
  | 14, 2, .d x => B.gD x * (E.X1 x - E.X x - E.AO x)
  | 14, 3, .d x => B.gD x * (B.gamM x * E.X1 x * (2 * (S.cnM : GF)) + E.dM x.1 * 2 ^ S.tn
      - 2 ^ (S.tn + 1) * E.dM x.1 * E.YM x - remVal 24 (E.mr.lo x) (E.mr.hi x))
  | 14, 4, .d x => B.gD x * (remVal 24 (E.mr.lo x) (E.mr.hi x) + remVal 24 (E.ms.lo x) (E.ms.hi x) + 1
      - 2 ^ (S.tn + 1) * E.dM x.1)
  | 14, 5, .d x => B.gD x * (E.X2 x - E.X1 x - E.Z x)
  | 15, 0, .q x => B.gQ x * (B.cosT x * E.Q x + B.sinT x * E.Q (x.1, (x.2.1, Lay.flip x.2.2)) - 2 ^ 7 * E.QR x
      - remVal 7 (E.rqr.lo x) (E.rqr.hi x) + 2 ^ 6)
  | 16, 0, .kv x => B.gK x * (B.cosK x * E.K x + B.sinK x * E.K (x.1, (x.2.1, Lay.flip x.2.2)) - 2 ^ 7 * E.KR x
      - remVal 7 (E.rkr.lo x) (E.rkr.hi x) + 2 ^ 6)
  | 17, 0, .s x => B.gS x * (E.ZSEL x * E.ZSEL x - E.ZSEL x)
  | 17, 1, .s x => B.gS x * (E.ZSEL x * (E.MX (x.1, x.2.1) - B.mask x * (E.S8 x + 127) + 127))
  | 17, 2, .s x => B.gS x * (B.mask x * E.E x * 2 ^ S.fp - E.PP x * E.SUM (x.1, x.2.1)
      - remVal S.wrho (E.sr.lo x) (E.sr.hi x))
  | 17, 3, .s x => B.gS x * (remVal S.wrho (E.sg.lo x) (E.sg.hi x) + remVal S.wrho (E.sr.lo x) (E.sr.hi x) + 1
      - E.SUM (x.1, x.2.1))
  | 18, 0, .f x => B.gF x * (E.A x * E.U x - 2 ^ S.sprod * E.H x - remVal S.sprod (E.rh.lo x) (E.rh.hi x)
      + 2 ^ (S.sprod - 1))
  | _, _, _ => 0

/-- How many gated clauses of `W16Rels` each host carries. -/
def relCount (k : ℕ) : ℕ :=
  if k = 2 then 6 else if k = 14 then 6 else if k = 15 then 1 else if k = 16 then 1 else if k = 17 then 4
  else if k = 18 then 1 else 0

/-- The clause counts: `SC_TZC` 6, `SC_DZC` 6, `SC_QZC` 1, `SC_KVZC` 1, `SC_SZC` 4, `SC_FZC` 1. -/
theorem relCl_count : algHosts.map relCount = [6, 6, 1, 1, 4, 1] := by decide

/-- **A hosted pair's gated host term** (the left side of `W16Rels`'s hosted identity), pair `i` of host `k`. -/
def relGh (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : W16Data Ct Cw Cg Cj Cd Cf) : ℕ → ℕ → W16Pos Ct Cw Cg Cj Cd Cf → GF
  | 2, 0, .t t => B.gT t * (E.dsqA t + (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t) - (S.ceps : GF))
  | 2, 1, .t t => B.gT t * (E.dsqM t + (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t) - (S.ceps : GF))
  | 14, 0, .d x => B.gD x * (2 ^ S.sao * E.AO x + remVal S.sao (E.rao.lo x) (E.rao.hi x) - 2 ^ (S.sao - 1))
  | 14, 1, .d x => B.gD x * (2 ^ S.sdown * E.Z x + remVal S.sdown (E.rd.lo x) (E.rd.hi x) - 2 ^ (S.sdown - 1))
  | 15, 0, .q x => B.gQ x * (2 ^ S.sq * E.Q x + remVal S.sq (E.rq.lo x) (E.rq.hi x) - 2 ^ (S.sq - 1))
  | 15, 1, .q x => B.gQ x * (2 ^ S.spv * E.O x + remVal S.spv (E.ro.lo x) (E.ro.hi x) - 2 ^ (S.spv - 1))
  | 16, 0, .kv x => B.gK x * (2 ^ S.sk * E.K x + remVal S.sk (E.rk.lo x) (E.rk.hi x) - 2 ^ (S.sk - 1))
  | 16, 1, .kv x => B.gK x * (2 ^ S.sv * E.V x + remVal S.sv (E.rv.lo x) (E.rv.hi x) - 2 ^ (S.sv - 1))
  | 17, 1, .s x => B.gS x * (2 ^ S.ss * E.S8 x + remVal S.ss (E.rs.lo x) (E.rs.hi x) - 2 ^ (S.ss - 1))
  | 18, 0, .f x => B.gF x * (2 ^ S.sgate * E.G x + remVal S.sgate (E.rg.lo x) (E.rg.hi x) - 2 ^ (S.sgate - 1))
  | 18, 1, .f x => B.gF x * (2 ^ S.sup * E.U x + remVal S.sup (E.ru.lo x) (E.ru.hi x) - 2 ^ (S.sup - 1))
  | _, _, _ => 0

/-- **A hosted pair's contraction** (the right side of `W16Rels`'s hosted identity). -/
def relMm (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : W16Data Ct Cw Cg Cj Cd Cf) : ℕ → ℕ → W16Pos Ct Cw Cg Cj Cd Cf → GF
  | 2, 0, .t t => ∑ c, B.gD (t, c) * E.X (t, c) * E.X (t, c)
  | 2, 1, .t t => ∑ c, B.gD (t, c) * E.X1 (t, c) * E.X1 (t, c)
  | 14, 0, .d x => ∑ c, E.O (x.1, c) * B.Wo c x.2
  | 14, 1, .d x => ∑ c, E.H (x.1, c) * B.Wd c x.2
  | 15, 0, .q x => ∑ c, E.Y (x.1, c) * B.Wq c x.2
  | 15, 1, .q x => ∑ j, E.PP (x.2.1, x.1, j) * E.V (j, (x.2.1.1, x.2.2))
  | 16, 0, .kv x => ∑ c, E.Y (x.1, c) * B.Wk c x.2
  | 16, 1, .kv x => ∑ c, E.Y (x.1, c) * B.Wv c x.2
  | 17, 1, .s x => ∑ c, E.QR (x.2.1, (x.1, c)) * E.KR (x.2.2, (x.1.1, c))
  | 18, 0, .f x => ∑ c, E.YM (x.1, c) * B.Wg c x.2
  | 18, 1, .f x => ∑ c, E.YM (x.1, c) * B.Wu c x.2
  | _, _, _ => 0

/-- **`SC_RS`'s first row difference**: `gHt·SUM − Σ_j gS·mask·E`. -/
def relRsA (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : W16Data Ct Cw Cg Cj Cd Cf) : W16Pos Ct Cw Cg Cj Cd Cf → GF
  | .ht r => B.gHt r * E.SUM r - ∑ j, B.gS (r.1, r.2, j) * (B.mask (r.1, r.2, j) * E.E (r.1, r.2, j))
  | _ => 0

/-- **`SC_RS`'s second row difference**: `gHt − Σ_j gS·ZSEL`. -/
def relRsB (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : W16Data Ct Cw Cg Cj Cd Cf) : W16Pos Ct Cw Cg Cj Cd Cf → GF
  | .ht r => B.gHt r - ∑ j, B.gS (r.1, r.2, j) * E.ZSEL (r.1, r.2, j)
  | _ => 0

end Tables

section Rels

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ} {P : BlockParams}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf]

/-- **The block's tables are `W16Rels`'s relation tables read through encodings of the flat cubes.** `enc k` sends a
point of host `k`'s flat cube to a position of its product cube, `encHt` a point of `Dom::Ht`'s flat cube; each is
onto its product cube (the axes' encodings are onto, L13 item 2). Clause `j` of host `k` (in `W16Rels`'s order) is
some entry `κ` of the host's batch; the hosted terms, the contractions and `SC_RS`'s row differences are the tables'
pullbacks. -/
structure W16Spec (sh : AlgShape P) (dt : AlgData K L sh) (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (xtE : Cuts3 L → RootsO → W16Data Ct Cw Cg Cj Cd Cf)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf) : Prop where
  cl : ∀ k ∈ algHosts, ∀ j, j < relCount k → ∃ κ, ∀ cu rt bga b,
    dt.cl k cu rt bga κ b = algebraMap GF K (relCl Pb Lay B (xtE cu rt) k j (enc k b))
  gh : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 17 ∧ i = 0) → ∀ cu rt b,
    dt.gh k cu rt i b = algebraMap GF K (relGh Pb Lay B (xtE cu rt) k i (enc k b))
  mm : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 17 ∧ i = 0) → ∀ cu rt b,
    dt.mm k cu rt i b = algebraMap GF K (relMm Pb Lay B (xtE cu rt) k i (enc k b))
  rsA : ∀ cu rt b, dt.rsA cu rt b = algebraMap GF K (relRsA Pb Lay B (xtE cu rt) (encHt b))
  rsB : ∀ cu rt b, dt.rsB cu rt b = algebraMap GF K (relRsB Pb Lay B (xtE cu rt) (encHt b))
  st : ∀ x, ∃ b, enc 2 b = .t x
  sd : ∀ x, ∃ b, enc 14 b = .d x
  sq : ∀ x, ∃ b, enc 15 b = .q x
  sk : ∀ x, ∃ b, enc 16 b = .kv x
  ss : ∀ x, ∃ b, enc 17 b = .s x
  sf : ∀ x, ∃ b, enc 18 b = .f x
  sht : ∀ x, ∃ b, encHt b = .ht x

/-- **`hgdR`'s reindexing at W16R2: `AlgGood` gives `W16Rels`** of the extracted planes, for tables that are
`W16Rels`'s relation tables through onto encodings (`W16Spec`), at a layout whose token axis and head-dimension axis
do not pad (`Dom::S` and `Dom::Kv` do not pad at the registered W16R2 shapes; the two pad-rule fields are then
empty). -/
theorem w16Rels_of_algGood (sh : AlgShape P) (dt : AlgData K L sh) (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (xtE : Cuts3 L → RootsO → W16Data Ct Cw Cg Cj Cd Cf)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : W16Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (hg : AlgGood sh dt cu rt bga) :
    W16Rels S Pb Lay B (xtE cu rt) := by
  obtain ⟨hcl0, hgm0, hA0, hB0⟩ := hg
  have hinj := (algebraMap GF K).injective
  -- the relation tables vanish / agree at every encoded point
  have hcl : ∀ k ∈ algHosts, ∀ j, j < relCount k → ∀ b, relCl Pb Lay B (xtE cu rt) k j (enc k b) = 0 := by
    intro k hk j hj b
    obtain ⟨κ, hκ⟩ := hspec.cl k hk j hj
    have h1 := (hcl0 k hk).1 κ b
    rw [hκ cu rt bga b] at h1
    exact hinj (h1.trans (map_zero _).symm)
  have hgm : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 17 ∧ i = 0) → ∀ b,
      relGh Pb Lay B (xtE cu rt) k i (enc k b) = relMm Pb Lay B (xtE cu rt) k i (enc k b) := by
    intro k hk i hrs b
    have h1 := hgm0 k hk i hrs b
    rw [hspec.gh k hk i hrs cu rt b, hspec.mm k hk i hrs cu rt b] at h1
    exact hinj h1
  have hA : ∀ b, relRsA Pb Lay B (xtE cu rt) (encHt b) = 0 := fun b => by
    have h1 := hA0 b
    rw [hspec.rsA cu rt b] at h1
    exact hinj (h1.trans (map_zero _).symm)
  have hB : ∀ b, relRsB Pb Lay B (xtE cu rt) (encHt b) = 0 := fun b => by
    have h1 := hB0 b
    rw [hspec.rsB cu rt b] at h1
    exact hinj (h1.trans (map_zero _).symm)
  -- on the product cubes, by the encodings' surjectivity
  have cT : ∀ j, j < 6 → ∀ t, relCl Pb Lay B (xtE cu rt) 2 j (.t t) = 0 := fun j hj t => by
    obtain ⟨b, hb⟩ := hspec.st t
    rw [← hb]
    exact hcl 2 (by decide) j hj b
  have cD : ∀ j, j < 6 → ∀ x, relCl Pb Lay B (xtE cu rt) 14 j (.d x) = 0 := fun j hj x => by
    obtain ⟨b, hb⟩ := hspec.sd x
    rw [← hb]
    exact hcl 14 (by decide) j hj b
  have cQ : ∀ x, relCl Pb Lay B (xtE cu rt) 15 0 (.q x) = 0 := fun x => by
    obtain ⟨b, hb⟩ := hspec.sq x
    rw [← hb]
    exact hcl 15 (by decide) 0 (by decide) b
  have cK : ∀ x, relCl Pb Lay B (xtE cu rt) 16 0 (.kv x) = 0 := fun x => by
    obtain ⟨b, hb⟩ := hspec.sk x
    rw [← hb]
    exact hcl 16 (by decide) 0 (by decide) b
  have cS : ∀ j, j < 4 → ∀ x, relCl Pb Lay B (xtE cu rt) 17 j (.s x) = 0 := fun j hj x => by
    obtain ⟨b, hb⟩ := hspec.ss x
    rw [← hb]
    exact hcl 17 (by decide) j hj b
  have cF : ∀ x, relCl Pb Lay B (xtE cu rt) 18 0 (.f x) = 0 := fun x => by
    obtain ⟨b, hb⟩ := hspec.sf x
    rw [← hb]
    exact hcl 18 (by decide) 0 (by decide) b
  have gT : ∀ i : Fin 2, ∀ t, relGh Pb Lay B (xtE cu rt) 2 i (.t t) = relMm Pb Lay B (xtE cu rt) 2 i (.t t) :=
    fun i t => by
      obtain ⟨b, hb⟩ := hspec.st t
      rw [← hb]
      exact hgm 2 (by decide) i (by decide) b
  have gD : ∀ i : Fin 2, ∀ x, relGh Pb Lay B (xtE cu rt) 14 i (.d x) = relMm Pb Lay B (xtE cu rt) 14 i (.d x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sd x
      rw [← hb]
      exact hgm 14 (by decide) i (by decide) b
  have gQ : ∀ i : Fin 2, ∀ x, relGh Pb Lay B (xtE cu rt) 15 i (.q x) = relMm Pb Lay B (xtE cu rt) 15 i (.q x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sq x
      rw [← hb]
      exact hgm 15 (by decide) i (by decide) b
  have gK : ∀ i : Fin 2, ∀ x, relGh Pb Lay B (xtE cu rt) 16 i (.kv x) = relMm Pb Lay B (xtE cu rt) 16 i (.kv x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sk x
      rw [← hb]
      exact hgm 16 (by decide) i (by decide) b
  have gS : ∀ x, relGh Pb Lay B (xtE cu rt) 17 (1 : Fin 2) (.s x) = relMm Pb Lay B (xtE cu rt) 17 (1 : Fin 2) (.s x) :=
    fun x => by
      obtain ⟨b, hb⟩ := hspec.ss x
      rw [← hb]
      exact hgm 17 (by decide) 1 (by decide) b
  have gF : ∀ i : Fin 2, ∀ x, relGh Pb Lay B (xtE cu rt) 18 i (.f x) = relMm Pb Lay B (xtE cu rt) 18 i (.f x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sf x
      rw [← hb]
      exact hgm 18 (by decide) i (by decide) b
  have rA : ∀ r, relRsA Pb Lay B (xtE cu rt) (.ht r) = 0 := fun r => by
    obtain ⟨b, hb⟩ := hspec.sht r
    rw [← hb]
    exact hA b
  have rB : ∀ r, relRsB Pb Lay B (xtE cu rt) (.ht r) = 0 := fun r => by
    obtain ⟨b, hb⟩ := hspec.sht r
    rw [← hb]
    exact hB b
  exact
    { tzc_sq := cT 0 (by decide)
      tzc_d := cT 1 (by decide)
      tzc_a := cT 2 (by decide)
      tzc_sqm := cT 3 (by decide)
      tzc_dm := cT 4 (by decide)
      tzc_am := cT 5 (by decide)
      ss := gT 0
      ssm := gT 1
      d0 := cD 0 (by decide)
      d1 := cD 1 (by decide)
      d2 := cD 2 (by decide)
      d3 := cD 3 (by decide)
      d4 := cD 4 (by decide)
      d5 := cD 5 (by decide)
      wo := gD 0
      dmm := gD 1
      qrope := cQ
      qmm := gQ 0
      pv := gQ 1
      krope := cK
      kmm := gK 0
      vmm := gK 1
      s0 := cS 0 (by decide)
      s1 := cS 1 (by decide)
      s2 := cS 2 (by decide)
      s3 := cS 3 (by decide)
      rsE := fun r => sub_eq_zero.mp (rA r)
      rsZ := fun r => sub_eq_zero.mp (rB r)
      score := gS
      f0 := cF
      gmm := gF 0
      umm := gF 1
      pp_pad := fun s t j h => by
        obtain ⟨i, hi⟩ := hTok j
        exact absurd hi (h i)
      kr_pad := fun j g c h => by
        obtain ⟨e, he⟩ := hHd c
        exact absurd he (h e) }

end Rels

end ZK60.Exec.Block
