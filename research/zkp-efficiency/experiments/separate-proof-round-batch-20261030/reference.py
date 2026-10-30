"""Independent bigint reference and serial Rust interface differential harness.

The SHA256 transcript and deterministic synthetic masks are research fixtures.
They replace neither the native BLAKE3/CFS/PCS protocol nor OS entropy.
"""
from pathlib import Path
import copy, hashlib, itertools, json, random, struct, subprocess

D=Path(__file__).resolve().parent
P=2**64-2**32+1
Z=(0,0); O=(1,0)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def neg(a):return ((-a[0])%P,(-a[1])%P)
def sub(a,b):return add(a,neg(b))
def mul(a,b):return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def prod(xs):
    a=O
    for x in xs:a=mul(a,x)
    return a
def inv(x):
    den=pow((x[0]*x[0]-7*x[1]*x[1])%P,P-2,P)
    return (x[0]*den%P,-x[1]*den%P)
def enc(xs):return b''.join(struct.pack('<QQ',*x) for x in xs)
def poly(xs,d):return add(prod(xs[:d]),xs[d])
def g_eval(j,point):
    # Expand the CFS polynomial itself, then sum Boolean suffixes. Do not use
    # native CfsMask::round's closed form, sum weights or eval weights.
    coeff=j['mask'];out=add(coeff[0],mul(coeff[1],prod(point)))
    for i,x in enumerate(point):
        for exponent in range(1,j['d']+1):
            out=add(out,mul(coeff[2+i*j['d']+exponent-1],prod([x]*exponent)))
    return out
def mle(table,point):
    out=Z;n=len(point)
    for index,value in enumerate(table):
        w=prod([point[b] if (index>>(n-1-b))&1 else sub(O,point[b]) for b in range(n)])
        out=add(out,mul(value,w))
    return out
def lagrange(values,x):
    out=Z
    for i,v in enumerate(values):
        w=O
        for k in range(len(values)):
            if k!=i:w=mul(w,mul(sub(x,(k,0)),inv(((i-k)%P,0))))
        out=add(out,mul(v,w))
    return out
class Transcript:
    def __init__(self,j):
        self.state=hashlib.sha256(b'research-only-SHA256/'+struct.pack('<QQQQ',j['id'],j['site'],j['generation'],j['seed'])).digest()
        self.counter=0
    def challenge(self,values):
        data=enc(values);label=b'sc-round'
        self.state=hashlib.sha256(self.state+struct.pack('<Q',len(label))+label+struct.pack('<Q',len(data))+data).digest()
        self.state=hashlib.sha256(self.state+b'squeeze'+struct.pack('<Q',self.counter)).digest();self.counter+=1
        return (int.from_bytes(self.state[:16],'little')%P,int.from_bytes(self.state[16:],'little')%P)
def scalar(j):
    tabs=copy.deepcopy(j['tabs']);prev=[];rounds=[];tr=Transcript(j)
    for r in range(j['n']):
        half=len(tabs[0])//2;sums=[]
        for x in range(j['d']+1):
            xv=(x,0);value=Z
            for i in range(half):
                vals=[add(mul(sub(O,xv),tb[i]),mul(xv,tb[i+half])) for tb in tabs]
                value=add(value,poly(vals,j['d']))
            for bits in itertools.product([Z,O],repeat=j['n']-r-1):
                value=add(value,mul(j['c'],g_eval(j,prev+[xv]+list(bits))))
            sums.append(value)
        challenge=tr.challenge(sums);rounds.append(sums);prev.append(challenge)
        tabs=[[add(mul(sub(O,challenge),tb[i]),mul(challenge,tb[i+half])) for i in range(half)] for tb in tabs]
    finals=[mle(tb,prev) for tb in j['tabs']]
    assert finals==[tb[0] for tb in tabs]
    claim=Z
    for i in range(1<<j['n']):claim=add(claim,poly([tb[i] for tb in j['tabs']],j['d']))
    for bits in itertools.product([Z,O],repeat=j['n']):claim=add(claim,mul(j['c'],g_eval(j,list(bits))))
    initial_claim=claim
    for sums,r in zip(rounds,prev):
        assert add(sums[0],sums[1])==claim
        claim=lagrange(sums,r)
    assert claim==add(poly(finals,j['d']),mul(j['c'],g_eval(j,prev)))
    return dict(rounds=rounds,challenges=prev,finals=finals,transcript=tr.state.hex(),initial_claim=initial_claim)
def fixture(seed,b,d,ragged):
    rng=random.Random(seed);out=[]
    for i in range(b):
        n=3+i if ragged else 6
        draw=lambda:(rng.randrange(P),rng.randrange(P))
        out.append(dict(id=100+i,site=1000+i,generation=1,n=n,d=d,seed=seed,c=draw(),
                        mask=[draw() for _ in range(n*d+2)],tabs=[[draw() for _ in range(1<<n)] for _ in range(d+1)]))
    return out
class Engine:
    def __init__(self):
        self.p=subprocess.Popen([str(D/'batch')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
        self.commands=0
    def ask(self,line,ok=True):
        self.commands+=1;self.p.stdin.write(line+'\n');self.p.stdin.flush();out=self.p.stdout.readline().strip()
        assert out.startswith('OK' if ok else 'ERR'),(line[:100],out)
        return out
    def load(self,j,ok=True):
        flat=[str(x) for pair in [j['c']]+j['mask']+[v for tb in j['tabs'] for v in tb] for x in pair]
        return self.ask(' '.join(map(str,['load',j['id'],j['site'],j['generation'],j['n'],j['d']]+flat)),ok)
    def stop(self):
        self.p.stdin.close();assert self.p.wait(timeout=3)==0,self.p.stderr.read()
def tag(j,r):return f"{j['id']} {j['site']} {j['generation']} {r}"
def parse_round(out):
    result={}
    for part in out.split('|')[1:]:
        v=list(map(int,part.split()));assert len(v)>=10
        result[v[0]]=(v[:4],list(zip(v[4::2],v[5::2])))
    return result
def run(jobs,expected,style):
    if style=='scalar':
        # Actual one-job admission: each child owns one table set, completes,
        # releases and exits before the next is loaded. This is a correctness
        # baseline, not a timing comparison (process count differs).
        parts=[run([j],expected,'single') for j in jobs]
        return dict(style=style,round_evaluate_fold_submissions=sum(x['round_evaluate_fold_submissions'] for x in parts),
                    commands=sum(x['commands'] for x in parts),numeric_limb_comparisons=sum(x['numeric_limb_comparisons'] for x in parts))
    engine=Engine();transcripts={j['id']:Transcript(j) for j in jobs};rpos={j['id']:0 for j in jobs};seen={j['id']:[] for j in jobs}
    for j in jobs:engine.load(j)
    dispatches=0;numeric=0
    while any(rpos[j['id']]<j['n'] for j in jobs):
        ready=[j for j in jobs if rpos[j['id']]<j['n']]
        if style=='scalar':ready=ready[:1]
        elif style=='reverse':ready.reverse()
        else:random.Random(91+dispatches).shuffle(ready)
        out=parse_round(engine.ask('eval '+str(len(ready))+' '+' '.join(tag(j,rpos[j['id']]) for j in ready)));dispatches+=1
        assert set(out)=={j['id'] for j in ready}
        folds=[]
        for j in ready:
            id=j['id'];r=rpos[id];header,values=out[id];assert header==[id,j['site'],j['generation'],r]
            assert values==expected[id]['rounds'][r],(style,id,r,'masked round')
            c=transcripts[id].challenge(values);assert c==expected[id]['challenges'][r]
            folds.append(tag(j,r)+f' {c[0]} {c[1]}');seen[id].append(values);numeric+=2*len(values)+2
        # Reorder fold descriptors separately from evaluation return order.
        engine.ask('fold '+str(len(ready))+' '+' '.join(reversed(folds)));dispatches+=1
        for j in ready:rpos[j['id']]+=1
    for j in jobs:
        id=j['id'];v=list(map(int,engine.ask('final '+tag(j,j['n'])).split()[1:]));finals=list(zip(v[::2],v[1::2]))
        assert finals==expected[id]['finals'];assert transcripts[id].state.hex()==expected[id]['transcript']
        engine.ask('release '+tag(j,j['n']));numeric+=len(v)
    commands=engine.commands;engine.stop()
    return dict(style=style,round_evaluate_fold_submissions=dispatches,commands=commands,numeric_limb_comparisons=numeric)

def controls():
    jobs=fixture(20261030,2,2,False)
    for j in jobs:
        j['n']=3;j['mask']=j['mask'][:8];j['tabs']=[tb[:8] for tb in j['tabs']]
    a,b=jobs;engine=Engine();names=[]
    for j in jobs:engine.load(j)
    def reject(name,line):engine.ask(line,False);names.append(name)
    reject('fold-before-result','fold 1 '+tag(a,0)+' 2 3')
    reject('duplicate-eval-owner','eval 2 '+tag(a,0)+' '+tag(a,0))
    reject('wrong-mask-site','eval 1 '+f"{a['id']} {b['site']} 1 0")
    reject('wrong-generation','eval 1 '+f"{a['id']} {a['site']} 2 0")
    reject('early-round','eval 1 '+tag(a,1))
    reject('atomic-invalid-eval-batch','eval 2 '+tag(a,0)+' '+tag(b,1))
    reject('early-release','release '+tag(a,0))
    dup=copy.deepcopy(b);dup['id']=999;dup['site']=a['site'];engine.load(dup,False);names.append('shared-live-site')
    engine.load(a,False);names.append('overwrite-live-owner')
    wrong=copy.deepcopy(a);wrong['id']=999;wrong['site']=999;wrong['c']=Z;engine.load(wrong,False);names.append('zero-mask-multiplier')
    out=parse_round(engine.ask('eval 2 '+tag(a,0)+' '+tag(b,0)))
    reject('reuse-before-fold','eval 1 '+tag(a,0))
    reject('release-pending','release '+tag(a,0))
    reject('swapped-fold-site','fold 1 '+f"{a['id']} {b['site']} 1 0 2 3")
    reject('duplicate-fold-owner','fold 2 '+tag(a,0)+' 2 3 '+tag(a,0)+' 2 3')
    # The second invalid descriptor must not consume the first job's pending round.
    reject('atomic-invalid-fold-batch','fold 2 '+tag(a,0)+' 2 3 '+tag(b,1)+' 2 3')
    refs={j['id']:scalar(j) for j in jobs}
    assert out[a['id']][1]!=out[b['id']][1];names.append('swapped-result-content-detected')
    ca=Transcript(a).challenge(out[a['id']][1]);cb=Transcript(b).challenge(out[b['id']][1]);assert ca!=cb
    # Deliberately retagged wrong challenge: raw arithmetic API cannot authenticate
    # challenge values. It accepts; the independent expected stream detects this.
    engine.ask('fold 2 '+tag(a,0)+f' {cb[0]} {cb[1]} '+tag(b,0)+f' {ca[0]} {ca[1]}')
    changed=parse_round(engine.ask('eval 2 '+tag(a,1)+' '+tag(b,1)))
    assert all(changed[j['id']][1]!=refs[j['id']]['rounds'][1] for j in jobs)
    for j,c in [(a,ca),(b,cb)]:
        message=changed[j['id']][1]
        assert add(message[0],message[1])!=lagrange(out[j['id']][1],c)
    names.append('retagged-swapped-challenges-accepted-raw-detected-by-reference')
    # Must restore/abandon whole synthetic jobs; no retry is modeled on changed state.
    engine.stop()
    engine=Engine();wrong=copy.deepcopy(a);wrong['mask']=b['mask'];engine.load(wrong)
    values=parse_round(engine.ask('eval 1 '+tag(wrong,0)))[wrong['id']][1]
    assert values!=refs[a['id']]['rounds'][0]
    engine.stop();names.append('retagged-swapped-mask-content-detected-by-reference')
    # Retirement and generation monotonicity, using a separate clean process.
    engine=Engine();j=copy.deepcopy(a);j['n']=1;j['mask']=j['mask'][:4];j['tabs']=[tb[:2] for tb in j['tabs']];engine.load(j)
    val=parse_round(engine.ask('eval 1 '+tag(j,0)))[j['id']][1];c=Transcript(j).challenge(val)
    engine.ask('fold 1 '+tag(j,0)+f' {c[0]} {c[1]}');engine.ask('release '+tag(j,1))
    engine.load(j,False);names.append('retired-generation-replay')
    j['generation']=2;engine.load(j);names.append('fresh-generation-admitted')
    engine.stop()
    # Main rounds accept 0 and 1; rejection of extension challenges 0/1 is a
    # separate native extension obligation and is deliberately not modeled.
    for c in [Z,O]:
        engine=Engine();j=copy.deepcopy(a);j['n']=1;j['mask']=j['mask'][:4];j['tabs']=[tb[:2] for tb in j['tabs']];engine.load(j)
        engine.ask('eval 1 '+tag(j,0));engine.ask('fold 1 '+tag(j,0)+f' {c[0]} {c[1]}')
        v=list(map(int,engine.ask('final '+tag(j,1)).split()[1:]));assert list(zip(v[::2],v[1::2]))==[tb[c[0]] for tb in j['tabs']]
        engine.stop();names.append('main-challenge-'+str(c[0])+'-preserved')
    return names

def main():
    fixtures=[];rows=[];reference_checks=0
    grid=list(itertools.product([601,602,603],[2,3,4],[2,4],[False,True]))
    grid+=list(itertools.product([604],[2,3,4],[2,4],[True]))
    for seed,d,b,ragged in grid:
        jobs=fixture(seed,b,d,ragged);reference_checks+=len(jobs)
        if seed==604:
            edges=[Z,O,(P-1,0),(0,P-1),(P-1,P-1),(2**32-1,2**63)]
            for i,j in enumerate(jobs):
                j['mask']=[edges[(k+i)%len(edges)] for k in range(j['n']*j['d']+2)]
                j['tabs']=[[edges[(k+t+i)%len(edges)] for k in range(1<<j['n'])] for t in range(j['d']+1)]
        expected={j['id']:scalar(j) for j in jobs}
        schedules=[run(jobs,expected,s) for s in ['scalar','reverse','shuffle']]
        scalar_calls=schedules[0]['round_evaluate_fold_submissions'];batch_calls=schedules[1]['round_evaluate_fold_submissions']
        assert scalar_calls==2*sum(j['n'] for j in jobs);assert batch_calls==2*max(j['n'] for j in jobs)
        # 16 bytes/Fp2; logical owned tables only, excludes masks, witnesses,
        # commitments, allocator capacity, GPU pools and model residency.
        live=[16*(j['d']+1)*(1<<j['n']) for j in jobs]
        rows.append(dict(seed=seed,degree=d,batch=b,ragged=ragged,n=[j['n'] for j in jobs],schedules=schedules,
                         scalar_table_payload_peak_bytes=max(live),batch_table_payload_bytes=sum(live),
                         scalar_rounds=sum(j['n'] for j in jobs),batch_waves=max(j['n'] for j in jobs),field_work_saved=0))
        fixtures.append(dict(jobs=jobs,expected=expected))
    names=controls()
    result=dict(status='PASS',fixture_groups=len(rows),independent_scalar_jobs=reference_checks,
        schedules_per_group=3,rust_job_runs=reference_checks*3,control_count=len(names),controls=names,
        numeric_limb_comparisons=sum(s['numeric_limb_comparisons'] for row in rows for s in row['schedules']),
        no_proving_speedup_measured=True,complete_proofs=0,proved_positions=0,
        limitation='Serial CPU arithmetic and surrogate SHA256 transcripts. No native BLAKE3, GPU, PCS, extension rounds, privacy/soundness proof or timing claim.',rows=rows)
    (D/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
    (D/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='rows'},indent=2))
if __name__=='__main__':main()
