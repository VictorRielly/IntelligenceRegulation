/-
D63 lane L63 (2026-11-17), part 40: **the stage IN-C IO semantics pinned to the matrices the run's openings check**
(the handoff's plan item 1, after the Medium finding of HANDOFF_20261117.md section 2).

The earlier pin (`epDecX`) read the input endpoint through the commitment's `decodeIn` on L58's CHECKED extractor; the
run's soundness facts make claims true of `decodeRows` of the closing openings' UNCHECKED matrices instead. Here both
IO matrices of stage IN-C are those matrices, read on the view:

* `epUxV R v`: part `0`'s closing opening (`ebOpen`, repair B): `decodeRows (encGL 8 11 256) 768` of `ebUxW … abRdIn 11 1`,
  the matrix extracted for the root the header's message at position `1` reads as under `abRdIn` (the input endpoint);
* `bxUxV R ipos v`: a regular R13 closing opening (`rkOpen` at `rkR13 R ipos`): `decodeRows (encGL 14 16 256) 24448` of
  the cut-level matrix `UxC` at the header's position `ipos` (part `1`'s, `B_in`, at `ipos = off 0 + 2`);
* `vwLoc_epUxV`, `vwLoc_bxUxV`: they read the view below any `n` past their positions;
* **`epUxV_nz`**: at a header whose position `1` reads as the root `r`, a non-zero `decodeIn` message entry (L58's checked
  extractor at `r`, on the whole log) is a non-zero entry of `epUxV` (`ssh_ebUxW_view`, `ssh_ep_bridge`; off
  `decodeIn`'s existence branch the entry is `0`);
* **`ssh_hdzW_gen`**: `ssh_hdzW_core` for any input-endpoint matrix `XI` that is non-zero at the word's entry on every
  header showing the input root; **`ssh_hdzW_coreU`**: at `XI := epUxV`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncSem

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV
open ZK60.Circuit (gP GF)

section Mat

variable {K : Type} [Field K] [Algebra GF K] (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **The input endpoint's matrix over the view**: part `0`'s closing opening's (`ebOpen`) unchecked matrix at the root
the header's message at position `1` reads as under `abRdIn`, decoded at the endpoint code (`encGL 8 11 256`, radius
`768`). -/
noncomputable def epUxV (R : ℕ) (v : StgVw L) : Fin R → Fin (2 ^ 8 + 256) → K :=
  decodeRows (encGL (K := K) 8 11 256) 768
    (ebUxW (K := K) tag L h64 key domain hs hL abRdIn 11 1 R (N := 2 ^ 11) (v.1 1) v.2)

/-- **An R13 closing opening's matrix over the view**: the cut-level matrix at the root the header absorbs at `ipos`,
decoded at R13's code (`encGL 14 16 256`, radius `24448`). -/
noncomputable def bxUxV (R ipos : ℕ) (v : StgVw L) : Fin R → Fin (2 ^ 14 + 256) → K :=
  decodeRows (encGL (K := K) 14 16 256) 24448 (UxC tag L h64 16 R (v.1 ipos) (Block.absAt v.2 ipos))

/-- `epUxV` reads the view below `n` when `1 < n`. -/
theorem vwLoc_epUxV (R n : ℕ) (hn : 1 < n) : VwLoc n (epUxV (K := K) tag L h64 key domain hs hL R) := by
  intro v v' h1 h2
  have e : ebUxW (K := K) tag L h64 key domain hs hL abRdIn 11 1 R (N := 2 ^ 11) (v.1 1) v.2
      = ebUxW (K := K) tag L h64 key domain hs hL abRdIn 11 1 R (N := 2 ^ 11) (v'.1 1) v'.2 := by
    funext row j
    unfold ebUxW colXM
    rw [h1 1 hn, ssh_absAt_eq v.2 v'.2 n 1 hn h2]
  unfold epUxV
  rw [e]

/-- `bxUxV` reads the view below `n` when `ipos < n`. -/
theorem vwLoc_bxUxV (R ipos n : ℕ) (hn : ipos < n) : VwLoc n (bxUxV (K := K) tag L h64 R ipos) := by
  intro v v' h1 h2
  unfold bxUxV
  rw [h1 ipos hn, ssh_absAt_eq v.2 v'.2 n ipos hn h2]

end Mat

section Nz

variable {K : Type} [Field K] [Fintype K] [Algebra GF K] (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **A NON-ZERO DECODED INPUT WORD IS A NON-ZERO ENTRY OF `epUxV`** at every header whose position `1` reads as the root
`r` (L58's checked extractor at `r` on the whole log, decoded by the input commitment's `decodeIn`). -/
theorem epUxV_nz {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 8)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tagc : MTag)
    (r : Dig) (Lg : List (QB L × Dig)) (hdr : List (TItem × Dig)) (x : List UInt8)
    (hx : Block.absAt hdr 1 = some x) (hr : abRdIn x = some r) (row : Fin R) (t : Fin (2 ^ 8 + 256))
    (ht : t.val < 2 ^ 8)
    (hnz : ((epTokenCommit R dR hpos place msg msg_place pad salt path root tagc).decodeIn
      (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r Lg j.val) 768).1 row ⟨t.val, ht⟩ ≠ 0) :
    epUxV (K := K) tag L h64 key domain hs hL R (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hdr)
      row t ≠ 0 := by
  set C := epTokenCommit R dR hpos place msg msg_place pad salt path root tagc with hC
  by_cases hex : ∃ (Mg : Fin R → Fin (2 ^ 8) → GF) (Pd : Fin R → Fin 256 → GF) (S : Finset (Fin (2 ^ 11))),
      2 ^ 11 ≤ S.card + 768 ∧ ∀ j ∈ S, ∃ o, epxAt tag L h64 key domain hs hL abRdIn 11 R r Lg j.val = some o
        ∧ o.col = C.colOf Mg Pd j
  · have e1 : (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hdr).1 1
        = Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt hdr 1) Lg := rfl
    have e2 : (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hdr).2 = hdr := rfl
    unfold epUxV
    rw [e1, e2, ssh_ebUxW_view tag L h64 key domain hs hL abRdIn 11 1 R (2 ^ 11) Lg hdr hdr x r hx hx hr,
      ssh_ep_bridge tag L h64 key domain hs hL R dR hpos place msg msg_place pad salt path root tagc r Lg hdr
        (by rw [hx, Option.bind_some, hr]) hex]
    obtain ⟨tv, htv⟩ := t
    have et : (⟨tv, htv⟩ : Fin (2 ^ 8 + 256)) = Fin.castAdd 256 ⟨tv, ht⟩ := rfl
    beta_reduce
    rw [et]
    intro h0
    apply hnz
    exact (Fin.append_left _ _ _).symm.trans
      ((map_eq_zero_iff (algebraMap GF K) (algebraMap GF K).injective).mp h0)
  · exfalso
    apply hnz
    have hd : C.decodeIn (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 R r Lg j.val) 768 = (0, 0) := by
      unfold PlaneCommit.decodeIn
      split
      · next h => exact absurd h hex
      · rfl
    rw [hd]
    rfl

end Nz

section Run

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **`hdzW` FOR ANY INPUT-ENDPOINT MATRIX** non-zero at the word's entry on every header showing the input root `r`. -/
theorem ssh_hdzW_gen (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (P0 : Block.BlockParams) (Vi : IncV) (Pof : List Fp2 → Block.BlockParams)
    (hPof : ∀ ch, Pof ch = Vi.bp (incCtx Vi.pub ch)) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (Rr rO lcO QO : ℕ) (XI : StgVw L → Fin Rr → Fin (2 ^ 8 + 256) → K)
    (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K)
    (hostOf : ℕ → List (ℕ × ℕ)) (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (dg : ℕ → ℕ) (eI : ℕ) (Λ : StgVw L → List (List UInt8 × K) → Prop)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) (r : Dig)
    (hP : ∀ ch, StgSame P0 (Pof ch))
    (hgeom : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hslots : 0 < P0.geom.slots.length)
    (hlc : Vi.pub.lt ≤ lc) (hep : Vi.pub.epLogN = 8) (hpow : 2 ^ clog2 Vi.pub.inEpWords = Vi.pub.inEpWords)
    (hroot : ∀ a, 1 < a → (Block.absAt (τ.take a) 1).bind abRdIn = some r)
    (x0 : ℕ) (hT : Vi.pub.tokens ≤ x0) (hx0 : x0 < Vi.pub.inEpWords) (hR : x0 / 2 ^ 8 < Rr)
    (hXI : ∀ (hd : List (TItem × Dig)) (x : List UInt8), Block.absAt hd 1 = some x → abRdIn x = some r →
      XI (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hd) ⟨x0 / 2 ^ 8, hR⟩
        ⟨x0 % 2 ^ 8, by have := Nat.mod_lt x0 (Nat.two_pow_pos 8); omega⟩ ≠ 0) :
    StgDoomAtV U key domain P0 Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) hostOf
      (Exec.Block.absOfC (chainEncB key domain hs L hL)) F
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH (stgCsIOm U Rr 8 256 rO lcO QO XI XO))
      dg eI Λ G Lg τ := by
  set lw := clog2 Vi.pub.inEpWords with hlw
  set csIO := stgCsIOm U Rr 8 256 rO lcO QO XI XO with hcsIO
  have hge : 2 ^ 8 ≤ Vi.pub.inEpWords := by
    show 2 ^ 8 ≤ max Vi.pub.tPad (2 ^ Vi.pub.epLogN)
    rw [hep]; exact le_max_right _ _
  have hlw8 : 8 ≤ lw := by
    have h2 : 2 ^ 8 ≤ 2 ^ lw := by rw [hlw, hpow]; exact hge
    exact (Nat.pow_le_pow_iff_right (by norm_num)).mp h2
  have hx0w : x0 < 2 ^ lw := by rw [hlw, hpow]; exact hx0
  have hdraws : ∀ ch, P0.draws 0 = lw := fun ch => by rw [(hP ch).1, hPof ch]; rfl
  have hN : stgN P0 0 = lw + 1 := by
    unfold stgN; rw [stg_slotShape (hP []), hPof []]; rfl
  have h0 : 0 ∈ stgDrawing P0 := by
    unfold stgDrawing
    refine List.mem_filter.mpr ⟨List.mem_range.mpr hslots, ?_⟩
    rw [hdraws []]
    simp only [decide_eq_true_eq]
    omega
  have hIO0 : StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) csIO :=
    ssh_hIO0m U hbij hU Vi Rr 8 256 rO lcO QO XI XO (by rw [hep])
  refine ssh_doomAtV_of_def0 U key domain P0 Pof m hdrLen _ hostOf _ F _ dg eI Λ G Lg τ hP hgeom hgt h0 ?_
  intro hdr core ch rs hrd
  -- the header shows the root at position 1
  have hq : ∃ q, core.slots[0]? = some q := by
    have hl : core.slots.length = (Pof ch).geom.slots.length := hrd.2.2.2.1.1
    have : 0 < core.slots.length := by rw [hl, ← (hP ch).2]; exact hslots
    exact ⟨_, List.getElem?_eq_getElem this⟩
  obtain ⟨q, hq⟩ := hq
  obtain ⟨htk, -⟩ := stg_rd_def key domain Pof m hdrLen _ G τ hdr core ch rs hrd (hgt ch) 0 q hq
  have hpos : 1 < stgDefPos (Pof ch) m hdrLen 0 := by unfold stgDefPos; omega
  have hr1 := hroot _ hpos
  rw [htk, List.take_zero] at hr1
  obtain ⟨x, hx, hrx⟩ := Option.bind_eq_some_iff.mp hr1
  -- the draws at x0's bits
  refine ⟨fun a => bit (mb lw x0 a), ?_⟩
  change stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 []))))
      (Fp2.zero, Fp2.zero, Fp2.zero) [] 0 (stgWords U hbij (fun a : Fin (P0.draws 0) => (bit (mb lw x0 a) : K))) ≠ 0
  have hP' : StgSame P0 (Vi.bp (incCtx Vi.pub ch)) := by rw [← hPof ch]; exact hP ch
  rw [ssh_inc0_Φ_bool U hbij tag h64 hU P0 Vi ch hP' lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO _ hlc hIO0 hpow x0 hT hx0]
  -- the claim on the input endpoint matrix
  set xs : Fin (stgN P0 0) → K := fun i => (bit (decide (i.val < lw) && mb lw x0 i) : K) with hxs
  have hxr : ∀ a, a < lw → Block.xrK lw xs a = bit (mb lw x0 a) := by
    intro a ha
    unfold Block.xrK
    rw [ite_eq_left ha, xg_bitv _ a (by omega)]
    simp [ha]
  have hsel : Block.selK lw 1 xs = 1 := by
    unfold Block.selK Block.yeK
    rw [Finset.prod_range_one, Nat.add_zero, xg_bitv _ lw (by omega)]
    simp [bit]
  have hcm : Block.cmK lw 1 xs 0 = 0 := by
    unfold Block.cmK Block.yeK
    rw [Nat.add_zero, xg_bitv _ lw (by omega)]
    simp [bit]
  have hep' : (atLog (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN 0)).endpointLogN = 8 := by
    show incElog Vi.pub Vi.geo.bLogN 0 = 8
    unfold incElog; rw [ite_eq_left rfl, hep]
  change claimSem U Rr 8 256 (XI _) _ ≠ 0
  rw [ssh_endClaim_bool U hbij hU _ 8 hep' Rr 256 _ lw 1 hN xs lw Vi.geo.epDataRows x0 rfl hlw8 (by omega) hx0w hR
    hxr hsel hcm]
  exact hXI _ x hx hrx

/-- **`hdzW` AT THE RUN'S INPUT-ENDPOINT MATRIX** (`XI := epUxV`): a non-zero decoded input word (L58's checked
extractor at the input root, decoded by the input commitment's `decodeIn`) past the tokens dooms stage IN-C. -/
theorem ssh_hdzW_coreU [Fintype K] (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (P0 : Block.BlockParams) (Vi : IncV) (Pof : List Fp2 → Block.BlockParams)
    (hPof : ∀ ch, Pof ch = Vi.bp (incCtx Vi.pub ch)) (n0 hdrLen m lc h Q e rA rH : ℕ)
    {T St Salt : Type} (Rr dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 8)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin Rr) (msg : (T → ℕ) → Salt → Fin Rr → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tagc : MTag)
    (rO lcO QO : ℕ) (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K)
    (hostOf : ℕ → List (ℕ × ℕ)) (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (dg : ℕ → ℕ) (eI : ℕ) (Λ : StgVw L → List (List UInt8 × K) → Prop)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) (r : Dig)
    (hP : ∀ ch, StgSame P0 (Pof ch))
    (hgeom : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hslots : 0 < P0.geom.slots.length)
    (hlc : Vi.pub.lt ≤ lc) (hep : Vi.pub.epLogN = 8) (hpow : 2 ^ clog2 Vi.pub.inEpWords = Vi.pub.inEpWords)
    (hroot : ∀ a, 1 < a → (Block.absAt (τ.take a) 1).bind abRdIn = some r)
    (x0 : ℕ) (hT : Vi.pub.tokens ≤ x0) (hx0 : x0 < Vi.pub.inEpWords) (hR : x0 / 2 ^ 8 < Rr)
    (hnz : ((epTokenCommit Rr dR hpos place msg msg_place pad salt path root tagc).decodeIn
      (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 Rr r Lg j.val) 768).1 ⟨x0 / 2 ^ 8, hR⟩
      ⟨x0 % 2 ^ 8, Nat.mod_lt _ (Nat.two_pow_pos 8)⟩ ≠ 0) :
    StgDoomAtV U key domain P0 Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) hostOf
      (Exec.Block.absOfC (chainEncB key domain hs L hL)) F
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH
        (stgCsIOm U Rr 8 256 rO lcO QO (epUxV tag L h64 key domain hs hL Rr) XO))
      dg eI Λ G Lg τ :=
  ssh_hdzW_gen U hbij tag h64 hU key domain hs hL P0 Vi Pof hPof n0 hdrLen m lc h Q e rA rH Rr rO lcO QO
    (epUxV tag L h64 key domain hs hL Rr) XO hostOf F dg eI Λ G Lg τ r hP hgeom hgt hslots hlc hep hpow hroot
    x0 hT hx0 hR (fun hd x hx hrx =>
      epUxV_nz tag L h64 key domain hs hL Rr dR hpos place msg msg_place pad salt path root tagc r Lg hd x hx hrx
        ⟨x0 / 2 ^ 8, hR⟩ _ (Nat.mod_lt _ (Nat.two_pow_pos 8)) hnz)

end Run

end ZK60.ProtocolClassify
