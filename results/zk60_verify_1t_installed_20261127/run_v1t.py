#!/usr/bin/env python3
"""One run of the classifier's verify command on a retained public receipt of the installed profile
(W16R2_SHIELD_T128_H24), with the per-block phase tables printed. No source file changes; nothing of the app is touched.

usage: run_v1t.py [--detached] <label> <arm> <run suffix> <scratch dir> [max secs, default 1800]
       e.g. run_v1t.py smoke p c0 /path/to/scratch 900
            run_v1t.py --detached t1a t1 c0 /path/to/scratch

Arms (environment of the verifier process):
  p    the global thread pool at its default size
  t1   RAYON_NUM_THREADS=1: a global pool of one thread, so every row of a table is one thread's work

What it does, in order:
  1. reads the app's pins from apps/proven-media/deploy.json (profile shieldstral-mac-fast-w16r2);
  2. copies the pinned verifier binary into <scratch>/<label>/ and compares the copy's SHA-256 with the pin (the
     installed file is read, never executed);
  3. copies the retained run <id>-<suffix> (28 segments and its published statement) into <scratch>/<label>/run
     (verify can clear and publish inside a run directory, so the original is not given to it);
  4. takes a listing (path, size, modification time) of the verifier export and of the models directory, which are
     read in place;
  5. runs the app's own verify call under the resource guard (class cpu, 12 GiB asked, 16 GiB cap), with every HL_,
     RAYON_ and ZK60_ variable of the caller removed and then: HL_PB_TIMING=1, HL_PB_ORACLE=0, HL_GPU=0,
     HL_GPU_REQUIRED=0, HL_A26_VERIFY_ONCE=0, OPENBLAS_NUM_THREADS=1, OMP_NUM_THREADS=1, ZK60_MODELS, and
     HL_OWNER_PRIVATE_DIR=<scratch>/<label>/owner-private (so no refusal detail can reach the owner's own log);
  6. takes the two listings again and compares.
Writes raw/<label>.log, .done, .guard.json, .status_pre.txt and raw/<label>.results.json beside this file.
With "--detached" first, the runner re-starts itself in a new session and returns at once; raw/<label>.runner.done
holds its exit code when it ends.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / 'raw'
ROOT = HERE.parent.parent
HOME = Path.home()
GUARD = str(ROOT / 'scripts/zk60_resource_guard.py')
BIN_SRC = HOME / 'zk60-artifacts/proven-media-fast/bin/zk60_classify.a30a31'
ART = HOME / 'zk60-artifacts/astra-merged-w16r2-slget05j'
EXPORT = ART / 'verifier-export-w16r2-94643880'
RUN_ID = '6a8ff87cb1ec6e17fcdf4e9c04ae1cb3'
MODELS = ROOT / 'results/zk60_astra_20261026/flashprove_runtime_20261104/models'
RECEIPT_BYTES = 669561472
NEED_GIB, CAP_GIB = 12, 16


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def listing(base):
    rows = []
    for d, dirs, fs in os.walk(base):
        dirs.sort()
        for f in sorted(fs):
            p = os.path.join(d, f)
            st = os.lstat(p)
            rows.append((os.path.relpath(p, base), st.st_size, st.st_mtime_ns))
    return rows


def digest(rows):
    return hashlib.sha256(json.dumps(rows).encode()).hexdigest()


def main():
    a = sys.argv[1:]
    detached = bool(a) and a[0] == '--detached'
    if detached:
        a = a[1:]
    label, arm, suffix, scratch = a[0], a[1], a[2], Path(a[3]).resolve()
    max_secs = int(a[4]) if len(a) > 4 else 1800
    assert re.fullmatch(r'[a-z0-9_]+', label) and arm in ('p', 't1') and suffix in ('c0', 'c1', 'c2')
    assert not str(scratch).startswith(str(ROOT)) and not str(scratch).startswith(str(HOME / 'zk60-'))
    RAW.mkdir(exist_ok=True)
    for suf in ('.log', '.done', '.guard.json', '.results.json', '.runner.done'):
        assert not (RAW / (label + suf)).exists(), label + suf + ' exists already: use a new label'
    if detached:
        out = open(RAW / (label + '.runner.txt'), 'w')
        p = subprocess.Popen([sys.executable, str(Path(__file__).resolve())] + a, stdin=subprocess.DEVNULL, stdout=out,
                             stderr=subprocess.STDOUT, start_new_session=True, cwd=str(HERE))
        print('launched', label, 'runner pid', p.pid)
        return 0
    rc = 1
    try:
        rc = run(label, arm, suffix, scratch, max_secs)
    finally:
        (RAW / (label + '.runner.done')).write_text(str(rc) + '\n')
    return rc


def run(label, arm, suffix, scratch, max_secs):
    pins = json.load(open(ROOT / 'apps/proven-media/deploy.json'))['classifier_profiles']['shieldstral-mac-fast-w16r2']
    work = scratch / label
    assert not work.exists(), 'the scratch directory of this label exists already'
    work.mkdir(parents=True)
    # 2. the binary: a copy, compared with the pin
    binary = work / 'zk60_classify.copy'
    shutil.copyfile(BIN_SRC, binary)
    os.chmod(binary, 0o700)
    bin_sha = sha(binary)
    assert bin_sha == pins['binary_sha256'], 'the copy is not the pinned verifier binary'
    assert sha(EXPORT / 'profile.json') == pins['profile_sha256'], 'the export is not the pinned one'
    # 3. the receipt: a copy
    src = ART / 'runs' / (RUN_ID + '-' + suffix)
    art = work / 'run'
    art.mkdir()
    segs = sorted(x for x in os.listdir(src) if re.fullmatch(r'segment-\d{3}\.bin', x))
    assert len(segs) == 28
    for s in segs:
        shutil.copyfile(src / s, art / s)
    shutil.copytree(src / 'statement', art / 'statement')
    assert sum((art / s).stat().st_size for s in segs) == RECEIPT_BYTES
    statement = (art / 'statement/statement.json').read_text()
    assert pins['statement_identity'] in statement
    policy = re.findall(r'shieldstral-1\.0-3b-moderate-[a-z]+/1', statement)[0]
    # 4. listings of what is read in place
    pre = {'export': listing(EXPORT), 'models': listing(MODELS)}
    status = subprocess.run([sys.executable, GUARD, 'status'], capture_output=True, text=True).stdout
    (RAW / (label + '.status_pre.txt')).write_text('\n'.join(l for l in status.split('\n') if not l.startswith('  rss')) + '\n')
    # 5. the run
    env = {k: v for k, v in os.environ.items() if not k.startswith(('HL_', 'RAYON_', 'ZK60_'))}
    own = work / 'owner-private'
    setv = {'HL_PB_TIMING': '1', 'HL_PB_ORACLE': '0', 'HL_GPU': '0', 'HL_GPU_REQUIRED': '0', 'HL_A26_VERIFY_ONCE': '0',
            'OPENBLAS_NUM_THREADS': '1', 'OMP_NUM_THREADS': '1'}
    if arm == 't1':
        setv['RAYON_NUM_THREADS'] = '1'
    env.update(setv)
    env.update({'ZK60_MODELS': str(MODELS), 'HL_OWNER_PRIVATE_DIR': str(own)})
    cmd = [sys.executable, GUARD, 'run', '--class', 'cpu', '--need-gib', str(NEED_GIB), '--cap-gib', str(CAP_GIB),
           '--max-secs', str(max_secs), '--wait-secs', '900', '--label', 'claude-v1t-' + label,
           '--log', str(RAW / (label + '.log')), '--done', str(RAW / (label + '.done')),
           '--result-json', str(RAW / (label + '.guard.json')), '--',
           str(binary), 'verify', '--export', str(EXPORT), '--tables', str(EXPORT / 'token_io'), '--policy', policy,
           '--label', 'zk60-classify-verdict', '--artifact', str(art), '--expect-statement', pins['statement_identity'],
           '--min-bits', '95', pins['native_cli_flags'][0]]
    t0 = time.time()
    started = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(t0))
    rc = subprocess.run(cmd, stdin=subprocess.DEVNULL, env=env, cwd=str(work)).returncode
    secs = time.time() - t0
    # 6. the listings again
    post = {'export': listing(EXPORT), 'models': listing(MODELS)}
    same = {k: pre[k] == post[k] for k in pre}
    own_files = sorted(str(p.relative_to(own)) for p in own.rglob('*')) if own.exists() else []
    art_now = sorted(str(p.relative_to(art)) for p in art.rglob('*') if p.is_file())
    res = {'label': label, 'arm': arm, 'run': RUN_ID + '-' + suffix, 'policy': policy, 'started_utc': started,
           'guard_exit': rc, 'seconds_with_guard_wait': round(secs, 1), 'binary_sha256': bin_sha,
           'profile_sha256': pins['profile_sha256'], 'statement_identity': pins['statement_identity'], 'set': setv,
           'also_set': ['ZK60_MODELS', 'HL_OWNER_PRIVATE_DIR'], 'max_secs': max_secs,
           'listing_entries': {k: len(v) for k, v in pre.items()},
           'listing_sha256_pre': {k: digest(v) for k, v in pre.items()},
           'listing_sha256_post': {k: digest(v) for k, v in post.items()}, 'listing_unchanged': same,
           'files_under_scratch_owner_private': own_files, 'files_in_run_copy_after': len(art_now)}
    (RAW / (label + '.results.json')).write_text(json.dumps(res, indent=1) + '\n')
    print(json.dumps({k: res[k] for k in ('label', 'arm', 'guard_exit', 'seconds_with_guard_wait', 'listing_unchanged',
                                           'files_under_scratch_owner_private')}))
    return 0 if rc == 0 and all(same.values()) else 1


if __name__ == '__main__':
    sys.exit(main())
