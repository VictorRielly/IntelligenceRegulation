#!/bin/bash
# Lane A28, job nb<N> (one guarded gpu-class job, about a minute): the commitment's kernels at the R13 Shieldstral
# A shape (4577 x 2^14 -> 2^16, q = 256), each alone, GPU timestamps, best of 5 (scratch bench a28nb/src/main.rs with
# the tree's metal_kernels.metal and a28nb/src/variants.metal; copies of both kept in nbench/): the tree's kernels
# against the A28 variants, every variant's words compared with the tree's.
# usage: nb.sh <tag> [rows]
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/a28nb
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
R=$WT/results/zk60_a28_app_20261107
O=$R/$1.log
if pgrep ds4-bench >/dev/null; then echo "POLLUTED: ds4-bench running" >> $O; else echo "quiet (no ds4-bench)" >> $O; fi
$S/target/release/kbench $WT/ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal_kernels.metal $S/src/variants.metal ${2:-4577} >> $O 2>&1
echo "rc=$?" >> $O
