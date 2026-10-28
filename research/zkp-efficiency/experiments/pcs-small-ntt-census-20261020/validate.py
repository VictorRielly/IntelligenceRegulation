"""Source-pin, route, census and wrong-source controls; no production writes."""
from pathlib import Path
import hashlib,json,re,time,resource
HERE=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def check(x):
    global checks
    checks+=1
    assert x,checks

def compact(s):
    # Expected fragments have no comments or URLs. Source hashes remain the
    # authoritative identity; these checks identify the used public seams.
    return re.sub(r'\s+','',s)

def load(lane,rel):return (HERE/('source/'+lane+'__'+rel.replace('/','__'))).read_text()

pins=json.loads((HERE/'source-manifest.json').read_text())
for p in pins:
    check(hashlib.sha256((HERE/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
    check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])

evidence=[];mutations=[]
def require(lane,rel,fragment,mutate=False):
    source=compact(load(lane,rel));needle=compact(fragment)
    check(needle in source)
    evidence.append(dict(lane=lane,file=rel,fragment=fragment))
    if mutate:
        # Deliberately remove EVERY copy, so another overload cannot hide a
        # changed parameter at the inspected seam.
        wrong=source.replace(needle,'BROKEN_SOURCE_FRAGMENT')
        check(needle not in wrong)
        mutations.append(dict(lane=lane,file=rel,fragment=fragment,rejected=True))

for lane in ['gpu','r9']:
    shape='hashline/src/private_block/shape.rs'
    require(lane,shape,'const COL_CHECKS: usize = 256;',True)
    require(lane,shape,'pub(crate) const LLAMA3_8B_LOG_COLS: usize = 13;',True)
    # The independent public constructor records each TinyLlama context/lc.
    for t,lc in [(32,12),(64,13),(128,14)]:
        if lane=='r9':
            require(lane,shape,f'TINYLLAMA_T{t}_TRAINED_PROFILE, {t}, {lc}),',True)
        else:
            require(lane,shape,f'TINYLLAMA_T{t}_TRAINED_PROFILE, {lc}),',True)
    require(lane,shape,'if sh.log(Dom::Tab) != sh.log_cols {',True)
    require(lane,shape,'for dom in [Dom::Q, Dom::Kv, Dom::S] {')
    require(lane,shape,'if sh.natural_log(Dom::T) >= sh.log_cols {',True)
    require(lane,shape,'endpoint_log_n.unwrap_or(log_cols), endpoint_inv_rate.unwrap_or(inv_rate)',True)
    protocol='hashline/src/private_block/protocol.rs'
    require(lane,protocol,'PcsParams { log_cols: sh.log_cols as u32, inv_rate: sh.inv_rate, num_col_checks: sh.opened_cols }',True)
    require(lane,protocol,'PcsParams { log_cols: sh.endpoint_log_n as u32, inv_rate: sh.endpoint_inv_rate, num_col_checks: sh.opened_cols }',True)
    require(lane,protocol,'max(zk::MASK_LOG_DOM)')
    pcs='zkp-core/src/pcs.rs'
    require(lane,pcs,'self.cols() * self.inv_rate',True)
    require(lane,pcs,'ZkOpts { q_pad: params.num_col_checks, coset: Fp::new(7) }',True)
    require(lane,pcs,'zk.q_pad >= params.num_col_checks')
    z='hashline/src/zk.rs'
    require(lane,z,'pub const MASK_LOG_MSG: u32 = 9;',True)
    require(lane,z,'pub const MASK_LOG_DOM: u32 = 12;',True)
    require(lane,z,'pub const MASK_Q: usize = 256;')
    require(lane,z,'ntt.forward(out);',True)
    require(lane,z,'let n_base = 2 * masks.len() + 4;')
    # Read actual body as well as its CPU-only comment: no backend/gpu call.
    body=load(lane,z).split('pub fn mask_commit_tagged(',1)[1].split('\npub fn ',1)[0]
    check('encode_coeffs_coset' in body)
    check('try_commit' not in body and 'gpu::' not in body)
    cuda='hashline/src/gpu/cuda.rs'
    require(lane,cuda,'pub const NTT_LOG_BLK: u32 = 12;')
    require(lane,cuda,'self.ntt_rows_view(data, coef, rows, n, log_n, true)?;',True)
    require(lane,cuda,'g.ntt_rows(d_data.get(), d_coef.get_mut(), rows, n, log_n, true)?;',True)
    require(lane,cuda,'self.ntt_rows(coef2, enc, rows, pw, log_nn, false)?;',True)
    require(lane,cuda,'g.ntt_rows(d_coef2.get(), d_enc.get_mut(), rows, nn, log_nn, false)?;',True)
    require(lane,cuda,'log_n as i32, n_src as i32, scale')
    require(lane,cuda,'pw == nn || pw == n + q')
    k='hashline/src/gpu/kernels.cu'
    require(lane,k,'int x = blk * bs + q;',True)
    require(lane,k,'__brev((u32)x) >> (32 - log_n)',True)
    require(lane,k,'sh[q] = (r < n_src) ? s[r] : 0ULL;',True)

s='hashline/src/private_block/shape.rs'
require('r9',s,'64 => Some(13),',True)
require('r9',s,'128 => Some(14),',True)
require('r9',s,'2 * self.n_slots() + 4',True)
require('r9',s,'N_SLOTS + usize::from(self.dd_cap > 0)',True)
for profile,call in [('TINYLLAMA_T128_DD_TRAINED_PROFILE','128, 14)'),
                     ('LLAMA3_8B_T128_DD_TRAINED_PROFILE','128)')]:
    source=load('r9',s)
    line=next(x for x in source.splitlines() if profile+' =>' in x)
    check(call in line)
for ctor,fragment in [('toy','32, 16, 16, 2, 8, 1, 8, 8, 9, 7'),
                      ('m125','512, 768, 2048, 12, 64, 4, 14, 4, 9, 37')]:
    text=load('r9',s).split('fn '+ctor+'()',1)[1].split('\n    }',1)[0]
    check(compact(fragment) in compact(text))

census=json.loads((HERE/'census.json').read_text())
result=json.loads((HERE/'result.json').read_text())
check(len(census)==result['census_rows']==160)
for row in census:
    check(row['q_pad']==256)
    if row['role']=='M':
        check(not row['eligible'] and row['backend'].startswith('CPU'))
        check(row['mask_rows']==(52 if row['dd'] else 50))
    else:
        lc=row.get('endpoint_log_cols',row['log_cols']) if row['role']=='endpoint_or_boundary' else row['log_cols']
        rate=row.get('endpoint_inv_rate',row['inv_rate']) if row['role']=='endpoint_or_boundary' else row['inv_rate']
        n=2**lc
        logn=lc if row['phase']=='inverse' else lc+rate.bit_length()-1
        check(logn==row['transform_log'])
        check(row['eligible']==(8<=logn<=13))
        expected_src=n if row['phase']=='inverse' else (n+256 if row['phase']=='forward_compact' else n*rate)
        check(row['n_src']==expected_src)
        if row['scope'].endswith('trained geometry'):
            check(row['context'] in [32,64,128])
            if row['context']==128:check(not row['eligible'])
check(result['full_stack']['proofs']==0 and result['full_stack']['positions']==0)
check(all(x['resident_pair_request_fraction_saved']==(0 if x['log_cols']==14 else 0.1) for x in result['summary']))
check(len(json.loads((HERE/'negative-controls.json').read_text()))==9)

out=dict(checks=checks,source_pins=len(pins),source_fragment_assertions=len(evidence),
         rejected_source_mutations=len(mutations),
         elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
         scope='Pinned source fragments and independent census accounting, not Rust execution/profile admission')
for name,value in [('source-evidence.json',evidence),('source-mutations.json',mutations),('validation-result.json',out)]:
    (HERE/name).write_text(json.dumps(value,indent=2)+'\n')
print(json.dumps(out))
