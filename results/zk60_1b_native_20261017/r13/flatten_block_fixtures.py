#!/usr/bin/env python3
"""Encode the independent JSON oracle as std-only Rust test inputs."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
VECTORS = HERE / 'working-tree/hashline/src/private_block/r13_vectors'

def flat(value):
    if isinstance(value, list):
        for item in value:
            yield from flat(item)
    else:
        yield int(value)

def write(name, rows):
    path = VECTORS / name
    path.write_text(''.join(key + '\t' + '\t'.join(map(str, flat(value))) + '\n' for key, value in rows))
    return dict(path=str(path.relative_to(HERE)), sha256=hashlib.sha256(path.read_bytes()).hexdigest())

if __name__ == '__main__':
    source = VECTORS / 'block_fixture_t32.json'
    fixture = json.loads(source.read_text())
    rows = [(key, fixture[key]) for key in ['input', 'gamma', 'cos', 'sin', 'exp', 'members', 'groups']]
    rows += [('w_' + key, value) for key, value in fixture['weights'].items()]
    rows += [('m_' + key, value) for key, value in fixture['multipliers'].items()]
    artifacts = [write('block_fixture_t32.tsv', rows)]
    for stack in ['low', 'low_h24']:
        trace_source = VECTORS / f'block_trace_{stack}_t32.json'
        trace = json.loads(trace_source.read_text())['trace']
        artifacts.append(write(f'block_trace_{stack}_t32.tsv', trace.items()))
    (HERE / 'block_flat_fixtures.json').write_text(json.dumps(dict(
        description='Independent integer Python oracle, crosschecked at 15 sites against fp_lib; synthetic T32',
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), artifacts=artifacts), indent=2) + '\n')
