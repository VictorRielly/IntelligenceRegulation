#!/bin/bash
# TOKEN ROUND 17, after the chain: captures WITH public-table values from the r17 tree (its suite-built test binary;
# no source change), each through the adopted gate-19 hooks with the export replay, and the v22 FORMAT check:
#  1. the R13 rung, L = 2 (G 20 / 21), verdict 1, values (H19-1): need 1.5 / cap 2.5 (round 19: 0.53-0.56 GiB)
#  2. v22's frozen reader on it (r17/tools/v22_format_check.py: schema S1-S3, replay, r13 block terminals with controls;
#     v22's pin rule bypassed, run_capture.rs moved): light, need 1.5 / cap 3.0 (round 19's rung records ~1.0 GiB)
#  3. the REAL Shieldstral T128 moderate-hate run directory (r16-runs/hate-run, proved by e94cecf9…, verified by the r17
#     binary in the chain), values (H19-2, the CLI's own door: ONE checkpoint stream; the export replay against a
#     second load of the export's layers): need 7.5 / cap 9.5 (round 19's capture without values 4.05 GiB + the
#     ~1.42 GB store [COUNTED] + margin); lean() first
# Bundles under ~/zk60-artifacts/token-io/captures/ (outside the repo). Marker logs/r17_values.done = 0 or the step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r17/tools/r17_common.sh
finish() { echo "$1" > $L/r17_values.done; step "values end $1"; exit 0; }
C=/home/victor/zk60-artifacts/token-io/captures
C1=$C/classify-r13-rung-L2-v1-r17-values
C2=$C/classify-r13-shield-t128-cli-hate-r17-values
BN=$R/cli/zk60_classify.r17.release.bin
BSHA=$(cut -d' ' -f1 $R/cli/binaries_r17.sha256)
[ -n "$BSHA" ] || finish no-binary
# 1. the rung capture
hold; gap; step "values: rung capture"
$G --class cpu --need-gib 1.5 --cap-gib 2.5 --label tio17-cap-rung --wait-secs 14400 --max-secs 1800 --log $L/cap-rung.log --done $L/cap-rung.guard.done --result-json $L/cap-rung.guard.json -- $ENV RAYON_NUM_THREADS=8 HL_PB_CAPTURE_DIR=$C1 HL_PB_CAPTURE_BLOCKS=2 HL_PB_CLASSIFY_VERDICT=1 HL_PB_CLASSIFY_CHUNK=whole HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=token-r17-uncommitted $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_capture_tests::gate19::gate19_capture_an_r13_rung_classify_run --exact --ignored --nocapture
echo $? > $L/cap-rung.exit
[ "$(cat $L/cap-rung.exit)" = "0" ] || finish cap-rung
# 2. the v22 format check on it
hold; gap; step "values: v22 format check (rung)"
$G --class light --need-gib 1.5 --cap-gib 3.0 --label tio17-v22-rung --wait-secs 14400 --max-secs 2400 --log $L/v22-rung.log --done $L/v22-rung.guard.done --result-json $L/v22-rung.guard.json -- python3 $T/tools/v22_format_check.py --bundle $C1 --out $T/v22check/rung-L2-v1-r17-values.json
echo $? > $L/v22-rung.exit
# 3. the real capture
RUN=/home/victor/zk60-artifacts/token-io/r16-runs/hate-run
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
OWN=/home/victor/zk60-owner-private/token-io/hate-run-01652914c5fa.owner-private
hold; gap; lean; step "values: real capture (moderate-hate)"
$G --class cpu --need-gib 7.5 --cap-gib 9.5 --label tio17-cap-real --wait-secs 14400 --max-secs 3600 --log $L/cap-real.log --done $L/cap-real.guard.done --result-json $L/cap-real.guard.json -- $ENV RAYON_NUM_THREADS=8 HL_PB_CAPTURE_DIR=$C2 HL_PB_REAL_EXPORT=$EX HL_PB_REAL_TABLES=$EX/token_io HL_PB_REAL_POLICY=shieldstral-1.0-3b-moderate-hate/1 HL_PB_REAL_RUN=$RUN HL_PB_REAL_EXPECT=29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1 HL_PB_REAL_DEC=$OWN/input.dec HL_PB_CLI_BIN=$BN HL_PB_CLI_BIN_SHA256=$BSHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=token-r17-uncommitted $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_capture_tests::gate19::gate19_capture_a_real_classify_cli_run --exact --ignored --nocapture
echo $? > $L/cap-real.exit
[ "$(cat $L/cap-real.exit)" = "0" ] || finish cap-real
du -sb $C2 > $L/cap-real.du 2>&1; ls -la $C2 >> $L/cap-real.du 2>&1
[ "$(cat $L/v22-rung.exit)" = "0" ] || finish v22-rung
finish 0
