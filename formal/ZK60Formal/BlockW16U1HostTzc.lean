/-
D63 W16R2 Shieldstral port (`BlockW16U1HostTzc.lean`):
**`SC_TZC`'s named identity (`FormAt`) at host `2` for the installed W16R2 Shieldstral export
`export_u1` (`W16R2_SHIELD_T128_H24`), with its hosted `SC_SS` (slot `0`) and `SC_SSM` (slot `1`),
parametric in per-layer `(cnA, cnM)`.**

Exact `export_u1` geometry (`c0 = cfgShieldU1 0 0`):
* `lt = 7`, `ld = 12`, `nD c0 = 19`, `ceps = 2439`, `pads .T = false`, `pads .D = true`;
* `A` planes: `d = 0`, `dsq = 1`, `dm = 2`, `dsqm = 3`, `limb = 6`, `limbm = 7`, `x = 8`, `x1 = 17`;
* `SC_TZC` draws: `[(.tau, 7), (.mu, 6), (.nu, 2), (.zeta, 0)]` (15 draws total);
* `DefW16.rawSlot (cfgU1 cnA cnM) s = DefW16.rawSlot c0 s` by `rfl` for `s ∈ {0, 1, 2}`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1Base
import ZK60Formal.BlockJoinTzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Tzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt segAt_mk)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB aPl_alg cstK cstS_map cstK_base cstK_tzc tabK_pa_cpt sum_append formAt_two)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD plT plD plL LayR gT_oneR PubR PrecR)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.DefW16 (W16Cfg cstS aTab rhoC numTabs)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)
open ZK60.Exec.Slot.Build (hostTerms gV gV_none gV_some L256 batchV tzcIr tzcClauses tzcIr_eval TzcR padSem ssIr
  ssIr_eval)
open ZK60.Exec.Slot.Compose (tzcIr_map ssIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The three raw slots at `export_u1` -/

/-- The draws `off … off + n − 1` of slot `s`, as expressions. -/
def drT (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

theorem drT_length (s off n : ℕ) : (drT s off n).length = n := by simp [drT]

theorem drT_getD (ev : Sym → Fp2) (s off n a : ℕ) (ha : a < n) :
    ((drT s off n).map ev).getD a Fp2.zero = ev (.dr s (off + a)) := by
  unfold drT
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

/-- **`export_u1`'s raw `SC_SS` (`s = 0`, `q = 8`) and `SC_SSM` (`s = 1`, `q = 17`)**: `eq(r_t)` on the
slot's `7` draws, the `Dom::D` plane (`19` bits), and the support gate `supp(D)`. -/
def rawSsU1 (s q : ℕ) : SlotS :=
  ⟨[TabS.eq (drT s 0 7) 0, aTz (offU1 q) 19, TabS.pub 0], ssIr cstS 0 1 (some 2), [], []⟩

/-- **`export_u1`'s raw `SC_TZC` tables**: `eq(τ)`, `eq(r_t)`, `eq(r_t2)`, `D` (`0`), `DSQ` (`1`),
nine byte-limb sub-slices of `Dom::L` plane `6` (`offU1 6 + k·2^7`), `DM` (`2`), `DSQM` (`3`),
and nine byte-limb sub-slices of plane `7`; no gate (`Dom::T` does not pad). -/
def tabsTzcU1 : List TabS :=
  [TabS.eq (drT 2 0 7) 0, TabS.eq (drT 0 0 7) 0, TabS.eq (drT 1 0 7) 0,
    aTz (offU1 0) 7, aTz (offU1 1) 7,
    aTz (offU1 6 + 0 * 2 ^ 7) 7, aTz (offU1 6 + 1 * 2 ^ 7) 7, aTz (offU1 6 + 2 * 2 ^ 7) 7,
    aTz (offU1 6 + 3 * 2 ^ 7) 7, aTz (offU1 6 + 4 * 2 ^ 7) 7, aTz (offU1 6 + 5 * 2 ^ 7) 7,
    aTz (offU1 6 + 6 * 2 ^ 7) 7, aTz (offU1 6 + 7 * 2 ^ 7) 7, aTz (offU1 6 + 8 * 2 ^ 7) 7,
    aTz (offU1 2) 7, aTz (offU1 3) 7,
    aTz (offU1 7 + 0 * 2 ^ 7) 7, aTz (offU1 7 + 1 * 2 ^ 7) 7, aTz (offU1 7 + 2 * 2 ^ 7) 7,
    aTz (offU1 7 + 3 * 2 ^ 7) 7, aTz (offU1 7 + 4 * 2 ^ 7) 7, aTz (offU1 7 + 5 * 2 ^ 7) 7,
    aTz (offU1 7 + 6 * 2 ^ 7) 7, aTz (offU1 7 + 7 * 2 ^ 7) 7, aTz (offU1 7 + 8 * 2 ^ 7) 7]

/-- `SC_TZC`'s table positions at `export_u1` (no gate). -/
def rrTzcU1 : TzcR := ⟨0, 1, 2, 3, 4, 14, 15, none⟩

/-- **`export_u1`'s `SC_TZC` IR**: `tzcIr` at `ceps = 2439`, `μ` draws `7 … 12`, `ν` draws `13, 14`,
no pad group. -/
def irTzcU1 : ZK60.Exec.Slot.Ir Sym :=
  tzcIr cstS rrTzcU1 2439 (drT 2 7 6) (drT 2 13 2) (fun j => Sym.pow Sym.zero j) []

/-- **`export_u1`'s raw `SC_TZC` slot**: hosts `SC_SS` at `ν₀` (draw `13`) and `SC_SSM` at `ν₁`
(draw `14`). -/
def rawTzcU1 : SlotS :=
  ⟨tabsTzcU1, irTzcU1, [(0, Sym.dr 2 13), (1, Sym.dr 2 14)], drT 2 13 2⟩

theorem rawSlot0_u1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 0 = rawSsU1 0 8 := rfl

theorem rawSlot1_u1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 1 = rawSsU1 1 17 := rfl

theorem rawSlot2_u1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 2 = rawTzcU1 := rfl

/-! ## The value list at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A slot's value list at a point: its tables' extensions. -/
noncomputable def valsOf (P : BlockParams) (D : CmData K P) (n e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2)
    (ts : List TabS) (x : Fin (n + e) → K) : List K :=
  (ts.map (TabS.eval ev pub)).map (tabK U P D n e x)

/-- An `A` slice on its own `n` coordinates, at the zero extension of a cube of `n` main variables. -/
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

/-- **`SC_TZC`'s plane entries at a token `t` for `export_u1`**: entries `3`, `4` are `D`, `DSQ`;
`5 + 3i + k` the byte limb `la i k`; `14`, `15` are `DM`, `DSQM`; `16 + 3i + k` the byte limb
`lm i k` (the extracted planes `xtU1`, embedded). -/
structure TzcEntU1 (P : BlockParams) (D : CmData K P) (t : CtU1) (v : List K) : Prop where
  d : v.getD 3 0 = algebraMap GF K ((xtU1 U P D).dA t)
  dsq : v.getD 4 0 = algebraMap GF K ((xtU1 U P D).dsqA t)
  l00 : v.getD 5 0 = algebraMap GF K ((xtU1 U P D).la 0 0 t)
  l01 : v.getD 6 0 = algebraMap GF K ((xtU1 U P D).la 0 1 t)
  l02 : v.getD 7 0 = algebraMap GF K ((xtU1 U P D).la 0 2 t)
  l10 : v.getD 8 0 = algebraMap GF K ((xtU1 U P D).la 1 0 t)
  l11 : v.getD 9 0 = algebraMap GF K ((xtU1 U P D).la 1 1 t)
  l12 : v.getD 10 0 = algebraMap GF K ((xtU1 U P D).la 1 2 t)
  l20 : v.getD 11 0 = algebraMap GF K ((xtU1 U P D).la 2 0 t)
  l21 : v.getD 12 0 = algebraMap GF K ((xtU1 U P D).la 2 1 t)
  l22 : v.getD 13 0 = algebraMap GF K ((xtU1 U P D).la 2 2 t)
  dm : v.getD 14 0 = algebraMap GF K ((xtU1 U P D).dM t)
  dsqm : v.getD 15 0 = algebraMap GF K ((xtU1 U P D).dsqM t)
  m00 : v.getD 16 0 = algebraMap GF K ((xtU1 U P D).lm 0 0 t)
  m01 : v.getD 17 0 = algebraMap GF K ((xtU1 U P D).lm 0 1 t)
  m02 : v.getD 18 0 = algebraMap GF K ((xtU1 U P D).lm 0 2 t)
  m10 : v.getD 19 0 = algebraMap GF K ((xtU1 U P D).lm 1 0 t)
  m11 : v.getD 20 0 = algebraMap GF K ((xtU1 U P D).lm 1 1 t)
  m12 : v.getD 21 0 = algebraMap GF K ((xtU1 U P D).lm 1 2 t)
  m20 : v.getD 22 0 = algebraMap GF K ((xtU1 U P D).lm 2 0 t)
  m21 : v.getD 23 0 = algebraMap GF K ((xtU1 U P D).lm 2 1 t)
  m22 : v.getD 24 0 = algebraMap GF K ((xtU1 U P D).lm 2 2 t)

/-- **The value list `SC_TZC`'s IR reads at a token `t` with the zero extension IS `xtU1`'s planes**,
for any claim sites `(ak, hk)`. -/
theorem tzcU1_ent (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
    (hrl : 0 < rowLog P .a) (aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2)
    (pub : ℕ → List Fp2) (t : CtU1) :
    TzcEntU1 U P D t
      (valsOf U P D 7 e ev pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1) (cpt 7 e t)) where
  d := ent_pl U P D hX 7 t (offU1 0) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  dsq := ent_pl U P D hX 7 t (offU1 1) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l00 := ent_pl U P D hX 7 t (offU1 6 + 0 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l01 := ent_pl U P D hX 7 t (offU1 6 + 1 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l02 := ent_pl U P D hX 7 t (offU1 6 + 2 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l10 := ent_pl U P D hX 7 t (offU1 6 + 3 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l11 := ent_pl U P D hX 7 t (offU1 6 + 4 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l12 := ent_pl U P D hX 7 t (offU1 6 + 5 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l20 := ent_pl U P D hX 7 t (offU1 6 + 6 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l21 := ent_pl U P D hX 7 t (offU1 6 + 7 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  l22 := ent_pl U P D hX 7 t (offU1 6 + 8 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  dm := ent_pl U P D hX 7 t (offU1 2) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  dsqm := ent_pl U P D hX 7 t (offU1 3) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m00 := ent_pl U P D hX 7 t (offU1 7 + 0 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m01 := ent_pl U P D hX 7 t (offU1 7 + 1 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m02 := ent_pl U P D hX 7 t (offU1 7 + 2 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m10 := ent_pl U P D hX 7 t (offU1 7 + 3 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m11 := ent_pl U P D hX 7 t (offU1 7 + 4 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m12 := ent_pl U P D hX 7 t (offU1 7 + 5 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m20 := ent_pl U P D hX 7 t (offU1 7 + 6 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m21 := ent_pl U P D hX 7 t (offU1 7 + 7 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)
  m22 := ent_pl U P D hX 7 t (offU1 7 + 8 * 2 ^ 7) rfl (aT_cpt U P D hrl 7 e (by norm_num) t ev pub _ _)

end Vals

/-! ## The IR's clauses and hosted terms are `W16Rels`' `SC_TZC` relations -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_TZC`'s IR read in the field** at `ceps = 2439`. -/
theorem tzcU1_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval ((irTzcU1.map (Sym.eval hist 2 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none (((drT 2 13 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U))
          (batchV (((drT 2 7 6).map (Sym.eval hist 2 dr)).map (Fp2.toK U)) (tzcClauses (cstK U) rrTzcU1 v))
          (v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-2439))
          (v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-2439)) := by
  unfold irTzcU1
  rw [tzcIr_map, tzcIr_map, cstS_map, tzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
  (P : BlockParams) (D : CmData K P) (t : CtU1) (v : List K)

/-- **The IR's six batched clauses ARE `relCl 2 0 … 5`** of `xtU1`, embedded, at any weights. -/
theorem tzcU1_Z (hv : TzcEntU1 U P D t v) (mu : List K) (w : ℕ → K) (hmu : ∀ j, j < 6 → mu.getD j 0 = w j) :
    batchV mu (tzcClauses (cstK U) rrTzcU1 v)
      = ∑ j ∈ Finset.range 6, w j * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 2 j (.t t)) := by
  obtain ⟨k2, -, k0, k1, k2'⟩ := cstK_tzc U
  simp only [batchV, tzcClauses, rrTzcU1, L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, Finset.sum_range_succ, Finset.sum_range_zero, zero_add, relCl, map_sub, map_mul,
    map_add, map_pow, map_ofNat, hv.d, hv.dsq, hv.l00, hv.l01, hv.l02, hv.l10, hv.l11, hv.l12, hv.l20, hv.l21,
    hv.l22, hv.dm, hv.dsqm, hv.m00, hv.m01, hv.m02, hv.m10, hv.m11, hv.m12, hv.m20, hv.m21, hv.m22, k2, k0, k1, k2']
  rw [hmu 0 (by norm_num), hmu 1 (by norm_num), hmu 2 (by norm_num), hmu 3 (by norm_num), hmu 4 (by norm_num),
    hmu 5 (by norm_num)]
  ring

/-- **The IR's first hosted term IS `relGh 2 0`** (the token gate is `1`; `S.ceps = 2439`). -/
theorem tzcU1_H0 (hv : TzcEntU1 U P D t v) (hLay : LayR Lay) {cnA cnM : ℕ} (hS : PrecR (cfgU1 cnA cnM) S) :
    v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-2439)
      = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 2 0 (.t t)) := by
  obtain ⟨-, -, k0, k1, k2'⟩ := cstK_tzc U
  have hceps : S.ceps = 2439 := hS.ceps
  rw [cstK_base U (-2439) (by norm_num) (by norm_num)]
  simp only [L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    hv.dsq, hv.l10, hv.l11, hv.l12, k0, k1, k2', relGh, gT_oneR B hLay t, hceps, map_mul, map_sub, map_add,
    map_pow, map_ofNat, map_intCast, one_mul]
  push_cast
  ring

/-- **The IR's second hosted term IS `relGh 2 1`.** -/
theorem tzcU1_H1 (hv : TzcEntU1 U P D t v) (hLay : LayR Lay) {cnA cnM : ℕ} (hS : PrecR (cfgU1 cnA cnM) S) :
    v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-2439)
      = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 2 1 (.t t)) := by
  obtain ⟨-, -, k0, k1, k2'⟩ := cstK_tzc U
  have hceps : S.ceps = 2439 := hS.ceps
  rw [cstK_base U (-2439) (by norm_num) (by norm_num)]
  simp only [L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    hv.dsqm, hv.m10, hv.m11, hv.m12, k0, k1, k2', relGh, gT_oneR B hLay t, hceps, map_mul, map_sub, map_add,
    map_pow, map_ofNat, map_intCast, one_mul]
  push_cast
  ring

end Rels

/-! ## `SC_TZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
  (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)

omit [Algebra GF K] in
theorem gV_none_mul (v : List K) (x : K) : gV v none * x = x := by rw [gV_none, one_mul]

include hX hrl in
/-- **`SC_TZC`'s cube sum at `export_u1`** (`n = 7` main variables), for any claim sites `(ak, hk)`:
`Σ_t hostPoly(τ, Σ_j μ_j·relCl 2 j, ν, (r_t, r_t2), 1, relGh 2)(t)`. -/
theorem tzcU1_cube (hLay : LayR Lay) {cnA cnM : ℕ} (hS : PrecR (cfgU1 cnA cnM) S)
    (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (n e : ℕ) (hn : n = 7) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((irTzcU1.map (Sym.eval hist 2 dr)).map (Fp2.toK U))
      (valsOf U P D n e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1) x)) :
    cubeSum f = ∑ t : CtU1, hostPoly (fun a : Fin 7 => (dr.getD a Fp2.zero).toK U)
      (fun t => ∑ j ∈ Finset.range 6, (dr.getD (7 + j) Fp2.zero).toK U
        * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 2 j (.t t)))
      (fun i => (dr.getD (13 + i) Fp2.zero).toK U)
      (fun i a => algDrawAt U hist i a)
      (fun _ => 1) (fun i t => algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 2 i (.t t))) t := by
  subst hn
  have hlen : ∀ s off, ((drT s off 7).map (Sym.eval hist 2 dr)).length = 7 := fun s off => by
    rw [List.length_map, drT_length]
  have hoff : ∀ (b : Fin 7 → Bool) (y : Fin e → Bool), y ≠ (fun _ => false) →
      (valsOf U P D 7 e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1)
        (bpt 7 e b y)).getD 0 0 = 0
      ∧ (valsOf U P D 7 e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1)
        (bpt 7 e b y)).getD 1 0 = 0
      ∧ (valsOf U P D 7 e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1)
        (bpt 7 e b y)).getD 2 0 = 0 := by
    intro b y hy
    refine ⟨?_, ?_, ?_⟩
    · show tabK U P D 7 e (bpt 7 e b y) (.eq ((drT 2 0 7).map (Sym.eval hist 2 dr)) 0) = 0
      exact tabK_eq_off U P D 7 e b y hy _ _
    · show tabK U P D 7 e (bpt 7 e b y) (.eq ((drT 0 0 7).map (Sym.eval hist 2 dr)) 0) = 0
      exact tabK_eq_off U P D 7 e b y hy _ _
    · show tabK U P D 7 e (bpt 7 e b y) (.eq ((drT 1 0 7).map (Sym.eval hist 2 dr)) 0) = 0
      exact tabK_eq_off U P D 7 e b y hy _ _
  have hτ : ∀ b : Fin 7 → Bool,
      (valsOf U P D 7 e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1)
        (cpt 7 e b)).getD 0 0
        = eqPoly (fun a : Fin 7 => (dr.getD a Fp2.zero).toK U) (fun i => bit (b i)) := by
    intro b
    show tabK U P D 7 e (cpt 7 e b) (.eq ((drT 2 0 7).map (Sym.eval hist 2 dr)) 0) = _
    rw [tabK_eqFull_cpt U P D 7 e b _ (hlen 2 0)]
    congr 1
    funext a
    rw [drT_getD _ 2 0 7 a a.isLt, Nat.zero_add, eval_dr_self]
  have hp1 : ∀ b : Fin 7 → Bool,
      (valsOf U P D 7 e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1)
        (cpt 7 e b)).getD 1 0
        = eqPoly ((fun (i : Fin 2) (a : Fin 7) => algDrawAt U hist i a) 0) (fun i => bit (b i)) := by
    intro b
    show tabK U P D 7 e (cpt 7 e b) (.eq ((drT 0 0 7).map (Sym.eval hist 2 dr)) 0) = _
    rw [tabK_eqFull_cpt U P D 7 e b _ (hlen 0 0)]
    congr 1
    funext a
    rw [drT_getD _ 0 0 7 a a.isLt, Nat.zero_add]
    rfl
  have hp2 : ∀ b : Fin 7 → Bool,
      (valsOf U P D 7 e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1)
        (cpt 7 e b)).getD 2 0
        = eqPoly ((fun (i : Fin 2) (a : Fin 7) => algDrawAt U hist i a) 1) (fun i => bit (b i)) := by
    intro b
    show tabK U P D 7 e (cpt 7 e b) (.eq ((drT 1 0 7).map (Sym.eval hist 2 dr)) 0) = _
    rw [tabK_eqFull_cpt U P D 7 e b _ (hlen 1 0)]
    congr 1
    funext a
    rw [drT_getD _ 1 0 7 a a.isLt, Nat.zero_add]
    rfl
  rw [cubeSum_host 7 e
    (valsOf U P D 7 e (Sym.eval hist 2 dr) pub (numTabs aB hB ioIn ioOut ak hk 0 tabsTzcU1)) 0 1 2 none none
    (((drT 2 13 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U))
    (fun v => batchV (((drT 2 7 6).map (Sym.eval hist 2 dr)).map (Fp2.toK U)) (tzcClauses (cstK U) rrTzcU1 v))
    (fun v => v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-2439))
    (fun v => v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-2439)) f
    (fun x => by rw [hf x, tzcU1_irEval U]) hoff
    (fun a : Fin 7 => (dr.getD a Fp2.zero).toK U) (fun i a => algDrawAt U hist i a) hτ hp1 hp2]
  have hmu : ∀ j, j < 6 → (((drT 2 7 6).map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD j 0
      = (dr.getD (7 + j) Fp2.zero).toK U := by
    intro j hj
    rw [getD_map_toK, drT_getD _ 2 7 6 j hj, eval_dr_self]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv := tzcU1_ent U P D hX hrl aB hB ioIn ioOut ak hk e (Sym.eval hist 2 dr) pub t
  refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun _ => rfl) ?_ (fun i => ?_) (fun _ _ => rfl) (fun i => ?_)
  · exact tzcU1_Z U Pb Lay B P D t _ hv _ _ hmu
  · fin_cases i
    · show (((drT 2 13 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD 0 0
        = (dr.getD (13 + 0) Fp2.zero).toK U
      rw [getD_map_toK, drT_getD _ 2 13 2 0 (by norm_num), eval_dr_self]
    · show (((drT 2 13 2).map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD 1 0
        = (dr.getD (13 + 1) Fp2.zero).toK U
      rw [getD_map_toK, drT_getD _ 2 13 2 1 (by norm_num), eval_dr_self]
  · fin_cases i
    · exact (gV_none_mul _ _).trans (tzcU1_H0 U Pb Lay B P D t _ hv hLay hS)
    · exact (gV_none_mul _ _).trans (tzcU1_H1 U Pb Lay B P D t _ hv hLay hS)

end Cube

/-! ## `SC_SS` and `SC_SSM`: the hosted row sums of squares -/

section Ss

variable {K : Type} [Field K] [Algebra GF K] (U : K)
variable {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1} (B : W16Pub S Pb Lay)
  (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)

omit [Algebra GF K] in
theorem ss_key (v : List K) (A Bv C : K) (h0 : v.getD 0 0 = A) (h1 : v.getD 1 0 = Bv) (h2 : v.getD 2 0 = C) :
    v.getD 2 0 * (v.getD 0 0 * (v.getD 1 0 * v.getD 1 0)) = C * (A * (Bv * Bv)) := by
  rw [h0, h1, h2]

theorem append_head7 (t : CtU1) (w : CwU1) (a : Fin 7) :
    Fin.append t w (⟨(a : ℕ), by omega⟩ : Fin 19) = t a :=
  Fin.append_left t w a

include hX hrl in
/-- **`SC_SS`'s (`SC_SSM`'s) cube sum at `export_u1`** (`n = 19` main variables, any claim sites):
the multilinear extension, at the slot's point `r_t`, of `Σ_w gD(t, w)·X(t, w)²` at `offU1 q`. -/
theorem ssU1_cube (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (s q : ℕ) (dr : List Fp2)
    (pub : ℕ → List Fp2)
    (hgD : ∀ (t : CtU1) (w : CwU1),
      ((pub 0).getD (msbIndex 19 (Fin.append t w)) Fp2.zero).toK U = algebraMap GF K (B.gD (t, w)))
    (n e : ℕ) (hn : n = 19) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((ssIr cstS 0 1 (some 2)).map (Sym.eval hist s dr)).map (Fp2.toK U))
      (valsOf U P D n e (Sym.eval hist s dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (rawSsU1 s q).tabs) x)) :
    cubeSum f = mleAt (fun t : CtU1 => algebraMap GF K (∑ w : CwU1,
        B.gD (t, w) * plD U c0 P D (offU1 q) (t, w) * plD U c0 P D (offU1 q) (t, w)))
      (fun a : Fin 7 => (dr.getD a Fp2.zero).toK U) := by
  subst hn
  have hir : ∀ v : List K, irEval (((ssIr cstS 0 1 (some 2)).map (Sym.eval hist s dr)).map (Fp2.toK U)) v
      = v.getD 2 0 * (v.getD 0 0 * (v.getD 1 0 * v.getD 1 0)) := by
    intro v
    rw [ssIr_map, ssIr_map, cstS_map, ssIr_eval _ (cstW_map_std U), gV_some]
  rw [cubeSum_split]
  have hrow : ∀ b : Fin 19 → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = ((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U
        * (eqPoly (fun a : Fin 7 => (dr.getD a Fp2.zero).toK U)
            (fun a => bit (b ⟨a, by omega⟩))
          * (aPl U P D (offU1 q) 19 b * aPl U P D (offU1 q) 19 b)) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt 19 e b) = _
      rw [hf, hir]
      refine ss_key _ _ _ _ ?_ ?_ ?_
      · show tabK U P D 19 e (cpt 19 e b) (.eq ((drT s 0 7).map (Sym.eval hist s dr)) 0) = _
        rw [tabK_eqHead_cpt U P D 19 e b _ 7 (by rw [List.length_map, drT_length]) (by norm_num)]
        congr 1
        funext a
        rw [drT_getD _ s 0 7 a a.isLt, Nat.zero_add, eval_dr_self]
      · exact aT_cpt U P D hrl 19 e (by norm_num) b _ pub _ _
      · show tabK U P D 19 e (cpt 19 e b) (.pub (pub 0)) = _
        rw [tabK_pub_cpt]
    · show f (bpt 19 e b y) = 0
      rw [hf, hir]
      have h0 : (valsOf U P D 19 e (Sym.eval hist s dr) pub (numTabs aB hB ioIn ioOut ak hk 0 (rawSsU1 s q).tabs)
          (bpt 19 e b y)).getD 0 0 = 0 := by
        show tabK U P D 19 e (bpt 19 e b y) (.eq ((drT s 0 7).map (Sym.eval hist s dr)) 0) = 0
        exact tabK_eq_off U P D 19 e b y hy _ _
      rw [h0, zero_mul, mul_zero]
  simp only [hrow]
  rw [sum_append (a := 7) (b := 12)]
  unfold mleAt
  refine Finset.sum_congr rfl (fun t _ => ?_)
  simp only [map_sum, Finset.mul_sum]
  refine Finset.sum_congr rfl (fun w _ => ?_)
  rw [show ((pub 0).getD (msbIndex 19 (Fin.append t w)) Fp2.zero).toK U = algebraMap GF K (B.gD (t, w)) from hgD t w]
  have he : (fun a : Fin 7 => (bit (Fin.append t w ⟨(a : ℕ), by omega⟩) : K))
      = fun a => bit (t a) := funext fun a => congrArg bit (Fin.append_left t w a)
  rw [he]
  have hx : algebraMap GF K (plD U c0 P D (offU1 q) (t, w))
      = aPl U P D (offU1 q) 19 (Fin.append t w) := aPl_alg U P D hX _ _ _
  simp only [map_mul]
  rw [hx]
  change (algebraMap GF K (B.gD (t, w))) * (eqPoly (fun a : Fin 7 => (dr.getD a Fp2.zero).toK U) (fun a => bit (t a))
      * (aPl U P D (offU1 q) 19 (Fin.append t w) * aPl U P D (offU1 q) 19 (Fin.append t w)))
    = eqPoly (fun a : Fin 7 => (dr.getD a Fp2.zero).toK U) (fun a => bit (t a))
      * (algebraMap GF K (B.gD (t, w)) * aPl U P D (offU1 q) 19 (Fin.append t w) * aPl U P D (offU1 q) 19 (Fin.append t w))
  ring

end Ss

/-! ## `SC_TZC`'s named identity at `export_u1` -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_TZC`'s named identity at `export_u1` (`FormAt` at host `2`)**, parametric in per-layer
`(cnA, cnM)`: for every algebra data `dt` whose host-`2` tables are `W16Rels`' relation tables of
`xtU1` (`relCl 2`, `relGh 2`, `relMm 2`, embedded), on every outcome whose verified slots are hosts
exactly when their definitions host slots, `SC_TZC`'s certified polynomial at the drawn challenges
IS its unmasked residual `Σ Poly₂ − (ν₀·Σ Poly₀ + ν₁·Σ Poly₁)`. -/
theorem formAt_tzcU1 (U : K) (hK : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR (cfgU1 cnA cnM) S) (hLay : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B)
    (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 6) (t : CtU1),
      dt.cl 2 cu rt bga κ t = algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 2 (κ : ℕ) (.t t)))
    (hgh : ∀ (i : Fin 2) (t : CtU1),
      dt.gh 2 cu rt i t = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 2 i (.t t)))
    (hmm : ∀ (i : Fin 2) (t : CtU1),
      dt.mm 2 cu rt i t = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 2 i (.t t)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeU1 P hdr) dt hK 0 cu rt k h).Φ) bga rs 2 := by
  have hs0 : slotShape P 0 = (19, 1, 4) := by simp only [slotShape, hsl]; decide
  have hs1 : slotShape P 1 = (19, 1, 4) := by simp only [slotShape, hsl]; decide
  have hs2 : slotShape P 2 = (7, 1, 3) := by simp only [slotShape, hsl]; decide
  obtain ⟨ak2, hk2', hsl2⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 2 (by norm_num)
  obtain ⟨ak0, hk0', hsl0⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 0 (by norm_num)
  obtain ⟨ak1, hk1', hsl1⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 1 (by norm_num)
  refine formAt_two U hK P (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs hdef D (algShapeU1 P hdr) dt cu rt bga rs 2
    (by decide) 0 1 (.dr 2 13) (.dr 2 14) (by rw [hsl2, rawSlot2_u1]; rfl) (by rw [hsl0, rawSlot0_u1]; rfl)
    (by rw [hsl1, rawSlot1_u1]; rfl) (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 2 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r0, hr0⟩ : ∃ r0, rs[0]? = some r0 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r1, hr1⟩ : ∃ r1, rs[1]? = some r1 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hsp2 := tzcU1_cube U Pb Lay B P D hX hrl hLay hS (DefW16.aDataRows (cfgU1 cnA cnM))
    (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak2 hk2' (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) r.draws
    (pubs 2 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) r.draws) (slotShape P 2).1 (slotShape P 2).2.1 (by rw [hs2])
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 2 (seenOf bga rs 2))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 2 r hr x, hsl2, rawSlot2_u1]; rfl)
  have hsp0 := ssU1_cube U B P D hX hrl (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM))
    ioIn ioOut ak0 hk0' (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) 0 8 r0.draws
    (pubs 0 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 0)) r0.draws)
    (fun t w => hpub.ssGate 0 (Or.inl rfl) _ _ t w) (slotShape P 0).1 (slotShape P 0).2.1 (by rw [hs0])
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 0 (seenOf bga rs 0))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 0 r0 hr0 x, hsl0, rawSlot0_u1]; rfl)
  have hsp1 := ssU1_cube U B P D hX hrl (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM))
    ioIn ioOut ak1 hk1' (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) 1 17 r1.draws
    (pubs 1 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 1)) r1.draws)
    (fun t w => hpub.ssGate 1 (Or.inr rfl) _ _ t w) (slotShape P 1).1 (slotShape P 1).2.1 (by rw [hs1])
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 1 (seenOf bga rs 1))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 1 r1 hr1 x, hsl1, rawSlot1_u1]; rfl)
  have hpw0 : ∀ g : Fin ((algShapeU1 P hdr).mpad 2) → K, ∑ j, g j = 0 := fun g => Fin.sum_univ_zero g
  have hseg : ∀ (g : Seg) (i : ℕ), segOff ((algShapeU1 P hdr).dl 2) g + i < 15 →
      segAt ((algShapeU1 P hdr).dl 2)
        (fun j => (fun q : Fin (P.draws 2) => (r.draws.getD q.val Fp2.zero).toK U)
          (Fin.cast ((algShapeU1 P hdr).hsum 2 (by decide)) j)) g i
        = (r.draws.getD (segOff ((algShapeU1 P hdr).dl 2) g + i) Fp2.zero).toK U := fun g i h =>
    (segAt_mk ((algShapeU1 P hdr).dl 2) _ g i h).symm
  have hκ : ∀ (bga' : Fp2 × Fp2 × Fp2) (b : CtU1) (κ : Fin 6),
      segAt ((algShapeU1 P hdr).dl 2)
        (fun j => (fun q : Fin (P.draws 2) => (r.draws.getD q.val Fp2.zero).toK U)
          (Fin.cast ((algShapeU1 P hdr).hsum 2 (by decide)) j)) .mu κ
        * dt.cl 2 cu rt bga' κ b
        = (r.draws.getD (7 + κ) Fp2.zero).toK U
          * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 2 κ (.t b)) := by
    intro bga' b κ
    have hκ6 : (κ : ℕ) < 6 := κ.isLt
    rw [hseg .mu κ (by show 7 + (κ : ℕ) < 15; omega), hcl]
    rfl
  rw [hostSp_Φ]
  unfold hostPhi
  unfold spSum
  rw [hsp2, hsp0, hsp1]
  refine congrArg₂ (fun x y : K => x - y) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun b _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ b (fun a => ?_) ?_ (fun i => ?_) (fun i _ => ?_) (fun i => ?_)
    · -- `τ`
      have ha : (a : ℕ) < 7 := a.isLt
      refine (hseg .tau a (by show 0 + (a : ℕ) < 15; omega)).trans ?_
      show (r.draws.getD (0 + (a : ℕ)) Fp2.zero).toK U = _
      rw [Nat.zero_add]
    · -- the batched clauses
      unfold batched
      rw [hpw0, mul_zero, add_zero]
      refine (Finset.sum_congr rfl (fun κ _ => hκ _ b κ)).trans ?_
      exact Fin.sum_univ_eq_sum_range (fun κ => (r.draws.getD (7 + κ) Fp2.zero).toK U
        * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 2 κ (.t b))) 6
    · -- `ν`
      have hi : (i : ℕ) < 2 := i.isLt
      exact hseg .nu i (by show 13 + (i : ℕ) < 15; omega)
    · -- the hosted points
      fin_cases i <;> rfl
    · -- the hosted terms
      rw [algH_gh U (algShapeU1 P hdr) dt 2 cu rt _ i (fun h => absurd h.1 (by decide))]
      exact hgh i b
  · -- the hosted sums
    rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeU1 P hdr) dt 2 cu rt i
        = fun t => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 2 i (.t t)) := fun i => by
      rw [algM_mm (algShapeU1 P hdr) dt 2 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeU1 P hdr) 2 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) 0
        = fun a : Fin 7 => (r0.draws.getD a Fp2.zero).toK U := by
      funext a
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 2 0 a r0 (by norm_num) hr0
    have hp1 : algPt U (algShapeU1 P hdr) 2 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 2)) 1
        = fun a : Fin 7 => (r1.draws.getD a Fp2.zero).toK U := by
      funext a
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 2 1 a r1 (by norm_num) hr1
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · refine (hseg .nu 0 (by show 13 + 0 < 15; omega)).trans ?_
      rw [eval_dr_self]
      rfl
    · refine (hseg .nu 1 (by show 13 + 1 < 15; omega)).trans ?_
      rw [eval_dr_self]
      rfl

end Form

end ZK60.Exec.Block.Join.W16U1.Tzc
