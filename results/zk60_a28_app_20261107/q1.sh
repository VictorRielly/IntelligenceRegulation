#!/bin/bash
# Lane A28, job q1 (one guarded gpu-class job): the first candidate's quick gates, then its byte identity and a
# first stream pair. (1) The release CLI kept as zk60_classify.a28-<tag>; (2) the test build; the A28 commitment
# test at the classifier's shapes (CPU = Metal), the Metal commitment integration tests, the A24 serve tests
# (seal-ahead on by default), the census tests, the six trained digests on CPU and Metal; (3) the byte identity
# on the real export (bi.sh: A27's pin, the candidate, the candidate with every A28 switch off, A27 again);
# (4) a stream plan if one is given.
# usage: q1.sh <tag> [plan]
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
R=$WT/results/zk60_a28_app_20261107
BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin
F=$WT/results/zk60_1b_native_20261017/r13/loader-fixtures
TAG=$1; PLAN=${2:-}
P=$R/$TAG.progress
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start at $(git -C $WT rev-parse --short HEAD 2>/dev/null) + the working tree; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --example zk60_classify > $R/${TAG}_cli.log 2>&1; rc=$?; say "release CLI rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/${TAG}_cli.log | head -120 >> $P; say "all done (build failed)"; exit 1; fi
cp $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify $BIN/zk60_classify.a28-$TAG
say "candidate a28-$TAG sha256 $(shasum -a 256 $BIN/zk60_classify.a28-$TAG | cut -d' ' -f1)"
$C --no-run > $R/${TAG}_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/${TAG}_build.log | head -120 >> $P; say "all done (test build failed)"; exit 1; fi
env HL_GPU_REQUIRED=1 $C $T::a28_the_classifier_commitment_shapes_on_metal_equal_the_cpu -- --ignored --exact --nocapture --test-threads=1 > $R/${TAG}_a28commit.log 2>&1; say "a28 classifier commitment shapes CPU = Metal rc=$?"
grep -E "test result|panicked" $R/${TAG}_a28commit.log | cut -c1-300 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --test zk60_metal_commit -- --test-threads=1 > $R/${TAG}_commit.log 2>&1; say "zk60_metal_commit rc=$?"
grep -E "^test result" $R/${TAG}_commit.log >> $P
for f in a24_ s25_tests hash_domain token_io::classify_serve; do
  n=$(echo $f | tr ':' '_')
  env HL_R13_LOADER_FIXTURES=$F $C $f -- --test-threads=8 > $R/${TAG}_$n.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $R/${TAG}_$n.log >> $P
  grep -E "^test .*(FAILED|failed)" $R/${TAG}_$n.log | head -20 >> $P
done
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 \
  $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $R/${TAG}_trained.log 2>&1; say "trained digests rc=$?"
for d in 5a6193d3 f590b01f 79f987ef a8258241 0e88d84f 90003b76; do
  if grep -q "digest cpu $d" $R/${TAG}_trained.log && grep -q "metal $d" $R/${TAG}_trained.log; then say "recorded digest $d: CPU and Metal"; else say "RECORDED DIGEST $d MISSING"; fi
done
if grep -qE "rc=[1-9]|MISSING" $P; then say "STOP: a gate failed"; exit 2; fi
free=$(df -g /Users/victorrielly | tail -1 | awk '{print $4}')
if [ "$free" -lt 40 ]; then say "STOP: free disk $free GiB under 40"; exit 3; fi
/bin/bash $R/bi.sh bi_$TAG $BIN/zk60_classify.a28-$TAG
say "byte identity done: $(tail -2 $R/bi_$TAG.progress | head -1 | cut -c1-700)"
if [ -n "$PLAN" ]; then
  /bin/bash $R/runs.sh ${TAG}s $PLAN
  say "stream plan done"
fi
rm -rf /Users/victorrielly/zk60-owner-private/a28-media-app-20261107/stream-* /Users/victorrielly/zk60-artifacts/a28-media-app-20261107/stream-*
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
