"""D24 review R13: the reviewer's independent integer reference of one R13 block,
reading an R13 export layer directly (numpy int64, exact; no float except the
public SiLU generator). Written from the S2 spec and coordinator notes (see
reviewer_block_reference.py for the arithmetic list), NOT from Sol's code.

Library use: load_layer(dir) -> L; block(L, x, stack) -> dict of trace arrays.
CLI: python3 -I reviewer_export_reference.py <export_dir> <layer> <x_in.bin> <x_out.bin|-> <stack low|h24> <out.json>
"""
import json
import math
import sys

import numpy as np

STD = [(-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11), (-2, -11), (-1, -11), (-1, -10), (-1, -9)]


class Refusal(Exception):
    pass


def rnd(n, s):
    n = np.asarray(n, dtype=np.int64)
    return (n + (np.int64(1) << np.int64(s - 1))) >> np.int64(s)


def check(a, lo, hi, what):
    a = np.asarray(a)
    if a.size and (a.min() < lo or a.max() > hi):
        raise Refusal(f"{what}: range [{a.min()}, {a.max()}] outside [{lo}, {hi}]")
    return a


def silu_table(e_in, e_out):
    out = []
    for g in range(-2048, 2048):
        x = g * 2.0 ** (e_in - 4)
        v = x / (1.0 + math.exp(-x))
        w = math.floor(v / 2.0 ** e_out + 0.5)
        if (e_in, e_out) in STD:
            w = max(-32767, min(32767, w))
        elif not -32767 <= w <= 32767:
            raise Refusal("silu member output exceeds signed16")
        out.append(w)
    return np.array(out, dtype=np.int64)


def load_layer(d, layer=0):
    m = json.load(open(f"{d}/layer_{layer:02d}/manifest.json"))
    L = {"c": m["constants"]}
    dt = {"int8": np.int8, "int16": np.int16, "int64": np.int64}
    for k, a in m["arrays"].items():
        L[k] = np.fromfile(f"{d}/layer_{layer:02d}/{a['file']}", dtype=dt[a["dtype"]]).reshape(a["shape"]).astype(np.int64)
    return L


def norm(x, gamma, cn, tn, ceps):
    tn2 = tn - 8
    ss = ceps + (x * x).sum(axis=1)
    D = np.array([math.isqrt(int(v)) for v in ss], dtype=np.int64)
    num = 2 * x * gamma[None, :] * cn + (D[:, None] << tn2)
    den = 2 * (D[:, None] << tn2)
    y = np.floor_divide(num, den)
    return check(y, -32768, 32767, "norm"), D


def block(L, x, stack, heads, kv_heads, head_dim, base_member=None):
    c = L["c"]
    T = x.shape[0]
    tn, cn_a, cn_m, ceps = c["norm_tn"], c["norm_cn_a"], c["norm_cn_m"], c["norm_ceps"]
    sq, ss_, so, sao, sg, sh, sz = c["sh_qkv"], c["sh_s"], c["sh_o"], c["sh_ao"], c["sh_g"], c["sh_h"], c["sh_z"]
    bin_, bout = c["silu_member"] if base_member is None else base_member
    for k in ["wq", "wk", "wv", "wo", "wg_t", "wu_t", "wd_t", "gamma_a", "gamma_m"]:
        if (L[k] == -128).any():
            raise Refusal(f"{k}: -128")
    tr = {"x": x}
    y, D = norm(x, L["gamma_a"], cn_a, tn, ceps)
    tr["y"] = y
    q = check(rnd((y @ L["wq"].T) * L["m_q"][None, :], sq + 7), -32768, 32767, "q")
    k = check(rnd((y @ L["wk"].T) * L["m_k"][None, :], sq + 7), -32768, 32767, "k")
    v = check(rnd((y @ L["wv"].T) * L["m_v"][None, :], sq + 8), -32768, 32767, "v")
    half = head_dim // 2
    if "rope_cos" in L:
        cos, sin = L["rope_cos"], L["rope_sin"]
    else:  # unscaled profile: the frozen public generator (tables_attn::rope_tables_generate)
        theta = c["rope_theta"]
        cos = np.zeros((T, half), dtype=np.int64)
        sin = np.zeros((T, half), dtype=np.int64)
        for i in range(half):
            w = theta ** (-2.0 * i / head_dim)
            for t in range(T):
                cos[t, i] = math.floor(math.cos(t * w) * 128 + 0.5)
                sin[t, i] = math.floor(math.sin(t * w) * 128 + 0.5)

    def rope(a, nh):
        a = a.reshape(T, nh, head_dim)
        lo, hi = a[:, :, :half], a[:, :, half:]
        cc, s = cos[:T, None, :], sin[:T, None, :]
        o = np.concatenate([cc * lo - s * hi, s * lo + cc * hi], axis=2)
        return check(rnd(o, 7), -32768, 32767, "rope").reshape(T, nh * head_dim)

    qr, kr = rope(q, heads), rope(k, kv_heads)
    tr.update(q=q, k=k, v=v, qr=qr, kr=kr)
    grp = heads // kv_heads
    Q = qr.reshape(T, heads, head_dim)
    K = kr.reshape(T, kv_heads, head_dim)
    V = v.reshape(T, kv_heads, head_dim)
    sacc = np.einsum("thd,jhd->htj", Q, np.repeat(K, grp, axis=1))
    s = check(rnd(sacc, ss_ + 12), -127, 127, "score (all T x T, masked included)")
    exp = L["exp"]
    P = np.zeros((heads, T, T), dtype=np.int64)
    for h in range(heads):
        for t in range(T):
            mx = s[h, t, : t + 1].max()
            e = exp[mx - s[h, t, : t + 1]]
            tot = int(e.sum())
            P[h, t, : t + 1] = (e << 12) // tot
    oacc = np.einsum("htj,jhd->thd", P, np.repeat(V, grp, axis=1)).reshape(T, heads * head_dim)
    o = check(rnd(oacc, so + 3), -32768, 32767, "pv")
    ao = check(rnd((o @ L["wo"].T) * L["m_o"][None, :], sao + 14), -32768, 32767, "ao")
    x1 = check(x + ao, -32768, 32767, "res1")
    nm, Dm = norm(x1, L["gamma_m"], cn_m, tn, ceps)
    tr.update(s=s, p=P, o=o, ao=ao, x1=x1, nm=nm)
    groups = [tuple(g) for g in L["silu_groups"].tolist()]
    gid = L["silu_group_ids"]
    tabs = [silu_table(*g) for g in groups]
    act_ok = all((L["act"][i] == tabs[i]).all() for i in range(len(groups)))
    ein = np.array([groups[g][0] for g in gid])
    eout = np.array([groups[g][1] for g in gid])
    gacc = (nm @ L["wg_t"]) * L["m_g"][None, :]
    gsh = sg + 10 + (ein - bin_)
    gate = check(np.stack([rnd(gacc[:, j], int(gsh[j])) for j in range(gacc.shape[1])], axis=1), -2048, 2047, "gate")
    a = np.stack([tabs[gid[j]][gate[:, j] + 2048] for j in range(gacc.shape[1])], axis=1)
    u = check(rnd((nm @ L["wu_t"]) * L["m_u"][None, :], 12), -32768, 32767, "up")
    H = sh - 8 if stack == "h24" else sh
    # exact: h = round(a*u*2^(eout-bout) / 2^H) -- group scale before the single rounding
    e = (eout - bout)[None, :] - H  # total exponent
    prod = a * u
    hv = np.where(e >= 0, prod << np.maximum(e, 0), 0)
    neg = e < 0
    sh_e = np.maximum(-e, 1)
    hv = np.where(neg, (prod + (np.int64(1) << (sh_e - 1))) >> sh_e, hv)
    lim = (1 << 23) if stack == "h24" else (1 << 15)
    hv = check(hv, -lim, lim - 1, "h")
    dsh = sz + 6 + (8 if stack == "h24" else 0)
    z = check(rnd((hv @ L["wd_t"]) * L["m_d"][None, :], dsh), -32768, 32767, "down")
    x2 = check(x1 + z, -32768, 32767, "res2")
    tr.update(gate=gate, a_raw=a, u=u, h=hv, z=z, x2=x2)
    tr["act_tables_equal_reviewer_generator"] = act_ok
    return tr


def main():
    d, layer, xin, xout, stack, outp = sys.argv[1:7]
    heads, kv_heads, head_dim = [int(v) for v in sys.argv[7:10]] if len(sys.argv) > 9 else (32, 8, 128)
    L = load_layer(d, int(layer))
    width = L["gamma_a"].shape[0]
    x = np.fromfile(xin, dtype=np.int16).astype(np.int64).reshape(-1, width)
    res = {"export": d, "layer": int(layer), "stack": stack}
    try:
        tr = block(L, x, stack, heads, kv_heads, head_dim)
    except Refusal as e:
        res["refusal"] = str(e)
        json.dump(res, open(outp, "w"), indent=1)
        print(json.dumps(res))
        return
    res["act_tables_equal_reviewer_generator"] = bool(tr.pop("act_tables_equal_reviewer_generator"))
    np.savez_compressed(outp + ".npz", **tr)
    res["ranges"] = {k: [int(v.min()), int(v.max()), int((v != 0).sum()), int(v.size)] for k, v in tr.items()}
    if xout != "-":
        want = np.fromfile(xout, dtype=np.int16).astype(np.int64).reshape(-1, width)
        res["x2_differ"] = int((want != tr["x2"]).sum())
        res["x2_n"] = int(want.size)
    json.dump(res, open(outp, "w"), indent=1)
    print(json.dumps(res))


if __name__ == "__main__":
    main()
