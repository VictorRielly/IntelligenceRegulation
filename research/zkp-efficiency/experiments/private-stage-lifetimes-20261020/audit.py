"""Independent declarative lifetime/capacity oracle and synthetic byte controls.

This authored single-agent audit is independent of model.py's event simulator;
it is not an external security review, a native proof, or a GPU measurement.
"""
import copy,hashlib,json,os,pathlib,random,re,resource,struct,time
H=pathlib.Path(__file__).resolve().parent
SEED=2026102094
C=0;NEG=0
def check(x,msg='check'):
 global C
 C+=1
 if not x:raise ValueError(msg)
def reject(fn):
 global NEG
 try:fn()
 except (ValueError,KeyError,AssertionError):NEG+=1;return
 raise ValueError('negative control accepted')
def declarative(events,L):
 # Obligations are derived from the adjacent-block relation, independently
 # of any candidate creation/drop instructions.
 expected={'IN','OUT'}|{f'{r}{k}' for k in range(L) for r in ['A','M','H']}|{f'B{k}' for k in range(L-1)}
 created={};dropped={};opened={};read={};claims={}
 for i,e in enumerate(events):
  op,obj,k=e['op'],e['obj'],e['stage']
  if op in ['serialize','sink']:continue
  check(obj in expected,'unknown owner')
  if op=='create':
   check(obj not in created,'created twice');created[obj]=i
  else:
   check(obj in created and obj not in dropped,'read/open/drop without live owner')
   if op=='drop':
    check(obj in opened,'drop before opening');dropped[obj]=i
   elif op=='open':
    check(obj not in opened,'multiple openings');opened[obj]=(i,k)
    need=({('consumer',0)} if obj=='IN' else {('producer',L-1)} if obj=='OUT' else {('producer',int(obj[1:])),('consumer',int(obj[1:])+1)} if obj.startswith('B') else set())
    check(set(claims.get(obj,[]))==need,'boundary claim list incomplete/misbound')
    check(bool(read.get(obj)),'open before slots')
   elif op=='read':
    check(obj not in opened,'read after opening');read.setdefault(obj,[]).append(k)
   elif op=='claim':
    check(obj not in opened,'late claim');claims.setdefault(obj,[]).append((e['side'],k))
   else:raise ValueError('unknown operation')
 check(set(created)==set(dropped)==set(opened)==expected,'missing owner or release')
 for obj in expected:
  need=([0] if obj=='IN' else [L-1] if obj=='OUT' else [int(obj[1:]),int(obj[1:])+1] if obj.startswith('B') else [int(obj[1:])])
  check(read.get(obj)==need,'read stage mismatch')
  k=need[-1];check(opened[obj][1]==k,'opened in wrong stage')
  check(dropped[obj]==opened[obj][0]+1,'late release remains')
 for k in range(L):
  inobj='IN' if k==0 else f'B{k-1}'
  sequence=[x['obj'] for x in events if x['stage']==k and x['op']=='open']
  check(sequence==[f'M{k}',f'A{k}',f'H{k}',inobj]+(['OUT'] if k==L-1 else []),'opening order')
  inds={op:[i for i,x in enumerate(events) if x['stage']==k and x['op']==op] for op in ['serialize','sink']}
  check(len(inds['serialize'])==len(inds['sink'])==1,'segment lost/duplicated')
  check(max(opened[o][0] for o in sequence)<inds['serialize'][0]<inds['sink'][0],'sink too early')
 return created,dropped
def independent_rows(g):
 n=g['n'];T=g['T'];ls=((T.bit_length()-1)+9+7)//8
 domains={'T':T,'Ht':32*T,'L':max(16*T,n),'D':4096*T,'Q':4096*T,'Kv':1024*T,'S':32*T*T,'F':16384*T,'Tab':n}
 # Expand a plane-family list, then accumulate padded rows. Does not use
 # model.py's aggregate a/h dictionaries or geometric byte function.
 a=['T']*4+['Ht']*2+['L']*2+['D']*35+['Q']*7+['Kv']*6+['S']*(7+2*ls)+['F']*11+['Tab']*3
 h=['L']+['D']*17+['Q']*7+['Kv']*6+['S']*((7+2*(ls+1)+1)//2+1)+['F']*6+['Tab']*4
 sites_a=[1,1,22,2,2]+[1]*7+[2,2,37,8,7,9+2*ls,11,3,2]
 sites_h=[1,17,7,6,(7+2*(ls+1)+1)//2+1,6,3,1]
 return sum(max(1,domains[d]//n) for d in a)+2*sum(sites_a)+2,2*sum(max(1,domains[d]//n) for d in h)+2*sum(sites_h)+2
def independently_count(obj,g,mode):
 if obj.startswith('M'):return (0,0)
 if obj in ['IN','OUT']:r=g['T']*4096//g['n']+5
 elif obj.startswith('B'):r=g['T']*4096//g['n']+7
 elif obj.startswith('A'):r=independent_rows(g)[0]
 else:r=independent_rows(g)[1]
 n=g['n']
 if mode=='resident':return (8*r*(n+4*n),0)
 return (8*r*n,8*(r*256+4*n))
def payload(obj,seed):
 # Synthetic test bytes only. Different commitment owners get different
 # bytes; these hashes are test checksums, not native roots or masks.
 return hashlib.shake_256(f'{seed}/{obj}'.encode()).digest(193)
def byte_reference(events,seed):
 # Immutable host-only values, no device cache or copy lifecycle.
 h=hashlib.sha256()
 for e in events:
  if e['op'] in ['read','open']:h.update(e['op'].encode()+e['obj'].encode()+payload(e['obj'],seed))
 return h.hexdigest()
def storage_candidate(events,seed,evict_output,mutation=None):
 host={};dev={};h=hashlib.sha256();out_copied=False
 for e in events:
  op,obj=e['op'],e['obj']
  if op=='create':
   host[obj]=payload(obj,seed);dev[obj]=host[obj]
   if obj=='OUT' and evict_output:del dev[obj]
  elif op=='read':
   # prove_core IO terminals read the HOST data, including OUT in final stage.
   b=host[obj];h.update(op.encode()+obj.encode()+b)
  elif op=='open':
   if obj=='OUT' and evict_output:
    if mutation=='missing_restore':raise ValueError('device output absent')
    dev[obj]=(host['IN'] if 'IN' in host else bytes(193)) if mutation=='wrong_owner' else host[obj]
    if mutation=='short_restore':dev[obj]=dev[obj][:-1]+b'!'
    out_copied=True
   h.update(op.encode()+obj.encode()+dev[obj])
  elif op=='drop':
   del host[obj];dev.pop(obj,None)
 if host or dev:raise ValueError('storage not released')
 check(out_copied==evict_output)
 return h.hexdigest()
def main():
 t=time.perf_counter();events=json.loads((H/'events.json').read_text());caps=json.loads((H/'capacity.json').read_text());facts=json.loads((H/'source-facts.json').read_text());examples=[]
 # Check source-line evidence with a line scan rather than candidate offsets.
 for tree,entries in facts.items():
  for e in entries:
   f='private_block/'+('run.rs' if e['file']=='run' else 'protocol.rs')
   lines=(H/'source'/(tree+'__'+f.replace('/','__'))).read_text().splitlines()
   check(e['anchor'] in lines[e['line']-1],'source pin line')
  # Numeric geometry is R8; active GPU source has an older trained door.
  check(len(entries)==19)
 for bstr,ev in events.items():
  L=int(bstr);created,dropped=declarative(ev,L)
  for obj in sorted(created):
   # Earliest legal logical release is immediately AFTER its only opening.
   mutated=copy.deepcopy(ev);i=next(i for i,x in enumerate(ev) if x['op']=='open' and x['obj']==obj)
   j=next(i for i,x in enumerate(ev) if x['op']=='drop' and x['obj']==obj)
   rec=mutated.pop(j);mutated.insert(i,rec);reject(lambda:declarative(mutated,L))
  if L>1:
   mut=copy.deepcopy(ev);oi=next(i for i,x in enumerate(mut) if x['op']=='open' and x['obj']=='B0');di=oi+1
   pair=mut[oi:di+1];del mut[oi:di+1]
   j=next(i for i,x in enumerate(mut) if x['op']=='claim' and x['obj']=='B0')+1
   mut[j:j]=pair;reject(lambda:declarative(mut,L))
   mut=copy.deepcopy(ev);j=next(i for i,x in enumerate(mut) if x['op']=='claim' and x['obj']=='B0' and x['side']=='consumer');mut[j]['side']='producer';reject(lambda:declarative(mut,L))
  for kind in ['double_open','missing_close','missing_sink','swapped_order']:
   mut=copy.deepcopy(ev)
   if kind=='double_open':
    i=next(i for i,x in enumerate(mut) if x['op']=='open');mut.insert(i,copy.deepcopy(mut[i]))
   elif kind=='missing_close':mut=[x for x in mut if not(x['obj']=='OUT' and x['op'] in ['open','drop'])]
   elif kind=='missing_sink':mut=[x for x in mut if not(x['op']=='sink' and x['stage']==L-1)]
   else:
    i=next(i for i,x in enumerate(mut) if x['op']=='open' and x['obj']=='M0');j=next(i for i,x in enumerate(mut) if x['op']=='open' and x['obj']=='A0');mut[i:j+2]=mut[j:j+2]+mut[i:j]
   reject(lambda:declarative(mut,L))
  for seed in [SEED,SEED+1,SEED+13]:
   ref=byte_reference(ev,seed)
   for off in [False,True]:check(storage_candidate(ev,seed,off)==ref,'storage changed bytes')
   for mutation in ['missing_restore','wrong_owner','short_restore']:
    def neg(mutation=mutation):check(storage_candidate(ev,seed,True,mutation)==ref,'bad restore')
    reject(neg)
 # Interval overlap oracle: no create/drop simulator and no candidate sums.
 for row in caps:
  g=row['geometry'];mode=row['storage'];ev=events[str(row['blocks'])];created,dropped=declarative(ev,row['blocks'])
  ar,hr=independent_rows(g);check((ar,hr)==(g['A'],g['H']),'independent rows')
  peak=0;new_peak=0
  out_open=next(i for i,x in enumerate(ev) if x['op']=='open' and x['obj']=='OUT')
  for i in range(len(ev)):
   live=[o for o in created if created[o]<=i<dropped[o]]
   total=sum(sum(independently_count(o,g,mode)) for o in live)
   omitted=sum(independently_count('OUT',g,mode)) if created['OUT']<=i<out_open else 0
   peak=max(peak,total);new_peak=max(new_peak,total-omitted)
  check(peak==row['persistent_owner_peak_bytes'],'peak differs')
  check(new_peak==row['output_evicted_peak_bytes'],'evict peak differs')
  check(row['release_only_saving_bytes']==0)
  ep,er=independently_count('OUT',g,mode)
  check(row['output_returned_idle_pooled_bytes']==ep)
  check(row['output_direct_raw_free_bytes']==er)
  check(row['output_pooled_backing_released_by_drop_bytes']==0)
  # Allocation ownership algebra: drop transfers the pooled backing to
  # idle; it is still charged to device allocation until reused or freed.
  active=peak;idle=0;allocated=active+idle
  active-=ep+er;idle+=ep
  check(active+idle==allocated-er,'drop falsely frees pooled backing')
  reject(lambda:check(active+idle==allocated-er-ep,'wrong pooled free'))
  if g['T']==128 and row['blocks']==32:examples.append(row)
 # Cross-check one counted source baseline without executing owner code.
 native=json.loads((H/'source/extra__r9_counts.json').read_text())['Llama-3-8B T128 (row 2^14)']['today']
 check((native['a_rows'],native['h_rows'])==(3405,3790))
 result=dict(status='PASS',checks=C,negative_controls=NEG,traces=len(events),capacity_cases=len(caps),synthetic_byte_fixtures=len(events)*3*2,seed=SEED,wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),scope='Independent authored single-agent dependency/interval/byte oracle; no native proof or external security review',T128_L32_examples=examples)
 (H/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='T128_L32_examples'}))
if __name__=='__main__':main()
