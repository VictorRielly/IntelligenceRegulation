"""Source/cost/provenance audit; does not import the candidate or run native code."""
import os,resource,signal,time
resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(45);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
import hashlib,json
from pathlib import Path
from fractions import Fraction
START=time.perf_counter();E=Path(__file__).resolve().parent;checks=0
def ck(x):
    global checks
    checks+=1
    if not x:raise AssertionError(checks)
sha=lambda b:hashlib.sha256(b).hexdigest()
r=json.loads((E/'result.json').read_text())
pins=json.loads((E/'native-pins.json').read_text());sources={}
for p in pins:
    b=Path(p['path']).read_bytes();ck(sha(b)==p['sha256']);ck(b==(E/p['snapshot']).read_bytes());sources[p['path'].split('/')[-1]]=b.decode()
tb=sources['trained_block.rs'];ts=sources['trained_statement.rs'];pb=sources['private_block.rs'];sh=sources['shape.rs'];tl=sources['load.rs']
for needle in ['let got = if check_sha { sha256(&bytes) } else { want };',
    'let mut record = if full { LayerRecord::of_block(index, &blk, source_tensors) } else { LayerRecord::unhashed(index) };',
    'if blk.digest() != self.digests[k]', 'load_layer_mode(sh, c, index, rope_from_export, false)']:
    ck(needle in tb)
for needle in ['words.par_iter().map(|w| sha(&i8_bytes(w))).collect()',
               'table_sha256 = [sha(&i64_bytes(&[&a.rope_cos, &a.rope_sin])), sha(&i64_bytes(&[&a.exp])), sha(&act)]',
               'block_digest: blk.digest()']:
    ck(needle in ts)
for needle in ['wq: wq.to_vec()','exp: exp.to_vec()','wg_t: wg_t.to_vec()',
               'act: [i16; 256] = act.try_into()', 'h.update(b"hashline/private-block-public/1")']:
    ck(needle in pb)
ck('(h / group) * self.slots_per_kv_group() + (h % group)' in sh)
ck('if blk.digest() != self.p.digests[k]' in tl)
# Independent integer calculation; all dimensions public and no allocation.
d=4096;f=14336;fp=16384;heads=32;kv=8;dh=128;t=128
raw=[heads*dh*d,kv*dh*d,kv*dh*d,d*heads*dh,d,d,d*f,d*f,f*d]
padded=raw[:6]+[d*fp,d*fp,fp*d]
saved=sum(raw[:6])+256*(8+2);total=sum(padded)+2*t*(dh//2)*8+256*(8+2)
c=r['census'];ck(c['reused_record_sha_bytes_per_full_layer']==saved);ck(c['baseline_record_sha_bytes_per_full_layer']==total);ck(c['reused_record_sha_bytes_per_32_layer_full_scan']==saved*32)
ck(c['fraction_of_record_sha_input_removed']==saved/total)
# The original per-word parallel task graph retains all three largest tasks.
# Ideal independent equal-byte/s tasks, list-scheduled largest-first. This
# is a counterexample to translating removed SHA input into phase wall gain.
def lpt(jobs,w):
    workers=[0]*w
    for job in sorted(jobs,reverse=True):
        i=min(range(w),key=lambda i:workers[i]);workers[i]+=job
    return max(workers)
schedules=[]
for workers in (1,2,3,4,8,16):
    before=lpt(padded,workers);after=lpt(padded[6:],workers)
    ck(before>=after);schedules.append({'workers':workers,'baseline_byte_time_units':before,
        'candidate_byte_time_units':after,'ratio':before/after,
        'assumption':'independent equal byte-time workers; no shared bandwidth contention; LPT countermodel, not measured Rayon scheduling'})
    if workers>=4:ck(before==after)
ck(max(padded)==max(padded[6:])==67108864)
(E/'scheduling-model.json').write_text(json.dumps(schedules,indent=2)+'\n')
prior=json.loads((E/'startup/13-hypotheses.json').read_text())
now=json.loads((E/'hypotheses.json').read_text());ck(len(now)>=len(prior)+1)
for old in prior:ck(any(v['rank']==old['rank'] for v in now))
old_sources=(E/'startup/03-sources.jsonl').read_bytes();ck((E.parents[1]/'sources.jsonl').read_bytes().startswith(old_sources))
for n,h in r['source_hashes'].items():ck(sha((E/n).read_bytes())==h)
ck(r['proof_accounting']['countable_positions']==0)
ck(len(r['fixtures'])==32);ck(r['checks']==5150);ck(r['negative_controls']==2584)
out={'status':'PASS_SOURCE_COST_PROVENANCE_ONLY','checks':checks,'native_pins':len(pins),
    'elapsed_s':time.perf_counter()-START,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    'saved_bytes':saved,'full_model_saved_bytes':saved*32,
    'parallel_task_countermodel':schedules,'largest_remaining_cast_bytes':max(padded[6:]),
    'scope':'source hashes and integer/countermodel checks; no native compilation, execution, proof, GPU or privacy gate'}
(E/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
