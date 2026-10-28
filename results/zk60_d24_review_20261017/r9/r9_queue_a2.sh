#!/bin/bash
# D24 review ROUND 9, queue A2 (after queue A): the corrected --dd probes (a
# well-formed pin), and the cross-RELATION controls: each receipt verified
# under the OTHER relation with the identity that relation rebuilds, so the
# pin check passes and the receipt itself must be refused. Read only (each
# run dir holds statement/; the receipt check comes before any statement
# check). Every leaf guarded.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r9
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9-scratch
X=$R/zk60_trained_block.review-r9.release.bin
N=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
Q=$R/queue_a2.out
VTL=$S/verifier-tl-T128
V8B=$S/verifier-8b-T128
DDTL=$N/r9/stack-tinyllama_dg_rot1_T128-ho00-cpu-dd/run
DD8B=$N/r9/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu-dd/run
R8TL=$N/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/run
R88B=$N/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/run
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
until [ -f $R/r9_queue_a.done ]; do sleep 15; done
log "queue A2 start"
guard cpu 2 4 1800 r9-dd-probes2 /bin/bash $R/r9_dd_probes.sh $X
# the DD receipt under the NON-DD relation, pinned to the non-DD identity
guard cpu 2 5 1800 r9-xr-ddtl-as-plain /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $DDTL --expect-statement caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165
guard cpu 3 6 2400 r9-xr-dd8b-as-plain /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $V8B --artifact $DD8B --expect-statement 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4
# the R8 (non-DD) receipt under the DD relation, pinned to the DD identity
guard cpu 2 5 1800 r9-xr-r8tl-as-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $R8TL --expect-statement d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b --dd
guard cpu 3 6 2400 r9-xr-r88b-as-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $V8B --artifact $R88B --expect-statement 4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520 --dd
log "queue A2 end"
echo done > $R/r9_queue_a2.done
