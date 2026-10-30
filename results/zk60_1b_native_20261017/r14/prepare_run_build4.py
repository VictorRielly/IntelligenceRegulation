"""Pin C7g root uniqueness and matched timing after native stream PASS8/0."""
from datetime import datetime, timezone
import hashlib, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
TREE = HERE / 'working-tree'
old = json.loads((HERE / 'sol-r14-run-build-3.source.json').read_text())
assert (HERE / 'NATIVE_STREAM_ACCEPTANCE.done').read_text().strip() == '0'
checkpoint = HERE / 'checkpoints/run-build-3'
for name, want in old['files'].items():
    assert hashlib.sha256((checkpoint / 'tree' / name).read_bytes()).hexdigest() == want, name
    if name not in {'hashline/src/private_block/split_run.rs', 'hashline/src/private_block/split_run_tests.rs'}:
        assert hashlib.sha256((TREE / name).read_bytes()).hexdigest() == want, name
files = {name: hashlib.sha256((TREE / name).read_bytes()).hexdigest() for name in old['files']}
digest = hashlib.sha256(''.join(f'{k} {v}\n' for k, v in sorted(files.items())).encode()).hexdigest()
new = HERE / 'sol-r14-run-build-4.source.json'
assert not new.exists()
new.write_text(json.dumps({'tree_sha256': digest, 'count': len(files), 'files': files}, indent=2) + '\n')
state = json.loads((HERE / 'CURRENT_DEV_STATE.json').read_text())
state.update(utc=datetime.now(timezone.utc).isoformat(),
    phase='Stream PASS8/0; C7g root uniqueness and prove-only timing installed for build4',
    live_tool_sessions=[], live_tool_session=None, source_edits_held=True,
    live_stage='sol-r14-run-build-4', source_pin=str(new), source_sha256=digest,
    receipt_tradeoff='Native DD/nonDD first/last bytes exactly match counter; T128 backend receipt +~6%, A/H words -24..25%. Coordinator10:23 accepted proceed.',
    next='Compile root audit/timing; replay saved fresh streams; guarded DD/nonDD prove-only matched measurements. Baseline fixture index corrected separately. Remaining mandated attacks/parity/compatibility/security/captures/freeze/D24/privacy owed.')
(HERE / 'CURRENT_DEV_STATE.json').write_text(json.dumps(state, indent=2) + '\n')
print(json.dumps({'stage': 'run-build-4', 'source': digest, 'files': len(files)}))
