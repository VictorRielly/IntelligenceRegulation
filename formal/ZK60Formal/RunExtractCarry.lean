/-
D63 lane L45 (2026-11-10), part 9: **the carry's content between two parts** (finding L43-3, deliverable 3's first
step).

L34's `RtRun.accept_part` gives, for each part on its own, the carry it was handed (meeting the part's invariant, which
holds only the pending claims' COUNT) and the carry it handed on, as two unrelated witnesses; so the closing opening of
part `i + 1` (which opens the commitment part `i` committed, on the claims part `i` left pending) could not be tied to
part `i`'s accumulator. Here the two consecutive steps are taken from ONE run of the segments:

* **`rx_accept_two`**: on an accepted run, for consecutive parts `i`, `i + 1`, the verifier ran part `i`'s framed step
  from a carry meeting `Inv i` on the transcript of the run's steps before part `i`, and part `i + 1`'s step FROM THE
  CARRY AND THE TRANSCRIPT PART `i` HANDED ON.

With L29's step lemmas (`inSegExec_step_ok_iff`: stage IN-C hands on `⟨acc.claims.out, B_in's root⟩`;
`d12a_blockSeg_step_ok_iff`: block `k` hands on its outgoing claims and its boundary root) this is the content of the
carry `rkData`'s closing-opening reader assumes (`rkPend acc i = (acc (i - 1)).claims.out`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunExtractParts

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code

section Two

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **TWO CONSECUTIVE PARTS OF AN ACCEPTED RUN, ON ONE CARRY** (the content of the carry between parts, finding
L43-3). -/
theorem rx_accept_two (R : RtRun V key domain Lq) (H : HIn → Dig) (s : ClsStmt Hdr) (segs : List (List UInt8))
    (hacc : classifyVerifyE V H s segs = .ok ()) (i : ℕ) (σ σ' : RtSeg (ClsStmt Hdr)) (hσ : R.σs[i]? = some σ)
    (hσ' : R.σs[i + 1]? = some σ') :
    ∃ (cr cr' cr'' : Carry) (t t' t'' : Tr), R.Inv i cr
      ∧ t = runOps H (Tr.newKeyed H domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i))
      ∧ segStep σ.v H s (V.start H s).state (segs.getD i []) cr t = .ok (cr', t')
      ∧ segStep σ'.v H s (V.start H s).state (segs.getD (i + 1) []) cr' t' = .ok (cr'', t'') := by
  unfold classifyVerifyE at hacc
  simp only [ex_bind_ok_iff, countOk_eq_ok] at hacc
  obtain ⟨⟨⟩, -, ⟨⟩, -, ⟨⟩, -, ⟨crF, tF⟩, hr, -⟩ := hacc
  rw [runSegs_ok_iff, ← R.hv] at hr
  obtain ⟨hi, hσe⟩ := List.getElem?_eq_some_iff.mp hσ
  obtain ⟨hi', hσe'⟩ := List.getElem?_eq_some_iff.mp hσ'
  have hsplit : R.σs.map (fun σ => σ.v)
      = (R.σs.take i).map (fun σ => σ.v) ++ (σ.v :: σ'.v :: (R.σs.drop (i + 1 + 1)).map (fun σ => σ.v)) := by
    conv_lhs => rw [← List.take_append_drop i R.σs]
    rw [List.map_append, List.drop_eq_getElem_cons hi, hσe, List.drop_eq_getElem_cons hi', hσe', List.map_cons,
      List.map_cons]
  rw [hsplit, segsOk_append] at hr
  obtain ⟨cr, t, hpre, hpost⟩ := hr
  have hlen : ((R.σs.take i).map (fun σ => σ.v)).length = i := by
    rw [List.length_map, List.length_take]
    omega
  rw [hlen] at hpre hpost
  rcases hd : segs.drop i with _ | ⟨b, bs⟩
  · rw [hd] at hpost
    exact False.elim hpost
  · rw [hd] at hpost
    obtain ⟨cr', t', hstep, hpost2⟩ := hpost
    rcases bs with _ | ⟨b', bs'⟩
    · exact False.elim hpost2
    · obtain ⟨cr'', t'', hstep2, -⟩ := hpost2
      have hb : segs[i]? = some b := rt_drop_cons_getElem? segs i b (b' :: bs') hd
      have hb' : segs[i + 1]? = some b' := by
        have h1 : (segs.drop i)[1]? = some b' := by rw [hd]; rfl
        rw [List.getElem?_drop] at h1
        exact h1
      have hgd : segs.getD i [] = b := by
        rw [List.getD_eq_getElem?_getD, hb]
        rfl
      have hgd' : segs.getD (i + 1) [] = b' := by
        rw [List.getD_eq_getElem?_getD, hb']
        rfl
      obtain ⟨e, -, inv⟩ := rt_segsOk Lq H s (V.start H s).state R.Inv (R.σs.take i) 0 (segs.take i) carry0
        (V.start H s) cr t
        (fun j σ'' hj => by
          have hj' : R.σs[j]? = some σ'' := by
            rw [List.getElem?_take] at hj
            split_ifs at hj with hji
            exact hj
          simpa using R.hσ j σ'' hj') R.hInv0 hpre
      have hli : (R.σs.take i).length = i := by
        rw [List.length_take]
        omega
      refine ⟨cr, cr', cr'', t, t', t'', ?_, ?_, ?_, ?_⟩
      · rw [hli] at inv
        simpa using inv
      · have e' : stpsOps (rtPre R.pf (R.rd (s, segs)) i)
            = R.hdr s ++ stpsOps (rtPartsStps ((R.σs.take i).map (fun σ => σ.p))
                (List.zipWith (fun σ b => σ.rd s b) (R.σs.take i) (segs.take i))) := by
          show stpsOps (opsStps (R.hdr s) ++ rtPartsStps ((R.σs.map (fun σ => σ.p)).take i)
            ((List.zipWith (fun σ b => σ.rd s b) R.σs segs).take i)) = _
          rw [stpsOps_append, stpsOps_opsStps, ← List.map_take, rt_take_zipWith]
        rw [e', runOps_append, ← R.hstart]
        exact e
      · rw [hgd]
        exact hstep
      · rw [hgd']
        exact hstep2

end Two

end ZK60.ProtocolClassify
