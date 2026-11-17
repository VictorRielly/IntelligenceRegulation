/-
D63 lane L63 (2026-11-17), part 35: **`hdzW` PROVED at the concrete input-endpoint semantics** (the three pieces
composed).

With stage IN-C's IO semantics `csIO := stgCsIOm … (epDecX … dec) XO` (a claim on the input endpoint is its functional on
the rows `dec` decodes from L58's checked extractor at the root the header shows at position `1`), a decoded word `x0`
past the tokens that is non-zero (at the input root `r` the header shows, on the whole log) makes INC-00's define
polynomial non-zero at the draws `x0`'s bits (`ssh_inc0_Φ_bool`, `ssh_endClaim_bool`, `epDecX_ops_run`), so every reading
is doomed (`ssh_doomAtV_of_def0`).

* **`ssh_hdzW_core`**.

Hypotheses beyond the run's: the stage's profile (`Vi.pub.lt ≤ lc`, `epLogN = 8`, `in_ep_words` a power of two, a
non-empty slot list) and the header showing the root at position `1` at every cut past it (`ab_rdIn_at1` on a run).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldDzDoom

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV
open ZK60.Circuit (gP GF)

section Run

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **`hdzW` AT THE CONCRETE INPUT-ENDPOINT SEMANTICS.** -/
theorem ssh_hdzW_core (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (P0 : Block.BlockParams) (Vi : IncV) (Pof : List Fp2 → Block.BlockParams)
    (hPof : ∀ ch, Pof ch = Vi.bp (incCtx Vi.pub ch)) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (Rr rO lcO QO : ℕ) (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K)
    (dec : (Fin (2 ^ 11) → Option (MerkleOpening Dig Dig (ColR Rr))) →
      (Fin Rr → Fin (2 ^ 8) → GF) × (Fin Rr → Fin 256 → GF))
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
    (hnz : (dec (fun j => epxAt tag L h64 key domain hs hL abRdIn 11 Rr r Lg j.val)).1 ⟨x0 / 2 ^ 8, hR⟩
      ⟨x0 % 2 ^ 8, Nat.mod_lt _ (Nat.two_pow_pos 8)⟩ ≠ 0) :
    StgDoomAtV U key domain P0 Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) hostOf
      (Exec.Block.absOfC (chainEncB key domain hs L hL)) F
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH
        (stgCsIOm U Rr 8 256 rO lcO QO (epDecX tag L h64 key domain hs hL abRdIn 11 1 Rr 8 256 (2 ^ 11) dec) XO))
      dg eI Λ G Lg τ := by
  set lw := clog2 Vi.pub.inEpWords with hlw
  set csIO := stgCsIOm U Rr 8 256 rO lcO QO (epDecX tag L h64 key domain hs hL abRdIn 11 1 Rr 8 256 (2 ^ 11) dec) XO
    with hcsIO
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
    ssh_hIO0m U hbij hU Vi Rr 8 256 rO lcO QO _ XO (by rw [hep])
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
  -- the claim on the decoded input endpoint
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
  change claimSem U Rr 8 256 (epDecX tag L h64 key domain hs hL abRdIn 11 1 Rr 8 256 (2 ^ 11) dec _) _ ≠ 0
  rw [ssh_endClaim_bool U hbij hU _ 8 hep' Rr 256 _ lw 1 hN xs lw Vi.geo.epDataRows x0 rfl hlw8 (by omega) hx0w hR
    hxr hsel hcm]
  unfold epDecX
  rw [dite_eq_left (Nat.mod_lt _ (Nat.two_pow_pos 8))]
  rw [epDecX_ops_run tag L h64 key domain hs hL abRdIn 11 1 Rr (2 ^ 11) Lg _ x r hx hrx]
  intro h0'
  exact hnz ((map_eq_zero_iff (algebraMap GF K) (algebraMap GF K).injective).mp h0')

end Run

end ZK60.ProtocolClassify
