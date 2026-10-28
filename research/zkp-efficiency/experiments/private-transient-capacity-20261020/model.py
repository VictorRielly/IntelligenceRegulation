"""Public shape allocation schedule; no native/CUDA/proof work.

Numbers model selected commitment + slot18 allocations only. R8 geometry
is applied to the separately pinned GPU allocator as a hypothetical study.
Not all source paths are measured as resident in an actual trained proof.
"""
from pathlib import Path
import json,os,time,resource,hashlib
H=Path(__file__).resolve().parent
SEED=2026102095

def dump(n,v): (H/n).write_text(json.dumps(v,indent=2,sort_keys=True)+'\n')

class Trace:
 def __init__(self):
  self.idle=[];self.live={};self.backing={};self.events=[];self.serial=0
 def snap(self,op,name,bid,requested=0,capacity=0,kind='',phase='',**kw):
  lp=sum(v['capacity'] for v in self.live.values() if v['kind']=='pooled')
  lr=sum(v['capacity'] for v in self.live.values() if v['kind']=='raw')
  ip=sum(self.backing[i] for i in self.idle)
  self.events.append(dict(op=op,name=name,id=bid,requested=requested,capacity=capacity,kind=kind,phase=phase,live_pooled=lp,live_raw=lr,idle_pooled=ip,backing_bytes=lp+lr+ip,requested_live=sum(v['requested'] for v in self.live.values()),**kw))
 def take(self,name,size,kind='pooled',minimum=False,phase=''):
  assert name not in self.live and size>0
  idx=[i for i,bid in enumerate(self.idle) if self.backing[bid]>=size] if minimum else [i for i,bid in enumerate(self.idle) if self.backing[bid]==size]
  if kind=='pooled' and idx:
   at=min(idx,key=lambda i:self.backing[self.idle[i]]) if minimum else idx[0]
   bid=self.idle[at];self.idle[at]=self.idle[-1];self.idle.pop();cap=self.backing[bid];op='reuse'
  else:
   self.serial+=1;bid=self.serial;cap=size;op='alloc'
   if kind=='pooled':self.backing[bid]=cap
  self.live[name]=dict(id=bid,requested=size,capacity=cap,kind=kind)
  self.snap(op,name,bid,size,cap,kind,phase,minimum=minimum)
 def drop(self,name,phase=''):
  v=self.live.pop(name);bid=v['id'];op='free'
  if v['kind']=='pooled' and len(self.idle)<64:
   self.idle.append(bid);op='return'
  elif v['kind']=='pooled':del self.backing[bid]
  self.snap(op,name,bid,v['requested'],v['capacity'],v['kind'],phase)
 def mark(self,phase):self.snap('mark','',0,phase=phase)

def persistent(tr,name,rows,n,q,mode):
 tr.take(name+'.data',rows*n*8,phase='seed owners')
 if mode=='resident':tr.take(name+'.enc',rows*4*n*8,phase='seed owners')
 else:
  tr.take(name+'.pads',rows*q*8,'raw',phase='seed owners');tr.take(name+'.pows',4*n*8,'raw',phase='seed owners')

def commit(tr,name,rows,n,q,mode,compact):
 nn=4*n;ph=name+' commit';tr.take(name+'.data',rows*n*8,phase=ph)
 tr.take(name+'.pads',rows*q*8,'raw',phase=ph);tr.take(name+'.pows',nn*8,'raw',phase=ph)
 if mode=='resident':
  tr.take(name+'.coef',rows*n*8,phase=ph)
  tr.take(name+'.coef2',rows*nn*8,phase=ph)
  tr.mark(ph+' pad');tr.drop(name+'.coef',ph)
  tr.take(name+'.enc',rows*nn*8,phase=ph)
  tr.mark(ph+' expand');tr.drop(name+'.coef2',ph)
 else:
  rc=min(rows,128);pw=n+q if compact else nn
  for suffix,size in [('coef',rc*n*8),('coef2',rc*pw*8),('encscratch',rc*nn*8),('state',((193*nn+1)//2)*8)]:
   tr.take(name+'.'+suffix,size,minimum=True,phase=ph)
 tr.take(name+'.leaves',nn*32,'raw',phase=ph+' hash')
 tr.take(name+'.key',32,'raw',phase=ph+' hash');tr.mark(ph+' hash')
 tr.drop(name+'.key',ph);tr.drop(name+'.leaves',ph)
 if mode=='resident':tr.drop(name+'.pows',ph);tr.drop(name+'.pads',ph)
 else:
  for suffix in ['state','encscratch','coef2','coef']:tr.drop(name+'.'+suffix,ph)
 tr.mark(ph+' done')

def fzc(tr,T,supp,split=True,raw=True,packed=False):
 # All A/H sources resident; three full-domain Eq tables. Parameter and
 # per-round buffers included, device occupancy remains a free parameter.
 assert not packed or (raw and split), 'mixed arena requires unchanged raw+split eligibility'
 l=T*16384;n=l.bit_length()-1;k=20+supp;kd=k+int(split)*(1+supp);deg=4+supp;bc=128
 reserve=(2*kd-17)*l*8 if packed else kd*l*16
 tr.take('fzc.tabs',reserve,minimum=True,phase='slot18 build')
 # eq_table_into uses hi/lo decomposition for n>1; all three copies kept
 # until the final build synchronize (source keep Vec).
 keep=[]
 for table in range(3):
  lo=n//2;hi=n-lo
  for suffix,size in [('hi_r',hi*16),('lo_r',lo*16),('hi',(1<<hi)*16),('lo',(1<<lo)*16)]:
   name=f'fzc.eq{table}.{suffix}';tr.take(name,size,'raw',phase='slot18 build');keep.append(name)
 if supp:
  # One public support table, cold cache miss; persists beyond evaluator.
  if 'cache.support' not in tr.live:tr.take('cache.support',l*16,'raw',phase='slot18 build')
 for suffix,size in [('prm',84*8),('part',bc*(deg+1)*16),('sums',(deg+1)*16),('fin',k*16),('cnt',4),('src',3*k*8)]:
  tr.take('fzc.'+suffix,size,'raw',phase='slot18 build')
 tr.mark('slot18 build synchronized')
 for name in reversed(keep):tr.drop(name,'slot18 build complete')
 tr.mark('slot18 rounds')
 # Tables retain original stride and capacity even with raw-source rounds.
 tr.mark('slot18 raw='+str(raw))
 for name in [x for x in list(tr.live) if x.startswith('fzc.')][::-1]:tr.drop(name,'slot18 drop')
 tr.mark('slot18 done')
 return dict(n=n,k=k,kd=kd,degree=deg,blocks_cap_assumed=bc,tabs_requested=reserve,raw=raw,packed=packed)

def run(g,mode,compact,supp,reps,raw=True,packed=False):
 tr=Trace();n=g['n'];q=g['q']
 # Middle-stage live set from prior cycle. These seed requests omit their
 # earlier commit/open transients, so this is not a complete-run peak.
 for name,role in [('prev','B'),('cur','B'),('OUT','E')]:persistent(tr,name,g[role],n,q,mode)
 info=None
 for r in range(reps):
  for role in ['A','H']:commit(tr,role,g[role],n,q,mode,compact)
  info=fzc(tr,g['T'],supp,raw=raw,packed=packed)
  tr.mark('owners still required for openings')
  for role in ['H','A']:
   for name in [x for x in list(tr.live) if x.startswith(role+'.')][::-1]:tr.drop(name,'after required opening (scratch omitted)')
 tr.mark('subset end')
 ev=tr.events;peak=max(x['backing_bytes'] for x in ev);live=max(x['live_pooled']+x['live_raw'] for x in ev)
 return dict(geometry=g,mode=mode,compact=compact,supp=supp,repetitions=reps,raw=raw,fzc=info,peak_backing=peak,peak_live=live,peak_phase=next(x['phase'] for x in ev if x['backing_bytes']==peak),end_idle=ev[-1]['idle_pooled'],raw_allocated_cumulative=sum(x['capacity'] for x in ev if x['op']=='alloc' and x['kind']=='raw'),fresh_pooled_cumulative=sum(x['capacity'] for x in ev if x['op']=='alloc' and x['kind']=='pooled'),events=ev)

def facts():
 s=(H/'source/gpu__gpu__cuda.rs').read_text();arg=(H/'source/gpu__private_block__argument.rs').read_text()
 anchors=[('resident','let resident = if chunked_now'),('coef release','drop(d_coef);'),('encoded allocation','let mut d_enc = match Pooled::take(&dev, rows * nn)'),('coef2 release','drop(d_coef2);'),('chunk scratch','let mut d_coef = Pooled::take_min(&dev, rmax * n)?;'),('tables','let mut tabs = Pooled::take_min(&dev, kd * l * 2)?;'),('raw kept','let mut keep: Vec<CudaSlice<u64>>'),('sync','dev.synchronize().map_err(|e| format!("fzc build: {e}"))?;'),('drop keep','drop(keep);')]
 out=[]
 for key,a in anchors:
  assert a in s,key
  out.append(dict(key=key,anchor=a,lines=[i+1 for i,x in enumerate(s.splitlines()) if a in x]))
 assert 'if pool.len() < 64' in s and 'pool.swap_remove(i)' in s
 assert s.index('let raw = split')<s.index('let mut tabs = Pooled::take_min(&dev, kd * l * 2)?;')
 assert 'stride: l' in s and 'd_prm, d_part, d_sums, d_fin' in s
 arm=arg.split('SC_DZC => {',1)[1].split('SC_FZC => {',1)[0]
 assert 'FzcDesc' not in arm and 'dev_zerocheck' not in arg and 'dev_tab_zerocheck' not in arg
 return out

def main():
 t=time.perf_counter();dump('source-facts.json',facts())
 prior=json.loads((H/'startup/prior__capacity.json').read_text());gs=[]
 for x in prior:
  if x['geometry'] not in gs:gs.append(x['geometry'])
 rows=[]
 for g in gs:
  for mode,compact in [('resident',False),('chunked',False),('chunked',True)]:
   for supp in [0,1]:
    for reps in [1,2,4,8]:rows.append(run(g,mode,compact,supp,reps))
 dump('traces.json',rows)
 summary=[{k:v for k,v in x.items() if k!='events'} for x in rows];dump('capacity.json',summary)
 result=dict(status='GENERATED',seed=SEED,cases=len(rows),events=sum(len(x['events']) for x in rows),wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),scope='Partial public allocation schedule; no timing/VRAM/native proof; R8 geometry/GPU allocator are separate versions',excluded=['other slots including CPU DZC','opening scratch','preceding owner commit history','H helper construction','failure retries','twiddles','multiple/evicted public caches','host/pinned/mapped buffers','CUDA granularity,modules,driver'],full_stack=dict(proofs=0,positions=0,passes=0,context_length=None,device='CPU accounting only; no accelerator',witness_s=None,proof_s=None,serialization_s=None,verification_s=None,steady_rate=None,total_rate=None,startup_fraction=None))
 dump('model-result.json',result);print(json.dumps(result))
if __name__=='__main__':main()
