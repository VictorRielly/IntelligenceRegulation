"""GS-12 adversarial check: act[128] re-measured with my own code, without
assuming which LogUp challenge is beta and which is gamma (every ordered pair
of the capture's three replayed challenges is tried; exactly one table and
one ordering must invert every true row to an i16), plus the padded-row
pattern and the Dom::F padding from the shape.  Read-only.

Row rule (argument.rs:1067-1069 at lane 2ea7221): t_i = i + beta*act[i] + TAG_ACT*gamma,
TAG_ACT = 134 (hashline/src/tables_attn.rs:77).
"""

from __future__ import annotations

import hashlib
import itertools
import json
import os

P = 2**64 - 2**32 + 1
NR = 7
TAG_ACT = 134
LANE = "/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g"
ART = "/home/victor/zk60-artifacts/block-captures-20260923"
BUNDLES = [("rung-G dense", f"{LANE}/rung-g-dense"), ("rung-G zero", f"{LANE}/rung-g-zero"),
           ("125M dense", f"{ART}/m125-dense"), ("125M zero", f"{ART}/m125-zero")]


def mul(x, y):
    return ((x[0] * y[0] + NR * x[1] * y[1]) % P, (x[0] * y[1] + x[1] * y[0]) % P)


def inv(x):
    nrm = (x[0] * x[0] - NR * x[1] * x[1]) % P
    i = pow(nrm, P - 2, P)
    return (x[0] * i % P, (-x[1]) * i % P)


def arr(bundle, ref):
    if isinstance(ref, list):
        return [tuple(v) for v in ref]
    with open(os.path.join(bundle, "arrays.bin"), "rb") as f:
        f.seek(ref["offset"])
        raw = f.read(ref["bytes"])
    assert hashlib.sha256(raw).hexdigest() == ref["array"]
    return [(int.from_bytes(raw[16 * k:16 * k + 8], "little"), int.from_bytes(raw[16 * k + 8:16 * k + 16], "little"))
            for k in range(ref["len"])]


def i16(v):
    if v[1] != 0:
        return None
    s = v[0] if v[0] <= P // 2 else v[0] - P
    return s if -32768 <= s <= 32767 else None


def main():
    out = []
    for label, b in BUNDLES:
        obs = json.load(open(os.path.join(b, "observations.json")))
        blk = json.load(open(os.path.join(b, "block.json")))
        sh = blk["shape"]
        ch = [tuple(c) for c in obs["logup_challenges"]]
        slot = [a for a in obs["arguments"] if a["slot"] == 19][0]
        hits = []
        for ti, t in enumerate(slot["tables"]):
            if not isinstance(t, dict) or "values" not in t:
                continue
            vals = arr(b, t["values"])
            for bi, gi in itertools.permutations(range(len(ch)), 2):
                beta, gamma = ch[bi], ch[gi]
                binv = inv(beta)
                g = mul(gamma, (TAG_ACT, 0))
                acts = []
                for i in range(256):
                    x = ((vals[i][0] - i - g[0]) % P, (vals[i][1] - g[1]) % P)
                    acts.append(i16(mul(x, binv)))
                if all(a is not None for a in acts):
                    rep_mod = all(vals[i] == vals[i % 256] for i in range(len(vals)))
                    rep_last = all(vals[i] == vals[255] for i in range(256, len(vals)))
                    hits.append({"table": ti, "kind": t.get("kind"), "beta_index": bi, "gamma_index": gi,
                                 "len": len(vals), "act_128": acts[128], "act_0": acts[0], "act_255": acts[255],
                                 "padded_rows_repeat_i_mod_256": rep_mod, "padded_rows_repeat_row_255": rep_last})
        # Dom::F is the (t_pad, f_pad) cube; its true extent is (tokens, hidden)
        padF = sh["t_pad"] * sh["f_pad"] - sh["tokens"] * sh["hidden"]
        rec = {"bundle": label, "hits": hits, "DomF_positions": sh["t_pad"] * sh["f_pad"], "DomF_padded": padF,
               "log_cols": sh["log_cols"]}
        out.append(rec)
        print(json.dumps(rec))
    json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gs12_check.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
