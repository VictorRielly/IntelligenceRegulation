#!/usr/bin/env python3
"""Lane A25 (copied from A24): launch a guarded run only after leaving the heavy lock free for other lanes.

Coordinator, 2026-11-06 19:4x: before each new guarded run, read the guard's status; if other
jobs are queued or live, wait about 3 minutes with the lock free (or until the queue drains),
then launch. This waits until the guard shows no live job and no waiter for `--quiet-s`
consecutive seconds (at most `--max-wait-s` after the lock first frees), then runs
run_guarded.py with the remaining arguments.

usage: polite_launch.py [--quiet-s 180] [--max-wait-s 900] -- <run_guarded.py arguments>
"""
import subprocess
import sys
import time

GUARD = '/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py'
RUN = '/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c/results/zk60_a25_app_20261107/run_guarded.py'


def busy():
    s = subprocess.run(['python3', GUARD, 'status'], capture_output=True, text=True, timeout=30).stdout
    jobs = [l for l in s.splitlines() if l.strip().startswith('job ')]
    held = any(l.startswith('LOCKS') and 'heavy HELD' in l for l in s.splitlines())
    return bool(jobs) or held, s


def main():
    args = sys.argv[1:]
    quiet_s, max_wait = 180.0, 900.0
    while args and args[0] != '--':
        k, v = args[0], float(args[1])
        if k == '--quiet-s':
            quiet_s = v
        elif k == '--max-wait-s':
            max_wait = v
        args = args[2:]
    args = args[1:]
    t_free = None
    quiet_since = None
    t_start = time.time()
    while True:
        b, _ = busy()
        now = time.time()
        if b:
            quiet_since = None
        else:
            t_free = t_free or now
            quiet_since = quiet_since or now
            if now - quiet_since >= min(30.0, quiet_s) and now - t_free >= quiet_s:
                break
            if now - t_free >= max_wait:
                break
        if now - t_start >= max_wait:
            # the lock never stayed free (other lanes back to back): join the guard's own queue
            # after this long a wait instead of waiting for a free window forever
            break
        time.sleep(5)
    print(f'launching after {time.time() - (t_free or time.time()):.0f} s with the lock free', flush=True)
    if args and args[0] == '--raw':
        # an unguarded light driver (the app); its heavy service takes the guard itself
        subprocess.run(args[1:], check=True)
    else:
        subprocess.run(['python3', RUN] + args, check=True)


if __name__ == '__main__':
    main()
