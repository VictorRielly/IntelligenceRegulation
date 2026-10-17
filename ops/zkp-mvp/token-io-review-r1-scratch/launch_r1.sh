#!/usr/bin/env bash
# Token I/O R1 independent review: guarded build, tests, fresh-process pair.
# Every heavy leaf goes through the resource guard (LANE_RULES rule 1).
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r1-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs
C=/home/victor/.cargo/bin/cargo
mkdir -p "$L" "$S/runs"

python3 "$G" run --class build --need-gib 3 --cap-gib 5 --label trv-build --wait-secs 5400 --max-secs 2400 \
  --log "$L/b1-build.log" --done "$L/b1-build.exit" --result-json "$L/b1-build.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M" \
&& python3 "$G" run --class cpu --need-gib 4 --cap-gib 7 --label trv-tests --wait-secs 5400 --max-secs 2400 \
  --log "$L/t1-tests.log" --done "$L/t1-tests.exit" --result-json "$L/t1-tests.guard.json" -- \
  "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io -- --test-threads 2 --nocapture
T=$?
if [ "$(cat "$L/b1-build.exit" 2>/dev/null)" != "0" ]; then echo "build failed"; exit 2; fi
# the fresh-process pair (two separate processes), run whatever the test result
python3 "$G" run --class cpu --need-gib 3 --cap-gib 6 --label trv-p1 --wait-secs 5400 --max-secs 1200 \
  --log "$L/p1-prove-to-dir.log" --done "$L/p1-prove-to-dir.exit" --result-json "$L/p1-prove-to-dir.guard.json" -- \
  /usr/bin/env TOKEN_IO_R1_OUT="$S/runs" "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io_r1_prove_to_dir -- --ignored --nocapture \
&& python3 "$G" run --class cpu --need-gib 3 --cap-gib 6 --label trv-p2 --wait-secs 5400 --max-secs 1200 \
  --log "$L/p2-verify-from-dir.log" --done "$L/p2-verify-from-dir.exit" --result-json "$L/p2-verify-from-dir.guard.json" -- \
  /usr/bin/env TOKEN_IO_R1_OUT="$S/runs" "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io_r1_verify_from_dir -- --ignored --nocapture
P=$?
echo "tests=$T pair=$P"
exit $(( T != 0 || P != 0 ))
