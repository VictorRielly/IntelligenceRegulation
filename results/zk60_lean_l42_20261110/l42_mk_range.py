#!/usr/bin/env python3
"""D63 lane L42 (2026-11-10): write formal/ZK60Formal/StatementsD76Range.lean.

Every production gate of the classify run asks its zero-knowledge premise `hzk : ∀ q R', εzk q R' ≤ εzkTarget q R'`
for EVERY q and R. Under Victor's ruling D76 (2) the approved zero-knowledge statement asks only q ≤ 2^64 and
R ≤ 2^64, so the gates in the approved form need `hzk` on that range only. In every gate of the chain `hzk` is passed
down unchanged, and used once, at the bottom (`classifyU_productionReady_joint_target`, ProtocolClassifyU.lean), by
`productionReady_mono`. This script copies each gate of the chain (statement AND proof) out of its file and changes
exactly four things:
  1. the name: `…productionReady…` → `…productionReadyL…_range`;
  2. the premise `hzk` → `∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R'`;
  3. the conclusion `ProductionReady M A P εcTarget …` → `ProductionReadyL M A P (classifyLeak S R) εcTarget …`;
  4. in the proof, the gate it calls → that gate's copy; at the bottom, `productionReady_mono` → the bridge
     `productionReadyL_of_productionReady_range (classifyLeak S R) classifyU_leaksAtMost` (D76's range form).
Each copy sits in its own section with its source file's `open` lines and its source section's `variable` lines and
local notation, so that its text means what it meant there.

usage: python3 -I l42_mk_range.py <formal/ZK60Formal dir> [output file, default <dir>/StatementsD76Range.lean]
"""
import re
import sys

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else f"{src}/StatementsD76Range.lean"

HZK = "(hzk : ∀ q R', εzk q R' ≤ εzkTarget q R')"
HZKR = "(hzk : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R')"

# (file, theorem, the gate it calls, or None at the bottom)
CHAIN = [
    ("ProtocolClassifyU", "classifyU_productionReady_joint_target", None),
    ("ProtocolClassifyUEp", "classifyU_productionReady_ep_target", "classifyU_productionReady_joint_target"),
    ("RunChainUGate", "classifyU_productionReady_runChain", "classifyU_productionReady_ep_target"),
    ("RunChainUGate", "classifyU_productionReady_run_w16r2", "classifyU_productionReady_runChain"),
    ("RunChainUGate", "classifyU_productionReady_run_r13", "classifyU_productionReady_runChain"),
    ("RunChainUToken", "classifyU_productionReady_run_r13_token", "classifyU_productionReady_run_r13"),
    ("RunTrGate", "rt_productionReady_r13", "classifyU_productionReady_run_r13_token"),
    ("RunChainUExec", "classifyUExec_productionReady_run_w16r2", "classifyU_productionReady_run_w16r2"),
    ("RunChainUExec", "classifyUExec_productionReady_run_r13", "classifyU_productionReady_run_r13"),
]


def new_name(n):
    assert "productionReady_" in n, n
    return n.replace("productionReady_", "productionReadyL_", 1) + "_range"


def decl(text, name):
    """The declaration `theorem name …` (statement and proof): up to the first blank line."""
    i = text.index(f"theorem {name} ")
    j = text.index("\n\n", i) + 1
    k = text.rfind("\n\n", 0, i) + 2  # the doc comment before it
    return text[k:i], text[i:j]


def header_lines(text):
    """The file's own `open` and top-level `variable` lines (before its first section)."""
    i = text.index("\nnamespace ZK60.ProtocolClassify\n")
    j = text.index("\nsection ", i)
    keep = [ln for ln in text[i:j].splitlines()
            if ln.startswith("open ") or ln.startswith("variable ")]
    return keep


def section_context(text, name):
    """The `variable` statements and local notations of the section enclosing theorem `name`, before it."""
    i = text.index(f"theorem {name} ")
    s = text.rfind("\nsection ", 0, i)
    body = text[s:i].splitlines()[1:]
    out, take = [], False
    for ln in body:
        if ln.startswith("variable ") or ln.startswith("local notation "):
            take = True
            out.append(ln)
        elif take and ln.startswith(" ") and ln.strip():
            out.append(ln)
        else:
            take = False
    return out


def transform(file, name, callee):
    text = open(f"{src}/{file}.lean", encoding="utf-8").read()
    doc, d = decl(text, name)
    n = {}
    d, n["name"] = re.subn(rf"^theorem {name} ", f"theorem {new_name(name)} ", d)
    d, n["hzk"] = re.subn(re.escape(HZK), HZKR, d)
    m = re.search(r"\n    ProductionReady \(classifyModel S (\w+)\) ", d)
    assert m, name
    run = m.group(1)
    d = d[:m.start()] + "\n    ProductionReadyL (classifyModel S " + run + ") " + d[m.end():]
    d, n["end"] = re.subn(r"\n      εcTarget εsTarget εsTarget εzkTarget :=",
                          f"\n      (classifyLeak S {run}) εcTarget εsTarget εsTarget εzkTarget :=", d)
    if callee is None:
        d, n["call"] = re.subn(r"  productionReady_mono\n",
                               "  productionReadyL_of_productionReady_range (classifyLeak S R) classifyU_leaksAtMost\n",
                               d)
    else:
        d, n["call"] = re.subn(rf"(?<![\w.']){callee}(?![\w'])", new_name(callee), d)
    assert n["name"] == 1 and n["hzk"] == 1 and n["end"] == 1 and n["call"] == 1, (name, n)
    assert d.count("ProductionReady ") == 0, (name, "an unchanged ProductionReady remains")
    doc = doc.replace("/-- ", f"/-- **D76 (range form) of `{name}`.** ", 1)
    ctx = header_lines(text) + section_context(text, name)
    print(f"{new_name(name)}: from {file}.lean, {len(ctx)} context lines")
    return (f"section {new_name(name).replace('.', '_')}\n\n" + "\n".join(ctx) + "\n\n" + doc + d
            + f"\nend {new_name(name).replace('.', '_')}\n")


HEADER = '''/-
D63 lane L42 (2026-11-10), part 5: **the classify run's production gates in the approved form of D76 with the
zero-knowledge premise on D76's range only.** GENERATED by `results/zk60_lean_l42_20261110/l42_mk_range.py` from
ProtocolClassifyU.lean, ProtocolClassifyUEp.lean, RunChainUGate.lean, RunChainUToken.lean, RunTrGate.lean and
RunChainUExec.lean: do not edit by hand.

Every gate of the chain asks `hzk : ∀ q R', εzk q R' ≤ εzkTarget q R'` for EVERY `q` and `R`; ruling D76 (2) asks the
approved zero-knowledge statement for `q, R ≤ 2^64` only. Each gate below is its source's statement and proof with four
changes: the name (`…productionReadyL…_range`), `hzk` asked on the range only, the conclusion
`ProductionReadyL … (classifyLeak S R) …`, and the gate it calls (at the bottom, `productionReady_mono` is replaced by
D76's bridge `productionReadyL_of_productionReady_range`). So the zero-knowledge part of each gate is met by lane L33's
receipt cap as proved (`R ≤ 2^110` contains `R ≤ 2^64`; `classifyU_zkL_target_of_refErr`); the instance-leak gates and
the gates of `StatementsD76Gate.lean` cannot be, between `2^110` and `2^120` receipts.

The chain: `classifyU_productionReadyL_joint_target_range` ← `…_ep_target_range` ← `…_runChain_range` ←
`…_run_w16r2_range`, `…_run_r13_range` ← `…_run_r13_token_range` ← **`rt_productionReadyL_r13_range`** (L34's gate
on the run's transcript); **`classifyUExec_productionReadyL_run_r13_range`**, `…_run_w16r2_range` (L30's gates at the
production instance `classifyProtocolUExec`); **`rt_productionReadyL_r13_exec_range`** (L34's gate at
`V := classifyRunV …`, so at `classifyProtocolUExec`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StatementsD76Gate

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60.D76 (classifyLeak productionReadyL_of_productionReady_range)

'''

EXEC_DOC = ('/-- **L34\'s gate on the run\'s transcript at the production instance `classifyProtocolUExec` (D77), in the '
            'approved form\nof D76, with `hzk` on the range only**: `rt_productionReadyL_r13_range` at '
            '`V := classifyRunV …`. -/\n')


def rt_exec_range():
    """`rt_productionReadyL_r13_range` at `V := classifyRunV …` (statement as in StatementsD76Gate.lean's
    `rt_productionReadyL_r13_exec`, with `hzk` on the range)."""
    gate = open(f"{src}/StatementsD76Gate.lean", encoding="utf-8").read()
    i = gate.index("theorem rt_productionReadyL_r13_exec ")
    j = gate.index(" := by\n", i)
    st = gate[i:j] + " :=\n"
    n = {}
    st, n["name"] = re.subn(r"^theorem rt_productionReadyL_r13_exec ", "theorem rt_productionReadyL_r13_exec_range ", st)
    st, n["hzk"] = re.subn(re.escape(HZK), HZKR, st)
    assert n["name"] == 1 and n["hzk"] == 1, n
    # the proof: the range gate at `V := classifyRunV …`, every explicit argument by name, as in the source
    k = gate.index("    (rt_productionReady_r13\n", j)
    e = gate.index("  exact classifyUExec_leaksAtMost\n", k)
    args = gate[k + len("    (rt_productionReady_r13\n"):e].rstrip()
    assert args.endswith(")"), args[-40:]
    args = args[:-1]
    ctx = section_context(open(f"{src}/RunTrGate.lean", encoding="utf-8").read(), "rt_productionReady_r13")
    gh = open(f"{src}/StatementsD76Gate.lean", encoding="utf-8").read()
    opens = [ln for ln in gh[gh.index("\nnamespace ZK60.ProtocolClassify\n"):gh.index("\nsection ")].splitlines()
             if ln.startswith("open ") or ln.startswith("  ") or ln.startswith("variable ")]
    return ("section rt_productionReadyL_r13_exec_range\n\n" + "\n".join(opens + ctx) + "\n\n" + EXEC_DOC + st
            + "  rt_productionReadyL_r13_range\n" + args + "\n\nend rt_productionReadyL_r13_exec_range\n")


body = "\n".join(transform(f, t, c) for f, t, c in CHAIN) + "\n" + rt_exec_range()
open(dst, "w", encoding="utf-8").write(HEADER + body + "\nend ZK60.ProtocolClassify\n")
print("wrote", dst)
