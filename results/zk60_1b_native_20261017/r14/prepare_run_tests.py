"""Checkpoint run/transport admission PASS and install guarded run fixtures."""
from datetime import datetime,timezone
import hashlib,json,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'working-tree';OLD='sol-r14-run-build-1';NEW='sol-r14-run-build-2'
assert (HERE/(OLD+'.validated.done')).read_text().strip()=='0'
pin=json.loads((HERE/(OLD+'.source.json')).read_text());checkpoint=HERE/'checkpoints/run-build-1';assert not checkpoint.exists()
for name,want in pin['files'].items():
    source=TREE/name;assert hashlib.sha256(source.read_bytes()).hexdigest()==want,name
    target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
shutil.copy2(bins[0],checkpoint/'hashline.test.bin');log=(HERE/(OLD+'.log')).read_text();assert '15 passed; 0 failed; 2 ignored' in log
report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'files':pin['count'],
    'binary_sha256':hashlib.sha256(bins[0].read_bytes()).hexdigest(),'tests':15,'failed':0,'ignored':2,
    'scope':'New R14 run/transport compiles. Native components plus exact-shape first/interior/last wire roundtrip, hostile headers/counts/noncanonical words, strict trained-model/checkpoint-context admission and adjacent layer-calibration/shared-boundary binding pass. No native multi-block run or fresh-process result yet.',
    'guard':json.loads((HERE/(OLD+'.guard.json')).read_text())}
(HERE/'RUN_WIRE_COMPONENTS.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'RUN_WIRE_COMPONENTS.done').write_text('0\n')
src=TREE/'hashline/src/private_block'
for name in ['split_run_tests.rs','split_definition_tests.rs']:shutil.copy2(HERE/'staged'/name,src/name)
path=src/'argument.rs';s=path.read_text();needle='mod split_definition_tests;';assert s.count(needle)==1
s=s.replace(needle,needle+'\n#[cfg(test)]\n#[path="split_run_tests.rs"]\nmod split_run_tests;');path.write_text(s)
names=set(pin['files']);names.add('hashline/src/private_block/split_run_tests.rs')
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
pin={'tree_sha256':hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest(),'count':len(files),'files':files}
(HERE/(NEW+'.source.json')).write_text(json.dumps(pin,indent=2)+'\n')
state=json.loads((HERE/'CURRENT_DEV_STATE.json').read_text());state.update(utc=datetime.now(timezone.utc).isoformat(),phase='Run/wire components PASS15/0; two-block native/fresh/malicious boundary fixture tests installed for compile',
    live_stage=NEW,live_tool_session=None,source_edits_held=True,source_pin=str(HERE/(NEW+'.source.json')),source_sha256=pin['tree_sha256'],
    next='Poll run-build2 before edits. Then guarded DD/nonDD two-block serialized runs, fresh-process honest/canonical scalar corruptions, emitted narrow boundary forgery. No T256 laptop proof; captures/remaining attacks/parity/compatibility/security/freeze/D24/privacy still owed.')
(HERE/'CURRENT_DEV_STATE.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps({'stage':NEW,'source':pin['tree_sha256'],'files':len(files)}))
