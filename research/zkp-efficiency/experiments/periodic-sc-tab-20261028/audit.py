"""Independent source/extent/count audit; does not import candidate."""
import hashlib,json,resource,time
from pathlib import Path
E=Path(__file__).resolve().parent;start=time.monotonic();checks=0
def check(ok,label):
    global checks
    checks+=1
    assert ok,label
pins=json.loads((E/'native-pins.json').read_text());src={};live=[]
for p in pins:
    b=Path(p['snapshot']).read_bytes();check(hashlib.sha256(b).hexdigest()==p['sha256'],'snapshot hash')
    current=hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()
    live.append({'path':p['path'],'pinned':p['sha256'],'current':current,'unchanged':current==p['sha256']})
    src[p['path'].split('/trained-1b/')[1]]=b.decode()
a=src['hashline/src/private_block/argument.rs'];sh=src['hashline/src/private_block/shape.rs'];l=src['hashline/src/private_block/layout.rs'];p=src['hashline/src/private_block/protocol.rs'];r=src['zkp-core/src/sumcheck/rounds.rs']
section=a[a.index('        SC_TAB => {'):a.index('        SC_ZS => {')]
for fragment in ['b.eq(&tau, 0);','let tab_len = sh.size(Dom::Tab);','b.public(table_values_u8_at(tab_len, g_u8));','b.public(table_values_exp_at(tab_len, ctx.public, beta, g_exp));','b.public(table_values_act_at(tab_len, ctx.ff, beta, g_act));','pz.add(si, &[1, 4, 7], zeta);','pz.add(si, &[2, 5, 8], zeta);','tab_group_is_declared(sh, ids,','b.finish(Box::new(poly), vec![])']:
    check(fragment in section,'native SC_TAB '+fragment)
check(section.count('b.a(')==3 and section.count('b.h(')==3,'six private term sites')
check(section.count('b.public(')==3,'three public periodic factors')
for kind in ('u8','exp','act'):
    pos=a.index('pub(crate) fn table_values_'+kind+'_at');body=a[pos:a.index('\n}',pos)+2]
    check('% U8_LEN' in body,'repeat original 256 '+kind)
for fragment in ['Tab::Pub(v) => std::mem::take(v)','v.len() != 1usize << n','public table length','Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho))','_ => Fp2::ZERO,','*v = masked_terminal(*v, *x, e);','e.is_zero() || *e == Fp2::ONE','zero CFS mask challenge','tab_group_is_declared']:
    check(fragment in a,'native contract '+fragment)
check('None };' in a or 'else { None }' in a,'host/standalone starts without exact claim')
check('if kind == SlotKind::Private' in a and 'Some(scalar.sub(c.mul(mask.total())))' in a,'SC_TAB no generic initial total')
for fragment in ['SC_TAB | SC_ZS => Dom::Tab','let ext = if s == SC_SCORE || s == SC_PV { 2 } else { 1 };','a[SC_TAB] = 3;','h[SC_TAB] = 3;','64 => Some(13)','128 => Some(14)','Dom::Tab => clog2(U8_LEN)']:
    check(fragment in sh,'shape '+fragment)
check('pub(crate) const SC_TAB: usize = 19;' in l,'slot index19')
check('most-significant-bit' in r and 'let (lo, hi) = tb.split_at_mut(half);' in r,'MSB split')
check('tables.iter().all(|t| t.len() == len)' in r,'dense-only native driver requires adapter')
check('alpha.sub(*t)' in p and 'inverses(tv.iter()' in p,'whole table inversion stays')
check('zeta^0, zeta^1, ..' in a and 'ACROSS the groups' in a,'six ordered pad powers')

cost=[]
for n in (8,9,10,13,14):
    N=1<<n
    # Independently enumerate every native fold length, not candidate counters.
    dense=sum(1<<i for i in range(n));compact=sum(1<<i for i in range(8))
    check(dense==N-1,'geometric native fold sum');check(compact==255,'short suffix folds')
    fulltables=10+int(n>8)
    row={'n':n,'rows':N,'scope':'R12 SC_TAB public factors only; synthetic n9/n10 are not admitted profiles',
      'public_words_before':3*N,'public_words_after':768,'public_payload_before_bytes':48*N,'public_payload_after_bytes':12288,
      'public_payload_saved_bytes':48*(N-256),'public_fold_lerps_before':3*dense,'public_fold_lerps_after':3*compact,
      'public_fold_lerps_removed':3*(dense-compact),'descriptor_noop_binds':3*(n-8),
      'unchanged_logical_round_endpoint_calls':6*(N-1),'full_slot_initial_payload_before_bytes':16*N*fulltables,
      'full_slot_initial_payload_after_bytes':16*N*(fulltables-3)+12288,
      'exp_act_source_products_before':2*N,'exp_act_source_products_after':512,
      'public_main_cube_reduction':0,'private_mask_opening_commitment_reduction':0,
      'per_32_block_argument_cumulative_removed_public_lerps':96*(N-256),
      'per_32_block_argument_cumulative_removed_public_payload_bytes':1536*(N-256)}
    check(row['full_slot_initial_payload_before_bytes']-row['full_slot_initial_payload_after_bytes']==row['public_payload_saved_bytes'],'full slot payload crosscheck')
    cost.append(row)
model=json.loads((E/'result.json').read_text());check(model['native_proofs']==0,'no native proof counted');check(model['full_slot_cases']==6,'bounded actual polynomial cases');check(model['rounds']==54,'complete schedules')
out={'status':'PASS_SOURCE_AND_COST_ONLY','checks':checks,'native_pins':len(pins),'live_pins':live,'cost':cost,
     'negative':'SC_TAB round cube, all private/equality/support tables and generic per-cell polynomial work remain. Existing public vector move already avoids clone. Adapter dispatch/indices and typed metadata added; no complete proof gain measured.',
     'native_integration_owed':['Tab variant and fresh constructors','exact full-cube length validation on both sides','heterogeneous ClosureRounds explicit cube, n and table order','table build/move','census/capture labels and readers','public terminal evaluator with every zero-extension selector','six private terms/pad-zero group completeness','CFS RNG/transcript/claims/openings/refusals/golden/fresh verify/privacy gates'],
     'ceiling':'Unknown exclusive critical-path fraction f: even free deletion <=1/(1-f); actual gain subtracts descriptor costs and only removes a subset. No 50/s projection.',
     'elapsed_seconds':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
(E/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k not in ('live_pins','cost')}))
