"""Bind accepted public receipt bytes in the independent uncompiled observer."""
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'capture-working-tree';LABEL='sol-r14-capture-build-1'
assert not (HERE/(LABEL+'.command.json')).exists(),'source held after recorded build'
pin=json.loads((HERE/(LABEL+'.source.json')).read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for name,want in pin['files'].items():assert sha(TREE/name)==want,name
src=TREE/'hashline/src/private_block'
path=src/'split_run.rs';text=path.read_text();needle='super::run_capture::split::stage_end(k, end, &self.tr);'
assert text.count(needle)==1;text=text.replace(needle,'super::run_capture::split::stage_end(k, end, &self.tr, bytes);');path.write_text(text)
shutil.copy2(HERE/'staged/split_capture.rs',src/'split_capture.rs')
subprocess.run(['/home/victor/.cargo/bin/rustfmt','--edition','2021',str(path)],check=True)
files={name:sha(TREE/name) for name in pin['files']}
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in sorted(files.items())).encode()).hexdigest()
(HERE/(LABEL+'.source.json')).write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
state=json.loads((HERE/'CAPTURE_BRANCH_STATE.json').read_text());state.update(utc=datetime.now(timezone.utc).isoformat(),source=digest,
    public_receipt_provenance='Uncompiled writer records actual accepted stage receipt SHA256/length and explicit ordered public block digests.')
(HERE/'CAPTURE_BRANCH_STATE.json').write_text(json.dumps(state,indent=2)+'\n');print(json.dumps({'source':digest,'files':len(files),'status':'uncompiled'}))
