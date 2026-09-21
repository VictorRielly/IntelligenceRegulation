#!/bin/bash
# ROUND 7 (2026-09-21): the FULL zero-data preimage -- A and H included, both
# halves, every opened column and the salted leaves of the opened columns --
# on the four current bundles, every stage.  `--full-preimage` is the opt-in
# arm; everything else is the round-6 command line, so every other figure in
# these records is comparable with the records of record.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
E=$W/results/zk60_native_run_gate_preimage
python3 $G --full-preimage --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $E
python3 $G --full-preimage --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $E
python3 $G --full-preimage --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $E
python3 $G --full-preimage --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $E
