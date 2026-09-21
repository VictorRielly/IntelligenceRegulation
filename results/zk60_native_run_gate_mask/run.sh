#!/bin/bash
# ROUND 8 (2026-09-21), the run of record: the four current bundles under
# BOTH arms -- `--full-preimage` (round 7) and `--mask-cfs` (round 8) -- so
# that the channel table is complete in one record and channel 16's reason
# can say what the masking layer now is.  Each is wrapped in
# `/usr/bin/time -v` so the peak resident set is MEASURED.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
E=$W/results/zk60_native_run_gate_mask
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $E 2> $E/time-run-g-dense-s20.log
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $E 2> $E/time-run-h-zero-s20.log
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $E 2> $E/time-run-i-dense-k4.log
/usr/bin/time -v python3 $G --full-preimage --mask-cfs --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $E 2> $E/time-run-j-zero-k4.log
python3 $W/scripts/zk60_native_rg_mask.py --toy $W/results/zk60_native_captures_20260919/captures --evidence $E
bash $W/results/zk60_native_run_gate_preimage/refresh.sh
bash $E/diff.sh
