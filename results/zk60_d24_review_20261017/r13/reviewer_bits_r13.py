"""D24 review R13: whole-run lookup soundness term, recounted by the reviewer.

Written from the frozen R13 source as READ (accuracy_layout.rs lookups, shape.rs
a_plane_doms / natural_log / domain lift, accuracy_act.rs table), not from Sol's
census script. It compares with Sol's NATIVE_LAYOUT_CENSUS.json at the end.

Per block (reviewer's derivation, CHECK.md section 3 extended to degree-2 tuples):
  B1 (first bad query collides with a table tuple, degree <= 2 in (beta, gamma)):  2*T_d
  B2 (alpha at an equal-pair pole or a table pole):                                |PP| + T_d
  B3 (alpha identity; Schwartz-Zippel in alpha):                                     |V| + T_d - 1
  with |V| + |PP| <= N  =>  term <= (N + 4*T_d - 1) / p^2
  N   = byte lookups over padded/lifted domains + |S| exp + |F| ACT3 (+ |S| DD tuple queries)
  T_d = 256 (U8) + 256 (EXP) + 4096*groups (ACT3) (+ |Dd| DD tuples)
Run = union over the L blocks (D15 reading, as in R12 and CHECK.md).
Sol's conservative proposal 2*(positions-1)/p^2 (positions = N + tables) is printed beside it.
"""
import json
import math
import sys

P = 2**64 - 2**32 + 1
F = P * P


def clog2(n):
    return (n - 1).bit_length()


def npow2(n):
    return 1 << clog2(n)


GEOS = {
    # name: (width, hidden, q_heads, head_dim, kv_heads, blocks)
    "tinyllama": (2048, 5632, 32, 64, 4, 22),
    "llama3-8b": (4096, 14336, 32, 128, 8, 32),
    "shieldstral": (3072, 9216, 32, 128, 8, 26),
    "rung": (384, 768, 16, 64, 8, 1),
}
DD_CAP = 32


def sizes(geo, T, log_cols, dd):
    width, hidden, qh, dh, kv, _ = GEOS[geo]
    t_pad, d_pad, f_pad = npow2(T), npow2(width), npow2(hidden)
    h_pad = kv * npow2(qh // kv)
    nat = {
        "T": clog2(t_pad), "Ht": clog2(h_pad * t_pad), "L": clog2(16 * t_pad),
        "D": clog2(t_pad * d_pad), "Q": clog2(t_pad * h_pad * dh), "Kv": clog2(t_pad * kv * dh),
        "S": clog2(h_pad * t_pad * t_pad), "F": clog2(t_pad * f_pad), "Tab": clog2(256),
        "Dd": clog2(h_pad * t_pad * DD_CAP),
    }
    out = {}
    for k, v in nat.items():
        carries = k not in ("T", "Ht")
        out[k] = 1 << (log_cols if carries and v < log_cols else v)
    if not dd:
        out.pop("Dd")
    return out


def count(geo, T, log_cols, stack, dd, groups, f_e=9):
    s = sizes(geo, T, log_cols, dd)
    wrho_s = clog2(T) + f_e
    ls = (wrho_s + 7) // 8
    lpp = {"L": 2, "D": 34 if stack == "h24" else 33, "Q": 14, "Kv": 14, "F": 14,
           "S": 6 if dd else 11 + 2 * ls}
    if dd:
        lpp["Dd"] = 5 + 2 * ls
    byte = sum(s[d] * n for d, n in lpp.items())
    n = byte + s["S"] + s["F"] + (s["S"] if dd else 0)
    t_dd = s["Dd"] if dd else 0
    t_d = 512 + 4096 * groups + t_dd
    blocks = GEOS[geo][5]
    derived = (n + 4 * t_d - 1) / F
    positions = n + 512 + 4096 * groups + t_dd
    sol = 2 * (positions - 1) / F
    return {
        "geometry": geo, "T": T, "log_cols": log_cols, "stack": stack, "dd": dd, "groups": groups,
        "wrho_s": wrho_s, "ls": ls, "byte_queries": byte, "exp_queries": s["S"], "act_queries": s["F"],
        "dd_queries": s["S"] if dd else 0, "dd_table": t_dd, "N": n, "T_d": t_d, "blocks": blocks,
        "per_block_bits": -math.log2(derived), "run_bits": -math.log2(blocks * derived),
        "sol_per_block_bits": -math.log2(sol), "sol_run_bits": -math.log2(blocks * sol),
        "positions": positions,
    }


def main():
    out = json.load(open(sys.argv[1])) if False else {}
    rows = []
    cases = [
        ("tinyllama", 128, 14, "low"),
        ("llama3-8b", 128, 14, "h24"),
        ("llama3-8b", 512, 15, "h24"),   # counted only; not registered in R13
        ("llama3-8b", 512, 16, "h24"),   # counted only; recount's projected row width
        ("shieldstral", 128, 14, "h24"),
        ("shieldstral", 256, 15, "h24"),
        ("shieldstral", 512, 15, "h24"),  # counted only
        ("rung", 32, 14, "low"),
        ("rung", 32, 14, "h24"),
    ]
    for geo, T, lc, stack in cases:
        for dd in (False, True):
            for g in (1, 4):
                rows.append(count(geo, T, lc, stack, dd, g))
    census = json.load(open(sys.argv[1]))["rows"]
    checks = []
    for c in census:
        geo = {2048: "tinyllama", 4096: "llama3-8b", 3072: "shieldstral", 384: "rung"}[c["width"]]
        T = c["tokens"]
        lc = clog2(c["n"])
        stack = "h24" if ("lh24" in c["profile"] or "lowh24" in c["profile"] or "-lh-" in c["profile"] or "-hh-" in c["profile"]) else "low"
        mine = count(geo, T, lc, stack, c["dd"], c["groups"], c["f_e"])
        same = (mine["byte_queries"], mine["exp_queries"], mine["act_queries"], mine["dd_queries"], mine["positions"]) == \
               (c["byte_queries"], c["exp_queries"], c["act_queries"], c["dd_queries"], c["lookup_positions"])
        checks.append({"profile": c["profile"], "f_e": c["f_e"], "groups": c["groups"], "dd": c["dd"], "stack": stack,
                       "match": same, "mine_byte": mine["byte_queries"], "census_byte": c["byte_queries"],
                       "mine_positions": mine["positions"], "census_positions": c["lookup_positions"]})
    res = {"rows": rows, "census_checks": checks, "census_rows": len(checks),
           "census_all_match": all(c["match"] for c in checks)}
    json.dump(res, open(sys.argv[2], "w"), indent=1)
    for r in rows:
        print(f"{r['geometry']:11s} T{r['T']:<4d} 2^{r['log_cols']} {r['stack']:3s} dd={int(r['dd'])} G{r['groups']} "
              f"N={r['N']:>12,d} block 2^-{r['per_block_bits']:.2f} run({r['blocks']}) 2^-{r['run_bits']:.2f} "
              f"[Sol-form run 2^-{r['sol_run_bits']:.2f}]")
    print("census rows", len(checks), "all match:", res["census_all_match"])
    for c in checks:
        if not c["match"]:
            print("MISMATCH", c)


if __name__ == "__main__":
    main()
