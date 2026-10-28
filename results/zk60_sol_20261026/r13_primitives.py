#!/usr/bin/env python3
"""Compile and run the R13 primitives inside the full isolated native crate."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('r13_stage', HERE / 'r13_red.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

if __name__ == '__main__':
    cargo = ['/home/victor/.cargo/bin/cargo', 'test', '--release', '--offline', '--locked', '-j2',
             '--manifest-path', str(stage.R13 / 'working-tree/hashline/Cargo.toml'), '--lib']
    result = 1
    try:
        stage.run('r13-primitives-build', 'build', 2.5, 5, cargo + ['--no-run'], 0, seconds=900)
        stage.run('r13-primitives-tests', 'cpu', 0.5, 2,
                  cargo + ['--', '--test-threads=1', 'accuracy'], 0, seconds=180)
        result = 0
    finally:
        (stage.R13 / 'primitives.done').write_text(f'{result}\n')
    sys.exit(result)
