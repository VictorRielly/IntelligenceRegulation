#!/usr/bin/env python3
"""D63 L1/L2, fourth Lean lane (2026-11-06): run one command under the zk60 resource guard, detached
(macOS has no setsid / flock; `start_new_session` survives the session).

usage: run_guarded.py <label> <logfile> <donefile> <cmd...>

The jobs of this lane, in order:
  run_guarded.py lean-l2d-rust3 rust.log rust.done /usr/bin/env CARGO_TARGET_DIR=<scratch target> \
    /opt/homebrew/bin/cargo test -j 2 --release --offline --locked --features gpu-metal \
    --manifest-path <worktree>/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml --lib -- lean_l1_export s25_tests \
    private_block::hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table \
    grow_tests::no_commitment_column_and_no_domain_label_can_be_confused_with_a_hash_input --test-threads 2 --nocapture
  (then keep the lines starting `OUT<TAB>` / `OUTC<TAB>` of the log as rust_token_out.tsv)
  run_guarded.py lean-l2d-check check.log check.done /bin/bash check_l2d.sh
"""
import subprocess
import sys

label, log, done = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = sys.argv[4:]
guard = ["python3", "/Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py", "run",
         "--class", "cpu", "--need-gib", "14", "--cap-gib", "24", "--wait-secs", "14400",
         "--label", label, "--log", log, "--done", done, "--"] + cmd
p = subprocess.Popen(guard, stdin=subprocess.DEVNULL, stdout=open(log + ".guard", "w"), stderr=subprocess.STDOUT,
                     start_new_session=True)
print("started", p.pid)
