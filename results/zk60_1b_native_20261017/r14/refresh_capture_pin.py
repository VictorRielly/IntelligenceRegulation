"""Finalize an uncompiled capture draft before its first recorded build."""
import hashlib,json,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'capture-working-tree';LABEL='sol-r14-capture-build-1'
assert not (HERE/(LABEL+'.command.json')).exists(),'source held once build recorded'
pin=json.loads((HERE/(LABEL+'.source.json')).read_text())
name='hashline/src/private_block/split_capture.rs'
for path,want in pin['files'].items():assert hashlib.sha256((TREE/path).read_bytes()).hexdigest()==want,path
shutil.copy2(HERE/'staged/split_capture.rs',TREE/name)
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in pin['files']}
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in sorted(files.items())).encode()).hexdigest()
(HERE/(LABEL+'.source.json')).write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
state=json.loads((HERE/'CAPTURE_BRANCH_STATE.json').read_text());state['source']=digest;state['status']='Uncompiled hooks and3stage capture tests, independent tree; arithmetic candidate unchanged'
(HERE/'CAPTURE_BRANCH_STATE.json').write_text(json.dumps(state,indent=2)+'\n');print(json.dumps({'source':digest,'files':len(files)}))
