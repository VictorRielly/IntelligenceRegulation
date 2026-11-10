#!/usr/bin/env python3
"""D63 lane L48 (2026-11-10): generate formal/ZK60Formal/RunOpenGeoEP.lean, the app's top theorem with the classifier's
input commitment at its REAL geometry (finding L45-2, decision D77a): the token-words commitment `epTokenCommit`
(`2^8` columns, rate `1/8`, `N = 2^11`, depth `11`) at the largest radius `e = 768`, the endpoint's column test `T` at
`2^11` symbols over the endpoint code (`epPts`, `rowFormK8`), on top of the stages' openings at `ogStage`
(RunOpenGeoTop.lean). The blocks keep the block geometry `2^14` (their openings, EvXR's `256 256 256 16 16 12`).

It copies, in order, the chain of lemmas the app's top theorem is proved through, from the R13 gate up:
  RunCoverPSomeL.lean  sections rc_productionReadyL_run_r13P_some_range … rc_productionReadyL_r13P_exec_some_range
                       (the R13 gate at classifyProtocolUP, its token-endpoint form, the P-range forms, the exec forms),
  RunCoverPRk.lean     section RkTop (L43's kinds-data form),
  RunOpenGeoTop.lean   section OgTop (L45's own-Merkle-work form, with the stages at ogStage: L48 part 6),
and substitutes (each count checked):
  * the eight theorem names -> `og_…_ep…` (declarations and uses);
  * `R13.r13TokenCommit` -> `epTokenCommit`; the plane's `Fin (2 ^ 14)` -> `Fin (2 ^ 8)`; the commitment's
    `Fin (2 ^ 16)` (salts, paths, the test's matrix and openable set, the extractor's openings) -> `Fin (2 ^ 11)`;
  * the test `XTest … (Fin (2 ^ 14 + 256)) Cl 16` / `XTest F κ μ Cl 16` -> `… (Fin (2 ^ 8 + 256)) Cl 11` / `… Cl 11`;
  * the test's code `R13.r13Pts`, `R13.r13Form`, `rowFormK14 F`, `rowFormK14_ext_r13 F` -> `epPts`, `epForm`,
    `rowFormK8 F`, `rowFormK8_ext_ep F`;
  * the radius `24448` -> `768`, its fact `2 * 768 + (2 ^ 14 + 256) ≤ 2 ^ 16` -> `2 * 768 + (2 ^ 8 + 256) ≤ 2 ^ 11`,
    `2 ^ 16 ≤ 2 ^ 20` -> `2 ^ 11 ≤ 2 ^ 20`;
  * the test's round bounds `T.εA_r13` -> `T.εA_ep110` (`2^-115 ≤ 2^-110`: the kind's constant `2^16` is kept),
    `T.εB_r13` -> `T.εB_ep` (`2^-173 ≤ 2^-126`).
Nothing else changes; the result is checked to contain none of the R13 endpoint's names or numbers.

usage: python3 l48_mk_ep.py <WT>
"""
import re
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"


def between(text, start, end):
    i = text.index(start)
    j = text.index(end, i) + len(end)
    return text[i:j]


some = open(L + "RunCoverPSomeL.lean").read()
rk = open(L + "RunCoverPRk.lean").read()
top = open(L + "RunOpenGeoTop.lean").read()
body = (between(some, "section rc_productionReadyL_run_r13P_some_range\n",
                "end rc_productionReadyL_r13P_exec_some_range\n")
        + "\n" + between(rk, "section RkTop\n", "end RkTop\n")
        + "\n" + between(top, "section OgTop\n", "end OgTop\n"))

NAMES = [
    ("rc_productionReadyL_run_r13P_some_range", "og_productionReadyL_run_epP_some_range"),
    ("rc_productionReadyL_run_r13_tokenP_some_range", "og_productionReadyL_run_ep_tokenP_some_range"),
    ("rc_productionReadyL_r13P_some_range", "og_productionReadyL_epP_some_range"),
    ("rc_productionReadyL_r13P_top_range", "og_productionReadyL_epP_top_range"),
    ("rc_productionReadyL_r13P_exec_some_range", "og_productionReadyL_epP_exec_some_range"),
    ("rc_productionReadyL_r13P_exec_top_range", "og_productionReadyL_epP_exec_top_range"),
    ("rc_productionReadyL_r13P_exec_rk", "og_productionReadyL_epP_exec_rk"),
    ("og_productionReadyL_r13P_exec_stage", "og_productionReadyL_epP_exec_stage"),
]
for old, new in NAMES:
    body, n = re.subn(r"(?<![A-Za-z0-9_.'])" + re.escape(old) + r"(?![A-Za-z0-9_'])", new, body)
    assert n >= 1, (old, n)
body = body.replace("section RkTop\n", "section EpRkTop\n").replace("end RkTop\n", "end EpRkTop\n")
body = body.replace("section OgTop\n", "section EpTop\n").replace("end OgTop\n", "end EpTop\n")

SUBS = [
    ("R13.r13TokenCommit", "epTokenCommit"),
    ("Fin dR × Fin (2 ^ 14)", "Fin dR × Fin (2 ^ 8)"),
    ("Fin Rr → Fin (2 ^ 14) → GF", "Fin Rr → Fin (2 ^ 8) → GF"),
    ("Fin (2 ^ 16)", "Fin (2 ^ 11)"),
    ("(Fin (2 ^ 14 + 256)) Cl 16", "(Fin (2 ^ 8 + 256)) Cl 11"),
    ("XTest F κ μ Cl 16", "XTest F κ μ Cl 11"),
    ("R13.r13Pts", "epPts"),
    ("R13.r13Form", "epForm"),
    ("rowFormK14_ext_r13 F", "rowFormK8_ext_ep F"),
    ("rowFormK14 F", "rowFormK8 F"),
    ("24448", "768"),
    ("2 * 768 + (2 ^ 14 + 256) ≤ 2 ^ 16", "2 * 768 + (2 ^ 8 + 256) ≤ 2 ^ 11"),
    ("2 ^ 16 ≤ 2 ^ 20", "2 ^ 11 ≤ 2 ^ 20"),
    ("T.εA_r13", "T.εA_ep110"),
    ("T.εB_r13", "T.εB_ep"),
]
counts = {}
for old, new in SUBS:
    counts[old] = body.count(old)
    assert counts[old] > 0, old
    body = body.replace(old, new)
for bad in ["R13.", "r13Pts", "r13Form", "rowFormK14", "Cl 16", "24448", "Fin (2 ^ 16)", "Fin (2 ^ 14)",
            "εA_r13", "εB_r13", "r13TokenCommit"]:
    assert bad not in body, bad

header = '''/-
D63 lane L48 (2026-11-10), part 9: **the app's top theorem at the REAL widths** (finding L45-2, decision D77a):
the two stages' openings at the tier's stage geometry (`2^12`, rate `1/4`: part 6), the blocks at the block geometry
(`2^14`), and the classifier's INPUT COMMITMENT at its real geometry (`epTokenCommit`: `2^8` columns, rate `1/8`,
`N = 2,048`, depth `11`) at the largest unique-decoding radius `e = 768` (Victor's D77 (1), at the commitment the code
builds), its column test `T` at `2^11` symbols over the endpoint code (`epPts`, `rowFormK8`).
GENERATED by `results/zk60_lean_l48_20261110/l48_mk_ep.py` from the chain the app's top theorem is proved through
(`RunCoverPSomeL.lean`'s R13 gate and its P-range and exec forms, `RunCoverPRk.lean`, `RunOpenGeoTop.lean`), with the
R13 endpoint's commitment, numbers and test replaced by the real ones; the proofs are the same steps, with the
endpoint test's round bounds `XTest.εA_ep110` (`2^-115 ≤ 2^-110`) and `XTest.εB_ep` (`2^-173 ≤ 2^-126`), so the
joint budget is the R13 gate's (`eleven_bud_r13`).

* `og_productionReadyL_run_epP_some_range`, `og_productionReadyL_run_ep_tokenP_some_range`,
  `og_productionReadyL_epP_some_range`, `og_productionReadyL_epP_top_range`, `og_productionReadyL_epP_exec_some_range`,
  `og_productionReadyL_epP_exec_top_range`, `og_productionReadyL_epP_exec_rk`;
* **`og_productionReadyL_epP_exec_stage`**: THE APP'S TOP THEOREM at the real widths.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoTop
import ZK60Formal.ProtocolClassifyEP

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify.RunShapeP

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (LeaksAtMost productionReadyL_of_productionReady productionReadyL_of_productionReady_range)

'''
open(L + "RunOpenGeoEP.lean", "w").write(header + body + "\nend ZK60.ProtocolClassify.RunShapeP\n")
print("RunOpenGeoEP.lean written; substitutions:", ", ".join("%s x%d" % (k, v) for k, v in counts.items()))
