/-
D63 lane L49 (2026-11-10), sub-agent `tzc`, part 1: **R13's `SC_TZC` (slot `2`) and its hosted `SC_SS` (slot `0`) and
`SC_SSM` (slot `1`), generic in the configuration** (the R13 rung `cfgRungR13` and every Shieldstral layer
`cfgShieldR13 L`), on the foundation `BlockR13HostBase.lean`; lane L41's `BlockJoinTzc.lean` at R13.

* `drS`, `aTz`, `rawSsR`, `tabsTzcR`, `rrT`, `irTzcR`, `rawTzcR`: the three raw slots written out for any configuration
  (`eq` tables on the slots' draws, the `A` planes at `DefR13.aOff c q`, the nine byte-limb sub-slices of the `Dom::L`
  planes `6`, `7` at `aOff c q + k·2^lt`, L13's `ssIr` and `tzcIr` with the configuration's `ceps`);
* **`TzcCfg c`**: the facts about `c` this host reads (the three raw slots ARE those, slot `2` draws `τ, μ (6), ν (2)`
  and no `ζ`, `ceps` fits a signed 64-bit word); **`tzcCfg_rung`**, **`tzcCfg_shield`** (every layer `L`, by
  evaluation with `L` free), `tzcCfg_shieldExport`;
* `TzcEnt`, **`tzcR_ent`**: the value list `SC_TZC`'s IR reads at a cube point (the zero extension) IS the extracted
  planes `xtR`'s `dA`, `dsqA`, `la`, `dM`, `dsqM`, `lm`, embedded;
* **`tzcR_Z`**, **`tzcR_H0`**, **`tzcR_H1`**: the IR's batched clauses and its two hosted terms ARE R13's `r13Cl 2 j`
  (`j < 6`) and `r13Gh 2 i` (the token gate is `1`; `ceps` read in the field from the code word, any `ceps` in range);
* **`tzcR_cube`**: `SC_TZC`'s cube sum is `Σ_t hostPoly(τ, Σ_j μ_j·r13Cl 2 j, ν, (r_t, r_t2), 1, r13Gh 2)(t)`;
* **`ssR_cube`**: `SC_SS`'s (`SC_SSM`'s) cube sum is the multilinear extension of the gated row sums of squares of its
  plane at its claim point.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Tzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB aPl_alg cstK cstS_map cstK_base cstK_tzc tabK_pa_cpt sum_append)
open ZK60.Exec.Block.DefW16 (W16Cfg cstS aTab rhoC numTabs)
open ZK60.Exec.Slot.Build (hostTerms gV gV_none gV_some L256 batchV tzcIr tzcClauses tzcIr_eval TzcR padSem ssIr
  ssIr_eval)
open ZK60.Exec.Slot.Compose (tzcIr_map ssIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The three raw slots, for any configuration -/

/-- The draws `off … off + n − 1` of slot `s`, as expressions. -/
def drS (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

theorem drS_length (s off n : ℕ) : (drS s off n).length = n := by simp [drS]

theorem drS_getD (ev : Sym → Fp2) (s off n a : ℕ) (ha : a < n) :
    ((drS s off n).map ev).getD a Fp2.zero = ev (.dr s (off + a)) := by
  unfold drS
  rw [List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range ha]
  rfl

/-- A draw of the slot itself. -/
theorem eval_dr_self (hist : Hist) (k : ℕ) (dr : List Fp2) (i : ℕ) :
    Sym.eval hist k dr (.dr k i) = dr.getD i Fp2.zero := by
  show drawAt hist k dr k i = _
  unfold drawAt
  rw [ite_eq_left rfl]

/-- An `A` plane on its own first `log` coordinates (`a_slice`). -/
def aTz (off log : ℕ) : TabS := aTab off log (rhoC 0 log) 0

/-- **R13's `SC_SS` (`s = 0`, plane `q = X`) and `SC_SSM` (`s = 1`, `q = X1`)**: `eq(r_t)` on the slot's first `lt`
draws, the plane on `Dom::D`, the gate `supp(D)`; `supp·eq·x·x`. -/
def rawSsR (c : W16Cfg) (s q : ℕ) : SlotS :=
  ⟨[TabS.eq (drS s 0 c.sh.lt) 0, aTz (DefR13.aOff c q) (c.sh.lt + c.sh.ld), TabS.pub 0], ssIr cstS 0 1 (some 2),
    [], []⟩

/-- **R13's `SC_TZC` tables**: `eq(τ)`, `eq(r_t)` (`SC_SS`'s point), `eq(r_t2)` (`SC_SSM`'s), the `Dom::T` planes `D`
(id `0`), `DSQ` (`1`), the nine byte-limb sub-slices of the `Dom::L` plane `6` (`aOff c 6 + k·2^lt`), `DM` (`2`), `DSQM`
(`3`), the nine of plane `7`; no gate (`Dom::T` does not pad). -/
def tabsTzcR (c : W16Cfg) : List TabS :=
  [TabS.eq (drS 2 0 c.sh.lt) 0, TabS.eq (drS 0 0 c.sh.lt) 0, TabS.eq (drS 1 0 c.sh.lt) 0,
    aTz (DefR13.aOff c 0) c.sh.lt, aTz (DefR13.aOff c 1) c.sh.lt,
    aTz (DefR13.aOff c 6 + 0 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 1 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 2 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 3 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 4 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 5 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 6 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 6 + 7 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 6 + 8 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 2) c.sh.lt, aTz (DefR13.aOff c 3) c.sh.lt,
    aTz (DefR13.aOff c 7 + 0 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 1 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 2 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 3 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 4 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 5 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 6 * 2 ^ c.sh.lt) c.sh.lt, aTz (DefR13.aOff c 7 + 7 * 2 ^ c.sh.lt) c.sh.lt,
    aTz (DefR13.aOff c 7 + 8 * 2 ^ c.sh.lt) c.sh.lt]

/-- `SC_TZC`'s table positions (no gate). -/
def rrT : TzcR := ⟨0, 1, 2, 3, 4, 14, 15, none⟩

/-- **R13's `SC_TZC` IR**: L13's `tzcIr` at the configuration's `ceps`, `μ` draws `lt … lt + 5`, `ν` draws `lt + 6`,
`lt + 7`, no pad group. -/
def irTzcR (c : W16Cfg) : ZK60.Exec.Slot.Ir Sym :=
  tzcIr cstS rrT c.p.ceps (drS 2 c.sh.lt 6) (drS 2 (c.sh.lt + 6) 2) (fun j => Sym.pow Sym.zero j) []

/-- **R13's raw `SC_TZC` slot**: it hosts `SC_SS` at `ν_0` and `SC_SSM` at `ν_1`. -/
def rawTzcR (c : W16Cfg) : SlotS :=
  ⟨tabsTzcR c, irTzcR c, [(0, Sym.dr 2 (c.sh.lt + 6)), (1, Sym.dr 2 (c.sh.lt + 7))], drS 2 (c.sh.lt + 6) 2⟩

/-! ## The configuration's facts -/

/-- **The facts about a configuration `SC_TZC`'s named identity reads**: the program's raw slots `0`, `1`, `2` are
`rawSsR c 0 8`, `rawSsR c 1 26`, `rawTzcR c`; slot `2` draws `τ` (`lt`), `μ` (`6`), `ν` (`2`) and no `ζ` (`Dom::T`
does not pad); `ceps` is a signed word below `2^64` in size (the code word `Fp::from_i64(−ceps)`). -/
structure TzcCfg (c : W16Cfg) : Prop where
  raw0 : DefR13.rawSlot c 0 = rawSsR c 0 8
  raw1 : DefR13.rawSlot c 1 = rawSsR c 1 26
  raw2 : DefR13.rawSlot c 2 = rawTzcR c
  dl2 : ZK60.Exec.Slot.R13.draws c.sh 2 = [(.tau, c.sh.lt), (.mu, 6), (.nu, 2), (.zeta, 0)]
  cepsLo : -2 ^ 64 < c.p.ceps
  cepsHi : c.p.ceps < 2 ^ 64

/-- **At the R13 rung** (`ceps = 1`), by evaluation. -/
theorem tzcCfg_rung : TzcCfg DefR13.cfgRungR13 where
  raw0 := rfl
  raw1 := rfl
  raw2 := rfl
  dl2 := rfl
  cepsLo := by
    show -2 ^ 64 < (1 : ℤ)
    norm_num
  cepsHi := by
    show (1 : ℤ) < 2 ^ 64
    norm_num

/-- **At every Shieldstral layer** (`ceps = 2439`), by evaluation with the layer free: these slots do not read the
layer's calibration. -/
theorem tzcCfg_shield (L : ZK60.RunShape.Shield.ShieldLayer) : TzcCfg (DefR13.cfgShieldR13 L) where
  raw0 := rfl
  raw1 := rfl
  raw2 := rfl
  dl2 := rfl
  cepsLo := by
    show -2 ^ 64 < (2439 : ℤ)
    norm_num
  cepsHi := by
    show (2439 : ℤ) < 2 ^ 64
    norm_num

/-- At each of the 26 layers of the app's export. -/
theorem tzcCfg_shieldExport : ∀ L ∈ ZK60.RunShape.Shield.shieldExport, TzcCfg (DefR13.cfgShieldR13 L) :=
  fun L _ => tzcCfg_shield L

/-! ## The value list at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A slot's value list at a point: its tables' extensions. -/
noncomputable def valsOf (P : BlockParams) (D : CmData K P) (n e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2)
    (ts : List TabS) (x : Fin (n + e) → K) : List K :=
  (ts.map (TabS.eval ev pub)).map (tabK U P D n e x)

/-- **An `A` slice on its own `n` coordinates, at the zero extension of a cube of `n` main variables.** -/
theorem aT_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : 0 < n) (b : Fin n → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) (off m : ℕ) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv ⟨.a, [(off, false)], n, rhoC 0 n, m, 0⟩))
      = aPl U P D off n b := by
  rw [aTab_eval, tabK_pa_cpt U P D hrl n e b n hn rfl, castB_rfl]

/-- A plane entry read as an extracted plane, embedded. -/
theorem ent_pl (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (n : ℕ) (b : Fin n → Bool)
    (off : ℕ) {g : GF} (hg : g = piB K (aPl U P D off n b)) {x : K} (h : x = aPl U P D off n b) :
    x = algebraMap GF K g := by
  rw [hg, aPl_alg U P D hX, h]

theorem getD_map_toK (l : List Fp2) (k : ℕ) : (l.map (Fp2.toK U)).getD k 0 = (l.getD k Fp2.zero).toK U := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map]
  cases l[k]? with
  | none => simp [Fp2.toK_zero]
  | some y => rfl

/-- **`SC_TZC`'s plane entries at a token `t`**: entries `3`, `4` are `D`, `DSQ`; `5 + 3i + k` the byte limb `la i k`;
`14`, `15` are `DM`, `DSQM`; `16 + 3i + k` the byte limb `lm i k` (the extracted planes, embedded). -/
structure TzcEnt (c : W16Cfg) (P : BlockParams) (D : CmData K P) (ls : ℕ) (t : CtR c) (v : List K) : Prop where
  d : v.getD 3 0 = algebraMap GF K ((xtR U c P D ls).dA t)
  dsq : v.getD 4 0 = algebraMap GF K ((xtR U c P D ls).dsqA t)
  l00 : v.getD 5 0 = algebraMap GF K ((xtR U c P D ls).la 0 0 t)
  l01 : v.getD 6 0 = algebraMap GF K ((xtR U c P D ls).la 0 1 t)
  l02 : v.getD 7 0 = algebraMap GF K ((xtR U c P D ls).la 0 2 t)
  l10 : v.getD 8 0 = algebraMap GF K ((xtR U c P D ls).la 1 0 t)
  l11 : v.getD 9 0 = algebraMap GF K ((xtR U c P D ls).la 1 1 t)
  l12 : v.getD 10 0 = algebraMap GF K ((xtR U c P D ls).la 1 2 t)
  l20 : v.getD 11 0 = algebraMap GF K ((xtR U c P D ls).la 2 0 t)
  l21 : v.getD 12 0 = algebraMap GF K ((xtR U c P D ls).la 2 1 t)
  l22 : v.getD 13 0 = algebraMap GF K ((xtR U c P D ls).la 2 2 t)
  dm : v.getD 14 0 = algebraMap GF K ((xtR U c P D ls).dM t)
  dsqm : v.getD 15 0 = algebraMap GF K ((xtR U c P D ls).dsqM t)
  m00 : v.getD 16 0 = algebraMap GF K ((xtR U c P D ls).lm 0 0 t)
  m01 : v.getD 17 0 = algebraMap GF K ((xtR U c P D ls).lm 0 1 t)
  m02 : v.getD 18 0 = algebraMap GF K ((xtR U c P D ls).lm 0 2 t)
  m10 : v.getD 19 0 = algebraMap GF K ((xtR U c P D ls).lm 1 0 t)
  m11 : v.getD 20 0 = algebraMap GF K ((xtR U c P D ls).lm 1 1 t)
  m12 : v.getD 21 0 = algebraMap GF K ((xtR U c P D ls).lm 1 2 t)
  m20 : v.getD 22 0 = algebraMap GF K ((xtR U c P D ls).lm 2 0 t)
  m21 : v.getD 23 0 = algebraMap GF K ((xtR U c P D ls).lm 2 1 t)
  m22 : v.getD 24 0 = algebraMap GF K ((xtR U c P D ls).lm 2 2 t)

/-- **The value list `SC_TZC`'s IR reads at a token `t` with the zero extension IS the extracted planes**, whatever the
numbering's claim sites. -/
theorem tzcR_ent (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
    (hrl : 0 < rowLog P .a) (hlt : 0 < c.sh.lt) (ls aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2)
    (pub : ℕ → List Fp2) (t : CtR c) :
    TzcEnt U c P D ls t
      (valsOf U P D c.sh.lt e ev pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c)) (cpt c.sh.lt e t)) where
  d := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 0) rfl (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  dsq := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 1) rfl (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l00 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 0 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l01 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 1 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l02 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 2 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l10 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 3 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l11 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 4 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l12 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 5 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l20 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 6 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l21 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 7 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  l22 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 6 + 8 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  dm := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 2) rfl (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  dsqm := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 3) rfl (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m00 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 0 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m01 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 1 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m02 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 2 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m10 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 3 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m11 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 4 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m12 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 5 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m20 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 6 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m21 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 7 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)
  m22 := ent_pl U P D hX c.sh.lt t (DefR13.aOff c 7 + 8 * 2 ^ c.sh.lt) rfl
    (aT_cpt U P D hrl c.sh.lt e hlt t ev pub _ _)

end Vals

/-! ## The IR's clauses and hosted terms are R13's relations -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K)
variable {S : ZK60.Block.BlockShape} {c : W16Cfg} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
  (P : BlockParams) (D : CmData K P) (ls : ℕ) (t : CtR c) (v : List K)

/-- **`SC_TZC`'s IR read in the field**: L13's host terms with the six clauses and the two hosted terms, the code word
`Fp::from_i64(−ceps)` read in the field. -/
theorem tzcR_irEval (hist : Hist) (dr : List Fp2) :
    irEval (((irTzcR c).map (Sym.eval hist 2 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none (((drS 2 (c.sh.lt + 6) 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U))
          (batchV (((drS 2 c.sh.lt 6).map (Sym.eval hist 2 dr)).map (Fp2.toK U)) (tzcClauses (cstK U) rrT v))
          (v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-c.p.ceps))
          (v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-c.p.ceps)) := by
  unfold irTzcR
  rw [tzcIr_map, tzcIr_map, cstS_map, tzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

/-- **The IR's six batched clauses ARE `r13Cl 2 0 … 5`** of the extracted planes, embedded, at any weights. -/
theorem tzcR_Z (hv : TzcEnt U c P D ls t v) (mu : List K) (w : ℕ → K) (hmu : ∀ j, j < 6 → mu.getD j 0 = w j) :
    batchV mu (tzcClauses (cstK U) rrT v)
      = ∑ j ∈ Finset.range 6, w j * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 2 j (.t t)) := by
  obtain ⟨k2, -, k0, k1, k2'⟩ := cstK_tzc U
  simp only [batchV, tzcClauses, rrT, L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, Finset.sum_range_succ, Finset.sum_range_zero, zero_add, r13Cl, map_sub, map_mul,
    map_add, map_pow, map_ofNat, hv.d, hv.dsq, hv.l00, hv.l01, hv.l02, hv.l10, hv.l11, hv.l12, hv.l20, hv.l21,
    hv.l22, hv.dm, hv.dsqm, hv.m00, hv.m01, hv.m02, hv.m10, hv.m11, hv.m12, hv.m20, hv.m21, hv.m22, k2, k0, k1, k2']
  rw [hmu 0 (by norm_num), hmu 1 (by norm_num), hmu 2 (by norm_num), hmu 3 (by norm_num), hmu 4 (by norm_num),
    hmu 5 (by norm_num)]
  ring

/-- **The IR's first hosted term IS `r13Gh 2 0`** (the token gate is `1`; `ceps` from the model's shape). -/
theorem tzcR_H0 (hv : TzcEnt U c P D ls t v) (hLay : LayR Lay) (hS : PrecR c S) (hlo : -2 ^ 64 < c.p.ceps)
    (hhi : c.p.ceps < 2 ^ 64) :
    v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-c.p.ceps)
      = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 2 0 (.t t)) := by
  obtain ⟨-, -, k0, k1, k2'⟩ := cstK_tzc U
  rw [cstK_base U (-c.p.ceps) (by linarith) (by linarith)]
  simp only [L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    hv.dsq, hv.l10, hv.l11, hv.l12, k0, k1, k2', r13Gh, gT_oneR B hLay t, hS.ceps, map_mul, map_sub, map_add,
    map_pow, map_ofNat, map_intCast, one_mul]
  push_cast
  ring

/-- **The IR's second hosted term IS `r13Gh 2 1`.** -/
theorem tzcR_H1 (hv : TzcEnt U c P D ls t v) (hLay : LayR Lay) (hS : PrecR c S) (hlo : -2 ^ 64 < c.p.ceps)
    (hhi : c.p.ceps < 2 ^ 64) :
    v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-c.p.ceps)
      = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 2 1 (.t t)) := by
  obtain ⟨-, -, k0, k1, k2'⟩ := cstK_tzc U
  rw [cstK_base U (-c.p.ceps) (by linarith) (by linarith)]
  simp only [L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    hv.dsqm, hv.m10, hv.m11, hv.m12, k0, k1, k2', r13Gh, gT_oneR B hLay t, hS.ceps, map_mul, map_sub, map_add,
    map_pow, map_ofNat, map_intCast, one_mul]
  push_cast
  ring

end Rels

/-! ## `SC_TZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K)
variable {S : ZK60.Block.BlockShape} {c : W16Cfg} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
  (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)

omit [Algebra GF K] in
theorem gV_none_mul (v : List K) (x : K) : gV v none * x = x := by rw [gV_none, one_mul]

include hX hrl in
/-- **`SC_TZC`'s cube sum** (`n = lt` main variables), for any configuration with `TzcCfg`'s `ceps` and any claim
sites: `Σ_t hostPoly(τ, Σ_j μ_j·r13Cl 2 j, ν, (r_t, r_t2), 1, r13Gh 2)(t)`, `τ` draws `0 … lt − 1`, `μ_j` draw
`lt + j`, `ν_i` draw `lt + 6 + i`, the hosted points `SC_SS`'s and `SC_SSM`'s draws read off the history. -/
theorem tzcR_cube (hlt : 0 < c.sh.lt) (hlo : -2 ^ 64 < c.p.ceps) (hhi : c.p.ceps < 2 ^ 64) (hLay : LayR Lay)
    (hS : PrecR c S) (ls aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (n e : ℕ) (hn : n = c.sh.lt) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((irTzcR c).map (Sym.eval hist 2 dr)).map (Fp2.toK U))
      (valsOf U P D n e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c)) x)) :
    cubeSum f = ∑ t : CtR c, hostPoly (fun a : Fin c.sh.lt => (dr.getD a Fp2.zero).toK U)
      (fun t => ∑ j ∈ Finset.range 6, (dr.getD (c.sh.lt + j) Fp2.zero).toK U
        * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 2 j (.t t)))
      (fun i => (dr.getD (c.sh.lt + 6 + i) Fp2.zero).toK U)
      (fun i a => algDrawAt U hist i a)
      (fun _ => 1) (fun i t => algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 2 i (.t t))) t := by
  subst hn
  have hlen : ∀ s off, ((drS s off c.sh.lt).map (Sym.eval hist 2 dr)).length = c.sh.lt := fun s off => by
    rw [List.length_map, drS_length]
  have hoff : ∀ (b : Fin c.sh.lt → Bool) (y : Fin e → Bool), y ≠ (fun _ => false) →
      (valsOf U P D c.sh.lt e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c))
        (bpt c.sh.lt e b y)).getD 0 0 = 0
      ∧ (valsOf U P D c.sh.lt e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c))
        (bpt c.sh.lt e b y)).getD 1 0 = 0
      ∧ (valsOf U P D c.sh.lt e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c))
        (bpt c.sh.lt e b y)).getD 2 0 = 0 := by
    intro b y hy
    refine ⟨?_, ?_, ?_⟩
    · show tabK U P D c.sh.lt e (bpt c.sh.lt e b y) (.eq ((drS 2 0 c.sh.lt).map (Sym.eval hist 2 dr)) 0) = 0
      exact tabK_eq_off U P D c.sh.lt e b y hy _ _
    · show tabK U P D c.sh.lt e (bpt c.sh.lt e b y) (.eq ((drS 0 0 c.sh.lt).map (Sym.eval hist 2 dr)) 0) = 0
      exact tabK_eq_off U P D c.sh.lt e b y hy _ _
    · show tabK U P D c.sh.lt e (bpt c.sh.lt e b y) (.eq ((drS 1 0 c.sh.lt).map (Sym.eval hist 2 dr)) 0) = 0
      exact tabK_eq_off U P D c.sh.lt e b y hy _ _
  have hτ : ∀ b : Fin c.sh.lt → Bool,
      (valsOf U P D c.sh.lt e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c))
        (cpt c.sh.lt e b)).getD 0 0
        = eqPoly (fun a : Fin c.sh.lt => (dr.getD a Fp2.zero).toK U) (fun i => bit (b i)) := by
    intro b
    show tabK U P D c.sh.lt e (cpt c.sh.lt e b) (.eq ((drS 2 0 c.sh.lt).map (Sym.eval hist 2 dr)) 0) = _
    rw [tabK_eqFull_cpt U P D c.sh.lt e b _ (hlen 2 0)]
    congr 1
    funext a
    rw [drS_getD _ 2 0 c.sh.lt a a.isLt, Nat.zero_add, eval_dr_self]
  have hp1 : ∀ b : Fin c.sh.lt → Bool,
      (valsOf U P D c.sh.lt e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c))
        (cpt c.sh.lt e b)).getD 1 0
        = eqPoly ((fun (i : Fin 2) (a : Fin c.sh.lt) => algDrawAt U hist i a) 0) (fun i => bit (b i)) := by
    intro b
    show tabK U P D c.sh.lt e (cpt c.sh.lt e b) (.eq ((drS 0 0 c.sh.lt).map (Sym.eval hist 2 dr)) 0) = _
    rw [tabK_eqFull_cpt U P D c.sh.lt e b _ (hlen 0 0)]
    congr 1
    funext a
    rw [drS_getD _ 0 0 c.sh.lt a a.isLt, Nat.zero_add]
    rfl
  have hp2 : ∀ b : Fin c.sh.lt → Bool,
      (valsOf U P D c.sh.lt e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c))
        (cpt c.sh.lt e b)).getD 2 0
        = eqPoly ((fun (i : Fin 2) (a : Fin c.sh.lt) => algDrawAt U hist i a) 1) (fun i => bit (b i)) := by
    intro b
    show tabK U P D c.sh.lt e (cpt c.sh.lt e b) (.eq ((drS 1 0 c.sh.lt).map (Sym.eval hist 2 dr)) 0) = _
    rw [tabK_eqFull_cpt U P D c.sh.lt e b _ (hlen 1 0)]
    congr 1
    funext a
    rw [drS_getD _ 1 0 c.sh.lt a a.isLt, Nat.zero_add]
    rfl
  rw [cubeSum_host c.sh.lt e
    (valsOf U P D c.sh.lt e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (tabsTzcR c))) 0 1 2 none none
    (((drS 2 (c.sh.lt + 6) 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U))
    (fun v => batchV (((drS 2 c.sh.lt 6).map (Sym.eval hist 2 dr)).map (Fp2.toK U)) (tzcClauses (cstK U) rrT v))
    (fun v => v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-c.p.ceps))
    (fun v => v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-c.p.ceps)) f
    (fun x => by rw [hf x, tzcR_irEval U]) hoff
    (fun a : Fin c.sh.lt => (dr.getD a Fp2.zero).toK U) (fun i a => algDrawAt U hist i a) hτ hp1 hp2]
  have hmu : ∀ j, j < 6 → (((drS 2 c.sh.lt 6).map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD j 0
      = (dr.getD (c.sh.lt + j) Fp2.zero).toK U := by
    intro j hj
    rw [getD_map_toK, drS_getD _ 2 c.sh.lt 6 j hj, eval_dr_self]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv := tzcR_ent U c P D hX hrl hlt ls aB hB ioIn ioOut ak hk e (Sym.eval hist 2 dr) pub t
  refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => rfl) ?_ (fun i => ?_) (fun i j => rfl) (fun i => ?_)
  · -- the batched clauses
    exact tzcR_Z U Pb Lay B P D ls t _ hv _ _ hmu
  · -- the hosted weights
    fin_cases i
    · show (((drS 2 (c.sh.lt + 6) 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD 0 0
        = (dr.getD (c.sh.lt + 6 + 0) Fp2.zero).toK U
      rw [getD_map_toK, drS_getD _ 2 (c.sh.lt + 6) 2 0 (by norm_num), eval_dr_self]
    · show (((drS 2 (c.sh.lt + 6) 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD 1 0
        = (dr.getD (c.sh.lt + 6 + 1) Fp2.zero).toK U
      rw [getD_map_toK, drS_getD _ 2 (c.sh.lt + 6) 2 1 (by norm_num), eval_dr_self]
  · -- the hosted terms
    fin_cases i
    · exact (gV_none_mul _ _).trans (tzcR_H0 U Pb Lay B P D ls t _ hv hLay hS hlo hhi)
    · exact (gV_none_mul _ _).trans (tzcR_H1 U Pb Lay B P D ls t _ hv hLay hS hlo hhi)

end Cube

/-! ## `SC_SS` and `SC_SSM`: the hosted row sums of squares -/

section Ss

variable {K : Type} [Field K] [Algebra GF K] (U : K)
variable {S : ZK60.Block.BlockShape} {c : W16Cfg} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
  (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)

omit [Algebra GF K] in
theorem ss_key (v : List K) (A Bv C : K) (h0 : v.getD 0 0 = A) (h1 : v.getD 1 0 = Bv) (h2 : v.getD 2 0 = C) :
    v.getD 2 0 * (v.getD 0 0 * (v.getD 1 0 * v.getD 1 0)) = C * (A * (Bv * Bv)) := by
  rw [h0, h1, h2]

theorem append_head (t : CtR c) (w : CwR c) (a : Fin c.sh.lt) :
    Fin.append t w (⟨(a : ℕ), Nat.lt_of_lt_of_le a.isLt (Nat.le_add_right _ _)⟩ : Fin (c.sh.lt + c.sh.ld)) = t a := by
  rw [show (⟨(a : ℕ), Nat.lt_of_lt_of_le a.isLt (Nat.le_add_right _ _)⟩ : Fin (c.sh.lt + c.sh.ld))
    = Fin.castAdd c.sh.ld a from rfl, Fin.append_left]

include hX hrl in
/-- **`SC_SS`'s (`SC_SSM`'s) cube sum** (`n = lt + ld` main variables, any claim sites): the multilinear extension, at
the slot's point `r_t` (its first `lt` draws), of the gated row sums of squares `Σ_w gD(t, w)·X(t, w)²` of its plane
at `aOff c q`. -/
theorem ssR_cube (hlt : 0 < c.sh.lt) (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (s q : ℕ) (dr : List Fp2)
    (pub : ℕ → List Fp2)
    (hgD : ∀ (t : CtR c) (w : CwR c),
      ((pub 0).getD (msbIndex (nD c) (Fin.append t w)) Fp2.zero).toK U = algebraMap GF K (B.gD (t, w)))
    (n e : ℕ) (hn : n = nD c) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((ssIr cstS 0 1 (some 2)).map (Sym.eval hist s dr)).map (Fp2.toK U))
      (valsOf U P D n e (Sym.eval hist s dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (rawSsR c s q).tabs) x)) :
    cubeSum f = mleAt (fun t : CtR c => algebraMap GF K (∑ w : CwR c,
        B.gD (t, w) * plD U c P D (DefR13.aOff c q) (t, w) * plD U c P D (DefR13.aOff c q) (t, w)))
      (fun a : Fin c.sh.lt => (dr.getD a Fp2.zero).toK U) := by
  subst hn
  have hir : ∀ v : List K, irEval (((ssIr cstS 0 1 (some 2)).map (Sym.eval hist s dr)).map (Fp2.toK U)) v
      = v.getD 2 0 * (v.getD 0 0 * (v.getD 1 0 * v.getD 1 0)) := by
    intro v
    rw [ssIr_map, ssIr_map, cstS_map, ssIr_eval _ (cstW_map_std U), gV_some]
  have hle : c.sh.lt ≤ nD c := Nat.le_add_right _ _
  have hpos : 0 < nD c := Nat.lt_of_lt_of_le hlt hle
  rw [cubeSum_split]
  have hrow : ∀ b : Fin (nD c) → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = ((pub 0).getD (msbIndex (nD c) b) Fp2.zero).toK U
        * (eqPoly (fun a : Fin c.sh.lt => (dr.getD a Fp2.zero).toK U)
            (fun a => bit (b ⟨a, Nat.lt_of_lt_of_le a.isLt hle⟩))
          * (aPl U P D (DefR13.aOff c q) (nD c) b * aPl U P D (DefR13.aOff c q) (nD c) b)) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt (nD c) e b) = _
      rw [hf, hir]
      refine ss_key _ _ _ _ ?_ ?_ ?_
      · show tabK U P D (nD c) e (cpt (nD c) e b) (.eq ((drS s 0 c.sh.lt).map (Sym.eval hist s dr)) 0) = _
        rw [tabK_eqHead_cpt U P D (nD c) e b _ c.sh.lt (by rw [List.length_map, drS_length]) hle]
        congr 1
        funext a
        rw [drS_getD _ s 0 c.sh.lt a a.isLt, Nat.zero_add, eval_dr_self]
      · exact aT_cpt U P D hrl (nD c) e hpos b _ pub _ _
      · show tabK U P D (nD c) e (cpt (nD c) e b) (.pub (pub 0)) = _
        rw [tabK_pub_cpt]
    · show f (bpt (nD c) e b y) = 0
      rw [hf, hir]
      have h0 : (valsOf U P D (nD c) e (Sym.eval hist s dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (rawSsR c s q).tabs)
          (bpt (nD c) e b y)).getD 0 0 = 0 := by
        show tabK U P D (nD c) e (bpt (nD c) e b y) (.eq ((drS s 0 c.sh.lt).map (Sym.eval hist s dr)) 0) = 0
        exact tabK_eq_off U P D (nD c) e b y hy _ _
      rw [h0, zero_mul, mul_zero]
  simp only [hrow]
  rw [sum_append]
  unfold mleAt
  refine Finset.sum_congr rfl (fun t _ => ?_)
  simp only [map_sum, Finset.mul_sum]
  refine Finset.sum_congr rfl (fun w _ => ?_)
  rw [hgD t w]
  have he : (fun a : Fin c.sh.lt => (bit (Fin.append t w ⟨(a : ℕ), Nat.lt_of_lt_of_le a.isLt hle⟩) : K))
      = fun a => bit (t a) := by
    funext a
    rw [append_head]
  rw [he]
  have hx : algebraMap GF K (plD U c P D (DefR13.aOff c q) (t, w))
      = aPl U P D (DefR13.aOff c q) (nD c) (Fin.append t w) := aPl_alg U P D hX _ _ _
  simp only [map_mul]
  rw [hx]
  ring

end Ss

end ZK60.Exec.Block.Join.R13H.Tzc
