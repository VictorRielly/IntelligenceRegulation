#!/bin/bash
# D64 / H124d: a stream of requests on the Mac, all witness work on the clock. The D55 A/B harness's HL_D55_PIPE arm
# seals request r + 1 (its forward chain, witnesses kept) while request r's fork run proves; every receipt is verified
# after the clock. Test code only. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/pipe2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/pipe2_build.log 2>&1; say "build rc=$?"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_SEALED=1 HL_D55_PIPE=4 $C private_block::run::fork::tests::d55_ab_one_request_serial_against_forks -- --ignored --exact --nocapture --test-threads=1 > $O/d55_ab_pipe2.log 2>&1; say "d55 A/B stream rc=$?"
grep -E "sealing pass|^D55-AB SUMMARY|^D55-AB PIPE|SEALED pass" $O/d55_ab_pipe2.log >> $P
say "all done"
