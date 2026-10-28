"""Isolated public R-C1 fixture from a retained native tiny export.

No new native build, no production data. The generated table follows the
frozen classify_cli_tests.rs recipe and names the original retained files.
The model identity must still be obtained and independently rechecked by the
pinned native CLI; preparing these files is not proof evidence.
"""
import hashlib
import json
from pathlib import Path
import shutil
import struct

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
SOURCE=ROOT/'results/zk60_1b_native_20261017/tiny_export/round-trip/tiny-v1'
DEST=HERE/'classifier_fixture'
PRIVATE=Path('/tmp/zk60-astra-classifier-owner-20261026')


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def lcg(state):
    state=(state*6364136223846793005+1442695040888963407)&((1<<64)-1)
    return state,state>>33


def main():
    if DEST.exists():raise SystemExit('fixture already exists; do not overwrite')
    shape=json.loads((SOURCE/'layer_00/manifest.json').read_text())['arrays']['wq']['shape']
    d=shape[1];assert d==384
    DEST.mkdir();PRIVATE.mkdir(mode=0o700,exist_ok=False)
    shutil.copytree(SOURCE,DEST/'prover-export')
    shutil.copytree(SOURCE,DEST/'verifier-export',ignore=shutil.ignore_patterns('seq_*'))
    state=0x636c6363;emb=[]
    for _ in range(300*d):
        state,n=lcg(state);emb.append(n%12001-6000)
    xin=struct.unpack('<'+str(32*d)+'h',(SOURCE/'seq_s0/x_in_L00.bin').read_bytes())
    for pos in range(32):emb[(pos+1)*d:(pos+2)*d]=xin[pos*d:(pos+1)*d]
    state=0x6d617267;margin=[]
    for _ in range(d):
        state,n=lcg(state);margin.append(n%65535-32767)
    for name,sign in (('tables',1),('tables-neg',-1)):
        directory=DEST/name;directory.mkdir()
        (directory/'embedding_int16.bin').write_bytes(struct.pack('<'+str(len(emb))+'h',*emb))
        (directory/'margin_int16.bin').write_bytes(struct.pack('<'+str(d)+'h',*(x*sign for x in margin)))
        (directory/'token_io.json').write_text(json.dumps({'bos':1,'embedding_table':{'dtype':'int16',
            'file':'embedding_int16.bin','shape':[300,d],'sha256':digest(directory/'embedding_int16.bin')}})+'\n')
        (directory/'classifier.json').write_text(json.dumps({'schema':'zk60-classifier-tables/1','bos':1,
            'margin_vector':{'dtype':'int16','file':'margin_int16.bin','d':d,'sha256':digest(directory/'margin_int16.bin')},
            'final_norm':{'g0':127,'cn':2048,'tn':11,'ceps':33554467}})+'\n')
    content=PRIVATE/'content.ids'
    with content.open('x') as f:f.write(','.join(str(n) for n in range(9,32))+'\n')
    content.chmod(0o600)
    source_files={str(p.relative_to(SOURCE)):digest(p) for p in sorted(SOURCE.rglob('*')) if p.is_file()}
    generated={str(p.relative_to(DEST)):digest(p) for p in sorted(DEST.rglob('*')) if p.is_file()}
    manifest={'schema':'pm-r-c1-development-fixture/1','source':str(SOURCE),'source_files':source_files,
        'generated_files':generated,'tool_sha256':digest(Path(__file__)),'private_root':str(PRIVATE),
        'policy':'rung-tc-synthetic-policy-dev/1','content_tokens':23,'scope':'public synthetic fixture; no native run yet'}
    (DEST/'fixture.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'fixture':str(DEST),'private_root':str(PRIVATE),'source_files':len(source_files),'generated_files':len(generated)}))


if __name__=='__main__':main()
