/-
D63 lane L52 (2026-11-10), part 5: **the endpoint's column test `T` built from part `0`'s closing opening** (finding
L51-2; the brief's deliverable 2: `T`, `hTenc`, `hTe`, `hTQ`, `hβLR`, `hβJ`, `hw0`, `hF`, `Ux`, `Xx`, `hUc`, `hXc`,
`hBal`).

The app's top theorem reads the input endpoint twice: as part `0`'s closing opening in the kinds data (`hopX` at `0`)
and as the column test `T` (`Ux`, `Xx`, `hread`, `hBal`). Here `T` IS part `0`'s closing opening (repair B's, read
under a reader `rdx`), at the input endpoint's code geometry `ogEp` (`2^11` symbols, `2^8` message columns, `256`
queries and pads, radius `768`, `64` index squeezes):

* **`eb_enc_ep`**: the run model's code at `ogEp` (`encGL 8 11 256`: L48's `RWL 8` on L22's `ptsG 11`) IS the
  endpoint code the test's statement names (`encLin` on `epPts`, the coset `7·G_{2^11}`, and `rowFormK8`): `hTenc`;
* **`ebT`**: the column test whose code, radius, batching challenges (`lrCode`, L28), index challenges (`idxCode`), proximity
  label and decoder (`"pcs-prox"`, `proxDec`) and windows are those of part `0`'s closing opening; its code facts are
  L48's `ep_open_code_factsU` (minimum distance `1,537`, `2·768 < 1,537`, correlated agreement at `A = 2^11`), its
  challenge biases L28's `lrCode_prob_le` (`(1 + p/2^128)^(2·w0)`) and `idxCode_prob_le` (`1`);
* `ebXxW`, `ebUxW_cut`, **`ebXxW_cut`**: the test's extraction (`Ux` the matrix `colXM rdx` extracts, `Xx` the columns it
  extracts), cut readers (L30's `CutReads`, through L51's `colXM_cutEq`): `hUc`, `hXc`;
* **`eb_xB_alive`**: the test's second half `T.cB` is ALIVE wherever part `0`'s closing opening meets `RhOpWM`: the
  opening's `opB` is alive (`eb_opB_of`), its round reads off the transcript (L28's `cRd_opB`), and every column the
  verifier samples is one the extraction found (`hcolX`): L30's `xB_subSt_of_opB`. This is `hBal`'s route (L51-2);
* `eb_ab_le`: the closing opening's two windows are in order.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunEpBInc
import ZK60Formal.BindingEP
import ZK60Formal.RunChainUStab

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-- The closing opening's two windows are in order. -/
theorem eb_ab_le (pf : RtProf) (i : ℕ) : pf.off i + (pf.part i).oX ≤ pf.off i + (pf.part i).oBX := by
  simp only [RtPart.oBX]
  omega

/-! ## The endpoint code -/

/-- **THE RUN MODEL'S CODE AT THE ENDPOINT GEOMETRY IS THE TEST'S** (`hTenc`): `encGL 8 11 256` (L22's points `ptsG 11`,
the coset `7·G_{2^11}` read through `Fp`, and L48's row form `RWL 8`) is `encLin` on `epPts` with `rowFormK8`. -/
theorem eb_enc_ep {K : Type} [Field K] [Algebra GF K] :
    encGL (K := K) 8 11 256 = encLin (Q := 256) (fun j => algebraMap GF K (epPts j)) (rowFormK8 K) := by
  have hp : ptsG (K := K) 11 = fun j => algebraMap GF K (epPts j) := by
    funext j
    show algebraMap GF K (cosetPt (rootFp 11) j).toGF = algebraMap GF K (cosetPts 7 (rootGF 11) j)
    rw [cosetPt_toGF _ _ (lt_of_lt_of_le j.isLt (by norm_num)), rootFp_toGF (by norm_num)]
    rfl
  show encLin (Q := 256) (ptsG 11) (RWL 8) = _
  rw [hp, rowFormK8_eq_RWL]

/-! ## The test -/

section Test

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **THE ENDPOINT'S COLUMN TEST BUILT FROM PART `0`'S CLOSING OPENING** (L51-2): the code `encGL 8 11 256` at radius
`768` (L48's facts at the endpoint), the batching challenges `lrCode` over `nC + Rr` squeezes, the index challenges
`idxCode 11` over `64` squeezes, `"pcs-prox"` and `proxDec`, its windows `aA` (the opening's) and `aB` (after the group
vectors). -/
noncomputable def ebT (Rr nC aA aB : ℕ) (hab : aA ≤ aB) : XTest K (Fin Rr) (Fin (2 ^ 8 + 256)) (Fin nC) 11 where
  enc := encGL (K := K) 8 11 256
  d := 1537
  e := 768
  A := 2 ^ 11
  hd := (ep_open_code_factsU (ptsG (K := K) 11) (ptsG_injective 11 (by norm_num)) (RWL (K := K) 8)).1
  h2 := by norm_num
  hA := by norm_num
  hAN := le_rfl
  hca := (ep_open_code_factsU (ptsG (K := K) 11) (ptsG_injective 11 (by norm_num)) (RWL (K := K) 8)).2.2.2.2
  d₀ := dg0
  w0 := nC + Rr
  chalLR := lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + Rr) ≃ Fin nC ⊕ Fin Rr)
  βLR := (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * (nC + Rr))
  hLR := fun Ev => lrCode_prob_le gP (Equiv.ofBijective _ hbij) _ Ev
  m := 64
  nQ := 256
  chalJ := idxCode 11 ogEp.hQm
  βJ := 1
  hJ := fun Ev => idxCode_prob_le (by norm_num) ogEp.hQm Ev
  labB := Block.labPcsProx
  decB := proxDec U (2 ^ 8 + 256)
  aA := aA
  aB := aB
  hab := hab

variable (Rr nC aA aB : ℕ) (hab : aA ≤ aB)

/-- **The test's numbers** (`hTe`, `hTQ`, `hβJ`, `hβLR`, the windows): radius `768`, `256` queries, index bias `1`,
batching bias `(1 + p/2^128)^(2·w0)` with `w0 = nC + Rr`. -/
theorem ebT_nums : (ebT U hbij Rr nC aA aB hab).e = 768 ∧ (ebT U hbij Rr nC aA aB hab).nQ = 256
    ∧ (ebT U hbij Rr nC aA aB hab).βJ = 1
    ∧ (ebT U hbij Rr nC aA aB hab).βLR
      = (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * (ebT U hbij Rr nC aA aB hab).w0)
    ∧ (ebT U hbij Rr nC aA aB hab).w0 = nC + Rr
    ∧ (ebT U hbij Rr nC aA aB hab).aA = aA ∧ (ebT U hbij Rr nC aA aB hab).aB = aB :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- **`hTenc` for the test built from part `0`'s opening.** -/
theorem ebT_enc : (ebT U hbij Rr nC aA aB hab).enc
    = encLin (Q := 256) (fun j => algebraMap GF K (epPts j)) (rowFormK8 K) :=
  eb_enc_ep

end Test

/-! ## The test's extraction -/

section Ext

variable (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **The columns the extraction finds** (`Xx`): those at which `colXM rdx` extracts, for the root the header's
message at `i` reads as (depth `d`), a column of `rows` values (the commitment's rows: an extractor of openings of
`rows`-row columns can return exactly these, L30-5). -/
noncomputable def ebXxW (rdx : List UInt8 → Option Dig) (d i rows : ℕ) {N : ℕ} (log : List (QB Lq × Dig))
    (hdr : List (TItem × Dig)) : Finset (Fin N) :=
  Finset.univ.filter (fun j => (colXM tag Lq h64 key domain hs hL rdx d i log hdr j).map (fun c => c.val.length)
    = some rows)

/-- **`hUc`: the test's matrix is a cut reader.** -/
theorem ebUxW_cut {K : Type} [Field K] [Algebra GF K] (rdx : List UInt8 → Option Dig) (d i rows N : ℕ) :
    CutReads (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (fun P hdr => ebUxW (K := K) tag Lq h64 key domain hs hL rdx d i rows (N := N) P hdr) := by
  intro P P' hdr h
  funext r j
  show ebUxW (K := K) tag Lq h64 key domain hs hL rdx d i rows (N := N) P hdr r j
    = ebUxW (K := K) tag Lq h64 key domain hs hL rdx d i rows (N := N) P' hdr r j
  unfold ebUxW
  rw [colXM_cutEq tag Lq h64 key domain hs hL rdx d i hdr P P' h]

/-- **`hXc`: the test's column set is a cut reader.** -/
theorem ebXxW_cut (rdx : List UInt8 → Option Dig) (d i rows N : ℕ) :
    CutReads (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (fun P hdr => ebXxW tag Lq h64 key domain hs hL rdx d i rows (N := N) P hdr) := by
  intro P P' hdr h
  unfold ebXxW
  simp only [colXM_cutEq tag Lq h64 key domain hs hL rdx d i hdr P P' h]

end Ext

/-! ## The test's second half alive, from part `0`'s closing opening -/

section Alive

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

include hU in
/-- **THE COLUMN TEST'S SECOND HALF IS ALIVE WHEREVER PART `0`'S CLOSING OPENING MEETS ITS ACCEPTANCE FACTS** (`hBal`'s
route, L51-2): if the opening (at the endpoint geometry, `Rr` rows, its root read under `rdx` at `xPos`) meets
`RhOpWM` at its windows `aO`, `aB` on `τ`, then `T.cB` of the test built from it (`ebT`), with the extraction `Ux`
(`ebUxW`) and `Xx` (`ebXxW`), is alive at the end of `τ`. -/
theorem eb_xB_alive (rdx : List UInt8 → Option Dig) (W : UInt64 → ℕ) (Rr nC xPos : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig)
    (τ : List (TItem × Dig))
    (w : RhOpWM U tag Lq h64 key domain hs hL rdx W (rkAt ogEp Rr xPos) nC clr aO aB vpos P G τ) (hab : aO ≤ aB) :
    subSt W ((ebT U hbij Rr nC aO aB hab).cB W
      (fun P' hdr => ebUxW tag Lq h64 key domain hs hL rdx 11 xPos Rr P' hdr)
      (fun P' hdr => ebXxW tag Lq h64 key domain hs hL rdx 11 xPos Rr P' hdr) P) τ := by
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
  -- every sampled column is one the extraction finds
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
  have hin : ∀ k : Fin 256,
      idxCode 11 ogEp.hQm (vecOf dg0 64 ((sqDs (liftH G) ((runOps (liftH G) (runOps (liftH G) w.tA
        (List.replicate (nC + Rr) Op.squeeze)) (stpsOps (vecStps w.zo.groupVecs))).absorb (liftH G)
          Block.labPcsProx (w.zo.proxVec.flatMap Fp2.toBytes)) 64).map halves)) k
        ∈ ebXxW tag Lq h64 key domain hs hL rdx 11 xPos Rr P ((τ.take aB).take aO) := by
    intro k
    rw [List.take_take, min_eq_left hab]
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
    rw [hk1] at hx
    have hlen := congrArg (Option.map List.length) hx
    rw [Option.map_map, Option.map_some] at hlen
    exact Finset.mem_filter.mpr ⟨Finset.mem_univ _, hlen.trans (congrArg some hc.2.1)⟩
  exact xB_subSt_of_opB W aO (nC + Rr) (encGL (K := K) 8 11 256) 768
    (ebOpen U tag Lq h64 key domain hs hL rdx (rkAt ogEp Rr xPos) nC clr vpos).cl
    (fun hdr => ebUxW tag Lq h64 key domain hs hL rdx 11 xPos Rr P hdr)
    (fun hdr => ebXxW tag Lq h64 key domain hs hL rdx 11 xPos Rr P hdr)
    (vRd U (2 ^ 8 + 256) vpos) dg0
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + Rr) ≃ Fin nC ⊕ Fin Rr)) 64
    (idxCode 11 ogEp.hQm) Block.labPcsProx (proxDec U (2 ^ 8 + 256)) aB _ _ τ _ _ _ _ hrd hin hop

end Alive

end ZK60.ProtocolClassify
