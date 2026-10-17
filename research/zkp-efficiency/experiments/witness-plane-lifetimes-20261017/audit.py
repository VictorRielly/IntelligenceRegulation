#!/usr/bin/env python3
"""Separate arithmetic/provenance check; never imports or runs candidate code."""
from pathlib import Path
import hashlib,json,os,re,resource,signal,time

p=Path(__file__).resolve().parent
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
t=time.perf_counter(); d=json.loads((p/'result.json').read_text()); checks=0
def check(x):
 global checks
 assert x
 checks+=1

check(d['status']=='pass')
check(hashlib.sha256((p/'run.py').read_bytes()).hexdigest()==d['executed_source_sha256'])
for c in d['allocation_free_census']:
 T=c['context'];D=2048 if c['model']=='TinyLlama1.1B' else 4096;F=8192 if D==2048 else 16384
 K=256 if D==2048 else 1024;N=1<<c['log_cols'];S=32*T*T;ls=(T.bit_length()-1+9+7)//8
 # Explicit domain family equations, independent of source Ids table expansion.
 L=max(16*T,N); TD=T*D;TV=T*K;FF=T*F
 final=8*(4*T+2*32*T+2*L+35*TD+7*TD+6*TV+(7+2*ls)*max(S,N)+11*FF)
 avoided=8*(4*T+2*L+22*TD+5*TD+6*TV+2*max(S,N)+5*FF)
 check(final==c['final_plane_bytes']);check(avoided==c['avoided_initial_zero_payload_bytes'])
 check(c['ls']==ls);check(c['moved_plane_count']==46);check(c['final_plane_capacity_reduction_bytes']==0)
 check(c['three_clone_payload_bytes']==24*TD);check(c['score_support_index_bytes']==8*S)

old=(p/'native/witness.rs').read_text().splitlines(keepends=True)
target=(p/'witness-candidate.rs').read_text().splitlines(keepends=True)
patch=(p/'witness-candidate.patch').read_text().splitlines(keepends=True)
hunk=next(i for i,l in enumerate(patch) if l.startswith('@@'))
start=int(re.match(r'@@ -(\d+)',patch[hunk]).group(1))-1
out=old[:start];i=start
for line in patch[hunk+1:]:
 if line[0]==' ':
  check(old[i]==line[1:]);out.append(old[i]);i+=1
 elif line[0]=='-':check(old[i]==line[1:]);i+=1
 elif line[0]=='+':out.append(line[1:])
 else:raise AssertionError('unexpected patch format')
out+=old[i:];check(out==target)
check('unsafe' not in ''.join(line[1:] for line in patch if line.startswith('+')))
for path,h in json.loads((p/'source-manifest.json').read_text()).items():
 check(hashlib.sha256((p/'native'/Path(path).name).read_bytes()).hexdigest()==h)
 # Live drift is reported, not silently accepted as the patch baseline.
drift=[dict(path=path,baseline=h,live=hashlib.sha256(Path(path).read_bytes()).hexdigest()) for path,h in json.loads((p/'source-manifest.json').read_text()).items() if hashlib.sha256(Path(path).read_bytes()).hexdigest()!=h]
for r in d['retained_owner_samples']:
 for name,h in r['source_pins'].items():check(hashlib.sha256((p/'retained'/(r['name']+'__'+name)).read_bytes()).hexdigest()==h)
 check(r['passes']==1 and r['blocks']==22)
 check(abs(r['diagnostic_positions_per_second']*r['total_wall_s']-r['context'])<1e-10)
 check(r['steady_rate'] is None and r['startup_fraction'] is None and r['serialization_s'] is None)
 check(r['proof_including_sink_excluding_witness_s']>r['witness_and_extraction_s'])
out=dict(status='pass',checks=checks,live_source_drift=drift,wall_seconds=time.perf_counter()-t,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,scope='independent integer census, single-hunk patch reconstruction and retained source/log provenance; no native compile or verify')
(p/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
