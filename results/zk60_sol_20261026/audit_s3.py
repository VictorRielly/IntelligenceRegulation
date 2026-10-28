#!/usr/bin/env python3
"""Verify and record the completed S3 swap without launching guarded work."""
import datetime
import difflib
import hashlib
import json
from pathlib import Path
import re

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = ROOT / 'results/zk60_sol_20261026'
NEW = '87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c'
OLD = 'f0b87668b9ad3bc42683d95a16314b54973b8e36be576b25183302287168e772'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert (OUT / 'guard_swap.done').read_text().strip() == '0'
assert sha(ROOT / 'scripts/zk60_resource_guard.py') == NEW
assert sha(ROOT / 'tests/test_zk60_guard_fix.py') == '7814c8f43f8ab5fc337fbe1ffa1c1740f8eb812ca58e93bd90a59747cff512c9'
assert sha(OUT / 'guard-backup/zk60_resource_guard.py') == OLD
for name, variable in [('zk60_guarded_command.py', 'REVIEWED_GUARD_SHA256'), ('zk60_techweek_demo.py', 'GUARD_PIN')]:
    before = (OUT / 'guard-backup' / name).read_text()
    after = (ROOT / 'scripts' / name).read_text()
    assert after == before.replace(f"{variable} = '{OLD}'", f"{variable} = '{NEW}'", 1)
assert sha(ROOT / 'scripts/zk60_private_stack_benchmark.py') == sha(OUT / 'guard-backup/zk60_private_stack_benchmark.py')
assert not Path('/tmp/zk-guard/fifo.on').exists()
records = json.loads((OUT / 'guard_swap_tests.json').read_text())
assert len(records) == 5 and all(row['exit'] == 0 for row in records)
assert all(row.get('all_cases_executed') is True for row in records[:2])
counts = {}
for row in records:
    log = (OUT / f'installed_{row["suite"]}.log').read_text()
    assert 'OK' in log and 'skipped=' not in log
    counts[row['suite']] = int(re.search(r'Ran (\d+) tests?', log).group(1))
assert counts['test_zk60_resource_guard.py'] == 45 and counts['test_zk60_guard_fix.py'] == 31
now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
message = f'{now}: S3 SWAPPED {NEW}. Host preflight READY; all lane HOLDs retained; own prior sessions terminal. Installed official suites 45/45 and 31/31 pass without skips; consumer suites {counts}. Both static pins equal the new guard; private_stack_benchmark unchanged and remains a dynamic hash consumer. FIFO OFF. Rollback/source diffs/hash manifest and S3_AUDIT.json retained under results/zk60_sol_20261026/. Claude may close the window/release lane holds; Sol starts no R13 job until S3 WINDOW CLOSED. Please update the two historical known-gap paragraphs in LANE_RULES (outside Sols write set).'
with (OUT / 'PROGRESS.md').open('a') as f:
    f.write('\n- ' + message + '\n')
with (ROOT / 'ops/zkp-mvp/RECOVERY_COORDINATION.md').open('a') as f:
    f.write('\n\n## Sol S3 terminal — ' + now + '\n\n' + message + '\n')
path = ROOT / 'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md'
text = path.read_text()
anchor = '\n---\n\n## Astra'
assert anchor in text
path.write_text(text.replace(anchor, '\n- ' + message + '\n' + anchor, 1))
paths = ['scripts/zk60_resource_guard.py', 'scripts/zk60_guarded_command.py', 'scripts/zk60_techweek_demo.py',
         'scripts/zk60_private_stack_benchmark.py', 'tests/test_zk60_guard_fix.py',
         'docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md', 'ops/zkp-mvp/RECOVERY_COORDINATION.md']
patch = []
for relative in paths:
    current = ROOT / relative
    backup = OUT / 'guard-backup' / current.name
    before = backup.read_text().splitlines(keepends=True) if backup.exists() else []
    patch.extend(difflib.unified_diff(before, current.read_text().splitlines(keepends=True),
                                     fromfile='a/' + relative, tofile='b/' + relative))
(OUT / 'guard_swap.patch').write_text(''.join(patch))
audit = dict(written_utc=now, s3_complete=True, guard_sha256=NEW, fifo_enabled=False,
             suites=counts, static_pins_verified=True, dynamic_consumer_unchanged=True,
             source_snapshot_sha256={relative: sha(ROOT / relative) for relative in paths},
             patch_sha256=sha(OUT / 'guard_swap.patch'),
             rollback_guard_sha256=sha(OUT / 'guard-backup/zk60_resource_guard.py'))
(OUT / 'S3_AUDIT.json').write_text(json.dumps(audit, indent=2) + '\n')
print(message)
