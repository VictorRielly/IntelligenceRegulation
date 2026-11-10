/-
D63 lane L45 (2026-11-10), part 4: **the run's OWN Merkle work, and the extraction from `EvXR`** (finding L43-2,
audit GA-8; L30 §5.2).

The top theorem's Merkle event `EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G` (L27) speaks of the
chain `C`, the blocks' cores `coreOf`, the rest of the run's Merkle work `Vx` and the rest of its roots `rx`; all four
were free parameters. With them free the extraction facts `RhXOk`, `RhXMOk` (L43) could not be derived: a lucky Merkle
collision at a commitment `EvXR` does not watch falsifies them (GA-8). Here they are set to the run's OWN:

* `C := chainEncB key domain hs Lq hL` (the code's chain, as `rkData`'s extractions use);
* `rxCoreOf`: block `k`'s core is the core of segment `k + 1` read off the receipt alone (L34's `rtSegOf`);
* `rxVx`: the verifier's Merkle checks of EVERY other opening of the run: stage IN-C's `A`, `H`, `M` and the input
  token endpoint's opening, stage OUT-C's `A`, `H`, `M` and `B_out`'s, and every block's boundary opening (the closing
  `X` openings: the endpoint's column checks are in, as the gap audit and L30 §5.2 ask); each opened column (the first
  `256` of each opening that fit `Lq` and have paths of at most `64` entries) checked at its own path's depth;
* `rxRoots`: the stages' roots, `B_in`'s, every block's boundary root, and the statement's input root.

Numbers: `rxVx` is within `34·256·66 = 574,464` queries (`≤ 3,800,000`, L27's allowance) and `rxRoots` lists at most
`35` roots (`≤ 2^99`): PROVED (`rxVx_bounded`, `rxRoots_length`).

The extraction, from `¬ EvXR`:
* **`rx_xok`**: an opening's extraction `RhXOk` at a header absorbing its root at the geometry's position, when the root
  is one of the run's and every sampled column is checked by the run verifier's Merkle work;
* **`rx_xmok`**: `M`'s extraction `RhXMOk`, from the verifier's own `MaskOk` (which fixes the sampled indices and
  checks every sampled column's path);
* `rx_q_blkA`, `rx_q_blkH`, `rx_q_blkM`: block `k`'s openings' columns are checked by block `k`'s Merkle work
  (`blockV` at L27's numbers `256, 256, 256, 16, 16, 12`); `rx_q_work`: any opening listed in `rxOpenings` is checked
  by `rxVx`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStageRdHal
import ZK60Formal.RunChainExtract

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

/-! ## Checking an opening's columns at their own depths -/

section Work

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L)

/-- **An opening's columns as openings of the encoding**: the first `256` opened columns that fit `L` and whose paths
have at most `64` entries. -/
noncomputable def rxCols (cs : List Block.Column) : List (ℕ × MerkleOpening Dig Dig (ColV L)) :=
  (cs.take 256).filterMap (fun c =>
    haveI := Classical.propDecidable (8 * c.col.length ≤ L ∧ c.path.length ≤ 64)
    if h : 8 * c.col.length ≤ L ∧ c.path.length ≤ 64 then some (c.j, ⟨⟨c.col, h.1⟩, c.salt, c.path⟩) else none)

theorem rxCols_length (cs : List Block.Column) : (rxCols L cs).length ≤ 256 :=
  (List.length_filterMap_le _ _).trans (List.length_take_le _ _)

theorem rxCols_path (cs : List Block.Column) : ∀ jo ∈ rxCols L cs, jo.2.path.length ≤ 64 := by
  intro jo hjo
  obtain ⟨c, -, hc⟩ := List.mem_filterMap.mp hjo
  by_cases h : 8 * c.col.length ≤ L ∧ c.path.length ≤ 64
  · rw [dite_eq_left h] at hc
    cases hc
    exact h.2
  · rw [dite_eq_right h] at hc
    cases hc

/-- **Column `k` of an opening is listed** when `k < 256`, it fits and its path has at most `64` entries. -/
theorem mem_rxCols (cs : List Block.Column) (k : ℕ) (hk : k < 256) (hkl : k < cs.length)
    (hfit : 8 * (cs.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L)
    (hp : (cs.getD k ⟨0, [], zeroDig, []⟩).path.length ≤ 64) :
    ((cs.getD k ⟨0, [], zeroDig, []⟩).j,
      (⟨⟨(cs.getD k ⟨0, [], zeroDig, []⟩).col, hfit⟩, (cs.getD k ⟨0, [], zeroDig, []⟩).salt,
        (cs.getD k ⟨0, [], zeroDig, []⟩).path⟩ : MerkleOpening Dig Dig (ColV L))) ∈ rxCols L cs := by
  unfold rxCols
  refine List.mem_filterMap.mpr ⟨cs.getD k ⟨0, [], zeroDig, []⟩, ?_, ?_⟩
  · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hkl, Option.getD_some]
    exact List.mem_iff_getElem.mpr ⟨k, by rw [List.length_take]; omega, by rw [List.getElem_take]⟩
  · rw [dite_eq_left ⟨hfit, hp⟩]

/-- **The verifier's hashing for a list of openings, each at its own path's depth.** -/
noncomputable def rxCheck : List (ℕ × MerkleOpening Dig Dig (ColV L)) → OC (QB L) Dig Unit
  | [] => .ret ()
  | jo :: rest => ((merkleEncV tag L h64).checkOC jo.2.path.length jo.1 jo.2).bind (fun _ => rxCheck rest)

theorem rxCheck_bounded : ∀ (l : List (ℕ × MerkleOpening Dig Dig (ColV L))), (∀ jo ∈ l, jo.2.path.length ≤ 64) →
    (rxCheck tag L h64 l).Bounded (l.length * 66)
  | [], _ => trivial
  | jo :: rest, h => by
    have hb := ((merkleEncV tag L h64).checkOC_bounded jo.2.path.length jo.1 jo.2).bind
      (fun _ => rxCheck_bounded rest (fun jo' hj => h jo' (List.mem_cons_of_mem _ hj)))
    refine hb.mono ?_
    have h0 := h jo List.mem_cons_self
    simp only [List.length_cons]
    omega

theorem rxCheck_queries (G : QB L → Dig) : ∀ (l : List (ℕ × MerkleOpening Dig Dig (ColV L)))
    (jo : ℕ × MerkleOpening Dig Dig (ColV L)), jo ∈ l →
    ∀ v ∈ (merkleEncV tag L h64).openQs G jo.1 jo.2, v ∈ OC.queries G (rxCheck tag L h64 l)
  | [], _, hjo => by simp at hjo
  | jo' :: rest, jo, hjo => by
    intro v hv
    rw [rxCheck, OC.queries_bind]
    rcases List.mem_cons.mp hjo with rfl | hjo
    · rw [(merkleEncV tag L h64).checkOC_queries G rfl]
      exact List.mem_append_left _ hv
    · exact List.mem_append_right _ (rxCheck_queries G rest jo hjo v hv)

/-- **The verifier's Merkle work on a list of openings' columns.** -/
noncomputable def rxWork : List (List Block.Column) → OC (QB L) Dig Unit
  | [] => .ret ()
  | cs :: rest => (rxCheck tag L h64 (rxCols L cs)).bind (fun _ => rxWork rest)

theorem rxWork_bounded : ∀ (ls : List (List Block.Column)), (rxWork tag L h64 ls).Bounded (ls.length * (256 * 66))
  | [] => trivial
  | cs :: rest => by
    have h1 := (rxCheck_bounded tag L h64 (rxCols L cs) (rxCols_path L cs)).mono
      (Nat.mul_le_mul_right 66 (rxCols_length L cs))
    have hb := h1.bind (fun _ => rxWork_bounded rest)
    refine hb.mono (le_of_eq ?_)
    simp only [List.length_cons]
    ring

theorem rxWork_queries (G : QB L → Dig) : ∀ (ls : List (List Block.Column)) (cs : List Block.Column), cs ∈ ls →
    ∀ jo ∈ rxCols L cs, ∀ v ∈ (merkleEncV tag L h64).openQs G jo.1 jo.2, v ∈ OC.queries G (rxWork tag L h64 ls)
  | [], _, hcs => by simp at hcs
  | cs' :: rest, cs, hcs => by
    intro jo hjo v hv
    rw [rxWork, OC.queries_bind]
    rcases List.mem_cons.mp hcs with rfl | hcs
    · exact List.mem_append_left _ (rxCheck_queries tag L h64 G _ jo hjo v hv)
    · exact List.mem_append_right _ (rxWork_queries G rest cs hcs jo hjo v hv)

end Work

/-! ## The run's own Merkle work and roots -/

section Own

variable {Hdr : Type}

/-- A core with nothing in it (for a segment that does not decode). -/
def rxCore0 : Block.Core := ⟨zeroDig, zeroDig, zeroDig, [], ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩⟩

/-- **Block `k`'s segment read off the receipt alone** (segment `k + 1`, L34's `rtSegOf`). -/
def rxBlkSeg (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (o : ClsStmt Hdr × ClsReceipt) (k : ℕ) :
    Option Block.Segment :=
  rtSegOf (sgeom o.1 k) (o.2.getD (k + 1) [])

/-- **The blocks' cores of the run** (`EvXR`'s `coreOf`): block `k`'s is the core of its segment read off the
receipt. -/
def rxCoreOf (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (o : ClsStmt Hdr × ClsReceipt) (k : ℕ) :
    List Op × Block.Core :=
  ([], ((rxBlkSeg sgeom o k).map Block.Segment.core).getD rxCore0)

/-- Stage IN-C's segment read off the receipt (segment `0`). -/
def rxInSeg (incG : Hdr → StageGeom) (o : ClsStmt Hdr × ClsReceipt) : Option StageSeg :=
  rtStageOf (incG o.1.hdr) (o.2.getD 0 [])

/-- Stage OUT-C's segment read off the receipt (segment `Lb + 1`). -/
def rxOutSeg (outcG : Hdr → StageGeom) (Lb : ℕ) (o : ClsStmt Hdr × ClsReceipt) : Option StageSeg :=
  rtStageOf (outcG o.1.hdr) (o.2.getD (Lb + 1) [])

/-- A stage's four openings' columns: `A`, `H`, `M` and the commitment it closes. -/
def rxStCols : Option StageSeg → List (List Block.Column)
  | some seg => [seg.core.aOpen.columns, seg.core.hOpen.columns, seg.core.maskOpen.columns,
      (seg.closes.headD IncV.ozk0).columns]
  | none => [[], [], [], []]

/-- A stage's roots: `A`, `H`, `M` and the boundary root it commits (`B_in` for IN-C). -/
def rxStRoots : Option StageSeg → List Dig
  | some seg => [seg.core.aRoot, seg.core.hRoot, seg.core.maskRoot, seg.bRoot.getD zeroDig]
  | none => []

/-- **The openings the run's other Merkle work checks**: the two stages' four each, every block's boundary opening. -/
def rxOpenings (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (o : ClsStmt Hdr × ClsReceipt) : List (List Block.Column) :=
  rxStCols (rxInSeg incG o) ++ rxStCols (rxOutSeg outcG Lb o)
    ++ (List.range 26).map (fun k => ((rxBlkSeg sgeom o k).map (fun sg => sg.inOpen.columns)).getD [])

/-- **THE RUN'S OTHER MERKLE WORK** (`EvXR`'s `Vx`): the verifier's checks of every opening `rxOpenings` lists. -/
noncomputable def rxVx (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (incG outcG : Hdr → StageGeom)
    (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ) (o : ClsStmt Hdr × ClsReceipt) : OC (QB L) Dig Unit :=
  rxWork tag L h64 (rxOpenings incG outcG sgeom Lb o)

/-- **THE RUN'S OTHER ROOTS** (`EvXR`'s `rx`): the stages', every block's boundary root, the input root. -/
def rxRoots (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (o : ClsStmt Hdr × ClsReceipt) : List Dig :=
  rxStRoots (rxInSeg incG o) ++ rxStRoots (rxOutSeg outcG Lb o) ++ [o.1.inRoot]
    ++ (List.range 26).map (fun k => ((rxBlkSeg sgeom o k).bind Block.Segment.bRoot).getD zeroDig)

theorem rxStCols_length (sg : Option StageSeg) : (rxStCols sg).length = 4 := by
  cases sg <;> rfl

theorem rxStRoots_length (sg : Option StageSeg) : (rxStRoots sg).length ≤ 4 := by
  cases sg <;> simp [rxStRoots]

theorem rxOpenings_length (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (o : ClsStmt Hdr × ClsReceipt) : (rxOpenings incG outcG sgeom Lb o).length = 34 := by
  rw [rxOpenings, List.length_append, List.length_append, rxStCols_length, rxStCols_length, List.length_map,
    List.length_range]

/-- **`rxVx` is within `574,464` queries** (`34` openings of at most `256` columns, each at most `66` queries). -/
theorem rxVx_bounded (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (incG outcG : Hdr → StageGeom)
    (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ) (o : ClsStmt Hdr × ClsReceipt) :
    (rxVx tag L h64 incG outcG sgeom Lb o).Bounded 574464 := by
  have h := rxWork_bounded tag L h64 (rxOpenings incG outcG sgeom Lb o)
  rw [rxOpenings_length] at h
  exact h

/-- **`rxRoots` lists at most `35` roots.** -/
theorem rxRoots_length (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (o : ClsStmt Hdr × ClsReceipt) : (rxRoots incG outcG sgeom Lb o).length ≤ 35 := by
  have h1 := rxStRoots_length (rxInSeg incG o)
  have h2 := rxStRoots_length (rxOutSeg outcG Lb o)
  simp only [rxRoots, List.length_append, List.length_map, List.length_range, List.length_singleton]
  omega

theorem rxVx_le : (574464 : ℕ) ≤ 3800000 := by norm_num

theorem rxRoots_le : (35 : ℕ) ≤ 2 ^ 99 := by norm_num

end Own

/-! ## The extraction, from `¬ EvXR` -/

section Ext

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) {α : Type}

/-- The `k`-th opened column, as L10's tuple. -/
theorem rx_toOZ_getD (zo : Block.OpeningZk) (k : ℕ) :
    (toOZ zo).columns.getD k (0, [], zeroDig, []) = toOCol (zo.columns.getD k ⟨0, [], zeroDig, []⟩) := by
  show (zo.columns.map toOCol).getD k (toOCol ⟨0, [], zeroDig, []⟩) = _
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map]
  cases zo.columns[k]? <;> rfl

theorem rx_toMO_getD (mo : Block.MaskOpening) (k : ℕ) :
    (toMO mo).columns.getD k (0, [], zeroDig, []) = toOCol (mo.columns.getD k ⟨0, [], zeroDig, []⟩) := by
  show (mo.columns.map toOCol).getD k (toOCol ⟨0, [], zeroDig, []⟩) = _
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map]
  cases mo.columns[k]? <;> rfl

/-- **AN OPENING'S EXTRACTION FROM `¬ EvXR`** (L43's `RhXOk`): if the run's Merkle event did not happen, the opening's
root is one of the run's, the header absorbs it at the geometry's position, the rows fit `L`, and the run verifier's
Merkle work checks every sampled column, then every sampled column that verifies against the root is the column
extracted for the root the header absorbs there. -/
theorem rx_xok (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig)
    (A : OC (QB L) Dig α) (G : QB L → Dig)
    (hX : ¬ EvXR tag L h64 (chainEncB key domain hs L hL) 256 256 256 16 16 12 26 coreOf Vx rx A G)
    (g : RkGeo) (hdr : List (TItem × Dig)) (zo : Block.OpeningZk) (root : Dig)
    (hroot : root ∈ runRoots 26 coreOf rx (A.run G)) (habs : Block.absAt hdr g.ipos = some root.toList)
    (hfit : 8 * g.rows ≤ L)
    (hq : ∀ k, k < g.Q → k < zo.columns.length → (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path.length = g.h →
      ∀ (hf : 8 * (zo.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (zo.columns.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(zo.columns.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (zo.columns.getD k ⟨0, [], zeroDig, []⟩).salt,
          (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx))) :
    RhXOk tag L h64 key domain hs hL g (A.runLog G).2 G hdr zo root := by
  intro k hkQ hkl hpath hver hlen
  rw [rx_toOZ_getD] at hpath hver hlen ⊢
  set c := zo.columns.getD k ⟨0, [], zeroDig, []⟩ with hcdef
  have hpath' : c.path.length = g.h := hpath
  have hver' : verifyPath (liftH G) tag root c.j (saltLeaf (liftH G) tag (colDigest (liftH G) tag c.col) c.salt) c.path
      = true := hver
  have hlen' : c.col.length = g.rows := hlen
  have hf : 8 * c.col.length ≤ L := by rw [hlen']; exact hfit
  have hop := opensV_of_exec tag L h64 G g.h root c.j c.col hf c.salt c.path hpath' hver'
  have hext : (merkleEncV tag L h64).extractCol (cutAt (absD (chainEncB key domain hs L hL)) root (A.runLog G).2) g.h
      c.j root = some ⟨c.col, hf⟩ := by
    by_contra hne
    exact hX ⟨root, hroot, g.h, c.j, ⟨⟨c.col, hf⟩, c.salt, c.path⟩, hop, hq k hkQ hkl hpath' hf, hne⟩
  show (colX tag L h64 key domain hs hL g.h g.ipos (A.runLog G).2 hdr c.j).map Subtype.val = some c.col
  rw [colX_root tag L h64 key domain hs hL g.h g.ipos (A.runLog G).2 hdr root habs c.j, hext]
  rfl

/-- `M`'s steps before its index squeezes, as `mask_verify_tagged` runs them (L22). -/
theorem rx_mPre_tr (H : HIn → Dig) (tM : Tr) (S : ℕ) (mo : Block.MaskOpening) :
    runOps H tM (stpsOps (mPre S mo))
      = (((tM.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
          maskProxLabel mo.prox := by
  rw [stpsOps_mPre_split, runOps_append, runOps_append, challengeFp2Vec_sqDs]
  rfl

/-- **`M`'S EXTRACTION FROM `¬ EvXR`** (L43's `RhXMOk`): the verifier's `MaskOk` on `tM` fixes the sampled indices
(`idxOf` of the transcript's squeezes, as L22's `mask_subSt_of_ok` reads them) and checks every sampled column's path
(depth `12`); if the run's Merkle event did not happen, the root is the run's, the header absorbs it at `mpos`, the
columns fit and are checked by the run verifier's Merkle work, the table extracted at every sampled index is the opened
column. -/
theorem rx_xmok (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig)
    (A : OC (QB L) Dig α) (G : QB L → Dig)
    (hX : ¬ EvXR tag L h64 (chainEncB key domain hs L hL) 256 256 256 16 16 12 26 coreOf Vx rx A G)
    (S mpos : ℕ) (hdr : List (TItem × Dig)) (tM tA : Tr) (mo : Block.MaskOpening) (root : Dig)
    (fs : List MaskFunctional)
    (hok : MaskOk (liftH G) tag (rootFp 9) (rootFp 12) root S fs (toMO mo) tM tA)
    (hroot : root ∈ runRoots 26 coreOf rx (A.run G)) (habs : Block.absAt hdr mpos = some root.toList)
    (hfit : 8 * (2 * S + 4) ≤ L)
    (hq : ∀ k, k < mQ → k < mo.columns.length → (mo.columns.getD k ⟨0, [], zeroDig, []⟩).path.length = 12 →
      ∀ (hf : 8 * (mo.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (mo.columns.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(mo.columns.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (mo.columns.getD k ⟨0, [], zeroDig, []⟩).salt,
          (mo.columns.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx))) :
    RhXMOk tag L h64 key domain hs hL S mpos (A.runLog G).2 G hdr tM mo := by
  intro j hj
  have hT4 := rx_mPre_tr (liftH G) tM S mo
  obtain ⟨-, -, -, idx', hidx', hlen, hcols⟩ := hok
  have hc := challengeIndices_sqDs (liftH G) mQ mDom (runOps (liftH G) tM (stpsOps (mPre S mo))) (by decide)
    (by decide)
  rw [show (mQ + 3) / 4 = 64 from rfl] at hc
  have e2 : some (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64),
      runOps (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) (List.replicate 64 Op.squeeze))
      = some (idx', tA) := by
    rw [← hc, hT4]
    exact hidx'
  simp only [Option.some.injEq, Prod.mk.injEq] at e2
  obtain ⟨hidx, -⟩ := e2
  have hil : (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).length = mQ := by
    rw [idxOf_length, sqDs_length]
    rfl
  have hml : (toMO mo).columns.length = mo.columns.length := List.length_map _
  have hjl : (j : ℕ) < mo.columns.length := by
    rw [← hml, hlen, ← hidx, hil]
    exact j.isLt
  obtain ⟨h1, h2, h3, h4, -, -⟩ := hcols j (by rw [hml]; exact hjl)
  rw [rx_toMO_getD] at h1 h2 h3 h4
  set c := mo.columns.getD j ⟨0, [], zeroDig, []⟩ with hcdef
  have h1' : c.j = idx'.getD j 0 := h1
  have h2' : c.col.length = 2 * S + 4 := h2
  have h3' : c.path.length = 12 := h3
  have h4' : verifyPath (liftH G) tag root c.j (saltLeaf (liftH G) tag (colDigest (liftH G) tag c.col) c.salt) c.path
      = true := h4
  have hf : 8 * c.col.length ≤ L := by rw [h2']; exact hfit
  have hop := opensV_of_exec tag L h64 G 12 root c.j c.col hf c.salt c.path h3' h4'
  have hext : (merkleEncV tag L h64).extractCol (cutAt (absD (chainEncB key domain hs L hL)) root (A.runLog G).2) 12
      c.j root = some ⟨c.col, hf⟩ := by
    by_contra hne
    exact hX ⟨root, hroot, 12, c.j, ⟨⟨c.col, hf⟩, c.salt, c.path⟩, hop, hq j j.isLt hjl h3' hf, hne⟩
  have hjeq : c.j = (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0 := by
    rw [h1', ← hidx]
  show ((colX tag L h64 key domain hs hL 12 mpos (A.runLog G).2 hdr
    ((idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0)).map
      Subtype.val).getD [] = c.col
  rw [← hjeq, colX_root tag L h64 key domain hs hL 12 mpos (A.runLog G).2 hdr root habs c.j, hext]
  rfl

/-! ### The run verifier's Merkle work checks the columns -/

/-- Queries of the other Merkle work are the run verifier's. -/
theorem rx_q_Vx (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (A : OC (QB L) Dig α)
    (G : QB L → Dig) (v : QB L) (hv : v ∈ OC.queries G (Vx (A.run G))) :
    v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx)) := by
  rw [OC.queries_bind, List.mem_append]
  refine Or.inr ?_
  show v ∈ OC.queries G ((blocksV tag L h64 256 256 256 16 16 12 coreOf (A.run G) 26).bind (fun _ => Vx (A.run G)))
  rw [OC.queries_bind, List.mem_append]
  exact Or.inr hv

/-- **Every sampled column of an opening `rxOpenings` lists is checked by `rxVx`** (path depth at most `64`). -/
theorem rx_q_work {Hdr : Type} (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Block.Core)
    (A : OC (QB L) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB L → Dig) (zo : List Block.Column)
    (hzo : zo ∈ rxOpenings incG outcG sgeom Lb (A.run G)) (d : ℕ) (hd : d ≤ 64) :
    ∀ k, k < 256 → k < zo.length → (zo.getD k ⟨0, [], zeroDig, []⟩).path.length = d →
      ∀ (hf : 8 * (zo.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (zo.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(zo.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (zo.getD k ⟨0, [], zeroDig, []⟩).salt,
          (zo.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf
        (rxVx tag L h64 incG outcG sgeom Lb))) := by
  intro k hk hkl hp hf v hv
  apply rx_q_Vx tag L h64 coreOf _ A G v
  exact rxWork_queries tag L h64 G _ zo hzo _ (mem_rxCols L zo k hk hkl hf (by rw [hp]; exact hd)) v hv

/-- **Block `k`'s `A` columns are checked by block `k`'s Merkle work** (`blockV`, `256` columns at depth `16`). -/
theorem rx_q_blkA (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (A : OC (QB L) Dig α)
    (G : QB L → Dig) (kb : ℕ) (hkb : kb < 26) (zo : Block.OpeningZk) (hzo : (coreOf (A.run G) kb).2.aOpen = zo) :
    ∀ k, k < 256 → k < zo.columns.length → (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path.length = 16 →
      ∀ (hf : 8 * (zo.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (zo.columns.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(zo.columns.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (zo.columns.getD k ⟨0, [], zeroDig, []⟩).salt,
          (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx)) := by
  intro k hk hkl hp hf v hv
  apply runV_queries tag L h64 256 256 256 16 16 12 26 coreOf Vx A G kb hkb v
  have h1 := (merkleEncV tag L h64).checkAll_queries G 16 _ _ (mem_colsV L 256 zo.columns k hk hkl hf) hp v hv
  rw [← hzo] at h1
  simp only [blockV, OC.queries_bind, List.mem_append]
  exact Or.inl h1

/-- Block `k`'s `H` columns are checked by block `k`'s Merkle work. -/
theorem rx_q_blkH (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (A : OC (QB L) Dig α)
    (G : QB L → Dig) (kb : ℕ) (hkb : kb < 26) (zo : Block.OpeningZk) (hzo : (coreOf (A.run G) kb).2.hOpen = zo) :
    ∀ k, k < 256 → k < zo.columns.length → (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path.length = 16 →
      ∀ (hf : 8 * (zo.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (zo.columns.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(zo.columns.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (zo.columns.getD k ⟨0, [], zeroDig, []⟩).salt,
          (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx)) := by
  intro k hk hkl hp hf v hv
  apply runV_queries tag L h64 256 256 256 16 16 12 26 coreOf Vx A G kb hkb v
  have h1 := (merkleEncV tag L h64).checkAll_queries G 16 _ _ (mem_colsV L 256 zo.columns k hk hkl hf) hp v hv
  rw [← hzo] at h1
  simp only [blockV, OC.queries_bind, List.mem_append]
  exact Or.inr (Or.inl h1)

/-- Block `k`'s `M` columns are checked by block `k`'s Merkle work (`256` columns at depth `12`). -/
theorem rx_q_blkM (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (A : OC (QB L) Dig α)
    (G : QB L → Dig) (kb : ℕ) (hkb : kb < 26) (mo : Block.MaskOpening)
    (hmo : (coreOf (A.run G) kb).2.maskOpen = mo) :
    ∀ k, k < mQ → k < mo.columns.length → (mo.columns.getD k ⟨0, [], zeroDig, []⟩).path.length = 12 →
      ∀ (hf : 8 * (mo.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (mo.columns.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(mo.columns.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (mo.columns.getD k ⟨0, [], zeroDig, []⟩).salt,
          (mo.columns.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx)) := by
  intro k hk hkl hp hf v hv
  apply runV_queries tag L h64 256 256 256 16 16 12 26 coreOf Vx A G kb hkb v
  have h1 := (merkleEncV tag L h64).checkAll_queries G 12 _ _ (mem_colsV L 256 mo.columns k hk hkl hf) hp v hv
  rw [← hmo] at h1
  simp only [blockV, OC.queries_bind, List.mem_append]
  exact Or.inr (Or.inr h1)

end Ext

end ZK60.ProtocolClassify
