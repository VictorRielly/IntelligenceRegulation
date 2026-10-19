#!/usr/bin/env bash
# Token I/O review ROUND 3: guarded build, tests, R3-shape and full-scale
# probes, the lane's trained R3 fresh-process verify with the reviewer's
# binary. Every heavy leaf guarded.
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r3-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs3
C=/home/victor/.cargo/bin/cargo
X=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b7_T32
LANE_R3=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/runs/r3
mkdir -p "$L"

python3 "$G" run --class build --need-gib 3 --cap-gib 5 --label trv3-build --wait-secs 7200 --max-secs 2400 \
  --log "$L/b1-build.log" --done "$L/b1-build.exit" --result-json "$L/b1-build.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M"
if [ "$(cat "$L/b1-build.exit" 2>/dev/null)" != "0" ]; then echo "build failed"; exit 2; fi

python3 "$G" run --class cpu --need-gib 5 --cap-gib 8 --label trv3-tests --wait-secs 7200 --max-secs 2400 \
  --log "$L/t1-tests.log" --done "$L/t1-tests.exit" --result-json "$L/t1-tests.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io -- --test-threads 2 --nocapture
T1=$?

python3 "$G" run --class cpu --need-gib 5.5 --cap-gib 8 --label trv3-r3scale --wait-secs 7200 --max-secs 2700 \
  --log "$L/t2-r3scale.log" --done "$L/t2-r3scale.exit" --result-json "$L/t2-r3scale.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" rv3_ -- --ignored --test-threads 1 --nocapture
T2=$?

python3 "$G" run --class cpu --need-gib 4.5 --cap-gib 7 --label trv3-lane-verify --wait-secs 7200 --max-secs 1500 \
  --log "$L/t3-lane-r3-verify.log" --done "$L/t3-lane-r3-verify.exit" --result-json "$L/t3-lane-r3-verify.guard.json" -- \
  /usr/bin/env TOKEN_IO_R3_OUT="$LANE_R3" TOKEN_IO_R3_SEQ=ho00 TOKEN_IO_R3_EXPORT="$X" TOKEN_IO_R3_EMB="$X/token_io" TOKEN_IO_R3_HEAD="$X/token_io" \
  "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io_r3_verify_from_dir -- --ignored --nocapture
T3=$?
echo "tests=$T1 r3scale=$T2 lane_verify=$T3"
exit $(( T1 != 0 || T2 != 0 || T3 != 0 ))
