#!/bin/bash
# Lane A24 acceptance, second pass (one guarded job): after the additive s25 census edits, the s25 and
# hash-domain censuses, every token_io classify test and the A24 tests by filter; then the A23 server's
# R13-export device test (the stack-serve path, untouched by A24) as a spot check.
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5090f993c1401215
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
R=$WT/results/zk60_a24_app_20261107
TAG=${1:-t2}
P=$R/accept_$TAG.progress
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $R/accept_${TAG}_build.log 2>&1; rc=$?; say "test build rc=$rc"
[ $rc -ne 0 ] && { grep -E "^error" -A 14 $R/accept_${TAG}_build.log | head -80 >> $P; say "all done (build failed)"; exit 1; }
for f in s25_tests hash_domain token_io::classify a24_; do
  env HL_R13_LOADER_FIXTURES=$F $C $f -- --test-threads=8 > $R/accept_${TAG}_$(echo $f | tr ':' '_').log 2>&1
  say "filter $f rc=$? $(grep -E '^test result' $R/accept_${TAG}_$(echo $f | tr ':' '_').log | tail -1)"
  sed -n '/^failures:$/,/^test result/p' $R/accept_${TAG}_$(echo $f | tr ':' '_').log | grep -E "^    [a-z_:0-9]+$" >> $P
done
t=a23_the_server_with_shared_blocks_proves_the_r13_export_as_stack_prove_does_on_the_device
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a23::$t -- --ignored --exact --nocapture --test-threads=1 > $R/accept_${TAG}_a23_r13.log 2>&1
say "$t rc=$? $(grep -E '^test result' $R/accept_${TAG}_a23_r13.log | tail -1)"
say "all done"
