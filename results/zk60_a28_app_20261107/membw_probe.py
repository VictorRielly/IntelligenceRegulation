#!/usr/bin/env python3
"""Lane A28: a one-thread memory-traffic probe (diagnostics). Every `--period` seconds it copies a 256 MiB array
`--copies` times (numpy `copyto`: a streaming read and write, far larger than any cache) and prints the
monotonic time (the mach clock: the stream driver's GPU series and the GPU trace use it too) and the GiB/s it
got. Run beside a stream it shows whether the machine's memory traffic is contended: a probe that keeps its
idle rate while six prover lanes run says the lanes are not short of memory bandwidth; one that loses a large
part of it says they are. It uses one core and about 0.5 GiB, and it is itself a load of some GiB/s: only for
diagnostic runs, never beside an A/B measurement.

usage: membw_probe.py <out.tsv> [--period 0.5] [--copies 4] [--seconds 900]
"""
import argparse
import os
import time

import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--period', type=float, default=0.5)
    ap.add_argument('--copies', type=int, default=4)
    ap.add_argument('--seconds', type=float, default=900.0)
    a = ap.parse_args()
    os.environ.setdefault('OMP_NUM_THREADS', '1')
    n = 256 << 20
    src = np.ones(n // 8, dtype=np.uint64)
    dst = np.zeros(n // 8, dtype=np.uint64)
    np.copyto(dst, src)
    t_end = time.monotonic() + a.seconds
    with open(a.out, 'w') as f:
        f.write('monotonic\tgib_per_s\n')
        while time.monotonic() < t_end:
            t0 = time.monotonic()
            for _ in range(a.copies):
                np.copyto(dst, src)
            dt = time.monotonic() - t0
            # each copy reads 256 MiB and writes 256 MiB
            f.write(f'{t0:.4f}\t{2 * a.copies * n / dt / (1 << 30):.2f}\n')
            f.flush()
            rest = a.period - dt
            if rest > 0:
                time.sleep(rest)


if __name__ == '__main__':
    main()
