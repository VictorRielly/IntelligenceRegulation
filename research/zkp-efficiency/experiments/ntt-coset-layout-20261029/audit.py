"""Evidence/source audit only, independent of the algebra harness run."""
import os, resource, signal, hashlib, json, time
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(40,40))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(45)
H=Path(__file__).resolve().parent;t0=time.perf_counter();checks=0
def check(ok):
    global checks
    checks+=1
    assert ok, checks
pins=json.loads((H/'native-pins.json').read_text())
for item in pins:
    for f in (Path(item['path']),H/item['snapshot']):
        check(hashlib.sha256(f.read_bytes()).hexdigest()==item['sha256'])
c=(H/'native/hashline__src__gpu__cuda.rs').read_text()
k=(H/'native/hashline__src__gpu__kernels.cu').read_text()
p=(H/'native/zkp-core__src__pcs.rs').read_text()
n=(H/'native/zkp-core__src__ntt.rs').read_text()
f=(H/'native/zkp-core__src__field.rs').read_text()
fragments=[(c,'self.ntt_rows_view(data, coef, rows, n, log_n, true)?;'),
 (c,'self.ntt_rows(coef2, enc, rows, pw, log_nn, false)?;'),
 (c,'let pview = d_pads.slice(r0 * q..(r0 + rc) * q);'),
 (c,'let pw = zk_pad_width(n, q, nn, zk_compact_pad())?;'),
 (c,'log_nn <= NTT_LOG_BLK'),
 (k,'#define NTT_LOG_BLK 12'),
 (k,'if (i < n) v = coef[(size_t)row * (size_t)n + i];'),
 (k,'if (i < q) v = gl_sub(v, pads[(size_t)row * (size_t)q + i]);'),
 (k,'if (i >= n && i < n + q) v = gl_add(v, pads[(size_t)row * (size_t)q + (i - n)]);'),
 (k,'out[g] = gl_mul(v, pows[i]);'),
 (k,'for (int st = 1; st <= lb; st++)'),
 (k,'u64 v = gl_mul(sh[i + half], w);'),
 (p,'assert!(n + q <= nn && nn % n == 0);'),
 (p,'out[i] = out[i].sub(pad[i]);'),
 (p,'out[n + i] = pad[i];'),
 (p,'let pads = rng.fp_vec(rows * q);'),
 (n,'at omega^i, i = 0..n (natural order).'),
 (f,'pub const GENERATOR: u64 = 7;')]
for body,fragment in fragments:check(fragment in body)
small=json.loads((H/'result.json').read_text());large=json.loads((H/'large-row-result.json').read_text())
check(small['checks']==21424 and small['fixtures']==186)
check(large['checks']==114688 and len(large['rows'])==3)
check(len(small['conformance_vectors'])==15)
check(len(small['rejected_controls'])==13)
check(small['complete_verified_proofs']==0 and not small['gpu_execution'])
check(large['complete_verified_proofs']==0 and not large['native_execution'])
for c in small['counts']:
    if c['q']==256 and c['rate']==4 and c['n']==16384:
        check(c['baseline_mul']==672000 and c['split_mul']==656384)
        check(c['extra_coef_reads_words']==49152)
        check(c['baseline_forward_kernels']==c['split_forward_kernels_if_cosets_batched']==2)
    if c['q']==c['n'] and c['rate']==4:check(c['mul_saved']<0)
check((H/'startup/sources.jsonl').read_bytes()==Path('sources.jsonl').read_bytes()[:(H/'startup/sources.jsonl').stat().st_size])
check(Path('FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()))
prior=json.loads((H/'startup/prior-hypotheses.json').read_text())
current=json.loads((H/'hypotheses.json').read_text())
for old in prior:
    match=next(x for x in current if x['rank']==old['rank'])
    check(match==old or (old['rank']==1 and match['title']==old['title']))
check(len(current)>=52 and len(current)==len({h['rank'] for h in current}))
out=dict(status='PASS',checks=checks,native_pins=len(pins),source_fragment_checks=len(fragments),
    elapsed_s=time.perf_counter()-t0,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    scope='source/provenance and claimed count checks, not native behavior')
(H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
