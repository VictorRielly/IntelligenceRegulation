#!/usr/bin/env python3
"""D63 lane L36 (2026-11-09): the negative control of BlockAlgCheck. Writes a copy of L17's shape corpus with FIVE
single changes, outside the repository, and prints them. BlockAlgCheck on the copy must fail exactly 7 checks:
  1. the W16R2 rung's SHAPE lh 4 -> 3                      (ALG-NUMBERS, 1)
  2. the R13 rung's SHAPE helper count of Dom::D 17 -> 16  (HELPERS, 1)
  3. the Shieldstral R13 SHAPE log of Dom::Tab 14 -> 13    (LOGS, 1)
  4. the Shieldstral R13 SHAPE lf 14 -> 13                 (ALG-NUMBERS, 1)
  5. the W16R2 rung's LOOKUPS of Dom::S 9 -> 10            (LOOKUPS 1, COUNT 2)

usage: python3 -I l36_mutate.py <shape_corpus.txt> <out dir>
"""
import os
import sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
lines = open(src).read().split("\n")


def idx(profile, rec):
    i = lines.index("PROFILE " + profile)
    j = i + 1
    while not lines[j].startswith(rec + " "):
        j += 1
    return j


def sub(profile, rec, old, new):
    j = idx(profile, rec)
    assert lines[j].count(old) == 1, (profile, rec, old, lines[j])
    lines[j] = lines[j].replace(old, new)
    print("changed", profile, rec, old, "->", new)


W16 = "hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/2"
R13 = "hashline-zk-mr1/private-block-rung-lh-t32-dev/2"
SH = "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2"
sub(W16, "SHAPE", " lh=4 ", " lh=3 ")
sub(R13, "SHAPE", "helpers=0,0,1,17,", "helpers=0,0,1,16,")
sub(SH, "SHAPE", "logs=7,12,14,19,19,17,19,21,14 ", "logs=7,12,14,19,19,17,19,21,13 ")
sub(SH, "SHAPE", " lf=14 ", " lf=13 ")
sub(W16, "LOOKUPS", "S:9", "S:10")
open(os.path.join(out, "l36_mut_shape.txt"), "w").write("\n".join(lines))
