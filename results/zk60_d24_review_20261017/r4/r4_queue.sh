#!/bin/bash
# D24 review ROUND 4 (of the native Round-5 tree): serial queue, every leaf
# guarded. (1) the production CLI built from the PRISTINE frozen copy into a
# scratch target dir; (2) the release test binaries of the scratch copy
# (frozen + review_r4 test modules only); (3) the review tests; (4) the CLI
# DoS / binding checks on the round-3 two-layer rung stack; (5) the author's
# full release suite on the scratch copy with the review tests skipped.
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r4
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r4/hashline
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r4-scratch
C=/home/victor/.cargo/bin/cargo
X=$R/zk60_trained_block.review-r4.release.bin
XR4=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r4/zk60_trained_block.release.bin
K=$S/review_out/stack2
ID=$(cat $K/identity.hex)
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { # class need cap max label cmd...
  local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 14400 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  local rc=$?; log "$label exit $rc"; return $rc
}
log "queue start"
# (1) CLI from the pristine frozen sources
guard build 2.5 5 3600 r4-cli-build $C build --release --offline --locked -j2 --manifest-path $F/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block || { echo fail > $R/r4_queue.done; exit 1; }
cp $S/target-cli/release/examples/zk60_trained_block $X
sha256sum $X $XR4 > $R/binaries.sha256
log "cli copied: $(sha256sum $X | cut -c1-16)"
# (4) CLI checks (light, small caps, short limits)
V="stack-verify --export $K/rev-stack2 --expect-statement $ID --artifact"
guard light 0.5 1.5 300 r4-stack2-verify /usr/bin/time -v $X $V $K/run --controls
guard light 0.5 1.5 20 r4-stack2-dos /usr/bin/time -v $X $V $K/run-dos
guard light 0.5 1.5 20 r4-stack2-sparse /usr/bin/time -v $X $V $K/run-sparse
guard light 0.5 1.5 20 r4-stack2-fifo /usr/bin/time -v $X $V $K/run-fifo
guard light 0.5 1.5 20 r4-stack2-short $X $V $K/run-short
guard light 0.5 1.5 20 r4-stack2-long1 $X $V $K/run-long1
guard light 0.5 1.5 20 r4-stack2-dir $X $V $K/run-dir
guard light 0.5 1.5 20 r4-stack2-devnull $X $V $K/run-devnull
guard light 0.5 1.5 20 r4-stack2-symlink-honest $X $V $K/run-symlink-honest
guard light 0.5 1.5 60 r4-stack2-fifo1 /usr/bin/time -v $X $V $K/run-fifo1
guard light 0.5 1.5 60 r4-stack2-fifo1-ctl $X $V $K/run-fifo1 --controls
guard light 0.5 1.5 60 r4-stack2-hardlink $X $V $K/run-hardlink
# export side
guard light 0.5 1.5 20 r4-exp-arr-zero /usr/bin/time -v $X stack-verify --export $K/exp-arr-zero --expect-statement $ID --artifact $K/run
guard light 0.5 1.5 20 r4-exp-arr-fifo /usr/bin/time -v $X stack-verify --export $K/exp-arr-fifo --expect-statement $ID --artifact $K/run
guard light 0.5 1.5 20 r4-exp-arr-big /usr/bin/time -v $X stack-verify --export $K/exp-arr-big --expect-statement $ID --artifact $K/run
guard light 1.5 1.5 60 r4-exp-fat /usr/bin/time -v $X stack-verify --export $K/exp-fat --expect-statement $ID --artifact $K/run
guard light 1.5 1.5 60 r4-exp-fat-r4cli /usr/bin/time -v $XR4 stack-verify --export $K/exp-fat --expect-statement $ID --artifact $K/run
# (2) test binaries of the scratch copy
guard build 3 6 3600 r4-test-build $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --no-run || { log "test build failed: skipping the review tests and the suite"; echo testbuild-fail > $R/r4_queue.done; exit 1; }
# (3) review tests (one at a time, so VmHWM is per test)
guard cpu 2 4 1800 r4-fast /usr/bin/env ZK60_REVIEW_TMP=$S/review_tmp RAYON_NUM_THREADS=8 $C test --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --lib review_r4 -- --test-threads=1 --nocapture
# (5) the author's full suite on the scratch copy, review tests skipped
guard cpu 5.5 8 5400 r4-suite $C test --release --offline --locked -j2 --no-fail-fast --manifest-path $S/hashline/Cargo.toml -- --test-threads=8 --skip review_r4
log "queue end"
echo done > $R/r4_queue.done
