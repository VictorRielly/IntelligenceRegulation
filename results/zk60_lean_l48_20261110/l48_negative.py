#!/usr/bin/env python3
"""D63 lane L48 (2026-11-10): the positive and negative controls of RunOpenGeoCheck.lean.

Copies lane L29's corpus and the six production source files the checker reads into scratch trees OUTSIDE the
repository (/Users/victorrielly/zk60-artifacts/l48_neg/<case>/, same relative layout), applies ONE change per case,
and runs the checker on each copy. The unchanged copy must pass (exit 0); every single change must be refused
(exit nonzero). Prints one line per case and a summary; exits nonzero unless every case behaves.

Run inside a guarded job (it starts one `lean --run` per case).
"""
import os
import shutil
import subprocess
import sys

# The tree to check: the lane's worktree by default; the coordinator's merged check sets L48_TREE to the main checkout.
WT = os.environ.get("L48_TREE", "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ab319ebebdb0feaea")
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
CHECK = WT + "/formal/ZK60Formal/RunOpenGeoCheck.lean"
CORPUS = WT + "/results/zk60_lean_l29_20261107/corpus.txt"
ROOT = WT + "/ops/zkp-mvp/gpu-metal"
SCRATCH = "/Users/victorrielly/zk60-artifacts/l48_neg"
SRC = [
    "hashline/src/private_block/token_io.rs",
    "hashline/src/private_block/token_io/classify.rs",
    "hashline/src/private_block/token_io/stage_in_c.rs",
    "zkp-core/src/pcs.rs",
    "hashline/src/private_block/endpoint_g.rs",
    "hashline/src/private_block/shape.rs",
]


def corpus_word(line_key, idx, new):
    """Change word idx of the corpus line whose first word is line_key."""
    def f(text):
        out = []
        done = False
        for line in text.split("\n"):
            ws = line.split(" ")
            if not done and ws and ws[0] == line_key:
                ws[idx] = new
                line = " ".join(ws)
                done = True
            out.append(line)
        assert done, line_key
        return "\n".join(out)
    return ("corpus", f)


def src_sub(path, old, new):
    def f(text):
        assert old in text, (path, old)
        return text.replace(old, new, 1)
    return (path, f)


CASES = [
    ("positive: unchanged", None),
    ("corpus: IN-C tier stage_log_n 12 -> 13", corpus_word("INP", 7, "13")),
    ("corpus: tier ep_log_n 8 -> 9", corpus_word("INP", 8, "9")),
    ("corpus: OUT-C tier stage_log_n 12 -> 14", corpus_word("OUTP", 4, "14")),
    ("corpus: IN-C A/H encoded columns 16384 -> 32768", corpus_word("INDIM", 3, "32768")),
    ("corpus: IN-C A/H vector length 4352 -> 4608", corpus_word("INDIM", 2, "4608")),
    ("corpus: endpoint encoded columns 2048 -> 4096", corpus_word("INDIM", 7, "4096")),
    ("corpus: endpoint path depth 11 -> 12", corpus_word("INDIM", 8, "12")),
    ("corpus: endpoint log inverse rate 3 -> 2", corpus_word("INPCS", 2, "2")),
    ("corpus: endpoint column checks 256 -> 280", corpus_word("INPCS", 4, "280")),
    ("corpus: OUT-C A/H vector length 4352 -> 16640", corpus_word("OUTDIM", 2, "16640")),
    ("corpus: endpoint data rows 1 -> 2", corpus_word("INGEO", 4, "2")),
    ("source: R1_MVP stage_log_n 12 -> 13", src_sub(SRC[0], "stage_log_n: 12,", "stage_log_n: 13,")),
    ("source: R1_MVP ep_inv_rate 8 -> 4", src_sub(SRC[0], "ep_inv_rate: 8,", "ep_inv_rate: 4,")),
    ("source: R1_MVP opened_cols 256 -> 280", src_sub(SRC[0], "opened_cols: 256,", "opened_cols: 280,")),
    ("source: a second registered tier", src_sub(SRC[0], "pub(crate) const REGISTERED: [Tier; 1] = [Tier::R1_MVP];",
                                                  "pub(crate) const REGISTERED: [Tier; 2] = [Tier::R1_MVP, Tier::R2];")),
    ("source: input endpoint at the stage geometry", src_sub(SRC[1], "t.ep_log_n, t.ep_inv_rate, t.opened_cols",
                                                             "t.stage_log_n, t.stage_inv_rate, t.opened_cols")),
    ("source: the tier door removed", src_sub(SRC[1], "        tier.check()?;", "        // door removed")),
    ("source: stage IN-C at ep_log_n", src_sub(SRC[2], "    let lt = cp.tier.stage_log_n;", "    let lt = cp.tier.ep_log_n;")),
    ("source: pads != opened columns", src_sub(SRC[3], "ZkOpts { q_pad: params.num_col_checks, coset: Fp::new(7) }",
                                               "ZkOpts { q_pad: params.num_col_checks + 24, coset: Fp::new(7) }")),
    ("source: six endpoint mask rows", src_sub(SRC[4], "pub(crate) const MASK_ROWS: usize = 5;",
                                               "pub(crate) const MASK_ROWS: usize = 6;")),
    ("source: R13 T128 log_cols 14 -> 13", src_sub(SRC[5], "profile:R13_SHIELD_T128_H24,name:\"R13_SHIELD_T128_H24\"",
                                                   "profile:R13_SHIELD_T128_H24,name:\"R13_SHIELD_T128_H24\",log_cols:13")),
]


def build_case(i, mut):
    d = os.path.join(SCRATCH, "case%02d" % i)
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    corpus = open(CORPUS).read()
    files = {p: open(os.path.join(ROOT, p)).read() for p in SRC}
    if mut is not None:
        where, f = mut
        if where == "corpus":
            corpus = f(corpus)
        else:
            files[where] = f(files[where])
    open(os.path.join(d, "corpus.txt"), "w").write(corpus)
    for p, text in files.items():
        q = os.path.join(d, "src", p)
        os.makedirs(os.path.dirname(q), exist_ok=True)
        open(q, "w").write(text)
    return os.path.join(d, "corpus.txt"), os.path.join(d, "src")


def main():
    ok_all = True
    for i, (name, mut) in enumerate(CASES):
        corpus, root = build_case(i, mut)
        r = subprocess.run([LAKE, "-d", WT + "/formal", "env", "lean", "--run", CHECK, corpus, root],
                           capture_output=True, text=True)
        last = [l for l in r.stdout.splitlines() if l.startswith("RunOpenGeoCheck:")]
        want_pass = mut is None
        good = (r.returncode == 0) == want_pass
        ok_all = ok_all and good
        fails = [l for l in r.stdout.splitlines() if l.startswith("FAIL")]
        print("%s case %02d (%s): exit %d, %s%s" % ("ok  " if good else "BAD ", i, name, r.returncode,
              last[0] if last else "no summary", ("; first refusal: " + fails[0]) if fails else ""))
        if r.returncode != 0 and not last:
            print(r.stderr[-2000:])
    print("l48_negative: %d cases, %s" % (len(CASES), "all as required" if ok_all else "SOME CASE MISBEHAVED"))
    shutil.rmtree(SCRATCH, ignore_errors=True)
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
