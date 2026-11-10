#!/usr/bin/env python3
"""D63 lane L53 (2026-11-10): the positive and negative controls of RunStgCheck.lean (the stage parts' lists against a
real classifier receipt, lane L29's corpus). The unchanged corpus and sources must pass; each single change below must
make the checker fail (exit nonzero, at least one failed check). The mutated copies are written in this evidence
directory (prefix l53_neg_) and removed afterwards. The checker's own NEGATIVE checks (the lists' parameters changed)
run inside every run; these are changes to the CODE's side (the receipt's records and the stage sources).

usage: python3 -I l53_negative.py
"""
import os
import re
import subprocess
import sys

WT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9ec802146c5f3200"
OUT = f"{WT}/results/zk60_lean_l53_20261110"
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
CHK = f"{WT}/formal/ZK60Formal/RunStgCheck.lean"
CORPUS = f"{WT}/results/zk60_lean_l29_20261107/corpus.txt"
SIN = f"{WT}/ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io/stage_in_c.rs"
SOUT = f"{WT}/ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io/stage_out_c.rs"


def run(corpus, sin, sout):
    p = subprocess.run([LAKE, "-d", f"{WT}/formal", "env", "lean", "--run", CHK, corpus, sin, sout],
                       capture_output=True, text=True)
    last = [l for l in p.stdout.splitlines() if l.startswith("RunStgCheck:")]
    return p.returncode, (last[-1] if last else "(no summary) " + p.stderr[-300:])


def flip_hex(tok):
    return ("0" if tok[0] != "0" else "1") + tok[1:]


def mut_record(lines, key, idx, field, fn):
    """Change field `field` of the idx-th record `key`."""
    out, seen = [], 0
    for l in lines:
        w = l.split(" ")
        if w[0] == key:
            if seen == idx:
                w[field] = fn(w[field])
                l = " ".join(w)
            seen += 1
        out.append(l)
    return out


def drop_round(tok):
    parts = tok.split(";")
    return ";".join(parts[:-1])


corpus = open(CORPUS).read().split("\n")
src_in = open(SIN).read()
src_out = open(SOUT).read()
cases = [
    ("the receipt's state after H (IN-C) changed", lambda c: mut_record(c, "INHEAD", 0, 1, flip_hex), None, None),
    ("the receipt's state after IN-C slot 2 changed", lambda c: mut_record(c, "INAFTER", 2, 2, flip_hex), None, None),
    ("the receipt's counter after IN-C slot 1 one more", lambda c: mut_record(c, "INAFTER", 1, 3, lambda x: str(int(x) + 1)),
     None, None),
    ("the receipt's state after OUT-C slot 5 changed", lambda c: mut_record(c, "OUTAFTER", 5, 2, flip_hex), None, None),
    ("the receipt's counter after OUT-C's head one less", lambda c: mut_record(c, "OUTHEAD", 0, 2, lambda x: str(int(x) - 1)),
     None, None),
    ("IN-C slot 1's proof one round short", lambda c: mut_record(c, "INSLOT", 1, 3, drop_round), None, None),
    ("one head challenge fewer recorded (IN-C)", lambda c: mut_record(c, "INHEAD", 0, 3, lambda x: ",".join(x.split(",")[:-1])),
     None, None),
    ("IN-C source: slot INC-01's degree 5", None, lambda s: s.replace("main: lti, ext: 1, degree: 4", "main: lti, ext: 1, degree: 5", 1), None),
    ("IN-C source: a host declared", None, lambda s: s.replace("hosts: vec![],", "hosts: vec![(SIC_QZC, vec![SIC_IO])],", 1), None),
    ("OUT-C source: LZC hosts nothing", None, None, lambda s: s.replace("(SOC_LZC, vec![SOC_PD])", "", 1)),
    # the verifier's copy (stage_out_c.rs `verify`, after `seg.mask_root`), not the prover's (finding L51's case 18)
    ("OUT-C source: the verifier draws alpha before gamma", None, None,
     lambda s: s.replace("tr.absorb(b\"M\", &seg.mask_root);\n    let gamma = tr.challenge_fp2();\n    let alpha = tr.challenge_fp2();",
                         "tr.absorb(b\"M\", &seg.mask_root);\n    let alpha = tr.challenge_fp2();\n    let gamma = tr.challenge_fp2();", 1)),
]
rc0, s0 = run(CORPUS, SIN, SOUT)
print(f"unchanged: rc {rc0}: {s0}")
ok = rc0 == 0 and s0.endswith(" 0 failed")
n_ok = 0
for i, (what, fc, fi, fo) in enumerate(cases):
    cp, ip, op = CORPUS, SIN, SOUT
    tmp = []
    if fc:
        cp = f"{OUT}/l53_neg_{i}_corpus.txt"
        open(cp, "w").write("\n".join(fc(corpus)))
        tmp.append(cp)
    if fi:
        t = fi(src_in)
        assert t != src_in, what
        ip = f"{OUT}/l53_neg_{i}_in.rs"
        open(ip, "w").write(t)
        tmp.append(ip)
    if fo:
        t = fo(src_out)
        assert t != src_out, what
        op = f"{OUT}/l53_neg_{i}_out.rs"
        open(op, "w").write(t)
        tmp.append(op)
    rc, summ = run(cp, ip, op)
    m = re.search(r"(\d+) failed", summ)
    caught = rc != 0 and m is not None and int(m.group(1)) > 0
    n_ok += caught
    print(f"case {i + 1}: {what}: rc {rc}: {summ}: {'caught' if caught else 'NOT CAUGHT'}")
    for f in tmp:
        os.remove(f)
print(f"l53_negative: unchanged {'passes' if ok else 'FAILS'}; {n_ok} of {len(cases)} changes caught")
sys.exit(0 if ok and n_ok == len(cases) else 1)
