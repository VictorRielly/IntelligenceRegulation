"""Install staged builders only after the pinned CFS component gate passes."""
import hashlib,json,shutil,subprocess,sys
from pathlib import Path
from datetime import datetime,timezone
HERE=Path(__file__).resolve().parent
TREE=HERE/'working-tree'
SRC=TREE/'hashline/src/private_block'
STAGED=HERE/'staged'
OLD='sol-r14-scheduled-cfs-1'
NEW='sol-r14-builders-1'
assert (HERE/(OLD+'.validated.done')).read_text().strip()=='0'
pin=json.loads((HERE/(OLD+'.source.json')).read_text())
checkpoint=HERE/'checkpoints/scheduled-cfs-1/tree'
assert not checkpoint.exists()
for name,want in pin['files'].items():
    source=TREE/name
    assert hashlib.sha256(source.read_bytes()).hexdigest()==want,name
    target=checkpoint/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
log=(HERE/(OLD+'.log')).read_text()
assert '8 passed; 0 failed' in log
report={'utc':datetime.now(timezone.utc).isoformat(),'source_sha256':pin['tree_sha256'],
    'tests':8,'failed':0,'scope':'Native explicit CFS schedule at slot30, PCS/M honest and emitted wrong-gate/degree rejection; corrected geometry and inventory; not complete R14 protocol or privacy acceptance',
    'guard':json.loads((HERE/(OLD+'.guard.json')).read_text())}
(HERE/'SCHEDULED_CFS_COMPONENTS.json').write_text(json.dumps(report,indent=2)+'\n')
(HERE/'SCHEDULED_CFS_COMPONENTS.done').write_text('0\n')
subprocess.run([sys.executable,str(STAGED/'prepare_piece_view.py')],check=True)
for staged,name in [('argument-with-piece-view.rs','argument.rs'),('argument-accuracy-with-piece-view.rs','argument_accuracy.rs')]:
    shutil.copy2(STAGED/staged,SRC/name)
added=['argument_split.rs','split_profile.rs','split_endpoint.rs','split_definition_tests.rs','split_witness.rs']
for name in added:shutil.copy2(STAGED/name,SRC/name)
path=SRC/'argument.rs';s=path.read_text()
needle='mod split_cfs_tests;';assert s.count(needle)==1
s=s.replace(needle,needle+'\n#[cfg(test)]\n#[path="split_definition_tests.rs"]\nmod split_definition_tests;')
path.write_text(s)
path=TREE/'hashline/src/private_block.rs';s=path.read_text()
needle='mod split_geometry;';assert s.count(needle)==1
s=s.replace(needle,needle+'\nmod split_profile;\nmod split_endpoint;\nmod split_witness;');path.write_text(s)
names=set(pin['files']);names.update('hashline/src/private_block/'+name for name in added)
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
pin={'tree_sha256':hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest(),'count':len(files),'files':files}
(HERE/(NEW+'.source.json')).write_text(json.dumps(pin,indent=2)+'\n')
state=json.loads((HERE/'CURRENT_DEV_STATE.json').read_text())
state.update(utc=datetime.now(timezone.utc).isoformat(),phase='Scheduled CFS components PASS8/0; staged native builders installed and pinned, compiling next',
    source_edits_held=True,live_stage=NEW,live_tool_session=None,source_pin=str(HERE/(NEW+'.source.json')),source_sha256=pin['tree_sha256'],
    next='Poll builders1 before edits. Native SlotDef/degree/source census, joint owner components and witness histogram adapter; full protocol/codec/capture and all review gates still owed.')
(HERE/'CURRENT_DEV_STATE.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps({'stage':NEW,'source':pin['tree_sha256'],'files':len(files)}))
