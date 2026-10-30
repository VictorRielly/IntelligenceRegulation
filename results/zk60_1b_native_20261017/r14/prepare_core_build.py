"""Package the accepted component checkpoint and stage the R14 core build."""
from datetime import datetime,timezone
import hashlib,json,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'working-tree';OLD='sol-r14-builders-2';NEW='sol-r14-core-build-1'
assert (HERE/(OLD+'.validated.done')).read_text().strip()=='0'
pin=json.loads((HERE/(OLD+'.source.json')).read_text());checkpoint=HERE/'checkpoints/builders-2';assert not checkpoint.exists()
for name,want in pin['files'].items():
    source=TREE/name;assert hashlib.sha256(source.read_bytes()).hexdigest()==want,name
    target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
shutil.copy2(bins[0],checkpoint/'hashline.test.bin')
log=(HERE/(OLD+'.log')).read_text();assert '13 passed; 0 failed' in log
def records(marker):return [json.loads(line.split(marker+' ',1)[1]) for line in log.splitlines() if marker+' ' in line]
report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'files':pin['count'],
    'binary_sha256':hashlib.sha256(bins[0].read_bytes()).hexdigest(),'tests':13,'failed':0,
    'slot_definitions':records('R14_ACTUAL_SLOT'),'groups':records('R14_NATIVE_GROUPS'),'inventory':records('R14_SPLIT_CENSUS'),
    'guard':json.loads((HERE/(OLD+'.guard.json')).read_text()),
    'scope':'Native SlotDef/coordinate/role/site/host/degree census, H sum-claim schedule audit, joint endpoint one-opening components, global histogram repacking; not complete R14 proof/codec/profile acceptance or privacy',
    'prior_failure':'Attempt1 found new descriptor alias f_e12/16; explicitly corrected arithmetic/window binding. Stable joint-geometry binding supports adjacent calibrations. Original attempt1 retained.',
    'next':'Compile staged A/M/H core, then separately guarded native T128 DD/nonDD proof components; wire/CLI/trained-context/captures/attacks/parity/old compatibility/security/freeze/D24/privacy still owed'}
assert len(report['slot_definitions'])==126 and len(report['groups'])==4
(HERE/'NATIVE_BUILDERS_CENSUS.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'NATIVE_BUILDERS_CENSUS.done').write_text('0\n')
src=TREE/'hashline/src/private_block'
for name in ['split_protocol.rs','split_definition_tests.rs']:shutil.copy2(HERE/'staged'/name,src/name)
path=TREE/'hashline/src/private_block.rs';s=path.read_text();needle='mod split_witness;';assert s.count(needle)==1;s=s.replace(needle,needle+'\nmod split_protocol;');path.write_text(s)
names=set(pin['files']);names.add('hashline/src/private_block/split_protocol.rs')
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
pin={'tree_sha256':hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest(),'count':len(files),'files':files}
(HERE/(NEW+'.source.json')).write_text(json.dumps(pin,indent=2)+'\n')
state=json.loads((HERE/'CURRENT_DEV_STATE.json').read_text());state.update(utc=datetime.now(timezone.utc).isoformat(),
    phase='Native builders PASS13/0,126actual SlotDefs; A/M/H core installed for build only, T128 proof tests ignored pending separate9.5GiB guard',
    live_stage=NEW,live_tool_session=None,source_edits_held=True,source_pin=str(HERE/(NEW+'.source.json')),source_sha256=pin['tree_sha256'],
    next='Poll core build before edits. If green, run each ignored native T128 core component under9.5GiB declaration; no T256 laptop proof. Full wire/CLI/capture and review gates still owed.')
(HERE/'CURRENT_DEV_STATE.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps({'stage':NEW,'source':pin['tree_sha256'],'files':len(files)}))
