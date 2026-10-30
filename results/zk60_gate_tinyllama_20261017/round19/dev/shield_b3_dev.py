#!/usr/bin/env python3
"""Gate round 19 dev check: staging_v22's Shieldstral B-3 derivation (numpy port of native R12b
recompute_profile) against the PUBLISHED statement of a real round-16 run (public fields only:
embedding_digest, margin_vector_digest). Writes digests and timings only, never a table."""
import json, os, struct, sys, time
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v22/scripts"
sys.path.insert(0, S)
import zk60_native_rg_classtied as T
import zk60_native_rg_classterminals as CT
EX = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128"
ST = "/home/victor/zk60-artifacts/token-io/r16-runs/sexual-run/statement/statement.json"
st = json.load(open(ST))
scale = struct.unpack("<d", struct.pack("<Q", 0x3ED11FF597DB2FB6))[0]
t0 = time.time()
dv = T.shieldstral_derive(EX, st["yes_id"], st["no_id"], scale, authenticate=True)
w_dig = CT.w_digest(T.SHIELD_D, dv["w"])
out = {"statement": ST, "statement_embedding_digest": st["embedding_digest"], "derived_embedding_digest": dv["emb_digest"],
       "embedding_equal": dv["emb_digest"] == st["embedding_digest"],
       "statement_margin_digest": st["margin_vector_digest"], "derived_margin_digest": w_dig,
       "margin_equal": w_dig == st["margin_vector_digest"], "scale": scale, "scale_equal_statement": scale == st["margin_scale"],
       "checkpoint_sha256": dv["checkpoint_sha256"], "emb_sha256_int16": dv["emb_sha256"], "w_sha256_int16": dv["w_sha256"],
       "emb_min_max": [int(dv["emb"].min()), int(dv["emb"].max())], "w_min_max": [min(dv["w"]), max(dv["w"])],
       "derive_seconds": dv["seconds"]}
t1 = time.time()
r = [((7 * i + 3) % T.P, (11 * i + 5) % T.P) for i in range(12)]
ef = T.emb_fold_np(dv["emb"], T.SHIELD_D, r)
out["fold_seconds"] = round(time.time() - t1, 1)
# spot check the numpy fold against the exact pure-Python fold on 64 rows
from zk60_native_jv_field import eq_table_msb, f2_add, f2_mul_base
e = eq_table_msb(r)
bad = 0
for v in list(range(32)) + list(range(131040, 131072)):
    acc = (0, 0)
    for i in range(T.SHIELD_D):
        w = int(dv["emb"][v, i])
        if w:
            acc = f2_add(acc, f2_mul_base(e[i], w % T.P))
    bad += acc != ef[v]
out["fold_spot_rows"] = 64
out["fold_spot_differing"] = bad
try:
    import resource
    out["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
except Exception:
    pass
out["total_seconds"] = round(time.time() - t0, 1)
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "shield_b3_dev.json"), "w"), indent=1)
print(json.dumps(out))
sys.exit(0 if out["embedding_equal"] and out["margin_equal"] and not bad else 1)
