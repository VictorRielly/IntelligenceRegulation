from pathlib import Path
import json,math,hashlib,platform,subprocess
D=Path(__file__).resolve().parent
prior=D.parent/'composition-eq-scope-20261029'
rows=json.loads((prior/'sized-metadata.json').read_text());out=[];checks=0
for x in rows:
 R=x['rows'];N=1<<x['log_cols'];K=x['groups']+1
 cases=[]
 for B in [1,2,4,8]:
  chunks=[min(B,K-i)for i in range(0,K,B)]
  # Two independently expressed accounting routes, no large matrix allocated.
  passes=math.ceil(K/B);matrix=passes*R*N*8
  h2d=K*R*16;d2h=K*N*16
  assert matrix==sum(R*N*8 for _ in chunks)
  assert h2d==sum(k*R*16 for k in chunks)
  assert d2h==sum(k*N*16 for k in chunks)
  cases.append(dict(batch=B,dispatch_supported=B<=4,full_matrix_passes=passes,logical_base_matrix_bytes=matrix,rho_h2d_bytes=h2d,output_d2h_bytes=d2h,largest_device_rho_plus_output_bytes=min(B,K)*(R+N)*16,fp2_base_macs=K*R*N,host_and_device_allocs_per_call_at_least=dict(flat_host=1,rho_device=1,out_device=1,download_host=1)))
  checks+=3
 assert len({x['rho_h2d_bytes']for x in cases})==1
 assert len({x['output_d2h_bytes']for x in cases})==1
 checks+=2
 out.append(dict(label=x['label'],profile=x['source_profile'],rows=R,cols=N,groups_excluding_proximity=K-1,rhos=K,cases=cases,scope='Prior source-derived R13 8BT128 descriptor/row counts; support unknown; no private matrix allocated. R14 split-width geometry is distinct.'))
r=json.loads((D/'result.json').read_text())
study=[]
names=['dense','all-zero algebra-only','disjoint row supports','interleaved25percent','disjoint plus dense proximity','last-row-only','first-row-only','random one-eighth']
for x in r['studies']:
 R,N,K=257,17,37;B=x['batch'];dense=math.ceil(K/B)*R*N
 # Independent explicit bitset unions, except stochastic case uses probe counts.
 if x['mode']!=7:
  sets=[]
  for g in range(K):
   sets.append(set(i for i in range(R)if [True,False,i%K==g,(i+g)%4==0,g==K-1 or i%K==g,i==R-1,i==0][x['mode']]))
  loads=sum(len(set().union(*sets[i:i+B]))for i in range(0,K,B))*N
  macs=sum(map(len,sets))*N
  assert loads==x['candidate_data_loads'];assert macs==x['candidate_fp2_base_macs'];checks+=2
 assert x['baseline_data_loads']==dense;checks+=1
 study.append(dict(**x,name=names[x['mode']],data_load_reduction=1-x['candidate_data_loads']/dense,mac_reduction=1-x['candidate_fp2_base_macs']/x['baseline_fp2_base_macs']))
stats=(D/'native/hashline/src/gpu/cuda.rs').read_text();start=stats.index('pub fn dev_fold_rows(');end=stats.index('\n}\n',start)+3;body=stats[start:end]
assert 'htod_sync_copy(&flat)'in body and 'bytes_d2h +='in body and 'bytes_h2d +='not in body;checks+=1
meta=dict(status='PASS',checks=checks,profile_accounting=out,synthetic_support_studies=study,
 limits=['All counts are source logical loads/MACs, not physical DRAM,cache,warp-broadcast,compiled register,allocation peak or time measurements.','No support census from an actual native invocation exists here; no synthetic distribution is adopted as a real profile saving.','Host fold already skips zero row weights; candidate kernel directly affects device store only.','Pads are folded on host and every output vector/transfer/private mask retained.','Batch8 is counterfactual: chunks(4),FR_MAX_K4 and adaptermax4 must all change coherently; current adapter rejects5..8.'],
 telemetry_finding='dev_fold_rows explicitly uploads rho but adds only output bytes_d2h to aggregate GPU counters; rho_h2d is missing from that local stats update. secs_fold encloses upload/allocate/launch/download/conversion, not a kernel-only timer.',
 added_costs='Public zero tests/warp-uniform control and FR_MAX_K temporary Fp2 row weights. AtB4 source live acc+rw payload128B/thread versus64B acc baseline; physical registers/spills unknown. No persistent cache. Batch8 doubles these payloads again.',
 ceiling='Npositions/(Tworkload-Cremoved_exclusive+Aadded); exclusive native fold fraction f unknown. Free deletion bound1/(1-f). No whole8B tok/s forecast.',
 full_stack_proofs=0,model_passes=0,proved_positions=0)
(D/'account-result.json').write_text(json.dumps(meta,indent=2)+'\n')
cpu='unknown'
for line in Path('/proc/cpuinfo').read_text().splitlines():
 if line.startswith('model name'):cpu=line.split(':',1)[1].strip();break
(D/'hardware.json').write_text(json.dumps(dict(cpu=cpu,worker_threads=1,os=platform.platform(),python=platform.python_version(),rustc=subprocess.check_output(['/usr/bin/rustc','--version'],text=True).strip(),gxx=subprocess.check_output(['/usr/bin/g++','--version'],text=True).splitlines()[0],gpu_jobs=False,actual_model_context=None,model_passes=0),indent=2)+'\n')
for name in ['sized-metadata.json','native/NATIVE_LAYOUT_CENSUS.json']:
 p=prior/name;b=p.read_bytes();q=D/'prior'/name;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
(D/'prior-pins.json').write_text(json.dumps([dict(path=str((prior/n).resolve()),snapshot='prior/'+n,sha256=hashlib.sha256((prior/n).read_bytes()).hexdigest())for n in ['sized-metadata.json','native/NATIVE_LAYOUT_CENSUS.json']],indent=2)+'\n')
print(json.dumps(dict(status='PASS',checks=checks,modeled_core_blocks=2,explicit_rho_h2d_missing_in_local_stats=True)))
for mode in ['nonDD','DD']:
 pair=[x for x in out if x['label'].startswith(mode+'-')]
 print(mode,{B:sum(next(c for c in x['cases']if c['batch']==B)['logical_base_matrix_bytes']for x in pair)for B in [1,2,4,8]})
