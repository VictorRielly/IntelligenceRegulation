#!/usr/bin/env python3
"""Run one isolated R13 component through retained red/green gates."""
import hashlib
import importlib.util
from pathlib import Path
import re
import shutil
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    name, phase, relative = sys.argv[1:]
    assert re.fullmatch(r'[a-z][a-z0-9-]*', name) and phase in ('red', 'green')
    source = (stage.R13 / relative).resolve()
    assert source.is_relative_to(stage.R13)
    if phase == 'green':
        assert (stage.R13 / f'{name}_red.done').read_text().strip() == '0'
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    if phase == 'red':
        shutil.copy2(source, stage.R13 / f'{name}.failing-first.rs')
    result = 1
    try:
        stage.run(f'r13-{name}-{phase}-build', 'build', 0.7, 2,
                  ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(source),
                   '-o', str(stage.R13 / f'{name}-{phase}.bin')], 0)
        stage.run(f'r13-{name}-{phase}-tests', 'cpu', 0.5, 1,
                  [str(stage.R13 / f'{name}-{phase}.bin'), '--test-threads=1'], 101 if phase == 'red' else 0)
        assert hashlib.sha256(source.read_bytes()).hexdigest() == before
        result = 0
    finally:
        (stage.R13 / f'{name}_{phase}.done').write_text(f'{result}\n')
    sys.exit(result)
