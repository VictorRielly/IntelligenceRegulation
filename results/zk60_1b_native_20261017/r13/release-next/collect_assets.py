"""Pin public R13 test/import assets; retain the authenticated checkpoint pin."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parents[1]

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda:stream.read(1<<20),b''):h.update(data)
    return h.hexdigest()

def main():
    roots=['loader-fixtures','shieldstral-export-v2','actual-t128-smoke-export','actual-t128-public-sequence']
    files={}
    for name in roots:
        directory=HERE/name;assert directory.is_dir(),name
        for path in sorted(directory.rglob('*')):
            assert not path.is_symlink(),str(path)
            if path.is_file():
                files[str(path.relative_to(HERE))]={'sha256':sha(path),'bytes':path.stat().st_size}
    pinned=''.join(f'{p} {v["sha256"]}\n' for p,v in sorted(files.items()))
    result={'scope':'public synthetic fixtures/oracles and actual transformed public weights/tied tables; no private sequence',
            'roots':roots,'count':len(files),'bytes':sum(x['bytes'] for x in files.values()),
            'tree_sha256':hashlib.sha256(pinned.encode()).hexdigest(),'files':files,
            'external_checkpoint':{'model':'mistralai/Shieldstral-1.0-3B','revision':'003ec7e2b0bab5f0e6307edbaf186fa5822b76f5',
                'weights_sha256':'87753e30c8c321da478b83bbabebcd813cc9b3d0cee5c5b3d64349a8ee4172f7',
                'tied_tensor_sha256':'67a138c1c483b89874526ef523f5f0c30f161808076561730193d1de2093dd19',
                'validation':'native loader reauthenticates the whole checkpoint and regenerates tied tables; no checkpoint copy in this package'}}
    target=HERE/'PUBLIC_ASSETS.json'
    if target.exists():assert json.loads(target.read_text())==result,'public assets changed; retain old manifest and investigate'
    else:target.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['count','bytes','tree_sha256','scope']}))

if __name__=='__main__':main()
