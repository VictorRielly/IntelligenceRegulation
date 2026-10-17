#!/bin/bash
# Lane B5 serial queue: ONE guarded job at a time; each step starts after the previous guard exited.
D=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
TOK=/home/victor/IntelligenceRegulation/local-models/zk60-llama3-8b/tokenizer.json
$D/logs/b5_run.sh pg_T32 4.5 6 --variant pg --rotate 1 --tokenizer $TOK --T 32 --export --export-seqs 2
EXP=$D/export/llama3_8b_pg_rot1_T32
ZK60_MODEL=llama3-8b python3 $G run --class light --need-gib 2 --cap-gib 3 --label b5-verify-pg_T32 --wait-secs 21600 --max-secs 7200 \
  --log $D/logs/b5-verify-pg_T32.log --done $D/logs/b5-verify-pg_T32.done --result-json $D/logs/b5-verify-pg_T32.guard.json \
  -- env ZK60_MODEL=llama3-8b python3 /home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/b3_verify_export.py $EXP
$D/logs/b5_run.sh pg_T128 4.5 6 --variant pg --rotate 1 --tokenizer $TOK --T 128 --calib-per 2 --fw-calib 12 --heldout-per 2 --fw-heldout 12 --iso-seqs 6
echo done > $D/logs/b5_serial.done
