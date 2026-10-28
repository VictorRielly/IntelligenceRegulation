#!/bin/bash
# D24 review ROUND 8 (of the native R8 tree): serial queue, every leaf guarded.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r8
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8/hashline
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r8.release.bin
XA=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r8/zk60_trained_block.release.bin
N=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
K=$S/review_out
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 14400 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
log "queue start"
guard build 2.5 5 3600 r8-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block
[ "$(cat $R/r8-cli-build.done)" = 0 ] || { echo fail > $R/r8_queue.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $XA > $R/binaries.sha256
# compatibility, read only (each run's statement/ exists: only checked)
guard light 0.5 1.5 300 r8-compat-rung /usr/bin/env RAYON_NUM_THREADS=4 $X stack-verify --export $K/rev-stack2-v --artifact $K/run-r6 --expect-statement $(cat $K/identity.hex)
guard cpu 3 5 1800 r8-compat-b7-T128 /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r6-scratch/verifier-8b-b7-T128 --artifact $N/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu/run --expect-statement 97c4acda9da994c11790c2c8ec93b44beecb21501686b7e25965d2c18f970566
guard cpu 3 5 1800 r8-compat-8b-T32 /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S/verifier-8b-T32 --artifact $N/r6/compat-llama3_8b_pg_rot1_T32/run --expect-statement 259dad7cb2c9739e44cfdf5c27c4c87090458cf330e9d39b592221094ae3537f
guard cpu 1.5 3 1800 r8-compat-tl-T32 /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S/verifier-tl-T32 --artifact $N/r6/compat-pg_rot1_b4_T32_cal128/run --expect-statement $(grep -o '"trained_statement_identity": "[0-9a-f]*"' $N/r6/compat-pg_rot1_b4_T32_cal128/run/statement/statement.json | cut -d'"' -f4)
guard build 3 6 3600 r8-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib --no-run
[ "$(cat $R/r8-test-build.done)" = 0 ] || { echo testbuild-fail > $R/r8_queue.done; exit 1; }
BIN=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r8-test-build.log | tail -1)
log "lib test binary: $BIN"
guard cpu 2 4 1800 r8-fast /usr/bin/env ZK60_REVIEW_TMP=$S/review_tmp RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=1 --nocapture review_r8
guard cpu 4 6 2400 r8-author-subset /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/author RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=4 r8_tests r6_tests trained_stack_tests trained_block_tests trained_statement cs_port_tests s24_tests s25_tests ladder8b_tests --skip review_r8
log "queue end"
echo done > $R/r8_queue.done
