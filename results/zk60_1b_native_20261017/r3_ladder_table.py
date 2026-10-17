#!/usr/bin/env python3
"""NATIVE LANE round 3: the R3-3 ladder table from the run logs and guard
records (every number read from a file under r2/ or r3/; nothing typed)."""
import json, os, sys
D = os.path.dirname(os.path.abspath(__file__))

def events(path):
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path):
        line = line.strip()
        if line.startswith('{"event"'):
            try:
                e = json.loads(line)
            except Exception:
                continue
            out.setdefault(e["event"], []).append(e)
    return out

def guard(path):
    return json.load(open(path)) if os.path.exists(path) else {}

rows = []
runs = [("T32 (round 2 reference, pg_rot1_export_T32)", "r2/stack-pg_rot1-ho00-cpu", 32, "CPU r2"),
        ("T32 (round 2 reference, pg_rot1_export_T32)", "r2/stack-pg_rot1-ho00-gpu", 32, "GPU r2")]
for v, t in [("pg_rot1_b4_T32_cal128", 32), ("pg_rot1_b4_T64_cal128", 64), ("pg_rot1_b4_T128", 128)]:
    runs.append((v, f"r3/stack-{v}-ho00-cpu", t, "CPU"))
    runs.append((v, f"r3/stack-{v}-ho00-gpu", t, "GPU"))
for name, rel, t, mode in runs:
    p = events(os.path.join(D, rel, "prove.log"))
    vv = events(os.path.join(D, rel, "verify.log"))
    gp = guard(os.path.join(D, rel, "prove.guard.json"))
    gv = guard(os.path.join(D, rel, "verify.guard.json"))
    if "proved" not in p:
        continue
    pr = p["proved"][0]
    ver = vv.get("verified", [{}])[0]
    witness = pr.get("of_which_witness_seconds", pr.get("of_which_witness_rebuild_seconds"))
    seal = pr.get("sealing_pass_seconds")
    proofs = pr["prove_run_seconds"] - witness
    wall = gp.get("child_wall_seconds")
    ctl = vv.get("stack-controls", [{}])[0].get("refused")
    rows.append(dict(rung=f"T{t}", export=name, mode=mode, gpu=pr["gpu"], declines=pr.get("gpu_declines"),
                     total_wall_s=round(wall, 1), total_in_process_s=pr["total_seconds"], load_s=pr["load_seconds"],
                     sealing_s=seal, witness_s=witness, witness_per_block_s=round(witness / 22, 3), proofs_only_s=round(proofs, 1),
                     prove_run_s=pr["prove_run_seconds"], in_process_verify_s=pr["in_process_verify_seconds"],
                     fresh_verify_s=ver.get("verify_seconds"), fresh_verify_load_s=ver.get("load_seconds"), fresh_verify_wall_s=gv.get("child_wall_seconds") and round(gv["child_wall_seconds"], 1),
                     controls_refused=ctl, receipt_bytes=pr["receipt_bytes"], peak_rss_gib=gp.get("peak_rss_gib"), peak_vram_mib=gp.get("peak_vram_mib"),
                     rayon_threads=pr.get("rayon_threads", "default (22)"), statement_identity=pr["statement_identity"],
                     pos_per_s_total=round(t / wall, 3), pos_per_s_proofs=round(t / proofs, 3)))
json.dump(rows, open(os.path.join(D, "r3", "ladder.json"), "w"), indent=1)
hdr = "| rung | mode | total wall (s) | sealing (s) | witness (s) [per block] | proofs only (s) | in-proc verify (s) | fresh verify (s) | receipt (B) | peak RSS (GiB) | peak VRAM (MiB) | positions/s total | positions/s proofs |"
print(hdr)
print("|" + "---|" * 13)
for r in rows:
    print(f"| {r['rung']} {'(r2 ref)' if 'r2' in r['mode'] else ''} | {r['mode']} | {r['total_wall_s']} | {r['sealing_s']} | {r['witness_s']} [{r['witness_per_block_s']}] | {r['proofs_only_s']} | {r['in_process_verify_s']} | {r['fresh_verify_s']} | {r['receipt_bytes']:,} | {r['peak_rss_gib']} | {r['peak_vram_mib'] or '-'} | {r['pos_per_s_total']} | {r['pos_per_s_proofs']} |")
for r in rows:
    print(r['rung'], r['mode'], 'threads', r['rayon_threads'], 'controls', r['controls_refused'], 'declines', r['declines'], 'id', r['statement_identity'][:16], 'load', r['load_s'], 'fresh-verify wall', r['fresh_verify_wall_s'])
