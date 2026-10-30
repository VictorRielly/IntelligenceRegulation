"""Fresh replay of retained R14 frames and matched prove-only measurements."""
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TREE = HERE / 'working-tree'
BUILD = 'sol-r14-run-build-4'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
STEM = 'private_block::argument::split_run_tests::'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    assert (HERE / (BUILD + '.validated.done')).read_text().strip() == '0'
    pin = json.loads((HERE / (BUILD + '.source.json')).read_text())
    def check():
        for name, want in pin['files'].items(): assert sha(TREE / name) == want, name
    check()
    checkpoint = HERE / 'checkpoints/run-build-4'
    binary = checkpoint / 'hashline.test.bin'
    if not checkpoint.exists():
        for name in pin['files']:
            target = checkpoint / 'tree' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(TREE / name, target)
        bins = [p for p in (TREE / 'hashline/target/release/deps').glob('hashline-*')
                if p.is_file() and p.stat().st_mode & 0o111]
        assert len(bins) == 1
        shutil.copy2(bins[0], binary)
    binary_sha = sha(binary)
    records = []
    def run(label, test, proof, env):
        check()
        assert sha(binary) == binary_sha
        need, cap = (7.5, 10) if proof else (2.5, 4.5)
        command = [sys.executable, str(GUARD), 'run', '--class', 'cpu', '--label', label,
            '--need-gib', str(need), '--cap-gib', str(cap), '--wait-secs', '21600', '--max-secs', '1800',
            '--log', str(HERE / (label + '.log')), '--done', str(HERE / (label + '.done')),
            '--result-json', str(HERE / (label + '.guard.json')), '--', '/usr/bin/env',
            'RAYON_NUM_THREADS=2', 'OPENBLAS_NUM_THREADS=1', *[f'{k}={v}' for k,v in env.items()],
            str(binary), STEM + test, '--exact', '--ignored', '--nocapture', '--test-threads=1']
        record = HERE / (label + '.command.json')
        assert not record.exists(), 'Do not duplicate a recorded stage'
        record.write_text(json.dumps({'command': command, 'source': pin['tree_sha256'],
            'binary_sha256': binary_sha}, indent=2) + '\n')
        while True:
            check()
            r = subprocess.run([sys.executable, str(GUARD), 'check', '--class', 'cpu', '--need-gib', str(need)],
                cwd=ROOT, capture_output=True, text=True)
            if r.returncode == 0 and 'OK to start now' in r.stdout: break
            print(datetime.now(timezone.utc).isoformat(), label, 'waiting outside heavy lock', flush=True)
            time.sleep(10)
        result = subprocess.run(command, cwd=ROOT)
        check()
        assert sha(binary) == binary_sha
        if result.returncode: sys.exit(result.returncode)
        text = (HERE / (label + '.log')).read_text()
        assert '1 passed; 0 failed' in text
        out = {'label': label, 'source': pin['tree_sha256'], 'binary_sha256': binary_sha,
            'guard': json.loads((HERE / (label + '.guard.json')).read_text())}
        if proof:
            rows = [json.loads(line.split('R14_NATIVE_STREAM ', 1)[1]) for line in text.splitlines()
                if 'R14_NATIVE_STREAM ' in line]
            assert len(rows) == 1 and not rows[0]['narrow_boundary_forgery']
            out['measurement'] = rows[0]
        (HERE / (label + '.result.json')).write_text(json.dumps(out, indent=2) + '\n')
        (HERE / (label + '.validated.done')).write_text('0\n')
        records.append(out)
        print(label, 'PASS', flush=True)
    for mode in ['non-dd', 'dd']:
        code = mode.replace('-', '_')
        for corrupt in [False, True]:
            label = 'sol-r14-root-audit-replay-' + mode + ('-corrupt' if corrupt else '') + '-1'
            directory = HERE / 'stream-fixtures' / (mode + ('-corrupt' if corrupt else ''))
            test = 'split_run_t128_' + code + ('_fresh_rejects_corrupt_stream' if corrupt else '_fresh_verify_from_dir')
            run(label, test, False, {'HL_R14_RUN_INPUT': str(directory)})
        run('sol-r14-matched-' + mode + '-1',
            'split_run_t128_' + code + '_serialized_two_blocks_with_own_calibration_verify',
            True, {'HL_R14_RUN_OUTPUT': str(HERE / 'matched-r14' / mode)})
    (HERE / 'ROOT_AUDIT_MATCHED_CHECKS.json').write_text(json.dumps({
        'utc': datetime.now(timezone.utc).isoformat(), 'source': pin['tree_sha256'],
        'binary_sha256': binary_sha, 'cases': records,
        'scope': 'Native root uniqueness plus fresh replay and matched public synthetic timing; no approved model/privacy acceptance',
    }, indent=2) + '\n')
    (HERE / 'ROOT_AUDIT_MATCHED_CHECKS.done').write_text('0\n')
    print('R14 root replay / matched measurements PASS6/0', flush=True)
if __name__ == '__main__': main()
