"""Independent source/incidence/cost audit; does not import candidate code."""
import hashlib
import json
import math
import random
import re
import resource
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
checks = 0


def check(v, label):
    global checks
    assert v, label
    checks += 1


def main():
    start=time.monotonic()
    pins=json.loads((ROOT/'source-manifest.json').read_text())
    sources={}
    for pin in pins:
        data=(ROOT/pin['snapshot']).read_bytes()
        check(hashlib.sha256(data).hexdigest()==pin['sha256'],'snapshot hash')
        if '/docs/' not in pin['path']:
            check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],'current tested source pin')
        sources[pin['path']]=data.decode()
    def source(suffix):
        return next(v for k,v in sources.items() if k.endswith('/trained-1b/'+suffix))
    mle=source('zkp-core/src/mle.rs')
    check('num = num.mul(x.sub_base(Fp::new(j as u64)))' in mle,'native node ordering')
    check('den = den.mul(Fp::from_i64(i as i64 - j as i64))' in mle,'native denominator sign')
    check('vals[i].mul(num).mul_base(den.inv())' in mle,'native inversion in inner interpolation call')
    check('pub use zkp_core::mle::*;' in source('hashline/src/mle.rs'),'adapter reaches canonical core')
    a=source('hashline/src/private_block/argument.rs')
    constructors=[
      {'name':'B::supp','reusable':'full checked shape/domain/cube identity; retain tile_rep refusal', 'dynamic':'none', 'evidence':'fn supp(&mut self, dom: Dom, cube_len: usize)'},
      {'name':'rope_tables_at','reusable':'checked shape/domain and full authenticated public RoPE contents', 'dynamic':'none', 'evidence':'pub(super) fn rope_tables_at'},
      {'name':'table_values_u8_at','reusable':'base index vector only', 'dynamic':'fresh g_u8 shift must recur', 'evidence':'k((i % U8_LEN) as i64).add(g_u8)'},
      {'name':'table_values_exp_at','reusable':'authenticated raw public exp values/index only', 'dynamic':'fresh beta and g_exp must recur', 'evidence':'beta.mul(k(public.exp[i]))).add(g_exp)'},
      {'name':'table_values_act_at','reusable':'authenticated raw public act values/index only', 'dynamic':'fresh beta and g_act must recur', 'evidence':'beta.mul(k(i64::from(ff.act[i])))).add(g_act)'}]
    for row in constructors:
        check(row['evidence'] in a,'constructor dependency '+row['name'])
    check('point: point.to_vec()' in a,'Eq point is current transcript data')
    legacy_cuda=next(v for k,v in sources.items() if k.endswith('/gpu-zerocheck/hashline/src/gpu/cuda.rs'))
    check('self.claim = Some(crate::mle::interpolate_eval(&sums, r))' in legacy_cuda,'separately pinned legacy GPU branch fold interpolates on host')
    check('DevFzcRounds' not in source('hashline/src/gpu/cuda.rs'),'native R12 GPU module differs; do not transfer FZC incidence')
    shape=source('hashline/src/private_block/shape.rs')
    base=list(map(int,re.search(r'const BASE_DEGREE:.*?= \[([^]]+)\]',shape).group(1).split(',')))
    check(base==[3,3,3,4,3,2,2,2,2,2,2,2,2,2,4,4,4,4,4,3,2,2,2,4],'native degrees')
    check('64 => Some(13)' in shape and '128 => Some(14)' in shape,'registered row widths')
    check('SC_DD => Dom::Dd' in shape,'DD last-slot main domain')
    check('SC_WO => clog2(self.q_pad())' in shape,'R12 Wo uses query width')
    layout=source('hashline/src/private_block/layout.rs')
    toy_literal=re.search(r'const SLOTS:.*?= \[(.*?)\];',layout,re.S).group(1)
    toy=[tuple(map(int,row)) for row in re.findall(r'\((\d+),\s*(\d+),\s*(\d+)\)',toy_literal)]
    check(sum(x[0] for x in toy)==159 and sum(x[1] for x in toy)==25,'independent toy literal counts')
    result=json.loads((ROOT/'result.json').read_text())
    for row in result['per_call_source_api_counts']:
        m=row['samples']
        old={'ext_sub_base':m*(m-1),'ext_mul':m*m,'base_den_mul':m*(m-1),'base_inv':m,'ext_mul_base':m,'ext_add':m}
        new={'ext_sub':m*(m-1)//2,'ext_mul_base':m-1,'ext_sub_base':m-1,'ext_mul':m-1,'ext_add':m-1}
        check(old==row['literal'],'old operation census')
        check(new==row['prepared'],'new operation census')
    def costs(slots):
        calls=sum(n+e for n,e,d in slots)
        return {'interpolation_calls':calls,'base_inv_removed':sum((n+e)*(d+1) for n,e,d in slots),
                'ext_mul_removed':sum((n+e)*((d+1)**2-d) for n,e,d in slots),
                'ext_sub_added':sum((n+e)*(d+1)*d//2 for n,e,d in slots),
                'scope':'one honest block verifier; not full verifier time, prover count or hardware instructions'}
    counts=[{'geometry':'frozen toy','slots':toy,'cost':costs(toy)}]
    for t,lc in [(32,13),(64,13),(128,14)]:
        # Declared Llama3 geometry from trained_geometry; P3 lift from domain_log_at.
        lg=lambda x:(x-1).bit_length()
        logs={'D':lg(t*4096),'T':lg(t),'L':max(lg(16*t),lc),
              'S':lg(32*t*t),'Q':lg(t*32*128),'Kv':max(lg(t*8*128),lc),
              'F':lg(t*16384),'Tab':lc}
        main=[logs[x] if isinstance(x,str) else x for x in ['D','D','T','L','S',12,12,12,10,3+lg(t),12,12,12,14,'D','Q','Kv','S','F','Tab','Tab','D','D']]
        deg=base[:23];deg[8]+=1;deg[9]+=1;deg[18]+=1
        slots=[(n,2 if s in (8,9) else 1,deg[s]) for s,n in enumerate(main)]
        counts.append({'geometry':f'R12 base 8B T{t} nonDD','log_cols':lc,'slots':slots,'cost':costs(slots),'scope_limit':'excludes R13 LOW+h24 changes, endpoint/token stages; source-counted, no native execution'})
        if t==128:
            dd=slots+[(lg(32*t*32),1,4)]
            counts.append({'geometry':'R12 base 8B T128 DD32','log_cols':lc,'slots':dd,'cost':costs(dd),'scope_limit':'excludes R13 LOW+h24 changes, endpoint/token stages; source-counted, no native execution'})
    # Stale table cache controls. Public table bytes != proof-independent encodings.
    p=2**64-2**32+1
    for beta,tag in [(3,7),(11,19),(0,0),(p-1,p-1)]:
        raw=[(i*i+3*i+1)%p for i in range(256)]
        old=[(i+beta*x+tag)%p for i,x in enumerate(raw)]
        fresh=[(i+(beta+1)*x+tag+1)%p for i,x in enumerate(raw)]
        check(old!=fresh,'fresh encoded table cannot be shape cached')
        check([(i+tag)%p for i in range(256)]!=[(i+tag+1)%p for i in range(256)],'fresh U8 tag cannot be shape cached')
    # Powers inside Fp::inv, explicitly a source lowering count, not codegen.
    e=p-2
    inversion_source_products=e.bit_length()+e.bit_count()
    for row in counts:
        row['cost']['base_products_inside_removed_source_inversions']=row['cost']['base_inv_removed']*inversion_source_products
    out={'status':'PASS_SOURCE_AND_COUNT_AUDIT_ONLY','checks':checks,'source_pins':len(pins),
         'public_constructor_dependencies':constructors,'counts':counts,'inversion_source_products_each':inversion_source_products,
         'scratch':'one [Fp2;6] stack array (96 bytes); 48 bytes of inverse-factorial constants; per-call initialization/copy/dispatch remain',
         'important_negative':'five constructors include three challenge-dependent encoded tables; caching finished encodings by shape is stale. Scalar interpolation touches only O(log cube) calls, does not delete dense cube scan/fold work.',
         'elapsed_seconds':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
    (ROOT/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({'status':out['status'],'checks':checks,'source_pins':len(pins),'counts':[{k:v for k,v in row.items() if k not in ['slots']} for row in counts],'elapsed_seconds':out['elapsed_seconds'],'max_rss_kib':out['max_rss_kib']},indent=2))


if __name__=='__main__':main()
