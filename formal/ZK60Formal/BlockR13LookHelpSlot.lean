/-
D63 lane L49 (2026-11-10), sub-agent `help`, part 1: **`SC_LZC` (slot `3`) and `SC_ZS` (slot `20`) at R13, and the
configuration facts of the helper layer**, generic in the configuration `c` (the R13 rung `cfgRungR13` and every layer
of the Shieldstral T128 R13 block `cfgShieldR13 L`), by lane L44's W16R2 pattern (`BlockLkBase.lean`, `BlockLkLzc.lean`).

R13's slot `3` is `argument.rs`'s shared `SC_LZC` arm at R13's plane offsets: `eq(τ)`, the limb planes `A` `6` and `7`
(`aOff c 6`, `aOff c 7`), the limb helper `H` plane `fh c 0 = 0`, `supp(L)`; its IR is lane L44's `ir3` verbatim
(`lzcIr` over `Dom::L`'s two byte lookups, which are the same two lookups in both layouts, and the pad group
`(supp(L), [limb, limbm])`: `Dom::L` pads at both configurations). Slot `20` is `zsIr` on the all-ones public table and
the zero-sum row `H_U` (`H` plane `fh c 10`).

* `drH`, **`rawTabs3M`**, **`rawSlot3R`**, **`rawTabs20M`**, **`rawSlot20R`**: the raw slots by shape (`M`: with any mask
  rows); `numTabs3`, `numTabs20`: the numbering sets the mask rows only; `progR13_slotH`: the numbered slot `k` is the
  raw slot `k` numbered from some claim sites;
* **`HelpCfg c`**: the configuration facts the helper layer reads (raw slots `3`, `19`, `20` by shape; their schedules
  and draw counts); **`helpCfg_rung`**, **`helpCfg_shield`** (every layer of `shieldExport`; the raw slots one layer at
  a time: `rawSlot3_shield`, lane L47's `rawSlot19_shield`, `rawSlot20_shield`);
* **`HelpProf P`**: the verifier's draw counts and schedules at slots `3`, `19`, `20`; `helpProf_rung`,
  `helpProf_shield` (from an `IsRungR13` / `IsShieldR13` verifier's `hdr`, `hsl`);
* `lzcR_vals`; `valsLR`, **`cLzcR`** (LogUp's pair relation of the two limb lookups, read at `(β, γ, α)`), **`wLzcR`**
  (the two pad planes `(1 − supp_L)·limb`); **`lzcR_cube`**; **`spLzcR`** (L23's `SlotPoly.lzc`, degree `4`);
  **`lzcR_formAt`**: the standalone named identity at slot `3`, for a verifier whose slot `3` is standalone and whose
  slot-`3` public table is a support gate `gL` (public data);
* **`zsR_cube`**, **`spZsR`**, **`zsR_formAt`**: the same for `SC_ZS` on an all-ones public table.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLkGd
import ZK60Formal.BlockR13JoinForm

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Help

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.Join.W16.Lk (shapedL ir3 lzc_irEval lksLK secL)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (zsIr zsIr_eval logupSem padSem)
open ZK60.Exec.Slot.Compose (zsIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)

/-! ## The raw slots -/

/-- The draws `off … off + n − 1` of slot `s`, as expressions (`DefR13.seg`'s shape). -/
def drH (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

theorem drH_length (ev : Sym → Fp2) (s off n : ℕ) : ((drH s off n).map ev).length = n := by
  simp [drH]

/-- **R13's `SC_LZC` tables**, with mask rows `m₁ m₂ m₃`: `eq(τ)` (draws `0 … 13`), the limb planes `A` `6` and `7`,
the limb helper `H` plane `0`, `supp(L)`. -/
def rawTabs3M (c : W16Cfg) (m1 m2 m3 : ℕ) : List TabS :=
  [.eq (drH 3 0 14) 0, .priv ⟨.a, [(DefR13.aOff c 6, false)], 14, DefW16.rhoC 0 14, m1, 0⟩,
    .priv ⟨.a, [(DefR13.aOff c 7, false)], 14, DefW16.rhoC 0 14, m2, 0⟩,
    .priv ⟨.h, [((DefR13.hOff c 0).1, false), ((DefR13.hOff c 0).2, true)], 14, DefW16.rhoC 0 14, m3, 0⟩, .pub 0]

/-- **R13's raw slot `3`** by shape: the tables above, lane L44's IR `ir3` (`μ_pad` draw `14`, `ζ` draw `15`, the pad
group `(4, [1, 2])`), no hosted slot, `ζ` refused when zero. -/
def rawSlot3R (c : W16Cfg) : SlotS := ⟨rawTabs3M c 0 0 0, ir3, [], [.dr 3 15]⟩

/-- **R13's `SC_ZS` tables**, with mask row `m`: the all-ones public table and `H_U` (`H` plane `fh c 10`). -/
def rawTabs20M (c : W16Cfg) (m : ℕ) : List TabS :=
  [.pub 0, .priv ⟨.h, [((DefR13.hOff c (DefR13.fh c 10)).1, false), ((DefR13.hOff c (DefR13.fh c 10)).2, true)], 14,
    DefW16.rhoC 0 14, m, 0⟩]

/-- **R13's raw slot `20`** by shape. -/
def rawSlot20R (c : W16Cfg) : SlotS := ⟨rawTabs20M c 0, zsIr DefW16.cstS 0 1, [], []⟩

/-- The numbering sets the mask rows of slot `3`'s tables only. -/
theorem numTabs3 (c : W16Cfg) (aB hB ioIn ioOut ak hk : ℕ) :
    DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabs3M c 0 0 0)
      = rawTabs3M c (aB + 2 * ak) (aB + 2 * (ak + 1)) (hB + 2 * hk) := rfl

/-- The numbering sets the mask row of slot `20`'s `H` table only. -/
theorem numTabs20 (c : W16Cfg) (aB hB ioIn ioOut ak hk : ℕ) :
    DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabs20M c 0) = rawTabs20M c (hB + 2 * hk) := rfl

/-- **R13's slot `k`, numbered**: the raw slot `k` numbered from some claim sites. -/
theorem progR13_slotH (c : W16Cfg) (ioIn ioOut k : ℕ) (hk : k < 23) : ∃ ak hk',
    (DefR13.progR13 c ioIn ioOut).getD k SlotS.empty
      = DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak hk' (DefR13.rawSlot c k) := by
  have hlen : k < (DefR13.rawProg c).length := by
    unfold DefR13.rawProg
    rw [List.length_map, List.length_range]
    exact hk
  obtain ⟨a, h, e⟩ := R13T.numProg_getD (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut (DefR13.rawProg c) k 0 0
    hlen
  refine ⟨a, h, ?_⟩
  show (DefW16.numProg (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut 0 0 (DefR13.rawProg c)).getD k
    SlotS.empty = _
  rw [e]
  congr 1
  unfold DefR13.rawProg
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hk]
  rfl

/-! ## The configuration facts -/

/-- **The configuration facts the helper layer reads**: the raw slots `3` (`SC_LZC`), `19` (`SC_TAB`, lane L47's
`rawSlotR`) and `20` (`SC_ZS`) by shape, their schedules `(14, 1, 4)`, `(14, 1, 3)`, `(14, 1, 2)` and their draw counts
`16`, `19`, `0`. PROVED at the R13 rung (`helpCfg_rung`) and at every Shieldstral layer (`helpCfg_shield`). -/
structure HelpCfg (c : W16Cfg) : Prop where
  raw3 : DefR13.rawSlot c 3 = rawSlot3R c
  raw19 : DefR13.rawSlot c 19 = R13T.rawSlotR c
  raw20 : DefR13.rawSlot c 20 = rawSlot20R c
  sc3 : ZK60.Exec.Slot.W16R2.sched c.sh 3 = (14, 1, 4)
  sc19 : ZK60.Exec.Slot.W16R2.sched c.sh 19 = (14, 1, 3)
  sc20 : ZK60.Exec.Slot.W16R2.sched c.sh 20 = (14, 1, 2)
  dl3 : ZK60.Exec.Slot.R13.drawLen c.sh 3 = 16
  dl19 : ZK60.Exec.Slot.R13.drawLen c.sh 19 = 19
  dl20 : ZK60.Exec.Slot.R13.drawLen c.sh 20 = 0

/-- **The R13 rung's helper-layer facts**, by evaluation of the three raw slots. -/
theorem helpCfg_rung : HelpCfg DefR13.cfgRungR13 where
  raw3 := rfl
  raw19 := R13T.rawSlot19_rung
  raw20 := rfl
  sc3 := by decide
  sc19 := by decide
  sc20 := by decide
  dl3 := by decide
  dl19 := by decide
  dl20 := by decide

/-- **Every Shieldstral layer's raw slot `3`**, by evaluation, one layer at a time (for a symbolic layer `rfl` does not
close it; finding L49-HELP-1). -/
theorem rawSlot3_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 3 = rawSlot3R (DefR13.cfgShieldR13 L) := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-- **Every Shieldstral layer's raw slot `20`**, by evaluation, one layer at a time. -/
theorem rawSlot20_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport,
    DefR13.rawSlot (DefR13.cfgShieldR13 L) 20 = rawSlot20R (DefR13.cfgShieldR13 L) := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

local notation "shS" => ZK60.Exec.Slot.R13.shShieldR13

/-- **Every Shieldstral layer's helper-layer facts** (each of the 26 layers of `shieldExport`). -/
theorem helpCfg_shield (L : ZK60.RunShape.Shield.ShieldLayer) (hL : L ∈ ZK60.RunShape.Shield.shieldExport) :
    HelpCfg (DefR13.cfgShieldR13 L) where
  raw3 := rawSlot3_shield L hL
  raw19 := R13T.rawSlot19_shield L hL
  raw20 := rawSlot20_shield L hL
  sc3 := (by decide : ZK60.Exec.Slot.W16R2.sched shS 3 = (14, 1, 4))
  sc19 := (by decide : ZK60.Exec.Slot.W16R2.sched shS 19 = (14, 1, 3))
  sc20 := (by decide : ZK60.Exec.Slot.W16R2.sched shS 20 = (14, 1, 2))
  dl3 := (by decide : ZK60.Exec.Slot.R13.drawLen shS 3 = 16)
  dl19 := (by decide : ZK60.Exec.Slot.R13.drawLen shS 19 = 19)
  dl20 := (by decide : ZK60.Exec.Slot.R13.drawLen shS 20 = 0)

/-! ## The verifier's profile at the helper slots -/

/-- **The verifier facts the helper layer reads**: the helper slots' draw counts and schedules. PROVED at an
`IsRungR13`-shaped verifier (`helpProf_rung`) and an `IsShieldR13`-shaped one (`helpProf_shield`). -/
structure HelpProf (P : BlockParams) : Prop where
  d3 : P.draws 3 = 16
  d19 : P.draws 19 = 19
  d20 : P.draws 20 = 0
  s3 : slotShape P 3 = (14, 1, 4)
  s19 : slotShape P 19 = (14, 1, 3)
  s20 : slotShape P 20 = (14, 1, 2)

/-- A verifier with the R13 rung's draws and schedule. -/
theorem helpProf_rung (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.rungDraws)
    (hsl : P.geom.slots = ZK60.Exec.Block.R13.rungSlots) : HelpProf P := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩ <;> (try rw [hdr]) <;> (try simp only [slotShape, hsl]) <;> decide

/-- A verifier with the Shieldstral block's draws and schedule. -/
theorem helpProf_shield (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = ZK60.Exec.Block.R13.shieldSlots) : HelpProf P := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩ <;> (try rw [hdr]) <;> (try simp only [slotShape, hsl]) <;> decide

/-! ## `SC_LZC`'s value list -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **R13's `SC_LZC` value list at a cube point with the zero extension**, for any mask rows. -/
theorem lzcR_vals (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (e : ℕ)
    (b : Fin 14 → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (m1 m2 m3 : ℕ) :
    ((rawTabs3M c m1 m2 m3).map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e b))
      = [eqPoly (fun a : Fin 14 => (((drH 3 0 14).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a)),
         aPl U P D (DefR13.aOff c 6) 14 b, aPl U P D (DefR13.aOff c 7) 14 b,
         hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 14 b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U] := by
  have hlen : ((drH 3 0 14).map ev).length = 14 := drH_length ev 3 0 14
  simp only [rawTabs3M, List.map_cons, List.map_nil, eqT_eval, pubT_eval, aTab_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D 14 e b _ hlen, tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl,
    tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl,
    tabK_pub_cpt, castB_rfl]

/-- `SC_LZC`'s value list without the draws at R13: the `eq` entry `0`, the limb planes, the helper, the gate. -/
noncomputable def valsLR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (gL : (Fin 14 → Bool) → GF)
    (b : Fin 14 → Bool) : List K :=
  [0, aPl U P D (DefR13.aOff c 6) 14 b, aPl U P D (DefR13.aOff c 7) 14 b,
    hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 14 b, algebraMap GF K (gL b)]

/-- **R13's `SC_LZC` helper relation** at a cube point: LogUp's pair relation `h·d₁·d₂ − d₁ − d₂` of the two limb
lookups (weight `1`), read at `bga = (β, γ, α)`. -/
noncomputable def cLzcR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (gL : (Fin 14 → Bool) → GF)
    (bga : Fp2 × Fp2 × Fp2) (b : Fin 14 → Bool) : K :=
  logupSem (cstK U) (valsLR U c P D gL b) 3 (fun _ => (cstK U).one) 0 (lksLK U bga)

/-- **R13's `SC_LZC` pad planes**: `(1 − supp_L)·limb`, `(1 − supp_L)·limbm`. -/
noncomputable def wLzcR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (gL : (Fin 14 → Bool) → GF) (j : Fin 2)
    (b : Fin 14 → Bool) : K :=
  (1 - algebraMap GF K (gL b))
    * (if (j : ℕ) = 0 then aPl U P D (DefR13.aOff c 6) 14 b else aPl U P D (DefR13.aOff c 7) 14 b)

end Vals

/-! ## `SC_LZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **R13's `SC_LZC` cube sum** (`n = 14`), for any configuration and mask rows:
`Σ_b eq(τ, b)·(cLzcR(b) + μ_pad·Σ_j ζ^j·wLzcR_j(b))`, `τ` draws `0 … 13`, `μ_pad` draw `14`, `ζ` draw `15`. -/
theorem lzcR_cube (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (gL : (Fin 14 → Bool) → GF) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hgate : ∀ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (m1 m2 m3 n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((ir3.map (Sym.eval hist 3 dr)).map (Fp2.toK U))
      (((rawTabs3M c m1 m2 m3).map (TabS.eval (Sym.eval hist 3 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a))
      * (cLzcR U c P D gL (hist.beta, hist.gamma, hist.alpha) b
        + (dr.getD 14 Fp2.zero).toK U * ∑ j : Fin 2, ((dr.getD 15 Fp2.zero).toK U) ^ (j : ℕ) * wLzcR U c P D gL j b) := by
  subst hn
  -- the lookups read only `α`, `γ`
  have hlks : ((DefW16.lksS DefW16.cfgRungW16 shapedL .L).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 3 dr))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)) = lksLK U (hist.beta, hist.gamma, hist.alpha) := by
    unfold lksLK
    rw [lksS_eval DefW16.cfgRungW16 shapedL .L hist (histOf hist.beta hist.gamma hist.alpha []) 3 3 dr [] rfl rfl]
  -- the `eq` table's point is the slot's first fourteen draws
  have heq : eqPoly (fun a : Fin 14 => (((drH 3 0 14).map (Sym.eval hist 3 dr)).getD a Fp2.zero).toK U)
      = eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) := by
    congr 1
    funext a
    simp [drH, Sym.eval, drawAt]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, lzc_irEval, lzcR_vals U c P D hrl e b (Sym.eval hist 3 dr) pub m1 m2 m3, hlks, heq]
    have hL : logupSem (cstK U) [eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a)),
          aPl U P D (DefR13.aOff c 6) 14 b, aPl U P D (DefR13.aOff c 7) 14 b,
          hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 14 b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U] 3
          (fun _ => (cstK U).one) 0 (lksLK U (hist.beta, hist.gamma, hist.alpha))
        = cLzcR U c P D gL (hist.beta, hist.gamma, hist.alpha) b := by
      -- the relation reads only the limb planes and the helper (positions `1`, `2`, `3`), where the two lists agree
      unfold cLzcR
      rw [logupSem_eq_wsum, logupSem_eq_wsum]
      congr 1
    have hP : padSem (cstK U) [eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a)),
          aPl U P D (DefR13.aOff c 6) 14 b, aPl U P D (DefR13.aOff c 7) 14 b,
          hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 14 b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U]
          ((Sym.eval hist 3 dr (.dr 3 14)).toK U) (fun j => (Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j)).toK U) 0
          [(4, [1, 2])]
        = (dr.getD 14 Fp2.zero).toK U * ∑ j : Fin 2, ((dr.getD 15 Fp2.zero).toK U) ^ (j : ℕ) * wLzcR U c P D gL j b := by
      rw [padSem_eq_wsum _ (cstW_map_std U)]
      simp only [padPls, List.map_cons, List.map_nil, List.append_nil, wsum, List.getD_cons_zero,
        List.getD_cons_succ, Fin.sum_univ_two, wLzcR, Fin.val_zero, Fin.val_one, Fin.isValue, one_ne_zero, ↓reduceIte,
        add_zero, Nat.zero_add]
      rw [hgate b]
      have h14 : Sym.eval hist 3 dr (.dr 3 14) = dr.getD 14 Fp2.zero := by simp [Sym.eval, drawAt]
      have hz : ∀ j, (Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j)).toK U = ((dr.getD 15 Fp2.zero).toK U) ^ j := by
        intro j
        rw [show Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j) = zpowW (dr.getD 15 Fp2.zero) j by simp [Sym.eval, drawAt],
          toK_zpowW U hU]
      rw [h14, hz 0, hz 1]
    simp only [List.getD_cons_zero]
    rw [hL, hP]
  · show f (bpt 14 e b y) = 0
    rw [hf, lzc_irEval]
    simp only [rawTabs3M, List.map_cons, eqT_eval, List.getD_cons_zero]
    rw [tabK_eq_off U P D 14 e b y hy, zero_mul]

end Cube

/-! ## `SC_LZC`'s certified polynomial and named identity -/

section Poly

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)

include hcard in
/-- **R13's `SC_LZC` certified polynomial** (L23's `SlotPoly.lzc`; draws `τ` 0–13, `μ_pad` 14, `ζ` 15): its start
claim is that the limb helper relation and the two pad planes vanish on the cube. -/
noncomputable def spLzcR (c : W16Cfg) (P : BlockParams) (hd : P.draws 3 = 16) (D : CmData K P)
    (gL : (Fin 14 → Bool) → GF) (h : Hist) : SlotPoly K (P.draws 3) :=
  SlotPoly.cast hd.symm
    (SlotPoly.lzc (n := 14) (m := 2) (D := 16) (cLzcR U c P D gL (h.beta, h.gamma, h.alpha)) (wLzcR U c P D gL)
      (fun x => x 15) (fun x => x 14) (fun i => Fin.castLE (by norm_num) i)
      (ZK60.Sound.SlotW16.indDeg_coord 15) (ZK60.Sound.SlotW16.indDeg_coord 14)
      (Fin.castLE_injective (by norm_num : 14 ≤ 16)) (by omega)
      (fun ζ μp τ _ => ⟨secL ζ μp τ, rfl, funext fun i => by simp [secL]⟩))

theorem spLzcR_dg (c : W16Cfg) (P : BlockParams) (hd : P.draws 3 = 16) (D : CmData K P)
    (gL : (Fin 14 → Bool) → GF) (h : Hist) : (spLzcR U hcard c P hd D gL h).dg = 4 := rfl

theorem spLzcR_Gd (c : W16Cfg) (P : BlockParams) (hd : P.draws 3 = 16) (D : CmData K P)
    (gL : (Fin 14 → Bool) → GF) (h : Hist) :
    (spLzcR U hcard c P hd D gL h).Gd = ((∀ b, cLzcR U c P D gL (h.beta, h.gamma, h.alpha) b = 0)
      ∧ ∀ j b, wLzcR U c P D gL j b = 0) := rfl

include hcard in
/-- **R13's `SC_LZC` standalone named identity** at slot `3`, for any configuration whose raw slot `3` has
`rawSlot3R`'s shape, a verifier whose slot `3` draws `16` challenges, has the shape `(14, 1, 4)` and is standalone (the
code's `SLOT_KINDS`), and whose slot-`3` public table is the support gate `gL` of `Dom::L` (public data). -/
theorem lzcR_formAt (hU : U ^ 2 = algebraMap GF K 7) (c : W16Cfg) (hraw : DefR13.rawSlot c 3 = rawSlot3R c)
    (P : BlockParams) (hd : P.draws 3 = 16) (hs3 : slotShape P 3 = (14, 1, 4)) (ioIn ioOut : ℕ) (pubs : PubTabs)
    (D : CmData K P) (hrl : 0 < rowLog P .a) (hkind : P.kind 3 = SlotKind.standalone) (gL : (Fin 14 → Bool) → GF)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 3 hist x = (spLzcR U hcard c P hd D gL hist).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) Φ bga rs 3 := by
  intro r df hr _
  refine Or.inl ⟨hkind, ?_⟩
  rw [hΦ]
  obtain ⟨ak, hk, hslot⟩ := progR13_slotH c ioIn ioOut 3 (by norm_num)
  unfold spSum
  rw [lzcR_cube U hU c P D hrl gL (histOf bga.1 bga.2.1 bga.2.2 (rs.take 3)) r.draws
    (pubs 3 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 3)) r.draws) (hgate _ _)
    (DefR13.aDataRows c + 2 * ak) (DefR13.aDataRows c + 2 * (ak + 1)) (DefR13.hDataRows c + 2 * hk)
    (slotShape P 3).1 (slotShape P 3).2.1 (by rw [hs3]) _
    (fun x => by rw [polyS_seenOf U P D _ _ bga rs 3 r hr x, hslot, hraw]; rfl)]
  rfl

end Poly

/-! ## `SC_ZS` -/

section Zs

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **R13's `SC_ZS` cube sum** (`n = 14`), for any `H` plane `(re, im)` and mask row: `Σ_b ones(b)·H_U(b)`; off the
zero extension the public table is `0`. -/
theorem zsR_cube (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .h) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2) (re im m n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((zsIr DefW16.cstS 0 1).map (Sym.eval hist 20 dr)).map (Fp2.toK U))
      (([TabS.pub 0, TabS.priv ⟨.h, [(re, false), (im, true)], 14, DefW16.rhoC 0 14, m, 0⟩].map
        (TabS.eval (Sym.eval hist 20 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U * hPl U P D re im 14 b := by
  subst hn
  have hir : ∀ v : List K, irEval (((zsIr DefW16.cstS 0 1).map (Sym.eval hist 20 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * v.getD 1 0 := by
    intro v
    rw [zsIr_map, zsIr_map, cstS_map, zsIr_eval _ (cstW_map_std U)]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, pubT_eval, hTab_eval, List.getD_cons_zero, List.getD_cons_succ]
    rw [tabK_pub_cpt, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  · show f (bpt 14 e b y) = 0
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, pubT_eval, List.getD_cons_zero]
    rw [tabK_pub_off U P D 14 e b y hy, zero_mul]

/-- **R13's `SC_ZS` certified polynomial** (no draws): its start claim is that the zero-sum row `H_U` sums to `0`. -/
noncomputable def spZsR (c : W16Cfg) (P : BlockParams) (hd : P.draws 20 = 0) (D : CmData K P) :
    SlotPoly K (P.draws 20) :=
  SlotPoly.cast hd.symm (SlotPoly.zs (fun b : Fin 14 → Bool =>
    hPl U P D (DefR13.hOff c (DefR13.fh c 10)).1 (DefR13.hOff c (DefR13.fh c 10)).2 14 b))

theorem spZsR_dg (c : W16Cfg) (P : BlockParams) (hd : P.draws 20 = 0) (D : CmData K P) :
    (spZsR U c P hd D).dg = 0 := rfl

/-- **R13's `SC_ZS` standalone named identity** at slot `20`, for any configuration whose raw slot `20` has
`rawSlot20R`'s shape: a polynomial family whose value at slot `20` is `Σ_b H_U(b)` meets `FormAt` there, for a verifier
whose slot `20` has the shape `(14, 1, 2)` and is standalone, and whose slot-`20` public table is the all-ones table. -/
theorem zsR_formAt (c : W16Cfg) (hraw : DefR13.rawSlot c 20 = rawSlot20R c) (P : BlockParams)
    (hs20 : slotShape P 20 = (14, 1, 2)) (ioIn ioOut : ℕ) (pubs : PubTabs) (D : CmData K P)
    (hrl : 0 < rowLog P .a) (hkind : P.kind 20 = SlotKind.standalone)
    (hones : ∀ hist dr (b : Fin 14 → Bool), ((pubs 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 20 hist x = ∑ b : Fin 14 → Bool,
      hPl U P D (DefR13.hOff c (DefR13.fh c 10)).1 (DefR13.hOff c (DefR13.fh c 10)).2 14 b)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) Φ bga rs 20 := by
  intro r df hr _
  refine Or.inl ⟨hkind, ?_⟩
  rw [hΦ]
  obtain ⟨ak, hk, hslot⟩ := progR13_slotH c ioIn ioOut 20 (by norm_num)
  unfold spSum
  rw [zsR_cube U P D hrl (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20)) r.draws
    (pubs 20 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20)) r.draws) (DefR13.hOff c (DefR13.fh c 10)).1
    (DefR13.hOff c (DefR13.fh c 10)).2 (DefR13.hDataRows c + 2 * hk) (slotShape P 20).1 (slotShape P 20).2.1
    (by rw [hs20]) _ (fun x => by rw [polyS_seenOf U P D _ _ bga rs 20 r hr x, hslot, hraw]; rfl)]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [hones, one_mul]

end Zs

end ZK60.Exec.Block.Join.R13H.Help
