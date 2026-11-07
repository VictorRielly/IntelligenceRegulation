#!/bin/bash
# Lane A27, job nb1 (one guarded gpu-class job, about a minute): the commitment's kernels at the R13 Shieldstral
# A shape (4577 x 2^14 -> 2^16, q = 256), each alone, GPU timestamps, best of 3 (scratch bench nbench/main.rs with
# the tree's metal_kernels.metal and nbench/variants.metal): the inverse head and tail, the forward head (A27's
# power-of-2 stages on and off, two stages per barrier, a loads-and-stores floor), the forward tail, the hash.
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/nb
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247
R=$WT/results/zk60_a27_app_20261107
O=$R/nb1.log
if pgrep ds4-bench >/dev/null; then echo "POLLUTED: ds4-bench running" >> $O; else echo "quiet (no ds4-bench)" >> $O; fi
$S/target/release/kbench $WT/ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal_kernels.metal $S/src/variants.metal 4577 >> $O 2>&1
echo "rc=$?" >> $O
