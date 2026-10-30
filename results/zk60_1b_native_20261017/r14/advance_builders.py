"""Checkpoint terminal attempt1 and install reviewed staged corrections."""
from datetime import datetime,timezone
import hashlib,json,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent
OLD='sol-r14-builders-1';NEW='sol-r14-builders-2';TREE=HERE/'working-tree'
assert (HERE/(OLD+'.done')).read_text().strip()=='101'
log=(HERE/(OLD+'.log')).read_text()
assert '12 passed; 1 failed' in log and 'assertion failed: digests.iter().all' in log
pin=json.loads((HERE/(OLD+'.source.json')).read_text())
checkpoint=HERE/'checkpoints/builders-1';assert not checkpoint.exists()
for name,want in pin['files'].items():
    source=TREE/name;assert hashlib.sha256(source.read_bytes()).hexdigest()==want,name
    target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111]
assert len(bins)==1,[str(p) for p in bins]
shutil.copy2(bins[0],checkpoint/'hashline.test.bin')
record={'source':pin['tree_sha256'],'binary_sha256':hashlib.sha256(bins[0].read_bytes()).hexdigest(),
    'scope':'attempt1 terminal101,12pass/1fail; all126 SlotDef census entries, joint endpoints and witness histogram passed; descriptor f_e12/16 alias found',
    'fix':'New R14 descriptor explicitly binds every arithmetic calibration/window including f_e,f_p,d_max. Stable joint geometry digest permits adjacent layer calibrations; added regression. OldR13 frozen bytes unchanged.',
    'pending':'full protocol,codec,captures,receipt attacks,old compatibility,whole-run security,freeze/D24/privacy'}
(HERE/'BUILDERS_ATTEMPT1.json').write_text(json.dumps(record,indent=2)+'\n')
for name in ['split_profile.rs','split_endpoint.rs','split_definition_tests.rs','argument_split.rs']:
    shutil.copy2(HERE/'staged'/name,TREE/'hashline/src/private_block'/name)
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in pin['files']}
pin={'tree_sha256':hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest(),'count':len(files),'files':files}
(HERE/(NEW+'.source.json')).write_text(json.dumps(pin,indent=2)+'\n')
state=json.loads((HERE/'CURRENT_DEV_STATE.json').read_text());state.update(utc=datetime.now(timezone.utc).isoformat(),
    phase='Builder attempt1 terminal101,12pass/1fail (new descriptor calibration alias); corrected descriptor and stable boundary geometry installed, group census added',
    live_stage=NEW,live_tool_session=None,source_edits_held=True,source_pin=str(HERE/(NEW+'.source.json')),source_sha256=pin['tree_sha256'],
    next='Poll builders2 before edits; actual protocol/codec/capture and review gates still owed.')
(HERE/'CURRENT_DEV_STATE.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps({'stage':NEW,'source':pin['tree_sha256'],'files':len(files)}))
