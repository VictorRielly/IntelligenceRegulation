#!/usr/bin/env python3
"""Run a named R13 component phase or native filter through direct admission."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_guard', HERE / 'r13_guard.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    name, mode, target = sys.argv[1:]
    assert re.fullmatch(r'[a-z][a-z0-9-]*', name) and mode in ('component', 'red', 'green', 'native')
    if mode == 'green':
        assert (stage.R13 / f'{name}_red.done').read_text().strip() == '0'
    tag = name + ('_' + mode if mode in ('red', 'green') else '')
    assert not (stage.R13 / f'{tag}.done').exists(), 'Retain old terminal markers; choose a fresh run name'
    if mode != 'native':
        source = (stage.R13 / target).resolve()
        assert source.is_relative_to(stage.R13)
        commands = [
            ('build', .7, 2, ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(source), '-o', str(stage.R13 / f'{tag}.bin')], 180, 0),
            ('cpu', .5, 1, [str(stage.R13 / f'{tag}.bin'), '--test-threads=1'], 180, 101 if mode == 'red' else 0),
        ]
    else:
        cargo = ['/home/victor/.cargo/bin/cargo', 'test', '--release', '--offline', '--locked', '-j2',
                 '--manifest-path', str(stage.R13 / 'working-tree/hashline/Cargo.toml'), '--lib']
        commands = [('build', 2.5, 5, cargo + ['--no-run'], 900, 0),
                    ('cpu', .5, 2, cargo + [target, '--', '--test-threads=1'], 180, 0)]
    roots = [stage.R13 / 'working-tree/hashline/src', stage.R13 / 'precision-next', stage.R13 / 'aligned-next']
    before = {str(path.relative_to(stage.R13)): hashlib.sha256(path.read_bytes()).hexdigest()
              for root in roots for path in root.rglob('*') if path.is_file()}
    (stage.R13 / f'{tag}.source.json').write_text(json.dumps(before, indent=2, sort_keys=True) + '\n')
    result = 1
    try:
        for label, need, cap, command, seconds, expected in commands:
            stage.run('r13-' + tag.replace('_', '-') + '-' + label, label, need, cap, command, expected, seconds=seconds)
        assert all(hashlib.sha256((stage.R13 / path).read_bytes()).hexdigest() == digest for path, digest in before.items())
        result = 0
    finally:
        (stage.R13 / f'{tag}.done').write_text(f'{result}\n')
    sys.exit(result)
