"""Consolidate test-only c2 correction and generic dense gate after actual PASS6/0."""
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'actual-working-tree'
assert (HERE/'ACTUAL_S2_NATIVE_ACCEPTANCE.done').read_text().strip()=='0'
old=json.loads((HERE/'sol-r14-actual-build-1.source.json').read_text())
for name,want in old['files'].items():
    assert hashlib.sha256((TREE/name).read_bytes()).hexdigest()==want,name
    assert hashlib.sha256((HERE/'checkpoints/actual-build-1/tree'/name).read_bytes()).hexdigest()==want,name
src=TREE/'hashline/src/private_block'
main=json.loads((HERE/'sol-r14-run-build-6.source.json').read_text())
name='hashline/src/private_block/split_attack_tests.rs'
assert hashlib.sha256((HERE/'working-tree'/name).read_bytes()).hexdigest()==main['files'][name]
shutil.copy2(HERE/'working-tree'/name,src/'split_attack_tests.rs')
path=src/'split_attack_tests.rs';text=path.read_text();needle='fn emit(';assert text.count(needle)==1;path.write_text(text.replace(needle,'pub(super) '+needle))
path=src/'split_actual_tests.rs';text=path.read_text()
for name in ['native_dense','piece_dense']:
    needle='fn '+name+'(';assert text.count(needle)==1;text=text.replace(needle,'pub(super) '+needle)
path.write_text(text)
shutil.copy2(HERE/'staged/split_dense_tests.rs',src/'split_dense_tests.rs')
path=src/'argument.rs';text=path.read_text();needle='mod split_actual_tests;';assert text.count(needle)==1
path.write_text(text.replace(needle,needle+'\n#[cfg(test)]\n#[path="split_dense_tests.rs"]\nmod split_dense_tests;'))
subprocess.run(['/home/victor/.cargo/bin/rustfmt','--edition','2021',str(src/'split_dense_tests.rs'),str(src/'split_actual_tests.rs'),str(src/'split_attack_tests.rs')],check=True)
names=set(old['files'])|{'hashline/src/private_block/split_dense_tests.rs'}
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest()
path=HERE/'sol-r14-actual-build-2.source.json';assert not path.exists();path.write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
state={'utc':datetime.now(timezone.utc).isoformat(),'source':digest,'files':len(files),
    'actual_native_gate':'ActualS2 layer0 DD/nonDD19sites+proof+fresh+canonical corruption PASS6/0 source087016a3.',
    'test_only_changes':'Stronger global-AO-c2 fixture;19-site generic dense/full-support matrices/varying inputs, both score signs, native proof and public trace dumps for independent reference.',
    'main_build6_withdrawn':{'tool_session':44299,'exit':130,'heavy_leaf_started':False,
        'reason':'Consolidate correction into superset actual branch2; original handle Ctrl-C while queued behind gate20 CPU8.8GiB, no guard/foreign process signal.'},
    'source_edits_held':True,'pending':'Compile and complete emitted DD/nonDD malicious receipts plus generic dense native/reference gates; actual6gates unchanged native code. Captures/compatibility/trained CLI/independent bound/privacy review still owed.'}
(HERE/'ACTUAL_BRANCH_STATE.json').write_text(json.dumps(state,indent=2)+'\n');print(json.dumps({'source':digest,'files':len(files)}))
