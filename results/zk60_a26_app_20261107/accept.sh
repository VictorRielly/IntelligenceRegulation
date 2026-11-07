#!/bin/bash
# Lane A26 native acceptance (one guarded job): the release CLI; hashline's census tests (s25, hash_domain,
# r19b), every token_io::classify test (A24's serve tests and A26's included), the A26 tests by name, the
# L9 and L11 test-only exports (each corpus compared byte for byte with its committed one: the prover's
# bytes on the W16R2 rung); zkp-core's suite; the no-feature `cargo check --tests`; optionally the full
# hashline lib suite (FULL=1).
# usage: accept.sh <tag>
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
R=$WT/results/zk60_a26_app_20261107
TAG=${1:-t1}
P=$R/accept_$TAG.progress
F=$WT/results/zk60_1b_native_20261017/r13/loader-fixtures
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/a26_$TAG
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify > $R/accept_${TAG}_cli.log 2>&1; rc=$?; say "release CLI rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/accept_${TAG}_cli.log | head -120 >> $P; say "all done (build failed)"; exit 1; fi
say "zk60_classify sha256 $(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1)"
$C --no-run > $R/accept_${TAG}_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/accept_${TAG}_build.log | head -120 >> $P; say "all done (test build failed)"; exit 1; fi
say "warnings naming A26 files: $(grep -A 4 '^warning' $R/accept_${TAG}_build.log | grep -cE 'classify_run.rs|classify_serve|classify_cli.rs|token_io/run.rs|argument.rs|a26')"
for f in a26_ a4_ s25_tests hash_domain r19b token_io::classify; do
  n=$(echo $f | tr ':' '_')
  env HL_R13_LOADER_FIXTURES=$F $C $f -- --test-threads=8 > $R/accept_${TAG}_$n.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $R/accept_${TAG}_$n.log >> $P
  grep -E "^test .*(FAILED|failed)" $R/accept_${TAG}_$n.log | head -20 >> $P
done
env L9_OUT=$S $C lean_l9_export_the_w16r2_rung_block -- --test-threads 1 > $R/accept_${TAG}_l9export.log 2>&1; say "hashline lean_l9_export rc=$?"
cmp $S/corpus.txt $WT/results/zk60_lean_l9_20261107/corpus.txt; say "L9 corpus byte-identical: cmp rc=$?"
env LEAN_L11_CORPUS=$S/l11_corpus.txt $C lean_l11_export > $R/accept_${TAG}_l11export.log 2>&1; say "hashline lean_l11_export rc=$?"
cmp $S/l11_corpus.txt $WT/results/zk60_lean_l11_20261107/corpus.txt; say "L11 corpus byte-identical: cmp rc=$?"
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $Z > $R/accept_${TAG}_zkpcore.log 2>&1; say "zkp-core suite rc=$?"
grep -E "^test result|a26" $R/accept_${TAG}_zkpcore.log >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked -j 2 --manifest-path $H > $R/accept_${TAG}_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
if [ "${FULL:-0}" = "1" ]; then
  env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $R/accept_${TAG}_full.log 2>&1; say "full lib suite rc=$? (A25 c1: 972 passed, 3 known failures)"
  grep -E "^test result" $R/accept_${TAG}_full.log >> $P
  sed -n '/^failures:$/,/^test result/p' $R/accept_${TAG}_full.log | grep -E "^    [a-z_:0-9]+$" >> $P
fi
rm -rf $S
say "all done"
