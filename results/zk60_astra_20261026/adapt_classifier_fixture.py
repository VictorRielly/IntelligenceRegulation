"""Add frozen R-C1 profile metadata to the isolated legacy fixture only."""
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
FIX=HERE/'classifier_fixture'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    manifest=FIX/'fixture.json';old=json.loads(manifest.read_text())
    backup=FIX/'fixture.initial.json'
    with backup.open('x') as f:f.write(manifest.read_text())
    changes={}
    for name in ('prover-export','verifier-export'):
        p=FIX/name/'profile.json';obj=json.loads(p.read_text());before=sha(p)
        if 'variant' in obj:raise ValueError('fixture already adapted')
        obj['variant']='astra-retained-rung-tc'
        obj['layers']=[{'layer':0,'dir':'layer_00','manifest_sha256':sha(p.parent/'layer_00/manifest.json')}]
        p.write_text(json.dumps(obj,indent=2)+'\n')
        changes[str(p.relative_to(FIX))]={'before':before,'after':sha(p)}
    old['adaptation']={'tool_sha256':sha(Path(__file__)),'initial_manifest_sha256':sha(backup),
                      'changes':changes,'reason':'frozen R-C1 requires a profile variant; bind existing layer manifest'}
    old['generated_files']={name:sha(FIX/name) for name in old['generated_files']}
    manifest.write_text(json.dumps(old,indent=2)+'\n')
    print(json.dumps(old['adaptation']))

if __name__=='__main__':main()
