"""Regenerate four synthetic CLI receipts with one immutable reported binary."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
R13 = ROOT / "results/zk60_1b_native_20261017/r13"
spec = importlib.util.spec_from_file_location("r13_f1_guard", HERE.parent / "r13_guard.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
guard.R13 = HERE


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def check_source():
    source = json.loads((HERE / "candidate.source.json").read_text())
    assert all(sha(HERE / "working-tree" / rel) == want for rel, want in source["files"].items())
    return source["tree_sha256"]


def events(stem):
    return [json.loads(s) for s in (HERE / f"{stem}.log").read_text().splitlines() if s.startswith("{")]


def main():
    source = check_source()
    built = HERE / "working-tree/hashline/target/release/examples/zk60_trained_block"
    cli = HERE / "zk60_trained_block.r13-f1.release.bin"
    assert (HERE / "sol-r13-f1-cli-build-1.done").read_text().strip() == "0"
    if not cli.exists():
        shutil.copy2(built, cli)
    assert sha(cli) == sha(built)
    binary_sha = sha(cli)
    (HERE / "CLI_PIN.json").write_text(json.dumps({"path": str(cli), "sha256": binary_sha, "source_tree_sha256": source}, indent=2) + "\n")

    def run(label, command):
        check_source()
        assert sha(cli) == binary_sha
        done = HERE / f"{label}.done"
        if done.exists():
            assert done.read_text().strip() == "0", label
            return
        while True:
            check = subprocess.run([sys.executable, str(guard.GUARD), "check", "--class", "cpu", "--need-gib", "2.5"],
                                   cwd=ROOT, capture_output=True, text=True)
            if check.returncode == 0 and "OK to start now" in check.stdout:
                break
            print(datetime.now(timezone.utc).isoformat(), label, "waiting for CPU admission", flush=True)
            time.sleep(10)
        guard.run(label, "cpu", 2.5, 4, ["/usr/bin/env", "RAYON_NUM_THREADS=2", "OPENBLAS_NUM_THREADS=1", *map(str, command)], seconds=600)
        check_source()
        assert sha(cli) == binary_sha

    records = []
    for name in ["r13-low-dense", "r13-h24-wide"]:
        public = R13 / "release-exports" / name
        inputs = R13 / "loader-fixtures" / name / "seq_public"
        for dd in [False, True]:
            case = name + ("-dd" if dd else "-plain")
            flags = ["--dd"] if dd else []
            out = HERE / "receipts" / case
            out.parent.mkdir(parents=True, exist_ok=True)
            record = {"case": case, "utc_before_prove": datetime.now(timezone.utc).isoformat(),
                      "cli_sha256": binary_sha, "cli_path": str(cli), "source_tree_sha256": source,
                      "profile_sha256": sha(public / "profile.json"), "scope": "public synthetic fixture"}
            # This provenance exists BEFORE the binary runs, never inferred after a rebuild.
            (HERE / f"{case}.binary-before-run.json").write_text(json.dumps(record, indent=2) + "\n")
            prove = "sol-r13-f1-prove-" + case
            run(prove, [cli, "prove", "--export", public, "--layer", "0", "--seq-dir", inputs, "--out", out, "--controls", *flags])
            proof_events = [e for e in events(prove) if e.get("event") == "proved"]
            assert len(proof_events) == 1
            identity = proof_events[0]["statement_identity"]
            old = json.loads((R13 / f"release-2-cli-{case}.json").read_text())
            assert identity == old["statement_identity"], "CLI-only correction changed the trained statement"
            verify = "sol-r13-f1-verify-" + case
            run(verify, [cli, "verify", "--export", public, "--layer", "0", "--artifact", out, "--expect-statement", identity, "--controls", *flags])
            ev = events(verify)
            controls = [e for e in ev if e.get("event") == "calibration-controls"]
            assert controls == [{"event": "calibration-controls", "receipt_refusals": 11, "door_refusals": 0}], controls
            ref = [e for e in ev if e.get("event") == "control-refused"]
            assert len(ref) == 19 and all(e["error"] == "private run wire: this segment belongs to another run" for e in ref[:11])
            assert any(e.get("event") == "verified" for e in ev)
            assert [e for e in ev if e.get("event") == "controls"] == [{"event": "controls", "refused": 19, "honest_still_verifies": True}]
            compat = "sol-r13-f1-old-" + case
            run(compat, [cli, "verify", "--export", public, "--layer", "0", "--artifact", R13 / "release-receipts/release-2" / case,
                         "--expect-statement", old["statement_identity"], *flags])
            assert any(e.get("event") == "verified" for e in events(compat))
            record.update({"statement_identity": identity, "receipt_dir": str(out), "segment_sha256": sha(out / "segment-000.bin"),
                           "calibration_controls_reach_receipt": 11, "all_refusals": 19, "old_receipt_verifies": True})
            (HERE / f"{case}.PASS.json").write_text(json.dumps(record, indent=2) + "\n")
            records.append(record)
    assert check_source() == source and sha(cli) == binary_sha
    report = {"utc": datetime.now(timezone.utc).isoformat(), "status": "R13-F1 four regenerated receipts and fresh controls PASS",
              "source_tree_sha256": source, "cli_sha256": binary_sha, "cases": records,
              "calibration_receipt_refusals": 44, "all_fresh_controls_refused": 76,
              "unchanged_old_statement_identities": 4, "old_receipts_verified": 4,
              "scope": "CLI control/evidence correction only; frozen R13 retained; no new relation, S4 profile or security acceptance"}
    (HERE / "F1_ACCEPTANCE.json").write_text(json.dumps(report, indent=2) + "\n")
    (HERE / "F1_ACCEPTANCE.done").write_text("0\n")
    print(json.dumps({"status": report["status"], "cli_sha256": binary_sha}), flush=True)


if __name__ == "__main__":
    main()
