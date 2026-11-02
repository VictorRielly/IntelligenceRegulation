#!/bin/bash
# Merged gate queue (2026-11-02), detached; progress lines go to logs/queue.progress, each step's rc with it.
#  0. wait for the NL-1 / PRE lane's chain (its four records and suite run on that lane's own code, on a box this
#     queue leaves alone);
#  1. the post-merge check m32 (results/zk60_metal_20261031/logs/m32lanes/m32_merge.sh): build, targeted tests on
#     Metal, CPU = Metal bytes, the v25 Python suite with every lane's bundles, the full Rust suite;
#  2. the merged gate (pygate.sh, all 18 parts at an R13 base) on the four round-26 registered R13 bundles, then the
#     TS lane's eight registered-base bundles, each with its pair as --other.
# Before every step: if logs/STOP exists the queue ends there (a stop without a kill).
set -u
R=/Users/victorrielly/IntelligenceRegulation
P=$R/results/zk60_d60_20261102/privacy_gate_merged
L=$P/logs
Q=$L/queue.progress
NLDONE=$R/.claude/worktrees/agent-a19d9832207e830a4/results/zk60_d60_20261102/privacy_gate_nlpre/logs/chain.done
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
N=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
mkdir -p $L
say() { echo "$(date -u +%FT%TZ) $*" >> $Q; }
stop() { [ -f $L/STOP ] && { say "STOP file found, queue ends"; exit 0; }; return 0; }
say start
until [ -f $NLDONE ]; do sleep 120; done
say "nl chain.done $(cat $NLDONE)"
stop
bash $R/results/zk60_metal_20261031/logs/m32lanes/m32_merge.sh > $R/results/zk60_metal_20261031/logs/m32lanes/m32.out 2>&1
say "m32 rc=$?"
pair() {  # tag-stem, directory, bundle stem
  stop; bash $P/pygate.sh mg-$1-s0 $2/d55-$3-s0 --other $2/d55-$3-s1; say "mg-$1-s0 rc=$?"
  stop; bash $P/pygate.sh mg-$1-s1 $2/d55-$3-s1 --other $2/d55-$3-s0; say "mg-$1-s1 rc=$?"
}
pair r13-rung $B r13_rung_h24
pair r13-8b $B r13_8b_t128_h24
pair tiny-t128 $N r13_tiny_t128_low
pair shield-t128 $N r13_shield_t128_h24
pair shield-t128-own $N r13_shield_t128_h24-own
pair shield-t256 $N r13_shield_t256_h24
say "all done"
