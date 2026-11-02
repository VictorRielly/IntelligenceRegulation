#!/bin/bash
# Gate round 26 wiring (2026-11-02): every Python D55 gate run of the record, one after another on one tool state:
#  1. the FRESH registered R13-rung pair and the FRESH registered R13 8B T128 pair (pg_bundles_r26; each with its
#     pair as --other): the records the round asks for (PASS expected);
#  2. the GPU-refusal control: the fresh rung s0 bundle's clone with the manifest marked proved_on_gpu = true
#     (refused: DEV-PASS expected, the backend refused);
#  3. the OLD D60 rung s0 bundle (pg_bundles, no proved_on_gpu field): every pin now read, the backend UNKNOWN
#     (refused: DEV-PASS expected);
#  4. the W16 / W16R2 rung test-only D55 bundles of the privacy re-check (the regression: DEV-PASS expected,
#     their test-only pins stay unread).
# Exit 0 only if every run exits 0 (PASS or DEV-PASS); the verdicts are read from the records.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad2863f50f3102344/results/zk60_d60_20261102/privacy_gate_r26
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
C=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26_controls
O=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
rc=0
for pair in "r13-rung r13_rung_h24" "r13-8b r13_8b_t128_h24"; do
  set -- $pair
  bash $P/pygate.sh py-$1-s0 $B/d55-$2-s0 --other $B/d55-$2-s1 || rc=1
  bash $P/pygate.sh py-$1-s1 $B/d55-$2-s1 --other $B/d55-$2-s0 || rc=1
done
bash $P/pygate.sh py-ctl-marked-gpu $C/d55-r13_rung_h24-s0-marked-gpu --other $B/d55-r13_rung_h24-s1 || rc=1
bash $P/pygate.sh py-old-d60-rung-s0 $O/d55-r13_rung_h24-s0 --other $O/d55-r13_rung_h24-s1 || rc=1
for pair in "w16-rung w16_rung_h24" "w16r2-rung w16r2_rung_h24"; do
  set -- $pair
  bash $P/pygate.sh py-$1-s0 $W/d55-$2-s0 --other $W/d55-$2-s1 || rc=1
  bash $P/pygate.sh py-$1-s1 $W/d55-$2-s1 --other $W/d55-$2-s0 || rc=1
done
exit $rc
