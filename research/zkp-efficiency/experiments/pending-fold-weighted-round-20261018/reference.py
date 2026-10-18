"""Synthetic one-thread parity, not a proof benchmark. No downloaded code executed."""
from pathlib import Path
import ctypes as C,datetime,hashlib,json,os,platform,random,resource,signal,subprocess,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
START=time.perf_counter();SEED=2026101871;rng=random.Random(SEED)
P=2**64-2**32+1;Z=(0,0);O=(1,0)
def add(a,b):return((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):return((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):return((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def prod(xs):
 v=O
 for x in xs:v=mul(v,x)
 return v
def total(xs):
 v=Z
 for x in xs:v=add(v,x)
 return v
def rnd():return(rng.randrange(P),rng.randrange(P))
def weight(i,r):return prod(x if i>>(len(r)-1-j)&1 else sub(O,x) for j,x in enumerate(r))
def evaluate(v,r):return total(mul(x,weight(i,r))for i,x in enumerate(v))
def dense(tables,r):
 ts=[list(t)for t in tables];out=[]
 for x in r:
  half=len(ts[0])//2
  out.append([total(prod(add(t[i],mul((j,0),sub(t[i+half],t[i])))for t in ts)for i in range(half))for j in range(4)])
  ts=[[add(t[i],mul(x,sub(t[i+half],t[i])))for i in range(half)]for t in ts]
 return out,[t[0]for t in ts]
def interpolate(v,r):
 ans=Z
 for i,x in enumerate(v):
  num=O;den=1
  for j in range(len(v)):
   if i!=j:num=mul(num,sub(r,(j,0)));den=den*(i-j)%P
  ans=add(ans,mul(x,mul(num,(pow(den,-1,P),0))))
 return ans
