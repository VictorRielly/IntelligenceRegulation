#!/bin/bash
# Lane A27, job kb1 (one guarded gpu-class job, about a minute): the later-round kernels of the Shieldstral
# R13 slots 14 and 18 (dumped from the real run, p1solo) and their variants (scratchpad gen.py: v1 fewer
# points at the attained degree, v2 line values by additions, v3 linear nodes as tables, combined), timed on
# random extension tables with GPU timestamps, best of 3. Timing only: the variants' sums are not compared here.
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/kb
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247/results/zk60_a27_app_20261107
O=$R/kb1.log
if pgrep ds4-bench >/dev/null; then echo "POLLUTED: ds4-bench running" >> $O; else echo "quiet (no ds4-bench)" >> $O; fi
echo "== slot 14: 64 tables, 2^19, degree 5, eval_one 0 (later rounds from cap/4)" >> $O
$S/target/release/kbench $S/s14.metal 68 5 19 0 k_v0:5,k_v1:4,k_v2:5,k_v3:5,k_v13:4,k_v123:4 3 4 >> $O 2>&1
echo "== slot 18: 29 tables, 2^21, degree 5, eval_one 0 (later rounds from cap/4)" >> $O
$S/target/release/kbench $S/s18.metal 33 5 21 0 k_v0:5,k_v1:4,k_v2:5,k_v3:5,k_v13:4,k_v123:4 3 4 >> $O 2>&1
echo "rc=$?" >> $O
