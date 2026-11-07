/-
D63 Lean lane L17 (2026-11-07): **the Shieldstral T128 R13 shape's concrete facts, as finite checks**: the real
model's per-layer calibration is accepted at R13, and the R13 plane list does not move with it.

Lane A25 found that the real Shieldstral export cannot run at W16R2: its per-layer requantization shifts (`sh_ao`, `sh_s`,
`sh_h`, `sh_z`: 17 distinct sets over 26 layers) and gate denominators (18, 19, 20) move W16R2's range families and so
its plane list (three different lists over the 26 layers; the trained door refuses 8). At R13 the plane list is a
function of the STACK and the softmax limb count `ls` only (`AccuracyIds::new`, accuracy_layout.rs:51-104): a shift
moves only the coefficient `2^(8c − b)` of its top limb's pin (accuracy_layout.rs:226-236), never a plane, a lookup count
or a slot degree, provided it lies in its counted limb window — which `accuracy_precision::derive` checks
(accuracy_precision.rs:56-104).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `derive`: `accuracy_precision::derive` at a LOW stack, executable (the base class, `tn − 8 > 0`, the derived windows);
* **`derive_windows`**: at LowH24, every calibration `derive` accepts puts each shift in its R13 limb window (three limbs
  for the 24-bit remainders `ao`, `score`, `down`; two for `q`, `k`, `v`, `pv`, `up`); with the common gate shift in
  `17..24`, the softmax window and the product shift `16`, that is `LayoutR13.lean`'s `R13Windows`
  (**`windows_of_derive`**), the hypothesis of `blockSat_of_slots_r13`;
* `aPlanes`, `lookupsPerPos`, `hPlanes`: the R13 plane list's counts as functions of `(h24, ls)` alone (no shift is an
  argument); `planes_shield` (`107`, `53`, the census's run seed and every one of its 26 stages) and `planes_rung`
  (`109`, `54`, the shape corpus);
* **`shield_layers_accepted`**: each of the real export's 26 layer calibrations (A25's census,
  `results/zk60_a25_app_20261107/c1.progress`, with the run's `tn 9, sh_qkv 8, sh_o 9, sh_g 8`) is accepted by `derive`
  at LowH24 with its gate denominator in `17..24`: so every stage meets `R13Windows` and has the run seed's plane list.
-/
import ZK60Formal.LayoutR13

namespace ZK60.Layout.R13.Shape

open ZK60.Circuit

/-- `accuracy_precision::BaseShifts`: the trained calibration's shifts (`Shape::accuracy_base`, shape.rs:894-897:
`norm_tn`, `sh_qkv`, `sh_s`, `sh_o`, `sh_ao`, `sh_g`, `0`, `sh_h`, `sh_z`). -/
structure Base where
  tn : ℕ
  qkv : ℕ
  score : ℕ
  pv : ℕ
  ao : ℕ
  gate : ℕ
  up : ℕ
  product : ℕ
  down : ℕ
  deriving DecidableEq, Repr

/-- `accuracy_precision::Precision`'s shifts. -/
structure Prec where
  tn : ℕ
  q : ℕ
  k : ℕ
  v : ℕ
  score : ℕ
  pv : ℕ
  ao : ℕ
  gate : ℕ
  up : ℕ
  product : ℕ
  down : ℕ
  fp : ℕ
  deriving DecidableEq, Repr

def inR (a b x : ℕ) : Bool := a ≤ x && x ≤ b

/-- **`accuracy_precision::derive` at a LOW stack** (`h24`: LowH24): the base class, `tn − 8 > 0`, the derived shifts, the
derived windows; `none` exactly where the code returns an error. -/
def derive (h24 : Bool) (b : Base) : Option Prec :=
  if !(inR 1 16 b.tn && inR 1 8 b.qkv && inR 1 8 b.score && inR 9 16 b.pv && decide (b.ao ≤ 8) && inR 1 8 b.gate
      && b.up == 0 && inR 9 16 b.product && inR 1 8 b.down) then none
  else if b.tn ≤ 8 then none
  else if b.product < (if h24 then 8 else 0) then none
  else
    let p : Prec := ⟨b.tn - 8, b.qkv + 7, b.qkv + 7, b.qkv + 8, b.score + 12, b.pv + 3, b.ao + 14, b.gate + 10,
      b.up + 12, b.product - (if h24 then 8 else 0), b.down + 6 + (if h24 then 8 else 0), 12⟩
    if !(inR 9 16 p.q && inR 9 16 p.k && inR 9 16 p.v && inR 9 16 p.pv && inR 9 16 p.up && inR 17 24 p.score
        && inR 17 24 p.ao && inR 1 24 p.gate && (if h24 then inR 5 8 p.product else inR 13 16 p.product)
        && (if h24 then inR 17 24 p.down else inR 9 16 p.down)) then none
    else some p

/-- **Every calibration `derive` accepts at LowH24 has its shifts in the R13 limb windows**: the 24-bit remainders
(`ao`, `score`, `down`) in `17..24` (three byte limbs, the top pinned), the 16-bit ones (`q`, `k`, `v`, `pv`, `up`) in
`9..16` (two limbs), `f_p = 12`. -/
theorem derive_windows {b : Base} {p : Prec} (h : derive true b = some p) :
    (16 < p.ao ∧ p.ao ≤ 24) ∧ (16 < p.down ∧ p.down ≤ 24) ∧ (8 < p.q ∧ p.q ≤ 16) ∧ (8 < p.pv ∧ p.pv ≤ 16)
      ∧ (8 < p.k ∧ p.k ≤ 16) ∧ (8 < p.v ∧ p.v ≤ 16) ∧ (16 < p.score ∧ p.score ≤ 24) ∧ (8 < p.up ∧ p.up ≤ 16)
      ∧ p.fp = 12 := by
  simp only [derive] at h
  split_ifs at h with h1 h2 h3 h4
  cases h
  simp [inR] at h4
  dsimp only
  exact ⟨⟨by omega, by omega⟩, ⟨by omega, by omega⟩, ⟨by omega, by omega⟩, ⟨by omega, by omega⟩, ⟨by omega, by omega⟩,
    ⟨by omega, by omega⟩, ⟨by omega, by omega⟩, ⟨by omega, by omega⟩, rfl⟩

/-- **The R13 windows of a block shape from its accepted calibration** (`LayoutR13.lean`'s `R13Windows`): the shape's
shifts are the derived ones, the common gate shift in `17..24` (`with_accuracy_gate_shift`, shape.rs:904-910), the
softmax window of `ls + 1` limbs (`limbs_sigma_s`), the product shift `16` (the fold's, at LowH24). -/
theorem windows_of_derive (S : ZK60.Block.BlockShape) (ls : ℕ) {b : Base} {p : Prec} (h : derive true b = some p)
    (hq : S.sq = p.q) (hk : S.sk = p.k) (hv : S.sv = p.v) (hs : S.ss = p.score) (hpv : S.spv = p.pv)
    (hao : S.sao = p.ao) (hup : S.sup = p.up) (hdown : S.sdown = p.down) (hfp : S.fp = p.fp)
    (hgate : 17 ≤ S.sgate ∧ S.sgate ≤ 24) (hw : 8 * ls < S.wrho ∧ S.wrho ≤ 8 * (ls + 1)) (hw24 : S.wrho ≤ 24)
    (hprod : S.sprod = 16) : R13Windows S ls := by
  obtain ⟨w1, w2, w3, w4, w5, w6, w7, w8, w9⟩ := derive_windows h
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ⟨by omega, hgate.2⟩, ?_, ?_, hw, hw24, hprod⟩ <;> omega

/-! ## The plane list, a function of the stack and `ls` alone -/

/-- `AccuracyIds::new`'s `A` plane count (non-DD): `Dom::T` 4, `Dom::Ht` 2, `Dom::L` 2, `Dom::D` `36 + RDL`
(`RDL` three limbs at h24, two at LOW), `Dom::Q` 14, `Dom::Kv` 14, `Dom::S` `9 + 2·ls`, `Dom::F` 16, `Dom::Tab` 3. -/
def aPlanes (h24 : Bool) (ls : ℕ) : ℕ := 4 + 2 + 2 + (36 + (if h24 then 3 else 2)) + 14 + 14 + (9 + 2 * ls) + 16 + 3

/-- `AccuracyIds::lookups`' count per position of each lookup domain (`L`, `D`, `Q`, `Kv`, `S`, `F`): every limb a
byte, one pin per pinned remainder. -/
def lookupsPerPos (h24 : Bool) (ls : ℕ) : List ℕ :=
  [2, 31 + (if h24 then 3 else 2), 14, 14, 11 + 2 * ls, 14]

/-- `Shape::h_plane_doms`' count: the helpers (two lookups each) of `L`, `D`, `Q`, `Kv`, `S` (plus the exp helper), `F`
(plus the ACT helper), and `Dom::Tab`'s three table helpers and `u` (no range sub-plane). -/
def hPlanes (h24 : Bool) (ls : ℕ) : ℕ :=
  ((lookupsPerPos h24 ls).map fun n => (n + 1) / 2).sum + 1 + 1 + 4

/-- **The Shieldstral T128 R13 plane list** (LowH24, `ls = 2`): `A` 107 and `H` 53 planes, `D` 34, `Q` 14, `Kv` 14,
`S` 15, `F` 14 lookups per position: the census's run seed and every one of its 26 stages (A25), and the shape corpus. -/
theorem planes_shield : aPlanes true 2 = 107 ∧ hPlanes true 2 = 53 ∧ lookupsPerPos true 2 = [2, 34, 14, 14, 15, 14] := by
  decide

/-- The R13 development rung (LowH24, `ls = 3`): `A` 109, `H` 54 (the shape corpus). -/
theorem planes_rung : aPlanes true 3 = 109 ∧ hPlanes true 3 = 54 ∧ lookupsPerPos true 3 = [2, 34, 14, 14, 17, 14] := by
  decide

/-! ## The real Shieldstral export's 26 layer calibrations -/

/-- One layer's per-layer constants: `(sh_ao, sh_s, sh_h, sh_z, gate denominator)`. -/
abbrev LayerCal := ℕ × ℕ × ℕ × ℕ × ℕ

/-- **The real Shieldstral-1.0-3B export's 26 layers** (A25's census, `results/zk60_a25_app_20261107/c1.progress`,
2026-11-07: `own (sh_ao sh_s sh_h sh_z) gate`), layers 0 to 25. -/
def shieldLayers : List LayerCal :=
  [(8, 7, 16, 8, 19), (8, 8, 14, 8, 19), (8, 8, 16, 6, 18), (8, 8, 15, 8, 20), (8, 6, 15, 8, 20), (8, 7, 15, 8, 20),
   (7, 7, 15, 8, 20), (8, 6, 15, 8, 20), (8, 6, 15, 8, 20), (7, 7, 14, 8, 20), (7, 6, 16, 8, 19), (7, 7, 15, 8, 20),
   (7, 6, 14, 8, 20), (7, 7, 13, 8, 20), (7, 7, 13, 8, 19), (7, 7, 13, 8, 20), (6, 6, 14, 8, 20), (7, 7, 14, 8, 20),
   (6, 7, 15, 8, 20), (7, 7, 15, 8, 20), (6, 7, 16, 8, 20), (7, 7, 14, 8, 20), (6, 7, 15, 8, 20), (7, 8, 16, 8, 19),
   (7, 8, 15, 8, 19), (7, 8, 15, 5, 19)]

/-- A layer's base shifts: the run's `tn 9, sh_qkv 8, sh_o 9, sh_g 8` and the layer's own `sh_ao, sh_s, sh_h, sh_z`. -/
def shieldBase (c : LayerCal) : Base := ⟨9, 8, c.2.1, 9, c.1, 8, 0, c.2.2.1, c.2.2.2.1⟩

/-- **Every one of the 26 real layer calibrations is accepted at R13 (LowH24)**, with its gate denominator in
`17..24`: by `windows_of_derive`, every stage meets `R13Windows` (at `ls = 2`, `wrho ≤ 16`) and keeps the run seed's
plane list (`aPlanes true 2`, `hPlanes true 2`, which take no shift). -/
theorem shield_layers_accepted : shieldLayers.length = 26 ∧
    ∀ c ∈ shieldLayers, (derive true (shieldBase c)).isSome = true ∧ 17 ≤ c.2.2.2.2 ∧ c.2.2.2.2 ≤ 24 := by
  decide

/-- The distinct shift sets among them (A25: 17). -/
theorem shield_shift_sets : (shieldLayers.map fun c => (c.1, c.2.1, c.2.2.1, c.2.2.2.1)).dedup.length = 17 := by
  decide

end ZK60.Layout.R13.Shape
