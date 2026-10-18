"""Check the offline adapter does not use unknown future transcript challenges."""
from pathlib import Path
import ctypes as C,datetime,json,os,resource,signal,time
H=Path(__file__).resolve().parent;os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();U=C.c_uint64;S=C.c_size_t;P=2**64-2**32+1
lib=C.CDLL(str(H/'isolated.so'));lib.factorized.argtypes=[S,S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),C.POINTER(S)]
def pack(v):return(U*(2*len(v)))(*(x for p in v for x in p))
def call(f,r):
 v=f['values'];p=[x for row in f['initial_points']for x in row];c=f['column_point'];out=(U*(2*(4*len(r)+3)))();ns=(S*3)()
 assert lib.factorized(f['rows'],f['columns'],pack(v),len(v),pack(p),len(p),pack(c),len(c),pack(r),len(r),out,ns)==0
 return[list(out[8*j:8*j+8])for j in range(len(r))]
fs=json.loads((H/'fixtures.json').read_text());checks=0;controls=0
for f in fs:
 r=f['challenges'];base=call(f,r)
 for j in range(len(r)):
  changed=[p[:]for p in r]
  for i in range(j,len(r)):changed[i]=[(changed[i][0]+1)%P,changed[i][1]]
  assert call(f,changed)[:j+1]==base[:j+1];checks+=j+1
 # A nondegenerate fixture must react to an already known challenge.
 if f['tag']=='controls-N4-C3':
  changed=[p[:]for p in r];changed[0]=[(changed[0][0]+1)%P,changed[0][1]]
  assert call(f,changed)[1:]!=base[1:];controls+=1
out=dict(status='PASS',fixtures=len(fs),unchanged_prior_round_checks=checks,past_challenge_sensitivity_controls=controls,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,scope='Offline arithmetic challenge causality only; native interactive adapter/transcript not implemented.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'causality-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
