#!/usr/bin/env python3
"""D63 lane L55 (2026-11-10): the positive and negative controls of RunCloseBGeoCheck.lean (the run's boundary openings'
geometry: the closing openings of parts 1 on). A copy of lane L48's l48_negative.py with this checker's inputs.

Copies lane L29's corpus, lane L49's R13 Shieldstral export and the six production source files the checker reads into
scratch trees OUTSIDE the repository (/Users/victorrielly/zk60-artifacts/l55_neg/<case>/, same relative layout),
applies ONE change per case, and runs the checker on each copy. The unchanged copy must pass (exit 0); every single
change must be refused (exit nonzero). Prints one line per case and a summary; exits nonzero unless every case behaves.

Run inside a guarded job (it starts one `lean --run` per case).
"""
import os
import shutil
import subprocess
import sys

# The tree to check: the lane's worktree by default; the coordinator's merged check sets L55_TREE to the main checkout.
WT = os.environ.get("L55_TREE", "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a33fed333d77ee386")
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
CHECK = WT + "/formal/ZK60Formal/RunCloseBGeoCheck.lean"
C29 = WT + "/results/zk60_lean_l29_20261107/corpus.txt"
C49 = WT + "/results/zk60_lean_l49_20261110/pub_shield_short.txt"
ROOT = WT + "/ops/zkp-mvp/gpu-metal"
SCRATCH = "/Users/victorrielly/zk60-artifacts/l55_neg"
SRC = [
    "hashline/src/private_block/shape.rs",
    "hashline/src/private_block/boundary.rs",
    "hashline/src/private_block/token_io/classify.rs",
    "hashline/src/private_block/token_io/classify_run.rs",
    "hashline/src/private_block/token_io/stage_out_c.rs",
    "hashline/src/private_block/endpoint_g.rs",
]


def corpus_word(which, line_key, idx, new):
    """Change word idx of the line of corpus `which` whose first word is line_key."""
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
    return (which, f)


def src_sub(path, old, new):
    def f(text):
        assert old in text, (path, old)
        return text.replace(old, new, 1)
    return (path, f)


CASES = [
    ("positive: unchanged", None),
    ("r13: another profile", corpus_word("c49", "L49S", 1, "R13_SHIELD_T256_H24")),
    ("r13: log_cols 14 -> 15", corpus_word("c49", "L49S", 3, "15")),
    ("r13: t_pad 128 -> 256", corpus_word("c49", "SHAPE", 7, "256")),
    ("r13: d_pad 4096 -> 2048", corpus_word("c49", "SHAPE", 8, "2048")),
    ("dev: B_out rows 22 -> 21", corpus_word("c29", "OUTGEO", 2, "21")),
    ("dev: B_out sites 2 -> 3", corpus_word("c29", "OUTGEO", 4, "3")),
    ("dev: B_out data rows 16 -> 32", corpus_word("c29", "OUTGEO", 3, "32")),
    ("dev: B_out vector length 1280 -> 1281", corpus_word("c29", "OUTDIM", 6, "1281")),
    ("dev: B_out path depth 12 -> 13", corpus_word("c29", "OUTDIM", 8, "13")),
    ("dev: B_out checks 256 -> 128", corpus_word("c29", "OUTPCS", 4, "128")),
    ("dev: the plane 2^14 -> 2^15", corpus_word("c29", "OUTDERIV", 4, "15")),
    ("source: R13 T128 log_cols 14 -> 13", src_sub(SRC[0], "profile:R13_SHIELD_T128_H24,name:\"R13_SHIELD_T128_H24\"",
                                                   "profile:R13_SHIELD_T128_H24,name:\"R13_SHIELD_T128_H24\",log_cols:13")),
    ("source: the R13 profile made W16R2", src_sub(SRC[0], "pub(crate) const W16R2_PROFILES:[AccuracyProfile;3]=[\n",
                                                   "pub(crate) const W16R2_PROFILES:[AccuracyProfile;3]=[\nAccuracyProfile{profile:R13_SHIELD_T128_H24,},\n")),
    ("source: trained rate 4 -> 8", src_sub(SRC[0], "{W16R2_INV_RATE} else {4};", "{W16R2_INV_RATE} else {8};")),
    ("source: an endpoint override", src_sub(SRC[0], "s.kv_heads,s.log_cols,inv_rate,f_e,rows,None,None,None,None));",
                                             "s.kv_heads,s.log_cols,inv_rate,f_e,rows,Some(12),None,None,None));")),
    ("source: COL_CHECKS 256 -> 128", src_sub(SRC[0], "const COL_CHECKS: usize = 256;", "const COL_CHECKS: usize = 128;")),
    ("source: rows + 1 -> rows + 2", src_sub(SRC[1], "        self.data_rows() + 2 * self.sites + 2",
                                             "        self.data_rows() + 2 * self.sites + 1")),
    ("source: the declared-rows refusal removed", src_sub(SRC[1], "        if declared_rows != derived {",
                                                          "        if false {")),
    ("source: boundary params swap", src_sub(SRC[1], "PcsParams { log_cols: self.log_n, inv_rate: self.inv_rate, num_col_checks: self.checks }",
                                             "PcsParams { log_cols: self.log_n, inv_rate: self.inv_rate * 2, num_col_checks: self.checks }")),
    ("source: boundaries at three sites", src_sub(SRC[2], "(j + 1) as u64, 2, sh.endpoint_log_n", "(j + 1) as u64, 3, sh.endpoint_log_n")),
    ("source: boundaries at the core row width", src_sub(SRC[2], "2, sh.endpoint_log_n, sh.endpoint_inv_rate", "2, sh.log_cols, sh.endpoint_inv_rate")),
    ("source: block k opens its own boundary", src_sub(SRC[3], "        let bp = pspec.params();", "        let bp = spec.params();")),
    ("source: OUT-C handed B_in", src_sub(SRC[3], "    let (bspec, broot) = prev;", "    let (bspec, broot) = (st.boundary_spec(0)?, prev.1);")),
    ("source: B_out at other params", src_sub(SRC[4], "    let bp = b_spec.params();", "    let bp = lay.params;")),
    ("source: six mask rows", src_sub(SRC[5], "pub(crate) const MASK_ROWS: usize = 5;", "pub(crate) const MASK_ROWS: usize = 6;")),
]


def build_case(i, mut):
    d = os.path.join(SCRATCH, "case%02d" % i)
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    texts = {"c29": open(C29).read(), "c49": open(C49).read()}
    files = {p: open(os.path.join(ROOT, p)).read() for p in SRC}
    if mut is not None:
        where, f = mut
        if where in texts:
            texts[where] = f(texts[where])
        else:
            files[where] = f(files[where])
    open(os.path.join(d, "c29.txt"), "w").write(texts["c29"])
    open(os.path.join(d, "c49.txt"), "w").write(texts["c49"])
    for p, text in files.items():
        q = os.path.join(d, "src", p)
        os.makedirs(os.path.dirname(q), exist_ok=True)
        open(q, "w").write(text)
    return os.path.join(d, "c29.txt"), os.path.join(d, "c49.txt"), os.path.join(d, "src")


def main():
    ok_all = True
    for i, (name, mut) in enumerate(CASES):
        c29, c49, root = build_case(i, mut)
        r = subprocess.run([LAKE, "-d", WT + "/formal", "env", "lean", "--run", CHECK, c29, c49, root],
                           capture_output=True, text=True, stdin=subprocess.DEVNULL)
        last = [l for l in r.stdout.splitlines() if l.startswith("RunCloseBGeoCheck:")]
        want_pass = mut is None
        good = (r.returncode == 0) == want_pass
        ok_all = ok_all and good
        fails = [l for l in r.stdout.splitlines() if l.startswith("FAIL")]
        print("%s case %02d (%s): exit %d, %s%s" % ("ok  " if good else "BAD ", i, name, r.returncode,
              last[0] if last else "no summary", ("; first refusal: " + fails[0]) if fails else ""))
        if r.returncode != 0 and not last:
            print(r.stderr[-2000:])
    print("l55_negative: %d cases, %s" % (len(CASES), "all as required" if ok_all else "SOME CASE MISBEHAVED"))
    shutil.rmtree(SCRATCH, ignore_errors=True)
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
