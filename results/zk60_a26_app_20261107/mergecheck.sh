#!/bin/bash
# Lane A26, the check on the branch after merging perf (the Lean lanes L13-L17), one guarded cpu job: the release
# CLI (its SHA-256 against the app's pin), the census and classify tests, A26's and A4's tests, the L9 / L11
# exports and the L17 R13 export (a seeded R13 rung block proved by prove_core and verified by verify_core, and a
# real one-stage R13 D12a run) regenerated and compared with their committed corpora and sha256, zkp-core.
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
R=$WT/results/zk60_a26_app_20261107
P=$R/mergecheck.progress
F=$WT/results/zk60_1b_native_20261017/r13/loader-fixtures
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/a26_mergecheck
L17=$WT/results/zk60_lean_l17_20261107
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S/l17
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify > $R/mergecheck_cli.log 2>&1; say "release CLI rc=$?"
say "zk60_classify sha256 $(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1) (the app's pin: b6336628364ae4407a2640d52b84ddf3c9688420fc827082ccb1c1aaf37d366d)"
$C --no-run > $R/mergecheck_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/mergecheck_build.log | head -80 >> $P; say "all done (test build failed)"; exit 1; fi
for f in a26_ a4_ s25_tests hash_domain r19b token_io::classify; do
  n=$(echo $f | tr ':' '_')
  env HL_R13_LOADER_FIXTURES=$F $C $f -- --test-threads=8 > $R/mergecheck_$n.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $R/mergecheck_$n.log | head -1 >> $P
  grep -E "^test .*(FAILED|failed)" $R/mergecheck_$n.log | head -20 >> $P
done
env L9_OUT=$S $C lean_l9_export_the_w16r2_rung_block -- --test-threads 1 > $R/mergecheck_l9export.log 2>&1; say "lean_l9_export rc=$?"
cmp $S/corpus.txt $WT/results/zk60_lean_l9_20261107/corpus.txt; say "L9 corpus byte-identical: cmp rc=$?"
env LEAN_L11_CORPUS=$S/l11_corpus.txt $C lean_l11_export > $R/mergecheck_l11export.log 2>&1; say "lean_l11_export rc=$?"
cmp $S/l11_corpus.txt $WT/results/zk60_lean_l11_20261107/corpus.txt; say "L11 corpus byte-identical: cmp rc=$?"
env L17_OUT=$S/l17 HL_R13_LOADER_FIXTURES=$F $C lean_l17_export -- --nocapture --test-threads 1 > $R/mergecheck_l17export.log 2>&1; say "lean_l17_export rc=$?"
for f in block_corpus.txt slots_corpus.txt segment_corpus.txt shape_corpus.txt; do
  cmp $S/l17/$f $L17/$f; say "L17 $f byte-identical: cmp rc=$?"
done
( cd $S/l17 && shasum -a 256 -c $L17/large_files.sha256 ) >> $P 2>&1; say "L17 large files against their committed sha256: rc=$?"
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $Z > $R/mergecheck_zkpcore.log 2>&1; say "zkp-core suite rc=$?"
grep -E "^test result" $R/mergecheck_zkpcore.log | head -1 >> $P
rm -rf $S
say "all done"
