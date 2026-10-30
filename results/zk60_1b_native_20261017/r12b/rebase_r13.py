"""Rebase the isolated R13 source on a completed R12b freeze, without Git.

Default is a dry run. Refuse conflicts and preserve pre-rebase source hashes.
Never writes frozen trees or the main native tree.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'r12/frozen-tree'
FROZEN=HERE/'frozen-tree'
WORK=HERE.parent/'r13/working-tree'

def digest(data):return hashlib.sha256(data).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    assert (HERE/'R12B_COMPLETE.done').read_text().strip()=='0','R12b acceptance must finish first'
    manifest=json.loads((HERE/'manifest_frozen.json').read_text())
    plans=[];conflicts=[]
    for name,want in manifest['files'].items():
        old_path=BASE/name;new_path=FROZEN/name;work_path=WORK/name
        newer=new_path.read_bytes();assert digest(newer)==want,name
        older=old_path.read_bytes() if old_path.exists() else None
        candidate=work_path.read_bytes() if work_path.exists() else None
        if newer==older:continue
        if candidate==older or candidate is None:merged=newer
        elif candidate==newer:continue
        elif older is None:conflicts.append(name);continue
        else:
            result=subprocess.run(['diff3','-m',str(work_path),str(old_path),str(new_path)],capture_output=True)
            assert result.returncode in (0,1),(name,result.stderr)
            if result.returncode:conflicts.append(name);continue
            merged=result.stdout
        plans.append((name,candidate,merged))
    report={'base':str(BASE),'r12b_tree_sha256':manifest['tree_sha256'],'conflicts':conflicts,
        'writes':[{'path':n,'before_sha256':digest(before) if before is not None else None,'after_sha256':digest(after)} for n,before,after in plans],
        'applied':False}
    (HERE/'r13-rebase-plan.json').write_text(json.dumps(report,indent=2)+'\n')
    assert not conflicts,f'manual three-way merge required: {conflicts}'
    if args.apply:
        backup=HERE.parent/'r13/pre-r12b-rebase'
        for name,before,after in plans:
            p=WORK/name
            if before is not None:
                save=backup/name;save.parent.mkdir(parents=True,exist_ok=True)
                assert not save.exists(),'refuse to overwrite rebase backup'
                save.write_bytes(before)
            p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(after)
        report['applied']=True
        (HERE/'r13-rebase-applied.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'writes':len(plans),'conflicts':conflicts,'applied':args.apply}))

if __name__=='__main__':main()
