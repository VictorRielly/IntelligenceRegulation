#!/usr/bin/env python3
"""Read every coordinator check-in without confusing it with the lane logs."""
from pathlib import Path
import datetime
import hashlib
import json

ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = Path(__file__).resolve().parent
source = ROOT / 'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md'
text = source.read_text().split('## Coordinator notes', 1)[1].split('\n## Backlog', 1)[0]
previous = OUT / 'coordinator.last_seen.txt'
old = previous.read_text() if previous.exists() else ''
if old and text.startswith(old):
    delta = text[len(old):]
    print(delta if delta.strip() else 'No new coordinator notes.')
else:
    print('\n'.join(text.splitlines()[-45:]))
previous.write_text(text)
(OUT / 'coordinator.last_seen.json').write_text(json.dumps({
    'read_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'sha256': hashlib.sha256(text.encode()).hexdigest(), 'source': str(source)}, indent=2) + '\n')
