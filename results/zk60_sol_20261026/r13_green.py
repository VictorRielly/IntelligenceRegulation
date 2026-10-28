#!/usr/bin/env python3
"""Run the implemented R13 scalar tests after the retained failing-first run."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    assert (stage.R13 / 'red.done').read_text().strip() == '0', 'retain the expected failing-first evidence'
    result = 1
    try:
        stage.run('r13-green-build', 'build', 0.7, 2,
                  ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(stage.SOURCE),
                   '-o', str(stage.R13 / 'accuracy-green.bin')], 0)
        stage.run('r13-green-tests', 'cpu', 0.5, 1,
                  [str(stage.R13 / 'accuracy-green.bin'), '--test-threads=1'], 0)
        result = 0
    finally:
        (stage.R13 / 'green.done').write_text(f'{result}\n')
    sys.exit(result)
