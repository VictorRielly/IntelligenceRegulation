#!/bin/bash
# Lane A25, job c1 (one guarded cpu-class job), after f1 found the W16R2 switch refused on the real export:
#  1. the release test build and the real export's census at W16R2 (which layers the trained door refuses,
#     and the W16R2 plane lists the layers' own calibrations would give);
#  2. the R13 path's byte compatibility: A24's pinned binary verifies (re-checks byte for byte) the R13
#     receipt this lane's binary made in f1 (stream r1), and this binary's CLI verify without the switch;
#  3. the A25 filter again, then the full hashline lib suite and zkp-core's.
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c
REPO=/Users/victorrielly/IntelligenceRegulation
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
R=$WT/results/zk60_a25_app_20261107
BIN=$WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify
A24BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
VEXP=$REPO/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier
EXP=$REPO/results/zk60_shieldstral_export_20261026/native_low_h24_t128
PUBR=/Users/victorrielly/zk60-artifacts/a25-media-app-20261107/stream-r1/p0
F=$REPO/results/zk60_1b_native_20261017/r13/loader-fixtures
IDR=e4f97455f9a301ea8646ae1754bb29de52e51798ae7e8e435a597eedbcf3279d
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
export ZK60_MODELS=$REPO/results/zk60_astra_20261026/flashprove_runtime_20261104/models HL_GPU=0 HL_PB_ORACLE=0 HL_PB_TIMING=0
P=$R/c1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $R/c1_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/c1_build.log | head -120 >> $P; say "all done (build failed)"; exit 1; fi
say "warnings in A25 files: $(grep -A 3 '^warning' $R/c1_build.log | grep -cE 'classify_w16r2|classify_serve|classify_cli.rs|token_io/classify.rs|token_io/load.rs|classify_tied.rs|private_block/run.rs:(1[7-9][0-9]|2[0-4][0-9]|36[0-9]|65[0-9]|66[0-9])')"
env HL_A25_EXPORT=$EXP $C a25_census -- --ignored --nocapture --test-threads=1 > $R/c1_census.log 2>&1; say "census rc=$? $(grep -E '^test result' $R/c1_census.log | tail -1)"
grep -E "A25-CENSUS" $R/c1_census.log >> $P
POL=shieldstral-1.0-3b-moderate-sexual/1
V="--export $VEXP --tables $VEXP/token_io --label zk60-classify-verdict --min-bits 95 --expect-statement $IDR"
$A24BIN verify $V --policy $POL --artifact $PUBR/sexual-c0 > $R/c1_a24_verify_r1.log 2>&1
say "A24 binary verify of this binary's R13 receipt (stream r1) rc=$? $(grep -o '"published_by":"[^"]*"' $R/c1_a24_verify_r1.log)"
$BIN verify $V --policy shieldstral-1.0-3b-moderate-violence/1 --artifact $PUBR/violence-c0 > $R/c1_a25_verify_r1.log 2>&1
say "this binary's verify (no switch) of its R13 receipt (violence) rc=$? $(grep -o '"published_by":"[^"]*"' $R/c1_a25_verify_r1.log)"
$A24BIN verify $V --policy shieldstral-1.0-3b-moderate-hate/1 --artifact $PUBR/hate-c0 > $R/c1_a24_verify_r1_hate.log 2>&1
say "A24 binary verify of this binary's R13 receipt (hate) rc=$? $(grep -o '"published_by":"[^"]*"' $R/c1_a24_verify_r1_hate.log)"
env HL_R13_LOADER_FIXTURES=$F $C a25_ -- --test-threads=4 > $R/c1_a25.log 2>&1; say "filter a25_ rc=$? $(grep -E '^test result' $R/c1_a25.log | tail -1)"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $R/c1_full.log 2>&1; say "full lib suite rc=$? (A24's tree: 961 passed, 7 failed, of which the 3 A23-known and 4 A24 census fixes)"
grep -E "^test result" $R/c1_full.log >> $P
sed -n '/^failures:$/,/^test result/p' $R/c1_full.log | grep -E "^    [a-z_:0-9]+$" >> $P
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $Z --lib > $R/c1_zkpcore.log 2>&1; say "zkp-core lib tests rc=$?"
grep -E "test result" $R/c1_zkpcore.log >> $P
say "all done"
