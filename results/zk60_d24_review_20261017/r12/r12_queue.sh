#!/bin/bash
# D24 review round 10 (native R12, tree 1e406781): the whole queue, serial,
# launched only after the coordinator's "S3 window closed". Every heavy leaf:
# pre-check until "OK to start now", then the guard. Read only on every
# other lane's tree (retained run dirs hold statement/: byte check only; the
# dense test runs WITHOUT ZK60_R12_EVIDENCE_DIR so it writes nothing there).
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
EV=/home/victor/IntelligenceRegulation/results/zk60_sol_20261026/dense-receipts
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
pre() {  # class need
  until out=$(python3 $G check --class $1 --need-gib $2 2>&1); echo "$out" | grep -q "OK to start now"; do sleep 30; done
}
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  pre $cl $need
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
log "queue start"
# ---- my CLI from the pristine copy
guard build 2.5 5 3600 r12-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block
[ "$(cat $R/r12-cli-build.done)" = 0 ] || { echo fail > $R/r12_queue.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $N/r12/zk60_trained_block.release.bin > $R/binaries.sha256
# ---- retained receipts under my R12 CLI (statement/ exists: byte check only)
guard cpu 2 5 1800 r12-compat-tl-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-tl-T128 --artifact $N/r9/stack-tinyllama_dg_rot1_T128-ho00-cpu-dd/run --expect-statement d57212761b29a8eab43d03af012a3b5bec7154455786275f4000502893d22e4b --dd
guard cpu 3 6 2400 r12-compat-8b-dd /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-8b-T128 --artifact $N/r9/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu-dd/run --expect-statement 4da580bdda8b9e4aef4ceb281e2b31e8008d99425d2601553b38f753b1492520 --dd
guard cpu 2 5 1800 r12-compat-tl /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-tl-T128 --artifact $N/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu/run --expect-statement caf6ced22fbb87a94c1f571a96faf278815668996863146805c9d2eea76c9165
guard cpu 3 6 2400 r12-compat-8b /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S9/verifier-8b-T128 --artifact $N/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu/run --expect-statement 5585f5eed7a24a559ce76ddbd0413ddffd877637efb07d29bbd9408b4fc5a3b4
guard cpu 2 5 1800 r12-compat-tl-t32 /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $S8/verifier-tl-T32 --artifact $N/r6/compat-pg_rot1_b4_T32_cal128/run --expect-statement $(grep -o '"trained_statement_identity": "[0-9a-f]*"' $N/r6/compat-pg_rot1_b4_T32_cal128/run/statement/statement.json | cut -d'"' -f4)
rm -rf $S/review_out/dd-probe
$X stack-prove --export $S8/verifier-8b-T32 --seq ho00 --out $S/review_out/dd-probe --dd > $R/r12-dd-probe.log 2>&1
echo "exit $? dir $([ -e $S/review_out/dd-probe ] && echo yes || echo no)" >> $R/r12-dd-probe.log
log "dd probe: $(tail -1 $R/r12-dd-probe.log)"
# ---- the scratch test build (my review module registered) and the tests
guard build 3 6 3600 r12-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib --no-run
[ "$(cat $R/r12-test-build.done)" = 0 ] || { echo testbuild-fail > $R/r12_queue.done; exit 1; }
BIN=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r12-test-build.log | tail -1)
log "lib test binary: $BIN"
mkdir -p $S/review_tmp/review $S/review_tmp/author
guard cpu 3 6 2400 r12-review /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/review RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=1 --nocapture review_r12
guard cpu 4 7 3600 r12-author-subset /usr/bin/env ZK60_NATIVE_TINY_EXPORT_DIR=$S/review_tmp/author RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=4 r12_tests r9_tests trained_stack_tests trained_block_tests r6_tests r8_tests s24_tests s25_tests s33_tests pad::tests cs_port_tests --skip review_r
guard cpu 3 6 1800 r12-saved-receipts /usr/bin/env ZK60_R12_EVIDENCE_DIR=$EV RAYON_NUM_THREADS=16 $S/hashline/$BIN --ignored --test-threads=1 --nocapture f2_saved_shieldstral
guard cpu 7.5 10.5 2400 r12-golden /usr/bin/env RAYON_NUM_THREADS=16 $S/hashline/$BIN --ignored --test-threads=1 --nocapture r12_golden
guard cpu 7.5 10.5 2400 r12-dense /usr/bin/env RAYON_NUM_THREADS=16 $S/hashline/$BIN --ignored --test-threads=1 --nocapture f2_a_generic_dense_shieldstral
# ---- the R9 side of the goldens, on my own copy of the R9 freeze (record mode)
guard build 3 6 3600 r9-golden-build $C test --release --offline --locked -j2 --manifest-path $S/r9-golden/hashline/Cargo.toml --lib --no-run
if [ "$(cat $R/r9-golden-build.done)" = 0 ]; then
  BIN9=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r9-golden-build.log | tail -1)
  log "R9 golden test binary: $BIN9"
  guard cpu 7.5 10.5 2400 r9-golden-run /usr/bin/env RAYON_NUM_THREADS=16 $S/r9-golden/hashline/$BIN9 --ignored --test-threads=1 --nocapture r12_golden
fi
log "queue end"
echo done > $R/r12_queue.done
