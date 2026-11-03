#!/bin/bash
# W16R2 Q = 280 + F6: the DEFERRED step, the full lib suite, on q280_targeted.sh's binary. It starts only after
#  (1) q280_targeted.sh has finished with a binary (its .done marker, exit < 100), and
#  (2) the merged privacy-gate queue's follow-up checks have finished: the fr25-fixes worktree's
#      results/zk60_gate_tinyllama_20261017/round27/fixes/logs/after_queue.done exists (read only, never written),
# so the gate's own checks go first. Guarded like m32's full-suite step.
# Floors: 896 passed / 3 failed / 92 ignored before this branch, with exactly the known three failures; this branch
# adds two non-ignored tests (w16r2_tests: the Q = 280 pad-block check and the F6 counter check), so the expected
# totals are 898 / 3 / 92. Exit 0 = the failures are exactly the known three and the totals are 898 / 3 / 92.
set -u
export ZK60_GUARD_POLL_SECS=0.5
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7e40cbdbbf3f1b5d
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_q280_20261103/logs
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
AQ=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes/results/zk60_gate_tinyllama_20261017/round27/fixes/logs/after_queue.done
step() { echo "== $1 $(date +%H:%M:%S)"; }

step wait-targeted
while [ ! -e $L/q280_targeted.done ]; do sleep 30; done
TX=$(cat $L/q280_targeted.done)
echo "q280_targeted.sh exit $TX"
[ "$TX" -lt 100 ] || { echo "THE TARGETED CHAIN HAS NO BINARY (exit $TX): nothing to run"; exit 100; }
B=$(cat $L/binary.path)
ls -la $B || exit 101
step wait-gate-queue
while [ ! -e $AQ ]; do sleep 60; done
echo "after_queue.done: $(cat $AQ 2>/dev/null) at $(date +%H:%M:%S)"

step full-suite
$G --class cpu --need-gib 24 --cap-gib 160 --label q280-full --wait-secs 36000 --max-secs 7200 --log $L/full.log --done $L/full.guard.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --test-threads=8
grep -h "^test result" $L/full.log
KNOWN=$(printf '%s\n' \
  private_block::review_tests::a_toy_receipt_made_before_the_lane_still_verifies \
  private_block::trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces \
  private_block::trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name | sort)
GOT=$(grep -E '^test .* \.\.\. FAILED$' $L/full.log | awk '{print $2}' | sort)
echo "full-suite failures:"; echo "$GOT"
RC=0
[ "$GOT" = "$KNOWN" ] || { echo "THE FULL SUITE'S FAILURES ARE NOT EXACTLY THE KNOWN THREE"; RC=1; }
grep -q "^test result: FAILED. 898 passed; 3 failed; 92 ignored" $L/full.log || { echo "THE TOTALS ARE NOT 898 / 3 / 92"; RC=$((RC + 2)); }
step done
exit $RC
