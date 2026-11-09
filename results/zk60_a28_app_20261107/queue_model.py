#!/usr/bin/env python3
"""Lane A28: the stream as a closed queueing network (a model, [INFERRED]; every input is a measured number).

N prover lanes each cycle through host work (think time Z seconds per category proof, no queueing: every lane
has its own threads) and the GPU (S seconds of device work per proof on ONE shared device that serves its
command buffers by time-slicing: A27's and A28's traces show the union of executing command buffers in the
stream equal to the sum of the solo proofs' GPU time). Exact mean-value analysis for a processor-sharing
station:

    R(n) = S (1 + Q(n-1));  X(n) = n / (Z + R(n));  Q(n) = X(n) R(n)

Z is fitted from the measured proof times at different thread counts as Z = serial + parallel / threads
(A27's runs: one lane of 30 threads 18.4 s with 5.0 s of GPU alone; six lanes of five threads 38 s).

usage: queue_model.py [--serial 11] [--parallel 70] [--gpu 5.0]
  prints the lane cycle, the steady proofs/s and proved tok/s, the GPU's utilization and the 8-post stream
  (wall = first two writers 20 s + rounds + the last check 8 s) for a list of settings.
"""
import argparse


def mva(n_lanes, z, s):
    q = 0.0
    x = r = 0.0
    for n in range(1, n_lanes + 1):
        r = s * (1.0 + q)
        x = n / (z + r)
        q = x * r
    return x, r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--serial', type=float, default=11.0, help='serial host seconds per proof')
    ap.add_argument('--parallel', type=float, default=70.0, help='parallel host CPU-seconds per proof')
    ap.add_argument('--gpu', type=float, default=5.0, help='GPU seconds per proof alone')
    ap.add_argument('--proofs', type=int, default=24)
    ap.add_argument('--fixed', type=float, default=28.0, help='stream seconds outside the rounds (two writers, the last check)')
    a = ap.parse_args()
    print(f'serial {a.serial} s, parallel {a.parallel} CPU-s, GPU {a.gpu} s per proof')
    print('lanes x threads   Z s   GPU wait s   cycle s   steady tok/s   GPU util   8-post stream s   tok/s')
    for lanes, threads in ((1, 30), (3, 10), (6, 5), (6, 8), (6, 10), (8, 4), (8, 6), (6, 1000)):
        z = a.serial + a.parallel / threads
        x, r = mva(lanes, z, a.gpu)
        cycle = lanes / x
        rounds = a.proofs / lanes
        wall = a.fixed + rounds * cycle
        t = 'inf' if threads >= 1000 else str(threads)
        print(f'{lanes:>5} x {t:<8} {z:5.1f}   {r:9.1f}   {cycle:7.1f}   {128 * x:12.1f}   {100 * x * a.gpu:7.0f}%   {wall:15.0f}   {128 * a.proofs / wall:5.1f}')
    print(f'the device alone bounds the steady stream at {128 / a.gpu:.1f} proved tok/s (one proof per {a.gpu} s of GPU)')


if __name__ == '__main__':
    main()
