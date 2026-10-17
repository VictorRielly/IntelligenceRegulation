#!/usr/bin/env python3
"""NATIVE LANE round 5: the R5-4 table (Llama-3-8B 32-block stack at T32 and
the TinyLlama 22-block stack at T128, CPU and GPU) from the run logs and
guard records, each beside the previous round's run of the same stack.
Every number is read from a file. [MEASURED, shared box, n=1]"""
import json, os
D = os.path.dirname(os.path.abspath(__file__))

def events(path):
    out = {}
    if os.path.exists(path):
        for line in open(path, errors="replace"):
            if line.startswith('{"event"'):
                try:
                    e = json.loads(line)
                except Exception:
                    continue
                out.setdefault(e["event"], []).append(e)
    return out

def guard(path):
    return json.load(open(path)) if os.path.exists(path) else {}

runs = [("Llama-3-8B T32", "r4", "r4/stack-llama3_8b_pg_rot1_T32-ho00-cpu", 32, 32, "CPU"),
        ("Llama-3-8B T32", "r5", "r5/stack-llama3_8b_pg_rot1_T32-ho00-cpu", 32, 32, "CPU"),
        ("Llama-3-8B T32", "r4", "r4/stack-llama3_8b_pg_rot1_T32-ho00-gpu", 32, 32, "GPU"),
        ("Llama-3-8B T32", "r5", "r5/stack-llama3_8b_pg_rot1_T32-ho00-gpu", 32, 32, "GPU"),
        ("TinyLlama T128", "r3", "r3/stack-pg_rot1_b4_T128-ho00-cpu", 128, 22, "CPU"),
        ("TinyLlama T128", "r5", "r5/stack-pg_rot1_b4_T128-ho00-cpu", 128, 22, "CPU"),
        ("TinyLlama T128", "r3", "r3/stack-pg_rot1_b4_T128-ho00-gpu", 128, 22, "GPU"),
        ("TinyLlama T128", "r5", "r5/stack-pg_rot1_b4_T128-ho00-gpu", 128, 22, "GPU")]
rows = []
for name, rnd, rel, t, nb, mode in runs:
    p = events(os.path.join(D, rel, "prove.log"))
    v = events(os.path.join(D, rel, "verify.log"))
    gp = guard(os.path.join(D, rel, "prove.guard.json"))
    gv = guard(os.path.join(D, rel, "verify.guard.json"))
    if "proved" not in p:
        continue
    pr = p["proved"][0]
    ver = v.get("verified", [{}])[0]
    wit = pr["of_which_witness_seconds"]
    bl = pr.get("of_which_block_load_seconds", 0.0)
    ipv = pr.get("in_process_verify_seconds", 0.0) if pr.get("in_process_verified", True) else 0.0
    proofs = pr["prove_run_seconds"] - wit - bl
    wall = gp["child_wall_seconds"]
    vv = ver.get("verify_seconds")
    vbl = ver.get("of_which_block_load_seconds", 0.0)
    seg = os.path.join(D, rel, "run", "statement", "segments.json")
    lens = [s["bytes"] for s in json.load(open(seg))] if os.path.exists(seg) else None
    rows.append(dict(run=name, round=rnd, mode=mode, blocks=nb, total_wall_s=round(wall, 1), digest_pass_s=pr["load_seconds"], sealing_s=pr["sealing_pass_seconds"],
                     witness_s=wit, witness_per_block_s=round(wit / nb, 3), block_load_in_prove_s=bl, proofs_only_s=round(proofs, 1), proofs_per_block_s=round(proofs / nb, 2),
                     in_process_verified=pr.get("in_process_verified", True), in_process_verify_s=ipv, fresh_verify_s=vv,
                     fresh_verify_crypto_s=None if vv is None else round(vv - vbl, 1), fresh_verify_wall_s=gv.get("child_wall_seconds"),
                     controls=v.get("stack-controls", [{}])[0].get("refused"), receipt_bytes=pr["receipt_bytes"], segment_lengths=lens,
                     peak_rss_gib=gp.get("peak_rss_gib"), peak_vram_mib=gp.get("peak_vram_mib"), gpu=pr["gpu"], declines=pr["gpu_declines"],
                     identity=pr["statement_identity"], pos_per_s_total=round(t / wall, 3), pos_per_s_proofs=round(t / proofs, 3)))
json.dump(rows, open(os.path.join(D, "r5", "table.json"), "w"), indent=1)
print("| run | round | mode | blocks | total wall (s) | digest pass (s) | witness (s) [per block] | block loads in proving pass (s) | proofs only (s) [per block] | in-proc verify (s) | fresh verify (s) [crypto only] | receipt (B) | peak RSS (GiB) | peak VRAM (MiB) | positions/s total | positions/s proofs |")
print("|" + "---|" * 16)
for r in rows:
    ipv = r["in_process_verify_s"] if r["in_process_verified"] else "off"
    print(f"| {r['run']} | {r['round']} | {r['mode']} | {r['blocks']} | {r['total_wall_s']} | {r['digest_pass_s']} | {r['witness_s']} [{r['witness_per_block_s']}] | {r['block_load_in_prove_s']} | {r['proofs_only_s']} [{r['proofs_per_block_s']}] | {ipv} | {r['fresh_verify_s']} [{r['fresh_verify_crypto_s']}] | {r['receipt_bytes']:,} | {r['peak_rss_gib']} | {r['peak_vram_mib'] or '-'} | {r['pos_per_s_total']} | {r['pos_per_s_proofs']} |")
print()
for r in rows:
    print(r["run"], r["round"], r["mode"], "controls", r["controls"], "declines", r["declines"], "id", r["identity"][:16])
# segment-length identity between the rounds of the same stack and mode
by = {}
for r in rows:
    by.setdefault((r["run"], r["mode"]), []).append(r)
for k, rs in by.items():
    if len(rs) == 2:
        a, b = rs
        print(k, "identity equal:", a["identity"] == b["identity"], "| segment lengths equal:", a["segment_lengths"] == b["segment_lengths"], "| receipt bytes equal:", a["receipt_bytes"] == b["receipt_bytes"])
