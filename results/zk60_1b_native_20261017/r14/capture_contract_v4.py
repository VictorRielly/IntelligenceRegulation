"""Explicit source and stage-count contract for schema6 native capture checks."""
from pathlib import Path
import hashlib
import json

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1 << 20), b""):
            h.update(data)
    return h.hexdigest()

def arguments(parser):
    parser.add_argument("--source-pin", type=Path, required=True)
    parser.add_argument("--source-tree", type=Path, required=True)
    parser.add_argument("--expected-blocks", type=int, required=True)

def load(bundle, source_pin, source_tree, expected_blocks):
    assert 1 <= expected_blocks <= 128
    pin = json.loads(source_pin.read_text())
    assert pin["count"] == len(pin["files"])
    computed = hashlib.sha256("".join(f"{name} {digest}\n" for name, digest in sorted(pin["files"].items())).encode()).hexdigest()
    assert computed == pin["tree_sha256"]
    for name, want in pin["files"].items():
        relative = Path(name)
        assert not relative.is_absolute() and ".." not in relative.parts
        assert sha(source_tree / relative) == want, name
    run = json.loads((bundle / "run.json").read_text())
    assert run["schema"] == "hashline-native-capture/6-split-run"
    assert type(run["blocks"]) is int and run["blocks"] == expected_blocks
    assert len(run["profiles"]) == len(run["block_digests"]) == expected_blocks
    assert run["fully_verified"] is True
    pins = run["source_pins"]
    assert len(pins) == len({row["file"] for row in pins})
    assert {row["file"]: row["sha256"] for row in pins} == pin["files"]
    return run, pin
