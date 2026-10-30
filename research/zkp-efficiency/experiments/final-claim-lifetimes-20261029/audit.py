import hashlib,json,re,resource,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
begin=time.monotonic(); checks=0
def ck(v):
    global checks
    checks+=1
    assert v,checks
pins=json.loads((HERE/'native-pins.json').read_text())
for pin in pins:
    ck(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    ck(hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
arg=(HERE/'native/hashline__src__private_block__argument.rs').read_text()
shape=(HERE/'native/hashline__src__private_block__shape.rs').read_text()
layout=(HERE/'native/hashline__src__private_block__layout.rs').read_text()
core=(HERE/'native/zkp-core__src__mle.rs').read_text()
field=(HERE/'native/zkp-core__src__field.rs').read_text()
tab=arg.split('        SC_TAB => {',1)[1].split('        SC_ZS => {',1)[0]
ck(tab.count('b.a(ids.at(')==3)
ck(tab.count('b.h(th[')==3)
for n in ['A_MU8','A_MEXP','A_MACT']: ck('b.a(ids.at('+n+'))?' in tab)
for n in ['a[SC_TAB] = 3;','h[SC_TAB] = 3;','if sh.log(Dom::Tab) != sh.log_cols']: ck(n in shape)
for n in ['v.extend([Dom::Tab; 3]);','v.extend([Dom::Tab; 4]);']: ck(n in shape)
for n in ['coords: rho(0..log), mask_row, ext_round: 0','self.a_at(plane, rho(0..log), 0)',
          'Cm::A | Cm::H => sh.log_cols','let logm = p.log.min(log_n);',
          'let eq = eq_table_msb(&point[p.log - logm..]);',
          'if p.log < log_n { p.slices[0].0 % n } else { 0 }',
          'row(p.mask_row).add(Fp2::U.mul(row(p.mask_row + 1)))',
          'let mut cur = finals;', 'let mut prev = rho.clone();',
          'Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho))']: ck(n in arg)
ck('fn eval_mle_ext' in core and 'let eq = eq_table_msb(r);' in core)
ck('let rev: Vec<Fp2> = r.iter().rev().copied().collect();' in core)
ck('*b = e.mul(ri);' in core and '*a = e.mul(one_minus);' in core)
ck('pub fn mul_base(self, r: Fp)' in field)

# Independently parse and apply the unified diff in memory only.
patch=(HERE/'mask-tail-weights.unapplied.patch').read_text().splitlines(True)
old=arg.splitlines(True); built=[]; cursor=0; i=2
while i<len(patch):
    m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',patch[i]); ck(bool(m))
    start=int(m[1])-1; built.extend(old[cursor:start]); cursor=start; i+=1
    while i<len(patch) and not patch[i].startswith('@@ '):
        tag,line=patch[i][0],patch[i][1:]
        if tag in ' -': ck(old[cursor]==line); cursor+=1
        if tag in ' +': built.append(line)
        i+=1
built.extend(old[cursor:]); patched=''.join(built)
ck(patched==(HERE/'candidate-argument.rs').read_text())
ck(patched.count('if s == SC_TAB { Some(MaskTailWeights::default()) } else { None }')==1)
ck('None => mask_eval(&sh, p, pd.data[p.cm as usize], &point)' in patched)
# Cached scalar function must be precisely the old body with an eq provider.
original=arg.split('fn mask_eval(',1)[1].split('/// `cd * plane~',1)[0]
cached=patched.split('fn mask_eval_cached(',1)[1].split('/// `cd * plane~',1)[0]
restored=cached.replace('point: &[Fp2], weights: &mut MaskTailWeights)', 'point: &[Fp2])',1).replace('weights.at(&point[p.log - logm..])','eq_table_msb(&point[p.log - logm..])',1)
ck(restored==original)

result=json.loads((HERE/'result.json').read_text()); ck(result['status']=='PASS')
ck(len(result['fixtures'])==102 and len(result['negative_controls'])==13)
counts=[]
for log in (8,13,14):
    n=1<<log
    row={'row_log':log,'row_words':n,'mask_pairs':6,'baseline_eq_builds':6,'candidate_eq_builds':1,
         'baseline_eq_fp2_mul':12*(n-1),'candidate_eq_fp2_mul':2*(n-1),
         'removed_eq_fp2_mul':10*(n-1),'unchanged_mask_row_base_reads':12*n,
         'unchanged_fp2_mul_base':12*n,'unchanged_final_U_fp2_mul':6,
         'baseline_sequential_weight_payload_bytes':16*n,'candidate_retained_weight_payload_bytes':16*n,
         'added_point_payload_bytes':16*log,'worst_hit_point_comparison_fp2':5*log,
         'removed_msb_reverse_point_vectors':5,'removed_eq_vectors':5,
         'new_peak_bytes':None,'native_runtime_gain':None}
    fixture=next(x for x in result['fixtures'] if x['label']==f'SC_TAB:{log}')
    ck(fixture['baseline_eq_mul']==row['baseline_eq_fp2_mul'])
    ck(fixture['candidate_eq_mul']==row['candidate_eq_fp2_mul'])
    counts.append(row)
(HERE/'counts.json').write_text(json.dumps(counts,indent=2)+'\n')
profile=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r4/PHASES_T128.md')
text=profile.read_text()
ck('slot 19 extension rounds (mask_eval + zk.rs) | 0.69' in text)
ck('slot 19 extension rounds (mask_eval + zk.rs) | 0.55' in text)
ck('prove_run 153.072' in text and 'prove_run 135.809' in text)
hist={'path':str(profile),'sha256':hashlib.sha256(profile.read_bytes()).hexdigest(),
      'scope':'historical R4 TinyLlama T128 L22, n=1 shared-box; not 8B; not rerun or reverified',
      'CPU':{'prove_run_s':153.072,'SC_TAB_extension_inclusive_s':0.69,
             'unphysical_free_whole_extension_speedup_ceiling':153.072/(153.072-0.69)},
      'GPU_assisted':{'device':'RTX4070 Laptop','prove_run_s':135.809,'SC_TAB_extension_inclusive_s':0.55,
                      'unphysical_free_whole_extension_speedup_ceiling':135.809/(135.809-0.55)},
      'limitations':'Extension includes all mask-row dots, extension polynomials and CFS work. Only equality preparation is removed; exclusive share unknown. No cross-profile transfer.'}
(HERE/'historical-extension-clocks.json').write_text(json.dumps(hist,indent=2)+'\n')
out={'status':'PASS','checks':checks,'native_source_pins':len(pins),
     'elapsed_s':time.monotonic()-begin,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
     'compiled':False,'patch_applied':False,'model_proofs':0}
(HERE/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
