/-
D63 lane L58 (2026-11-10), part 4: **the column test's second half alive at the checked extractor** (`hBal`; the
brief's deliverable 2).

The column test `T` is still built from part `0`'s closing opening (L52's `ebT`), but its matrix and column set are now
the CHECKED extractor's (`exUx`, `exXx`), the ones `ops` reads (so `hread` holds by definition). Part `0`'s closing
opening in the kinds data keeps its matrix read with `colXM` (L52's `ebData`, unchanged): on the sampled columns the two
matrices agree outside the widened event `exEvIn`.

* **`ex_inc_opXC`**: at an accepted run, stage IN-C's closing opening meets `RhOpWC` OUTRIGHT outside `EvXC` (which
  contains L51's `EvXM`), whenever the header's message at `xPos` reads as the statement's input root;
* **`ex_hopX0C`**: the same at part `0` AT THE CODE'S HEADER (`abRdIn` at position `1`, L51's `ab_rdIn_at1`), outside the
  run's `exEvIn`;
* **`epx_xB_of_opB`**: L30's `xB_subSt_of_opB` with the test's matrix allowed to differ from the opening's off the
  sampled columns (`hagr`: they agree at every sampled column; `comb` reads one column) — a general version of L30's
  lemma, whose form asks the two matrices to be one function;
* **`ex_xB_alive`**: THE COLUMN TEST'S SECOND HALF IS ALIVE WITH THE CHECKED EXTRACTOR'S MATRIX AND COLUMNS wherever part
  `0`'s closing opening meets `RhOpWC`: every sampled column is one the checked extractor returns, with the column the
  unchecked one reads.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunEpXInc
import ZK60Formal.RunEpBTest

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX Code
open ZK60.Circuit (gP GF)

/-! ## Part `0`'s closing opening with the checked extraction, at the run -/

section IncC

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **THE INPUT TOKEN ENDPOINT'S OPENING MEETS `RhOpWC` OUTRIGHT AT PART `0`** (L52's `rx_inc_opXM` with the checked
extraction): at any code geometry `g` with at most `256` queries, on an accepted run outside `EvXC rdx` (which contains
L51's `EvXM rdx`) with the run's own Merkle work, given that the header's message at `xPos` reads (under `rdx`) as the
statement's input root. -/
theorem ex_inc_opXC (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG p)
    (hσ : R.σs[0]? = some (rtIncSeg inc incG cx0 p))
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off 0 + p.pre)) = inc s.hdr)
    (g : OGeo) (hg : g.Ok) (hgQ : g.Q ≤ 256) (hX : RkPcsAt U tag g I.pX) (xPos : ℕ)
    (outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs)) (rdx : List UInt8 → Option Dig)
    (hXev : ¬ EvXC tag Lq h64 key domain hs hL rdx 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) ebInRoots A G)
    (hfit : 8 * I.pX.rows ≤ Lq)
    (hRd : (Block.absAt ((R.tr G (s, segs)).take (R.pf.off 0 + (R.pf.part 0).oX)) xPos).bind rdx = some s.inRoot) :
    RhOpWC U tag Lq h64 key domain hs hL rdx (rtW R.pf.sqs) (rkAt g I.pX.rows xPos) I.nIn
      (fun hdr => [] ++ (rkAccInc W (R.pf.off 0 + 5) (R.pf.off 0 + p.pre) hdr).claims.inp)
      (R.pf.off 0 + (R.pf.part 0).oX) (R.pf.off 0 + (R.pf.part 0).oBX)
      (R.pf.off 0 + (R.pf.part 0).oX + (I.nIn + I.pX.rows)) (A.runLog G).2 G (R.tr G (s, segs)) := by
  obtain ⟨seg, hof, himp⟩ :=
    ex_inc_opXG U tag h64 hs hL R hv G s segs hE 0 p inc incG cx0 I hσ W hW g hg hX xPos (A.runLog G).2 rdx
  have hseg : rxInSeg incG (A.run G) = some seg := by rw [hrun]; exact hof
  have hroot : s.inRoot ∈ ebInRoots (A.run G) := by
    rw [hrun]
    exact List.mem_singleton_self _
  have hq := fun k (hk : k < g.Q) => rx_q_work tag Lq h64 incG outcG sgeom Lb (rxCoreOf sgeom) A G
    (seg.closes.headD IncV.ozk0).columns (rx_inCols_mem incG outcG sgeom Lb _ seg hseg).2.2.2 g.h
    (by have := hg.hh; omega) k (lt_of_lt_of_le hk hgQ)
  have hXm : ¬ EvXM tag Lq h64 key domain hs hL rdx 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) ebInRoots A G :=
    fun h => hXev (evXC_of_xm tag Lq h64 key domain hs hL rdx 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) ebInRoots A G h)
  apply himp
  · exact ab_xok_in tag Lq h64 key domain hs hL rdx (rxCoreOf sgeom) (rxVx tag Lq h64 incG outcG sgeom Lb) ebInRoots
      A G hXm g.h xPos I.pX.rows g.Q _ (seg.closes.headD IncV.ozk0) s.inRoot hroot hRd hfit hq
  · intro hcan k hkQ hkl hpath hver hlen
    have h := epx_xok tag Lq h64 key domain hs hL rdx (rxCoreOf sgeom) (rxVx tag Lq h64 incG outcG sgeom Lb) ebInRoots
      A G hXev g.h I.pX.rows g.Q (seg.closes.headD IncV.ozk0) s.inRoot hroot hfit hcan hq k hkQ hkl hpath hver hlen
    have e := epxHn_at_root tag Lq h64 key domain hs hL rdx g.h xPos I.pX.rows (A.runLog G).2 _ s.inRoot hRd
      ((toOZ (seg.closes.headD IncV.ozk0)).columns.getD k (0, [], zeroDig, [])).1
    exact (congrArg (Option.map (fun o : MerkleOpening Dig Dig (ColR I.pX.rows) => o.col.1)) e).trans h

/-- **PART `0`'S CLOSING OPENING MEETS `RhOpWC` AT THE CODE'S HEADER** (L52's `eb_hopX0` with the checked extraction):
on an accepted run whose header is the code's (`clsHdrOf`, L51: the input root inside `expected-IO` at position `1`),
outside the run's widened event `exEvIn`, stage IN-C's closing opening at the endpoint geometry read at position `1`
meets `RhOpWC abRdIn`. -/
theorem ex_hopX0C (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (pin : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG pin)
    (hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin))
    (Win : List (TItem × Dig) → IncV) (hWin : Win ((R.tr G (s, segs)).take (R.pf.off 0 + pin.pre)) = inc s.hdr)
    (g : OGeo) (hg : g.Ok) (hgQ : g.Q ≤ 256) (hX : RkPcsAt U tag g I.pX)
    (outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G)
    (hfit : 8 * I.pX.rows ≤ Lq) :
    RhOpWC U tag Lq h64 key domain hs hL abRdIn (rtW R.pf.sqs) (rkAt g I.pX.rows 1) I.nIn
      (fun hdr => [] ++ (rkAccInc Win (R.pf.off 0 + 5) (R.pf.off 0 + pin.pre) hdr).claims.inp)
      (R.pf.off 0 + (R.pf.part 0).oX) (R.pf.off 0 + (R.pf.part 0).oBX)
      (R.pf.off 0 + (R.pf.part 0).oX + (I.nIn + I.pX.rows)) (A.runLog G).2 G (R.tr G (s, segs)) := by
  have hRd : (Block.absAt ((R.tr G (s, segs)).take (R.pf.off 0 + (R.pf.part 0).oX)) 1).bind abRdIn = some s.inRoot :=
    ab_rdIn_at1 hw R hR G s segs hE _ (by rw [ab_off0 hw R hR G s segs hE]; omega)
  exact ex_inc_opXC U tag h64 hs hL R hv G s segs hE pin inc incG cx0 I hσ0 Win hWin g hg hgQ hX 1 outcG sgeom Lb
    A hrun abRdIn hXev hfit hRd

end IncC

/-! ## L30's step with the test's matrix agreeing with the opening's on the sampled columns -/

section Agree

/-- **The test's second half alive from the opening's `opB`, the two matrices agreeing on the sampled columns** (a
general version of L30's `xB_subSt_of_opB`, which asks the test's matrix to BE the opening's): `opB` alive after its
round says the proximity vector is consistent with `Σ ρ_i U_i` of the OPENING's matrix `Uo` at every sampled column;
`comb` reads one column, so where the test's matrix `Ux` agrees with `Uo` at every sampled column (`hagr`), the test's
check holds with `Ux`. -/
theorem epx_xB_of_opB {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ]
    [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ} (W : UInt64 → ℕ) (aA w0 : ℕ)
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (clOf : List (TItem × Dig) → OClaims Cl G κ μ F)
    (Uo Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx : List (TItem × Dig) → Finset (Fin (2 ^ h)))
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8)
    (decB : List UInt8 → Option (μ → F)) (aB : ℕ) (εB εB' : ℝ≥0∞) (τ : List (TItem × Dig)) (x : List UInt8)
    (ds : List Dig) (pm : Option (List UInt8)) (ds' : List Dig)
    (hrd : cRd (opBRounds labB m) W (τ.drop aB) = some ([(x, ds)], pm, ds'))
    (hin : ∀ k, chalJ (vecOf d₀ m (ds.map halves)) k ∈ Xx ((τ.take aB).take aA))
    (hagr : ∀ k i, Ux ((τ.take aB).take aA) i (chalJ (vecOf d₀ m (ds.map halves)) k)
      = Uo ((τ.take aB).take aA) i (chalJ (vecOf d₀ m (ds.map halves)) k))
    (hop : subSt W (opBCSub W aA w0 enc e clOf Uo vOf d₀ chalLR m chalJ labB decB aB εB') τ) :
    subSt W (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB) τ := by
  rcases hop with h1 | ⟨htr, hl⟩ | h3
  · exact Or.inl h1
  · refine Or.inr (Or.inl ⟨htr, ?_⟩)
    have hl' : liftC ((opBCSub W aA w0 enc e clOf Uo vOf d₀ chalLR m chalJ labB decB aB εB').St (τ.take aB))
        (cRd (opBRounds labB m) W (τ.drop aB)) := hl
    rw [hrd] at hl'
    have hl2 : (opARead W aA w0 (τ.take aB)).isSome = true
        ∧ ∃ wv, decB x = some wv
          ∧ GroupsAccept enc (Uo ((τ.take aB).take aA)) (clOf ((τ.take aB).take aA)).rw
              (clOf ((τ.take aB).take aA)).cw (clOf ((τ.take aB).take aA)).grp (clOf ((τ.take aB).take aA)).val
              (fun g _ _ => vOf (τ.take aB) g) (fun _ _ => wv) (opBLR W aA w0 d₀ chalLR (τ.take aB)).1
              (opBLR W aA w0 d₀ chalLR (τ.take aB)).2 (chalJ (vecOf d₀ m (ds.map halves))) := hl'
    obtain ⟨hsome, wv, hw, hacc⟩ := hl2
    show liftC ((xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB).St (τ.take aB))
      (cRd (opBRounds labB m) W (τ.drop aB))
    rw [hrd]
    show (opARead W aA w0 (τ.take aB)).isSome = true
      ∧ ∃ wv, decB x = some wv
        ∧ ∀ k, chalJ (vecOf d₀ m (ds.map halves)) k ∈ Xx ((τ.take aB).take aA)
          ∧ enc wv (chalJ (vecOf d₀ m (ds.map halves)) k)
            = comb (Ux ((τ.take aB).take aA)) (opBLR W aA w0 d₀ chalLR (τ.take aB)).2
                (chalJ (vecOf d₀ m (ds.map halves)) k)
    refine ⟨hsome, wv, hw, fun k => ⟨hin k, (hacc.2.2 k).trans ?_⟩⟩
    simp only [comb, Finset.sum_apply, Pi.smul_apply, hagr k]
  · exact absurd h3 id

end Agree

/-! ## The column test's second half alive at the checked extractor -/

section Alive

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

include hU in
/-- **THE COLUMN TEST'S SECOND HALF IS ALIVE WITH THE CHECKED EXTRACTOR'S MATRIX AND COLUMNS** (`hBal`'s route at the
checked extractor; L52's `eb_xB_alive` with `Ux`, `Xx` read by `exUx`, `exXx`): if part `0`'s closing opening (at the
endpoint geometry, `Rr` rows, its root read under `rdx` at `xPos`) meets `RhOpWC` at its windows `aO`, `aB` on `τ`,
then `T.cB` of the test built from it (`ebT`), with the checked extractor's matrix and columns, is alive at the end of
`τ`: every sampled column is one the checked extractor returns, and there its column is the one `colXM` reads. -/
theorem ex_xB_alive (rdx : List UInt8 → Option Dig) (W : UInt64 → ℕ) (Rr nC xPos : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig)
    (τ : List (TItem × Dig))
    (wc : RhOpWC U tag Lq h64 key domain hs hL rdx W (rkAt ogEp Rr xPos) nC clr aO aB vpos P G τ) (hab : aO ≤ aB) :
    subSt W ((ebT U hbij Rr nC aO aB hab).cB W
      (fun P' hdr => exUx (K := K) tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P' hdr)
      (fun P' hdr => exXx tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P' hdr) P) τ := by
  obtain ⟨w, hxc⟩ := wc
  have hop := eb_opB_of U hU hbij tag Lq h64 key domain hs hL rdx W (rkAt ogEp Rr xPos) nC clr aO aB vpos P G τ w
  obtain ⟨-, -, hW2', hm0⟩ := rh_stpOK_pcs W _ _ _ w.zo w.rs w.hst
  have hW2 : W ((runOps (liftH G) (runOps (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze))
      (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G) Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)).counter
      = 64 := by
    rw [rh_ctr_pcs (liftH G) w.tA w.c (nC + Rr) w.zo w.hctr]
    exact hW2'
  -- the transcript from the opening's window on
  have htr : opTrace (liftH G) w.tA (stpsOps (pcsStps (nC + Rr) 64 w.zo))
      = opTrace (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze ++ stpsOps (vecStps w.zo.groupVecs))
        ++ ((TItem.absorb Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes),
            ((runOps (liftH G) (runOps (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze))
              (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G) Block.labPcsProx
                (w.zo.proxVec.flatMap Fp2.toBytes)).state)
          :: opTrace (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze))
              (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G) Block.labPcsProx
                (w.zo.proxVec.flatMap Fp2.toBytes)) (List.replicate 64 Op.squeeze)) := by
    rw [stpsOps_pcsStps_split, Block.opTrace_append, runOps_append]
    rfl
  have hA1l : (opTrace (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze ++ stpsOps (vecStps w.zo.groupVecs))).length
      = nC + Rr + w.zo.groupVecs.length := by
    rw [Block.opTrace_length, List.length_append, List.length_replicate, stpsOps_vecStps_length]
  have hdropA : τ.drop aO = opTrace (liftH G) w.tA (stpsOps (pcsStps (nC + Rr) 64 w.zo))
      ++ opTrace (liftH G) (runOps (liftH G) w.tA (stpsOps (pcsStps (nC + Rr) 64 w.zo))) (stpsOps w.rs) := by
    have hd0 : τ.drop aO = opTrace (liftH G) w.tA (stpsOps (pcsStps (nC + Rr) 64 w.zo ++ w.rs)) := w.hdrop
    rw [hd0, stpsOps_append, Block.opTrace_append]
  have hdropB : τ.drop aB = (TItem.absorb Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes),
            ((runOps (liftH G) (runOps (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze))
              (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G) Block.labPcsProx
                (w.zo.proxVec.flatMap Fp2.toBytes)).state)
          :: (opTrace (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze))
              (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G) Block.labPcsProx
                (w.zo.proxVec.flatMap Fp2.toBytes)) (List.replicate 64 Op.squeeze)
            ++ opTrace (liftH G) (runOps (liftH G) w.tA (stpsOps (pcsStps (nC + Rr) 64 w.zo))) (stpsOps w.rs)) := by
    have hd1 : τ.drop aB = τ.drop (aO + (nC + Rr + w.zo.groupVecs.length)) := congrArg (fun n => τ.drop n) w.haB
    rw [hd1, ← List.drop_drop, hdropA, htr, List.append_assoc, List.drop_left' hA1l]
    rfl
  have hrd := cRd_opB (liftH G) W 64 hm0 (w.zo.proxVec.flatMap Fp2.toBytes)
    (runOps (liftH G) (runOps (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs)))
    hW2 (opTrace (liftH G) (runOps (liftH G) w.tA (stpsOps (pcsStps (nC + Rr) 64 w.zo))) (stpsOps w.rs))
  rw [← hdropB] at hrd
  have hnC : nMem (groupZclaims (w.cl.map toZClaim) Rr 8) = nC := by
    unfold nMem
    rw [groupZclaims_count, List.length_map, w.hcnt]
  have htP' : (absorbVecs (liftH G) (toOZ w.zo).groupVecs (zkRhosAux (liftH G) Rr
      (groupZclaims (w.cl.map toZClaim) Rr 8) w.tA).2.2).absorbFp2 (liftH G) pcsProxLabel (toOZ w.zo).proxVec
      = (runOps (liftH G) (runOps (liftH G) w.tA (List.replicate (nC + Rr) Op.squeeze))
          (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G) Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes) := by
    rw [zkRhosAux_tr', hnC, runOps_vecStps]
    rfl
  obtain ⟨hpath, -, -, -, -, hcl, hco⟩ := pcsOk_named (liftH G) tag w.prm _ _ w.root Rr 8 _ (toOZ w.zo) w.tA w.tH
    w.hok 256 (2 ^ 11) 64 w.hqp w.hnQ w.hnn (by have hp2 := w.hpow; rw [w.hnn] at hp2; exact hp2) w.hQ0 w.hm
  rw [htP'] at hco
  -- at every sampled column: the unchecked extraction reads the opened column, the checked one returns it
  have hk : ∀ k : Fin 256, ∃ o : MerkleOpening Dig Dig (ColR Rr),
      epxHn tag Lq h64 key domain hs hL rdx 11 xPos Rr P (τ.take aO)
        ((idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k : Fin (2 ^ 11)) : ℕ) = some o
      ∧ (colXM tag Lq h64 key domain hs hL rdx 11 xPos P (τ.take aO)
        ((idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k : Fin (2 ^ 11)) : ℕ)).map
          Subtype.val = some o.col.1 := by
    intro k
    have hkl : (k : ℕ) < (toOZ w.zo).columns.length := by rw [hcl]; exact k.isLt
    have hkl' : (k : ℕ) < w.zo.columns.length := by
      have e : (toOZ w.zo).columns.length = w.zo.columns.length := List.length_map _
      rw [← e]; exact hkl
    have hc := hco k k.isLt
    have hk1 : ((toOZ w.zo).columns.getD k (0, [], zeroDig, [])).1
        = ((idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k : Fin (2 ^ 11)) : ℕ) := by
      rw [hc.1]
      exact (idxCode_sqDs 11 ogEp.hQm (sqDs (liftH G) _ 64) (sqDs_length _ _ _) k).symm
    have hp : ((toOZ w.zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = 11 := by
      rw [hpath _ (mem_of_getD_lt _ _ hkl _), Nat.log2_two_pow]
    have hx := w.hcolX k k.isLt hkl' hp hc.2.2.1 hc.2.1
    have hxc' := hxc w.hcan k k.isLt hkl' hp hc.2.2.1 hc.2.1
    rw [hk1] at hx hxc'
    obtain ⟨o, ho, hoc⟩ := Option.map_eq_some_iff.mp hxc'
    exact ⟨o, ho, hx.trans (congrArg some hoc.symm)⟩
  have hin : ∀ k : Fin 256,
      idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
        (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
          Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k
        ∈ exXx tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P ((τ.take aB).take aO) := by
    intro k
    rw [List.take_take, min_eq_left hab]
    obtain ⟨o, ho, -⟩ := hk k
    refine Finset.mem_filter.mpr ⟨Finset.mem_univ _, ?_⟩
    show (epxHn tag Lq h64 key domain hs hL rdx 11 xPos Rr P (τ.take aO) _).isSome = true
    exact Option.isSome_iff_exists.mpr ⟨o, ho⟩
  have hagr : ∀ (k : Fin 256) (i : Fin Rr),
      exUx (K := K) tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P ((τ.take aB).take aO) i
        (idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k)
      = ebUxW (K := K) tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P ((τ.take aB).take aO) i
        (idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k) := by
    intro k i
    rw [List.take_take, min_eq_left hab]
    obtain ⟨o, ho, hx⟩ := hk k
    have hi : (i : ℕ) < o.col.1.length := by rw [o.col.2]; exact i.isLt
    have hU1 : exU (epxH tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P (τ.take aO)) i
        (idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k)
        = colGF o.col i := exU_spec _ _ o ho i
    show algebraMap GF K (exU (epxH tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P (τ.take aO)) i
        (idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k))
      = algebraMap GF K ((((colXM tag Lq h64 key domain hs hL rdx 11 xPos P (τ.take aO)
        ((idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
          (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
            Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k : Fin (2 ^ 11)) : ℕ)).map
          Subtype.val).getD []).getD i Fp.zero).toGF
    rw [hU1, hx, Option.getD_some, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi, Option.getD_some]
    rfl
  exact epx_xB_of_opB W aO (nC + Rr) (encGL (K := K) 8 11 256) 768
    (ebOpen U tag Lq h64 key domain hs hL rdx (rkAt ogEp Rr xPos) nC clr vpos).cl
    (fun hdr => ebUxW tag Lq h64 key domain hs hL rdx 11 xPos Rr P hdr)
    (fun hdr => exUx (K := K) tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P hdr)
    (fun hdr => exXx tag Lq h64 key domain hs hL rdx 11 xPos Rr (N := 2 ^ 11) P hdr)
    (vRd U (2 ^ 8 + 256) vpos) dg0
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + Rr) ≃ Fin nC ⊕ Fin Rr)) 64
    (idxCode 11 ogEp.hQm) Block.labPcsProx (proxDec U (2 ^ 8 + 256)) aB _ _ τ _ _ _ _ hrd hin hagr hop

end Alive

end ZK60.ProtocolClassify
