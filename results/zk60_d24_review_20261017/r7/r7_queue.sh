#!/bin/bash
# D24 review ROUND 7 (of the native R7 tree): serial queue, every leaf guarded.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r7
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r7/hashline
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r7-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r7.release.bin
XA=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r7/zk60_trained_block.release.bin
K=$S/review_out
ID=$(cat $K/identity.hex)
V8B7=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r6-scratch/verifier-8b-b7-T128
RUN8B7=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/run
ID8B7=97c4acda9da994c11790c2c8ec93b44beecb21501686b7e25965d2c18f970566
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 14400 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
log "queue start"
guard build 2.5 5 3600 r7-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block
[ "$(cat $R/r7-cli-build.done)" = 0 ] || { echo fail > $R/r7_queue.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $XA > $R/binaries.sha256
# R6 CPU statements under R7 (read only: statement/ exists, only checked)
guard light 0.5 1.5 300 r7-r6-rung-statement /usr/bin/env RAYON_NUM_THREADS=4 $X stack-verify --export $K/rev-stack2-v --artifact $K/run-r6-live --expect-statement $ID
guard light 0.5 1.5 300 r7-stale-dead-forged /usr/bin/env RAYON_NUM_THREADS=4 $X stack-verify --export $K/rev-stack2-v --artifact $K/run-r6 --expect-statement $ID
log "after r7-stale-dead-forged: run-r6 entries: $(ls $K/run-r6 | tr '\n' ' ')"
log "run-r6-live entries: $(ls $K/run-r6-live | tr '\n' ' ')"
guard cpu 3 5 1800 r7-8b-b7-under-r7 /usr/bin/env RAYON_NUM_THREADS=16 /usr/bin/time -v $X stack-verify --export $V8B7 --artifact $RUN8B7 --expect-statement $ID8B7
guard build 3 6 3600 r7-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib --no-run
[ "$(cat $R/r7-test-build.done)" = 0 ] || { echo testbuild-fail > $R/r7_queue.done; exit 1; }
BIN=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r7-test-build.log | tail -1)
log "lib test binary: $BIN"
guard cpu 2 4 1800 r7-fast /usr/bin/env ZK60_REVIEW_TMP=$S/review_tmp RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=1 --nocapture review_r7
guard cpu 4 6 2400 r7-author-subset /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/author RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=4 trained_stack_tests trained_block_tests r6_tests cs_port_tests s24_tests s25_tests review_r4_b review_r3_6 --skip review_r7
log "queue end"
echo done > $R/r7_queue.done
