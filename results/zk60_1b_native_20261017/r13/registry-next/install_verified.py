"""Install the tested registry math into the isolated R13 tree only."""
from pathlib import Path
import hashlib
import json
import shutil
from datetime import datetime, timezone

p = Path(__file__).resolve().parent
src = p.parent / "working-tree/hashline/src/private_block"
assert (p / "red.done").read_text().strip() == "101"
assert (p / "green.done").read_text().strip() == "0"
assert "27 passed; 0 failed" in (p / "green.log").read_text()
assert (p.parent / "components-rebased-4.done").read_text().strip() == "0"
backup = p / "before-install"
backup.mkdir(exist_ok=False)
manifest = {"utc": datetime.now(timezone.utc).isoformat(), "files": {}}
for name in ("accuracy_tables", "accuracy_groups", "accuracy_aligned"):
    destination = src / (name + ".rs")
    shutil.copy2(destination, backup / destination.name)
    text = (p / (name + ".green.rs")).read_text()
    text = text.replace("../working-tree/hashline/src/private_block/r13_vectors/", "r13_vectors/")
    text = text.replace('include_bytes!("silu_0_-8.bin")', 'include_bytes!("r13_vectors/silu_0_-8.bin")')
    destination.write_text(text)
    manifest["files"][str(destination.relative_to(p.parent))] = hashlib.sha256(destination.read_bytes()).hexdigest()
shutil.copy2(p / "silu_0_-8.bin", src / "r13_vectors/silu_0_-8.bin")
shutil.copy2(p.parent / "shieldstral_product_vectors.tsv", src / "r13_vectors/shieldstral_product_vectors.tsv")
tests = (p / "green_harness.rs").read_text().split("#[test]", 1)[1]
tests = "#[test]" + tests
tests = tests.replace('include_str!("../shieldstral_product_vectors.tsv")', 'include_str!("r13_vectors/shieldstral_product_vectors.tsv")')
tests = "\n#[cfg(test)]\nmod shieldstral_tests {\nuse super::super::{accuracy,accuracy_precision,accuracy_tables,accuracy_groups,accuracy_aligned};\n" + tests + "\n}\n"
with (src / "accuracy_aligned.rs").open("a") as f:
    f.write(tests)
manifest["files"][str((src / "accuracy_aligned.rs").relative_to(p.parent))] = hashlib.sha256((src / "accuracy_aligned.rs").read_bytes()).hexdigest()
(p / "installed.json").write_text(json.dumps(manifest, indent=2) + "\n")
