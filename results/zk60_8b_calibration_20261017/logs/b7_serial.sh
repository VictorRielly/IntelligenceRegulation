#!/bin/bash
# Lane B7 (coordinator 23:4xZ): b6 calibration + profile decisions, layer 1 at SH_S 7 (l1-mode sh7), every other
# layer SH_S 6; native R6 per-layer sh_s format. T128 FIRST, then T64, T32. ONE guarded light job at a time.
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
TOK=/home/victor/IntelligenceRegulation/local-models/zk60-llama3-8b/tokenizer.json
PRE128=$D/runs/llama3_8b_pg_rot1_T128/prepass.json
B6=$D/export/llama3_8b_pg_rot1_b6_T128
COMMON="--variant pg --rotate 1 --tokenizer $TOK --calib-per 2 --fw-calib 12 --heldout-per 1 --fw-heldout 6 --iso-seqs 4 --site-seqs 2 --tag b7 --profile-from $PRE128 --l1-mode sh7 --export --export-seqs 2 --check-against $B6"
verify() {
  python3 $G run --class light --need-gib 2.5 --cap-gib 3.5 --label b7-verify-$1 --wait-secs 21600 --max-secs 7200 \
    --log $D/logs/b7-verify-$1.log --done $D/logs/b7-verify-$1.done --result-json $D/logs/b7-verify-$1.guard.json \
    -- env ZK60_MODEL=llama3-8b python3 /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/b3_verify_export.py $D/export/$1
  python3 $D/b7_check_format.py $D/export/$1 > $D/logs/b7-format-$1.json 2>&1; echo $? > $D/logs/b7-format-$1.done
}
$D/logs/b5_run.sh b7_T128 3.5 4.5 $COMMON --T 128 --export-name llama3_8b_pg_rot1_b7_T128 --link-from $B6
verify llama3_8b_pg_rot1_b7_T128
echo done > $D/logs/b7_T128_stage.done
$D/logs/b5_run.sh b7_T64 3.5 4.5 $COMMON --T 64 --calib-T 128 --export-name llama3_8b_pg_rot1_b7_T64 --link-from $D/export/llama3_8b_pg_rot1_b7_T128
verify llama3_8b_pg_rot1_b7_T64
$D/logs/b5_run.sh b7_T32 3.5 4.5 $COMMON --T 32 --calib-T 128 --export-name llama3_8b_pg_rot1_b7_T32 --link-from $D/export/llama3_8b_pg_rot1_b7_T128
verify llama3_8b_pg_rot1_b7_T32
