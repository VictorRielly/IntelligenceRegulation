#!/bin/bash
# D24 review ROUND 9 (native R9 tree af90c703: DD, D30), queue A: my CLI from
# the PRISTINE copy, then read-only verifies and refusal probes. Every heavy
# leaf guarded; serial; the DD and R8 run dirs already hold statement/ (the
# verifier only byte-checks it and writes nothing).
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r9
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9/hashline
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9-scratch
S8=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r9.release.bin
N=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
XA=$N/r9/zk60_trained_block.release.bin
FX=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
K=$S/review_out
Q=$R/queue_a.out
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
log "queue A start"
guard build 2.5 5 3600 r9-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block
[ "$(cat $R/r9-cli-build.done)" = 0 ] || { echo fail > $R/r9_queue_a.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $XA > $R/binaries.sha256
# (1) the two DD receipts, fresh, with every run-level control, under --dd
guard cpu 2 5 1800 r9-dd-tl /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $DDTL --expect-statement d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b --controls --dd
guard cpu 3 6 2400 r9-dd-8b /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $V8B --artifact $DD8B --expect-statement 4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520 --controls --dd
# (2) the R8 receipts under my R9 CLI, no --dd (statement byte-checked)
guard cpu 2 5 1800 r9-compat-tl /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $R8TL --expect-statement caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165
guard cpu 3 6 2400 r9-compat-8b /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $V8B --artifact $R88B --expect-statement 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4
# (3) cross-profile controls (each must REFUSE, exit 1): a DD receipt without
# --dd, an R8 receipt with --dd; with and without the pinned identity
guard cpu 2 5 1800 r9-x-ddtl-noflag /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $DDTL
guard cpu 2 5 1800 r9-x-ddtl-noflag-pin /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $DDTL --expect-statement d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b
guard cpu 2 5 1800 r9-x-r8tl-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $R8TL --dd
guard cpu 2 5 1800 r9-x-r8tl-dd-pin /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $VTL --artifact $R8TL --expect-statement caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165 --dd
guard cpu 3 6 2400 r9-x-dd8b-noflag /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $V8B --artifact $DD8B
# (4) --dd at geometries with no DD profile: all four commands, refused by
# name, no output dir (the refusal comes right after the export load)
guard cpu 2 4 1800 r9-dd-probes /bin/bash $R/r9_dd_probes.sh $X
# (5) one single-block DD prove (TinyLlama T128 layer 0, my scratch) with the
# inconsistent-witness controls, a fresh verify --dd --controls, and the same
# artifact verified WITHOUT --dd (must refuse)
rm -rf $K/sb-tl-dd
guard cpu 6 9 2400 r9-sb-dd-prove /usr/bin/env RAYON_NUM_THREADS=16 $X prove --export $FX/tinyllama_dg_rot1_T128 --layer 0 --seq ho00 --out $K/sb-tl-dd --controls --dd
if [ "$(cat $R/r9-sb-dd-prove.done)" = 0 ]; then
  ID=$(grep -o '"statement_identity":"[0-9a-f]*"' $R/r9-sb-dd-prove.log | head -1 | cut -d'"' -f4)
  log "single-block DD identity $ID"
  guard cpu 2 5 1200 r9-sb-dd-verify /usr/bin/env RAYON_NUM_THREADS=16 $X verify --export $VTL --layer 0 --artifact $K/sb-tl-dd --expect-statement $ID --controls --dd
  guard cpu 2 5 1200 r9-sb-x-noflag /usr/bin/env RAYON_NUM_THREADS=16 $X verify --export $VTL --layer 0 --artifact $K/sb-tl-dd --expect-statement $ID
fi
log "queue A end"
echo done > $R/r9_queue_a.done
