#!/bin/bash
# D65(2): the prove commands print one constant external refusal, with the detail in the owner's private log.
# D66(3): the DD dictionary's LogUp refusal is challenge-only (dd_challenge_refusal). Neither may move a receipt byte in
# an honest flow. Acceptance: the two new tests pass; the full lib suite shows only the known three failures; the
# W16R2 rung golden and the six pinned trained digests are unchanged. One guarded job, class gpu.
set -u
H=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_h124_witness_20261104
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
P=$O/d65d66b.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/d65d66b_build.log 2>&1; say "build rc=$?"
$C d65_the_external_refusal_is_constant_and_the_detail_stays_private > $O/d65b_test.log 2>&1; say "d65 test rc=$?"
$C d66_the_dictionary_refusal_is_challenge_only_and_covers_every_admissible_tuple > $O/d66b_test.log 2>&1; say "d66 test rc=$?"
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/d65d66b_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/d65d66b_full.log | tail -8 >> $P
say "all done"
