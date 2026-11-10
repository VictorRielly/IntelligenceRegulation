/-
D63 lane L41 (2026-11-10), part 8: **the block's algebra data `dt`, the cube encodings `enc`, `encHt`, and lane
L36's `hspec : W16Spec` at the W16R2 rung**.

* `splitD`, `splitQ`, `splitK`, `splitS`, `splitHt`, `splitF`: a domain's cube point as its product cube's position
  (most significant axis first, `shape.rs::natural_log`);
* **`encW`**, **`encHtW`**: the hosts' and `Dom::Ht`'s encodings; each is onto its product cube (`Fin.append`
  inverts them);
* **`dtW`**: the algebra data whose relation entries ARE `W16Rels`' relation tables of the extracted planes `xtW`
  (embedded), the clauses past the named ones and the pad planes given (`xc`, `pwc`: LogUp's helper relations and the
  zero-rule planes, which `W16Spec` does not read), `SC_RS`'s scale `2^5` (`per_row` at the rung);
* **`hspecW`**: `W16Spec` holds for `dtW`, `xtW`, `encW`, `encHtW`, for every `xc`, `pwc`: lane L36's premise
  `hspec` discharged at the rung.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinW16
import ZK60Formal.BlockAlgRels
import ZK60Formal.BlockDefineW16Rung

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum shRungW16)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## The cube encodings -/

/-- `Dom::D`'s point `t ++ i`. -/
def splitD (b : Fin 14 → Bool) : CtW × CwW := (fun i => b (Fin.castAdd 9 i), fun i => b (Fin.natAdd 5 i))

/-- `Dom::Q`'s point `t ++ (g ++ j) ++ c`. -/
def splitQ (b : Fin 15 → Bool) : CtW × ((CgW × CjW) × CdW) :=
  (fun i => b (Fin.castAdd 10 i),
    ((fun i => b (Fin.natAdd 5 (Fin.castAdd 6 (Fin.castAdd 1 i))), fun i => b (Fin.natAdd 5 (Fin.castAdd 6 (Fin.natAdd 3 i)))),
      fun i => b (Fin.natAdd 5 (Fin.natAdd 4 i))))

/-- `Dom::Kv`'s point `t ++ g ++ c`. -/
def splitK (b : Fin 14 → Bool) : CtW × (CgW × CdW) :=
  (fun i => b (Fin.castAdd 9 i), (fun i => b (Fin.natAdd 5 (Fin.castAdd 6 i)), fun i => b (Fin.natAdd 5 (Fin.natAdd 3 i))))

/-- `Dom::S`'s point `(g ++ j) ++ t ++ t'`. -/
def splitS (b : Fin 14 → Bool) : (CgW × CjW) × CtW × CtW :=
  ((fun i => b (Fin.castAdd 10 (Fin.castAdd 1 i)), fun i => b (Fin.castAdd 10 (Fin.natAdd 3 i))),
    fun i => b (Fin.natAdd 4 (Fin.castAdd 5 i)), fun i => b (Fin.natAdd 4 (Fin.natAdd 5 i)))

/-- `Dom::Ht`'s point `(g ++ j) ++ t`. -/
def splitHt (b : Fin 9 → Bool) : (CgW × CjW) × CtW :=
  ((fun i => b (Fin.castAdd 5 (Fin.castAdd 1 i)), fun i => b (Fin.castAdd 5 (Fin.natAdd 3 i))), fun i => b (Fin.natAdd 4 i))

/-- `Dom::F`'s point `t ++ f`. -/
def splitF (b : Fin 15 → Bool) : CtW × CfW := (fun i => b (Fin.castAdd 10 i), fun i => b (Fin.natAdd 5 i))

theorem splitD_append (x : CtW × CwW) : splitD (Fin.append x.1 x.2) = x := by
  obtain ⟨t, c⟩ := x
  simp only [splitD, Fin.append_left, Fin.append_right]

theorem splitQ_append (x : CtW × ((CgW × CjW) × CdW)) :
    splitQ (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)) = x := by
  obtain ⟨t, ⟨g, j⟩, c⟩ := x
  simp only [splitQ, Fin.append_left, Fin.append_right]

theorem splitK_append (x : CtW × (CgW × CdW)) : splitK (Fin.append x.1 (Fin.append x.2.1 x.2.2)) = x := by
  obtain ⟨t, g, c⟩ := x
  simp only [splitK, Fin.append_left, Fin.append_right]

theorem splitS_append (x : (CgW × CjW) × CtW × CtW) :
    splitS (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)) = x := by
  obtain ⟨⟨g, j⟩, t, t'⟩ := x
  simp only [splitS, Fin.append_left, Fin.append_right]

theorem splitHt_append (x : (CgW × CjW) × CtW) : splitHt (Fin.append (Fin.append x.1.1 x.1.2) x.2) = x := by
  obtain ⟨⟨g, j⟩, t⟩ := x
  simp only [splitHt, Fin.append_left, Fin.append_right]

theorem splitF_append (x : CtW × CfW) : splitF (Fin.append x.1 x.2) = x := by
  obtain ⟨t, f⟩ := x
  simp only [splitF, Fin.append_left, Fin.append_right]

/-- **The hosts' cube encodings**: a host's cube point as its product cube's position. -/
def encW : (k : ℕ) → (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) →
    W16Pos CtW CwW CgW CjW CdW CfW
  | 2, b => .t b
  | 14, b => .d (splitD b)
  | 15, b => .q (splitQ b)
  | 16, b => .kv (splitK b)
  | 17, b => .s (splitS b)
  | 18, b => .f (splitF b)
  | _, _ => .t (fun _ => false)

/-- **`Dom::Ht`'s cube encoding.** -/
def encHtW (b : Fin 9 → Bool) : W16Pos CtW CwW CgW CjW CdW CfW := .ht (splitHt b)

/-! ## The pad plane counts -/

/-- **The hosts' pad plane counts at the rung**: the zero-rule planes of the padded domains (`DefW16.zeroPl`): `Dom::D`'s
19 planes at `SC_DZC`, `Dom::F`'s 9 at `SC_FZC`; the other hosts' domains do not pad. -/
def mpadW (k : ℕ) : ℕ := if k = 14 then 19 else if k = 18 then 9 else 0

theorem mpadW_zeroPl : [mpadW 14, mpadW 18]
    = [(DefW16.zeroPl DefW16.cfgRungW16 .D).length, (DefW16.zeroPl DefW16.cfgRungW16 .F).length]
      ∧ DefW16.zeroPl DefW16.cfgRungW16 .T = [] ∧ DefW16.zeroPl DefW16.cfgRungW16 .Q = []
      ∧ DefW16.zeroPl DefW16.cfgRungW16 .Kv = [] ∧ DefW16.zeroPl DefW16.cfgRungW16 .S = []
      ∧ DefW16.zeroPl DefW16.cfgRungW16 .Ht = [] := by
  decide +kernel

theorem mpadW_hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpadW k = 0 := by
  decide

theorem mpadW_hm78 : ∀ k ∈ algHosts, mpadW k ≤ 78 := by decide

/-! ## The algebra data -/

section Dt

variable {K : Type} [Field K] [Algebra GF K] (U : K) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- `32` is not `0` in an extension of the Goldilocks field. -/
theorem thirtytwo_ne_zero : (32 : K) ≠ 0 := by
  have h2 : (2 : GF) ≠ 0 := by
    have hc : ringChar GF = gP := ZMod.ringChar_zmod_n gP
    exact Ring.two_ne_zero (by rw [hc]; norm_num)
  have h32 : (32 : GF) ≠ 0 := by
    rw [show (32 : GF) = 2 ^ 5 by norm_num]
    exact pow_ne_zero 5 h2
  intro h
  apply h32
  have : algebraMap GF K 32 = 0 := by rw [map_ofNat]; exact h
  exact (algebraMap GF K).injective (this.trans (map_zero _).symm)

variable (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (mpad : ℕ → ℕ)
  (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
  (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78)
  (E : Cuts3 L → RootsO → W16Data CtW CwW CgW CjW CdW CfW)

/-- **The algebra data at the rung**: the named relations' tables of the extracted planes `E` through the encodings;
the batch entries past the named clauses `xc` and the pad planes `pwc` given. -/
noncomputable def dtW
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpad k) →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K) :
    AlgData K L (algShapeW16Rung P hdr mpad hm0 hm78) where
  cl k cu rt bga κ b :=
    if (κ : ℕ) < relCount k then algebraMap GF K (relCl Pb Lay B (E cu rt) k κ (encW k b)) else xc k cu rt bga κ b
  pw k cu rt j b := pwc k cu rt j b
  gh k cu rt i b := algebraMap GF K (relGh Pb Lay B (E cu rt) k i (encW k b))
  mm k cu rt i b := algebraMap GF K (relMm Pb Lay B (E cu rt) k i (encW k b))
  rsA cu rt b := algebraMap GF K (relRsA Pb Lay B (E cu rt) (encHtW b))
  rsB cu rt b := algebraMap GF K (relRsB Pb Lay B (E cu rt) (encHtW b))
  rsScale := 32
  hsc := thirtytwo_ne_zero

/-- The batch has room for the named clauses: `relCount k ≤ segLn μ − segLn ζ` at every host. -/
theorem relCount_room : ∀ k ∈ algHosts,
    relCount k ≤ segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .mu
      - segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta := by
  decide

/-- **Lane L36's `hspec` at the rung**: the algebra data `dtW` IS `W16Rels`' relation tables of `E` through onto
encodings, for every choice of the batch's other entries and the pad planes. -/
theorem hspecW
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpad k) →
      (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K) :
    W16Spec (algShapeW16Rung P hdr mpad hm0 hm78) (dtW Pb Lay B P hdr mpad hm0 hm78 E xc pwc) Pb Lay B E encW
      encHtW where
  cl k hk j hj := by
    refine ⟨⟨j, lt_of_lt_of_le hj (relCount_room k hk)⟩, fun cu rt bga b => ?_⟩
    show (if j < relCount k then _ else _) = _
    rw [ite_eq_left hj]
  gh _ _ _ _ _ _ _ := rfl
  mm _ _ _ _ _ _ _ := rfl
  rsA _ _ _ := rfl
  rsB _ _ _ := rfl
  st x := ⟨x, rfl⟩
  sd x := ⟨Fin.append x.1 x.2, by show W16Pos.d (splitD _) = _; rw [splitD_append]⟩
  sq x := ⟨Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2),
    by show W16Pos.q (splitQ _) = _; rw [splitQ_append]⟩
  sk x := ⟨Fin.append x.1 (Fin.append x.2.1 x.2.2), by show W16Pos.kv (splitK _) = _; rw [splitK_append]⟩
  ss x := ⟨Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2),
    by show W16Pos.s (splitS _) = _; rw [splitS_append]⟩
  sf x := ⟨Fin.append x.1 x.2, by show W16Pos.f (splitF _) = _; rw [splitF_append]⟩
  sht x := ⟨Fin.append (Fin.append x.1.1 x.1.2) x.2, by show W16Pos.ht (splitHt _) = _; rw [splitHt_append]⟩

end Dt

end ZK60.Exec.Block.Join.W16
