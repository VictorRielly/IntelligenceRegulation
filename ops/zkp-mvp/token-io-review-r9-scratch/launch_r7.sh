#!/usr/bin/env bash
# Token I/O review ROUND 7 (frozen-r9): builds, my review tests + the lane's
# token_io tests (r9 / r9v / t128 / pr4) on my build, and an 8B T32 end-to-end
# with the lane's NAMED r9 binary (the presenter demo's binary) for prove and
# MY binary for verify / owner / input-owner. Every heavy leaf guarded.
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r9-scratch
M=$S/tree/hashline/Cargo.toml
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_review_r1_20261017/logs7
C=/home/victor/.cargo/bin/cargo
BIN=$S/tree/hashline/target/release/examples/zk60_token_io
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
LBIN=$R/cli/zk60_token_io.r9.release.bin
LBIN_SHA=b56f1b7152e617e8753c21aa9c77fa5de19862df759081cce514d0766c8d4851
E=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32
VX=$R/cli/verifier-export-llama3_8b_pg_rot1_b7voc0_T32
SP=/tmp/claude-1000/-home-victor-IntelligenceRegulation/c08c4558-9df4-474f-a0b5-1bf1cd034626/scratchpad/r7
RUN=$S/b8/run-8b-t32-r9
OD=$SP/owners/run-8b-t32-r9.owner-private
ID=$(python3 -c "import json;print(json.load(open('$R/approvals/token_profile_approval_llama3_8b_pg_rot1_b7voc0_T32.json'))['pins']['expect_statement'])")
TP=$(python3 -c "import json;print(json.load(open('$R/approvals/token_profile_approval_llama3_8b_pg_rot1_b7voc0_T32.json'))['pins']['expect_token_profile'])")
mkdir -p "$L" "$S/b8"
g() { # label need cap max -- cmd...
  local lab=$1 need=$2 cap=$3 max=$4; shift 4
  python3 "$G" run --class "${CLS:-cpu}" --need-gib "$need" --cap-gib "$cap" --label "trv7-$lab" --wait-secs 21600 --max-secs "$max" \
    --log "$L/$lab.log" --done "$L/$lab.exit" --result-json "$L/$lab.guard.json" -- "$@"
}
CLS=build g b1-build-tests 3 5 3000 "$C" test --release --offline --locked -j2 --lib --no-run --manifest-path "$M" || { echo "test build failed"; exit 2; }
CLS=build g b2-build-cli 3 5 3000 "$C" build --release --offline --locked -j2 --example zk60_token_io --manifest-path "$M" || { echo "cli build failed"; exit 2; }
sha256sum "$BIN" "$LBIN" > "$L/binaries.sha256"
[ "$(sha256sum $LBIN | cut -c1-64)" = "$LBIN_SHA" ] && echo "lane r9 binary sha256 = the frozen note's" >> "$L/binaries.sha256" || echo "LANE r9 BINARY DIFFERS FROM THE NOTE" >> "$L/binaries.sha256"
g t1-review 5 8 3000 "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" review_r7 -- --test-threads 2 --nocapture
g t2-token-io 6.5 8.5 3600 "$C" test --release --offline --locked -j2 --lib --manifest-path "$M" token_io -- --test-threads 2 --nocapture --skip review_r7
P=(--export "$VX" --emb "$VX/token_io" --head "$VX/token_io" --expect-statement "$ID" --expect-token-profile "$TP")
g e1-prove-8b-t32-lane-r9 4.5 6.5 2400 "$LBIN" prove --export "$E" --emb "$E/token_io" --head "$E/token_io" --seq ho00 --prompt-file "$SP/prompt-ho00" --out "$RUN" --owner-dir "$OD"
g e2-verify-mine 3.5 6 1500 "$BIN" verify "${P[@]}" --artifact "$RUN"
g e3-owner-mine 3.5 6 1500 "$BIN" owner "${P[@]}" --artifact "$RUN" --decommitment "$OD/output.dec" --token-out "$SP/owners/token-8b-t32"
g e4-input-owner-mine 3.5 6 1500 "$BIN" input-owner "${P[@]}" --artifact "$RUN" --decommitment "$OD/input.dec" --prompt-file "$SP/prompt-ho00"
g e5-recheck-lane-r9 3.5 6 1500 "$LBIN" verify "${P[@]}" --artifact "$RUN"
cmp "$RUN/statement/statement.json" "$R/cli/run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00/statement/statement.json" > "$L/compare.log" 2>&1; echo "statement.json vs the r7 run's: exit $? (roots and context differ per run; expected to differ only in the two endpoint roots)" >> "$L/compare.log"
diff <(grep -v endpoint_root "$RUN/statement/statement.json") <(grep -v endpoint_root "$R/cli/run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00/statement/statement.json") >> "$L/compare.log" 2>&1; echo "statement.json minus the two endpoint-root lines vs the r7 run's: diff exit $?" >> "$L/compare.log"
stat -c '%a %n' "$OD" "$OD"/* "$SP/owners/token-8b-t32" >> "$L/compare.log" 2>&1
exit 0
