#!/usr/bin/env python3
"""D63 lane L45 (2026-11-10): generate formal/ZK60Formal/RunExtractTop.lean, THE APP'S TOP THEOREM in D76's approved
form with the run's OWN Merkle work and the kinds data's readers built (deliverable 2's statement, carried through
deliverable 1).

From lane L43's generated RunCoverPRk.lean, the theorem `rc_productionReadyL_r13P_exec_rk` is copied with exactly these
changes (each checked below to apply the expected number of times):
  * the name -> rx_productionReadyL_r13P_exec_own;
  * the block profile `blk` -> L18's D12a profile `d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen` (its parameters become binders): the app's blocks;
  * the free Merkle work `C`, `coreOf`, `Vx`, `nx`, `hVx`, `hnx`, `rx`, `nrx`, `hrx`, `hnrx` -> the run's OWN
    (`chainEncB key domain hs Lq hL`, `rxCoreOf sgeom`, `rxVx …`, `rxRoots …`, discharged inside with
    `rxVx_bounded`, `rxRoots_length`): these binders are removed and every `EvXR … C … coreOf Vx rx A G` is rewritten;
  * the free parts' data `ps`, readers `acc`, LogUp sums `lsc` -> the ones BUILT for the classify run (`rxPs`, `rxAcc`,
    `rxLsc`), with the schedule's contracts as binders (`hσ`: the run's parts are L34's classify parts) and the
    openings' R13 numbers, fits and readers' verifiers (`hW`, finding L45-1) as premises;
  * `hopW` -> `hopX`: only the CLOSING openings' facts are asked (deliverable 3); the `A`, `H` facts are PROVED
    (`rx_parts_AH`); `hMW` is removed: PROVED (`rx_parts_M`).
The proof calls `rc_productionReadyL_r13P_exec_rk` with those set.

usage: python3 -I l45_mk_own.py <formal/ZK60Formal dir> <out.lean>
"""
import re
import sys

src, out = sys.argv[1], sys.argv[2]
text = open(f"{src}/RunCoverPRk.lean", encoding="utf-8").read()
a = text.index("section RkTop")
pre = text[a:text.index("/-- **THE APP'S TOP THEOREM")]
t0 = text.index("theorem rc_productionReadyL_r13P_exec_rk")
thm = text[t0:text.index("  by\n  subst hDe", t0)]
thm = thm.replace("theorem rc_productionReadyL_r13P_exec_rk", "theorem rx_productionReadyL_r13P_exec_own", 1)


def sub1(s, old, new, count=1):
    n = s.count(old)
    assert n == count, (old[:60], n, count)
    return s.replace(old, new)


D12A = "(d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)"
D12A_BIND = ("(Pk : ℕ → Exec.Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)\n"
             "    (check : ClsStmt Hdr → ℕ → Except String Unit)\n"
             "    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit) (digest : ClsStmt Hdr → ℕ → Dig)\n"
             "    (bRows bLogN : ℕ → ℕ)\n"
             "    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)\n"
             "    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →\n"
             "      Except String Tr)\n    ")
thm = sub1(thm, "(blk : BlockProfV (ClsStmt Hdr)) ", D12A_BIND)
nblk = len(re.findall(r"\bblk\b", thm))
thm = re.sub(r"\bblk\b", D12A, thm)

MERKLE = ("    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × "
          "Exec.Block.Core)\n"
          "    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)\n"
          "    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)\n"
          "    (hnrx : nrx ≤ 2 ^ 99)\n")
thm = sub1(thm, MERKLE, "    (tag : MTag)\n")
EVX = "EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G"
OWN = ("EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)\n"
       "        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G")
nevx = thm.count(EVX)
thm = thm.replace(EVX, OWN)

i = thm.index("    (hU : U ^ 2 = algebraMap GF K 7) (ps : ℕ → RkPart K Lq)")
k = thm.index("    (hal_slots :")
hopw = thm[thm.index("    (hopW :"):thm.index("    (hMW :")]
verify_line = hopw.split("\n")[1]
PF = "(RtRun.pf Rn)"
TAU = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
VR = f"classifyRunV Lb preA preB start inc incG {D12A} outc outcG"
PS = ("(rxPs base Lb (rxDin (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)\n"
      "        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA\n"
      "          (bp k).nH)\n"
      "        (rxDout (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))")
ACC = "(rxAcc Win Wout Pk (RtRun.pf Rn) Lb)"
LSC = "(rxLsc lscIn lscOut Pk Lb)"
new = f"""    (hU : U ^ 2 = algebraMap GF K 7)
    (cx0 : IncCtx) (pin pout : RtPart) (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts ({VR})
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hIA : RkPcsR13 U tag Iin.pA) (hIH : RkPcsR13 U tag Iin.pH) (hOA : RkPcsR13 U tag Oout.pA)
    (hOH : RkPcsR13 U tag Oout.pH) (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (htI : Iin.tag = tag) (htO : Oout.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIA : 8 * Iin.pA.rows ≤ Lq) (hfIH : 8 * Iin.pH.rows ≤ Lq) (hfOA : 8 * Oout.pA.rows ≤ Lq)
    (hfOH : 8 * Oout.pH.rows ≤ Lq) (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn) (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (base : ℕ → RkPart K Lq) (eL : ℕ)
    (hDe : D = rkData U tag Lq h64 key domain hs hL (RtRun.pf Rn)
      {PS}
      {ACC} {LSC} eL)
    (hW : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
{verify_line}
      Win ({TAU}.take ({PF}.off 0 + pin.pre)) = inc (A.run G).1.hdr
        ∧ Wout ({TAU}.take ({PF}.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hopX : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
{verify_line}
      ¬ {OWN} →
      ∀ i, i < {PF}.parts.length →
        Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW {PF}.sqs) ({PS} i).gX ({PS} i).nX
            (fun hdr => rkPend {ACC} i hdr ++ ({ACC} i hdr).claims.inp) ({PF}.off i + ({PF}.part i).oX)
            ({PF}.off i + ({PF}.part i).oBX)
            ({PF}.off i + ({PF}.part i).oX + (({PS} i).nX + ({PS} i).gX.rows)) (A.runLog G).2 G
            {TAU}))
"""
thm = thm[:i] + new + thm[k:]

COMMON = ("Rr dR hpos place msg msg_place pad salt path tagc Rp Lq Lb preA preB start inc incG outc outcG P h64 hr hon "
          "U hbij key domain hs hL hL64 Rn hv D hD site kOf δOf E O T hTenc hTaA hTaB Ux Xx hUc hXc pr hp1 hp2 hF hw0 "
          "hβLR hTe hTQ hβJ tag hU eL hDe").split()
TAIL = ("hal_slots hal_R0 hal_R1 hal_H0 hal_H1 hal_LU hdin hdblk hdout mk ops hE hops hcan hwin hread hBal hdzero "
        "hzk").split()
HE = (f"(by have h := rc_uexecP_E Rp Lb preA preB start inc incG {D12A} outc outcG P (CinR) h64 hr hon.base 24448 G _ _ "
      "hv'; rw [OC.runLog_fst] at h; exact h)")
PARTS_COMMON = ("(tag := tag) (h64 := h64) (hs := hs) (hL := hL) (Lb := Lb) (preA := preA) (preB := preB) "
                "(start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG) (Pk := Pk) "
                "(sgeom := sgeom) (check := check) (paths := paths) (digest := digest) (bRows := bRows) "
                "(bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := Rn) (hv := hv) (cx0 := cx0) "
                "(pin := pin) (pout := pout) (I := Iin) (O := Oout) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) "
                "(hσ := hσ) (hLb := hLb) (hgeo := hgeo) (Win := Win) (Wout := Wout) (mIn := mIn) (kIn := kIn) "
                "(kOut := kOut) (base := base) (acc := _) (hacc := rfl) (A := A) (G := G) (hE := " + HE + ") "
                "(hWin := (hW A G hv').1) (hWout := (hW A G hv').2) (hX := hx') (i := i) (hi := hi)")
AH = ("rx_parts_AH (U := U) " + PARTS_COMMON + " (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA) "
      "(hBH := hBH) (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) "
      "(lscIn := lscIn) (lscOut := lscOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (ps := _) "
      "(hps := rfl) (lsc := _) (hlsc := rfl)")
MM = ("rx_parts_M " + PARTS_COMMON + " (htI := htI) (htO := htO) (htB := htB) (hfIM := hfIM) (hfOM := hfOM) "
      "(hfBM := hfBM) (hkIn := hkIn) (hkOut := hkOut) (ps := _) (rIA := Iin.pA.rows) (rIH := Iin.pH.rows) "
      "(rOA := Oout.pA.rows) (rOH := Oout.pH.rows) (rBA := fun k => (bp k).pA.rows) (rBH := fun k => (bp k).pH.rows) "
      "(hps := rfl)")
args = [f"({x} := {x})" for x in COMMON]
args.append(f"(blk := {D12A})")
args += ["(C := chainEncB key domain hs Lq hL)", "(coreOf := rxCoreOf sgeom)",
         "(Vx := rxVx tag Lq h64 incG outcG sgeom Lb)", "(nx := 574464)",
         "(hVx := rxVx_bounded tag Lq h64 incG outcG sgeom Lb)", "(hnx := rxVx_le)",
         "(rx := rxRoots incG outcG sgeom Lb)", "(nrx := 35)", "(hrx := rxRoots_length incG outcG sgeom Lb)",
         "(hnrx := rxRoots_le)", f"(ps := {PS})", f"(acc := {ACC})", f"(lsc := {LSC})"]
args.append(f"(hopW := fun A G hv' hx' i hi => ⟨({AH}).1, ({AH}).2, hopX A G hv' hx' i hi⟩)")
args.append(f"(hMW := fun A G hv' hx' i hi => {MM})")
args += [f"({x} := {x})" for x in TAIL]
body = ["  by", "  exact rc_productionReadyL_r13P_exec_rk"]
line = ""
for x in args:
    if len(line) + len(x) + 1 > 110 and line:
        body.append("    " + line.rstrip())
        line = ""
    line += x + " "
body.append("    " + line.rstrip())

doc = ("/-- **THE APP'S TOP THEOREM WITH THE RUN'S OWN MERKLE WORK AND THE KINDS DATA'S READERS BUILT** (D63 lane L45).\n"
       "L43's `rc_productionReadyL_r13P_exec_rk` at the D12a blocks, with `EvXR`'s chain, cores, other Merkle work and\n"
       "other roots the run's own (`chainEncB …`, `rxCoreOf`, `rxVx`, `rxRoots`: no free Merkle work left, finding\n"
       "L43-2, GA-8), with `D`'s parts, readers and LogUp sums those of the classify run (`rxPs`, `rxAcc`, `rxLsc`),\n"
       "`hopW`'s `A` and `H` halves PROVED (`rx_parts_AH`: the stages' readers, finding L43-6, and the extraction from\n"
       "`¬ EvXR`) and `hMW` PROVED (`rx_parts_M`); only the closing openings' facts `hopX` are left of them. Generated. -/")
out_l = [
    "/-",
    "D63 lane L45 (2026-11-10), part 8: **the app's top theorem in D76's approved form with the run's OWN Merkle work",
    "(`C`, `coreOf`, `Vx`, `rx` set to the run's: finding L43-2, GA-8) and the kinds data's parts and readers BUILT for the",
    "classify run (finding L43-6)**. `hopW`'s `A`, `H` halves and all of `hMW` are discharged; `hopX` (the closing",
    "openings) is left to deliverable 3.",
    "GENERATED by `results/zk60_lean_l45_20261110/l45_mk_own.py` from lane L43's generated RunCoverPRk.lean.",
    "",
    "* **`rx_productionReadyL_r13P_exec_own`**.",
    "",
    "Only `propext`, `Classical.choice`, `Quot.sound`.",
    "-/",
    "import ZK60Formal.RunCoverPRk",
    "import ZK60Formal.RunExtractParts",
    "",
    "set_option autoImplicit false",
    "set_option linter.constructorNameAsVariable false",
    "",
    "namespace ZK60.ProtocolClassify.RunShapeP",
    "",
]
ns = text.index("namespace ZK60.ProtocolClassify.RunShapeP")
ns_end = text.index("\n", ns) + 1
hdr_lines = text[ns_end:text.index("\nsection RkTop", ns_end)].strip("\n").split("\n")
pre2 = pre.replace("section RkTop", "section OwnTop").rstrip("\n")
pre2 = pre2.replace("open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)",
                    "open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec incHeadDraws IncCtx)")
out_l += hdr_lines + ["", pre2, "", doc, thm.rstrip("\n")] + body
out_l += ["", "end OwnTop", "", "end ZK60.ProtocolClassify.RunShapeP", ""]
open(out, "w", encoding="utf-8").write("\n".join(out_l))
print(f"wrote {out}: blk replaced {nblk} times, EvXR rewritten {nevx} times")
