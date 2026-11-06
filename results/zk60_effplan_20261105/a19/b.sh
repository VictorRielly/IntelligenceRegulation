#!/bin/bash
# A19: a compile check of the work-in-progress tree (the test binary, release, gpu-metal; then the no-feature
# `cargo check --tests`). One guarded job, class build.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a19
P=$O/b.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run -j 8 > $O/raw/b_build.log 2>&1
rc=$?
say "build rc=$rc"
grep -E "^(error|warning)" -A 14 $O/raw/b_build.log | head -400 > $O/raw/b_errors.txt
if [ $rc -eq 0 ]; then
  /opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/raw/b_check_nometal.log 2>&1
  say "no-feature cargo check --tests rc=$?"
  grep -E "^(error|warning)" -A 14 $O/raw/b_check_nometal.log | head -200 > $O/raw/b_check_errors.txt
fi
say "all done"
