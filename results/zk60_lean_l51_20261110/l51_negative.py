#!/usr/bin/env python3
"""D63 lane L51 (2026-11-10): the positive and negative controls of RunAbsCheck.lean (adapted from
results/zk60_lean_l48_20261110/l48_negative.py).

Copies lane L51's corpus (l51_corpus.txt, the export of a real classifier run's header) and the three production source
files the checker reads into scratch trees OUTSIDE the repository (/Users/victorrielly/zk60-artifacts/l51_neg/<case>/,
same relative layout), applies ONE change per case, and runs the checker on each copy. The unchanged copy must pass
(exit 0); every single change must be refused (exit nonzero). Prints one line per case and a summary; exits nonzero
unless every case behaves.

Run inside a guarded job (it starts one `lean --run` per case).
"""
import os
import shutil
import subprocess
import sys

WT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a60fcb882718532c4"
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
CHECK = WT + "/formal/ZK60Formal/RunAbsCheck.lean"
CORPUS = WT + "/results/zk60_lean_l51_20261110/l51_corpus.txt"
ROOT = WT + "/ops/zkp-mvp/gpu-metal"
SCRATCH = "/Users/victorrielly/zk60-artifacts/l51_neg"
SRC = [
    "hashline/src/private_block/token_io/classify.rs",
    "hashline/src/private_block/token_io/classify_run.rs",
    "hashline/src/private_block/token_io/stage_in_c.rs",
]


def corpus_line(key, f):
    """Apply f to the word list of the first corpus line whose first word is key (key may be 'HDR <i>')."""
    def g(text):
        out, done = [], False
        for line in text.split("\n"):
            ws = line.split(" ")
            hit = (" ".join(ws[:len(key.split(" "))]) == key)
            if not done and hit:
                ws = f(ws)
                line = " ".join(ws)
                done = True
            out.append(line)
        assert done, key
        return "\n".join(out)
    return ("corpus", g)


def flip_hex(s, i):
    """Flip the low bit of hex byte i of the string s."""
    b = bytearray.fromhex(s)
    b[i] ^= 1
    return b.hex()


def word(idx, fn):
    def f(ws):
        ws[idx] = fn(ws[idx])
        return ws
    return f


def swap_hdr(i, j):
    """Swap the (label, data) of header items i and j."""
    def g(text):
        lines = text.split("\n")
        ii = [k for k, l in enumerate(lines) if l.startswith("HDR %d " % i)][0]
        jj = [k for k, l in enumerate(lines) if l.startswith("HDR %d " % j)][0]
        a, b = lines[ii].split(" "), lines[jj].split(" ")
        a[2:], b[2:] = b[2:], a[2:]
        lines[ii], lines[jj] = " ".join(a), " ".join(b)
        return "\n".join(lines)
    return ("corpus", g)


def drop_hdr(i):
    def g(text):
        return "\n".join(l for l in text.split("\n") if not l.startswith("HDR %d " % i))
    return ("corpus", g)


def src_sub(path, old, new):
    def f(text):
        assert old in text, (path, old)
        return text.replace(old, new, 1)
    return (path, f)


CASES = [
    ("positive: unchanged", None),
    ("corpus: one byte of the input root", corpus_line("INROOT", word(1, lambda s: flip_hex(s, 31)))),
    ("corpus: one byte of the input endpoint spec's digest", corpus_line("INSPECDIG", word(1, lambda s: flip_hex(s, 0)))),
    ("corpus: one byte of the binding", corpus_line("BINDING", word(1, lambda s: flip_hex(s, 5)))),
    ("corpus: the verdict 1 -> 0", corpus_line("VERDICT", word(1, lambda s: "0" if s == "1" else "1"))),
    ("corpus: expected-IO's last byte (the root's)", corpus_line("HDR 1", word(3, lambda s: flip_hex(s, 83)))),
    ("corpus: one byte of the parameter line", corpus_line("HDR 3", word(3, lambda s: flip_hex(s, 10)))),
    ("corpus: one byte of the chunk", corpus_line("HDR 7", word(3, lambda s: flip_hex(s, 0)))),
    ("corpus: a label (run-shape -> run-shapd)",corpus_line("HDR 0", word(2, lambda s: flip_hex(s, 8)))),
    ("corpus: calibration and schedule swapped", swap_hdr(4, 5)),
    ("corpus: the chunk absorb dropped", drop_hdr(7)),
    ("corpus: another Fiat-Shamir key", corpus_line("KEY", word(1, lambda s: flip_hex(s, 0) if s != "-" else "00" * 32))),
    ("corpus: the fresh state", corpus_line("FRESH", word(1, lambda s: flip_hex(s, 1)))),
    ("corpus: B_in's root is the input root", None),  # built below (needs the corpus's INROOT)
    ("source: expected-IO and public-statement swapped",
     src_sub(SRC[0], "        tr.absorb(b\"expected-IO\", &self.expected_bytes());\n"
                     "        tr.absorb(b\"public-statement\", &self.public_statement());",
             "        tr.absorb(b\"public-statement\", &self.public_statement());\n"
             "        tr.absorb(b\"expected-IO\", &self.expected_bytes());")),
    ("source: a ninth header absorb (the repair)",
     src_sub(SRC[0], "        tr.absorb(b\"expected-IO\", &self.expected_bytes());",
             "        tr.absorb(b\"expected-IO\", &self.expected_bytes());\n"
             "        tr.absorb(b\"input-root\", &self.in_root);")),
    ("source: expected_bytes without the spec digest",
     src_sub(SRC[0], "        v.extend_from_slice(&self.in_spec.digest());\n", "")),
    ("source: expected_bytes with the root before the digest",
     src_sub(SRC[0], "        v.extend_from_slice(&self.in_spec.digest());\n        v.extend_from_slice(&self.in_root);",
             "        v.extend_from_slice(&self.in_root);\n        v.extend_from_slice(&self.in_spec.digest());")),
    ("source: the run not on st.transcript()",
     src_sub(SRC[1], "    let mut tr = st.transcript()?;\n    let binding = tr.state();",
             "    let mut tr = st.transcript_v2()?;\n    let binding = tr.state();")),
    ("source: stage IN-C absorbs the endpoint root",
     src_sub(SRC[2], "    let ep_data_rows = ep_spec.data_rows();",
             "    protocol::absorb_root(tr, b\"In\", ep_root, ep_spec.commitment_rows(), cp.tier.ep_log_n);\n"
             "    let ep_data_rows = ep_spec.data_rows();")),
]


def build_case(i, name, mut):
    d = os.path.join(SCRATCH, "case%02d" % i)
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    corpus = open(CORPUS).read()
    files = {p: open(os.path.join(ROOT, p)).read() for p in SRC}
    if name == "corpus: B_in's root is the input root":
        root = [l for l in corpus.split("\n") if l.startswith("INROOT ")][0].split(" ")[1]
        corpus = corpus_line("INROOTS", word(1, lambda s: root))[1](corpus)
    elif mut is not None:
        where, f = mut
        if where == "corpus":
            corpus = f(corpus)
        else:
            files[where] = f(files[where])
    open(os.path.join(d, "l51_corpus.txt"), "w").write(corpus)
    for p, text in files.items():
        q = os.path.join(d, "src", p)
        os.makedirs(os.path.dirname(q), exist_ok=True)
        open(q, "w").write(text)
    return os.path.join(d, "l51_corpus.txt"), os.path.join(d, "src")


def main():
    ok_all = True
    for i, (name, mut) in enumerate(CASES):
        corpus, root = build_case(i, name, mut)
        r = subprocess.run([LAKE, "-d", WT + "/formal", "env", "lean", "--run", CHECK, corpus, root],
                           capture_output=True, text=True)
        last = [l for l in r.stdout.splitlines() if l.startswith("RunAbsCheck:")]
        want_pass = name.startswith("positive")
        good = (r.returncode == 0) == want_pass
        ok_all = ok_all and good
        fails = [l for l in r.stdout.splitlines() if l.startswith("FAIL")]
        print("%s case %02d (%s): exit %d, %s%s" % ("ok  " if good else "BAD ", i, name, r.returncode,
              last[0] if last else "no summary", ("; first refusal: " + fails[0]) if fails else ""))
        if r.returncode != 0 and not last:
            print(r.stderr[-2000:])
    print("l51_negative: %d cases, %s" % (len(CASES), "all as required" if ok_all else "SOME CASE MISBEHAVED"))
    shutil.rmtree(SCRATCH, ignore_errors=True)
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
