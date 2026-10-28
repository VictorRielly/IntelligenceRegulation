#!/usr/bin/env bash
# Token I/O review ROUND 6 (the lane's rounds 6 + 7): builds, my tests on the
# frozen r7 tree (+ cfg(test)-only review modules), and the 8B probes through
# my own CLI binary on the lane's round-7 demo run. Every heavy leaf guarded.
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r7-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs6
C=/home/victor/.cargo/bin/cargo
BIN=$S/tree/hashline/target/release/examples/zk60_token_io
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
CLI=$R/cli
VX7=$CLI/verifier-export-llama3_8b_pg_rot1_b7voc0_T32
VX6=$CLI/verifier-export-llama3_8b_pg_rot1_b7_T32
PX7=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32
OD7=/home/victor/zk60-artifacts/token-io/run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00-ef2b58a0591d.owner-private
B8=$S/b8
ID7=$(python3 -c "import json;print(json.load(open('$R/approvals/token_profile_approval_llama3_8b_pg_rot1_b7voc0_T32.json'))['pins']['expect_statement'])")
TP7=$(python3 -c "import json;print(json.load(open('$R/approvals/token_profile_approval_llama3_8b_pg_rot1_b7voc0_T32.json'))['pins']['expect_token_profile'])")
ID6=$(python3 -c "import json;print(json.load(open('$R/approvals/token_profile_approval_llama3_8b_pg_rot1_b7_T32.json'))['pins']['expect_statement'])")
TP6=$(python3 -c "import json;print(json.load(open('$R/approvals/token_profile_approval_llama3_8b_pg_rot1_b7_T32.json'))['pins']['expect_token_profile'])")
PROMPT=$(python3 -c "import json;print(','.join(str(x) for x in json.load(open('$PX7/seq_ho00/manifest.json'))['token_ids']))")
mkdir -p "$L"
echo "ID7=$ID7 TP7=$TP7 ID6=$ID6 TP6=$TP6 PROMPT=$PROMPT" > "$L/pins.log"

g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 4
  python3 "$G" run --class "${CLS:-cpu}" --need-gib "$need" --cap-gib "$cap" --label "trv6-$lab" --wait-secs 14400 --max-secs "$max" \
    --log "$L/$lab.log" --done "$L/$lab.exit" --result-json "$L/$lab.guard.json" -- "$@"
}

CLS=build g b1-build-tests 3 5 3000 "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M" || { echo "test build failed"; exit 2; }
CLS=build g b2-build-cli 3 5 3000 "$C" build --release --offline --locked -j2 --example zk60_token_io --manifest-path "$M" || { echo "cli build failed"; exit 2; }
sha256sum "$BIN" "$CLI/zk60_token_io.r7.release.bin" "$CLI/zk60_token_io.r7c.release.bin" > "$L/my-binary.sha256"

g t1-review 5 8 3000 "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" review_r6 -- --test-threads 2 --nocapture
g t2-token-io 5 8 3600 "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io -- --test-threads 2 --nocapture --skip review_r6

rm -rf "$B8"
python3 "$S/prep_b8_r6.py" > "$L/prep_b8.log" 2>&1 || { echo "prep failed"; exit 3; }
P7=(--export "$VX7" --emb "$VX7/token_io" --head "$VX7/token_io" --expect-statement "$ID7" --expect-token-profile "$TP7")
g p1-profile-fidelity-export 3 6 900 "$BIN" profile --export "$PX7" --emb "$PX7/token_io" --head "$PX7/token_io"
g p2-profile-verifier-copy 3 6 900 "$BIN" profile --export "$VX7" --emb "$VX7/token_io" --head "$VX7/token_io"
g p3-profile-b7 3 6 900 "$BIN" profile --export "$VX6" --emb "$VX6/token_io" --head "$VX6/token_io"
g c1-verify-recheck 3.5 6 1200 "$BIN" verify "${P7[@]}" --artifact "$B8/art7"
g c2-verify-publish 3.5 6 1200 "$BIN" verify "${P7[@]}" --artifact "$B8/art7-fresh"
cmp "$B8/art7-fresh/statement/statement.json" "$CLI/run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00/statement/statement.json" > "$L/compare.log" 2>&1 && echo "PUBLISHED statement.json IDENTICAL to the lane's" >> "$L/compare.log" || echo "PUBLISHED statement.json DIFFERS" >> "$L/compare.log"
cmp "$B8/art7-fresh/statement/segments.json" "$CLI/run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00/statement/segments.json" >> "$L/compare.log" 2>&1 && echo "PUBLISHED segments.json IDENTICAL to the lane's" >> "$L/compare.log" || echo "PUBLISHED segments.json DIFFERS" >> "$L/compare.log"
g c3-owner 3.5 6 1200 "$BIN" owner "${P7[@]}" --artifact "$B8/art7" --decommitment "$OD7/output.dec"
g c4-input-owner 3.5 6 1200 "$BIN" input-owner "${P7[@]}" --artifact "$B8/art7" --decommitment "$OD7/input.dec" --prompt "$PROMPT"
g c5-verify-b7-identity-pin 3.5 6 1200 "$BIN" verify --export "$VX7" --emb "$VX7/token_io" --head "$VX7/token_io" --expect-statement "$ID6" --expect-token-profile "$TP7" --artifact "$B8/art7"
g c6-verify-b7-export 3.5 6 1200 "$BIN" verify --export "$VX6" --emb "$VX6/token_io" --head "$VX6/token_io" --expect-statement "$ID6" --expect-token-profile "$TP6" --artifact "$B8/art7"
g c7-verify-schema1 3.5 6 1200 "$BIN" verify "${P7[@]}" --artifact "$B8/art7-schema1"
g c8-verify-owncal-empty 3.5 6 1200 "$BIN" verify "${P7[@]}" --artifact "$B8/art7-owncal"
g c9-verify-owncal-shs6 3.5 6 1200 "$BIN" verify "${P7[@]}" --artifact "$B8/art7-owncal2"
g c10-verify-tamper 3.5 6 1200 "$BIN" verify "${P7[@]}" --artifact "$B8/art7-tamper"
g c11-owner-tamper 3.5 6 1200 "$BIN" owner "${P7[@]}" --artifact "$B8/art7-tamper" --decommitment "$OD7/output.dec"
g c12-verify-r6-run-schema1 3.5 6 1200 "$BIN" verify --export "$VX6" --emb "$VX6/token_io" --head "$VX6/token_io" --expect-statement "$ID6" --expect-token-profile "$TP6" --artifact "$B8/art6"
ls -la "$B8"/* > "$L/after-listing.log" 2>&1
exit 0
