"""Independent interval oracle and adversarial controls for capacity events.

No reuse of the model's live/backing accounting implementation. The reference
uses allocation and lease lifetime difference arrays. Single author, separate
algorithm, not independent organizational review or proof verification.
"""
from pathlib import Path
import json,random,time,resource,os,copy,hashlib
import model
H=Path(__file__).resolve().parent
CHECKS=0
NEG=0

def ck(x,msg=''):
 global CHECKS
 CHECKS+=1
 assert x,msg

def oracle(events):
 N=len(events);alloc={};lease={};open_lease={};active=set();idle=[];seen=set();intervals=[];leases=[]
 for i,e in enumerate(events):
  op=e['op'];bid=e['id'];name=e['name'];cap=e['capacity'];kind=e['kind'];req=e['requested']
  if op=='mark':continue
  ck(cap>=req>0,(i,'capacity'))
  if op=='alloc':
   ck(bid not in seen,(i,'duplicate allocation id'));seen.add(bid)
   ck(name not in open_lease,(i,'duplicate lease'));ck(cap==req,(i,'fresh exact size'))
   if kind=='pooled':
    matches=[a for a in idle if alloc[a][0]>=req] if e['minimum'] else [a for a in idle if alloc[a][0]==req]
    ck(not matches,(i,'avoidable fresh allocation'))
   alloc[bid]=(cap,kind,i);active.add(bid);open_lease[name]=(bid,req,i)
  elif op=='reuse':
   ck(kind=='pooled' and bid in idle,(i,'not idle pooled'))
   ck(name not in open_lease,(i,'duplicate live name'))
   matches=[a for a in idle if alloc[a][0]>=req] if e['minimum'] else [a for a in idle if alloc[a][0]==req]
   ck(bool(matches) and cap==min(alloc[a][0] for a in matches),(i,'best fit'))
   ck(alloc[bid][0]==cap,(i,'changed capacity'))
   idle.remove(bid);open_lease[name]=(bid,req,i)
  elif op in ['return','free']:
   ck(name in open_lease,(i,'missing lease'));b,r,begin=open_lease.pop(name)
   ck(b==bid and r==req and alloc[bid][:2]==(cap,kind),(i,'lease mismatch'))
   leases.append((begin,i,cap,req,kind))
   if op=='return':
    ck(kind=='pooled' and len(idle)<64,(i,'pool limit'));idle.append(bid)
   else:
    ck(kind=='raw' or len(idle)>=64,(i,'pool unexpectedly freed'))
    c,k,start=alloc.pop(bid);active.remove(bid);intervals.append((start,i,c,k))
  else:raise AssertionError('unknown event')
 for bid,(cap,kind,begin) in alloc.items():intervals.append((begin,N,cap,kind))
 for name,(bid,req,begin) in open_lease.items():leases.append((begin,N,alloc[bid][0],req,alloc[bid][1]))
 # Evaluate half-open intervals at AFTER-event sample points.
 diff={k:[0]*(N+1) for k in ['pooled','raw','livepool','liveraw','requested']}
 for begin,end,cap,kind in intervals:diff[kind][begin]+=cap;diff[kind][end]-=cap
 for begin,end,cap,req,kind in leases:
  key='livepool' if kind=='pooled' else 'liveraw';diff[key][begin]+=cap;diff[key][end]-=cap;diff['requested'][begin]+=req;diff['requested'][end]-=req
 sums={k:0 for k in diff};snap=[]
 for i,e in enumerate(events):
  for k in diff:sums[k]+=diff[k][i]
  ref=dict(live_pooled=sums['livepool'],live_raw=sums['liveraw'],idle_pooled=sums['pooled']-sums['livepool'],backing_bytes=sums['pooled']+sums['raw'],requested_live=sums['requested'])
  ck(all(v>=0 for v in ref.values()),(i,'negative'))
  for k,v in ref.items():ck(v==e[k],(i,k,v,e[k]))
  snap.append(ref)
 return snap

def refuse(ev):
 global NEG
 try:oracle(ev)
 except (AssertionError,KeyError):NEG+=1;return
 raise AssertionError('negative control accepted')

def source_checks():
 s=(H/'source/gpu__gpu__cuda.rs').read_text();f=(H/'source/gpu__gpu__fzc.rs').read_text();arg=(H/'source/gpu__private_block__argument.rs').read_text()
 inner=s.split('fn dev_commit_zk_from_inner(',1)[1].split('/// Upload `data`',1)[0]
 resident=inner.split('g.ntt_rows(d_data.get()',1)[1]
 ck(resident.index('drop(d_coef);')<resident.index('let mut d_enc = match')<resident.index('g.ntt_rows(d_coef2.get()')<resident.rindex('drop(d_coef2);')<resident.index('let leaves = match key'))
 ck('const B3_STATE_SLOTS: usize = 8 * 24 + 1;' in s)
 ck('pub const FZ_LEN: usize = 84;' in f)
 ck('let lo_bits = nv / 2;' in s and 'let hi_bits = nv - lo_bits;' in s)
 ctor=s.split('pub fn new(srcs:',1)[1].split('/// the first device error',1)[0]
 ck(ctor.index('let mut tabs = Pooled::take_min')<ctor.index('for (t, sp)')<ctor.index('let d_part =')<ctor.index('fzc build: {e}')<ctor.index('drop(keep);'))
 ck('tabs, k, stride: l' in ctor)
 dzc=arg.split('SC_DZC => {',1)[1].split('SC_FZC => {',1)[0]
 ck('FzcDesc' not in dzc and 'gpu::' not in dzc)
 ck('dev_tab_zerocheck' not in arg and 'dev_zerocheck_blocks' not in arg)


def main():
 t=time.perf_counter();source_checks();cases=json.loads((H/'traces.json').read_text());mutations=0
 for case in cases:
  ev=case['events'];ref=oracle(ev)
  ck(max(x['backing_bytes'] for x in ref)==case['peak_backing'])
  ck(sum(x['capacity'] for x in ev if x['op']=='alloc' and x['kind']=='raw')==case['raw_allocated_cumulative'])
  # Catch systematically confusing live/requested/cumulative with backing.
  for key in ['backing_bytes','idle_pooled','requested_live','live_raw']:
   at=next((i for i,e in enumerate(ev) if e[key]>0),None)
   if at is not None:
    bad=copy.deepcopy(ev);bad[at][key]-=1;refuse(bad);mutations+=1
  at=next(i for i,e in enumerate(ev) if e['op']=='return');bad=copy.deepcopy(ev);bad[at]['op']='free';refuse(bad);mutations+=1
  # raw source flag changes table building, not reservation or ownership.
  if case['repetitions']==1:
   alt=model.run(case['geometry'],case['mode'],case['compact'],case['supp'],1,raw=False)
   ck(alt['peak_backing']==case['peak_backing'])
   ck(alt['fzc']['tabs_requested']==case['fzc']['tabs_requested'])
 # Randomized small allocator traffic: symbol-only, never large allocations.
 rng=random.Random(model.SEED);randoms=80
 for j in range(randoms):
  tr=model.Trace();names=[]
  for step in range(70):
   if names and rng.random()<.42:
    name=names.pop(rng.randrange(len(names)));tr.drop(name,'random')
   else:
    name=f'x{step}';names.append(name);tr.take(name,rng.choice([8,16,24,32,64,128,256]),'raw' if rng.random()<.25 else 'pooled',rng.random()<.5,'random')
  for name in names:tr.drop(name,'random')
  oracle(tr.events)
  at=next(i for i,e in enumerate(tr.events) if e['op']=='alloc');bad=copy.deepcopy(tr.events);bad[at]['capacity']+=8;refuse(bad)
 # 64 idle buffer limit really frees the 65th; released buffers are not
 # generally deallocations. Largest-minimum reuse capacity must be counted.
 tr=model.Trace()
 for i in range(70):tr.take(f'b{i}',(i+1)*8)
 for i in range(70):tr.drop(f'b{i}')
 oracle(tr.events);ck(len(tr.idle)==64)
 ck(sum(e['op']=='free' for e in tr.events)==6)
 tr=model.Trace();tr.take('large',4096);tr.drop('large');tr.take('small',256,minimum=True)
 oracle(tr.events);ck(tr.events[-1]['requested_live']==256 and tr.events[-1]['backing_bytes']==4096)
 bad=copy.deepcopy(tr.events);bad[-1]['backing_bytes']=256;refuse(bad)
 # A source-derived owner cannot be released before slots/opening consume it.
 for case in cases:
  ev=case['events']
  starts=[i for i,e in enumerate(ev) if e['phase']=='slot18 build' and e['name']=='fzc.tabs']
  for begin in starts:
   end=next(i for i in range(begin,len(ev)) if ev[i]['phase']=='slot18 done')
   for role in ['A','H']:
    ck(not any(e['op'] in ['return','free'] and e['name'].startswith(role+'.data') for e in ev[begin:end+1]))
 # Compare repeated workloads: cumulative raw grows while HWM can plateau.
 groups={}
 for c in cases:groups.setdefault((c['geometry']['T'],c['mode'],c['compact'],c['supp']),[]).append(c)
 for group in groups.values():
  a,b,c,d=sorted(group,key=lambda c:c['repetitions'])
  ck(c['peak_backing']==d['peak_backing']);ck(c['raw_allocated_cumulative']<d['raw_allocated_cumulative'])
 res=dict(status='PASS',checks=CHECKS,negative_controls=NEG,capacity_traces=len(cases),random_traces=randoms,pool_limit_cases=1,oversize_cases=1,seed=model.SEED,scope='Authored independent interval oracle; no native arithmetic,transcripts,security review or proof verification',wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)))
 model.dump('audit-result.json',res);print(json.dumps(res))
if __name__=='__main__':main()
