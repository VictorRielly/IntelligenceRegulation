#!/bin/bash
# gate round 20: the official queues on frozen v23, in order:
#   A (light: the r17 rung values capture gated in full, failing-first, the v23 suite frozen + working copy),
#   R (LIMITS 1 + 2: the real values bundle, the WHOLE gate with the FULL preimage over all 84 commitments; cpu
#      8.8 / 10.5, ALONE: waits until no other guarded job -- sol- / astra- included -- is live or waiting).
P=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round20
$P/r20_queue_a.sh > $P/r20_queue_a.log 2>&1
$P/r20_gate_r.sh > $P/r20_gate_r.log 2>&1
date -u > $P/r20_chain.done
