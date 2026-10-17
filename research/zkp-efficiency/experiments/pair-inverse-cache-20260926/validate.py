#!/usr/bin/env python3
"""Artifact/source/patch validation only; no prover build or execution."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal

HERE = Path(__file__).resolve().parent
RESEARCH = HERE.parent.parent
ROOT = RESEARCH.parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def apply_in_memory(original, patch):
    lines, result, cursor = original.splitlines(True), [], 0
    entries = patch.splitlines(True)
    k = 2
    assert entries[0].startswith('--- ') and entries[1].startswith('+++ ')
    while k < len(entries):
        m = re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', entries[k])
        assert m, entries[k]
        start = int(m[1])-1
        assert start >= cursor
        result.extend(lines[cursor:start])
        cursor, k = start, k+1
        removed, added = 0, 0
        while k < len(entries) and not entries[k].startswith('@@ '):
            x = entries[k]
            if x[0] in ' -':
                assert lines[cursor] == x[1:]
                cursor += 1
                removed += 1
            if x[0] in ' +':
                result.append(x[1:])
                added += 1
            assert x[0] in ' +-'
            k += 1
        assert removed == int(m[2] or 1) and added == int(m[4] or 1)
    result.extend(lines[cursor:])
    return ''.join(result)


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*2**20, 512*2**20))
    resource.setrlimit(resource.RLIMIT_CPU, (55,55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    result = json.loads((HERE/'result.json').read_text())
    assert result['status'] == 'passed' and result['threads'] == 1
    assert result['differential_cases'] == len(result['cases']) == 76
    assert result['independently_solved_words'] == 21015
    assert len(result['pipeline_cases']) == 41
    assert len(set(result['negative_controls'])) == 11
    assert result['script_wall_s_not_proving'] < 60
    assert result['peak_rss_kib'] < 512*1024
    assert result['experiment_sha256'] == sha(HERE/'experiment.py')
    for field in ('proving_seconds','verification_seconds','complete_readiness_seconds'):
        assert result[field] is None
    assert all(sha(Path(path)) == digest for path,digest in result['source_pins'].items())
    provenance = json.loads((HERE/'patch-provenance.json').read_text())
    assert provenance['applied'] is False and provenance['compiled'] is False
    original = Path(provenance['source']).read_text()
    assert hashlib.sha256(original.encode()).hexdigest() == provenance['source_sha256']
    patch = (HERE/'pair-helper-cache.proposed.patch').read_text()
    assert hashlib.sha256(patch.encode()).hexdigest() == provenance['patch_sha256']
    proposed = apply_in_memory(original, patch)
    assert hashlib.sha256(proposed.encode()).hexdigest() == provenance['proposed_source_sha256']
    table_start = '    let [gu8, gexp, gact] = hids.table_helpers();'
    table_end = '    // FINDING F-4, injection point 2 of 2'
    table_body = lambda x: x[x.index(table_start):x.index(table_end)]
    assert table_body(original) == table_body(proposed)
    challenges = lambda x: re.findall(r'^.*tr\.challenge_fp2\(\).*$', x, re.M)
    assert challenges(original) == challenges(proposed)
    assert proposed.count((HERE/'pair_helpers.proposed.rs').read_text()) == 1
    records = json.loads((HERE/'source-records.json').read_text())
    log = (RESEARCH/'sources.jsonl').read_bytes()
    prior = json.loads((HERE/'source-log-provenance.json').read_text())
    assert hashlib.sha256(log[:prior['prior_bytes']]).hexdigest() == prior['prior_sha256']
    decoded = [json.loads(line) for line in log.decode().splitlines()]
    assert len(records) == prior['appended_records'] == 5
    assert all(decoded.count(r) == 1 for r in records)
    assert all(r['accessed'] == '2026-09-26' for r in records)
    bottleneck = json.loads((HERE/'bottleneck.json').read_text())
    for rec in bottleneck['records']+bottleneck['latest_r2a_records']:
        assert sha(Path(rec['path'])) == rec['sha256']
        known = rec['witness_seconds']+rec['prove_seconds']+rec['serialization_seconds']
        assert abs(known-rec['known_readiness_components_sum_seconds']) < 1e-9
    assert bottleneck['native_grouped_ab']['state'] == 'waiting-for-heavy-lock'
    work = json.loads((HERE/'work-counts.json').read_text())
    case = work['synthetic_executed']
    assert case == result['cases'][-1]
    assert case['reference']['batch_multiplications'] == 49152
    assert case['candidate']['batch_multiplications'] == 768
    assert case['candidate']['field_inversions'] == case['reference']['field_inversions'] == 1
    for name, entry in json.loads((HERE/'source-context.json').read_text()).items():
        src = Path('/tmp/zk60-groups-20260926')/name
        assert sha(src) == entry['sha256']
        lines = src.read_text().splitlines()
        assert all('\n'.join(lines[r['first']-1:r['last']]) == r['text'] for r in entry['ranges'])
    docs = ['CLAUDE.md','docs/zkmatrix-poc/MVP_STATUS.md',
            'docs/zkmatrix-poc/ZK60_DECISIONS.md',
            'docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md']
    report = dict(status='passed', exit_code=0, checkpoint_utc=datetime.now(timezone.utc).isoformat(),
                  run_identity=result['run_identity'], cycle='0004',
                  source_pins_match=True, patch_applied_in_memory_only=True,
                  public_table_loop_and_challenge_calls_unchanged=True,
                  previous_source_log_prefix_preserved=True,
                  experiment_command='python3 experiments/pair-inverse-cache-20260926/experiment.py > experiments/pair-inverse-cache-20260926/run.log 2>&1',
                  validation_command='python3 experiments/pair-inverse-cache-20260926/validate.py > experiments/pair-inverse-cache-20260926/validation.log 2>&1',
                  cwd=str(RESEARCH), native_build_or_execution=False, gpu=False,
                  git=False, dependencies_installed=False, downloaded_code_executed=False,
                  runtime_writes=False, external_writes_or_messages=False,
                  reference_document_sha256={d:sha(ROOT/d) for d in docs},
                  artifact_sha256={str(p.relative_to(HERE)):sha(p) for p in HERE.rglob('*')
                                   if p.is_file() and p.name not in ('validation.json','validation.log')},
                  research_document_sha256={d:sha(RESEARCH/d) for d in
                    ('STATE.md','FINDINGS.md','sources.jsonl','handoffs/20260926-pair-inverse-cache.md')})
    (HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if not k.endswith('sha256')},indent=2))


if __name__ == '__main__':
    main()
