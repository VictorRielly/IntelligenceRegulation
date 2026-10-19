#!/bin/bash
# NATIVE LANE R7, second chain (after the Q-2 edits): wait for the first
# chain's marker (it started before Q-2 and cannot freeze: its tree moved),
# archive its outputs under r7/attempt1-before-q2/, then run r7_chain.sh
# again on the complete R7 tree (N-r6-b + Q-2).
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
O=$D/r7
until [ -f $O/chain.done ]; do sleep 30; done
A=$O/attempt1-before-q2
mkdir -p $A
for f in $O/*; do
  [ "$f" = "$A" ] && continue
  mv "$f" $A/
done
echo "first chain exit $(cat $A/chain.done) (archived $(date -u +%H:%M:%S))"
$D/r7_chain.sh > $O/chain.out 2>&1
echo $? > $O/chain.done
