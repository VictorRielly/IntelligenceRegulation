#!/usr/bin/env python3
"""Independent fallback check: the grouped bracket ACTUALLY reads Eq."""
import random,time,json,hashlib,resource
from pathlib import Path
from field import F,P
from driver import Tables,Dense,interpolate
from grouped import Group,Grouped
from equality import Equality,derive
from fixture import limits,original_partial
import full_oracle as o

def main():
    limits();start=time.perf_counter();rng=random.Random(2026101345);counts={k:0 for k in ('fixtures','round_samples','ordered_finals','actual_claims','used_eq_not_elided','generic_total_checks')}
    pin=hashlib.sha256((Path(__file__).parent/'native/hashline__src__private_block__argument.rs').read_bytes()).hexdigest()
    for n in range(5):
        for mode in ('full','zero','boolean'):
            draw=lambda:F(rng.randrange(P),rng.randrange(P)) if mode=='full' else F() if mode=='zero' else F(rng.randrange(2))
            point=[draw() for _ in range(n)];rs=[draw() for _ in range(n)]
            aa=[draw() for _ in range(1<<n)];bb=[draw() for _ in aa]
            ee=[o.eq(list(map(o.tup,point)),[(b,0) for b in o.bits(i,n)]) for i in range(1<<n)]
            original=[list(map(o.tup,aa)),ee,list(map(o.tup,bb))]
            entries=[('a',True,Dense(n,aa)),('eq',False,Equality(n,point)),('b',True,Dense(n,bb))]
            terms=[[(F(1),(0,1)),(F(1),(2,))]];deps=derive(entries,terms,pin)
            assert deps.unused==();counts['used_eq_not_elided']+=1
            bracket=lambda g,v:v[0]*v[1]+v[2]
            tabs=Tables(n,entries);ev=Grouped(tabs,3,[Group(point,0,2)],bracket,3,True,deps)
            def literal(values):return o.mul(values[1],o.add(o.mul(values[0],values[1]),values[2]))
            total=o.Z
            for vals in zip(*original):total=o.add(total,literal(vals))
            assert tabs.total(lambda v:v[1]*bracket(0,v))==F(*total);counts['generic_total_checks']+=1
            prefix=[]
            for j,r in enumerate(rs):
                expected=[]
                for x in range(5):
                    vals=original_partial(original,prefix+[(x,0)],n);value=o.Z
                    for row in zip(*vals):value=o.add(value,literal(row))
                    expected.append(F(*value))
                actual=ev.round(j);assert actual==expected[:4]
                assert interpolate(actual,F(4))==expected[4];counts['round_samples']+=5
                ev.bind(r);assert ev.claims[0]==interpolate(expected[:4],r);counts['actual_claims']+=1
                prefix.append(o.tup(r))
            assert ev.finals()==[F(*o.mle(a,prefix)) for a in original];counts['ordered_finals']+=3;counts['fixtures']+=1
    result=dict(status='pass',seed=2026101345,counts=counts,elapsed_seconds=time.perf_counter()-start,
      peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
      source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),limits='One thread59s/512MiB. Synthetic Eq-dependent bracket; no native/masked proof.')
    (Path(__file__).parent/'fallback-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()
