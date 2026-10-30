"""Pin malicious receipt tests after matched native measurement completion."""
from datetime import datetime, timezone
import hashlib, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
TREE = HERE / 'working-tree'
assert (HERE / 'ROOT_AUDIT_MATCHED_CHECKS.done').read_text().strip() == '0'
old = json.loads((HERE / 'sol-r14-run-build-4.source.json').read_text())
changed = {'hashline/src/private_block/' + name for name in [
    'argument.rs', 'split_protocol.rs', 'split_witness.rs', 'split_run_tests.rs']}
for name, want in old['files'].items():
    assert hashlib.sha256((HERE / 'checkpoints/run-build-4/tree' / name).read_bytes()).hexdigest() == want, name
    if name not in changed: assert hashlib.sha256((TREE / name).read_bytes()).hexdigest() == want, name
names = set(old['files']) | {'hashline/src/private_block/split_attack_tests.rs'}
files = {name: hashlib.sha256((TREE / name).read_bytes()).hexdigest() for name in sorted(names)}
digest = hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest()
path = HERE / 'sol-r14-run-build-5.source.json'; assert not path.exists()
path.write_text(json.dumps({'tree_sha256': digest, 'count': len(files), 'files': files}, indent=2) + '\n')
state = json.loads((HERE / 'CURRENT_DEV_STATE.json').read_text())
state.update(utc=datetime.now(timezone.utc).isoformat(),phase='Malicious complete-receipt cases installed for compile',
    source_sha256=digest,source_pin=str(path),source_edits_held=True,live_tool_sessions=[],
    live_stage='sol-r14-run-build-5',live_tool_session=None,
    next='Compile, then guard DD/non-DD six split-specific emitted receipt attacks. No source edits while queued/running; native captures/parity/compatibility/trained CLI/security/freeze/D24/privacy still owed.')
(HERE / 'CURRENT_DEV_STATE.json').write_text(json.dumps(state, indent=2) + '\n')
print(json.dumps({'source': digest, 'files': len(files)}))
