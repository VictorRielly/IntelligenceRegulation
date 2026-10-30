#!/usr/bin/env python3
"""Gate round 19 dev run (staging_v22) of the non-block parts on the REAL Shieldstral capture, step by step
with timings and peak memory, to size the official frozen-v22 run. Writes round19/dev/real_dev.json."""
import json, os, resource, sys, time, traceback
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v22/scripts"
sys.path.insert(0, S)
sys.dont_write_bytecode = True
import zk60_native_rg_classgate as CG
import zk60_native_rg_classterminals as CT
import zk60_native_rg_classtied as TD
TD.SHIELD_EXPORT = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128"
C = sys.argv[1] if len(sys.argv) > 1 else "/home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-sexual-r16b"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "real_dev.json")
out = {"capture": C, "steps": {}}

def save():
    json.dump(out, open(OUT, "w"), indent=1, default=str)

def step(name, fn):
    t = time.time()
    try:
        r = fn()
        ok = r.get("ok") if isinstance(r, dict) else (r[0].get("ok") if isinstance(r, tuple) and isinstance(r[0], dict) else True)
        out["steps"][name] = {"ok": ok, "seconds": round(time.time() - t, 1),
                              "peak_rss_mb": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss // 1024}
        return r
    except Exception as e:
        out["steps"][name] = {"exception": repr(e)[:600], "tb": traceback.format_exc()[-1500:], "seconds": round(time.time() - t, 1)}
        return None
    finally:
        save()

b = step("load", lambda: CG.load(C))
i = step("integrity", lambda: CG.class_integrity(b))
if i:
    out["integrity_findings"] = i["findings"][:20]
    out["r13_stage_gates"] = i["r13_stage_gates"]
    out["pins"] = {k: i["source_pins"][k] for k in ("pins", "ok")}
rp = step("replay", lambda: CG.ClassRunReplay(b).run())
if rp is not None:
    out["replay_summary"] = {k: v for k, v in rp.summary().items() if k in ("run_binding_reproduced", "positions_checked", "challenges_checked")}
    from zk60_native_rg_hashlayer import check_hash_layer
    h = step("hash_layer", lambda: check_hash_layer(b))
    s3 = step("per_commitment", lambda: CG.class_stage3(b, rp, pad_rank=True))
    if s3:
        s3r, views = s3
        out["per_commitment_not_meeting"] = [(r["role"], r["disclosed_dimension"], r["expected_disclosed_dimension"]) for r in s3r["per_commitment"] if not r["meets_expectation"]][:10]
        out["per_commitment_count"] = len(s3r["per_commitment"])
        ct = step("classifier_slots_and_B3", lambda: CT.check_classify_terminals(b, rp))
        if ct:
            out["ct_findings"] = (ct.get("findings") or [])[:10]
            out["B3"] = {k: (ct.get("B3_margin_vector") or {}).get(k) for k in ("ok", "findings")}
            out["one_public_bit"] = {k: v for k, v in (ct.get("one_public_bit") or {}).items() if not isinstance(v, (list, dict))}
        step("NL1", lambda: CT.nl1_classify_slots(b, rp))
        step("joint", lambda: CG.class_joint_figure(b, views))
        step("mask_cfs", lambda: CG.class_mask_cfs(b, rp))
        # [attempt 2] the full zero-data preimage on a SAMPLE, timed per group, to size the official run:
        # stage IN-C, block 0, block 25, stage OUT-C (the boundary each opens included)
        from zk60_native_rg_ahpreimage import full_preimages
        L = b.l
        for tag, names in (("IN-C", ["A-in@0", "H-in@0", "E-token-in"]), ("block0", ["A@1", "H@1", "B0"]),
                           ("block25", [f"A@{L}", f"H@{L}", f"B{L - 1}"]), ("OUT-C", [f"A-out@{L + 1}", f"H-out@{L + 1}", f"B{L}"])):
            names = [n for n in names if n in views]
            r = step(f"preimage_{tag}", lambda: full_preimages(b, views, names=names))
            if r:
                out["steps"][f"preimage_{tag}"].update({k: r.get(k) for k in ("view_entries_compared", "view_entries_differing")})
                out["steps"][f"preimage_{tag}"]["names"] = names
                save()
out["total_peak_rss_mb"] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss // 1024
save()
print(json.dumps({k: out[k] for k in out if k != "steps"}, default=str)[:3000])
print(json.dumps(out["steps"], default=str)[:3000])
