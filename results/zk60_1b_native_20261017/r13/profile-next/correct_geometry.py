from pathlib import Path
import shutil
import json

p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block"
assert (p.parent/"profiles-2.done").read_text().strip()=="0"
assert (p.parent/"hash-kinds-2.done").read_text().strip()=="0"
backup=p/"before-geometry-correction";backup.mkdir(exist_ok=False)
for name in ("shape.rs","accuracy_profile_tests.rs","accuracy_act.rs"):
    shutil.copy2(src/name,backup/name)
s=(src/"shape.rs").read_text()
lines=s.splitlines(keepends=True);count=0
for i,line in enumerate(lines):
    if line.startswith("AccuracyProfile{profile:R13_RUNG_"):
        assert "width:192,hidden:384" in line
        lines[i]=line.replace("width:192,hidden:384","width:384,hidden:768");count+=1
assert count==4
s="".join(lines)
needle="        for dom in [Dom::Q, Dom::Kv, Dom::S] {"
assert s.count(needle)==1
s=s.replace(needle,'''        if accuracy_spec(profile).is_some() {
            for dom in [Dom::D,Dom::F] {
                if sh.log(dom)!=sh.natural_log(dom) {
                    return Err(format!("R13 shape: the {dom:?} matmul domain cannot be lifted by the row width"));
                }
            }
        }
'''+needle)
(src/"shape.rs").write_text(s)
s=(src/"accuracy_profile_tests.rs").read_text().replace("if spec.width<256 {12} else {9}","if spec.tokens==32 {12} else {9}")
s=s.replace("if s.width<256 {12} else {9}","if s.tokens==32 {12} else {9}")
needle="        let lay=Layout::for_shape(&sh).unwrap();"
assert s.count(needle)==1
s=s.replace(needle,"        for dom in [Dom::D,Dom::F,Dom::Q,Dom::Kv,Dom::S] {assert_eq!(sh.log(dom),sh.natural_log(dom));}\n"+needle)
(src/"accuracy_profile_tests.rs").write_text(s)
shutil.copy2(p.parent/"act-next/accuracy_act.query.candidate.rs",src/"accuracy_act.rs")
plan=json.loads((p/"PLAN.json").read_text());plan["scope"]="installed corrected profile registry; proof remains explicitly disabled"
(p/"PLAN.json").write_text(json.dumps(plan,indent=2)+"\n")
