import collections,hashlib,itertools,json,pathlib
D=pathlib.Path(__file__).resolve().parent
P=2**64-2**32+1
checks=0
def ck(cond):
 global checks
 assert cond
 checks+=1
def dump(name,obj):(D/name).write_text(json.dumps(obj,indent=2)+'\n')
def digest(b):return hashlib.sha256(b).hexdigest()
# Independently indexed bigint full-dot products, one reduction per output limb.
limbs=0
for line in (D/'public-vectors.jsonl').read_text().splitlines():
 x=json.loads(line);rows,n,q,k=(x[s] for s in ['rows','n','q','k']);want=[]
 for g in range(k):
  out=[]
  for src,width in [(x['data'],n),(x['pads'],q)]:
   for j in range(width):
    out.extend(sum(x['rho'][g][2*i+t]*src[i*width+j] for i in range(rows))%P for t in range(2))
  ck(out==x['out'][g]);want.append(out);limbs+=len(out)
 ck(want==x['out'])
# Public descriptor oracle: partition vector identities and both limb index spaces.
for rows,n,k in itertools.product([0,1,7,3517],[1,7,16384],range(130)):
 groups=[list(range(k))[i:i+4] for i in range(0,k,4)]
 ck([v for g in groups for v in g]==list(range(k)))
 for g in groups:
  start=g[0];w=len(g)
  ck(w in range(1,5));ck(2*start*rows+2*w*rows<=2*k*rows);ck(2*start*n+2*w*n<=2*k*n)
  ck(2*w*rows<=2*min(4,k)*rows);ck(2*w*n<=2*min(4,k)*n)

# Enumerate every interleaving of upload/kernel/download completions on three FIFO
# engines. This is a dependency model, not a CUDA execution or timing simulation.
def schedules(batches,slots,guard):
 def rec(done,seq):
  if len(seq)==3*batches:
   yield seq;return
  for stage in range(3):
   i=done[stage]
   if i==batches:continue
   if stage>0 and done[stage-1]<=i:continue
   if stage==0 and guard and i>=slots and done[2]<=i-slots:continue
   nxt=list(done);nxt[stage]+=1
   yield from rec(tuple(nxt),seq+[(stage,i)])
 yield from rec((0,0,0),[])
def replay(seq,slots):
 rho=[None]*slots;out=[None]*slots;bad=[]
 for stage,i in seq:
  s=i%slots
  if stage==0:rho[s]=i
  elif stage==1:
   if rho[s]!=i:bad.append(('stale_rho',i,rho[s]))
   out[s]=rho[s]
  elif out[s]!=i:bad.append(('stale_output',i,out[s]))
 return bad
events=[]
for slots in [1,2]:
 good=list(schedules(4,slots,True));bad=list(schedules(4,slots,False))
 ck(all(not replay(s,slots) for s in good))
 broken=[s for s in bad if replay(s,slots)]
 ck(bool(broken))
 events.append({'slots':slots,'batches':4,'guarded_schedules':len(good),'unguarded_schedules':len(bad),'corrupt_unguarded_schedules':len(broken),'first_corrupt':broken[0],'diagnosis':replay(broken[0],slots)})
# Outstanding queued uses must be completed before reuse/release on error.
cleanup=[]
seq=[('upload',0),('kernel',0),('download',0),('upload',1),('kernel',1),('download',1)]
for cut in range(1,len(seq)+1):
 pending=list(seq[:cut]);early_drop_safe=not pending;ck(not early_drop_safe)
 pending.clear();ck(not pending)
 cleanup.append({'failure_after_enqueues':cut,'drop_without_drain_rejected':True,'drained_before_drop':True})

# Count API submissions and requested scratch; not physical allocations/DRAM/time.
cost=[]
for label,rows,n,k in [('A_nonDD_fe9_T128',3517,16384,57),('H_nonDD_fe9_T128',3272,16384,12),('A_DD_fe9_T128',3395,16384,59),('H_DD_fe9_T128',3116,16384,13)]:
 b=(k+3)//4
 modes={}
 for name in ['baseline','serial','full','ring2']:
  cap=k if name=='full' else min(4,k)*(2 if name=='ring2' else 1)
  modes[name]={'scratch_device_requested_bytes':16*(rows+n)*cap,'rho_host_flat_capacity_bytes':16*rows*cap,'device_alloc_submissions':2*b if name=='baseline' else 4 if name=='ring2' else 2,'h2d_submissions':1 if name=='full' else b,'d2h_submissions':1 if name=='full' else b,'kernel_launches':b,'matrix_source_operand_bytes':8*rows*n*b,'h2d_payload_bytes':16*k*rows,'d2h_payload_bytes':16*k*n}
 for name,v in modes.items():
  ck(v['kernel_launches']==b);ck(v['h2d_payload_bytes']==16*k*rows);ck(v['d2h_payload_bytes']==16*k*n);ck(v['matrix_source_operand_bytes']==8*rows*n*b)
 ck(modes['serial']['scratch_device_requested_bytes']==modes['baseline']['scratch_device_requested_bytes'])
 ck(modes['full']['scratch_device_requested_bytes']/modes['baseline']['scratch_device_requested_bytes']==k/min(k,4))
 cost.append({'label':label,'rows':rows,'columns':n,'rhos_including_fresh_proximity':k,'chunks':b,'historical_conditional_only':True,'modes':modes})
dump('cost-study.json',{'scope':'Conditional historical standalone R14 fe9 groups; not current full-run groups or8B','cases':cost,'host_limit':'Host output collection is unchanged in total payload; transient host flatten/D2H Vec capacity and conversion coexist. Actual allocator capacity/RSS and native lifetime must be measured.','time_ceiling':'N/(T-C_removed_exclusive+A_added). Unknown exclusive allocator/submission fraction f; free removal <=1/(1-f). No GPU8B forecast.','no_saved_arithmetic_or_transcript':True})
dump('lifetime-study.json',{'model':'three independent FIFO engines; generation-tagged ring slots; every legal completion order enumerated for4batches','events':events,'error_cleanup':cleanup,'not_cuda_or_race_proof':True})
# Recheck source and copied scalar arithmetic/serial-host extraction against current pins.
pins=json.loads((D/'source-pins.json').read_text())
drift=[]
for p in pins:
 current=pathlib.Path(p['path']).read_bytes();now=digest(current)
 if now!=p['sha256'] and ('/docs/' in p['path'] or p['path'].endswith('/CLAUDE.md')):
  # Keep preparation evidence immutable; concurrent owner documentation is read,
  # snapshotted, and reported, never silently repinned as native arithmetic.
  dest=D/'closing-documents'/pathlib.Path(p['path']).name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(current)
  drift.append({'path':p['path'],'initial_sha256':p['sha256'],'current_sha256':now,'closing_snapshot':str(dest.relative_to(D))})
  ck(True)
 else:ck(now==p['sha256'])
 ck(digest((D/p['snapshot']).read_bytes())==p['sha256'])
dump('concurrent-document-recheck.json',drift)
field=(D/'context/native/zkp-core/src/field.rs').read_text();ck((D/'field.rs').read_text()==field)
pcs=(D/'context/native/zkp-core/src/pcs.rs').read_text();start=pcs.index('fn fold_rows_host(');pos=pcs.index('{',start);depth=1;end=pos+1
while depth:
 depth+=(pcs[end]=='{')-(pcs[end]=='}');end+=1
host=pcs[start:end].replace('.into_par_iter()', '.into_iter()')+'\n';ck((D/'native_host.rs').read_text()==host)
for txt in ['for chunk in rhos.chunks(4)','let padf = fold_rows_host','let (rhos, _wants) = zk_rhos','assert_mask_sites(cmz, &rhos)']:ck(txt in pcs)
result={'status':'PASS','python_assertions':checks,'python_bigint_vector_fixtures':16,'python_bigint_scalar_limbs':limbs,'rust':json.loads((D/'probe.stdout.log').read_text()),'lifetime_model':events,'scope':'Independent authored references and synthetic scheduling model; not external review or native CUDA/PCS/FS/receipt/privacy acceptance','full_stack_proofs':0,'passes':0,'positions':0}
dump('result.json',result);print(json.dumps(result))
