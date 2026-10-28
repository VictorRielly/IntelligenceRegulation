#!/usr/bin/env python3
"""NATIVE R12: copy the R9 recordings (r12/r12-golden-r9-run.log, produced in
r12/r9-golden-tree/) into the live tree's r12_golden_tests.rs: the four seeded
block digests (the two non-DD ones must equal R8 / R9's own) and the
synthetic statement identities."""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "r12-golden-r9-run.log")
SRC = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/src/private_block/r12_golden_tests.rs"
R8 = {"tinyllama-t128": "782b64c97a88cba4c6c34a2fecb73132f26d5f54adc9bd159f3d6cf9df4205c0", "llama3-8b-t128": "05a22d72a892aff5fb2e35da4d0ab0c894d696f2e6afa542b6ecece5aeb9f4db"}

text = open(LOG, errors="replace").read()
dig = dict(re.findall(r"R12-GOLDEN-DIGEST (\S+) ([0-9a-f]{64})", text))
ids = dict(re.findall(r"R12-GOLDEN-IDENTITY (\S+) ([0-9a-f]{64})", text))
want = ["tinyllama-t128", "llama3-8b-t128", "tinyllama-t128-dd", "llama3-8b-t128-dd"]
assert set(want) <= set(dig), f"missing recordings: {set(want) - set(dig)}"
for k, v in R8.items():
    assert dig[k] == v, f"{k}: the R9 copy's digest {dig[k]} is not the R8 golden {v}"
assert len(ids) == 5, ids
src = open(SRC).read()
g = "const GOLDEN: &[(&str, &str)] = &[\n" + "".join(f'    ("{k}", "{dig[k]}"),\n' for k in want) + "];"
src = re.sub(r"const GOLDEN: &\[\(&str, &str\)\] = &\[\n.*?\n\];", g, src, count=1, flags=re.S)
gi = "const GOLDEN_IDENTITIES: &[(&str, &str)] = &[\n" + "".join(f'    ("{k}", "{v}"),\n' for k, v in sorted(ids.items())) + "];"
src = re.sub(r"const GOLDEN_IDENTITIES: &\[\(&str, &str\)\] = &\[\];", gi, src, count=1)
assert "tinyllama-t128-dd" in src and "GOLDEN_IDENTITIES: &[(&str, &str)] = &[\n" in src
open(SRC, "w").write(src)
print("filled:", {k: dig[k][:16] for k in want}, {k: v[:16] for k, v in ids.items()})
