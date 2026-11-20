#!/usr/bin/env python3
"""Co-coordinator (Claude), 2026-11-16: free disk held by FINISHED agent worktrees, keeping every uncommitted file.

Successor of results/zk60_lean_resume_20261109/prune_worktrees.py, which refuses any worktree with uncommitted or
untracked files. Here such a worktree is removed only after its uncommitted state is archived outside the repository.

A worktree under .claude/worktrees/ is removed only when ALL hold:
  - its name is not in the keep list given on the command line;
  - its branch is fully merged into perf/zk-batch-optimizations (every commit stays on perf; the branch is NOT deleted);
  - its uncommitted state (untracked files that are not ignored, plus tracked files that differ from HEAD) totals at
    most LIMIT bytes and was archived and re-read successfully:
        ARCH/<name>/meta.json      branch, HEAD, status, file list with sizes and SHA-256
        ARCH/<name>/tracked.diff   `git diff --binary HEAD`
        ARCH/<name>/files.tar.gz   every such file that exists on disk
Ignored build output (formal/.lake, cargo target) is not archived; it is reproducible from the sources.
Before removal the formal/.lake/packages SYMLINK is unlinked, the worktree is unlocked if locked (the locks belong to
agents of sessions that ended), then `git worktree remove --force`.

usage: archive_and_prune_worktrees.py [--dry-run] <keep-name> [<keep-name> ...]
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile

R = '/Users/victorrielly/IntelligenceRegulation'
BASE = os.path.join(R, '.claude/worktrees')
ARCH = '/Users/victorrielly/zk60-artifacts/worktree-prune-20261116'
LIMIT = 300 * 2**20


def git(*a, cwd=R, text=True):
    return subprocess.run(['git', *a], cwd=cwd, capture_output=True, text=text)


def free_gib():
    return shutil.disk_usage('/Users/victorrielly').free / 2**30


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def dirty_files(p):
    un = git('-C', p, 'ls-files', '--others', '--exclude-standard', '-z').stdout.split('\0')
    mod = git('-C', p, 'diff', '--name-only', '-z', 'HEAD').stdout.split('\0')
    return sorted({x for x in un + mod if x})


args = sys.argv[1:]
dry = '--dry-run' in args
keep = {a for a in args if a != '--dry-run'}
merged = {l.strip().lstrip('*+ ').strip()
          for l in git('branch', '--merged', 'perf/zk-batch-optimizations').stdout.splitlines()}
before = free_gib()
out = []
for blk in git('worktree', 'list', '--porcelain').stdout.split('\n\n'):
    d = {}
    for line in blk.strip().splitlines():
        k, _, v = line.partition(' ')
        d[k] = v
    p = d.get('worktree')
    if not p or not p.startswith(BASE + '/'):
        continue
    name = os.path.basename(p)
    br = d.get('branch', '').replace('refs/heads/', '')
    if name in keep:
        out.append(('KEEP  ', name, 'in the keep list'))
        continue
    if br not in merged:
        out.append(('KEEP  ', name, 'branch not merged into perf'))
        continue
    files = dirty_files(p)
    present = [f for f in files if os.path.isfile(os.path.join(p, f)) and not os.path.islink(os.path.join(p, f))]
    other = [f for f in files if f not in present]
    size = sum(os.path.getsize(os.path.join(p, f)) for f in present)
    if size > LIMIT:
        out.append(('KEEP  ', name, 'uncommitted files total %.1f MiB, over the limit' % (size / 2**20)))
        continue
    tag = '%d uncommitted files, %.2f MiB%s' % (len(present), size / 2**20, ', locked' if 'locked' in d else '')
    if dry:
        out.append(('WOULD ', name, tag))
        continue
    if files:
        dst = os.path.join(ARCH, name)
        os.makedirs(dst, exist_ok=True)
        meta = {
            'worktree': p, 'branch': br, 'head': d.get('HEAD'),
            'status': git('-C', p, 'status', '--porcelain').stdout,
            'files': {f: {'bytes': os.path.getsize(os.path.join(p, f)), 'sha256': sha(os.path.join(p, f))}
                      for f in present},
            'not_regular_or_deleted': other,
        }
        with open(os.path.join(dst, 'tracked.diff'), 'wb') as f:
            f.write(git('-C', p, 'diff', '--binary', 'HEAD', text=False).stdout)
        tarp = os.path.join(dst, 'files.tar.gz')
        with tarfile.open(tarp, 'w:gz') as t:
            for f in present:
                t.add(os.path.join(p, f), arcname=f)
        with tarfile.open(tarp, 'r:gz') as t:
            names = sorted(m.name for m in t.getmembers())
            ok = names == sorted(present)
            for m in t.getmembers():
                h = hashlib.sha256(t.extractfile(m).read()).hexdigest()
                ok = ok and h == meta['files'][m.name]['sha256']
        meta['archive_verified'] = ok
        with open(os.path.join(dst, 'meta.json'), 'w') as f:
            json.dump(meta, f, indent=1)
        if not ok:
            out.append(('KEEP  ', name, 'ARCHIVE CHECK FAILED, not removed'))
            continue
    link = os.path.join(p, 'formal/.lake/packages')
    if os.path.islink(link):
        os.unlink(link)
    if 'locked' in d:
        git('worktree', 'unlock', p)
    r = git('worktree', 'remove', '--force', p)
    out.append(('REMOVE', name, tag + (' removed' if r.returncode == 0 else ' FAILED: ' + r.stderr.strip()[:200])))
for x in out:
    print(*x)
print('free disk before %.1f GiB, after %.1f GiB' % (before, free_gib()))
