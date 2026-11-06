#!/bin/bash
# D63 L1/L2 second Lean lane: the test-only export of the T = 128 rung trace (lean_l1_export_tests.rs, already
# registered and listed in s25_tests' TEST_ONLY_FILES), the fixture export, and the source audits that read
# witness.rs or the private_block directory (module census, file census, absorb labels, byte-literal lengths).
# The trace lines go to the guard log; extract_rung.py turns them into the TSV the Lean L1 check reads.
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-abd25deed597b23bd
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib -- \
  lean_l1_export s25_tests hash_domain_tests::every_absorb_label_on_the_path_is_in_the_table \
  grow_tests::no_commitment_column_and_no_domain_label_can_be_confused_with_a_hash_input --test-threads 2 --nocapture
