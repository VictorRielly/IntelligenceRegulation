#!/bin/bash
# Lane A26, measurement job final1 (one guarded gpu-class job): build the release CLI from this tree (the
# candidate the app pins) and place it outside the repository as zk60_classify.a26; then its fixed-entropy
# byte identity against A24's on the real export (bi.sh); then the stream A/B pairs (m1.plan, A B B A);
# then the one-post pairs and the proof-only clocks (m2.plan).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb
R=$WT/results/zk60_a26_app_20261107
B=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a26
P=$R/final1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml --example zk60_classify > $R/final1_build.log 2>&1; rc=$?
say "release CLI rc=$rc"
if [ $rc -ne 0 ]; then say "all done (build failed)"; exit 1; fi
if [ -e $B ]; then chmod u+w $B; fi
cp $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify $B && chmod 555 $B
say "zk60_classify.a26 sha256 $(shasum -a 256 $B | cut -d' ' -f1)"
/bin/bash $R/bi.sh bi2 $B; say "bi2 done"
/bin/bash $R/runs.sh m1 $R/m1.plan; say "m1 done"
/bin/bash $R/runs.sh m2 $R/m2.plan; say "m2 done"
say "all done"
