/-
D63 lane L49 (2026-11-10), sub-agent `look`, part 1: **R13's lookup lists, LogUp's index sets and helper planes, and
the code's LogUp sum claim, generic in the configuration** (the R13 counterpart of lane L47's `BlockLookBase.lean`
index sets and of `DefW16.logupSumW16`).

The code: `accuracy_layout.rs::lookups` (`DefR13.lookups`, L44: a byte lookup per limb plane, a top-bit pin per
shifted group, `Dom::S`'s int8 pair), `layout.rs::HIds::new` (`DefR13.hDoms`: the helpers of `Dom::L`, `D`, `Q`, `Kv`,
`S`, the exp tuple's own helper, `F`, the ACT tuple's own helper, the three table helpers, `H_U`), `argument::helper_sum`
(helper `k` of a domain covers its lookups `2k`, `2k + 1`; an odd count leaves the last one single) and
`protocol::logup_sum_claim` (protocol.rs:171-188: every `H` plane with sign `−1` on a table helper, real half then
imaginary half, value `0`).

* `bLk`, `pLk`, `lkLe`, `lkDe`, `lkQe`, `lkKe`, `lkSe`, `lkFe`: the code's lookup lists at LowH24 with `ls + 1` softmax
  limbs, written out (plane ids of `AccuracyIds::new`, the pins' exponents from the precision);
* **`LookCfg c ls`**: the facts about the configuration this sub-agent reads (the lookup lists are those, `Dom::L` and
  `Dom::Tab` are one row, the other domains at least one, the token axis at most `10` bits); PROVED at the R13 rung
  (`lookCfg_rung`) and at every Shieldstral layer (`lookCfg_shield`, for a symbolic layer);
* `Dm`, `Sg`, **`SgIx c`, `PrIx c ls`, `TbIx`**: LogUp's index sets (singles: the last `Dom::S` lookup, the exp tuple,
  the ACT tuple; pairs per domain helper and cube point; the table's three columns of `2^14`);
* `card_sgIx`, `card_prIx`, `card_tbIx` and their values at both configurations (`N` = 2,064,384 at the rung and
  66,879,488 at Shieldstral);
* `lkLen`, `nHelp_eq`, **`hDoms_eq`**, `fh_eq`: the code's helper planes at a configuration of `LookCfg`;
* **`logupSumR13 c`**: the code's `logup_sum_claim` at R13 (no range sub-plane: the three table helpers carry `−1`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13Prog

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Look

open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build.Lay (LkW PrecW)
open ZK60.Exec.Slot.W16R2 (Dom)

/-! ## The lookup lists, written out -/

/-- A byte lookup of plane `q` (`byte(q)`, `Lk::u8`). -/
def bLk (q : ℕ) : LkW := ⟨[(q, 1)], 0, 8⟩

/-- A top pin `2^e·q` in the byte table (`bytes(g, Some(b))`'s last lookup, `e = 8·|g| − b`). -/
def pLk (q e : ℕ) : LkW := ⟨[(q, 2 ^ e)], 0, 8⟩

/-- `Dom::L`'s lookups: the isqrt limb planes `LIMB`, `LIMBM`. -/
def lkLe : List LkW := [bLk 6, bLk 7]

/-- `Dom::D`'s 34 lookups (`XL`, `YL`, `NR`, `NS`, `AL`, `RAL` + pin, `X1L`, `YML`, `MR`, `MS`, `ZL`, `RDL` + pin, `X2L`). -/
def lkDe (p : PrecW) : List LkW :=
  [bLk 9, bLk 10, bLk 12, bLk 13, bLk 14, bLk 15, bLk 16, bLk 17, bLk 18, bLk 19, bLk 21, bLk 22, bLk 23, bLk 24,
    bLk 25, pLk 25 (8 * 3 - p.ao), bLk 27, bLk 28, bLk 30, bLk 31, bLk 32, bLk 33, bLk 34, bLk 35, bLk 36, bLk 37, bLk 39,
    bLk 40, bLk 41, bLk 42, bLk 43, pLk 43 (8 * 3 - p.down), bLk 45, bLk 46]

/-- `Dom::Q`'s 14 lookups (`QL`, `RQL` + pin, `QRL`, `RQRL` + pin, `OL`, `RO` + pin). -/
def lkQe (p : PrecW) : List LkW :=
  [bLk 48, bLk 49, bLk 50, bLk 51, pLk 51 (8 * 2 - p.q), bLk 53, bLk 54, bLk 55, pLk 55 (8 * 1 - p.rope), bLk 57, bLk 58,
    bLk 59, bLk 60, pLk 60 (8 * 2 - p.pv)]

/-- `Dom::Kv`'s 14 lookups (`KL`, `RKL` + pin, `VL`, `RVL` + pin, `KRL`, `RKRL` + pin). -/
def lkKe (p : PrecW) : List LkW :=
  [bLk 62, bLk 63, bLk 64, bLk 65, pLk 65 (8 * 2 - p.k), bLk 67, bLk 68, bLk 69, bLk 70, pLk 70 (8 * 2 - p.v), bLk 72, bLk 73,
    bLk 74, pLk 74 (8 * 1 - p.rope)]

/-- `Dom::S`'s `13 + 2·ls` lookups: `S8`'s int8 pair, `RSL` + pin, `PL` + pin, then `SR` + pin and `SG` + pin
(`ls + 1` limbs each). -/
def lkSe (p : PrecW) (ls : ℕ) : List LkW :=
  [⟨[(75, 1)], 127, 8⟩, ⟨[(75, -1)], 127, 8⟩, bLk 76, bLk 77, bLk 78, pLk 78 (8 * 3 - p.score), bLk 82, bLk 83,
    pLk 83 (8 * 2 - (p.fp + 1))]
    ++ ((List.range' 84 (ls + 1)).map bLk ++ [pLk (84 + ls) (8 * (ls + 1) - p.wrho)])
    ++ ((List.range' (84 + (ls + 1)) (ls + 1)).map bLk ++ [pLk (84 + (ls + 1) + ls) (8 * (ls + 1) - p.wrho)])

/-- `Dom::F`'s 14 lookups (`RGL` + pin, `UL`, `RU` + pin, `HL`, `RH`), from `F0 = 86 + 2·ls`. -/
def lkFe (p : PrecW) (ls : ℕ) : List LkW :=
  [bLk (86 + 2 * ls + 1), bLk (86 + 2 * ls + 2), bLk (86 + 2 * ls + 3), pLk (86 + 2 * ls + 3) (8 * 3 - p.gate),
    bLk (86 + 2 * ls + 6), bLk (86 + 2 * ls + 7), bLk (86 + 2 * ls + 8), bLk (86 + 2 * ls + 9),
    pLk (86 + 2 * ls + 9) (8 * 2 - p.up), bLk (86 + 2 * ls + 11), bLk (86 + 2 * ls + 12), bLk (86 + 2 * ls + 13),
    bLk (86 + 2 * ls + 14), bLk (86 + 2 * ls + 15)]

/-! ## The configuration's facts -/

/-- **The facts about the configuration the lookup side reads**: the code's lookup lists are the ones written out above
(LowH24, `ls + 1` softmax limbs), `Dom::L` and `Dom::Tab` are one row of `2^14`, every other lookup domain at least
one row, and the token axis has at most `10` bits (the isqrt limbs' nine sub-slices of `2^lt` fit one row). PROVED at
the R13 rung (`lookCfg_rung`) and at every Shieldstral layer (`lookCfg_shield`). -/
structure LookCfg (c : W16Cfg) (ls : ℕ) : Prop where
  lkL : DefR13.lookups c .L = lkLe
  lkD : DefR13.lookups c .D = lkDe c.p
  lkQ : DefR13.lookups c .Q = lkQe c.p
  lkK : DefR13.lookups c .Kv = lkKe c.p
  lkS : DefR13.lookups c .S = lkSe c.p ls
  lkF : DefR13.lookups c .F = lkFe c.p ls
  logL : c.sh.logs .L = 14
  logTab : c.sh.logs .Tab = 14
  logD : 14 ≤ c.sh.logs .D
  logQ : 14 ≤ c.sh.logs .Q
  logK : 14 ≤ c.sh.logs .Kv
  logS : 14 ≤ c.sh.logs .S
  logF : 14 ≤ c.sh.logs .F
  lt10 : c.sh.lt ≤ 10

/-- **`LookCfg` at the R13 rung.** -/
theorem lookCfg_rung : LookCfg DefR13.cfgRungR13 2 where
  lkL := rfl
  lkD := rfl
  lkQ := rfl
  lkK := rfl
  lkS := rfl
  lkF := rfl
  logL := rfl
  logTab := rfl
  logD := by decide
  logQ := by decide
  logK := by decide
  logS := by decide
  logF := by decide
  lt10 := by decide

/-- A Shieldstral layer's shape is the registered one (`shShieldR13`). -/
theorem cfgShield_shL (L : ZK60.RunShape.Shield.ShieldLayer) :
    (DefR13.cfgShieldR13 L).sh = ZK60.Exec.Slot.R13.shShieldR13 := rfl

/-- A Shieldstral layer's plane ids are `AccuracyIds::new` at LowH24 with two softmax limbs. -/
theorem ids_shieldL (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.ids (DefR13.cfgShieldR13 L) = DefR13.idsR13 true 2 := by
  show DefR13.idsR13 (DefR13.cfgShieldR13 L).p.h24 (DefR13.lsOf (DefR13.cfgShieldR13 L).p) = _
  rw [show (DefR13.cfgShieldR13 L).p.h24 = true from rfl]
  show DefR13.idsR13 true (((DefR13.cfgShieldR13 L).p.wrho + 7) / 8) = _
  rw [show (DefR13.cfgShieldR13 L).p.wrho = 16 from rfl]

/-- **`LookCfg` at every layer of the Shieldstral T128 R13 block** (the layer's calibration enters the pins' exponents
only). -/
theorem lookCfg_shield (L : ZK60.RunShape.Shield.ShieldLayer) : LookCfg (DefR13.cfgShieldR13 L) 1 where
  lkL := by unfold DefR13.lookups; rw [ids_shieldL L]; rfl
  lkD := by unfold DefR13.lookups; rw [ids_shieldL L]; rfl
  lkQ := by unfold DefR13.lookups; rw [ids_shieldL L]; rfl
  lkK := by unfold DefR13.lookups; rw [ids_shieldL L]; rfl
  lkS := by unfold DefR13.lookups; rw [ids_shieldL L]; rfl
  lkF := by unfold DefR13.lookups; rw [ids_shieldL L]; rfl
  logL := rfl
  logTab := rfl
  logD := (by decide : 14 ≤ ZK60.Exec.Slot.R13.shShieldR13.logs .D)
  logQ := (by decide : 14 ≤ ZK60.Exec.Slot.R13.shShieldR13.logs .Q)
  logK := (by decide : 14 ≤ ZK60.Exec.Slot.R13.shShieldR13.logs .Kv)
  logS := (by decide : 14 ≤ ZK60.Exec.Slot.R13.shShieldR13.logs .S)
  logF := (by decide : 14 ≤ ZK60.Exec.Slot.R13.shShieldR13.logs .F)
  lt10 := (by decide : ZK60.Exec.Slot.R13.shShieldR13.lt ≤ 10)

/-! ## The index sets -/

/-- The domains whose lookups LogUp pairs. -/
inductive Dm
  | L | D | Q | Kv | S | F
  deriving DecidableEq

instance : Fintype Dm :=
  Fintype.ofList [.L, .D, .Q, .Kv, .S, .F] (fun d => by cases d <;> decide)

/-- The code's domain. -/
def Dm.dom : Dm → Dom
  | .L => .L | .D => .D | .Q => .Q | .Kv => .Kv | .S => .S | .F => .F

/-- The domain's cube bits (the code's `Shape::log`). -/
abbrev Dm.log (c : W16Cfg) (d : Dm) : ℕ := c.sh.logs d.dom

/-- The domain's pair helpers (its lookups, halved and rounded down). -/
def Dm.np (ls : ℕ) : Dm → ℕ
  | .L => 1 | .D => 17 | .Q => 7 | .Kv => 7 | .S => 6 + ls | .F => 7

/-- The domain's first helper plane (`HIds::first_helper`). -/
def Dm.fh (ls : ℕ) : Dm → ℕ
  | .L => 0 | .D => 1 | .Q => 18 | .Kv => 25 | .S => 32 | .F => 40 + ls

/-- The single lookups: `Dom::S`'s odd last lookup, the exp tuple, the ACT tuple. -/
inductive Sg
  | S | Exp | Act
  deriving DecidableEq

instance : Fintype Sg :=
  Fintype.ofList [.S, .Exp, .Act] (fun s => by cases s <;> decide)

/-- A single lookup's cube bits. -/
def Sg.log (c : W16Cfg) : Sg → ℕ
  | .S => c.sh.logs .S | .Exp => c.sh.logs .S | .Act => c.sh.logs .F

/-- A single lookup's helper plane (`Dom::S`'s last helper, `sexp`, `fact`). -/
def Sg.hp (ls : ℕ) : Sg → ℕ
  | .S => 38 + ls | .Exp => 39 + ls | .Act => 47 + ls

/-- **The single lookups' positions.** -/
abbrev SgIx (c : W16Cfg) := Σ s : Sg, (Fin (s.log c) → Bool)

/-- **The pairs' positions.** -/
abbrev PrIx (c : W16Cfg) (ls : ℕ) := Σ d : Dm, Fin (d.np ls) × (Fin (d.log c) → Bool)

/-- **The table's positions**: three columns (bytes, exp, ACT) of `2^14` entries. -/
abbrev TbIx := Fin 3 × (Fin 14 → Bool)

theorem sum_sg {M : Type} [AddCommMonoid M] (f : Sg → M) : ∑ s, f s = f .S + (f .Exp + f .Act) := by
  rw [show (Finset.univ : Finset Sg) = [Sg.S, .Exp, .Act].toFinset from rfl, List.sum_toFinset _ (by decide)]
  simp

theorem sum_dm {M : Type} [AddCommMonoid M] (f : Dm → M) :
    ∑ d, f d = f .L + (f .D + (f .Q + (f .Kv + (f .S + f .F)))) := by
  rw [show (Finset.univ : Finset Dm) = [Dm.L, .D, .Q, .Kv, .S, .F].toFinset from rfl, List.sum_toFinset _ (by decide)]
  simp

/-! ## The counts -/

theorem card_sgIx (c : W16Cfg) :
    Fintype.card (SgIx c) = 2 ^ c.sh.logs .S + (2 ^ c.sh.logs .S + 2 ^ c.sh.logs .F) := by
  rw [Fintype.card_sigma, sum_sg]
  simp only [Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  rfl

theorem card_prIx (c : W16Cfg) (ls : ℕ) :
    Fintype.card (PrIx c ls) = 1 * 2 ^ c.sh.logs .L + (17 * 2 ^ c.sh.logs .D + (7 * 2 ^ c.sh.logs .Q
      + (7 * 2 ^ c.sh.logs .Kv + ((6 + ls) * 2 ^ c.sh.logs .S + 7 * 2 ^ c.sh.logs .F)))) := by
  rw [Fintype.card_sigma, sum_dm]
  simp only [Fintype.card_prod, Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  rfl

theorem card_tbIx : Fintype.card TbIx = 49152 := by
  simp only [Fintype.card_prod, Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  norm_num

/-- At the R13 rung: `2^14 + 2^14 + 2^15` singles. -/
theorem card_sgIx_rung : Fintype.card (SgIx DefR13.cfgRungR13) = 65536 := by
  rw [card_sgIx]
  rfl

/-- At the R13 rung: `61·2^14` pairs. -/
theorem card_prIx_rung : Fintype.card (PrIx DefR13.cfgRungR13 2) = 999424 := by
  rw [card_prIx]
  rfl

/-- At a Shieldstral layer: `2^19 + 2^19 + 2^21` singles. -/
theorem card_sgIx_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    Fintype.card (SgIx (DefR13.cfgShieldR13 L)) = 3145728 := by
  rw [card_sgIx, cfgShield_shL]
  decide +kernel

/-- At a Shieldstral layer: `2^14 + 17·2^19 + 7·2^19 + 7·2^17 + 7·2^19 + 7·2^21` pairs. -/
theorem card_prIx_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    Fintype.card (PrIx (DefR13.cfgShieldR13 L) 1) = 31866880 := by
  rw [card_prIx, cfgShield_shL]
  decide +kernel

/-- **The lookups at the R13 rung**: `N = 65,536 + 2·999,424 = 2,064,384` (`126·2^14`). -/
theorem lkN_rung : Fintype.card (SgIx DefR13.cfgRungR13) + 2 * Fintype.card (PrIx DefR13.cfgRungR13 2) = 2064384 := by
  rw [card_sgIx_rung, card_prIx_rung]

/-- **The lookups at a Shieldstral layer**: `N = 3,145,728 + 2·31,866,880 = 66,879,488` (finding L47-4's count). -/
theorem lkN_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    Fintype.card (SgIx (DefR13.cfgShieldR13 L)) + 2 * Fintype.card (PrIx (DefR13.cfgShieldR13 L) 1) = 66879488 := by
  rw [card_sgIx_shield, card_prIx_shield]

/-! ## The helper planes -/

/-- The `H` planes' domains, written out: `L`, `17 D`, `7 Q`, `7 Kv`, `7 + ls` `S` and the exp tuple's, `7 F` and the
ACT tuple's, the three table helpers and `H_U`. -/
def domList (ls : ℕ) : List Dom :=
  List.replicate 1 .L ++ List.replicate 17 .D ++ List.replicate 7 .Q ++ List.replicate 7 .Kv
    ++ List.replicate (7 + ls) .S ++ [.S] ++ List.replicate 7 .F ++ [.F] ++ List.replicate 3 .Tab ++ [.Tab]

theorem domList_length (ls : ℕ) : (domList ls).length = 52 + ls := by
  simp only [domList, List.length_append, List.length_replicate, List.length_cons, List.length_nil]
  omega

section Help

variable {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls)
include hc

/-- **Every lookup domain's lookup count**: twice its pairs, plus one at `Dom::S`. -/
theorem lkLen : ∀ d : Dm, (DefR13.lookups c d.dom).length = 2 * d.np ls + (if d = .S then 1 else 0) := by
  intro d
  cases d
  · rw [show Dm.L.dom = Dom.L from rfl, hc.lkL]; simp [lkLe, Dm.np]
  · rw [show Dm.D.dom = Dom.D from rfl, hc.lkD]; simp [lkDe, Dm.np]
  · rw [show Dm.Q.dom = Dom.Q from rfl, hc.lkQ]; simp [lkQe, Dm.np]
  · rw [show Dm.Kv.dom = Dom.Kv from rfl, hc.lkK]; simp [lkKe, Dm.np]
  · rw [show Dm.S.dom = Dom.S from rfl, hc.lkS]
    simp only [lkSe, List.length_append, List.length_map, List.length_range', List.length_cons, List.length_nil,
      Dm.np, ↓reduceIte]
    omega
  · rw [show Dm.F.dom = Dom.F from rfl, hc.lkF]; simp [lkFe, Dm.np]

/-- **The helper counts** (`nHelp`): `1, 17, 7, 7, 7 + ls, 7`. -/
theorem nHelp_eq : DefR13.nHelp c .L = 1 ∧ DefR13.nHelp c .D = 17 ∧ DefR13.nHelp c .Q = 7 ∧ DefR13.nHelp c .Kv = 7
    ∧ DefR13.nHelp c .S = 7 + ls ∧ DefR13.nHelp c .F = 7 := by
  unfold DefR13.nHelp
  rw [hc.lkL, hc.lkD, hc.lkQ, hc.lkK, hc.lkS, hc.lkF]
  refine ⟨by simp [lkLe], by simp [lkDe], by simp [lkQe], by simp [lkKe], ?_, by simp [lkFe]⟩
  simp only [lkSe, List.length_append, List.length_map, List.length_range', List.length_cons, List.length_nil]
  omega

/-- **The code's `H` plane list at the configuration** (`HIds::new`). -/
theorem hDoms_eq : DefR13.hDoms c = domList ls := by
  obtain ⟨h1, h2, h3, h4, h5, h6⟩ := nHelp_eq hc
  unfold DefR13.hDoms domList
  rw [h1, h2, h3, h4, h5, h6]

/-- **The code's helper ids** (`first_l, first_d, first_q, first_kv, first_s, sexp, first_f, fact, gu8, ·, u`). -/
theorem fh_eq : DefR13.fh c 0 = 0 ∧ DefR13.fh c 1 = 1 ∧ DefR13.fh c 2 = 18 ∧ DefR13.fh c 3 = 25
    ∧ DefR13.fh c 4 = 32 ∧ DefR13.fh c 5 = 39 + ls ∧ DefR13.fh c 6 = 40 + ls ∧ DefR13.fh c 7 = 47 + ls
    ∧ DefR13.fh c 8 = 48 + ls ∧ DefR13.fh c 10 = 51 + ls := by
  obtain ⟨h1, h2, h3, h4, h5, h6⟩ := nHelp_eq hc
  have e1 : DefR13.fh c 1 = DefR13.nHelp c .L := rfl
  have e2 : DefR13.fh c 2 = DefR13.nHelp c .L + DefR13.nHelp c .D := rfl
  have e3 : DefR13.fh c 3 = DefR13.nHelp c .L + DefR13.nHelp c .D + DefR13.nHelp c .Q := rfl
  have e4 : DefR13.fh c 4 = DefR13.nHelp c .L + DefR13.nHelp c .D + DefR13.nHelp c .Q + DefR13.nHelp c .Kv := rfl
  have e5 : DefR13.fh c 5 = DefR13.nHelp c .L + DefR13.nHelp c .D + DefR13.nHelp c .Q + DefR13.nHelp c .Kv
      + DefR13.nHelp c .S := rfl
  have e6 : DefR13.fh c 6 = DefR13.nHelp c .L + DefR13.nHelp c .D + DefR13.nHelp c .Q + DefR13.nHelp c .Kv
      + DefR13.nHelp c .S + 1 := rfl
  have e7 : DefR13.fh c 7 = DefR13.nHelp c .L + DefR13.nHelp c .D + DefR13.nHelp c .Q + DefR13.nHelp c .Kv
      + DefR13.nHelp c .S + 1 + DefR13.nHelp c .F := rfl
  have e8 : DefR13.fh c 8 = DefR13.nHelp c .L + DefR13.nHelp c .D + DefR13.nHelp c .Q + DefR13.nHelp c .Kv
      + DefR13.nHelp c .S + 1 + DefR13.nHelp c .F + 1 := rfl
  have e10 : DefR13.fh c 10 = DefR13.nHelp c .L + DefR13.nHelp c .D + DefR13.nHelp c .Q + DefR13.nHelp c .Kv
      + DefR13.nHelp c .S + 1 + DefR13.nHelp c .F + 1 + 3 := rfl
  rw [e1, e2, e3, e4, e5, e6, e7, e8, e10, h1, h2, h3, h4, h5, h6]
  refine ⟨rfl, rfl, rfl, rfl, rfl, ?_, ?_, ?_, ?_, ?_⟩ <;> omega

end Help

/-! ## The code's LogUp sum claim at R13 -/

/-- **`protocol::logup_sum_claim` at R13** (protocol.rs:171-188, the configuration's `HIds`): every `H` plane, with
sign `−1` on the three table helpers (`HIds::is_table`: `gu8 … gu8 + 2`, no range sub-plane at R13) and `+1`
otherwise, its real half then its imaginary half (coefficient `sign·u`), at the log size of its domain, with an empty
point; value `0`. -/
def logupSumR13 (c : W16Cfg) : Block.ZClaim :=
  ⟨(List.range (DefR13.hDoms c).length).flatMap (fun hp =>
      let sign := if decide (DefR13.fh c 8 ≤ hp) && decide (hp < DefR13.fh c 8 + 3) then Fp2.one.neg else Fp2.one
      let ls := c.sh.logs ((DefR13.hDoms c).getD hp .Tab)
      [⟨(DefR13.hOff c hp).1, ls, sign, []⟩, ⟨(DefR13.hOff c hp).2, ls, sign.mul fp2U, []⟩]), Fp2.zero⟩

end ZK60.Exec.Block.Join.R13H.Look
