#!/usr/bin/env python3
"""Run red/green tests in the complete isolated native R13 crate."""
import importlib.util
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    name, phase, test_filter = sys.argv[1:]
    assert re.fullmatch(r'[a-z][a-z0-9-]*', name) and phase in ('red', 'green')
    if phase == 'green':
        assert (stage.R13 / f'{name}_red.done').read_text().strip() == '0'
    cargo = ['/home/victor/.cargo/bin/cargo', 'test', '--release', '--offline', '--locked', '-j2',
             '--manifest-path', str(stage.R13 / 'working-tree/hashline/Cargo.toml'), '--lib']
    result = 1
    try:
        stage.run(f'r13-{name}-{phase}-build', 'build', 2.5, 5, cargo + ['--no-run'], 0, seconds=900)
        stage.run(f'r13-{name}-{phase}-tests', 'cpu', 0.5, 2,
                  cargo + ['--', '--test-threads=1', test_filter], 101 if phase == 'red' else 0)
        result = 0
    finally:
        (stage.R13 / f'{name}_{phase}.done').write_text(f'{result}\n')
    sys.exit(result)
