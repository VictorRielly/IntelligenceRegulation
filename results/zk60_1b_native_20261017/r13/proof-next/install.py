"""Install development proof gates after the v2 reader/components pass."""
from pathlib import Path
import datetime
import hashlib
import json
import shutil

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'
assert (out.parent/'loader-v2-2.done').read_text().strip()=='0'
assert '75 passed; 0 failed' in (out.parent/'loader-v2-2.log').read_text()
s=(out/'private_block.scope.candidate.rs').read_text()
needle='#[cfg(test)]\nmod accuracy_profile_tests;'
assert s.count(needle)==1
s=s.replace(needle,needle+'\n#[cfg(test)]\nmod accuracy_proof_tests;')
(out/'private_block.ready.candidate.rs').write_text(s)
names={'private_block':'private_block.ready.candidate.rs','witness':'witness.scope.candidate.rs',
    'accuracy_profile_tests':'accuracy_profile_tests.ledger.candidate.rs','accuracy_proof_tests':'accuracy_proof_tests.candidate.rs'}
backup=out/'pre-install';backup.mkdir(exist_ok=False)
manifest={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'production_proof_active':False,'files':{}}
for name,candidate in names.items():
    target=src.with_suffix('.rs') if name=='private_block' else src/(name+'.rs')
    if target.exists():shutil.copy2(target,backup/(name+'.rs'))
    manifest['files'][name]={'before':hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None,
        'after':hashlib.sha256((out/candidate).read_bytes()).hexdigest()}
(backup/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for name,candidate in names.items():
    target=src.with_suffix('.rs') if name=='private_block' else src/(name+'.rs')
    shutil.copy2(out/candidate,target)
(out/'INSTALLED.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Installed scoped test-only full-proof gates and native census; production availability still false.')
