#!/usr/bin/env python3
"""Check retained artifacts and the proposed diff without executing native code."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import resource
import signal

resource.setrlimit(resource.RLIMIT_AS, (512 * 2**20, 512 * 2**20))
resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
signal.alarm(59)
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
EXP = Path(__file__).resolve().parent
RESEARCH = EXP.parent.parent
ROOT = RESEARCH.parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


x = json.loads((EXP/'result.json').read_text())
assert x['status'] == 'passed' and x['differential_cases'] == 90
assert x['mapped_comparisons'] == 240 and x['direct_output_points'] == 10560
assert x['lagrange_points'] == 360 and len(x['conformance_vectors']) == 15
assert all(x['negative_controls'].values()) and x['malformed_fixture_refusals'] == 3
assert x['closed_form_overlap']['mismatch_columns'] == 32
assert sha(EXP/'experiment.py') == x['source_sha256']
assert all(sha(ROOT/p) == h for p,h in x['source_pins'].items())
assert x['threads'] == 1 and x['elapsed_seconds'] < 60
assert x['peak_rss_kib'] < 512*1024
assert all(x[k] is None for k in ['proving_seconds','verification_seconds','complete_readiness_seconds'])

pm = json.loads((EXP/'patch-provenance.json').read_text())
source_path = Path(pm['source_path'])
assert sha(source_path) == pm['source_sha256']
assert sha(EXP/'cuda-pad-overlap.proposed.patch') == pm['patch_sha256']
source = source_path.read_text()
diff = (EXP/'cuda-pad-overlap.proposed.patch').read_text().splitlines(True)
assert sum(line.startswith('@@') for line in diff) == 1
hunk = diff[3:]
before = ''.join(line[1:] for line in hunk if line[:1] in [' ','-'])
after = ''.join(line[1:] for line in hunk if line[:1] in [' ','+'])
assert source.count(before) == 1
assert hashlib.sha256(source.replace(before,after).encode()).hexdigest() == pm['proposed_source_sha256']

sources = [json.loads(line) for line in (RESEARCH/'sources.jsonl').read_text().splitlines()]
latest = json.loads((EXP/'source-records.json').read_text())
assert len(sources) == len({s['id'] for s in sources})
assert all(s in sources for s in latest) and len(latest) == 6
assert all(s['accessed'] == '2026-09-26' and
           all(k in s for k in ['publication_date','update_date','implementation_license','inspected_commit_id'])
           for s in latest)
other = RESEARCH/'experiments/forward-budget-20260926/result.json'
assert len(json.loads(other.read_text())['self_checks_passed']) == 14

required = ['CLAUDE.md','docs/zkmatrix-poc/MVP_STATUS.md',
            'docs/zkmatrix-poc/ZK60_DECISIONS.md',
            'docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md',
            'docs/zkmatrix-poc/ZK60_ENCODE_CONFORMANCE_VECTORS.md',
            'results/zk60_grouped_rounds_20260926/validation-1/validation.json',
            'results/zk60_grouped_rounds_20260926/dense-ab-1/comparison.json']
checks = {
    'exit_code':0, 'result_and_source_hash_checks':True,
    'proposed_patch_in_memory_check':True, 'source_log_records_present':True,
    'production_sources_still_match_experiment_pins':True,
    'experiment_command':'python3 experiments/ntt-mapped-layout-20260926/experiment.py > experiments/ntt-mapped-layout-20260926/run.log 2>&1',
    'validation_command':'python3 experiments/ntt-mapped-layout-20260926/validate.py',
    'cwd':str(RESEARCH), 'run_identity':x['run_identity'], 'cycle':'0003',
    'checkpoint_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'no_native_build_or_execution':True, 'no_gpu':True, 'no_git':True,
    'no_dependencies_installed':True, 'no_downloaded_code_executed':True,
    'no_runtime_writes':True, 'no_external_writes_or_messages':True,
    'reference_document_sha256':{p:sha(ROOT/p) for p in required},
    'artifact_sha256':{p.name:sha(p) for p in EXP.iterdir()
                       if p.is_file() and p.name not in ['validation.json','validation.log']},
    'research_document_sha256':{p:sha(RESEARCH/p) for p in
        ['STATE.md','FINDINGS.md','sources.jsonl','handoffs/20260926-ntt-layout-and-pad-overlap.md']},
    'separate_session_result_sha256':sha(other),
}
(EXP/'validation.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps({k:checks[k] for k in
    ['exit_code','result_and_source_hash_checks','proposed_patch_in_memory_check','checkpoint_utc']},indent=2))
