#!/usr/bin/env python3
"""Run the implemented int12 table tests after their retained failing run."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    assert (stage.R13 / 'tables_red.done').read_text().strip() == '0'
    source = stage.SOURCE.with_name('accuracy_tables.rs')
    result = 1
    try:
        stage.run('r13-tables-green-build', 'build', 0.7, 2,
                  ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(source),
                   '-o', str(stage.R13 / 'accuracy-tables-green.bin')], 0)
        stage.run('r13-tables-green-tests', 'cpu', 0.5, 1,
                  [str(stage.R13 / 'accuracy-tables-green.bin'), '--test-threads=1'], 0)
        result = 0
    finally:
        (stage.R13 / 'tables_green.done').write_text(f'{result}\n')
    sys.exit(result)
