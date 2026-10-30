"""Source-pinned full26 actual S2 proof, fresh public verifier, and tamper gates.

Run only after authenticated astra-smoke-prefix-1 and final build acceptance are complete.
Shared-host observations are correctness runs, not performance benchmarks.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "full26-native-1"
REF = HERE / "astra-smoke-prefix-1"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
EXPORT = ROOT / "results/zk60_shieldstral_export_20261026/native_low_h24_t128"
GUARD_SHA = "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
PROFILE_SHA = "2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")

def main():
    for directory in [REF, HERE / "final-validation-1"]:
        assert (directory / "ACCEPTANCE.done").read_text().strip() == "0"
    build = json.loads((HERE / "final-validation-1/ACCEPTANCE.json").read_text())
    reference = json.loads((REF / "ACCEPTANCE.json").read_text())
    assert len(reference["layers"]) == 26 and not reference["native_full_stack_proved"]
    assert reference["manifest_sha256"] == sha(REF / "manifest.json")
    manifest = json.loads((REF / "manifest.json").read_text())
    assert len(manifest["arrays"]) == 52
    for name, info in manifest["arrays"].items():
        assert info["shape"] == [128, 3072] and info["dtype"] == "int16"
        assert sha(REF / info["file"]) == info["sha256"], name
    pin = json.loads((HERE / "sol-r14-final-build-1.source.json").read_text())
    assert pin["tree_sha256"] == build["source"]
    tree = HERE / "checkpoints/final-build-1/tree"
    binary = HERE / "checkpoints/final-build-1/zk60_split_stack.bin"
    binary_sha = sha(binary)
    assert binary_sha == build["cli_sha256"]
    assert not OUT.exists()
    OUT.mkdir()
    fixed = {p: sha(p) for p in [Path(__file__), REF / "ACCEPTANCE.json", REF / "manifest.json"]}
    records = []
    def check():
        assert sha(GUARD) == GUARD_SHA and sha(EXPORT / "profile.json") == PROFILE_SHA
        assert sha(binary) == binary_sha
        for path, want in fixed.items():
            assert sha(path) == want, path
        for name, want in pin["files"].items():
            assert sha(tree / name) == want, name
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    def run(name, args, need, cap, expected=0, reason=None):
        check()
        command = [sys.executable, str(GUARD), "run", "--class", "cpu", "--label", "sol-r14-full26-" + name + "-1",
                   "--need-gib", str(need), "--cap-gib", str(cap), "--wait-secs", "21600", "--max-secs", "1800",
                   "--log", str(OUT / (name + ".log")), "--done", str(OUT / (name + ".done")),
                   "--result-json", str(OUT / (name + ".guard.json")), "--", "/usr/bin/env",
                   "RAYON_NUM_THREADS=8", "OPENBLAS_NUM_THREADS=1", str(binary), *args]
        save(OUT / (name + ".command.json"), {"command": command, "source": pin["tree_sha256"],
             "binary_sha256": binary_sha, "runner_sha256": fixed[Path(__file__)]})
        result = subprocess.run(command, cwd=ROOT)
        check()
        assert result.returncode == expected, (name, result.returncode, expected)
        log = (OUT / (name + ".log")).read_text()
        events = [json.loads(line) for line in log.splitlines() if line.startswith("{")]
        if expected:
            assert any(event.get("event") in ["rejected", "refused"] for event in events)
            assert reason in log, (name, "unexpected refusal", log[-1000:])
        else:
            assert events and not any(event.get("event") in ["rejected", "refused"] for event in events)
        guard = json.loads((OUT / (name + ".guard.json")).read_text())
        assert guard["exit"] == guard["child_rc"] == expected and not guard["guard_killed"]
        records.append({"name": name, "events": events, "guard": guard, "log_sha256": sha(OUT / (name + ".log"))})
        save(OUT / "PROGRESS.json", records)
        (OUT / (name + ".validated.done")).write_text("0\n")
        print(name, "PASS", flush=True)
        return events
    modes = []
    for dd in [False, True]:
        mode = "dd" if dd else "non-dd"
        extra = ["--dd"] if dd else []
        artifact = OUT / mode
        events = run(mode + "-prove", ["stack-prove", "--experimental-r14", "--export", str(EXPORT),
                     "--layers", "0..26", "--seq-dir", str(REF), "--out", str(artifact),
                     "--witness-cache-gib", "0", *extra], 8, 10.5)
        sealed = [event for event in events if event.get("event") == "sealed"]
        proven = [event for event in events if event.get("event") == "proven"]
        segments = [event for event in events if event.get("event") == "segment"]
        assert len(sealed) == len(proven) == 1 and len(segments) == 26
        assert sealed[0]["blocks"] == proven[0]["blocks"] == 26
        assert sealed[0]["checked_before_run_header"] is True and sealed[0]["kept_witness_bytes"] == 0
        assert sealed[0]["parity"] == "bit-exact at every layer"
        assert proven[0]["privacy_accepted"] is False and proven[0]["verified_in_process"] is False
        assert [(event["index"], event["layer"]) for event in segments] == [(k, k) for k in range(26)]
        unverified = artifact.with_name(mode + ".unverified-statement")
        assert unverified.is_dir() and not (artifact / "statement").exists()
        model, binding = proven[0]["statement_identity"], proven[0]["binding"]
        # The fresh verifier independently authenticates all public arrays and
        # rebuilds the model; these recorded event pins are not an independent
        # external model-identity oracle.
        verify = ["stack-verify", "--experimental-r14", "--export", str(EXPORT), "--layers", "0..26",
                  "--artifact", str(artifact), "--expect-statement", model, "--expect-binding", binding, *extra]
        fresh = run(mode + "-fresh", verify, 2.5, 5)
        ok = [event for event in fresh if event.get("event") == "verified"]
        assert len(ok) == 1 and ok[0]["blocks"] == 26 and ok[0]["statement_promoted"] is True
        assert (artifact / "statement").is_dir() and not unverified.exists()
        statement = json.loads((artifact / "statement/statement.json").read_text())
        assert statement["layers"] == list(range(26)) and statement["blocks"] == 26
        assert statement["privacy_accepted"] is False and statement["binding"] == binding
        assert len(statement["profiles"]) == 26
        frame_pins = []
        for k, event in enumerate(segments):
            frame = artifact / f"segment-{k:03}.bin"
            assert frame.stat().st_size == event["bytes"]
            frame_pins.append({"index": k, "bytes": frame.stat().st_size, "sha256": sha(frame)})
        # Hard links retain unchanged regular files without another full-stack
        # copy. Only the attacked first frame is independently copied/written.
        bad = OUT / (mode + "-scalar-corrupt")
        bad.mkdir()
        shutil.copytree(artifact / "statement", bad / "statement")
        for k in range(1, 26):
            os.link(artifact / f"segment-{k:03}.bin", bad / f"segment-{k:03}.bin")
        frame = bytearray((artifact / "segment-000.bin").read_bytes())
        offset, prime = 120 + 32 + 3 * 32, 0xffffffff00000001
        scalar = int.from_bytes(frame[offset:offset + 8], "little")
        assert scalar < prime
        frame[offset:offset + 8] = ((scalar + 1) % prime).to_bytes(8, "little")
        (bad / "segment-000.bin").write_bytes(frame)
        corrupt = verify.copy()
        corrupt[corrupt.index("--artifact") + 1] = str(bad)
        run(mode + "-scalar-corrupt", corrupt, 2.5, 5, 1, "sumcheck round 0")
        assert sha(artifact / "segment-000.bin") == frame_pins[0]["sha256"]
        modes.append({"dd": dd, "artifact": str(artifact.relative_to(HERE)), "statement_identity": model,
                      "binding": binding, "segments": frame_pins, "bytes": sum(row["bytes"] for row in frame_pins)})
        save(OUT / (mode + "-verified.json"), modes[-1])
    save(OUT / "ACCEPTANCE.json", {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"],
         "binary_sha256": binary_sha, "reference_acceptance_sha256": sha(REF / "ACCEPTANCE.json"),
         "public_export_profile_sha256": PROFILE_SHA, "modes": modes,
         "reference_provenance": "Astra complete26 numerical baseline/cache residual parity and authenticated native export equivalence; separate reviewer int64 chain remains additional validation", "cases": records,
         "privacy_accepted": False, "performance_benchmark": False,
         "scope": "Actual S2 public weights, all26 T128 layers, independently computed numerical reference outputs checked before the header, DD/nonDD native proof and fresh public-only export verifier, exact segment pins, canonical first-scalar mutation rejects natively. Shared host n=1/8threads. No classifier, privacy acceptance or production registration."})
    (OUT / "ACCEPTANCE.done").write_text("0\n")
    print("Full26 actual S2 native proof/fresh/tamper PASS both variants", flush=True)

if __name__ == "__main__":
    main()
