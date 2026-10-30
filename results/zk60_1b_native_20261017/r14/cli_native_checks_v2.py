"""Experimental R14 CLI actual-L25 gates; requires an explicitly pinned build.

No legacy registration and no full-26/classifier/privacy acceptance.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GUARD = ROOT / "scripts/zk60_resource_guard.py"
EXPORT = ROOT / "results/zk60_shieldstral_export_20261026/native_low_h24_t128"
GUARD_SHA = "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-pin", type=Path, required=True)
    parser.add_argument("--tree", type=Path, required=True)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--attempt", required=True)
    args = parser.parse_args()
    pin = json.loads(args.source_pin.read_text())
    binary_sha = sha(args.binary)
    out = HERE / ("cli-native-" + args.attempt)
    assert not out.exists()
    out.mkdir()
    accepted = json.loads((HERE / "ACTUAL_L25_NATIVE_ACCEPTANCE.json").read_text())
    models = {row["proof"]["dd"]: row["proof"]["model_identity"] for row in accepted["cases"] if "proof" in row}
    records = []

    def check():
        assert sha(GUARD) == GUARD_SHA
        assert sha(args.binary) == binary_sha
        for name, want in pin["files"].items():
            assert sha(args.tree / name) == want, name
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()

    def run(name, command, need, cap, expected=0, detail=None):
        check()
        label = "sol-r14-cli-" + args.attempt + "-" + name
        leaf = [sys.executable, str(GUARD), "run", "--class", "cpu", "--label", label,
                "--need-gib", str(need), "--cap-gib", str(cap), "--wait-secs", "21600", "--max-secs", "1800",
                "--log", str(out / (name + ".log")), "--done", str(out / (name + ".done")),
                "--result-json", str(out / (name + ".guard.json")), "--", "/usr/bin/env",
                "RAYON_NUM_THREADS=8", "OPENBLAS_NUM_THREADS=1", str(args.binary), *command]
        path = out / (name + ".command.json")
        assert not path.exists()
        path.write_text(json.dumps({"command": leaf, "source": pin["tree_sha256"],
                                   "binary_sha256": binary_sha, "runner_sha256": sha(Path(__file__))}, indent=2) + "\n")
        result = subprocess.run(leaf, cwd=ROOT)
        check()
        assert result.returncode == expected, (name, result.returncode, expected)
        log = (out / (name + ".log")).read_text()
        events = [json.loads(line) for line in log.splitlines() if line.startswith("{")]
        assert events, name
        if expected == 0:
            assert not any(e.get("event") in ["rejected", "refused"] for e in events)
        else:
            assert any(e.get("event") in ["rejected", "refused"] for e in events)
        if detail:
            assert detail in log, (name, "wrong refusal")
        row = {"name": name, "source": pin["tree_sha256"], "binary_sha256": binary_sha,
               "events": events, "guard": json.loads((out / (name + ".guard.json")).read_text())}
        records.append(row)
        (out / (name + ".validated.done")).write_text("0\n")
        (out / "PROGRESS.json").write_text(json.dumps(records, indent=2) + "\n")
        return events

    for dd in [False, True]:
        mode = "dd" if dd else "non-dd"
        extras = ["--dd"] if dd else []
        artifact = out / mode
        unverified = artifact.with_name(mode + ".unverified-statement")
        cmd = ["stack-prove", "--experimental-r14", "--export", str(EXPORT), "--layers", "25..26",
               "--seq-dir", str(HERE / "cli-l25-sequence"), "--out", str(artifact), "--witness-cache-gib", "0", *extras]
        events = run(mode + "-prove", cmd, 8, 10.5)
        proof = [event for event in events if event.get("event") == "proven"]
        sealed = [event for event in events if event.get("event") == "sealed"]
        assert len(proof) == len(sealed) == 1
        assert proof[0]["statement_identity"] == models[dd]
        assert proof[0]["privacy_accepted"] is False and proof[0]["verified_in_process"] is False
        assert sealed[0]["checked_before_run_header"] is True and sealed[0]["kept_witness_bytes"] == 0
        assert unverified.is_dir() and not (artifact / "statement").exists()
        # Keep an unmodified, unverified template for the native publication race.
        race = out / (mode + "-m9-input")
        shutil.copytree(artifact, race)
        shutil.copytree(unverified, race.with_name(race.name + ".unverified-statement"))
        model, binding = proof[0]["statement_identity"], proof[0]["binding"]
        verify = ["stack-verify", "--experimental-r14", "--export", str(EXPORT), "--layers", "25..26",
                  "--artifact", str(artifact), "--expect-statement", model, "--expect-binding", binding, *extras]
        fresh = run(mode + "-fresh", verify, 2.5, 5)
        ok = [event for event in fresh if event.get("event") == "verified"]
        assert len(ok) == 1 and ok[0]["statement_promoted"] is True
        assert (artifact / "statement").is_dir() and not unverified.exists()
        # The pin is supplied by the caller, independently of statement JSON.
        wrong = verify.copy()
        wrong[wrong.index("--expect-binding") + 1] = ("00" if binding[:2] != "00" else "01") + binding[2:]
        run(mode + "-wrong-binding", wrong, 2.5, 5, 1, "run binding differs from the caller's pin")
        bad = out / (mode + "-scalar-corrupt")
        shutil.copytree(artifact, bad)
        frames = sorted(bad.glob("segment*.bin"))
        assert len(frames) == 1
        frame = bytearray(frames[0].read_bytes())
        offset, prime = 120 + 3 * 32, 0xffffffff00000001
        scalar = int.from_bytes(frame[offset:offset + 8], "little")
        assert scalar < prime
        frame[offset:offset + 8] = ((scalar + 1) % prime).to_bytes(8, "little")
        frames[0].write_bytes(frame)
        corrupt = verify.copy()
        corrupt[corrupt.index("--artifact") + 1] = str(bad)
        run(mode + "-scalar-corrupt", corrupt, 2.5, 5, 1, "sumcheck round 0")
    # H-1: a valid native witness with a false reference output must refuse
    # before creating a run/header/statement. The sequence manifest is kept valid.
    sequence = out / "bad-reference"
    shutil.copytree(HERE / "cli-l25-sequence", sequence)
    path = sequence / "x_out_L25.bin"
    data = bytearray(path.read_bytes())
    data[0] ^= 1
    path.write_bytes(data)
    manifest = json.loads((sequence / "manifest.json").read_text())
    manifest["arrays"]["x_out_L25"]["sha256"] = sha(path)
    (sequence / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    artifact = out / "h1-refused"
    run("h1-refused", ["stack-prove", "--experimental-r14", "--export", str(EXPORT), "--layers", "25..26",
                       "--seq-dir", str(sequence), "--out", str(artifact)], 2.5, 5, 1,
        "parity: the native block output differs")
    assert not artifact.exists() and not artifact.with_name(artifact.name + ".unverified-statement").exists()
    report = {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"],
              "binary_sha256": binary_sha, "cases": records,
              "scope": "Experimental actual S2 L25/T128 CLI, independent oracle parity, strict model identity, streamed public blocks, fresh public-export verification/promotion, caller binding pin, canonical receipt mutation refusal and H1 pre-header refusal. No full26/classifier/privacy acceptance."}
    (out / "ACCEPTANCE.json").write_text(json.dumps(report, indent=2) + "\n")
    (out / "ACCEPTANCE.done").write_text("0\n")
    print("Experimental R14 actual-L25 CLI gates PASS")

if __name__ == "__main__":
    main()
