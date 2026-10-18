#!/usr/bin/env python3
"""NATIVE LANE, speed plan task 3: the Llama-3-8B phase ladder (generic dense
block at T64 / T128, CPU and GPU arm) against the plan's predictions.

Reads r5/ladder8b-T{64,128}-{cpu,gpu}/{prove,verify}.log and .guard.json:
the `LADDER8B {json}` line, the FIRST `PB-TIMING prove` table (the honest
prove; the controls follow it) and the FIRST `PB-TIMING verify` table of the
fresh-process verify. Phase groups as in the speed plan's cost model:
commit (A + H), zero-checks (slots 14-18), inverses (U8 + exp/act),
openings (A + H), conversion (A allocate), rest (the block wall minus those).
The predictions are computed by the plan's own cost_model / projection
(imported READ-ONLY with -B from results/zk60_speed_plan_20261017/).

usage: python3 -B r5_ladder_table.py  -> prints markdown, writes r5/ladder8b.json
"""
import json
import os
import sys

D = os.path.dirname(os.path.abspath(__file__))
SP = "/home/victor/IntelligenceRegulation/results/zk60_speed_plan_20261017"
sys.path.insert(0, SP)
import cost_model as cm  # noqa: E402
import projection as pj  # noqa: E402
from layout import llama3_8b  # noqa: E402

LC = {64: 13, 128: 14}
PLAN = {  # the plan's written predictions (section 6, task 3)
    64: dict(cpu=5.47, gpu=4.78, witness=1.19, peak=3.2, verify=0.48, receipt_mb=21.7),
    128: dict(cpu=10.60, gpu=8.78, witness=2.51, peak=6.3, verify=0.77, receipt_mb=29.3,
              commit=2.72, zc=5.05, inverses=0.67, openings=0.69, conversion=0.34, rest=1.14),
}


def first_table(path, side):
    rows, wall, on = [], None, False
    for line in open(path, errors="replace"):
        if line.startswith(f"PB-TIMING {side} [") and "phases, wall" in line:
            if on:
                break
            on = True
            continue
        if on and line.startswith(f"PB-TIMING {side} |"):
            p = [x.strip() for x in line.split("|")]
            if p[1] == "phase" or p[1].startswith("SUM OF") or p[1].startswith("unaccounted"):
                continue
            if p[1].startswith("WALL CLOCK"):
                wall = float(p[3])
                break
            su = p[5].split()
            rows.append(dict(name=p[1], half=p[2], secs=float(p[3]), size=int(su[0]) if su and su[0].isdigit() else 0,
                             unit=" ".join(su[1:]), bytes=int(p[9]) if len(p) > 10 and p[9].isdigit() else 0))
    return rows, wall


def groups(rows, wall):
    g = dict(commit=0.0, zc_D=0.0, zc_Q=0.0, zc_Kv=0.0, zc_S=0.0, zc_F=0.0, inverses=0.0, openings=0.0, conversion=0.0, run=0.0)
    for r in rows:
        n = r["name"]
        if n.startswith("A: commit") or n.startswith("H: commit"):
            g["commit"] += r["secs"]
        elif n.startswith("slot 14"):
            g["zc_D"] += r["secs"]
        elif n.startswith("slot 15"):
            g["zc_Q"] += r["secs"]
        elif n.startswith("slot 16"):
            g["zc_Kv"] += r["secs"]
        elif n.startswith("slot 17"):
            g["zc_S"] += r["secs"]
        elif n.startswith("slot 18"):
            g["zc_F"] += r["secs"]
        elif n.startswith("H: LogUp helper inverses") or n.startswith("H: exp + activation"):
            g["inverses"] += r["secs"]
        elif n.startswith("open A") or n.startswith("open H"):
            g["openings"] += r["secs"]
        elif n.startswith("A: allocate"):
            g["conversion"] += r["secs"]
        elif n.startswith("run:"):
            g["run"] += r["secs"]
    g["zero_checks"] = g["zc_D"] + g["zc_Q"] + g["zc_Kv"] + g["zc_S"] + g["zc_F"]
    body = (wall or 0.0) - g["run"]
    g["rest"] = body - g["commit"] - g["zero_checks"] - g["inverses"] - g["openings"] - g["conversion"]
    g["block_wall"] = body
    return g


def ladder_line(path):
    for line in open(path, errors="replace"):
        if line.startswith("LADDER8B {"):
            return json.loads(line[len("LADDER8B "):])
    return None


def main():
    out = []
    cpu_c = cm.coefficients("cpu")
    for t in (64, 128):
        sh = llama3_8b(t, LC[t])
        model = cm.block_phases(sh, cpu_c)
        model["zero_checks"] = sum(model[k] for k in ("zc_D", "zc_F", "zc_S", "zc_Q", "zc_Kv"))
        gpu_model = model["total"] - model["commit"] + pj.C_GPU_COMMIT_4070 * (sh.summary()["A_elems"] + sh.summary()["H_elems"]) + pj.G0_4070
        for mode in ("cpu", "gpu", "gpu-chunked"):
            r = os.path.join(D, "r5", f"ladder8b-T{t}-{mode}")
            pl = os.path.join(r, "prove.log")
            if not os.path.exists(pl):
                continue
            lad = ladder_line(pl)
            rows, wall = first_table(pl, "prove")
            if not rows or lad is None:
                continue  # e.g. the T128 resident GPU arm, never run (VRAM limit)
            g = groups(rows, wall) if rows else {}
            vrows, vwall = first_table(os.path.join(r, "verify.log"), "verify") if os.path.exists(os.path.join(r, "verify.log")) else ([], None)
            gp = json.load(open(os.path.join(r, "prove.guard.json"))) if os.path.exists(os.path.join(r, "prove.guard.json")) else {}
            gv = json.load(open(os.path.join(r, "verify.guard.json"))) if os.path.exists(os.path.join(r, "verify.guard.json")) else {}
            fresh = None
            if os.path.exists(os.path.join(r, "verify.log")):
                for line in open(os.path.join(r, "verify.log"), errors="replace"):
                    if line.startswith("LADDER8B fresh-process verify"):
                        fresh = line.strip()
            out.append(dict(T=t, mode=mode, ladder=lad, groups=g, verify_table_wall=vwall, prove_guard=dict(wall=gp.get("child_wall_seconds"), peak_rss_gib=gp.get("peak_rss_gib"), peak_vram_mib=gp.get("peak_vram_mib"), exit=gp.get("exit")),
                            verify_guard=dict(wall=gv.get("child_wall_seconds"), peak_rss_gib=gv.get("peak_rss_gib"), exit=gv.get("exit")), fresh=fresh,
                            model={k: round(v, 3) for k, v in model.items()}, model_gpu_total=round(gpu_model, 3), plan=PLAN[t]))
    json.dump(out, open(os.path.join(D, "r5", "ladder8b.json"), "w"), indent=1)
    print("| T | arm | block wall (PB-TIMING) | model | err | commit | zero-checks (D/F/S/Q/Kv) | inverses | openings | conversion | rest | witness | prove_one_bound | verify (fresh) | receipt B | peak RSS GiB | VRAM MiB |")
    print("|" + "---|" * 17)
    for o in out:
        g, m, lad = o["groups"], o["model"], o["ladder"] or {}
        tot_m = m["total"] if o["mode"] == "cpu" else o["model_gpu_total"]
        g.setdefault("block_wall", float("nan"))
        err = 100 * (g["block_wall"] - tot_m) / tot_m if g else float("nan")
        zc = "/".join(f"{g[k]:.2f}" for k in ("zc_D", "zc_F", "zc_S", "zc_Q", "zc_Kv"))
        zcm = "/".join(f"{m[k]:.2f}" for k in ("zc_D", "zc_F", "zc_S", "zc_Q", "zc_Kv"))
        print(f"| {o['T']} | {o['mode']} | {g['block_wall']:.2f} | {tot_m:.2f} | {err:+.0f}% | {g['commit']:.2f} ({m['commit']:.2f}) | {g['zero_checks']:.2f} = {zc} ({m['zero_checks']:.2f} = {zcm}) | {g['inverses']:.2f} ({m['inverses']:.2f}) | {g['openings']:.2f} ({m['openings']:.2f}) | {g['conversion']:.2f} ({m['conversion']:.2f}) | {g['rest']:.2f} ({m['rest']:.2f}) | {lad.get('witness_seconds')} ({o['plan']['witness']}) | {lad.get('prove_seconds')} | {o['fresh'] or '-'} | {lad.get('segment_bytes')} ({o['plan']['receipt_mb']} MB) | {o['prove_guard']['peak_rss_gib']} ({o['plan']['peak']}) | {o['prove_guard']['peak_vram_mib'] or '-'} |")
    print()
    for o in out:
        g, m = o["groups"], o["model"]
        mm = m if o["mode"] == "cpu" else dict(m, commit=pj.C_GPU_COMMIT_4070 * 0)  # GPU commit is compared below
        print(f"T{o['T']} {o['mode']}: per-group error vs the model (>15% flagged):")
        for k in ("commit", "zero_checks", "inverses", "openings", "conversion", "rest"):
            if o["mode"] == "gpu" and k == "commit":
                continue
            e = 100 * (g[k] - m[k]) / m[k] if m[k] else float("nan")
            print(f"   {k:12s} measured {g[k]:7.3f}  model {m[k]:7.3f}  {e:+6.1f}% {'MISS' if abs(e) > 15 else 'ok'}")


if __name__ == "__main__":
    main()
