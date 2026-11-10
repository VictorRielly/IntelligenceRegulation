#!/usr/bin/env python3
"""D63 lane L54 (2026-11-10): generate formal/ZK60Formal/RunWireTop.lean, the app's top theorem with the block slots'
alive premise `hsl_blk` replaced by the slot polynomials' interface at the run's data, from lane L52's
`eb_productionReadyL_epP_codeT` (RunEpBTopT.lean), so that every discharge of lanes L50 and L52 is kept. Changes, each
asserted to apply exactly once:
  * the name -> `wr_productionReadyL_epP_codeT`, the section -> `WrCodeTTop`;
  * the binder `hsl_blk` (lane L50's `RaTermAt` at the 26 blocks) is REMOVED and PROVED in the proof: lane L16's
    `blockSlots_terminal` at every reading of block `k` (`wr_term`) with the claims' and functionals' truth from the
    run-level `hsem` (`wr_hsem_acc`, PROVED on an accepted run outside the extraction events, from the ordered cover's
    own hypotheses `¬ rtKB.Dm`, `¬ rtKM.Dm`, `¬ rtKA.Dm`);
  * two premises take its place: `hdefS` (each block's `define` is a slot program's `defineS`, so its words are
    canonical: `defineS_polyC`) and `hsl_ev` (each block's
    slot polynomial `Fsl k` meets lane L16's `SlotEval` over the run's extracted data `wrCs`, `wrMs` at every reading);
  * the proof: `eb_productionReadyL_epP_codeT` with every binder passed by name and `hsl_blk` the proved one.
usage: python3 l54_mk_top.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
src = open(L + "RunEpBTopT.lean").read()
i = src.index("section EbCodeTTop\n")
j = src.index("end EbCodeTTop\n", i) + len("end EbCodeTTop\n")
sec = src[i:j]


def once(text, old, new):
    n = text.count(old)
    assert n == 1, (old[:90], n)
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


doc0 = sec.index("/-- **THE APP'S TOP THEOREM UNDER REPAIR B")
head = sec[:doc0]
th0 = sec.index("theorem eb_productionReadyL_epP_codeT ")
end_tok = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="
th1 = sec.index(end_tok, th0) + len(end_tok)
stmt0 = sec[th0:th1]
binders = top_binders(stmt0)
explicit0 = [n for (k, ns, _, _) in binders if k == "(" for n in ns]
assert "hsl_blk" in explicit0 and "hDe" in explicit0 and "hopX1" in explicit0, explicit0
assert explicit0.count("hsl_blk") == 1
(_, _, b0, b1) = [b for b in binders if b[1] == ["hsl_blk"]][0]
grp = stmt0[b0:b1]
assert grp.startswith("(hsl_blk : ") and grp.endswith(")")
ty = grp[len("(hsl_blk : "):-1]
# the quantifier, the acceptance and the events, up to the ordered cover's hypotheses
cut = ty.index("¬ (rtKB ")
pre = ty[:cut]
assert pre.count("verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →") == 1, pre
assert pre.count("ebEvIn") == 1, pre

PS = ("(rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)\n"
      "            (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA\n"
      "              (bp k).nH)\n"
      "            (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))")
TAU = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
NEW = ("(hdefS : ∀ k, k < Lb → ∃ (prog : List Exec.Block.SlotS) (pubs : Exec.Block.PubTabs),\n"
       "      (Pk k).define = Exec.Block.defineS prog pubs)\n"
       "    (hsl_ev : " + pre +
       "∀ k, k < Lb → ∀ (hdr : List Op) (core : Exec.Block.Core) (bga : Fp2 × Fp2 × Fp2)\n"
       "        (rs : List Exec.Block.SlotRec) (acc : Exec.Block.Acc) (T' : List Op),\n"
       "        Exec.Block.SlotsAcc key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G (hdr, core) bga rs acc →\n"
       "        " + TAU + "\n"
       "          = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Exec.Block.allOps (Pk k) (hdr, core) ++ T') →\n"
       "        Exec.Block.SlotEval U (Pk k)\n"
       "          (ZK60.ProtocolClassify.wrCs U D (RtRun.pf Rn) (k + 1) (A.runLog G).2 " + TAU + ")\n"
       "          (ZK60.ProtocolClassify.wrMs U tag Lq h64 key domain hs hL\n"
       "            " + PS + "\n"
       "            (RtRun.pf Rn) (k + 1) (A.runLog G).2 " + TAU + ")\n"
       "          (fun j sn pt => Fsl k (Exec.Block.cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2\n"
       "            (Exec.Block.rootsOf core)) (Exec.Block.rootsOf core) j sn pt))")
stmt1 = stmt0[:b0] + NEW + stmt0[b1:]
stmt1 = once(stmt1, "theorem eb_productionReadyL_epP_codeT ", "theorem wr_productionReadyL_epP_codeT ")

args = []
for n in explicit0:
    args.append("(%s := %s)" % (n, n))
sec_args = ["(Rr := Rr)", "(dR := dR)", "(hpos := hpos)", "(place := place)", "(msg := msg)", "(msg_place := msg_place)",
            "(pad := pad)", "(salt := salt)", "(path := path)", "(tagc := tagc)"]
allargs = sec_args + args
lines = []
cur = "   "
for a in allargs:
    if len(cur) + 1 + len(a) > 118:
        lines.append(cur)
        cur = "   "
    cur += " " + a
lines.append(cur)

PROOF = (
    "\n  by\n"
    "  have hsl_blk : " + ty + " := by\n"
    "    intro A G hacc hx _ hM hA k hk\n"
    "    have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN\n"
    "      bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "    rw [OC.runLog_fst] at hE0\n"
    "    have hev := hsl_ev A G hacc hx k hk\n"
    "    subst hDe\n"
    "    exact ZK60.ProtocolClassify.wr_term U hU key domain (Pk k) _ _ (Fsl k) G (A.runLog G).2 _ _ _\n"
    "      (fun j hj => ((bp k).hgeomL j hj).1)\n"
    "      (by obtain ⟨prog, pubs, hd⟩ := hdefS k hk; exact Exec.Block.defineS_polyC (Pk k) prog pubs hd)\n"
    "      (fun hdr core bga rs acc T' hsa htr => ZK60.ProtocolClassify.wr_hsem_acc U hbij tag h64 hs hL hL64 Lb preA preB\n"
    "        start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout Iin Oout\n"
    "        bp wXk gXk mXk hσ hLb hgeo ogStage ogStage_ok le_rfl hIA hIH hOA hOH hBA hBH htI htO htB hfIA hfIH hfOA hfOH\n"
    "        hfBA hfBH hfIM hfOM hfBM Win Wout lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn hkIn hkOut base abRdIn eL hD\n"
    "        (Rp.blks.length + 2) (le_of_eq ((RtRun.parts_length Rn).trans (congrArg (fun n => n + 2) O.blocks.2)))\n"
    "        A G hE0 (hW A G hacc).1 (hW A G hacc).2 (fun h => hx (Or.inl h)) (hopX1 A G hacc hx) hA hM k hk hdr core bga rs\n"
    "        acc T' hsa htr)\n"
    "      hev\n"
    "  exact eb_productionReadyL_epP_codeT\n" + "\n".join(lines) + "\n")

DOC = (
    "/-- **THE APP'S TOP THEOREM WITH THE BLOCK SLOTS' ALIVE PREMISE WIRED TO THE RUN** (D63 lane L54; lane L52's\n"
    "`eb_productionReadyL_epP_codeT`). The premise `hsl_blk` (lane L50: every block slot's terminal identity at the\n"
    "block's reading of the run) is PROVED: lane L16's `blockSlots_terminal` (`wr_term`) with the accumulator's claims\n"
    "and functionals TRUE of the run's extracted data by the run-level `hsem` (`wr_hsem_acc`: no doomed `opA`, `M`\n"
    "entrant on an accepted run outside the extraction events). What remains of it: `hsl_ev` (each block's slot\n"
    "polynomial `Fsl k` is the masked slot polynomial over the run's extracted data, lane L16's `SlotEval` over `wrCs`,\n"
    "`wrMs`) and `hdefS` (each block's `define` is a slot program's `defineS`). Generated by\n"
    "`results/zk60_lean_l54_20261110/l54_mk_top.py`.\n"
    "-/\n")

head1 = once(head, "section EbCodeTTop\n", "section WrCodeTTop\n")
body = head1 + DOC + stmt1 + PROOF + "\nend WrCodeTTop\n"

pre_src = src[:i]
pre_src = once(pre_src, "import ZK60Formal.RunEpBTop\nimport ZK60Formal.RunEpBTest\n",
               "import ZK60Formal.RunEpBTopT\nimport ZK60Formal.RunWireTerm\n")
top = pre_src.index("/-")
top_end = pre_src.index("-/", top) + 2
FILEDOC = (
    "/-\n"
    "D63 lane L54 (2026-11-10), part 3: **the app's top theorem with the block slots' alive premise `hsl_blk` wired to\n"
    "the run** (the brief's deliverable 4). GENERATED by `results/zk60_lean_l54_20261110/l54_mk_top.py` from lane L52's\n"
    "`eb_productionReadyL_epP_codeT` (RunEpBTopT.lean), so every discharge of lanes L50 and L52 is kept.\n"
    "\n"
    "* **`wr_productionReadyL_epP_codeT`**: `eb_productionReadyL_epP_codeT` with `hsl_blk` PROVED (`wr_term` with\n"
    "  `wr_hsem_acc`); two premises in its place: `hsl_ev` (the slot polynomials' interface over the run's data) and\n"
    "  `hdefS` (each block's `define` is a slot program's `defineS`).\n"
    "\n"
    "Only `propext`, `Classical.choice`, `Quot.sound`.\n"
    "-/")
pre_src = pre_src[:top] + FILEDOC + pre_src[top_end:]
end_src = src[j:]
out = pre_src + body + end_src
open(L + "RunWireTop.lean", "w").write(out)
print("RunWireTop.lean: %d lines, %d explicit binders in, %d out" % (
    out.count("\n"), len(explicit0), len([n for (k, ns, _, _) in top_binders(stmt1) if k == "(" for n in ns])))
