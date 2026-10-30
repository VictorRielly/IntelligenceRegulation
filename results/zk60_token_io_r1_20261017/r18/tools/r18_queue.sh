#!/bin/bash
# TOKEN ROUND 18: the follow-up queue. Waits for r18_chain.sh's marker; runs r18_suite.sh only if the chain ended 0;
# runs r18_eq.sh only if the suite ended 0. Every heavy step inside them waits its turn (wait_turn.py). Marker
# logs/r18_queue.done = the last stage reached.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/tools/r18_common.sh
until [ -f $L/r18_chain.sh.done ]; do sleep 30; done
[ "$(cat $L/r18_chain.done)" = "0" ] || { echo "chain:$(cat $L/r18_chain.done)" > $L/r18_queue.done; exit 0; }
bash $T/tools/r18_suite.sh; echo $? > $L/r18_suite.sh.done
[ "$(cat $L/r18_suite.done)" = "0" ] || { echo "suite:$(cat $L/r18_suite.done)" > $L/r18_queue.done; exit 0; }
bash $T/tools/r18_eq.sh; echo $? > $L/r18_eq.sh.done
echo "eq:$(cat $L/r18_eq.done)" > $L/r18_queue.done
