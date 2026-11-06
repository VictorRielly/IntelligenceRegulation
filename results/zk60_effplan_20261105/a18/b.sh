#!/bin/bash
# A18: a compile check of the work-in-progress tree (the test binary, release, gpu-metal). One guarded job.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a18
P=$O/b.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run > $O/raw/b_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^(error|warning)" -A 14 $O/raw/b_build.log | head -300 > $O/raw/b_errors.txt
fi
say "all done"
