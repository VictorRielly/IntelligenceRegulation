"""Stage separate R13 run identities and their exact block-shape registry."""
from pathlib import Path
import json
import re

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'
specs=re.findall(r'pub\(crate\) const (R13_\w+): &str = "([^"]+)";', (src/'shape.rs').read_text())
assert len(specs)==12
names=[];declarations=[];mapping=[]
for name,block in specs:
    run=block.replace('private-block','private-run')
    if 'RUNG' not in name:run=run.removesuffix('/1')+('-statement' if '_8B_' in name else '-run')+'/1'
    assert len(run)==(45 if 'RUNG' in name else 63 if '_8B_' in name else 67),(name,run)
    symbol='RUN_PROFILE_'+name
    declarations.append(f'pub(crate) const {symbol}: &str = "{run}";')
    mapping.append(f'    ({symbol},super::shape::{name}),')
    names.append({'symbol':symbol,'block_symbol':name,'block':block,'run':run,'length':len(run)})
s=(out/'run.candidate.rs').read_text()
needle='/// One run\'s geometry: the per-block shape'
assert s.count(needle)==1
registry='\n// R13: one new run identity for each new arithmetic/geometry profile.\n'+'\n'.join(declarations)+'''
pub(crate) const ACCURACY_RUN_PROFILES:[(&str,&str);12]=[
'''+ '\n'.join(mapping)+'''
];
pub(crate) fn accuracy_run_profile(block:&str)->Option<&'static str> {
    ACCURACY_RUN_PROFILES.iter().find(|(_,b)|*b==block).map(|(r,_)|*r)
}

'''
s=s.replace(needle,registry+needle)
needle='''    let cal = sh.norm_calibration();
    Some(match profile {'''
assert s.count(needle)==1
s=s.replace(needle,'''    let cal = sh.norm_calibration();
    if let Some((_,block))=ACCURACY_RUN_PROFILES.iter().find(|(run,_)|*run==profile) {
        return Some(Shape::accuracy_trained(block,&cal,sh.f_e,sh.accuracy_gate_shift));
    }
    Some(match profile {''')
needle='impl RunShape {'
assert s.count(needle)==1
s=s.replace(needle,needle+'''
    pub(crate) fn accuracy(sh:Shape,l:usize)->Result<RunShape,String> {
        let profile=accuracy_run_profile(sh.profile).ok_or("private run: no R13 run profile for this block")?;
        Self::new(sh,l,profile)
    }
''')
(out/'run.candidate.rs').write_text(s)
(out/'RUN_PROFILES.json').write_text(json.dumps(names,indent=2)+'\n')
s=(src/'accuracy_profile_tests.rs').read_text()+'''

pub(super) fn registered_runs()->Vec<(&'static str,Shape)> {
    registered_shapes().into_iter().map(|s|(super::run::accuracy_run_profile(s.profile).unwrap(),s)).collect()
}
'''
(out/'accuracy_profile_tests.candidate.rs').write_text(s)
print('Staged12 run profiles and their registry; lengths45/63/67 retained for hash-input audit.')
