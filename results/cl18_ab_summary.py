#!/usr/bin/env python3
"""[ZK60-CL18] Summarize the compact-pad A/B (results/cl18_ab_{compact,reference}_r*.log).

Reads, per run: the three `chunked ZK commit` clocks (W/A/H, by row count), the
three `chunked ZK re-encode + gather` clocks, the device-side summary line
(ntt / h2d / vram peak), the HASHLINE_TIMING prove_s / proof_ready_s, and the
CL18_RUN digest line. Writes results/cl18_ab_summary.md and .json. Reports the
CHANGED PHASE (commits, re-encodes) and the WHOLE PROOF (prove_s,
proof_ready_s) separately. Pure text parsing; nothing is run.
"""
import glob
import json
import os
import re
import statistics
import sys

R = "/home/victor/wt-zk60-cl1/results"
RE_COMMIT = re.compile(r"chunked ZK commit rows (\d+) 2\^(\d+) -> 2\^(\d+) \(q (\d+)\) in (\d+) chunks of <= (\d+)(.*?): ([0-9.]+) s")
RE_REENC = re.compile(r"chunked ZK re-encode \+ gather rows (\d+) \((\d+) chunks(.*?)\): ([0-9.]+) s")
RE_DEV = re.compile(r"h2d ([0-9.]+) s \((\d+) MB\) \| ntt ([0-9.]+) s .* vram peak (\d+) MB")
RE_RUN = re.compile(r"CL18_RUN arm=(\w+) rep=(\d+) exit=(\d+) sha256=(\w+) bytes=(\w+)")


def parse(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    commits = [{"rows": int(m[0]), "log_n": int(m[1]), "log_nn": int(m[2]), "q": int(m[3]), "chunks": int(m[4]),
                "rmax": int(m[5]), "how": m[6].strip(", "), "s": float(m[7])} for m in RE_COMMIT.findall(text)]
    reencs = [{"rows": int(m[0]), "chunks": int(m[1]), "how": m[2].strip(", "), "s": float(m[3])} for m in RE_REENC.findall(text)]
    dev = RE_DEV.search(text)
    timing = None
    for line in text.splitlines():
        if line.startswith("HASHLINE_TIMING "):
            timing = json.loads(line[len("HASHLINE_TIMING "):])
    run = RE_RUN.search(text)
    return {
        "log": os.path.relpath(path, R),
        "arm": run and run.group(1), "rep": run and int(run.group(2)), "exit": run and int(run.group(3)),
        "sha256": run and run.group(4), "bytes": run and run.group(5),
        "commits": commits, "reencs": reencs,
        "commit_total_s": round(sum(c["s"] for c in commits), 4),
        "reenc_total_s": round(sum(r["s"] for r in reencs), 4),
        "dev": dev and {"h2d_s": float(dev.group(1)), "h2d_mb": int(dev.group(2)), "ntt_s": float(dev.group(3)), "vram_peak_mb": int(dev.group(4))},
        "prove_s": timing and timing.get("prove_s"), "proof_ready_s": timing and timing.get("proof_ready_s"),
        "witness_s": timing and timing.get("witness_s"), "verified": timing and timing.get("verified"),
    }


def main():
    runs = [parse(p) for p in sorted(glob.glob(os.path.join(R, "cl18_ab_*_r*.log")))]
    runs = [r for r in runs if r["arm"]]
    if not runs:
        print("no CL18 A/B runs found", file=sys.stderr)
        return 1
    arms = {}
    for r in runs:
        arms.setdefault(r["arm"], []).append(r)
    digests = {(r["sha256"], r["bytes"]) for r in runs}
    out = {"schema": 1, "scope": "CL18 compact pad/scale A/B, Mistral one layer P3, two threads, single box, not a p95",
           "runs": runs, "digests": sorted(digests), "byte_identical_across_arms": len(digests) == 1 and all(r["exit"] == 0 for r in runs)}

    def mean(xs):
        xs = [x for x in xs if x is not None]
        return round(statistics.fmean(xs), 4) if xs else None

    summary = {}
    for arm, rs in arms.items():
        summary[arm] = {
            "n": len(rs),
            "commit_total_s": mean([r["commit_total_s"] for r in rs]),
            "reenc_total_s": mean([r["reenc_total_s"] for r in rs]),
            "commit_W_s": mean([r["commits"][0]["s"] for r in rs if r["commits"]]),
            "reenc_W_s": mean([r["reencs"][0]["s"] for r in rs if r["reencs"]]),
            "ntt_s": mean([r["dev"]["ntt_s"] for r in rs if r["dev"]]),
            "prove_s": mean([r["prove_s"] for r in rs]),
            "proof_ready_s": mean([r["proof_ready_s"] for r in rs]),
            "vram_peak_mb": max((r["dev"]["vram_peak_mb"] for r in rs if r["dev"]), default=None),
        }
    out["summary"] = summary
    if "compact" in summary and "reference" in summary:
        c, f = summary["compact"], summary["reference"]
        def ratio(a, b):
            return round(b / a, 3) if a and b else None
        out["changed_phase"] = {
            "three_commits_s": {"reference": f["commit_total_s"], "compact": c["commit_total_s"], "speedup_x": ratio(c["commit_total_s"], f["commit_total_s"])},
            "three_reencodes_s": {"reference": f["reenc_total_s"], "compact": c["reenc_total_s"], "speedup_x": ratio(c["reenc_total_s"], f["reenc_total_s"])},
            "changed_phase_total_s": {"reference": round(f["commit_total_s"] + f["reenc_total_s"], 4), "compact": round(c["commit_total_s"] + c["reenc_total_s"], 4)},
        }
        out["whole_proof"] = {
            "prove_s": {"reference": f["prove_s"], "compact": c["prove_s"], "delta_s": round((c["prove_s"] or 0) - (f["prove_s"] or 0), 4)},
            "proof_ready_s": {"reference": f["proof_ready_s"], "compact": c["proof_ready_s"], "delta_s": round((c["proof_ready_s"] or 0) - (f["proof_ready_s"] or 0), 4)},
        }
    with open(os.path.join(R, "cl18_ab_summary.json"), "w") as fh:
        json.dump(out, fh, indent=2)

    lines = ["# CL18 compact pad/scale A/B — Mistral one layer, P3, two threads [MEASURED, WSL-BOX, RTX 4070, single box, not a p95]", ""]
    lines.append("| arm | rep | commit W s | commit A s | commit H s | three commits s | re-enc W s | re-enc A s | re-enc H s | three re-encodes s | dev ntt s | PROVE s | proof_ready s | VRAM peak MB | proof |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|")
    for r in runs:
        cs = [c["s"] for c in r["commits"]] + [None] * 3
        es = [e["s"] for e in r["reencs"]] + [None] * 3
        fmt = lambda x: "—" if x is None else f"{x:.4f}"
        lines.append(f"| {r['arm']} | {r['rep']} | {fmt(cs[0])} | {fmt(cs[1])} | {fmt(cs[2])} | {fmt(r['commit_total_s'])} | {fmt(es[0])} | {fmt(es[1])} | {fmt(es[2])} | {fmt(r['reenc_total_s'])} | "
                     f"{fmt(r['dev'] and r['dev']['ntt_s'])} | {fmt(r['prove_s'])} | {fmt(r['proof_ready_s'])} | {r['dev'] and r['dev']['vram_peak_mb']} | `{(r['sha256'] or '')[:8]}..` / {r['bytes']} B |")
    lines.append("")
    lines.append(f"byte-identical across arms: **{out['byte_identical_across_arms']}** ({', '.join(f'{s[:12]}../{b}' for s, b in out['digests'])})")
    if "changed_phase" in out:
        cp, wp = out["changed_phase"], out["whole_proof"]
        lines.append("")
        lines.append("| quantity | reference | compact | change |")
        lines.append("|---|---:|---:|---:|")
        lines.append(f"| three chunked ZK commits (W/A/H) s | {cp['three_commits_s']['reference']} | {cp['three_commits_s']['compact']} | {cp['three_commits_s']['speedup_x']}x |")
        lines.append(f"| three chunked ZK re-encodes (W/A/H) s | {cp['three_reencodes_s']['reference']} | {cp['three_reencodes_s']['compact']} | {cp['three_reencodes_s']['speedup_x']}x |")
        lines.append(f"| changed phase total s | {cp['changed_phase_total_s']['reference']} | {cp['changed_phase_total_s']['compact']} | |")
        lines.append(f"| PROVE s (HASHLINE_TIMING prove_s) | {wp['prove_s']['reference']} | {wp['prove_s']['compact']} | {wp['prove_s']['delta_s']:+} s |")
        lines.append(f"| proof_ready_s | {wp['proof_ready_s']['reference']} | {wp['proof_ready_s']['compact']} | {wp['proof_ready_s']['delta_s']:+} s |")
    lines.append("")
    lines.append("Means over the reps per arm. The changed phase and the whole proof are reported separately; the traffic reduction remains a hypothesis until measured with a profiler; two-thread laptop diagnostic seconds, not a p95.")
    with open(os.path.join(R, "cl18_ab_summary.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
