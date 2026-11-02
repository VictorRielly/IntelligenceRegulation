#!/bin/bash
# D59 condition (5) / D60 prerequisite (2026-11-02): the FINAL v25 staging gate runs, all on one tool state:
# the W16 gate on the W16R2 rung and 8B one-block captures (two hidden inputs each) and on the W16 rung
# (the regression of the edited module); the D55 gate on the W16 and W16R2 rung fork-run captures (two each);
# then the staging_v25 suite with each D55 bundle named. One after another; exit 0 only if all pass.
set -u
L=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f/results/zk60_w16r2_20261101/logs/privacy_recheck
E=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f/results/zk60_w16r2_20261101/privacy_recheck_gate
B=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
rm -f $E/*.json
rc=0
for x in w16r2_rung_h24-s0 w16r2_rung_h24-s1 w16r2_8b_t128_h24-s0 w16r2_8b_t128_h24-s1 w16_rung_h24-s0; do
  bash $L/pygate.sh py-$x w16 $B/$x --name cpu-$x || rc=1
done
for x in d55-w16_rung_h24-s0 d55-w16_rung_h24-s1 d55-w16r2_rung_h24-s0 d55-w16r2_rung_h24-s1; do
  bash $L/pygate.sh py-$x d55 $B/$x --name cpu-$x || rc=1
done
bash $L/suite_v25.sh suite_v25_d55w16r2 d55-w16r2_rung_h24-s0
bash $L/suite_v25.sh suite_v25_d55w16 d55-w16_rung_h24-s0
exit $rc
