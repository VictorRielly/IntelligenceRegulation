"""Receipt attacks for the single-root joint endpoint/boundary design.

There are no separately serialized piece roots. Ordered piece rows instead
share one salted Merkle leaf. Row attacks retain canonical field words,
header, roots, slot proofs and vector lengths, and must reach native PCS.
Structural/routing/root-ownership refusals are reported separately.
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
OUT = HERE / "joint-receipts-1"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
P = 0xffffffff00000001
N, Q, PATH = 16384, 256, 16

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")

def opening_len(groups, rows):
    return (groups + 1) * (N + Q) * 16 + Q * (8 + rows * 8 + 32 + PATH * 32)

def columns(frame, stage):
    groups, rows = (2, 31) if stage == 0 else (4, 34)
    tail = 0 if stage == 0 else opening_len(2, 31)
    start = len(frame) - 32 - tail - opening_len(groups, rows)
    offset = start + (groups + 1) * (N + Q) * 16
    stride = 8 + rows * 8 + 32 + PATH * 32
    assert start > 248
    positions = []
    for k in range(Q):
        at = offset + k * stride
        assert int.from_bytes(frame[at:at + 8], "little") < N * 4
        at += 8
        assert all(int.from_bytes(frame[at + 8*r:at + 8*r + 8], "little") < P for r in range(rows))
        positions.append(at)
    assert offset + Q * stride == len(frame) - 32 - tail
    return positions

def main():
    assert not OUT.exists()
    OUT.mkdir()
    build = json.loads((HERE / "final-validation-1/ACCEPTANCE.json").read_text())
    pin = json.loads((HERE / "sol-r14-final-build-1.source.json").read_text())
    assert build["source"] == pin["tree_sha256"]
    binary = HERE / "checkpoints/final-build-1/hashline.test.bin"
    tree = HERE / "checkpoints/final-build-1/tree"
    assert sha(binary) == build["test_binary_sha256"]
    script_sha = sha(Path(__file__))
    records = []
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        assert sha(binary) == build["test_binary_sha256"] and sha(Path(__file__)) == script_sha
        for name, want in pin["files"].items():
            assert sha(tree / name) == want, name
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    def run(name, dd, artifact, category, reason=None, mutation=None):
        check()
        mode = "dd" if dd else "non_dd"
        test = "private_block::argument::split_run_tests::split_run_t128_" + mode + "_fresh_verify_from_dir"
        command = [sys.executable, str(GUARD), "run", "--class", "cpu", "--label", "sol-r14-joint-" + name + "-1",
                   "--need-gib", "2.5", "--cap-gib", "5", "--wait-secs", "21600", "--max-secs", "600",
                   "--log", str(OUT / (name + ".log")), "--done", str(OUT / (name + ".done")),
                   "--result-json", str(OUT / (name + ".guard.json")), "--", "/usr/bin/env", "RAYON_NUM_THREADS=8",
                   "HL_R14_RUN_INPUT=" + str(artifact), str(binary), test, "--exact", "--ignored", "--nocapture", "--test-threads=1"]
        save(OUT / (name + ".command.json"), {"command": command, "source": pin["tree_sha256"],
             "binary_sha256": build["test_binary_sha256"], "runner_sha256": script_sha})
        result = subprocess.run(command, cwd=ROOT)
        check()
        expected = 0 if reason is None else 101
        assert result.returncode == expected, (name, result.returncode, expected)
        log = (OUT / (name + ".log")).read_text()
        if reason is None:
            assert "1 passed; 0 failed" in log and "R14_FRESH_NATIVE_STREAM " in log
        else:
            assert reason in log and "0 passed; 1 failed" in log, (name, log[-1500:])
        guard = json.loads((OUT / (name + ".guard.json")).read_text())
        assert guard["exit"] == guard["child_rc"] == expected and not guard["guard_killed"]
        row = {"case": name, "category": category, "dd": dd, "expected_verifier_test_exit": expected,
               "native_error_required": reason, "guard": guard, "log_sha256": sha(OUT / (name + ".log")),
               "mutation": mutation, "artifact": str(artifact.relative_to(HERE))}
        records.append(row)
        save(OUT / "PROGRESS.json", records)
        (OUT / (name + ".validated.done")).write_text("0\n")
        print(name, "PASS expected acceptance/refusal", flush=True)
    for dd in [False, True]:
        mode = "dd" if dd else "non-dd"
        original = HERE / "stream-fixtures" / mode
        foreign = HERE / "streaming-native-1" / (mode + "-source-prover")
        original_pins = {p.name: sha(p) for p in original.iterdir()}
        foreign_pins = {p.name: sha(p) for p in foreign.iterdir()}
        run(mode + "-honest", dd, original, "positive")
        run(mode + "-foreign-honest", dd, foreign, "positive")
        for stage, role in [(0, "endpoint"), (1, "boundary")]:
            source = (original / f"segment{stage}.bin").read_bytes()
            other = (foreign / f"segment{stage}.bin").read_bytes()
            positions, foreign_positions = columns(source, stage), columns(other, stage)
            for action in ["swap-piece-rows", "duplicate-piece-rows", "zero-drop-narrow", "foreign-narrow-mix"]:
                name = mode + "-" + role + "-" + action
                artifact = OUT / name
                artifact.mkdir()
                shutil.copy2(original / "statement.txt", artifact / "statement.txt")
                os.link(original / f"segment{1-stage}.bin", artifact / f"segment{1-stage}.bin")
                changed = bytearray(source)
                for at, foreign_at in zip(positions, foreign_positions):
                    wide, narrow = source[at:at + 16*8], source[at + 16*8:at + 24*8]
                    if action == "swap-piece-rows":
                        changed[at:at + 24*8] = narrow + wide
                    elif action == "duplicate-piece-rows":
                        changed[at + 16*8:at + 24*8] = wide[:8*8]
                    elif action == "zero-drop-narrow":
                        changed[at + 16*8:at + 24*8] = bytes(8*8)
                    else:
                        changed[at + 16*8:at + 24*8] = other[foreign_at + 16*8:foreign_at + 24*8]
                assert len(changed) == len(source) and changed != source
                assert changed[:positions[0]] == source[:positions[0]]
                columns(changed, stage)
                frame = artifact / f"segment{stage}.bin"
                frame.write_bytes(changed)
                detail = {"stage": stage, "rows": 31 if stage == 0 else 34, "wide_rows": 16, "narrow_rows": 8,
                          "source_frame_sha256": original_pins[frame.name], "mutated_frame_sha256": sha(frame),
                          "foreign_frame_sha256": foreign_pins[frame.name] if action == "foreign-narrow-mix" else None,
                          "changed_bytes": sum(a != b for a,b in zip(source, changed)),
                          "canonical_length_and_field_words": True,
                          "foreign_columns": "rows taken by opening position; foreign sampled column indices may differ" if action == "foreign-narrow-mix" else None}
                run(name, dd, artifact, "native_joint_PCS_opened_row_attack", "pcs zk: Merkle path for column", detail)
        # A genuine foreign logical boundary root, not random root bytes.
        artifact = OUT / (mode + "-foreign-boundary-root")
        artifact.mkdir()
        shutil.copy2(original / "statement.txt", artifact / "statement.txt")
        os.link(original / "segment1.bin", artifact / "segment1.bin")
        first = bytearray((original / "segment0.bin").read_bytes())
        other = (foreign / "segment0.bin").read_bytes()
        assert first[120:152] != other[120:152]
        first[120:152] = other[120:152]
        (artifact / "segment0.bin").write_bytes(first)
        run(mode + "-foreign-boundary-root", dd, artifact, "native_foreign_logical_root", "sumcheck round 0",
            {"root_offset": 120, "source": original_pins["segment0.bin"], "foreign": foreign_pins["segment0.bin"],
             "changed_sha256": sha(artifact / "segment0.bin")})
        for path in [original, foreign]:
            expected = original_pins if path == original else foreign_pins
            assert {p.name: sha(p) for p in path.iterdir()} == expected
    save(OUT / "ACCEPTANCE.json", {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"],
         "binary_sha256": build["test_binary_sha256"], "cases": records, "privacy_accepted": False,
         "scope": "Final-source fresh native verifier:4 honest2stage artifacts accept; endpoint/boundary joint opened-row swaps, duplicates, zeroed narrow blocks and foreign narrow-row mixes reject at keyed Merkle verification, and2 genuine cross-run logical boundary roots reject at native sumcheck. Rows are one jointly committed ordered matrix, not independent piece roots. Foreign row mixes may use different sampled coordinates. Public synthetic fixture with explicit native test waiver; no trained/full26/privacy acceptance."})
    (OUT / "ACCEPTANCE.done").write_text("0\n")

if __name__ == "__main__":
    main()
