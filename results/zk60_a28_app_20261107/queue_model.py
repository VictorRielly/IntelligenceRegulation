#!/usr/bin/env python3
"""Lane A28: how much of a lane's slowdown in the stream does the device's queue explain? (a model, [INFERRED];
its inputs are measured numbers).

N prover lanes each alternate host work (Z seconds per category proof) and the one device (S seconds of
command-buffer execution per proof, shared by time-slicing: the traces show the union of executing command
buffers in the stream equal to the sum of the solo proofs' GPU time). If the lanes shared NOTHING but the
device, the host work would take in company what it takes alone, and the exact mean-value analysis of a
closed network with one processor-sharing station gives the lane's cycle:

    R(n) = S (1 + Q(n-1));  X(n) = n / (Z + R(n));  Q(n) = X(n) R(n)

Inputs (a28-q2, section 3.3 of the README): one proof alone on a lane of five threads takes 19.6 s, 4.84 s of
it on the device (plus about 0.6 s of command-buffer latency), so Z = 14.2 s and S = 5.4 s.

Measured against it: three at once 27.7 s, six at once 38 s, eight at once 48-58 s. The model gives 23.1, 33.5
and 43.4 s: the device's queue alone explains most of what a lane loses in company (14 of the 18 s at six
lanes), and it puts the device at 97% busy with six lanes. It gets the total within 12% but not the split: in
the sampled stream a lane waits 12-15 s for the device (the model: 19 s) and its host work takes 26-30 s (alone:
14 s): every host section, serial ones included, runs 1.3x to 3x slower beside the other lanes
(lane_split.py), and a slower host asks less of the device. Either way more lanes cannot help: the model's
steady stream is flat from six lanes on, as measured.

usage: queue_model.py [--host 14.2] [--gpu 5.4]
"""
import argparse

MEASURED = {1: '19.6', 3: '27.7', 6: '38', 8: '48-58'}


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
    ap.add_argument('--host', type=float, default=14.2, help='host seconds per proof alone')
    ap.add_argument('--gpu', type=float, default=5.4, help='device seconds per proof alone (execution plus latency)')
    a = ap.parse_args()
    print(f'host {a.host} s and device {a.gpu} s per proof alone; lanes that share only the device:')
    print('lanes   device wait s   cycle s   measured cycle s   steady proved tok/s   device busy')
    for lanes in (1, 3, 6, 8, 12):
        x, r = mva(lanes, a.host, a.gpu)
        print(f'{lanes:>5}   {r:13.1f}   {lanes / x:7.1f}   {MEASURED.get(lanes, "-"):>16}   {128 * x:19.1f}   {100 * x * a.gpu:10.0f}%')
    print(f'the device alone bounds the steady stream at {128 / a.gpu:.1f} proved tok/s; the measured stream runs at about 20 steady (one proof every 6.3 s)')


if __name__ == '__main__':
    main()
