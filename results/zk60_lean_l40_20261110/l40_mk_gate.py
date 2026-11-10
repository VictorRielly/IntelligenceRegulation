#!/usr/bin/env python3
"""D63 lane L40 (2026-11-10): write formal/ZK60Formal/RunShapeGate.lean, the run-chain gates of lanes L26, L30 and L34
RE-INDEXED to the per-block-shape run model (RunShape.lean, RunShapeProtocol.lean).

Each declaration below is read from its source file and rewritten by fixed substitutions, as lane L30 wrote its
token and exec gates (results/zk60_lean_l30_20261109/l30_mk_token.py):
  * the run data `R : ClassifyRunPublic S` -> `R : ClassifyRunPublicP S` (`S` is now the run's carrier: T and d);
  * the model, the arithmetization and the instances at `classifyModelP R`, `classifyArithP R`,
    `classifyProtocolUP R`, `classifyProtocolUExecP R`;
  * `ClassifyOpen ... E εin εblk εout εep εzk` -> `ClassifyOpenP ... εzk` (L18's obligations without O11, which these
    gates never read);
  * the block count `R.Ps.length` -> `R.blks.length`, and block k's conclusion `BlockOn R.Ps[k]` ->
    `BlockOn R.blks[k].pub` (L18's own predicate, AT BLOCK k'S SHAPE);
  * the parts' predicates `InOk`, `BlocksOk`, `OutOk`, `EpOk`, `JointOk` -> their per-block versions;
  * the theorem names -> `...P`, and the calls among them.
Nothing else changes: every other premise is the source's, term for term.

usage: python3 -I l40_mk_gate.py <formal/ZK60Formal dir>
"""
import re
import sys

src = sys.argv[1]

STARTS = ("/--", "/-!", "theorem ", "noncomputable ", "def ", "end ", "section ", "variable ", "omit ", "open ",
          "local ", "-- ", "abbrev ")


def block(fname, name):
    lines = open(f"{src}/{fname}").read().split("\n")
    idx = None
    for i, l in enumerate(lines):
        if re.match(r"^(noncomputable )?(theorem|def) " + re.escape(name) + r"\b", l):
            idx = i
            break
    if idx is None:
        raise SystemExit(f"{name} not found in {fname}")
    start = idx
    if start > 0 and lines[start - 1].rstrip().endswith("-/"):
        j = start - 1
        while not lines[j].startswith("/--"):
            j -= 1
        start = j
    end = idx + 1
    while end < len(lines) and not (lines[end] == "" or lines[end].startswith(STARTS)):
        end += 1
    return "\n".join(lines[start:end])


NAMES = {
    "classifyU_productionReady_joint_target": "classifyUP_productionReady_joint_target",
    "classifyU_productionReady_ep_target": "classifyUP_productionReady_ep_target",
    "classifyU_productionReady_runChain": "classifyUP_productionReady_runChain",
    "classifyU_productionReady_run_r13_token": "classifyUP_productionReady_run_r13_token",
    "classifyU_productionReady_run_r13": "classifyUP_productionReady_run_r13",
    "classifyUExec_productionReady_run_r13": "classifyUExecP_productionReady_run_r13",
    "rt_productionReady_r13": "rt_productionReady_r13P",
    "cover3_of_runParts_ord": "cover3_of_runParts_ordP",
    "jointCover_of_parts": "jointCover_of_partsP",
    "epCoverU": "epCoverUP",
}


def rewrite(text):
    for old, new in NAMES.items():
        text = re.sub(r"\b" + old + r"\b", new, text)
    for r in ["R", "Rp"]:
        text = text.replace(f"({r} : ClassifyRunPublic S)", f"({r} : ClassifyRunPublicP S)")
        text = text.replace(f"classifyProtocolUExec {r} ", f"classifyProtocolUExecP {r} ")
        text = text.replace(f"classifyProtocolU S {r} ", f"classifyProtocolUP {r} ")
        text = text.replace(f"classifyModel S {r})", f"classifyModelP {r})")
        text = text.replace(f"classifyArith S {r})", f"classifyArithP {r})")
        text = text.replace(f"{r}.Ps.length", f"{r}.blks.length")
        text = text.replace(f"BlockOn {r}.Ps[k]", f"BlockOn {r}.blks[k].pub")
        text = re.sub(r"\bInOk " + r + r"\b", f"InOkP {r}", text)
        text = re.sub(r"\bOutOk " + r + r"\b", f"OutOkP {r}", text)
        text = re.sub(r"\bBlocksOk " + r + r"\b", f"BlocksOkP {r}", text)
        text = re.sub(r"\bJointOk " + r + r"\b", f"JointOkP {r}", text)
    text = re.sub(r"\bEpOk\b", "EpOkP", text)
    text = re.sub(r"ClassifyOpen (\w+) (.*?) E εin εblk εout εep εzk\)", r"ClassifyOpenP \1 \2 εzk)", text, flags=re.S)
    text = text.replace("{εin εblk εout εep : ℕ → ℝ≥0∞} ", "")
    text = text.replace("(R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins' (classifyModel S R))",
                        "(R : ClassifyRunPublicP S) (P : Protocol (QB Lq) Dig Coins' (classifyModelP R))")
    text = text.replace("(R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))",
                        "(R : ClassifyRunPublicP S) (P : Protocol (QB Lq) Dig Coins (classifyModelP R))")
    return text


def check_clean(text, what):
    for bad in ["ClassifyRunPublic S)", "classifyModel S", "classifyArith S", ".Ps", "ClassifyOpen ", "εin"]:
        if bad in text:
            raise SystemExit(f"{what}: unconverted '{bad}'")


HEADER = open(f"{src}/../../results/zk60_lean_l40_20261110/l40_gate_header.lean.txt").read()

out = [HEADER]


def emit(fname, name):
    t = rewrite(block(fname, name))
    check_clean(t, name)
    out.append(t)
    out.append("")


out.append("/-! ## The covers (L26, L30) -/\n\nsection Cover\n\nvariable {Lq : ℕ} {Coins' : Type}\n")
emit("ProtocolClassifyU.lean", "jointCover_of_parts")
out.append("end Cover\n\nsection CoverOrd\n\nvariable {Lq : ℕ} {Coins : Type}\n")
t = rewrite(block("RunChainUOrd.lean", "cover3_of_runParts_ord"))
t = t.replace("unfold BlocksOk at hblk", "unfold BlocksOkP at hblk")
check_clean(t, "cover3")
out.append(t)
out.append("\nend CoverOrd\n\nsection Endpoint\n")
emit("ProtocolClassifyUEp.lean", "epCoverU")
out.append("variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]\n"
           "variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]\n")
emit("ProtocolClassifyUEp.lean", "classifyU_productionReady_ep_target")
out.append("end Endpoint\n\n/-! ## The gate through the run's chain (L30), generic and at R13 -/\n\nsection Gates\n\n"
           "variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]\n"
           "variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]\n")
emit("RunChainUGate.lean", "classifyU_productionReady_runChain")
emit("RunChainUGate.lean", "classifyU_productionReady_run_r13")
out.append("end Gates\n")
out.append(open(f"{src}/../../results/zk60_lean_l40_20261110/l40_gate_token_header.lean.txt").read())
emit("RunChainUToken.lean", "classifyU_productionReady_run_r13_token")
out.append("end TokenR13\n")
out.append(open(f"{src}/../../results/zk60_lean_l40_20261110/l40_gate_exec_header.lean.txt").read())
emit("RunChainUExec.lean", "classifyUExec_productionReady_run_r13")
out.append("end Exec\n")
out.append(open(f"{src}/../../results/zk60_lean_l40_20261110/l40_gate_rt_header.lean.txt").read())
emit("RunTrGate.lean", "rt_productionReady_r13")
out.append("end GateR13\n\nend ZK60.ProtocolClassify.RunShapeP\n")
open(f"{src}/RunShapeGate.lean", "w").write("\n".join(out))
print("wrote RunShapeGate.lean")
