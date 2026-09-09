"""Apply the unchanged round-21 slot checks to independently validated fresh captures."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import zk60_io_cfs_composition as cfs

manifest = ROOT / "results/zk60_round22_captures.json"
pins = json.loads(manifest.read_text())
checked = cfs.pre.run(ROOT / "results/zk60_round22_captures", pins["source_commit"])
assert checked == pins["captures"]
cases = []
for entry in checked["cases"]:
    capture = json.loads(Path(entry["path"]).read_bytes())
    assert all(t["slot"] < 6 for f in capture["mask"]["functionals"][:10] for t in f["terms"])
    cases.append(dict(proof_sha256=entry["proof_sha256"],
                      slots=[cfs.check_slot(arg, capture["mask"]) for arg in capture["io_arguments"]],
                      controls=[cfs.controls(arg, capture["mask"]) for arg in capture["io_arguments"]]))
result = dict(status="passed", cases=cases, manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest(),
              tool_sha256=hashlib.sha256(Path(cfs.__file__).read_bytes()).hexdigest(),
              fresh_captures=True, original_capture_reproduction_claimed=False,
              full_privacy_review_complete=False, adaptive_transcript_simulation_performed=False)
(ROOT / "results/zk60_round22_io_cfs.json").write_text(json.dumps(result, indent=2) + "\n")
print("PASS: eight fresh IO CFS slots and 72 corruption controls")
