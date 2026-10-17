#!/bin/bash
# Lane B6 resume after the 14:59:58Z shutdown / 18:21Z reboot: ONE guarded job at a time.
# (the killed run's partial T64 export was removed at 18:3xZ; the driver now refuses a non-empty export dir)
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
TOK=/home/victor/IntelligenceRegulation/local-models/zk60-llama3-8b/tokenizer.json
PRE128=$D/runs/llama3_8b_pg_rot1_T128/prepass.json
PRE32=$D/runs/llama3_8b_pg_rot1_T32/prepass.json
CAL128="--calib-per 2 --fw-calib 12"
verify() {
  python3 $G run --class light --need-gib 2.5 --cap-gib 3.5 --label b6r-verify-$1 --wait-secs 21600 --max-secs 7200 \
    --log $D/logs/b6r-verify-$1.log --done $D/logs/b6r-verify-$1.done --result-json $D/logs/b6r-verify-$1.guard.json \
    -- env ZK60_MODEL=llama3-8b python3 /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/b3_verify_export.py $D/export/$1
}
# B6-1 (resume): T128 verifier (killed at start before), T64 export (same calibration, hard links), T64 verifier
verify llama3_8b_pg_rot1_b6_T128
$D/logs/b5_run.sh b6r_T64 4 5 --variant pg --rotate 1 --tokenizer $TOK --T 64 --calib-T 128 $CAL128 --heldout-per 1 --fw-heldout 6 \
  --iso-seqs 4 --site-seqs 2 --tag b6 --profile-from $PRE128 --export --export-seqs 2 --export-name llama3_8b_pg_rot1_b6_T64 \
  --link-from $D/export/llama3_8b_pg_rot1_b6_T128
verify llama3_8b_pg_rot1_b6_T64
echo done > $D/logs/b6r_serial_exports.done
# B6-2: layer-1 options, whole model, T=32, FineWeb held-out only (36), B5's T=32 calibration + profile;
# 'none' runs on 2 layers only (b5_run.sh): its whole-model numbers equal B5 T32's FineWeb domain
for mode in s16 perhead m2zero none; do
  $D/logs/b5_run.sh b6_l1_$mode 4 5 --variant pg --rotate 1 --tokenizer $TOK --T 32 --heldout-per 0 --fw-heldout 36 \
    --tag b6l1$mode --profile-from $PRE32 --l1-mode $mode --check-against $D/export/llama3_8b_pg_rot1_T32
done
