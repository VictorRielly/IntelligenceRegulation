/-
D63 lane L63 (2026-11-17), part 38: **the input endpoint's decoding bridge** (step (c1)).

The run's kinds data read the input endpoint as part `0`'s closing opening (`ebOpen` under `abRdIn`, L52's repair B):
its matrix is the UNCHECKED extraction `ebUxW` (`colXM`), decoded by `decodeRows` at the endpoint code `encGL 8 11 256`
and radius `768`. The top theorem's `hdzero` reads the CHECKED extractor's openings `epxOps` decoded by the input
commitment's `decodeIn`. They agree wherever `decodeIn` decodes:

* **`ssh_dec_bridge`** (the coding fact): a matrix over `K` that agrees, on at least `2^11 − 768` columns, with the
  embedded endpoint codewords of base-field rows `(Mg, Pd)` decodes (`decodeRows`) to those rows. It uses the endpoint
  code's minimum distance `1,537` and `2·768 < 1,537` (lane L48's `ep_open_code_factsU`, BindingEP.lean:176, from
  `encLin_minDist`), unique decoding `Code.Close.unique`, the code equality `eb_enc_ep` (RunEpBTest.lean:47) and the
  base-field extension `encLin_map_base` with `rowFormK8_ext_ep`.
* **`ssh_ebUx_colOf`**: where the checked extractor returns an opening at a column, the unchecked one returns its column
  (lane L52's `ebOpenX_col`), so the unchecked matrix's entry there is the checked one's.
* **`ssh_ep_bridge`**: on `decodeIn`'s existence branch for `epxAt … r`, `decodeRows` of the unchecked matrix at the
  root `r` is the embedded `decodeIn` rows (messages, then pads).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldTopPd
import ZK60Formal.RunEpBTest

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section Code

variable {K : Type} [Field K] [Fintype K] [Algebra GF K]

/-- **THE ENDPOINT CODE'S UNIQUE DECODING ON THE ROWS**: a matrix agreeing on `≥ 2^11 − 768` columns with the embedded
endpoint codewords of `(Mg, Pd)` decodes to `(Mg, Pd)`. -/
theorem ssh_dec_bridge {R : ℕ} (U : Fin R → Fin (2 ^ 11) → K) (Mg : Fin R → Fin (2 ^ 8) → GF)
    (Pd : Fin R → Fin 256 → GF) (S : Finset (Fin (2 ^ 11))) (hS : 2 ^ 11 ≤ S.card + 768)
    (hU : ∀ j ∈ S, ∀ r, U r j = algebraMap GF K (encLin (Q := 256) epPts epForm (Fin.append (Mg r) (Pd r)) j)) :
    decodeRows (encGL (K := K) 8 11 256) 768 U = fun r t => algebraMap GF K (Fin.append (Mg r) (Pd r) t) := by
  classical
  have hpts : Function.Injective (fun j => algebraMap GF K (epPts j)) :=
    (algebraMap GF K).injective.comp ep_pts_injective
  have hfacts := ep_open_code_factsU (F := K) (fun j => algebraMap GF K (epPts j)) hpts (rowFormK8 K)
  have hinj : Function.Injective (encGL (K := K) 8 11 256) := by
    rw [eb_enc_ep]; exact encLin_injective hpts (rowFormK8 K) (by norm_num) (by norm_num)
  set W : Fin R → Fin (2 ^ 11) → K :=
    fun r => encGL (K := K) 8 11 256 (fun t => algebraMap GF K (Fin.append (Mg r) (Pd r) t)) with hWdef
  have hWv : ∀ r j, W r j = algebraMap GF K (encLin (Q := 256) epPts epForm (Fin.append (Mg r) (Pd r)) j) := by
    intro r j
    show encGL (K := K) 8 11 256 (fun t => algebraMap GF K (Fin.append (Mg r) (Pd r) t)) j = _
    rw [eb_enc_ep]
    exact encLin_map_base epPts epForm (rowFormK8 K) (rowFormK8_ext_ep K) _ j
  have hWm : ∀ r, W r ∈ LinearMap.range (encGL (K := K) 8 11 256) := fun r => LinearMap.mem_range_self _ _
  have hS' : Fintype.card (Fin (2 ^ 11)) ≤ S.card + 768 := by rw [Fintype.card_fin]; exact hS
  have hUW : ∀ j ∈ S, ∀ r, U r j = W r j := fun j hj r => by rw [hU j hj r, hWv]
  have hclose : Code.Close (LinearMap.range (encGL (K := K) 8 11 256)) 768 U :=
    ⟨S, hS', fun r => Code.mem_agreeOn.mpr ⟨W r, hWm r, fun j hj => hUW j hj r⟩⟩
  obtain ⟨hT, T, hT1, hT2⟩ := closeTable_spec hclose
  have hmd : Code.MinDist (LinearMap.range (encGL (K := K) 8 11 256)) 1537 := by
    rw [eb_enc_ep]; exact hfacts.1
  have huniq : closeTable (LinearMap.range (encGL (K := K) 8 11 256)) 768 U = W :=
    Code.Close.unique hmd hfacts.2.1 hT hWm hT1 hS' hT2 hUW
  funext r t
  unfold decodeRows
  rw [huniq]
  exact congrFun (decodeWord_enc _ hinj _) t

end Code

section Ext

variable {K : Type} [Field K] [Algebra GF K] (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **Where the checked extractor returns an opening, the unchecked matrix's entry is that opening's** (lane L52's
`ebOpenX_col`: the checked extraction's column is `extractCol`'s). -/
theorem ssh_ebUx_of_epx (rd : List UInt8 → Option Dig) (d i rows N : ℕ) (r : Dig) (P : List (QB L × Dig))
    (hdr : List (TItem × Dig)) (hr : (Block.absAt hdr i).bind rd = some r) (j : Fin N)
    (o : MerkleOpening Dig Dig (ColR rows)) (ho : epxAt tag L h64 key domain hs hL rd d rows r P j.val = some o)
    (row : Fin rows) :
    ebUxW (K := K) tag L h64 key domain hs hL rd d i rows (N := N) P hdr row j = algebraMap GF K (colGF o.col row) := by
  unfold epxAt at ho
  obtain ⟨o0, h1, h2⟩ := Option.bind_eq_some_iff.mp ho
  by_cases hc : o0.col.1.length = rows ∧ ∀ a ∈ o0.col.1, a.Canon
  · rw [dite_eq_left hc] at h2
    have h2' := Option.some.inj h2
    subst h2'
    have hx := (merkleEncV tag L h64).ebOpenX_col _ _ _ _ o0 h1
    unfold ebUxW colXM
    rw [hr]
    dsimp only
    rw [hx]
    unfold colGF
    simp only [Option.map_some, Option.getD_some]
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [hc.1]; exact row.isLt), Option.getD_some]
  · rw [dite_eq_right hc] at h2
    cases h2

end Ext

section Bridge

variable {K : Type} [Field K] [Fintype K] [Algebra GF K] (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **THE INPUT ENDPOINT'S DECODING BRIDGE**: on `decodeIn`'s existence branch for the checked extractor's openings at
the root `r` (on the whole log `P`), the unchecked matrix read at a header whose position `1` reads as `r` decodes
(`decodeRows`, endpoint code, radius `768`) to `decodeIn`'s rows, messages then pads. -/
theorem ssh_ep_bridge {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 8)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tagc : MTag)
    (r : Dig) (P : List (QB L × Dig)) (hdr : List (TItem × Dig)) (hr : (Block.absAt hdr 1).bind abRdIn = some r)
    (hex : ∃ (Mg : Fin R → Fin (2 ^ 8) → GF) (Pd : Fin R → Fin 256 → GF) (S : Finset (Fin (2 ^ 11))),
      2 ^ 11 ≤ S.card + 768 ∧ ∀ j ∈ S, ∃ o, epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val = some o
        ∧ o.col = (epTokenCommit R dR hpos place msg msg_place pad salt path root tagc).colOf Mg Pd j) :
    decodeRows (encGL (K := K) 8 11 256) 768
        (ebUxW (K := K) tag L h64 key domain hs hL abRdIn 11 1 R (N := 2 ^ 11) P hdr)
      = fun row t => algebraMap GF K (Fin.append
          (((epTokenCommit R dR hpos place msg msg_place pad salt path root tagc).decodeIn
            (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val) 768).1 row)
          (((epTokenCommit R dR hpos place msg msg_place pad salt path root tagc).decodeIn
            (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val) 768).2 row) t) := by
  set C := epTokenCommit R dR hpos place msg msg_place pad salt path root tagc with hC
  obtain ⟨S, hS, hag⟩ := C.decodeIn_spec (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val) 768 hex
  refine ssh_dec_bridge _ _ _ S hS (fun j hj row => ?_)
  obtain ⟨o, ho, hoc⟩ := hag j hj
  rw [ssh_ebUx_of_epx tag L h64 key domain hs hL abRdIn 11 1 R (2 ^ 11) r P hdr hr j o ho row, hoc]
  congr 1
  have h1 : colGF (C.colOf (C.decodeIn (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val) 768).1
      (C.decodeIn (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val) 768).2 j) row
      = encWord epPts epForm
        ((C.decodeIn (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val) 768).1 row)
        ((C.decodeIn (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r P j.val) 768).2 row) j := by
    unfold colGF PlaneCommit.colOf
    simp only [List.getElem_ofFn]
    exact Fp.toGF_ofGF _
  refine h1.trans ?_
  rw [encLin_apply]
  unfold encWord
  congr 2 <;> funext i
  · exact (Fin.append_left _ _ _).symm
  · exact (Fin.append_right _ _ _).symm

end Bridge

end ZK60.ProtocolClassify
