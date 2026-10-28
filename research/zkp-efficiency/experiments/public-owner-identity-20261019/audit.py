#!/usr/bin/env python3
"""Independent audit: does not import or execute candidate functions."""
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import time

HERE=Path(__file__).resolve().parent


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    t=time.perf_counter(); count=0
    def ck(ok):
        nonlocal count
        assert ok
        count+=1
    digest=lambda b:hashlib.sha256(b).hexdigest()
    fixtures=json.loads((HERE/'fixtures.json').read_text())
    def padded(record,request):
        pieces=[]
        for name in sorted(record['arrays']):
            a=record['arrays'][name]; rows=[]
            pr,pc=request['padding'][name]
            for i in range(a['rows']):
                rows.append(bytes(a['data'][i*a['cols']:(i+1)*a['cols']])+bytes(pc-a['cols']))
            rows.extend([bytes(pc)]*(pr-a['rows']))
            pieces.append(b''.join(rows))
        return b''.join(pieces)
    tampered=0
    for rec,req in fixtures:
        ck(digest(padded(rec,req))==req['public_digest'])
        for name,a in rec['arrays'].items():
            ck(digest(bytes(a['data']))==req['array_hashes'][name])
            old=a['data'][0]; a['data'][0]=(old+1)%256
            ck(digest(padded(rec,req))!=req['public_digest']); tampered+=1
            a['data'][0]=old
    for row in json.loads((HERE/'request-ledger.json').read_text()):
        n,p=row['pins'],row['passes']
        seen=set(); misses=hits=0
        for phase in range(2*p):
            for k in range(32):
                if k in seen: hits+=1
                else:
                    misses+=1
                    if k<n: seen.add(k)
        ck(hits==row['hits']); ck(misses==row['constructs'])
        ck(row['raw_read_requests']==hits+misses)
    # Fresh, asymmetric shapes expose mistaken row-copy/transpose/padding.
    rng=random.Random(2026101986); fresh=0
    for _ in range(64):
        r,c=rng.randrange(1,8),rng.randrange(1,6)
        pr,pc=r+rng.randrange(4),c+rng.randrange(4)
        data=[rng.randrange(256) for _ in range(r*c)]
        rec={'arrays':{'x':dict(rows=r,cols=c,data=data)}}
        req={'padding':{'x':[pr,pc]}}
        out=padded(rec,req)
        ck(len(out)==pr*pc)
        for i in range(pr):
            for j in range(pc):
                ck(out[i*pc+j]==(data[i*c+j] if i<r and j<c else 0))
        fresh+=1
    # Public lifetime count checked by explicit sets, not pool logic.
    lifetime=json.loads((HERE/'lifetime-ledger.json').read_text())
    old={('old',0),('old',1)}; new={('new',i) for i in range(4)}
    active={('stream',0),('stream',1)}
    ck(len(old|new|active)==8)
    ck(lifetime['unsafe']['peak_blocks']==8)
    ck(lifetime['safe']['peak_blocks']==6)
    ck(lifetime['safe']['admitted']==2 and lifetime['safe']['denied']==2)
    # Payload size independently sum source-pinned named public axes.
    components=json.loads((HERE.parent/'public-setup-lifetimes-20261019/public-block-payload-components.json').read_text())['128']
    block=sum(components.values()); ck(block==243411456)
    ck(lifetime['safe']['peak_bytes']==6*block)
    ck(lifetime['unsafe']['peak_bytes']==8*block)
    # Guard limitations: preserved owner bytes still name the OLD model.
    # This is a changed source/refusal observation, not an accepted bad proof.
    rec,req=fixtures[0]; retained=padded(rec,req)
    rec['arrays']['wq']['data'][0]^=1
    ck(digest(retained)==req['public_digest'])
    ck(digest(padded(rec,req))!=req['public_digest'])
    native=(HERE/'native/hashline__src__private_block__trained_block.rs').read_text()
    anchors=['self.cur = None;', 'let blk = self.ex.reload_block(',
             'if blk.digest() != self.digests[k]', 'rayon::join(',
             'self.load_layer_mode(sh, c, index, rope_from_export, true)',
             'self.load_layer_mode(sh, c, index, rope_from_export, false)']
    for s in anchors: ck(s in native)
    pins=json.loads((HERE/'source-pins.json').read_text())
    for p in pins: ck(digest(Path(p['source']).read_bytes())==p['sha256'])
    result=dict(status='PASS',checks=count,fixtures=len(fixtures),
        stale_content_controls=tampered,fresh_asymmetric_padding_fixtures=fresh,
        controls=dict(source_mutation_is_not_bad_statement_proof=True,
                      retained_leases_outlive_eviction=True,
                      revalidation_does_not_eliminate_reads=True,
                      asymmetric_padding_audited=True),
        source_pins=len(pins),threads=1,affinity=sorted(os.sched_getaffinity(0)),
        seed=2026101986,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        wall_seconds=time.perf_counter()-t,
        scope='Independent fixture/trace/payload/source audit only; no native proof, admission or privacy gate.')
    (HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__': main()
