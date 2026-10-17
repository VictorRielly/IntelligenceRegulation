"""Independent retained-ms and patch-provenance audit. Does not import experiment."""
from pathlib import Path
import hashlib
import json
import os
import re
import resource
import signal
import time

P = Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
signal.alarm(59)
os.nice(19)
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
t0 = time.monotonic()
checks = 0


def ck(x):
    global checks
    assert x
    checks += 1


def ms(v):
    # Exact reading of the three-decimal Rust display; no float/Decimal sum.
    m = re.fullmatch(r'(\d+)(?:\.(\d{1,3}))?', str(v))
    ck(m is not None)
    return int(m[1])*1000 + int((m[2] or '').ljust(3, '0'))


rows = json.loads((P/'retained-timing-only.json').read_text())
result = json.loads((P/'result.json').read_text())
names = ['load','witness_parity','prove_inclusive','verify_in_process','total','fresh_load','fresh_verify','unclassified']
sums = dict.fromkeys(names, 0)
for r in rows:
    pe = {v['event']:v for v in r['prove_events']}
    ve = r['verify_events'][0]
    p = pe['proved']
    vals = [ms(pe['loaded']['seconds']),ms(pe['parity']['seconds']),ms(p['prove_seconds']),ms(p['in_process_verify_seconds']),ms(p['total_seconds']),ms(ve['load_seconds']),ms(ve['verify_seconds'])]
    vals.append(vals[4]-sum(vals[:4]))
    ck(vals[-1] >= -2)  # ms integers: ±2.5ms tolerated by the main audit
    for n,v in zip(names,vals):
        sums[n] += v
    ck((p['segment_sha256'],p['statement_identity'],p['segment_bytes']) == (ve['segment_sha256'],ve['statement_identity'],ve['segment_bytes']))
for n,v in sums.items():
    ck(ms(result['diagnostic_seconds'][n]) == v)
ck(sums['total'] == 405980 and sums['witness_parity'] == 294314)
ck(result['target_total_workload_rate'] is None and result['target_steady_rate'] is None)
ck(result['accepted_complete_8b_positions'] == 0)

pins = json.loads((P/'evidence-pins.json').read_text())
owner_changes = []
for path,pin in pins.items():
    path = Path(path)
    h = hashlib.sha256(path.read_bytes()).hexdigest()
    if '/ops/' in str(path) and h != pin['sha256']:
        owner_changes.append(str(path))
    else:
        ck(h == pin['sha256'])
manifest_path = next(Path(x) for x in pins if x.endswith('/manifest_final_sources.json'))
old_manifest = json.loads(manifest_path.read_text())['files']
ck(hashlib.sha256((P/'source/trained_block-t5.rs').read_bytes()).hexdigest() == old_manifest['hashline/src/private_block/trained_block.rs'])
ck(hashlib.sha256((P/'source/run-t5.rs').read_bytes()).hexdigest() == old_manifest['hashline/src/private_block/run.rs'])
for name in ['run-t5.rs','current-run.rs']:
    s=(P/'source'/name).read_text()
    b=s.split('for k in 0..l {',1)[1].split('Ok(stats)',1)[0]
    markers=['let t0 = Instant::now();','src.boundary_plane(k)?','let wit = src.witness(k)?;','wire::encode_segment','sink(k, bytes)?;','stats.prove_s.push(t0.elapsed()']
    indexes=[b.index(m) for m in markers]
    ck(indexes == sorted(indexes))

# Independent unified-diff application to a research-only source string.
base = (P/'source/current-run.rs').read_text().splitlines(keepends=True)
diff = (P/'phase-probe-candidate.patch').read_text().splitlines(keepends=True)
out=[];cursor=0;i=2;hunks=0
while i<len(diff):
    h=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',diff[i]);ck(h is not None)
    start=int(h[1])-1;ck(start >= cursor);out.extend(base[cursor:start]);cursor=start;i+=1;hunks+=1
    while i<len(diff) and not diff[i].startswith('@@'):
        line=diff[i]; tag=line[0]; content=line[1:]
        if tag in ' -':
            ck(base[cursor] == content);cursor+=1
        if tag in ' +':
            out.append(content)
        ck(tag in ' +-');i+=1
out.extend(base[cursor:]);ck(''.join(out) == (P/'source/candidate-run.rs').read_text())
for f in ['source_witness_s','encode_s','sink_s','setup_s']:
    ck(f in ''.join(out))
checkpoint={'status':'pass','checks':checks,'diff_hunks':hunks,
            'observed_concurrent_owner_source_changes':owner_changes,
            'wall_seconds':time.monotonic()-t0,
            'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'limits':'one nice19 CPU0 thread;59s;512MiB AS;32MiB estimated',
            'scope':'No native compile, transcript/bytes gate or fresh receipt verification.'}
(P/'audit.json').write_text(json.dumps(checkpoint,indent=2)+'\n')
print(json.dumps(checkpoint))
