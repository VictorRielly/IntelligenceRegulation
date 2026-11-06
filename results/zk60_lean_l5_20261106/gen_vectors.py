#!/usr/bin/env python3
"""D63 step L5 (2026-11-06): turn the official BLAKE3 test vectors (blake3_test_vectors.json, a copy of
test_vectors/test_vectors.json of github.com/BLAKE3-team/BLAKE3) into formal/ZK60Formal/L5Vectors.lean.

usage: python3 -I gen_vectors.py <json> <out.lean>
"""
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
assert d["key"] == "whats the Elvish word for friend"
assert d["context_string"] == "BLAKE3 2019-12-27 16:29:52 test vectors context"
out = ['''/-
D63 step L5: the OFFICIAL BLAKE3 test vectors, hard-coded (data only, no proofs).

Source: `test_vectors/test_vectors.json` of `github.com/BLAKE3-team/BLAKE3` (fetched 2026-11-06 from
`raw.githubusercontent.com/BLAKE3-team/BLAKE3/master/test_vectors/test_vectors.json`; the copy is
`results/zk60_lean_l5_20261106/blake3_test_vectors.json`, its sha256 in `results/zk60_lean_l5_20261106/README.md`).
Each case is an input length; the input is the repeating bytes `0, 1, …, 250`; the three outputs are 131 bytes of
extended output of `hash`, of `keyed_hash` under the key `"whats the Elvish word for friend"`, and of `derive_key` under
the context `"BLAKE3 2019-12-27 16:29:52 test vectors context"`. `L5Check.lean` checks `ExecBlake3.lean` against all of
them. Generated from the JSON by `results/zk60_lean_l5_20261106/gen_vectors.py`.
-/

namespace ZK60.Exec.Blake3Vectors

def key : String := "whats the Elvish word for friend"
def context : String := "BLAKE3 2019-12-27 16:29:52 test vectors context"

/-- (input length, hash, keyed_hash, derive_key), the outputs in hex (131 bytes each). -/
def cases : List (Nat × String × String × String) := [''']
cs = d["cases"]
for i, c in enumerate(cs):
    sep = "," if i < len(cs) - 1 else ""
    out.append(f'  ({c["input_len"]},\n   "{c["hash"]}",\n   "{c["keyed_hash"]}",\n   "{c["derive_key"]}"){sep}')
out.append("]\n\nend ZK60.Exec.Blake3Vectors\n")
open(dst, "w").write("\n".join(out))
print(len(cs), "cases; output length", len(cs[0]["hash"]) // 2, "bytes")
