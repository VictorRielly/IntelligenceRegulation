/-
D63 lane L36 (2026-11-09), part 4b: **`hgdR` at R13: the start claims give `R13Rels`** (the R13 reindexing, the
premise `hrels` of `block_knowledge_alg_r13` and `block_knowledge_alg_r13_shield`), as `BlockAlgRels.lean` does for
`W16Rels`.

R13 runs the same 23 slots, hosts and hosted pairs as W16R2 (`SlotR13.lean`); its six zero-checks batch more clauses:
the word decompositions W16R2 drops and the quotient's (`R13Rels`, L17). So:

* `r13Cl`, `r13Count`: `R13Rels`'s gated clauses as tables on the product cubes, in `R13Rels`'s order: `SC_TZC` 6,
  `SC_DZC` 13 (`d0 … d5`, then the seven word decompositions), `SC_QZC` 4 (`qrope`, then `Q`, `QR`, `O`), `SC_KVZC`
  4 (`krope`, then `K`, `KR`, `V`), `SC_SZC` 5 (`s0 … s4`), `SC_FZC` 3 (`f0`, `f1`, `f2`);
* `r13Gh`, `r13Mm`, `r13RsA`, `r13RsB`: the hosted pairs' gated host terms (with the byte-limb sums `lv` in place of
  W16's limb pairs) and contractions, and `SC_RS`'s two row differences;
* `R13Spec`: **the tables of an `AlgData` are those relation tables read through encodings of the flat cubes**, each
  encoding onto its product cube (the same shape as `W16Spec`);
* **`r13Rels_of_algGood`**: `AlgGood` and `R13Spec` give `R13Rels` of the extracted planes, at a layout whose token
  and head-dimension axes do not pad;
* **`block_knowledge_alg_r13_spec`**, **`block_knowledge_alg_r13_shield_spec`**: the R13 rung and the Shieldstral T128
  R13 block's statements with `hrels` replaced by `R13Spec` and the two axes that do not pad, as at W16R2.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgFinal

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open ZK60.Layout.R13 (R13Data R13Rels lv)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)
open scoped ENNReal

section Tables

variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] {ls : ℕ}

/-- **`R13Rels`'s gated clauses as a table**: clause `j` of host `k` at a position of the host's cube, in `R13Rels`'s
order (`0` elsewhere). -/
def r13Cl (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) : ℕ → ℕ → W16Pos Ct Cw Cg Cj Cd Cf → GF
  | 2, 0, .t t => E.dsqA t - E.dA t * E.dA t
  | 2, 1, .t t => E.dA t - (E.la 0 0 t + 2 ^ 8 * E.la 0 1 t + 2 ^ 16 * E.la 0 2 t)
  | 2, 2, .t t => 2 * E.dA t - (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t)
      - (E.la 2 0 t + 2 ^ 8 * E.la 2 1 t + 2 ^ 16 * E.la 2 2 t)
  | 2, 3, .t t => E.dsqM t - E.dM t * E.dM t
  | 2, 4, .t t => E.dM t - (E.lm 0 0 t + 2 ^ 8 * E.lm 0 1 t + 2 ^ 16 * E.lm 0 2 t)
  | 2, 5, .t t => 2 * E.dM t - (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t)
      - (E.lm 2 0 t + 2 ^ 8 * E.lm 2 1 t + 2 ^ 16 * E.lm 2 2 t)
  | 14, 0, .d x => B.gD x * (B.gamA x * E.X x * (2 * (S.cnA : GF)) + E.dA x.1 * 2 ^ S.tn
      - 2 ^ (S.tn + 1) * E.dA x.1 * E.Y x - lv E.nr x)
  | 14, 1, .d x => B.gD x * (lv E.nr x + lv E.ns x + 1 - 2 ^ (S.tn + 1) * E.dA x.1)
  | 14, 2, .d x => B.gD x * (E.X1 x - E.X x - E.AO x)
  | 14, 3, .d x => B.gD x * (B.gamM x * E.X1 x * (2 * (S.cnM : GF)) + E.dM x.1 * 2 ^ S.tn
      - 2 ^ (S.tn + 1) * E.dM x.1 * E.YM x - lv E.mr x)
  | 14, 4, .d x => B.gD x * (lv E.mr x + lv E.ms x + 1 - 2 ^ (S.tn + 1) * E.dM x.1)
  | 14, 5, .d x => B.gD x * (E.X2 x - E.X1 x - E.Z x)
  | 14, 6, .d x => B.gD x * (E.X x + 32768 - lv E.xl x)
  | 14, 7, .d x => B.gD x * (E.Y x + 32768 - lv E.yl x)
  | 14, 8, .d x => B.gD x * (E.AO x + 32768 - lv E.aol x)
  | 14, 9, .d x => B.gD x * (E.X1 x + 32768 - lv E.x1l x)
  | 14, 10, .d x => B.gD x * (E.YM x + 32768 - lv E.yml x)
  | 14, 11, .d x => B.gD x * (E.Z x + 32768 - lv E.zl x)
  | 14, 12, .d x => B.gD x * (E.X2 x + 32768 - lv E.x2l x)
  | 15, 0, .q x => B.gQ x * (B.cosT x * E.Q x + B.sinT x * E.Q (x.1, (x.2.1, Lay.flip x.2.2)) - 2 ^ 7 * E.QR x
      - lv E.rqrl x + 2 ^ 6)
  | 15, 1, .q x => B.gQ x * (E.Q x + 32768 - lv E.ql x)
  | 15, 2, .q x => B.gQ x * (E.QR x + 32768 - lv E.qrl x)
  | 15, 3, .q x => B.gQ x * (E.O x + 32768 - lv E.ol x)
  | 16, 0, .kv x => B.gK x * (B.cosK x * E.K x + B.sinK x * E.K (x.1, (x.2.1, Lay.flip x.2.2)) - 2 ^ 7 * E.KR x
      - lv E.rkrl x + 2 ^ 6)
  | 16, 1, .kv x => B.gK x * (E.K x + 32768 - lv E.kl x)
  | 16, 2, .kv x => B.gK x * (E.KR x + 32768 - lv E.krl x)
  | 16, 3, .kv x => B.gK x * (E.V x + 32768 - lv E.vl x)
  | 17, 0, .s x => B.gS x * (E.ZSEL x * E.ZSEL x - E.ZSEL x)
  | 17, 1, .s x => B.gS x * (E.ZSEL x * (E.MX (x.1, x.2.1) - B.mask x * (E.S8 x + 127) + 127))
  | 17, 2, .s x => B.gS x * (B.mask x * E.E x * 2 ^ S.fp - E.PP x * E.SUM (x.1, x.2.1) - lv E.sr x)
  | 17, 3, .s x => B.gS x * (lv E.sg x + lv E.sr x + 1 - E.SUM (x.1, x.2.1))
  | 17, 4, .s x => B.gS x * (E.PP x - lv E.pl x)
  | 18, 0, .f x => B.gF x * (E.A x * E.U x - 2 ^ S.sprod * E.H x - lv E.rh x + 2 ^ (S.sprod - 1))
  | 18, 1, .f x => B.gF x * (E.U x + 32768 - lv E.ul x)
  | 18, 2, .f x => B.gF x * (E.H x + 2 ^ 23 - lv E.hl x)
  | _, _, _ => 0

/-- How many gated clauses of `R13Rels` each host carries. -/
def r13Count (k : ℕ) : ℕ :=
  if k = 2 then 6 else if k = 14 then 13 else if k = 15 then 4 else if k = 16 then 4 else if k = 17 then 5
  else if k = 18 then 3 else 0

/-- The clause counts: `SC_TZC` 6, `SC_DZC` 13, `SC_QZC` 4, `SC_KVZC` 4, `SC_SZC` 5, `SC_FZC` 3. -/
theorem r13Cl_count : algHosts.map r13Count = [6, 13, 4, 4, 5, 3] := by decide

/-- **A hosted pair's gated host term at R13** (the left side of `R13Rels`'s hosted identity, with `lv`). -/
def r13Gh (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) : ℕ → ℕ → W16Pos Ct Cw Cg Cj Cd Cf → GF
  | 2, 0, .t t => B.gT t * (E.dsqA t + (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t) - (S.ceps : GF))
  | 2, 1, .t t => B.gT t * (E.dsqM t + (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t) - (S.ceps : GF))
  | 14, 0, .d x => B.gD x * (2 ^ S.sao * E.AO x + lv E.ral x - 2 ^ (S.sao - 1))
  | 14, 1, .d x => B.gD x * (2 ^ S.sdown * E.Z x + lv E.rdl x - 2 ^ (S.sdown - 1))
  | 15, 0, .q x => B.gQ x * (2 ^ S.sq * E.Q x + lv E.rql x - 2 ^ (S.sq - 1))
  | 15, 1, .q x => B.gQ x * (2 ^ S.spv * E.O x + lv E.ro x - 2 ^ (S.spv - 1))
  | 16, 0, .kv x => B.gK x * (2 ^ S.sk * E.K x + lv E.rkl x - 2 ^ (S.sk - 1))
  | 16, 1, .kv x => B.gK x * (2 ^ S.sv * E.V x + lv E.rvl x - 2 ^ (S.sv - 1))
  | 17, 1, .s x => B.gS x * (2 ^ S.ss * E.S8 x + lv E.rsl x - 2 ^ (S.ss - 1))
  | 18, 0, .f x => B.gF x * (2 ^ S.sgate * E.G x + lv E.rgl x - 2 ^ (S.sgate - 1))
  | 18, 1, .f x => B.gF x * (2 ^ S.sup * E.U x + lv E.ru x - 2 ^ (S.sup - 1))
  | _, _, _ => 0

/-- **A hosted pair's contraction at R13** (the right side of `R13Rels`'s hosted identity). -/
def r13Mm (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) : ℕ → ℕ → W16Pos Ct Cw Cg Cj Cd Cf → GF
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

/-- **`SC_RS`'s first row difference at R13**: `gHt·SUM − Σ_j gS·mask·E`. -/
def r13RsA (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) : W16Pos Ct Cw Cg Cj Cd Cf → GF
  | .ht r => B.gHt r * E.SUM r - ∑ j, B.gS (r.1, r.2, j) * (B.mask (r.1, r.2, j) * E.E (r.1, r.2, j))
  | _ => 0

/-- **`SC_RS`'s second row difference at R13**: `gHt − Σ_j gS·ZSEL`. -/
def r13RsB (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) : W16Pos Ct Cw Cg Cj Cd Cf → GF
  | .ht r => B.gHt r - ∑ j, B.gS (r.1, r.2, j) * E.ZSEL (r.1, r.2, j)
  | _ => 0

end Tables

section Rels

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ} {P : BlockParams}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] {ls : ℕ}

/-- **The block's tables are `R13Rels`'s relation tables read through encodings of the flat cubes** (as `W16Spec`):
clause `j` of host `k` (in `R13Rels`'s order) is some entry `κ` of the host's batch; the hosted terms, the
contractions and `SC_RS`'s row differences are the tables' pullbacks; each encoding is onto its product cube. -/
structure R13Spec (sh : AlgShape P) (dt : AlgData K L sh) (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (xtE : Cuts3 L → RootsO → R13Data Ct Cw Cg Cj Cd Cf ls)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf) : Prop where
  cl : ∀ k ∈ algHosts, ∀ j, j < r13Count k → ∃ κ, ∀ cu rt bga b,
    dt.cl k cu rt bga κ b = algebraMap GF K (r13Cl Pb Lay B (xtE cu rt) k j (enc k b))
  gh : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 17 ∧ i = 0) → ∀ cu rt b,
    dt.gh k cu rt i b = algebraMap GF K (r13Gh Pb Lay B (xtE cu rt) k i (enc k b))
  mm : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 17 ∧ i = 0) → ∀ cu rt b,
    dt.mm k cu rt i b = algebraMap GF K (r13Mm Pb Lay B (xtE cu rt) k i (enc k b))
  rsA : ∀ cu rt b, dt.rsA cu rt b = algebraMap GF K (r13RsA Pb Lay B (xtE cu rt) (encHt b))
  rsB : ∀ cu rt b, dt.rsB cu rt b = algebraMap GF K (r13RsB Pb Lay B (xtE cu rt) (encHt b))
  st : ∀ x, ∃ b, enc 2 b = .t x
  sd : ∀ x, ∃ b, enc 14 b = .d x
  sq : ∀ x, ∃ b, enc 15 b = .q x
  sk : ∀ x, ∃ b, enc 16 b = .kv x
  ss : ∀ x, ∃ b, enc 17 b = .s x
  sf : ∀ x, ∃ b, enc 18 b = .f x
  sht : ∀ x, ∃ b, encHt b = .ht x

/-- **`hgdR`'s reindexing at R13: `AlgGood` gives `R13Rels`** of the extracted planes, for tables that are `R13Rels`'s
relation tables through onto encodings (`R13Spec`), at a layout whose token axis and head-dimension axis do not pad
(the two pad-rule fields are then empty, finding L36-4). This discharges the premise `hrels` of
`block_knowledge_alg_r13` and `block_knowledge_alg_r13_shield` from `R13Spec`. -/
theorem r13Rels_of_algGood (sh : AlgShape P) (dt : AlgData K L sh) (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (xtE : Cuts3 L → RootsO → R13Data Ct Cw Cg Cj Cd Cf ls)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : R13Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (hg : AlgGood sh dt cu rt bga) :
    R13Rels S Pb Lay B (xtE cu rt) := by
  obtain ⟨hcl0, hgm0, hA0, hB0⟩ := hg
  have hinj := (algebraMap GF K).injective
  -- the relation tables vanish / agree at every encoded point
  have hcl : ∀ k ∈ algHosts, ∀ j, j < r13Count k → ∀ b, r13Cl Pb Lay B (xtE cu rt) k j (enc k b) = 0 := by
    intro k hk j hj b
    obtain ⟨κ, hκ⟩ := hspec.cl k hk j hj
    have h1 := (hcl0 k hk).1 κ b
    rw [hκ cu rt bga b] at h1
    exact hinj (h1.trans (map_zero (algebraMap GF K)).symm)
  have hgm : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 17 ∧ i = 0) → ∀ b,
      r13Gh Pb Lay B (xtE cu rt) k i (enc k b) = r13Mm Pb Lay B (xtE cu rt) k i (enc k b) := by
    intro k hk i hrs b
    have h1 := hgm0 k hk i hrs b
    rw [hspec.gh k hk i hrs cu rt b, hspec.mm k hk i hrs cu rt b] at h1
    exact hinj h1
  have hA : ∀ b, r13RsA Pb Lay B (xtE cu rt) (encHt b) = 0 := fun b => by
    have h1 := hA0 b
    rw [hspec.rsA cu rt b] at h1
    exact hinj (h1.trans (map_zero (algebraMap GF K)).symm)
  have hB : ∀ b, r13RsB Pb Lay B (xtE cu rt) (encHt b) = 0 := fun b => by
    have h1 := hB0 b
    rw [hspec.rsB cu rt b] at h1
    exact hinj (h1.trans (map_zero (algebraMap GF K)).symm)
  -- on the product cubes, by the encodings' surjectivity
  have cT : ∀ j, j < 6 → ∀ t, r13Cl Pb Lay B (xtE cu rt) 2 j (.t t) = 0 := fun j hj t => by
    obtain ⟨b, hb⟩ := hspec.st t
    rw [← hb]
    exact hcl 2 (by decide) j hj b
  have cD : ∀ j, j < 13 → ∀ x, r13Cl Pb Lay B (xtE cu rt) 14 j (.d x) = 0 := fun j hj x => by
    obtain ⟨b, hb⟩ := hspec.sd x
    rw [← hb]
    exact hcl 14 (by decide) j hj b
  have cQ : ∀ j, j < 4 → ∀ x, r13Cl Pb Lay B (xtE cu rt) 15 j (.q x) = 0 := fun j hj x => by
    obtain ⟨b, hb⟩ := hspec.sq x
    rw [← hb]
    exact hcl 15 (by decide) j hj b
  have cK : ∀ j, j < 4 → ∀ x, r13Cl Pb Lay B (xtE cu rt) 16 j (.kv x) = 0 := fun j hj x => by
    obtain ⟨b, hb⟩ := hspec.sk x
    rw [← hb]
    exact hcl 16 (by decide) j hj b
  have cS : ∀ j, j < 5 → ∀ x, r13Cl Pb Lay B (xtE cu rt) 17 j (.s x) = 0 := fun j hj x => by
    obtain ⟨b, hb⟩ := hspec.ss x
    rw [← hb]
    exact hcl 17 (by decide) j hj b
  have cF : ∀ j, j < 3 → ∀ x, r13Cl Pb Lay B (xtE cu rt) 18 j (.f x) = 0 := fun j hj x => by
    obtain ⟨b, hb⟩ := hspec.sf x
    rw [← hb]
    exact hcl 18 (by decide) j hj b
  have gT : ∀ i : Fin 2, ∀ t, r13Gh Pb Lay B (xtE cu rt) 2 i (.t t) = r13Mm Pb Lay B (xtE cu rt) 2 i (.t t) :=
    fun i t => by
      obtain ⟨b, hb⟩ := hspec.st t
      rw [← hb]
      exact hgm 2 (by decide) i (fun h => absurd h.1 (by decide)) b
  have gD : ∀ i : Fin 2, ∀ x, r13Gh Pb Lay B (xtE cu rt) 14 i (.d x) = r13Mm Pb Lay B (xtE cu rt) 14 i (.d x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sd x
      rw [← hb]
      exact hgm 14 (by decide) i (fun h => absurd h.1 (by decide)) b
  have gQ : ∀ i : Fin 2, ∀ x, r13Gh Pb Lay B (xtE cu rt) 15 i (.q x) = r13Mm Pb Lay B (xtE cu rt) 15 i (.q x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sq x
      rw [← hb]
      exact hgm 15 (by decide) i (fun h => absurd h.1 (by decide)) b
  have gK : ∀ i : Fin 2, ∀ x, r13Gh Pb Lay B (xtE cu rt) 16 i (.kv x) = r13Mm Pb Lay B (xtE cu rt) 16 i (.kv x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sk x
      rw [← hb]
      exact hgm 16 (by decide) i (fun h => absurd h.1 (by decide)) b
  have gS : ∀ x, r13Gh Pb Lay B (xtE cu rt) 17 (1 : Fin 2) (.s x) = r13Mm Pb Lay B (xtE cu rt) 17 (1 : Fin 2) (.s x) :=
    fun x => by
      obtain ⟨b, hb⟩ := hspec.ss x
      rw [← hb]
      exact hgm 17 (by decide) 1 (by decide) b
  have gF : ∀ i : Fin 2, ∀ x, r13Gh Pb Lay B (xtE cu rt) 18 i (.f x) = r13Mm Pb Lay B (xtE cu rt) 18 i (.f x) :=
    fun i x => by
      obtain ⟨b, hb⟩ := hspec.sf x
      rw [← hb]
      exact hgm 18 (by decide) i (fun h => absurd h.1 (by decide)) b
  have rA : ∀ r, r13RsA Pb Lay B (xtE cu rt) (.ht r) = 0 := fun r => by
    obtain ⟨b, hb⟩ := hspec.sht r
    rw [← hb]
    exact hA b
  have rB : ∀ r, r13RsB Pb Lay B (xtE cu rt) (.ht r) = 0 := fun r => by
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
      wX := cD 6 (by decide)
      wY := cD 7 (by decide)
      wAO := cD 8 (by decide)
      wX1 := cD 9 (by decide)
      wYM := cD 10 (by decide)
      wZ := cD 11 (by decide)
      wX2 := cD 12 (by decide)
      wo := gD 0
      dmm := gD 1
      qrope := cQ 0 (by decide)
      wQ := cQ 1 (by decide)
      wQR := cQ 2 (by decide)
      wO := cQ 3 (by decide)
      qmm := gQ 0
      pv := gQ 1
      krope := cK 0 (by decide)
      wK := cK 1 (by decide)
      wKR := cK 2 (by decide)
      wV := cK 3 (by decide)
      kmm := gK 0
      vmm := gK 1
      s0 := cS 0 (by decide)
      s1 := cS 1 (by decide)
      s2 := cS 2 (by decide)
      s3 := cS 3 (by decide)
      s4 := cS 4 (by decide)
      rsE := fun r => sub_eq_zero.mp (rA r)
      rsZ := fun r => sub_eq_zero.mp (rB r)
      score := gS
      f0 := cF 0 (by decide)
      f1 := cF 1 (by decide)
      f2 := cF 2 (by decide)
      gmm := gF 0
      umm := gF 1
      pp_pad := fun s t j h => by
        obtain ⟨i, hi⟩ := hTok j
        exact absurd hi (h i)
      kr_pad := fun j g c h => by
        obtain ⟨e, he⟩ := hHd c
        exact absurd he (h e) }

end Rels

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One R13 rung block's knowledge statement with the relation layers' algebra discharged, the reindexing
included** (D63 lane L36): `block_knowledge_alg_r13` with the premise `hrels` replaced by `R13Spec` at a layout whose
token and head-dimension axes do not pad, as `block_knowledge_alg_w16r2` at W16R2. -/
theorem block_knowledge_alg_r13_spec [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungR13 P tag rowsOf)
    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)
    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = 148) (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = 55)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hPoly : ∀ cu rt, SlotEvalN U P (Link.csRungR13 U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))
    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    {ls : ℕ} (hW13 : ZK60.Layout.R13.R13Windows S ls) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.R13.R13Data Ct Cw Cg Cj Cd Cf ls)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the block's algebra: the shape facts, the tables, the hosts' named identities, the reindexing
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : R13Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).toW16 S)))
      ≤ εsTarget q + εend :=
  block_knowledge_alg_r13 U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP aC hC hdc hsA hsH hdrLen hdrSq hh hq
    Poly csE hpolyC hPoly hdegP Pb Lay B hW13 h24 xtE q A hA εend hEnd sh dt hform
    (fun cu rt bga hg => r13Rels_of_algGood sh dt Pb Lay B xtE enc encHt hspec hTok hHd cu rt bga hg)
    HGd spH hdgH hformH hgdH Alk T mlk hN he hbr hhr

/-- **One Shieldstral T128 R13 block's knowledge statement with the relation layers' algebra discharged, the
reindexing included** (the media app's classifier block): `block_knowledge_alg_r13_shield` with `hrels` replaced by
`R13Spec`. The premise `he` is L31's: see finding L36-1 before using it at this block. -/
theorem block_knowledge_alg_r13_shield_spec [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldR13 P tag rowsOf)
    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)
    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = 146) (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = 54)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hPoly : ∀ cu rt, SlotEvalN U P (Link.csShieldR13 U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))
    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    {ls : ℕ} (hW13 : ZK60.Layout.R13.R13Windows S ls) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.R13.R13Data Ct Cw Cg Cj Cd Cf ls)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the block's algebra: the shape facts, the tables, the hosts' named identities, the reindexing
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (enc : (k : ℕ) → (Fin (segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : R13Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).toW16 S)))
      ≤ εsTarget q + εend :=
  block_knowledge_alg_r13_shield U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP aC hC hdc hsA hsH hdrLen hdrSq hh
    hq Poly csE hpolyC hPoly hdegP Pb Lay B hW13 h24 xtE q A hA εend hEnd sh dt hform
    (fun cu rt bga hg => r13Rels_of_algGood sh dt Pb Lay B xtE enc encHt hspec hTok hHd cu rt bga hg)
    HGd spH hdgH hformH hgdH Alk T mlk hN he hbr hhr

end Final

end ZK60.Exec.Block
