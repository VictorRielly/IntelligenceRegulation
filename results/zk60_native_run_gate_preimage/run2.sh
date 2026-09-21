#!/bin/bash
# ROUND 7 (2026-09-21), the run of record: the four bundles under
# `--full-preimage`, each wrapped in `/usr/bin/time -v` so the peak resident
# set is MEASURED and not estimated.  (The first pass, `run.sh`, was taken
# while the tool was still being edited; this one is taken on frozen bytes,
# which is what `tool_sha256` in each record then pins.)
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
E=$W/results/zk60_native_run_gate_preimage
/usr/bin/time -v python3 $G --full-preimage --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $E 2> $E/time-run-g-dense-s20.log
/usr/bin/time -v python3 $G --full-preimage --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $E 2> $E/time-run-h-zero-s20.log
/usr/bin/time -v python3 $G --full-preimage --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $E 2> $E/time-run-i-dense-k4.log
/usr/bin/time -v python3 $G --full-preimage --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $E 2> $E/time-run-j-zero-k4.log
bash $E/refresh.sh
bash $E/diff.sh
