#!/bin/bash
# Lane A27, job p1 (one guarded gpu-class job): build the classifier CLI from this worktree (the A26 tree +
# the A27 GPU trace; the A27 kernel switches are set OFF by p1.plan's env, so the runs are A26's GPU work),
# keep the binary as zk60_classify.a27-b0, then the profile runs of p1.plan (every receipt freshly verified).
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247/results/zk60_a27_app_20261107
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247
BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin
P=$R/p1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
/bin/bash $R/build.sh b0
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then say "all done (build failed)"; exit 1; fi
cp $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify $BIN/zk60_classify.a27-b0
say "binary a27-b0 sha256 $(shasum -a 256 $BIN/zk60_classify.a27-b0 | cut -d' ' -f1)"
/bin/bash $R/runs.sh p1 $R/p1.plan
say "runs rc=$?"
say "all done"
