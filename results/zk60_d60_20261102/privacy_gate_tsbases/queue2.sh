#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02), PASS 2: after the s25 W-2 L-coverage fix (s25_tests.rs, test code), in order:
#  1. build.sh full build2 (guarded build class; logs/binary.path then names the new test binary);
#  2. the s25 W-2 census with its printout at the fixed coverage -> logs/s25_w2_printout_v2.log;
#  3. pygate_all2.sh (all 12 bundles, records_final/).
# Steps 2-3 run only if the step before succeeded. Progress lines go to logs/queue2.progress.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7/results/zk60_d60_20261102/privacy_gate_tsbases
Q=$P/logs/queue2.progress
echo "$(date -u +%FT%TZ) start" >> $Q
bash $P/build.sh full build2; rc=$?; echo "$(date -u +%FT%TZ) build2 rc=$rc" >> $Q
[ $rc = 0 ] || exit $rc
bash $P/run.sh s25_w2_v2 cpu 4 16 -- --exact --nocapture --test-threads=1 private_block::s25_tests::every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length; rc=$?
echo "$(date -u +%FT%TZ) s25_w2_v2 rc=$rc" >> $Q
[ $rc = 0 ] || exit $rc
cp $P/logs/s25_w2_v2.log $P/logs/s25_w2_printout_v2.log
bash $P/pygate_all2.sh; rc=$?; echo "$(date -u +%FT%TZ) pygate_all2 rc=$rc" >> $Q
exit $rc
