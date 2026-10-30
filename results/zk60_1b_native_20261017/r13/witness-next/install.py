from pathlib import Path
import shutil
import hashlib
import json

p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block"
assert (p.parent/"layout-integrated.done").read_text().strip()=="0"
assert all((p.parent/f"layout-gate-{i}.done").read_text().strip()=="0" for i in range(4))
backup=p/"before-install";backup.mkdir(exist_ok=False)
for name in ("witness.rs","witness_accuracy.rs","tamper.rs","review_tests.rs"):
    shutil.copy2(src/name,backup/name)
s=(src/"witness.rs").read_text()
s=s.replace("pub(crate) struct Witness {", "#[derive(Clone)]\npub(crate) struct Witness {")
s=s.replace("    pub planes: Vec<Vec<i64>>,", "    pub planes: Vec<Vec<i64>>,\n    pub(crate) output_plane: usize,")
start=s.index("    /// `A_X2` is the ONE plane")
end=s.index("    pub(crate) fn output",start)
s=s[:start]+"    /// The builder records the profile-derived output plane; norm limb\n    /// changes must never silently move the endpoint onto another role.\n"+s[end:]
s=s.replace("self.planes[A_X2].iter()", "self.planes.get(self.output_plane).ok_or(\"private block: output plane is absent\")?.iter()")
s=s.replace("Ok(Witness { planes: pl })", "Ok(Witness { planes: pl, output_plane: ids.at(A_X2) })")
assert "self.planes[A_X2]" not in s
(src/"witness.rs").write_text(s)
for name in ("tamper.rs","review_tests.rs"):
    s=(src/name).read_text()
    assert "Witness { planes: w.planes.clone() }" in s
    s=s.replace("Witness { planes: w.planes.clone() }", "w.clone()")
    (src/name).write_text(s)
s=(src/"witness_accuracy.rs").read_text()
marker="#[cfg(test)]\nmod tests {"
assert s.count(marker)==1
s=s.replace(marker,(p/"assign.rs").read_text()+"\n"+marker)
at=s.rfind("\n}")
s=s[:at]+"\n"+(p/"tests.rs").read_text()+s[at:]
(src/"witness_accuracy.rs").write_text(s)
(p/"installed.json").write_text(json.dumps({name:hashlib.sha256((src/name).read_bytes()).hexdigest()
    for name in ("witness.rs","witness_accuracy.rs","tamper.rs","review_tests.rs")},indent=2)+"\n")
