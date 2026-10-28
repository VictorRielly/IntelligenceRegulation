"""Research-only checkpoint and source pins; no private model data read."""
import datetime, hashlib, json, os, re, resource
from pathlib import Path

resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
os.nice(19)
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJECT = ROOT.parents[1]
PRIOR = ROOT / 'experiments/decode-statement-scopes-20261019'
RUN = '20261019T231854Z-28e6b36b'
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
(HERE / 'startup').mkdir(exist_ok=True)
paths = [ROOT / n for n in ['AGENDA.md', 'STATE.md', 'FINDINGS.md', 'sources.jsonl', 'PROGRESS.md']]
paths += [PROJECT / 'CLAUDE.md']
paths += [PROJECT / 'docs/zkmatrix-poc' / (n + '.md') for n in
          ['MVP_STATUS', 'ZK60_DECISIONS', 'ZK60_CODEX_FABLE_COORDINATION', 'ZK60_THROUGHPUT_TARGET', 'START_HERE', 'ZK60_PRIVACY_REQUIREMENTS', 'ZK60_SPEED_PLAN_20261017']]
manifest = []
for path in paths:
    data = path.read_bytes()
    (HERE / 'startup' / path.name).write_bytes(data)
    manifest.append(dict(path=str(path), sha256=hashlib.sha256(data).hexdigest(), bytes=len(data)))
(HERE / 'startup-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
findings = (ROOT / 'FINDINGS.md').read_text()
sections = re.split(r'(?=^## )', findings, flags=re.M)
source_rows = [json.loads(s) for s in (ROOT / 'sources.jsonl').read_text().splitlines() if s.strip()]
index = dict(read_at=now, findings_sections=[dict(heading=s.splitlines()[0], bytes=len(s.encode()),
              opening=' '.join(s.splitlines()[1:8])[:600]) for s in sections],
             sources_count=len(source_rows), source_index=[dict(title=r.get('title'), url=r.get('url'),
              cycle=r.get('cycle')) for r in source_rows])
(HERE / 'durable-read-index.json').write_text(json.dumps(index, indent=2) + '\n')
pins = []
for name in ['result.json', 'audit-result.json', 'payload-ledger.json', 'hypotheses.json', 'review-only-statement-scopes.patch']:
    path = PRIOR / name
    data = path.read_bytes()
    (HERE / ('prior-' + name)).write_bytes(data)
    pins.append(dict(path=str(path), copy='prior-' + name, sha256=hashlib.sha256(data).hexdigest()))
for name in ['hashline/src/private_block/trained_block.rs']:
    path = PROJECT / 'ops/zkp-mvp/trained-1b-review-r8' / name
    data = path.read_bytes()
    copied = 'native-' + path.name
    (HERE / copied).write_bytes(data)
    pins.append(dict(path=str(path), copy=copied, sha256=hashlib.sha256(data).hexdigest()))
(HERE / 'input-pins.json').write_text(json.dumps(pins, indent=2) + '\n')
state = f'''# ZKP efficiency explorer — durable state

Cycle0091 IN PROGRESS: `{RUN}`, checkpoint {now}.
Deadline 2026-10-19 23:38:54 UTC; next cycle no earlier 2026-10-20 00:18:54 UTC.
Read AGENDA, durable memory and current direction; startup snapshots and read
index in experiments/vec-allocation-scopes-20261019/. Prior cycle0090 state,
findings, sources and negative results preserved in startup/ and original files.

Plan: test original Vec<i8> decode allocation overlap with a single-thread,
no-dependency Rust System allocator probe, preallocated event log and scalar
pad analogue. Compare grouped versus separate result statements and an
extended-reference negative; independent destination-indexed byte oracle and
allocation-event formulas. No custom decoded Drop wrapper. This tests an
unmeasured premise; no native loader/Rayon/whole-proof speed or RSS inferred.
Baseline prior112.003906MiB modeled padding overlap; standalone loader peak
saving0B. All-load deletion gives at most1.103104x on carried R8 CPU diagnostic.

Ranked: (1) owner whole-prover GPU/resident1/2/4/8 verified workloads;
(2) checked public constructor transfer, native gates pending;
(3) this cycle's real Vec allocation falsification of per-call scopes;
(4) prior raw releases/direct-byte padding, composed capacity only.
New refinement: compare optimized and unoptimized allocations, direct-byte
control, and allocation/requested-byte counts so compiler-elision or moved
allocation costs can falsify the previous semantic envelope.

Carried diagnostic only:8B T128,32 blocks,one16-thread CPU pass,GPU off,
478.737s total,prove_run393.785s,witness98.348s nested,receipt922711264B,
fresh verify42.709s+13.681s initial load. Researcher did not reverify it.
No new complete proofs/passes/positions;new witness/proof/serialization/verify,
startup fraction,steady/total rates unmeasured. Target unchanged:complete
private8B >=50 positions/s on RTX5090/named high-end GPU. Long context,
resident passes and decode remain distinct. No mask/opening reuse.

Only research writes; no runtime/, production, Git, receipt, calibration,
instruction or reviewer edits. No GPU/install/downloaded-code execution,
external write/message, purchase or escalation. Owner native build/proof
and allocation/HWM/enclosing clocks remain under shared heavy/build locks.
'''
(ROOT / 'STATE.md').write_text(state)
print(json.dumps(dict(checkpoint=now, findings_sections=len(sections), sources=len(source_rows),
                     startup_files=len(manifest), input_pins=len(pins)), indent=2))
for s in sections[-6:]:
    print(s.splitlines()[0], ' '.join(s.splitlines()[1:5])[:500])
print('Previously searched relevant sources:')
for r in source_rows:
    if any(w in str(r.get('url','')).lower() for w in ['goldilocksntt', 'recmo', 'zkprophet', 'statesync', 'ss-gkr']):
        print(r.get('title'), r.get('url'), r.get('cycle'))
