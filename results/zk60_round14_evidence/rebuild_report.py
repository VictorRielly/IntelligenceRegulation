import hashlib
import json
from pathlib import Path
import re
import shutil

root = Path('/home/victor/IntelligenceRegulation')
scratch = Path('/tmp/zk60-round14')
out = root / 'results/zk60_round14_evidence'
final = scratch / 'complete'
assert (final / 'validation.done').read_text().strip() == '0'
report = json.loads((final / 'summary.json').read_text())
assert report['validation_status'] == 'complete' and report['exit_code'] == 0
assert report['rust_tests_total'] == {'passed': 219, 'failed': 0, 'ignored': 0}

def digest(p):
    b = p.read_bytes()
    return {'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()}

def copy(src, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)
    assert digest(src) == digest(dest)

def retain_run(src, dest):
    for p in sorted(src.iterdir()):
        if p.is_file() and (p.suffix in ('.log', '.time') or p.name in
                            ('validate.py', 'launch.py', 'summary.json', 'validation.done', 'runner.pid')):
            # Root scratch also contains a separate tooling test run.
            if p.name.startswith('python_consumers'): continue
            copy(p, dest / p.name)

retain_run(scratch, out / 'registration_only')
retain_run(scratch / 'final', out / 'attempts/merge_compile_1')
retain_run(scratch / 'combined', out / 'attempts/merge_compile_2')
retain_run(scratch / 'validated', out / 'attempts/floor_lock_failure')
copy(scratch / 'validated/source_before_lock_fix.json', out / 'attempts/floor_lock_failure/source_before_lock_fix.json')
for p in (scratch / 'validated/floors').iterdir():
    if p.is_file() and p.suffix in ('.out', '.json', '.log', '.done'):
        copy(p, out / 'attempts/floor_lock_failure/floors' / p.name)
retain_run(final, out / 'combined')
for name in ('graph_a.json', 'graph_b.json'):
    copy(final / name, out / 'combined' / name)
for p in (final / 'floors').iterdir():
    if p.is_file() and p.suffix in ('.out', '.json', '.log', '.done'):
        copy(p, out / 'combined/floors' / p.name)
for p in scratch.glob('python_consumers.*'):
    copy(p, out / 'attempts/floor_lock_failure/consumers' / p.name)
for p in (final / 'consumers').glob('python_consumers.*'):
    copy(p, out / 'consumers' / p.name)
review = scratch / 'core-review'
for name in ('run.py', 'launch.py', 'runner.log', 'probes.log', 'probes.done',
             'source.json', 'pcs_review.json', 'held_source.patch',
             'snapshot_sha256.json', 'reconstruct.py'):
    copy(review / name, out / 'review' / name)
for name in ('Cargo.toml', 'Cargo.lock', 'src/main.rs'):
    copy(review / 'probe' / name, out / 'review/probe' / name)
for p in (scratch / 'lock-review').iterdir():
    if p.is_file() and p.suffix in ('.rs', '.json', '.py', '.log', '.done'):
        copy(p, out / 'lock_review' / p.name)

for s in report['stages']:
    s['retained_log'] = str((out / 'combined' / Path(s['log']).name).relative_to(root))
    s['retained_resource_log'] = str((out / 'combined' / Path(s['resource_log']).name).relative_to(root))
report['combined_manifest']['retained_path'] = str((out / 'combined/floors/manifest.json').relative_to(root))
manifest = json.loads((final / 'floors/manifest.json').read_text())
for c in manifest['cases']:
    p = out / 'combined/floors' / Path(c['log']['path']).name
    assert digest(p)['sha256'] == c['log']['sha256'], c['id']
report['retained_floor_logs'] = {
    c['id']: str((out / 'combined/floors' / Path(c['log']['path']).name).relative_to(root))
    for c in manifest['cases']}
report['validation_resources'] = {
    'cpu_stage_address_space_limit_bytes': 8 << 30,
    'combined_gpu_floors_address_space_cap': None,
    'reason': 'CUDA requires large virtual address reservations; hardware work is limited to the frozen FFN fixtures and oracle cases.',
    'heavy_job_serialized': True,
    'build_and_rayon_threads': 2,
}
times = [Path(s['resource_log']).read_text() for s in report['stages']]
report['validation_resources']['max_reported_stage_rss_kib'] = max(
    int(re.search(r'Maximum resident set size \(kbytes\): (\d+)', t)[1]) for t in times)
report['validation_resources']['reported_stage_swaps'] = sum(int(re.search(r'Swaps: (\d+)', t)[1]) for t in times)
consumers = json.loads((final / 'consumers/python_consumers.json').read_text())
assert consumers['exit_code'] == 0
assert re.search(r'Ran 343 tests.*\n\nOK\s*$', (final / 'consumers/python_consumers.log').read_text())
report['python_consumers'] = dict(consumers, passed=343, skipped=0,
    retained_log='results/zk60_round14_evidence/consumers/python_consumers.log')
report['full_python_native_suite'] = {'rerun': False, 'historical_passed': 546, 'historical_round': 11,
    'note': '343 affected tooling consumer tests rerun; unrelated native/full Python suite retains prior evidence.'}
report['registration_only_run'] = {'source_commit': '7a9273b910890c4638b70b1f5c3d45d9d10b1ce0',
    'exit_code': 0, 'rust_tests': 218, 'frozen_cpu_proofs': 4,
    'retained_summary': 'results/zk60_round14_evidence/registration_only/summary.json'}
report['earlier_combined_attempts'] = [
    {'source_commit': 'b044e20', 'exit_code': 1, 'test_command_exit': 101,
     'stage': 'hashline_tests', 'issue': 'E0004: protected-material Drop did not cover the borrowed generic CPU external-store variant.',
     'retained_summary': 'results/zk60_round14_evidence/attempts/' + n + '/summary.json',
     'gpu_stage_executed': False}
    for n in ('merge_compile_1', 'merge_compile_2')]
report['earlier_attempt_note'] = 'The second attempt corrected unused report parser keys but repeated the same compile failure. 83115b5 fixes the source integration before the successful final run.'
report['lock_failure_run'] = {'source_commit': '83115b5762156dc390618b63d2d7b1c68712bc33',
    'retained_summary': 'results/zk60_round14_evidence/attempts/floor_lock_failure/summary.json',
    'retained_manifest': 'results/zk60_round14_evidence/attempts/floor_lock_failure/floors/manifest.json',
    'rust_storage_and_core_passed': 218, 'python_consumers_passed': 343,
    'floor_cases_recorded': 21, 'oracle_cases_passed': 189, 'frozen_proof_cases_passed': 12,
    'default_feature_unit_tests': {'passed': 52, 'failed': 1},
    'overall_accepted': False,
    'raw_summary_gpu_flag_note': 'The raw runner sets gpu_executed only after the entire floor stage succeeds, so it remains false in this failed-run summary. The retained case manifest/logs establish the actual 189-case GPU execution and 12 passing byte comparisons.',
    'failure': 'Reopening immediately after Drop can return Busy while a child process inherits the file description before exec. Fixed with an owned lock guard that explicitly unlocks before closing, including initialization error paths.',
    'native_reproduction': 'results/zk60_round14_evidence/lock_review/native.log',
    'deterministic_regression': 'dropping_owner_unlocks_descriptors_inherited_during_process_startup'}
report['core_integration'] = {'pcs_commit': '76ee27513763b7992bd57638b203b7ce76e6a8ed',
    'scanner_commit': 'ee775be', 'merge_commit': 'b044e20', 'compatibility_commit': '83115b5',
    'journal_lock_fix_commit': 'df7fb0d',
    'held_decoder_commit': 'f8d40a74e07ee9d60f869fe323eee2a2f564f067', 'held_decoder_integrated': False,
    'findings': ['C20-R1', 'C20-R2', 'C20-R3'],
    'snapshot_reconstruction': {'files': 94, 'all_sha256_match': True,
       'method': 'integrated 76ee275 Git archive plus retained held_source.patch'}}
report['source_identity_note'] = 'Docs/task records were edited during the run. Both hashline and zkp-core tracked source/manifests/lockfiles were clean at start and retained hashes were unchanged at completion. The embedded legacy suite-v3 dirty delta covers only hashline; this outer check does not complete CL21.'
report['evidence_directory'] = 'results/zk60_round14_evidence'
report['retained_index'] = 'results/zk60_round14_evidence/index.json'
(root / 'results/zk60_round14_validation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ('source_commit', 'rust_tests_total', 'default_hashline_tests', 'validation_resources')}, indent=2))
print('Retained', len([p for p in out.rglob('*') if p.is_file()]), 'files; README/index to finalize.')
