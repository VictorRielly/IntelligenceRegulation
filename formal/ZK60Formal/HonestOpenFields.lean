/-
D63 Lean lane L32 (2026-11-09), part 1: **the honest openings in lane L9's wire types, and the completeness of the
`BlockParams` fields and of the stages' opening checks** on them.

L9's block verifier and L29's stage verifiers take the opening checks as fields on L9's wire types
(`Block.OpeningZk`, `Block.MaskOpening`, `Block.ZClaim`, `Block.MaskFunctional`): `pcsField` (W16R2), `pcsFieldR13`
(R13, the media app's blocks), `StageV.pcsAt` (a stage's commitments: `A`, `H`, the token endpoint, `B`) and
`maskField` (`M`, every profile). Each is L10's executable verifier with the code's messages. Here:
* `ofOZ`, `ofMO`: this lane's honest openings in L9's wire types (`toOZ_ofOZ`, `toMO_ofMO`: read back unchanged);
* **`bOpen`**, **`bMask`**: the honest opening provers on L9's types, the shape L25's `CoreData.aOpen` / `hOpen` /
  `mOpen` and `D12aBlockP.inOpen` take;
* **`pcsAt_of_prove`**, **`pcsField_of_prove`**, **`pcsFieldR13_of_prove`**, **`maskField_of_prove`**: each field
  ACCEPTS the honest opening and returns the prover's transcript, at every hash function and from every transcript:
  the contracts `hM`, `hA`, `hH` of L25's `blockVerify_of_prove` and of L29's `incVerify_of_prove` /
  `outcVerify_of_prove`, for honest tables and true claims / functionals;
* **`bOpen_canon`**, **`bOpen_shape`**, **`bOpen_pathsDepth`**, **`bMask_canon`**, **`bMask_shape`**,
  **`bMask_pathsDepth`**: the honest openings' words are canonical, their counts and lengths are the geometry's, and
  their paths have the tree's depth (the codec contract's `HidingCanon` / `MaskCanon`, the opening parts of
  `CoreShape`, and the `pathsDepth` pre-checks, T-4).
-/
import ZK60Formal.HonestOpenM
import ZK60Formal.OpeningR13
import ZK60Formal.StageVerifyExec

set_option autoImplicit false

namespace ZK60.HonestOpen

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## This lane's openings in L9's wire types -/

section Wire

def ofOCol (c : OCol) : Block.Column := ⟨c.1, c.2.1, c.2.2.1, c.2.2.2⟩

def ofOZ (o : OpeningZk) : Block.OpeningZk := ⟨o.groupVecs, o.proxVec, o.columns.map ofOCol⟩

def ofMO (o : MaskOpening) : Block.MaskOpening := ⟨o.q, o.prox, o.columns.map ofOCol⟩

theorem map_toOCol_ofOCol : ∀ cols : List OCol, (cols.map ofOCol).map toOCol = cols
  | [] => rfl
  | c :: cs => congrArg (List.cons c) (map_toOCol_ofOCol cs)

theorem toOZ_ofOZ (o : OpeningZk) : toOZ (ofOZ o) = o := by
  cases o with
  | mk gv pv cols => exact congrArg (OpeningZk.mk gv pv) (map_toOCol_ofOCol cols)

theorem toMO_ofMO (o : MaskOpening) : toMO (ofMO o) = o := by
  cases o with
  | mk q pr cols => exact congrArg (MaskOpening.mk q pr) (map_toOCol_ofOCol cols)

/-- The paths of the wire columns have the tree's depth when the opening's do. -/
theorem pathsDepth_ofOCol (what : String) (depth : ℕ) : ∀ (cols : List OCol) (i : ℕ),
    (∀ c ∈ cols, c.2.2.2.length = depth) → Block.pathsDepth what depth i (cols.map ofOCol) = .ok ()
  | [], _, _ => rfl
  | c :: cs, i, h => by
    have hc : (ofOCol c).path.length = depth := h c List.mem_cons_self
    have ih := pathsDepth_ofOCol what depth cs (i + 1) (fun c' hc' => h c' (List.mem_cons_of_mem _ hc'))
    rw [List.map_cons, Block.pathsDepth, ite_eq_right (not_not.mpr hc)]
    exact ih

end Wire

/-! ## The honest opening provers on L9's types -/

section Provers

variable (H : HIn → Dig) (tag : MTag)

/-- **The honest opening of one commitment on L9's types** (`pcs::open_zk`). -/
def bOpen (prm : PcsPrm) (depth : ℕ) (T : Table) (cl : List Block.ZClaim) (t : Tr) : Block.OpeningZk × Tr :=
  (ofOZ (pcsProve H tag prm depth T (cl.map toZClaim) t).1, (pcsProve H tag prm depth T (cl.map toZClaim) t).2)

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **The honest opening of `M` on L9's types** (`zk::mask_open`, the code's roots of orders `512` and `4096`). -/
noncomputable def bMask (M : MTable) (S : ℕ) (fs : List Block.MaskFunctional) (t : Tr) : Block.MaskOpening × Tr :=
  (ofMO (maskProve H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t).1,
    (maskProve H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t).2)

/-- **The interpolant row form on `G_{2^logN}` over `K`**, with the code's root. -/
noncomputable def lagK (logN : ℕ) (h : logN ≤ 32) : RowForm K (2 ^ logN) :=
  lagForm (Nat.two_pow_pos logN) ((rootFp_isPrimitiveRoot h).map_of_injective (algebraMap GF K).injective)

/-- The column evaluator of a commitment of row width `2^logN` and rate `2^-lr` meets L10's specification. -/
theorem colEnc_spec_at (logN lr q : ℕ) (hk : logN + lr ≤ 31) :
    ColEncSpec U (lagK logN (by omega)) q (cosetPt (rootFp (logN + lr))) (colEncLag (rootFp logN) (2 ^ logN) q) :=
  colEncLag_spec U (Nat.two_pow_pos logN) (Nat.pow_lt_pow_right (by norm_num) (by omega))
    (pow_dvd_pow 2 (Nat.le_add_right logN lr)) rfl hk _ _ (rootFp_isPrimitiveRoot (by omega))
    (rootFp_isPrimitiveRoot (by omega))

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **A stage's opening check accepts the honest opening** (`StageV.pcsAt`: `A`, `H`, the token endpoint and `B` of
stages IN-C and OUT-C), for an honest table and true claims. -/
theorem pcsAt_of_prove (logN lr q : ℕ) (hk : logN + lr ≤ 31) (hq : 0 < q) (T : Table)
    (hcols : ColsHonest U (lagK logN (by omega)) q (cosetPt (rootFp (logN + lr))) (2 ^ logN * 2 ^ lr) T)
    (cl : List Block.ZClaim) (htrue : ∀ c ∈ cl, ClaimTrue U (2 ^ logN) logN T.rows (toZClaim c)) (t : Tr) :
    StageV.pcsAt tag logN lr q H (rootOf H tag (logN + lr) T) T.rows.length cl
        (bOpen H tag ⟨logN, 2 ^ lr, q, q⟩ (logN + lr) T cl t).1 t
      = .ok (bOpen H tag ⟨logN, 2 ^ lr, q, q⟩ (logN + lr) T cl t).2 := by
  show mapErr _ (ZK60.Exec.pcsVerify H tag ⟨logN, 2 ^ lr, q, q⟩ (cosetPt (rootFp (logN + lr)))
      (colEncLag (rootFp logN) (2 ^ logN) q) (rootOf H tag (logN + lr) T) T.rows.length logN (cl.map toZClaim)
      (toOZ (ofOZ (pcsProve H tag ⟨logN, 2 ^ lr, q, q⟩ (logN + lr) T (cl.map toZClaim) t).1)) t)
    = .ok (pcsProve H tag ⟨logN, 2 ^ lr, q, q⟩ (logN + lr) T (cl.map toZClaim) t).2
  rw [mapErr_ok, toOZ_ofOZ]
  exact pcsVerify_of_prove H tag U hU ⟨logN, 2 ^ lr, q, q⟩ _ _ (fun x vs => by simp [colEncLag])
    (lagK logN (by omega)) (colEnc_spec_at U logN lr q hk) (logN + lr) (pow_add 2 logN lr).symm hq le_rfl T hcols
    (cl.map toZClaim) (fun c hc => by
      obtain ⟨c', hc', rfl⟩ := List.mem_map.mp hc
      exact htrue c' hc') t

include hU in
/-- **`BlockParams.pcsVerify` at W16R2 accepts the honest opening** (L10's `pcsField`: `log_cols 14`, rate `1/2`,
`Q = 280`). -/
theorem pcsField_of_prove (rowsOf : Block.Cm → ℕ) (cm : Block.Cm) (T : Table) (hrows : rowsOf cm = T.rows.length)
    (hcols : ColsHonest U (lagK 14 (by norm_num)) 280 (cosetPt (rootFp 15)) (2 ^ 15) T) (cl : List Block.ZClaim)
    (htrue : ∀ c ∈ cl, ClaimTrue U (2 ^ 14) 14 T.rows (toZClaim c)) (t : Tr) :
    pcsField tag rowsOf H cm (rootOf H tag 15 T) cl (bOpen H tag w16r2Prm 15 T cl t).1 t
      = .ok (bOpen H tag w16r2Prm 15 T cl t).2 := by
  show mapErr _ (ZK60.Exec.pcsVerify H tag w16r2Prm (cosetPt (rootFp 15)) (colEncLag (rootFp 14) (2 ^ 14) 280)
      (rootOf H tag 15 T) (rowsOf cm) 14 (cl.map toZClaim)
      (toOZ (ofOZ (pcsProve H tag w16r2Prm 15 T (cl.map toZClaim) t).1)) t)
    = .ok (pcsProve H tag w16r2Prm 15 T (cl.map toZClaim) t).2
  rw [mapErr_ok, toOZ_ofOZ, hrows]
  exact pcsVerify_of_prove H tag U hU w16r2Prm _ _ w16r2_colEnc_length (lagK 14 (by norm_num)) (w16r2_colEnc_spec U)
    15 (by norm_num [PcsPrm.nn, w16r2Prm]) (by norm_num [w16r2Prm]) le_rfl T hcols (cl.map toZClaim) (fun c hc => by
      obtain ⟨c', hc', rfl⟩ := List.mem_map.mp hc
      exact htrue c' hc') t

include hU in
/-- **`BlockParams.pcsVerify` at R13 accepts the honest opening** (L17's `pcsFieldR13`, the media app's blocks:
`log_cols 14`, rate `1/4`, `Q = 256`). -/
theorem pcsFieldR13_of_prove (rowsOf : Block.Cm → ℕ) (cm : Block.Cm) (T : Table)
    (hrows : rowsOf cm = T.rows.length)
    (hcols : ColsHonest U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) T) (cl : List Block.ZClaim)
    (htrue : ∀ c ∈ cl, ClaimTrue U (2 ^ 14) 14 T.rows (toZClaim c)) (t : Tr) :
    R13.pcsFieldR13 tag rowsOf H cm (rootOf H tag 16 T) cl (bOpen H tag R13.r13Prm 16 T cl t).1 t
      = .ok (bOpen H tag R13.r13Prm 16 T cl t).2 := by
  show mapErr _ (ZK60.Exec.pcsVerify H tag R13.r13Prm (cosetPt (rootFp 16)) (colEncLag (rootFp 14) (2 ^ 14) 256)
      (rootOf H tag 16 T) (rowsOf cm) 14 (cl.map toZClaim)
      (toOZ (ofOZ (pcsProve H tag R13.r13Prm 16 T (cl.map toZClaim) t).1)) t)
    = .ok (pcsProve H tag R13.r13Prm 16 T (cl.map toZClaim) t).2
  rw [mapErr_ok, toOZ_ofOZ, hrows]
  exact pcsVerify_of_prove H tag U hU R13.r13Prm _ _ R13.r13_colEnc_length (lagK 14 (by norm_num))
    (R13.r13_colEnc_spec U) 16 R13.r13Prm_nn (by norm_num [R13.r13Prm]) le_rfl T hcols (cl.map toZClaim)
    (fun c hc => by
      obtain ⟨c', hc', rfl⟩ := List.mem_map.mp hc
      exact htrue c' hc') t

include hU in
/-- **`BlockParams.maskVerify` accepts the honest `M` opening** (L10's `maskField`, every profile), for honest rows
and functionals TRUE of the masks. -/
theorem maskField_of_prove (M : MTable) (S : ℕ) (hM : MHonest U (algebraMap GF K (rootFp 9).toGF) M S)
    (fs : List Block.MaskFunctional)
    (htrue : ∀ i : Fin (fs.map toMF).length, ((fs.map toMF).get i).value.toK U
      = mTrue (algebraMap GF K (rootFp 9).toGF) (wtOf U (fs.map toMF) S) (mA U M S) i) (t : Tr) :
    maskField tag S H (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) M)) fs (bMask H tag U hbij M S fs t).1 t
      = .ok (bMask H tag U hbij M S fs t).2 := by
  show mapErr _ (maskVerify H tag (rootFp 9) (rootFp 12) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) M)) S
      (fs.map toMF) (toMO (ofMO (maskProve H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t).1)) t)
    = .ok (maskProve H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t).2
  rw [mapErr_ok, toMO_ofMO]
  exact maskVerify_of_prove H tag U hbij (rootFp 9) (rootFp 12) hU
    (show IsPrimitiveRoot (rootFp 9).toGF 512 from rootFp_isPrimitiveRoot (by norm_num))
    (show IsPrimitiveRoot (rootFp 12).toGF 4096 from rootFp_isPrimitiveRoot (by norm_num)) M S hM (fs.map toMF)
    htrue t

end Provers

/-! ## Canonical words, shapes and path depths of the honest openings -/

section Shapes

variable (H : HIn → Dig) (tag : MTag)

/-- **The honest opening's words are canonical** (`HidingCanon`, the codec contract), for canonical columns. -/
theorem bOpen_canon (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon) (cl : List Block.ZClaim) (t : Tr) :
    Block.HidingCanon (bOpen H tag prm depth T cl t).1 := by
  obtain ⟨h1, h2, h3⟩ := pcsProve_canon H tag prm depth hnn hnQ T hcan (cl.map toZClaim) t
  refine ⟨h1, h2, fun c hc => ?_⟩
  obtain ⟨c', hc', rfl⟩ := List.mem_map.mp hc
  exact h3 c' hc'

/-- **The honest opening's shape** (the opening parts of `CoreShape` / `HidingShape`): the group count is the claims',
every clear vector has `n + Q` words, there are `Q` columns, each at an index below `nn`, of `rows` words, with a path
of the tree's depth. -/
theorem bOpen_shape (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table)
    (hlen : ∀ j, (T.cols j).length = T.rows.length) (cl : List Block.ZClaim) (t : Tr) :
    (bOpen H tag prm depth T cl t).1.groupVecs.length
        = (groupZclaims (cl.map toZClaim) T.rows.length prm.logCols).length
      ∧ (∀ v ∈ (bOpen H tag prm depth T cl t).1.groupVecs, v.length = prm.n + prm.qPad)
      ∧ (bOpen H tag prm depth T cl t).1.proxVec.length = prm.n + prm.qPad
      ∧ (bOpen H tag prm depth T cl t).1.columns.length = prm.nQ
      ∧ ∀ c ∈ (bOpen H tag prm depth T cl t).1.columns,
          c.j < prm.nn ∧ c.col.length = T.rows.length ∧ c.path.length = depth := by
  obtain ⟨h1, h2, h3, h4, h5⟩ := pcsProve_shape H tag prm depth hnn hnQ T (cl.map toZClaim) t
  refine ⟨h1, h2, h3, ?_, fun c hc => ?_⟩
  · show ((pcsProve H tag prm depth T (cl.map toZClaim) t).1.columns.map ofOCol).length = prm.nQ
    rw [List.length_map, h4]
  · obtain ⟨c', hc', rfl⟩ := List.mem_map.mp hc
    obtain ⟨a1, a2, a3⟩ := h5 c' hc'
    refine ⟨a1, ?_, a3⟩
    show c'.2.1.length = T.rows.length
    rw [a2]
    exact hlen _

/-- **The honest opening's paths pass the depth pre-check** (`pathsDepth`, D19 T-4). -/
theorem bOpen_pathsDepth (what : String) (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (T : Table) (cl : List Block.ZClaim) (t : Tr) (i : ℕ) :
    Block.pathsDepth what depth i (bOpen H tag prm depth T cl t).1.columns = .ok () :=
  pathsDepth_ofOCol what depth _ i
    (fun c hc => ((pcsProve_shape H tag prm depth hnn hnQ T (cl.map toZClaim) t).2.2.2.2 c hc).2.2)

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- The wire form of an `M` opening has canonical words when the opening has. -/
theorem ofMO_canon (o : MaskOpening) (hq : ∀ x ∈ o.q, x.Canon) (hp : ∀ x ∈ o.prox, x.Canon)
    (hc : ∀ c ∈ o.columns, ∀ x ∈ c.2.1, x.Canon) : Block.MaskCanon (ofMO o) := by
  refine ⟨hq, hp, fun c hc' => ?_⟩
  obtain ⟨c', hc'', rfl⟩ := List.mem_map.mp hc'
  exact hc c' hc''

/-- The wire form of an `M` opening has the opening's shape. -/
theorem ofMO_shape (o : MaskOpening) (n k d r p : ℕ) (hq : o.q.length = n) (hp : o.prox.length = n)
    (hk : o.columns.length = k) (hc : ∀ c ∈ o.columns, c.1 < d ∧ c.2.1.length = r ∧ c.2.2.2.length = p) :
    (ofMO o).q.length = n ∧ (ofMO o).prox.length = n ∧ (ofMO o).columns.length = k
      ∧ ∀ c ∈ (ofMO o).columns, c.j < d ∧ c.col.length = r ∧ c.path.length = p := by
  refine ⟨hq, hp, ?_, fun c hc' => ?_⟩
  · show (o.columns.map ofOCol).length = k
    rw [List.length_map, hk]
  · obtain ⟨c', hc'', rfl⟩ := List.mem_map.mp hc'
    exact hc c' hc''

/-- The honest `M` opening on L9's types is the wire form of this lane's. -/
theorem bMask_fst (M : MTable) (S : ℕ) (fs : List Block.MaskFunctional) (t : Tr) :
    (bMask H tag U hbij M S fs t).1
      = ofMO (maskProve H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t).1 := rfl

/-- **The honest `M` opening's words are canonical** (`MaskCanon`). -/
theorem bMask_canon (M : MTable) (S : ℕ) (fs : List Block.MaskFunctional) (t : Tr) :
    Block.MaskCanon (bMask H tag U hbij M S fs t).1 := by
  obtain ⟨-, h2, -, h4, -, h6⟩ := maskProve_shape H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t
  rw [bMask_fst]
  exact ofMO_canon _ h2 h4 (fun c hc => (h6 c hc).2.2.1)

/-- **The honest `M` opening's shape** (`CoreShape`'s mask part): `1024` words each for `q'` and the proximity vector,
`256` columns, each at an index below `4096`, of `2S + 4` words, with a path of `12` digests. -/
theorem bMask_shape (M : MTable) (S : ℕ) (fs : List Block.MaskFunctional) (t : Tr) :
    (bMask H tag U hbij M S fs t).1.q.length = 2 * mMsg
      ∧ (bMask H tag U hbij M S fs t).1.prox.length = 2 * mMsg
      ∧ (bMask H tag U hbij M S fs t).1.columns.length = mQ
      ∧ ∀ c ∈ (bMask H tag U hbij M S fs t).1.columns,
          c.j < mDom ∧ c.col.length = 2 * S + 4 ∧ c.path.length = 12 := by
  obtain ⟨h1, -, h3, -, h5, h6⟩ := maskProve_shape H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t
  rw [bMask_fst]
  exact ofMO_shape _ (2 * mMsg) mQ mDom (2 * S + 4) 12 h1 h3 h5
    (fun c hc => ⟨(h6 c hc).1, (h6 c hc).2.1, (h6 c hc).2.2.2⟩)

/-- **The honest `M` opening's paths pass the depth pre-check** (`pathsDepth "M"`, depth `12`). -/
theorem bMask_pathsDepth (what : String) (M : MTable) (S : ℕ) (fs : List Block.MaskFunctional) (t : Tr) (i : ℕ) :
    Block.pathsDepth what 12 i (bMask H tag U hbij M S fs t).1.columns = .ok () := by
  obtain ⟨-, -, -, -, -, h6⟩ := maskProve_shape H tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t
  rw [bMask_fst]
  exact pathsDepth_ofOCol what 12 _ i (fun c hc => (h6 c hc).2.2.2)

end Shapes

end ZK60.HonestOpen
