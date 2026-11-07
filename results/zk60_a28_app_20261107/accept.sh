#!/bin/bash
# Lane A28 (from A27) native acceptance (one guarded gpu-class job). The release CLI (its SHA-256 is the app's pin); the
# test build; hashline's A27 unit tests, A26's and A4's, A24's serve tests (seal-ahead on by default), the census tests (s25, hash_domain, r19b), every
# token_io::classify test; the L9 and L11 test-only exports (corpora compared byte for byte); zkp-core; the
# no-feature `cargo check --tests`; then the DEVICE byte gates the kernel changes must keep (A23's merge list
# for the 8B stack): CPU = Metal at every development accuracy shape, the six trained profiles' recorded
# digests (R13 / W16 / W16R2, Shieldstral and 8B), the W16R2 rung golden and its every-setting variants, the
# 8B block, the R13 export through stack-serve = stack-prove (A22/A23), the device-table word test, the
# queue and pool byte tests; the Metal commitment tests against the CPU; and the full lib suite (FULL=1).
# usage: accept.sh <tag>
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
Z=$WT/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
R=$WT/results/zk60_a28_app_20261107
TAG=${1:-t1}
P=$R/accept_$TAG.progress
F=$WT/results/zk60_1b_native_20261017/r13/loader-fixtures
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/a28_$TAG
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
K=private_block::run::fork::tests
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
dev() { # name, log, filter, extra env...
  local name=$1 log=$2 filt=$3; shift 3
  env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 "$@" $C $filt -- --ignored --exact --nocapture --test-threads=1 > $R/accept_${TAG}_$log.log 2>&1
  say "$name rc=$?"
  grep -E "test result|panicked" $R/accept_${TAG}_$log.log | cut -c1-300 >> $P
}
say start
rm -rf $S; mkdir -p $S
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify > $R/accept_${TAG}_cli.log 2>&1; rc=$?; say "release CLI rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/accept_${TAG}_cli.log | head -120 >> $P; say "all done (build failed)"; exit 1; fi
say "zk60_classify sha256 $(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1)"
say "CLI warnings: $(grep -c '^warning' $R/accept_${TAG}_cli.log) (A26's build: 103 lines)"
$C --no-run > $R/accept_${TAG}_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/accept_${TAG}_build.log | head -120 >> $P; say "all done (test build failed)"; exit 1; fi
for f in a27_ a26_ a24_ a4_ s25_tests hash_domain r19b token_io::classify; do
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
grep -E "^test result" $R/accept_${TAG}_zkpcore.log >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked -j 2 --manifest-path $H > $R/accept_${TAG}_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
# --- device byte gates
dev "a28 classifier commitment shapes CPU = Metal" a28commit $T::a28_the_classifier_commitment_shapes_on_metal_equal_the_cpu
dev "M4 development shapes CPU = Metal" m4dev $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
dev "trained digests, six profiles" trained $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times HL_PB_ORACLE=0 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "digest cpu $d" $R/accept_${TAG}_trained.log && grep -q "metal $d" $R/accept_${TAG}_trained.log; then say "recorded digest $d: CPU and Metal"; else say "RECORDED DIGEST $d MISSING"; fi
done
dev "w16r2 rung golden (CPU and Metal)" r2rung private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
grep -E "W16R2-RUNG-DIGEST" $R/accept_${TAG}_r2rung.log | cut -c1-220 >> $P
dev "a18 rung golden under every setting" a18rung private_block::w16r2_tests::a18_w16r2_rung_golden_under_every_a18_setting
dev "a18 8B block under every setting" a18_8b private_block::w16r2_tests::a18_the_8b_block_proves_the_same_under_every_a18_setting HL_PB_ORACLE=0
if grep -q "90003b760eb7ad80" $R/accept_${TAG}_a18_8b.log; then say "8B core proof 90003b760eb7ad80 present (a18 8B block)"; else say "8B CORE PROOF 90003b760eb7ad80 MISSING"; fi
dev "a17 rung golden under every setting" a17rung private_block::w16r2_tests::a17_w16r2_rung_golden_under_every_a17_setting
dev "a12 rung golden in every table mode" rung_modes private_block::w16r2_tests::a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device
dev "a11 per-fork pools on the device" pools_metal private_block::w16r2_tests::a11_w16r2_rung_digests_in_per_fork_pools_on_the_device
dev "a7 one and six queues" queues private_block::w16r2_tests::a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues
env HL_GPU_REQUIRED=1 $C private_block::range16_tests::a12_census_and_the_device_tables_equal_the_host_tables_word_for_word -- --ignored --exact --nocapture --test-threads=1 > $R/accept_${TAG}_a12census.log 2>&1; say "a12 device tables word for word rc=$?"
grep -E "test result|panicked" $R/accept_${TAG}_a12census.log | cut -c1-300 >> $P
dev "a22 the R13 export through the server = stack-prove (device)" a22srv $K::a22::a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal_on_the_device
dev "a23 the server with shared blocks = stack-prove (device)" a23srv $K::a23::a23_the_server_with_shared_blocks_proves_the_r13_export_as_stack_prove_does_on_the_device
dev "a23 resident 8B stream (blocks shared)" a23_8b $K::a23::a23_the_resident_8b_stream_with_shared_blocks_replays HL_PB_ORACLE=0
for t in zk60_metal_commit zk60_tagged_gpu_commit; do
  /opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --test $t -- --test-threads=1 > $R/accept_${TAG}_$t.log 2>&1; say "integration test $t rc=$?"
  grep -E "^test result" $R/accept_${TAG}_$t.log >> $P
done
if [ "${FULL:-0}" = "1" ]; then
  env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $R/accept_${TAG}_full.log 2>&1; say "full lib suite rc=$? (A27: 981 passed, the 3 known A23 failures)"
  grep -E "^test result" $R/accept_${TAG}_full.log >> $P
  sed -n '/^failures:$/,/^test result/p' $R/accept_${TAG}_full.log | grep -E "^    [a-z_:0-9]+$" >> $P
fi
rm -rf $S
say "all done"
