#!/bin/bash
# NL-1 / PRE lane (2026-11-02): the whole record, one detached chain -- the four gate runs (pygate_all.sh: rung s0, s1,
# 8B s0, s1, each queued behind the heavy lock with wait-secs 28800), then the v25 staging suite (suite.sh).
# Each step's exit code goes to logs/chain.<step>.rc; launched by detach.py with marker logs/chain.done.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a19d9832207e830a4/results/zk60_d60_20261102/privacy_gate_nlpre
bash $P/pygate_all.sh; echo $? > $P/logs/chain.pygate_all.rc
bash $P/suite.sh suite_v25; echo $? > $P/logs/chain.suite.rc
exit 0
