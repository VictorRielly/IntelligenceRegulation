"""Prepare an isolated actual-weight gate without changing queued attack source."""
from datetime import datetime, timezone
import hashlib, json, shutil
from pathlib import Path
HERE = Path(__file__).resolve().parent
BASE = HERE / 'working-tree'
TREE = HERE / 'actual-working-tree'
assert not TREE.exists()
pin = json.loads((HERE / 'sol-r14-run-build-5.source.json').read_text())
for name,want in pin['files'].items():
    source=BASE/name;assert hashlib.sha256(source.read_bytes()).hexdigest()==want,name
    target=TREE/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
src=TREE/'hashline/src/private_block'
shutil.copy2(HERE/'staged/split_actual_tests.rs',src/'split_actual_tests.rs')
path=src/'argument.rs';text=path.read_text();needle='pub(crate) mod split_attack_tests;';assert text.count(needle)==1
path.write_text(text.replace(needle,needle+'\n#[cfg(test)]\n#[path="split_actual_tests.rs"]\nmod split_actual_tests;'))
path=src/'split_run_tests.rs';text=path.read_text()
for name in ['parse_digest','read_file']:
    needle='fn '+name+'(';assert text.count(needle)==1;text=text.replace(needle,'pub(super) '+needle)
path.write_text(text)
names=set(pin['files'])|{'hashline/src/private_block/split_actual_tests.rs'}
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest()
(HERE/'sol-r14-actual-build-1.source.json').write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
(HERE/'ACTUAL_BRANCH_STATE.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),
    'base':pin['tree_sha256'],'source':digest,'tree':str(TREE),'files':len(files),'source_edits_held':True,
    'scope':'Isolated actual19trace parity / strict native one-stage proof / fresh verification tests. Queued main malicious receipt source unchanged.',
    'pending':'compile and guarded actual DD/nonDD proof/fresh/corrupt cases; not CLI activation or privacy acceptance'},indent=2)+'\n')
print(json.dumps({'source':digest,'files':len(files)}))
