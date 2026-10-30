#!/bin/bash
# gate round 19: the official queues on frozen v22, in order: R (the real capture, cpu 7.2 / 9, ALONE), then A and B
# (the R13 rung captures, light 1.3 / 2 each, side by side; nothing >= 3 GiB of this lane beside them)
P=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round19
$P/r19_gate_r.sh > $P/r19_gate_r.log 2>&1
$P/r19_gate_a.sh > $P/r19_gate_a.log 2>&1 &
$P/r19_gate_b.sh > $P/r19_gate_b.log 2>&1 &
wait
date -u > $P/r19_chain.done
