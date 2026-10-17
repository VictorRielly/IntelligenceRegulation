#!/usr/bin/env python3
"""GPU ZERO-CHECK lane: A/B table of stack runs (HL_PB_TIMING=1 logs).

usage: gzc_table.py <label>=<prove.log> [<label>=<prove.log> ...]

Per log: sum of block walls, the slot-18 phase and its steps summed over
blocks, the five zero-check phases, the commit phases, prove_run, and the
PB-GZC per-sumcheck lines (device kernels, counted bytes) when present.
Reads logs only; prints Markdown.
"""
import collections
import json
import re
import sys

PLAN_B = 72  # the speed plan's counted bytes per element-term
TERMS = 17
BW = 256e9


def parse(path):
    phases = collections.OrderedDict()
    steps = collections.OrderedDict()
    walls = []
    proved = None
    gzc_event = None
    gzc_lines = []
    slot18_cube = None
    for line in open(path, errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("PB-TIMING prove |"):
            parts = [p.strip() for p in line.split("|")]
            name, secs = parts[1], parts[3]
            if name == "phase" or name.startswith("SUM OF") or name.startswith("unaccounted"):
                continue
            if name.startswith("WALL CLOCK"):
                walls.append(float(secs))
                continue
            phases[name] = phases.get(name, 0.0) + float(secs)
        elif line.startswith("PB-SLOTSTEP"):
            m = re.match(r"PB-SLOTSTEP slot (\d+) \| (.*?)\s*\|\s*([\d.]+) s \|\s*(\d+)", line)
            if m:
                k = (int(m.group(1)), m.group(2).strip())
                steps[k] = steps.get(k, 0.0) + float(m.group(3))
                if int(m.group(1)) == 18 and "masked sumcheck" in m.group(2):
                    slot18_cube = int(m.group(4))
        elif line.startswith('{"event":"proved"'):
            proved = json.loads(line)
        elif line.startswith('{"event":"gpu_zerocheck"'):
            gzc_event = json.loads(line)
        elif line.startswith("PB-GZC slot 18"):
            gzc_lines.append(line)
    return dict(phases=phases, steps=steps, wall=sum(walls), blocks=len(walls), proved=proved, gzc=gzc_event, gzc_lines=gzc_lines, cube=slot18_cube)


def main():
    cols = []
    for arg in sys.argv[1:]:
        label, path = arg.split("=", 1)
        cols.append((label, path, parse(path)))
    print("| quantity | " + " | ".join(c[0] for c in cols) + " |")
    print("|---|" + "---|" * len(cols))

    def row(name, f):
        vals = []
        for _, _, c in cols:
            try:
                vals.append(f(c))
            except Exception:
                vals.append("-")
        print(f"| {name} | " + " | ".join(vals) + " |")

    row("blocks", lambda c: str(c["blocks"]))
    row("sum of block walls (s)", lambda c: f"{c['wall']:.2f}")
    row("prove_run (s)", lambda c: f"{c['proved']['prove_run_seconds']:.2f}")
    row("of which witness (s)", lambda c: f"{c['proved']['of_which_witness_seconds']:.2f}")
    row("total CLI (s)", lambda c: f"{c['proved']['total_seconds']:.2f}")
    row("gpu / declines", lambda c: f"{c['proved']['gpu'][:12]} / {c['proved']['gpu_declines']}")
    row("device slot-18 sumchecks / shadow checks", lambda c: f"{c['gzc']['device_slot18_sumchecks']} / {c['gzc']['shadow_checks_passed']}")
    zc = ["slot 14 03 D zero-check (hosts 12, 13D)", "slot 15 04 Q zero-check (hosts 09Q, 11)", "slot 16 05 KV zero-check (hosts 09K, 09V)", "slot 17 06 softmax zero-check (hosts 07, 10)", "slot 18 14 F zero-check (hosts 13G, 13U)"]
    for z in zc:
        row(f"phase: {z} (s)", lambda c, z=z: f"{c['phases'].get(z, float('nan')):.2f}")
    for name in ["A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", "H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)"]:
        row(f"phase: {name} (s)", lambda c, n=name: f"{c['phases'].get(n, float('nan')):.2f}")
    keys = sorted({k for _, _, c in cols for k in c["steps"] if k[0] == 18})
    for k in keys:
        row(f"slot 18 step: {k[1]} (s)", lambda c, k=k: f"{c['steps'].get(k, float('nan')):.3f}")

    def body(c):
        return sum(v for k, v in c["steps"].items() if k[0] == 18 and "masked sumcheck" in k[1])

    row("slot-18 sumcheck body per block (ms)", lambda c: f"{1e3 * body(c) / c['blocks']:.1f}")
    row("plan figure 72 B x cube x 17 / body time (GB/s, % of 256)", lambda c: f"{PLAN_B * c['cube'] * TERMS * c['blocks'] / body(c) / 1e9:.1f} ({100 * PLAN_B * c['cube'] * TERMS * c['blocks'] / body(c) / BW:.1f}%)")
    for label, path, c in cols:
        if c["gzc"] and c["gzc"].get("totals"):
            print(f"\n{label} device totals: `{c['gzc']['totals']}`")
        if c["gzc_lines"]:
            print(f"\n{label}: {len(c['gzc_lines'])} PB-GZC lines; first and last:\n\n    {c['gzc_lines'][0]}\n    {c['gzc_lines'][-1]}")


if __name__ == "__main__":
    main()
