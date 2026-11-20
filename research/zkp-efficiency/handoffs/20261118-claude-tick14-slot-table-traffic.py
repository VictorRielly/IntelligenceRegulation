#!/usr/bin/env python3
"""Tick 14 counting script (standard library only; reads dumped shader sources, the breakdown
summary and prints tables; runs nothing on a GPU). Inputs:
  DUMPS  /Users/victorrielly/zk60-artifacts/a27_shader_dumps_20261117/{w16r2_8b,r13_shield}/*.metal  (A27 slot libraries)
  SUMM   results/zk60_slot18_14_breakdown_20261117/summary.json   (Arm B unbatched per-round GPU ms, medians)
Everything printed is COUNTED (parse of the dump) or DERIVED (arithmetic on counted values and the summary's ms).
The live-table sets assume the Metal compiler removes a table load whose value no statement reaching `out`
uses (ASSUMED, not verified by a counter or an ISA dump).
"""
import json
import re
import sys
from pathlib import Path

DUMPS = Path("/Users/victorrielly/zk60-artifacts/a27_shader_dumps_20261117")
SUMM = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_slot18_14_breakdown_20261117/summary.json")
EB = 16  # bytes of one table element as stored (two u64 words, base tables too: stride 2)

REF = re.compile(r"\b([vnm]\d+)\b")


def kernel_text(src, name):
    a = src.index(f"kernel void {name}(")
    nxt = [src.find("kernel void ", a + 10)]
    b = nxt[0] if nxt[0] != -1 else len(src)
    return src[a:b]


def parse_body(txt):
    """-> (loads {v: (kind, space)}, defs {name: expr}, out_exprs [expr])"""
    loads, defs, outs = {}, {}, []
    for ln in txt.split("\n"):
        s = ln.strip()
        m = re.match(r"(fp2|ulong) (v\d+) = (ln_ext|ln_base)\((tabs|xtabs),", s)
        if m:
            loads[m.group(2)] = ("ext" if m.group(3) == "ln_ext" else "base", m.group(4))
            continue
        m = re.match(r"(fp2|ulong) (v\d+) = (tabs\[|f2\(tabs\[)", s)  # mat kernel loads
        if m:
            loads[m.group(2)] = ("base" if m.group(1) == "ulong" else "ext", "tabs")
            continue
        m = re.match(r"(fp2|ulong) ([nm]\d+) = (.*);$", s)
        if m:
            defs[m.group(2)] = m.group(3)
            continue
        m = re.match(r"out = f2_add\(out, (.*)\);$", s)
        if m:
            outs.append(m.group(1))
    return loads, defs, outs


def live_set(seeds, defs, loads):
    live, stack = set(), list(seeds)
    while stack:
        n = stack.pop()
        if n in live:
            continue
        live.add(n)
        if n in defs:
            stack.extend(REF.findall(defs[n]))
    return {v for v in live if v in loads}


def analyse(path):
    src = path.read_text()
    first = next(l for l in src.split("\n") if l.startswith("// slot"))
    slot = int(re.match(r"// slot (\d+)", first).group(1))
    k = int(re.search(r"#define SC_K (\d+)", src).group(1))
    d = int(re.search(r"#define SC_D (\d+)", src).group(1))
    mm = re.search(r"#define SC_M (\d+)u", src)
    m = int(mm.group(1)) if mm else 0
    de_m = re.search(r"#define SC_DE (\d+)u", src)
    de = int(de_m.group(1)) if de_m else d
    out = {"slot": slot, "label": first[3:], "k": k, "m": m, "deg": d, "de": de}
    for name, key in (("k_sc_round0", "r0"), ("k_sc_round", "rl")):
        loads, defs, outs = parse_body(kernel_text(src, name))
        seeds = [x for e in outs for x in REF.findall(e)]
        live = live_set(seeds, defs, loads)
        out[key] = {
            "loaded": len(loads),
            "live": len(live),
            "live_base": sum(1 for v in live if loads[v][0] == "base"),
            "live_orig": sum(1 for v in live if loads[v][1] == "tabs"),
            "live_x": sum(1 for v in live if loads[v][1] == "xtabs"),
            "loaded_base": sum(1 for v in loads.values() if v[0] == "base"),
        }
    if m:
        loads, defs, _ = parse_body(kernel_text(src, "k_sc_mat"))
        seeds = [n for n in defs if re.fullmatch(r"m\d+", n)]
        live = live_set(seeds, defs, loads)
        out["mat"] = {"loaded": len(loads), "read": len(live), "read_base": sum(1 for v in live if loads[v][0] == "base")}
    return out


def load_ms(profile_key):
    arm = {"w16r2_8b": "w16r2_8b_armB_unbatched_sync_lin1", "r13_shield": "r13_shield_armB_unbatched_sync_lin1"}[profile_key]
    d = json.loads(SUMM.read_text())["arms"][arm]["unbatched"]
    res = {}
    for lbl, v in d.items():
        s = int(re.match(r"slot (\d+)", lbl).group(1))
        meta = dict(kv.split("=") for kv in v["meta"].split())
        res[s] = {"log_cap": int(meta["log_cap"]), "ms": [v["per_round_median_ms"][f"j={j}"] for j in range(len(v["per_round_median_ms"]))],
                  "tables_sync": v["phases_median_ms"].get("tables_sync_ms", 0.0), "total": v["phases_median_ms"]["total_unbatched_gpu_ms"]}
    return res


def words_per_pair(de, j):
    """logical u64-element loads (each a lo or hi element) per live table per pair: point 0 loads lo, point 1 hi,
    points >= 2 both. Round 0 evaluates 0..de (point 1 included); later rounds skip point 1 (claim gives s(1))."""
    if j == 0:
        return 1 + 1 + 2 * (de - 1)
    return 1 + 2 * (de - 1)


def model(a, tm, e_mode, rounds=5):
    """bytes per window j = 0..rounds-1 for one slot. Windows (metal.rs:3537-3560): window 0 = k_sc_mat + eval 0;
    window j >= 1 = fold of round j-1 (all k + m tables) + eval j. X_j = one table at round j start = len_j * 16 B."""
    L = tm["log_cap"]
    k, m = a["k"], a["m"]
    nt = k + m
    ll = a["rl"]["live"]                # live tables in later rounds (original + materialized)
    ll_orig = a["rl"]["live_orig"]
    dead = k - ll_orig                  # original tables that no later round reads (fold only)
    l0 = a["r0"]["live"]
    l0b = a["r0"]["live_base"]
    rows = []
    for j in range(min(rounds, len(tm["ms"]))):
        len_j = 2 ** (L - j)
        Xj = len_j * EB
        w = {"j": j, "ms": tm["ms"][j]}
        wl = words_per_pair(a["de"], j)
        if j == 0:
            mat_r = a.get("mat", {"read": 0})["read"] * 2 ** L * EB       # line-granular: a base word sits in a 16 B element
            mat_w = m * 2 ** L * EB
            ev_distinct = l0 * Xj                                          # line-granular
            ev_useful = (l0 - l0b) * Xj + l0b * (Xj // 2)
            ev_logical = (l0 - l0b) * (len_j // 2) * wl * EB + l0b * (len_j // 2) * wl * (EB // 2)
            w.update(mat_r=mat_r, mat_w=mat_w, fold_r=0, fold_w=0, ev_distinct=ev_distinct, ev_useful=ev_useful, ev_logical=ev_logical,
                     live=l0, dead_fold_r=0, dead_fold_w=0)
        else:
            pre = 2 * Xj                                                   # table before the fold of round j-1
            fold_r = nt * pre
            fold_w = nt * Xj
            ev_distinct = ll * Xj
            ev_logical = ll * (len_j // 2) * wl * EB
            dead_r = dead * pre
            dead_w = dead * Xj
            w.update(mat_r=0, mat_w=0, fold_r=fold_r, fold_w=fold_w, ev_distinct=ev_distinct, ev_useful=ev_distinct, ev_logical=ev_logical,
                     live=ll, dead_fold_r=dead_r, dead_fold_w=dead_w)
        rows.append(w)
    return rows


def totals(rows, e_mode):
    """traffic (bytes) per window under the scenarios. e_mode 'dram': every logical load is DRAM traffic;
    'cache': neighbouring loads hit in cache (eval reads = distinct bytes)."""
    out = []
    for w in rows:
        ev = w["ev_logical"] if e_mode == "dram" else w["ev_distinct"]
        base = w["mat_r"] + w["mat_w"] + w["fold_r"] + w["fold_w"] + ev
        live_fold_r = w["fold_r"] - w["dead_fold_r"]
        live_fold_w = w["fold_w"] - w["dead_fold_w"]
        j0 = w["j"] == 0
        # F1 (fused fold-eval, no single fetch): the live tables' fold read and the eval's re-read of the folded table are replaced by
        #     eval reads of the UNFOLDED tables (twice the elements) at the same multiplicity: eval reads double, fold read of live tables goes.
        #     Window 0 has no fold before its eval: nothing to fuse.
        f1 = base if j0 else base - live_fold_r + ev
        # F2 (single fetch only): eval reads fall to the distinct bytes
        f2 = base - (ev - w["ev_distinct"])
        # F1 + F2: the unfolded live tables are read once (that read is the fold's read, already counted), folded in registers,
        #     written once: the eval's reads vanish (window 0: F2 alone)
        f12 = f2 if j0 else base - ev
        # H134: dead tables not folded (their finals come from one end-of-slot read, counted by the caller)
        h134 = base - w["dead_fold_r"] - w["dead_fold_w"]
        both = f12 - w["dead_fold_r"] - w["dead_fold_w"]
        out.append({"base": base, "F1": f1, "F2": f2, "F12": f12, "H134": h134, "F12H": both})
    return out


def main():
    block_ms = {"w16r2_8b": 117.285, "r13_shield": 248.899}  # breakdown README section 2.1 (Arm A, solo block GPU)
    for prof in ("w16r2_8b", "r13_shield"):
        ms = load_ms(prof)
        an = {}
        for p in sorted((DUMPS / prof).glob("*.metal")):
            a = analyse(p)
            an[a["slot"]] = a
        print(f"\n===== profile {prof} =====")
        print("slot | k m | log_cap deg de | round0: loaded/live (base) | later: loaded/live (orig+x) | dead-orig | mat reads")
        for s in sorted(an):
            a = an[s]
            t = ms.get(s)
            print(f"{s:>4} | {a['k']:>2} {a['m']:>2} | {t['log_cap'] if t else '?'} {a['deg']} {a['de']} | "
                  f"{a['r0']['loaded']}/{a['r0']['live']} ({a['r0']['live_base']}) | {a['rl']['loaded']}/{a['rl']['live']} "
                  f"({a['rl']['live_orig']}+{a['rl']['live_x']}) | {a['k'] - a['rl']['live_orig']} | {a.get('mat', {}).get('read', 0)}")
        grand = {sc: 0.0 for sc in ("dram", "cache")}
        print("\nper-window distinct bytes (MB, line-granular 16 B/element), eval logical bytes, implied rates, window ms")
        for s in sorted(an):
            a = an[s]
            t = ms.get(s)
            if not t or a["k"] < 15:
                continue
            rows = model(a, t, "dram")
            print(f"-- slot {s} (k={a['k']}, m={a['m']}, cap 2^{t['log_cap']}, de={a['de']}), later live {a['rl']['live']} of {a['k'] + a['m']}")
            for w in rows:
                tot = w["mat_r"] + w["mat_w"] + w["fold_r"] + w["fold_w"] + w["ev_distinct"]
                totl = w["mat_r"] + w["mat_w"] + w["fold_r"] + w["fold_w"] + w["ev_logical"]
                print(f"   j={w['j']} {w['ms']:7.3f} ms | live {w['live']:>3} | eval distinct {w['ev_distinct'] / 1e6:8.1f} MB logical {w['ev_logical'] / 1e6:8.1f} MB"
                      f" | fold r {w['fold_r'] / 1e6:8.1f} w {w['fold_w'] / 1e6:8.1f} (dead share r {w['dead_fold_r'] / 1e6:7.1f}) mat r {w['mat_r'] / 1e6:6.1f} w {w['mat_w'] / 1e6:6.1f}"
                      f" | total distinct {tot / 1e6:8.1f} MB = {tot / w['ms'] / 1e6:6.1f} GB/s ; with logical eval {totl / 1e6:8.1f} MB = {totl / w['ms'] / 1e6:6.1f} GB/s")
        print("\ncuts over windows 0..4 per slot, and time saved if window time is proportional to traffic (upper bound for that scenario)")
        for sc in ("cache", "dram", "dram_slc"):
            print(f"  scenario '{sc}': " + {"cache": "eval re-reads are cache hits (eval reads = distinct)", "dram": "all eval re-reads reach DRAM (eval reads = logical)",
                                            "dram_slc": "as 'dram', but a window whose table footprint is <= 96 MB is taken as SLC-resident (no saving there)"}[sc])
            hdr = "slot | traffic MB (today) | F1 | F2 | F1+F2 | H134 | F1+F2+H134 (% cut)  | ms saved: F1 | F2 | F1+F2 | H134 | all | block share (all)"
            print("   " + hdr)
            tot_saved = {k: 0.0 for k in ("F1", "F2", "F12", "H134", "F12H")}
            for s in sorted(an):
                a = an[s]
                t = ms.get(s)
                if not t or a["k"] < 15:
                    continue
                rows = model(a, t, sc)
                tt = totals(rows, "cache" if sc == "cache" else "dram")
                if sc == "dram_slc":
                    for w, x in zip(rows, tt):
                        foot = (w["fold_r"] + w["mat_r"]) if w["j"] > 0 else (a["k"] * 2 ** t["log_cap"] * EB)
                        if foot <= 96e6:
                            for k_ in ("F1", "F2", "F12", "H134", "F12H"):
                                x[k_] = x["base"]
                base = sum(x["base"] for x in tt)
                cuts = {k: 1 - sum(x[k] for x in tt) / base for k in ("F1", "F2", "F12", "H134", "F12H")}
                saved = {k: sum(w["ms"] * (1 - x[k] / x["base"]) for w, x in zip(rows, tt)) for k in cuts}
                # H134's end-of-slot read of the dead tables' originals (one pass of the original table) is added back
                dead = a["k"] - a["rl"]["live_orig"]
                end_ms_penalty = 0.0
                for k_ in ("H134", "F12H"):
                    end_bytes = dead * 2 ** t["log_cap"] * EB
                    # convert to ms at the window-0 effective rate for the slot
                    rate = sum(x["base"] for x in tt) / sum(w["ms"] for w in rows)
                    pen = end_bytes / rate
                    saved[k_] -= pen
                    end_ms_penalty = pen
                for k_ in tot_saved:
                    tot_saved[k_] += saved[k_]
                print(f"   {s:>3} | {base / 1e6:9.0f} | " + " | ".join(f"{100 * cuts[k_]:5.1f}%" for k_ in ("F1", "F2", "F12", "H134", "F12H"))
                      + " | " + " | ".join(f"{saved[k_]:6.2f}" for k_ in ("F1", "F2", "F12", "H134", "F12H"))
                      + f" | {100 * saved['F12H'] / block_ms[prof]:5.1f}% (dead-table end read costs {end_ms_penalty:.2f} ms)")
            print("   sum over slots listed (ms/block): " + ", ".join(f"{k_} {v:.2f}" for k_, v in tot_saved.items())
                  + " ; share of block GPU: " + ", ".join(f"{k_} {100 * v / block_ms[prof]:.1f}%" for k_, v in tot_saved.items()))


def compact_base(prof_key, block_ms):
    """H161 (proposal, derived): base-typed tables held at 8 B per element (not 16) until the first fold writes extension words.
    Saves, per slot: round-0 eval distinct reads of live base tables, the mat kernel's base reads, and the first fold's read
    of the original base tables (window 1). Time saved if window time is proportional to the window's distinct bytes (upper bound)."""
    ms = load_ms(prof_key)
    tot = 0.0
    print(f"\n== H161 compact base tables, profile {prof_key}")
    for p in sorted((DUMPS / prof_key).glob("*.metal")):
        a = analyse(p)
        t = ms.get(a["slot"])
        if not t or a["k"] < 15 or a["slot"] == 19:
            continue
        rows = model(a, t, "cache")
        L = t["log_cap"]
        base_orig = sum(1 for v in re.findall(r"ulong v(\d+) = ln_base\(tabs", kernel_text(p.read_text(), "k_sc_round0")))  # loaded base originals
        l0b = a["r0"]["live_base"]
        mat_b = a.get("mat", {}).get("read_base", 0)
        save0 = (l0b + mat_b) * 2 ** L * 8
        save1 = base_orig * 2 ** L * 8
        w0 = rows[0]; w1 = rows[1]
        b0 = w0["mat_r"] + w0["mat_w"] + w0["ev_distinct"]
        b1 = w1["fold_r"] + w1["fold_w"] + w1["ev_distinct"]
        ms_saved = w0["ms"] * save0 / b0 + w1["ms"] * save1 / b1
        tot += ms_saved
        print(f"slot {a['slot']:>2}: live base at round 0 {l0b}, mat base reads {mat_b}, base originals {base_orig}: saves {save0 / 1e6:.0f} MB in window 0 ({100 * save0 / b0:.1f}%), "
              f"{save1 / 1e6:.0f} MB in window 1 ({100 * save1 / b1:.1f}%) -> <= {ms_saved:.2f} ms")
    print(f"sum <= {tot:.2f} ms per block = {100 * tot / block_ms[prof_key]:.1f}% of block GPU (upper bound, time proportional to bytes)")


if __name__ == "__main__":
    main()
    compact_base("w16r2_8b", {"w16r2_8b": 117.285, "r13_shield": 248.899})
    compact_base("r13_shield", {"w16r2_8b": 117.285, "r13_shield": 248.899})
