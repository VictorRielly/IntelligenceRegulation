#!/bin/bash
# D60 privacy gate (2026-11-02): every Python D55 gate run of the record, one after another on one tool state:
# the two registered R13-rung bundles and the two registered R13 8B T128 bundles (each with its pair as --other),
# then the W16 / W16R2 rung test-only D55 bundles of the privacy re-check (the regression, with the new D55-IO and
# D55-J parts). Exit 0 only if every run passes.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ac47d053f76c60f1c/results/zk60_d60_20261102/privacy_gate
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
rc=0
for pair in "r13-rung r13_rung_h24" "r13-8b r13_8b_t128_h24"; do
  set -- $pair
  bash $P/pygate.sh py-$1-s0 $B/d55-$2-s0 --other $B/d55-$2-s1 || rc=1
  bash $P/pygate.sh py-$1-s1 $B/d55-$2-s1 --other $B/d55-$2-s0 || rc=1
done
for pair in "w16-rung w16_rung_h24" "w16r2-rung w16r2_rung_h24"; do
  set -- $pair
  bash $P/pygate.sh py-$1-s0 $W/d55-$2-s0 --other $W/d55-$2-s1 || rc=1
  bash $P/pygate.sh py-$1-s1 $W/d55-$2-s1 --other $W/d55-$2-s0 || rc=1
done
exit $rc
