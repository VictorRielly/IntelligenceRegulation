"""Prepare only the retained public review fixture for experimental CLI checks."""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "cli-l25-sequence"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1 << 20), b""):
            h.update(data)
    return h.hexdigest()

def main():
    oracle_path = HERE / "l25-causal-prefix/ORACLE.json"
    oracle = json.loads(oracle_path.read_text())
    ref = ROOT / "results/zk60_d24_review_20261017/r13/ref_shield_L25.json.npz"
    inp = oracle_path.parent / "input.i16"
    assert sha(ref) == oracle["source_sha256"][str(ref.relative_to(ROOT))]
    assert sha(inp) == oracle["input_sha256"]
    assert not OUT.exists()
    traces = {row["site"]: row for row in oracle["trace_sites"]}
    with np.load(ref, allow_pickle=False) as data:
        output = np.asarray(data["x2"][:128], dtype="<i8")
    assert output.shape == (128, 3072)
    assert hashlib.sha256(output.tobytes()).hexdigest() == traces["x2"]["sha256"]
    assert np.all((-32768 <= output) & (output <= 32767))
    OUT.mkdir()
    (OUT / "x_in_L25.bin").write_bytes(inp.read_bytes())
    output.astype("<i2").tofile(OUT / "x_out_L25.bin")
    arrays = {}
    for name in ["x_in_L25", "x_out_L25"]:
        path = OUT / (name + ".bin")
        arrays[name] = {"file": path.name, "dtype": "int16", "shape": [128, 3072], "sha256": sha(path)}
    (OUT / "manifest.json").write_text(json.dumps({"arrays": arrays}, indent=2) + "\n")
    (OUT / "PROVENANCE.json").write_text(json.dumps({
        "scope": "Public retained numerical review fixture, causal T128 prefix of the independently checked actual L25 oracle. No private app item, no T256 proof, no full-stack result.",
        "oracle_sha256": sha(oracle_path), "reference_sha256": sha(ref),
        "script_sha256": sha(Path(__file__)), "output_i64_trace_sha256": traces["x2"]["sha256"],
        "arrays": arrays,
    }, indent=2) + "\n")
    print("Prepared independent actual-L25 CLI sequence, T128 x3072, input/output oracle pins matched")

if __name__ == "__main__":
    main()
