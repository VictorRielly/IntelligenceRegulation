"""Independent scalar-prime field cube audit and artifact integrity checks."""
from pathlib import Path
from dataclasses import replace
import ast,hashlib,json,os,random,resource,signal,time
from selector import MaskLayout,dependency,round0_mask_active,mask_mle
HERE=Path(__file__).resolve().parent
P=18446744069414584321
SEED=2026101758001


class B:
    # Independent scalar-only field; no F/Fp2/reference/generator import.
    def __init__(self,v=0):self.v=v%P
    def __add__(self,x):return B(self.v+x.v)
    def __sub__(self,x):return B(self.v-x.v)
    def __mul__(self,x):return B(self.v*x.v)


def direct(lay,point,e):
    ans=0;t=lay.token_extent;n=lay.main_rounds
    for i in range(lay.head_slots*t*t):
        if i%t>(i//t)%t:continue
        w=1
        for k,x in enumerate(point):
            b=(i>>(n-k-1))&1
            w=w*(x if b else 1-x)%P
        ans=(ans+w)%P
    return ans*(1-e)%P


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    started=time.perf_counter();rng=random.Random(SEED);checks=0
    for h in (1,2,4):
        for t in (1,2,4,8):
            n=h.bit_length()-1+2*(t.bit_length()-1)
            lay=MaskLayout(h,t,h,t,n)
            for i in range(h*t*t):
                point=[B((i>>(n-k-1))&1) for k in range(n)]
                for e in (0,1):
                    got=mask_mle(lay,point,[B(e)],B(1)).v
                    assert got==int(i%t<=(i//t)%t)*(1-e);checks+=1
            for _ in range(9):
                point=[rng.randrange(P) for _ in range(n)];e=rng.randrange(P)
                got=mask_mle(lay,[B(x) for x in point],[B(e)],B(1)).v
                assert got==direct(lay,point,e);checks+=1
                for k,active in enumerate(dependency(lay)[:n]):
                    if not active:
                        changed=point[:];changed[k]=rng.randrange(P)
                        assert direct(lay,changed,e)==got;checks+=1
    base=MaskLayout(2,4,2,4,5)
    for delta in [{'head_slots':True},{'true_tokens':True},{'main_rounds':True},
                  {'extension_rounds':True},{'axes':('head','j','t')}]:
        assert dependency(replace(base,**delta)) is None;checks+=1
    assert round0_mask_active(base,False) is False;checks+=1
    assert round0_mask_active(base,False,True) is None;checks+=1
    # Confirm descriptor has no source of witness/challenge-driven dispatch.
    tree=ast.parse((HERE/'selector.py').read_text())
    fn=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='dependency')
    assert [x.arg for x in fn.args.args]==['layout'];checks+=1
    fn=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='round0_mask_active')
    assert [x.arg for x in fn.args.args]==['layout','pad_on','round_index'];checks+=1
    for pin in json.loads((HERE/'native-pins.json').read_text()):
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
    result=json.loads((HERE/'result.json').read_text());assert result['status']=='pass';checks+=1
    assert result['proof_accounting']['tokens']==0;checks+=1
    execution=json.loads((HERE/'execution.json').read_text());assert execution['exit_code']==0;checks+=1
    assert hashlib.sha256((HERE/'run.log').read_bytes()).hexdigest()==execution['log_sha256'];checks+=1
    out={'status':'pass','seed':SEED,'checks':checks,'wall_seconds':time.perf_counter()-started,
         'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
         'threads':1,'gpu':None,'scope':'Independent base-prime Boolean/offdomain original-cube audit, no native proof',
         'limits':{'wall_seconds':59,'memory_mib':512,'estimated_memory_mib':32}}
    (HERE/'audit.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))


if __name__=='__main__':main()
