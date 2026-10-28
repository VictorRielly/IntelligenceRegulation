"""Separate source/copy/traffic/incidence audit. No candidate import or native run."""
import difflib,hashlib,json,math,resource,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent
START=time.monotonic();checks=0
def check(ok,label):
    global checks
    checks+=1
    assert ok,label

pins=json.loads((ROOT/'native-pins.json').read_text());sources={};live=[]
for pin in pins:
    b=Path(pin['snapshot']).read_bytes()
    check(hashlib.sha256(b).hexdigest()==pin['sha256'],'snapshot hash')
    now=hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()
    live.append(dict(path=pin['path'],snapshot=pin['sha256'],current=now,unchanged=now==pin['sha256']))
    sources[pin['path']]=b.decode()
def src(branch,suffix):
    return next(v for k,v in sources.items() if k.endswith('/'+branch+'/'+suffix))
a=src('trained-1b','hashline/src/private_block/argument.rs')
p=src('trained-1b','hashline/src/private_block/protocol.rs')
sh=src('trained-1b','hashline/src/private_block/shape.rs')
lay=src('trained-1b','hashline/src/private_block/layout.rs')
block=src('trained-1b','hashline/src/private_block.rs')
field=src('trained-1b','zkp-core/src/field.rs')
for kind,expr in [('exp','k(public.exp[i])'),('act','k(i64::from(ff.act[i]))')]:
    body=f'(0..len).map(|x| x % U8_LEN).map(|i| k(i as i64).add(beta.mul({expr})).add(g_{kind})).collect()'
    check(a.count(body)==1,'native constructor literal '+kind)
    check(body in src('gpu-zerocheck','hashline/src/private_block/argument.rs'),'legacy pair arithmetic same '+kind)
    check(f'table_values_{kind}_at(Dom::Tab.len(),' in a,'wrapper remains frozen length '+kind)
    check(f'b.public(table_values_{kind}_at(tab_len,' in a,'SC_TAB incidence '+kind)
check('let tab_len = sh.size(Dom::Tab);' in a,'lifted SC_TAB shape')
check('for slot in 0..sh.n_slots()' in a and 'let def = define(slot, ctx, &mut pts, tr)?;' in a,'one definition per slot per argument call')
check('while out.len() < len {\n        out.extend_from_within(..);' in a,'existing eq_cube repeats using same native API')
check('Tab::Pub(v) => std::mem::take(v)' in a,'public table already moved; do not count eliminated downstream clone')
check('v.len() != 1usize << n' in a and 'public table length' in a,'existing public length refusal retained')
check('64 => Some(13)' in sh and '128 => Some(14)' in sh,'R12 native context widths')
check('Dom::Tab => clog2(U8_LEN)' in sh,'fixed byte cardinality')
check('domain_log_at(self.natural_log(dom), dom.carries_h_planes(), self.log_cols)' in sh,'lift is shape-driven')
check('pub const U8_LEN: usize = 256;' in lay or 'pub(crate) const U8_LEN: usize = 256;' in lay,'native cardinality pin')
check('act: [i16; 256]' in block and 'exp: Vec<i64>' in block,'native table payload widths')
check('exp.len() != 256' in block,'public exp shape check unchanged')
check('let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;' in p,'all table inverse refusals unchanged')
for kind in ['exp','act']:
    check(f'table_values_{kind}(' in p,'H table helper wrapper stays 256 '+kind)
check('#[derive(Clone, Copy, PartialEq, Eq, Debug, Default, Hash)]' in field,'Fp2 clone is Copy')
candidate=(ROOT/'candidate-argument.rs').read_text()
for fragment in ['Vec::with_capacity(len)','for i in 0..len.min(U8_LEN)','let take = (len - out.len()).min(out.len());','out.extend_from_within(..take);']:
    check(fragment in candidate,'safe candidate bound '+fragment)
check('unsafe' not in candidate[len(a[:a.index('pub(crate) fn table_values_exp_at')]):len(a[:a.index('pub(crate) fn table_values_exp_at')])+650],'no unsafe helper')
rel='ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs'
patch=''.join(difflib.unified_diff(a.splitlines(True),candidate.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel))
check(patch==(ROOT/'row-tiling.patch').read_text(),'unapplied patch matches copied candidate')
check(patch.count('@@ ')==3 or patch.count('@@ ')==2,'patch bounded hunks')

result=json.loads((ROOT/'result.json').read_text())
rows=[]
for r in result['source_api_counts']:
    n=r['length'];q=min(n,256)
    check(r['baseline'].get('mul',0)==n,'old products')
    check(r['candidate'].get('mul',0)==q,'new products')
    check(r['baseline'].get('add',0)==2*n,'old additions')
    check(r['candidate'].get('add',0)==2*q,'new additions')
    check(r['candidate'].get('copy_rows',0)==n-q,'copied rows')
    calls=0;ready=q
    while ready<n:ready+=min(ready,n-ready);calls+=1
    check(r['candidate'].get('copy_calls',0)==calls,'independent copy calls')
    check(r['output_payload_bytes']==16*n,'output payload unchanged')
    # Logical payload loads only: compiler/cache lowering are unknown.
    # exp[i] is i64; act[i] is i16. New copy reads both Fp2 coordinates.
    rows.append(dict(length=n,pair_fp2_products_before=2*n,pair_fp2_products_after=2*q,
        pair_fp2_additions_before=4*n,pair_fp2_additions_after=4*q,
        pair_signed_conversions_before=4*n,pair_signed_conversions_after=4*q,
        pair_output_payload_bytes=32*n,separate_rust_scratch_bytes=0,
        pair_copy_read_bytes=32*(n-q),pair_raw_public_table_loads_before_bytes=10*n,
        pair_raw_public_table_loads_after_bytes=10*q,
        net_extra_pair_logical_read_bytes=22*(n-q),copy_calls_per_constructor=calls,
        private_mask_or_commitment_savings=0))
native=[]
for t,log in [(32,13),(64,13),(128,14)]:
    n=1<<log;d=n-256
    native.append(dict(context=t,log_cols=log,tab_rows=n,layers=32,
       per_block_pair_mul_removed=2*d,per_32_block_argument_mul_removed=64*d,
       per_block_pair_copy_reads_bytes=32*d,per_32_block_argument_copy_reads_bytes=1024*d,
       per_block_pair_net_extra_logical_reads_bytes=22*d,
       scope='R12 one SC_TAB definition pair per block per argument invocation. Prove and each verify counted separately; no pass or elapsed measurement. R13 LOW+h24 excluded.'))
out=dict(status='PASS_SOURCE_AND_COST_AUDIT_ONLY',checks=checks,native_pins=len(pins),
    live_source_status=live,source_count_rows=rows,native_incidence=native,
    zero_gain_scope='H helper wrappers build 256 rows; no arithmetic removed there. Existing public move already avoids downstream clone. No private helper/scan/fold/inversion/PCS/mask/receipt work removed.',
    negative='More logical reads, not fewer: copying 16-byte Fp2 replaces hot 8-byte exp or 2-byte act loads. No peak memory/output size reduction. Machine code and full critical-path share unknown.',
    memory='Candidate Rust reserves one unchanged destination Vec, no zero fill and no second prefix. Vec allocation capacity/allocator metadata/compiler temporaries unmeasured. Python slice allocation is model-only.',
    elapsed_seconds=time.monotonic()-START,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
(ROOT/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k not in ['source_count_rows','live_source_status']},indent=2))
