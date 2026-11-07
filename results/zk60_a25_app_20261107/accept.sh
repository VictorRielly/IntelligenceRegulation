#!/bin/bash
# Lane A25 native acceptance (one guarded job): the release test build, the A25 tests and the census /
# registry / classifier filters, the no-feature check, then the release CLI and its SHA-256.
# usage: accept.sh <tag> [full]   (full: also the whole hashline lib suite and zkp-core's)
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
R=$WT/results/zk60_a25_app_20261107
TAG=${1:-t1}
FULL=${2:-}
P=$R/accept_$TAG.progress
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $R/accept_${TAG}_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/accept_${TAG}_build.log | head -150 >> $P; say "all done (build failed)"; exit 1; fi
say "warnings in A25 files: $(grep -A 3 '^warning' $R/accept_${TAG}_build.log | grep -cE 'classify_w16r2|classify_serve|classify_cli.rs|token_io/classify.rs|token_io/load.rs|classify_tied.rs|private_block/run.rs')"
for filt in a25_ a24_ s25_tests hash_domain s24_tests s33_tests token_io::classify w16r2_tests::w16r2_f6 w16r2_tests::w16r2_profiles; do
  env HL_R13_LOADER_FIXTURES=$F $C $filt -- --test-threads=4 > $R/accept_${TAG}_f_${filt//:/_}.log 2>&1
  say "filter $filt rc=$? $(grep -E '^test result' $R/accept_${TAG}_f_${filt//:/_}.log | tail -1)"
done
grep -E "^A25 \|" $R/accept_${TAG}_f_a25_.log >> $P
grep -E "^test .*FAILED|panicked" $R/accept_${TAG}_f_*.log | head -40 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked -j 2 --manifest-path $H > $R/accept_${TAG}_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
if [ "$FULL" = "full" ]; then
  env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $R/accept_${TAG}_full.log 2>&1; say "full lib suite rc=$? (A24 merge: 961 passed, 7 failed incl. 3 known)"
  grep -E "^test result" $R/accept_${TAG}_full.log >> $P
  sed -n '/^failures:$/,/^test result/p' $R/accept_${TAG}_full.log | grep -E "^    [a-z_:0-9]+$" >> $P
  /opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $Z --lib > $R/accept_${TAG}_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
  grep -E "test result" $R/accept_${TAG}_zkpcore.log >> $P
fi
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify > $R/accept_${TAG}_cli.log 2>&1; say "release CLI rc=$?"
say "zk60_classify sha256 $(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1)"
say "all done"
