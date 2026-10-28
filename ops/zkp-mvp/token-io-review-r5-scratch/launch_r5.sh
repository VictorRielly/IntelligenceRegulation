#!/usr/bin/env bash
# Token I/O review ROUND 5: builds, the round-4 reproductions as unit tests
# against the fixed commands, and the 8B probes through the reviewer's own
# CLI binary (built from the frozen r5 tree + the cfg(test)-only review
# module, which the example binary does not contain). Every heavy leaf guarded.
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r5-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs5
C=/home/victor/.cargo/bin/cargo
BIN=$S/tree/hashline/target/release/examples/zk60_token_io
CLI=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli
VX=$CLI/verifier-export-llama3_8b_pg_rot1_b7_T32
PX=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b7_T32
OWN4=/home/victor/zk60-artifacts/token-io/run-b7_T32-ho00.owner-private
OWN5=/home/victor/zk60-artifacts/token-io/run-b7_T32-ho00-r5.owner-private
B4=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r4-scratch/b8
B8=$S/b8
PIN=47f0194335d08efb4d63df70df01f1e42d900f4730c2384490359046bb07b876
TP=$(cat $CLI/token_profile_pin_b7_T32.txt)
TPX=${TP:0:63}$( [ "${TP:63:1}" = "0" ] && echo 1 || echo 0 )
PROMPT=128000,198,792,9091,1914,198,6096,6207,220,17,13,15,11,6186,220,1049,19,198,667,1795,1129,2185,5206,2726,7116,8851,256,100028,3651,11596,4716,9645
WRONG=128000,198,792,9091,1914,199,6096,6207,220,17,13,15,11,6186,220,1049,19,198,667,1795,1129,2185,5206,2726,7116,8851,256,100028,3651,11596,4716,9645
mkdir -p "$L"
echo "TP=$TP TPX=$TPX" > "$L/pins.log"

g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 4
  python3 "$G" run --class "${CLS:-cpu}" --need-gib "$need" --cap-gib "$cap" --label "trv5-$lab" --wait-secs 7200 --max-secs "$max" \
    --log "$L/$lab.log" --done "$L/$lab.exit" --result-json "$L/$lab.guard.json" -- "$@"
}

CLS=build g b1-build-tests 3 5 2400 "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M" || { echo "test build failed"; exit 2; }
CLS=build g b2-build-cli 3 5 2400 "$C" build --release --offline --locked -j2 --example zk60_token_io --manifest-path "$M" || { echo "cli build failed"; exit 2; }
sha256sum "$BIN" "$CLI/zk60_token_io.r5.release.bin" > "$L/my-binary.sha256"

g t1-tests 5 8 2400 "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io -- --test-threads 2 --nocapture
T1=$?

rm -rf "$B8"
python3 "$S/prep_b8_r5.py" > "$L/prep_b8.log" 2>&1 || { echo "prep failed"; exit 3; }
TB=(--export "$VX" --emb "$VX/token_io" --head "$VX/token_io" --expect-statement "$PIN")
g p1-profile-prover-export 3 6 900 "$BIN" profile --export "$PX" --emb "$PX/token_io" --head "$PX/token_io"
g p2-profile-verifier-export 3 6 900 "$BIN" profile --export "$VX" --emb "$VX/token_io" --head "$VX/token_io"
g p3-profile-tables-mult 3 6 900 "$BIN" profile --export "$VX" --emb "$B8/tables-mult" --head "$B8/tables-mult"
g p4-profile-tables-link 3 6 900 "$BIN" profile --export "$VX" --emb "$B8/tables-link" --head "$B8/tables-link"
TPM=$(python3 -c "import json,sys;print(json.loads([l for l in open(sys.argv[1]) if '\"event\":\"profile\"' in l][0])['token_profile_digest'])" "$L/p3-profile-tables-mult.log")
echo "TPM=$TPM" >> "$L/pins.log"
g c1-owner-tamper 3.5 6 1200 "$BIN" owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B4/art-tamper" --decommitment "$OWN4/output.dec"
g c2-input-owner-tamper 3.5 6 1200 "$BIN" input-owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B4/art-tamper" --decommitment "$OWN4/input.dec" --prompt "$PROMPT"
g c3-owner-unverified 3.5 6 1200 "$BIN" owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B8/art-unverified" --decommitment "$OWN4/output.dec"
g c4-owner-forged 3.5 6 1200 "$BIN" owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B8/art-forged" --decommitment "$OWN4/output.dec"
g c5-verify-wrong-tp 3.5 6 1200 "$BIN" verify "${TB[@]}" --expect-token-profile "$TPX" --artifact "$B4/art-recheck"
g c6-verify-no-tp 3.5 6 1200 "$BIN" verify "${TB[@]}" --artifact "$B4/art-recheck"
g c7-verify-mult-approved-tp 3.5 6 1200 "$BIN" verify --export "$VX" --emb "$B8/tables-mult" --head "$B8/tables-mult" --expect-statement "$PIN" --expect-token-profile "$TP" --artifact "$B4/art-recheck"
g c8-verify-mult-own-tp 3.5 6 1200 "$BIN" verify --export "$VX" --emb "$B8/tables-mult" --head "$B8/tables-mult" --expect-statement "$PIN" --expect-token-profile "$TPM" --artifact "$B4/art-recheck"
g c9-owner-recheck 3.5 6 1200 "$BIN" owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B4/art-recheck" --decommitment "$OWN4/output.dec"
g c10-input-owner-recheck 3.5 6 1200 "$BIN" input-owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B4/art-recheck" --decommitment "$OWN4/input.dec" --prompt "$PROMPT"
g c11-input-owner-wrong-prompt 3.5 6 1200 "$BIN" input-owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B4/art-recheck" --decommitment "$OWN4/input.dec" --prompt "$WRONG"
g c12-verify-r5-recheck 3.5 6 1200 "$BIN" verify "${TB[@]}" --expect-token-profile "$TP" --artifact "$B8/art-r5"
g c13-owner-r5 3.5 6 1200 "$BIN" owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B8/art-r5" --decommitment "$OWN5/output.dec"
g c14-input-owner-r5 3.5 6 1200 "$BIN" input-owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B8/art-r5" --decommitment "$OWN5/input.dec" --prompt "$PROMPT"
g c15-owner-r5-with-r4-dec 3.5 6 1200 "$BIN" owner "${TB[@]}" --expect-token-profile "$TP" --artifact "$B8/art-r5" --decommitment "$OWN4/output.dec"
ls -la "$B8/art-forged" "$B8/art-unverified" "$B4/art-tamper" "$B4/art-recheck" > "$L/after-listing.log" 2>&1
echo "tests=$T1"
exit 0
