#!/bin/bash
# Lane A24: one guarded job: the second acceptance (after the s25 census edits), then one native stream
# with smaller rayon pools (8 prover lanes x 3, 4 verifier lanes x 2) to test the spin hypothesis.
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5090f993c1401215/results/zk60_a24_app_20261107
/bin/bash $R/accept2.sh t3
/bin/bash $R/stream.sh s8c $R/posts/stream8.json --lanes 8 --lane-threads 3 --check-lanes 4 --check-threads 2 --witness-gib 12 --keep 0
