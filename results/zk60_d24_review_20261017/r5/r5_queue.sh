#!/bin/bash
# D24 review ROUND 5 (of the native R5b tree): serial queue, every leaf guarded.
# (1) the CLI from the PRISTINE frozen copy; (2) the CLI probes (r4_A / r4_B
# re-runs, P-5, C-R4, the policy read); (3) a fresh-process verify of the
# 32-block Llama-3-8B T128 stack with my CLI, from MY verifier copy of the
# calibration lane's export; (4) the scratch lib test build; (5) the review
# tests; (6) the author's tests of the touched modules.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r5
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r5/hashline
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r5-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r5.release.bin
XA=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5b/zk60_trained_block.release.bin
K=$S/review_out/stack2
ID=$(cat $K/identity.hex)
ID8=6aba46fbd12d14b053a0ec4afb29ba7b7dbad5ef4fe327213474a737b6e3fe24
RUN8=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5b/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu/run
V8=$S/verifier-8b-T128
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { # class need cap max label cmd...
  local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 14400 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  local rc=$?; log "$label exit $rc"; return $rc
}
log "queue start"
guard build 2.5 5 3600 r5-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block || { echo fail > $R/r5_queue.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $XA > $R/binaries.sha256
log "cli copied: $(sha256sum $X | cut -c1-16)"
V="stack-verify --expect-statement $ID --artifact"
T="/usr/bin/time -v"
# P-5, C-R4
guard light 0.5 1.5 30 r5-p5-seq-in-export $X stack-verify --export $K/rev-stack2 --expect-statement $ID --artifact $K/run
guard light 0.5 1.5 30 r5-cr4-verify-label $X stack-verify --export $K/rev-stack2-v --expect-statement $ID --artifact $K/run --label request-42
rm -rf $K/run-label $K/run-label.unverified-statement
guard light 0.5 1.5 30 r5-cr4-prove-label $X stack-prove --export $K/rev-stack2 --seq s0 --out $K/run-label --label request-42
log "after r5-cr4-prove-label: run-label exists: $([ -e $K/run-label ] && echo yes || echo no); unverified exists: $([ -e $K/run-label.unverified-statement ] && echo yes || echo no)"
# honest
guard light 0.5 1.5 300 r5-honest-verify $T $X stack-verify --export $K/rev-stack2-v --expect-statement $ID --artifact $K/run --controls
# r3_6 segment probes (unchanged reader) on R5b
for c in dos sparse fifo short long1 dir devnull symlink-honest fifo1 hardlink expected-fifo; do
  guard light 0.5 1.5 30 r5-seg-$c $T $X stack-verify --export $K/rev-stack2-v --expect-statement $ID --artifact $K/run-$c
done
guard light 0.5 1.5 60 r5-seg-fifo1-ctl $X stack-verify --export $K/rev-stack2-v --expect-statement $ID --artifact $K/run-fifo1 --controls
# r4_A / r4_B export probes (verifier)
for c in arr-zero-v arr-fifo-v arr-big-v profile-fifo-v manifest-zero-v misdeclared-v fat40-v; do
  guard light 0.5 1.5 30 r5-exp-$c $T $X stack-verify --export $K/exp-$c --expect-statement $ID --artifact $K/run
done
guard light 1.5 1.5 60 r5-exp-fat-v $T $X stack-verify --export $K/exp-fat-v --expect-statement $ID --artifact $K/run
# r4_A on the PROVER side (the sealing pass)
rm -rf $K/run-fatp $K/run-fatp.unverified-statement
guard light 1.5 1.5 60 r5-exp-fat-prove $T $X stack-prove --export $K/exp-fat-p --seq s0 --out $K/run-fatp
log "after r5-exp-fat-prove: run-fatp exists: $([ -e $K/run-fatp ] && echo yes || echo no)"
# (3) the 32-block Llama-3-8B T128 stack, fresh process, my CLI, my verifier copy
guard cpu 1.5 3 1800 r5-8b-T128-verify /usr/bin/env RAYON_NUM_THREADS=16 $T $X stack-verify --export $V8 --artifact $RUN8 --expect-statement $ID8 --controls
# (4)-(6)
guard build 3 6 3600 r5-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib --no-run || { log "test build failed"; echo testbuild-fail > $R/r5_queue.done; exit 1; }
BIN=$(grep -o "target/release/deps/hashline-[0-9a-f]*" $R/r5-test-build.log | tail -1)
log "lib test binary: $BIN"
guard cpu 2 4 1800 r5-fast /usr/bin/env ZK60_REVIEW_TMP=$S/review_tmp RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=1 --nocapture review_r5
guard cpu 4 6 2400 r5-author-subset /usr/bin/env RAYON_NUM_THREADS=8 $S/hashline/$BIN --test-threads=4 trained_block_tests trained_stack_tests review_r4_b review_r3_6 cs_port_tests ladder8b_tests s24_tests s25_tests trained_calib_tests review_d24_tests r4_tests --skip review_r5
log "queue end"
echo done > $R/r5_queue.done
