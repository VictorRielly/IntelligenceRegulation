#!/usr/bin/env python3
"""Tick 31 side check: what does DirSink::accept cost on this Mac for one segment-sized buffer?
It copies the sink's steps (create, write_all, sync_all, rename, SHA-256 of the bytes) on random bytes
under a temp directory. Rust's File::sync_all on macOS is fcntl(F_FULLFSYNC); both that and plain
fsync are timed. Standard library only; 1 or 6 concurrent writers; MB per buffer from argv.
Usage: python3 -I this.py <dir-for-temp-files> <MB> ; light (at most 6 x MB of RAM). Timings only."""
import os, sys, time, hashlib, fcntl, threading, statistics as st

d, mb = sys.argv[1], int(sys.argv[2])
buf = os.urandom(mb * 1024 * 1024)

def one(tag, i, full, out):
    p = os.path.join(d, f'sink-{tag}-{i}.partial')
    t0 = time.perf_counter()
    with open(p, 'wb') as f:
        f.write(buf)
        f.flush()
        t1 = time.perf_counter()
        if full:
            fcntl.fcntl(f.fileno(), fcntl.F_FULLFSYNC)
        else:
            os.fsync(f.fileno())
        t2 = time.perf_counter()
    os.rename(p, p[:-8])
    t3 = time.perf_counter()
    hashlib.sha256(buf).digest()
    t4 = time.perf_counter()
    os.remove(p[:-8])
    out.append((t1 - t0, t2 - t1, t3 - t2, t4 - t3, t4 - t0))

for writers in (1, 6):
    for full in (False, True):
        res = []
        for rep in range(8):
            outs = [[] for _ in range(writers)]
            ths = [threading.Thread(target=one, args=(f'{writers}{int(full)}', rep * 10 + w, full, outs[w])) for w in range(writers)]
            [t.start() for t in ths]
            [t.join() for t in ths]
            res += [o[0] for o in outs]
        cols = list(zip(*res))
        print('writers %d  %s  %d MB: write %.1f  fsync %.1f  rename %.1f  sha256 %.1f  total %.1f ms (median over %d)'
              % (writers, 'F_FULLFSYNC' if full else 'fsync     ', mb, *[1000 * st.median(c) for c in cols], len(res)))
