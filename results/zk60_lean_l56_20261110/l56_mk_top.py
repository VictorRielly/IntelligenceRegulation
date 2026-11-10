#!/usr/bin/env python3
"""D63 lane L56 (2026-11-10): generate formal/ZK60Formal/RunBndTop.lean, the app's top theorem with finding L54-1
repaired, from lane L54's `wr_productionReadyL_epP_codeT` (RunWireTop.lean), so that every discharge of lanes L50,
L52 and L54 is kept. Changes, each asserted to apply exactly once:
  * the name -> `bnd_productionReadyL_epP_wire`, the section -> `BndWireTop`;
  * the binder `Fsl`: its type gets the header's roots and cuts `Exec.Block.HdrX Lq` (lane L56's `blockSlotXB`);
  * `hslB`: `blockSchedX` -> `blockSchedXB`;
  * the binder `hsl_ev` is REPLACED by `hsl_evB`: each block's slot polynomial `Fsl k` at the core's roots AND the run's
    header data `hdrX … (off (k + 1) + 5) τ` meets lane L16's `SlotEval` over `wrCsB` (lane L54's `wrCs` with the two
    boundary claims read from the header's roots and cuts at `off k + 2`, `off (k + 1) + 2`) and `wrMs`;
  * finding L56-7: `hR0_blk`, `hR1_blk`, `hH0_blk`, `hH1_blk`: `RaDefAt` -> `RaDefAtB` (lane L56's `defSqB` draws);
  * a new binder `hgXB` (before `hsl_evB`): the closing openings of parts `1 … Lb + 1` read their roots at the code's
    positions `off j + 2` (`(base (j + 1)).gX.ipos`);
  * the proof: `hsl_blk` (`RaTermAtB`) PROVED by `wr_termB` with `wr_hsem_acc` (as lane L54) and `hsl_evB` through
    `wrCs_eq_B`; then lane L56's `bnd_productionReadyL_epP_codeT` with every binder passed by name.
usage: python3 l56_mk_top.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
src = open(L + "RunWireTop.lean").read()
i = src.index("section WrCodeTTop\n")
j = src.index("end WrCodeTTop\n", i) + len("end WrCodeTTop\n")
sec = src[i:j]


def once(text, old, new):
    n = text.count(old)
    assert n == 1, (old[:100], n)
    return text.replace(old, new)


def top_binders(text):
    """The top-level binder groups of a theorem statement: (kind, names, start, end) (lane L50's parser)."""
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


doc0 = sec.index("/-- **THE APP'S TOP THEOREM WITH THE BLOCK SLOTS' ALIVE PREMISE WIRED TO THE RUN**")
head = sec[:doc0]
th0 = sec.index("theorem wr_productionReadyL_epP_codeT ")
end_tok = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="
th1 = sec.index(end_tok, th0) + len(end_tok)
stmt0 = sec[th0:th1]
binders = top_binders(stmt0)
explicit0 = [n for (k, ns, _, _) in binders if k == "(" for n in ns]
assert explicit0.count("hsl_ev") == 1 and "hsl_blk" not in explicit0, explicit0
(_, _, b0, b1) = [b for b in binders if b[1] == ["hsl_ev"]][0]
grp = stmt0[b0:b1]
assert grp.startswith("(hsl_ev : ") and grp.endswith(")")
ty = grp[len("(hsl_ev : "):-1]
cut = ty.index("∀ k, k < Lb → ")
pre = ty[:cut]
assert pre.count("verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →") == 1, pre
assert pre.count("ebEvIn") == 1, pre

TAU = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
ABS = "(Exec.Block.absOfC (chainEncB key domain hs Lq hL))"
HX = "(Exec.Block.hdrX " + ABS + " (A.runLog G).2 ((RtRun.pf Rn).off (k + 1) + 5)\n            " + TAU + ")"
PS = ("(rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)\n"
      "            (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA\n"
      "              (bp k).nH)\n"
      "            (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))")
NEW = ("(hgXB : ∀ j, j ≤ Lb → (base (j + 1)).gX.ipos = (RtRun.pf Rn).off j + 2)\n"
       "    (hsl_evB : " + pre +
       "∀ k, k < Lb → ∀ (hdr : List Op) (core : Exec.Block.Core) (bga : Fp2 × Fp2 × Fp2)\n"
       "        (rs : List Exec.Block.SlotRec) (acc : Exec.Block.Acc) (T' : List Op),\n"
       "        Exec.Block.SlotsAcc key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G (hdr, core) bga rs acc →\n"
       "        " + TAU + "\n"
       "          = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Exec.Block.allOps (Pk k) (hdr, core) ++ T') →\n"
       "        Exec.Block.SlotEval U (Pk k)\n"
       "          (ZK60.ProtocolClassify.wrCsB U tag Lq h64 D (RtRun.pf Rn) k (A.runLog G).2 " + TAU + "\n"
       "            " + HX + ")\n"
       "          (ZK60.ProtocolClassify.wrMs U tag Lq h64 key domain hs hL\n"
       "            " + PS + "\n"
       "            (RtRun.pf Rn) (k + 1) (A.runLog G).2 " + TAU + ")\n"
       "          (fun j sn pt => Fsl k (Exec.Block.cuts3 " + ABS + " (A.runLog G).2\n"
       "            (Exec.Block.rootsOf core)) (Exec.Block.rootsOf core)\n"
       "            " + HX + " j sn pt))")
stmt1 = stmt0[:b0] + NEW + stmt0[b1:]
stmt1 = once(stmt1, "theorem wr_productionReadyL_epP_codeT ", "theorem bnd_productionReadyL_epP_wire ")
stmt1 = once(stmt1, "(Fsl : (k : ℕ) → Exec.Block.Cuts3 Lq → Exec.Block.RootsO → (j : ℕ) → Exec.Block.Seen →",
             "(Fsl : (k : ℕ) → Exec.Block.Cuts3 Lq → Exec.Block.RootsO → Exec.Block.HdrX Lq → (j : ℕ) →\n"
             "      Exec.Block.Seen →")
stmt1 = once(stmt1, "D.sls (k + 1) = Exec.Block.blockSchedX (Pk k)", "D.sls (k + 1) = Exec.Block.blockSchedXB (Pk k)")
# finding L56-7: the four define kinds' block draws in the new form
assert stmt1.count("RaDefAt U key domain (Pk k)") == 4, stmt1.count("RaDefAt U key domain (Pk k)")
stmt1 = stmt1.replace("RaDefAt U key domain (Pk k)", "RaDefAtB U key domain (Pk k)")

# the chain's codeT takes `hsl_blk` where lane L54's theorem took `hsl_ev`, `hdefS` (hdefS is kept as a binder here)
explicit1 = [n for (k, ns, _, _) in top_binders(stmt1) if k == "(" for n in ns]
args = []
for n in explicit0:
    if n == "hsl_ev":
        args.append("(hsl_blk := hsl_blk)")
    elif n == "hdefS":
        continue
    else:
        args.append("(%s := %s)" % (n, n))
sec_args = ["(Rr := Rr)", "(dR := dR)", "(hpos := hpos)", "(place := place)", "(msg := msg)", "(msg_place := msg_place)",
            "(pad := pad)", "(salt := salt)", "(path := path)", "(tagc := tagc)"]
allargs = sec_args + args
lines = []
curl = "   "
for a in allargs:
    if len(curl) + 1 + len(a) > 118:
        lines.append(curl)
        curl = "   "
    curl += " " + a
lines.append(curl)

# the RaTermAtB premise of the chain's codeT, as the chain states it
chain = open(L + "RunBndChain.lean").read()
ci = chain.index("theorem bnd_productionReadyL_epP_codeT ")
cj = chain.index(end_tok, ci) + len(end_tok)
cstmt = chain[ci:cj]
(_, _, c0, c1) = [b for b in top_binders(cstmt) if b[1] == ["hsl_blk"]][0]
cgrp = cstmt[c0:c1]
assert cgrp.startswith("(hsl_blk : ") and "RaTermAtB" in cgrp
bty = cgrp[len("(hsl_blk : "):-1]

PROOF = (
    "\n  by\n"
    "  have hsl_blk : " + bty + " := by\n"
    "    intro A G hacc hx _ hM hA k hk\n"
    "    have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN\n"
    "      bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "    rw [OC.runLog_fst] at hE0\n"
    "    have hev := hsl_evB A G hacc hx k hk\n"
    "    subst hDe\n"
    "    have e := ZK60.ProtocolClassify.wrCs_eq_B U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn) base Lb\n"
    "      (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)\n"
    "      (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)\n"
    "      (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH)\n"
    "      (rxAcc Win Wout Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL (A.runLog G).2\n"
    "      " + TAU + " k hgXB hk\n"
    "    exact ZK60.ProtocolClassify.wr_termB U hU key domain (Pk k) _ _ (Fsl k) G (A.runLog G).2 _ _ _\n"
    "      (fun j hj => ((bp k).hgeomL j hj).1)\n"
    "      (by obtain ⟨prog, pubs, hd⟩ := hdefS k hk; exact Exec.Block.defineS_polyC (Pk k) prog pubs hd)\n"
    "      (fun hdr core bga rs acc T' hsa htr => ZK60.ProtocolClassify.wr_hsem_acc U hbij tag h64 hs hL hL64 Lb preA preB\n"
    "        start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout Iin Oout\n"
    "        bp wXk gXk mXk hσ hLb hgeo ogStage ogStage_ok le_rfl hIA hIH hOA hOH hBA hBH htI htO htB hfIA hfIH hfOA hfOH\n"
    "        hfBA hfBH hfIM hfOM hfBM Win Wout lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn hkIn hkOut base abRdIn eL hD\n"
    "        (Rp.blks.length + 2) (le_of_eq ((RtRun.parts_length Rn).trans (congrArg (fun n => n + 2) O.blocks.2)))\n"
    "        A G hE0 (hW A G hacc).1 (hW A G hacc).2 (fun h => hx (Or.inl h)) (hopX1 A G hacc hx) hA hM k hk hdr core bga rs\n"
    "        acc T' hsa htr)\n"
    "      (fun hdr core bga rs acc T' hsa htr => by\n"
    "        have h2 := hev hdr core bga rs acc T' hsa htr\n"
    "        rw [← e] at h2\n"
    "        exact h2)\n"
    "  exact bnd_productionReadyL_epP_codeT\n" + "\n".join(lines) + "\n")

DOC = (
    "/-- **THE APP'S TOP THEOREM WITH FINDING L54-1 REPAIRED** (D63 lane L56; lane L54's\n"
    "`wr_productionReadyL_epP_codeT`). Every block slot's polynomial `Fsl k` also receives the run's header data before\n"
    "the block's roots (`hdrX`: each root the transcript absorbed and the prover's log cut at it), so the two boundary\n"
    "slots `SC_IO_IN`, `SC_IO_OUT`, which read the boundary commitments absorbed at `off k + 2` and `off (k + 1) + 2`\n"
    "(the code's frames), have polynomials of its type. The kinds data's block slots are `blockSchedXB` (`hslB`); the\n"
    "slots' terminal identity (`RaTermAtB`) is PROVED from the run-level `hsem` (`wr_hsem_acc`) and `hsl_evB` (each\n"
    "`Fsl k` is the masked slot polynomial over the run's data, with the boundary claims read from the header data:\n"
    "`wrCsB`), through `wrCs_eq_B` under `hgXB` (the closing openings read their roots at the code's positions).\n"
    "Generated by `results/zk60_lean_l56_20261110/l56_mk_top.py`.\n"
    "-/\n")

# deliverable 2 (finding L54-2): the same theorem with `hdefS` and `hLb` derived from the run-level tie `hPk`
binders1 = top_binders(stmt1)
(_, _, d0, d1) = [b for b in binders1 if b[1] == ["hdefS"]][0]
assert stmt1[d0:d1].startswith("(hdefS : ")
stmt2 = stmt1[:d0] + ("(hPk : ZK60.Exec.Block.Join.R13H.ShieldRunAt Pk Rp.blks Lb)") + stmt1[d1:]
binders2 = top_binders(stmt2)
(_, _, l0, l1) = [b for b in binders2 if b[1] == ["hLb"]][0]
assert stmt2[l0:l1] == "(hLb : Lb ≤ 26)", stmt2[l0:l1]
stmt2 = stmt2[:l0] + stmt2[l1:].lstrip(" ")
stmt2 = once(stmt2, "theorem bnd_productionReadyL_epP_wire ", "theorem bnd_productionReadyL_epP_shield ")
args2 = []
for n in explicit1:
    if n == "hdefS":
        args2.append("(hdefS := ZK60.Exec.Block.Join.R13H.ShieldRunAt.hdefS hPk)")
    elif n == "hLb":
        args2.append("(hLb := ZK60.Exec.Block.Join.R13H.ShieldRunAt.lb_le hPk)")
    else:
        args2.append("(%s := %s)" % (n, n))
lines2 = []
curl = "   "
for a in sec_args + args2:
    if len(curl) + 1 + len(a) > 118:
        lines2.append(curl)
        curl = "   "
    curl += " " + a
lines2.append(curl)
PROOF2 = "\n  bnd_productionReadyL_epP_wire\n" + "\n".join(lines2) + "\n"
DOC2 = (
    "/-- **THE APP'S TOP THEOREM AT THE SHIELDSTRAL EXPORT** (D63 lane L56, finding L54-2): `bnd_productionReadyL_epP_wire`\n"
    "with block `k`'s verifier tied to layer `k` of `shieldExport` (`hPk`: `ShieldRunAt`, every premise lane L49's\n"
    "block statement asks of its verifier, at the run's block `k`'s calibration and public data). Lane L54's `hdefS` and\n"
    "the block count's bound `hLb` are PROVED from it. Generated by `results/zk60_lean_l56_20261110/l56_mk_top.py`.\n"
    "-/\n")

# the premise `hsl_evB` replaced by a property of the slot polynomials alone (`hsl_args`; lane L56's
# `bnd_hsl_evB_of_args`): no adversary, no transcript, no run in it
binders2b = top_binders(stmt2)
(_, _, e0, e1) = [b for b in binders2b if b[1] == ["hsl_evB"]][0]
DPS = ("(rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)\n"
       "          (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA\n"
       "            (bp k).nH)\n"
       "          (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))")
ARGS = ("(hsl_args : ∀ k, k < Lb → ∀ (c3 : Exec.Block.Cuts3 Lq) (rt : Exec.Block.RootsO) (hx : Exec.Block.HdrX Lq),\n"
        "      Exec.Block.SlotEval U (Pk k)\n"
        "        (ZK60.ProtocolClassify.csArgs U tag Lq h64 (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))\n"
        "          c3 rt hx ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))\n"
        "        (ZK60.ProtocolClassify.msArgs U tag Lq h64 (bp k).S c3 rt) (fun j sn pt => Fsl k c3 rt hx j sn pt))")
stmt3 = stmt2[:e0] + ARGS + stmt2[e1:]
stmt3 = once(stmt3, "theorem bnd_productionReadyL_epP_shield ", "theorem bnd_productionReadyL_epP_args ")
explicit2 = [n for (k, ns, _, _) in top_binders(stmt2) if k == "(" for n in ns]
args3 = []
for n in explicit2:
    if n == "hsl_evB":
        args3.append("(hsl_evB := fun A G _ _ => ZK60.ProtocolClassify.bnd_hsl_evB_of_args U tag h64 hs hL Lb preA preB start inc "
                     "incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn cx0 pin pout bp wXk gXk mXk "
                     "hσ abRdIn base (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn) "
                     "(rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH) "
                     "(fun k => (bp k).S) (fun k => (Pk k).nFunctionals) (fun k => (bp k).pA.rows) (fun k => (bp k).pH.rows) "
                     "(fun k => (bp k).nA) (fun k => (bp k).nH) (rxAcc Win Wout Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) "
                     "eL Fsl hsl_args G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))")
    elif n == "D":
        args3.append("(D := _)")
    elif n == "hDe":
        args3.append("(hDe := rfl)")
    else:
        args3.append("(%s := %s)" % (n, n))
lines3 = []
curl = "   "
for a in sec_args + args3:
    if len(curl) + 1 + len(a) > 118:
        lines3.append(curl)
        curl = "   "
    curl += " " + a
lines3.append(curl)
PROOF3 = "\n  by\n  subst hDe\n  exact bnd_productionReadyL_epP_shield\n" + "\n".join(lines3) + "\n"
DOC3 = (
    "/-- **THE APP'S TOP THEOREM WITH THE SLOT POLYNOMIALS' PREMISE ABOUT THE POLYNOMIALS ALONE** (D63 lane L56):\n"
    "`bnd_productionReadyL_epP_shield` with `hsl_evB` (an adversary, a transcript, a reading) replaced by `hsl_args`: each\n"
    "block's slot polynomial `Fsl k` meets `SlotEval` over `csArgs`, `msArgs` of its own arguments (the cut logs and\n"
    "roots of the block's `A`, `M`, `H` and the header's roots and cuts), at the openings' fixed code parameters.\n"
    "`hsl_evB` is PROVED from it (`bnd_hsl_evB_of_args`): finding L54-1's obstruction is gone, since what is left is a\n"
    "property of a function of exactly the data the slots read. Generated by `results/zk60_lean_l56_20261110/l56_mk_top.py`.\n"
    "-/\n")

head1 = once(head, "section WrCodeTTop\n", "section BndWireTop\n")
body = (head1 + DOC + stmt1 + PROOF + "\n" + DOC2 + stmt2 + PROOF2 + "\n" + DOC3 + stmt3 + PROOF3
        + "\nend BndWireTop\n")

pre_src = src[:i]
pre_src = once(pre_src, "import ZK60Formal.RunEpBTopT\nimport ZK60Formal.RunWireTerm\n",
               "import ZK60Formal.RunBndChain\nimport ZK60Formal.RunBndArgs\nimport ZK60Formal.RunBndShield\n")
top = pre_src.index("/-")
top_end = pre_src.index("-/", top) + 2
FILEDOC = (
    "/-\n"
    "D63 lane L56 (2026-11-10), part 5: **the app's top theorem with finding L54-1 repaired** (the brief's deliverables\n"
    "1 and 4). GENERATED by `results/zk60_lean_l56_20261110/l56_mk_top.py` from lane L54's\n"
    "`wr_productionReadyL_epP_codeT` (RunWireTop.lean), so every discharge of lanes L50, L52 and L54 is kept.\n"
    "\n"
    "* **`bnd_productionReadyL_epP_wire`**: `wr_productionReadyL_epP_codeT` with the block slots' polynomials widened\n"
    "  (`blockSchedXB`), `hsl_ev` replaced by `hsl_evB` (the boundary claims read from the header data the polynomials\n"
    "  receive, `wrCsB`), and the closing openings' root positions `hgXB`; `hsl_blk` PROVED as in lane L54; the four\n"
    "  define kinds' block premises `hR0_blk` … `hH1_blk` in the new draw form `RaDefAtB` (finding L56-7);\n"
    "* **`bnd_productionReadyL_epP_shield`**: the same with block `k`'s verifier tied to layer `k` of `shieldExport`\n"
    "  (`hPk`, finding L54-2); `hdefS` and `hLb` PROVED from it;\n"
    "* **`bnd_productionReadyL_epP_args`**: the same with `hsl_evB` replaced by `hsl_args`, a property of each slot\n"
    "  polynomial `Fsl k` as a function of its own arguments (`hsl_evB` PROVED from it: `bnd_hsl_evB_of_args`).\n"
    "\n"
    "Only `propext`, `Classical.choice`, `Quot.sound`.\n"
    "-/")
pre_src = pre_src[:top] + FILEDOC + pre_src[top_end:]
end_src = src[j:]
out = pre_src + body + end_src
open(L + "RunBndTop.lean", "w").write(out)
print("RunBndTop.lean: %d lines, %d explicit binders in, %d out (wire), %d (shield), %d (args)" % (out.count("\n"), len(explicit0), len(explicit1), len(explicit2), len([n for (k, ns, _, _) in top_binders(stmt3) if k == "(" for n in ns])))
