"""Source/shape/scope audit independent of candidate execution."""
import hashlib,json,resource,time
from pathlib import Path
E=Path(__file__).resolve().parent;start=time.monotonic();checks=0
def check(ok,label):
    global checks
    checks+=1
    if not ok:raise AssertionError(label)
src={};pins=json.loads((E/'native-pins.json').read_text());live=[]
for pin in pins:
    b=Path(pin['snapshot']).read_bytes();check(hashlib.sha256(b).hexdigest()==pin['sha256'],'snapshot pin')
    now=hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()
    live.append({'path':pin['path'],'pinned':pin['sha256'],'current':now,'unchanged':now==pin['sha256']})
    src[pin['path'].split('/trained-1b/')[1]]=b.decode()
a=src['hashline/src/private_block/argument.rs'];s=src['zkp-core/src/sumcheck.rs'];t=src['zkp-core/src/transcript.rs'];z=src['hashline/src/zk.rs'];sh=src['hashline/src/private_block/shape.rs']
for fragment in ['n_vars * degree + 2','coeffs[2 + j * self.degree + (e - 1)]','w[0] = Fp2::from_u64(1u64 << n_vars);','w[1] = Fp2::ONE;','let scale = Fp2::from_u64(1u64 << (n - 1 - j));','self.coeffs[1].mul(prod_prev).mul(xv)','fin.add(rho_k.mul(ext.sub(fin)))','if s[0].add(s[1]) != claim','if proof.rounds.len() != n_rounds','if s.len() != degree + 1']:
    check(fragment in s,'CFS/round contract '+fragment)
for fragment in ['h.update(b"hashline-v1/");','h.update(&(label.len() as u64).to_le_bytes());','h.update(&(data.len() as u64).to_le_bytes());','h.update(b"squeeze");','h.update(&self.counter.to_le_bytes());','self.counter += 1;','b[..16]','b[16..]','m.note_challenge(r);','label == b"sc-round"','key: tr.key']:
    check(fragment in t,'transcript contract '+fragment)
for fragment in ['SlotKind::Standalone => c.mul(mask.total())','let unmasked_claim = if kind == SlotKind::Private','} else { None };','let mut prev = rho.clone();','Tab::Priv(p) if p.ext_round == m','_ => Fp2::ZERO,','*v = masked_terminal(*v, *x, e);','prev.push(e);','Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho))','let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());','CfsMask::eval_weights(&rho_full, degree)','sum_weights(&sh, s).iter().map(|w| w.mul(c))']:
    check(fragment in a,'slot contract '+fragment)
guard=a.index('if es.iter().any(|e| e.is_zero() || *e == Fp2::ONE)')
term=a.index('tr.absorb_fp2(b"pb-term", &terms);');check(guard<term,'terminal refusal before term absorption')
check(a.index('if c.is_zero()')<a.index('let (scalar, rho, es, terms, g_val)'),'zero CFS refused before proving')
check('let logm = p.log.min(log_n);' in a and 'point[p.log - logm..]' in a,'reserved pair tail geometry')
check('for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate()' in a and 'coef: cm.mul(u)' in a,'both reserved pair coordinates')
slot=a[a.index('        SC_TAB => {'):a.index('        SC_ZS => {')]
for frag in ['b.eq(&tau, 0);','b.a(ids.at(A_MU8))?;','b.h(th[0])?;','b.public(table_values_u8_at(tab_len, g_u8));','pz.add(si, &[1, 4, 7], zeta);','pz.add(si, &[2, 5, 8], zeta);','b.finish(Box::new(poly), vec![])']:
    check(frag in slot,'SC_TAB '+frag)
check(slot.count('b.a(')==3 and slot.count('b.h(')==3,'six ordered private sites')
check('let gk = mask.round(prev.len(), prev);' in z,'extension uses full mask round')
check('let ext = if s == SC_SCORE || s == SC_PV { 2 } else { 1 };' in sh,'SC_TAB one extension')
native_tests=src['zkp-core/src/sumcheck/rounds/tests.rs']
check('masked_transcripts_and_one_or_two_extension_rounds_match' in native_tests,'native dense masked tests already exist')
check('Periodic' not in native_tests,'native tests do not cover this periodic adapter')
r=json.loads((E/'result.json').read_text());check(r['native_proofs']==0 and len(r['cases'])==6,'scope')
for case in r['cases']:
    n=case['n'];check(case['full_mask_variables']==n+1,'full mask dimensions');check(case['mask_coefficients']==3*(n+1)+2,'full coefficients')
    check(case['recoveries']==n-1,'standalone first round not recovered')
    fn=E/f"synthetic-n{n}-key{int(case['keyed'])}-rounds.bin";b=fn.read_bytes()
    check(hashlib.sha256(b).hexdigest()==case['round_sha256'] and len(b)==case['synthetic_round_bytes'],'synthetic wire pin')
cost=[]
for n in (13,14):
    cost.append({'slot':'R12 SC_TAB','n':n,'full_mask_variables':n+1,'mask_coefficients_before':3*(n+1)+2,'mask_coefficients_after':3*(n+1)+2,'private_claims_before':6,'private_claims_after':6,'public_words_before':3*(1<<n),'public_words_after':768,'logical_public_payload_removed_bytes':48*((1<<n)-256),'public_lerps_removed':3*((1<<n)-256),'generic_round_cube_before':1<<n,'generic_round_cube_after':1<<n,'native_elapsed_saving':None})
out={'status':'PASS_SOURCE_AND_SCOPE_AUDIT','checks':checks,'live_pins':live,'cost':cost,'elapsed_seconds':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'limits':'String/extent/source-count audit only; no native executable. Key/domain/prelude/rows are synthetic. Reserved mask row width8 fixtures are not current R12 widths13/14. No actual source mutation, capture, PCS, RNG or privacy acceptance.'}
(E/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k not in ('live_pins','cost')}))
