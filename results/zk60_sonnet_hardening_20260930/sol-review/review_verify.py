#!/usr/bin/env python3
"""Independent bounded verification controls; requires owner-created p2 proof.

Never proves or builds. Each child gets explicit argv, scrubbed runtime switches,
a 30-second deadline and a 768 MiB address-space cap. Original artifacts remain
unchanged. Supply a NEW --out directory outside the original artifacts.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import time


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda: f.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()


def memory_cap():
    resource.setrlimit(resource.RLIMIT_AS, (768 * 1024 * 1024,) * 2)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--binary', required=True, type=Path)
    p.add_argument('--artifact', required=True, type=Path)
    p.add_argument('--policy', required=True, type=Path)
    p.add_argument('--out', required=True, type=Path)
    args = p.parse_args()
    binary, original, policy = args.binary.resolve(), args.artifact.resolve(), args.policy.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    out = args.out.resolve()
    env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'RISC0_', 'BONSAI_', 'RUST_LOG'))}
    env['RAYON_NUM_THREADS'] = '2'
    pins = {str(x): digest(x) for x in [binary, policy, *original.glob('segment-*.bin')]}
    checks = []

    def run(name, artifact, trusted_policy, flags=(), refusal=False, expected_reason=None):
        command = [str(binary), 'verify', '--artifact', str(artifact), '--policy', str(trusted_policy), *flags]
        start = time.monotonic()
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=30, preexec_fn=memory_cap)
            (out / (name + '.stdout')).write_text(result.stdout)
            (out / (name + '.stderr')).write_text(result.stderr)
            values = [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
            latest = values[-1] if values else {}
            accepted = any(v.get('status') == 'accepted' or v.get('accepted') is True for v in values)
            passed = (result.returncode == 1 and latest.get('status') == 'refused' and not accepted) if refusal else (result.returncode == 0 and latest.get('status') == 'accepted')
            if expected_reason:
                passed = passed and expected_reason in latest.get('reason', '')
            checks.append(dict(name=name, passed=passed, argv=command, exit_code=result.returncode, elapsed_seconds=time.monotonic()-start, result=latest))
        except (subprocess.TimeoutExpired, ValueError) as exc:
            checks.append(dict(name=name, passed=False, argv=command, error=str(exc)))

    def copy_case(name):
        directory = out / name
        shutil.copytree(original, directory)
        return directory

    run('fresh_accept', original, policy, ['--policy-sha256', digest(policy)])
    exotic = out / '路径 with space and "quote"'
    shutil.copytree(original, exotic)
    exotic_policy = out / '调用 policy "雪".txt'; shutil.copyfile(policy, exotic_policy)
    run('unicode_space_accept', exotic, exotic_policy)
    missing_policy = out / '不存在 policy "雪".txt'
    run('unicode_error_exact_path', original, missing_policy, refusal=True, expected_reason=str(missing_policy))
    long_parent = out
    for i in range(22):
        long_parent = long_parent / (str(i) + '雪' + 'x' * 92)
    long_parent.mkdir(parents=True)
    long_artifact = long_parent / 'artifact'; shutil.copytree(original, long_artifact)
    run('long_path_accept', long_artifact, policy)
    missing_long_policy = long_parent / 'absent policy.txt'
    run('long_error_no_truncation', original, missing_long_policy, refusal=True, expected_reason=str(missing_long_policy))
    run('wrong_blocks', original, policy, ['--expect-blocks', '64'], True, 'pin')
    run('wrong_policy_digest', original, policy, ['--policy-sha256', '00' * 32], True, 'pin')
    for name, cap, target in [('oversize_policy', 16384, 'policy'), ('oversize_manifest', 65536, 'manifest'), ('oversize_segment', 64*1024*1024, 'segment')]:
        directory = copy_case(name)
        supplied = policy
        if target == 'policy':
            supplied = out / 'oversize-policy.txt'; path = supplied
        elif target == 'manifest':
            path = directory / 'statement/mvp-manifest.json'
        else:
            path = sorted(directory.glob('segment-*.bin'))[0]
        with path.open('wb') as f:
            f.truncate(cap + 1)
        run(name, directory, supplied, refusal=True, expected_reason='bound')
    for name in ['extra_segment', 'truncated_segment', 'changed_segment', 'swapped_segments']:
        directory = copy_case(name)
        segments = sorted(directory.glob('segment-*.bin'))
        if name == 'extra_segment':
            (directory / 'foreign.bin').write_bytes(b'x')
        elif name == 'truncated_segment':
            with segments[0].open('r+b') as f: f.truncate(segments[0].stat().st_size - 1)
        elif name == 'changed_segment':
            with segments[0].open('r+b') as f:
                f.seek(40); value = f.read(1); f.seek(40); f.write(bytes([value[0] ^ 1]))
        elif len(segments) >= 2:
            first, second = segments[0].read_bytes(), segments[1].read_bytes()
            segments[0].write_bytes(second); segments[1].write_bytes(first)
        else:
            checks.append(dict(name=name, passed=False, error='needs >=2 blocks')); continue
        run(name, directory, policy, refusal=True)
    unchanged = all(digest(Path(path)) == pin for path, pin in pins.items())
    checks.append(dict(name='originals_unchanged', passed=unchanged))
    report = dict(status='passed' if all(x['passed'] for x in checks) else 'failed', checks=checks, original_pins=pins, proof_generated=False)
    (out / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(dict(status=report['status'], checks=len(checks))))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
