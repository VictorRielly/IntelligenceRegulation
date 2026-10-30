from pathlib import Path
import shutil
import json
import hashlib

p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block"
assert (p.parent/"profiles.done").read_text().strip()=="101"
assert "can't compare `[&str; 27]` with `[&str; 15]`" in (p.parent/"profiles.log").read_text()
backup=p/"before-install";backup.mkdir(exist_ok=False)
names=("accuracy_public.rs","accuracy_profile_tests.rs","s24_tests.rs","s25_tests.rs","s33_tests.rs")
for name in names:
    shutil.copy2(src/name,backup/name)
    shutil.copy2(p/name.replace(".rs",".candidate.rs"),src/name)
name="trained_calib_tests.rs";shutil.copy2(src/name,backup/name)
s=(src/name).read_text();old="assert_eq!(TRAINED_CALIBRATION_PROFILES, ["
assert s.count(old)==1
s=s.replace(old,"assert_eq!(TRAINED_CALIBRATION_PROFILES[..15], [")
at=s.index(";",s.index("assert_eq!(TRAINED_CALIBRATION_PROFILES[..15]"))+1
s=s[:at]+'''\n    assert_eq!(&TRAINED_CALIBRATION_PROFILES[15..],super::shape::ACCURACY_PROFILES.iter().map(|s|s.profile).collect::<Vec<_>>().as_slice());'''+s[at:]
(src/name).write_text(s)
(p/"installed.json").write_text(json.dumps({name:hashlib.sha256((src/name).read_bytes()).hexdigest() for name in names+(name,)},indent=2)+"\n")
