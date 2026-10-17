#!/bin/bash
# D24 review ROUND 4: the byte counters are diagnostics. The review CLI (built
# from the pristine frozen copy) proves the 2-layer rung stack WITH and
# WITHOUT HL_PB_TIMING=1; each receipt is verified in a FRESH process under
# the OTHER setting; segment lengths are compared with the round-3 receipt.
# Each leaf guarded (light: a few seconds of CPU at the rung).
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r4
X=$R/zk60_trained_block.review-r4.release.bin
K=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r4-scratch/review_out/stack2
ID=$(cat $K/identity.hex)
Q=$R/prove_checks.out
guard() { local need=$1 cap=$2 maxs=$3 label=$4; shift 4
  python3 $G run --class light --need-gib $need --cap-gib $cap --label $label --wait-secs 14400 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  echo "[$(date -u +%H:%M:%SZ)] $label exit $?" >> $Q; }
rm -rf $K/run-r5-timing $K/run-r5-plain
guard 1 2 300 r4-prove-timing /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=4 $X stack-prove --export $K/rev-stack2 --seq s0 --out $K/run-r5-timing
guard 1 2 300 r4-prove-plain /usr/bin/env RAYON_NUM_THREADS=4 $X stack-prove --export $K/rev-stack2 --seq s0 --out $K/run-r5-plain
guard 0.5 1.5 300 r4-verify-timing-receipt-plain /usr/bin/env RAYON_NUM_THREADS=4 $X stack-verify --export $K/rev-stack2 --expect-statement $ID --artifact $K/run-r5-timing --controls
guard 0.5 1.5 300 r4-verify-plain-receipt-timing /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=4 $X stack-verify --export $K/rev-stack2 --expect-statement $ID --artifact $K/run-r5-plain
ls -l $K/run/segment-*.bin $K/run-r5-timing/segment-*.bin $K/run-r5-plain/segment-*.bin >> $Q 2>&1
echo done > $R/r4_prove_checks.done
