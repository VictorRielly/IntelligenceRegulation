/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 3: **a RoPE zero-check at R13 on its cube** (`SC_QZC` on `Dom::Q`,
`SC_KVZC` on `Dom::Kv`), generic in the configuration, the domain and the IR's positions.

* `zcPl`, `zcV`: the value list at a cube point with the zero extension (`eq(τ)`, `eq(p1)`, `eq(p2)`, `cos`, `sin`, the
  planes, the flipped source, the helpers); **`zc_vals`**: the numbered tables read there are `zcV` (whatever the claim
  sites of the numbering);
* `lksF`: the lookups read in the field; `lksF_pos`, `lksF_length`, `lksF_eval`: they read positions `≥ 5`, there are
  as many as the domain's lookups, and they read only `α` and `γ`;
* **`xcZc`**: the batch's entries past the four named clauses: LogUp's seven helper relations at the cube point, read
  without the draws (L44's `xcQzc` at R13);
* **`zc_cube`**: the slot's cube sum is `Σ_t hostPoly(τ, Z, ν, (p1, p2), 1, (host₁, host₂))(t)` with `Z` the IR's batch
  at `zcV t`;
* **`zc_Z`**: that batch is `Σ_{κ < 11} μ_κ·(clause κ, or `xcZc κ`)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostQkvBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (aPl hPl tabK_ph_cpt tabK_pa_cpt eqT_eval pubT_eval cstK cstS_map lkRels_congr)
open ZK60.Exec.Block.Join.W16.Qkv (drs drs_length flT flC flT_eval flipB tabK_fl_cpt eqv)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Block.DefR13 (QzcR13 r13QzcIr)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Exec.Slot.Build (Cst LkD hostTerms gV gV_none batchV logupSem padSem)
open ZK60.Exec.Slot.Compose (cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open Finset

/-! ## The value list -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A RoPE zero-check's private entries at a cube point**: the planes `q0 … q0 + 13`, the source `q0` at the flipped
bit vector, the seven helpers. -/
noncomputable def zcPl (c : W16Cfg) (P : BlockParams) (D : CmData K P) (d : Dom) (q0 hf : ℕ)
    (b : Fin (c.sh.logs d) → Bool) : List K :=
  [aPl U P D (DefR13.aOff c q0) _ b, aPl U P D (DefR13.aOff c (q0 + 1)) _ b, aPl U P D (DefR13.aOff c (q0 + 2)) _ b,
    aPl U P D (DefR13.aOff c (q0 + 3)) _ b, aPl U P D (DefR13.aOff c (q0 + 4)) _ b,
    aPl U P D (DefR13.aOff c (q0 + 5)) _ b, aPl U P D (DefR13.aOff c (q0 + 6)) _ b,
    aPl U P D (DefR13.aOff c (q0 + 7)) _ b, aPl U P D (DefR13.aOff c (q0 + 8)) _ b,
    aPl U P D (DefR13.aOff c (q0 + 9)) _ b, aPl U P D (DefR13.aOff c (q0 + 10)) _ b,
    aPl U P D (DefR13.aOff c (q0 + 11)) _ b, aPl U P D (DefR13.aOff c (q0 + 12)) _ b,
    aPl U P D (DefR13.aOff c (q0 + 13)) _ b,
    aPl U P D (DefR13.aOff c q0) _ (flipB (c.sh.logs d - c.sh.ldh) b),
    hPl U P D (DefR13.hOff c (DefR13.fh c hf + 0)).1 (DefR13.hOff c (DefR13.fh c hf + 0)).2 _ b,
    hPl U P D (DefR13.hOff c (DefR13.fh c hf + 1)).1 (DefR13.hOff c (DefR13.fh c hf + 1)).2 _ b,
    hPl U P D (DefR13.hOff c (DefR13.fh c hf + 2)).1 (DefR13.hOff c (DefR13.fh c hf + 2)).2 _ b,
    hPl U P D (DefR13.hOff c (DefR13.fh c hf + 3)).1 (DefR13.hOff c (DefR13.fh c hf + 3)).2 _ b,
    hPl U P D (DefR13.hOff c (DefR13.fh c hf + 4)).1 (DefR13.hOff c (DefR13.fh c hf + 4)).2 _ b,
    hPl U P D (DefR13.hOff c (DefR13.fh c hf + 5)).1 (DefR13.hOff c (DefR13.fh c hf + 5)).2 _ b,
    hPl U P D (DefR13.hOff c (DefR13.fh c hf + 6)).1 (DefR13.hOff c (DefR13.fh c hf + 6)).2 _ b]

/-- **A RoPE zero-check's value list at a cube point with the zero extension.** -/
noncomputable def zcV (c : W16Cfg) (P : BlockParams) (D : CmData K P) (d : Dom) (s q0 hf : ℕ) (p1 p2 : List Sym)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin (c.sh.logs d) → Bool) : List K :=
  eqv U (drs s 13 (c.sh.logs d)) ev _ b :: eqv U p1 ev _ b :: eqv U p2 ev _ b
    :: ((pub 0).getD (msbIndex _ b) Fp2.zero).toK U :: ((pub 1).getD (msbIndex _ b) Fp2.zero).toK U
    :: zcPl U c P D d q0 hf b

/-- An `A` table on its own coordinates, numbered and evaluated. -/
theorem evA (ev : Sym → Fp2) (pub : ℕ → List Fp2) (aB hB ioIn ioOut ak hk off log m ext : ℕ) :
    TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk ⟨.a, [(off, false)], log, DefW16.rhoC 0 log, m, ext⟩))
      = .priv ⟨.a, [(off, Fp2.one)], log, rhoAll log, aB + 2 * ak, ext⟩ :=
  aTab_eval ev pub off log ext (aB + 2 * ak)

/-- An `H` table on its own coordinates, numbered and evaluated. -/
theorem evH (ev : Sym → Fp2) (pub : ℕ → List Fp2) (aB hB ioIn ioOut ak hk re im log m : ℕ) :
    TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
        ⟨.h, [(re, false), (im, true)], log, DefW16.rhoC 0 log, m, 0⟩))
      = .priv ⟨.h, [(re, Fp2.one), (im, fp2U)], log, rhoAll log, hB + 2 * hk, 0⟩ :=
  ZK60.Exec.Block.Join.W16.hTab_eval ev pub re im log (hB + 2 * hk)

/-- The RoPE source table (one coordinate flipped), numbered and evaluated. -/
theorem evF (ev : Sym → Fp2) (pub : ℕ → List Fp2) (aB hB ioIn ioOut ak hk off log k m : ℕ) :
    TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
        ⟨.a, [(off, false)], log, (List.range log).map (fun j => if j = k then CoordS.flip j else CoordS.rho j), m, 0⟩))
      = .priv ⟨.a, [(off, Fp2.one)], log, flC log k, aB + 2 * ak, 0⟩ :=
  flT_eval ev pub off log k (aB + 2 * ak)

/-- **The numbered tables of a RoPE zero-check at a cube point with the zero extension are `zcV`.** -/
theorem zc_vals (c : W16Cfg) (d : Dom) (s q0 hf : ℕ) (p1 p2 : List Sym) (aB hB ioIn ioOut ak hk : ℕ)
    (P : BlockParams) (D : CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h) (hpos : 0 < c.sh.logs d)
    (e : ℕ) (b : Fin (c.sh.logs d) → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2)
    (h1 : p1.length = c.sh.logs d) (h2 : p2.length = c.sh.logs d) :
    ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hf p1 p2)).map (TabS.eval ev pub)).map
        (tabK U P D (c.sh.logs d) e (cpt (c.sh.logs d) e b))
      = zcV U c P D d s q0 hf p1 p2 ev pub b := by
  have l0 : ((drs s 13 (c.sh.logs d)).map ev).length = c.sh.logs d := drs_length _ _ _ ev
  have l1 : (p1.map ev).length = c.sh.logs d := by rw [List.length_map, h1]
  have l2 : (p2.map ev).length = c.sh.logs d := by rw [List.length_map, h2]
  simp only [zcTabs, zP, zH, flT, DefW16.aTab, DefW16.numTabs, List.map_cons, List.map_nil, evA, evH, evF, eqT_eval,
    pubT_eval, Nat.zero_add]
  rw [tabK_eqFull_cpt U P D _ e b _ l0, tabK_eqFull_cpt U P D _ e b _ l1, tabK_eqFull_cpt U P D _ e b _ l2,
    tabK_pub_cpt U P D _ e b, tabK_pub_cpt U P D _ e b,
    tabK_fl_cpt U P D hrlA _ e b (c.sh.logs d - c.sh.ldh) hpos]
  simp only [tabK_pa_cpt U P D hrlA (c.sh.logs d) e b (c.sh.logs d) hpos rfl,
    tabK_ph_cpt U P D hrlH (c.sh.logs d) e b (c.sh.logs d) hpos rfl, castB_rfl]
  rfl

/-- Off the zero extension the three `eq` entries are `0`. -/
theorem zc_off (c : W16Cfg) (d : Dom) (s q0 hf : ℕ) (p1 p2 : List Sym) (aB hB ioIn ioOut ak hk : ℕ)
    (P : BlockParams) (D : CmData K P) (e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin (c.sh.logs d) → Bool)
    (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hf p1 p2)).map (TabS.eval ev pub)).map
        (tabK U P D (c.sh.logs d) e (bpt (c.sh.logs d) e b y))).getD 0 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hf p1 p2)).map (TabS.eval ev pub)).map
        (tabK U P D (c.sh.logs d) e (bpt (c.sh.logs d) e b y))).getD 1 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hf p1 p2)).map (TabS.eval ev pub)).map
        (tabK U P D (c.sh.logs d) e (bpt (c.sh.logs d) e b y))).getD 2 0 = 0 := by
  simp only [zcTabs, DefW16.numTabs, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
  exact ⟨tabK_eq_off U P D _ e b y hy _ _, tabK_eq_off U P D _ e b y hy _ _, tabK_eq_off U P D _ e b y hy _ _⟩

end Vals

/-! ## The lookups -/

section Lk

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A RoPE zero-check's lookups, read at a history and draws, in the field. -/
noncomputable def lksF (c : W16Cfg) (shaped : ℕ → ℕ) (d : Dom) (hist : Hist) (s : ℕ) (dr : List Fp2) :
    List (LkD K) :=
  ((DefR13.lksS c shaped d).map (LkD.map (Sym.eval hist s dr))).map (LkD.map (Fp2.toK U))

/-- **R13's lookups read only `α` and `γ`.** -/
theorem lksR_eval (c : W16Cfg) (shaped : ℕ → ℕ) (d : Dom) (h h' : Hist) (k k' : ℕ) (dr dr' : List Fp2)
    (ha : h.alpha = h'.alpha) (hg : h.gamma = h'.gamma) :
    (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h k dr))
      = (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h' k' dr')) := by
  unfold DefR13.lksS
  simp only [List.map_map]
  refine List.map_congr_left (fun l _ => ?_)
  simp only [Function.comp_def, LkD.map, Sym.eval, ha, hg, List.map_map]

theorem lksF_eval (c : W16Cfg) (shaped : ℕ → ℕ) (d : Dom) (h h' : Hist) (k k' : ℕ) (dr dr' : List Fp2)
    (ha : h.alpha = h'.alpha) (hg : h.gamma = h'.gamma) :
    lksF U c shaped d h k dr = lksF U c shaped d h' k' dr' := by
  unfold lksF
  rw [lksR_eval c shaped d h h' k k' dr dr' ha hg]

/-- The lookups read positions `≥ q`. -/
theorem lksF_pos (c : W16Cfg) (d : Dom) (q q0 : ℕ) (hq : q ≤ 5) (hist : Hist) (s : ℕ) (dr : List Fp2) :
    ∀ l ∈ lksF U c (fun p => 5 + (p - q0)) d hist s dr, ∀ t ∈ l.terms, q ≤ t.2 := by
  intro l hl t ht
  unfold lksF DefR13.lksS at hl
  simp only [List.map_map, List.mem_map, Function.comp] at hl
  obtain ⟨l0, -, rfl⟩ := hl
  simp only [LkD.map, List.map_map, List.mem_map, Function.comp] at ht
  obtain ⟨t0, -, rfl⟩ := ht
  omega

theorem lksF_length (c : W16Cfg) (shaped : ℕ → ℕ) (d : Dom) (hist : Hist) (s : ℕ) (dr : List Fp2) :
    (lksF U c shaped d hist s dr).length = (DefR13.lookups c d).length := by
  unfold lksF DefR13.lksS
  simp only [List.length_map]

end Lk

/-! ## The batch's other entries -/

section Xc

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A RoPE zero-check's batch entries past the four named clauses**: LogUp's helper relations at the cube point,
read without the draws (entry `κ` for `4 ≤ κ`; L44's `xcQzc` at R13). They read the committed planes and `(α, γ)`. -/
noncomputable def xcZc (c : W16Cfg) (P : BlockParams) (D : CmData K P) (d : Dom) (q0 hf : ℕ)
    (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin (c.sh.logs d) → Bool) : K :=
  (0 :: 0 :: 0 :: 0 :: lkRels (cstK U) (0 :: 0 :: 0 :: 0 :: 0 :: zcPl U c P D d q0 hf b) 20 0
    (lksF U c (fun p => 5 + (p - q0)) d (histOf bga.1 bga.2.1 bga.2.2 []) 0 [])).getD κ 0

/-- **The batch at a cube point is `Σ_{κ < 11} μ_κ·(clause κ, or a helper relation)`.** -/
theorem zc_Z (c : W16Cfg) (P : BlockParams) (D : CmData K P) (d : Dom) (q0 hf : ℕ) (hlk : (DefR13.lookups c d).length = 14)
    (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (s : ℕ) (dr : List Fp2) (ha : hist.alpha = bga.2.2)
    (hgm : hist.gamma = bga.2.1) (mu : List K) (e0 e1 e2 e3 e4 c0 c1 c2 c3 : K) (b : Fin (c.sh.logs d) → Bool) :
    logupSem (cstK U) (e0 :: e1 :: e2 :: e3 :: e4 :: zcPl U c P D d q0 hf b) 20 (fun k => mu.getD (4 + k) 0) 0
        (lksF U c (fun p => 5 + (p - q0)) d hist s dr)
      + gV (e0 :: e1 :: e2 :: e3 :: e4 :: zcPl U c P D d q0 hf b) none * batchV mu [c0, c1, c2, c3]
      = ∑ κ : Fin 11, mu.getD κ 0 * (if (κ : ℕ) < 4 then [c0, c1, c2, c3].getD κ 0
          else xcZc U c P D d q0 hf bga κ b) := by
  have hlk' : lksF U c (fun p => 5 + (p - q0)) d hist s dr
      = lksF U c (fun p => 5 + (p - q0)) d (histOf bga.1 bga.2.1 bga.2.2 []) 0 [] :=
    lksF_eval U c _ d hist _ s 0 dr [] ha hgm
  have hcg : lkRels (cstK U) (e0 :: e1 :: e2 :: e3 :: e4 :: zcPl U c P D d q0 hf b) 20 0
        (lksF U c (fun p => 5 + (p - q0)) d hist s dr)
      = lkRels (cstK U) (0 :: 0 :: 0 :: 0 :: 0 :: zcPl U c P D d q0 hf b) 20 0
        (lksF U c (fun p => 5 + (p - q0)) d (histOf bga.1 bga.2.1 bga.2.2 []) 0 []) := by
    rw [hlk']
    refine lkRels_congr (cstK U) _ _ 20 0 _ (fun l hl t ht => ?_) (fun i _ => ?_)
    · have h5 := lksF_pos U c d 5 q0 le_rfl _ 0 [] l hl t ht
      obtain ⟨j, hj⟩ : ∃ j, t.2 = j + 5 := ⟨t.2 - 5, by omega⟩
      rw [hj]
      simp only [List.getD_cons_succ]
    · rw [show 20 + (0 + i) = (15 + i) + 5 by omega]
      simp only [List.getD_cons_succ]
  set rels := lkRels (cstK U) (0 :: 0 :: 0 :: 0 :: 0 :: zcPl U c P D d q0 hf b) 20 0
    (lksF U c (fun p => 5 + (p - q0)) d (histOf bga.1 bga.2.1 bga.2.2 []) 0 []) with hrels
  have hlen : rels.length = 7 := by
    rw [hrels, lkRels_length, lksF_length, hlk]
  have hxc : ∀ κ, xcZc U c P D d q0 hf bga κ b = (0 :: 0 :: 0 :: 0 :: rels).getD κ 0 := fun κ => rfl
  rw [logupSem_eq_wsum, hcg, gV_none, one_mul, wsum_eq_sum,
    Fin.sum_univ_eq_sum_range (fun i => mu.getD (4 + (0 + i)) 0 * rels.getD i 0) rels.length, hlen,
    Fin.sum_univ_eq_sum_range (fun κ => mu.getD κ 0 * (if κ < 4 then [c0, c1, c2, c3].getD κ 0
      else xcZc U c P D d q0 hf bga κ b)) 11]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add, hxc, batchV, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, add_zero]
  norm_num
  ring

end Xc

/-! ## The cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **R13 `qzc`'s IR read in the field**, on the slot's draws `μ 0 … 10`, `ν 11, 12`, no pad term. -/
theorem zc_irEval (c : W16Cfg) (Rr : QzcR13) (rope s1 s2 : ℕ) (shaped : ℕ → ℕ) (d : Dom) (s : ℕ) (hist : Hist)
    (dr : List Fp2) (v : List K) :
    irEval (((r13QzcIr DefW16.cstS Rr rope s1 s2 (DefR13.lksS c shaped d) (drs s 0 11) (drs s 11 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist s dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 Rr.gate Rr.gate (((drs s 11 2).map (Sym.eval hist s dr)).map (Fp2.toK U))
          (logupSem (cstK U) v Rr.h0
              (fun k => (((drs s 0 11).map (Sym.eval hist s dr)).map (Fp2.toK U)).getD (4 + k) 0) 0
              (lksF U c shaped d hist s dr)
            + gV v Rr.gate * batchV (((drs s 0 11).map (Sym.eval hist s dr)).map (Fp2.toK U))
              (r13QzcClauses (cstK U) Rr rope v))
          (reqV8 (cstK U) v s1 Rr.src Rr.r1) (reqV8 (cstK U) v s2 Rr.oth Rr.r2) := by
  rw [r13QzcIr_map, r13QzcIr_map, cstS_map, r13QzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

/-- **A RoPE zero-check's cube sum**: `Σ_t hostPoly(τ, Z, ν, (p1, p2), 1, (host₁, host₂))(t)`, with `Z` the IR's batch
at the value list `zcV t`. -/
theorem zc_cube (c : W16Cfg) (d : Dom) (s q0 hfi : ℕ) (p1 p2 : List Sym) (Rr : QzcR13) (hg : Rr.gate = none)
    (rope s1 s2 : ℕ) (shaped : ℕ → ℕ) (aB hB ioIn ioOut ak hk : ℕ) (P : BlockParams) (D : CmData K P)
    (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h) (hpos : 0 < c.sh.logs d) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2) (h1 : p1.length = c.sh.logs d) (h2 : p2.length = c.sh.logs d) (n e : ℕ)
    (hn : n = c.sh.logs d) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((r13QzcIr DefW16.cstS Rr rope s1 s2 (DefR13.lksS c shaped d) (drs s 0 11) (drs s 11 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist s dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hfi p1 p2)).map
        (TabS.eval (Sym.eval hist s dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ t : Fin (c.sh.logs d) → Bool,
      hostPoly (fun a : Fin (c.sh.logs d) => (((drs s 13 (c.sh.logs d)).map (Sym.eval hist s dr)).getD a Fp2.zero).toK U)
        (fun t => logupSem (cstK U) (zcV U c P D d s q0 hfi p1 p2 (Sym.eval hist s dr) pub t) Rr.h0
              (fun k => (((drs s 0 11).map (Sym.eval hist s dr)).map (Fp2.toK U)).getD (4 + k) 0) 0
              (lksF U c shaped d hist s dr)
            + gV (zcV U c P D d s q0 hfi p1 p2 (Sym.eval hist s dr) pub t) none
              * batchV (((drs s 0 11).map (Sym.eval hist s dr)).map (Fp2.toK U))
                (r13QzcClauses (cstK U) Rr rope (zcV U c P D d s q0 hfi p1 p2 (Sym.eval hist s dr) pub t)))
        ![(((drs s 11 2).map (Sym.eval hist s dr)).map (Fp2.toK U)).getD 0 0,
          (((drs s 11 2).map (Sym.eval hist s dr)).map (Fp2.toK U)).getD 1 0]
        ![fun a : Fin (c.sh.logs d) => ((p1.map (Sym.eval hist s dr)).getD a Fp2.zero).toK U,
          fun a : Fin (c.sh.logs d) => ((p2.map (Sym.eval hist s dr)).getD a Fp2.zero).toK U]
        (fun _ => 1)
        (fun i t => if i = 0 then reqV8 (cstK U) (zcV U c P D d s q0 hfi p1 p2 (Sym.eval hist s dr) pub t) s1 Rr.src Rr.r1
          else reqV8 (cstK U) (zcV U c P D d s q0 hfi p1 p2 (Sym.eval hist s dr) pub t) s2 Rr.oth Rr.r2) t := by
  subst hn
  set ev := Sym.eval hist s dr with hev
  rw [cubeSum_host (c.sh.logs d) e
    (fun x => ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hfi p1 p2)).map (TabS.eval ev pub)).map
      (tabK U P D (c.sh.logs d) e x)) 0 1 2 Rr.gate Rr.gate (((drs s 11 2).map ev).map (Fp2.toK U))
    (fun v => logupSem (cstK U) v Rr.h0 (fun k => (((drs s 0 11).map ev).map (Fp2.toK U)).getD (4 + k) 0) 0
        (lksF U c shaped d hist s dr)
      + gV v Rr.gate * batchV (((drs s 0 11).map ev).map (Fp2.toK U)) (r13QzcClauses (cstK U) Rr rope v))
    (fun v => reqV8 (cstK U) v s1 Rr.src Rr.r1) (fun v => reqV8 (cstK U) v s2 Rr.oth Rr.r2) f
    (fun x => by rw [hf x, zc_irEval U c Rr rope s1 s2 shaped d s hist dr])
    (fun b y hy => zc_off U c d s q0 hfi p1 p2 aB hB ioIn ioOut ak hk P D e ev pub b y hy)
    (fun a : Fin (c.sh.logs d) => (((drs s 13 (c.sh.logs d)).map ev).getD a Fp2.zero).toK U)
    ![fun a : Fin (c.sh.logs d) => ((p1.map ev).getD a Fp2.zero).toK U,
      fun a : Fin (c.sh.logs d) => ((p2.map ev).getD a Fp2.zero).toK U]
    (fun b => by rw [zc_vals U c d s q0 hfi p1 p2 aB hB ioIn ioOut ak hk P D hrlA hrlH hpos e b ev pub h1 h2]; rfl)
    (fun b => by rw [zc_vals U c d s q0 hfi p1 p2 aB hB ioIn ioOut ak hk P D hrlA hrlH hpos e b ev pub h1 h2]; rfl)
    (fun b => by rw [zc_vals U c d s q0 hfi p1 p2 aB hB ioIn ioOut ak hk P D hrlA hrlH hpos e b ev pub h1 h2]; rfl)]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv := zc_vals U c d s q0 hfi p1 p2 aB hB ioIn ioOut ak hk P D hrlA hrlH hpos e t ev pub h1 h2
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ (fun i => ?_)
  · show logupSem (cstK U) (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hfi p1 p2)).map
        (TabS.eval ev pub)).map (tabK U P D (c.sh.logs d) e (cpt (c.sh.logs d) e t))) Rr.h0 _ 0 _
        + gV (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (zcTabs c s d q0 hfi p1 p2)).map
          (TabS.eval ev pub)).map (tabK U P D (c.sh.logs d) e (cpt (c.sh.logs d) e t))) Rr.gate * _ = _
    rw [hv, hg]
  · rw [hg]
    by_cases h : i = 0
    · rw [ite_eq_left h, ite_eq_left h, hv, gV_none, one_mul]
    · rw [ite_eq_right h, ite_eq_right h, hv, gV_none, one_mul]

end Cube

end ZK60.Exec.Block.Join.R13H.Qkv
