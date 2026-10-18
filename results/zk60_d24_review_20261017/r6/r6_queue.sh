#!/bin/bash
# D24 review ROUND 6 (of the native R6 tree): serial queue, every leaf guarded.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r6
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r6/hashline
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r6-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r6.release.bin
XA=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r6/zk60_trained_block.release.bin
K=$S/review_out
ID=$(cat $K/identity.hex)
ZERO=0000000000000000000000000000000000000000000000000000000000000000
V8B6=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r5-scratch/verifier-8b-T128
RUN8B6=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu/run
ID8B6=6aba46fbd12d14b053a0ec4afb29ba7b7dbad5ef4fe327213474a737b6e3fe24
V8B7=$S/verifier-8b-b7-T128
RUN8B7=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/run
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 14400 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  local rc=$?; log "$label exit $rc"; return $rc; }
log "queue start"
guard build 2.5 5 3600 r6-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block || { echo fail > $R/r6_queue.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $XA > $R/binaries.sha256
log "cli copied: $(sha256sum $X | cut -c1-16)"
# (a) a run-wide export keeps its identity under R6: prove, verify (publish), re-check
rm -rf $K/run-r6 $K/run-r6.unverified-statement
guard light 1 2 300 r6-runwide-prove /usr/bin/env RAYON_NUM_THREADS=4 $X stack-prove --export $K/rev-stack2 --seq s0 --out $K/run-r6
log "run-wide identity printed: $(grep -o '"statement_identity":"[0-9a-f]*"' $R/r6-runwide-prove.log | head -1) (round 3: $ID)"
guard light 0.5 1.5 300 r6-runwide-verify /usr/bin/env RAYON_NUM_THREADS=4 $X stack-verify --export $K/rev-stack2-v --artifact $K/run-r6 --expect-statement $ID --controls
guard light 0.5 1.5 300 r6-runwide-recheck /usr/bin/env RAYON_NUM_THREADS=4 $X stack-verify --export $K/rev-stack2-v --artifact $K/run-r6 --expect-statement $ID
# (b) the R5b-proved 8B b6 T128 run (run-wide) under the R6 verifier, read only
guard cpu 2.5 4 1200 r6-8b-b6-under-r6 /usr/bin/env RAYON_NUM_THREADS=16 /usr/bin/time -v $X stack-verify --export $V8B6 --artifact $RUN8B6 --expect-statement $ID8B6
# (c) the b7 export's per-layer statement, rebuilt by my CLI (wrong pin: prints the identity)
guard cpu 3 5 600 r6-8b-b7-identity /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $V8B7 --artifact $RUN8B7 --expect-statement $ZERO
# (d) the native lane's b7 stack, only once it carries its own published statement (read only)
if [ -d $RUN8B7/statement ] && [ ! -e $RUN8B7.unverified-statement ]; then
  ID8B7=$(grep -o '"statement_identity":"[0-9a-f]*"' $R/r6-8b-b7-identity.log | head -1 | cut -d'"' -f4)
  [ -z "$ID8B7" ] && ID8B7=$(grep -o 'rebuilt trained statement [0-9a-f]*' $R/r6-8b-b7-identity.log | head -1 | awk '{print $4}')
  guard cpu 2.5 4 1800 r6-8b-b7-verify /usr/bin/env RAYON_NUM_THREADS=16 /usr/bin/time -v $X stack-verify --export $V8B7 --artifact $RUN8B7 --expect-statement $ID8B7 --controls
else
  log "b7 stack not landed (no published statement at $RUN8B7); not verified here"
fi
# tests
guard build 3 6 3600 r6-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib --no-run || { log "test build failed"; echo testbuild-fail > $R/r6_queue.done; exit 1; }
BIN=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r6-test-build.log | tail -1)
log "lib test binary: $BIN"
guard cpu 2 4 1800 r6-fast /usr/bin/env ZK60_REVIEW_TMP=$S/review_tmp RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=1 --nocapture review_r6
guard cpu 4 6 2400 r6-author-subset /usr/bin/env RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=4 r6_tests trained_stack_tests trained_block_tests trained_statement cs_port_tests ladder8b_tests s24_tests s25_tests review_d24_tests r4_tests review_r4_b review_r3_6 trained_calib_tests --skip review_r6
log "queue end"
echo done > $R/r6_queue.done
