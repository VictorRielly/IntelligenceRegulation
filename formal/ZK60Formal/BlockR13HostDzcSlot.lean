/-
D63 lane L49 (2026-11-10), sub-agent dzc, part 2: **R13's raw slots `SC_DZC` (14), `SC_WO` (10), `SC_DMM` (13), as
explicit programs, and the configuration facts `DzcCfg` the host's named identity reads**, PROVED at the R13 rung and
at every layer of the app's Shieldstral T128 R13 block.

* `drR`, `shD`, `aPD`, `aPT`, `hPD`, **`tabsDz`**: `SC_DZC`'s 64 tables before the numbering (`eq(τ)` at draws
  `34 …`, `eq` of `SC_WO`'s and `SC_DMM`'s claim points, `γ_a`, `γ_m`, the 39 planes `8 … 46` of `Dom::D`, `D` and
  `DM` on `Dom::T`, the 17 LogUp helpers `fh 1 + j`, `supp(D)`);
* `RDz`, `KDz`, `grpDz`, **`irDz`**: its IR, `r13DzcIr` at the tables' positions (`μ` draws `0 … 30`, `ν` `31, 32`,
  `ζ` `33`; the lookups `DefR13.lksS c shD .D`; the pad group `(63, [5 … 43])`);
* **`rawDz`**, **`rawWo`**, **`rawDmm`**: the three raw slots;
* **`DzcCfg c ls`**: the raw-slot equalities, `SC_DZC`'s draw list, its lookup count `34`, and the ranges of the
  precision constants its IR writes; **`dzcCfg_rung`**, **`dzcCfg_shield`**: PROVED at both configurations (the raw
  slots by evaluation, layer by layer).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostDzcIr

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Dzc

open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.DefW16 (W16Cfg cstS rhoC)
open ZK60.Exec.Slot.Build (DzcK mmIr)

/-! ## The raw slots -/

/-- The draws `off … off + n − 1` of slot `s`, as expressions. -/
def drR (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

theorem drR_length (s off n : ℕ) (ev : Sym → Fp2) : ((drR s off n).map ev).length = n := by simp [drR]

theorem drR_getD (ev : Sym → Fp2) (s off n a : ℕ) (h : a < n) :
    ((drR s off n).map ev).getD a Fp2.zero = ev (.dr s (off + a)) := by
  unfold drR
  rw [List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range h]
  first | done | rfl

/-- `SC_DZC`'s plane-to-table map on `Dom::D` (`5 + (q − 8)`). -/
def shD (q : ℕ) : ℕ := 5 + (q - 8)

/-- An `A` plane of `Dom::D` on its own coordinates. -/
def aPD (c : W16Cfg) (q : ℕ) : TabS :=
  .priv ⟨.a, [(DefR13.aOff c q, false)], c.sh.logs .D, rhoC 0 (c.sh.logs .D), 0, 0⟩

/-- An `A` plane of `Dom::T` on the first `lt` coordinates. -/
def aPT (c : W16Cfg) (q : ℕ) : TabS :=
  .priv ⟨.a, [(DefR13.aOff c q, false)], c.sh.lt, rhoC 0 c.sh.lt, 0, 0⟩

/-- `Dom::D`'s LogUp helper `j` (`H` plane `fh 1 + j`). -/
def hPD (c : W16Cfg) (j : ℕ) : TabS :=
  .priv ⟨.h, [((DefR13.hOff c (DefR13.fh c 1 + j)).1, false), ((DefR13.hOff c (DefR13.fh c 1 + j)).2, true)],
    c.sh.logs .D, rhoC 0 (c.sh.logs .D), 0, 0⟩

/-- **`SC_DZC`'s 64 tables before the numbering.** -/
def tabsDz (c : W16Cfg) : List TabS :=
  [.eq (drR 14 34 (c.sh.logs .D)) 0, .eq (drR 10 0 (c.sh.logs .D)) 0, .eq (drR 13 0 (c.sh.logs .D)) 0, .pub 0, .pub 0,
    aPD c 8, aPD c 9, aPD c 10, aPD c 11, aPD c 12, aPD c 13, aPD c 14, aPD c 15, aPD c 16, aPD c 17, aPD c 18,
    aPD c 19, aPD c 20, aPD c 21, aPD c 22, aPD c 23, aPD c 24, aPD c 25, aPD c 26, aPD c 27, aPD c 28, aPD c 29,
    aPD c 30, aPD c 31, aPD c 32, aPD c 33, aPD c 34, aPD c 35, aPD c 36, aPD c 37, aPD c 38, aPD c 39, aPD c 40,
    aPD c 41, aPD c 42, aPD c 43, aPD c 44, aPD c 45, aPD c 46,
    aPT c 0, aPT c 2,
    hPD c 0, hPD c 1, hPD c 2, hPD c 3, hPD c 4, hPD c 5, hPD c 6, hPD c 7, hPD c 8, hPD c 9, hPD c 10, hPD c 11,
    hPD c 12, hPD c 13, hPD c 14, hPD c 15, hPD c 16,
    .pub 0]

theorem tabsDz_length (c : W16Cfg) : (tabsDz c).length = 64 := rfl

/-- `SC_DZC`'s table positions (`shD` of the plane ids at LowH24). -/
def RDz : DefR13.DzcR13 := ⟨3, 4, 5, 8, 17, 23, 26, 35, 41, 44, 45, 46, [11, 12, 13], [14, 15, 16], [29, 30, 31],
  [32, 33, 34], [6, 7], [9, 10], [18, 19], [20, 21, 22], [24, 25], [27, 28], [36, 37], [38, 39, 40], [42, 43], some 63⟩

/-- `SC_DZC`'s constants at a configuration: `2·cn_a`, `2·cn_m`, `2^tn`, `2^(tn+1)`, the two hosts' shifts. -/
def KDz (c : W16Cfg) : DzcK := ⟨2 * c.p.cnA, 2 * c.p.cnM, 2 ^ c.p.tn, 2 ^ (c.p.tn + 1), c.p.ao, c.p.down⟩

/-- `Dom::D`'s pad group: the gate at `63`, the 39 zero-rule planes at `5 … 43`. -/
def grpDz : List (ℕ × List ℕ) := [(63, List.range' 5 39)]

/-- **`SC_DZC`'s IR at a configuration** (`r13DzcIr` at `tabsDz`'s positions). -/
def irDz (c : W16Cfg) : ZK60.Exec.Slot.Ir Sym :=
  DefR13.r13DzcIr cstS RDz (KDz c) (DefR13.lksS c shD .D) (drR 14 0 31) (drR 14 31 2)
    (fun j => Sym.pow (Sym.dr 14 33) j) grpDz

/-- **R13's raw slot `SC_DZC`.** -/
def rawDz (c : W16Cfg) : SlotS :=
  ⟨tabsDz c, irDz c, [(10, .dr 14 31), (13, .dr 14 32)], [.dr 14 31, .dr 14 32, .dr 14 33]⟩

/-- **R13's raw slot `SC_WO`**: `O` (plane `56`) on its claim point's token coordinates `r_q` (draws `0 … lt − 1`)
then the head-slot-and-dimension axis; the folded `W_o`. -/
def rawWo (c : W16Cfg) : SlotS :=
  ⟨[.priv ⟨.a, [(DefR13.aOff c 56, false)], c.sh.lt + (c.sh.lkv + (c.sh.lh - c.sh.lkv) + c.sh.ldh),
      (drR 10 0 c.sh.lt).map CoordS.fixed ++ rhoC 0 (c.sh.lkv + (c.sh.lh - c.sh.lkv) + c.sh.ldh), 0, 0⟩, .pub 0],
    mmIr cstS 0 1, [], []⟩

/-- **R13's raw slot `SC_DMM`**: `H` (plane `86 + 2·ls + 10`) on `r_row` (draws `0 … lt − 1`) then the hidden axis;
the folded `W_d`. -/
def rawDmm (c : W16Cfg) (ls : ℕ) : SlotS :=
  ⟨[.priv ⟨.a, [(DefR13.aOff c (86 + 2 * ls + 10), false)], c.sh.lt + c.sh.lf,
      (drR 13 0 c.sh.lt).map CoordS.fixed ++ rhoC 0 c.sh.lf, 0, 0⟩, .pub 0],
    mmIr cstS 0 1, [], []⟩

/-! ## The configuration facts -/

/-- **The facts about a configuration that `SC_DZC`'s named identity reads**: its three raw slots are the explicit
ones; `SC_DZC` draws `μ` (31: 13 clauses, 17 helpers, the pad weight), `ν` (2), `ζ` (1), `τ` (`Dom::D`'s log); its
lookups are 34 (two per helper); the precision's constants its IR writes are in the ranges the words represent. -/
structure DzcCfg (c : W16Cfg) (ls : ℕ) : Prop where
  raw14 : DefR13.rawSlot c 14 = rawDz c
  raw10 : DefR13.rawSlot c 10 = rawWo c
  raw13 : DefR13.rawSlot c 13 = rawDmm c ls
  dl : ZK60.Exec.Slot.R13.draws c.sh 14 = [(.mu, 31), (.nu, 2), (.zeta, 1), (.tau, c.sh.logs .D)]
  lks : (DefR13.lksS c shD .D).length = 34
  tn : c.p.tn < 32
  cnA : 0 ≤ c.p.cnA ∧ c.p.cnA ≤ 2 ^ 24
  cnM : 0 ≤ c.p.cnM ∧ c.p.cnM ≤ 2 ^ 24
  ao : 1 ≤ c.p.ao ∧ c.p.ao ≤ 24
  down : 1 ≤ c.p.down ∧ c.p.down ≤ 24

/-- The R13 rung's raw slot `14`, by evaluation. -/
theorem rawDz_rung : DefR13.rawSlot DefR13.cfgRungR13 14 = rawDz DefR13.cfgRungR13 := rfl

theorem rawWo_rung : DefR13.rawSlot DefR13.cfgRungR13 10 = rawWo DefR13.cfgRungR13 := rfl

theorem rawDmm_rung : DefR13.rawSlot DefR13.cfgRungR13 13 = rawDmm DefR13.cfgRungR13 2 := rfl

/-- **`DzcCfg` at the R13 rung.** -/
theorem dzcCfg_rung : DzcCfg DefR13.cfgRungR13 2 where
  raw14 := rawDz_rung
  raw10 := rawWo_rung
  raw13 := rawDmm_rung
  dl := rfl
  lks := rfl
  tn := by decide
  cnA := ⟨by decide, by decide⟩
  cnM := ⟨by decide, by decide⟩
  ao := ⟨by decide, by decide⟩
  down := ⟨by decide, by decide⟩

/-- Every Shieldstral layer's raw slot `14`, by evaluation, one layer at a time (at a symbolic layer the evaluation
reaches the elaborator's recursion limit). -/
theorem rawDz_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 14 = rawDz (DefR13.cfgShieldR13 L) := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-- Every Shieldstral layer's raw slot `10`, by evaluation (a symbolic layer). -/
theorem rawWo_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 10 = rawWo (DefR13.cfgShieldR13 L) := rfl

/-- Every Shieldstral layer's raw slot `13`, by evaluation, one layer at a time. -/
theorem rawDmm_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 13 = rawDmm (DefR13.cfgShieldR13 L) 1 := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

theorem dl_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    ZK60.Exec.Slot.R13.draws (DefR13.cfgShieldR13 L).sh 14
      = [(.mu, 31), (.nu, 2), (.zeta, 1), (.tau, (DefR13.cfgShieldR13 L).sh.logs .D)] := rfl

/-- Every Shieldstral layer's `Dom::D` lookup count, one layer at a time. -/
theorem lks_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    (DefR13.lksS (DefR13.cfgShieldR13 L) shD .D).length = 34 := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-- **`DzcCfg` at every layer of the Shieldstral T128 R13 block** (the export's ranges, `shield_layers_ok`). -/
theorem dzcCfg_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport, DzcCfg (DefR13.cfgShieldR13 L) 1 := by
  intro L hL
  obtain ⟨h1, -, -, -, h5, -, -, -, h9, h10, -, -⟩ := ZK60.RunShape.Shield.shield_layers_ok L hL
  exact
    { raw14 := rawDz_shield L hL
      raw10 := rawWo_shield L
      raw13 := rawDmm_shield L hL
      dl := dl_shield L
      lks := lks_shield L hL
      tn := by show 1 < 32; norm_num
      cnA := ⟨by show (0 : ℤ) ≤ (L.cnA : ℤ); exact Int.natCast_nonneg _,
        by show (L.cnA : ℤ) ≤ 2 ^ 24; exact_mod_cast h9⟩
      cnM := ⟨by show (0 : ℤ) ≤ (L.cnM : ℤ); exact Int.natCast_nonneg _,
        by show (L.cnM : ℤ) ≤ 2 ^ 24; exact_mod_cast h10⟩
      ao := ⟨by show 1 ≤ L.ao + 14; omega, by show L.ao + 14 ≤ 24; omega⟩
      down := ⟨by show 1 ≤ L.z + 14; omega, by show L.z + 14 ≤ 24; omega⟩ }

end ZK60.Exec.Block.Join.R13H.Dzc
