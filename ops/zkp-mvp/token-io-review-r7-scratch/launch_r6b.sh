#!/usr/bin/env bash
# Review round 6, follow-up (the coordinator's t34 question): rebuild the
# test binary with rv6_8 and run it. Waits for launch_r6 to finish first.
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r7-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs6
C=/home/victor/.cargo/bin/cargo
while [ ! -f "$L/launch_r6.done" ]; do sleep 20; done
g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 4
  python3 "$G" run --class "${CLS:-cpu}" --need-gib "$need" --cap-gib "$cap" --label "trv6-$lab" --wait-secs 14400 --max-secs "$max" \
    --log "$L/$lab.log" --done "$L/$lab.exit" --result-json "$L/$lab.guard.json" -- "$@"
}
CLS=build g b3-build-tests-rv6-8 3 5 3000 "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M" || { echo "test build failed"; exit 2; }
g t3-rv6-8 5 8 3000 "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" rv6_8 -- --test-threads 1 --nocapture
exit 0
