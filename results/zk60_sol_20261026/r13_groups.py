#!/usr/bin/env python3
"""Failing-first or passing group-fold tests in the isolated R13 copy."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    phase = sys.argv[1]
    assert phase in ('red', 'green')
    if phase == 'green':
        assert (stage.R13 / 'groups_red.done').read_text().strip() == '0'
    result = 1
    try:
        stage.run(f'r13-groups-{phase}-build', 'build', 0.7, 2,
                  ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(stage.R13 / 'test_groups.rs'),
                   '-o', str(stage.R13 / f'accuracy-groups-{phase}.bin')], 0)
        stage.run(f'r13-groups-{phase}-tests', 'cpu', 0.5, 1,
                  [str(stage.R13 / f'accuracy-groups-{phase}.bin'), '--test-threads=1'], 101 if phase == 'red' else 0)
        result = 0
    finally:
        (stage.R13 / f'groups_{phase}.done').write_text(f'{result}\n')
    sys.exit(result)
