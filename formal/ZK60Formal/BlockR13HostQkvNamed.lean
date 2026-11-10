/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 4: **`SC_QZC`'s and `SC_KVZC`'s batches and hosted terms ARE R13's
named relations** at the extracted planes `xtR` (`r13Cl` / `r13Gh` at hosts `15`, `16`), generic in the
configuration.

* `q_alg`, `q_algF`, `k_alg`, `k_algF`: a `Dom::Q` (`Dom::Kv`) plane of `xtR` at the encoded point, embedded, is the
  committed plane at the cube point (at the RoPE-flipped point: the flipped bit of the slot's table);
* `q_cl0` … `q_cl3`, `k_cl0` … `k_cl3`: the four named clauses, embedded; **`q_clauses`**, **`k_clauses`**: the IR's
  clause list is `[r13Cl 15 0, …, r13Cl 15 3]` (`[r13Cl 16 0, …]`);
* **`q_hosts`**, **`k_hosts`**: the IR's byte-limb requantizations are `r13Gh 15 i` (`r13Gh 16 i`);
* **`xcQzcR`**, **`xcKvzcR`**: the batch's entries past the four named clauses (L44's `xcQzc` / `xcKvzc` at R13);
* **`qzc_cubeR`**, **`kvzc_cubeR`**: the hosts' cube sums with the named relations:
  `Σ_t hostPoly(τ, Σ_{κ < 11} μ_κ·(r13Cl κ or xc κ), ν, (p1, p2), 1, r13Gh)(t)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostQkvZc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg cstK cstK_base cstK_p256)
open ZK60.Exec.Block.Join.W16.Qkv (drs flipB cstK_pow cstK_negpow)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Block.DefR13 (QzcR13 r13QzcIr)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Exec.Slot.Build (Cst LkD hostTerms gV gV_none batchV logupSem padSem L256)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

section Consts

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem cstK_32768 : (cstK U).base 32768 = 32768 := by
  rw [cstK_base U 32768 (by norm_num) (by norm_num)]
  simp only [Int.cast_ofNat, map_ofNat]

theorem cstK_p0 : (cstK U).p256 0 = 1 := by
  rw [cstK_p256 U 0 (by norm_num), pow_zero]

theorem cstK_p1 : (cstK U).p256 1 = 256 := by
  rw [cstK_p256 U 1 (by norm_num), pow_one]

end Consts

/-! ## The planes of `xtR`, embedded -/

section Alg

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)}
  (hL : LayR Lay)

include hX

theorem q_alg (off : ℕ) (b : Fin (c.sh.logs .Q) → Bool) :
    algebraMap GF K (plQ U c P D off (splitQ c (castB G.logQ b))) = aPl U P D off (c.sh.logs .Q) b := by
  unfold plQ
  rw [aPl_alg U P D hX, append_splitQR c, aPl_castB]

theorem k_alg (off : ℕ) (b : Fin (c.sh.logs .Kv) → Bool) :
    algebraMap GF K (plK U c P D off (splitK c (castB G.logK b))) = aPl U P D off (c.sh.logs .Kv) b := by
  unfold plK
  rw [aPl_alg U P D hX, append_splitKR c, aPl_castB]

include hL

theorem q_algF (off : ℕ) (b : Fin (c.sh.logs .Q) → Bool) :
    algebraMap GF K (plQ U c P D off ((splitQ c (castB G.logQ b)).1,
        ((splitQ c (castB G.logQ b)).2.1, Lay.flip (splitQ c (castB G.logQ b)).2.2)))
      = aPl U P D off (c.sh.logs .Q) (flipB (c.sh.logs .Q - c.sh.ldh) b) := by
  have hidx : c.sh.logs .Q - c.sh.ldh = c.sh.lt + nH c := by
    have h := G.logQ
    change c.sh.logs .Q = c.sh.lt + (nH c + c.sh.ldh) at h
    omega
  unfold plQ
  dsimp only
  rw [hL.flip G.ldh_pos, aPl_alg U P D hX, append_flipQR c G.ldh_pos, hidx, ← castB_flipB, aPl_castB]

theorem k_algF (off : ℕ) (b : Fin (c.sh.logs .Kv) → Bool) :
    algebraMap GF K (plK U c P D off ((splitK c (castB G.logK b)).1,
        ((splitK c (castB G.logK b)).2.1, Lay.flip (splitK c (castB G.logK b)).2.2)))
      = aPl U P D off (c.sh.logs .Kv) (flipB (c.sh.logs .Kv - c.sh.ldh) b) := by
  have hidx : c.sh.logs .Kv - c.sh.ldh = c.sh.lt + c.sh.lkv := by
    have h := G.logK
    change c.sh.logs .Kv = c.sh.lt + (c.sh.lkv + c.sh.ldh) at h
    omega
  unfold plK
  dsimp only
  rw [hL.flip G.ldh_pos, aPl_alg U P D hX, append_flipKR c G.ldh_pos, hidx, ← castB_flipB, aPl_castB]

end Alg

/-! ## The named clauses and hosted terms -/

section Named

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) (hL : LayR Lay)

include hX hL

theorem q_cl0 (b : Fin (c.sh.logs .Q) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 0 (.q (splitQ c (castB G.logQ b))))
      = algebraMap GF K (B.cosT (splitQ c (castB G.logQ b))) * aPl U P D (DefR13.aOff c 47) _ b
        + algebraMap GF K (B.sinT (splitQ c (castB G.logQ b)))
          * aPl U P D (DefR13.aOff c 47) _ (flipB (c.sh.logs .Q - c.sh.ldh) b)
        - 2 ^ 7 * aPl U P D (DefR13.aOff c 52) _ b - aPl U P D (DefR13.aOff c 55) _ b + 2 ^ 6 := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gQ_oneR B hL, one_mul, Fin.sum_univ_one, Fin.val_zero, pow_zero,
    Nat.add_zero, map_add, map_sub, map_mul, map_pow, map_ofNat, q_alg U G P D hX, q_algF U G P D hX hL, offR]

theorem q_cl1 (b : Fin (c.sh.logs .Q) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 1 (.q (splitQ c (castB G.logQ b))))
      = aPl U P D (DefR13.aOff c 47) _ b + 32768
        - (aPl U P D (DefR13.aOff c 48) _ b + 256 * aPl U P D (DefR13.aOff c 49) _ b) := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gQ_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_ofNat, q_alg U G P D hX, offR, Nat.reduceAdd]

theorem q_cl2 (b : Fin (c.sh.logs .Q) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 2 (.q (splitQ c (castB G.logQ b))))
      = aPl U P D (DefR13.aOff c 52) _ b + 32768
        - (aPl U P D (DefR13.aOff c 53) _ b + 256 * aPl U P D (DefR13.aOff c 54) _ b) := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gQ_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_ofNat, q_alg U G P D hX, offR, Nat.reduceAdd]

theorem q_cl3 (b : Fin (c.sh.logs .Q) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 3 (.q (splitQ c (castB G.logQ b))))
      = aPl U P D (DefR13.aOff c 56) _ b + 32768
        - (aPl U P D (DefR13.aOff c 57) _ b + 256 * aPl U P D (DefR13.aOff c 58) _ b) := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gQ_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_ofNat, q_alg U G P D hX, offR, Nat.reduceAdd]

theorem k_cl0 (b : Fin (c.sh.logs .Kv) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 0 (.kv (splitK c (castB G.logK b))))
      = algebraMap GF K (B.cosK (splitK c (castB G.logK b))) * aPl U P D (DefR13.aOff c 61) _ b
        + algebraMap GF K (B.sinK (splitK c (castB G.logK b)))
          * aPl U P D (DefR13.aOff c 61) _ (flipB (c.sh.logs .Kv - c.sh.ldh) b)
        - 2 ^ 7 * aPl U P D (DefR13.aOff c 71) _ b - aPl U P D (DefR13.aOff c 74) _ b + 2 ^ 6 := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gK_oneR B hL, one_mul, Fin.sum_univ_one, Fin.val_zero, pow_zero,
    Nat.add_zero, map_add, map_sub, map_mul, map_pow, map_ofNat, k_alg U G P D hX, k_algF U G P D hX hL, offR]

theorem k_cl1 (b : Fin (c.sh.logs .Kv) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 1 (.kv (splitK c (castB G.logK b))))
      = aPl U P D (DefR13.aOff c 61) _ b + 32768
        - (aPl U P D (DefR13.aOff c 62) _ b + 256 * aPl U P D (DefR13.aOff c 63) _ b) := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gK_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_ofNat, k_alg U G P D hX, offR, Nat.reduceAdd]

theorem k_cl2 (b : Fin (c.sh.logs .Kv) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 2 (.kv (splitK c (castB G.logK b))))
      = aPl U P D (DefR13.aOff c 71) _ b + 32768
        - (aPl U P D (DefR13.aOff c 72) _ b + 256 * aPl U P D (DefR13.aOff c 73) _ b) := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gK_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_ofNat, k_alg U G P D hX, offR, Nat.reduceAdd]

theorem k_cl3 (b : Fin (c.sh.logs .Kv) → Bool) :
    algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 3 (.kv (splitK c (castB G.logK b))))
      = aPl U P D (DefR13.aOff c 66) _ b + 32768
        - (aPl U P D (DefR13.aOff c 67) _ b + 256 * aPl U P D (DefR13.aOff c 68) _ b) := by
  simp only [r13Cl, xtR, ZK60.Layout.R13.lv, gK_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_ofNat, k_alg U G P D hX, offR, Nat.reduceAdd]

/-- **`SC_QZC`'s IR clauses are R13's four named relations at host `15`.** -/
theorem q_clauses (hr : c.p.rope = 7) (e0 e1 e2 : K) (b : Fin (c.sh.logs .Q) → Bool) :
    r13QzcClauses (cstK U) RQ c.p.rope (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ c (castB G.logQ b)))
        :: algebraMap GF K (B.sinT (splitQ c (castB G.logQ b))) :: zcPl U c P D .Q 47 2 b)
      = [algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 0 (.q (splitQ c (castB G.logQ b)))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 1 (.q (splitQ c (castB G.logQ b)))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 2 (.q (splitQ c (castB G.logQ b)))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 3 (.q (splitQ c (castB G.logQ b))))] := by
  rw [q_cl0 U G P D hX Pb Lay B hL, q_cl1 U G P D hX Pb Lay B hL, q_cl2 U G P D hX Pb Lay B hL,
    q_cl3 U G P D hX Pb Lay B hL, hr]
  unfold r13QzcClauses
  rw [cstK_negpow U 7 (by norm_num), show (7 - 1 : ℕ) = 6 from rfl, cstK_pow U 6 (by norm_num), cstK_32768 U]
  simp only [RQ, L256, zcPl, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p0 U, cstK_p1 U, Nat.reduceAdd, List.cons.injEq,
    and_true]
  refine ⟨by ring, by ring, by ring, by ring⟩

/-- **`SC_KVZC`'s IR clauses are R13's four named relations at host `16`.** -/
theorem k_clauses (hr : c.p.rope = 7) (e0 e1 e2 : K) (b : Fin (c.sh.logs .Kv) → Bool) :
    r13QzcClauses (cstK U) RK c.p.rope (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK c (castB G.logK b)))
        :: algebraMap GF K (B.sinK (splitK c (castB G.logK b))) :: zcPl U c P D .Kv 61 3 b)
      = [algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 0 (.kv (splitK c (castB G.logK b)))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 1 (.kv (splitK c (castB G.logK b)))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 2 (.kv (splitK c (castB G.logK b)))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 3 (.kv (splitK c (castB G.logK b))))] := by
  rw [k_cl0 U G P D hX Pb Lay B hL, k_cl1 U G P D hX Pb Lay B hL, k_cl2 U G P D hX Pb Lay B hL,
    k_cl3 U G P D hX Pb Lay B hL, hr]
  unfold r13QzcClauses
  rw [cstK_negpow U 7 (by norm_num), show (7 - 1 : ℕ) = 6 from rfl, cstK_pow U 6 (by norm_num), cstK_32768 U]
  simp only [RK, L256, zcPl, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p0 U, cstK_p1 U, Nat.reduceAdd, List.cons.injEq,
    and_true]
  refine ⟨by ring, by ring, by ring, by ring⟩

/-- **`SC_QZC`'s IR hosts are R13's named requantizations `r13Gh 15 0`, `r13Gh 15 1`.** -/
theorem q_hosts (hS : PrecR c S) (hq : c.p.q < 63) (hpv : c.p.pv < 63) (e0 e1 e2 cs sn : K)
    (b : Fin (c.sh.logs .Q) → Bool) :
    reqV8 (cstK U) (e0 :: e1 :: e2 :: cs :: sn :: zcPl U c P D .Q 47 2 b) c.p.q RQ.src RQ.r1
        = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 15 0 (.q (splitQ c (castB G.logQ b))))
      ∧ reqV8 (cstK U) (e0 :: e1 :: e2 :: cs :: sn :: zcPl U c P D .Q 47 2 b) c.p.pv RQ.oth RQ.r2
        = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 15 1 (.q (splitQ c (castB G.logQ b)))) := by
  simp only [r13Gh, xtR, ZK60.Layout.R13.lv, gQ_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_pow, map_ofNat, q_alg U G P D hX, offR,
    Nat.reduceAdd, hS.sq, hS.spv]
  unfold reqV8
  rw [cstK_pow U c.p.q hq, cstK_negpow U (c.p.q - 1) (by omega), cstK_pow U c.p.pv hpv,
    cstK_negpow U (c.p.pv - 1) (by omega)]
  simp only [RQ, L256, zcPl, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p0 U, cstK_p1 U, Nat.reduceAdd]
  constructor <;> ring

/-- **`SC_KVZC`'s IR hosts are R13's named requantizations `r13Gh 16 0`, `r13Gh 16 1`.** -/
theorem k_hosts (hS : PrecR c S) (hk : c.p.k < 63) (hv : c.p.v < 63) (e0 e1 e2 cs sn : K)
    (b : Fin (c.sh.logs .Kv) → Bool) :
    reqV8 (cstK U) (e0 :: e1 :: e2 :: cs :: sn :: zcPl U c P D .Kv 61 3 b) c.p.k RK.src RK.r1
        = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 16 0 (.kv (splitK c (castB G.logK b))))
      ∧ reqV8 (cstK U) (e0 :: e1 :: e2 :: cs :: sn :: zcPl U c P D .Kv 61 3 b) c.p.v RK.oth RK.r2
        = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 16 1 (.kv (splitK c (castB G.logK b)))) := by
  simp only [r13Gh, xtR, ZK60.Layout.R13.lv, gK_oneR B hL, one_mul, Fin.sum_univ_two, Fin.val_zero, Fin.val_one,
    pow_zero, pow_one, Nat.add_zero, map_add, map_sub, map_mul, map_pow, map_ofNat, k_alg U G P D hX, offR,
    Nat.reduceAdd, hS.sk, hS.sv]
  unfold reqV8
  rw [cstK_pow U c.p.k hk, cstK_negpow U (c.p.k - 1) (by omega), cstK_pow U c.p.v hv,
    cstK_negpow U (c.p.v - 1) (by omega)]
  simp only [RK, L256, zcPl, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p0 U, cstK_p1 U, Nat.reduceAdd]
  constructor <;> ring

end Named

/-! ## The batches' other entries -/

section Xc

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_QZC`'s batch entries past the four named clauses at R13** (LogUp's seven helper relations at the cube point,
read without the draws; L44's `xcQzc`). -/
noncomputable def xcQzcR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (bga : Fp2 × Fp2 × Fp2) (κ : ℕ)
    (b : Fin (tauLen c 15) → Bool) : K :=
  xcZc U c P D .Q 47 2 bga κ b

/-- **`SC_KVZC`'s batch entries past the four named clauses at R13** (L44's `xcKvzc`). -/
noncomputable def xcKvzcR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (bga : Fp2 × Fp2 × Fp2) (κ : ℕ)
    (b : Fin (tauLen c 16) → Bool) : K :=
  xcZc U c P D .Kv 61 3 bga κ b

end Xc

end ZK60.Exec.Block.Join.R13H.Qkv
