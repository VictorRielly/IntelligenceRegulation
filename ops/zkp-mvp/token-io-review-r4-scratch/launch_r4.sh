#!/usr/bin/env bash
# Token I/O review ROUND 4: builds, CLI probes (unit tests), the 8B CLI demo
# artefacts through the reviewer's own CLI binary. Every heavy leaf guarded.
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r4-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs4
C=/home/victor/.cargo/bin/cargo
BIN=$S/tree/hashline/target/release/examples/zk60_token_io
VX=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/verifier-export-llama3_8b_pg_rot1_b7_T32
PX=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b7_T32
OWN=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/run-b7_T32-ho00.owner-private
PIN=47f0194335d08efb4d63df70df01f1e42d900f4730c2384490359046bb07b876
B8=$S/b8
mkdir -p "$L"

g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 4
  python3 "$G" run --class "${CLS:-cpu}" --need-gib "$need" --cap-gib "$cap" --label "trv4-$lab" --wait-secs 7200 --max-secs "$max" \
    --log "$L/$lab.log" --done "$L/$lab.exit" --result-json "$L/$lab.guard.json" -- "$@"
}

CLS=build g b1-build-tests 3 5 2400 "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M" || { echo "test build failed"; exit 2; }
CLS=build g b2-build-cli 3 5 2400 "$C" build --release --offline --locked -j2 --example zk60_token_io --manifest-path "$M" || { echo "cli build failed"; exit 2; }
sha256sum "$BIN" > "$L/my-binary.sha256"

g t1-tests 5 8 2400 "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io -- --test-threads 2 --nocapture
T1=$?

rm -rf "$B8"
python3 "$S/prep_b8.py" > "$L/prep_b8.log" 2>&1 || { echo "prep failed"; exit 3; }
VA=(verify --export "$VX" --emb "$VX/token_io" --head "$VX/token_io" --expect-statement "$PIN")
OA=(owner --export "$VX" --emb "$VX/token_io" --head "$VX/token_io" --expect-statement "$PIN")
g c1-verify-recheck 3.5 6 1200 "$BIN" "${VA[@]}" --artifact "$B8/art-recheck"
g c2-verify-publish 3.5 6 1200 "$BIN" "${VA[@]}" --artifact "$B8/art-publish"
g c3-owner 3 6 900 "$BIN" "${OA[@]}" --artifact "$B8/art-recheck" --decommitment "$OWN/output.dec"
g c4-verify-tamper 3.5 6 1200 "$BIN" "${VA[@]}" --artifact "$B8/art-tamper"
g c5-owner-tamper 3 6 900 "$BIN" "${OA[@]}" --artifact "$B8/art-tamper" --decommitment "$OWN/output.dec"
g c6-verify-minbits98 3.5 6 1200 "$BIN" "${VA[@]}" --artifact "$B8/art-recheck" --min-bits 98
g c7-verify-prover-export 3 6 600 "$BIN" verify --export "$PX" --emb "$PX/token_io" --head "$PX/token_io" --expect-statement "$PIN" --artifact "$B8/art-recheck"
g c8-owner-input-dec 3 6 900 "$BIN" "${OA[@]}" --artifact "$B8/art-recheck" --decommitment "$OWN/input.dec"
cmp "$B8/art-publish/statement/statement.json" /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/run-b7_T32-ho00/statement/statement.json && echo "PUBLISHED statement.json IDENTICAL to the lane's" >> "$L/compare.log" || echo "PUBLISHED statement.json DIFFERS" >> "$L/compare.log"
cmp "$B8/art-publish/statement/segments.json" /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/run-b7_T32-ho00/statement/segments.json && echo "PUBLISHED segments.json IDENTICAL to the lane's" >> "$L/compare.log" || echo "PUBLISHED segments.json DIFFERS" >> "$L/compare.log"
echo "tests=$T1"
exit 0
