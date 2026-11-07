#!/bin/bash
# Lane A24: one guarded job: the real-receipt controls (negctl.sh), then the second acceptance (accept2.sh).
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5090f993c1401215/results/zk60_a24_app_20261107
/bin/bash $R/negctl.sh
/bin/bash $R/accept2.sh t2
