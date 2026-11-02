#!/bin/bash
# Throwaway experiment (never committed): the W16R2 tests with W16R2_OPENED_COLS = 280 in a scratch copy,
# to show which tests derive Q from the constant (pass) and which are deliberate literal pins (fail).
set -u
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/q280
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
H=$S/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
$G --class build --need-gib 4 --cap-gib 10 --label w16r2-q280-build --wait-secs 7200 --max-secs 3600 --log $S/build.log --done $S/build.done -- \
  cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run || { grep -E -A12 '^error' $S/build.log | head -60; exit 1; }
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $S/build.log | tail -1)
B=$S/hashline/$REL
$G --class cpu --need-gib 8 --cap-gib 40 --label w16r2-q280-tests --wait-secs 7200 --max-secs 3000 --log $S/tests.log --done $S/tests.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B w16r2_tests:: range16_tests::w16_limbs --nocapture --test-threads=1
grep -h "^test .*\.\.\. \(ok\|FAILED\)$\|test result" $S/tests.log | sort | uniq
