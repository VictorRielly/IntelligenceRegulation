"""Independent public A plane/interval/symbolic-key model; no witness or native prove."""
from pathlib import Path
import json,time,platform
from collections import Counter
import model,legacy_catalog as base
D=Path(__file__).resolve().parent
native=json.loads((D/'result.json').read_text());metadata=json.loads((D/'case-metadata.json').read_text());checks=0;out=[]
def check(x,label=''):
 global checks
 assert x,label
 checks+=1
def inventory(g):
 # Independent named allocation read from R13 relation roles, not Rust offsets.
 names=[];domains=[]
 def block(dom,items):
  names.extend(items.split());domains.extend([dom]*len(items.split()))
 block('T','D DSQ DM DSQM');block('Ht','MX SUM');block('L','LIMB LIMBM')
 block('D','X XL0 XL1 Y YL0 YL1 NR0 NR1 NR2 NS0 NS1 NS2 AO AL0 AL1 RAL0 RAL1 RAL2 X1 X1L0 X1L1 YM YML0 YML1 MR0 MR1 MR2 MS0 MS1 MS2 Z ZL0 ZL1 RDL0 RDL1'+(' RDL2' if g.h24 else '')+' X2 X2L0 X2L1')
 block('Q','Q QL0 QL1 RQL0 RQL1 QR QRL0 QRL1 RQRL O OL0 OL1 RO0 RO1')
 block('Kv','K KL0 KL1 RKL0 RKL1 V VL0 VL1 RVL0 RVL1 KR KRL0 KRL1 RKRL')
 div='PL0 PL1 '+' '.join('SR'+str(k) for k in range(g.ls))+' '+' '.join('SG'+str(k) for k in range(g.ls))
 block('S','S RSL0 RSL1 RSL2 ZSEL E P'+('' if g.dd else ' '+div))
 block('F','G RGL0 RGL1 RGL2 A_SCALED U UL0 UL1 RU0 RU1 H HL0 HL1'+(' HL2 RH0 RH1' if g.h24 else ' RH0 RH1 RH2'))
 if g.dd:block('Dd','PDICT '+div+' MDD')
 block('Tab','MU8 MEXP MACT')
 return names,domains

def group_plan(bits):
 # Bounded deterministic public-only pair swaps. Full chunks stay full;
 # only the final chunk may be partial. No claim of global optimality.
 order=list(range(len(bits)));batch_count=(len(bits)+3)//4
 def cost(order):
  total=0
  for k in range(0,len(order),4):
   u=0
   for i in order[k:k+4]:u|=bits[i]
   total+=u.bit_count()
  return total
 initial=cost(order);current=initial;swaps=0
 for step in range(100):
  best=(current,None)
  for i in range(len(order)):
   for j in range(i+1,len(order)):
    if i//4==j//4:continue
    a=(i//4)*4;b=(j//4)*4
    old=sum(__import__('functools').reduce(int.__or__,(bits[g] for g in order[k:k+4]),0).bit_count() for k in (a,b))
    new=0
    for k in (a,b):
     u=0
     for pos in range(k,min(k+4,len(order))):u|=bits[order[j] if pos==i else order[i] if pos==j else order[pos]]
     new+=u.bit_count()
    trial=current-old+new
    if trial<best[0]:best=(trial,(i,j))
  if best[1] is None:break
  i,j=best[1];order[i],order[j]=order[j],order[i];current=best[0];swaps+=1
 check(cost(order)==current);check(sorted(order)==list(range(len(bits))))
 return order,current,swaps,step<99
for p,meta in zip(native['profiles'],metadata):
 g=model.Geometry(**meta['geometry']);logs=g.domains();n=1<<g.row;names,doms=inventory(g)
 check(names==p['plane_names'],'names');offsets=[];data=0
 for dom in doms:offsets.append(data*n);data+=max(1,(1<<logs[dom])//n)
 check(offsets==p['plane_offsets'],'offsets');check(data==p['data'],'data')
 byname={name:(off,dom) for name,off,dom in zip(names,offsets,doms)}
 bydom={dom:[name for name,d in zip(names,doms) if d==dom] for dom in logs}
 schedule={0:['X'],1:['X1'],2:['D','DSQ']+['LIMB']*9+['DM','DSQM']+['LIMBM']*9,3:['LIMB','LIMBM'],4:['E','ZSEL'],5:['Y'],6:['Y'],7:['Y'],8:['QR','KR'],9:['P','V'],10:['O'],11:['YM'],12:['YM'],13:['H'],14:bydom['D']+['D','DM'],15:bydom['Q']+['Q'],16:bydom['Kv']+['K'],17:bydom['S']+['MX','SUM'],18:bydom['F'],19:['MU8','MEXP','MACT'],21:['X'],22:['X2']}
 if g.dd:schedule[23]=bydom['Dd']+['SUM']
 descriptor=[];sets=[];keys=[];counts=[];site=0
 for slot,entries in enumerate(base.catalog(g)):
  entries=[x for x in entries if x.cm=='A'];plane_names=schedule.get(slot,[]);check(len(entries)==len(plane_names),str(slot))
  for k,(entry,name) in enumerate(zip(entries,plane_names)):
   off,dom=byname[name]
   if slot==2 and name.startswith('LIMB'):off+=(k-2 if name=='LIMB' else k-13)*g.t
   mask=data+2*site;site+=1;descriptor.append([slot,entry.log,off,mask])
   m=min(entry.row,entry.log);cs=entry.coords[entry.log-m:]
   def coord(c):
    typ,x=c
    if meta['mode']:
     z=meta['mode']-1
     return (1-z if typ=='flip' else z)
    if typ=='fixed':return c
    return (typ,slot,x)
   key=(tuple(map(coord,cs)),off%n if entry.log<g.row else 0,1<<m)
   if key not in keys:keys.append(key);sets.append(set());counts.append(0)
   gi=keys.index(key);counts[gi]+=1
   sets[gi].update(range(off//n,off//n+max(1,(1<<entry.log)//n)));sets[gi].update([mask,mask+1])
 check(descriptor==p['descriptors'],'descriptor');check(site==p['sites']);check(data+2*site+2==p['rows'])
 check(counts==p['group_claim_counts'],'group counts');sets.append(set(range(p['rows'])))
 check([sorted(x) for x in sets]==p['support_rows'],'full support rows')
 chunks=[len(set().union(*sets[i:i+4])) for i in range(0,len(sets),4)];check(chunks==p['chunks']);check(sum(chunks)==p['structural_visits'])
 overlap=sum(sum(r in s for s in sets[:-1])>1 for r in range(data));check(overlap==p['multiply_claimed_data_rows']);check(overlap>0,'A is not H-disjoint')
 if meta['source']:
  row=meta['native_census'];check(p['rows']==row['a_rows']);check(site==row['a_sites']);check(data==row['a_mask_base']);check(len(sets)-1==(38 if g.dd else 36))
  check(p['support_sizes']==p['numeric_nonzeros'],'generic numerical support')
  t=time.monotonic();bits=[sum(1<<r for r in s) for s in sets];order,best,swaps,converged=group_plan(bits);plan_s=time.monotonic()-t
  packed=[order[i:i+4] for i in range(0,len(order),4)];independent=sum(len(set().union(*(sets[i] for i in batch))) for batch in packed);check(independent==best)
  # Native API packing capacity requires all earlier batches full.
  check(all(len(b)==4 for b in packed[:-1]));check(best<=sum(chunks))
  baseline=p['baseline_visits'];v=sum(chunks)
  h=next(x for x in json.loads((D/'startup/prior-census-result.json').read_text())['profiles'] if x['dd']==bool(g.dd))
  out.append(dict(dd=bool(g.dd),context=128,n=n,rows=p['rows'],data=data,sites=site,groups=len(sets)-1,baseline_visits=baseline,structural_visits=v,logical_matrix_read_reduction=(baseline-v)/baseline,baseline_bytes=baseline*n*8,structural_bytes_upper=v*n*8,multiply_claimed_data_rows=overlap,packing_plan=packed,packed_visits=best,packed_bytes_upper=best*n*8,packed_reduction_from_dense=(baseline-best)/baseline,planner_s=plan_s,planner_swaps=swaps,pair_swap_local_optimum=converged,global_optimum_claim=False,rho_bytes_copied_if_clone=len(sets)*p['rows']*16,max_streamed_clone_payload=min(4,len(sets))*p['rows']*16,combined_AH_baseline_bytes=(baseline*n*8)+h['baseline_bytes'],combined_AH_original_order_upper_bytes=(v*n*8)+h['structural_upper_bytes'],combined_AH_original_order_read_reduction=1-((v*n*8)+h['structural_upper_bytes'])/((baseline*n*8)+h['baseline_bytes']),combined_AH_packed_upper_bytes=(best*n*8)+h['packed_structural_upper_bytes'],combined_AH_packed_read_reduction=1-((best*n*8)+h['packed_structural_upper_bytes'])/((baseline*n*8)+h['baseline_bytes']),native_define_executed=False,native_FS_executed=False,CUDA_executed=False))
result=dict(status='PASS',checks=checks,profiles=out,seed=202610290150,scope='Exact source-derived frozenR13 A structural support; locally supplied public geometry/schedule and scripted challenges; no native define/FS/full proof. Pair-swap packing is bounded local optimum only.',full_stack_proofs=0,model_passes=0,proved_positions=0)
(D/'census-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
