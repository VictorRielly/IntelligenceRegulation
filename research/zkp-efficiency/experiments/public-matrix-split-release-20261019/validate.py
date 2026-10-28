"""Final local provenance, patch-replay and report-accounting gate; no build."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import resource
import signal
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RUN = '20261019T211854Z-fff84a98'
resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
signal.alarm(59)
os.nice(19)
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
start = time.perf_counter()
checks = 0


def check(value):
    global checks
    assert value
    checks += 1


def read(name):
    return json.loads((HERE / name).read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


pins = read('source-pins.json')
for row in pins:
    check(sha(Path(row['source'])) == row['sha256'])
    check(sha(HERE / row['snapshot']) == row['sha256'])
check(sum(p['r8_manifest_match'] is True for p in pins) == 14)
for row in read('input-pins.json'):
    check(sha(Path(row['path'])) == row['sha256'])

# Replay the exact standalone patch in memory, using source context as the gate.
base = (HERE / 'native/hashline__src__private_block__trained_block.rs').read_text()
lines = base.splitlines(True)
patch = (HERE / 'review-only-split-release.patch').read_text().splitlines(True)
result = []
cursor = 0
i = 2
hunks = 0
while i < len(patch):
    match = re.fullmatch(r'@@ -(\d+)(?:,\d+)? \+\d+(?:,\d+)? @@[^\n]*\n', patch[i])
    check(match is not None)
    offset = int(match[1]) - 1
    result.extend(lines[cursor:offset])
    cursor = offset
    i += 1
    hunks += 1
    while i < len(patch) and not patch[i].startswith('@@ '):
        line = patch[i]
        if line[0] in ' -':
            check(lines[cursor] == line[1:])
            cursor += 1
        if line[0] in ' +':
            result.append(line[1:])
        i += 1
result.extend(lines[cursor:])
candidate = (HERE / 'candidate-trained_block.rs').read_text()
check(''.join(result) == candidate)
check(hunks == 2)
check(candidate.count('let _ = (wq.sha256, exp.sha256);') == 1)
check(candidate.index('let fw = [') < candidate.index('drop((wq, wk, wv, wo, ga, gm, wg, wu, wd));') < candidate.index('let public = AttentionPublic::new_shaped'))
check(candidate.index('let blk = BlockPublic::new(public, ff);') < candidate.index('drop((exp, act));') < candidate.index('let mut source_tensors'))
check('fn i8s(&self) -> Vec<i8>' in base)

r = read('result.json')
a = read('audit-result.json')
check(r['status'] == a['status'] == 'PASS')
check(r['run_id'] == RUN and r['seed'] == 2026101989)
check(r['threads'] == a['threads'] == 1)
check(r['wall_seconds'] < 60 and a['wall_seconds'] < 60)
check(max(r['rss_kib'], a['rss_kib']) < 512 * 1024)
check(r['accepted_path_cases'] == a['accepted_path_cases'] == 78)
check(r['mutation_path_cases'] == a['independent_first_error_checks'] == 6720)
for n in r['negative_controls'].values():
    check(n == 78)
for command in read('commands.json'):
    check(command['exit_code'] == 0)
    check((HERE / command['stdout']).is_file())
    check((HERE / command['stderr']).read_text() == '')

ledger = read('payload-ledger.json')
check(len(ledger['rows']) == 32)
for row in ledger['rows']:
    check(row['after_envelope_bytes'] == max(row['after_phase_bytes']))
    check(row['saving_bytes'] == row['before_envelope_bytes'] - row['after_envelope_bytes'])
    check(row['after_current_next_pins_bytes'] == row['after_envelope_bytes'] + (row['pins'] + 1) * 243411456)
    if row['constructor'] == 'checked_move':
        check(row['incremental_saving_bytes'] == 0)
    if row['constructor'] == 'borrowed_copy' and row['decode_mode'] == 'native_decode' and not row['full']:
        check(row['saving_bytes'] == 67082752 and row['after_envelope_bytes'] == 638116864)
    if row['hash_workers'] == 16 and row['full']:
        check(row['incremental_saving_bytes'] == 0)
check(ledger['temporary_scope_correction']['delta_bytes'] == 117444608)

account = read('target-accounting.json')
check(account['run_id'] == RUN)
for key in ['new_target_proofs', 'new_target_positions', 'new_target_passes', 'passes']:
    check(account[key] == 0)
for key in ['target_steady_state_positions_per_second', 'target_total_workload_positions_per_second', 'startup_fraction', 'witness_seconds', 'proof_seconds', 'serialization_seconds', 'verification_seconds', 'device', 'context_length']:
    check(account[key] is None)
check(account['carried_owner']['researcher_independent_verification'] is False)
queue = read('hypotheses.json')
check(len(queue) == 7 and [q['rank'] for q in queue] == list(range(1, 8)))
check(len({q['id'] for q in queue}) == 7)
check(queue[3]['id'] == 'new-separate-decode-temporary-statement-scopes')
for q in queue:
    for key in ['baseline', 'eliminated_work', 'added_costs', 'end_to_end_ceiling', 'prerequisites', 'integration_cost', 'exactness', 'privacy_soundness', 'compatibility', 'falsification']:
        check(bool(q[key]))

records = read('source-records.json')
all_sources = [json.loads(x) for x in (ROOT / 'sources.jsonl').read_text().splitlines()]
check(len(records) == 6 and all_sources[-6:] == records)
check(all(x['inspected_commit_id'] is None for x in records))
check(all(not x['external_execution'] and not x['reproduced_performance'] for x in records))
for doc in ['STATE.md', 'PROGRESS.md', 'FINDINGS.md', 'progress/' + RUN + '.md']:
    text = (ROOT / doc).read_text()
    check(RUN in text)
    check('No speed improvement measured' in text)
    check('638116864' in text or '63.98' in text)

changed_docs = []
for row in read('startup-manifest.json'):
    p = Path(row['path'])
    if p.name in ['CLAUDE.md', 'AGENDA.md', 'ZK60_THROUGHPUT_TARGET.md', 'MVP_STATUS.md', 'ZK60_DECISIONS.md', 'ZK60_CODEX_FABLE_COORDINATION.md'] and sha(p) != row['sha256']:
        changed_docs.append(str(p))
check(not changed_docs)
out = dict(status='PASS', checks=checks, source_pins=len(pins), r8_manifest_matches=14,
           in_memory_patch_hunks=hunks, changed_direction_documents=changed_docs,
           wall_seconds=time.perf_counter() - start,
           rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
           checkpoint=datetime.datetime.now(datetime.timezone.utc).isoformat(),
           scope='Local provenance/semantic/synthetic/report gate; no Rust build, loader, proof, GPU or RSS benchmark')
(HERE / 'validation-result.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out, sort_keys=True))
