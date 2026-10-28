#!/bin/bash
# Round 8, part B, v2 (the coordinator's order, 20:2x UTC: the TinyLlama T128 demo FIRST, its prove
# declared from the measured TinyLlama T128 peak (3.6 GiB): need 4.2; the 8B T128 demos when room opens,
# their declarations kept at the measured peak plus margin, each guarded step waiting at most until
# 23:00 UTC). Part B (after part A, tools/r8_chain.sh: t33, the round-8 CLI, the verifier copies and the
# three `profile` runs): the three approval records, the T128 demo chains (8B b7voc0_T128, 8B
# dg_rot1_voc0_T128, TinyLlama dg_rot1_T128; each: pre-check, prove, verify, verify again, owner,
# input-owner; guard needs from the measured peaks), the 8B public-file cross-checks, the full suite and
# the final manifest. Ends by writing logs/r8_round.done with the exit code (the coordinator's release
# signal for the light-job hold), on success or failure.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
X=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
B=$D/zk60_token_io.r8.release.bin
finish() { echo "$1" > $L/r8_round.done; exit 0; }
until [ -f $L/r8_chain.done ]; do sleep 15; done
[ "$(cat $L/t33-r8-built.exit 2>/dev/null)" = "0" ] || finish "$(cat $L/t33-r8-built.exit 2>/dev/null || echo 99)"
for EN in llama3_8b_pg_rot1_b7voc0_T128 llama3_8b_dg_rot1_voc0_T128 tinyllama_dg_rot1_T128; do
  [ "$(cat $L/r8-profile-$EN.exit 2>/dev/null)" = "0" ] || finish 98
done
# the approval records: the export's own token_io SHA256SUMS re-hashed, profile.json equal to the
# fidelity ledger's value, the pins as `profile` printed them over the VERIFIER copy (public files)
rec() { # export-name profile-sha256 approved-by evidence...
  local EN=$1 PSHA=$2 WHO=$3; shift 3
  read ID TP <<< "$(python3 -c "import json;l=[json.loads(x) for x in open('$L/r8-profile-$EN.log') if x.startswith('{\"event\":\"profile\"')];print(l[-1]['trained_statement_identity'], l[-1]['token_profile_digest'])")"
  local EV=()
  for e in "$@"; do EV+=(--evidence "$e"); done
  python3 $R/tools/approval_record.py --export $X/$EN --profile-sha256 $PSHA --expect-statement $ID --expect-token-profile $TP --approved-by "$WHO" "${EV[@]}" --evidence "pins: zk60_token_io profile (round-8 binary $(cut -c1-12 $D/binaries_r8.sha256)...) over the VERIFIER copy's public files (logs/r8-profile-$EN.log)" --out $R/approvals/token_profile_approval_$EN.json >> $L/p8-approval-records.log 2>&1
  echo $? > $L/p8-approval-$EN.exit
}
rec llama3_8b_pg_rot1_b7voc0_T128 26fc103b207cb33948e0824b399a60363583387a85ba570b8722e9c22be5f796 "coordinator, 2026-10-19 ~19:10 UTC (round-8 instruction 2: approval record for b7voc0_T128 from its data files and SHA256SUMS)" "fidelity lane ledger: exports/llama3_8b_pg_rot1_b7voc0_T128 written 14:42 UTC 2026-10-19 (profile sha256 26fc103b...f796; b7 + layer-0 vocabulary recalibration); proved as a stack on native R8 (identity 5585f5ee..., the coordinator)" "STALE WORDING, DATA CORRECT: this export's token_io/ is hard-linked from the calibration lane's b7_T128 token_io/ (README.md, token_io.json and f2_fidelity.json describe b7_T128, not this export; noted by the fidelity lane 14:46 UTC). The record is built from the data files and their SHA256SUMS only: embedding 8b5a5fb1..., head rows f50ba1aa..., multipliers 9eafb7f4..., head_manifest ceecb727... (final norm g0 127 / Cn 4234 / tn 9 / Ceps 78617 = this export's profile norm_tn / norm_ceps)"
rec llama3_8b_dg_rot1_voc0_T128 00aba3d9f75a443b0238bb889edecc5c3b0b8b07965f18a5a536d0be6a675827 "coordinator, 2026-10-19 ~19:10 UTC (round-8 instruction 2: prepare the record; proving confirmed ~19:30 UTC after the export beat b7voc0: ppl ratio 1.281 / 1.277 vs 1.63 / 1.77)" "fidelity lane ledger: exports/llama3_8b_dg_rot1_voc0_T128 written 18:28 UTC 2026-10-19 (profile sha256 00aba3d9...5827), with a rebuilt token_io/ (its own SHA256SUMS)"
rec tinyllama_dg_rot1_T128 b01a6db14ad93319286fe32bcdf4827e9a41bcee2609cc63e25cdf19609e6b8a "coordinator, 2026-10-19 ~19:30 UTC (round-8 instruction 2: TinyLlama token_io added by the fidelity lane; record from SHA256SUMS)" "fidelity lane: exports/tinyllama_dg_rot1_T128 (profile sha256 b01a6db1...e6b8a); token_io/ added 2026-10-19: head files byte-identical to R2's r2_inputs (b99cbec5..., 78240198...), Cn 5664 confirmed (not recalibrated), tn 10, Ceps 74429, window 32, 0 final-norm range violations on 96 held-out sequences"
for EN in llama3_8b_pg_rot1_b7voc0_T128 llama3_8b_dg_rot1_voc0_T128 tinyllama_dg_rot1_T128; do
  [ "$(cat $L/p8-approval-$EN.exit)" = "0" ] || finish 97
done
# the demos, one after another on the heavy lock: TinyLlama T128 first (fits beside the gate and
# fidelity jobs), then the two 8B T128 demos, each step waiting at most until 23:00 UTC
/usr/bin/env TAG=r8tl EXPORT=$X/tinyllama_dg_rot1_T128 BIN=$B NO_SUITE=1 PROVE_NEED=4.2 PROVE_CAP=6 VERIFY_NEED=3.5 VERIFY_CAP=5 bash $R/tools/r4_cli_demo.sh >> $L/r8_demo_tl.log 2>&1
DEADLINE=$(date -u -d "23:00" +%s)
W=$(( DEADLINE - $(date -u +%s) ))
if [ $W -gt 300 ]; then
  /usr/bin/env TAG=r8 EXPORT=$X/llama3_8b_pg_rot1_b7voc0_T128 BIN=$B NO_SUITE=1 PROVE_NEED=8 PROVE_CAP=10 VERIFY_NEED=6 VERIFY_CAP=8 WAIT_SECS=$W bash $R/tools/r4_cli_demo.sh >> $L/r8_demo_b7voc0.log 2>&1
fi
W=$(( DEADLINE - $(date -u +%s) ))
if [ $W -gt 300 ]; then
  /usr/bin/env TAG=r8dg EXPORT=$X/llama3_8b_dg_rot1_voc0_T128 BIN=$B NO_SUITE=1 PROVE_NEED=8 PROVE_CAP=10 VERIFY_NEED=6 VERIFY_CAP=8 WAIT_SECS=$W bash $R/tools/r4_cli_demo.sh >> $L/r8_demo_dg.log 2>&1
fi
# the 8B public-file cross-checks (calibration lane's integer head, R0, float head on the integer row)
for P in "r8 llama3_8b_pg_rot1_b7voc0_T128" "r8dg llama3_8b_dg_rot1_voc0_T128"; do
  read T EN <<< "$P"
  TOK=$(python3 -c "import json;l=[json.loads(x) for x in open('$L/$T-d6-cli-owner.log') if x.startswith('{\"event\":\"next-token\"')];print(l[-1]['token'])" 2>/dev/null)
  if [ -n "$TOK" ]; then
    $G --class light --need-gib 3.5 --cap-gib 5 --label tio-p8-crosscheck-$T --wait-secs 14400 --max-secs 1800 --log $L/p8-crosscheck-$T.log --done $L/p8-crosscheck-$T.guard.done --result-json $L/p8-crosscheck-$T.guard.json -- python3 $R/tools/crosscheck_cli_next_token.py $X/$EN ho00 $TOK $R/runs/r8_crosscheck_${EN}_ho00.json
    echo $? > $L/p8-crosscheck-$T.exit
  fi
done
python3 $R/tools/manifest.py $R/manifest_final_r8.sha256 $R/manifest_r8B.sha256 $R/manifest_final_r7.sha256 > $L/r8-final-manifest.log 2>&1
$G --class cpu --need-gib 6.5 --cap-gib 8 --label tio-s12-suite --wait-secs 14400 --max-secs 2700 --log $L/s12-suite.log --done $L/s12-suite.done --result-json $L/s12-suite.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s12-suite.exit
finish "$(cat $L/s12-suite.exit)"
