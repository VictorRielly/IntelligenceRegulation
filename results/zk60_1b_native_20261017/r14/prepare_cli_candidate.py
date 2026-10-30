"""Prepare a new immutable CLI candidate only after the original typecheck ends.

No build is launched here. Previously queued native branches remain unchanged.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

HERE = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assert (HERE / "sol-r14-cli-check-2.done").read_text().strip() == "0"
    base = json.loads((HERE / "sol-r14-cli-check-2.source.json").read_text())
    audit = json.loads((HERE / "sol-r14-legacy-full-suite-3.source.json").read_text())
    original = HERE / "cli-working-tree"
    candidate = HERE / "cli-candidate-working-tree"
    assert not candidate.exists()
    for name, digest in base["files"].items():
        assert sha(original / name) == digest
        out = candidate / name
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original / name, out)
    # Keep the exact source underlying the completed first CLI typecheck.
    checkpoint = HERE / "checkpoints/cli-check-2/tree"
    assert not checkpoint.exists()
    shutil.copytree(candidate, checkpoint)
    private = candidate / "hashline/src/private_block"
    for name in ["source_audit.rs", "s24_tests.rs", "s25_tests.rs", "run_capture.rs"]:
        relative = "hashline/src/private_block/" + name
        source = HERE / "compatibility-audit-v3" / relative
        assert sha(source) == audit["files"][relative]
        shutil.copy2(source, private / name)
    parent = candidate / "hashline/src/private_block.rs"
    text = parent.read_text()
    assert text.count("mod split_run;") == 1
    parent.write_text(text.replace("mod split_run;", "mod split_run;\n#[cfg(test)]\nmod source_audit;"))
    capture = private / "run_capture.rs"
    text = capture.read_text().replace("const OWN_SOURCE_FILES: [&str; 42]", "const OWN_SOURCE_FILES: [&str; 43]")
    needle = '    "src/private_block/split_capture.rs",\n'
    assert text.count(needle) == 1
    capture.write_text(text.replace(needle, needle + '    "src/private_block/trained_split.rs",\n'))
    classifier = private / "s25_tests.rs"
    text = classifier.read_text().replace("const CALL_SITES: [(&str, &str, usize, &str); 20]", "const CALL_SITES: [(&str, &str, usize, &str); 21]")
    needle = "const CALL_SITES: [(&str, &str, usize, &str); 21] = [\n"
    assert text.count(needle) == 1
    classifier.write_text(text.replace(needle, needle + '    ("src/private_block/trained_split.rs", "sha256_hex(", 0, "C1 — the experimental CLI uses the authenticated loader and parent SHA-256 helpers for consumed segment bytes; no new direct hash or RNG entry point"),\n'))
    cli = private / "trained_split.rs"
    text = cli.read_text()
    assert text.rstrip().endswith("}")
    at = text.rfind("}")
    cli.write_text(text[:at] + (HERE / "staged/split_cli_m9_test.rs").read_text() + "\n" + text[at:])
    subprocess.run(["/home/victor/.cargo/bin/rustfmt", "--edition", "2021", str(cli)], check=True)
    names = sorted(set(base["files"]) | {"hashline/src/private_block/source_audit.rs"})
    files = {name: sha(candidate / name) for name in names}
    tree_sha = hashlib.sha256("".join(f"{name} {digest}\n" for name, digest in files.items()).encode()).hexdigest()
    pin = HERE / "sol-r14-cli-build-1.source.json"
    assert not pin.exists()
    pin.write_text(json.dumps({"tree_sha256": tree_sha, "count": len(files), "files": files}, indent=2) + "\n")
    print(json.dumps({"source": tree_sha, "files": len(files), "tree": str(candidate), "build_launched": False}))

if __name__ == "__main__":
    main()
