/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 2: **R13's `SC_QZC` / `SC_KVZC` raw slots and their hosted slots, as
explicit programs generic in the configuration**, the premise structure `QkvCfg` the identities read off the
configuration, and the bit-vector tools the identities need.

* `zP`, `zH`, `zcTabs`: a zero-check's tables on `Dom::Q` / `Dom::Kv` (`eq(τ)`, the two hosted claim points' `eq`, the
  two public RoPE tables, the domain's fourteen `A` planes, the RoPE source on the flipped table, the seven LogUp helper
  planes); `RQ`, `RK`: the IR's table positions; **`rawQ`**, **`rawKv`**: the hosts' raw slots (`r13QzcIr`);
  **`rawMm`** (`SC_QMM`, `SC_KMM`, `SC_VMM`), **`rawPv`** (`SC_PV`): the hosted slots' raw slots;
* **`QkvCfg c ls`**: the facts about the configuration the identities read (the six raw-slot equalities, the two hosts'
  draw lists, the lookup counts, `0 < lkv`, the shifts' range); `BlockR13HostQkvCfg.lean` proves it at the R13 rung and
  at every Shieldstral layer;
* `aPl_castB`, `msbIndex_castB`, `castB_flipB`, `mleAt_castB`: reading through an equality of widths;
* `append_splitHQR`, `append_splitQR`, `append_splitGDR`, `append_splitKR`: the splits undone; **`append_flipQR`**,
  **`append_flipKR`**: the RoPE flip of the head dimension's top bit is `flipB` at bit `lt + |g ++ j|` (`lt + lkv`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostBase
import ZK60Formal.BlockHostQkv
import ZK60Formal.BlockR13HostQkvIr

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (aPl)
open ZK60.Exec.Block.Join.W16.Qkv (drs flT flipB fxT)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Block.DefR13 (QzcR13 r13QzcIr)
open ZK60.Exec.Slot.W16R2 (Dom segLn segOff segSum Seg)
open ZK60.Exec.Slot.Build (mmIr bilIr)
open ZK60.Circuit (gP GF)

/-! ## The raw slots -/

section Raw

variable (c : W16Cfg)

/-- An `A` plane of domain `d` on its own coordinates (`DefR13.aPlane` at a plane of `d`). -/
def zP (d : Dom) (q : ℕ) : TabS := DefW16.aTab (DefR13.aOff c q) (c.sh.logs d) (DefW16.rhoC 0 (c.sh.logs d)) 0

/-- LogUp helper `j` of the domain whose helpers start at `fh hf` (`DefR13.hTab`). -/
def zH (d : Dom) (hf j : ℕ) : TabS :=
  .priv ⟨.h, [((DefR13.hOff c (DefR13.fh c hf + j)).1, false), ((DefR13.hOff c (DefR13.fh c hf + j)).2, true)],
    c.sh.logs d, DefW16.rhoC 0 (c.sh.logs d), 0, 0⟩

/-- **A RoPE zero-check's tables** on domain `d` (slot `s`, planes from `q0`, helpers from `fh hf`, hosted claim points
`p1`, `p2`): `eq(τ)` (draws `13 …`), `eq(p1)`, `eq(p2)`, `cos`, `sin`, the fourteen planes `q0 … q0 + 13`, the
source `q0` on the flipped table (`Coord::Flip` at the head dimension's first variable), the seven helpers. -/
def zcTabs (s : ℕ) (d : Dom) (q0 hf : ℕ) (p1 p2 : List Sym) : List TabS :=
  [.eq (drs s 13 (c.sh.logs d)) 0, .eq p1 0, .eq p2 0, .pub 0, .pub 0,
    zP c d q0, zP c d (q0 + 1), zP c d (q0 + 2), zP c d (q0 + 3), zP c d (q0 + 4), zP c d (q0 + 5), zP c d (q0 + 6),
    zP c d (q0 + 7), zP c d (q0 + 8), zP c d (q0 + 9), zP c d (q0 + 10), zP c d (q0 + 11), zP c d (q0 + 12),
    zP c d (q0 + 13),
    flT (DefR13.aOff c q0) (c.sh.logs d) (c.sh.logs d - c.sh.ldh) 0,
    zH c d hf 0, zH c d hf 1, zH c d hf 2, zH c d hf 3, zH c d hf 4, zH c d hf 5, zH c d hf 6]

/-- `SC_QZC`'s IR table positions: `cos 3`, `sin 4`, `Q 5`, `QR 10`, `O 14`, the flipped `Q` `19`, helpers from `20`;
`RQRL [13]`, `QL [6, 7]`, `QRL [11, 12]`, `OL [15, 16]`, `RQL [8, 9]`, `RO [17, 18]`; no gate. -/
def RQ : QzcR13 := ⟨3, 4, 5, 10, 14, 19, 20, [13], [6, 7], [11, 12], [15, 16], [8, 9], [17, 18], none⟩

/-- `SC_KVZC`'s IR table positions: `K 5`, `KR 15`, `V 10`, the flipped `K` `19`, helpers from `20`; `RKRL [18]`,
`KL [6, 7]`, `KRL [16, 17]`, `VL [11, 12]`, `RKL [8, 9]`, `RVL [13, 14]`; no gate. -/
def RK : QzcR13 := ⟨3, 4, 5, 15, 10, 19, 20, [18], [6, 7], [16, 17], [11, 12], [8, 9], [13, 14], none⟩

/-- `SC_QZC`'s plane positions (`5 + (q − 47)`). -/
abbrev shQR : ℕ → ℕ := fun q => 5 + (q - 47)

/-- `SC_KVZC`'s plane positions (`5 + (q − 61)`). -/
abbrev shKR : ℕ → ℕ := fun q => 5 + (q - 61)

/-- **`SC_QZC`'s raw slot at R13** (`DefR13.rawSlot c 15` at a LowH24 configuration whose `Dom::Q` does not pad):
draws `μ 0 … 10`, `ν 11, 12`, `τ 13 …`; hosts `SC_QMM` at `ν_0`, `SC_PV` at `ν_1` (claim point `(r_t, r_h, r_i)`). -/
def rawQ : SlotS :=
  ⟨zcTabs c 15 .Q 47 2 (drs 5 0 c.sh.lt ++ drs 5 c.sh.lt c.sh.lq)
      (drs 9 c.sh.lh c.sh.lt ++ drs 9 0 c.sh.lh ++ drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh),
    r13QzcIr DefW16.cstS RQ c.p.rope c.p.q c.p.pv (DefR13.lksS c shQR .Q) (drs 15 0 11) (drs 15 11 2)
      (fun j => Sym.pow Sym.zero j) [],
    [(5, .dr 15 11), (9, .dr 15 12)], [.dr 15 11, .dr 15 12]⟩

/-- **`SC_KVZC`'s raw slot at R13**: hosts `SC_KMM`, `SC_VMM`, whose claim points start with `SC_QMM`'s `r_q`. -/
def rawKv : SlotS :=
  ⟨zcTabs c 16 .Kv 61 3 (drs 5 0 c.sh.lt ++ drs 6 0 c.sh.lkvw) (drs 5 0 c.sh.lt ++ drs 7 0 c.sh.lkvw),
    r13QzcIr DefW16.cstS RK c.p.rope c.p.k c.p.v (DefR13.lksS c shKR .Kv) (drs 16 0 11) (drs 16 11 2)
      (fun j => Sym.pow Sym.zero j) [],
    [(6, .dr 16 11), (7, .dr 16 12)], [.dr 16 11, .dr 16 12]⟩

/-- **`SC_QMM`'s, `SC_KMM`'s and `SC_VMM`'s raw slot**: `Y` (plane `11`) with `SC_QMM`'s `r_q` fixed, the folded
weight. -/
def rawMm : SlotS :=
  ⟨[fxT (DefR13.aOff c 11) (c.sh.lt + c.sh.ld) (drs 5 0 c.sh.lt) c.sh.ld 0 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩

/-- `SC_PV`'s claim coordinates of `PP` (`Dom::S`): `ρ_0 … ρ_{lkv−1}` (`g`), fixed `r_hj`, fixed `r_t`,
`ρ_lkv …` (`t'`). -/
def ppCR : List CoordS :=
  DefW16.rhoC 0 c.sh.lkv ++ (drs 9 c.sh.lkv (c.sh.lh - c.sh.lkv)).map CoordS.fixed
    ++ (drs 9 c.sh.lh c.sh.lt).map CoordS.fixed ++ DefW16.rhoC c.sh.lkv (c.sh.lkv + c.sh.lt)

/-- `SC_PV`'s claim coordinates of `V` (`Dom::Kv`): `ρ_lkv …` (`t'`), `ρ_0 … ρ_{lkv−1}` (`g`), fixed `r_i`. -/
def vCR : List CoordS :=
  DefW16.rhoC c.sh.lkv (c.sh.lkv + c.sh.lt) ++ DefW16.rhoC 0 c.sh.lkv
    ++ (drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh).map CoordS.fixed

/-- **`SC_PV`'s raw slot** (`0 < lkv`): `eq(r_g)`, `PP` (plane `81`) at `(g, r_hj, r_t, t')`, `V` (plane `66`) at
`(t', g, r_i)`; draws `r_h` (`0 … lh − 1`), `r_t` (`lh …`), `r_i` (`lh + lt …`). -/
def rawPv : SlotS :=
  ⟨[.eq (drs 9 0 c.sh.lkv) 0, DefW16.aTab (DefR13.aOff c 81) (nS c) (ppCR c) 0,
      DefW16.aTab (DefR13.aOff c 66) (nK c) (vCR c) 1],
    bilIr DefW16.cstS (some 0) 1 2, [], []⟩

end Raw

/-! ## The configuration's facts -/

/-- **What the `SC_QZC` / `SC_KVZC` identities read off the configuration** (`ls` is the configuration's softmax limb
count less one, as in `GeoR c ls`; it is not read here): the numbered program's slots `15`, `16`, `5`, `6`, `7`, `9`
are these raw slots; the two hosts draw `μ` (`4` clauses and `7` helpers), `ν`, no `ζ` (`Dom::Q`, `Dom::Kv` do not
pad), `τ`; each domain has `14` lookups (`7` helpers); `SC_PV` reads a group axis; the requantization shifts are
below `63`. Proved at the R13 rung and at every Shieldstral layer (`BlockR13HostQkvCfg.lean`). -/
structure QkvCfg (c : W16Cfg) (ls : ℕ) : Prop where
  raw15 : DefR13.rawSlot c 15 = rawQ c
  raw16 : DefR13.rawSlot c 16 = rawKv c
  raw5 : DefR13.rawSlot c 5 = rawMm c
  raw6 : DefR13.rawSlot c 6 = rawMm c
  raw7 : DefR13.rawSlot c 7 = rawMm c
  raw9 : DefR13.rawSlot c 9 = rawPv c
  dQ : ZK60.Exec.Slot.R13.draws c.sh 15 = [(.mu, 11), (.nu, 2), (.zeta, 0), (.tau, c.sh.logs .Q)]
  dK : ZK60.Exec.Slot.R13.draws c.sh 16 = [(.mu, 11), (.nu, 2), (.zeta, 0), (.tau, c.sh.logs .Kv)]
  lkQ : (DefR13.lookups c .Q).length = 14
  lkK : (DefR13.lookups c .Kv).length = 14
  lkv_pos : 0 < c.sh.lkv
  sq : c.p.q < 63
  spv : c.p.pv < 63
  sk : c.p.k < 63
  sv : c.p.v < 63

/-! ## Reading through an equality of widths -/

theorem drs_len (s off n : ℕ) : (drs s off n).length = n := by
  simp [drs]

section Cast

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem aPl_castB (P : BlockParams) (D : CmData K P) {m n : ℕ} (h : m = n) (off : ℕ) (b : Fin m → Bool) :
    aPl U P D off n (castB h b) = aPl U P D off m b := by
  subst h
  rfl

theorem msbIndex_castB {m n : ℕ} (h : m = n) (b : Fin m → Bool) : msbIndex n (castB h b) = msbIndex m b := by
  subst h
  rfl

theorem castB_flipB {m n : ℕ} (h : m = n) (k : ℕ) (b : Fin m → Bool) :
    castB h (flipB k b) = flipB k (castB h b) := by
  subst h
  rfl

omit [Algebra GF K] in
/-- **The multilinear extension read through an equality of widths.** -/
theorem mleAt_castB {m n : ℕ} (h : m = n) (f : (Fin n → Bool) → K) (p : Fin n → K) :
    mleAt (fun b : Fin m → Bool => f (castB h b)) (fun i => p (Fin.cast h i)) = mleAt f p := by
  subst h
  rfl

end Cast

/-! ## The splits undone, the RoPE flip -/

section Splits

variable (c : W16Cfg)

theorem append_splitHQR (y : Fin (nH c + c.sh.ldh) → Bool) :
    Fin.append (Fin.append (splitHQ c y).1.1 (splitHQ c y).1.2) (splitHQ c y).2 = y := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i4 => ?_) i1
    · rw [Fin.append_left]
      rfl
    · rw [Fin.append_right]
      rfl
  · rw [Fin.append_right]
    rfl

theorem append_splitQR (b : Fin (nQ c) → Bool) :
    Fin.append (splitQ c b).1 (Fin.append (Fin.append (splitQ c b).2.1.1 (splitQ c b).2.1.2) (splitQ c b).2.2) = b := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    rfl
  · rw [Fin.append_right]
    exact congrFun (append_splitHQR c (fun i => b (Fin.natAdd c.sh.lt i))) i2

theorem append_splitGDR (y : Fin (c.sh.lkv + c.sh.ldh) → Bool) :
    Fin.append (splitGD c y).1 (splitGD c y).2 = y := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    rfl
  · rw [Fin.append_right]
    rfl

theorem append_splitKR (b : Fin (nK c) → Bool) :
    Fin.append (splitK c b).1 (Fin.append (splitK c b).2.1 (splitK c b).2.2) = b := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    rfl
  · rw [Fin.append_right]
    exact congrFun (append_splitGDR c (fun i => b (Fin.natAdd c.sh.lt i))) i2

/-- The head dimension's top bit flipped, on the last block of a bit vector. -/
theorem update_flipB {a m : ℕ} (h0 : 0 < m) (y : Fin (a + m) → Bool) (i : Fin m) :
    Function.update (fun j : Fin m => y (Fin.natAdd a j)) ⟨0, h0⟩ (!y (Fin.natAdd a ⟨0, h0⟩)) i
      = flipB a y (Fin.natAdd a i) := by
  rw [Function.update_apply]
  unfold flipB
  rw [Fin.val_natAdd]
  by_cases h : i = ⟨0, h0⟩
  · subst h
    rw [ite_eq_left rfl, ite_eq_left (by simp)]
  · have hv : (i : ℕ) ≠ 0 := fun hv => h (Fin.ext hv)
    rw [ite_eq_right h, ite_eq_right (by omega)]

/-- **`Dom::Q`'s RoPE flip is `flipB` at bit `lt + |g ++ j|`.** -/
theorem append_flipQR (h0 : 0 < c.sh.ldh) (b : Fin (nQ c) → Bool) :
    Fin.append (splitQ c b).1 (Fin.append (Fin.append (splitQ c b).2.1.1 (splitQ c b).2.1.2)
      (Function.update (splitQ c b).2.2 ⟨0, h0⟩ (!(splitQ c b).2.2 ⟨0, h0⟩))) = flipB (c.sh.lt + nH c) b := by
  have hnH : nH c = c.sh.lkv + (c.sh.lh - c.sh.lkv) := rfl
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    show b (Fin.castAdd _ i1) = flipB (c.sh.lt + nH c) b (Fin.castAdd _ i1)
    have := i1.isLt
    unfold flipB
    rw [Fin.val_castAdd, ite_eq_right (by omega)]
  · rw [Fin.append_right]
    refine Fin.addCases (fun i3 => ?_) (fun i4 => ?_) i2
    · rw [Fin.append_left]
      have e := congrFun (append_splitHQR c (fun i => b (Fin.natAdd c.sh.lt i))) (Fin.castAdd c.sh.ldh i3)
      rw [Fin.append_left] at e
      show Fin.append (splitHQ c (fun i => b (Fin.natAdd c.sh.lt i))).1.1
          (splitHQ c (fun i => b (Fin.natAdd c.sh.lt i))).1.2 i3 = _
      rw [e]
      have := i3.isLt
      unfold flipB
      simp only [Fin.val_natAdd, Fin.val_castAdd]
      rw [ite_eq_right (by omega)]
    · rw [Fin.append_right]
      have e := update_flipB (a := nH c) h0 (fun i => b (Fin.natAdd c.sh.lt i)) i4
      show Function.update (fun j : Fin c.sh.ldh => b (Fin.natAdd c.sh.lt (Fin.natAdd (nH c) j))) ⟨0, h0⟩
          (!b (Fin.natAdd c.sh.lt (Fin.natAdd (nH c) ⟨0, h0⟩))) i4 = _
      rw [e]
      unfold flipB
      simp only [Fin.val_natAdd]
      by_cases h : (i4 : ℕ) = 0
      · rw [ite_eq_left (by omega), ite_eq_left (by omega)]
      · rw [ite_eq_right (by omega), ite_eq_right (by omega)]

/-- **`Dom::Kv`'s RoPE flip is `flipB` at bit `lt + lkv`.** -/
theorem append_flipKR (h0 : 0 < c.sh.ldh) (b : Fin (nK c) → Bool) :
    Fin.append (splitK c b).1 (Fin.append (splitK c b).2.1
      (Function.update (splitK c b).2.2 ⟨0, h0⟩ (!(splitK c b).2.2 ⟨0, h0⟩))) = flipB (c.sh.lt + c.sh.lkv) b := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    show b (Fin.castAdd _ i1) = flipB (c.sh.lt + c.sh.lkv) b (Fin.castAdd _ i1)
    have := i1.isLt
    unfold flipB
    rw [Fin.val_castAdd, ite_eq_right (by omega)]
  · rw [Fin.append_right]
    refine Fin.addCases (fun i3 => ?_) (fun i4 => ?_) i2
    · rw [Fin.append_left]
      show b (Fin.natAdd c.sh.lt (Fin.castAdd c.sh.ldh i3)) = _
      have := i3.isLt
      unfold flipB
      simp only [Fin.val_natAdd, Fin.val_castAdd]
      rw [ite_eq_right (by omega)]
    · rw [Fin.append_right]
      have e := update_flipB (a := c.sh.lkv) h0 (fun i => b (Fin.natAdd c.sh.lt i)) i4
      show Function.update (fun j : Fin c.sh.ldh => b (Fin.natAdd c.sh.lt (Fin.natAdd c.sh.lkv j))) ⟨0, h0⟩
          (!b (Fin.natAdd c.sh.lt (Fin.natAdd c.sh.lkv ⟨0, h0⟩))) i4 = _
      rw [e]
      unfold flipB
      simp only [Fin.val_natAdd]
      by_cases h : (i4 : ℕ) = 0
      · rw [ite_eq_left (by omega), ite_eq_left (by omega)]
      · rw [ite_eq_right (by omega), ite_eq_right (by omega)]

end Splits

end ZK60.Exec.Block.Join.R13H.Qkv
