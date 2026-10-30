from pathlib import Path
import shutil
import json
import hashlib

p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block"
assert (p/"check-2.done").read_text().strip()=="0"
assert "9 passed; 0 failed" in (p/"check-2.log").read_text()
assert (p.parent/"registry-integrated.done").read_text().strip()=="0"
destination=src/"accuracy_layout.rs"
assert not destination.exists()
text=(p/"accuracy_layout.rs").read_text()
text+='\n#[cfg(test)]\n#[path="accuracy_layout_tests.rs"]\nmod tests;\n'
destination.write_text(text)
text=(p/"tests.rs").read_text().replace("use super::accuracy_", "use crate::private_block::accuracy_").replace("use super::layout::", "use crate::private_block::layout::")
text=text.replace('include_str!("roles.tsv")','include_str!("r13_vectors/roles.tsv")')
(src/"accuracy_layout_tests.rs").write_text(text)
shutil.copy2(p/"roles.tsv",src/"r13_vectors/roles.tsv")
(p/"installed.json").write_text(json.dumps({"scope":"native compiled role allocator and lookup emitter; profile/host relations not activated",
    "sha256":hashlib.sha256(destination.read_bytes()).hexdigest()},indent=2)+"\n")
