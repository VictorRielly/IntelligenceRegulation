#!/bin/bash
# TOKEN ROUND 17: the v22 FORMAT check (r17/tools/v22_format_check.py; v22's pin rule bypassed, as declared) on the REAL
# capture with values, BOUNDED to blocks 2 and 3 (G 18 and 20: two gate denominators the rung does not have); controls on
# the first. cpu class alone, need 6.5 / cap 8 (the coordinator's rule for the real capture's analysis since gate round
# 19). Marker logs/v22-real.exit.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r17/tools/r17_common.sh
C2=/home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values
hold; gap; lean; step "v22 format check (real, blocks 2, 3)"
$G --class cpu --need-gib 6.5 --cap-gib 8.0 --label tio17-v22-real --wait-secs 14400 --max-secs 3600 --log $L/v22-real.log --done $L/v22-real.guard.done --result-json $L/v22-real.guard.json -- python3 $T/tools/v22_format_check.py --bundle $C2 --out $T/v22check/real-hate-r17-values-blocks-2-3.json --blocks 2,3
echo $? > $L/v22-real.exit
step "v22 format check (real) end $(cat $L/v22-real.exit)"
