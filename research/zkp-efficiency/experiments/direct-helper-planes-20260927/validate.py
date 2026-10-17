#!/usr/bin/env python3
"""Read-only artifact/pin audit; the differential oracle lives in experiment.py."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
result = json.loads((HERE / "result.json").read_text())
traffic = json.loads((HERE / "traffic.json").read_text())
records = json.loads((HERE / "source-records.json").read_text())
log = json.loads((HERE / "run.log").read_text())
assert result == log
assert result["status"] == "passed"
assert result["source_sha256"] == hashlib.sha256((HERE / "experiment.py").read_bytes()).hexdigest()
pins = {
    "protocol_rs": "/tmp/zk60-groups-20260926/hashline/src/private_block/protocol.rs",
    "layout_rs": "/tmp/zk60-groups-20260926/hashline/src/private_block/layout.rs",
    "shape_rs": "/tmp/zk60-groups-20260926/hashline/src/private_block/shape.rs",
    "model_m125_json": "/home/victor/IntelligenceRegulation/results/zk60_generic_rank_lemma_shaped/model/model_m125.json",
    "owner_measured_summary_json": "/home/victor/IntelligenceRegulation/results/zk60_sol_fusion_20260927/dense-ab-1/measured-summary.json",
    "owner_02_old_log": "/home/victor/IntelligenceRegulation/results/zk60_sol_fusion_20260927/dense-ab-1/02-old.log",
    "owner_05_old_log": "/home/victor/IntelligenceRegulation/results/zk60_sol_fusion_20260927/dense-ab-1/05-old.log",
}
for key, path in pins.items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == traffic["source_hashes_sha256"][key]
assert result["native_source_sha256"] == traffic["source_hashes_sha256"]["protocol_rs"]
model = json.loads(Path(pins["model_m125_json"]).read_text())
count = 0
for domain, helpers in {"L":1,"D":17,"Q":7,"Kv":6,"S":8,"F":5}.items():
    words = helpers * model["domains"][domain]["padded"]
    assert traffic["helper_words_by_domain"][domain] == words
    count += words
assert traffic["helper_words_total"] == count
assert traffic["baseline_temp_vec_write_read_bytes"] == 32 * count
assert traffic["looked_words_total"] == model["lookups"]["u8_total"]
assert traffic["transactional_preflight_added_successful_proof_input_payload_bytes"] == 8 * model["lookups"]["u8_total"]
saved = [json.loads(line) for line in (ROOT / "sources.jsonl").read_text().splitlines() if line.strip()]
assert [x for x in saved if x.get("cycle") == "0011"] == records
print(json.dumps({"status":"passed","source_pins":len(pins),"source_records":len(records),"helper_words":count,"traffic_bytes":32*count},indent=2))
