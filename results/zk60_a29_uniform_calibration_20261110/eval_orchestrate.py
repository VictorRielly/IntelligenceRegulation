#!/usr/bin/env python3
"""A29: run the full A1 evaluation of one export as a chain of guarded cpu leaves (one per
stage, need 5 / cap 8 GiB, eight BLAS threads, Astra's per-leaf declaration), then the
export lane's UNCHANGED analyzer (analyze_verdicts.py --run). Launch detached:
  python3 run_detached.py <log> python3 eval_orchestrate.py --export DIR --run DIR --tag NAME
Progress: <run>/orchestrate.jsonl; exit code: <run>/orchestrate.done. A stage that stops at
its time box (exit 3) is resumed by the next leaf from its journal; any other failure stops.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PY = '/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python'
GUARD = '/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py'
EXPORT_LANE = Path('/Users/victorrielly/IntelligenceRegulation/results/zk60_shieldstral_export_20261026')


def note(run, **kw):
    with (run / 'orchestrate.jsonl').open('a') as f:
        f.write(json.dumps({'at': datetime.now(timezone.utc).isoformat(), **kw}) + '\n')


def leaf(run, tag, stage, export, logs):
    label = f'a29-eval-{tag}-{stage}'
    log, done = logs / f'{stage}.log', logs / f'{stage}.done'
    cmd = ['python3', GUARD, 'run', '--class', 'cpu', '--need-gib', '5', '--cap-gib', '8', '--max-secs', '2400',
           '--wait-secs', '14400', '--label', label, '--log', str(log), '--done', str(done),
           '--result-json', str(done) + '.json', '--', '/usr/bin/env', 'OPENBLAS_NUM_THREADS=8', 'OMP_NUM_THREADS=8',
           'VECLIB_MAXIMUM_THREADS=8', 'PYTHONDONTWRITEBYTECODE=1', PY, '-B', str(HERE / 'eval_stage.py'),
           '--export', str(export), '--run', str(run), '--minutes', '30', stage]
    rc = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=open(str(log) + '.guard', 'a'),
                        stderr=subprocess.STDOUT).returncode
    return rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--export', type=Path, required=True)
    ap.add_argument('--run', type=Path, required=True)
    ap.add_argument('--tag', required=True)
    a = ap.parse_args()
    a.run.mkdir(parents=True, exist_ok=True)
    logs = a.run / 'logs'; logs.mkdir(exist_ok=True)
    marker = a.run / 'orchestrate.done'
    if marker.exists():
        marker.unlink()
    note(a.run, event='start', pid=os.getpid(), export=str(a.export))
    code = 1
    try:
        for stage in ['input'] + [str(i) for i in range(26)] + ['finish']:
            for attempt in range(1, 6):
                rc = leaf(a.run, a.tag, stage, a.export, logs)
                note(a.run, stage=stage, attempt=attempt, rc=rc)
                if rc != 3:
                    break
            if rc != 0:
                note(a.run, event='stopped', stage=stage, rc=rc)
                code = rc
                return rc
        rc = subprocess.run([PY, '-B', str(EXPORT_LANE / 'analyze_verdicts.py'), '--run', str(a.run)],
                            stdin=subprocess.DEVNULL, stdout=open(logs / 'analyze.log', 'a'),
                            stderr=subprocess.STDOUT, cwd=str(EXPORT_LANE),
                            env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'}).returncode
        note(a.run, event='analyzed', rc=rc)
        code = rc
        return rc
    finally:
        marker.write_text(str(code) + '\n')


if __name__ == '__main__':
    sys.exit(main())
