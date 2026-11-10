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


# ---- the last theorem again, with L46's block cover carried in (finding: L45 §5, "restating with L46's hdblk")
stage_sec = between(body, "section EpTop\n", "end EpTop\n")
t0 = stage_sec.index("theorem og_productionReadyL_epP_exec_stage")
t1 = stage_sec.index("\n  by\n", t0)
stmt = stage_sec[t0:t1]
head = stage_sec[:stage_sec.rindex("/--", 0, t0)].replace("section EpTop\n", "section EpBlkTop\n", 1)
h0 = stmt.index("    (hdblk : ")
h1 = stmt.index("    (hdout : ")
old_hdblk = stmt[h0:h1]
hl = old_hdblk.split("\n")
assert hl[1].endswith(" →") and hl[3].endswith(" →"), hl[:4]
VERIFY = hl[1].strip()[:-2]
EVX = hl[2].strip() + "\n        " + hl[3].strip()[:-2]
new_hblk = (
    "    (hblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length),\n"
    "      " + VERIFY + " →\n"
    "      " + EVX + " →\n"
    "      Nonempty (ZK60.ProtocolClassify.RdBlkR13 U D k (A.runLog G).2\n"
    "        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))\n"
    "        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.Exec.Block.card_K_gt K) Rp.blks[k].pub\n"
    "        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)\n"
    "        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1))))\n")
stmt_blk = (stmt[:h0] + new_hblk + stmt[h1:]).replace("theorem og_productionReadyL_epP_exec_stage",
                                                        "theorem og_productionReadyL_epP_exec_blk", 1)


def top_binders(s):
    """The names bound by the top-level `( … : … )` groups of a statement (implicit and instance groups skipped)."""
    names, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c in "([{":
            depth, j = 0, i
            while True:
                if s[j] in "([{":
                    depth += 1
                elif s[j] in ")]}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            grp = s[i + 1:j]
            if c == "(" and " : " in grp:
                names += grp.split(" : ", 1)[0].split()
            i = j + 1
        else:
            i += 1
    return names


sig = stmt[stmt.index(" ", len("theorem ")):stmt.rindex(":\n    ProductionReadyL")]
names = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path", "tagc"] + \
    [x for x in top_binders(sig) if x != "hdblk"]
assert len(set(names)) == len(names), [x for x in names if names.count(x) > 1]
lines_, cur = [], "    "
for piece in ("(%s := %s)" % (x, x) for x in names):
    if len(cur) + len(piece) + 1 > 116:
        lines_.append(cur.rstrip())
        cur = "    "
    cur += piece + " "
lines_.append(cur.rstrip())
proof_blk = (
    "\n  by\n"
    "  exact og_productionReadyL_epP_exec_stage\n"
    + "\n".join(lines_) + "\n"
    "    (hdblk := fun A G k hk hv' hx' => ZK60.ProtocolClassify.rd_hdblk key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn)\n"
    "      hL64 hv U hbij D hD Rp ((RtRun.parts_length Rn).trans (congrArg (fun n => n + 2) O.blocks.2))\n"
    "      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.Exec.Block.card_K_gt K)\n"
    "      (fun A G => " + VERIFY + "\n"
    "        ∧ " + EVX + ")\n"
    "      (fun A G => (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes)\n"
    "      (fun A G k hk hacc => hblk A G k hk hacc.1 hacc.2) A G k hk ⟨hv', hx'⟩)\n")
doc_blk = '''/-- **THE APP'S TOP THEOREM AT THE REAL WIDTHS, WITH THE BLOCK COVER DISCHARGED TO THE BLOCKS' BUNDLES** (D63 lane L48,
carrying lane L46's `rd_hdblk`). `og_productionReadyL_epP_exec_stage` (the stages at `2^12`, the blocks at `2^14`, the
input commitment at `2^8` / rate `1/8` / radius `768`, the run's own Merkle work, the kinds data's readers) with its
premise `hdblk` replaced by `hblk`: on every accepted outcome outside the run's extraction failure, every block `k` has
its R13 bundle `RdBlkR13` (L46) at its own shape, on the run's planes `k`, `k + 1`. Generated. -/
'''
blk_section = head + doc_blk + stmt_blk + proof_blk + "\nend EpBlkTop\n"
assert blk_section.count("(hdblk : ∀") == 0 and blk_section.count("(hblk :") == 1
body = body + "\n" + blk_section

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
* **`og_productionReadyL_epP_exec_stage`**: THE APP'S TOP THEOREM at the real widths;
* **`og_productionReadyL_epP_exec_blk`**: the same with lane L46's block cover carried in (`hdblk` replaced by the
  blocks' bundles `RdBlkR13`, `rd_hdblk`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoTop
import ZK60Formal.ProtocolClassifyEP
import ZK60Formal.RunDoomBlk

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
