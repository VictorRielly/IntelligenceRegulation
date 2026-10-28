#!/usr/bin/env python3
"""Validate scientific scope, retained evidence and research checkpoints."""
import ast
import datetime
import hashlib
import json
import os
import re
import resource
import signal
import time
from pathlib import Path

H = Path(__file__).resolve().parent
R = H.parent.parent
RUN = '20261019T151854Z-4f2eec2a'


def main():
    t = time.perf_counter()
    os.nice(19)
    cpu = min(os.sched_getaffinity(0))
    os.sched_setaffinity(0, {cpu})
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2,)*2)
    signal.alarm(59)
    n = 0
    def check(value):
        nonlocal n
        assert value
        n += 1
    def read(name):
        return json.loads((H/name).read_text())
    result, audit = read('result.json'), read('audit-result.json')
    check(result['status'] == audit['status'] == 'PASS')
    check(result['symbolic_checks'] == 2888 and audit['checks'] == 187)
    check(len(result['negative_controls']) == 8 and all(result['negative_controls'].values()))
    check(len(audit['controls']) == 3 and all(audit['controls'].values()))
    check(result['nonuniform_raw_instances'] == result['noncanonical_instances'] == 9)
    check(result['minimal_raw_translation_groups'] == {'3':2,'6':3})
    check(result['numerical']['fixtures'] == 33)
    check(result['numerical']['coefficients_per_arm'] == 165)
    check(result['numerical']['naive_wrong_random'] == 24)
    check(result['numerical']['naive_wrong_boundary'] == 7)
    check(result['numerical']['naive_wrong_zero'] == 0)
    check(audit['native_field_oracle_coefficients'] == 180)
    for output in (result, audit):
        check(output['threads'] == 1 and output['cpu_affinity'] == [cpu])
        check(output['wall_seconds'] < 60)
        check(output['rss_kib'] < 512*1024)
    check(result['dag_ops'] == 1167)
    check(sum(result['field_primitives'].values()) == 884)
    check(result['original_tables'] == result['original_finals'] == 59)
    check(result['original_folds_unchanged'])
    costs = result['partial_map_cost']
    check(costs['removed_map_bytes'] == 198)
    check(costs['remaining_map_bytes'] == 436)
    check(costs['partial_logical_bytes'] == 8964)
    check(costs['physical_DRAM_bytes'] is costs['candidate_runtime_seconds'] is None)
    check(costs['extra_helper_arguments'] == 0)
    for pin in read('input-pins.json')+read('oracle-pins.json'):
        check(hashlib.sha256((H/pin['local']).read_bytes()).hexdigest() == pin['sha256'])
    for pin in read('startup-pins.json'):
        # Snapshots preserve original bytes, including docs that owners can edit.
        path = Path(pin['path'])
        rel = path.relative_to(R) if path.is_relative_to(R) else path.relative_to(R.parent.parent)
        snap = H/'startup'/str(rel).replace('/', '__')
        check(hashlib.sha256(snap.read_bytes()).hexdigest() == pin['sha256'])
    for pin in read('pin-recheck.json'):
        check(pin['matches'])
        check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest() == pin['sha256'])
    previous = (H/'startup/sources.jsonl').read_bytes()
    current = (R/'sources.jsonl').read_bytes()
    check(current.startswith(previous))
    rows = [json.loads(line) for line in current.splitlines()]
    check(len(previous.splitlines()) == 448 and len(rows) == 455)
    check(rows[448:] == read('source-records.json'))
    for row in rows[448:]:
        check(row['run_id'] == RUN and row['access_date'] == '2026-10-19')
        check(row['url'].startswith('https://'))
        check('date_evidence' in row and not row['reproduced_performance'])
    old_findings = (H/'startup/FINDINGS.md').read_bytes()
    findings = (R/'FINDINGS.md').read_bytes()
    check(findings.startswith(old_findings))
    check(findings[len(old_findings):].count(b'## Cycle 0083') == 1)
    check((R/'AGENDA.md').read_bytes() == (H/'startup/AGENDA.md').read_bytes())
    state = (R/'STATE.md').read_text()
    check(state == (H/'final-state.md').read_text())
    check(RUN in state and '16:18:54 UTC' in state)
    check('COMPLETE' in state and 'unachieved' in state)
    for path in [R/'PROGRESS.md', R/'progress'/f'{RUN}.md', H/'README.md',
                 R/'handoffs/20261019-dzc-affine-address-census.md']:
        check(path.exists())
        check('No speed improvement' in path.read_text() or 'No native patch' in path.read_text())
        for link in re.findall(r'\]\(([^)]+)\)', path.read_text()):
            if not link.startswith(('https://', 'http://', '#')):
                check((path.parent/link).exists())
    queue = read('hypotheses.json')
    check(len(queue) >= 3 and [x['rank'] for x in queue] == list(range(1,len(queue)+1)))
    for item in queue:
        for key in ('hypothesis','expected_end_to_end_impact','prerequisites',
                    'integration_cost','exactness','privacy_soundness','falsification'):
            check(bool(item[key]))
    accounting = read('target-accounting.json')
    check(accounting['run_id'] == RUN)
    target = accounting['new_target_work']
    check(target['completed_independently_verified_full_stack_proofs'] == 0)
    check(target['complete_model_passes'] == target['proved_token_positions'] == 0)
    check(target['device'] == 'none' and target['context_tokens'] is None)
    for key in ('steady_proved_tokens_per_second','total_workload_proved_tokens_per_second',
                'startup_seconds','startup_fraction','witness_seconds','proof_seconds',
                'serialization_seconds','verification_seconds'):
        check(target[key] is None)
    for key in ('long_context_prefill','resident_pass_series','decode_stream'):
        check(target[key] is False)
    prior = read('prior-target-accounting.json')
    for key in ('carried_8B_D_phase_ceiling','carried_8B_next_token'):
        check(accounting[key] == prior[key])
    check(accounting['synthetic_experiment']['tokens'] == 0)
    check(accounting['synthetic_experiment']['whole_D_folds_finals_tested_this_cycle'] is False)
    check((H/'initial-harness-failure.txt').stat().st_size > 500)
    for p in H.glob('*.py'):
        ast.parse(p.read_text(), filename=str(p))
        check(True)
    now = datetime.datetime.now(datetime.timezone.utc)
    check(now < datetime.datetime(2026,10,19,15,38,54,tzinfo=datetime.timezone.utc))
    # Audit JSON/source artifacts, without reading real private model material.
    artifacts = []
    for p in sorted(H.rglob('*')):
        if not p.is_file() or p.name in ('artifact-manifest.json','validation.json','validation.log'):
            continue
        b = p.read_bytes()
        if p.suffix == '.json':
            json.loads(b)
        artifacts.append(dict(path=str(p.relative_to(H)), bytes=len(b), sha256=hashlib.sha256(b).hexdigest()))
    (H/'artifact-manifest.json').write_text(json.dumps(artifacts, indent=2)+'\n')
    out = dict(status='PASS', checks=n, artifacts=len(artifacts),
               recorded_at_utc=now.isoformat(), wall_seconds=time.perf_counter()-t,
               rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
               original_findings_prefix_preserved=True, original_source_prefix_preserved=True,
               target_proofs_passes_positions=[0,0,0], cpu_affinity=[cpu], threads=1,
               scope='Evidence/checkpoint integrity and measurement-scope validation, not a native proof or benchmark')
    (H/'validation.json').write_text(json.dumps(out, indent=2)+'\n')
    (H/'validation.log').write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
