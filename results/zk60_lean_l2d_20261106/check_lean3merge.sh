#!/bin/bash
# D63 L2 fourth round (the whole forward pass: stage IN, the blocks, stage OUT / OUT-C), merged into perf on top of the
# second round: the check on the MERGED tree in
# the main checkout. Rust touches are test-only (the token-stage export in lean_l1_export_tests.rs). So: the test build;
# the full lib suite (exactly the known three failures; it includes the absorb-label test the lane's rust_rung.sh
# filter missed, private_block::hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table, and the s25 /
# R19b censuses); the full Lean build of formal/; the fixture L1 check; the T=128 rung L1 check from the lane's
# extracted trace (scratch, over 1 MB, not committed; its hash is in rust_rung_summary.txt); the axiom audit of every
# new theorem. One guarded job.
set -u
R=/Users/victorrielly/IntelligenceRegulation
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$R/results/zk60_lean_l2d_20261106
R1=$R/results/zk60_lean_l1l2_20261106
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
RUNG=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/rung/rung_t128_trace.tsv
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
P=$O/lean3merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/lean3merge_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $O/lean3merge_build.log | head -80 >> $P; say "all done (build failed)"; exit 1; fi
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/lean3merge_full_suite.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/lean3merge_full_suite.log | tail -8 >> $P
grep -E "every_absorb_label_on_the_path_is_in_the_table|lean_l1_export|r19b_|s25_tests::the_file" $O/lean3merge_full_suite.log | cut -c1-200 >> $P
$LAKE -d $R/formal build > $O/lean3merge_lake.log 2>&1; rc=$?; say "lake build rc=$rc"
tail -2 $O/lean3merge_lake.log >> $P
grep -ciE "warning|sorry" $O/lean3merge_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > $O/lean3merge_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 $O/lean3merge_l1check.log >> $P
$LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/L1CheckOut.lean $O/rust_token_out.tsv $R1/rust_fixture_trace.tsv \
  > $O/lean3merge_l1check_out.log 2>&1; say "output-stage L1 check (OUT, OUT-C) rc=$?"
tail -1 $O/lean3merge_l1check_out.log >> $P
$LAKE -d $R/formal env lean $O/axioms_l2d.lean > $O/lean3merge_axioms.log 2>&1; say "axiom audit rc=$?"
grep -cE "sorryAx" $O/lean3merge_axioms.log | sed 's/^/sorryAx mentions: /' >> $P
grep -oE "axioms: \[[^]]*\]" $O/lean3merge_axioms.log | sort | uniq -c >> $P
grep -cE "does not depend on any axioms" $O/lean3merge_axioms.log | sed 's/^/theorems with no axioms: /' >> $P
say "all done"
