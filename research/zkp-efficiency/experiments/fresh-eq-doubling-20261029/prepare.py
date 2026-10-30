"""Snapshot authorized research inputs and checkpoint before experimentation."""
from pathlib import Path
import datetime, hashlib, json, os, platform

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PROJECT = ROOT.parent.parent
PRIOR = HERE.parent / 'resident-public-plan-20261029'
RUN = '20261029T145649Z-fb1b89ab'
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
startup = HERE / 'startup'
startup.mkdir(exist_ok=True)
index = []
for p in [ROOT / n for n in ['AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md']] + [PROJECT/'CLAUDE.md'] + [PROJECT/'docs/zkmatrix-poc'/n for n in ['START_HERE.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md']]:
    b = p.read_bytes()
    (startup/p.name).write_bytes(b)
    index.append(dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),lines=len(b.splitlines()),headings=[x for x in b.decode().splitlines() if x.startswith('#')]))
for name in ['result.json','account-result.json','audit-result.json','final-audit-result.json','hypotheses.json','cycle-ranking.json']:
    (startup/('prior-'+name)).write_bytes((PRIOR/name).read_bytes())
for name in ['model.py','legacy_catalog.py','serial_eq.rs','run_bounded.py']:
    (HERE/name).write_bytes((PRIOR/name).read_bytes())
pins = json.loads((PRIOR/'native-pins.json').read_text())
for pin in pins:
    b = Path(pin['path']).read_bytes()
    assert hashlib.sha256(b).hexdigest() == pin['sha256']
    p = HERE/pin['snapshot']; p.parent.mkdir(exist_ok=True); p.write_bytes(b)
(HERE/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
(HERE/'required-reading-index.json').write_text(json.dumps(index,indent=2)+'\n')
sources = [json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
(HERE/'prior-source-index.json').write_text(json.dumps(dict(records=len(sources),urls=sorted({s.get('url','') for s in sources})),indent=2)+'\n')
cpu = next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))
(HERE/'hardware.json').write_text(json.dumps(dict(cpu=cpu,platform=platform.platform(),affinity_available=sorted(os.sched_getaffinity(0)),gpu=False,numeric_workers=1),indent=2)+'\n')
(HERE/'early-checkpoint.json').write_text(json.dumps(dict(run_id=RUN,cycle='0145',checkpoint_utc=now,deadline_utc='2026-10-29T15:16:49Z',previous_cycle='0144',prior_source_records=len(sources),source_pins=len(pins)),indent=2)+'\n')
(ROOT/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle 0145 IN PROGRESS: `{RUN}`; early checkpoint {now}.
Deadline 2026-10-29 15:16:49 UTC. Next cycle no earlier than 15:56:49 UTC.
Prior state/findings/sources/latest results retained in
experiments/fresh-eq-doubling-20261029/startup/.

Investigating exact fresh Eq table doubling: replace each e*(1-r), e*r
with e-hi, hi=e*r. No challenge/table/mask reuse is permitted. First measure
the incidence in R13 priv_table; broader PCS/sumcheck calls need separate
scope accounting. Expected end-to-end gain unknown without exclusive clocks.
Global priorities remain whole-prover high-end GPU, admitted context/DD/fidelity
scaling, and exclusive clocks/capacity. Prior 61 hypotheses/negative results
are preserved; this cycle will add/refine one and run bounded differential
controls with an independent modular reference.

No new full-stack proofs/model passes/proved positions: 0/0/0. CPU only,
one pinned worker; no GPU, native build, external writes, installations or Git.
New witness/proof/serialization/verification/startup clocks, startup fraction,
steady-state and total-workload rates unmeasured. No model context or decode.
Complete private 8B >=50 proved tokens/s remains unachieved.

Carried historical CPU 8B T128/L32 single 16-thread pass, GPU off:
478.737s total (0.267370 positions/s); prove_run393.785s includes witness
98.348s and block load17.595s; sealing84.824s before prove_run; verification
42.709s plus load13.681s; receipt922,711,264B. Not rerun/reverified/new credit.
See prior state for overlapping phase and profile limits.
''')
print(json.dumps(dict(checkpoint_utc=now,prior_sources=len(sources),native_pins=len(pins),cpu=cpu)))
