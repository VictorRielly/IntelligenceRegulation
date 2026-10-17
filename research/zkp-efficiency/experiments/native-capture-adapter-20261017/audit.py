"""Independent post-run provenance, emitted-index and metadata audit.

This audit does not execute native Rust or generate proof receipts.
"""
import ast,hashlib,json,os,random,resource,signal,time
from pathlib import Path
from adapter import compile_capture,eligible,config,proof_arguments
from native_fixture import fixture
from field_support import F,P
import reference as ref

HERE=Path(__file__).resolve().parent


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024*1024,512*1024*1024))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59);os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});start=time.perf_counter();n=0
    r=json.loads((HERE/'result.json').read_text());assert r['status']=='pass';n+=1
    cmd=json.loads((HERE/'command.json').read_text())
    for name,want in cmd['source_sha256'].items():
        assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==want,name;n+=1
    for p in json.loads((HERE/'native-pins.json').read_text()):
        assert hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'];n+=1
    rng=random.Random(2026101757001)
    for _ in range(1000):
        x=F(rng.randrange(P),rng.randrange(P));y=F(rng.randrange(P),rng.randrange(P))
        assert ref.cv(x*y)==ref.mul(ref.cv(x),ref.cv(y));n+=1
        assert ref.cv(x+y)==ref.add(ref.cv(x),ref.cv(y));n+=1
        assert ref.cv(x-y)==ref.sub(ref.cv(x),ref.cv(y));n+=1
    for p in (HERE/'generated').glob('*.py'):
        tree=ast.parse(p.read_text());fn=tree.body[0];assert isinstance(fn,ast.FunctionDef);n+=1
        for node in ast.walk(tree):
            if isinstance(node,ast.Subscript) and isinstance(node.value,ast.Name) and node.value.id in ('values','differences'):
                assert isinstance(node.slice,ast.Constant) and type(node.slice.value) is int;n+=1
        assert not any(isinstance(x,(ast.For,ast.While,ast.If,ast.ListComp,ast.GeneratorExp)) for x in ast.walk(tree));n+=1
    # Reconstruct an independent compact table ordering without carriers().
    # Check every remapped input in a concrete noncompact native-shaped frame.
    cap,raw=fixture(3,2,False,(False,False),None,True,rng)
    expected=[0,1,2,cap.im,cap.idx[56],cap.idx[57],cap.idx[58],cap.idx[59],cap.idx[60]]
    expected+=list(cap.i_pl)+list(cap.i_sr)+list(cap.i_sg)+[cap.imx,cap.isum]
    expected+=list(range(cap.h0,cap.h0+cap.n_help))+[cap.ihx]
    cfg,native=config(cap);assert tuple(expected)==native;n+=1
    fn,body,_,_,g,out=compile_capture(cap,True,False)
    # Wrong remapping must fail an oracle, not merely a source text compare.
    params={k:F(rng.randrange(P),rng.randrange(P)) for k in
            ['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']+['mu'+str(j) for j in range(6+cap.n_help)]}
    params['lk_cst']=tuple(F(c)+params['gu8'] for c in raw)
    const,offsets=proof_arguments(cap,params)
    v=[F(rng.randrange(P),rng.randrange(P)) for _ in range(cap.n_tabs)]
    d=[F(rng.randrange(P),rng.randrange(P)) for _ in v]
    good=fn(v,d,const,offsets)
    old=f'values[{cap.idx[56]}]';new=f'values[{cap.idx[57]}]'
    assert old in body;badbody=body.replace(old,new,1)
    scope={'F':F};exec(compile(badbody,'<intentional-remap-mutation>','exec'),scope)
    assert scope['factory'](v,d,const,offsets)!=good;n+=1
    for t in [F(),F(1),F(0,1),F(7,11)]:
        row=[x+t*y for x,y in zip(v,d)];answer=F()
        for c in reversed(good):answer=answer*t+c
        assert ref.cv(answer)==ref.groups(cap,row,params)[0];n+=1
    # Selector depends on public metadata. A pad-enabled profile with no
    # support tables still takes the original scalar implementation.
    pad,_=fixture(3,2,True,(False,False))
    assert not eligible(pad,0,True);assert not eligible(cap,1,True);n+=2
    result={'status':'pass','checks':n,'seed':2026101757001,
            'controls':{'wrong_remap':'detected','pad_rule_without_optional_supports':'scalar fallback','later_round':'scalar fallback'},
            'wall_seconds':time.perf_counter()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'scope':'CPU/source audit only; no native capture export, Rust compile, transcript, proof or verifier'}
    (HERE/'audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))


if __name__=='__main__':main()
