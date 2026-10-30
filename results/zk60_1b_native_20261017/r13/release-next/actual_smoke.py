"""Normal-release one-block actual-weight proof, fresh verify and tamper gate."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import shutil

HERE=Path(__file__).resolve().parents[1]
ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('sol_r13_runner',ROOT/'results/zk60_sol_20261026/r13_guard.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['prove','verify','tamper']);p.add_argument('--prefix',required=True)
    p.add_argument('--dd',action='store_true');a=p.parse_args()
    pins=json.loads((HERE/f'{a.prefix}.source.json').read_text())['files']
    def check():
        for path,digest in pins.items():assert sha(HERE/'working-tree'/path)==digest,path
    check()
    export=HERE/'actual-t128-smoke-export';seq=HERE/'actual-t128-public-sequence'
    assert sha(export/'profile.json')=='04102cce64dea0cd45dee5caa62095da1cf33fcaabd5647554202b564e6e7e57'
    assert sha(export/'PUBLIC_ORACLE.json')=='9fe10a9c257bd18baf1dd00d752ddfa4e46ef0db914027fcc715d26f2d8e59b2'
    cli=HERE/'working-tree/hashline/target/release/examples/zk60_trained_block'
    suffix='dd' if a.dd else 'plain';stem=f'{a.prefix}-actual-t128-{suffix}'
    artifact=HERE/'release-receipts'/a.prefix/('actual-t128-'+suffix)
    flags=['--dd'] if a.dd else []
    env=['/usr/bin/env','RAYON_NUM_THREADS=8','OPENBLAS_NUM_THREADS=1']
    base=[str(cli),a.mode if a.mode!='tamper' else 'verify','--export',str(export),'--layer','0']
    label=stem+'-'+a.mode
    if a.mode=='prove':
        artifact.parent.mkdir(parents=True,exist_ok=True)
        runner.run(label,'cpu',10.5,12,[*env,*base,'--seq-dir',str(seq),'--out',str(artifact),*flags],seconds=1800)
        events=[json.loads(s) for s in (HERE/f'{label}.log').read_text().splitlines() if s.startswith('{')]
        proved=[e for e in events if e.get('event')=='proved'];assert len(proved)==1
        (HERE/f'{stem}.identity.json').write_text(json.dumps({'statement_identity':proved[0]['statement_identity'],
            'cli_sha256':sha(cli),'profile_sha256':sha(export/'profile.json'),
            'scope':'one actual S2 layer at T128 on public synthetic input; no full26 proof or fidelity/privacy acceptance'},indent=2)+'\n')
    else:
        record=json.loads((HERE/f'{stem}.identity.json').read_text());assert sha(cli)==record['cli_sha256']
        if a.mode=='tamper':
            changed=artifact.with_name(artifact.name+'-tampered');assert not changed.exists()
            shutil.copytree(artifact,changed);file=changed/'segment-000.bin'
            with file.open('r+b') as f:
                f.seek(file.stat().st_size//2);word=f.read(1);f.seek(-1,1);f.write(bytes([word[0]^1]))
            runner.run(label,'cpu',3,6,[*env,*base,'--artifact',str(changed),'--expect-statement',record['statement_identity'],*flags],expected=1,seconds=900)
            output=(HERE/f'{label}.log').read_text();assert '"event":"rejected"' in output and '"event":"verified"' not in output
        else:
            runner.run(label,'cpu',3,6,[*env,*base,'--artifact',str(artifact),'--expect-statement',record['statement_identity'],*flags],seconds=900)
            output=(HERE/f'{label}.log').read_text();assert '"event":"verified"' in output
    check()
    (HERE/f'{label}.PASS.json').write_text(json.dumps({'mode':a.mode,'dd':a.dd,'passed':True,
        'expected_child_exit':1 if a.mode=='tamper' else 0,'scope':'actualL00 only/public synthetic input'},indent=2)+'\n')

if __name__=='__main__':main()
