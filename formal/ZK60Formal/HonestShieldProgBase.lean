/-
D63 lane L68c, part 3 base infrastructure (`HonestShieldProgBase.lean`):
shared zero-`sorry` transcript-program, Merkle `RootProg`, `SqLE`, `proveSegs_refuses_at`, and
`PProg.DepAbsorbed` infrastructure needed for Shieldstral T128 R13 `O.refuse` and `O.zk`.

What this file proves (only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s):
1. **`StartProg` → `Site` lift (`startSite`, `startSite_delta`, `startSite_fires_iff_tprogSite`)**:
   lifts `HonestOracleProg.StartProg` (whose start transcript `Tr.newKeyed (liftH G) domain key` depends on `G`,
   unlike `tprogSite`) into `ProtocolClassify.Site (QB Lq) Coins K` with `δ = 0` PROVED (whenever `domain.length ≠ 35`,
   e.g. `shdP_runDomain.length = 74 ≠ 35`), and proves firing equivalence with `tprogSite` at the fixed `G`-dependent
   start transcript so every L29/L32 `*_refuse_cover` theorem transports verbatim in 1 line.
2. **Concrete Merkle `RootProg` builders (`colDigestP`, `saltLeafP`, `treeRootP`, `rootOfP`)**:
   proves that every `HonestOpen.rootOf` tree is a `RootProg` (every column digest query has length `8 * len ≠ 47`;
   every leaf and node query has length `64 ≠ 47`), hence `TProg.Sep key` for all `key`, `SqLE 0`, and exact `final_eq`.
3. **Complete `SqLE` propagation library**:
   `sqLE_absorbRootP`, `sqLE_drawProg`, `sqLE_slotCProg`, `sqLE_scUpToP`, `sqLE_slotEAfter`, `sqLE_scPc`,
   `sqLE_slotAfterC`, `sqLE_slotProg`, `sqLE_famProg`, `sqLE_famPre`, `sqLE_depCProg`, `sqLE_depEProg`,
   `sqLE_outcAlphaProg`, `sqLE_coreHeadProg`, `sqLE_outcHeadProg`, `sqLE_incHeadProg`, `sqLE_sqsP`, `sqLE_rhosP`,
   `sqLE_absorbsP`, `sqLE_maskProg`, `sqLE_pcsProg`.
4. **Prefix-preserving refusal decomposition (`proveSegs_refuses_at`)**:
   strengthens `HonestClassify.proveSegs_refuses` to return the exact prefix success witness
   `proveSegs H s x c bnd (ps.take j) cr t = .ok (rs₁, cr₁, t₁)` alongside the refusing segment `ps[j]? = some p`.
5. **`PProg.DepAbsorbed` (`res_eq_of_depAbsorbed`, `depAbsorbed_depPt`, `depAbsorbed_dep2Pt`, `hres_of_depAbsorbed`)**:
   proves `hres` for `ZKHonestRun.zk_of_prog` / `classifyP_zk_of_prog_model` whenever every `.dep` query (`colDigest`
   and the 2 public header queries) is absorbed into a `.pt` query (`saltLeaf` / `expected-IO`) without branching
   directly on its digest in `PProg.res`.
-/
import ZK60Formal.HonestRunProg
import ZK60Formal.ZKHonestProg
import ZK60Formal.RunShieldInstP

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestOracle ZK60.HonestRun ZK60.ZKHonest
open ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams Hist Acc SlotDef SlotProof SlotRec histOf slotShape)

/-! ## 1. `StartProg` → `Site` lift (`δ = 0` from `Tr.newKeyed`) -/

section StartSite

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {Coins : Type} [Fintype Coins] [Nonempty Coins]

/-- `δ = 0` for a `StartProg` site (`domain.length ≠ 35` separates `startMsg` from 47-byte squeezes). -/
theorem startProg_delta_zero {β : Type} (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (p : Coins → TProg β) (hs : ∀ c, TProg.Sep key (p c))
    (hn : ∀ c dg, TProg.NoWrap (p c) ⟨dg, 0, key⟩) :
    prHC (fun H c => (((⟨key, domain, p c⟩ : StartProg β).oc Lq hLq).run H).1
        ∈ OC.queries H ((⟨key, domain, p c⟩ : StartProg β).oc Lq hLq)) ≤ 0 := by
  unfold prHC
  calc _ ≤ (PMF.uniformOfFintype ((QB Lq → Dig) × Coins)).toOuterMeasure ∅ :=
        MeasureTheory.measure_mono (fun x hx =>
          (startProg_point_fresh Lq hLq x.1 ⟨key, domain, p x.2⟩ hdom (hs x.2) (hn x.2) hx).elim)
    _ = 0 := MeasureTheory.measure_empty

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **Refusal site starting from `Tr.newKeyed (liftH G) domain key`** (`δ = 0` PROVED). -/
noncomputable def startSite {β : Type} (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (p : Coins → TProg β) (bad : β → Finset K) (k : ℕ) (hk : ∀ b, (bad b).card ≤ k)
    (hs : ∀ c, TProg.Sep key (p c)) (hn : ∀ c dg, TProg.NoWrap (p c) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins K where
  β := β
  G c := (⟨key, domain, p c⟩ : StartProg β).oc Lq hLq
  bad := bad
  k := k
  hk := hk
  δ := 0
  hfresh := startProg_delta_zero Lq hLq key domain hdom p hs hn

omit [Field K] [DecidableEq K] [Algebra GF K] in
theorem startSite_delta {β : Type} (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (p : Coins → TProg β) (bad : β → Finset K) (k : ℕ) (hk : ∀ b, (bad b).card ≤ k)
    (hs : ∀ c, TProg.Sep key (p c)) (hn : ∀ c dg, TProg.NoWrap (p c) ⟨dg, 0, key⟩) :
    (startSite Lq hLq key domain hdom p bad k hk hs hn (K := K)).δ = 0 := rfl

omit [DecidableEq K] in
/-- **Exact firing characterization of `startSite`**: identical to `tprogSite` at the `G`-dependent start transcript
`Tr.newKeyed (liftH G) domain key`. -/
theorem startSite_fires {β : Type} (U : K) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (p : Coins → TProg β) (bad : β → Finset K) (k : ℕ) (hk : ∀ b, (bad b).card ≤ k)
    (hs : ∀ c, TProg.Sep key (p c)) (hn : ∀ c dg, TProg.NoWrap (p c) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) :
    (startSite Lq hLq key domain hdom p bad k hk hs hn).fires U G c ↔
      let t0 := Tr.newKeyed (liftH G) domain key
      (challengeFp2Of (liftH G ⟨(TProg.final (liftH G) (p c) t0).1.key,
        squeezeMsg (TProg.final (liftH G) (p c) t0).1.state (TProg.final (liftH G) (p c) t0).1.counter⟩)).toK U
        ∈ bad (TProg.final (liftH G) (p c) t0).2 := by
  dsimp only
  show (challengeFp2Of (G (((⟨key, domain, p c⟩ : StartProg β).oc Lq hLq).run G).1)).toK U
      ∈ bad (((⟨key, domain, p c⟩ : StartProg β).oc Lq hLq).run G).2 ↔ _
  have hrun : ((⟨key, domain, p c⟩ : StartProg β).oc Lq hLq).run G
      = ((p c).oc Lq hLq (Tr.newKeyed (liftH G) domain key)).run G :=
    TProg.askQ_run Lq G _ _
  rw [hrun, TProg.oc_run]
  have hl : (squeezeMsg (TProg.final (liftH G) (p c) (Tr.newKeyed (liftH G) domain key)).1.state
      (TProg.final (liftH G) (p c) (Tr.newKeyed (liftH G) domain key)).1.counter).length ≤ Lq := by
    rw [squeezeMsg_length]; exact hLq
  simp only [TProg.sqPoint, liftH, hl, ↓reduceDIte]

omit [DecidableEq K] in
/-- **1-line transport between `tprogSite` (at fixed `G`'s `Tr.newKeyed`) and `startSite`**: allows applying every
existing L29/L32 `*_refuse_cover` theorem verbatim and lifting its firing site to `startSite`. -/
theorem startSite_fires_iff_tprogSite {β : Type} (U : K) (key : Option Dig) (domain : List UInt8)
    (hdom : domain.length ≠ 35) (p : Coins → TProg β) (bad : β → Finset K) (k : ℕ) (hk : ∀ b, (bad b).card ≤ k)
    (hs : ∀ c, TProg.Sep key (p c)) (hn : ∀ c dg, TProg.NoWrap (p c) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) :
    (startSite Lq hLq key domain hdom p bad k hk hs hn).fires U G c ↔
      (tprogSite Lq hLq p (fun _ => Tr.newKeyed (liftH G) domain key) bad k hk hs
        (fun c' => hn c' (liftH G ⟨key, startMsg domain⟩))).fires U G c :=
  (startSite_fires Lq hLq U key domain hdom p bad k hk hs hn G c).trans
    (tprogSite_fires Lq hLq U p (fun _ => Tr.newKeyed (liftH G) domain key) bad k hk hs
      (fun c' => hn c' (liftH G ⟨key, startMsg domain⟩)) G c).symm

/-- Shieldstral's registered run domain has length `74 ≠ 35`, separating `startMsg` from 47-byte squeezes. -/
theorem shdP_runDomain_length_ne_35 : shdP_runDomain.length ≠ 35 := by
  decide

end StartSite

/-! ## 2. Concrete Merkle `RootProg` builders for `HonestOpen.rootOf` -/

section MerkleRootProg

/-- Column-digest program: one `ext` query of length `8 * col.length` (never `47`). -/
def colDigestP (tag : MTag) (col : List Fp) : RootProg (fun H => colDigest H tag col) where
  p := .ext ⟨tag.col, colBytes col⟩ (fun d => .done d)
  final_eq _ _ := rfl
  sep _ := ⟨Or.inr (by rw [colBytes_length]; omega), fun _ => trivial⟩
  sq _ := trivial

/-- Salted-leaf program for column `j` of a `Table`: `colDigest` (`8 * len ≠ 47`) then `saltLeaf` (`64 ≠ 47`). -/
def saltLeafP (tag : MTag) (T : Table) (j : ℕ) : RootProg (fun H => leafAt H tag T j) where
  p := .ext ⟨tag.col, colBytes (T.cols j)⟩ (fun d =>
    .ext ⟨tag.leaf, d.toList ++ (T.salts j).toList⟩ (fun ld => .done ld))
  final_eq _ _ := rfl
  sep _ := ⟨Or.inr (by rw [colBytes_length]; omega),
    fun d => ⟨Or.inr (by rw [digPair_length]; omega), fun _ => trivial⟩⟩
  sq _ _ := trivial

/-- Recursive Merkle tree-root program over any leaf `RootProg` family `L : ℕ → RootProg ...`. -/
def treeRootP (tag : MTag) :
    ∀ (d : ℕ) {v : (HIn → Dig) → ℕ → Dig} (_ : ∀ i, RootProg (fun H => v H i)) (idx : ℕ),
      RootProg (fun H => ZK60.Complete.treeRoot (merkleEnc tag) H d (fun i => v H (2 ^ d * idx + i)))
  | 0, v, L, idx =>
    { p := (L idx).p
      final_eq := fun H t => by
        simpa [ZK60.Complete.treeRoot] using (L idx).final_eq H t
      sep := (L idx).sep
      sq := (L idx).sq }
  | d + 1, v, L, idx =>
    let left := treeRootP tag d L (2 * idx)
    let right := treeRootP tag d L (2 * idx + 1)
    { p := bindP left.p (fun dl => bindP right.p (fun dr =>
        .ext ⟨tag.node, dl.toList ++ dr.toList⟩ (fun dn => .done dn)))
      final_eq := fun H t => by
        rw [final_bindP, left.final_eq, final_bindP, right.final_eq]
        -- Helper: treeRoot at d + 1 splits into left and right subtrees of height d
        have hsplit : ∀ (m : ℕ) (w : ℕ → Dig),
            ZK60.Complete.treeRoot (merkleEnc tag) H (m + 1) w =
              H ((merkleEnc tag).nodeQ
                (ZK60.Complete.treeRoot (merkleEnc tag) H m (fun i => w i))
                (ZK60.Complete.treeRoot (merkleEnc tag) H m (fun i => w (2 ^ m + i)))) := by
          intro m
          induction m with
          | zero => intro w; rfl
          | succ m' ih =>
            intro w
            simp only [ZK60.Complete.treeRoot]
            have h1 := ih (fun i => H ((merkleEnc tag).nodeQ (w (2 * i)) (w (2 * i + 1))))
            refine h1.trans ?_
            have hfn : (fun i => H ((merkleEnc tag).nodeQ (w (2 * (2 ^ m' + i))) (w (2 * (2 ^ m' + i) + 1))))
                = (fun i => H ((merkleEnc tag).nodeQ (w (2 ^ (m' + 1) + 2 * i)) (w (2 ^ (m' + 1) + (2 * i + 1))))) := by
              funext i
              have ha : 2 * (2 ^ m' + i) = 2 ^ (m' + 1) + 2 * i := by ring
              simp only [ha, Nat.add_assoc]
            rw [hfn]
        have hstep := hsplit d (fun i => v H (2 ^ (d + 1) * idx + i))
        have hl : (fun i => v H (2 ^ d * (2 * idx) + i)) = (fun i => v H (2 ^ (d + 1) * idx + i)) := by
          funext i; congr 1; ring
        have hr : (fun i => v H (2 ^ d * (2 * idx + 1) + i)) =
            (fun i => v H (2 ^ (d + 1) * idx + (2 ^ d + i))) := by
          funext i; congr 1; ring
        change (t, H ((merkleEnc tag).nodeQ _ _)) = _
        rw [hl, hr, ← hstep]
      sep := fun key => sep_bindP key left.p _ (left.sep key) (fun dl =>
        sep_bindP key right.p _ (right.sep key) (fun dr =>
          ⟨Or.inr (by rw [digPair_length]; omega), fun _ => trivial⟩))
      sq := sqLE_bindP left.p _ 0 0 left.sq (fun _ =>
        sqLE_bindP right.p _ 0 0 right.sq (fun _ _ => trivial)) }

/-- **Any `HonestOpen.rootOf H tag d T` is a concrete `RootProg`** (`Sep key` for all `key`, `SqLE 0`). -/
def rootOfP (tag : MTag) (d : ℕ) (T : Table) : RootProg (fun H => rootOf H tag d T) where
  p := (treeRootP tag d (v := fun H i => leafAt H tag T i) (fun i => saltLeafP tag T i) 0).p
  final_eq H t := by
    have h := (treeRootP tag d (v := fun H i => leafAt H tag T i) (fun i => saltLeafP tag T i) 0).final_eq H t
    simpa [rootOf] using h
  sep := (treeRootP tag d (v := fun H i => leafAt H tag T i) (fun i => saltLeafP tag T i) 0).sep
  sq := (treeRootP tag d (v := fun H i => leafAt H tag T i) (fun i => saltLeafP tag T i) 0).sq

end MerkleRootProg

/-! ## 3. Complete `SqLE` propagation library -/

section SqLELib

variable {α β : Type}

theorem sqLE_absorbRootP {root : (HIn → Dig) → Dig} (r : RootProg root) (label : List UInt8) (rows logCols m : ℕ)
    (k : Dig → TProg β) (hk : ∀ d, SqLE m (k d)) :
    SqLE m (absorbRootP r label rows logCols k) := by
  unfold absorbRootP
  have h := sqLE_bindP r.p (fun d => .absorb label d.toList (.absorb Exec.Block.labRows (le64 (UInt64.ofNat rows))
    (.absorb Exec.Block.labLogCols (le64 (UInt64.ofNat logCols)) (k d)))) 0 m r.sq (fun d => hk d)
  rwa [Nat.zero_add] at h

theorem sqLE_drawProg (j m : ℕ) (pre : TProg α) (hp : SqLE m pre) :
    SqLE (m + j) (drawProg j pre) := by
  unfold drawProg
  exact sqLE_bindP pre _ m j hp (fun a => by
    have h := sqLE_drawsP j 0 (fun dr => TProg.done (a, dr)) (fun _ => trivial)
    rwa [Nat.add_zero] at h)

theorem sqLE_slotCProg (P : BlockParams) (s m : ℕ) (pre : TProg α) (hp : SqLE m pre) :
    SqLE (m + P.draws s) (slotCProg P s pre) := by
  unfold slotCProg
  exact sqLE_bindP pre _ m (P.draws s) hp (fun a => by
    have h := sqLE_drawsP (P.draws s) 0
      (fun dr => TProg.absorb Exec.Block.labPbSlot (le64 (UInt64.ofNat s)) (TProg.done (a, dr)))
      (fun _ => trivial)
    rwa [Nat.add_zero] at h)

theorem sqLE_scUpToP : ∀ (N : ℕ) (p : WProver N) (m : ℕ), SqLE m (scUpToP N p m)
  | 0, _, _ => trivial
  | _ + 1, _, 0 => trivial
  | N + 1, p, m + 1 => fun dg => sqLE_scUpToP N (p.2 (challengeFp2Of dg)) m

theorem sqLE_slotEAfter (P : BlockParams) (s : ℕ) (D : SlotData P) (m : ℕ) (hist : Hist) (acc : Acc) (c : Fp2)
    (r : Except String SlotDef) :
    SqLE m (slotEAfter P s D m hist acc c r) := by
  cases r with
  | error _ => trivial
  | ok df => exact sqLE_scUpToP (slotN P s) _ m

theorem sqLE_scPc : ∀ (n m : ℕ) (p : WProver n) (k : List (List Fp2) → List Fp2 → TProg β),
    (∀ rs cs, SqLE m (k rs cs)) → SqLE (n + m) (scPc n p k)
  | 0, m, _, k, hk => by rw [Nat.zero_add]; exact hk [] []
  | n + 1, m, _, _, hk => by
    show SqLE (n + 1 + m) (TProg.squeeze _)
    rw [show n + 1 + m = (n + m) + 1 by omega]
    exact fun _ => sqLE_scPc n m _ _ (fun _ _ => hk _ _)

theorem sqLE_slotAfterC (P : BlockParams) (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (dr : List Fp2)
    (c : Fp2) (r : Except String SlotDef) :
    SqLE (slotN P s) (slotAfterC P D s hist acc dr c r) := by
  unfold slotAfterC
  cases r with
  | error _ => trivial
  | ok df =>
    dsimp only
    refine sqLE_mono _ (slotN P s + 0) (slotN P s) ?_ (by omega)
    exact sqLE_scPc (slotN P s) 0 (D.strat s hist acc df c) _ (fun _ _ => trivial)

theorem sqLE_slotProg (P : BlockParams) (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) :
    SqLE (P.draws s + 1 + slotN P s) (slotProg P D s hist acc) := by
  unfold slotProg
  rw [show P.draws s + 1 + slotN P s = P.draws s + (slotN P s + 1) by omega]
  exact sqLE_drawsP (P.draws s) (slotN P s + 1) _ (fun dr => fun dgc => sqLE_slotAfterC P D s hist acc dr _ _)

/-- Total squeezes upper bound for `m` slots starting at `s` in a family `Pf`. -/
def famSqBound (Pf : ℕ → BlockParams) : ℕ → ℕ → ℕ
  | 0, _ => 0
  | m + 1, s => ((Pf s).draws s + 1 + slotN (Pf s) s) + famSqBound Pf m (s + 1)

theorem sqLE_famProg (Pf : ℕ → BlockParams) (Df : (s : ℕ) → SlotData (Pf s)) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc),
      SqLE (famSqBound Pf m s) (famProg Pf Df b g a m recs s acc)
  | 0, _, _, _ => trivial
  | m + 1, recs, s, acc =>
    sqLE_bindP _ _ _ _ (sqLE_slotProg (Pf s) (Df s) s (histOf b g a recs) acc) (fun r => by
      cases r with
      | ok x => exact sqLE_famProg Pf Df b g a m (recs ++ [x.2.1]) (s + 1) x.2.2
      | error _ => exact sqLE_famProg Pf Df b g a m recs (s + 1) acc)

theorem sqLE_famPre (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s))
    (bga : α → Fp2 × Fp2 × Fp2) (hd : TProg α) (i nh nf : ℕ)
    (hhd : SqLE nh hd) (hf : ∀ x, famSqBound (Pf x) i 0 ≤ nf) :
    SqLE (nh + nf) (famPre Pf Df bga hd i) := by
  unfold famPre
  exact sqLE_bindP hd _ nh nf hhd (fun x => by
    have h := sqLE_bindP (famProg (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 i [] 0 {})
      (fun ra => TProg.done (x, ra)) (famSqBound (Pf x) i 0) 0 (sqLE_famProg (Pf x) (Df x) _ _ _ i [] 0 {})
      (fun _ => trivial)
    exact sqLE_mono _ _ nf h (by have := hf x; omega))

theorem sqLE_depCProg (Pf : α → ℕ → BlockParams) (pre : TProg (α × List SlotRec × Acc)) (i m dmax : ℕ)
    (hp : SqLE m pre) (hd : ∀ x, (Pf x i).draws i ≤ dmax) :
    SqLE (m + dmax) (depCProg Pf pre i) := by
  unfold depCProg
  exact sqLE_bindP pre _ m dmax hp (fun y => by
    have h := sqLE_drawsP ((Pf y.1 i).draws i) 0
      (fun dr => TProg.absorb Exec.Block.labPbSlot (le64 (UInt64.ofNat i)) (TProg.done (y, dr)))
      (fun _ => trivial)
    exact sqLE_mono _ _ dmax h (by have := hd y.1; omega))

theorem sqLE_depEProg (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s))
    (bga : α → Fp2 × Fp2 × Fp2) (pre : TProg (α × List SlotRec × Acc)) (i r m dmax : ℕ)
    (hp : SqLE m pre) (hd : ∀ x, (Pf x i).draws i ≤ dmax) :
    SqLE (m + dmax + 1 + r) (depEProg Pf Df bga pre i r) := by
  unfold depEProg
  rw [show m + dmax + 1 + r = (m + dmax) + (r + 1) by omega]
  exact sqLE_bindP _ _ (m + dmax) (r + 1) (sqLE_depCProg Pf pre i m dmax hp hd)
    (fun yd _ => sqLE_slotEAfter (Pf yd.1.1 i) i (Df yd.1.1 i) r _ _ _ _)

theorem sqLE_outcAlphaProg (V : OutcV) {rA rM : (HIn → Dig) → Dig} (pre : TProg α) (RA : RootProg rA)
    (RM : RootProg rM) (m : ℕ) (hp : SqLE m pre) :
    SqLE (m + 1) (outcAlphaProg V pre RA RM) := by
  unfold outcAlphaProg
  exact sqLE_bindP pre _ m 1 hp (fun _ =>
    sqLE_absorbRootP RA _ _ _ 1 _ (fun _ => by
      have h := sqLE_bindP RM.p (fun mg => .absorb Exec.Block.labM mg.toList (drawsP 1 (fun g => .done g)))
        0 1 RM.sq (fun _ => by
          have h1 := sqLE_drawsP 1 0 (fun g => TProg.done g) (fun _ => trivial)
          rwa [Nat.add_zero] at h1)
      rwa [Nat.zero_add] at h))

theorem sqLE_coreHeadProg (P : BlockParams) {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig}
    {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β) (RA : RootProg rA) (RM : RootProg rM)
    (RH : ∀ ch, RootProg (rH ch)) (m : ℕ) (hp : SqLE m pre) :
    SqLE (m + 3) (coreHeadProg P a pre RA RM RH) := by
  unfold coreHeadProg
  exact sqLE_bindP pre _ m 3 hp (fun _ =>
    sqLE_absorbRootP RA _ _ _ 3 _ (fun _ => by
      have h := sqLE_bindP RM.p
        (fun mg => .absorb Exec.Block.labM mg.toList (drawsP 3 (fun ch =>
          absorbRootP (RH ch) Exec.Block.labH P.hRows P.logCols (fun _ => .done (a, ch)))))
        0 3 RM.sq (fun _ => by
          have h1 := sqLE_drawsP 3 0
            (fun ch => absorbRootP (RH ch) Exec.Block.labH P.hRows P.logCols (fun _ => .done (a, ch)))
            (fun ch => sqLE_absorbRootP (RH ch) _ _ _ 0 (fun _ => .done (a, ch)) (fun _ => trivial))
          rwa [Nat.add_zero] at h1)
      rwa [Nat.zero_add] at h))

theorem sqLE_outcHeadProg (V : OutcV) {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig}
    {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β) (RA : RootProg rA) (RM : RootProg rM)
    (RH : ∀ ch, RootProg (rH ch)) (m : ℕ) (hp : SqLE m pre) :
    SqLE (m + 2) (outcHeadProg V a pre RA RM RH) := by
  unfold outcHeadProg
  exact sqLE_bindP pre _ m 2 hp (fun _ =>
    sqLE_absorbRootP RA _ _ _ 2 _ (fun _ => by
      have h := sqLE_bindP RM.p
        (fun mg => .absorb Exec.Block.labM mg.toList (drawsP 2 (fun ch =>
          absorbRootP (RH ch) Exec.Block.labH V.bp.hRows V.bp.logCols (fun _ => .done (a, ch)))))
        0 2 RM.sq (fun _ => by
          have h1 := sqLE_drawsP 2 0
            (fun ch => absorbRootP (RH ch) Exec.Block.labH V.bp.hRows V.bp.logCols (fun _ => .done (a, ch)))
            (fun ch => sqLE_absorbRootP (RH ch) _ _ _ 0 (fun _ => .done (a, ch)) (fun _ => trivial))
          rwa [Nat.add_zero] at h1)
      rwa [Nat.zero_add] at h))

theorem sqLE_incHeadProg (V : IncV) {A : Type} (a : A) {rB rA rM : (HIn → Dig) → Dig}
    {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β) (RB : RootProg rB) (RA : RootProg rA)
    (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) (m : ℕ) (hp : SqLE m pre) :
    SqLE (m + incHeadDraws V.pub) (incHeadProg V a pre RB RA RM RH) := by
  unfold incHeadProg
  exact sqLE_bindP pre _ m (incHeadDraws V.pub) hp (fun _ =>
    sqLE_absorbRootP RB _ _ _ (incHeadDraws V.pub) _ (fun _ =>
      sqLE_absorbRootP RA _ _ _ (incHeadDraws V.pub) _ (fun _ => by
        have h := sqLE_bindP RM.p
          (fun mg => .absorb Exec.Block.labM mg.toList (drawsP (incHeadDraws V.pub) (fun ch =>
            absorbRootP (RH ch) Exec.Block.labH V.lay.hRows V.lay.logN (fun _ => .done (a, ch)))))
          0 (incHeadDraws V.pub) RM.sq (fun _ => by
            have h1 := sqLE_drawsP (incHeadDraws V.pub) 0
              (fun ch => absorbRootP (RH ch) Exec.Block.labH V.lay.hRows V.lay.logN (fun _ => .done (a, ch)))
              (fun ch => sqLE_absorbRootP (RH ch) _ _ _ 0 (fun _ => .done (a, ch)) (fun _ => trivial))
            rwa [Nat.add_zero] at h1)
        rwa [Nat.zero_add] at h)))

theorem sqLE_sqsP : ∀ (n m : ℕ) (k : List Dig → TProg β), (∀ ds, SqLE m (k ds)) → SqLE (n + m) (sqsP n k)
  | 0, m, k, hk => by rw [Nat.zero_add]; exact hk []
  | n + 1, m, _, hk => by
    rw [show n + 1 + m = (n + m) + 1 by omega]
    exact fun _ => sqLE_sqsP n m _ (fun _ => hk _)

theorem sqLE_rhosP (rows : ℕ) :
    ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (m : ℕ) (k : List (List Fp2) × List Fp2 → TProg β),
      (∀ r, SqLE m (k r)) → SqLE ((gs.map (fun g => g.2.length)).sum + rows + m) (rhosP rows gs k)
  | [], m, k, hk => by
    simp only [List.map_nil, List.sum_nil, Nat.zero_add]
    exact sqLE_drawsP rows m _ (fun _ => hk _)
  | g :: gs, m, k, hk => by
    simp only [rhosP, List.map_cons, List.sum_cons]
    rw [show g.2.length + (gs.map (fun x => x.2.length)).sum + rows + m
        = g.2.length + ((gs.map (fun x => x.2.length)).sum + rows + m) by omega]
    exact sqLE_drawsP g.2.length _ _ (fun _ => sqLE_rhosP rows gs m _ (fun _ => hk _))

theorem sqLE_absorbsP : ∀ (vs : List (List Fp2)) (m : ℕ) (k : TProg β), SqLE m k → SqLE m (absorbsP vs k)
  | [], _, _, hk => hk
  | _ :: vs, m, k, hk => sqLE_absorbsP vs m k hk

theorem sqLE_maskProg (S : ℕ) (qw : α → Fp2 → List Fp2) (pw : α → Fp2 → List Fp2 → List Fp2)
    (pre : TProg α) (m : ℕ) (hp : SqLE m pre) :
    SqLE (m + (1 + (2 * S + 2) + (mQ + 3) / 4)) (maskProg S qw pw pre) := by
  unfold maskProg
  refine sqLE_bindP pre _ m (1 + (2 * S + 2) + (mQ + 3) / 4) hp (fun a => ?_)
  rw [show 1 + (2 * S + 2) + (mQ + 3) / 4 = 1 + ((2 * S + 2) + (mQ + 3) / 4) by omega]
  exact sqLE_drawsP 1 ((2 * S + 2) + (mQ + 3) / 4) _ (fun th =>
    sqLE_drawsP (2 * S + 2) ((mQ + 3) / 4) _ (fun rs => by
      have h := sqLE_sqsP ((mQ + 3) / 4) 0 (fun _ => TProg.done ()) (fun _ => trivial)
      rwa [Nat.add_zero] at h))

theorem sqLE_pcsProg (prm : PcsPrm) (T : α → Table) (claims : α → List ZClaim)
    (pre : TProg α) (m bound : ℕ) (hp : SqLE m pre)
    (hb : ∀ a, ((pGroups prm (T a) (claims a)).map (fun g => g.2.length)).sum + (T a).rows.length + (prm.nQ + 3) / 4 ≤ bound) :
    SqLE (m + bound) (pcsProg prm T claims pre) := by
  unfold pcsProg
  refine sqLE_bindP pre _ m bound hp (fun a => ?_)
  refine sqLE_mono _ _ bound ?_ (hb a)
  exact sqLE_rhosP (T a).rows.length (pGroups prm (T a) (claims a)) ((prm.nQ + 3) / 4) _ (fun _ =>
    sqLE_absorbsP _ _ _ (sqLE_mono _ ((prm.nQ + 3) / 4 + 0) ((prm.nQ + 3) / 4)
      (sqLE_sqsP ((prm.nQ + 3) / 4) 0 _ (fun _ => trivial)) (by omega)))

end SqLELib

/-! ## 4. Prefix-preserving `proveSegs_refuses_at` -/

section ProveSegsAt

open ZK60.Exec.Block (posTag)

/-- **Prefix-preserving refusal decomposition**: if `proveSegs` refuses on `ps`, there is an index `j < ps.length`
such that the prefix `ps.take j` SUCCEEDED with `(rs₁, cr₁, t₁)` and segment `ps[j]` refused on `(cr₁, t₁)`. -/
theorem proveSegs_refuses_at {St X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    ∀ (ps : List (SegP St X Coins)) (cr : Carry) (t : Tr),
      proveSegs H s x c bnd ps cr t = .error () →
      ∃ (j : ℕ) (p : SegP St X Coins) (rs₁ : List (List UInt8)) (cr₁ : Carry) (t₁ : Tr),
        ps[j]? = some p
        ∧ proveSegs H s x c bnd (ps.take j) cr t = .ok (rs₁, cr₁, t₁)
        ∧ p.run H s x c bnd (posTag H t₁) cr₁ t₁ = .error ()
  | [], _, _, h => by cases h
  | p :: ps, cr, t, h => by
    have h' : (p.run H s x c bnd (posTag H t) cr t >>= fun r =>
        proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' =>
          .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2)) = .error () := h
    cases hp : p.run H s x c bnd (posTag H t) cr t with
    | error e =>
      cases e
      exact ⟨0, p, [], cr, t, rfl, rfl, hp⟩
    | ok r =>
      rw [hp] at h'
      cases hq : proveSegs H s x c bnd ps r.2.1 r.2.2 with
      | error e =>
        cases e
        obtain ⟨j, p₁, rs₁, cr₁, t₁, hj, hpre, href⟩ := proveSegs_refuses_at H s x c bnd ps r.2.1 r.2.2 hq
        refine ⟨j + 1, p₁, r.1 (posTag H r.2.2) :: rs₁, cr₁, t₁, by simpa using hj, ?_, href⟩
        show (p.run H s x c bnd (posTag H t) cr t >>= fun r0 =>
          proveSegs H s x c bnd (ps.take j) r0.2.1 r0.2.2 >>= fun r' =>
            .ok (r0.1 (posTag H r0.2.2) :: r'.1, r'.2.1, r'.2.2)) = .ok _
        rw [hp]
        change (proveSegs H s x c bnd (ps.take j) r.2.1 r.2.2 >>= fun r' =>
          .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2)) = .ok _
        rw [hpre]
        rfl
      | ok r' =>
        have h'' : (Except.ok r >>= fun r0 => proveSegs H s x c bnd ps r0.2.1 r0.2.2 >>= fun r1 =>
            (.ok (r0.1 (posTag H r0.2.2) :: r1.1, r1.2.1, r1.2.2) : Except Unit _)) = .error () := h'
        have he : (Except.ok r >>= fun r0 => proveSegs H s x c bnd ps r0.2.1 r0.2.2 >>= fun r1 =>
            (.ok (r0.1 (posTag H r0.2.2) :: r1.1, r1.2.1, r1.2.2) : Except Unit _))
            = .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2) := by
          change (proveSegs H s x c bnd ps r.2.1 r.2.2 >>= _) = _
          rw [hq]; rfl
        rw [he] at h''
        cases h''

end ProveSegsAt

/-! ## 5. `PProg.DepAbsorbed` (`hres` for `.dep` queries absorbed into `.pt` queries, e.g. `colDigest → saltLeaf`) -/

section DepAbsorbed

variable {Q D α : Type}

/-- Structural criterion ensuring `PProg.res H v p i` is completely independent of `H`:
every `.dep` query's digest may enter later `.pt` query inputs (e.g., `colDigest` into `saltLeaf`, or
`Tr.newKeyed`/`run-shape` into `expected-IO`), without changing `PProg.res`. -/
inductive DepAbsorbed : PProg Q D α → Prop
  | ret (a : α) : DepAbsorbed (.ret a)
  | pt (z : Q) (k : D → PProg Q D α) : (∀ d, DepAbsorbed (k d)) → DepAbsorbed (.pt z k)
  | dep (z : Q) (k : D → PProg Q D α) :
      (∀ d, DepAbsorbed (k d)) →
      (∀ d₁ d₂ H v i, PProg.res H v (k d₁) i = PProg.res H v (k d₂) i) →
      DepAbsorbed (.dep z k)

/-- **Core theorem**: a `DepAbsorbed` program's value-driven result `PProg.res` is independent of the oracle `H`. -/
theorem res_eq_of_depAbsorbed {p : PProg Q D α} (h : DepAbsorbed p) :
    ∀ (H₁ H₂ : Q → D) (v : ℕ → D) (i : ℕ), PProg.res H₁ v p i = PProg.res H₂ v p i := by
  induction h with
  | ret a => intro _ _ _ _; rfl
  | pt z k _ ih => intro H₁ H₂ v i; exact ih (v i) H₁ H₂ v (i + 1)
  | dep z k _ hind ih =>
    intro H₁ H₂ v i
    exact (ih (H₁ z) H₁ H₂ v i).trans (hind (H₁ z) (H₂ z) H₂ v i)

/-- Single `.dep` absorbed into an immediately following `.pt` (`colDigest → saltLeaf`). -/
theorem depAbsorbed_depPt (z : Q) (q : D → Q) (k : D → PProg Q D α) (hk : ∀ d, DepAbsorbed (k d)) :
    DepAbsorbed (.dep z (fun d => .pt (q d) k)) :=
  DepAbsorbed.dep z _ (fun d => DepAbsorbed.pt (q d) k hk) (fun _ _ _ _ _ => rfl)

/-- Two consecutive `.dep`s absorbed into a `.pt` (`Tr.newKeyed → run-shape → expected-IO`). -/
theorem depAbsorbed_dep2Pt (z₁ : Q) (z₂ : D → Q) (q : D → D → Q) (k : D → PProg Q D α)
    (hk : ∀ d, DepAbsorbed (k d)) :
    DepAbsorbed (.dep z₁ (fun d₁ => .dep (z₂ d₁) (fun d₂ => .pt (q d₁ d₂) k))) :=
  DepAbsorbed.dep z₁ _
    (fun d₁ => depAbsorbed_depPt (z₂ d₁) (q d₁) k hk)
    (fun _ _ _ _ _ => rfl)

/-- Direct discharge of `ZKHonestRun.zk_of_prog` / `classifyP_zk_of_prog_model`'s `hres` hypothesis. -/
theorem hres_of_depAbsorbed [Inhabited D] {p : PProg Q D α} (h : DepAbsorbed p)
    (H' : Q → D) (v : ℕ → D) :
    p.res H' v 0 = p.res (fun _ => (default : D)) v 0 :=
  res_eq_of_depAbsorbed h H' (fun _ => default) v 0

end DepAbsorbed

end ZK60.HonestShield
