"""One resumable, exact integer reference layer for a public R14 stack fixture.

Uses the unchanged reviewer's independently written S2 reference, never a
native witness dump. Each layer is a separate guarded leaf. This script is
prepared for the full-stack gate; preparing it is not a full-stack result.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import importlib.util
import json
import sys

sys.dont_write_bytecode = True
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
EXPORT = ROOT / "results/zk60_shieldstral_export_20261026/native_low_h24_t128"
REFERENCE = ROOT / "results/zk60_d24_review_20261017/r13/reviewer_export_reference.py"
PROFILE_SHA = "2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--layer", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference-sha256", required=True)
    args = parser.parse_args()
    assert 0 <= args.layer < 26
    assert sha(REFERENCE) == args.reference_sha256
    assert sha(EXPORT / "profile.json") == PROFILE_SHA
    profile = json.loads((EXPORT / "profile.json").read_text())
    assert profile["T"] == 128 and len(profile["layers"]) == 26
    row = profile["layers"][args.layer]
    assert row["layer"] == args.layer
    manifest_path = EXPORT / row["dir"] / "manifest.json"
    assert sha(manifest_path) == row["manifest_sha256"]
    manifest = json.loads(manifest_path.read_text())
    pins = {}
    # The independent reference loader does no authentication of its own.
    # Authenticate every public payload before it can influence a trace.
    for name, spec in manifest["arrays"].items():
        path = manifest_path.parent / spec["file"]
        assert sha(path) == spec["sha256"], name
        pins[name] = spec["sha256"]
    spec = importlib.util.spec_from_file_location("retained_reviewer_s2_reference", REFERENCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    report_path = out / f"layer_{args.layer:02}.json"
    input_path = out / f"x_in_L{args.layer:02}.bin"
    output_path = out / f"x_out_L{args.layer:02}.bin"
    assert not report_path.exists() and not input_path.exists() and not output_path.exists()
    previous = None
    if args.layer == 0:
        # Same explicit public synthetic input used by the actual-L00 native
        # gate. This is backend arithmetic coverage, not an app/fidelity input.
        x = np.zeros((128, 3072), dtype=np.int64)
        for t in range(128):
            for j in range(32):
                x[t, (j * 97 + t * 13) % 3072] = 1 if (j + t) % 2 else -1
    else:
        previous = json.loads((out / f"layer_{args.layer-1:02}.json").read_text())
        prior = out / f"x_out_L{args.layer-1:02}.bin"
        assert previous["layer"] == args.layer - 1 and sha(prior) == previous["output_sha256"]
        assert previous["profile_sha256"] == PROFILE_SHA
        assert previous["reference_sha256"] == args.reference_sha256
        x = np.fromfile(prior, dtype="<i2").astype(np.int64).reshape(128, 3072)
    layer = module.load_layer(str(EXPORT), args.layer)
    trace = module.block(layer, x, "h24", 32, 8, 128)
    assert trace.pop("act_tables_equal_reviewer_generator") is True
    constants = manifest["constants"]
    groups = layer["silu_groups"]
    ids = layer["silu_group_ids"]
    exponent = 24 - constants["sh_h"] + groups[ids, 1] - constants["silu_member"][1]
    assert np.all((0 <= exponent) & (exponent <= 16))
    trace["a_raw"] = trace["a_raw"] * np.left_shift(np.int64(1), exponent)
    names = {"x": "input", "u": "up", "a_raw": "a_scaled"}
    traces = []
    for name, value in trace.items():
        value = np.asarray(value, dtype="<i8")
        traces.append({"site": names.get(name, name), "shape": list(value.shape),
                       "sha256": hashlib.sha256(value.tobytes()).hexdigest(),
                       "range": [int(value.min()), int(value.max())]})
    assert len(traces) == 19
    if args.layer == 0:
        accepted = json.loads((HERE / "ACTUAL_S2_NATIVE_ACCEPTANCE.json").read_text())
        proof = next(case for case in accepted["cases"] if "trace_sites" in case)
        want = {site["site"]: site["sha256"] for site in proof["trace_sites"]}
        assert {site["site"]: site["sha256"] for site in traces} == want
    x.astype("<i2").tofile(input_path)
    trace["x2"].astype("<i2").tofile(output_path)
    report = {"utc": datetime.now(timezone.utc).isoformat(), "layer": args.layer,
              "scope": "Independent exact S2 integer reference, actual public model weights, explicit public synthetic input; no native full-stack proof or classifier/privacy acceptance.",
              "profile_sha256": PROFILE_SHA, "manifest_sha256": row["manifest_sha256"],
              "reference_sha256": args.reference_sha256, "script_sha256": sha(Path(__file__)),
              "input_sha256": sha(input_path), "output_sha256": sha(output_path),
              "previous_report_sha256": None if previous is None else sha(out / f"layer_{args.layer-1:02}.json"),
              "public_array_sha256": pins, "traces": traces}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"layer": args.layer, "trace_sites": 19, "integer_reference": "PASS", "native_full_stack": False}))

if __name__ == "__main__":
    main()
