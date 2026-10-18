#!/usr/bin/env bash
# Token I/O review ROUND 2: guarded build, tests, R2-scale probes, the lane's
# R2 fresh-process verify with the reviewer's binary. Every heavy leaf guarded.
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r2-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs2
C=/home/victor/.cargo/bin/cargo
LANE_R2=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/runs/r2
mkdir -p "$L"

python3 "$G" run --class build --need-gib 3 --cap-gib 5 --label trv2-build --wait-secs 5400 --max-secs 2400 \
  --log "$L/b1-build.log" --done "$L/b1-build.exit" --result-json "$L/b1-build.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M"
if [ "$(cat "$L/b1-build.exit" 2>/dev/null)" != "0" ]; then echo "build failed"; exit 2; fi

python3 "$G" run --class cpu --need-gib 4 --cap-gib 7 --label trv2-tests --wait-secs 5400 --max-secs 2400 \
  --log "$L/t1-tests.log" --done "$L/t1-tests.exit" --result-json "$L/t1-tests.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io -- --test-threads 2 --nocapture
T1=$?

python3 "$G" run --class cpu --need-gib 5 --cap-gib 8 --label trv2-r2scale --wait-secs 5400 --max-secs 2400 \
  --log "$L/t2-r2scale.log" --done "$L/t2-r2scale.exit" --result-json "$L/t2-r2scale.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" rv2_ -- --ignored --test-threads 1 --nocapture
T2=$?

python3 "$G" run --class cpu --need-gib 4 --cap-gib 7 --label trv2-lane-verify --wait-secs 5400 --max-secs 1200 \
  --log "$L/t3-lane-r2-verify.log" --done "$L/t3-lane-r2-verify.exit" --result-json "$L/t3-lane-r2-verify.guard.json" -- \
  /usr/bin/env TOKEN_IO_R2_OUT="$LANE_R2" "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io_r2_verify_from_dir -- --ignored --nocapture
T3=$?
echo "tests=$T1 r2scale=$T2 lane_verify=$T3"
exit $(( T1 != 0 || T2 != 0 || T3 != 0 ))
