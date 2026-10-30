"""Install the staged R13 relations; leave shared proof activation refused."""
from pathlib import Path
import datetime
import hashlib
import json
import shutil

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'
root=out.parents[3]
coord=(root/'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md').read_text()
assert '2026-10-29T00:34:16Z — **S8 WINDOW CLOSED.' in coord
assert 'R13 proof profiles remain disabled until all host and lookup relations are integrated' in src.with_suffix('.rs').read_text()
backup=out/'pre-install'
backup.mkdir(exist_ok=False)
names={
    'argument_accuracy.rs':'argument_accuracy.ready.candidate.rs',
    'argument.rs':'argument.parent.candidate.rs',
    'protocol.rs':'protocol.act3.candidate.rs',
    'run_capture.rs':'run_capture.candidate.rs',
    'hash_domain_tests.rs':'hash_domain_tests.candidate.rs',
    's25_tests.rs':'s25_tests.candidate.rs',
}
for name in ['tests','s20_review_tests','trained_calib_tests','s35_tests','p2_tests','grow_tests','slot_ir_tests','s24_tests']:
    names[name+'.rs']=name+'.ctx.candidate.rs'
manifest={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'proof_active':False,'files':{}}
for name,candidate in names.items():
    target=src/name
    if target.exists():shutil.copy2(target,backup/name)
    elif name!='argument_accuracy.rs':raise AssertionError(name)
    manifest['files'][name]={'before':hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None,
        'after':hashlib.sha256((out/candidate).read_bytes()).hexdigest()}
(backup/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for name,candidate in names.items():shutil.copy2(out/candidate,src/name)
(out/'INSTALLED.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Installed',len(names),'R13 source/test files; shared proof activation remains refused.')
