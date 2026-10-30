"""Independent public-geometry reference, plus retained native-census comparison.

Uses count blocks and global prefix sums rather than the extracted Rust's
per-plane constructor. No private source words or runtime rho values inspected.
"""
from pathlib import Path
from collections import Counter
from itertools import accumulate
import copy,hashlib,json,math,random
D=Path(__file__).resolve().parent
SEED=202610290154
rng=random.Random(SEED)
checks=0;negative=0
def check(v):
 global checks
 checks+=1
 assert v
def lg(x):
 check(x>0 and x&(x-1)==0)
 return x.bit_length()-1
def reference(t,dd,fe):
 n=128*t;r=lg(n);ls=math.ceil((lg(t)+fe)/8)
 ac=dict(T=4,Ht=2,L=2,D=39,Q=14,Kv=14,S=7 if dd else 9+2*ls,F=16)
 if dd:ac['Dd']=4+2*ls
 ac['Tab']=3
 lookup=dict(L=2,D=34,Q=14,Kv=14,F=14,S=6 if dd else 11+2*ls,Dd=5+2*ls if dd else 0)
 helpers={k:(v+1)//2 for k,v in lookup.items()}
 hc={k:helpers[k] for k in ['L','D','Q','Kv']};hc['S']=helpers['S']+1+int(dd);hc['F']=helpers['F']+1
 if dd:hc['Dd']=helpers['Dd']+1
 hc['Tab']=4
 natural=dict(T=t,Ht=32*t,L=16*t,D=4096*t,Q=4096*t,Kv=1024*t,S=32*t*t,F=16384*t,Tab=256,Dd=32*t*(32 if dd else 1))
 sizes={k:(v if k in ['T','Ht'] else max(v,n)) for k,v in natural.items()}
 logs={k:lg(v) for k,v in sizes.items()}
 planes=[];data={}
 for cm,count,components in [('A',ac,1),('H',hc,2)]:
  logical=[dom for dom,m in count.items() for _ in range(m)]
  widths={'D':[2048*t,1024*t],'F':[8192*t,1024*t]}
  entries=[(i,dom,part,size) for i,dom in enumerate(logical) for part,size in (list(zip(['Wide','Narrow'],widths[dom])) if dom in widths else [('Whole',sizes[dom])])]
  lengths=[max(1,math.ceil(size/n)) for _,_,_,size in entries]
  offsets=[0]+list(accumulate(components*x*n for x in lengths))
  planes.extend(dict(cm=cm,parent=i,domain=dom,part=part,offset=off,log=lg(size),rows=rows) for (i,dom,part,size),off,rows in zip(entries,offsets,lengths))
  data[cm]=offsets[-1]//n
 a0=[1,1,22,2,2,1,1,1,2,2,1,1,1,1,41,15,15,ac['S']+2,16,3,0,1,1]
 h0=[0,0,0,1,0,0,0,0,0,0,0,0,0,0,17,7,7,hc['S'],8,3,1,0,0]
 if dd:a0.append(ac['Dd']+1);h0.append(hc['Dd'])
 base_main=[logs['D'],logs['D'],logs['T'],logs['L'],logs['S'],12,12,12,10,3+lg(t),12,12,12,14,logs['D'],logs['Q'],logs['Kv'],logs['S'],logs['F'],logs['Tab'],logs['Tab'],logs['D'],logs['D']]
 if dd:base_main.append(logs['Dd'])
 degrees=[3,3,3,4,3,2,2,2,3,3,2,2,2,2,4,4,4,4,4,3,2,2,2,4]
 # The true D/F split removes the padded-axis degree increment. Other
 # current domains are unpadded for the indicator-bearing slots.
 slots=[]
 for old in range(len(a0)):
  parts=['Wide','Narrow'] if old in [10,11,12,13,14,18,21,22] else ['Whole']
  for part in parts:
   a,h,ep=a0[old],h0[old],0
   main=base_main[old]
   if old in [0,1]:a=2;main=lg(t)+11
   if old in [5,6,7,11,12]:a=2;main=11
   if old==13:a=2;main=13
   if old in [14,18,21,22]:
    width=(2048 if part=='Wide' else 1024) if old!=18 else (8192 if part=='Wide' else 1024)
    main=lg(t*width)
   if old in [21,22]:ep=1
   slots.append(dict(base=old,part=part,main=main,ext=2 if old in [8,9] else 1,degree=degrees[old],a_sites=a,h_sites=h,endpoint_sites=ep))
 for cm in ['A','H']:
  cursor=data[cm]
  for slot in slots:
   sites=slot[cm.lower()+'_sites'];slot[cm.lower()+'_pairs']=list(range(cursor,cursor+2*sites,2));cursor+=2*sites
  data[cm+'_rows']=cursor+2
 return dict(t=t,dd=dd,fe=fe,n=n,a_data=data['A'],h_data=data['H'],a_rows=data['A_rows'],h_rows=data['H_rows'],m_rows=2*len(slots)+4,endpoint=[24,31,34],planes=planes,slots=slots)
def validate(meta):
 for cm in ['A','H']:
  ps=[p for p in meta['planes'] if p['cm']==cm];factor=1 if cm=='A' else 2
  bands=[(p['offset']//meta['n'],p['offset']//meta['n']+factor*p['rows']) for p in ps]
  if not bands or bands[0][0]!=0 or any(a[1]!=b[0] for a,b in zip(bands,bands[1:])):return False
  data=meta[cm.lower()+'_data'];rows=meta[cm.lower()+'_rows']
  if bands[-1][1]!=data:return False
  pairs=[p for s in meta['slots'] for p in s[cm.lower()+'_pairs']]
  if pairs!=list(range(data,rows-2,2)):return False
  if sum(s[cm.lower()+'_sites'] for s in meta['slots'])*2+data+2!=rows:return False
 # Endpoints retain the middle external spare and both proximity rows.
 if meta['endpoint']!=[24,31,34]:return False
 return len(meta['slots'])==31+int(meta['dd'])
observed=[json.loads(s) for s in (D/'probe.stdout.log').read_text().splitlines()]
native=json.loads((D/'snapshots/owner/NATIVE_INVENTORY_CENSUS.json').read_text())['rows']
builders=json.loads((D/'snapshots/owner/NATIVE_BUILDERS_CENSUS.json').read_text())
summaries=[]
for got in observed:
 ref=reference(got['t'],got['dd'],got['fe'])
 for key in ref:
  if isinstance(ref[key],list):
   check(len(ref[key])==len(got[key]))
   for a,b in zip(ref[key],got[key]):check(a==b)
  else:check(ref[key]==got[key])
 check(validate(got));check(validate(ref))
 nr=next(x for x in native if x['tokens']==got['t'] and x['dd']==got['dd'] and x['f_e']==got['fe'])
 expected=dict(a_rows=got['a_rows'],h_rows=got['h_rows'],m_rows=got['m_rows'],a_planes=sum(p['cm']=='A' for p in got['planes']),h_planes=sum(p['cm']=='H' for p in got['planes']),a_sites=sum(p['a_sites'] for p in got['slots']),h_sites=sum(p['h_sites'] for p in got['slots']),slots=len(got['slots']),joint_external_rows=31,joint_internal_rows=34,a_h_words=(got['a_rows']+got['h_rows'])*got['n'])
 for k,v in expected.items():check(nr[k]==v)
 for key in ['a_rows','h_rows','a_data','h_data']:
  bad=copy.deepcopy(got);bad[key]-=1;check(not validate(bad));negative+=1
 bad=copy.deepcopy(got);bad['planes'][1]['offset']=0;check(not validate(bad));negative+=1
 bad=copy.deepcopy(got);bad['slots'][1]['a_pairs'][0]=bad['slots'][0]['a_pairs'][0];check(not validate(bad));negative+=1
 for i in [0,1,2]:
  bad=copy.deepcopy(got);bad['endpoint'][i]-=1;check(not validate(bad));negative+=1
 # Refuse the earlier 8B R13 numerical assumptions, without treating R14
 # Shieldstral as a new 8B profile.
 check(got['a_rows']!=4577);negative+=1
 summary={k:got[k] for k in ['t','dd','fe','n','a_data','h_data','a_rows','h_rows','m_rows','endpoint']}
 summary.update(expected);summary['vs_base_a_h_word_reduction']=1-expected['a_h_words']/nr['base_a_h_words']
 summary['rowbands']={cm:dict(data=got[cm.lower()+'_data'],claim_mask_rows=2*sum(s[cm.lower()+'_sites'] for s in got['slots']),proximity_rows=2) for cm in ['A','H']}
 summary['endpoint_rowbands']=dict(external=dict(data=[0,24],claim_masks=[24,28],spare=[28,29],proximity=[29,31]),internal=dict(data=[0,24],claim_masks=[24,32],proximity=[32,34]))
 summary['internal_endpoint_group_bounds']=dict(claims=4,possible_groups=[1,2,3,4],rho_counts=[2,3,4,5],max4_dispatch_counts=[1,1,1,2],note='Conservative group bounds only; current native grouping not executed. Never count as two independent external endpoints.')
 if got['fe']==9:
  gr=next(g for g in builders['groups'] if g['base']==nr['base_profile'])
  fold=[]
  for cm,rows,groups in [('A',got['a_rows'],gr['a_groups']),('H',got['h_rows'],gr['h_groups']),('Input',31,gr['input_groups']),('Output',31,gr['output_groups'])]:
   rhos=groups+1;batches=math.ceil(rhos/4)
   widths=[min(4,rhos-i) for i in range(0,rhos,4)]
   check(sum(widths)==rhos);check(max(widths)<=4)
   # Logical source operands only. Pads, device/cache traffic, setup and
   # further PCS phases remain outside this counter, explicitly.
   matrix=rows*batches*got['n']*8;rho=rows*rhos*got['n']*16;out=rhos*got['n']*16
   fold.append(dict(cm=cm,rows=rows,recorded_generic_groups=groups,rhos_including_fresh_proximity=rhos,batch_widths=widths,matrix_row_visits_per_column=rows*batches,rho_memberships_per_column=rows*rhos,logical_matrix_B=matrix,logical_rho_B=rho,logical_output_B=out,logical_total_B=matrix+rho+out,missed_visits_if_proximity_omitted=rows*(batches-math.ceil(groups/4))))
   # Independent dispatch coverage, including 0-group proximity-only edge.
   for g in range(130):
    simulated=[list(range(g+1))[i:i+4] for i in range(0,g+1,4)]
    check([x for chunk in simulated for x in chunk]==list(range(g+1)))
    check(len(simulated)==math.ceil((g+1)/4))
  summary['conditional_generic_group_fold_model']=fold
 summaries.append(summary)
 # Independently partition every physical A/H row, including H real/imag.
 for cm in ['A','H']:
  occupancy=Counter()
  for p in got['planes']:
   if p['cm']!=cm:continue
   start=p['offset']//got['n'];stop=start+p['rows']*(2 if cm=='H' else 1)
   occupancy.update(range(start,stop))
  check(set(occupancy)==set(range(got[cm.lower()+'_data'])))
  check(all(v==1 for v in occupancy.values()))
# Source provenance is checked against BOTH historical census producer and
# the current held build manifest. Drift is evidence, not silently waived.
pin_records=json.loads((D/'native-pins.json').read_text())
provenance=[]
for version in ['sol-r14-builders-2.source.json','sol-r14-actual-build-2.source.json']:
 manifest=json.loads((D/'snapshots/owner'/version).read_text())
 for p in pin_records:
  if '/actual-working-tree/' not in p['path']:continue
  rel=p['path'].split('/actual-working-tree/',1)[1]
  old=manifest['files'].get(rel)
  provenance.append(dict(manifest=version,path=rel,current_sha256=p['sha256'],recorded_sha256=old,equal=(old==p['sha256'])))
  if rel.endswith(('split_layout.rs','shape.rs','layout.rs')):check(old==p['sha256'])
for p in pin_records:
 check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
result=dict(status='PASS',seed=SEED,fixtures=len(observed),assertions=checks,python_negative_controls=negative,extracted_native_negative_controls=132,source_manifest_comparison=provenance,profiles=summaries,scope='Exact public metadata/reference/census comparison; conditional logical operands use historical generic-point group counts. Native define, actual rho vectors, physical traffic, full PCS pads/FS/CUDA/proofs/privacy unrun.',new_verified_full_stack_proofs=0,new_proved_positions=0)
(D/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['profiles','source_manifest_comparison']}))
print('manifest drift',[(p['manifest'],p['path']) for p in provenance if not p['equal']])
print('T128fe9',json.dumps([r for r in summaries if r['t']==128 and r['fe']==9],indent=2)[:4000])
