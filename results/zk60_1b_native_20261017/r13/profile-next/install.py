from pathlib import Path
import shutil
import json
import hashlib
import sys

p=Path(__file__).resolve().parent
root=p.parent/"working-tree/hashline/src"
src=root/"private_block"
assert (p.parent/"public-helpers.done").read_text().strip()=="0"
assert all((p.parent/f"public-helpers-gate-{i}.done").read_text().strip()=="0" for i in range(5))
backup=p/"before-install"
if "--resume" in sys.argv:
    assert (root/"private_block.rs").read_bytes()==(backup/"private_block.rs").read_bytes()
    assert (src/"witness_accuracy.rs").read_bytes()==(backup/"witness_accuracy.rs").read_bytes()
    for name in ("shape","layout"):assert (src/(name+".rs")).read_bytes()==(p/(name+".candidate.rs")).read_bytes()
else:
    backup.mkdir(exist_ok=False)
    for name in ("shape.rs","layout.rs","witness_accuracy.rs"):
        shutil.copy2(src/name,backup/name)
    shutil.copy2(root/"private_block.rs",backup/"private_block.rs")
    for name in ("shape","layout"):shutil.copy2(p/(name+".candidate.rs"),src/(name+".rs"))
    shutil.copy2(p/"tests.rs",src/"accuracy_profile_tests.rs")
s=(root/"private_block.rs").read_text()
marker="#[cfg(test)]\nmod accuracy_binding_tests;"
assert s.count(marker)==1
s=s.replace(marker,marker+"\n#[cfg(test)]\nmod accuracy_profile_tests;")
marker="    pub(crate) fn check_for_shape(&self, sh: &shape::Shape) -> Result<(), String> {"
at=s.index(marker,s.index("impl BlockPublic"))+len(marker)
s=s[:at]+'''
        if sh.accuracy_stack()!=accuracy_precision::Stack::Legacy {
            return Err("R13 proof profiles remain disabled until all host and lookup relations are integrated".into());
        }
'''+s[at:]
(root/"private_block.rs").write_text(s)
s=(src/"witness_accuracy.rs").read_text()
first=s.index("    let registry=if crate::private_block::shape::SHIELDSTRAL_PROFILES.contains(&sh.profile)")
last=s.index("    accuracy.check_for_registry",first)
s=s[:first]+"    let registry=sh.accuracy_registry();\n"+s[last:]
(src/"witness_accuracy.rs").write_text(s)
(p/"installed.json").write_text(json.dumps({"scope":"native profile/Shape/Ids construction and counts; explicit shared proof refusal remains",
    "files":{name:hashlib.sha256((src/name).read_bytes()).hexdigest() for name in ("shape.rs","layout.rs","witness_accuracy.rs","accuracy_profile_tests.rs")}},indent=2)+"\n")
