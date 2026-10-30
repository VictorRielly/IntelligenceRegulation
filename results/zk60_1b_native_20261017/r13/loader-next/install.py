"""Install the v2 reader after the metadata coverage gates are terminal."""
from pathlib import Path
import datetime
import hashlib
import json
import shutil

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'
for i in range(6):assert (out.parent/f'metadata-gate-{i}.done').read_text().strip()=='0'
names={'trained_block.rs':'trained_block.dispatch.candidate.rs',
    'trained_accuracy.rs':'trained_accuracy.ready.candidate.rs',
    'trained_statement.rs':'trained_statement.dispatch.candidate.rs',
    'run.rs':'run.dispatch.candidate.rs'}
backup=out/'pre-install';backup.mkdir(exist_ok=False)
manifest={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'proof_active':False,'files':{}}
for name,candidate in names.items():
    shutil.copy2(src/name,backup/name)
    manifest['files'][name]={'before':hashlib.sha256((src/name).read_bytes()).hexdigest(),
        'after':hashlib.sha256((out/candidate).read_bytes()).hexdigest()}
(backup/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for name,candidate in names.items():shutil.copy2(out/candidate,src/name)
(out/'INSTALLED.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Installed v2 reader/public import/run preflight dispatch; ordinary R13 proofs remain refused.')
