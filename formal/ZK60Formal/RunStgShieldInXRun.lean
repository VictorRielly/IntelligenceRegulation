/-
D63 lane L63 (2026-11-18), part 73: **`hdinX`'s contrapositive at a reading, generic in the stage** (HANDOFF_20261118_4.md
section 5 step 1, pieces (a) to (d)).

At a reading of stage IN-C where every drawing slot's define state and the head's LogUp state are alive:
* (a) slot `0` alive: INC-00's define polynomial vanishes, so at every token position the input endpoint's entry IS the
  `A_in` token plane (`ssh_inc0_Φ_tok`); the token words `tokW` the extractor reads are those entries (hypothesis
  `hXI`, which the concrete top meets on `decodeIn`'s existence branch, see finding L63-11);
* (b) slots `1`, `2` alive: SIC_QZC's clauses (`shd_inc_qt`), so the token plane is the public BOS at position `0` and
  the template id at every template position (`incBosTmpl_of_qzc`, `shdIncLay_bosTmpl`);
* (c) LogUp alive: `InGood` of the projected data (`stgLkInK_iff`, `not_stgLkInK_nil_of_not_inGood`);
* (d) `InSat` of the token words and the `B_in` plane (`in_inSat`), the plane read at the head view (hypothesis `hpl`,
  the concrete top's `bndPlanes0_head`).

* `stg_inc_def_zero_al`: `stg_inc_def_zero` from the reading's alive define state (no run-level entrant);
* `shdIncData_head`: the projected data at the head view is the data at `τ`'s;
* **`shd_inSat_rd`**: the four pieces joined: `InSat P tokW planes`;
* **`shd_hdinX_gen`**: `¬ InSat P tokW planes` ⇒ `StgDoomAtV …` (hdinX's conclusion), by contradiction at each reading.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldInX

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Head

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ} (U : K) (tag : MTag) (h64 : 64 ≤ Lq)

/-- **The projected IN-C data reads the view below `n`.** -/
theorem vwLoc_shdIncData (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF)
    (iB iA n : ℕ) (hA : iA < n) (hB : iB < n) :
    VwLoc n (shdIncData U tag h64 P I Epad iB iA) := by
  intro v v' h1 h2
  have eA : ∀ lc h Q e r, stgIOX (K := K) tag h64 lc h Q e r iA v = stgIOX tag h64 lc h Q e r iA v' :=
    fun lc h Q e r => stgIOX_loc tag h64 lc h Q e r iA n hA v v' h1 h2
  have eB : ∀ lc h Q e r, stgIOX (K := K) tag h64 lc h Q e r iB v = stgIOX tag h64 lc h Q e r iB v' :=
    fun lc h Q e r => stgIOX_loc tag h64 lc h Q e r iB n hB v v' h1 h2
  simp only [shdIncData, stgPlB, eA, eB]

/-- **At a reading, the projected data at the head's view is the data at `τ`'s view.** -/
theorem shdIncData_head (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF)
    (iB hdrLen : ℕ) (hB : iB < hdrLen + 4) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (G : QB Lq → Dig) (Lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs) :
    shdIncData U tag h64 P I Epad iB hdrLen
        (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = shdIncData U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) := by
  obtain ⟨h1, -⟩ := stg_rd_head key domain Pof 15 hdrLen bgaOf G τ hdr core ch rs hrd
  rw [← h1]
  exact vw_take absOf Lg (hdrLen + 4) (hdrLen + 4) le_rfl _
    (vwLoc_shdIncData U tag h64 P I Epad iB hdrLen (hdrLen + 4) (by omega) hB) τ

/-- **At a reading, a matrix extracted below the head reads the same at the head's view and at `τ`'s.** -/
theorem stgIOX_head (lc h Q e r i hdrLen : ℕ) (hi : i < hdrLen + 4) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (G : QB Lq → Dig) (Lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs) :
    stgIOX (K := K) tag h64 lc h Q e r i
        (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = stgIOX tag h64 lc h Q e r i (stgVw absOf Lg τ) := by
  obtain ⟨h1, -⟩ := stg_rd_head key domain Pof 15 hdrLen bgaOf G τ hdr core ch rs hrd
  rw [← h1]
  exact vw_take absOf Lg (hdrLen + 4) (hdrLen + 4) le_rfl _
    (fun v v' e1 e2 => stgIOX_loc tag h64 lc h Q e r i (hdrLen + 4) hi v v' e1 e2) τ

/-- **At a reading, the token plane at the head's view is the one at `τ`'s view.** -/
theorem shdIncDataK_tok_head (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF)
    (iB hdrLen : ℕ) (_hB : iB < hdrLen + 4) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (G : QB Lq → Dig) (Lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs) (t : shieldS0.Tok) :
    (shdIncDataK U tag h64 P I Epad iB hdrLen
        (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))).tok t
      = (shdIncDataK U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ)).tok t := by
  simp only [shdIncDataK, stgPlK]
  rw [stgIOX_head tag h64 _ _ _ _ _ hdrLen hdrLen (by omega) key domain Pof bgaOf absOf G Lg τ hdr core ch rs hrd]

/-- **The join (d)**: a good lookup of the projected data at a view, with the BOS and template facts and the token plane
the token words `tokW`, is `InSat` of `tokW` and the `B_in` plane at the column bits `msbBits 12 i`. -/
theorem shd_inSat_join (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF)
    (hE : ∀ (j : Fin P.V) (i : shieldS0.Wid), Epad j (msbBits 12 i.val) = (P.emb j i : GF))
    (iB iA : ℕ) (v : StgVw Lq) (tokW : shieldS0.Tok → GF)
    (hgood : InGood (shdIncData U tag h64 P I Epad iB iA v))
    (hb : ∀ t : shieldS0.Tok, (t : ℕ) = 0 → (shdIncDataK U tag h64 P I Epad iB iA v).tok t = ((P.bos : ℕ) : K))
    (ht : ∀ t : shieldS0.Tok, P.isT t = true →
      (shdIncDataK U tag h64 P I Epad iB iA v).tok t = ((P.kap t : ℕ) : K))
    (htk : ∀ t : shieldS0.Tok, (shdIncDataK U tag h64 P I Epad iB iA v).tok t = algebraMap GF K (tokW t)) :
    InSat P tokW (fun p => (shdIncData U tag h64 P I Epad iB iA v).X p.1 (msbBits 12 p.2.val)) := by
  have htw : (fun t => (shdIncData U tag h64 P I Epad iB iA v).tok t) = tokW := by
    funext t
    rw [shdIncData_proj_tok, htk t, Exec.Block.Join.W16.piB_alg]
  have hsat := in_inSat P 12 (tagEmb : GF) (fun t => (shdIncData U tag h64 P I Epad iB iA v).tok t)
    (fun t c => (shdIncData U tag h64 P I Epad iB iA v).X t c) Epad
    (fun j => (shdIncData U tag h64 P I Epad iB iA v).m j) (fun i => msbBits 12 i.val) hE hgood
    (fun t h0 => by
      show (shdIncData U tag h64 P I Epad iB iA v).tok t = _
      rw [shdIncData_proj_tok, hb t h0, lay_natCast_alg, Exec.Block.Join.W16.piB_alg])
    (fun t hi => by
      show (shdIncData U tag h64 P I Epad iB iA v).tok t = _
      rw [shdIncData_proj_tok, ht t hi, lay_natCast_alg, Exec.Block.Join.W16.piB_alg])
  rw [htw] at hsat
  exact hsat

end Head

section Zero

variable {K : Type} [Field K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **AN ALIVE DEFINE STATE AT A READING: STAGE IN-C'S DEFINE POLYNOMIAL VANISHES AT EVERY DRAW**, over the claims at
`τ`'s view (`stg_inc_def_zero` with the reading's alive state in place of the run-level entrant). -/
theorem stg_inc_def_zero_al (tag : MTag) (h64 : 64 ≤ Lq)
    (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 15)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      G τ hdr core ch rs)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hgt : (Vi.bp (incCtx Vi.pub ch)).geom.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.terms.length)
    (hgeom : ∀ k, k < (Vi.bp (incCtx Vi.pub ch)).geom.slots.length →
      1 ≤ (Block.slotShape (Vi.bp (incCtx Vi.pub ch)) k).2.2)
    (k : ℕ) (hk : k ∈ stgDrawing P0)
    (hal : (stgDefSqV P0 15 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 lc h Q e rA rH csIO) sshDgI k).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Vi.bp (incCtx Vi.pub ch)) core 15
          ++ Block.fullOps (Vi.bp (incCtx Vi.pub ch)) 0 (core.slots.take k))) []) :
    ∀ y : Fin (P0.draws k) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ))
      (Fp2.zero, Fp2.zero, Fp2.zero) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 := by
  have hslen : core.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← hP.2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  have hz := stg_def_zero_of_alive key domain P0 (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 lc h Q e rA rH csIO) sshDgI G lg τ
    hdr core ch rs hrd hP hgeom hgt k hkl.le hal
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
  obtain ⟨h1, -⟩ := stg_rd_def key domain (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G τ hdr core ch rs hrd hgt k q hq
  have hcsv : stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) csIO
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Vi.bp (incCtx Vi.pub ch)) core 15
            ++ Block.fullOps (Vi.bp (incCtx Vi.pub ch)) 0 (core.slots.take k))))
      = stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) := by
    rw [← h1]
    exact vw_take _ lg (hdrLen + (7 + 15)) _ (by unfold stgDefPos; omega) _
      (vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) _ (by omega) (by omega) csIO hIOl) τ
  intro y
  rw [← hcsv]
  exact hz y

end Zero

section Sat

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **(c) An alive head LogUp state is a good lookup** of the projected data at its view. -/
theorem shd_inGood_of_lu (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (hPV : P.Valid) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB hdrLen eI : ℕ) (absOf : QB Lq → Option (List UInt8))
    (lg : List (QB Lq × Dig)) (tr : List (TItem × Dig))
    (hlu : (stgLkSqV 15 hdrLen eI absOf (shd_ΛI U tag h64 P I Epad iB hdrLen)).St lg tr []) :
    InGood (shdIncData U tag h64 P I Epad iB hdrLen (stgVw absOf lg tr)) := by
  by_contra hbad
  exact not_stgLkInK_nil_of_not_inGood U tag h64 P I Epad iB hdrLen (stgVw absOf lg tr) hPV hbad
    ((stgLkInK_iff U tag h64 P I Epad iB hdrLen (stgVw absOf lg tr) []).mpr hlu)

omit [Fintype K] [DecidableEq K] in
/-- **(b) SIC_QZC's define polynomial vanishing gives the BOS and template facts** of the token plane at the view. -/
theorem shd_bt_rd (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0)
    (P0 : Block.BlockParams) (Vi : IncV) (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB hdrLen rH Rr : ℕ)
    (XI : StgVw Lq → Fin Rr → Fin (2 ^ 8 + 256) → K) (w : StgVw Lq)
    (ch : List Fp2) (hl : ch.length = 15) (hch : ∀ a ∈ ch, a.Canon) (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hti : Vi.pub.tiLog = 12) (hvoc : Vi.pub.vocLog = 17) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19)
    (hGb : Vi.geo.bLogN = 14) (hlt : Vi.pub.lt ≤ ogStage.lc) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hbos : Vi.pub.bos < 2 ^ 63) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hvP : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    (hbosP : Vi.pub.bos = P.bos) (hTP : ∀ t : shieldS0.Tok, Vi.pub.isTemplate t.val = P.isT t)
    (hkP : ∀ t : shieldS0.Tok, Vi.pub.kappa t.val = P.kap t)
    (hd1 hd2 : List (List Fp2)) (hhd1 : hd1.length = 1) (hhd2 : hd2.length = 2)
    (hz1 : ∀ y : Fin (P0.draws 1) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH hdrLen (hdrLen + 4 + 15)
        (stgCsIOm U Rr 8 256 38 14 256 XI (bxUxV tag Lq h64 38 iB)) w)
      (Fp2.zero, Fp2.zero, Fp2.zero) hd1 1 (stgWords U hbij y) = 0)
    (hz2 : ∀ y : Fin (P0.draws 2) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH hdrLen (hdrLen + 4 + 15)
        (stgCsIOm U Rr 8 256 38 14 256 XI (bxUxV tag Lq h64 38 iB)) w)
      (Fp2.zero, Fp2.zero, Fp2.zero) hd2 2 (stgWords U hbij y) = 0) :
    (∀ t : shieldS0.Tok, (t : ℕ) = 0 →
        (shdIncDataK U tag h64 P Vi.pub Epad iB hdrLen w).tok t = ((P.bos : ℕ) : K))
      ∧ (∀ t : shieldS0.Tok, P.isT t = true →
        (shdIncDataK U tag h64 P Vi.pub Epad iB hdrLen w).tok t = ((P.kap t : ℕ) : K)) := by
  obtain ⟨hq, -⟩ := shd_inc_qt U hbij tag h64 hU P P0 Vi Epad iB hdrLen 41 rH (hdrLen + 4 + 15) 38 rfl rfl
    (stgCsIOm U Rr 8 256 38 14 256 XI (bxUxV tag Lq h64 38 iB)) w (fun _ => rfl)
    (ssh_hIO1m U hbij hU Vi Rr 8 256 38 14 256 XI (bxUxV tag Lq h64 38 iB) (le_of_eq hGb))
    ch hl hch hP hti hvoc htB hbIn hGb hlt hlc hbos hkap hns hVV hEmb hvP hV htok hcq hd1 hd2 hhd1 hhd2 hz1 hz2
  exact shdIncLay_bosTmpl U tag h64 P Vi.pub Epad iB hdrLen w hvP hV htok hcq hbosP hTP hkP
    (incBosTmpl_of_qzc (RingHom.id K) _ _ (incChalOf U ch) _ hq)

omit [Fintype K] [DecidableEq K] in
/-- **(a) INC-00's define polynomial vanishing: the `A_in` token plane at every token position is the input endpoint's
entry, hence the token word** (when the endpoint's entries at the view are the words, `hXI`). -/
theorem shd_tok_rd (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ Lq) (P0 : Block.BlockParams) (Vi : IncV)
    (ch : List Fp2) (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch))) (hdrLen iB rH Rr : ℕ) (hRr : 0 < Rr)
    (XI : StgVw Lq → Fin Rr → Fin (2 ^ 8 + 256) → K) (w : StgVw Lq) (hlt : Vi.pub.lt ≤ ogStage.lc)
    (hrl : 0 < (Vi.bp (incCtx Vi.pub ch)).logCols)
    (hep : Vi.pub.epLogN = 8) (hpow : 2 ^ clog2 Vi.pub.inEpWords = Vi.pub.inEpWords)
    (hti : Vi.pub.tiLog = 12) (hlw8 : clog2 Vi.pub.inEpWords = 8) (htok : Vi.pub.tokens = 128)
    (hGb : Vi.geo.bLogN = 14) (tokW : shieldS0.Tok → GF)
    (hXI : ∀ (t : shieldS0.Tok) (hr : t.val / 2 ^ 8 < Rr) (hc : t.val % 2 ^ 8 < 2 ^ 8 + 256),
      XI w ⟨t.val / 2 ^ 8, hr⟩ ⟨t.val % 2 ^ 8, hc⟩ = algebraMap GF K (tokW t))
    (hz0 : ∀ y : Fin (P0.draws 0) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH hdrLen (hdrLen + 4 + 15)
        (stgCsIOm U Rr 8 256 38 14 256 XI (bxUxV tag Lq h64 38 iB)) w)
      (Fp2.zero, Fp2.zero, Fp2.zero) [] 0 (stgWords U hbij y) = 0) :
    ∀ t : shieldS0.Tok, stgPlK U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 hdrLen
      ((incLay Vi.pub 14).aOff incA_TOK) 12 w (msbBits 12 t.val) = algebraMap GF K (tokW t) := by
  intro t
  have ht : t.val < 128 := t.isLt
  have hinw : Vi.pub.inEpWords = 256 := by rw [← hpow, hlw8]; norm_num
  have hR : t.val / 2 ^ 8 < Rr := by rw [Nat.div_eq_of_lt (by omega)]; exact hRr
  have h0 := hz0 (fun a => (bit (mb (clog2 Vi.pub.inEpWords) t.val a) : K))
  rw [ssh_inc0_Φ_tok U hbij tag h64 hU P0 Vi ch hP ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH
      hdrLen (hdrLen + 4 + 15) Rr 38 14 256 XI (bxUxV tag Lq h64 38 iB) w hlt (by decide) hrl hep hpow hti hlw8
      t.val (by rw [htok]; exact ht) (by rw [hinw]; omega) hR, hXI t hR] at h0
  rw [← hGb]
  exact (sub_eq_zero.mp h0).symm

/-- **`InSat` AT A READING WHERE THE DRAWING DEFINE STATES AND THE LOGUP STATE ARE ALIVE** (stage IN-C's registered
numbers; the token words `tokW` are the input endpoint's entries at the run's view, `hXI`; the plane is read at the
head view, `hpl`). -/
theorem shd_inSat_rd (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0)
    (hPV : P.Valid) (P0 : Block.BlockParams) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (hE : ∀ (j : Fin P.V) (i : shieldS0.Wid), Epad j (msbBits 12 i.val) = (P.emb j i : GF))
    (n0 hdrLen iB rH rX Rr : ℕ) (hB : iB < hdrLen + 4) (hrX : rX = 38) (hRr : 0 < Rr)
    (XI : StgVw Lq → Fin Rr → Fin (2 ^ 8 + 256) → K)
    (hIOl : VwLoc (hdrLen + (7 + 15)) (stgCsIOm U Rr 8 256 rX 14 256 XI (bxUxV tag Lq h64 rX iB)))
    (hP : ∀ ch, StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hgt : ∀ ch, (Vi.bp (incCtx Vi.pub ch)).geom.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.terms.length)
    (hgeom : ∀ ch k, k < (Vi.bp (incCtx Vi.pub ch)).geom.slots.length →
      1 ≤ (Block.slotShape (Vi.bp (incCtx Vi.pub ch)) k).2.2)
    (hsl : 3 ≤ P0.geom.slots.length) (hd0 : 0 < P0.draws 0) (hd1 : 0 < P0.draws 1) (hd2 : 0 < P0.draws 2)
    (hti : Vi.pub.tiLog = 12) (hvoc : Vi.pub.vocLog = 17) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19)
    (hGb : Vi.geo.bLogN = 14) (hlt : Vi.pub.lt ≤ ogStage.lc) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hbos : Vi.pub.bos < 2 ^ 63) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hvP : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    (hbosP : Vi.pub.bos = P.bos) (hTP : ∀ t : shieldS0.Tok, Vi.pub.isTemplate t.val = P.isT t)
    (hkP : ∀ t : shieldS0.Tok, Vi.pub.kappa t.val = P.kap t)
    (hep : Vi.pub.epLogN = 8) (hpow : 2 ^ clog2 Vi.pub.inEpWords = Vi.pub.inEpWords)
    (hlw8 : clog2 Vi.pub.inEpWords = 8)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (eI : ℕ)
    (tokW : shieldS0.Tok → GF)
    (hXI : ∀ (t : shieldS0.Tok) (hr : t.val / 2 ^ 8 < Rr) (hc : t.val % 2 ^ 8 < 2 ^ 8 + 256),
      XI (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) ⟨t.val / 2 ^ 8, hr⟩ ⟨t.val % 2 ^ 8, hc⟩
        = algebraMap GF K (tokW t))
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      G τ hdr core ch rs)
    (hal : ∀ k ∈ stgDrawing P0, (stgDefSqV P0 15 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH
          (stgCsIOm U Rr 8 256 rX 14 256 XI (bxUxV tag Lq h64 rX iB))) sshDgI k).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Vi.bp (incCtx Vi.pub ch)) core 15
          ++ Block.fullOps (Vi.bp (incCtx Vi.pub ch)) 0 (core.slots.take k))) [])
    (hlu : (stgLkSqV 15 hdrLen eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (shd_ΛI U tag h64 P Vi.pub Epad iB hdrLen)).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Vi.bp (incCtx Vi.pub ch)) core)) []) :
    InSat P tokW (fun p => (shdIncData U tag h64 P Vi.pub Epad iB hdrLen
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ Block.rootOpsA (Vi.bp (incCtx Vi.pub ch)) core)))).X p.1 (msbBits 12 p.2.val)) := by
  subst hrX
  obtain ⟨hch, hl⟩ := stg_rd_chal key domain _ 15 hdrLen _ G τ hdr core ch rs hrd
  have hmem : ∀ k, k < 3 → 0 < P0.draws k → k ∈ stgDrawing P0 := fun k hk hdk =>
    List.mem_filter.mpr ⟨List.mem_range.mpr (by omega), by simpa using hdk⟩
  have hslen : core.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.slots.length := hrd.2.2.2.1.1
  obtain ⟨acc, t', hacc⟩ := hrd.2.2.2.2.1
  have hrsl : rs.length = core.slots.length :=
    (ssh_rd_facts key domain _ 15 hdrLen _ G τ hdr core ch rs hrd (hgt ch) (hgeom ch) acc t' hacc).1
  have hcore3 : 3 ≤ rs.length := by rw [hrsl, hslen, ← (hP ch).2]; exact hsl
  have hz : ∀ k, k < 3 → 0 < P0.draws k → ∀ y : Fin (P0.draws k) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch))
      (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH hdrLen (hdrLen + 4 + 15)
        (stgCsIOm U Rr 8 256 38 14 256 XI (bxUxV tag Lq h64 38 iB))
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ))
      (Fp2.zero, Fp2.zero, Fp2.zero) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 :=
    fun k hk hdk => stg_inc_def_zero_al key domain hs Lq hL U hbij tag h64 P0 Vi n0 hdrLen
      ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH _ hIOl G lg τ hdr core ch rs hrd (hP ch) (hgt ch)
      (hgeom ch) k (hmem k hk hdk) (hal k (hmem k hk hdk))
  -- (b) SIC_QZC: the BOS and template facts at `τ`'s view
  obtain ⟨hbK, htK⟩ := shd_bt_rd Lq U hbij hU tag h64 P P0 Vi Epad iB hdrLen rH Rr XI
    (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) ch hl hch (hP ch) hti hvoc
    htB hbIn hGb hlt hlc hbos hkap hns hVV hEmb hvP hV htok hcq hbosP hTP hkP
    ((rs.take 1).map Block.SlotRec.draws) ((rs.take 2).map Block.SlotRec.draws)
    (by rw [List.length_map, List.length_take]; omega) (by rw [List.length_map, List.length_take]; omega)
    (hz 1 (by norm_num) hd1) (hz 2 (by norm_num) hd2)
  -- (a) slot 0: the `A_in` token plane is the token words
  have htokA := shd_tok_rd Lq U hbij hU tag h64 P0 Vi ch (hP ch) hdrLen iB rH Rr hRr XI
    (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) hlt (hlc _) hep hpow hti hlw8
    htok hGb tokW hXI (hz 0 (by norm_num) hd0)
  -- (c) LogUp alive: a good lookup at the head view
  have hgood := shd_inGood_of_lu Lq U tag h64 P hPV Vi.pub Epad iB hdrLen eI
    (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg _ hlu
  -- the token plane at the head view is the one at `τ`'s
  have hTk := shdIncDataK_tok_head U tag h64 P Vi.pub Epad iB hdrLen hB key domain _ _
    (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G lg τ hdr core ch rs hrd
  -- (d) the join
  exact shd_inSat_join U tag h64 P Vi.pub Epad hE iB hdrLen _ tokW hgood (fun t h0 => (hTk t).trans (hbK t h0))
    (fun t hi => (hTk t).trans (htK t hi)) (fun t => (hTk t).trans (htokA t))

/-- **`hdinX` AT THE STAGE, GENERIC**: on every transcript, if the token words `tokW` are the input endpoint's entries
at the run's view (`hXI`) and the extracted plane `planes` is the `B_in` plane at every reading's head view (`hpl`),
then `¬ InSat P tokW planes` is stage IN-C's doom (`StgDoomAtV`, hdinX's conclusion). -/
theorem shd_hdinX_gen (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0)
    (hPV : P.Valid) (P0 : Block.BlockParams) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (hE : ∀ (j : Fin P.V) (i : shieldS0.Wid), Epad j (msbBits 12 i.val) = (P.emb j i : GF))
    (n0 hdrLen iB rA rH rX Rr : ℕ) (hB : iB < hdrLen + 4) (hrA : rA = 41) (hrX : rX = 38) (hRr : 0 < Rr)
    (XI : StgVw Lq → Fin Rr → Fin (2 ^ 8 + 256) → K)
    (hIOl : VwLoc (hdrLen + (7 + 15)) (stgCsIOm U Rr 8 256 rX 14 256 XI (bxUxV tag Lq h64 rX iB)))
    (hP : ∀ ch, StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hgt : ∀ ch, (Vi.bp (incCtx Vi.pub ch)).geom.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.terms.length)
    (hgeom : ∀ ch k, k < (Vi.bp (incCtx Vi.pub ch)).geom.slots.length →
      1 ≤ (Block.slotShape (Vi.bp (incCtx Vi.pub ch)) k).2.2)
    (hsl : 3 ≤ P0.geom.slots.length) (hd0 : 0 < P0.draws 0) (hd1 : 0 < P0.draws 1) (hd2 : 0 < P0.draws 2)
    (hti : Vi.pub.tiLog = 12) (hvoc : Vi.pub.vocLog = 17) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19)
    (hGb : Vi.geo.bLogN = 14) (hlt : Vi.pub.lt ≤ ogStage.lc) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hbos : Vi.pub.bos < 2 ^ 63) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hvP : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    (hbosP : Vi.pub.bos = P.bos) (hTP : ∀ t : shieldS0.Tok, Vi.pub.isTemplate t.val = P.isT t)
    (hkP : ∀ t : shieldS0.Tok, Vi.pub.kappa t.val = P.kap t)
    (hep : Vi.pub.epLogN = 8) (hpow : 2 ^ clog2 Vi.pub.inEpWords = Vi.pub.inEpWords)
    (hlw8 : clog2 Vi.pub.inEpWords = 8)
    (hostOf : ℕ → List (ℕ × ℕ)) (F : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (eI : ℕ) (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (tokW : shieldS0.Tok → GF) (planes : shieldS0.Pos → GF)
    (hXI : ∀ (t : shieldS0.Tok) (hr : t.val / 2 ^ 8 < Rr) (hc : t.val % 2 ^ 8 < 2 ^ 8 + 256),
      XI (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) ⟨t.val / 2 ^ 8, hr⟩ ⟨t.val % 2 ^ 8, hc⟩
        = algebraMap GF K (tokW t))
    (hpl : ∀ hdr core ch rs, StgRd key domain Lq (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G τ hdr core ch rs →
      ∀ p : shieldS0.Pos, planes p = (shdIncData U tag h64 P Vi.pub Epad iB hdrLen
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
          (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ Block.rootOpsA (Vi.bp (incCtx Vi.pub ch)) core)))).X p.1 (msbBits 12 p.2.val))
    (hnot : ¬ InSat P tokW planes) :
    StgDoomAtV U key domain P0 (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      hostOf (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) F
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH
        (stgCsIOm U Rr 8 256 rX 14 256 XI (bxUxV tag Lq h64 rX iB)))
      sshDgI eI (shd_ΛI U tag h64 P Vi.pub Epad iB hdrLen) G lg τ := by
  subst hrA
  intro hdr core ch rs hrd
  by_contra hnd
  have hal : ∀ k ∈ stgDrawing P0, (stgDefSqV P0 15 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 rH
        (stgCsIOm U Rr 8 256 rX 14 256 XI (bxUxV tag Lq h64 rX iB))) sshDgI k).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Vi.bp (incCtx Vi.pub ch)) core 15
          ++ Block.fullOps (Vi.bp (incCtx Vi.pub ch)) 0 (core.slots.take k))) [] := by
    intro k hk
    by_contra h
    exact hnd (Or.inl ⟨k, hk, h⟩)
  have hlu : (stgLkSqV 15 hdrLen eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (shd_ΛI U tag h64 P Vi.pub Epad iB hdrLen)).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Vi.bp (incCtx Vi.pub ch)) core)) [] := by
    by_contra h
    exact hnd (Or.inr (Or.inl h))
  apply hnot
  have hpe : planes = fun p => (shdIncData U tag h64 P Vi.pub Epad iB hdrLen
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ Block.rootOpsA (Vi.bp (incCtx Vi.pub ch)) core)))).X p.1 (msbBits 12 p.2.val) :=
    funext (hpl hdr core ch rs hrd)
  rw [hpe]
  exact shd_inSat_rd key domain hs Lq hL U hbij hU tag h64 P hPV P0 Vi Epad hE n0 hdrLen iB rH rX Rr hB hrX hRr XI
    hIOl hP hgt hgeom hsl hd0 hd1 hd2 hti hvoc htB hbIn hGb hlt hlc hbos hkap hns hVV hEmb hvP hV htok hcq hbosP hTP
    hkP hep hpow hlw8 G lg τ eI tokW hXI hdr core ch rs hrd hal hlu

end Sat

end ZK60.ProtocolClassify
