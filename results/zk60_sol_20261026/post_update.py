#!/usr/bin/env python3
"""Post a Sol milestone to the authorized shared log and durable status."""
from datetime import datetime, timezone
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
TODO = ROOT / 'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md'
ANCHOR = '\n---\n\n## Astra'

if __name__ == '__main__':
    message = ' '.join(sys.argv[1:]).strip()
    assert message
    line = '\n- ' + datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ') + ': ' + message + '\n'
    text = TODO.read_text()
    assert text.count(ANCHOR) == 1
    TODO.write_text(text.replace(ANCHOR, line + ANCHOR))
    with (Path(__file__).resolve().parent / 'PROGRESS.md').open('a') as stream:
        stream.write(line)
    print(line.strip())
