#!/bin/bash
# Lane B4 serial queue v2 (orchestrator rule 2026-10-17: AT MOST ONE guarded B4
# job at a time, declared need <= 3.5 GiB). Each step starts only after the
# previous guard has exited. Order: B4-2 export + checks first, then B4-1's
# remaining dg+rot T=128 run.
D=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929
L=$D/logs
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/export
for v in pg_rot1_T128 pg_rot1_T32_cal128 dg_o16_rot1_T32 pg_o16_rot1_T32; do
  until [ -f $L/b4-$v.done ]; do sleep 20; done
done
chk() {  # chk <label> <need> <cap> <cmd...>
  lab=$1; need=$2; cap=$3; shift 3
  python3 $G run --class light --need-gib $need --cap-gib $cap --label b4-$lab --wait-secs 21600 --max-secs 3600 \
    --log $L/b4-$lab.log --done $L/b4-$lab.done --result-json $L/b4-$lab.guard.json -- "$@"
}
$L/b4_run.sh pg_rot1_T64_cal128 3.5 4.5 --variant pg --rotate 1 --corpus b4 --T 64 --calib-T 128 --site-seqs 3 --export --export-seqs 2 --token-io
for e in pg_rot1_b4_T128 pg_rot1_b4_T64_cal128 pg_rot1_b4_T32_cal128; do
  chk verify-$e 1.5 2.5 python3 $D/b3_verify_export.py $X/$e
  chk tokenio-$e 2.5 3.5 python3 $D/b4_token_io.py $X/$e
done
chk dedup-cal128 1 1.5 python3 $D/b4_dedup.py $X/pg_rot1_b4_T128 $X/pg_rot1_b4_T64_cal128 $X/pg_rot1_b4_T32_cal128
echo done > $L/b4_serial2_exports.done
$L/b4_run.sh dg_rot1_T128 3.5 5 --variant dg --rotate 1 --corpus b4 --T 128 --site-seqs 3
echo done > $L/b4_serial2.done
