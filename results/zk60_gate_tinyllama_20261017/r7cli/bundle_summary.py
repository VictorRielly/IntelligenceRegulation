#!/usr/bin/env python3
"""P-18 (R7): summary of the CLI-run capture bundle against the CLI's own
published statement. Public data only.  python3 bundle_summary.py <out.json>
(never overwrites)."""
import hashlib, json, os, sys
B = "/home/victor/zk60-artifacts/tinyllama-cli-r7-capture-dense-l2"
S = "/home/victor/zk60-artifacts/tinyllama-cli-r7-run-l2/statement"
P = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/r7cli/r7cli-source-pins.v1.json"
dst = sys.argv[1]
if os.path.exists(dst):
    raise SystemExit(f"{dst} exists")
hx = lambda v: bytes(v).hex() if isinstance(v, list) else v
man = json.load(open(os.path.join(B, "manifest.json")))
run = json.load(open(os.path.join(B, "run.json")))
stmt = json.load(open(os.path.join(S, "statement.json")))
segs = json.load(open(os.path.join(S, "segments.json")))
pins = {p["file"]: p["sha256"] for p in man["source_pins"]}
gate = {r["pin"]: r["sha256_gate_copy"] for r in json.load(open(P))["pins"]}
stages = [json.load(open(os.path.join(B, f"stage-{k:02d}.json"))) for k in range(man["blocks"])]
out = {
    "bundle": B,
    "manifest_sha256": hashlib.sha256(open(os.path.join(B, "manifest.json"), "rb").read()).hexdigest(),
    "schema": man["schema"], "profile": man["profile"], "blocks": man["blocks"], "source_commit": man["source_commit"],
    "files": [(f["file"], f["bytes"], f["sha256"]) for f in man["files"]],
    "total_bytes": man["total_bytes"],
    "source_pins_count": len(pins),
    "source_pins_equal_gate_copy_r7cli_v1": pins == gate,
    "run_capture_rs_pin": pins.get("src/private_block/run_capture.rs"),
    "statement_dir": S,
    "statement_written_by": stmt["statement_written_by"],
    "statement_identity": stmt["trained_statement_identity"],
    "run_calibration_hex": hx(run["calibration"]),
    "calibration_equals_identity": hx(run["calibration"]) == stmt["trained_statement_identity"],
    "context_equals_statement": hx(run["context"]) == stmt["context"],
    "expected_policy_equals_statement_expected_io": hx(run["expected_policy"]) == stmt["expected_io"],
    "stage_segment_pins_equal_cli_segments_json": [(s["segment_bytes"], s["segment_sha256"]) for s in stages] == [(e["bytes"], e["sha256"]) for e in segs],
    "fully_verified": run["fully_verified"], "privacy_review_complete": run["privacy_review_complete"],
    "note": "a CAPTURE of the production CLI's receipt; NOT a privacy result",
}
json.dump(out, open(dst, "w"), indent=1)
print(json.dumps({k: v for k, v in out.items() if k != "files"}, indent=1))
