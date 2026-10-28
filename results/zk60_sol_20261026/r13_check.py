#!/usr/bin/env python3
"""Retain one bounded R13 component/native verification run."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    name, kind, target = sys.argv[1:]
    assert re.fullmatch(r'[a-z][a-z0-9-]*', name) and kind in ('component', 'native')
    if kind == 'component':
        source = (stage.R13 / target).resolve()
        assert source.is_relative_to(stage.R13)
        commands = [
            ('build', .7, 2, ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(source), '-o', str(stage.R13 / f'{name}.bin')], 180),
            ('cpu', .5, 1, [str(stage.R13 / f'{name}.bin'), '--test-threads=1'], 180),
        ]
    else:
        cargo = ['/home/victor/.cargo/bin/cargo', 'test', '--release', '--offline', '--locked', '-j2',
                 '--manifest-path', str(stage.R13 / 'working-tree/hashline/Cargo.toml'), '--lib']
        commands = [('build', 2.5, 5, cargo + ['--no-run'], 900),
                    ('cpu', .5, 2, cargo + [target, '--', '--test-threads=1'], 180)]
    root = stage.R13 / 'working-tree/hashline/src/private_block'
    before = {str(path.relative_to(stage.R13)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in root.rglob('*') if path.is_file()}
    (stage.R13 / f'{name}.source.json').write_text(json.dumps(before, indent=2, sort_keys=True) + '\n')
    result = 1
    try:
        for label, need, cap, command, seconds in commands:
            stage.run('r13-' + name + '-' + label, label, need, cap, command, 0, seconds=seconds)
        assert all(hashlib.sha256((stage.R13 / path).read_bytes()).hexdigest() == digest for path, digest in before.items())
        result = 0
    finally:
        (stage.R13 / f'{name}.done').write_text(f'{result}\n')
    sys.exit(result)
