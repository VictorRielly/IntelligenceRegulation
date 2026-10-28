#!/bin/bash
# NATIVE LANE R9, check (a): the seeded single-block golden digests.
# usage: r9_golden.sh <tree root> <label>   (tree root = r9/r8-golden-tree for
# the R8 golden, or the live trained-1b tree for R9). Builds the release lib
# test binary (guarded build), then runs the two #[ignore]d golden tests one
# at a time (guarded cpu: an 8B T128 block peaks near 6.5 GiB).
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=$1; L=$2
M=$W/hashline/Cargo.toml
C=/home/victor/.cargo/bin/cargo
O=$D/r9
pre() {  # $1 need, $2 class
  until out=$(python3 $G check --class ${2:-cpu} --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
pre 3 build
python3 $G run --class build --need-gib 3 --cap-gib 6 --label $L-build --wait-secs 14400 --max-secs 5400 \
  --log $O/$L-build.log --done $O/$L-build.done --result-json $O/$L-build.guard.json \
  -- $C test --release --offline --locked -j2 --manifest-path $M --lib --no-run || exit 1
pre 7.5
python3 $G run --class cpu --need-gib 7.5 --cap-gib 10.5 --label $L-run --wait-secs 14400 --max-secs 3600 \
  --log $O/$L-run.log --done $O/$L-run.done --result-json $O/$L-run.guard.json \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $C test --release --offline --locked -j2 --manifest-path $M --lib -- --ignored --test-threads=1 --nocapture r9_golden
rc=$?
grep "R9-GOLDEN" $O/$L-run.log
exit $rc
