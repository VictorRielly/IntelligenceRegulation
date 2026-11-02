#!/bin/bash
# D60 review closure: the MUTATION CHECK of the F4 and F8 tests. On a temporary build of the tree with
# (i) run::NOFOLLOW_NONBLOCK = None on macOS (the pre-F4 state) and (ii) the prover's catch_unwind removed (the
# pre-F8 state), each test must FAIL — at its timeout, never by hanging the harness — and the symlink case of F4
# must be ACCEPTED by the readers (so the test's refusal assertion fails). Logs in logs/close/mutant/.
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2e328baa581cb5b0
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/close/mutant
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
B=$R/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-48a0f1849b7501c1
T=private_block::run::fork::tests
export ZK60_GUARD_POLL_SECS=0.05
mkdir -p $L
shasum -a 256 $B | tee $L/mutant_binary.sha256
for c in "f4_fifo FIFO d60_f4_a_fifo_or_symlink_swapped_in_after_the_check_is_refused_without_hanging" \
         "f4_symlink symlink d60_f4_a_fifo_or_symlink_swapped_in_after_the_check_is_refused_without_hanging" \
         "f8 - d60_f8_a_prover_whose_every_worker_panics_fails_and_does_not_hang"; do
  set -- $c
  $G --class cpu --need-gib 8 --cap-gib 40 --label d60close-mutant-$1 --wait-secs 7200 --max-secs 600 --log $L/$1.log --done $L/$1.done -- \
    env HL_R13_LOADER_FIXTURES=$F HL_D60_F4_MUTANT=1 HL_D60_F4_SWAPS=$2 $B --exact $T::$3 --nocapture --test-threads=1
  echo "$1: test exit $(cat $L/$1.done) (want nonzero: the test FAILS on the mutant)"
  grep -h "panicked at\|HUNG\|WAS READ\|test result" $L/$1.log | grep -v "D60 F8 test switch" | head -6
done
