"""Native constructor push-order model, independent of adapter carrier map.

No native constructor executed. Registered captures are not exported here:
this model is checked against pinned source constants and push-order markers.
Relocated frames and lp3 are synthetic robustness fixtures, not native profiles.
"""
from dataclasses import replace
from adapter import Capture


def fixture(ls=3,lp=2,pad_on=False,supports=(False,False),subset=None,relocate=False,rng=None):
    if not pad_on and any(supports):raise ValueError('support without pad rule')
    if ls<2 or lp<2:raise ValueError('shorter than toy')
    # Four norm groups remain LN_TOY=4; S grows at PL, SR and SG only.
    shaped_s8=56;shaped_pl=61;shaped_sr=61+lp;shaped_sg=61+lp+ls
    shaped=[None]*(81+lp-2+2*(ls-2))
    table=4  # Eq0,Eq1,Eq2,public causal mask
    for plane in range(shaped_s8,shaped_sg+ls):shaped[plane]=table;table+=1
    idx=[None]*81
    for toy in range(56,61):idx[toy]=shaped[toy]
    for j in range(2):
        idx[61+j]=shaped[shaped_pl+j]
        idx[63+j]=shaped[shaped_sr+j]
        idx[65+j]=shaped[shaped_sg+j]
    pl=tuple(shaped[shaped_pl+j] for j in range(lp))
    sr=tuple(shaped[shaped_sr+j] for j in range(ls))
    sg=tuple(shaped[shaped_sg+j] for j in range(ls))
    imx,isum=table,table+1;table+=2
    pscale=1<<(8*lp-10);sscale=1<<(8*ls-(15 if ls==2 else 18))
    # lookups_at uses SHAPED ids, resolved through B.shaped, never idx.
    raw=[(56,1,127),(56,-1,127),(57,1,0),(57,4,0)]
    raw += [(shaped_pl+j,1,0) for j in range(lp)]+[(shaped_pl+lp-1,pscale,0)]
    raw += [(shaped_sr+j,1,0) for j in range(ls)]+[(shaped_sr+ls-1,sscale,0)]
    raw += [(shaped_sg+j,1,0) for j in range(ls)]+[(shaped_sg+ls-1,sscale,0)]
    if subset is not None:raw=raw[:subset]
    lookups=tuple(((shaped[p],c),) for p,c,_ in raw)
    n_help=(len(raw)+1)//2;h0=table;table+=n_help;ihx=table;table+=1
    ght=table if supports[0] else None;table+=int(supports[0])
    gs=table if supports[1] else None;table+=int(supports[1])
    splanes=tuple(shaped[p] for p in range(shaped_s8,shaped_sg+ls) if p!=59)
    cap=Capture(tuple(idx),3,imx,isum,ihx,h0,sr,sg,pl,lookups,n_help,gs,ght,pad_on,splanes,table)
    if relocate:
        # Preserve Eq coordinates and contiguous helpers. Relocate all other
        # carriers bijectively; unused sentinels exercise noncompact frames.
        new_size=table+7;pool=list(range(3,new_size-n_help));rng.shuffle(pool)
        old=[i for i in range(3,table) if not h0<=i<h0+n_help]
        perm=dict(zip(old,pool));perm.update({i:i for i in range(3)})
        perm.update({h0+j:new_size-n_help+j for j in range(n_help)})
        r=lambda i:None if i is None else perm[i]
        cap=Capture(tuple(r(i) for i in cap.idx),r(cap.im),r(cap.imx),r(cap.isum),r(cap.ihx),r(cap.h0),
                    tuple(r(i) for i in sr),tuple(r(i) for i in sg),tuple(r(i) for i in pl),
                    tuple(tuple((r(i),c) for i,c in term) for term in lookups),n_help,r(gs),r(ght),pad_on,
                    tuple(r(i) for i in splanes),new_size)
    return cap,tuple(c for _,_,c in raw)
