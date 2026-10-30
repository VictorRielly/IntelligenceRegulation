"""Checkpoint green native core2, then install the staged R14 run/transport."""
from datetime import datetime,timezone
import hashlib,json,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'working-tree';OLD='sol-r14-core-build-2';NEW='sol-r14-run-build-1'
for label in [OLD,'sol-r14-native-core-non-dd-2','sol-r14-native-core-dd-2']:
    assert (HERE/(label+'.validated.done')).read_text().strip()=='0',label
pin=json.loads((HERE/(OLD+'.source.json')).read_text());checkpoint=HERE/'checkpoints/core-build-2';assert not checkpoint.exists()
for name,want in pin['files'].items():
    source=TREE/name;assert hashlib.sha256(source.read_bytes()).hexdigest()==want,name
    target=checkpoint/'tree'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
binary_sha=hashlib.sha256(bins[0].read_bytes()).hexdigest();shutil.copy2(bins[0],checkpoint/'hashline.test.bin')
cases=[]
for mode in ['non-dd','dd']:
    label='sol-r14-native-core-'+mode+'-2';log=(HERE/(label+'.log')).read_text();marker='R14_NATIVE_CORE '
    rows=[json.loads(line.split(marker,1)[1]) for line in log.splitlines() if marker in line];assert len(rows)==1
    cases.append({'result':rows[0],'guard':json.loads((HERE/(label+'.guard.json')).read_text()),'command':str(HERE/(label+'.command.json'))})
report={'utc':datetime.now(timezone.utc).isoformat(),'source':pin['tree_sha256'],'files':pin['count'],'binary_sha256':binary_sha,
    'cases':cases,'scope':'Native T128 DD/nonDD public synthetic core: all31/32scheduled CFS slots, A/H/M,2joint endpoint commitments, honest in-process verifier and scalar tamper refusal. Not wire/CLI/fresh-process/trained/full-stack/privacy acceptance.',
    'failed_attempt':'Native nonDD attempt1 at a23c1406 emitted proof but honest verifier refused at D-wide gamma stride mismatch; checkpoint and report retained, corrected before these passes.',
    'next':'Compile bounded new R14 segment transport and trained-model-backed streaming run binding; run admission/transport checks before serialized/fresh-process and multi-block receipt tests.'}
(HERE/'NATIVE_CORE_COMPONENTS.json').write_text(json.dumps(report,indent=2)+'\n');(HERE/'NATIVE_CORE_COMPONENTS.done').write_text('0\n')
src=TREE/'hashline/src/private_block'
for name in ['split_run.rs','split_wire.rs','split_definition_tests.rs','split_endpoint.rs']:shutil.copy2(HERE/'staged'/name,src/name)
path=TREE/'hashline/src/private_block.rs';s=path.read_text();needle='mod split_protocol;';assert s.count(needle)==1;s=s.replace(needle,needle+'\nmod split_run;');path.write_text(s)
path=src/'wire.rs';s=path.read_text();s='#[path="split_wire.rs"]\npub(crate) mod split;\n'+s if not s.startswith('//!') else s
# Keep module documentation first; child has access to the canonical private readers.
if '#[path="split_wire.rs"]' not in s:
    needle='use super::argument::SlotProof;';assert s.count(needle)==1;s=s.replace(needle,'#[path="split_wire.rs"]\npub(crate) mod split;\n\n'+needle)
path.write_text(s)
names=set(pin['files']);names.update(['hashline/src/private_block/split_run.rs','hashline/src/private_block/split_wire.rs'])
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
pin={'tree_sha256':hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest(),'count':len(files),'files':files}
(HERE/(NEW+'.source.json')).write_text(json.dumps(pin,indent=2)+'\n')
state=json.loads((HERE/'CURRENT_DEV_STATE.json').read_text());state.update(utc=datetime.now(timezone.utc).isoformat(),phase='Native core2 DD/nonDD PASS; new wire and strict model-backed streaming run source installed for first compile',
    live_stage=NEW,live_tool_session=None,source_edits_held=True,source_pin=str(HERE/(NEW+'.source.json')),source_sha256=pin['tree_sha256'],
    next='Poll run-build1 before edits. Transport/model-binding checks first, then guarded native multi-block/serialized/fresh-process tests. Capture/full attacks/parity/old compatibility/security/freeze/D24/privacy still owed.')
(HERE/'CURRENT_DEV_STATE.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps({'stage':NEW,'source':pin['tree_sha256'],'files':len(files)}))
