#!/bin/bash
# Lane A24 native acceptance (one guarded job): the test build, the no-feature check, the full hashline lib
# suite (gpu-metal, release; compare its failures with the A23 merge's known five), the A24 tests by name,
# zkp-core's lib suite, then the release CLIs.
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5090f993c1401215
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
R=$WT/results/zk60_a24_app_20261107
TAG=${1:-t1}
P=$R/accept_$TAG.progress
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $R/accept_${TAG}_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/accept_${TAG}_build.log | head -120 >> $P; say "all done (build failed)"; exit 1; fi
say "warnings in A24 files: $(grep -A 3 '^warning' $R/accept_${TAG}_build.log | grep -cE 'classify_serve|classify_cli.rs|token_io/classify.rs|token_io/load.rs')"
/opt/homebrew/bin/cargo check --tests --offline --locked -j 2 --manifest-path $H > $R/accept_${TAG}_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C a24_ -- --test-threads=4 > $R/accept_${TAG}_a24.log 2>&1; say "A24 tests rc=$?"
grep -E "^test |test result" $R/accept_${TAG}_a24.log >> $P
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $R/accept_${TAG}_full.log 2>&1; say "full lib suite rc=$? (A23 merge: 956 passed, 5 known failures)"
grep -E "^test result" $R/accept_${TAG}_full.log >> $P
sed -n '/^failures:$/,/^test result/p' $R/accept_${TAG}_full.log | grep -E "^    [a-z_:0-9]+$" >> $P
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $Z --lib > $R/accept_${TAG}_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "test result" $R/accept_${TAG}_zkpcore.log >> $P
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify --example zk60_trained_block > $R/accept_${TAG}_cli.log 2>&1; say "release CLIs rc=$?"
say "zk60_classify sha256 $(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1)"
say "all done"
