"""[UPERF3 AM] WHAT WITNESS VALUES DOES A PRODUCED PROOF CARRY IN THE CLEAR?

The empirical half of rung 0's answer (the other half is that StatementV3
carries no tensor values at all -- see the AM rung 0 note in
PROGRESS_UPERF3.md), and the acceptance test for rung 1's weight privacy.

Method: every aligned 8-byte little-endian word of the proof is read as a
Goldilocks field element and asked whether its signed representative lies
in the int8 class [-127, 127] (weights) or the int16 class [-32768, 32767]
(every v3 activation, the layer OUTPUT plane z16 included).  A uniform
field element lands in the int16 class with probability 2^17/p ~ 7e-15, so
in a hiding proof the count is zero up to the handful of small integers the
serializer itself writes (row counts, column indices).  What identifies a
LEAK rather than an artifact is a RUN: an opened systematic column of a
commitment is `rows` consecutive words of raw witness, and the columns
repeat at a fixed stride (1 index word + rows + 4 salt words if the
commitment is ZK + 4 words per Merkle digest).

Usage: python3 am_r0_output_scan.py <proof> [<proof> ...]
"""
import collections
import struct
import sys

P = (1 << 64) - (1 << 32) + 1
MIN_RUN = 100


def signed(v):
    return v - P if v > P // 2 else v


def scan(path):
    b = open(path, 'rb').read()
    n = len(b) // 8
    small8 = small16 = 0
    runs = []
    cur = 0
    start = 0
    for i in range(n):
        v = struct.unpack_from('<Q', b, i * 8)[0]
        s = signed(v) if v < P else None
        in8 = s is not None and -127 <= s <= 127
        in16 = s is not None and -32768 <= s <= 32767
        small8 += in8
        small16 += in16
        if in8:
            if cur == 0:
                start = i
            cur += 1
        else:
            if cur >= MIN_RUN:
                runs.append((start, cur))
            cur = 0
    if cur >= MIN_RUN:
        runs.append((start, cur))
    return len(b), n, small8, small16, runs


for path in sys.argv[1:]:
    nb, n, s8, s16, runs = scan(path)
    lens = collections.Counter(c for _, c in runs)
    strides = collections.Counter(runs[i + 1][0] - runs[i][0] for i in range(len(runs) - 1))
    print(path)
    print(f"  {nb} B = {n} aligned 8-byte words")
    print(f"  words in the int8 class  [-127, 127]:      {s8}")
    print(f"  words in the int16 class [-32768, 32767]:  {s16}   (uniform expectation: {n * 65537 / P:.2e})")
    print(f"  RUNS of >= {MIN_RUN} consecutive int8-class words: {len(runs)}, {sum(c for _, c in runs)} words")
    print(f"    run lengths:       {lens.most_common(6)}")
    print(f"    run-start strides: {strides.most_common(6)}")
    print(f"    first runs:        {runs[:4]}")
