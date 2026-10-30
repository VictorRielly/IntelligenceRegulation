"""Source pins, independent counters and exact patch-scope checks."""
import hashlib,json,random,resource,time
from pathlib import Path
import candidate as c
import reference as r
HERE=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def ck(v):
    global checks
    checks+=1
    assert v,checks
pins=json.loads((HERE/'native-pins.json').read_text())
for pin in pins:
    ck(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    ck(hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
source=(HERE/'native/hashline__src__private_block__argument.rs').read_text()
field=(HERE/'native/zkp-core__src__field.rs').read_text()
manifest=json.loads((HERE/'adapter-manifest.json').read_text());new=(HERE/'candidate-argument.rs').read_text()
ck(source.count(manifest['original_function'])==1)
ck(source.replace(manifest['original_function'],manifest['candidate_function'],1)==new)
ck(new.count('fn mask_eval(')==1)
ck(new.count('let eq = eq_table_msb(&point[p.log - logm..]);')==source.count('let eq = eq_table_msb(&point[p.log - logm..]);'))
ck('row(p.mask_row).add(Fp2::U.mul(row(p.mask_row + 1)))' in manifest['original_function'])
ck('self.c0.mul(r), c1: self.c1.mul(r)' in field)
ck('pub const NONRESIDUE: u64 = 7;' in field)
ck('cross.sub(a).sub(b)' in manifest['candidate_function'])
ck('p.slices[0].0 % n' in manifest['candidate_function'])
ck('p.mask_row + 1' in manifest['candidate_function'])
ck('eq.iter().zip(re.iter()).zip(im.iter())' in manifest['candidate_function'])
ck(not manifest['compiled'] and not manifest['applied_to_production'])
for fname,key in [('candidate-argument.rs','candidate_sha256'),('paired-mask-dot.unapplied.patch','patch_sha256')]:
    ck(hashlib.sha256((HERE/fname).read_bytes()).hexdigest()==manifest[key])

# Count actual model primitive calls, independent of candidate.counts formula.
original={x:getattr(c,x) for x in ['add','sub','mul']}
rng=random.Random(202610290138)
for n in [0,1,2,3,7,256,8192]:
    eq=[(rng.randrange(c.P),rng.randrange(c.P)) for _ in range(n)]
    xs=[rng.randrange(c.P) for _ in range(n)];ys=[rng.randrange(c.P) for _ in range(n)]
    expected=r.fold([(x,y) for x,y in zip(xs,ys)],[]) if n==1 else None
    for mode in ['baseline','four','three']:
        observed={x:0 for x in original}
        def count(name):
            def invoke(a,b):
                observed[name]+=1
                return original[name](a,b)
            return invoke
        for name in original:setattr(c,name,count(name))
        try:
            val=c.baseline(eq,xs,ys) if mode=='baseline' else c.paired(eq,xs,ys,mode)
        finally:
            for name,func in original.items():setattr(c,name,func)
        projected=c.counts(n)[mode]
        ck(observed['mul']==projected['variable_mul']+projected['constant7_mul'])
        ck(observed['add']==projected['add']);ck(observed['sub']==projected['sub'])
        schoolbook=(sum(a*x+7*b*y for (a,b),x,y in zip(eq,xs,ys))%c.P,
                    sum(b*x+a*y for (a,b),x,y in zip(eq,xs,ys))%c.P)
        ck(val==schoolbook)

# Original candidate Eq is checked against a separate direct-cube basis,
# including fixed and flipped coordinates; no comparison shares Eq code.
for log in range(7):
    point=[(rng.randrange(c.P),rng.randrange(c.P)) for _ in range(log)]
    for kind in ['original','reversed','flipped']:
        rp=point if kind=='original' else point[::-1] if kind=='reversed' else [r.complement(z) for z in point]
        eq=c.eq_msb(rp)
        for i,e in enumerate(eq):
            values=[(0,0)]*(1<<log);values[i]=(1,0)
            ck(e==r.original_cube(values,rp))

historical=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r4/PHASES_T128.md')
b=historical.read_bytes();(HERE/'historical-phases.md').write_bytes(b)
result={'status':'PASS','checks':checks,'source_pins':len(pins),'primitive_count_modes':['baseline-lowered-U','paired-four','paired-three'],
        'historical_phases':{'path':str(historical),'sha256':hashlib.sha256(b).hexdigest(),'rerun':False,'receipts_reverified':False},
        'elapsed_s':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'compiled':False,'applied_to_production':False,'full_stack_proofs':0}
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
