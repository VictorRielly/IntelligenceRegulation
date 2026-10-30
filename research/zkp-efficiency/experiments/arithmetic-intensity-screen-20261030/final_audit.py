"""Preservation/provenance/coverage audit; no candidate/prover imports."""
import datetime, hashlib, json
from pathlib import Path
E = Path(__file__).resolve().parent
ROOT = E.parents[1]
RUN = '20261030T154123Z-20600a3e'
checks = 0


def check(ok, msg):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(msg)


old = (E/'startup/sources.jsonl').read_bytes()
current = (ROOT/'sources.jsonl').read_bytes()
check(current.startswith(old), 'all prior source ledger bytes preserved')
parsed = [json.loads(x) for x in current.splitlines() if x.strip()]
check(len(parsed) == 1122, 'source record count')
check(len({x['id'] for x in parsed[-9:]}) == 9, 'new source ids unique')
for s in parsed[-9:]:
    check(s['run_id'] == RUN and s['access_date'] == '2026-10-30', 'source identity/date')
    check(s['url'].startswith('https://'), 'exact source URL')
    for name in ('publication_date', 'verified_update_date', 'date_evidence',
                 'implementation_license', 'inspected_commit_id'):
        check(name in s, 'source scope field ' + name)
    check(not s['reproduced_performance'] and not s['external_execution'], 'no foreign reproduction')
findings = (ROOT/'FINDINGS.md').read_bytes()
check(findings.startswith((E/'startup/FINDINGS.md').read_bytes()), 'all prior findings bytes preserved')
check(findings.count(b'## Cycle0167') == 1, 'one findings entry')
h = json.loads((E/'hypotheses.json').read_text())
check(h[:-1] == json.loads((E/'startup/prior-hypotheses.json').read_text()), 'all100 prior hypothesis dictionaries preserved')
check(len(h) == 101 and h[-1]['rank'] == 101, 'new hypothesis')
for pin in json.loads((E/'native-pins.json').read_text()):
    check(hashlib.sha256((E/pin['snapshot']).read_bytes()).hexdigest() == pin['sha256'], 'snapshot pin')
    check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest() == pin['sha256'], 'live native pin')
for d in json.loads((E/'owner-document-refresh.json').read_text()):
    check(hashlib.sha256(Path(d['path']).read_bytes()).hexdigest() == d['sha256'], 'owner document unchanged after closing read')
accounting = json.loads((E/'target-accounting.json').read_text())
for name in ('new_independently_verified_full_stack_proofs', 'new_complete_passes', 'new_proved_positions'):
    check(accounting[name] == 0, 'no counted proof work')
for name in ('actual_context', 'accelerator', 'steady_state_proved_tokens_per_s',
             'total_workload_proved_tokens_per_s', 'startup_s', 'startup_fraction',
             'initial_prefill_s', 'witness_s', 'proof_s', 'serialization_s', 'verification_s'):
    check(accounting[name] is None, 'unknown model clock/scope remains unknown')
for file in (ROOT/'STATE.md', ROOT/'PROGRESS.md', ROOT/'progress'/f'{RUN}.md'):
    txt = file.read_text()
    check(RUN in txt and 'unachieved' in txt, 'self-contained run/target report')
for which in ('experiment', 'audit'):
    r = json.loads((E/(which+'-execution.json')).read_text())
    check(r['returncode'] == 0 and r['wall_s'] < 60 and r['child_maxrss_kib'] < 512*1024, 'bounded leaf')
    check(r['limits']['threads'] == 1, 'one thread')

exclude = {'artifact-manifest.json', 'final-audit-result.json'}
manifest = []
for q in sorted(E.rglob('*')):
    if q.is_file() and q.name not in exclude:
        manifest.append(dict(path=str(q.relative_to(E)),bytes=q.stat().st_size,
                             sha256=hashlib.sha256(q.read_bytes()).hexdigest()))
check(not list(E.rglob('__pycache__')), 'no hidden Python build cache')
(E/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
result = dict(status='PASS',checks=checks,artifacts=len(manifest),native_pins=21,
              preserved_source_records=1113,current_source_records=1122,
              preserved_hypotheses=100,current_hypotheses=101,
              utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(E/'final-audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
