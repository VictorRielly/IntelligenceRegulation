"""Promote the tested app delta only after the original public demo is terminal.

Run on the host so live app processes are visible. Source snapshots are retained;
this does not restart services, run proofs, reset data, or write git metadata.
"""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
APP = ROOT / 'apps/proven-media'
CANDIDATE = HERE / 'privacy_app_candidate'
DEMO = HERE / 'real_app_demo_1'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    # A sandbox PID namespace cannot attest process quiescence on the host.
    # The old validation run predates a reboot; its namespace inode is no
    # longer a host identity. Require the current host init namespace instead.
    # Reading root-owned /proc/1/ns/pid is denied to this host user. The
    # sandbox's PID 1 is codex-linux-san; require host init and a single
    # visible PID namespace level without requesting root privileges.
    status = dict(line.split(':', 1) for line in Path('/proc/self/status').read_text().splitlines() if ':' in line)
    require(Path('/proc/1/comm').read_text().strip() in ('systemd', 'init', '/init')
            and status.get('NSpid', '').split() == [str(os.getpid())],
            'run on the host for process visibility')
    evidence = json.loads((CANDIDATE / 'evidence.json').read_text())
    require(evidence['tests'] == 183 and evidence['frontend_behavioral_checks']['passed'] == 5,
            'candidate validation evidence missing')
    require((DEMO / 'worker.done').read_text().strip() == '0', 'first real demo has not reached terminal success')
    complete = json.loads((DEMO / 'complete.json').read_text())
    require(complete['source_sha256_revalidated'] is True, 'original demo source provenance not validated')
    require(json.loads((DEMO / 'stored_verify_complete.json').read_text())['accepted'] is True,
            'stored receipt verification incomplete')
    require(json.loads((DEMO / 'input_owner_capture.json').read_text())['complete'] is True,
            'three-policy input-owner evidence incomplete')
    plan = json.loads((DEMO / 'plan.json').read_text())
    private_root = Path(complete.get('recovery', {}).get('private_root', plan['private_root']))
    db = sqlite3.connect(f'file:{private_root / "app.sqlite3"}?mode=ro', uri=True)
    try:
        require(db.execute("SELECT count(*) FROM jobs WHERE status IN ('queued','running')").fetchone()[0] == 0,
                'demo jobs are still active')
    finally:
        db.close()
    # Refuse an active web server, pipeline or original supervisor. Promotion is
    # done between runs; an operator may restart the server after this finishes.
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit() or int(proc.name) == os.getpid():
            continue
        try:
            argv = (proc / 'cmdline').read_bytes().split(b'\0')
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        words = [x.decode(errors='replace') for x in argv if x]
        forbidden = (str(APP / 'serve.py'), str(APP / 'tools/classifier_pipeline.py'),
                     str(HERE / 'run_real_app_demo.py'), 'proven_media.app:app')
        try:
            cwd = (proc / 'cwd').resolve(strict=True)
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            cwd = None
        resolved_scripts = {str((cwd / x).resolve()) for x in words if cwd and x.endswith('.py')}
        require(not any(x in words or x in resolved_scripts for x in forbidden),
                f'app process {proc.name} is still active')
    changed = evidence['source_changes']
    for name, pins in changed.items():
        require(sha(CANDIDATE / name) == pins['candidate'], f'candidate source changed: {name}')
        dest = APP / name
        require((sha(dest) == pins['before']) if pins['before'] else not dest.exists(),
                f'active source changed since candidate baseline: {name}')
    backup = CANDIDATE / 'applied-before'
    backup.mkdir(exist_ok=False)
    for name, pins in changed.items():
        dest = APP / name
        if pins['before']:
            saved = backup / name
            saved.parent.mkdir(parents=True, exist_ok=True)
            saved.write_bytes(dest.read_bytes())
        temporary = dest.with_suffix(dest.suffix + '.privacy-tmp')
        with temporary.open('xb') as stream:
            stream.write((CANDIDATE / name).read_bytes())
        os.chmod(temporary, dest.stat().st_mode & 0o777 if dest.exists() else 0o644)
        os.replace(temporary, dest)
    result = {'at': datetime.now(timezone.utc).isoformat(), 'applied': True,
              'source_changes': changed, 'original_demo_plan_unchanged': sha(DEMO / 'plan.json'),
              'prior_sources': str(backup), 'services_restarted': False,
              'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
              'pid_ns': os.readlink('/proc/self/ns/pid')}
    (CANDIDATE / 'applied.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'applied_files': len(changed), 'original_demo_complete': True, 'restart_required_for_web_server': True}))


if __name__ == '__main__':
    main()
