#!/bin/bash
# D65(1) / F12 fix, final checks. Each cargo command is its own guarded job (class gpu), one at a time.
# Acceptance: the full lib suite shows only the three known failures (one renamed:
# review_tests::a_toy_receipt_made_before_f12_is_refused, same cause); the W16R2 rung golden holds on CPU and
# Metal at 96e4f0b6; the six trained digests are the new values below on CPU and Metal; the r9/r12 goldens and
# statement identities hold at their new pins; the integration tests that reach M pass; the release CLI builds.
# Usage: check_f12.sh <worktree> <out_dir>
set -u
W=${1:?worktree}
O=${2:?out dir}
mkdir -p "$O"
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class gpu --need-gib 48 --cap-gib 120"
CT="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H"
C="$CT --lib"
T=private_block::slot_ir::accuracy::tests
P=$O/check.progress
say() { echo "$(date -u +%FT%TZ) $*" >> "$P"; }
say start
$G --label f12-final-full --log $O/full.log --done $O/full.done -- env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8
say "full lib suite rc=$(cat $O/full.done) (expect: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/full.log | tail -8 >> "$P"
$G --label f12-final-r2rung --log $O/r2rung.log --done $O/r2rung.done -- env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden -- --ignored --exact --nocapture --test-threads=1
say "w16r2 rung golden (CPU = Metal = 96e4f0b6) rc=$(cat $O/r2rung.done)"
$G --label f12-final-trained --log $O/trained.log --done $O/trained.done -- env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=1 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1
say "trained digests rc=$(cat $O/trained.done)"
# the six pinned trained digests after D65(1) (were 2b0d04bb 678953f6 01a6d51d c5e0bdac a9a19ee5 4e189ccc)
for pd in R13_SHIELD_T128_H24:5a6193d3 R13_8B_T128_H24:f590b01f W16_SHIELD_T128_H24:79f987ef W16_8B_T128_H24:a8258241 W16R2_SHIELD_T128_H24:0e88d84f W16R2_8B_T128_H24:90003b76; do
  p=${pd%%:*}; d=${pd##*:}
  n=$(grep -cE "M4-TRAINED $p .*digest cpu $d[0-9a-f]* metal $d" $O/trained.log)
  if [ "$n" -ge 2 ]; then say "digest $p $d present on CPU and Metal ($n passes)"; else say "DIGEST $p $d MISSING ($n passes)"; fi
done
$G --label f12-final-goldens --log $O/goldens.log --done $O/goldens.done -- $C -- --ignored --test-threads=4 --nocapture r9_golden_tests r12_golden_tests
say "r9/r12 goldens and statement identities rc=$(cat $O/goldens.done)"
grep -E "^test result" $O/goldens.log >> "$P"
$G --label f12-final-integration --log $O/integration.log --done $O/integration.done -- $CT --test zk60_private_seam --test zk60_private_attention --test zk60_private_block --test zk60_fable_cfs_channel --test zk60_proof_size --test zk60_mask_rank --test zk60_tagged_gpu_commit -- --test-threads=4
say "integration tests reaching M rc=$(cat $O/integration.done)"
grep -E "^test result|Running" $O/integration.log >> "$P"
$G --label f12-final-cli --log $O/cli_build.log --done $O/cli_build.done -- /opt/homebrew/bin/cargo build --release --offline --locked --features gpu-metal --manifest-path $H --bins --examples
say "release CLI build (bin hashline and every example) rc=$(cat $O/cli_build.done)"
grep -E "^(warning|error)" $O/cli_build.log | sort | uniq -c >> "$P"
say "all done"
