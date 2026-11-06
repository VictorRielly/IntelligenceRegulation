#!/bin/bash
# D63 L1/L2 lane: the new test-only export module, rebuilt in its one-line registration, plus the source audits
# that read witness.rs (module census, absorb labels, byte-literal lengths).
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a79790674c331b122
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib -- \
  lean_l1_export s25_tests hash_domain_tests::every_absorb_label_on_the_path_is_in_the_table \
  grow_tests::no_commitment_column_and_no_domain_label_can_be_confused_with_a_hash_input --test-threads 2
