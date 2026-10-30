"""Independent source/extraction/registry/count audit. No model/cache import."""
from pathlib import Path
import hashlib,json,re,resource,time
HERE=Path(__file__).resolve().parent;start=time.monotonic();checks=0
def ck(ok,label=''):
 global checks
 checks+=1
 if not ok:raise AssertionError((checks,label))
pins=json.loads((HERE/'native-pins.json').read_text())
for p in pins:
 ck(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'],'live pin')
 ck(hashlib.sha256((HERE/p['snapshot']).read_bytes()).hexdigest()==p['sha256'],'snapshot pin')
shape=(HERE/'native/shape.rs').read_text();compiled=(HERE/'metadata.rs').read_text()
for p in json.loads((HERE/'extraction.json').read_text())['methods']:
 # Same body appears once inside each source; compare exact source window.
 name=p['name'];start1=re.search(r'(?m)^    (?:pub\(crate\) )?fn '+name+r'\(',shape).start()
 start2=re.search(r'(?m)^    (?:pub\(crate\) )?fn '+name+r'\(',compiled).start()
 native=shape[start1:start1+p['bytes']];adapter=compiled[start2:start2+p['bytes']]
 ck(native==adapter);ck(hashlib.sha256(native.encode()).hexdigest()==p['sha256'])
 # Mutation must invalidate the exact-source guarantee even if counts agree.
 changed=adapter.replace('self.','self /* mutation */ .',1)
 ck(changed!=adapter and hashlib.sha256(changed.encode()).hexdigest()!=p['sha256'])
rows=json.loads((HERE/'counts.json').read_text());data=json.loads((HERE/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows']
registry={}
names=dict(re.findall(r'pub\(crate\) const (R13_\w+): &str = "([^"]+)";',shape))
for block in re.findall(r'AccuracyProfile\{([^\n]+)\}',shape):
 ident=re.search(r'profile:(R13_\w+)',block)
 if not ident:continue
 ns={k:int(v) for k,v in re.findall(r'(tokens|width|hidden|q_heads|head_dim|kv_heads|log_cols):(\d+)',block)}
 ns['h24']='Stack::LowH24' in block;registry[names[ident[1]]]=ns
ck(len(registry)==12)
for row in rows:
 g=row['geometry'];native=registry[g['name']]
 for a,b in [('t','tokens'),('d','width'),('f','hidden'),('h','q_heads'),('dh','head_dim'),('kv','kv_heads'),('row','log_cols'),('h24','h24')]:ck(g[a]==native[b],a)
 ck(g['endpoint']==g['row']);ck(g['ls']==((g['t']-1).bit_length()+row['f_e']+7)//8)
 matches=[r for r in data if r['profile']==g['name'] and r['f_e']==row['f_e']]
 ck(len(matches)==4)
 # Independent row-count arithmetic, including endpoints not in A/H totals.
 ck(row['totals']['sites']==matches[0]['a_sites']+matches[0]['h_sites']+2)
 totals={k:0 for k in row['totals']}
 for slot in row['slots']:
  ck(slot['sites']==sum(slot['counts'].values()))
  ck(slot['sites']==sum(slot['tail_logs'].values()))
  M=sum((1<<int(log))*n for log,n in slot['tail_logs'].items())
  ck(slot['private_base_word_reads']==2*M)
  ck(slot['baseline_eq_mul']==2*M-2*slot['sites'])
  ck(slot['hits']+slot['builds']==slot['sites'])
  ck(slot['candidate_eq_mul']==2*slot['prepared_public_sum_additions']-2*slot['builds'])
  ck(slot['paired3_public_sum_additions_baseline']==M)
  ck(slot['max_entry_bytes']==16*max(1<<int(k) for k in slot['tail_logs']))
  for k in totals:totals[k]+=slot[k]
 ck(totals==row['totals'])
 M=totals['private_base_word_reads']//2;S=totals['prepared_public_sum_additions'];cost=row['costs']
 ck(cost['all_private_base_word_reads']==2*M);ck(cost['baseline_four_variable_products']==4*M)
 ck(cost['paired3_variable_products']==3*M);ck(cost['prepared_sum_added_logical_access_bytes']==8*(3*S+M))
 ck(cost['prepared_sum_removed_additions']==M-S)
 ck(cost['physical_bytes'] is None and cost['enclosing_time_saved'] is None)

arg=(HERE/'native/argument.rs').read_text();accuracy=(HERE/'native/argument_accuracy.rs').read_text()
# Coordinates/reservations preserved by original builder calls. The metadata
# model is not executing B::finish, native refusal or the masking protocol.
anchors=[(arg,'let eq = eq_table_msb(&point[p.log - logm..]);'),
 (arg,'row(p.mask_row).add(Fp2::U.mul(row(p.mask_row + 1)))'),
 (arg,'Tab::Priv(p) if p.ext_round == m => mask_eval'),
 (arg,'if self.ak != self.lay.a_sites()[self.slot] || self.hk != self.lay.h_sites()[self.slot]'),
 (accuracy,'let idx=b.a_range(range.start,range.end-1)?;'),
 (accuracy,'cf[log-lg(sh.head_dim)]=Coord::Flip(log-lg(sh.head_dim));'),
 (accuracy,'let id=b.a_slice(lay.a_off[ids.at(A_D)],lt,rho(0..lt),0)?;'),
 (accuracy,'let imx = b.a_slice(lay.a_off[ids.at(A_MX)], lht, rho(0..lht), 0)?;'),
 (accuracy,'let isum=b.a_slice(lay.a_off[ids.at(A_SUM)],lht,rho(0..lht),0)?;')]
for text,anchor in anchors:
 ck(anchor in text,anchor);ck(anchor not in text.replace(anchor,'AUDIT_MUTATION'))
result=dict(status='PASS',checks=checks,source_pins=len(pins),unchanged_extracted_methods=6,
 source_anchor_mutations=len(anchors),exact_source_method_mutations=6,registry_geometries=12,
 census_geometries=len(rows),elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 native_constructor_or_define_executed=False,native_receipts_verified=False,external_review=False)
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
