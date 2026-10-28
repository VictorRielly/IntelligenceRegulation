#!/bin/bash
# D24 review ROUND 9, queue C (after B): the native r9_tests again WITH
# --nocapture (which relation rejects each mutation, and the lapse pass), and
# the single-block DD artifact verified under the NON-DD relation with the
# non-DD identity pinned (receipt-level cross-relation control). Guarded.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r9
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9-scratch
X=$R/zk60_trained_block.review-r9.release.bin
Q=$R/queue_c.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
until [ -f $R/r9_queue_b.done ]; do sleep 15; done
log "queue C start"
BIN=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r9-test-build.log | tail -1)
guard cpu 2 4 1200 r9-author-r9tests-nocapture /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/author RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=1 --nocapture r9_tests
guard cpu 2 5 1200 r9-xr-sb-as-plain /usr/bin/env RAYON_NUM_THREADS=16 $X verify --export $S/verifier-tl-T128 --layer 0 --artifact $S/review_out/sb-tl-dd --expect-statement 6b280d0693536488dab420d163d0eaf5343e00f8e385b11068c5992977a032f6
log "queue C end"
echo done > $R/r9_queue_c.done
