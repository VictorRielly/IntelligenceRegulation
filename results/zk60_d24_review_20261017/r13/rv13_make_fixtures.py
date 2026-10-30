"""D24 review R13: the reviewer's own GENERIC public synthetic R13 exports, plus
doctored variants for the trained-door refusal tests.

Sol's dense fixtures use weights in [-2, 2] and constant gains 64, so their
scores span only [-4, 3] and no weight is near the int8 edge. These fixtures use
random int8 weights over the whole symmetric class (with explicit +-127 entries),
random signed gains, and an input row engineered so that the attention norm
output y hits exactly -32768 (a widened-word endpoint).
Outputs are computed with the reviewer's independent reference
(reviewer_export_reference.py), never with native code.

Writes under ops/zkp-mvp/trained-1b-review-r13-scratch/loader-fixtures-rv/ (reviewer scratch).
"""
import hashlib
import json
import math
import os
import shutil
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import reviewer_export_reference as R  # noqa: E402

S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r13-scratch"
SRC = f"{S}/loader-fixtures/r13-h24-wide"
OUT = f"{S}/loader-fixtures-rv"
T, WIDTH, Q, KV, HID = 32, 384, 1024, 512, 768
HEADS, KVH, DH = 16, 8, 64


def sha(b):
    return hashlib.sha256(b).hexdigest()


def put(d, name, arr, dtype):
    m = json.load(open(f"{d}/layer_00/manifest.json"))
    b = np.asarray(arr).astype(dtype).tobytes()
    open(f"{d}/layer_00/{name}.bin", "wb").write(b)
    m["arrays"][name] = {"dtype": {np.int8: "int8", np.int16: "int16", np.int64: "int64"}[dtype],
                         "file": f"{name}.bin", "sha256": sha(b), "shape": list(np.asarray(arr).shape)}
    json.dump(m, open(f"{d}/layer_00/manifest.json", "w"), indent=2, sort_keys=True)


def set_constants(d, **kw):
    m = json.load(open(f"{d}/layer_00/manifest.json"))
    m["constants"].update(kw)
    json.dump(m, open(f"{d}/layer_00/manifest.json", "w"), indent=2, sort_keys=True)
    p = json.load(open(f"{d}/profile.json"))
    p["profile_constants"].update(kw)
    json.dump(p, open(f"{d}/profile.json", "w"), indent=2, sort_keys=True)


def seal(d, variant, stack):
    mb = open(f"{d}/layer_00/manifest.json", "rb").read()
    p = json.load(open(f"{d}/profile.json"))
    p["layers"][0]["manifest_sha256"] = sha(mb)
    p["variant"] = variant
    p["accuracy_stack"] = stack
    p["calibration_tool"] = {"path": "results/zk60_d24_review_20261017/r13/rv13_make_fixtures.py",
                             "sha256": sha(open(os.path.abspath(__file__), "rb").read())}
    json.dump(p, open(f"{d}/profile.json", "w"), indent=2, sort_keys=True)


def put_seq(d, x, x2):
    os.makedirs(f"{d}/seq_public", exist_ok=True)
    m = {"kind": "sequence", "arrays": {}}
    for k, a in [("x_in_L00", x), ("x_out_L00", x2)]:
        b = np.asarray(a).astype(np.int16).tobytes()
        open(f"{d}/seq_public/{k}.bin", "wb").write(b)
        m["arrays"][k] = {"file": f"{k}.bin", "dtype": "int16", "shape": [T, WIDTH], "sha256": sha(b)}
    json.dump(m, open(f"{d}/seq_public/manifest.json", "w"), indent=2)


def fresh(name):
    d = f"{OUT}/{name}"
    if os.path.exists(d):
        shutil.rmtree(d)
    os.makedirs(d)
    shutil.copy(f"{SRC}/profile.json", f"{d}/profile.json")
    shutil.copytree(f"{SRC}/layer_00", f"{d}/layer_00")
    return d


def weights(rng):
    def mat(shape, sigma):
        w = np.clip(np.rint(rng.normal(0, sigma, shape)), -127, 127).astype(np.int64)
        flat = w.reshape(-1)
        flat[rng.choice(flat.size, 8, replace=False)] = 127
        flat[rng.choice(flat.size, 8, replace=False)] = -127
        return w
    W = {"wq": mat((Q, WIDTH), 22), "wk": mat((KV, WIDTH), 22), "wv": mat((KV, WIDTH), 30),
         "wo": mat((WIDTH, Q), 30), "wg_t": mat((WIDTH, HID), 22), "wu_t": mat((WIDTH, HID), 22),
         "wd_t": mat((HID, WIDTH), 10)}
    # the endpoint column (input coordinate 0) stays small so the -32768 row is legal downstream
    for k in ["wq", "wk", "wv"]:
        W[k][:, 0] = np.clip(W[k][:, 0], -2, 2)
    for k in ["wg_t", "wu_t"]:
        W[k][0, :] = np.clip(W[k][0, :], -2, 2)
    sign = rng.choice([-1, 1], WIDTH)
    W["gamma_a"] = sign * rng.integers(20, 128, WIDTH)
    W["gamma_m"] = rng.choice([-1, 1], WIDTH) * rng.integers(20, 128, WIDTH)
    W["gamma_a"][0] = 127
    W["gamma_m"][0] = 100
    return W


def endpoint_row(rng, cn):
    """x row with y_0 = round(127*cn*x_0/(4*D)) == -32768 exactly (tn' = 2, ceps = 1)."""
    tail = rng.integers(-1, 2, WIDTH - 1) * rng.integers(300, 1400, WIDTH - 1)
    for X in range(6000, 30000):
        for scale_num in range(90, 111):
            r = tail * scale_num // 100
            D = math.isqrt(1 + X * X + int((r * r).sum()))
            num = 2 * (-X) * 127 * cn + 4 * D
            if num // (8 * D) == -32768:
                return np.concatenate([[-X], r]).astype(np.int64)
    raise SystemExit("no endpoint row")


def main():
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for name, stack, groups, seed in [("rv-generic-h24", "low-h24-v1", [(-4, -13), (-3, -12), (-2, -11), (-1, -9)], 1301),
                                      ("rv-generic-low", "low-v1", [(-4, -13), (-1, -9)], 1302)]:
        rng = np.random.default_rng(seed)
        cn = 2000
        for attempt in range(60):
            W = weights(rng)
            x = rng.integers(-9000, 9001, (T, WIDTH)).astype(np.int64)
            x[5] = rng.integers(-300, 301, WIDTH)        # a quiet row
            x[7, :16] = rng.integers(-30000, 30001, 16)  # a concentrated row
            x[7, 16:] = rng.integers(-400, 401, WIDTH - 16)
            x[0] = endpoint_row(rng, cn)
            L = R.load_layer(SRC, 0)
            for k, v in W.items():
                L[k] = v
            L["c"] = dict(L["c"], norm_cn_a=cn, norm_cn_m=cn)
            L["silu_groups"] = np.array(groups, dtype=np.int64)
            L["silu_group_ids"] = np.arange(HID) % len(groups)
            L["act"] = np.stack([R.silu_table(*g) for g in groups])
            st = "h24" if stack == "low-h24-v1" else "low"
            try:
                tr = R.block(L, x, st, HEADS, KVH, DH)
            except R.Refusal as e:
                print(name, attempt, "refused", e)
                continue
            if tr["y"].min() != -32768:
                print(name, attempt, "endpoint missed", tr["y"].min(), tr["nm"].min())
                continue
            if tr["s"].max() - tr["s"].min() < 60:
                print(name, attempt, "scores too narrow", tr["s"].min(), tr["s"].max())
                continue
            break
        else:
            raise SystemExit(f"{name}: no admissible generic fixture")
        d = fresh(name)
        for k in ["wq", "wk", "wv", "wo", "wg_t", "wu_t", "wd_t", "gamma_a", "gamma_m"]:
            put(d, k, W[k], np.int8)
        put(d, "silu_groups", L["silu_groups"], np.int64)
        put(d, "silu_group_ids", L["silu_group_ids"], np.int64)
        put(d, "act", L["act"], np.int16)
        set_constants(d, norm_cn_a=cn, norm_cn_m=cn)
        seal(d, name, stack)
        put_seq(d, x, tr["x2"])
        np.save(f"{OUT}/{name}.reference.npy", {k: v for k, v in tr.items() if isinstance(v, np.ndarray)}, allow_pickle=True)
        report[name] = {k: [int(v.min()), int(v.max()), int((v != 0).sum()), int(v.size)] for k, v in tr.items() if isinstance(v, np.ndarray)}
        report[name]["attempt"] = attempt
        print(name, json.dumps(report[name]))

    # ---- doctored variants of rv-generic-h24 (trained-door refusals)
    base = f"{OUT}/rv-generic-h24"

    def variant(vname, fn, stack="low-h24-v1"):
        d = f"{OUT}/{vname}"
        if os.path.exists(d):
            shutil.rmtree(d)
        shutil.copytree(base, d)
        fn(d)
        seal(d, vname, stack)

    def w128(d):
        w = np.fromfile(f"{d}/layer_00/wq.bin", dtype=np.int8).reshape(Q, WIDTH).copy(); w[3, 5] = -128
        put(d, "wq", w, np.int8)

    def g128(d):
        g = np.fromfile(f"{d}/layer_00/gamma_m.bin", dtype=np.int8).copy(); g[9] = -128
        put(d, "gamma_m", g, np.int8)

    def scaled(d):
        a = np.fromfile(f"{d}/layer_00/act.bin", dtype=np.int16).astype(np.int64).reshape(4, 4096) * 256
        put(d, "scaled_act", a, np.int64)

    def act_doc(d):
        a = np.fromfile(f"{d}/layer_00/act.bin", dtype=np.int16).reshape(4, 4096).copy(); a[2, 3000] += 1
        put(d, "act", a, np.int16)

    def five(d):
        g = [(-4, -13), (-3, -12), (-2, -11), (-1, -10), (-1, -9)]
        put(d, "silu_groups", np.array(g), np.int64)
        put(d, "silu_group_ids", np.arange(HID) % 5, np.int64)
        put(d, "act", np.stack([R.silu_table(*m) for m in g]), np.int16)

    def std08(d):
        g = [(-4, -13), (-3, -12), (-2, -11), (0, -8)]
        put(d, "silu_groups", np.array(g), np.int64)
        put(d, "act", np.stack([R.silu_table(*m) for m in g]), np.int16)

    def swap(d):
        ids = np.fromfile(f"{d}/layer_00/silu_group_ids.bin", dtype=np.int64).copy()
        assert ids[0] != ids[1]
        ids[0], ids[1] = ids[1], ids[0]
        put(d, "silu_group_ids", ids, np.int64)

    def mzero(d):
        m = np.fromfile(f"{d}/layer_00/m_g.bin", dtype=np.int64).copy(); m[4] = 0
        put(d, "m_g", m, np.int64)

    def mwide(d):
        m = np.fromfile(f"{d}/layer_00/m_o.bin", dtype=np.int64).copy(); m[4] = 257
        put(d, "m_o", m, np.int64)

    for vname, fn in [("rv-w128", w128), ("rv-gamma128", g128), ("rv-scaled-act", scaled), ("rv-act-doctored", act_doc),
                      ("rv-five-groups", five), ("rv-std-08", std08), ("rv-group-swap", swap), ("rv-mg-zero", mzero),
                      ("rv-mo-257", mwide)]:
        variant(vname, fn)
    # a legacy-schema export that names an R13 stack (must be refused by name)
    variant("rv-legacy-names-r13", lambda d: None)
    p = json.load(open(f"{OUT}/rv-legacy-names-r13/profile.json")); p["schema"] = "zk60-trained-profile-export/1"
    json.dump(p, open(f"{OUT}/rv-legacy-names-r13/profile.json", "w"), indent=2, sort_keys=True)
    json.dump(report, open(f"{HERE}/rv13_fixtures.json", "w"), indent=1)
    print("written", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
