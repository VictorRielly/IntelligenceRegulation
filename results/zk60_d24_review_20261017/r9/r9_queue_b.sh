#!/bin/bash
# D24 review ROUND 9, queue B (after A2): the scratch test build (my review
# module review_r9_tests.rs registered), my tests, the author's targeted
# subset on my binary, the seeded goldens on R9 (scratch) and on my own copy
# of the R8 freeze (record mode). Every leaf guarded; serial.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r9
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9-scratch
C=/home/victor/.cargo/bin/cargo
Q=$R/queue_b.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
until [ -f $R/r9_queue_a2.done ]; do sleep 15; done
log "queue B start"
guard build 3 6 3600 r9-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib --no-run
[ "$(cat $R/r9-test-build.done)" = 0 ] || { echo testbuild-fail > $R/r9_queue_b.done; exit 1; }
BIN=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r9-test-build.log | tail -1)
log "lib test binary: $BIN"
mkdir -p $S/review_tmp/review $S/review_tmp/author
guard cpu 3 6 2400 r9-review /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/review ZK60_REVIEW_TL_EXPORT=$S/verifier-tl-T128 ZK60_REVIEW_8B_EXPORT=$S/verifier-8b-T128 RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=1 --nocapture review_r9
guard cpu 4 7 3600 r9-author-subset /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/author RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=4 r9_tests trained_stack_tests trained_block_tests r6_tests r8_tests s24_tests s25_tests s33_tests pad::tests trained_statement review_e_ cs_port_tests --skip review_r9
guard cpu 7.5 10.5 2400 r9-golden-r9 /usr/bin/env RAYON_NUM_THREADS=16 $S/hashline/$BIN --ignored --test-threads=1 --nocapture r9_golden
guard build 3 6 3600 r8-golden-build $C test --release --offline --locked -j2 --manifest-path $S/r8-golden/hashline/Cargo.toml --lib --no-run
if [ "$(cat $R/r8-golden-build.done)" = 0 ]; then
  BIN8=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r8-golden-build.log | tail -1)
  log "R8 golden test binary: $BIN8"
  guard cpu 7.5 10.5 2400 r8-golden-run /usr/bin/env RAYON_NUM_THREADS=16 $S/r8-golden/hashline/$BIN8 --ignored --test-threads=1 --nocapture r9_golden
fi
log "queue B end"
echo done > $R/r9_queue_b.done
