#!/bin/bash
# Lane A28, job nbf<N> (one guarded gpu-class job, under a minute): the field-arithmetic variants (a28nb field mode):
# every variant's add / sub / product / reduction against the tree's on 2^25 canonical pairs plus the edge cases, and
# 2^24 arbitrary 64-bit pairs for the product and reduction, then their butterfly rates in registers.
S=/Users/victorrielly/zk60-artifacts/a28-tools/a28nb
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
R=$WT/results/zk60_a28_app_20261107
O=$R/$1.log
if pgrep ds4-bench >/dev/null; then echo "POLLUTED: ds4-bench running" >> $O; else echo "quiet (no ds4-bench)" >> $O; fi
$S/target/release/kbench $WT/ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal_kernels.metal $S/src/variants.metal field >> $O 2>&1
echo "rc=$?" >> $O
