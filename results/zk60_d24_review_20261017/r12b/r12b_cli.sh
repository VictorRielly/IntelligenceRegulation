#!/bin/bash
# D24 review round 11 (R12b fix check, tree 51de5b83): my CLI + derivation
# example from the PRISTINE scratch copy (built before any review test module
# is added; cfg(test) code does not enter these binaries anyway).
set -u
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
R=/home/victor/IntelligenceRegulation/results/zk60_d24_review_20261017/r12b
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r12b-scratch
C=/home/victor/.cargo/bin/cargo
N=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
Q=$R/queue.out
log() { echo "[$(date -u +%H:%M:%SZ)] $*" >> $Q; }
guard() { local cl=$1 need=$2 cap=$3 maxs=$4 label=$5; shift 5
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label $label --wait-secs 21600 --max-secs $maxs \
    --log $R/$label.log --done $R/$label.done --result-json $R/$label.guard.json -- "$@"
  log "$label exit $(cat $R/$label.done)"; }
log "cli start"
guard build 2.3 4 3600 rv12b-cli-build $C build --release --offline --locked -j2 --manifest-path $S/hashline/Cargo.toml --target-dir $S/target-cli --example zk60_trained_block --example zk60_tied_tables
if [ "$(cat $R/rv12b-cli-build.done)" = 0 ]; then
  cp $S/target-cli/release/examples/zk60_trained_block $R/zk60_trained_block.review-r12b.release.bin
  cp $S/target-cli/release/examples/zk60_tied_tables $R/zk60_tied_tables.review-r12b.release.bin
  sha256sum $R/zk60_trained_block.review-r12b.release.bin $R/zk60_tied_tables.review-r12b.release.bin $N/r12b/zk60_trained_block.release.bin $N/r12b/zk60_tied_tables.release.bin > $R/binaries.sha256
fi
log "cli end"
echo "$(cat $R/rv12b-cli-build.done)" > $R/r12b_cli.done
