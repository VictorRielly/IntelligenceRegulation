#!/usr/bin/env python3
"""D63 lane L43 (2026-11-10): generate formal/ZK60Formal/RunCoverPSomeL.lean, lane L40's PER-BLOCK-SHAPE gate chain in
D76's approved form (RunShapeGateL.lean, finding L40-1: only these gates apply to the app) restated as lane L39
restated the single-shape chain (results/zk60_lean_l39_20261110/l39_mk_some_range.py, run here on L40's ...P gates):
the covers `hdin`, `hdblk`, `hdout` in the SOME-PART form (L34-2, GA-7) and, at the two top gates, `halive` split into
nine named premises in `rtKo`'s order (`rc_aliveOrd9`).

  classifyUP_productionReadyL_runChain_range       -> rc_productionReadyL_runChainP_some_range
  classifyUP_productionReadyL_run_r13_range        -> rc_productionReadyL_run_r13P_some_range
  classifyUP_productionReadyL_run_r13_token_range  -> rc_productionReadyL_run_r13_tokenP_some_range
  rt_productionReadyL_r13P_range                   -> rc_productionReadyL_r13P_some_range       (+ _top_range)
  rt_productionReadyL_r13P_exec_range              -> rc_productionReadyL_r13P_exec_some_range  (+ _exec_top_range)

Each section is copied with exactly these changes: the names; the three cover conclusions `∃ c ∈ K'.cs j …` become
`∃ i, i < L + 2 ∧ ∃ c ∈ K'.cs i …` with `L = R.blks.length` (3 per gate, checked); `cover3_of_runParts_ordP` ->
`rc_cover3_someP` (RunCoverPAlive.lean). L39's substitutions with `Ps` replaced by L40's `blks`.

usage: python3 -I l43_mk_someP.py <formal/ZK60Formal dir> <out.lean>
"""
import re
import sys

src, out = sys.argv[1], sys.argv[2]
lines = open(f"{src}/RunShapeGateL.lean", encoding="utf-8").read().split("\n")

RENAME = [
    ("classifyUP_productionReadyL_run_r13_token_range", "rc_productionReadyL_run_r13_tokenP_some_range"),
    ("classifyUP_productionReadyL_run_r13_range", "rc_productionReadyL_run_r13P_some_range"),
    ("classifyUP_productionReadyL_runChain_range", "rc_productionReadyL_runChainP_some_range"),
    ("rt_productionReadyL_r13P_exec_range", "rc_productionReadyL_r13P_exec_some_range"),
    ("rt_productionReadyL_r13P_range", "rc_productionReadyL_r13P_some_range"),
    ("cover3_of_runParts_ordP", "rc_cover3_someP"),
]


def section(name):
    i = lines.index(f"section {name}")
    j = lines.index(f"end {name}")
    return lines[i:j + 1]


def transform(sec, rname):
    s = "\n".join(sec)
    n0 = 0
    for pat in [r"∃ c ∈ K'\.cs 0 \(A\.runLog G\)\.2,", r"∃ c ∈ K'\.cs \(k \+ 1\) \(A\.runLog G\)\.2,",
                rf"∃ c ∈ K'\.cs \({rname}\.blks\.length \+ 1\) \(A\.runLog G\)\.2,"]:
        s, n = re.subn(pat, f"∃ i, i < {rname}.blks.length + 2 ∧ ∃ c ∈ K'.cs i (A.runLog G).2,", s)
        n0 += n
    for a, b in RENAME:
        s = re.sub(rf"\b{a}\b(?![_\w])", b, s)
    s = re.sub(r"/-- \*\*D76 \(range form\)", "/-- **L43 (some-part covers, one shape per block) of the D76 range form", s)
    return s, n0


KINDS = [("rtKB", "hal_opB"), ("rtKM", "hal_M"), ("rtKA", "hal_opA"), ("rtKsl", "hal_slots"), ("rtKR0", "hal_R0"),
         ("rtKR1", "hal_R1"), ("rtKH0", "hal_H0"), ("rtKH1", "hal_H1"), ("rtKLU", "hal_LU")]
KARGS = "key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD"
NLT = "(Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
COMMON = ("P h64 hr hon U hbij key domain hs hL hL64 Rn hv D hD site kOf δOf E O T hTenc hTaA hTaB Ux Xx hUc hXc pr "
          "hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx").split()
SEC = "Rr dR hpos place msg msg_place pad salt path tagc Rp Lq".split()
TAIL = "hdin hdblk hdout mk ops hE hops hcan hwin hread hBal hdzero hzk".split()


def top_split(thm, inner, newname, vnames):
    """The theorem `thm` (text from `theorem`) with `halive` split into nine premises; its proof calls `inner` with
    named arguments."""
    s = thm
    i = s.index("    (halive :")
    j = s.index("    (hdin :")
    hal = s[i:j].rstrip("\n").split("\n")
    head = hal[:3]
    binders = []
    for n, (k, h) in enumerate(KINDS):
        pre = [f"      ¬ ({KINDS[m][0]} {KARGS}).Dm {NLT} →" for m in range(n)]
        hd = [head[0].replace("(halive :", f"({h} :")] + head[1:]
        binders += hd + pre + [f"      ({k} {KARGS}).Al {NLT})"]
    s = s[:i] + "\n".join(binders) + "\n" + s[j:]
    s = re.sub(r"theorem \S+", f"theorem {newname}", s, count=1)
    k = s.index("εcTarget εsTarget εsTarget εzkTarget :=")
    s = s[:k] + "εcTarget εsTarget εsTarget εzkTarget :=\n"
    args = [f"({a} := {a})" for a in SEC + vnames + COMMON]
    args.append("(halive := fun A G hv' hx' => rc_aliveOrd9 _ _ _ _ _ _ _ _ _ _ _ _ "
                + " ".join(f"({h} A G hv' hx')" for _, h in KINDS) + ")")
    args += [f"({a} := {a})" for a in TAIL]
    body = "  " + inner
    line = ""
    out_lines = [body]
    for a in args:
        if len(line) + len(a) + 1 > 110:
            out_lines.append("    " + line.rstrip())
            line = ""
        line += a + " "
    out_lines.append("    " + line.rstrip())
    return s + "\n".join(out_lines)


def theorem_text(sec_text):
    """From a section's text: the part from its last docstring to its `end` line, exclusive."""
    t = sec_text.split("\n")
    d = max(k for k, l in enumerate(t) if l.startswith("/--"))
    return "\n".join(t[d:-1]).rstrip("\n")


out_l = [
    "/-",
    "D63 lane L43 (2026-11-10), part 7b: **lane L40's PER-BLOCK-SHAPE gate chain in D76's APPROVED form (`ProductionReadyL",
    "… (classifyLeakP R) …`, zero knowledge on the range `q, R ≤ 2^64`, RunShapeGateL.lean) with the covers in the",
    "SOME-PART form** (L34-2, GA-7) and, at the two top gates, `halive` split into nine named premises in `rtKo`'s order",
    "(`rc_aliveOrd9`). Finding L40-1: the app's model has 26 distinct block calibrations, so only these gates apply to it.",
    "GENERATED by `results/zk60_lean_l43_20261110/l43_mk_someP.py` from `RunShapeGateL.lean` (lane L39's",
    "`l39_mk_some_range.py` on L40's `…P` gates): each section copied with the names changed, the three cover conclusions",
    "`∃ c ∈ K'.cs j …` replaced by `∃ i, i < R.blks.length + 2 ∧ ∃ c ∈ K'.cs i …` (3 per gate), and",
    "`cover3_of_runParts_ordP` replaced by `rc_cover3_someP` (RunCoverPAlive.lean).",
    "",
    "* `rc_productionReadyL_runChainP_some_range`, `rc_productionReadyL_run_r13P_some_range`,",
    "  `rc_productionReadyL_run_r13_tokenP_some_range`, `rc_productionReadyL_r13P_some_range`;",
    "* **`rc_productionReadyL_r13P_top_range`**: L40's top gate in the approved form, the covers in the some-part form,",
    "  `halive` as nine named premises;",
    "* `rc_productionReadyL_r13P_exec_some_range`, **`rc_productionReadyL_r13P_exec_top_range`**: the same at the",
    "  production instance `classifyProtocolUExecP` (`V := classifyRunV …`): THE APP'S TOP THEOREM in the approved form",
    "  at the per-block-shape model.",
    "",
    "Only `propext`, `Classical.choice`, `Quot.sound`.",
    "-/",
    "import ZK60Formal.RunShapeGateL",
    "import ZK60Formal.RunCoverPAlive",
    "",
    "set_option autoImplicit false",
    "set_option linter.constructorNameAsVariable false",
    "",
    "namespace ZK60.ProtocolClassify.RunShapeP",
    "",
] + lines[lines.index("open scoped ENNReal"):lines.index("section D76Gates")]
total = 0
for name, rname in [("classifyUP_productionReadyL_runChain_range", "R"),
                    ("classifyUP_productionReadyL_run_r13_range", "R"),
                    ("classifyUP_productionReadyL_run_r13_token_range", "R"),
                    ("rt_productionReadyL_r13P_range", "Rp"),
                    ("rt_productionReadyL_r13P_exec_range", "Rp")]:
    s, n = transform(section(name), rname)
    if n != 3:
        sys.exit(f"{name}: {n} cover premises replaced, 3 expected")
    total += n
    if name in ("rt_productionReadyL_r13P_range", "rt_productionReadyL_r13P_exec_range"):
        exec_ = name.endswith("exec_range")
        inner = "rc_productionReadyL_r13P_exec_some_range" if exec_ else "rc_productionReadyL_r13P_some_range"
        newname = "rc_productionReadyL_r13P_exec_top_range" if exec_ else "rc_productionReadyL_r13P_top_range"
        vnames = "Lb preA preB start inc incG blk outc outcG".split() if exec_ else ["V"]
        doc = ("/-- **THE TOP GATE IN D76'S APPROVED FORM AT ONE SHAPE PER BLOCK, EVERY COVER PREMISE NAMED** (D63 lane"
               " L43): `" + inner + "` with `halive`\nsplit into nine premises in `rtKo`'s order (`opB`, `M`, `opA`, the"
               " slots, the relation draws, the helper draws,\nLogUp), each asked only when no earlier kind has a doomed"
               " entrant (`rc_aliveOrd9`). Generated. -/")
        thm = theorem_text(s)
        split = top_split(thm[thm.index("theorem"):], inner, newname, vnames)
        sl = s.split("\n")
        s = "\n".join(sl[:-1]) + "\n\n" + doc + "\n" + split + "\n\n" + sl[-1]
    out_l += s.split("\n") + [""]
out_l += ["end ZK60.ProtocolClassify.RunShapeP", ""]
open(out, "w", encoding="utf-8").write("\n".join(out_l))
print(f"wrote {out}: 5 gates and 2 split tops, {total} cover premises replaced")
