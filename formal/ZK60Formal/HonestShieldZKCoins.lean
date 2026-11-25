/-
D63 lane L69, Milestone A Part 1 (`HonestShieldZKCoins.lean`):
instantiates the concrete product coin space
  `ShdCoins := ShdViewCoins GF shdP_K shdP_L1Spec shdP_L2Spec`
(so `π := id`, `hπ := PMF.map_id _`, and `2^512 ∣ Fintype.card ShdCoins` from
`HonestShieldZKCount.dvd_512_shdViewCoins`), defines the exact coin projections
`shdEpBase`, `shdBndRndOf`, `shdIncRndOf`, `shdBlkRndOf`, `shdOutcRndOf` feeding
`HonestShieldTop.shdP_honestRunP`, and proves the single-salt / single-coordinate
independence equivalences needed for `hfreshL`, `hpairs`, and `hcond_hid`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldTop

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.ProtocolClassify ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.HonestClassify (ofK toK_ofK)

/-! ## 1. Concrete product coin space `ShdCoins` & trivial uniform projection `π := id` -/

/-- Concrete product coin space for the full 28-segment Shieldstral T128 R13 honest prover:
Level-1 coins (`TE`, `B_0..26`, `A_0..27`, `H_0..27` polynomials + leaf salts) paired with
Level-2 coins (`28` segments' CFS sumcheck mask coefficients + `M`-table pads/b/u + `M` leaf salts). -/
abbrev ShdCoins : Type := ShdViewCoins GF shdP_K shdP_L1Spec shdP_L2Spec

noncomputable instance instInhabitedShdCoins : Inhabited ShdCoins :=
  ⟨Classical.choice inferInstance⟩

/-- `π := id` preserves the uniform distribution on `ShdCoins` trivially (`hπ` of `ShdZKProgWitness`). -/
theorem shdCoins_hpi :
    (PMF.uniformOfFintype ShdCoins).map (id : ShdCoins → ShdCoins) = PMF.uniformOfFintype ShdCoins :=
  PMF.map_id _

/-- `2^512 ∣ Fintype.card ShdCoins` (`h512` of `ShdZKCountWitness`), directly from `dvd_512_shdViewCoins`. -/
theorem shdCoins_h512 : 2 ^ 512 ∣ Fintype.card ShdCoins :=
  dvd_512_shdViewCoins

/-! ## 2. Exact low-level coin packing helpers -/

/-- Extend a `Fin (2^d) → Dig` salt vector to `ℕ → Dig` with `zeroDig` outside `[0, 2^d)`. -/
def extSalt {d : ℕ} (s : Fin (2 ^ d) → Dig) (j : ℕ) : Dig :=
  if hj : j < 2 ^ d then s ⟨j, hj⟩ else zeroDig

theorem extSalt_lt {d : ℕ} (s : Fin (2 ^ d) → Dig) {j : ℕ} (hj : j < 2 ^ d) :
    extSalt s j = s ⟨j, hj⟩ :=
  dite_eq_left hj

/-- Extract message slice (`Sum.inl`) of a `Hiding.Row GF n 256`. -/
def rowMsg {n : ℕ} (r : Hiding.Row GF n 256) (col : Fin n) : GF :=
  r (Sum.inl col)

/-- Extract pad slice (`Sum.inr`) of a `Hiding.Row GF n 256` as canonical `Fp` words. -/
def rowPadFp {n : ℕ} (r : Hiding.Row GF n 256) (p : Fin 256) : Fp :=
  Fp.ofGF (r (Sum.inr p))

/-- Pack a standard PCS table's site-mask rows `Γ × Bool → Row` into `Fin (2 * g) → Fin n → GF`:
pair `i : Fin (2 * g)` maps to `(⟨i / 2, _⟩, i % 2 == 0)` (`true` = `a`-row, `false` = `b`-row). -/
def packSiteMask {n g : ℕ} (site : Fin g × Bool → Hiding.Row GF n 256) (i : Fin (2 * g)) : Fin n → GF :=
  rowMsg (site (⟨i.val / 2, by omega⟩, decide (i.val % 2 = 0)))

/-- Pack a standard PCS table's proximity pair `Bool → Row` into `Fin 2 → Fin n → GF`
(`0 ↦ true`, `1 ↦ false`). -/
def packProxMask {n : ℕ} (prox : Bool → Hiding.Row GF n 256) (i : Fin 2) : Fin n → GF :=
  rowMsg (prox (decide (i.val = 0)))

/-- Pack all `d + 2*g + 2` pad rows of a standard PCS table (`TE`, `B`, `A`) as canonical `Fp` words. -/
def packStdPads {n d g : ℕ} (c : Hiding.Coins GF n 256 (Fin d) (Fin g))
    (r : Fin (d + 2 * g + 2)) (p : Fin 256) : Fp :=
  if h1 : r.val < d then Fp.ofGF (c.1 ⟨r.val, h1⟩ p)
  else if h2 : r.val < d + 2 * g then
    rowPadFp (c.2.1 (⟨(r.val - d) / 2, by omega⟩, decide ((r.val - d) % 2 = 0))) p
  else
    rowPadFp (c.2.2 (decide (r.val = d + 2 * g))) p

/-- Pack all `d + 2 + 2*g + 2` pad rows of an `H` PCS table (data, `H_U` re/im, site masks, prox)
as canonical `Fp` words. -/
def packHPads {n d g : ℕ} (c : Hiding.CoinsH GF n 256 (Fin d) (Fin g))
    (r : Fin (d + 2 + 2 * g + 2)) (p : Fin 256) : Fp :=
  if h1 : r.val < d then Fp.ofGF (c.1 ⟨r.val, h1⟩ p)
  else if h2 : r.val < d + 2 then
    rowPadFp (c.2.1 (decide (r.val = d))) p
  else if h3 : r.val < d + 2 + 2 * g then
    rowPadFp (c.2.2.1 (⟨(r.val - (d + 2)) / 2, by omega⟩, decide ((r.val - (d + 2)) % 2 = 0))) p
  else
    rowPadFp (c.2.2.2 (decide (r.val = d + 2 + 2 * g))) p

/-- Pack `H_U`'s raw random pair (`true` = re, `false` = im) from `Hiding.CoinsH`. -/
def packHURaw {n d g : ℕ} (c : Hiding.CoinsH GF n 256 (Fin d) (Fin g)) (col : Fin n) : GF × GF :=
  (rowMsg (c.2.1 true) col, rowMsg (c.2.1 false) col)

/-- Linear index into `CfsCoeffs shdP_K n d`: `0 ↦ a0`, `1 ↦ a'`, `2 + r*d + e ↦ a_{r,e}`. -/
noncomputable def cfsCoefAt {n d : ℕ} (hd : 1 ≤ d) (cf : Hiding.CfsCoeffs shdP_K n d) (j : ℕ) : shdP_K :=
  if j = 0 then cf.1
  else if j = 1 then cf.2.1
  else if hj : j - 2 < (n + 1) * d then
    cf.2.2 ⟨(j - 2) / d, Nat.div_lt_of_lt_mul (by rw [Nat.mul_comm]; exact hj)⟩
      ⟨(j - 2) % d, Nat.mod_lt _ (by omega)⟩
  else 0

/-- Pack one segment `s`'s `M`-table `mA : Fin (shdSegNS s) → Fin 512 → Fp2` from its Level-2 coins:
- `[0, L_t)`: `ofK shdP_U shdP_hbij (cfsCoefAt _ (cfs t) j)` (exact CFS mask coefficients),
- `[L_t, L_t + 256)`: `⟨Fp.ofGF (mPads t true _), Fp.ofGF (mPads t false _)⟩` (`256` pads per row,
  fitting inside `512` by `shdP_L2_slot_bounds`),
- `[L_t + 256, 512)`: `Fp2.zero`. -/
noncomputable def packSegMA (s : Fin 28) (c2 : SegL2Coins GF shdP_K (shdP_L2Spec s))
    (t : Fin (shdSegNS s)) (j : Fin 512) : Fp2 :=
  let L := shdP_slotMaskLen s t
  if hlt : j.val < L then
    ofK shdP_U shdP_hbij (cfsCoefAt (shdP_L2_slot_bounds s t).1 (c2.1.1 t) j.val)
  else if hj : j.val < L + 256 then
    ⟨Fp.ofGF (c2.1.2.1 t true ⟨j.val - L, by change j.val - L < 256; omega⟩),
     Fp.ofGF (c2.1.2.1 t false ⟨j.val - L, by change j.val - L < 256; omega⟩)⟩
  else Fp2.zero

/-! ## 3. Exact coin projections feeding `HonestShieldTop.shdP_honestRunP` -/

/-- Input endpoint opening randomness `epBase : ShdCoins → EpxSalt 6` from `c.1.1` (`TE` coins).
Row layout matches `shdP_epTable` / `checkTokenEp`:
- row `0`: token data (overwritten by `epxMsg`), pad `datPads 0`,
- rows `1..2`: site-mask pair `siteRows (0, true/false)`,
- rows `3..4`: proximity pair `proxRows (true/false)`,
- row `5`: unused 6th row (`msgs := 0`, pad `datPads 1`). -/
def shdEpBase (c : ShdCoins) : EpxSalt 6 where
  msgs := fun r col =>
    if r.val = 1 then rowMsg (c.1.1.1.2.1 (⟨0, by decide⟩, true)) col
    else if r.val = 2 then rowMsg (c.1.1.1.2.1 (⟨0, by decide⟩, false)) col
    else if r.val = 3 then rowMsg (c.1.1.1.2.2 true) col
    else if r.val = 4 then rowMsg (c.1.1.1.2.2 false) col
    else 0
  pads := fun r p =>
    if r.val = 0 then c.1.1.1.1 ⟨0, by decide⟩ p
    else if r.val = 1 then c.1.1.1.2.1 (⟨0, by decide⟩, true) (Sum.inr p)
    else if r.val = 2 then c.1.1.1.2.1 (⟨0, by decide⟩, false) (Sum.inr p)
    else if r.val = 3 then c.1.1.1.2.2 true (Sum.inr p)
    else if r.val = 4 then c.1.1.1.2.2 false (Sum.inr p)
    else c.1.1.1.1 ⟨1, by decide⟩ p
  salts := c.1.1.2
  paths := fun _ => []

/-- Boundary `k : Fin 27` randomness `BndRand` projected from `c.1.2.1 k` (`B_0..26`). -/
def shdBndRndOf (c : ShdCoins) (k : Fin 27) : BndRand where
  bMask := packSiteMask (c.1.2.1 k).1.2.1
  bProx := packProxMask (c.1.2.1 k).1.2.2
  bPads := packStdPads (c.1.2.1 k).1
  bSalts := extSalt (c.1.2.1 k).2

/-- Stage IN-C randomness `IncRand` projected from `c.1.2.2 0` (`A_0, H_0`), `c.1.2.1 0` (`B_0`),
and `c.2 0` (`M_0` + 4 slot CFS masks). -/
noncomputable def shdIncRndOf (c : ShdCoins) : IncRand :=
  let ah0 : PcsAHCoins GF ⟨shdP_incASpec, shdP_incHSpec⟩ := c.1.2.2 ⟨0, by decide⟩
  let b0 := shdBndRndOf c ⟨0, by decide⟩
  let l20 := c.2 ⟨0, by decide⟩
  { aMask := packSiteMask ah0.1.1.2.1
    aProx := packProxMask ah0.1.1.2.2
    aPads := packStdPads ah0.1.1
    aSalts := extSalt ah0.2.1
    hMask := packSiteMask ah0.1.2.2.2.1
    hProx := packProxMask ah0.1.2.2.2.2
    hURaw := packHURaw ah0.1.2
    hPads := packHPads ah0.1.2
    hSalts := extSalt ah0.2.2
    bMask := b0.bMask
    bProx := b0.bProx
    bPads := b0.bPads
    bSalts := b0.bSalts
    mA := packSegMA ⟨0, by decide⟩ l20
    mBRe := l20.1.2.2.1 true
    mBIm := l20.1.2.2.1 false
    mURe := l20.1.2.2.2 true
    mUIm := l20.1.2.2.2 false
    mSalts := extSalt l20.2 }

/-- Interior R13 block `k : Fin 26` randomness `BlkRand` projected from segment `s = k + 1`:
`c.1.2.2 (k+1)` (`A, H`), `c.1.2.1 (k+1)` (`B_{k+1}`), and `c.2 (k+1)` (`M` + 23 slot CFS masks). -/
noncomputable def shdBlkRndOf (c : ShdCoins) (k : Fin 26) : BlkRand :=
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  have hs0 : s.val ≠ 0 := by dsimp [s]; omega
  have hs27 : s.val ≠ 27 := by dsimp [s]; omega
  have hah : shdP_L1Spec.ah s = ⟨shdP_blkASpec, shdP_blkHSpec⟩ := by
    dsimp [shdP_L1Spec]
    rw [ite_eq_right hs0, ite_eq_right hs27]
  have hns : shdSegNS s = 23 := by
    dsimp [shdSegNS]
    rw [ite_eq_right hs0, ite_eq_right hs27]
  let ahk : PcsAHCoins GF ⟨shdP_blkASpec, shdP_blkHSpec⟩ := hah ▸ c.1.2.2 s
  let l2k := c.2 s
  { aMask := packSiteMask ahk.1.1.2.1
    aProx := packProxMask ahk.1.1.2.2
    aPads := packStdPads ahk.1.1
    aSalts := extSalt ahk.2.1
    hMask := packSiteMask ahk.1.2.2.2.1
    hProx := packProxMask ahk.1.2.2.2.2
    hURaw := packHURaw ahk.1.2
    hPads := packHPads ahk.1.2
    hSalts := extSalt ahk.2.2
    mA := fun t => packSegMA s l2k ⟨t.val, by omega⟩
    mBRe := l2k.1.2.2.1 true
    mBIm := l2k.1.2.2.1 false
    mURe := l2k.1.2.2.2 true
    mUIm := l2k.1.2.2.2 false
    mSalts := extSalt l2k.2
    bnd := shdBndRndOf c ⟨k.val + 1, by omega⟩ }

/-- Stage OUT-C randomness `OutcRand` projected from `c.1.2.2 27` (`A_27, H_27`) and `c.2 27`
(`M_27` + 8 slot CFS masks). -/
noncomputable def shdOutcRndOf (c : ShdCoins) : OutcRand :=
  let s : Fin 28 := ⟨27, by decide⟩
  let ah27 : PcsAHCoins GF ⟨shdP_outcASpec, shdP_outcHSpec⟩ := c.1.2.2 s
  let l227 := c.2 s
  { aMask := packSiteMask ah27.1.1.2.1
    aProx := packProxMask ah27.1.1.2.2
    aPads := packStdPads ah27.1.1
    aSalts := extSalt ah27.2.1
    hMask := packSiteMask ah27.1.2.2.2.1
    hProx := packProxMask ah27.1.2.2.2.2
    hURaw := packHURaw ah27.1.2
    hPads := packHPads ah27.1.2
    hSalts := extSalt ah27.2.2
    mA := packSegMA s l227
    mBRe := l227.1.2.2.1 true
    mBIm := l227.1.2.2.1 false
    mURe := l227.1.2.2.2 true
    mUIm := l227.1.2.2.2 false
    mSalts := extSalt l227.2 }

/-! ## 4. Independent-salt splitting equivalences (for `hfreshL`, `hpairs`, `hcond_hid`) -/

/-- Generic single-coordinate split of a finite function space `(ι → α) ≃ ({i : ι // i ≠ j} → α) × α`. -/
def piSplitAt {ι α : Type} [DecidableEq ι] (j : ι) : (ι → α) ≃ ({i : ι // i ≠ j} → α) × α where
  toFun f := (fun i => f i.1, f j)
  invFun p i := if h : i = j then p.2 else p.1 ⟨i, h⟩
  left_inv f := by
    funext i
    by_cases h : i = j
    · subst h; simp
    · simp [h]
  right_inv p := by
    cases p with
    | mk g a =>
      apply Prod.ext
      · funext ⟨i, hi⟩; simp [hi]
      · simp

/-- `ShdCoins` splits off any single `TE` leaf salt `j : Fin (2^11)` as an independent uniform `Dig` factor. -/
noncomputable def shdCoinsSplitTeSalt (j : Fin (2 ^ 11)) :
    ShdCoins ≃ (((Hiding.Coins GF shdP_teSpec.n shdP_teSpec.Q shdP_teSpec.Dat shdP_teSpec.Γ
      × ({i : Fin (2 ^ 11) // i ≠ j} → Dig))
      × ((k : Fin 27) → PcsStdCoins GF (shdP_L1Spec.bnd k))
      × ((s : Fin 28) → PcsAHCoins GF (shdP_L1Spec.ah s)))
      × ShdL2Coins GF shdP_K shdP_L2Spec) × Dig where
  toFun c := ((((c.1.1.1, (piSplitAt j c.1.1.2).1), c.1.2.1, c.1.2.2), c.2), c.1.1.2 j)
  invFun p := (((p.1.1.1.1, (piSplitAt j).symm (p.1.1.1.2, p.2)), p.1.1.2.1, p.1.1.2.2), p.1.2)
  left_inv c := by
    rcases c with ⟨⟨⟨c1, sl⟩, bnd, ah⟩, l2⟩
    have h := (piSplitAt j).left_inv sl
    exact Prod.ext (Prod.ext (Prod.ext rfl h) rfl) rfl
  right_inv p := by
    rcases p with ⟨⟨⟨⟨c1, g⟩, bnd, ah⟩, l2⟩, d⟩
    have h := (piSplitAt j).right_inv (g, d)
    have h1 : (piSplitAt j ((piSplitAt j).symm (g, d))).1 = g := congrArg Prod.fst h
    have h2 : (piSplitAt j ((piSplitAt j).symm (g, d))).2 = d := congrArg Prod.snd h
    exact Prod.ext (Prod.ext (Prod.ext (Prod.ext rfl h1) rfl) rfl) h2

theorem shdEpBase_salts_eq (c : ShdCoins) (j : Fin (2 ^ 11)) :
    (shdEpBase c).salts j = (shdCoinsSplitTeSalt j c).2 := rfl

end ZK60.HonestShield
