"""Independent provenance/source/scope audit, not native proof validation."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import resource
import signal
import time

resource.setrlimit(resource.RLIMIT_AS,(256<<20,256<<20))
resource.setrlimit(resource.RLIMIT_CPU,(15,15));signal.alarm(20)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
HERE=Path(__file__).resolve().parent;BASE=HERE.parents[1]
t=time.monotonic();checks=0
def ck(ok,message):
    global checks
    checks+=1
    assert ok,message
def read(name):return json.loads((HERE/name).read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
d=read('result.json')
ck(d['status']=='PASS_SYNTHETIC_WORD_AND_LAYOUT_CONTRACT_ONLY','status')
ck(d['checks']==sum(d['checks_by_kind'].values())==39179,'check counts')
ck(d['general_pairs']==12441,'pair census')
ck(d['borrow_hits']+d['no_borrow_hits']==d['general_pairs'],'borrow coverage')
ck(len(d['ntt_cases'])==18 and {x['n'] for x in d['ntt_cases']}=={2,4,8,16,32,64},'NTT scope')
ck(len(d['dot_cases'])==35 and len(d['matrix_cases'])==4,'matrix scope')
ck(len(d['negative_controls'])==54,'control count')
for control in d['negative_controls']:ck(control['actual']!=control['expected'],control['name'])
ck(next(x for x in d['dot_cases'] if x['fixture']=='all-pminus1')['top128']==15,'canonical dot carry')
ck(d['signed32_dot16_t_bound']==2138022000 < 2**31,'signed32 bound')
ck((7+256*8)*32*255**2 >= 2**31,'32term bound negative')
ck(d['elapsed_seconds']<60 and d['max_rss_kib']<512*1024 and d['threads']==1,'resource limits')
for k in ['native_full_proofs','passes','proved_positions']:ck(d[k]==0,k)
for k in ['context_length','witness_seconds','proof_seconds','serialization_seconds','verification_seconds','startup_seconds','startup_fraction','steady_proved_tokens_per_second','total_proved_tokens_per_second']:ck(d[k] is None,k)
for name,h in d['code_hashes'].items():ck(sha((HERE/name).read_bytes())==h,name)
for folder in ['initial-before-scaled-matrix','before-explicit-carry','before-top-fold']:
    old=read(folder+'/result.json')
    for name,h in old['code_hashes'].items():ck(sha((HERE/folder/name).read_bytes())==h,folder+'/'+name)
pins=read('native-pins.json');live=[]
for p in pins:
    ck(sha((HERE/p['snapshot']).read_bytes())==p['sha256'],'native snapshot '+p['path'])
    curr=sha(Path(p['path']).read_bytes());live.append(dict(path=p['path'],sha256=curr,unchanged=curr==p['sha256']))
    ck(curr==p['sha256'],'native live '+p['path'])

web=read('web-source-lines.json')
mod='\n'.join(web['modular.cuh']['rendered_lines'].values())
ntt='\n'.join(web['cuda/ntt.cuh']['rendered_lines'].values())
ck(len(web['modular.cuh']['rendered_lines'])==406,'complete rendered modular')
ck(len(web['cuda/ntt.cuh']['rendered_lines'])==339,'complete rendered NTT')
for text in ['std::bit_width(modulus) >= 63','modulus needs to be within 62 bits for now','class MontgomeryMultiplier64','class MontgomeryFriendlyMultiplier64','bp = b * calculate_montgomery_inverse(modulus);','const std::uint64_t qN1 = arithmetic::multiply_high(q, N);']:
    ck(text in mod,'modular contract '+text)
general=mod.split('class MontgomeryMultiplier64 {')[1].split('class MontgomeryFriendlyMultiplier64')[0]
ck('bit_width' not in general,'general helper has no friendly guard')
for text in ['using multiplier_type = modular::MontgomeryFriendlyMultiplier64;','b0 = a0 + a1;','b1 = a0 - a1 + N * 2;','modulus.power(2, reduction_type::get_factor())','std::int32_t>','ss[15], tt[8]','bitswap_within<std::uint32_t>(row, 4) * col']:
    ck(text in ntt,'NTT contract '+text)
for name in web:ck('SPDX-License-Identifier: Apache-2.0' in '\n'.join(web[name]['rendered_lines'].values()),name+' license')
rawtest=(HERE/'web/live-4.txt').read_text()+(HERE/'web/live-6.txt').read_text()
ck('MontgomeryFriendlyReductionBy64<modulus_bits>' in rawtest,'driver uses friendly reducer')
ck("0x1fff'fff9'0000'0001" in rawtest,'driver actual modulus')
ck('constexpr int modulus_bits = 64;' in rawtest,'driver template extent')
ck(int('1ffffff900000001',16).bit_length()==61,'actual modulus is61bits')

src=lambda suffix:next((HERE/p['snapshot']).read_text() for p in pins if p['path'].endswith(suffix))
kernel=src('kernels.cu');native_ntt=src('/ntt.rs');field=src('/field.rs');derive=src('/derive.rs')
for text in ['#define P_GL 0xFFFFFFFF00000001ULL','gl_reduce(a * b, __umul64hi(a, b))','extern "C" __global__ void k_ntt_p1','k_ntt_p2']:
    ck(text in kernel,'native seam '+text)
for text in ['pub const GENERATOR: u64 = 7;','pub const P: u64 = 0xFFFF_FFFF_0000_0001;']:ck(text in field,'field pin')
for text in ['pub fn inverse','pub fn forward','pub fn rs_encode','tw[k * stride]']:ck(text in native_ntt,'NTT seam')
for text in ['const CHECKPOINT_BYTES: u64 = 7698241104;','while offset < size','hasher.update(&buffer[..count]);','let mut checkpoint = Checkpoint::open','consumed tied tensor SHA-256 differs from pin']:
    ck(text in derive,'next resident-cache seam '+text)

prior=read('startup/prior-hypotheses.json');h=read('hypotheses.json')
ck(len(h)==46 and len(prior)==44,'hypotheses retained')
for i in range(44):
    ck(h[i]['rank']==prior[i]['rank'],'prior rank '+str(i+1))
    if i not in [0,43]:ck(h[i]==prior[i],'unchanged prior '+str(i+1))
for x in h:
    for k in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:ck(bool(x[k]),str(x['rank'])+k)
records=read('sources-cycle.json');ck(len(records)==9,'source count')
for x in records:
    for k in ['url','access_date','publication_date','verified_update_date','implementation_license','inspected_commit_id','assessment']:ck(k in x,k)
    ck(x['external_execution'] is False and x['reproduced_performance'] is False,'claim scope')
for item in read('startup/read-index.json'):
    ck(sha((HERE/'startup'/item['snapshot']).read_bytes())==item['sha256'],'startup snapshot '+item['snapshot'])

result=dict(status='PASS_SOURCE_SCOPE_AND_PROVENANCE_AUDIT',checks=checks,
    elapsed_seconds=time.monotonic()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    native_pins=live,checked_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    scope='Source strings, independent evidence counts and hashes; not compilation/PTX/device/PCS/receipt/privacy validation.')
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='native_pins'},indent=2))
