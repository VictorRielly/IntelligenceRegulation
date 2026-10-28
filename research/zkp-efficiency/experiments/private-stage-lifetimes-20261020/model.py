"""Private-run live-owner accounting. Source schedule, not a CUDA runtime trace.

No real model values, random masks, receipts, native shape constructors or
GPU code run. Public requested storage is counted with integers only.
"""
import hashlib,json,os,pathlib,platform,random,re,resource,time
H=pathlib.Path(__file__).resolve().parent
SEED=2026102094
def dump(n,v): (H/n).write_text(json.dumps(v,indent=2,sort_keys=True)+'\n')
def source(tree,name): return (H/'source'/(tree+'__'+name.replace('/','__'))).read_text()
def body(s,marker):
 start=s.index(marker); brace=s.index('{',start); depth=1; i=brace+1
 # Only called on functions without braces in strings/comments preceding
 # their final brace; production extraction is independently bounded below.
 while depth:
  if s[i]=='{':depth+=1
  elif s[i]=='}':depth-=1
  i+=1
 return s[start:i]
def pin_extra():
 P=H.parents[3]
 paths=[P/'ops/zkp-mvp/gpu-zerocheck/zkp-core/src/pcs.rs',P/'results/zk60_1b_native_20261017/r9/r9_counts.json',P/'results/zk60_1b_native_20261017/r9/r9_counts.py']
 out=[]
 for p in paths:
  b=p.read_bytes(); n='extra__'+p.name; (H/'source'/n).write_bytes(b)
  out.append(dict(path=str(p),snapshot=n,sha256=hashlib.sha256(b).hexdigest()))
 dump('extra-source-manifest.json',out)
def source_facts(tree):
 run=source(tree,'private_block/run.rs'); pro=source(tree,'private_block/protocol.rs'); bnd=source(tree,'private_block/boundary.rs'); zk=source(tree,'zk.rs'); cuda=source(tree,'gpu/cuda.rs')
 specs=[('run','endpoints','let [ein, eout] = protocol::check_endpoints'),('run','boundary_create','let p = boundary::prepare('),('run','core','protocol::prove_core(sh,'),('run','incoming','let in_open = match prev.take()'),('run','boundary_open','owner.into_opening('),('run','outgoing','let out_open = if k + 1 == l'),('run','encode','let bytes = wire::encode_segment'),('run','sink','sink(k, bytes)?;'),('run','handover','prev = cur;'),('protocol','A','let mut a = pcs::commit_zk_owned_tagged'),('protocol','M','let mc = zk::mask_commit_tagged'),('protocol','H','let mut h = pcs::commit_zk_owned_tagged'),('protocol','slots','let acc = argument(&mut side'),('protocol','open_M','let mask_open = zk::mask_open'),('protocol','drop_M','drop(mc);'),('protocol','open_A','let a_open = pcs::open_zk'),('protocol','drop_A','drop(a);'),('protocol','open_H','let h_open = pcs::open_zk'),('protocol','drop_H','drop(h);')]
 out=[]
 for file,key,anchor in specs:
  s=run.split('/// **THE RUN VERIFIER,')[0] if file=='run' else pro.split('// ---------------------------------------------------------------- verifier')[0]
  if key=='core': anchor='protocol::prove_core('
  assert s.count(anchor)==1,(tree,key,s.count(anchor))
  pos=s.index(anchor); out.append(dict(key=key,file=file,anchor=anchor,line=s[:pos].count('\n')+1))
 positions={x['key']:x['line'] for x in out}
 for keys in [('endpoints','boundary_create','core','incoming','outgoing','encode','sink','handover'),('A','M','H','slots','open_M','drop_M','open_A','drop_A','open_H','drop_H')]:
  assert [positions[k] for k in keys]==sorted(positions[k] for k in keys)
 assert 'fn into_opening(self,' in bnd and 'claims.extend(ic);' in run
 assert 'data: [a.data.as_slice(), h.data.as_slice(), io_data[0], io_data[1]]' in pro
 mask=zk.split('pub fn mask_commit_tagged(')[1].split('/// The combined weight')[0]
 assert 'pcs::hash_columns_keyed(&encoded' in mask
 assert 'MaskCommit { specs:' in mask and 'crate::gpu' not in mask and 'dev_commit' not in mask
 assert 'pub encoded: Vec<Fp>' in zk and 'pub(super) enc: Option<Pooled>' in cuda
 assert 'impl Drop for Pooled' in cuda and 'pool_put(b);' in cuda
 return out
def trace(blocks):
 """Forward source-order simulator, one logical owner per commitment."""
 events=[]
 def e(op,obj,stage=-1,**kw): events.append(dict(op=op,obj=obj,stage=stage,**kw))
 e('create','IN'); e('create','OUT')
 for k in range(blocks):
  incoming='IN' if k==0 else f'B{k-1}'
  outgoing='OUT' if k==blocks-1 else f'B{k}'
  if k+1<blocks:e('create',outgoing,k)
  for role in ['A','M','H']:e('create',f'{role}{k}',k)
  for owner in [f'A{k}',f'M{k}',f'H{k}',incoming,outgoing]:e('read',owner,k)
  e('claim',incoming,k,side='consumer'); e('claim',outgoing,k,side='producer')
  for role in ['M','A','H']:
   e('open',f'{role}{k}',k);e('drop',f'{role}{k}',k)
  e('open',incoming,k);e('drop',incoming,k)
  if k+1==blocks:e('open','OUT',k);e('drop','OUT',k)
  e('serialize',f'segment{k}',k);e('sink',f'segment{k}',k)
 return events
def rows(T,logn,fe=9):
 # Algebraic count independently checked against source families in audit.py.
 n=1<<logn; ls=((T-1).bit_length()+fe+7)//8; ln=4; lp=2
 sizes={'T':T,'Ht':32*T,'L':max(n,16*T),'D':T*4096,'Q':T*32*128,'Kv':T*8*128,'S':32*T*T,'F':T*16384,'Tab':n}
 a={'T':4,'Ht':2,'L':2,'D':19+4*ln,'Q':7,'Kv':6,'S':5+lp+2*ls,'F':11,'Tab':3}
 u={'L':2,'D':34,'Q':13,'Kv':12,'S':4+lp+1+2*(ls+1),'F':9}
 helpers={d:(v+1)//2 for d,v in u.items()}
 h=dict(helpers); h['S']+=1;h['F']+=1;h['Tab']=4
 a_sites=1+1+22+2+2+7+2+2+(a['D']+2)+(a['Q']+1)+(a['Kv']+1)+(a['S']+2)+a['F']+3+2
 h_sites=helpers['L']+helpers['D']+helpers['Q']+helpers['Kv']+h['S']+h['F']+3+1
 ar=sum(v*max(1,sizes[d]//n) for d,v in a.items())+2*a_sites+2
 hr=sum(2*v*max(1,sizes[d]//n) for d,v in h.items())+2*h_sites+2
 dr=T*4096//n
 return dict(T=T,log_cols=logn,n=n,q=256,rate=4,A=ar,H=hr,E=dr+5,B=dr+7,M=50,mask_encoded_n=4096)
def owner_bytes(role,g,mode):
 """Requested persistent bytes, excludes transient/scratch/allocator capacity."""
 if role=='M':return dict(host_encoded=50*4096*8,device_pooled=0,device_raw=0,host_data=0)
 rr=g[role];n=g['n'];q=g['q'];nn=n*g['rate']
 return dict(host_data=rr*n*8,host_encoded=0,device_pooled=rr*n*8+(rr*nn*8 if mode=='resident' else 0),device_raw=(rr*q+nn)*8 if mode=='chunked' else 0)
def capacity(events,g,mode,offload=False):
 live={};out=[];off=False
 for i,e in enumerate(events):
  if e['op']=='create':
   obj=e['obj'];role=obj[0] if obj.startswith(('A','H','B','M')) else 'E'
   live[obj]=owner_bytes(role,g,mode)
   # Speculative output-only device eviction after both endpoints sealed.
   if obj=='OUT' and offload:off=True
  if e['op']=='open' and e['obj']=='OUT' and offload:off=False
  if e['op']=='drop':del live[e['obj']]
  totals={key:sum(b[key] for b in live.values()) for key in ['device_pooled','device_raw','host_data','host_encoded']}
  if off and 'OUT' in live:
   for key in ['device_pooled','device_raw']:totals[key]-=live['OUT'][key]
  out.append(dict(event=i,stage=e['stage'],op=e['op'],obj=e['obj'],live=sorted(live),**totals,device_total=totals['device_pooled']+totals['device_raw']))
 return out
def main():
 t=time.perf_counter();pin_extra()
 facts={tree:source_facts(tree) for tree in ['gpu','r8']};dump('source-facts.json',facts)
 traces={str(b):trace(b) for b in [1,2,3,4,8,32]};dump('events.json',traces)
 results=[]
 for T,lc in [(32,13),(64,13),(128,14)]:
  g=rows(T,lc)
  for b in [1,2,3,4,8,32]:
   for mode in ['resident','chunked']:
    baseline=capacity(traces[str(b)],g,mode);candidate=capacity(traces[str(b)],g,mode,True)
    peak=max(x['device_total'] for x in baseline);new_peak=max(x['device_total'] for x in candidate)
    pe=[x for x in baseline if x['device_total']==peak]
    eb=owner_bytes('E',g,mode)
    results.append(dict(geometry=g,blocks=b,storage=mode,persistent_owner_peak_bytes=peak,output_evicted_peak_bytes=new_peak,output_evicted_peak_saving_bytes=peak-new_peak,output_saved_fraction=(peak-new_peak)/peak,peak_events=pe,output_restore_persistent_bytes=eb['device_pooled']+eb['device_raw'],output_returned_idle_pooled_bytes=eb['device_pooled'],output_direct_raw_free_bytes=eb['device_raw'],output_pooled_backing_released_by_drop_bytes=0,release_only_saving_bytes=0,limits='Hypothetical all-device owners; not observed residency. No transient commit/open scratch, pool idle/oversizing, twiddles, FZC cache, private witness/host masks/proof vectors or driver included. Output offload has no native implementation; initial seal transient omitted. Returning Pooled storage to idle does not free backing; further reuse/free required.'))
 dump('capacity.json',results)
 result=dict(status='GENERATED',seed=SEED,traces=len(traces),capacity_cases=len(results),source_trees=list(facts),wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),device='CPU only',cpu=next(x.split(':',1)[1].strip() for x in pathlib.Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),scope='Source-derived dependency and requested persistent-owner count; no native/GPU/full proof',full_stack=dict(independently_verified_proofs=0,positions=0,passes=0,context_length=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,steady_positions_per_s=None,total_positions_per_s=None,startup_fraction=None))
 dump('model-result.json',result);print(json.dumps(result))
if __name__=='__main__':main()
