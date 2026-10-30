from pathlib import Path
from collections import Counter,defaultdict
import json,time,resource,statistics
import model,legacy_catalog
D=Path(__file__).resolve().parent;t=time.monotonic();checks=0
def ck(v,label):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
raw=json.loads((D/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows'];seen=set();out=[]
shape=(D/'native/hashline/src/private_block/shape.rs').read_text()
ck('const LIMBS_ISQRT: usize = 3;' in shape,'actual isqrt limbs')
ck('tzc + 15 + 2 * 2 + 4 * 2 + if self.dd_cap > 0 { 2 } else { 0 }' in shape,'native a_groups formula')
ck('8 + 1 + usize::from(self.dd_cap > 0)' in shape,'native h_groups formula')
for row in raw:
 key=row['profile'],row['f_e']
 if key in seen:continue
 seen.add(key);g=model.geometry(row);groups=defaultdict(dict);sites=Counter()
 for slot in legacy_catalog.catalog(g):
  for p in slot:
   k=p.slot,p.tail,p.c0,1<<len(p.tail)
   groups[p.cm][k]=dict(log_tail=len(p.tail),sum=False,row=p.row);sites[p.cm]+=1
 ck(sites['A']==row['a_sites'] and sites['H']==row['h_sites'],'source census sites')
 groups['H'][('sum',)]=dict(log_tail=0,sum=True,row=g.row)
 # Independent declared group count from native Shape methods (not constructor execution).
 tpad=1<<legacy_catalog.lg(g.t);n=1<<g.row
 tz=1 if tpad>=n else len({(k*tpad)%n for k in range(9)}|{0})
 ck(len(groups['A'])==tz+27+(2 if g.dd else 0),'A declared/source-derived groups')
 ck(len(groups['H'])==9+bool(g.dd),'H declared/source-derived groups')
 costs={}
 for cm,keys in groups.items():
  vals=list(keys.values());eqs=[x for x in vals if not x['sum']];entries=sum(1<<x['log_tail'] for x in eqs)
  costs[cm]=dict(groups=len(vals),column_payload_bytes_removed=sum(16*(1<<x['row'])for x in vals),
    eq_builds_removed=len(eqs),eq_payload_bytes_removed=16*entries,
    reverse_point_bytes_removed=sum(16*x['log_tail']for x in eqs),
    source_fp2_products_removed=sum(2*((1<<x['log_tail'])-1)for x in eqs),
    nonempty_allocations_removed=len(vals)+len(eqs)+sum(x['log_tail']>0 for x in eqs),
    histogram=dict(Counter('sum' if x['sum'] else str(x['log_tail'])for x in vals)))
 out.append(dict(profile=row['profile'],f_e=row['f_e'],tokens=g.t,dd=bool(g.dd),costs=costs,
   a_rows_retained=row['a_rows'],h_rows_retained=row['h_rows'],
   ah_column_payload_bytes_removed=costs['A']['column_payload_bytes_removed']+costs['H']['column_payload_bytes_removed'],
   ah_fp2_products_removed=costs['A']['source_fp2_products_removed']+costs['H']['source_fp2_products_removed'],
   scope='Per core block metadata, not executed native constructor/opening, bytes moved, native peak or time. In/Out are per-site contributions; joined internal boundary has both adjacent sites. No layer multiplier applied. Accidental key collisions are refused by native declared group checks.'))
(D/'costs.json').write_text(json.dumps(out,indent=2)+'\n')
r=json.loads((D/'result.json').read_text());bench=[]
for b in r['bench']:
 ck(b['candidate_allocs']<b['baseline_allocs'],'compiled allocation reduction')
 ck(b['baseline_requested_bytes']-b['candidate_requested_bytes']>=b['column_payload_bytes'],'payload/allocation accounting')
 bench.append(dict(log_cols=b['log_cols'],ratio_of_helper_medians=statistics.median(b['baseline_ns'])/statistics.median(b['candidate_ns']),allocations_removed=b['baseline_allocs']-b['candidate_allocs'],requested_bytes_removed=b['baseline_requested_bytes']-b['candidate_requested_bytes']))
sized=[]
for b in r['sized']:
 dd=b['label'].startswith('DD-');cm=b['label'].split('-')[-1]
 row=next(x for x in out if '8b-t128' in x['profile'] and x['f_e']==9 and x['dd']==dd)
 c=row['costs'][cm]
 ck(b['groups']==c['groups'],'sized current group count')
 ck(b['rows']==row[cm.lower()+'_rows_retained'],'sized current row count')
 ck(b['baseline_group_allocs']-b['candidate_group_allocs']==c['nonempty_allocations_removed'],'compiled exact removed allocation count')
 removed=b['baseline_group_requested_bytes']-b['candidate_group_requested_bytes']
 ck(removed==c['column_payload_bytes_removed']+c['eq_payload_bytes_removed']+c['reverse_point_bytes_removed'],'compiled exact removed payload request bytes')
 sized.append(dict(label=b['label'],ratio_of_group_rhos_drop_medians=statistics.median(b['baseline_group_plus_rhos_drop_ns'])/statistics.median(b['candidate_group_plus_rhos_drop_ns']),allocation_calls_removed=c['nonempty_allocations_removed'],cumulative_requested_bytes_removed=removed,scope='Synthetic public descriptors/current row counts and fresh synthetic values. Grouping+rhos+drop only; no actual matrix fold, FS hash, native proof or GPU.'))
result=dict(status='PASS',checks=checks,registry_rows=len(raw),distinct_profile_precision_rows=len(out),bench=bench,sized=sized,
 eliminated='Only unused dense column weights in prover grouping, their Eq/reversal temporaries and copies. Row weights, full key validation/group order, masks/pads/salts, all commitment reads/NTT/hash/folds/transfers/openings remain.',
 added_costs='One bool branch per new group and empty Vec header in existing tuple; verifier path retains true columns. Native compiler optimization/allocator/parallel behavior and retained cache capacity unmeasured.',
 ceiling='N/(T-C_exclusive_removed+A_added); speedup=1/((1-f)+f/k); f and native k unknown. Free deletion of exclusive fraction f <=1/(1-f). No numeric native/GPU/token forecast.',
 elapsed_s=time.monotonic()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 full_stack_proofs=0,model_passes=0,proved_positions=0,startup_fraction=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,steady_tokens_per_s=None,total_tokens_per_s=None)
(D/'account-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
