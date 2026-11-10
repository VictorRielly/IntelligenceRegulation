#!/usr/bin/env python3
"""D63 lane L40 (2026-11-10): a one-off edit of l40_shield_export.py (kept for the record): add the geometry checks
(every table's shape is the Lean shape's: d 3072, T 128, half 64, 32 heads of 128, 8 key-value heads, hidden 9216) and
stage OUT-C's and stage IN-C's public data (the classifier's final norm and margin vector, the embedding's dtype and
shape) to the export check.

usage: python3 -I l40_edit_export.py <l40_shield_export.py>
"""
import sys

p = sys.argv[1]
s = open(p).read()
old = """        nG = len(members)
        ids = arr["silu_group_ids"]"""
new = """        nG = len(members)
        shapes = {k: man["arrays"][k]["shape"] for k in man["arrays"]}
        want = {"gamma_a": [3072], "gamma_m": [3072], "m_q": [4096], "m_k": [1024], "m_v": [1024], "m_o": [3072],
                "m_g": [9216], "m_u": [9216], "m_d": [3072], "rope_cos": [128, 64], "rope_sin": [128, 64],
                "exp": [256], "silu_group_ids": [9216], "act": [nG, 4096], "wq": [4096, 3072], "wk": [1024, 3072],
                "wv": [1024, 3072], "wo": [3072, 4096], "wg_t": [3072, 9216], "wu_t": [3072, 9216],
                "wd_t": [9216, 3072]}
        for k, v in want.items():
            check(f"L{L} {k} shape = the Lean shape's", mut("shape", shapes.get(k)) == v, f"{shapes.get(k)} != {v}")
        for k in ["wq", "wk", "wv", "wo", "wg_t", "wu_t", "wd_t"]:
            check(f"L{L} {k} is int8 and hash-pinned", man["arrays"][k]["dtype"] == "int8"
                  and len(man["arrays"][k].get("sha256", "")) == 64)
        ids = arr["silu_group_ids"]"""
assert old in s
s = s.replace(old, new)
old2 = """    return lean


lean = run()"""
new2 = """    # stage OUT-C's public data (L15's `shield_outc_valid` classes) and stage IN-C's embedding (dtype, shape)
    tio = f"{EXP}/token_io"
    cl = json.load(open(f"{tio}/classifier.json"))
    fn = cl["final_norm"]
    check("OUT-C final norm g0 in [1, 127]", 1 <= mut("outc", fn["g0"]) <= 127)
    check("OUT-C final norm cn in [1, 2^20]", 1 <= fn["cn"] <= 2 ** 20)
    check("OUT-C final norm ceps in [1, 2^40]", 1 <= fn["ceps"] <= 2 ** 40)
    check("OUT-C final norm tn <= 16", fn["tn"] <= 16)
    check("OUT-C threshold c = 0", cl["threshold_c"] == 0)
    mv = cl["margin_vector"]
    raw = open(f"{tio}/{mv['file']}", "rb").read()
    check("OUT-C margin vector hash-pinned", sha(f"{tio}/{mv['file']}") == mv["sha256"])
    w = list(struct.unpack("<" + "h" * (len(raw) // 2), raw))
    check("OUT-C margin vector int16 of d = 3072", mv["dtype"] == "int16" and mv["shape"] == [3072] and len(w) == 3072)
    check("OUT-C margin vector in [-32767, 32767]", all(-32767 <= mut("margin", v) <= 32767 for v in w))
    ti = json.load(open(f"{tio}/token_io.json"))
    em = ti["embedding_table"]
    check("IN-C embedding int16 of (V, d) = (131072, 3072), hash-pinned", em["dtype"] == "int16"
          and mut("emb", em["shape"]) == [131072, 3072] and len(em["sha256"]) == 64)
    return lean


lean = run()"""
assert old2 in s
s = s.replace(old2, new2)
old3 = """kinds = ["profile_sha", "T", "const", "gid", "cal", "gamma", "mult", "mg", "rope", "exp", "act"]"""
new3 = """kinds = ["profile_sha", "T", "const", "gid", "cal", "gamma", "mult", "mg", "rope", "exp", "act", "shape", "outc",
         "margin", "emb"]"""
assert old3 in s
s = s.replace(old3, new3)
old4 = """        if kind == "gid":
            return 99
        return v + 1"""
new4 = """        if kind == "gid":
            return 99
        if kind in ("shape", "emb"):
            return [1]
        if kind == "outc":
            return 128
        if kind == "margin":
            return -32768
        return v + 1"""
assert old4 in s
s = s.replace(old4, new4)
s = s.replace('''  4. the public data's classes, `BlockPublic.Valid`'s non-weight fields (CircuitBlock.lean:191-213):''',
              '''  4. every table's shape is the Lean shape's (d 3072, T 128, half 64, 32 heads of 128, 8 key-value heads, hidden
     9216), and the seven weight arrays are int8 and hash-pinned (their bytes are not in the repository);
  5. the public data's classes, `BlockPublic.Valid`'s non-weight fields (CircuitBlock.lean:191-213):''')
s = s.replace('''A negative control repeats every check with one value changed (one per check kind) and requires each to fail.''',
              '''And once: stage OUT-C's public data in L15's `shield_outc_valid` classes (the classifier's final norm, `c = 0`, the
hash-pinned int16 margin vector of width 3072 with no -32768), and stage IN-C's embedding table int16 of shape
(131072, 3072), hash-pinned (its bytes are not in the repository; its dtype IS the int16 class).
A negative control repeats every check with one value changed (one per check kind) and requires each to fail.''')
open(p, "w").write(s)
print("edited")
