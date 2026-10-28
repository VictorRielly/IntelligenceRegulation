#!/bin/bash
# D24 review round 10 (native R12, tree 1e406781): queue A. My CLI from the
# PRISTINE copy, then read-only re-verification of the retained R8 / R9
# stack receipts under it, and a --dd probe at a geometry without DD. Every
# heavy leaf: pre-check until "OK to start now", then the guard.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r12
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r12/hashline
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r12-scratch
S9=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r9-scratch
S8=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r8-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r12.release.bin
N=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
Q=$R/queue_a.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
pre() {  # class need
  until out=$(python3 $G check --class $1 --need-gib $2 2>&1); echo "$out" | grep -q "OK to start now"; do sleep 30; done
}
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  pre $cl $need
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
log "queue A start"
guard build 2.5 5 3600 r12-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block
[ "$(cat $R/r12-cli-build.done)" = 0 ] || { echo fail > $R/r12_queue_a.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $N/r12/zk60_trained_block.release.bin > $R/binaries.sha256
# retained receipts under my R12 CLI (statement/ exists in each: byte check only)
guard cpu 2 5 1800 r12-compat-tl-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-tl-T128 --artifact $N/r9/stack-tinyllama_dg_rot1_T128-ho00-cpu-dd/run --expect-statement d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b --dd
guard cpu 3 6 2400 r12-compat-8b-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-8b-T128 --artifact $N/r9/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu-dd/run --expect-statement 4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520 --dd
guard cpu 2 5 1800 r12-compat-tl /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-tl-T128 --artifact $N/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/run --expect-statement caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165
guard cpu 3 6 2400 r12-compat-8b /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-8b-T128 --artifact $N/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/run --expect-statement 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4
guard cpu 2 5 1800 r12-compat-tl-t32 /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S8/verifier-tl-T32 --artifact $N/r6/compat-pg_rot1_b4_T32_cal128/run --expect-statement $(grep -o '"trained_statement_identity": "[0-9a-f]*"' $N/r6/compat-pg_rot1_b4_T32_cal128/run/statement/statement.json | cut -d'"' -f4)
# --dd at a geometry with no DD profile (8B T32): refused by name, no dir
rm -rf $S/review_out/dd-probe
$X stack-prove --export $S8/verifier-8b-T32 --seq ho00 --out $S/review_out/dd-probe --dd > $R/r12-dd-probe.log 2>&1
echo "exit $? dir $([ -e $S/review_out/dd-probe ] && echo yes || echo no)" >> $R/r12-dd-probe.log
log "dd probe: $(tail -1 $R/r12-dd-probe.log)"
log "queue A end"
echo done > $R/r12_queue_a.done
