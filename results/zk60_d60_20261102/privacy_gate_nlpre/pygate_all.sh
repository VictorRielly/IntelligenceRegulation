#!/bin/bash
# NL-1 / PRE lane (2026-11-02): the full Python D55 gate, with the NL-1 and PRE parts, on the four FRESH registered R13
# bundles of gate round 26 (pg_bundles_r26; each with its pair as --other), one after another on one tool state.
# The bundles are read only.  Exit 0 only if every run exits 0 (PASS or DEV-PASS); the verdicts are read from the records.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a19d9832207e830a4/results/zk60_d60_20261102/privacy_gate_nlpre
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
rc=0
for pair in "r13-rung r13_rung_h24" "r13-8b r13_8b_t128_h24"; do
  set -- $pair
  bash $P/pygate.sh py-$1-s0 $B/d55-$2-s0 --other $B/d55-$2-s1 || rc=1
  bash $P/pygate.sh py-$1-s1 $B/d55-$2-s1 --other $B/d55-$2-s0 || rc=1
done
exit $rc
