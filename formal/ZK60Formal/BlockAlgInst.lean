/-
D63 lane L36 (2026-11-09), part 3: **the certified slot polynomials of a W16R2-family block** (`spR`, with `hdgR`),
built with L23's constructors from the block's tables on the slots' cubes, and **the vanishing of the layers above the
hosts** (`hvR`'s layers 1 to 3) and what the start claims say of the tables.

The 23 slots are L11's (`SlotW16R2.lean`): six hosts (`SC_TZC` 2, `SC_DZC` 14, `SC_QZC` 15, `SC_KVZC` 16, `SC_SZC` 17,
`SC_FZC` 18), each hosting two private slots (`hostedOf`). This file is generic in the profile: it reads the draw
schedule through `AlgShape` (the draw lists, where each hosted claim point sits in the draws, the cube splits), so it
serves the W16R2 rung, the R13 rung and the Shieldstral T128 R13 block alike.

* `AlgShape`, `AlgData`: the shape facts and the tables on the hosts' cubes: per host its batched clauses `cl` (at
  `β, γ, α`), pad planes `pw`, and for each hosted pair the host's gated term `gh` and the hosted contraction `mm`;
  for `SC_SZC` hosting `SC_RS` the two row differences `rsA`, `rsB` on `Dom::Ht`'s cube and the scale `2^b`;
* `algH`, `algM`, `algPt`: a host's hosted functions and claim points (L11's `claimPoint`, read off the history);
* `hostSp`, `privSp`, `partSp`, `rsSp`, `crossSp5`, `crossSp11`, **`algSp`**: the certified polynomials by layer and
  slot (L23 §3's table); **`algSp_dg`**: every degree is at most `80` (`hdgR`);
* `hostSp_Gd`, `hostSp_Φ`: a host's start claim and its polynomial at a draw vector;
* **`formAt_host`**: a host's named identity (`FormAt`) from its named sum and its hosted slots' named sums;
* **`algSp_van1`**, **`algSp_van2`**, **`algSp_van3`**: layers 1, 2, 3 vanish at the drawn challenges once the layers
  below hold their start claims (`hvR` for `i = 1, 2, 3`), with no further premise;
* `AlgGood`, **`algGood_of_gd`**: all four layers' start claims say: every host's clauses and pad planes vanish on
  its cube, every hosted identity `gh = mm` holds at every cube point, and `rsA`, `rsB` vanish.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgUnmask
import ZK60Formal.BlockAlgKinds

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly hostGd hostPhi batched segAt privPartGd)
open ZK60.Circuit (gP GF)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)

/-- The six host slots (`SC_TZC`, `SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`). -/
def algHosts : List ℕ := [2, 14, 15, 16, 17, 18]

/-- The private slot a host hosts at `ν_i` (L11's `hostsOf`). -/
def hostedOf (k : ℕ) (i : Fin 2) : ℕ :=
  if k = 2 then (if i = 0 then 0 else 1)
  else if k = 14 then (if i = 0 then 10 else 13)
  else if k = 15 then (if i = 0 then 5 else 9)
  else if k = 16 then (if i = 0 then 6 else 7)
  else if k = 17 then (if i = 0 then 4 else 8)
  else (if i = 0 then 11 else 12)

/-- The slot whose first coordinates a split claim point starts with: `SC_QMM` for `SC_KVZC`'s pairs, `SC_GMM` for
`SC_FZC`'s `SC_UMM`. -/
def partSrc (k : ℕ) : ℕ := if k = 16 then 5 else 11

/-- The layout facts of a host's draw list (`w16r2_host_layout`'s conclusion). -/
structure HostLay (l : List (Seg × ℕ)) : Prop where
  nd : (l.map Prod.fst).Nodup
  nu : segLn l .nu = 2
  z1 : segLn l .zeta ≤ 1
  zmu : segLn l .zeta ≤ segLn l .mu

/-- **The shape facts the block's algebra reads off the draw schedule**: the hosts' draw lists `dl` (their sums the
verifier's draw counts), their pad plane counts `mpad` (at most `78`, none where the slot draws no `ζ`), and how each
hosted claim point is made:
* a pair that is neither split nor `SC_RS`'s: coordinate `t` of the point is entry `ip k i t` of the hosted slot's
  draws (injective, within the draws);
* a split pair (`SC_KVZC`'s two, `SC_FZC`'s second): the first `pa` coordinates are the first `pa` draws of `partSrc`
  (`SC_QMM`, `SC_GMM`, whose draws are `pa + cq`, `pa + cf`), the rest are the hosted slot's own draws;
* `SC_SZC`'s `SC_RS`: `SC_RS` draws `nHt` row coordinates then `λ`; `Dom::S`'s cube is `nHt + bS`. -/
structure AlgShape (P : BlockParams) where
  dl : ℕ → List (Seg × ℕ)
  mpad : ℕ → ℕ
  pa : ℕ
  cq : ℕ
  cf : ℕ
  nHt : ℕ
  bS : ℕ
  ip : (k : ℕ) → Fin 2 → Fin (segLn (dl k) .tau) → ℕ
  hsum : ∀ k ∈ algHosts, segSum (dl k) = P.draws k
  hlay : ∀ k ∈ algHosts, HostLay (dl k)
  hm0 : ∀ k ∈ algHosts, segLn (dl k) .zeta = 0 → mpad k = 0
  hm78 : ∀ k ∈ algHosts, mpad k ≤ 78
  hipLt : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 16 ∨ (k = 18 ∧ i = 1)) → ¬ (k = 17 ∧ i = 0) →
    ∀ t, ip k i t < P.draws (hostedOf k i)
  hipInj : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 16 ∨ (k = 18 ∧ i = 1)) → ¬ (k = 17 ∧ i = 0) →
    Function.Injective (ip k i)
  hpart : ∀ (k : ℕ) (i : Fin 2), (k = 16 ∨ (k = 18 ∧ i = 1)) → segLn (dl k) .tau = pa + P.draws (hostedOf k i)
  hq5 : pa + cq = P.draws 5
  hq11 : pa + cf = P.draws 11
  hb6 : P.draws 6 ≤ cq
  hb7 : P.draws 7 ≤ cq
  hb12 : P.draws 12 ≤ cf
  hrs : nHt + 1 = P.draws 4
  hS : ∀ k, k = 17 → segLn (dl k) .tau = nHt + bS

/-- **The block's tables on the hosts' cubes**, as functions of the extraction's cuts and roots: the batched clauses
`cl` (they may read `β, γ, α`: the LogUp helper clauses), the pad planes `pw`, the hosts' gated terms `gh` and the
hosted contractions `mm` for each hosted pair, `SC_RS`'s row differences `rsA` (`gHt·SUM − Σ_j gS·mask·E`) and `rsB`
(`gHt − Σ_j gS·ZSEL`) on `Dom::Ht`'s cube, and the nonzero scale of `SC_SZC`'s hosted `SC_RS` term (`2^b`, the code's
`per_row`). -/
structure AlgData (K : Type) [Field K] (L : ℕ) {P : BlockParams} (sh : AlgShape P) where
  cl : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Fin (segLn (sh.dl k) .mu - segLn (sh.dl k) .zeta) →
    (Fin (segLn (sh.dl k) .tau) → Bool) → K
  pw : (k : ℕ) → Cuts3 L → RootsO → Fin (sh.mpad k) → (Fin (segLn (sh.dl k) .tau) → Bool) → K
  gh : (k : ℕ) → Cuts3 L → RootsO → Fin 2 → (Fin (segLn (sh.dl k) .tau) → Bool) → K
  mm : (k : ℕ) → Cuts3 L → RootsO → Fin 2 → (Fin (segLn (sh.dl k) .tau) → Bool) → K
  rsA : Cuts3 L → RootsO → (Fin sh.nHt → Bool) → K
  rsB : Cuts3 L → RootsO → (Fin sh.nHt → Bool) → K
  rsScale : K
  hsc : rsScale ≠ 0

section Inst

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ} {P : BlockParams} (U : K) (sh : AlgShape P)
  (dt : AlgData K L sh)

/-- A challenge an earlier slot drew, read off the history (`0` when absent). -/
def drawAt (hist : Hist) (s q : ℕ) : K := ((hist.draws.getD s []).getD q Fp2.zero).toK U

/-- The history before slot `k` shows an earlier slot's draws. -/
theorem drawAt_hist (b g a : Fp2) (rs : List SlotRec) (k j q : ℕ) (r : SlotRec) (hjk : j < k)
    (hr : rs[j]? = some r) :
    drawAt U (histOf b g a (rs.take k)) j q = (r.draws.getD q Fp2.zero).toK U := by
  unfold drawAt histOf
  simp only
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_take_of_lt hjk, hr]
  rfl

/-- `SC_RS`'s `λ` (its last draw), read off the history. -/
def algLam (hist : Hist) : K := drawAt U hist 4 sh.nHt

/-- **A host's hosted function** `i` on its cube: its gated term `gh`; for `SC_SZC` hosting `SC_RS`, the scaled
`λ`-batched row difference `2^b·(rsA + λ·rsB)` of the row coordinates. -/
def algH (k : ℕ) (cu : Cuts3 L) (rt : RootsO) (hist : Hist) (i : Fin 2) :
    (Fin (segLn (sh.dl k) .tau) → Bool) → K :=
  if h : k = 17 ∧ i = 0 then
    fun z => dt.rsScale * (dt.rsA cu rt (fun j => z (Fin.cast (sh.hS k h.1).symm (Fin.castAdd sh.bS j)))
      + algLam U sh hist * dt.rsB cu rt (fun j => z (Fin.cast (sh.hS k h.1).symm (Fin.castAdd sh.bS j))))
  else dt.gh k cu rt i

/-- **A host's hosted contraction** `i` on its cube (`0` for `SC_SZC`'s `SC_RS`: `algH` holds the difference). -/
def algM (k : ℕ) (cu : Cuts3 L) (rt : RootsO) (i : Fin 2) : (Fin (segLn (sh.dl k) .tau) → Bool) → K :=
  if k = 17 ∧ i = 0 then fun _ => 0 else dt.mm k cu rt i

/-- **A host's hosted claim point** `i` (L11's `claimPoint`), read off the history. -/
def algPt (k : ℕ) (hist : Hist) (i : Fin 2) (t : Fin (segLn (sh.dl k) .tau)) : K :=
  if k = 17 ∧ i = 0 then (if (t : ℕ) < sh.nHt then drawAt U hist 4 t else 0)
  else if k = 16 ∨ (k = 18 ∧ i = 1) then
    (if (t : ℕ) < sh.pa then drawAt U hist (partSrc k) t else drawAt U hist (hostedOf k i) ((t : ℕ) - sh.pa))
  else drawAt U hist (hostedOf k i) (sh.ip k i t)

theorem algH_gh (k : ℕ) (cu : Cuts3 L) (rt : RootsO) (hist : Hist) (i : Fin 2) (h : ¬ (k = 17 ∧ i = 0)) :
    algH U sh dt k cu rt hist i = dt.gh k cu rt i := by
  unfold algH
  simp only [h, ↓reduceDIte]

omit [Algebra GF K] in
theorem algM_mm (k : ℕ) (cu : Cuts3 L) (rt : RootsO) (i : Fin 2) (h : ¬ (k = 17 ∧ i = 0)) :
    algM sh dt k cu rt i = dt.mm k cu rt i := by
  unfold algM
  simp only [h, ↓reduceIte]

/-- The split difference of a split pair, on the cube `pa + (the hosted slot's draws)`. -/
def partD (k : ℕ) (i : Fin 2) (hp : k = 16 ∨ (k = 18 ∧ i = 1)) (cu : Cuts3 L) (rt : RootsO) :
    (Fin (sh.pa + P.draws (hostedOf k i)) → Bool) → K :=
  fun z => dt.gh k cu rt i (fun t => z (Fin.cast (sh.hpart k i hp) t))
    - dt.mm k cu rt i (fun t => z (Fin.cast (sh.hpart k i hp) t))

/-! ## The certified polynomials -/

/-- **A private slot whose claim point is read off its own draws** (layer 1). -/
def privSp (k : ℕ) (hk : k ∈ algHosts) (i : Fin 2) (hd1 : ¬ (k = 16 ∨ (k = 18 ∧ i = 1))) (hd2 : ¬ (k = 17 ∧ i = 0))
    (cu : Cuts3 L) (rt : RootsO) (hist : Hist) : SlotPoly K (P.draws (hostedOf k i)) :=
  SlotPoly.priv (algH U sh dt k cu rt hist i) (algM sh dt k cu rt i)
    (fun t => ⟨sh.ip k i t, sh.hipLt k hk i hd1 hd2 t⟩)
    (fun _ _ hab => sh.hipInj k hk i hd1 hd2 (congrArg Fin.val hab))

/-- **A private slot whose claim point starts with an earlier slot's coordinates** (layer 1). -/
def partSp (k : ℕ) (i : Fin 2) (hp : k = 16 ∨ (k = 18 ∧ i = 1)) (cu : Cuts3 L) (rt : RootsO) (hist : Hist) :
    SlotPoly K (P.draws (hostedOf k i)) :=
  SlotPoly.partWhole (partD sh dt k i hp cu rt) (fun t : Fin sh.pa => drawAt U hist (partSrc k) t)

/-- **`SC_RS`** (layer 1). -/
def rsSp (cu : Cuts3 L) (rt : RootsO) : SlotPoly K (P.draws 4) :=
  SlotPoly.cast sh.hrs (SlotPoly.rsLast (dt.rsA cu rt) (dt.rsB cu rt))

/-- **`SC_QMM`'s layer for `SC_KMM`** (layer 2, `i = 0`) **and for `SC_VMM`** (layer 3, `i = 1`). -/
def crossSp5 (i : Fin 2) (hb : P.draws (hostedOf 16 i) ≤ sh.cq) (cu : Cuts3 L) (rt : RootsO) :
    SlotPoly K (P.draws 5) :=
  SlotPoly.cast sh.hq5 (SlotPoly.crossFirst (partD sh dt 16 i (Or.inl rfl) cu rt) hb)

/-- **`SC_GMM`'s layer for `SC_UMM`** (layer 2). -/
def crossSp11 (cu : Cuts3 L) (rt : RootsO) : SlotPoly K (P.draws 11) :=
  SlotPoly.cast sh.hq11 (SlotPoly.crossFirst (partD sh dt 18 1 (Or.inr ⟨rfl, rfl⟩) cu rt) sh.hb12)

variable [Fintype K] [DecidableEq K] (hcard : 78 < Fintype.card K)

/-- **A host** (layer 0): L23's `hostAt` on its draw list, over the block's tables. -/
def hostSp (k : ℕ) (hk : k ∈ algHosts) (cu : Cuts3 L) (rt : RootsO) (hist : Hist) : SlotPoly K (P.draws k) :=
  SlotPoly.cast (sh.hsum k hk)
    (SlotPoly.hostAt (sh.dl k) (segSum (sh.dl k)) rfl (sh.hlay k hk).nd
      (segLn (sh.dl k) .mu - segLn (sh.dl k) .zeta) (segLn (sh.dl k) .tau) (sh.mpad k) rfl
      (by have := (sh.hlay k hk).zmu; omega) (sh.hlay k hk).nu (sh.hlay k hk).z1 (sh.hm0 k hk)
      (lt_of_le_of_lt (sh.hm78 k hk) hcard)
      (dt.cl k cu rt (hist.beta, hist.gamma, hist.alpha)) (dt.pw k cu rt) (algH U sh dt k cu rt hist)
      (algM sh dt k cu rt) (algPt U sh k hist))

/-- **The certified slot polynomials of a W16R2-family block, by layer and slot** (L23 §3): layer 0 the six hosts
(the standalone zero-checks carry no relation of `W16Rels`: the trivial polynomial); layer 1 the twelve private
slots; layer 2 `SC_QMM` (for `SC_KMM`) and `SC_GMM` (for `SC_UMM`); layer 3 `SC_QMM` (for `SC_VMM`). -/
def algSp : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k)
  | 0, cu, rt, 2, h => hostSp U sh dt hcard 2 (by decide) cu rt h
  | 0, cu, rt, 14, h => hostSp U sh dt hcard 14 (by decide) cu rt h
  | 0, cu, rt, 15, h => hostSp U sh dt hcard 15 (by decide) cu rt h
  | 0, cu, rt, 16, h => hostSp U sh dt hcard 16 (by decide) cu rt h
  | 0, cu, rt, 17, h => hostSp U sh dt hcard 17 (by decide) cu rt h
  | 0, cu, rt, 18, h => hostSp U sh dt hcard 18 (by decide) cu rt h
  | 1, cu, rt, 0, h => privSp U sh dt 2 (by decide) 0 (by decide) (by decide) cu rt h
  | 1, cu, rt, 1, h => privSp U sh dt 2 (by decide) 1 (by decide) (by decide) cu rt h
  | 1, cu, rt, 4, _ => rsSp sh dt cu rt
  | 1, cu, rt, 5, h => privSp U sh dt 15 (by decide) 0 (by decide) (by decide) cu rt h
  | 1, cu, rt, 6, h => partSp U sh dt 16 0 (Or.inl rfl) cu rt h
  | 1, cu, rt, 7, h => partSp U sh dt 16 1 (Or.inl rfl) cu rt h
  | 1, cu, rt, 8, h => privSp U sh dt 17 (by decide) 1 (by decide) (by decide) cu rt h
  | 1, cu, rt, 9, h => privSp U sh dt 15 (by decide) 1 (by decide) (by decide) cu rt h
  | 1, cu, rt, 10, h => privSp U sh dt 14 (by decide) 0 (by decide) (by decide) cu rt h
  | 1, cu, rt, 11, h => privSp U sh dt 18 (by decide) 0 (by decide) (by decide) cu rt h
  | 1, cu, rt, 12, h => partSp U sh dt 18 1 (Or.inr ⟨rfl, rfl⟩) cu rt h
  | 1, cu, rt, 13, h => privSp U sh dt 14 (by decide) 1 (by decide) (by decide) cu rt h
  | 2, cu, rt, 5, _ => crossSp5 sh dt 0 sh.hb6 cu rt
  | 2, cu, rt, 11, _ => crossSp11 sh dt cu rt
  | 3, cu, rt, 5, _ => crossSp5 sh dt 1 sh.hb7 cu rt
  | _, _, _, k, _ => SlotPoly.triv (P.draws k)

/-- A host's start claim. -/
theorem hostSp_Gd (k : ℕ) (hk : k ∈ algHosts) (cu : Cuts3 L) (rt : RootsO) (hist : Hist) :
    (hostSp U sh dt hcard k hk cu rt hist).Gd
      = hostGd (dt.cl k cu rt (hist.beta, hist.gamma, hist.alpha)) (dt.pw k cu rt) (fun _ => 1)
          (algH U sh dt k cu rt hist) (algM sh dt k cu rt) (algPt U sh k hist) := by
  unfold hostSp
  exact SlotW16.hostAt_Gd _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _

/-- A host's degree. -/
theorem hostSp_dg (k : ℕ) (hk : k ∈ algHosts) (cu : Cuts3 L) (rt : RootsO) (hist : Hist) :
    (hostSp U sh dt hcard k hk cu rt hist).dg = sh.mpad k + 2 := by
  unfold hostSp
  exact SlotW16.hostAt_dg _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _

/-- **A host's polynomial at a draw vector**: `hostPhi` over the block's tables at the segments' entries of the
vector (`ζ` and `μ_pad` only where the slot pads). -/
theorem hostSp_Φ (k : ℕ) (hk : k ∈ algHosts) (cu : Cuts3 L) (rt : RootsO) (hist : Hist) (x : Fin (P.draws k) → K) :
    (hostSp U sh dt hcard k hk cu rt hist).Φ x
      = hostPhi (dt.cl k cu rt (hist.beta, hist.gamma, hist.alpha)) (dt.pw k cu rt) (fun _ => 1)
          (algH U sh dt k cu rt hist) (algM sh dt k cu rt) (algPt U sh k hist)
          ((if segLn (sh.dl k) .zeta = 1
              then segAt (sh.dl k) (fun j => x (Fin.cast (sh.hsum k hk) j)) .zeta 0 else 0,
            if segLn (sh.dl k) .zeta = 1
              then segAt (sh.dl k) (fun j => x (Fin.cast (sh.hsum k hk) j)) .mu
                (segLn (sh.dl k) .mu - segLn (sh.dl k) .zeta) else 0),
            fun κ => segAt (sh.dl k) (fun j => x (Fin.cast (sh.hsum k hk) j)) .mu κ)
          (fun t => segAt (sh.dl k) (fun j => x (Fin.cast (sh.hsum k hk) j)) .tau t)
          (fun v => segAt (sh.dl k) (fun j => x (Fin.cast (sh.hsum k hk) j)) .nu v) := by
  unfold hostSp
  exact SlotW16.hostAt_Φ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ (fun j => x (Fin.cast (sh.hsum k hk) j))

/-- **`hdgR`**: every certified polynomial of the four layers has degree at most `80` (a host's is its pad plane
count plus `2`). -/
theorem algSp_dg : ∀ i, i < 4 → ∀ (cu : Cuts3 L) (rt : RootsO) (k : ℕ) (h : Hist), k ∈ w16r2RelKs i →
    (algSp U sh dt hcard i cu rt k h).dg ≤ 80 := by
  intro i hi cu rt k h hk
  have hh : ∀ k' (hk' : k' ∈ algHosts), (hostSp U sh dt hcard k' hk' cu rt h).dg ≤ 80 := fun k' hk' => by
    rw [hostSp_dg]
    have := sh.hm78 k' hk'
    omega
  have hi' : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 := by omega
  rcases hi' with rfl | rfl | rfl | rfl
  · simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk
    rcases hk with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · exact hh 2 (by decide)
    · exact Nat.zero_le 80
    · exact hh 14 (by decide)
    · exact hh 15 (by decide)
    · exact hh 16 (by decide)
    · exact hh 17 (by decide)
    · exact hh 18 (by decide)
    · exact Nat.zero_le 80
    · exact Nat.zero_le 80
  · simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk
    rcases hk with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (2 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
  · simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk
    rcases hk with rfl | rfl
    · exact (by decide : (1 : ℕ) ≤ 80)
    · exact (by decide : (1 : ℕ) ≤ 80)
  · simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk
    subst hk
    exact (by decide : (1 : ℕ) ≤ 80)

/-! ## The hosts' start claims on an outcome -/

/-- **A host's start claim, from layer 0's**: its clauses and pad planes vanish on its cube and each hosted
difference at its claim point is `0`. -/
theorem host_gd_of_sched (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hgd0 : SchedGd (w16r2DR P (algSp U sh dt hcard) 0) cu rt bga rs) (k : ℕ) (hk : k ∈ algHosts) :
    hostGd (dt.cl k cu rt bga) (dt.pw k cu rt) (fun _ => 1)
      (algH U sh dt k cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))) (algM sh dt k cu rt)
      (algPt U sh k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))) := by
  simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
  rcases hk with rfl | rfl | rfl | rfl | rfl | rfl
  · exact (hostSp_Gd U sh dt hcard 2 (by decide) cu rt _).mp (hgd0 2 (show 2 ∈ w16r2RelKs 0 by decide))
  · exact (hostSp_Gd U sh dt hcard 14 (by decide) cu rt _).mp (hgd0 14 (show 14 ∈ w16r2RelKs 0 by decide))
  · exact (hostSp_Gd U sh dt hcard 15 (by decide) cu rt _).mp (hgd0 15 (show 15 ∈ w16r2RelKs 0 by decide))
  · exact (hostSp_Gd U sh dt hcard 16 (by decide) cu rt _).mp (hgd0 16 (show 16 ∈ w16r2RelKs 0 by decide))
  · exact (hostSp_Gd U sh dt hcard 17 (by decide) cu rt _).mp (hgd0 17 (show 17 ∈ w16r2RelKs 0 by decide))
  · exact (hostSp_Gd U sh dt hcard 18 (by decide) cu rt _).mp (hgd0 18 (show 18 ∈ w16r2RelKs 0 by decide))

end Inst

section Van

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ} {P : BlockParams} (U : K) (sh : AlgShape P)
  (dt : AlgData K L sh)

/-- **A private slot read off its own draws vanishes at its drawn point** once its host's start claim holds. -/
theorem privSp_van (k : ℕ) (hk : k ∈ algHosts) (i : Fin 2) (hd1 : ¬ (k = 16 ∨ (k = 18 ∧ i = 1)))
    (hd2 : ¬ (k = 17 ∧ i = 0)) (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hlt : hostedOf k i < k) (r : SlotRec) (hr : rs[hostedOf k i]? = some r)
    (hG : hostGd (dt.cl k cu rt bga) (dt.pw k cu rt) (fun _ => 1)
      (algH U sh dt k cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))) (algM sh dt k cu rt)
      (algPt U sh k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)))) :
    (privSp U sh dt k hk i hd1 hd2 cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take (hostedOf k i)))).Φ
      (fun t => (r.draws.getD t.val Fp2.zero).toK U) = 0 := by
  unfold privSp
  rw [algH_gh U sh dt k cu rt _ i hd2]
  have hG2 := hG.2.2 i
  rw [algH_gh U sh dt k cu rt _ i hd2] at hG2
  refine SlotW16.priv_van _ _ _ _ (algPt U sh k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) i) _ ?_ hG2
  funext t
  unfold algPt
  simp only [hd1, hd2, ↓reduceIte]
  exact drawAt_hist U bga.1 bga.2.1 bga.2.2 rs k (hostedOf k i) _ r hlt hr

/-- **A private slot whose point starts with an earlier slot's coordinates vanishes at its drawn point** once its
host's start claim holds. -/
theorem partSp_van (k : ℕ) (i : Fin 2) (hp : k = 16 ∨ (k = 18 ∧ i = 1)) (hd2 : ¬ (k = 17 ∧ i = 0))
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hlt : hostedOf k i < k) (hsrc : partSrc k < hostedOf k i) (r rq : SlotRec)
    (hr : rs[hostedOf k i]? = some r) (hrq : rs[partSrc k]? = some rq)
    (hG : hostGd (dt.cl k cu rt bga) (dt.pw k cu rt) (fun _ => 1)
      (algH U sh dt k cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))) (algM sh dt k cu rt)
      (algPt U sh k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)))) :
    (partSp U sh dt k i hp cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take (hostedOf k i)))).Φ
      (fun t => (r.draws.getD t.val Fp2.zero).toK U) = 0 := by
  have hG2 := hG.2.2 i
  rw [algH_gh U sh dt k cu rt _ i hd2, algM_mm sh dt k cu rt i hd2] at hG2
  unfold partSp partD
  refine SlotW16.part_van (sh.hpart k i hp) (dt.gh k cu rt i) (dt.mm k cu rt i) _
    (algPt U sh k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) i) _ ?_ hG2
  funext t
  unfold algPt
  simp only [hd2, hp, ↓reduceIte]
  rw [SlotW16.append_cast_ite (sh.hpart k i hp)
    (fun t : Fin sh.pa => drawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take (hostedOf k i))) (partSrc k) t)
    (fun t : Fin (P.draws (hostedOf k i)) => (r.draws.getD t.val Fp2.zero).toK U)
    (fun q => (rq.draws.getD q Fp2.zero).toK U) (fun q => (r.draws.getD q Fp2.zero).toK U)
    (fun j => drawAt_hist U bga.1 bga.2.1 bga.2.2 rs (hostedOf k i) (partSrc k) _ rq hsrc hrq) (fun _ => rfl) t]
  by_cases ht : (t : ℕ) < sh.pa
  · simp only [ht, ↓reduceIte]
    exact drawAt_hist U bga.1 bga.2.1 bga.2.2 rs k (partSrc k) _ rq (lt_trans hsrc hlt) hrq
  · simp only [ht, ↓reduceIte]
    exact drawAt_hist U bga.1 bga.2.1 bga.2.2 rs k (hostedOf k i) _ r hlt hr

/-- **`SC_RS` vanishes at its drawn point and `λ`** once `SC_SZC`'s start claim holds. -/
theorem rsSp_van (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec)
    (hr : rs[4]? = some r)
    (hG : hostGd (dt.cl 17 cu rt bga) (dt.pw 17 cu rt) (fun _ => 1)
      (algH U sh dt 17 cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17))) (algM sh dt 17 cu rt)
      (algPt U sh 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)))) :
    (rsSp sh dt cu rt).Φ (fun t => (r.draws.getD t.val Fp2.zero).toK U) = 0 := by
  have hG2 := hG.2.2 0
  have eH : algH U sh dt 17 cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0
      = fun z => dt.rsScale * (dt.rsA cu rt (fun j => z (Fin.cast (sh.hS 17 rfl).symm (Fin.castAdd sh.bS j)))
        + algLam U sh (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17))
          * dt.rsB cu rt (fun j => z (Fin.cast (sh.hS 17 rfl).symm (Fin.castAdd sh.bS j)))) := by
    unfold algH
    simp only [eq_self, and_self, ↓reduceDIte]
  have eM : algM sh dt 17 cu rt 0 = fun _ => 0 := by
    unfold algM
    simp only [eq_self, and_self, ↓reduceIte]
  rw [eH, eM] at hG2
  have hlam : algLam U sh (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) = (r.draws.getD sh.nHt Fp2.zero).toK U :=
    drawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 _ r (by decide) hr
  show (SlotPoly.rsLast (dt.rsA cu rt) (dt.rsB cu rt)).Φ
    (fun j => (r.draws.getD (Fin.cast sh.hrs j).val Fp2.zero).toK U) = 0
  refine SlotW16.rs_van (sh.hS 17 rfl) (dt.rsA cu rt) (dt.rsB cu rt) dt.rsScale _ dt.hsc
    (fun t : Fin sh.nHt => (r.draws.getD t.val Fp2.zero).toK U) (fun _ : Fin sh.bS => (0 : K))
    (algPt U sh 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0) ?_ _ rfl hlam.symm hG2
  funext t
  unfold algPt
  simp only [eq_self, and_self, ↓reduceIte]
  rw [SlotW16.append_cast_ite (sh.hS 17 rfl) (fun t : Fin sh.nHt => (r.draws.getD t.val Fp2.zero).toK U)
    (fun _ : Fin sh.bS => (0 : K)) (fun q => (r.draws.getD q Fp2.zero).toK U) (fun _ => 0)
    (fun _ => rfl) (fun _ => rfl) t]
  by_cases ht : (t : ℕ) < sh.nHt
  · simp only [ht, ↓reduceIte]
    exact drawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 _ r (by decide) hr
  · simp only [ht, ↓reduceIte]

/-- **The drawing slot's layer vanishes at its drawn challenges** once the later slot's partial claim holds
(finding L23-2): `SC_QMM` for a pair of `SC_KVZC`. -/
theorem crossSp5_van (i : Fin 2) (hb : P.draws (hostedOf 16 i) ≤ sh.cq) (cu : Cuts3 L) (rt : RootsO)
    (b g a : Fp2) (rs : List SlotRec) (hlt : 5 < hostedOf 16 i) (r : SlotRec) (hr : rs[5]? = some r)
    (hG : (partSp U sh dt 16 i (Or.inl rfl) cu rt (histOf b g a (rs.take (hostedOf 16 i)))).Gd) :
    (crossSp5 sh dt i hb cu rt).Φ (fun t => (r.draws.getD t.val Fp2.zero).toK U) = 0 := by
  show (SlotPoly.crossFirst (partD sh dt 16 i (Or.inl rfl) cu rt) hb).Φ
    (fun j => (r.draws.getD (Fin.cast sh.hq5 j).val Fp2.zero).toK U) = 0
  refine SlotW16.cross_van _ hb _ (fun t : Fin sh.pa => drawAt U (histOf b g a (rs.take (hostedOf 16 i))) 5 t) ?_ hG
  funext t
  exact drawAt_hist U b g a rs (hostedOf 16 i) 5 _ r hlt hr

/-- The same for `SC_GMM` and `SC_FZC`'s `SC_UMM`. -/
theorem crossSp11_van (cu : Cuts3 L) (rt : RootsO) (b g a : Fp2) (rs : List SlotRec) (r : SlotRec)
    (hr : rs[11]? = some r)
    (hG : (partSp U sh dt 18 1 (Or.inr ⟨rfl, rfl⟩) cu rt (histOf b g a (rs.take 12))).Gd) :
    (crossSp11 sh dt cu rt).Φ (fun t => (r.draws.getD t.val Fp2.zero).toK U) = 0 := by
  show (SlotPoly.crossFirst (partD sh dt 18 1 (Or.inr ⟨rfl, rfl⟩) cu rt) sh.hb12).Φ
    (fun j => (r.draws.getD (Fin.cast sh.hq11 j).val Fp2.zero).toK U) = 0
  refine SlotW16.cross_van _ sh.hb12 _ (fun t : Fin sh.pa => drawAt U (histOf b g a (rs.take 12)) 11 t) ?_ hG
  funext t
  exact drawAt_hist U b g a rs 12 11 _ r (by decide) hr

variable [Fintype K] [DecidableEq K] (hcard : 78 < Fintype.card K)

/-- **`hvR` at layer 1**: the twelve private slots' polynomials vanish at their drawn challenges once layer 0 (the
hosts) holds its start claims. No further premise. -/
theorem algSp_van1 (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hgd0 : SchedGd (w16r2DR P (algSp U sh dt hcard) 0) cu rt bga rs) :
    SchedVan U P (w16r2DR P (algSp U sh dt hcard) 1) cu rt bga rs := by
  have hG := host_gd_of_sched U sh dt hcard cu rt bga rs hgd0
  intro k hk r hr
  have hk' : k ∈ w16r2RelKs 1 := hk
  simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk'
  rcases hk' with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact privSp_van U sh dt 2 (by decide) 0 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 2 (by decide))
  · exact privSp_van U sh dt 2 (by decide) 1 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 2 (by decide))
  · exact rsSp_van U sh dt cu rt bga rs r hr (hG 17 (by decide))
  · exact privSp_van U sh dt 15 (by decide) 0 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 15 (by decide))
  · obtain ⟨rq, hrq⟩ : ∃ rq, rs[5]? = some rq :=
      ⟨_, List.getElem?_eq_getElem (lt_trans (by decide) (List.getElem?_eq_some_iff.mp hr).1)⟩
    exact partSp_van U sh dt 16 0 (Or.inl rfl) (by decide) cu rt bga rs (by decide) (by decide) r rq hr hrq
      (hG 16 (by decide))
  · obtain ⟨rq, hrq⟩ : ∃ rq, rs[5]? = some rq :=
      ⟨_, List.getElem?_eq_getElem (lt_trans (by decide) (List.getElem?_eq_some_iff.mp hr).1)⟩
    exact partSp_van U sh dt 16 1 (Or.inl rfl) (by decide) cu rt bga rs (by decide) (by decide) r rq hr hrq
      (hG 16 (by decide))
  · exact privSp_van U sh dt 17 (by decide) 1 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 17 (by decide))
  · exact privSp_van U sh dt 15 (by decide) 1 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 15 (by decide))
  · exact privSp_van U sh dt 14 (by decide) 0 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 14 (by decide))
  · exact privSp_van U sh dt 18 (by decide) 0 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 18 (by decide))
  · obtain ⟨rq, hrq⟩ : ∃ rq, rs[11]? = some rq :=
      ⟨_, List.getElem?_eq_getElem (lt_trans (by decide) (List.getElem?_eq_some_iff.mp hr).1)⟩
    exact partSp_van U sh dt 18 1 (Or.inr ⟨rfl, rfl⟩) (by decide) cu rt bga rs (by decide) (by decide) r rq hr hrq
      (hG 18 (by decide))
  · exact privSp_van U sh dt 14 (by decide) 1 (by decide) (by decide) cu rt bga rs (by decide) r hr
      (hG 14 (by decide))

/-- **`hvR` at layer 2**: `SC_QMM`'s and `SC_GMM`'s layers vanish once layer 1 holds its start claims. -/
theorem algSp_van2 (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hgd1 : SchedGd (w16r2DR P (algSp U sh dt hcard) 1) cu rt bga rs) :
    SchedVan U P (w16r2DR P (algSp U sh dt hcard) 2) cu rt bga rs := by
  intro k hk r hr
  have hk' : k ∈ w16r2RelKs 2 := hk
  simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk'
  rcases hk' with rfl | rfl
  · exact crossSp5_van U sh dt 0 sh.hb6 cu rt bga.1 bga.2.1 bga.2.2 rs (by decide) r hr
      (hgd1 6 (show 6 ∈ w16r2RelKs 1 by decide))
  · exact crossSp11_van U sh dt cu rt bga.1 bga.2.1 bga.2.2 rs r hr (hgd1 12 (show 12 ∈ w16r2RelKs 1 by decide))

/-- **`hvR` at layer 3**: `SC_QMM`'s layer for `SC_VMM` vanishes once layer 1 holds its start claims. -/
theorem algSp_van3 (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hgd1 : SchedGd (w16r2DR P (algSp U sh dt hcard) 1) cu rt bga rs) :
    SchedVan U P (w16r2DR P (algSp U sh dt hcard) 3) cu rt bga rs := by
  intro k hk r hr
  have hk' : k ∈ w16r2RelKs 3 := hk
  simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk'
  subst hk'
  exact crossSp5_van U sh dt 1 sh.hb7 cu rt bga.1 bga.2.1 bga.2.2 rs (by decide) r hr
    (hgd1 7 (show 7 ∈ w16r2RelKs 1 by decide))

/-! ## What the start claims say of the tables -/

/-- **What all four layers' start claims say of the block's tables**: every host's clauses and pad planes vanish on
its cube; every hosted identity holds at every cube point (`gh = mm`); `SC_RS`'s two row differences vanish. -/
def AlgGood (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) : Prop :=
  (∀ k ∈ algHosts, (∀ κ b, dt.cl k cu rt bga κ b = 0) ∧ (∀ j b, dt.pw k cu rt j b = 0))
  ∧ (∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 17 ∧ i = 0) → ∀ b, dt.gh k cu rt i b = dt.mm k cu rt i b)
  ∧ (∀ b, dt.rsA cu rt b = 0) ∧ (∀ b, dt.rsB cu rt b = 0)

/-- **All four layers' start claims give `AlgGood`** (the generic half of `hgdR`). -/
theorem algGood_of_gd (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hgd : ∀ i, i < 4 → SchedGd (w16r2DR P (algSp U sh dt hcard) i) cu rt bga rs) :
    AlgGood sh dt cu rt bga := by
  have hG := host_gd_of_sched U sh dt hcard cu rt bga rs (hgd 0 (by norm_num))
  have h1 := hgd 1 (by norm_num)
  have h2 := hgd 2 (by norm_num)
  have h3 := hgd 3 (by norm_num)
  -- a private slot read off its own draws: its start claim is the pointwise identity
  have hpriv : ∀ (k : ℕ) (hk : k ∈ algHosts) (i : Fin 2) (hd1 : ¬ (k = 16 ∨ (k = 18 ∧ i = 1)))
      (hd2 : ¬ (k = 17 ∧ i = 0)) (hist : Hist), (privSp U sh dt k hk i hd1 hd2 cu rt hist).Gd →
      ∀ b, dt.gh k cu rt i b = dt.mm k cu rt i b := by
    intro k hk i hd1 hd2 hist hg b
    have := hg b
    rw [algH_gh U sh dt k cu rt hist i hd2, algM_mm sh dt k cu rt i hd2] at this
    exact this
  refine ⟨fun k hk => ⟨(hG k hk).1, (hG k hk).2.1⟩, ?_, ?_, ?_⟩
  · intro k hk i hrs
    simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
    rcases hk with rfl | rfl | rfl | rfl | rfl | rfl
    · fin_cases i
      · exact hpriv 2 (by decide) 0 (by decide) (by decide) _ (h1 0 (show 0 ∈ w16r2RelKs 1 by decide))
      · exact hpriv 2 (by decide) 1 (by decide) (by decide) _ (h1 1 (show 1 ∈ w16r2RelKs 1 by decide))
    · fin_cases i
      · exact hpriv 14 (by decide) 0 (by decide) (by decide) _ (h1 10 (show 10 ∈ w16r2RelKs 1 by decide))
      · exact hpriv 14 (by decide) 1 (by decide) (by decide) _ (h1 13 (show 13 ∈ w16r2RelKs 1 by decide))
    · fin_cases i
      · exact hpriv 15 (by decide) 0 (by decide) (by decide) _ (h1 5 (show 5 ∈ w16r2RelKs 1 by decide))
      · exact hpriv 15 (by decide) 1 (by decide) (by decide) _ (h1 9 (show 9 ∈ w16r2RelKs 1 by decide))
    · fin_cases i
      · exact SlotW16.part_pointwise (sh.hpart 16 0 (Or.inl rfl)) _ _ (h2 5 (show 5 ∈ w16r2RelKs 2 by decide))
      · exact SlotW16.part_pointwise (sh.hpart 16 1 (Or.inl rfl)) _ _ (h3 5 (show 5 ∈ w16r2RelKs 3 by decide))
    · fin_cases i
      · exact absurd ⟨rfl, rfl⟩ hrs
      · exact hpriv 17 (by decide) 1 (by decide) (by decide) _ (h1 8 (show 8 ∈ w16r2RelKs 1 by decide))
    · fin_cases i
      · exact hpriv 18 (by decide) 0 (by decide) (by decide) _ (h1 11 (show 11 ∈ w16r2RelKs 1 by decide))
      · exact SlotW16.part_pointwise (sh.hpart 18 1 (Or.inr ⟨rfl, rfl⟩)) _ _
          (h2 11 (show 11 ∈ w16r2RelKs 2 by decide))
  · exact (h1 4 (show 4 ∈ w16r2RelKs 1 by decide)).1
  · exact (h1 4 (show 4 ∈ w16r2RelKs 1 by decide)).2

/-! ## A host's named identity from named sums -/

/-- **A host's named identity (`FormAt`) from its named sum and its hosted slots' named sums.** If, on an outcome,
host `k`'s unmasked sum is `Z̃(τ) + Σ_i ν_i·h̃_i(p_i)` over the block's tables (L13's host form with `host_cubeSum`),
its hosted list's weighted unmasked sums are `Σ_i ν_i·M̃_i(p_i)`, and its hosted slots are not hosts, then its
certified polynomial at the drawn challenges is its unmasked residual. -/
theorem formAt_host (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (hk : k ∈ algHosts)
    (hkind : P.kind k = SlotKind.host)
    (hsum : ∀ r df, rs[k]? = some r → P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df →
      (∀ hk' ∈ df.hosted, P.kind hk'.1 ≠ SlotKind.host)
      ∧ ∃ Sh Sm, spSum P Poly bga rs k = Sh
        ∧ (df.hosted.map (fun hk' => hk'.2.toK U * spSum P Poly bga rs hk'.1)).sum = Sm
        ∧ (hostSp U sh dt hcard k hk cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))).Φ
            (fun i => (r.draws.getD i.val Fp2.zero).toK U) = Sh - Sm) :
    FormAt U P Poly (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k := by
  intro r df hr hdf
  obtain ⟨hpriv, Sh, Sm, hSh, hSm, hΦ⟩ := hsum r df hr hdf
  refine Or.inr ⟨hkind, hpriv, ?_⟩
  rw [hSh, hSm, ← hΦ]
  have hk' := hk
  simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk'
  rcases hk' with rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

end Van

end ZK60.Exec.Block
