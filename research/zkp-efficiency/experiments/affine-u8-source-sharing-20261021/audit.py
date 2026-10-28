"""Independent cost recalculation from original native descriptor memberships.

No candidate import. Width derives from exact allowed-set cardinality, rather
than candidate's coefficient formula. Native source pins and mutation controls.
"""
from collections import defaultdict
import copy, hashlib, json, pathlib, resource, time
import native_reference as ref

ROOT=pathlib.Path(__file__).resolve().parent;t0=time.monotonic();checks=0
def check(ok):
    global checks
    checks+=1
    if not ok: raise AssertionError(checks)
pins=json.loads((ROOT/'source-manifest.json').read_text())
for p in pins:
    check(hashlib.sha256(pathlib.Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
    check(hashlib.sha256((ROOT/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
anchors={
 'layout.rs':['fn sym(p: usize) -> [Lk; 2]',
              'Lk { terms: vec![(p, -1)], cst: 127 }',
              'let sigma_scale = 1i64 << (8 * ls as u32 - sh.wrho_s);',
              'v.push(scaled(ids.sg(ls - 1), sigma_scale));'],
 'shape.rs':['self.lookups_per_position(dom).div_ceil(2)',
             'h_rows: h_data_rows + 2 * h_sites + 2,',
             'h[SC_SZC] = self.helpers(Dom::S) + 1 + usize::from(self.dd_cap > 0);',
             'h[SC_DD] = self.helpers(Dom::Dd) + 1;',
             'let h_data_rows: usize = self.h_plane_doms().iter().map(|d| 2 * self.rows_of(*d)).sum();'],
 'argument.rs':['h.mul(d1).mul(d2).sub(d1.add(d2))','None => h.mul(d1).sub(Fp2::ONE),'],
 'protocol.rs':['let lookup_words: u64 = looked.iter().map(|(d, cols)| (cols.len() * sh.size(*d)) as u64).sum();',
                'let mut m_u8 = byte_histogram_at(&looked, lookup_words, HISTOGRAM_PAR_MIN);',
                'tr.absorb(b"M", &mask_root);','let alpha = tr.challenge_fp2();'],
 'core-pcs.rs':['let pads = rng.fp_vec(rows * q);',
                'let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();']}
saved_anchors=[]
for fn,terms in anchors.items():
    text=(ROOT/'source'/fn).read_text()
    for term in terms:
        check(term in text)
        check(term not in text.replace(term,'/* mutation */'))
        saved_anchors.append(dict(file=fn,line=text[:text.index(term)].count('\n')+1,fragment=term))
(ROOT/'source-anchors.json').write_text(json.dumps(saved_anchors,indent=2)+'\n')

costs=json.loads((ROOT/'cost-result.json').read_text())
prior=json.loads((ROOT/'prior-prior-census.json').read_text())
row_savings=[];families=[]
for r in costs:
    fixture=next(x for x in prior if x['model']==r['model'] and x['T']==r['T'] and x['dd']==r['dd'] and x['norm_window']==32 and x['f_e']==9)
    native=ref.native_expressions(r['T'],r['dd']);expected_bits=0;helper_save=0;removed_queries=0
    for d in r['domains']:
        es=native[d['domain']];by_name=defaultdict(list)
        for e in es:by_name[e['terms'][0][0]].append(e)
        width=0
        for name,local in by_name.items():
            allowed=ref.allowed_residues(local)
            minimum_bits=(len(allowed)-1).bit_length();width+=minimum_bits
            families.append(dict(T=r['T'],dd=r['dd'],domain=d['domain'],source=name,
                                 native_affine_queries=local,allowed_cardinality=len(allowed),
                                 chosen_dense_bits=minimum_bits,
                                 extra_endpoint_exclusion=len(allowed)==255))
        check(width==d['source_bit_widths']);check(len(by_name)==d['distinct_original_sources'])
        unique=[]
        for e in es:
            if e not in unique:unique.append(e)
        q_saved=len(es)-len(unique);old_planes=(len(es)+1)//2;new_planes=(len(unique)+1)//2
        save=(old_planes-new_planes)*d['size']*16
        check(save==d['dedup_helper_data_saved_bytes'])
        check(d['native_u8_helper_bytes']==old_planes*d['size']*16)
        check(d['bit_data_bytes']==width*d['size']*8)
        expected_bits+=width*d['size']*8;helper_save+=save;removed_queries+=q_saved*d['size']
    check(expected_bits==r['source_shared_bit_data_bytes'])
    check(helper_save==r['dedup_helper_data_saved_bytes'])
    check(expected_bits/r['native_u8_helper_data_bytes']==r['dense_shared_bits_over_native'])
    for k in ('new_private_mask_words','new_PCS_groups','new_CFS_coefficients','end_to_end_time_saving','physical_peak_saving'):
        check(r[k] is None)
    n=2**fixture['log_cols'];removed_planes=1 if r['T']==128 else 0
    saved_rows=helper_save//(8*n)+2*removed_planes
    ah_bytes=(fixture['a_rows']+fixture['h_rows'])*n*8
    h_bytes=fixture['h_rows']*n*8
    row_savings.append(dict(T=r['T'],dd=r['dd'],log_cols=fixture['log_cols'],
                            assumption='conditional consistent dedup profile; same row width and other sites',
                            removed_query_words=removed_queries,removed_H_planes=removed_planes,
                            removed_H_data_rows=helper_save//(8*n),removed_H_reserved_mask_rows=2*removed_planes,
                            removed_H_total_rows=saved_rows,removed_H_total_data_and_mask_bytes=saved_rows*n*8,
                            baseline_H_rows=fixture['h_rows'],candidate_H_rows=fixture['h_rows']-saved_rows,
                            baseline_AH_bytes=ah_bytes,AH_payload_fraction_saved=saved_rows*n*8/ah_bytes,
                            H_payload_fraction_saved=saved_rows*n*8/h_bytes,
                            full_receipt_bytes_saved=None,full_M_row_change=None,actual_HWM_or_elapsed_saving=None))

# The exact affine descriptor is the sharing key, never a private value.
# Detect source and coefficient edits even when every shape count survives.
original=ref.source;mutations=0
for before,after in [('v.push(scaled(ids.sg(ls - 1), sigma_scale));','v.push(scaled(ids.sg(ls - 1), 2));'),
                     ('v.extend(sym(ids.at(A_Q8)));','v.extend(sym(ids.at(A_K8)));')]:
    check(before in original)
    baseline=ref.native_expressions(128,False)
    ref.source=original.replace(before,after,1);changed=ref.native_expressions(128,False)
    check(sum(map(len,baseline.values()))==sum(map(len,changed.values())))
    check(baseline!=changed);mutations+=1
ref.source=original

# Check signed/unsigned contracts on padded positions as separate conjuncts.
signed=[dict(terms=[['x',1]],cst=127),dict(terms=[['x',-1]],cst=127)]
check(ref.accepts(signed,0));check(ref.accepts(signed,1))
support=[True,False];original_values=[1,0];tampered=[1,1]
def pad_zero(xs):return all(on or x==0 for on,x in zip(support,xs))
check(pad_zero(original_values));check(not pad_zero(tampered))
check(all(ref.accepts(signed,x) for x in tampered))

(ROOT/'source-families.json').write_text(json.dumps(families,indent=2)+'\n')
(ROOT/'dedup-row-cost.json').write_text(json.dumps(row_savings,indent=2)+'\n')
result=dict(status='PASS_INDEPENDENT_SOURCE_AND_COST_AUDIT',checks=checks,pinned_native_files=len(pins),
            exact_source_families=len(families),count_preserving_source_mutations=mutations,
            measured_script_seconds=time.monotonic()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            source_reference='Restricted native source interpreter plus original affine table set intersection',
            native_proof=False,external_review=False)
(ROOT/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));print(json.dumps(row_savings))
