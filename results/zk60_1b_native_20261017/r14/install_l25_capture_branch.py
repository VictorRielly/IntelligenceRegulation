"""Add uncompiled actual-L25 tests before the first capture build is recorded."""
import hashlib,json,shutil,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'capture-working-tree';LABEL='sol-r14-capture-build-1'
assert not (HERE/(LABEL+'.command.json')).exists()
pin=json.loads((HERE/(LABEL+'.source.json')).read_text())
for name,want in pin['files'].items():assert hashlib.sha256((TREE/name).read_bytes()).hexdigest()==want,name
src=TREE/'hashline/src/private_block'
shutil.copy2(HERE/'staged/split_capture.rs',src/'split_capture.rs')
shutil.copy2(HERE/'staged/split_l25_tests.rs',src/'split_l25_tests.rs')
path=src/'argument.rs';text=path.read_text();needle='mod split_capture_tests;';assert text.count(needle)==1
path.write_text(text.replace(needle,needle+'\n#[cfg(test)]\n#[path="split_l25_tests.rs"]\nmod split_l25_tests;'))
subprocess.run(['/home/victor/.cargo/bin/rustfmt','--edition','2021',str(src/'split_l25_tests.rs')],check=True)
names=set(pin['files'])|{'hashline/src/private_block/split_l25_tests.rs'}
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest()
(HERE/(LABEL+'.source.json')).write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
state=json.loads((HERE/'CAPTURE_BRANCH_STATE.json').read_text());state.update(source=digest,files=len(files),
    status='Uncompiled native observer+3stage tests and actualL25/T128 four-group/coarse-member19site native gates; arithmetic candidate unchanged')
(HERE/'CAPTURE_BRANCH_STATE.json').write_text(json.dumps(state,indent=2)+'\n');print(json.dumps({'source':digest,'files':len(files)}))
