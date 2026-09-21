#!/bin/bash
# ROUND 8 (2026-09-21), THE RUN OF RECORD (third and final pass).
# `run.sh` was the first pass (stage 13 did not exist yet).  `run2.sh` was
# the second, and while it was running the gate gained one more thing: the
# guard that makes a REFUSING mask stage carry zeroed counts instead of no
# counts, so that neither `mask_cfs_run` nor `channels()` can raise on one
# (round 5's finding K4-F1, which forbids exactly that shape of crash).
# That moved two tool files, so the run of record is taken again here on
# the frozen bytes -- which is what `tool_sha256` in each record pins --
# and this pass ends by running the three suites inside the SAME lock hold,
# so nothing can interleave between the records and the tests that read
# them.  Both arms are on
# (`--full-preimage --mask-cfs`), so the channel table is complete in one
# record and stage 13 can join them.  Each run is wrapped in
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
# ROUND 7's OWN evidence, re-taken under the current tools.  Round 8 moved
# the gate, so the tool digests round 7's records pin no longer name any
# file in the tree, and `zk60_native_rg_ahpreimage`'s own test says so.
# Every stage-11 figure is unchanged by this; what moves is the tool
# hashes and the channel table (25 -> 28, the three added entries OPEN
# because --mask-cfs is off here on purpose).
P=$W/results/zk60_native_run_gate_preimage
python3 $G --full-preimage --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $P
python3 $G --full-preimage --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $P
python3 $G --full-preimage --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $P
python3 $G --full-preimage --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $P
bash $E/diff.sh
bash $E/tests.sh
cp $E/tests_mask.log $E/tests_mask.final.log
cp $E/tests_run_gate_all.log $E/tests_run_gate_all.final.log
cp $E/tests_native_all.log $E/tests_native_all.final.log
