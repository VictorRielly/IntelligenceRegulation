#!/usr/bin/env python3
"""Independent native plane-MLE construction/fallback check, synthetic data."""
from pathlib import Path
from dataclasses import replace
from collections import Counter
import json,hashlib,random,resource,time
from field import F,P
from driver import Dense
from fixture import limits
from compact import Source,Leading,from_committed
import full_oracle as o

HERE=Path(__file__).resolve().parent
SEED=2026101344

def reference_cube(n,s,data):
    # Definition of native plane~(claim_point), independent of index maps,
    # compact readers or candidate folds. All words are synthetic.
    source=list(map(o.tup,data[s.offset:s.offset+(1<<s.log)]))
    out=[]
    for k in range(1<<n):
        bits=o.bits(k,n);point=[]
        for kind,arg in s.coords:
            point.append((bits[arg],0) if kind=='rho' else (1-bits[arg],0)
                         if kind=='flip' else arg)
        out.append(o.mul(s.coefficient,o.mle(source,point)))
    return out

def main():
    limits();start=time.perf_counter();rng=random.Random(SEED);counts=Counter();digest=hashlib.sha256()
    for n in range(5):
      for L in range(n+1):
       for mode in ('base','full','zero'):
        draw=lambda:F(rng.randrange(P),rng.randrange(P) if mode=='full' else 0) if mode!='zero' else F()
        raw=[draw() for _ in range((1<<L)+7)]
        spec=Source('SC_SZC','A_MX','A',3,(1,0),L,tuple(('rho',j) for j in range(L)),31,0)
        specs=[spec,replace(spec,plane='A_SUM'),replace(spec,coefficient=(3,5)),replace(spec,cm='H')]
        if L:
            specs.extend([replace(spec,coords=(('flip',0),)+spec.coords[1:]),
                          replace(spec,coords=(('fixed',(7,11)),)+spec.coords[1:]),
                          replace(spec,coords=(('rho',n-1),)+spec.coords[1:])])
        for s in specs:
            original=reference_cube(n,s,raw)
            fallback=lambda:Dense(n,[F(*x) for x in original])
            tab=from_committed(n,s,raw,fallback)
            assert isinstance(tab,Leading)==(s is spec or s==replace(spec,plane='A_SUM') or
                    (s.coords==spec.coords and s.coefficient==(1,0) and s.cm=='A'))
            prefix=[]
            for j in range(n+1):
                # Definitional partial MLE including free inactive axes.
                for k in range(1<<(n-j)):
                    point=prefix+[(b,0) for b in o.bits(k,n-j)]
                    expected=o.mle(original,point)
                    assert tab.at(k)==F(*expected);counts['source_cube_binding_checks']+=1
                    digest.update(F(*expected).wire())
                if j<n:
                    rho=[F(),F(1),F(3,5)][j%3];tab.bind(rho);prefix.append(o.tup(rho))
            assert tab.terminal()==F(*o.mle(original,prefix));counts['source_terminal_checks']+=1
            counts['compact_constructor_cases' if isinstance(tab,Leading) else 'exact_fallback_cases']+=1
    result=dict(status='pass',seed=SEED,counts=dict(counts),elapsed_seconds=time.perf_counter()-start,
        peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,digest_sha256=digest.hexdigest(),
        source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        limits='Direct synthetic plane-MLE definition. No native build, mask/proof/transcript or real private data. Same one-thread59s/512MiB caps.')
    (HERE/'constructor-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()
