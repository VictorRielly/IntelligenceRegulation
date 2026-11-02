#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02): the whole lane after build.sh, detached (detach.py), in this order:
#  1. the gate on the round-26 rung s0 bundle (the first full run of the new parts: a check before hours of runs);
#  2. capture_all.sh (the s25 W-2 printout, the new base bundles);
#  3. pygate_all.sh (every gate run; the rung s0 record is re-made with the printout in place).
# Each step is guarded inside its own script; progress lines go to logs/queue.progress.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7/results/zk60_d60_20261102/privacy_gate_tsbases
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
echo "$(date -u +%FT%TZ) start" >> $P/logs/queue.progress
bash $P/pygate.sh first-r13-rung-s0 $B/d55-r13_rung_h24-s0 --other $B/d55-r13_rung_h24-s1; echo "$(date -u +%FT%TZ) first-r13-rung-s0 rc=$?" >> $P/logs/queue.progress
bash $P/capture_all.sh; echo "$(date -u +%FT%TZ) capture_all rc=$?" >> $P/logs/queue.progress
bash $P/pygate_all.sh; echo "$(date -u +%FT%TZ) pygate_all rc=$?" >> $P/logs/queue.progress
