#!/bin/bash
# Efficiency plan A3: stack-prove's default witness-cache budget is sized to the machine (an eighth of RAM, 4..=64 GiB;
# test builds keep 4). Acceptance: the A3 test, the trained-stack CLI tests, and the full lib suite with only the
# known three failures. One guarded job.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/a3.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/a3_build.log 2>&1; say "build rc=$?"
$C a3_the_default_witness_cache -- --nocapture > $O/a3_test.log 2>&1; say "a3 test rc=$? $(grep -E '^A3:' $O/a3_test.log)"
env HL_R13_LOADER_FIXTURES=$F $C trained_stack_tests > $O/a3_stack.log 2>&1; say "trained_stack_tests rc=$? $(grep -E '^test result' $O/a3_stack.log)"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/a3_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/a3_full.log | tail -8 >> $P
say "all done"
