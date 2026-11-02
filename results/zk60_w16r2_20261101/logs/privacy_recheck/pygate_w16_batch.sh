#!/bin/bash
# D59 condition (5): the v25 W16 gate on the remaining one-block bundles (W16R2 rung s1, W16R2 8B T128 s0/s1,
# and the W16 rung s0 as the regression of the edited module), one after another
set -u
L=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f/results/zk60_w16r2_20261101/logs/privacy_recheck
B=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
rc=0
for x in w16r2_rung_h24-s1 w16r2_8b_t128_h24-s0 w16r2_8b_t128_h24-s1 w16_rung_h24-s0; do
  bash $L/pygate.sh py-$x w16 $B/$x --name cpu-$x || rc=1
done
exit $rc
