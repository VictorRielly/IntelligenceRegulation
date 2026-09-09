"""Synthetic manifests + a real temporary checkout; no proof or GPU run.
Usage: python3 reproduce_cl21.py REPO OUTPUT_DIR
"""
from contextlib import redirect_stdout, redirect_stderr
import importlib.util, io, json, sys, tempfile, subprocess
from pathlib import Path
root, out = map(lambda p: Path(p).resolve(), sys.argv[1:3])
out.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(root / "tests"))
from test_hashline_cl_gpu_gates import make_checkout
original = out / "cl21_original.py"
original.write_bytes(subprocess.check_output(["git", "show", "98e5785:scripts/hashline_cl_gpu_gates.py"], cwd=root))
def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m
before = module("before", original)
after = module("after", root / "scripts/hashline_cl_gpu_gates.py")
results = []
with tempfile.TemporaryDirectory() as temp:
    repo = Path(make_checkout(str(Path(temp) / "repo")))
    identity = before.probe_source_identity(str(repo))
    manifest = before.synthetic_manifest(suite_version=4, head=identity["head"], source_identity=identity)
    (repo / "zkp-core/src/lib.rs").write_text("pub fn changed() {}\n")
    for name, m in [("original_cl21", before), ("round15_fix", after)]:
        for command in ["validate", "finalize"]:
            path = Path(temp) / "manifest.json"
            before.save_manifest(manifest, str(path))
            argv = [command] + (["--manifest"] if command == "finalize" else []) + [str(path), "--repo", str(repo)]
            log = io.StringIO()
            with redirect_stdout(log), redirect_stderr(log):
                rc = m.main(argv)
            (out / f"cl21_{name}_{command}.log").write_text(log.getvalue())
            results.append(dict(implementation=name, command=command, exit_code=rc, accepted=rc == 0, synthetic=True))
assert [r["accepted"] for r in results] == [True, True, False, False], results
(out / "result.json").write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps(results, indent=2))
