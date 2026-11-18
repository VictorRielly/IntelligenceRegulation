/-
D63 lane L63 (2026-11-18), part 60: **SIC_QZC's tables at `(b, 0)` are `shdIncLay`'s fields, and its clauses are
`QzcHolds`** (item 4b, step 4 at stage IN-C's layout; generic in the stage's `IncV` under the registered stage's numbers).

At the claims' semantics `stgCsv … w` (the `A_in` and `H_in` matrices at `iA`, `iH`, `B_in` through `csIO` at `iB`)
and the twelve-bit cube point `(b, 0)`:
* `privZ_eq_planeZ`: a table of the main variables `0 … n − 1` is the plane at `b`;
* **`shdQzcR_vals`**: the eight table values are `supp_T`, `u0`, `π`, `κ`, `cq` at `b`, the `A_in` token plane, the
  helper `h_q` (`shdIncHd`), and `B_in`'s row at `r_emb` (`bq`), i.e. `shdIncLay`'s fields;
* **`shd_qzcHolds`**: `inc_qzc_clauses`' five equations there are `QzcHolds (incQ (shdIncLay …) ω (shdIncHd …))`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncVals
import ZK60Formal.RunStgShieldIncQzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Plane

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A table of the main variables `0 … n − 1` at `(b, 0)` is the plane at `b`** (the plane of the same slices and
size). -/
theorem privZ_eq_planeZ (lc R Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) {N : ℕ} (n : ℕ) (b : Fin n → Bool)
    (hN : n < N) (p : Block.Priv) (sl : List (ℕ × Fp2)) (cm' : Block.Cm) (hsl : p.slices = sl) (hlog : p.log = n)
    (hc : p.coords = rhoC 0 p.log) :
    Block.Join.privZ U lc R Q X p (Block.ptK U (Block.xrK n (fun i : Fin N => (bit (cptS n b i) : K))) p.coords)
      = Block.Join.planeZ U lc R Q X ⟨cm', sl, n, [], 0, 0⟩ b := by
  have e1 : ∀ z, Block.Join.privZ U lc R Q X p z = Block.Join.privZ U lc R Q X ⟨cm', sl, n, [], 0, 0⟩ z := by
    intro z
    unfold Block.Join.privZ
    rw [hsl, hlog]
  rw [e1]
  unfold Block.Join.planeZ
  refine Block.Join.privZ_congr U _ _ _ _ _ _ _ (fun a ha => ?_)
  have ha' : a < n := ha
  rw [hc, hlog, ptK_rhoC U _ 0 n a (by omega), Nat.zero_add, xrK_cptS n b a ha' hN, dite_eq_left ha']

end Plane

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- SIC_QZC's table values at `(b, 0)` on `N` variables (`inc_qzc_clauses`' `r` at `tl = 12`). -/
noncomputable def shdQzcR (Vi : IncV) (ch : List Fp2) (cs : Block.Cm → Block.ZClaim → K) (N : ℕ)
    (b : Fin 12 → Bool) (j : ℕ) : K :=
  ((incQzcRest Vi.pub Vi.geo (incCtx Vi.pub ch)).map
    (stgTabK U hbij (StageV.atLog (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN 1)) cs 12 1
      (fun i : Fin N => (bit (cptS 12 b i) : K)))).getD j 0

/-- **SIC_QZC'S TABLES AT `(b, 0)` ARE THE LAYOUT'S FIELDS.** -/
theorem shdQzcR_vals (hU : U ^ 2 = algebraMap GF K 7) (P : InPublic shieldS0) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA rA rH iH rX : ℕ) (hrA : rA = 41) (hrX : rX = 38)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hcsO : ∀ z, csIO w .out z = claimSem U rX 14 256 (bxUxV tag Lq h64 rX iB w) z)
    (ch : List Fp2) (hl : ch.length = 15) (hch : ∀ a ∈ ch, a.Canon)
    (hti : Vi.pub.tiLog = 12) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19) (hGb : Vi.geo.bLogN = 14)
    (hlc : ∀ cx, 0 < (Vi.bp cx).logCols) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hv : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    {N : ℕ} (hN : N = 13) (b : Fin 12 → Bool) :
    let cs := stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w
    let L := shdIncLay U tag h64 P Vi.pub Epad iB iA w hv hV htok hcq
    let ω := incChalOf U ch
    shdQzcR U hbij Vi ch cs N b 0 = L.supp b ∧ shdQzcR U hbij Vi ch cs N b 1 = L.u0 b
      ∧ shdQzcR U hbij Vi ch cs N b 2 = L.pt b ∧ shdQzcR U hbij Vi ch cs N b 3 = L.kap b
      ∧ shdQzcR U hbij Vi ch cs N b 4 = L.cq ω b ∧ shdQzcR U hbij Vi ch cs N b 5 = L.tok b
      ∧ shdQzcR U hbij Vi ch cs N b 6
          = (shdIncHd U tag h64 Vi.pub ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w).1 b
      ∧ shdQzcR U hbij Vi ch cs N b 7 = L.bq ω b := by
  intro cs L ω
  subst hrA hrX
  set I := Vi.pub with hI
  set G := Vi.geo with hG
  set cx := incCtx I ch with hcx
  set P' := StageV.atLog (Vi.bp cx) (incElog I G.bLogN 1) with hP'
  set x : Fin N → K := fun i => (bit (cptS 12 b i) : K) with hx
  have hidx : msbIndex 12 b < 2 ^ I.tiLog := by rw [hti]; exact msbIndex_lt 12 b
  have hsn : 2 ^ I.tiLog = 2 ^ 12 := by rw [hti]
  have hNlt : 12 < N := by omega
  -- the eight values, through `List.getD` of the explicit list
  have g0 : shdQzcR U hbij Vi ch cs N b 0 = stgTabK U hbij P' cs 12 1 x (.pub (supp I.tokens (2 ^ I.tiLog))) := rfl
  have g1 : shdQzcR U hbij Vi ch cs N b 1 = stgTabK U hbij P' cs 12 1 x (.pub (supp 1 (2 ^ I.tiLog))) := rfl
  have g2 : shdQzcR U hbij Vi ch cs N b 2 = stgTabK U hbij P' cs 12 1 x
      (.pub ((List.range (2 ^ I.tiLog)).map (fun t => if I.isTemplate t then Fp2.one else Fp2.zero))) := rfl
  have g3 : shdQzcR U hbij Vi ch cs N b 3 = stgTabK U hbij P' cs 12 1 x
      (.pub ((List.range (2 ^ I.tiLog)).map (fun t => kI (I.kappa t)))) := rfl
  have g4 : shdQzcR U hbij Vi ch cs N b 4 = stgTabK U hbij P' cs 12 1 x
      (.pub ((List.range (2 ^ I.tiLog)).map (fun t => if I.ctlQ t then cx.beta.mul cx.beta else Fp2.zero))) := rfl
  have g5 : shdQzcR U hbij Vi ch cs N b 5 = stgTabK U hbij P' cs 12 1 x
      (.priv ⟨.a, [((incLay I G.bLogN).aOff incA_TOK, Fp2.one)], (incLay I G.bLogN).aLog.getD incA_TOK 0,
        rhoC 0 ((incLay I G.bLogN).aLog.getD incA_TOK 0),
        (incLay I G.bLogN).aMaskBase + 2 * ((incLay I G.bLogN).prefixA 1 + 0), 0⟩) := rfl
  have g6 : shdQzcR U hbij Vi ch cs N b 6 = stgTabK U hbij P' cs 12 1 x
      (.priv ⟨.h, [(((incLay I G.bLogN).hOff incH_Q).1, Fp2.one), (((incLay I G.bLogN).hOff incH_Q).2, Block.fp2U)],
        (incLay I G.bLogN).hLog.getD incH_Q 0, rhoC 0 ((incLay I G.bLogN).hLog.getD incH_Q 0),
        (incLay I G.bLogN).hMaskBase + 2 * ((incLay I G.bLogN).prefixH 1 + 0), 0⟩) := rfl
  have g7 : shdQzcR U hbij Vi ch cs N b 7 = stgTabK U hbij P' cs 12 1 x
      (.priv ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb, G.bInRow, 0⟩) := rfl
  have hpub : ∀ pv : List Fp2, pv.length = 2 ^ I.tiLog →
      stgTabK U hbij P' cs 12 1 x (.pub pv) = (pv.getD (msbIndex 12 b) Fp2.zero).toK U := by
    intro pv hpv
    exact stgTabK_pub_cptS U hbij P' cs 12 b hN pv (by rw [hpv, hsn])
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · -- `supp_T`
    rw [g0, hpub _ (by simp [supp]), supp_getD_toK U _ _ _ hidx]
    rfl
  · -- `u0`
    rw [g1, hpub _ (by simp [supp]), supp_getD_toK U _ _ _ hidx]
    rfl
  · -- `π`
    rw [g2, hpub _ (by simp), rangeMap_getD _ _ hidx]
    show _ = (if I.isTemplate (msbIndex 12 b) then (1 : K) else 0)
    by_cases ht : I.isTemplate (msbIndex 12 b) = true
    · simp only [ht, ↓reduceIte, Fp2.toK_one]
    · simp only [ht, Bool.false_eq_true, ↓reduceIte, Fp2.toK_zero]
  · -- `κ`
    rw [g3, hpub _ (by simp), rangeMap_getD _ _ hidx, kI_nat_toK U _ (hkap _)]
    rfl
  · -- `cq`
    rw [g4, hpub _ (by simp), rangeMap_getD _ _ hidx]
    show _ = (if I.ctlQ (msbIndex 12 b) then ω.1.1.1 ^ 2 else 0)
    by_cases ht : I.ctlQ (msbIndex 12 b) = true
    · simp only [ht, ↓reduceIte, Fp2.toK_mul U hU, sq]
      rfl
    · simp only [ht, Bool.false_eq_true, ↓reduceIte, Fp2.toK_zero]
  · -- the `A_in` token plane
    rw [g5]
    refine (stgTabK_priv_cptS U hbij hU P' cs 41 ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 41 iA w) (by decide) 12 b hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < I.tiLog; omega) (by simp [rhoC]) (by exact hlc cx)
      (by intro c hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 12 b hNlt _ [((incLay I 14).aOff incA_TOK, Fp2.one)] .a
      (by rw [hGb]) (by show I.tiLog = 12; exact hti) rfl]
    rfl
  · -- the helper `h_q`
    rw [g6]
    refine (stgTabK_priv_cptS U hbij hU P' cs rH ogStage.lc ogStage.Q
      (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w) (by decide) 12 b hN _ (by intro _; rfl)
      (by exact List.cons_ne_nil _ _) (by show 0 < I.tiLog; omega) (by simp [rhoC]) (by exact hlc cx)
      (by intro c hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
    rw [privZ_eq_planeZ U _ _ _ _ 12 b hNlt _
      [(((incLay I 14).hOff incH_Q).1, Fp2.one), (((incLay I 14).hOff incH_Q).2, Block.fp2U)] .h
      (by rw [hGb]) (by show I.tiLog = 12; exact hti) rfl]
    rfl
  · -- `B_in`'s row at `r_emb`
    have hrE : cx.rEmb.length = 12 := by
      show (ch.drop 3).length = 12
      rw [List.length_drop, hl]
    have hrEc : ∀ a ∈ cx.rEmb, a.Canon := fun a ha => hch a (List.mem_of_mem_drop ha)
    have hlen : (rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb).length = I.bInLog := by
      simp [rhoC, fixedC, hrE, hti, htB, hbIn]
    rw [g7]
    refine (stgTabK_priv_cptS U hbij hU P' cs 38 14 256 (bxUxV tag Lq h64 38 iB w) (by norm_num) 12 b hN _
      (by exact hcsO) (by exact List.cons_ne_nil _ _) (by show 0 < I.bInLog; rw [hbIn]; norm_num) (by exact hlen)
      (by show 0 < G.bLogN; omega)
      (by
        intro c hc w' hw
        rcases List.mem_append.mp hc with hc | hc
        · simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw
        · simp only [fixedC, List.mem_map] at hc
          obtain ⟨a, ha, rfl⟩ := hc
          have he := Block.Coord.fixed.inj hw
          subst he
          exact hrEc _ ha)).trans ?_
    -- the functional is the plane's extension at `(b's low bits, r_emb)`
    have e1 : ∀ z, Block.Join.privZ U 14 38 256 (bxUxV tag Lq h64 38 iB w)
        ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb, G.bInRow, 0⟩ z
        = Block.Join.privZ U 14 38 256 (bxUxV tag Lq h64 38 iB w) ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩ z := by
      intro z
      unfold Block.Join.privZ
      show Block.claimK 14 38 256 _ ([(0, Fp2.one)].map fun sc => (⟨sc.1, I.bInLog, sc.2.toK U, z⟩ : Block.PartK K))
        = Block.claimK 14 38 256 _ ([(0, Fp2.one)].map fun sc => (⟨sc.1, 19, sc.2.toK U, z⟩ : Block.PartK K))
      rw [hbIn]
    rw [e1, privZ_mleF U P' 14 38 256 _ (by norm_num) _ (List.cons_ne_nil _ _) (by norm_num)]
    -- the point, split as `(7 low bits of b, r_emb)`
    have hpt : (fun a : Fin 19 => Block.ptK U (Block.xrK 12 x)
          (rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb) a.val)
        = Fin.append (fun i : Fin 7 => (bit (b ⟨5 + i.val, by omega⟩) : K))
            (fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U) := by
      funext a
      change Fin (7 + 12) at a
      refine Fin.addCases (fun i => ?_) (fun i => ?_) a
      · rw [Fin.append_left]
        have hi : (Fin.castAdd 12 i).val = i.val := rfl
        rw [hi]
        have hq : i.val < I.tiLog - (I.tiLog - I.tBits) := by rw [hti, htB]; have := i.isLt; omega
        rw [Block.ptK, List.getElem?_append_left (by simp [rhoC]; omega)]
        have h2 := ptK_rhoC U (Block.xrK 12 x) (I.tiLog - I.tBits) I.tiLog i.val hq
        unfold Block.ptK at h2
        rw [h2, hti, htB]
        exact xrK_cptS 12 b (5 + i.val) (by omega) hNlt
      · rw [Fin.append_right]
        have hi : (Fin.natAdd 7 i).val = 7 + i.val := rfl
        rw [hi, ptK_rhoC_fixed U (Block.xrK 12 x) (I.tiLog - I.tBits) I.tiLog cx.rEmb (7 + i.val)
          (by rw [hti, htB]; omega)]
        have hsub : 7 + i.val - (I.tiLog - (I.tiLog - I.tBits)) = i.val := by rw [hti, htB]; omega
        rw [hsub]
        show ((ch.drop 3).getD i.val Fp2.zero).toK U = _
        rw [List.getD_eq_getElem?_getD, List.getElem?_drop, ← List.getD_eq_getElem?_getD]
    rw [hpt]
    have h7 := Block.Join.W16.Qkv.mleAt_app' (a := 7) (b := 12)
      (Block.Join.planeZ U 14 38 256 (bxUxV tag Lq h64 38 iB w) ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩)
      (fun i : Fin 7 => (bit (b ⟨5 + i.val, by omega⟩) : K)) (fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U)
    rw [h7, mleAt_bit]
    -- the layout's `bq`
    show _ = mleAt (fun c => stgPlK U tag h64 14 16 256 24448 38 iB 0 19 w
      (Fin.append (msbBits 7 (msbIndex 12 b % 128)) c)) (fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U)
    have hlow : msbBits 7 (msbIndex 12 b % 128) = fun i : Fin 7 => b ⟨5 + i.val, by omega⟩ :=
      funext (bits7_low b)
    rw [hlow]
    rfl

end Vals

end ZK60.ProtocolClassify
