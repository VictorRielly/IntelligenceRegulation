#!/bin/bash
# TOKEN ROUND 16, chain 4: the frozen tree's own binary (dae5abd7…, rebuilt after the suite; its source differs from
# the receipts' binary e94cecf9… only by N-r14-2's two comment lines in classify.rs, which shift panic line numbers)
# (1) verifies a REAL receipt made by e94cecf9 (moderate-sexual; fresh process; the published statement re-checked
# byte for byte; need 2.9 / cap 4.5 = measured 2.29 + 25%), (2) cross-verifies rung receipts with e94cecf9 both ways.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/tools/r16_common.sh
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
BF=$R/cli/zk60_classify.r16-frozen.release.bin
B=$R/cli/zk60_classify.r16.release.bin
hold; gap; lean
$G --class cpu --need-gib 2.9 --cap-gib 4.5 --label tio16-frozen-verify-sexual --wait-secs 14400 --max-secs 1800 --log $L/frozen-verify-sexual.log --done $L/frozen-verify-sexual.guard.done --result-json $L/frozen-verify-sexual.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $BF verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-sexual/1 --artifact /home/victor/zk60-artifacts/token-io/r16-runs/sexual-run --expect-statement 29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1 --min-bits 95
echo $? > $L/frozen-verify-sexual.exit
hold; gap
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio16-xbin-frozen --wait-secs 14400 --max-secs 900 --log $L/xbin-frozen-r16.log --done $L/xbin-frozen-r16.guard.done --result-json $L/xbin-frozen-r16.guard.json -- $ENV HL_PB_CLI_BIN=$BF HL_PB_CLI_BIN_OTHER=$B $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r15_tests::r15_receipts_cross_verify_between_two_named_binaries --exact --ignored --nocapture
echo $? > $L/xbin-frozen-r16.exit
echo "verify=$(cat $L/frozen-verify-sexual.exit) xbin=$(cat $L/xbin-frozen-r16.exit)" > $L/r16_chain4.done
