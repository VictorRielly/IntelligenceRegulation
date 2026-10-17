#!/bin/bash
# Lane B4 serial queue (orchestrator rule 2026-10-17: AT MOST ONE guarded B4 job
# at a time, declared need <= 3.5 GiB). Waits for the jobs already running, then
# runs each step only after the previous step's guard has exited (.done written).
D=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/logs
for v in pg_rot1_T128 pg_rot1_T32_cal128 dg_o16_rot1_T32 pg_o16_rot1_T32; do
  until [ -f $D/b4-$v.done ]; do sleep 20; done
done
$D/b4_run.sh dg_rot1_T128 3.5 5 --variant dg --rotate 1 --corpus b4 --T 128 --site-seqs 3
$D/b4_run.sh pg_rot1_T64_cal128 3.5 4.5 --variant pg --rotate 1 --corpus b4 --T 64 --calib-T 128 --site-seqs 3 --export --export-seqs 2 --token-io
echo done > $D/b4_serial.done
