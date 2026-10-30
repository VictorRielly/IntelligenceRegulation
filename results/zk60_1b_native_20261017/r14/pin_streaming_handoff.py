"""Pin the completed native streaming/C3 checkpoint, without release claims."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

HERE = Path(__file__).resolve().parent

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()

def main():
    assert (HERE / "streaming-native-1/done").read_text().strip() == "0"
    name = "sol-r14-streaming-build-1"
    pin = json.loads((HERE / (name + ".source.json")).read_text())
    original = json.loads((HERE / "sol-r14-capture-build-1.source.json").read_text())
    for file, want in pin["files"].items():
        assert sha(HERE / "streaming-working-tree" / file) == want
        assert sha(HERE / "checkpoints/streaming-build-1/tree" / file) == want
    unchanged = []
    for part in ["argument_split", "split_protocol", "split_geometry", "split_endpoint", "split_profile", "split_wire"]:
        file = f"hashline/src/private_block/{part}.rs"
        assert pin["files"][file] == original["files"][file]
        unchanged.append(file)
    evidence = [HERE / (name + suffix) for suffix in [".source.json", ".log", ".guard.json", ".validated.done"]]
    evidence += [HERE / "checkpoints/streaming-build-1/hashline.test.bin"]
    evidence += sorted(p for p in (HERE / "streaming-native-1").rglob("*") if p.is_file())
    acceptance = json.loads((HERE / "streaming-native-1/ACCEPTANCE.json").read_text())
    assert len(acceptance["cases"]) == 6
    changed = [file for file in pin["files"] if pin["files"][file] != original["files"].get(file)]
    result = {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"],
              "source_files": pin["count"], "changed_from_capture": changed,
              "unchanged_native_math_and_codec": unchanged, "native_cases": acceptance["cases"],
              "scope": "Completed author checkpoint: 20 component tests; four C3 canonical malformed receipts reject at native slot20 sumcheck round0; two DD/nonDD two-stage source proofs and resident/cache verifiers pass, both post-preflight block replacements refuse. Cache peak one owned block; original synthetic fixture remains resident, so no full-model RSS result.",
              "release_accepted": False, "privacy_accepted": False,
              "remaining": ["50 relation regressions", "legacy compatibility/goldens", "experimental trained CLI/publication checks", "full26 native chain", "final capture/rank/lemma/whole-run soundness", "freeze and independent reviews"],
              "evidence_sha256": {str(p.relative_to(HERE)): sha(p) for p in evidence}}
    path = HERE / "STREAMING_SOURCE_HANDOFF.json"
    assert not path.exists()
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"source": pin["tree_sha256"], "native_cases": 6, "evidence_files": len(evidence), "privacy_accepted": False}))

if __name__ == "__main__":
    main()
