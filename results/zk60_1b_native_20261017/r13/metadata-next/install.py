"""Install the prepared metadata step after native host checks are terminal."""
from pathlib import Path
import datetime
import hashlib
import json
import shutil

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'
assert (out.parent/'argument-act3-3.done').read_text().strip()=='0'
assert '66 passed; 0 failed' in (out.parent/'argument-act3-3.log').read_text()
names=['accuracy_public','trained_statement','run','r4_tests','review_d24_tests',
    'accuracy_profile_tests','s24_tests','s25_tests','s33_tests','argument_accuracy']
backup=out/'pre-install';backup.mkdir(exist_ok=False)
manifest={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'proof_active':False,'files':{}}
for name in names+['private_block']:
    target=src.with_suffix('.rs') if name=='private_block' else src/(name+'.rs')
    candidate=out/(name+'.candidate.rs')
    shutil.copy2(target,backup/(name+'.rs'))
    manifest['files'][name]={'before':hashlib.sha256(target.read_bytes()).hexdigest(),'after':hashlib.sha256(candidate.read_bytes()).hexdigest()}
(backup/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for name in names+['private_block']:
    target=src.with_suffix('.rs') if name=='private_block' else src/(name+'.rs')
    shutil.copy2(out/(name+'.candidate.rs'),target)
(out/'INSTALLED.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Installed11 metadata/validation/run-profile/test sources; proof activation remains refused.')
