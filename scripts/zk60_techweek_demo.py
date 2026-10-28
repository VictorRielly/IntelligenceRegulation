#!/usr/bin/env python3
"""Local proof demonstrations. Saved verification never claims a new proof."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time

if __package__:
    from scripts import zk60_zkvm_demo as zkvm
else:
    import zk60_zkvm_demo as zkvm

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / 'hashline/target/release/examples/zk60_private_block'
NATIVE_PIN = '819895693b2e33b0ea1f1046c97e7f740bbdafb144fff8028f89a238eccfb8cf'
SOURCE = ROOT / 'hashline/examples/zk60_private_block.rs'
SOURCE_PIN = '8eee81aac94f1536cd0e15c9368817b98e268e0d699ea98db3ad4ab9c2192168'
MAX_DIAGNOSTIC_BYTES = 1024 * 1024
MAX_ARTIFACT_BYTES = 64 * 1024 * 1024
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
GUARD_PIN = '87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c'
SAVED = {
 'token': ('token-integration/token_public', 'receipt.bin',
 '3c0631ee629a40a78421e03cd5c6ac9ffdafa026a1289aa9207fcce6c016430b',
 '94f3ce1438b41b34a086cabd2eafcabf75c492dc2eed9da6555493f1cb9b2cb0',
 'f8177d93f57f00a813a142c1d3993b6de377e4f6ae87313e5a903c68ed82240b',
 '338eb2a7b16a8698c646c3d05bb885dcc6f40566f7dd3378acefc7c65d4fa7a7'),
 'block': ('block-integration/groth16_public', 'groth16.bin',
 '8d74aab3d58c1a713045dfd1ea4ffa15e61439e61af58b72a5fdb792111998d9',
 '6c67e05c70e6785023f5fd671770e95bc9de197c83558fc044817df4f16432e7',
 '6447e9909a38a90dd8e8f23c9d9e1959f862e04c6323421b49e9a5b3b8748f43',
 '3e7b1cd90c4399effc3a812d8e47702a04853a435f9f183aac3b1cffadd5cb59')}


def _pin(path, expected):
    actual = zkvm.sha256_file(path)
    if actual != expected:
        raise zkvm.RunnerError('artifact identity pin mismatch')
    return actual


def _guarded_child(command, log, env):
    """The guard owns timeouts and must finish cleanup before we reap it."""
    fd = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=fd, stderr=fd,
                                 env=env, cwd=ROOT, start_new_session=True, close_fds=True)
    finally:
        os.close(fd)
    try:
        return child.wait()
    except BaseException:
        if child.poll() is None:
            child.terminate()
        child.wait()
        raise


def _command(command, log, timeout=60, *, proof=False):
    _pin(GUARD, GUARD_PIN)
    env, _ = zkvm.scrubbed_env(2)
    # A native toy proof still serializes with builds and larger proofs. The
    # retained receipt verifiers are small, memory-admitted independent checks.
    result_path = log.with_suffix('.guard.json')
    guard_command = [sys.executable, str(GUARD), 'run', '--class', 'cpu' if proof else 'light',
                     '--label', 'demo-' + log.stem, '--wait-secs', '30', '--max-secs', str(timeout),
                     '--result-json', str(result_path), '--done', str(log.with_suffix('.guard.done')),
                     '--log', str(log)]
    if proof:
        guard_command += ['--need-gib', '1', '--cap-gib', '2']
    guard_command += ['--', *[str(x) for x in command]]
    guard_log = log.with_suffix('.guard.log')
    code = _guarded_child(guard_command, guard_log, env)
    _pin(GUARD, GUARD_PIN)
    try:
        verdict = json.loads(_read_small(result_path, MAX_DIAGNOSTIC_BYTES))
    except (OSError, ValueError) as exc:
        raise zkvm.RunnerError('resource guard did not publish a terminal result') from exc
    if (not isinstance(verdict, dict) or type(verdict.get('exit')) is not int
            or verdict['exit'] != code):
        raise zkvm.RunnerError('resource guard terminal result disagrees with its exit')
    if code in (0, 1) and (type(verdict.get('child_rc')) is not int
                          or verdict['child_rc'] != code or verdict.get('guard_killed')
                          or verdict.get('refused') or verdict.get('guard_error')):
        raise zkvm.RunnerError('resource guard did not establish a native child outcome')
    expired = bool(verdict.get('guard_killed'))
    diagnostic = log if log.exists() else guard_log
    if code == 0 and diagnostic != log:
        raise zkvm.RunnerError('resource guard did not retain the child output')
    return code, expired, _read_small(diagnostic, MAX_DIAGNOSTIC_BYTES).decode(errors='replace')


def _read_small(path, limit):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise zkvm.RunnerError('demo artifact or diagnostic exceeds its read limit')
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise zkvm.RunnerError('demo artifact or diagnostic exceeds its read limit')
    return data


def _save_report(out, report):
    temporary = out / '.report.json.tmp'
    temporary.write_text(json.dumps(report, indent=2) + '\n')
    temporary.replace(out / 'report.json')


def _demo(output_dir, mode, scope, operation):
    out = zkvm.new_destination(output_dir)
    out.mkdir(mode=0o700)
    started = time.monotonic()
    report = dict(status='running', mode=mode, scope=scope, receipt_bytes=0,
                  checks=[], new_proof_generated=False, trained_model=False,
                  model_scale_mvp=False, benchmark=False,
                  started_at=dt.datetime.now(dt.timezone.utc).isoformat())
    _save_report(out, report)
    try:
        operation(out, report)
        report['status'] = 'passed' if report['checks'] and all(x['passed'] for x in report['checks']) else 'failed'
    except (OSError, zkvm.RunnerError, ValueError) as exc:
        report['status'] = 'failed'
        report['error'] = str(exc)
    report['elapsed_seconds'] = time.monotonic() - started
    _save_report(out, report)
    (out / 'run.done').write_text('0\n' if report['status'] == 'passed' else '1\n')
    return report


def _check(report, name, passed):
    report['checks'].append(dict(name=name, passed=bool(passed)))
    if not passed:
        raise zkvm.RunnerError('verification check failed: ' + name)


def verify_saved_demo(output_dir: Path, profile='token') -> dict:
    """Fresh process verification and refusals for independently pinned receipts."""
    if profile not in SAVED:
        raise ValueError('unknown profile')
    def operation(out, report):
        folder, filename, image, receipt_pin, policy_pin, binary_pin = SAVED[profile]
        source = ROOT / 'results/zk60_loop_20260918' / folder
        binary = ROOT / f'zkvm-block/target/release/zk60-{profile}-wrap'
        report['binary_sha256'] = _pin(binary, binary_pin)
        report['receipt_sha256'] = _pin(source / filename, receipt_pin)
        report['policy_sha256'] = _pin(source / 'policy.bin', policy_pin)
        report['image_id'] = image
        policy, receipt = out / 'policy.bin', out / 'receipt.bin'
        shutil.copyfile(source / 'policy.bin', policy)
        shutil.copyfile(source / filename, receipt)
        _pin(policy, policy_pin)
        _pin(receipt, receipt_pin)
        report['receipt_bytes'] = receipt.stat().st_size
        code, expired, message = _command([binary, 'image-id'], out / 'image.log')
        _check(report, 'trusted_image_id', code == 0 and not expired and message.strip() == image)
        def verify(name, p, r, reject=False):
            code, expired, message = _command(zkvm.verify_command(profile, binary, p, r, image), out / (name + '.log'))
            error_prefix = 'zk60 token wrap:' if profile == 'token' else 'zk60 wrap:'
            refused = (code == 1 and any(line.startswith(error_prefix) for line in message.splitlines())
                       and not zkvm.reports(message, 'verified') and not zkvm.reports(message, 'mvp_complete'))
            passed = refused if reject else (code == 0 and zkvm.reports(message, 'verified', 'groth16')
                                               and not zkvm.reports(message, 'mvp_complete'))
            _check(report, name, not expired and passed)
        verify('fresh_process_verify', policy, receipt)
        changed = bytearray(_read_small(receipt, MAX_ARTIFACT_BYTES)); changed[-1] ^= 1
        bad = out / 'tampered.bin'; bad.write_bytes(changed)
        verify('tampered_receipt_rejected', policy, bad, True)
        changed = bytearray(_read_small(policy, MAX_ARTIFACT_BYTES)); changed[16] ^= 1
        bad_policy = out / 'wrong-policy.bin'; bad_policy.write_bytes(changed)
        verify('wrong_policy_rejected', bad_policy, receipt, True)
        _check(report, 'trusted_artifacts_unchanged', zkvm.sha256_file(receipt) == receipt_pin and zkvm.sha256_file(policy) == policy_pin)
        _pin(binary, binary_pin)
    scope = dict(profile=profile, synthetic=True, private_inputs=True, private_outputs=True,
                 coverage=zkvm.PROFILES[profile]['coverage'], proof_origin='retained proof generated 2026-09-18',
                 qualifiers=['Groth16 trusted setup', 'approximately 97-bit conjectured security',
                             'salt secrecy; build-directory-dependent image identity; timing leakage'])
    return _demo(output_dir, 'saved-zkvm-verification', scope, operation)


def run_native_demo(output_dir: Path) -> dict:
    """New complete toy block proof. All tensors are a public synthetic fixture."""
    def operation(out, report):
        report['binary_sha256'] = _pin(NATIVE, NATIVE_PIN)
        report['example_source_sha256'] = _pin(SOURCE, SOURCE_PIN)
        artifact = out / 'artifacts'
        code, expired, _ = _command([NATIVE, 'prove', artifact], out / 'prove.log', 180, proof=True)
        _check(report, 'new_proof_generated', code == 0 and not expired)
        report['new_proof_generated'] = True
        receipt, policy = artifact / 'block_receipt.bin', artifact / 'block_expected.bin'
        report['receipt_bytes'] = receipt.stat().st_size
        report['receipt_sha256'] = zkvm.sha256_file(receipt)
        report['policy_sha256'] = zkvm.sha256_file(policy)
        report['policy_origin'] = 'prover-created endpoints pinned before fresh verification (D18)'
        def verify(name, directory, reject=False):
            code, expired, message = _command([NATIVE, 'verify', directory], out / (name + '.log'))
            _check(report, name, not expired and (code == 1 and 'REJECT:' in message and 'ACCEPT:' not in message if reject else code == 0 and 'ACCEPT:' in message))
        verify('fresh_process_verify', artifact)
        for name, filename, offset in [('tampered_receipt_rejected', receipt.name, 40),
                                       ('wrong_policy_rejected', policy.name, 16)]:
            directory = out / name; shutil.copytree(artifact, directory)
            target = directory / filename; data = bytearray(_read_small(target, MAX_ARTIFACT_BYTES)); data[offset] ^= 1; target.write_bytes(data)
            verify(name, directory, True)
        _check(report, 'pinned_artifacts_unchanged', zkvm.sha256_file(receipt) == report['receipt_sha256'] and zkvm.sha256_file(policy) == report['policy_sha256'])
    return _demo(output_dir, 'live-native-toy-proof', dict(profile='private-block-t32-poc/1',
        synthetic=True, private_inputs=False, private_outputs=False, tokens=32, layers=1,
        coverage='complete T32/d16/f16 transformer block; public synthetic fixture; secret fresh proof randomness',
        identity_note='pinned existing binary and example source; full reproducible build provenance not established'), operation)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['saved', 'native'])
    parser.add_argument('--profile', choices=['token', 'block'], default='token')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    result = verify_saved_demo(Path(args.out), args.profile) if args.mode == 'saved' else run_native_demo(Path(args.out))
    print(json.dumps(result, indent=2))
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
