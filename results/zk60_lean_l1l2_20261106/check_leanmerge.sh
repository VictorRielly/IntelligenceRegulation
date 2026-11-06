#!/bin/bash
# D63 steps L1 and L2 (the Lean lane), merged into perf on top of A21 and A22: the check on the MERGED tree in the main
# checkout. The lane changed no prover source; its Rust touches are test-only (lean_l1_export_tests.rs, a one-line
# cfg(test) module in witness.rs, one TEST_ONLY_FILES entry), and its own source-audit re-run was queued behind other jobs
# and stopped before it started. So: the test build; the full lib suite (expect exactly the known three failures; the s25
# censuses, the module follower and R19b's file census are in it); the lane's trace export test; the full Lean build of
# formal/; the L1 value-for-value check and the axiom audit, as the lane's own full.sh ran them. One guarded job.
set -u
R=/Users/victorrielly/IntelligenceRegulation
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$R/results/zk60_lean_l1l2_20261106
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/leanmerge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/leanmerge_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $O/leanmerge_build.log | head -80 >> $P; say "all done (build failed)"; exit 1; fi
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/leanmerge_full_suite.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/leanmerge_full_suite.log | tail -8 >> $P
grep -E "s25_tests::|r19b_|lean_l1_export|hash_call_sites|every_absorb_label" $O/leanmerge_full_suite.log | grep -vE " ok$" | cut -c1-200 >> $P
grep -cE "(s25_tests::|r19b_|lean_l1_export).* ok$" $O/leanmerge_full_suite.log | sed 's/^/s25 \/ r19b \/ lean export tests passing in the suite: /' >> $P
say "== the Lean build of formal/"
$LAKE -d $R/formal build > $O/leanmerge_lake.log 2>&1; rc=$?; say "lake build rc=$rc"
tail -3 $O/leanmerge_lake.log >> $P
grep -ciE "warning|sorry" $O/leanmerge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $O/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/leanmerge_l1check.log 2>&1; say "L1 value-for-value check rc=$?"
tail -4 $O/leanmerge_l1check.log | cut -c1-240 >> $P
$LAKE -d $R/formal env lean $O/axioms_l1l2.lean > $O/leanmerge_axioms.log 2>&1; say "axiom audit rc=$?"
grep -cE "sorryAx" $O/leanmerge_axioms.log | sed 's/^/sorryAx mentions: /' >> $P
grep -oE "axioms: \[[^]]*\]" $O/leanmerge_axioms.log | sort | uniq -c >> $P
say "all done"
