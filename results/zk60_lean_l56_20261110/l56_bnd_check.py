#!/usr/bin/env python3
"""D63 lane L56 (2026-11-10): check the boundary positions of lane L56's Lean schedule against the code's transcript on
a real classifier receipt (the corpus `l56_corpus.txt` written by the test-only `lean_l56_export_tests.rs`).

The Lean schedule `blockSchedXB` (RunBndSched.lean) and the run's semantics `wrCsB` (RunBndSem.lean) read block `k`'s
INPUT boundary at run position `off k + 2` (part `k`'s frame, position 2) and its OUTPUT boundary at `off (k + 1) + 2`
(part `k + 1`'s frame, position 2); the top theorem's `hgXB` puts the closing opening of part `j + 1` at `off j + 2`.
This script checks, on the corpus:
  FRAME  every part before stage OUT-C (stage IN-C and the blocks) starts with the five absorbs `pb-run-stage` (the
         part's index), `pb-run-block`, `B` (a 32-byte root), `rows`, `log-cols`: the boundary root is at position 2;
  OPEN   the closing opening of every part `i = 1 … L + 1` is verified against the root part `i - 1`'s frame absorbed at
         its position 2 (so `(base i).gX.ipos = off (i - 1) + 2`), never against an `A` root;
  CLAIMS each block's closing opening checks the previous part's outgoing claims first (their count is the previous
         part's carry), then the block's incoming claims (`SC_IO_IN`, at least one); its outgoing claims (`SC_IO_OUT`)
         go to the next part's opening;
  NEG    the test refused all of its negative controls (five per block and one at stage OUT-C), each named.
With `--negative`, it also runs its own negative control: twelve single changes to the corpus, each must be refused.
usage: python3 l56_bnd_check.py <corpus> [--negative]
"""
import sys

LABELS = [b"pb-run-stage", b"pb-run-block", b"B", b"rows", b"log-cols"]
NEG_MODES = ["RootFirst", "OwnRoot", "PrevARoot", "NoIncoming", "OutHere"]


def parse(text):
    frames, aroots, opens, carries, negs = {}, {}, {}, {}, []
    head, refused, done = None, None, None
    for line in text.splitlines():
        f = line.split()
        if not f:
            continue
        if f[0] == "L56":
            head = f
        elif f[0] == "FRAME":
            frames.setdefault(int(f[1]), {})[int(f[2])] = (bytes.fromhex(f[3]), bytes.fromhex(f[4]))
        elif f[0] == "AROOT":
            aroots[int(f[1])] = bytes.fromhex(f[2])
        elif f[0] == "OPEN":
            kv = dict(x.split("=", 1) for x in f[2:])
            opens[int(f[1])] = (bytes.fromhex(kv["root"]), int(kv["pending"]), int(kv["in"]))
        elif f[0] == "CARRY":
            kv = dict(x.split("=", 1) for x in f[2:])
            carries[int(f[1])] = int(kv["out"])
        elif f[0] == "NEG":
            negs.append((int(f[1]), f[2], f[3]))
        elif f[0] == "REFUSED":
            refused = int(f[1])
        elif f[0] == "DONE":
            done = int(f[1])
    return head, frames, aroots, opens, carries, negs, refused, done


def check(text):
    """The failures (empty when the corpus passes) and the checks' count."""
    fails = []
    n = 0
    head, frames, aroots, opens, carries, negs, refused, done = parse(text)
    if head is None or done is None:
        return ["the corpus has no header or no end"], n
    L = int([x for x in head if x.startswith("L=")][0][2:])
    segs = int([x for x in head if x.startswith("segments=")][0][len("segments="):])
    n += 1
    if segs != L + 2 or done != L + 2:
        fails.append("the run is not L + 2 segments")
    # FRAME: parts 0 … L
    for i in range(L + 1):
        fr = frames.get(i, {})
        n += 1
        if sorted(fr) != [0, 1, 2, 3, 4]:
            fails.append("part %d: not five frame absorbs" % i)
            continue
        for j, lab in enumerate(LABELS):
            n += 1
            if fr[j][0] != lab:
                fails.append("part %d: frame absorb %d is %r, not %r" % (i, j, fr[j][0], lab))
        n += 1
        if fr[0][1] != i.to_bytes(8, "little"):
            fails.append("part %d: pb-run-stage is not the part's index" % i)
        n += 1
        if len(fr[2][1]) != 32:
            fails.append("part %d: the boundary root is not 32 bytes" % i)
    # OPEN: parts 1 … L + 1
    for i in range(1, L + 2):
        n += 1
        if i not in opens:
            fails.append("part %d: no closing opening" % i)
            continue
        root, pend, inc = opens[i]
        n += 1
        if root != frames.get(i - 1, {}).get(2, (b"", b""))[1]:
            fails.append("part %d: the closing opening's root is not part %d's frame position 2" % (i, i - 1))
        for p in range(L + 1):
            n += 1
            if p in aroots and root == aroots[p]:
                fails.append("part %d: the closing opening's root is part %d's A root" % (i, p))
        n += 1
        if pend != carries.get(i - 1, -1):
            fails.append("part %d: the opening's pending claims are not part %d's outgoing claims" % (i, i - 1))
        if i <= L:
            n += 1
            if inc < 1:
                fails.append("part %d: the block hands its opening no incoming claim" % i)
    # NEG
    for k in range(1, L + 1):
        for m in NEG_MODES:
            n += 1
            if not any(x == (k, m, "refused:") for x in negs):
                fails.append("block part %d: negative control %s not refused" % (k, m))
    n += 1
    if not any(x == (L + 1, "PrevARoot", "refused:") for x in negs):
        fails.append("stage OUT-C's negative control not refused")
    n += 1
    if refused != 5 * L + 1 or len(negs) != 5 * L + 1:
        fails.append("the refused count is not 5 L + 1")
    return fails, n


def mutations(text):
    """Twelve single changes to the corpus, each of which a correct checker must refuse."""
    lines = text.splitlines()
    out = []

    def sub(pred, fn, name):
        ls = list(lines)
        for i, l in enumerate(ls):
            if pred(l):
                ls[i] = fn(l)
                out.append((name, "\n".join(ls) + "\n"))
                return
        raise AssertionError("no line for " + name)

    def drop(pred, name):
        ls = [l for l in lines if not pred(l)]
        assert len(ls) == len(lines) - 1, name
        out.append((name, "\n".join(ls) + "\n"))

    fr = {}
    ar = {}
    for l in lines:
        f = l.split()
        if f and f[0] == "FRAME":
            fr[(int(f[1]), int(f[2]))] = (f[3], f[4])
        if f and f[0] == "AROOT":
            ar[int(f[1])] = f[2]
    # the boundary root moved to position 1 of part 1 (labels and data swapped)
    def swap12(text0):
        ls = text0.splitlines()
        i1 = [i for i, l in enumerate(ls) if l.startswith("FRAME 1 1 ")][0]
        i2 = [i for i, l in enumerate(ls) if l.startswith("FRAME 1 2 ")][0]
        a, b = ls[i1].split(), ls[i2].split()
        ls[i1] = " ".join(["FRAME", "1", "1", b[3], b[4]])
        ls[i2] = " ".join(["FRAME", "1", "2", a[3], a[4]])
        return "\n".join(ls) + "\n"
    out.append(("frame: B at position 1 of part 1", swap12(text)))
    sub(lambda l: l.startswith("FRAME 0 2 "), lambda l: l.replace(" 42 ", " 41 "), "frame: part 0's position 2 labelled A")
    sub(lambda l: l.startswith("FRAME 2 0 "), lambda l: l.rsplit(" ", 1)[0] + " " + (1).to_bytes(8, "little").hex(),
        "frame: part 2's stage index wrong")
    sub(lambda l: l.startswith("OPEN 1 "), lambda l: l.replace("root=" + fr[(0, 2)][1], "root=" + fr[(1, 2)][1]),
        "open: block 0 against its own root")
    sub(lambda l: l.startswith("OPEN 1 "), lambda l: l.replace("root=" + fr[(0, 2)][1], "root=" + ar[0]),
        "open: block 0 against stage IN-C's A root")
    sub(lambda l: l.startswith("OPEN 2 "), lambda l: l.replace("root=" + fr[(1, 2)][1], "root=" + fr[(0, 2)][1]),
        "open: block 1 against B_in")
    sub(lambda l: l.startswith("OPEN 3 "), lambda l: l.replace("root=" + fr[(2, 2)][1], "root=" + fr[(1, 2)][1]),
        "open: stage OUT-C against block 0's root")
    sub(lambda l: l.startswith("OPEN 2 "), lambda l: l.replace(" pending=", " pending=9"), "claims: block 1's pending count")
    sub(lambda l: l.startswith("OPEN 1 "), lambda l: l.rsplit(" in=", 1)[0] + " in=0", "claims: block 0 hands no incoming claim")
    drop(lambda l: l.startswith("NEG 2 OutHere "), "neg: block 1's OutHere control missing")
    sub(lambda l: l.startswith("REFUSED "), lambda l: "REFUSED 10", "neg: refused count")
    drop(lambda l: l.startswith("FRAME 1 4 "), "frame: part 1's fifth absorb missing")
    return out


def main():
    path = sys.argv[1]
    text = open(path).read()
    fails, n = check(text)
    head, frames, aroots, opens, carries, negs, refused, done = parse(text)
    L = len(frames) - 1
    print("l56_bnd_check: %s: %d checks, %d failures" % (path, n, len(fails)))
    for f in fails:
        print("  FAIL", f)
    for k in range(L):
        print("  block %d (part %d): input boundary = part %d frame position 2 = run position off %d + 2; output boundary"
              " = part %d frame position 2 = off %d + 2; opened by part %d (pending %d, incoming %d) and part %d"
              % (k, k + 1, k, k, k + 1, k + 1, k + 1, opens[k + 1][1], opens[k + 1][2], k + 2))
    rc = 0 if not fails else 1
    if "--negative" in sys.argv:
        ms = mutations(text)
        caught = 0
        for name, t in ms:
            fl, _ = check(t)
            ok = len(fl) > 0
            caught += ok
            print("  negative %-45s %s" % (name, "refused (%s)" % fl[0] if ok else "NOT REFUSED"))
        print("l56_bnd_check negative: %d of %d single changes refused" % (caught, len(ms)))
        if caught != len(ms):
            rc = 1
    sys.exit(rc)


if __name__ == "__main__":
    main()
