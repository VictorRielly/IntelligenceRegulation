"""Bounded A5 tests; no model weights, native prover build, GPU, DB or network."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent


def main():
    evidence = Path(sys.argv[1])
    if evidence.exists():
        raise ValueError('use a new evidence file for each test attempt')
    results = []

    def run(name, args, *, discard_stdout=False):
        before = time.monotonic()
        p = subprocess.run(args, cwd=HERE, stdout=subprocess.DEVNULL if discard_stdout else subprocess.PIPE,
                           stderr=subprocess.PIPE, text=True, timeout=90)
        row = {'name': name, 'exit': p.returncode, 'wall_seconds': time.monotonic() - before,
               'stdout': p.stdout or '', 'stderr': p.stderr}
        results.append(row)
        print(json.dumps({'step': name, 'exit': p.returncode}), flush=True)
        if p.returncode:
            raise RuntimeError(f'{name}: {p.stderr[-4000:]}')

    code = 1
    try:
        run('stage-native-delta', [sys.executable, str(HERE / 'stage_native.py')])
        sources = json.loads((HERE / 'native_sources.json').read_text())
        for relative in sources['staged_sha256']:
            run('rust-parse:' + relative, ['rustfmt', '--edition', '2021', '--emit', 'stdout', '--config', 'skip_children=true',
                                         str(HERE / 'staged/hashline' / relative)], discard_stdout=True)
        base = HERE.parents[2] / sources['baseline'] / 'src/private_block/token_io/classify_cli.rs'
        changed = HERE / 'staged/hashline/src/private_block/token_io/classify_cli.rs'
        marker = '/// a run directory CHECKED IN FULL'
        if base.read_bytes().split(marker.encode(), 1)[1] != changed.read_bytes().split(marker.encode(), 1)[1]:
            raise ValueError('candidate unexpectedly changed verifier/owner/label source')
        with tempfile.TemporaryDirectory(prefix='astra-a5-rust-') as tmp:
            binary = str(Path(tmp) / 'plan-tests')
            run('rust-plan-compile', ['rustc', '--edition=2021', '--test', '-C', 'codegen-units=1',
                                     str(HERE / 'native/light_tests.rs'), '-o', binary])
            run('rust-plan-tests', [binary, '--test-threads=1'])
        run('python-transport-tests', [sys.executable, '-m', 'unittest', 'discover', '-s', str(HERE), '-p', 'test_batch*.py', '-v'])
        code = 0
    finally:
        pins = {str(p.relative_to(HERE)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in ('.py', '.rs')}
        evidence.write_text(json.dumps({'at': datetime.now(timezone.utc).isoformat(), 'exit': code,
            'scope': 'light candidate transport/path tests, recorded R16 log payloads, pinned encoding; no new native proof',
            'native_full_build': False, 'native_integration': False, 'measured_batch_speedup': None,
            'steps': results, 'source_sha256': pins}, indent=2) + '\n')
    return code


if __name__ == '__main__':
    raise SystemExit(main())
