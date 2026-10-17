#!/bin/bash
# Lane B6 serial queue: ONE guarded job at a time (need <= measured 3.6 GiB peaks + margin).
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
TOK=/home/victor/IntelligenceRegulation/local-models/zk60-llama3-8b/tokenizer.json
PRE128=$D/runs/llama3_8b_pg_rot1_T128/prepass.json
PRE32=$D/runs/llama3_8b_pg_rot1_T32/prepass.json
CAL128="--calib-per 2 --fw-calib 12"
# B6-1: one T=128 calibration (B5's statistics and profile decisions), exported at T=128 and T=64
$D/logs/b5_run.sh b6_T128 4 5 --variant pg --rotate 1 --tokenizer $TOK --T 128 $CAL128 --heldout-per 1 --fw-heldout 6 \
  --iso-seqs 4 --site-seqs 2 --tag b6 --profile-from $PRE128 --export --export-seqs 2 --export-name llama3_8b_pg_rot1_b6_T128
$D/logs/b5_run.sh b6_T64 4 5 --variant pg --rotate 1 --tokenizer $TOK --T 64 --calib-T 128 $CAL128 --heldout-per 1 --fw-heldout 6 \
  --iso-seqs 4 --site-seqs 2 --tag b6 --profile-from $PRE128 --export --export-seqs 2 --export-name llama3_8b_pg_rot1_b6_T64 \
  --link-from $D/export/llama3_8b_pg_rot1_b6_T128
for e in llama3_8b_pg_rot1_b6_T128 llama3_8b_pg_rot1_b6_T64; do
  python3 $G run --class light --need-gib 2 --cap-gib 3 --label b6-verify-$e --wait-secs 21600 --max-secs 7200 \
    --log $D/logs/b6-verify-$e.log --done $D/logs/b6-verify-$e.done --result-json $D/logs/b6-verify-$e.guard.json \
    -- env ZK60_MODEL=llama3-8b python3 /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/b3_verify_export.py $D/export/$e
done
echo done > $D/logs/b6_serial_exports.done
# B6-2: layer-1 options, whole model, T=32, FineWeb held-out only, B5's T=32 calibration + profile
for mode in s16 perhead m2zero none; do
  $D/logs/b5_run.sh b6_l1_$mode 4 5 --variant pg --rotate 1 --tokenizer $TOK --T 32 --heldout-per 0 --fw-heldout 36 \
    --tag b6l1$mode --profile-from $PRE32 --l1-mode $mode --check-against $D/export/llama3_8b_pg_rot1_T32
done
echo done > $D/logs/b6_serial.done
