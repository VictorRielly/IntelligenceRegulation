#!/usr/bin/env python3
"""Capture failing-first int12 table tests, using the shared stage runner."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    source = stage.SOURCE.with_name('accuracy_tables.rs')
    result = 1
    try:
        stage.run('r13-tables-red-build', 'build', 0.7, 2,
                  ['/home/victor/.cargo/bin/rustc', '--edition=2021', '--test', str(source),
                   '-o', str(stage.R13 / 'accuracy-tables-red.bin')], 0)
        stage.run('r13-tables-red-tests', 'cpu', 0.5, 1,
                  [str(stage.R13 / 'accuracy-tables-red.bin'), '--test-threads=1'], 101)
        result = 0
    finally:
        (stage.R13 / 'tables_red.done').write_text(f'{result}\n')
    sys.exit(result)
