#!/bin/bash
# TOKEN ROUND 14: the mutation runs, then (only if every mutant was reverted and the tree's manifest is the
# pre-mutation one) the freeze chain. Marker logs/r14_tail.done.
T=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r14
L=$T/logs
bash $T/tools/r14_mut.sh > $L/r14_mut.chain.log 2>&1
if grep -q "^changed 0: \[\]" $L/mut-postmut.log && grep -q "^added 0: \[\]" $L/mut-postmut.log && grep -q "^removed 0: \[\]" $L/mut-postmut.log && ! grep -q "REVERT-FAILED\|apply-failed" $L/r14_mut.done; then
  bash $T/tools/r14_chain.sh > $L/r14_chain.chain.log 2>&1
  echo "mut=$(cat $L/r14_mut.done) chain=$(cat $L/r14_chain.done)" > $L/r14_tail.done
else
  echo "mut=$(cat $L/r14_mut.done) chain=NOT-RUN (the tree is not the pre-mutation tree)" > $L/r14_tail.done
fi
