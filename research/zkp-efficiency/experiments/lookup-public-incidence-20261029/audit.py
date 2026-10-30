"""Independent provenance, source-mutation and accounting audit; no candidate import."""
from pathlib import Path
import hashlib,json,resource,time
import source_reference as ref
HERE=Path(__file__).resolve().parent;start=time.monotonic();checks=0
def check(ok):
    global checks
    checks+=1
    if not ok:raise AssertionError(checks)
pins=json.loads((HERE/'native-pins.json').read_text())
for x in pins:
    check(hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'])
    check(hashlib.sha256((HERE/x['snapshot']).read_bytes()).hexdigest()==x['sha256'])
text=(HERE/'native/accuracy_layout.rs').read_text()
p=dict(q=15,k=15,v=16,score=18,pv=12,ao=21,down=20,up=12)
baseline=ref.catalog(True,False,16,p,18,text)
mutations=[('bytes(Limbs::Y,None)?','bytes(Limbs::X,None)?'),
           ('bytes(Limbs::Rv,Some(p.v))?','bytes(Limbs::Rv,Some(p.k))?'),
           ('bytes(Limbs::Sg,Some(wrho_s))?','bytes(Limbs::Sg,Some(p.f_p+1))?'),
           ('bytes(Limbs::Up,None)?','bytes(Limbs::Ru,None)?')]
for a,b in mutations:
    check(text.count(a)==1)
    mutated=ref.catalog(True,False,16,p,18,text.replace(a,b))
    check({d:len(v) for d,v in baseline.items()}=={d:len(v) for d,v in mutated.items()})
    check(mutated!=baseline)
rows=json.loads((HERE/'cost-result.json').read_text())
for row in rows:
    seen={};mib=2**20
    wrho=7+row['f_e'];ls=(wrho+7)//8
    # Independent analytic baseline counts from the shape's R13 branch.
    sizes=dict(L=16384,D=524288,Q=524288,Kv=131072,S=524288,F=2097152,Dd=131072)
    lpp=dict(L=2,D=34,Q=14,Kv=14,F=14,S=6 if row['dd'] else 11+2*ls,Dd=5+2*ls if row['dd'] else 0)
    query_count=sum(sizes[d]*n for d,n in lpp.items())
    saved=mib+(2*(mib if row['dd'] else 4*mib) if row['f_e']==9 else 0)
    check(query_count==row['source_census_byte_queries'])
    check(query_count*8==row['baseline_looked_bytes'])
    check(saved==row['avoided_materialized_bytes'])
    check(row['unique_prepared_bytes']==query_count*8-saved)
    for domain in row['domains']:
        d=domain['domain'];check(domain['logical_columns']==lpp[d]);check(domain['domain_positions']==sizes[d])
        check(domain['prepared_bytes']+domain['avoided_materialized_bytes']==domain['logical_bytes'])
    for key in ['modeled_H_rows_delta','modeled_A_rows_delta','modeled_M_rows_delta','modeled_masks_removed','modeled_helper_planes_delta','intended_receipt_bytes_delta']:
        check(row[key]==0)
    check(row['actual_receipt_bytes_delta'] is None and not row['native_receipt_byte_identity_verified'])
    check(row['physical_peak_bytes_delta'] is None and row['exclusive_elapsed_fraction'] is None and row['end_to_end_gain'] is None)

# Scope/source anchors: data/preparation only; production still has its own
# helper schedule, table poles, fresh masks, refusal gates and explicit drop.
protocol=(HERE/'native/protocol.rs').read_text();arg=(HERE/'native/argument.rs').read_text()
anchors=['a.wrapping_add(c.wrapping_mul(wit.planes[*p][x]))',
         'fn u8_misses_of(', 'fn byte_histogram_at(',
         'let u8_inv = u8_denominator_inverses(alpha, g_u8);',
         'Some(second) => helper_pair_inverses_u8(&cols[2 * k], second, alpha, g_u8, &u8_inv)?',
         'drop(looked);']
for a in anchors:check(a in protocol)
check('for k in 0..lks.len().div_ceil(2)' in arg)
check('h.mul(d1).mul(d2).sub(d1.add(d2))' in arg)
check('p.v += 8;' in (HERE/'native/accuracy_precision.rs').read_text())
check('p.pv += 3;' in (HERE/'native/accuracy_precision.rs').read_text())
check('wrho_s.div_ceil(8) as usize!=ls' in text)
check('v.push(Lk{terms:vec![(self.limb(g,count-1),1i64<<(8*count as u32-bits))],cst:0});' in text)

result=dict(status='PASS',checks=checks,source_pins=len(pins),count_preserving_source_mutations=len(mutations),
            elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            native_code_executed=False,external_review=False,
            limits='Source reader, synthetic algebra, public geometry accounting only; not native constructor, RNG, transcript, PCS, receipt or privacy validation.')
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
