#!/usr/bin/env python3
"""Coordinator, 2026-11-10: remove FINISHED agent worktrees to free disk, safely.

A worktree is removed only when ALL hold:
  - it is under .claude/worktrees/ and its name is not in the keep list given on the command line;
  - its branch is fully merged into perf/zk-batch-optimizations (so every commit is kept on perf);
  - `git status --porcelain` is empty (no modified and no untracked files; ignored build output is allowed);
Before removal the `formal/.lake/packages` SYMLINK (which points into the main checkout's packages) is unlinked, so
nothing can follow it, then the worktree is unlocked if locked and removed with `git worktree remove --force` (the
force only covers ignored build output and the lock; the checks above already refused anything uncommitted). The
branch itself is NOT deleted. Prints what it did and the free disk before and after.

usage: prune_worktrees.py [--dry-run] <keep-name> [<keep-name> ...]
"""
import os
import shutil
import subprocess
import sys

R = '/Users/victorrielly/IntelligenceRegulation'
BASE = os.path.join(R, '.claude/worktrees')


def git(*a, cwd=R):
    return subprocess.run(['git', *a], cwd=cwd, capture_output=True, text=True)


def free_gib():
    return shutil.disk_usage('/Users/victorrielly').free / 2**30


args = sys.argv[1:]
dry = '--dry-run' in args
keep = {a for a in args if a != '--dry-run'}
merged = {l.strip().lstrip('*+ ').strip() for l in git('branch', '--merged', 'perf/zk-batch-optimizations').stdout.splitlines()}
before = free_gib()
removed, kept = [], []
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
    st = git('-C', p, 'status', '--porcelain').stdout.strip()
    why = None
    if name in keep:
        why = 'in the keep list'
    elif br not in merged:
        why = 'branch not merged into perf'
    elif st:
        why = 'uncommitted or untracked files (%d lines)' % len(st.splitlines())
    if why:
        kept.append((name, why))
        continue
    if dry:
        removed.append((name, br, 'would remove'))
        continue
    link = os.path.join(p, 'formal/.lake/packages')
    if os.path.islink(link):
        os.unlink(link)
    if 'locked' in d:
        git('worktree', 'unlock', p)
    r = git('worktree', 'remove', '--force', p)
    removed.append((name, br, 'removed' if r.returncode == 0 else 'FAILED: ' + r.stderr.strip()[:200]))
for x in removed:
    print('REMOVE', *x)
for x in kept:
    print('KEEP  ', *x)
print('free disk before %.1f GiB, after %.1f GiB' % (before, free_gib()))
