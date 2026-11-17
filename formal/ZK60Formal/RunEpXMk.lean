/-
D63 lane L58 (2026-11-10), part 11: **the input endpoint's opening data and the run extractor's endpoint words, from
the checked extractor** (`mk`, `hE`; the brief's deliverable 2).

The top theorem is generic in the input commitment's opening-data type `Salt` (with `msg`, `pad`, `salt`, `path`), and
asks for a builder `mk : (CinR).SaltMk` of opening data from decoded rows and extracted salts and paths, and for the run
extractor `E` whose input endpoint words `epW` and opening data `r` are read from `ops` (`hE`). Here:

* `EpxSalt`: the input endpoint's opening data as the code keeps it (`Decommitment`: every row's words, every row's
  `256` pads, every column's salt; with the paths of its tree), at the endpoint geometry (`2^8` message words, `256`
  pads, `2^11` columns);
* `epxMsg`, **`epxMsg_place`**: row `i`'s message, the plane's row where a data row sits, the opening data's elsewhere
  (`msg_place` when the data rows' places are distinct: one data row at the code's geometry);
* **`epxMk`**: `mk` AT THAT OPENING DATA (`bld` is the constructor; its four laws hold);
* `epxE`, **`epxE_hE`**: the run extractor with `epW` and `r` read from `ops` (any `E0` for the other fields), and the
  top theorem's `hE` for it, by definition.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunEpXExt
import ZK60Formal.BindingEP

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-- **The input endpoint's opening data** (the code's `Decommitment`: data, pads, salts; with its tree's paths): every
row's `2^8` message words, every row's `256` pads, every column's salt and Merkle path. -/
structure EpxSalt (Rr : ℕ) where
  msgs : Fin Rr → Fin (2 ^ 8) → GF
  pads : Fin Rr → Fin 256 → GF
  salts : Fin (2 ^ 11) → Dig
  paths : Fin (2 ^ 11) → List Dig

section Msg

variable {T : Type} (Rr dR : ℕ) (place : Fin dR → Fin Rr) (pos : T → Fin dR × Fin (2 ^ 8))

open Classical in
/-- **Row `i`'s message**: the token plane's row where a data row sits (`place k = i`), the opening data's elsewhere. -/
noncomputable def epxMsg (v : T → ℕ) (r : EpxSalt Rr) (i : Fin Rr) : Fin (2 ^ 8) → GF :=
  if h : ∃ k, place k = i then posPlane pos v h.choose else r.msgs i

/-- **`msg_place` for it**: a data row's message is the plane's row, when the data rows' places are distinct. -/
theorem epxMsg_place (hplace : Function.Injective place) :
    ∀ v r k, epxMsg Rr dR place pos v r (place k) = posPlane pos v k := by
  intro v r k
  have hex : ∃ k', place k' = place k := ⟨k, rfl⟩
  have hc : hex.choose = k := hplace hex.choose_spec
  simp only [epxMsg, dite_eq_left hex, hc]

variable {pos} (hpos : Function.Injective pos) (hplace : Function.Injective place)

/-- **`mk` AT THE INPUT ENDPOINT'S OPENING DATA** (the top theorem's `mk`, for the commitment `epTokenCommit` with
`epxMsg` and the opening data's pads, salts and paths): opening data built from decoded rows, pads, salts and paths is
the record of them; its data rows' messages are the plane's, every other row's message is the decoded row. -/
noncomputable def epxMk {St : Type} (root : St → Dig) (tag : MTag) :
    (epTokenCommit (St := St) Rr dR hpos place (epxMsg Rr dR place pos) (epxMsg_place Rr dR place pos hplace)
      EpxSalt.pads EpxSalt.salts EpxSalt.paths root tag).SaltMk where
  bld Mg Pd sl pa := ⟨Mg, Pd, sl, pa⟩
  msg_mk v Mg Pd sl pa i hi := by
    have hne : ¬ ∃ k, place k = i := fun ⟨k, hk⟩ => hi k hk
    show epxMsg Rr dR place pos v ⟨Mg, Pd, sl, pa⟩ i = Mg i
    unfold epxMsg
    exact dite_eq_right hne
  pad_mk _ _ _ _ := rfl
  salt_mk _ _ _ _ := rfl
  path_mk _ _ _ _ := rfl

end Msg

section E

/-- **The run extractor with its input endpoint words and opening data read from `ops`**: `epW` the decoded data rows
at the layout's positions, `r` the opening data built from the decoded rows and the extracted salts and paths (`E0` for
the other fields: the boundary planes, IN-C's words, OUT-C's `x`, the second opening data). -/
noncomputable def epxE {S : BlockShape} {Hdr Salt : Type} {Lq : ℕ} (C : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt)
    (mk : C.SaltMk) (pos : S.Tok → Fin C.dR × Fin C.n)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt) :
    List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt :=
  fun lg s pf =>
    { E0 lg s pf with
      epW := fun t => (C.decodeIn (ops lg s) 768).1 (C.place (pos t).1) (pos t).2
      r := mk.bld (C.decodeIn (ops lg s) 768).1 (C.decodeIn (ops lg s) 768).2 (C.exSalt (ops lg s))
        (C.exPath (ops lg s)) }

/-- **THE TOP THEOREM'S `hE` FOR IT**, by definition. -/
theorem epxE_hE {S : BlockShape} {Hdr Salt : Type} {Lq : ℕ} (C : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt)
    (mk : C.SaltMk) (pos : S.Tok → Fin C.dR × Fin C.n)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt) :
    ∀ lg s pf, (epxE C mk pos ops E0 lg s pf).epW
        = (fun t => (C.decodeIn (ops lg s) 768).1 (C.place (pos t).1) (pos t).2)
      ∧ (epxE C mk pos ops E0 lg s pf).r = mk.bld (C.decodeIn (ops lg s) 768).1 (C.decodeIn (ops lg s) 768).2
          (C.exSalt (ops lg s)) (C.exPath (ops lg s)) :=
  fun _ _ _ => ⟨rfl, rfl⟩

end E

end ZK60.ProtocolClassify
