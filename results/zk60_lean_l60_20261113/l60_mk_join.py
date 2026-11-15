#!/usr/bin/env python3
"""D63 lane L60 (2026-11-13): generate the Stage + Block + Endpoint Join modules:
  - formal/ZK60Formal/RunStgJoinLk.lean
  - formal/ZK60Formal/RunStgJoinBnd.lean
  - formal/ZK60Formal/RunStgJoinSem.lean
  - formal/ZK60Formal/RunStgJoinChain.lean
  - formal/ZK60Formal/RunStgJoinTop.lean
Every transformation of existing compiled modules is count-asserted.
Only `propext`, `Classical.choice`, `Quot.sound`.
"""
import re
import sys
from pathlib import Path

WT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
L = WT / "formal/ZK60Formal"


def once(text: str, old: str, new: str) -> str:
    n = text.count(old)
    assert n == 1, f"expected 1 occurrence of {old[:95]!r}, got {n}"
    return text.replace(old, new)


def rep(text: str, old: str, new: str, count: int) -> str:
    n = text.count(old)
    assert n == count, f"expected {count} occurrences of {old[:95]!r}, got {n}"
    return text.replace(old, new)


def section(src: str, name: str) -> str:
    i = src.index(f"section {name}\n")
    j = src.index(f"end {name}\n", i) + len(f"end {name}\n")
    return src[i:j]


def cut(text: str, start: str, stop: str) -> str:
    a = text.index(start)
    assert text.count(start) == 1, start[:75]
    b = text.index(stop, a)
    return text[a:b]


def redoc(sec: str, theorem_head: str, doc: str) -> str:
    t = sec.index(theorem_head)
    d = sec.rindex("/-- ", 0, t)
    return sec[:d] + doc + "\n" + sec[t:]


def top_binders(text: str):
    i = text.index(" ") + 1
    i = text.index(" ", i)
    out = []
    depth = 0
    start = None
    opener = None
    pairs = {"(": ")", "{": "}", "[": "]", "⦃": "⦄"}
    closers = set(pairs.values())
    while i < len(text):
        c = text[i]
        if depth == 0 and c == ":" and text[i:i + 2] == ":=":
            break
        if depth == 0 and c == ":" and opener is None:
            break
        if c in pairs:
            if depth == 0:
                start = i
                opener = c
            depth += 1
        elif c in closers:
            depth -= 1
            if depth == 0 and opener is not None:
                grp = text[start:i + 1]
                inner = grp[1:-1]
                names = []
                if opener in "({" and ":" in inner:
                    names = inner[:inner.index(":")].split()
                out.append((opener, names, start, i + 1))
                opener = None
        i += 1
    return out


# ----------------------------------------------------------------------------
# 1. RunStgJoinLk.lean: lkSqB, lkSqB_rbr, ra_lk_blkB, lkSqB_cut, RaLkAtB, ra_hal_luB,
#                       DefSchedB, rd_hdrX_take, RdBlkR13B, rd_hdblkB
# ----------------------------------------------------------------------------
adef = (L / "RunAliveDef.lean").read_text()
lk_i = adef.index("theorem ra_lk_blk ")
lk_d = adef.rindex("/-- ", 0, lk_i)
lk_j = adef.index("\nend DefAlive\n", lk_i)
ra_lk_src = adef[lk_d:lk_j]
ra_lk_src = once(ra_lk_src, "theorem ra_lk_blk ", "theorem ra_lk_blkB ")
ra_lk_src = once(ra_lk_src, "(lkSq hdrLen absOf Alk T mlk)", "(lkSqB hdrLen absOf Alk T mlk)")
ra_lk_src = once(ra_lk_src, "(Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K)",
                 "(Alk : List (QB L × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K)")
ra_lk_src = once(ra_lk_src, "(mlk : List (QB L × Dig) → κ → K)",
                 "(mlk : List (QB L × Dig) × Option (List UInt8) → κ → K)")
ra_lk_src = once(ra_lk_src, "(Alk (cutO absOf (some core.aRoot.toList) Lg) l)",
                 "(Alk (cutO absOf (some core.aRoot.toList) Lg, some core.aRoot.toList) l)")
ra_lk_src = once(ra_lk_src, "(mlk (cutO absOf (some core.aRoot.toList) Lg))",
                 "(mlk (cutO absOf (some core.aRoot.toList) Lg, some core.aRoot.toList))")
TA_EXPR = ("(absAt ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)\n"
           "        (hdr ++ rootOpsA P core) ++ _).take (hdrLen + 4)) hdrLen)")
ra_lk_src = rep(ra_lk_src, f"(cutO absOf {TA_EXPR} Lg)", f"(cutO absOf {TA_EXPR} Lg, {TA_EXPR})", 2)

lk_blk = """omit [Algebra GF K] in
/-- **LogUp as a squeeze-run sub-protocol whose lookup and multiplicity readers also receive `absAt hdr hdrLen`.** -/
def lkSqB [DecidableEq K] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Alk : List (QB L × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K)
    (T : κ → Tup K) (mlk : List (QB L × Dig) × Option (List UInt8) → κ → K) : SqX K L where
  a := hdrLen + 4
  n := 3
  e := Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card
  St Lg hdr τ := lkSt3 (Alk (cutO absOf (absAt hdr hdrLen) Lg, absAt hdr hdrLen)) T
    (mlk (cutO absOf (absAt hdr hdrLen) Lg, absAt hdr hdrLen)) τ

omit [Algebra GF K] in
/-- Its round condition: `lkSt3_rbr`. -/
theorem lkSqB_rbr [DecidableEq K] [Fintype K] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Alk : List (QB L × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K)
    (T : κ → Tup K) (mlk : List (QB L × Dig) × Option (List UInt8) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K) : (lkSqB hdrLen absOf Alk T mlk).Rbr :=
  fun _ _ τ mg hτ hns => lkSt3_rbr _ T _ hN τ mg hτ hns

""" + ra_lk_src

ahal = (L / "RunAliveHal.lean").read_text()
ralk_i = ahal.index("def RaLkAt ")
ralk_d = ahal.rindex("/-- ", 0, ralk_i)
ralk_j = ahal.index("\nend ", ralk_i)
ralk_sec = ahal[ralk_d:ralk_j]
ralk_sec = ralk_sec.replace("def RaLkAt ", "def RaLkAtB ")
ralk_sec = ralk_sec.replace("theorem lkSq_cut ", "theorem lkSqB_cut ")
ralk_sec = ralk_sec.replace("Block.lkSq ", "Block.lkSqB ")
ralk_sec = ralk_sec.replace("Exec.Block.lkSq ", "Exec.Block.lkSqB ")
ralk_sec = ralk_sec.replace("(Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K)",
                            "(Alk : List (QB L × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K)")
ralk_sec = ralk_sec.replace("(mlk : List (QB L × Dig) → κ → K)",
                            "(mlk : List (QB L × Dig) × Option (List UInt8) → κ → K)")
ralk_sec = ralk_sec.replace("(Alk : List (QB Lq × Dig) → ι ⊕ (π ⊕ π) → Tup K)",
                            "(Alk : List (QB Lq × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K)")
ralk_sec = ralk_sec.replace("(mlk : List (QB Lq × Dig) → κ → K)",
                            "(mlk : List (QB Lq × Dig) × Option (List UInt8) → κ → K)")
ralk_sec = ralk_sec.replace("(Block.cutO absOf (some core.aRoot.toList) lg) l",
                            "(Block.cutO absOf (some core.aRoot.toList) lg, some core.aRoot.toList) l")
ralk_sec = ralk_sec.replace("(mlk (Block.cutO absOf (some core.aRoot.toList) lg))",
                            "(mlk (Block.cutO absOf (some core.aRoot.toList) lg, some core.aRoot.toList))")
ralk_sec = ralk_sec.replace("(cutO absOf (some core.aRoot.toList) lg) l",
                            "(cutO absOf (some core.aRoot.toList) lg, some core.aRoot.toList) l")
ralk_sec = ralk_sec.replace("(mlk (cutO absOf (some core.aRoot.toList) lg))",
                            "(mlk (cutO absOf (some core.aRoot.toList) lg, some core.aRoot.toList))")

hal_sec_full = section(ahal, "Hal")
hal_vars = hal_sec_full[:hal_sec_full.index("/-- **The block part's segment**")]
lu_i = hal_sec_full.index("theorem ra_hal_lu ")
lu_d = hal_sec_full.rindex("/-- ", 0, lu_i)
lu_j = hal_sec_full.index("\nend Hal\n", lu_i)
hal_lu = hal_vars + hal_sec_full[lu_d:lu_j] + "\n\nend Hal\n"
hal_lu = once(hal_lu, "section Hal\n", "section HalLkB\n")
hal_lu = once(hal_lu, "end Hal\n", "end HalLkB\n")
hal_lu = once(hal_lu, "theorem ra_hal_lu ", "theorem ra_hal_luB ")
hal_lu = once(hal_lu, "(Alk : (k : ℕ) → List (QB Lq × Dig) → ι k ⊕ (π k ⊕ π k) → Tup K)",
              "(Alk : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → ι k ⊕ (π k ⊕ π k) → Tup K)")
hal_lu = once(hal_lu, "(mlk : (k : ℕ) → List (QB Lq × Dig) → κ k → K)",
              "(mlk : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → κ k → K)")
hal_lu = once(hal_lu, "RaLkAt U key domain", "RaLkAtB U key domain")
hal_lu = once(hal_lu, "Block.ra_lk_blk U key domain", "Block.ra_lk_blkB U key domain")

DOOM_B = """
section DoomB

open ZK60.Block (BlockShape BlockPublic)
open ZK60.Exec.Block (defSqB tHistD defPos lkSqB AlgShape AlgData algSp algGood_of_gd w16r2DR w16r2RelKs SchedGd
  histOf SlotRec Hist R13Spec r13Rels_of_algGood hbr_r13_of_cover tupK R13Query rootsAt cuts3 cutO absAt
  Cuts3 RootsO W16Pos HdrX hdrX)
open ZK60.Layout (W16Layout W16Pub)
open ZK60.Layout.R13 (R13Data R13Rels R13Lookups R13Windows)

/-- **A block define schedule whose polynomials and start claims also see the run header data `HdrX`.** -/
structure DefSchedB (K : Type) [Field K] (Lq : ℕ) (P : ZK60.Exec.Block.BlockParams) where
  ks : List ℕ
  dg : ℕ → ℕ
  Φ : Cuts3 Lq → RootsO → HdrX Lq → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K
  Gd : Cuts3 Lq → RootsO → HdrX Lq → ℕ → Hist → Prop

/-- **The header data `hdrX` on a prefix `τ.take a` is the full transcript's once `hdrLen ≤ a`.** -/
theorem rd_hdrX_take {Lq : ℕ} (absOf : QB Lq → Option (List UInt8)) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (hdrLen a : ℕ) (h : hdrLen ≤ a) :
    hdrX absOf lg hdrLen (τ.take a) = hdrX absOf lg hdrLen τ := by
  funext i
  unfold hdrX
  by_cases hi : i < hdrLen
  · rw [if_pos hi, if_pos hi, rd_absAt_take τ a i (by omega)]
  · rw [if_neg hi, if_neg hi]

theorem rd_defSqB_doom {K : Type} [Field K] {Lq : ℕ} {P : ZK60.Exec.Block.BlockParams} {hdrLen : ℕ}
    {absOf : QB Lq → Option (List UInt8)}
    {Φ : Cuts3 Lq → RootsO → HdrX Lq → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K} {dg : ℕ → ℕ} {k : ℕ}
    (Gd : Cuts3 Lq → RootsO → HdrX Lq → ℕ → Hist → Prop)
    (hΦ : ∀ cu rt hx h, (∀ y, Φ cu rt hx k h y = 0) → Gd cu rt hx k h)
    (lg : List (QB Lq × Dig)) (hdr : List (TItem × Dig)) (h : Hist) (rest : List (TItem × Dig))
    (hh : tHistD P hdrLen k hdr = some (h, rest))
    (hg : ¬ Gd (cuts3 absOf lg (rootsAt hdrLen hdr)) (rootsAt hdrLen hdr) (hdrX absOf lg hdrLen hdr) k h) :
    ¬ (defSqB P hdrLen absOf Φ dg k).St lg hdr [] := by
  intro hst
  unfold defSqB at hst
  simp only [hh] at hst
  exact hg (hΦ _ _ _ _ ((szSt_nil _).mp hst))

theorem rd_lkSqB_doom {K : Type} [Field K] [DecidableEq K] {Lq : ℕ} {ι π κ : Type}
    [Fintype ι] [Fintype π] [Fintype κ] (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8))
    (Alk : List (QB Lq × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (mlk : List (QB Lq × Dig) × Option (List UInt8) → κ → K) (lg : List (QB Lq × Dig)) (hdr : List (TItem × Dig))
    (h : ∃ l, ∀ j, T j ≠ Alk (cutO absOf (absAt hdr hdrLen) lg, absAt hdr hdrLen) l) :
    ¬ (lkSqB hdrLen absOf Alk T mlk).St lg hdr [] := by
  obtain ⟨l, hl⟩ := h
  intro hst
  obtain ⟨j, hj⟩ := hst l
  exact hl j hj

section RunDoomB

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

theorem rd_defB_some (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) {P : ZK60.Exec.Block.BlockParams} {hdrLen : ℕ} {absOf : QB Lq → Option (List UInt8)}
    (Φ : Cuts3 Lq → RootsO → HdrX Lq → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (s : ℕ)
    (Gd : Cuts3 Lq → RootsO → HdrX Lq → ℕ → Hist → Prop)
    (hΦ : ∀ cu rt hx h, (∀ y, Φ cu rt hx s h y = 0) → Gd cu rt hx s h)
    (hmem : defSqB P hdrLen absOf Φ dg s ∈ D.r0 i ∨ defSqB P hdrLen absOf Φ dg s ∈ D.r1 i
      ∨ defSqB P hdrLen absOf Φ dg s ∈ D.h0 i ∨ defSqB P hdrLen absOf Φ dg s ∈ D.h1 i)
    (hlen : defPos P hdrLen s ≤ τ.length) (h : Hist) (rest : List (TItem × Dig))
    (hh : tHistD P hdrLen s (τ.take (defPos P hdrLen s)) = some (h, rest))
    (hg : ¬ Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf lg hdrLen τ) s h) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  have hr : rootsAt hdrLen (τ.take (defPos P hdrLen s)) = rootsAt hdrLen τ :=
    rd_rootsAt_take τ hdrLen _ (by unfold defPos; omega)
  have hhx : hdrX absOf lg hdrLen (τ.take (defPos P hdrLen s)) = hdrX absOf lg hdrLen τ :=
    rd_hdrX_take absOf lg τ hdrLen _ (by unfold defPos; omega)
  have hg' : ¬ Gd (cuts3 absOf lg (rootsAt hdrLen (τ.take (defPos P hdrLen s))))
      (rootsAt hdrLen (τ.take (defPos P hdrLen s))) (hdrX absOf lg hdrLen (τ.take (defPos P hdrLen s))) s h := by
    rw [hr, hhx]
    exact hg
  have hn : ¬ (defSqB P hdrLen absOf Φ dg s).St lg (τ.take (defPos P hdrLen s)) [] :=
    rd_defSqB_doom (dg := dg) Gd hΦ lg _ h rest hh hg'
  refine rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ _ ?_ hlen hn
  rcases hmem with h' | h' | h' | h'
  · exact Or.inl h'
  · exact Or.inr (Or.inl h')
  · exact Or.inr (Or.inr (Or.inl h'))
  · exact Or.inr (Or.inr (Or.inr (Or.inl h')))

theorem rd_luB_some {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (n i : ℕ) (hi : i < pf.parts.length)
    (hin : i < n) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdrLen : ℕ)
    (absOf : QB Lq → Option (List UInt8))
    (Alk : List (QB Lq × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (mlk : List (QB Lq × Dig) × Option (List UInt8) → κ → K)
    (hmem : lkSqB hdrLen absOf Alk T mlk ∈ D.lu i)
    (hlen : hdrLen + 4 ≤ τ.length)
    (hout : ∃ l, ∀ j, T j ≠ Alk (cutO absOf (absAt τ hdrLen) lg, absAt τ hdrLen) l) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  have hn : ¬ (lkSqB hdrLen absOf Alk T mlk).St lg (τ.take (lkSqB hdrLen absOf Alk T mlk).a) [] := by
    refine rd_lkSqB_doom hdrLen absOf Alk T mlk lg _ ?_
    show ∃ l, ∀ j, T j ≠ Alk (cutO absOf (absAt (τ.take (hdrLen + 4)) hdrLen) lg, absAt (τ.take (hdrLen + 4)) hdrLen) l
    rw [rd_absAt_take τ (hdrLen + 4) hdrLen (by omega)]
    exact hout
  exact rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ _
    (Or.inr (Or.inr (Or.inr (Or.inr hmem)))) hlen hn

theorem rd_blk_doomB (n k : ℕ) (hi : k + 1 < pf.parts.length) (hn : k + 1 < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (absOf : QB Lq → Option (List UInt8))
    {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
    [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
    [DecidableEq Cf] {ls : ℕ}
    (Pb : BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay) (hWr : R13Windows S ls)
    (h24 : S.h24 = true) (P : ZK60.Exec.Block.BlockParams) (hdrLen : ℕ) (sh : AlgShape P) (dt : AlgData K Lq sh)
    (hcard : 78 < Fintype.card K) (xtE : Cuts3 Lq → RootsO → R13Data Ct Cw Cg Cj Cd Cf ls)
    (enc : (k : ℕ) → (Fin (ZK60.Exec.Slot.W16R2.segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf) (hspec : R13Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hdefR : ∀ i, i < 4 → ∀ s ∈ w16r2RelKs i,
      RdDefAt D (k + 1) τ bga rs
        (defSqB P hdrLen absOf (fun cu rt _ s' h => (w16r2DR P (algSp U sh dt hcard) i).Φ cu rt s' h) (fun _ => 80) s)
        P hdrLen s)
    (DIO : DefSchedB K Lq P)
    (hIOΦ : ∀ cu rt hx s h, s ∈ DIO.ks → (∀ y, DIO.Φ cu rt hx s h y = 0) → DIO.Gd cu rt hx s h)
    (hdefIO : ∀ s ∈ DIO.ks, RdDefAt D (k + 1) τ bga rs (defSqB P hdrLen absOf DIO.Φ DIO.dg s) P hdrLen s)
    (Xin Xout : S.Pos → GF)
    (hIO : (∀ s ∈ DIO.ks, DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf lg hdrLen τ) s
        (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))) →
      Xin = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X (Lay.dPos p))
        ∧ Xout = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X2 (Lay.dPos p)))
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB Lq × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (mlk : List (QB Lq × Dig) × Option (List UInt8) → κ → K)
    (hlu : lkSqB hdrLen absOf Alk T mlk ∈ D.lu (k + 1)) (hlen : hdrLen + 4 ≤ τ.length)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ q, R13Query Pb Lay B (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)) q →
      ∃ l, Alk (cutO absOf (absAt τ hdrLen) lg, absAt τ hdrLen) l = tupK q) :
    ¬ BlockOn Pb Xin Xout → RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  intro hno
  by_cases hio : ∀ s ∈ DIO.ks, DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf lg hdrLen τ) s
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))
  · obtain ⟨hin, hout⟩ := hIO hio
    refine block_doom_r13 Pb Lay B (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)) hWr h24 Xin Xout
      hin hout (Op := True) (Cl := True) (fun h => absurd trivial h) (fun _ h => absurd trivial h) ?_ ?_ hno
    · intro _ _ hrel
      obtain ⟨j, hj, s, hs', hg⟩ := rd_r13_notGd U sh dt hcard Pb Lay B xtE enc encHt hspec hTok hHd
        (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) bga rs hrel
      obtain ⟨hmem, hl, rest, hh⟩ := hdefR j hj s hs'
      exact rd_defB_some key domain hs Lq hL pf rd hL64 hv U hbij D hD n (k + 1) hi hn lg τ
        (fun cu rt _ s' h => (w16r2DR P (algSp U sh dt hcard) j).Φ cu rt s' h) (fun _ => 80) s
        (fun cu rt _ s' h => (w16r2DR P (algSp U sh dt hcard) j).Gd cu rt s' h)
        (fun cu' rt' _ h' hy => (algSp U sh dt hcard j cu' rt' s h').hΦ hy) hmem hl _ rest hh hg
    · intro _ _ _ hlk
      exact rd_luB_some key domain hs Lq hL pf rd hL64 hv U hbij D hD n (k + 1) hi hn lg τ hdrLen absOf Alk T mlk
        hlu hlen (hbr_r13_of_cover (Alk (cutO absOf (absAt τ hdrLen) lg, absAt τ hdrLen)) T hTtab hcov hlk)
  · obtain ⟨s, hs', hg⟩ : ∃ s ∈ DIO.ks, ¬ DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)
        (hdrX absOf lg hdrLen τ) s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) := by
      by_contra hc
      exact hio (fun s hs' => by
        by_contra hg
        exact hc ⟨s, hs', hg⟩)
    obtain ⟨hmem, hl, rest, hh⟩ := hdefIO s hs'
    exact rd_defB_some key domain hs Lq hL pf rd hL64 hv U hbij D hD n (k + 1) hi hn lg τ DIO.Φ DIO.dg s DIO.Gd
      (fun cu' rt' hx' h' hy => hIOΦ cu' rt' hx' s h' hs' hy) hmem hl _ rest hh hg

end RunDoomB

section HdblkB

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **Block `k`'s R13 objects and links at one outcome, over `defSqB`, `DefSchedB`, and `lkSqB`.** -/
structure RdBlkR13B {Lq : ℕ} (U : K) (D : RtKData K Lq) (k : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K) {S : BlockShape} (Pb : BlockPublic S)
    (Xin Xout : S.Pos → GF) : Type 1 where
  Ct : Type
  Cw : Type
  Cg : Type
  Cj : Type
  Cd : Type
  Cf : Type
  [fCt : Fintype Ct]
  [fCw : Fintype Cw]
  [fCg : Fintype Cg]
  [fCj : Fintype Cj]
  [fCd : Fintype Cd]
  [fCf : Fintype Cf]
  [dCt : DecidableEq Ct]
  [dCw : DecidableEq Cw]
  [dCg : DecidableEq Cg]
  [dCj : DecidableEq Cj]
  [dCd : DecidableEq Cd]
  [dCf : DecidableEq Cf]
  ls : ℕ
  Lay : W16Layout S Ct Cw Cg Cj Cd Cf
  B : W16Pub S Pb Lay
  hWr : R13Windows S ls
  h24 : S.h24 = true
  P : ZK60.Exec.Block.BlockParams
  hdrLen : ℕ
  sh : AlgShape P
  dt : AlgData K Lq sh
  xtE : Cuts3 Lq → RootsO → R13Data Ct Cw Cg Cj Cd Cf ls
  enc : (j : ℕ) → (Fin (ZK60.Exec.Slot.W16R2.segLn (sh.dl j) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf
  encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf
  hspec : R13Spec sh dt Pb Lay B xtE enc encHt
  hTok : Function.Surjective Lay.tok.emb
  hHd : Function.Surjective Lay.hd.emb
  bga : Fp2 × Fp2 × Fp2
  rs : List SlotRec
  hdefR : ∀ i, i < 4 → ∀ s ∈ w16r2RelKs i,
    RdDefAt D (k + 1) τ bga rs
      (defSqB P hdrLen absOf (fun cu rt _ s' h => (w16r2DR P (algSp U sh dt hcard) i).Φ cu rt s' h) (fun _ => 80) s)
      P hdrLen s
  DIO : DefSchedB K Lq P
  hIOΦ : ∀ cu rt hx s h, s ∈ DIO.ks → (∀ y, DIO.Φ cu rt hx s h y = 0) → DIO.Gd cu rt hx s h
  hdefIO : ∀ s ∈ DIO.ks, RdDefAt D (k + 1) τ bga rs (defSqB P hdrLen absOf DIO.Φ DIO.dg s) P hdrLen s
  hIO : (∀ s ∈ DIO.ks, DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf lg hdrLen τ) s
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))) →
    Xin = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X (Lay.dPos p))
      ∧ Xout = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X2 (Lay.dPos p))
  ι : Type
  π : Type
  κ : Type
  [fι : Fintype ι]
  [fπ : Fintype π]
  [fκ : Fintype κ]
  Alk : List (QB Lq × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K
  T : κ → Tup K
  mlk : List (QB Lq × Dig) × Option (List UInt8) → κ → K
  hlu : lkSqB hdrLen absOf Alk T mlk ∈ D.lu (k + 1)
  hlen : hdrLen + 4 ≤ τ.length
  hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0
  hcov : ∀ q, R13Query Pb Lay B (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)) q →
    ∃ l, Alk (cutO absOf (absAt τ hdrLen) lg, absAt τ hdrLen) l = tupK q

attribute [local instance] RdBlkR13B.fCt RdBlkR13B.fCw RdBlkR13B.fCg RdBlkR13B.fCj RdBlkR13B.fCd RdBlkR13B.fCf
  RdBlkR13B.dCt RdBlkR13B.dCw RdBlkR13B.dCg RdBlkR13B.dCj RdBlkR13B.dCd RdBlkR13B.dCf RdBlkR13B.fι RdBlkR13B.fπ
  RdBlkR13B.fκ

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

theorem rd_blk_doomB_of (n k : ℕ) (hi : k + 1 < pf.parts.length) (hn : k + 1 < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K) {S : BlockShape}
    (Pb : BlockPublic S) (Xin Xout : S.Pos → GF) (bd : RdBlkR13B U D k lg τ absOf hcard Pb Xin Xout) :
    ¬ BlockOn Pb Xin Xout → RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  exact rd_blk_doomB key domain hs Lq hL pf rd hL64 hv U hbij D hD n k hi hn lg τ absOf Pb bd.Lay bd.B bd.hWr bd.h24
    bd.P bd.hdrLen bd.sh bd.dt hcard bd.xtE bd.enc bd.encHt bd.hspec bd.hTok bd.hHd bd.bga bd.rs bd.hdefR bd.DIO
    bd.hIOΦ bd.hdefIO Xin Xout bd.hIO bd.Alk bd.T bd.mlk bd.hlu bd.hlen bd.hTtab bd.hcov

open ZK60.RunShape (ClassifyRunPublicP) in
theorem rd_hdblkB {S : BlockShape} (Rp : ClassifyRunPublicP S) (hnp : pf.parts.length = Rp.blks.length + 2)
    (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K)
    (Acc : OC (QB Lq) Dig α → (QB Lq → Dig) → Prop) (pl : OC (QB Lq) Dig α → (QB Lq → Dig) → ℕ → S.Pos → GF)
    (hlink : ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length), Acc A G →
      Nonempty (RdBlkR13B U D k (A.runLog G).2 (rtTr key domain Lq pf rd G (A.run G)) absOf hcard Rp.blks[k].pub
        (pl A G k) (pl A G (k + 1)))) :
    ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length), Acc A G →
      ¬ BlockOn Rp.blks[k].pub (pl A G k) (pl A G (k + 1)) →
      ∃ K' ∈ rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD, ∃ i, i < Rp.blks.length + 2
        ∧ ∃ c ∈ K'.cs i (A.runLog G).2, EntD K'.RC.W c (rtTr key domain Lq pf rd G (A.run G)) := by
  intro A G k hk hacc hno
  obtain ⟨bd⟩ := hlink A G k hk hacc
  exact rd_blk_doomB_of key domain hs Lq hL pf rd hL64 hv U hbij D hD (Rp.blks.length + 2) k (by omega) (by omega)
    _ _ absOf hcard _ _ _ bd hno

end HdblkB

end DoomB
"""

join_lk_out = f"""/-
D63 lane L60 (2026-11-13), part 1: **adversary-free block LogUp (`lkSqB`, reading both the cut and the absorbed `A`
root) and the widened block doom bundle `RdBlkR13B` over `defSqB`, `DefSchedB`, and `lkSqB`**.

Generated by `results/zk60_lean_l60_20261113/l60_mk_join.py`. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBndDef
import ZK60Formal.RunDoomBlk

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section LkB

variable {{K : Type}} [Field K] [Algebra GF K] {{L : ℕ}}

{lk_blk}
end LkB

end ZK60.Exec.Block

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

section CutLkB

variable {{K : Type}} [Field K] [DecidableEq K] {{L : ℕ}}

/-- **LogUp's widened squeeze-run state (`lkSqB`) is a cut reader (`SqCut`).** -/
theorem lkSqB_cut {{ι π κ : Type}} [Fintype ι] [Fintype π] [Fintype κ]
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Alk : List (QB L × Dig) × Option (List UInt8) → ι ⊕ (π ⊕ π) → Tup K)
    (T : κ → Tup K) (mlk : List (QB L × Dig) × Option (List UInt8) → κ → K) :
    SqCut absOf (Exec.Block.lkSqB hdrLen absOf Alk T mlk) := by
  intro P P' hdr h τr
  simp only [Exec.Block.lkSqB, h hdrLen]

end CutLkB

section AtLkB

variable {{K : Type}} [Field K] [Algebra GF K] {{L : ℕ}}

{ralk_sec}

end AtLkB

{hal_lu}
{DOOM_B}
end ZK60.ProtocolClassify
"""
(L / "RunStgJoinLk.lean").write_text(join_lk_out) if not (L / "RunStgJoinLk.lean").exists() or (L / "RunStgJoinLk.lean").read_text() != join_lk_out else None
print("RunStgJoinLk.lean:", join_lk_out.count("\n"), "lines")


# ----------------------------------------------------------------------------
# 2. RunStgJoinBnd.lean: wr_termBN, sj_hgXB, bnd_slotEvalN_args, bnd_hsl_evBN_of_args
# ----------------------------------------------------------------------------
bargs = (L / "RunBndArgs.lean").read_text()
ba_i = bargs.index("theorem bnd_slotEval_args ")
ba_d = bargs.rindex("/-- ", 0, ba_i)
ba_j = bargs.index("end ZK60.ProtocolClassify", ba_i)
ba_sec = bargs[ba_d:ba_j]
ba_sec = once(ba_sec, "theorem bnd_slotEval_args ", "theorem bnd_slotEvalN_args ")
ba_sec = once(ba_sec, "theorem bnd_hsl_evB_of_args", "theorem bnd_hsl_evBN_of_args")
ba_sec = once(ba_sec, "have h := bnd_slotEval_args ", "have h := bnd_slotEvalN_args ")
assert ba_sec.count("Block.SlotEval ") >= 2, ba_sec.count("Block.SlotEval ")
ba_sec = ba_sec.replace("Block.SlotEval ", "Block.SlotEvalN ")

join_bnd_out = f"""/-
D63 lane L60 (2026-11-13), part 2: **the corrected slot evaluation interface `SlotEvalN` on the classify run's widened
block schedule (`wr_termBN`, `bnd_slotEvalN_args`, `bnd_hsl_evBN_of_args`) and `sj_hgXB`**.

Generated by `results/zk60_lean_l60_20261113/l60_mk_join.py`. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBndArgs
import ZK60Formal.SlotPolyInstEval
import ZK60Formal.RunCloseBEnds

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

/-- **`RaTermAtB` from the claims' truth and `SlotEvalN`** (repair of finding L31-1 on the run's widened schedule). -/
theorem wr_termBN {{K : Type}} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig)
    (domain : List UInt8) {{L : ℕ}} (P : Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Block.Cuts3 L → Block.RootsO → Block.HdrX L → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P j).1 + (Block.slotShape P j).2.1) → K) → K)
    (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (cs : Block.Cm → Block.ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hd : ∀ j, j < P.geom.slots.length → 1 ≤ (Block.slotShape P j).2.2)
    (hpolyC : ∀ (j : ℕ) (hist : Block.Hist) (dr : List Fp2) (df : Block.SlotDef), P.define j hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hsem : ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      Block.ClaimsTrue U cs acc.claims ∧ Block.MTrue U ms (acc.fs ++ acc.hostFs))
    (hEv : ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      Block.SlotEvalN U P cs ms (fun j sn pt => F (Block.cuts3 absOf lg (Block.rootsOf core)) (Block.rootsOf core)
        (Block.hdrX absOf lg hdrLen τ) j sn pt)) :
    RaTermAtB U key domain P hdrLen absOf F G lg τ := by
  intro hdr core bga rs acc T hsa _ htr j r hr
  obtain ⟨hcl, hm⟩ := hsem hdr core bga rs acc T hsa htr
  have hev := hEv hdr core bga rs acc T hsa htr
  obtain ⟨-, -, hcan, hsh, t', hbs⟩ := hsa
  exact Block.blockSlots_terminalN U hU (liftH G) P core _ bga rs acc t' hbs hcan hsh.1 hd cs ms hcl
    (fun mf h => hm mf (List.mem_append_left _ h)) hpolyC
    (Block.blockSlots_fin_canon (liftH G) P core _ bga rs acc t' hbs hcan hsh hd) _ hev j r hr

/-- **All closing openings of parts `1 … Lb + 1` read their roots at `off j + 2`** (`hgXB` of L56, derived directly
from L55's `hgX1`, `hgXk`, `hgXo`). -/
theorem sj_hgXB {{K : Type}} [Field K] {{Lq : ℕ}} (pf : RtProf) (Lb : ℕ) (base : ℕ → RkPart K Lq)
    (r0 : ℕ) (rk : ℕ → ℕ) (ro : ℕ)
    (hgX1 : (base 1).gX = rkR13 r0 (pf.off 0 + 2))
    (hgXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX = rkR13 (rk (k + 1)) (pf.off (k + 1) + 2))
    (hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX = rkR13 ro (pf.off (k + 1) + 2)) :
    ∀ j, j ≤ Lb → (base (j + 1)).gX.ipos = pf.off j + 2 := by
  intro j hj
  rcases j with _ | k
  · rw [hgX1]; rfl
  · by_cases hk : k + 1 < Lb
    · rw [hgXk k hk]; rfl
    · have heq : k + 1 = Lb := by omega
      rw [hgXo k heq]; rfl

section Args

variable {{K : Type}} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
  (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
  (hL : (startMsg domain).length ≤ Lq)

{ba_sec}
end ZK60.ProtocolClassify
"""
(L / "RunStgJoinBnd.lean").write_text(join_bnd_out) if not (L / "RunStgJoinBnd.lean").exists() or (L / "RunStgJoinBnd.lean").read_text() != join_bnd_out else None
print("RunStgJoinBnd.lean:", join_bnd_out.count("\n"), "lines")


# ----------------------------------------------------------------------------
# 3. RunStgJoinSem.lean: eb_stg_D_lists (ebData counterpart of stg_D_lists)
# ----------------------------------------------------------------------------
join_sem_out = """/-
D63 lane L60 (2026-11-13), part 3: **the repair-B kinds data `ebData` carries the stage parts' lists (`eb_stg_D_lists`)**.

Generated by `results/zk60_lean_l60_20261113/l60_mk_join.py`. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgAlgPoly
import ZK60Formal.RunEpBOpen

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

theorem eb_stg_D_lists {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (rdx : List UInt8 → Option Dig) (pf : RtProf)
    (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ) (D : RtKData K Lq)
    (hDe : D = ebData U tag Lq h64 key domain hs hL rdx pf (rxPs base Lb din dblk dout) acc lsc eL)
    (slsI slsO : List (SlotX K Lq)) (defsI defsO : List (SqX K Lq)) (lkI lkO : SqX K Lq)
    (hb0 : StgLists (base 0) slsI defsI lkI) (hbL : StgLists (base (Lb + 1)) slsO defsO lkO) :
    (D.sls 0 = slsI ∧ D.r0 0 = defsI ∧ D.r1 0 = [] ∧ D.h0 0 = [] ∧ D.h1 0 = [] ∧ D.lu 0 = [lkI])
      ∧ (D.sls (Lb + 1) = slsO ∧ D.r0 (Lb + 1) = defsO ∧ D.r1 (Lb + 1) = [] ∧ D.h0 (Lb + 1) = []
        ∧ D.h1 (Lb + 1) = [] ∧ D.lu (Lb + 1) = [lkO]) := by
  subst hDe
  obtain ⟨a1, a2, a3, a4, a5, a6⟩ := stg_rxPs_0 base Lb din dblk dout
  obtain ⟨b1, b2, b3, b4, b5, b6⟩ := stg_rxPs_out base Lb din dblk dout
  exact ⟨⟨a1.trans hb0.hsls, a2.trans hb0.hr0, a3.trans hb0.hr1, a4.trans hb0.hh0, a5.trans hb0.hh1,
    a6.trans hb0.hlu⟩, ⟨b1.trans hbL.hsls, b2.trans hbL.hr0, b3.trans hbL.hr1, b4.trans hbL.hh0,
    b5.trans hbL.hh1, b6.trans hbL.hlu⟩⟩

end ZK60.ProtocolClassify
"""
(L / "RunStgJoinSem.lean").write_text(join_sem_out) if not (L / "RunStgJoinSem.lean").exists() or (L / "RunStgJoinSem.lean").read_text() != join_sem_out else None
print("RunStgJoinSem.lean:", join_sem_out.count("\n"), "lines")


# ----------------------------------------------------------------------------
# 4. RunStgJoinChain.lean: exec_blk -> exec_alive -> code -> codeT -> wireT
# ----------------------------------------------------------------------------
END_TOK = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="

epb_chain = (L / "RunEpBChain.lean").read_text()

# 4A: EbBlkTop -> SjBlkTop (RdBlkR13B + rd_hdblkB)
s_blk = section(epb_chain, "EbBlkTop")
s_blk = once(s_blk, "section EbBlkTop\n", "section SjBlkTop\n")
s_blk = once(s_blk, "end EbBlkTop\n", "end SjBlkTop\n")
s_blk = once(s_blk, "theorem eb_productionReadyL_epP_exec_blk ", "theorem sj_productionReadyL_epP_exec_blk ")
s_blk = once(s_blk, "ZK60.ProtocolClassify.RdBlkR13 U", "ZK60.ProtocolClassify.RdBlkR13B U")
s_blk = once(s_blk, "ZK60.ProtocolClassify.rd_hdblk ", "ZK60.ProtocolClassify.rd_hdblkB ")

# 4B: EbRaTop -> SjRaTop (L56 B-slots/defs + L60 B-LogUp/RdBlkR13B + L57 real stage view lists)
s_ra = section(epb_chain, "EbRaTop")
s_ra = once(s_ra, "section EbRaTop\n", "section SjRaTop\n")
s_ra = once(s_ra, "end EbRaTop\n", "end SjRaTop\n")
s_ra = once(s_ra, "theorem eb_productionReadyL_epP_exec_alive ", "theorem sj_productionReadyL_epP_exec_alive ")
s_ra = once(s_ra, "exact eb_productionReadyL_epP_exec_blk ", "exact sj_productionReadyL_epP_exec_blk ")
s_ra = once(s_ra, "ZK60.ProtocolClassify.RdBlkR13 U", "ZK60.ProtocolClassify.RdBlkR13B U")

# L56 upgrades on SjRaTop:
s_ra = once(s_ra, "(Fsl : (k : ℕ) → Exec.Block.Cuts3 Lq → Exec.Block.RootsO → (j : ℕ) → Exec.Block.Seen →",
            "(Fsl : (k : ℕ) → Exec.Block.Cuts3 Lq → Exec.Block.RootsO → Exec.Block.HdrX Lq → (j : ℕ) →\n      Exec.Block.Seen →")
s_ra = once(s_ra, "D.sls (k + 1) = Exec.Block.blockSchedX (Pk k)", "D.sls (k + 1) = Exec.Block.blockSchedXB (Pk k)")
s_ra = once(s_ra, "∀ k, k < Lb → RaTermAt U key domain (Pk k)", "∀ k, k < Lb → RaTermAtB U key domain (Pk k)")
s_ra = once(s_ra, "ZK60.ProtocolClassify.ra_hal_sl (U := U)", "ZK60.ProtocolClassify.ra_hal_slB (U := U)")
s_ra = rep(s_ra, "RaDefAt U key domain (Pk k)", "RaDefAtB U key domain (Pk k)", 4)
s_ra = rep(s_ra, "ZK60.ProtocolClassify.ra_hal_def (U := U)", "ZK60.ProtocolClassify.ra_hal_defB (U := U)", 4)

# L60 B-LogUp upgrades on SjRaTop:
s_ra = once(s_ra, "(AlkL : (k : ℕ) → List (QB Lq × Dig) → ιL k ⊕ (πL k ⊕ πL k) → Tup K)",
            "(AlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → ιL k ⊕ (πL k ⊕ πL k) → Tup K)")
s_ra = once(s_ra, "(mlkL : (k : ℕ) → List (QB Lq × Dig) → κL k → K)",
            "(mlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → κL k → K)")
s_ra = once(s_ra, "RaLkAt U key domain (Pk k)", "RaLkAtB U key domain (Pk k)")
s_ra = once(s_ra, "ZK60.ProtocolClassify.ra_hal_lu (U := U)", "ZK60.ProtocolClassify.ra_hal_luB (U := U)")

# Extract RDX_TOK from hDe in s_ra (`ebData U tag Lq h64 key domain hs hL <RDX_TOK> (RtRun.pf Rn)`):
rdx_m = re.search(r"ebData U tag Lq h64 key domain hs hL (\S+) \(RtRun\.pf Rn\)", s_ra)
assert rdx_m, "ebData pattern not found in s_ra"
RDX_TOK = rdx_m.group(1)

# Read RunStgAlgTopR.lean to extract the exact stage binders & proof terms:
topr_src = (L / "RunStgAlgTopR.lean").read_text()
topr_th_i = topr_src.index("theorem stgAlg_productionReadyL_epP_exec_real ")
topr_th_j = topr_src.index(END_TOK, topr_th_i) + len(END_TOK)
topr_stmt = topr_src[topr_th_i:topr_th_j]
topr_bs = {b[1][0]: topr_stmt[b[2]:b[3]] for b in top_binders(topr_stmt) if len(b[1]) == 1}
topr_all_bs = [(b[1], topr_stmt[b[2]:b[3]]) for b in top_binders(topr_stmt)]

# Extract exact RK_EV_HYP from RunStgAlgTopR's hTrI:
rk_ev_i0 = topr_bs["hTrI"].index("¬ EvXR ")
rk_ev_i1 = topr_bs["hTrI"].index("A G →", rk_ev_i0) + len("A G →")
RK_EV_HYP = topr_bs["hTrI"][rk_ev_i0:rk_ev_i1]

# Extract exact RA_EV_HYP (`¬ (EvXR ... ∨ Ey A G) →`) and original stage binder types from s_ra:
ra_th_i = s_ra.index("theorem sj_productionReadyL_epP_exec_alive ")
ra_th_j = s_ra.index(END_TOK, ra_th_i) + len(END_TOK)
ra_stmt = s_ra[ra_th_i:ra_th_j]
ra_bs = top_binders(ra_stmt)
ra_orig_ty = {}
for (_, ns, bs_i, bs_e) in ra_bs:
    if len(ns) == 1:
        nm = ns[0]
        grp_s = ra_stmt[bs_i:bs_e]
        if grp_s.startswith(f"({nm} : ") and grp_s.endswith(")"):
            ra_orig_ty[nm] = grp_s[len(f"({nm} : "):-1]

hsl_grp = ra_orig_ty["hsl_stg"]
ra_ev_i0 = hsl_grp.index("¬ (EvXR ")
ra_ev_i1 = hsl_grp.index("∨ Ey A G) →", ra_ev_i0) + len("∨ Ey A G) →")
RA_EV_HYP = hsl_grp[ra_ev_i0:ra_ev_i1]


def adapt_stg_binder_for(grp_txt: str, ev_hyp: str) -> str:
    return once(grp_txt, RK_EV_HYP, ev_hyp)


stg_decl_grps = []
stg_decl_names = []
capture = False
for names, grp_txt in topr_all_bs:
    if names == ["P0in", "P0out"]:
        capture = True
    if capture:
        stg_decl_grps.append(grp_txt)
        stg_decl_names.extend(names)
    if names == ["hPout"]:
        break
assert len(stg_decl_grps) >= 8, stg_decl_grps


def make_stg_repl(ev_hyp: str) -> dict[str, str | None]:
    return {
        "hsl_stg": "\n    ".join(stg_decl_grps + [
            adapt_stg_binder_for(topr_bs["hTrI"], ev_hyp),
            adapt_stg_binder_for(topr_bs["hTrO"], ev_hyp),
        ]),
        "hR0_stg": "\n    ".join([
            adapt_stg_binder_for(topr_bs["hDI_stg"], ev_hyp),
            adapt_stg_binder_for(topr_bs["hDO_stg"], ev_hyp),
        ]),
        "hR1_stg": None,
        "hH0_stg": None,
        "hH1_stg": None,
        "hLU_stg": "\n    ".join([
            adapt_stg_binder_for(topr_bs["hLI_stg"], ev_hyp),
            adapt_stg_binder_for(topr_bs["hLO_stg"], ev_hyp),
        ]),
        "hdin": adapt_stg_binder_for(topr_bs["hdinS"], ev_hyp),
        "hdout": adapt_stg_binder_for(topr_bs["hdoutS"], ev_hyp),
    }


def apply_stg_repl(stmt_txt: str, repl_map: dict[str, str | None]) -> str:
    bs = top_binders(stmt_txt)
    out = ""
    pos = 0
    for (_, names, b_s, b_e) in bs:
        if len(names) == 1 and names[0] in repl_map:
            nm = names[0]
            out += stmt_txt[pos:b_s]
            rep_txt = repl_map[nm]
            if rep_txt is None:
                out = out.rstrip(" \n") + "\n    "
                pos = b_e
                while pos < len(stmt_txt) and stmt_txt[pos] in " \n":
                    pos += 1
            else:
                out += rep_txt
                pos = b_e
    out += stmt_txt[pos:]
    return out


new_ra_stmt = apply_stg_repl(ra_stmt, make_stg_repl(RA_EV_HYP))

# Build SjRaTop proof from RunStgAlgTop.lean and RunStgAlgTopR.lean:
topv_src = (L / "RunStgAlgTop.lean").read_text()
topv_pf = topv_src[topv_src.index(END_TOK) + len(END_TOK):topv_src.index("\nend StgAlgTop\n")]
topr_pf = topr_src[topr_src.index(END_TOK) + len(END_TOK):topr_src.index("\nend StgAlgTopR\n")]


def extract_named_arg(pf_txt: str, arg_name: str) -> str:
    needle = f"({arg_name} := "
    idx = pf_txt.index(needle)
    d = 0
    for k in range(idx, len(pf_txt)):
        if pf_txt[k] == "(":
            d += 1
        elif pf_txt[k] == ")":
            d -= 1
            if d == 0:
                return pf_txt[idx:k + 1]
    raise RuntimeError(f"unclosed {arg_name}")


N0I = "((RtRun.pf Rn).off 0 + pin.pre)"
N0O = "((RtRun.pf Rn).off (Lb + 1) + pout.pre)"
GEO = "ogStage.lc ogStage.h ogStage.Q ogStage.e"
P_PFX = "ZK60.ProtocolClassify."
FRI = f"({P_PFX}stgFstI U hbij tag h64 P0in Win {N0I} ((RtRun.pf Rn).off 0 + 5) mIn {GEO} Iin.pA.rows Iin.pH.rows pin.S csIOI)"
FRO = f"({P_PFX}stgFstO U hbij tag h64 P0out Wout {N0O} ((RtRun.pf Rn).off (Lb + 1) + 2) {GEO} Oout.pA.rows Oout.pH.rows pout.S csIOO)"

pf_hTI = extract_named_arg(topr_pf, "hTI_stg")
pf_hTO = extract_named_arg(topr_pf, "hTO_stg")
val_hTI = pf_hTI[len("(hTI_stg := "):-1]
val_hTO = pf_hTO[len("(hTO_stg := "):-1]
LAM_PFX = "fun A G hv' hx' h1 h2 h3 => "
assert val_hTI.startswith(LAM_PFX) and val_hTO.startswith(LAM_PFX)
body_hTI = val_hTI[len(LAM_PFX):]
body_hTO = val_hTO[len(LAM_PFX):]

OLD_DL = "(ZK60.ProtocolClassify.stg_D_lists U tag Lq h64 key domain hs hL (RtRun.pf Rn) base Lb _ _ _ _ _ eL D hDe _ _ _ _ _ _ hb0 hbL)"
NEW_DL_RHS = f"ZK60.ProtocolClassify.eb_stg_D_lists U tag Lq h64 key domain hs hL {RDX_TOK} (RtRun.pf Rn) base Lb _ _ _ _ _ eL D hDe _ _ _ _ _ _ hb0 hbL"


def adapt_stg_pf_arg(arg_txt: str) -> str:
    assert OLD_DL in arg_txt, arg_txt[:120]
    t = arg_txt.replace(OLD_DL, "hDL")
    t = t.replace("(FI := FstI)", f"(FI := {FRI})").replace("(FO := FstO)", f"(FO := {FRO})")
    t = t.replace("hTI_stg A G hv' hx' h1 h2 h3", f"({body_hTI})")
    t = t.replace("hTO_stg A G hv' hx' h1 h2 h3", f"({body_hTO})")
    return t


ra_pf = s_ra[ra_th_j:]
ra_pf = once(ra_pf, "(hdin := hdin)", adapt_stg_pf_arg(extract_named_arg(topv_pf, "hdin")))
ra_pf = once(ra_pf, "(hdout := hdout)", adapt_stg_pf_arg(extract_named_arg(topv_pf, "hdout")))

have_lines = ["\n  by", f"  have hDL := {NEW_DL_RHS}"]
for nm in ["hsl_stg", "hR0_stg", "hR1_stg", "hH0_stg", "hH1_stg", "hLU_stg"]:
    val_nm = adapt_stg_pf_arg(extract_named_arg(topv_pf, nm))[len(f"({nm} := "):-1]
    have_lines.append(f"  have {nm} : {ra_orig_ty[nm]} := {val_nm}")

by_idx = ra_pf.index("by\n")
ra_pf = "\n".join(have_lines) + "\n" + ra_pf[by_idx + len("by\n"):]
s_ra = s_ra[:ra_th_i] + new_ra_stmt + ra_pf


# 4C: ExCodeTop (from RunEpXTop.lean) -> SjCodeTop
epx_top = (L / "RunEpXTop.lean").read_text()
s_code = section(epx_top, "ExCodeTop")
s_code = once(s_code, "section ExCodeTop\n", "section SjCodeTop\n")
s_code = once(s_code, "end ExCodeTop\n", "end SjCodeTop\n")
s_code = once(s_code, "theorem ex_productionReadyL_epP_code ", "theorem sj_productionReadyL_epP_code ")
s_code = once(s_code, "exact eb_productionReadyL_epP_exec_alive ", "exact sj_productionReadyL_epP_exec_alive ")

# L56 + L60 upgrades on SjCodeTop:
s_code = once(s_code, "ZK60.ProtocolClassify.RdBlkR13 U", "ZK60.ProtocolClassify.RdBlkR13B U")
s_code = once(s_code, "(Fsl : (k : ℕ) → Exec.Block.Cuts3 Lq → Exec.Block.RootsO → (j : ℕ) → Exec.Block.Seen →",
              "(Fsl : (k : ℕ) → Exec.Block.Cuts3 Lq → Exec.Block.RootsO → Exec.Block.HdrX Lq → (j : ℕ) →\n      Exec.Block.Seen →")
s_code = once(s_code, "D.sls (k + 1) = Exec.Block.blockSchedX (Pk k)", "D.sls (k + 1) = Exec.Block.blockSchedXB (Pk k)")
s_code = once(s_code, "∀ k, k < Lb → RaTermAt U key domain (Pk k)", "∀ k, k < Lb → RaTermAtB U key domain (Pk k)")
s_code = rep(s_code, "RaDefAt U key domain (Pk k)", "RaDefAtB U key domain (Pk k)", 4)
s_code = once(s_code, "(AlkL : (k : ℕ) → List (QB Lq × Dig) → ιL k ⊕ (πL k ⊕ πL k) → Tup K)",
              "(AlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → ιL k ⊕ (πL k ⊕ πL k) → Tup K)")
s_code = once(s_code, "(mlkL : (k : ℕ) → List (QB Lq × Dig) → κL k → K)",
              "(mlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → κL k → K)")
s_code = once(s_code, "RaLkAt U key domain (Pk k)", "RaLkAtB U key domain (Pk k)")

c_th_i = s_code.index("theorem sj_productionReadyL_epP_code ")
c_th_j = s_code.index(END_TOK, c_th_i) + len(END_TOK)
c_stmt = s_code[c_th_i:c_th_j]
c_bs = top_binders(c_stmt)
(_, _, chs_i, chs_e) = [b for b in c_bs if b[1] == ["hsl_stg"]][0]
c_hsl_grp = c_stmt[chs_i:chs_e]
ex_ev_i0 = c_hsl_grp.index("¬ (EvXR ")
ex_ev_i1 = c_hsl_grp.index("sgeom Lb A G) →", ex_ev_i0) + len("sgeom Lb A G) →")
EX_EV_HYP = c_hsl_grp[ex_ev_i0:ex_ev_i1]

new_c_stmt = apply_stg_repl(c_stmt, make_stg_repl(EX_EV_HYP))
c_pf = s_code[c_th_j:]
stg_decl_pass = " ".join(f"({n} := {n})" for n in stg_decl_names)
old_call_slice = cut(c_pf, "(hsl_stg := hsl_stg)", "(mk := mk)").rstrip()
new_call_slice = (
    f"{stg_decl_pass} (hTrI := hTrI) (hTrO := hTrO) "
    "(hR0_blk := hR0_blk) (hDI_stg := hDI_stg) (hDO_stg := hDO_stg) "
    "(hR1_blk := hR1_blk) (hH0_blk := hH0_blk) (hH1_blk := hH1_blk) "
    "(hLU_blk := hLU_blk) (hLI_stg := hLI_stg) (hLO_stg := hLO_stg) "
    "(hdinS := hdinS) (hblk := hblk) (hdoutS := hdoutS)"
)
c_pf = once(c_pf, old_call_slice, new_call_slice)
s_code = s_code[:c_th_i] + new_c_stmt + c_pf


# 4D: SjCodeTop -> SjCodeTTop (exact l58_mk_chain.py ExCodeTTop step)
s_codeT = s_code
th0 = s_codeT.index("theorem sj_productionReadyL_epP_code ")
th1 = s_codeT.index(END_TOK, th0) + len(END_TOK)
explicit_code = [n for (k, ns, _, _) in top_binders(s_codeT[th0:th1]) if k == "(" for n in ns]
assert "hBal" in explicit_code and "T" in explicit_code and "Ux" in explicit_code, explicit_code
s_codeT = once(s_codeT, "section SjCodeTop\n", "section SjCodeTTop\n")
s_codeT = once(s_codeT, "end SjCodeTop\n", "end SjCodeTTop\n")
s_codeT = once(s_codeT, "theorem sj_productionReadyL_epP_code ", "theorem sj_productionReadyL_epP_codeT ")
TBLOCK = cut(s_codeT, "    {F Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Algebra GF F] [Fintype Cl] [DecidableEq Cl]\n",
             "    (tag : MTag)\n")
s_codeT = once(s_codeT, TBLOCK, "")
s_codeT = once(s_codeT, "(hXep : RkPcsAt U tag ogEp Iin.pX) (hfitX : 8 * Iin.pX.rows ≤ Lq)\n",
               "(hXep : RkPcsAt U tag ogEp Iin.pX) (hfitX : 8 * Iin.pX.rows ≤ Lq)\n    (hRr : Iin.pX.rows = Rr)\n")
bal = cut(s_codeT, "    (hBal : ∀ (A : OC", "    (hdzero : ∀ (A : OC")
s_codeT = once(s_codeT, bal, "")
AA = "((RtRun.pf Rn).off 0 + ((RtRun.pf Rn).part 0).oX)"
BB = "((RtRun.pf Rn).off 0 + ((RtRun.pf Rn).part 0).oBX)"
HAB = "(ZK60.ProtocolClassify.eb_ab_le (RtRun.pf Rn) 0)"
TT = f"(ZK60.ProtocolClassify.ebT U hbij Rr Iin.nIn {AA} {BB} {HAB})"
UX = "(fun P hdr => ZK60.ProtocolClassify.exUx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (N := 2 ^ 11) P hdr)"
XX = "(fun P hdr => ZK60.ProtocolClassify.exXx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (N := 2 ^ 11) P hdr)"
rd = cut(s_codeT, "    (hread : ∀ (A : OC", "    (hdzero : ∀ (A : OC")
rd2 = once(rd, "      Xx (A.runLog G).2 ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aA)",
           "      ZK60.ProtocolClassify.exXx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2\n"
           f"          ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take {AA})")
rd2 = once(rd2, "        ∧ Ux (A.runLog G).2 ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aA)",
           "        ∧ ZK60.ProtocolClassify.exUx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2\n"
           f"          ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take {AA})")
rd2 = once(rd2, "algebraMap GF F", "algebraMap GF K")
s_codeT = once(s_codeT, rd, rd2)
bal_type = bal[len("    (hBal : "):].rstrip()
assert bal_type.endswith(")")
bal_type = bal_type[:-1]
bal_type = once(bal_type, "(T.cB (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W Ux Xx (A.runLog G).2)",
                f"({TT}.cB\n          (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W {UX}\n          {XX}\n"
                "          (A.runLog G).2)")
BLK = "(d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)"
SECVARS = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path", "tagc"]
fixed_codeT = {
    "T": TT, "hTenc": "ZK60.ProtocolClassify.eb_enc_ep", "hTwA": "rfl", "hTwB": "rfl", "Ux": UX, "Xx": XX,
    "hUc": "(ZK60.ProtocolClassify.exUx_cut tag Lq h64 key domain hs hL abRdIn 11 1 Rr (2 ^ 11))",
    "hXc": "(ZK60.ProtocolClassify.exXx_cut tag Lq h64 key domain hs hL abRdIn 11 1 Rr (2 ^ 11))",
    "pr": "gP", "hp1": "(by norm_num)", "hp2": "(by norm_num)", "hF": "hD.hK", "hw0": "hw0'",
    "hβLR": "rfl", "hTe": "rfl", "hTQ": "rfl", "hβJ": "rfl", "hBal": "hBal",
}
args_codeT = [f"({n} := {n})" for n in SECVARS] + ["(F := K)", "(Cl := Fin Iin.nIn)"]
for n in explicit_code:
    args_codeT.append(f"({n} := {fixed_codeT.get(n, n)})")


def wrap_exact(head_call: str, arg_list: list[str]) -> str:
    lines = []
    cur = f"  exact {head_call}"
    for a in arg_list:
        if len(cur) + 1 + len(a) > 118:
            lines.append(cur)
            cur = "    " + a
        else:
            cur += " " + a
    lines.append(cur)
    return "\n".join(lines)


proof_codeT = (
    "  by\n"
    "  have hσ0 : (RtRun.σs Rn)[0]? = some (rtIncSeg inc incG cx0 pin) := by\n"
    "    rw [hσ]\n"
    "    rfl\n"
    "  have hw0' : Iin.nIn + Rr ≤ 2 ^ 61 := by\n"
    "    have h0 : 0 < (RtRun.pf Rn).parts.length := by\n"
    "      rw [RtRun.parts_length Rn]\n"
    "      omega\n"
    "    have hv0 := (hD.opV 0 h0).2.2.hw\n"
    "    rw [hDe] at hv0\n"
    "    change (base 0).nX + (base 0).gX.rows ≤ 2 ^ 61 at hv0\n"
    "    rw [hgX0] at hv0\n"
    "    rw [← hRr, ← hnX0]\n"
    "    exact hv0\n"
    "  have hBal : " + bal_type + " := by\n"
    "    intro A G hacc hx\n"
    "    have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG " + BLK + "\n"
    "      outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "    rw [OC.runLog_fst] at hE0\n"
    "    have w := ZK60.ProtocolClassify.ex_hopX0C U tag h64 hs hL hw Rn hRn hv G (A.run G).1 (A.run G).2 hE0 pin inc\n"
    "      incG cx0 Iin hσ0 Win (hW A G hacc).1 ogEp ogEp_ok (by decide) hXep outcG sgeom Lb A rfl\n"
    "      (fun h => hx (Or.inr h)) hfitX\n"
    "    rw [hRr] at w\n"
    "    exact ZK60.ProtocolClassify.ex_xB_alive U hU hbij tag Lq h64 key domain hs hL abRdIn _ Rr Iin.nIn 1 _ _ _ _ _ G\n"
    "      _ w " + HAB + "\n"
    + wrap_exact("sj_productionReadyL_epP_code", args_codeT) + "\n"
)
p0 = s_codeT.index("  by\n", s_codeT.index(END_TOK))
p1 = s_codeT.index("\nend SjCodeTTop\n")
s_codeT = s_codeT[:p0] + proof_codeT + s_codeT[p1:]


# 4E: SjCodeTTop -> SjWireTTop (discharge hsl_blk via wr_termBN + wrCs_eq_B + wr_hsem_acc + bnd_hsl_evBN_of_args)
s_wireT = s_codeT
s_wireT = once(s_wireT, "section SjCodeTTop\n", "section SjWireTTop\n")
s_wireT = once(s_wireT, "end SjCodeTTop\n", "end SjWireTTop\n")
s_wireT = once(s_wireT, "theorem sj_productionReadyL_epP_codeT ", "theorem sj_productionReadyL_epP_wireT ")
wt_i = s_wireT.index("theorem sj_productionReadyL_epP_wireT ")
wt_j = s_wireT.index(END_TOK, wt_i) + len(END_TOK)
wt_stmt = s_wireT[wt_i:wt_j]
wt_bs = top_binders(wt_stmt)
explicit_codeT = [n for (k, ns, _, _) in wt_bs if k == "(" for n in ns]
(_, _, hb_s, hb_e) = [b for b in wt_bs if b[1] == ["hsl_blk"]][0]
hsl_blk_grp = wt_stmt[hb_s:hb_e]
assert hsl_blk_grp.startswith("(hsl_blk : ") and hsl_blk_grp.endswith(")")
hsl_blk_ty = hsl_blk_grp[len("(hsl_blk : "):-1]

WIRE_NEW_BINDERS = (
    "(hgXB : ∀ j, j ≤ Lb → (base (j + 1)).gX.ipos = (RtRun.pf Rn).off j + 2)\n"
    "    (hdefS : ∀ k, k < Lb → ∃ (prog : List Exec.Block.SlotS) (pubs : Exec.Block.PubTabs),\n"
    "      (Pk k).define = Exec.Block.defineS prog pubs)\n"
    "    (hsl_argsN : ∀ k, k < Lb → ∀ (c3 : Exec.Block.Cuts3 Lq) (rt : Exec.Block.RootsO) (hx : Exec.Block.HdrX Lq),\n"
    "      Exec.Block.SlotEvalN U (Pk k)\n"
    "        (ZK60.ProtocolClassify.csArgs U tag Lq h64 (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))\n"
    "          c3 rt hx ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))\n"
    "        (ZK60.ProtocolClassify.msArgs U tag Lq h64 (bp k).S c3 rt) (fun j sn pt => Fsl k c3 rt hx j sn pt))"
)
wt_stmt_new = wt_stmt[:hb_s] + WIRE_NEW_BINDERS + wt_stmt[hb_e:]
TAU = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
OGS = "ogStage"
OGS_OK = "ogStage_ok"

args_wireT = [f"({n} := {n})" for n in SECVARS]
for n in explicit_codeT:
    args_wireT.append(f"({n} := {n})")

proof_wireT = (
    "  by\n"
    f"  have hsl_blk : {hsl_blk_ty} := by\n"
    "    intro A G hacc hx _ hM hA k hk\n"
    f"    have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG {BLK}\n"
    "      outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "    rw [OC.runLog_fst] at hE0\n"
    "    subst hDe\n"
    "    have hev := ZK60.ProtocolClassify.bnd_hsl_evBN_of_args U tag h64 hs hL Lb preA preB start inc incG outc outcG\n"
    "      Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn cx0 pin pout bp wXk gXk mXk hσ abRdIn base\n"
    f"      (rxDinG {OGS} (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)\n"
    f"      (rxDoutG {OGS} (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH)\n"
    "      (fun k => (bp k).S) (fun k => (Pk k).nFunctionals) (fun k => (bp k).pA.rows) (fun k => (bp k).pH.rows)\n"
    "      (fun k => (bp k).nA) (fun k => (bp k).nH) (rxAcc Win Wout Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb)\n"
    f"      eL Fsl hsl_argsN G (A.runLog G).2 {TAU} k hk\n"
    "    have e := ZK60.ProtocolClassify.wrCs_eq_B U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn) base Lb\n"
    f"      (rxDinG {OGS} (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)\n"
    "      (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)\n"
    f"      (rxDoutG {OGS} (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH)\n"
    f"      (rxAcc Win Wout Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL (A.runLog G).2 {TAU} k hgXB hk\n"
    "    exact ZK60.ProtocolClassify.wr_termBN U hU key domain (Pk k) _ _ (Fsl k) G (A.runLog G).2 _ _ _\n"
    "      (fun j hj => ((bp k).hgeomL j hj).1)\n"
    "      (by obtain ⟨prog, pubs, hd⟩ := hdefS k hk; exact Exec.Block.defineS_polyC (Pk k) prog pubs hd)\n"
    "      (fun hdr core bga rs acc T' hsa htr => ZK60.ProtocolClassify.wr_hsem_acc U hbij tag h64 hs hL hL64 Lb preA preB\n"
    "        start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout Iin Oout\n"
    f"        bp wXk gXk mXk hσ hLb hgeo {OGS} {OGS_OK} le_rfl hIA hIH hOA hOH hBA hBH htI htO htB hfIA hfIH hfOA hfOH\n"
    "        hfBA hfBH hfIM hfOM hfBM Win Wout lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn hkIn hkOut base abRdIn eL hD\n"
    "        (Rp.blks.length + 2) (le_of_eq ((RtRun.parts_length Rn).trans (congrArg (fun n => n + 2) O.blocks.2)))\n"
    "        A G hE0 (hW A G hacc).1 (hW A G hacc).2 (fun h => hx (Or.inl h)) (hopX1 A G hacc hx) hA hM k hk hdr core bga rs\n"
    "        acc T' hsa htr)\n"
    "      (fun hdr core bga rs acc T' hsa htr => by\n"
    "        have h2 := hev hdr core bga rs acc T' hsa htr\n"
    "        rw [← e] at h2\n"
    "        exact h2)\n"
    + wrap_exact("sj_productionReadyL_epP_codeT", args_wireT) + "\n"
)
wp0 = s_wireT.index("  by\n", wt_j)
wp1 = s_wireT.index("\nend SjWireTTop\n")
s_wireT = s_wireT[:wt_i] + wt_stmt_new + "\n" + proof_wireT + s_wireT[wp1:]

OPENS_CHAIN = """open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (LeaksAtMost productionReadyL_of_productionReady productionReadyL_of_productionReady_range)
open ZK60.ProtocolClassify (ClsHdrW clsHdrOf clsStart)
"""

join_chain_out = (
    "/-\n"
    "D63 lane L60 (2026-11-13), part 4: **the joined Stage + Block + Endpoint chain** (`exec_blk` -> `exec_alive` ->\n"
    "`code` -> `codeT` -> `wireT`), uniting L56's widened block schedule/defs, L57's real stage view lists, L58's\n"
    "checked input endpoint event/column test, and L60's `SlotEvalN` + `lkSqB` + `RdBlkR13B`.\n\n"
    "Generated by `results/zk60_lean_l60_20261113/l60_mk_join.py`. Only `propext`, `Classical.choice`, `Quot.sound`.\n"
    "-/\n"
    "import ZK60Formal.RunEpBChain\n"
    "import ZK60Formal.RunEpXTop\n"
    "import ZK60Formal.RunEpXTest\n"
    "import ZK60Formal.RunStgAlgTopR\n"
    "import ZK60Formal.RunStgJoinLk\n"
    "import ZK60Formal.RunStgJoinBnd\n"
    "import ZK60Formal.RunStgJoinSem\n\n"
    "set_option autoImplicit false\n"
    "set_option linter.constructorNameAsVariable false\n\n"
    "namespace ZK60.ProtocolClassify.RunShapeP\n\n"
    + OPENS_CHAIN + "\n"
    + s_blk + "\n" + s_ra + "\n" + s_code + "\n" + s_codeT + "\n" + s_wireT
    + "\nend ZK60.ProtocolClassify.RunShapeP\n"
)
(L / "RunStgJoinChain.lean").write_text(join_chain_out)
print("RunStgJoinChain.lean:", join_chain_out.count("\n"), "lines")


# ----------------------------------------------------------------------------
# 5. RunStgJoinTop.lean: W -> X -> F (+ sj_hgXB) -> G -> H -> join & join_shield
# ----------------------------------------------------------------------------
# 5A: Step W (`l55_mk_top.py` on `SjWireTTop`)
s_w = s_wireT
w_th0 = s_w.index("theorem sj_productionReadyL_epP_wireT ")
w_th1 = s_w.index(END_TOK, w_th0) + len(END_TOK)
explicit_wireT = [n for (k, ns, _, _) in top_binders(s_w[w_th0:w_th1]) if k == "(" for n in ns]
assert "hW" in explicit_wireT and "Win" in explicit_wireT and "Wout" in explicit_wireT

s_w = once(s_w, "section SjWireTTop\n", "section SjWireWTop\n")
s_w = once(s_w, "end SjWireTTop\n", "end SjWireWTop\n")
s_w = once(s_w, "theorem sj_productionReadyL_epP_wireT ", "theorem sj_productionReadyL_epP_wireW ")
s_w = once(s_w,
           "    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Exec.Block.ZClaim)\n",
           "    (Vi : IncV) (F : ℕ → OutcV) (hinc : ∀ hd, inc hd = Vi) (houtc : ∀ hd v, outc hd v = F v)\n"
           "    (hchk : ∀ s : ClsStmt Hdr, check s 0 = .ok () → s.verdict ≤ 1) (hLb1 : 0 < Lb)\n"
           "    (lscIn lscOut : Exec.Block.ZClaim)\n")
hw_cut = cut(s_w, "    (hW : ∀ (A : OC", "    (hopX1 : ∀ (A : OC")
s_w = once(s_w, hw_cut, "")

WIN = "(ZK60.ProtocolClassify.vdWin Vi)"
WOUT = "(ZK60.ProtocolClassify.vdWout F)"
wp_a = s_w.index("theorem sj_productionReadyL_epP_wireW ")
wp_b = s_w.index(END_TOK, wp_a)
w_stmt = s_w[wp_a:wp_b]
w_stmt = re.sub(r"\bWin\b", WIN, w_stmt)
w_stmt = re.sub(r"\bWout\b", WOUT, w_stmt)
s_w = s_w[:wp_a] + w_stmt + s_w[wp_b:]

fixed_W = {
    "Win": WIN, "Wout": WOUT,
    "hW": (f"(ZK60.ProtocolClassify.vd_hW Rp Lb preA preB start inc incG {BLK} outc outcG P (CinR) h64 hr\n"
           "      hon.base 768 key domain Rn hw hRn Vi F hinc houtc hchk hLb1 pin pout)"),
}
args_W = [f"({n} := {n})" for n in SECVARS] + [f"({n} := {fixed_W.get(n, n)})" for n in explicit_wireT]
proof_W = "  by\n" + wrap_exact("sj_productionReadyL_epP_wireT", args_W) + "\n"
wq0 = s_w.index("  by\n", s_w.index(END_TOK))
wq1 = s_w.index("\nend SjWireWTop\n")
s_w = s_w[:wq0] + proof_W + s_w[wq1:]


# 5B: Step X (`l55_mk_topX.py` on `SjWireWTop`)
s_x = s_w
x_th0 = s_x.index("theorem sj_productionReadyL_epP_wireW ")
x_th1 = s_x.index(END_TOK, x_th0) + len(END_TOK)
explicit_W = [n for (k, ns, _, _) in top_binders(s_x[x_th0:x_th1]) if k == "(" for n in ns]
assert "hopX1" in explicit_W

s_x = once(s_x, "section SjWireWTop\n", "section SjWireXTop\n")
s_x = once(s_x, "end SjWireWTop\n", "end SjWireXTop\n")
s_x = once(s_x, "theorem sj_productionReadyL_epP_wireW ", "theorem sj_productionReadyL_epP_wireX ")
hop = cut(s_x, "    (hopX1 : ∀ (A : OC", "    (hgX0 :")
hop_type = hop[len("    (hopX1 : "):].rstrip()
assert hop_type.endswith(")")
hop_type = hop_type[:-1]
hop2 = once(hop, "    (hopX1 : ∀ (A : OC", "    (hopX1e : ∀ (A : OC")
hop2 = once(hop2, "∀ i, 0 < i → i < (RtRun.pf Rn).parts.length →",
            "∀ i, (i = 1 ∨ i = Lb + 1) → i < (RtRun.pf Rn).parts.length →")
NEW_X = (
    "    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))\n"
    "    (hXk : ∀ k, ZK60.ProtocolClassify.RkPcsR13 U tag (pXk k))\n"
    "    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)\n"
    "    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m) (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)\n"
    "    (hgXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX\n"
    "      = ZK60.ProtocolClassify.rkR13 (pXk (k + 1)).rows ((RtRun.pf Rn).off (k + 1) + 2))\n"
    "    (hnXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn)\n"
)
s_x = once(s_x, hop, hop2 + NEW_X)

DIN = "(rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)"
DBLK = ("(fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA\n"
        "          (bp k).nH)")
DOUT = "(rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH)"
PP = ("(fun k => rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)\n"
      "        (bp k).pH.m (wXk k) (gXk k) (mXk k))")
args_X = [f"({n} := {n})" for n in SECVARS] + [f"({n} := {n})" for n in explicit_W]
proof_X = (
    "  by\n"
    "  have hσb : ∀ k, k < Lb → (RtRun.σs Rn)[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck\n"
    "      bndOpen k (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)\n"
    "        (bp k).pH.m (wXk k) (gXk k) (mXk k))) := by\n"
    "    intro k hk\n"
    "    rw [hσ]\n"
    "    exact ZK60.ProtocolClassify.rx_getBlk _ _ _ _ k hk\n"
    "  have hopX1 : " + hop_type + " := by\n"
    "    intro A G hacc hx i hi0 hil\n"
    "    by_cases h1 : i = 1 ∨ i = Lb + 1\n"
    "    · exact hopX1e A G hacc hx i h1 hil\n"
    "    · have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG " + BLK + "\n"
    "        outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "      rw [OC.runLog_fst] at hE0\n"
    "      have hl : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn\n"
    "      obtain ⟨k, rfl⟩ : ∃ k, i = k + 1 + 1 := ⟨i - 2, by omega⟩\n"
    "      have hk : k + 1 < Lb := by omega\n"
    "      exact ZK60.ProtocolClassify.cb_hopX1_mid U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck\n"
    "        bndOpen Rn hv G (A.run G).1 (A.run G).2 hE0 Lb hLb bp\n"
    "        " + PP + "\n"
    "        hσb (fun s k => hgeo k s) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) pXk hXk\n"
    "        hwXk hmXk hfitXk base " + DIN + "\n        " + DBLK + "\n        " + DOUT + "\n"
    "        hgXk hnXk (ZK60.ProtocolClassify.vdWin Vi) (ZK60.ProtocolClassify.vdWout F) abRdIn incG outcG A rfl\n"
    "        (fun h => hx (Or.inl h)) k hk\n"
    + wrap_exact("sj_productionReadyL_epP_wireW", args_X) + "\n"
)
xq0 = s_x.index("  by\n", s_x.index(END_TOK))
xq1 = s_x.index("\nend SjWireXTop\n")
s_x = s_x[:xq0] + proof_X + s_x[xq1:]


# 5C: Step F (`l55_mk_topF.py` + `sj_hgXB` discharging `hgXB`!)
s_f = s_x
f_th0 = s_f.index("theorem sj_productionReadyL_epP_wireX ")
f_th1 = s_f.index(END_TOK, f_th0) + len(END_TOK)
explicit_X = [n for (k, ns, _, _) in top_binders(s_f[f_th0:f_th1]) if k == "(" for n in ns]
assert "hopX1e" in explicit_X and "hgXB" in explicit_X

s_f = once(s_f, "section SjWireXTop\n", "section SjWireFTop\n")
s_f = once(s_f, "end SjWireXTop\n", "end SjWireFTop\n")
s_f = once(s_f, "theorem sj_productionReadyL_epP_wireX ", "theorem sj_productionReadyL_epP_wireF ")
hop_e = cut(s_f, "    (hopX1e : ∀ (A : OC", "    (pXk : ∀ k,")
hop_e_type = hop_e[len("    (hopX1e : "):].rstrip()
assert hop_e_type.endswith(")")
hop_e_type = hop_e_type[:-1]
s_f = once(s_f, hop_e, "")
anchor_F = "    (hnXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn)\n"
NEW_F = (
    "    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows) (hmX0 : mXk 0 = (pXk 0).m)\n"
    "    (hgX1 : (base 1).gX = ZK60.ProtocolClassify.rkR13 (pXk 0).rows ((RtRun.pf Rn).off 0 + 2))\n"
    "    (hnX1 : (base 1).nX = Iin.nOut + (bp 0).nIn)\n"
    "    (hOX : ZK60.ProtocolClassify.RkPcsR13 U tag Oout.pX)\n"
    "    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows) (hfitXo : 8 * Oout.pX.rows ≤ Lq)\n"
    "    (hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX\n"
    "      = ZK60.ProtocolClassify.rkR13 Oout.pX.rows ((RtRun.pf Rn).off (k + 1) + 2))\n"
    "    (hnXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).nX = (bp k).nOut + Oout.nIn)\n"
)
s_f = once(s_f, anchor_F, anchor_F + NEW_F)
# Also discharge hgXB!
s_f = once(s_f, "    (hgXB : ∀ j, j ≤ Lb → (base (j + 1)).gX.ipos = (RtRun.pf Rn).off j + 2)\n", "")

args_F = [f"({n} := {n})" for n in SECVARS] + [f"({n} := {n})" for n in explicit_X]
proof_F = (
    "  by\n"
    "  have hgXB : ∀ j, j ≤ Lb → (base (j + 1)).gX.ipos = (RtRun.pf Rn).off j + 2 :=\n"
    "    ZK60.ProtocolClassify.sj_hgXB (RtRun.pf Rn) Lb base (pXk 0).rows (fun j => (pXk j).rows) Oout.pX.rows hgX1 hgXk hgXo\n"
    "  have hσb : ∀ k, k < Lb → (RtRun.σs Rn)[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck\n"
    "      bndOpen k (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)\n"
    "        (bp k).pH.m (wXk k) (gXk k) (mXk k))) := by\n"
    "    intro k hk\n"
    "    rw [hσ]\n"
    "    exact ZK60.ProtocolClassify.rx_getBlk _ _ _ _ k hk\n"
    "  have hσ0 : (RtRun.σs Rn)[0]? = some (rtIncSeg inc incG cx0 pin) := by\n"
    "    rw [hσ]\n"
    "    rfl\n"
    "  have hσo : (RtRun.σs Rn)[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by\n"
    "    rw [hσ]\n"
    "    exact ZK60.ProtocolClassify.rx_getOut _ _ _ _\n"
    "  have hopX1e : " + hop_e_type + " := by\n"
    "    intro A G hacc hx i h1 hil\n"
    "    have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG " + BLK + "\n"
    "      outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "    rw [OC.runLog_fst] at hE0\n"
    "    have hW2 := ZK60.ProtocolClassify.vd_hW Rp Lb preA preB start inc incG " + BLK + "\n"
    "      outc outcG P (CinR) h64 hr hon.base 768 key domain Rn hw hRn Vi F hinc houtc hchk hLb1 pin pout A G hacc\n"
    "    rcases h1 with rfl | rfl\n"
    "    · exact ZK60.ProtocolClassify.cb_hopX1_one U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck\n"
    "        bndOpen Rn hv G (A.run G).1 (A.run G).2 hE0 Lb hLb1 pin inc incG cx0 Iin hσ0\n"
    "        (ZK60.ProtocolClassify.vdWin Vi) hW2.1 bp\n"
    "        " + PP + "\n"
    "        hσb (fun s k => hgeo k s) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) pXk hXk\n"
    "        hwX0 hmX0 hfitXk base " + DIN + "\n        " + DBLK + "\n        " + DOUT + "\n"
    "        hgX1 hnX1 (ZK60.ProtocolClassify.vdWout F) abRdIn outcG A rfl (fun h => hx (Or.inl h))\n"
    "    · exact ZK60.ProtocolClassify.cb_hopX1_last U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck\n"
    "        bndOpen Rn hv G (A.run G).1 (A.run G).2 hE0 Lb hLb1 hLb bp\n"
    "        " + PP + "\n"
    "        hσb (fun s k => hgeo k s) pout outc outcG Oout hσo (ZK60.ProtocolClassify.vdWout F) hW2.2 hOX hwXo hfitXo\n"
    "        base " + DIN + "\n        " + DBLK + "\n        " + DOUT + "\n"
    "        hgXo hnXo (ZK60.ProtocolClassify.vdWin Vi) abRdIn incG A rfl (fun h => hx (Or.inl h))\n"
    + wrap_exact("sj_productionReadyL_epP_wireX", args_F) + "\n"
)
fq0 = s_f.index("  by\n", s_f.index(END_TOK))
fq1 = s_f.index("\nend SjWireFTop\n")
s_f = s_f[:fq0] + proof_F + s_f[fq1:]


# 5D: Step G (`l58_mk_topG.py` on `SjWireFTop`)
s_g = s_f
g_th0 = s_g.index("theorem sj_productionReadyL_epP_wireF ")
g_th1 = s_g.index(END_TOK, g_th0) + len(END_TOK)
explicit_F = [n for (k, ns, _, _) in top_binders(s_g[g_th0:g_th1]) if k == "(" for n in ns]
for n in ["ops", "hops", "hcan", "hread", "tag", "E", "mk", "hE"]:
    assert n in explicit_F, n

s_g = once(s_g, "section SjWireFTop\n", "section SjWireGTop\n")
s_g = once(s_g, "end SjWireFTop\n", "end SjWireGTop\n")
s_g = once(s_g, "theorem sj_productionReadyL_epP_wireF ", "theorem sj_productionReadyL_epP_wireG ")
s_g = once(s_g, "(path : Salt → Fin (2 ^ 11) → List Dig) (tagc : MTag)\n",
           "(path : Salt → Fin (2 ^ 11) → List Dig) (tag : MTag)\n")
s_g = once(s_g, "salt path ClsStmt.inRoot tagc\n", "salt path ClsStmt.inRoot tag\n")
s_g = once(s_g, "    (tag : MTag)\n", "")

OPS = "(ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11))"
b_ops = cut(s_g, "    (ops : List (QB Lq × Dig)", "    (hE : ∀ lg s pf")
s_g = once(s_g, b_ops, "")
b_hops = cut(s_g, "    (hops : ∀ (A : OC", "    (hcan : ∀ lg s j o")
s_g = once(s_g, b_hops, "")
b_hcan = cut(s_g, "    (hcan : ∀ lg s j o", "    (hread : ∀ (A : OC")
s_g = once(s_g, b_hcan, "")
b_hread = cut(s_g, "    (hread : ∀ (A : OC", "    (hdzero : ∀ (A : OC")
s_g = once(s_g, b_hread, "")

gp_a = s_g.index("theorem sj_productionReadyL_epP_wireG ")
gp_b = s_g.index(END_TOK, gp_a)
g_stmt = re.sub(r"\bops\b", OPS, s_g[gp_a:gp_b])
s_g = s_g[:gp_a] + g_stmt + s_g[gp_b:]

hread_type = b_hread[len("    (hread : "):].rstrip()
assert hread_type.endswith(")")
hread_type = re.sub(r"\bops\b", OPS, hread_type[:-1])
SECVARS_G = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path"]
fixed_G = {
    "tag": "tag", "ops": OPS,
    "hops": "(ZK60.ProtocolClassify.ex_hops tag Lq h64 key domain hs hL abRdIn 11 Rr hr)",
    "hcan": "(ZK60.ProtocolClassify.ex_hcan tag Lq h64 key domain hs hL abRdIn 11 Rr)",
    "hread": "hread",
}
args_G = [f"({n} := {n})" for n in SECVARS_G] + ["(tagc := tag)"] + [f"({n} := {fixed_G.get(n, n)})" for n in explicit_F]
proof_G = (
    "  by\n"
    "  have hread : " + hread_type + " := by\n"
    "    intro A G hacc _\n"
    "    have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG " + BLK + "\n"
    "      outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "    rw [OC.runLog_fst] at hE0\n"
    "    have hRd := ZK60.ProtocolClassify.ab_rdIn_at1 hw Rn hRn G (A.run G).1 (A.run G).2 hE0 " + AA + "\n"
    "      (by rw [ZK60.ProtocolClassify.ab_off0 hw Rn hRn G (A.run G).1 (A.run G).2 hE0]; omega)\n"
    "    have hH := ZK60.ProtocolClassify.epxH_at_root tag Lq h64 key domain hs hL abRdIn 11 1 Rr (N := 2 ^ 11)\n"
    "      (A.runLog G).2 ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take " + AA + ")\n"
    "      (A.run G).1.inRoot hRd\n"
    "    rw [OC.runLog_fst]\n"
    "    exact ⟨congrArg exX hH, funext fun i => funext fun j => congrArg (fun f => algebraMap GF K (exU f i j)) hH⟩\n"
    + wrap_exact("sj_productionReadyL_epP_wireF", args_G) + "\n"
)
gq0 = s_g.index("  by\n", s_g.index(END_TOK))
gq1 = s_g.index("\nend SjWireGTop\n")
s_g = s_g[:gq0] + proof_G + s_g[gq1:]


# 5E: Step H (`l58_mk_topH.py` on `SjWireGTop`) -> `sj_productionReadyL_epP_join` & `sj_productionReadyL_epP_join_shield`
s_h = s_g
h_th0 = s_h.index("theorem sj_productionReadyL_epP_wireG ")
h_th1 = s_h.index(END_TOK, h_th0) + len(END_TOK)
explicit_G = [n for (k, ns, _, _) in top_binders(s_h[h_th0:h_th1]) if k == "(" for n in ns]
for n in ["E", "mk", "hE"]:
    assert n in explicit_G, n

s_h = once(s_h, "section SjWireGTop\n", "section SjJoinTop\n")
s_h = once(s_h, "end SjWireGTop\n", "end SjJoinTop\n")
s_h = once(s_h, "theorem sj_productionReadyL_epP_wireG ", "theorem sj_productionReadyL_epP_join ")
s_h = redoc(
    s_h, "theorem sj_productionReadyL_epP_join ",
    "/-- **THE JOINED STAGE + BLOCK + ENDPOINT TOP THEOREM** (D63 lane L60): unites L56's widened block schedule/defs,\n"
    "L57's real stage view lists, L55's stage readers and closing openings (`hW`, `hopX1`, `hgXB` PROVED), L58's\n"
    "checked input endpoint extractor and real opening data (`ops`, `hops`, `hcan`, `hread`, `mk`, `hE`, `msg_place`\n"
    "PROVED), and L60's `SlotEvalN` + `lkSqB` + `RdBlkR13B` (`hsl_blk` PROVED from `hsl_argsN`). -/"
)

SALT = "(ZK60.ProtocolClassify.EpxSalt Rr)"
MSG = "(ZK60.ProtocolClassify.epxMsg Rr dR place pos)"
MSGP = "(ZK60.ProtocolClassify.epxMsg_place Rr dR place pos hplace)"
MK = "(ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag)"
EX = f"(ZK60.ProtocolClassify.epxE (CinR) {MK} pos {OPS} E0)"

s_h = once(s_h, "variable {S : BlockShape} {Hdr Salt Coins : Type}\n", "variable {S : BlockShape} {Hdr Coins : Type}\n")
s_h = once(s_h,
           "  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 8) → GF)\n"
           "  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)\n"
           "  (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (tag : MTag)\n",
           "  (place : Fin dR → Fin Rr) (hplace : Function.Injective place) (tag : MTag)\n")
s_h = once(s_h, "  epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tag\n",
           "  epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place " + MSG + "\n    " + MSGP
           + " ZK60.ProtocolClassify.EpxSalt.pads\n    ZK60.ProtocolClassify.EpxSalt.salts ZK60.ProtocolClassify.EpxSalt.paths"
           " ClsStmt.inRoot tag\n")
s_h = once(s_h, "    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)\n",
           "    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S " + SALT + ")\n")
s_h = once(s_h, "    (mk : (CinR).SaltMk)\n", "")
b_hE = cut(s_h, "    (hE : ∀ lg s pf", "    (hdzero : ∀ (A : OC")
s_h = once(s_h, b_hE, "")

hp_a = s_h.index("theorem sj_productionReadyL_epP_join ")
hp_b = s_h.index(END_TOK, hp_a)
h_stmt = re.sub(r"\bE\b", EX, s_h[hp_a:hp_b])
assert not re.search(r"\bSalt\b", h_stmt), "Salt left"
assert not re.search(r"\bmk\b", h_stmt), "mk left"
s_h = s_h[:hp_a] + h_stmt + s_h[hp_b:]

SECVARS_H = ["Rr", "dR", "hpos", "place"]
fixed_H = {"E": EX, "mk": MK, "hE": f"(ZK60.ProtocolClassify.epxE_hE (CinR) {MK} pos {OPS} E0)"}
args_H = [f"({n} := {n})" for n in SECVARS_H] + [
    f"(msg := {MSG})", f"(msg_place := {MSGP})",
    "(pad := ZK60.ProtocolClassify.EpxSalt.pads)",
    "(salt := ZK60.ProtocolClassify.EpxSalt.salts)",
    "(path := ZK60.ProtocolClassify.EpxSalt.paths)", "(tag := tag)",
]
for n in explicit_G:
    if n == "tag":
        continue
    args_H.append(f"({n} := {fixed_H.get(n, n)})")
proof_H = "  by\n" + wrap_exact("sj_productionReadyL_epP_wireG", args_H) + "\n"
hq0 = s_h.index("  by\n", s_h.index(END_TOK))
hq1 = s_h.index("\nend SjJoinTop\n")
s_h = s_h[:hq0] + proof_H + s_h[hq1:]

# Also generate `sj_productionReadyL_epP_join_shield` inside `SjJoinTop`:
j_th0 = s_h.index("theorem sj_productionReadyL_epP_join ")
j_th1 = s_h.index(END_TOK, j_th0) + len(END_TOK)
j_stmt = s_h[j_th0:j_th1]
j_bs = top_binders(j_stmt)
explicit_join = [n for (k, ns, _, _) in j_bs if k == "(" for n in ns]
(_, _, d0, d1) = [b for b in j_bs if b[1] == ["hdefS"]][0]
js_stmt = j_stmt[:d0] + "(hPk : ZK60.Exec.Block.Join.R13H.ShieldRunAt Pk Rp.blks Lb)" + j_stmt[d1:]
js_bs2 = top_binders(js_stmt)
(_, _, l0, l1) = [b for b in js_bs2 if b[1] == ["hLb"]][0]
assert js_stmt[l0:l1] == "(hLb : Lb ≤ 26)", js_stmt[l0:l1]
js_stmt = js_stmt[:l0] + js_stmt[l1:].lstrip(" ")
js_stmt = once(js_stmt, "theorem sj_productionReadyL_epP_join ", "theorem sj_productionReadyL_epP_join_shield ")

SECVARS_JOIN = ["Rr", "dR", "hpos", "place", "hplace", "tag"]
args_JS = [f"({n} := {n})" for n in SECVARS_JOIN]
for n in explicit_join:
    if n == "hdefS":
        args_JS.append("(hdefS := ZK60.Exec.Block.Join.R13H.ShieldRunAt.hdefS hPk)")
    elif n == "hLb":
        args_JS.append("(hLb := ZK60.Exec.Block.Join.R13H.ShieldRunAt.lb_le hPk)")
    else:
        args_JS.append(f"({n} := {n})")
js_doc = (
    "\n/-- **THE JOINED TOP THEOREM AT THE SHIELDSTRAL EXPORT** (D63 lane L60): `sj_productionReadyL_epP_join` with\n"
    "block `k`'s verifier tied to layer `k` of `shieldExport` (`hPk : ShieldRunAt`), discharging `hdefS` and `hLb`. -/\n"
)
js_block = js_doc + js_stmt + "\n  by\n" + wrap_exact("sj_productionReadyL_epP_join", args_JS) + "\n"
end_sj_idx = s_h.index("\nend SjJoinTop\n")
s_h = s_h[:end_sj_idx] + js_block + s_h[end_sj_idx:]

join_top_out = (
    "/-\n"
    "D63 lane L60 (2026-11-13), part 5: **the joined Stage + Block + Endpoint top theorems**\n"
    "(`sj_productionReadyL_epP_join` and `sj_productionReadyL_epP_join_shield`).\n\n"
    "Generated by `results/zk60_lean_l60_20261113/l60_mk_join.py`. Only `propext`, `Classical.choice`, `Quot.sound`.\n"
    "-/\n"
    "import ZK60Formal.RunStgJoinChain\n"
    "import ZK60Formal.RunVerdictW\n"
    "import ZK60Formal.RunCloseBMid\n"
    "import ZK60Formal.RunCloseBEnds\n"
    "import ZK60Formal.RunEpXMk\n"
    "import ZK60Formal.RunBndShield\n\n"
    "set_option autoImplicit false\n"
    "set_option linter.constructorNameAsVariable false\n\n"
    "namespace ZK60.ProtocolClassify.RunShapeP\n\n"
    + OPENS_CHAIN + "\n"
    + s_w + "\n" + s_x + "\n" + s_f + "\n" + s_g + "\n" + s_h
    + "\nend ZK60.ProtocolClassify.RunShapeP\n"
)
(L / "RunStgJoinTop.lean").write_text(join_top_out)
print("RunStgJoinTop.lean:", join_top_out.count("\n"), "lines")
