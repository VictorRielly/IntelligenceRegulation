"""Independent extraction and whole-group cost accounting, no timing projection."""
from pathlib import Path
import hashlib, json, time, resource, statistics
from catalog import Geometry, catalog, schedule, NAMES
HERE=Path(__file__).resolve().parent
start=time.monotonic(); checks=0
def check(c):
 global checks
 assert c;checks+=1
pins=json.loads((HERE/'native-pins.json').read_text())
for p in pins:
 check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
 check(hashlib.sha256((HERE/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
arg=(HERE/'native/hashline__src__private_block__argument.rs').read_text()
expected=arg[arg.index('fn mask_eval('):arg.index('\n/// `cd * plane',arg.index('fn mask_eval('))]
check((HERE/'baseline_mask.rs').read_text()==expected.replace('fn mask_eval(', 'fn baseline_mask_eval(',1)+'\n')
mle=(HERE/'native/zkp-core__src__mle.rs').read_text()
check((HERE/'serial_eq.rs').read_text()==mle[mle.index('pub fn eq_table('):mle.index('/// eq(r, s)')].replace('.par_iter_mut()', '.iter_mut()'))
src=(HERE/'candidate.rs').read_text()
# Review anchors: each reconstruction and fresh private source is present.
anchors=['e.c0.add(e.c1).mul(x.add(*y))','weights.eq.iter().map(|e| e.c0.add(e.c1))',
         'self.weights.eq.iter().zip(&self.sums).zip(xs).zip(ys)',
         's.mul(x.add(*y))','assert_eq!(self.weights.point, point)',
         'assert_eq!(self.weights.eq.len(), xs.len())','assert_eq!(xs.len(), ys.len())',
         'Fp2::new(a.add(b.mul(Fp(7))), c.sub(a).sub(b))']
for a in anchors:check(a in src)
mutation_controls=0
for a in anchors:
 changed=src.replace(a,'MUTATED',1)
 check(any(x not in changed for x in anchors));mutation_controls+=1

rows=[]
old=json.loads((HERE/'prior-counts.json').read_text())
for record in old:
 if record['capacity']!=1:continue
 g=Geometry(**record['geometry']);groups=[]
 for slot,sites in enumerate(catalog(g)):
  for site in schedule(sites):
   if groups and groups[-1]['slot']==slot and groups[-1]['tail']==site.tail:
    groups[-1]['pairs']+=1
   else:groups.append(dict(slot=slot,tail=site.tail,n=1<<len(site.tail),pairs=1))
 m=sum(x['n']*x['pairs'] for x in groups);s=sum(x['n'] for x in groups)
 check(m==record['totals']['paired3_public_sum_additions_baseline'])
 check(s==record['totals']['prepared_public_sum_additions'])
 check(len(groups)==record['totals']['builds'])
 check(2*m==record['totals']['private_base_word_reads'])
 many=[x for x in groups if x['pairs']>1]
 def costs(gs):
  mm=sum(x['n']*x['pairs'] for x in gs);ss=sum(x['n'] for x in gs)
  return dict(eligible_groups=len(gs),eligible_pair_coefficients=mm,prepared_coefficients=ss,
              public_additions_removed=mm-ss,
              additional_source_read_words=2*ss+mm,additional_source_write_words=ss,
              additional_source_access_bytes=8*(3*ss+mm),additional_sum_vec_allocations=len(gs),
              max_added_live_payload_bytes=max([8*x['n'] for x in gs],default=0),
              note='Source-level logical accesses, not DRAM bytes, time or allocator RSS.')
 row=dict(geometry=g.__dict__,baseline_public_additions=m,paired_variable_products_both=3*m,
          private_word_reads_both=2*m,eager=costs(groups),skip_single_use_analytical=costs(many))
 check(row['eager']['public_additions_removed']==row['skip_single_use_analytical']['public_additions_removed'])
 rows.append(row)

# The old small-prime delayed-modulus approach needs a valid size bound.
p=2**64-2**32+1; product=(p-1)**2;max_u128=2**128-1
check(product<=max_u128);check(2*product>max_u128)
delay=dict(canonical_max_product=str(product),max_safe_maximal_products_in_u128=max_u128//product,
           bits_for_16384_maximal_products=(16384*product).bit_length(),
           status='Small-prime single-word packing does not transfer to full canonical Goldilocks operands; wider carry/reduction required.',
           prior_negative='wide-fp2-accumulation-20261004; paired-mask-three-product-20261029 unsafe-u128 premise retained')

probe=json.loads((HERE/'result.json').read_text());summaries=[]
check(probe['status']=='PASS');check(probe['fixtures']==792);check(probe['negative_controls']==10)
for b in probe['bench']:
 check(len(b['cached_paired3_group_ns'])==len(b['prepared_group_ns'])==5)
 a=statistics.median(b['cached_paired3_group_ns']);c=statistics.median(b['prepared_group_ns'])
 summaries.append(dict(row_log=b['row_log'],pairs=b['pairs'],cached_median_ns=a,prepared_median_ns=c,diagnostic_ratio=a/c))
result=dict(status='PASS',checks=checks,static_anchor_mutations=mutation_controls,source_pins=len(pins),
            elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            source_derived_cost_rows=rows,older_technique_size_bound=delay,component_diagnostics=summaries,
            native_source_executed='Extracted mask_eval with stub metadata; frozen Fp/Fp2; extracted serial Eq constructor',
            full_native_define_or_proof=False,model_passes=0,proved_positions=0)
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('source_derived_cost_rows','component_diagnostics')}))
for row in rows:
 if row['geometry']['name']=='Llama3-8B' and row['geometry']['t']==128:print(json.dumps(row))
