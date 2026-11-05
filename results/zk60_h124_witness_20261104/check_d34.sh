#!/bin/bash
# D66(3) for the token stages (the D34 term of L4 finding 2): stages IN, IN-C, OUT and OUT-C refuse on the challenges
# and the public tables alone, before any private denominator is inverted. Acceptance: the full lib suite with only
# the known three failures; the ignored r9 / r12 seeded block goldens (including the DD blocks, which also cover
# the dictionary check of 45b958e0) at their post-F12 pins. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/d34.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/d34_build.log 2>&1; say "build rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/d34_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/d34_full.log | tail -8 >> $P
$C golden_seeded -- --ignored --nocapture --test-threads=1 > $O/d34_goldens.log 2>&1; say "r9/r12 seeded goldens rc=$?"
grep -E "^test |^test result" $O/d34_goldens.log >> $P
say "all done"
