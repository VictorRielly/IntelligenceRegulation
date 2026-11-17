#!/usr/bin/env python3
"""D63 lane L63 (2026-11-16): generate formal/ZK60Formal/RunStgShieldTop.lean from L61's
`bw_productionReadyL_epP_shield` (formal/ZK60Formal/RunBlkWireTop.lean).

The restated theorem `ssh_productionReadyL_epP_def`:
  * instantiates the free define polynomials `ΦI`, `ΦO` at the real ones (`sshΦI`, `sshΦO`);
  * removes the premises `hDI_stg`, `hDO_stg` (PROVED: `ssh_hDI`, `ssh_hDO`);
  * adds the set-up premises `hN64I`, `hN64O` (every stage slot has fewer than 64 variables, the code's `1 << n`),
    `hIOlI`, `hIOlO` (the IO semantics `csIOI`, `csIOO` read the view below the stage's head) and the run-level premise
    `hHostO` (`M`'s host functionals true at stage OUT-C, the part of `M`'s check `hTrO` leaves out).
Every other binder is copied verbatim. Usage: l63_mk_top.py <worktree root> [--check]
"""
import re
import sys

WT = sys.argv[1]
SRC = WT + "/formal/ZK60Formal/RunBlkWireTop.lean"
DST = WT + "/formal/ZK60Formal/RunStgShieldTop.lean"

src = open(SRC).read()
start = src.index("theorem bw_productionReadyL_epP_shield")
end_ = src.index(":=\n  by\n", start)
stmt = src[start + len("theorem bw_productionReadyL_epP_shield"):end_]

# split the statement into top-level binders and the conclusion
binders = []
i = 0
n = len(stmt)
concl = None
while i < n:
    c = stmt[i]
    if c in "([{":
        depth = 0
        j = i
        while True:
            if stmt[j] in "([{":
                depth += 1
            elif stmt[j] in ")]}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        binders.append(stmt[i:j + 1])
        i = j + 1
    elif c == ":":
        concl = stmt[i + 1:]
        break
    else:
        i += 1
assert concl is not None


def names(b):
    if b[0] == "[":
        return []
    inner = b[1:-1]
    k = inner.index(":")
    return inner[:k].split()


DROP = {"ΦI", "ΦO", "hDI_stg", "hDO_stg"}
PHI_I = ("(ZK60.ProtocolClassify.sshΦI U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5)"
         " mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI)")
PHI_O = ("(ZK60.ProtocolClassify.sshΦO U hbij tag h64 P0out F ((RtRun.pf Rn).off (Lb + 1) + pout.pre)"
         " ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows csIOO)")


def subst(t):
    t = re.sub(r"(?<![\w.'])ΦI(?![\w'])", PHI_I, t)
    t = re.sub(r"(?<![\w.'])ΦO(?![\w'])", PHI_O, t)
    return t


NEW_AFTER_HNOUT = [
    "(hN64I : ∀ k, k < P0in.geom.slots.length → stgN P0in k < 64)",
    "(hN64O : ∀ k, k < P0out.geom.slots.length → stgN P0out k < 64)",
    "(hIOlI : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off 0 + 5 + (7 + mIn)) csIOI)",
    "(hIOlO : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off (Lb + 1) + 2 + (7 + 2)) csIOO)",
]

out_binders = []
all_names = []
for b in binders:
    nm = names(b)
    all_names.extend(nm)
    if set(nm) & DROP:
        assert set(nm) <= DROP, b[:80]
        continue
    out_binders.append(subst(b))
    if nm == ["hNout"]:
        out_binders.extend(NEW_AFTER_HNOUT)
    if nm == ["hTrO"]:
        k = b.index("ZK60.ProtocolClassify.StgTrueAt")
        host = b[:k].replace("(hTrO :", "(hHostO :", 1) + (
            "ZK60.ProtocolClassify.StgHostTrueAt U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2"
            " ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))"
            " (ZK60.ProtocolClassify.stgMsv U tag h64 pout.S ((RtRun.pf Rn).off (Lb + 1) + 2 + 3)) G (A.runLog G).2\n"
            "        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))")
        out_binders.append(host)
for d in DROP:
    assert d in all_names, d
assert "hNout" in all_names and "hTrO" in all_names

# the call: every original binder by name (section variables too), the four instantiated ones by their terms
SECTION = ["Rr", "dR", "hpos", "place", "hplace", "tag"]
args = []
for nm in SECTION + all_names:
    if nm in DROP:
        continue
    args.append("(%s := %s)" % (nm, nm))
args.append("(ΦI := %s)" % PHI_I)
args.append("(ΦO := %s)" % PHI_O)
HDI = ("(hDI_stg := fun A G h1 h2 h3 h4 h5 h6 => ZK60.ProtocolClassify.ssh_hDI (key := key) (domain := domain) (hs := hs)"
       " (Lq := Lq) (hL := hL) (pf := RtRun.pf Rn) (rd := RtRun.rd Rn) (hL64 := hL64) (hv := hv) (U := U) (hbij := hbij)"
       " (D := D) (hD := hD) (tag := tag) (h64 := h64) (hU := hU) (n := Rp.blks.length + 2)"
       " (hi := by rw [RtRun.parts_length]; omega) (hin := by omega)"
       " (Pof := fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch))"
       " (P0 := P0in) (Vi := Vi) (n0 := (RtRun.pf Rn).off 0 + pin.pre) (hdrLen := (RtRun.pf Rn).off 0 + 5) (m := mIn)"
       " (lc := ogStage.lc) (h := ogStage.h) (Q := ogStage.Q) (e := ogStage.e) (rA := Iin.pA.rows) (rH := Iin.pH.rows)"
       " (S := pin.S) (csIO := csIOI) (hP := fun _ => hPin _ _) (hgt := fun _ => Iin.hgt _)"
       " (hd := fun _ k hk => (Iin.hgeomL _ _ k hk).1) (hhost := fun _ => ZK60.ProtocolClassify.stg_hhIn inc _ _)"
       " (hN := hNin) (hN64 := hN64I) (hIOl := hIOlI) (G := G) (lg := (A.runLog G).2)"
       " (τ := rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
       " (hS := (ZK60.ProtocolClassify.eb_stg_D_lists U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn) base Lb _ _ _ _ _"
       " eL D hDe _ _ _ _ _ _ hb0 hbL).1.1) (hns := h6) (htrue := hTrI A G h1 h2 h3 h4 h5))")
HDO = ("(hDO_stg := fun A G h1 h2 h3 h4 h5 h6 => ZK60.ProtocolClassify.ssh_hDO (key := key) (domain := domain) (hs := hs)"
       " (Lq := Lq) (hL := hL) (pf := RtRun.pf Rn) (rd := RtRun.rd Rn) (hL64 := hL64) (hv := hv) (U := U) (hbij := hbij)"
       " (D := D) (hD := hD) (tag := tag) (h64 := h64) (hU := hU) (n := Rp.blks.length + 2) (i := Lb + 1)"
       " (hi := by rw [show (RtRun.pf Rn).parts.length = Lb + 2 from RtRun.parts_length Rn]; omega)"
       " (hin := by rw [show Lb = Rp.blks.length from O.blocks.2]; omega)"
       " (Pof := fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp)"
       " (P0 := P0out) (F := F) (n0 := (RtRun.pf Rn).off (Lb + 1) + pout.pre) (hdrLen := (RtRun.pf Rn).off (Lb + 1) + 2)"
       " (lc := ogStage.lc) (h := ogStage.h) (Q := ogStage.Q) (e := ogStage.e) (rA := Oout.pA.rows) (rH := Oout.pH.rows)"
       " (S := pout.S) (csIO := csIOO) (hP := fun _ => hPout _ _) (hgt := fun _ => Oout.hgt _ _)"
       " (hd := fun _ k hk => (Oout.hgeomL _ _ k hk).1)"
       " (hhost := fun _ => ZK60.ProtocolClassify.stg_hhOut outc P0out hPout _ _)"
       " (hN := hNout) (hN64 := hN64O) (hIOl := hIOlO) (G := G) (lg := (A.runLog G).2)"
       " (τ := rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
       " (hS := (ZK60.ProtocolClassify.eb_stg_D_lists U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn) base Lb _ _ _ _ _"
       " eL D hDe _ _ _ _ _ _ hb0 hbL).2.1) (hns := h6) (htrue := hTrO A G h1 h2 h3 h4 h5)"
       " (hhf := hHostO A G h1 h2 h3 h4 h5))")
args.append(HDI)
args.append(HDO)

header_end = src.index("/-- **THE APP'S TOP THEOREM WITH CONCRETE BLOCK SLOT POLYNOMIALS")
header = src[:header_end]
header = header.replace(
    "/-\nD63 lane L61 (2026-11-13), part 4: **the adversary-free block-wired top theorems**\n"
    "(`bw_productionReadyL_epP_wire` and `bw_productionReadyL_epP_shield`).\n\n"
    "Generated by `results/zk60_lean_l61_20261113/l61_mk_wire.py`.",
    "/-\nD63 lane L63 (2026-11-16), part 4: **the app's top theorem with the stages' define polynomials set to the real\n"
    "ones and `hDI_stg`, `hDO_stg` PROVED** (`ssh_productionReadyL_epP_def`).\n\n"
    "Generated by `results/zk60_lean_l63_20261116/l63_mk_top.py` from L61's `bw_productionReadyL_epP_shield`.")
assert "D63 lane L63" in header
header = header.replace("import ZK60Formal.RunStgJoinTop\nimport ZK60Formal.RunBlkWireLk\nimport ZK60Formal.RunBlkWireDoom\n"
                        "import ZK60Formal.RunBlkWireSlots\n",
                        "import ZK60Formal.RunBlkWireTop\nimport ZK60Formal.RunStgShieldInst\n")
assert "RunStgShieldInst" in header
header = header.replace("section BwWireTop", "section SshTop")

doc = ("/-- **THE APP'S TOP THEOREM WITH THE STAGES' DEFINE POLYNOMIALS SET TO THE REAL ONES** (D63 lane L63):\n"
       "`bw_productionReadyL_epP_shield` at `ΦI := sshΦI …`, `ΦO := sshΦO …` (the slots' unmasked residuals over the\n"
       "extracted data), with `hDI_stg` and `hDO_stg` PROVED (`ssh_hDI`, `ssh_hDO`: from `¬ rtKsl.Dm`, `hTrI`, `hTrO`, the\n"
       "new `hHostO`). New set-up premises: `hN64I`, `hN64O`, `hIOlI`, `hIOlO`. -/\n")
body = "theorem ssh_productionReadyL_epP_def" + "\n    " + "\n    ".join(out_binders) + " :" + subst(concl) + ":=\n  by\n"
body += "  exact bw_productionReadyL_epP_shield " + "\n    ".join(
    [" ".join(args[i:i + 6]) for i in range(0, len(args), 6)]) + "\n\nend SshTop\n\nend ZK60.ProtocolClassify.RunShapeP\n"
text = header + doc + body
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    cur = open(DST).read()
    print("identical" if cur == text else "DIFFERS")
    sys.exit(0 if cur == text else 1)
open(DST, "w").write(text)
print("wrote", DST, len(out_binders), "binders;", "dropped", sorted(DROP))
