#!/usr/bin/env python3
"""NATIVE LANE round 4: the R4-3 table (Llama-3-8B 32-block stack, T32,
CPU and GPU) from the run logs and guard records, beside the round-3
TinyLlama T32 / T128 rows for reference. Every number is read from a file."""
import json, os
D = os.path.dirname(os.path.abspath(__file__))

def events(path):
    out = {}
    if os.path.exists(path):
        for line in open(path):
            if line.startswith('{"event"'):
                try:
                    e = json.loads(line)
                except Exception:
                    continue
                out.setdefault(e["event"], []).append(e)
    return out

def guard(path):
    return json.load(open(path)) if os.path.exists(path) else {}

runs = [("TinyLlama T32 (r3)", "r3/stack-pg_rot1_b4_T32_cal128-ho00-cpu", 32, 22, "CPU"),
        ("TinyLlama T32 (r3)", "r3/stack-pg_rot1_b4_T32_cal128-ho00-gpu", 32, 22, "GPU"),
        ("TinyLlama T128 (r3)", "r3/stack-pg_rot1_b4_T128-ho00-cpu", 128, 22, "CPU"),
        ("TinyLlama T128 (r3)", "r3/stack-pg_rot1_b4_T128-ho00-gpu", 128, 22, "GPU"),
        ("Llama-3-8B T32", "r4/stack-llama3_8b_pg_rot1_T32-ho00-cpu", 32, 32, "CPU"),
        ("Llama-3-8B T32", "r4/stack-llama3_8b_pg_rot1_T32-ho00-gpu", 32, 32, "GPU")]
rows = []
for name, rel, t, nb, mode in runs:
    p = events(os.path.join(D, rel, "prove.log"))
    v = events(os.path.join(D, rel, "verify.log"))
    gp = guard(os.path.join(D, rel, "prove.guard.json"))
    if "proved" not in p:
        continue
    pr = p["proved"][0]
    ver = v.get("verified", [{}])[0]
    wit = pr["of_which_witness_seconds"]
    bl = pr.get("of_which_block_load_seconds", 0.0)
    proofs = pr["prove_run_seconds"] - wit - bl
    wall = gp["child_wall_seconds"]
    vv = ver.get("verify_seconds")
    vbl = ver.get("of_which_block_load_seconds", 0.0)
    rows.append(dict(run=name, mode=mode, blocks=nb, total_wall_s=round(wall, 1), digest_pass_s=pr["load_seconds"], sealing_s=pr["sealing_pass_seconds"],
                     witness_s=wit, witness_per_block_s=round(wit / nb, 3), block_load_in_prove_s=bl, proofs_only_s=round(proofs, 1), proofs_per_block_s=round(proofs / nb, 2),
                     in_process_verify_s=pr["in_process_verify_seconds"], fresh_verify_s=vv, fresh_verify_crypto_s=None if vv is None else round(vv - vbl, 1),
                     controls=v.get("stack-controls", [{}])[0].get("refused"), receipt_bytes=pr["receipt_bytes"], peak_rss_gib=gp.get("peak_rss_gib"),
                     peak_vram_mib=gp.get("peak_vram_mib"), gpu=pr["gpu"], declines=pr["gpu_declines"], identity=pr["statement_identity"],
                     pos_per_s_total=round(t / wall, 3), pos_per_s_proofs=round(t / proofs, 3)))
json.dump(rows, open(os.path.join(D, "r4", "table.json"), "w"), indent=1)
print("| run | mode | blocks | total wall (s) | digest pass (s) | witness (s) [per block] | block loads in proving pass (s) | proofs only (s) [per block] | in-proc verify (s) | fresh verify (s) [crypto only] | receipt (B) | peak RSS (GiB) | peak VRAM (MiB) | positions/s total | positions/s proofs |")
print("|" + "---|" * 15)
for r in rows:
    print(f"| {r['run']} | {r['mode']} | {r['blocks']} | {r['total_wall_s']} | {r['digest_pass_s']} | {r['witness_s']} [{r['witness_per_block_s']}] | {r['block_load_in_prove_s']} | {r['proofs_only_s']} [{r['proofs_per_block_s']}] | {r['in_process_verify_s']} | {r['fresh_verify_s']} [{r['fresh_verify_crypto_s']}] | {r['receipt_bytes']:,} | {r['peak_rss_gib']} | {r['peak_vram_mib'] or '-'} | {r['pos_per_s_total']} | {r['pos_per_s_proofs']} |")
for r in rows:
    print(r["run"], r["mode"], "controls", r["controls"], "declines", r["declines"], "id", r["identity"][:16])
