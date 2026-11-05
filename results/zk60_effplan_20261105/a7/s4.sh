#!/bin/bash
# A7 stage 4, the BEFORE / AFTER in ONE process, interleaved (separate processes were too noisy to resolve ~5%):
# per pass and per GPU policy, the proof-only fork run, one request from its input (sealed) and a 4-request stream,
# every stream receipt verified: shared+spin (before A7), thread+spin (the A7 default), thread+spin200 (opt-in).
# Then, since stage 3, only the harness (an ignored test) changed: the build, a no-feature check and the full lib
# suite again on this final tree. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a31903453c5c4056a
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a7
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s4.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s4_build.log 2>&1; say "build rc=$?"
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/s4_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_GPU_AB=shared+spin,thread+spin,thread+spin200 HL_D55_AB_PASSES=3 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s4_d55_ab.log 2>&1; say "d55 interleaved before/after rc=$?"
grep -E "^D55-AB SUMMARY|^D55-AB GPU-AB" $O/s4_d55_ab.log >> $P
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/s4_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/s4_full.log | tail -8 >> $P
say "all done"
