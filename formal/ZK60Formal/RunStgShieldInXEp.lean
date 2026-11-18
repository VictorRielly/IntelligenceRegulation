/-
D63 lane L63 (2026-11-18), part 75: **`shd_hdinX_gen`'s two readers at the wrapped run extractor, as GENERIC lemmas**
(applied at the concrete top by unification: an `rfl` on the concrete extractor exceeds the elaborator's recursion
depth, HANDOFF_20261118_1.md section 4).

* **`epxIO_hXI`**: on `decodeIn`'s existence branch for the checked extractor's openings `epxOps` at the statement's
  input root, the input endpoint matrix `epUxV` at a header showing that root, at a token's entry, is the wrapped
  extractor's token word (`epxIO_tokW`, `epUxV_tokW`);
* **`epxIO_hpl`**: the wrapped extractor's plane `0` at a position is the `B_in` plane at a reading's head view
  (`epxIO_planes`, `bndPlanes0_head`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldInXRun
import ZK60Formal.RunStgShieldEpxIO

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.Exec.StageV
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Ep

variable {K : Type} [Field K] [Fintype K] [Algebra GF K] {Hdr Salt : Type} {Lq : ℕ}

/-- **`hXI` at the wrapped extractor**: on `decodeIn`'s existence branch, `epUxV` at a token's entry is its token word. -/
theorem epxIO_hXI (R dR : ℕ) {pos : shieldS0.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
    (place : Fin dR → Fin R) (msg : (shieldS0.Tok → ℕ) → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (tagc : MTag)
    (mk : (epTokenCommit R dR hpos place msg msg_place pad salt path (ClsStmt.inRoot (Hdr := Hdr)) tagc).SaltMk)
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (pf : RtProf)
    (rd : ClsStmt Hdr × ClsReceipt → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)) (Lb : ℕ) (prow : shieldS0.Tok)
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt)
    (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) (hdr : List (TItem × Dig)) (x : List UInt8)
    (r : Dig) (hx : Block.absAt hdr 1 = some x) (hr : abRdIn x = some r) (hsr : s.inRoot = r)
    (hex : ∃ (Mg : Fin R → Fin (2 ^ 8) → GF) (Pd : Fin R → Fin 256 → GF) (S : Finset (Fin (2 ^ 11))),
      2 ^ 11 ≤ S.card + 768 ∧ ∀ j ∈ S, ∃ o,
        epxOps (Hdr := Hdr) tag Lq h64 key domain hs hL abRdIn 11 R (N := 2 ^ 11) lg s j = some o
        ∧ o.col = (epTokenCommit R dR hpos place msg msg_place pad salt path (ClsStmt.inRoot (Hdr := Hdr)) tagc).colOf
          Mg Pd j)
    (t : shieldS0.Tok) (row : Fin R) (col : Fin (2 ^ 8 + 256)) (hrow : row = place (pos t).1)
    (hcol : col.val = (pos t).2.val) :
    epUxV (K := K) tag Lq h64 key domain hs hL R (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg hdr)
        row col
      = algebraMap GF K ((epxE (epTokenCommit R dR hpos place msg msg_place pad salt path (ClsStmt.inRoot (Hdr := Hdr))
          tagc) mk pos (epxOps (Hdr := Hdr) tag Lq h64 key domain hs hL abRdIn 11 R (N := 2 ^ 11))
          (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
            (epxIOE (epTokenCommit R dR hpos place msg msg_place pad salt path (ClsStmt.inRoot (Hdr := Hdr)) tagc) pos
              (epxOps (Hdr := Hdr) tag Lq h64 key domain hs hL abRdIn 11 R (N := 2 ^ 11)) U tag h64 key domain hs hL
              pf rd D dPos0 Lb prow E0)) lg s rc).tokW t) := by
  subst hsr
  exact epUxV_tokW tag Lq h64 key domain hs hL R dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc
    s.inRoot lg hdr x hx hr hex t row col hrow hcol

omit [Fintype K] in
/-- **`hpl` at the wrapped extractor**: plane `0` at a position is the `B_in` plane at a reading's head view. -/
theorem epxIO_hpl (C : PlaneCommit (shieldS0.Tok → ℕ) (ClsStmt Hdr) Salt) (mk : C.SaltMk)
    (pos : shieldS0.Tok → Fin C.dR × Fin C.n)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (pf : RtProf)
    (rd : ClsStmt Hdr × ClsReceipt → List Op × List RtData)
    (D : RtKData K Lq) (Lb : ℕ) (prow : shieldS0.Tok)
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt)
    (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) (o : ClsStmt Hdr × ClsReceipt) (ho : (s, rc) = o)
    (hg : (D.opX 1).h = 16 ∧ (D.opX 1).lc = 14 ∧ (D.opX 1).Q = 256 ∧ (D.opX 1).e = 24448 ∧ (D.opX 1).rows = 38)
    (G : QB Lq → Dig) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G (rtTr key domain Lq pf rd G o) hdr core ch rs)
    (hj : pf.off 0 + 2 < hdrLen + 4)
    (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iA : ℕ) (p : shieldS0.Pos) :
    ((epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D shieldDPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D shieldDPos0 Lb prow E0)) lg s rc).planes 0) p
      = (shdIncData U tag h64 P I Epad (pf.off 0 + 2) iA
          (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
            (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))).X p.1
          (msbBits 12 p.2.val) := by
  subst ho
  rw [epxIO_planes]
  exact bndPlanes0_head U tag h64 key domain hs hL pf rd D lg (s, rc) hg G Pof m hdrLen bgaOf hdr core ch rs hrd hj
    P I Epad iA p.1 p.2

end Ep

end ZK60.ProtocolClassify
