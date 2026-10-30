"""Preserve the failed fixture attempt, correct only its R13 boundary index."""
from datetime import datetime, timezone
import hashlib, json, shutil
from pathlib import Path
HERE = Path(__file__).resolve().parent / 'matched-r13'
TREE = HERE / 'working-tree'
pin = json.loads((HERE / 'source.json').read_text())
checkpoint = HERE / 'checkpoints/attempt-1'
assert not checkpoint.exists()
assert (HERE / 'sol-r13-matched-non-dd-1.done').read_text().strip() == '101'
for name, want in pin['files'].items():
    source = TREE / name
    assert hashlib.sha256(source.read_bytes()).hexdigest() == want, name
    target = checkpoint / 'tree' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
bins = [p for p in (TREE / 'hashline/target/release/deps').glob('hashline-*')
        if p.is_file() and p.stat().st_mode & 0o111]
assert len(bins) == 1
shutil.copy2(bins[0], checkpoint / 'hashline.test.bin')
shutil.copy2(HERE / 'source.json', checkpoint / 'source.json')
file = TREE / 'hashline/src/private_block/matched_r14_benchmark.rs'
text = file.read_text()
assert text.count('if k != 1 {') == 1
file.write_text(text.replace('if k != 1 {', 'if k != 0 {'))
files = {name: hashlib.sha256((TREE / name).read_bytes()).hexdigest() for name in pin['files']}
digest = hashlib.sha256(''.join(f'{k} {v}\n' for k, v in sorted(files.items())).encode()).hexdigest()
(HERE / 'source.json').write_text(json.dumps({'tree_sha256': digest, 'count': len(files), 'files': files}, indent=2) + '\n')
(HERE / 'FIXTURE_ATTEMPT1.json').write_text(json.dumps({
    'utc': datetime.now(timezone.utc).isoformat(),
    'status': 'Test fixture failure before proof: R13 requests outgoing boundary at block index0; R14 fixture uses incoming stage index1.',
    'original_source': pin['tree_sha256'],
    'original_binary': hashlib.sha256(bins[0].read_bytes()).hexdigest(),
    'corrected_source': digest,
    'change': 'Test-only boundary_plane expected index1 -> index0; accepted R13 protocol code unchanged.',
}, indent=2) + '\n')
print(json.dumps({'source': digest, 'files': len(files)}))
