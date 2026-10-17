"""Serial model of native k_ntt_p1 and ntt_p2_body<true> indexing.

No CUDA launches, shared-memory race/sync model or pruned-open kernel validation.
"""
from arithmetic import P, root, stage_mul, candidate_mul


def transform(source, log_n, inverse=False):
    n = 1 << log_n
    assert len(source) <= n and 1 <= log_n <= 24
    lb = min(12, log_n)
    bs = 1 << lb
    stage_tw = {}
    for st in range(1,log_n+1):
        w=root(st)
        if inverse:w=pow(w,P-2,P)
        ts=[1]
        for _ in range((1<<(st-1))-1):ts.append(ts[-1]*w%P)
        stage_tw[st]=ts
    out=[0]*n
    scale=pow(n,P-2,P) if inverse else 1
    for blk in range(n//bs):
        sh=[]
        for q in range(bs):
            x=blk*bs+q
            r=int(f'{x:0{log_n}b}'[::-1],2)
            sh.append(source[r] if r<len(source) else 0)
        for st in range(1,lb+1):
            half=1<<(st-1)
            for b in range(bs//2):
                k=b&(half-1);i=((b>>(st-1))<<st)+k
                u=sh[i];v=stage_mul(sh[i+half],stage_tw[st][k],st,k,inverse)
                sh[i]=(u+v)%P;sh[i+half]=(u-v)%P
        if log_n<=12:sh=[candidate_mul(v,scale) for v in sh]
        out[blk*bs:(blk+1)*bs]=sh
    if log_n>12:
        lt=log_n-12;nt=1<<lt;lj=12-lt;J=4096>>lt
        for tile in range(nt):
            j0=tile*J
            sh=[out[(q>>lj)*4096+j0+(q&(J-1))] for q in range(4096)]
            for st in range(13,log_n+1):
                hs=st-1-12;halft=1<<hs
                for b in range(2048):
                    jj=b&(J-1);tb=b>>lj;tl=tb&(halft-1)
                    t=((tb>>hs)<<(hs+1))+tl;k=tl*4096+j0+jj
                    i=t*J+jj;ip=i+halft*J
                    u=sh[i];v=stage_mul(sh[ip],stage_tw[st][k],st,k,inverse)
                    sh[i]=(u+v)%P;sh[ip]=(u-v)%P
            for q in range(4096):
                out[(q>>lj)*4096+j0+(q&(J-1))]=candidate_mul(sh[q],scale)
    return out
