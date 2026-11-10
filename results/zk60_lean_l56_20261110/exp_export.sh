#!/bin/bash
# D63 Lean lane L56 (2026-11-10): build hashline's tests and run the TEST-ONLY export src/lean_l56_export_tests.rs (a
# child of the test-only private_block/token_io/classify_capture_tests.rs): an honest classifier run on the development
# rung (TWO blocks), proved, verified by the production verify_classify_run; the run loop replayed with the production
# pieces (lane L18's replay), recording each part's frame absorbs in order, the root each closing (boundary) opening is
# verified against and the claims it checks, with six kinds of negative control each ASSERTED refused. Writes the
# corpus here (l56_corpus.txt, a few kB). Then hashline's census tests s25_tests and hash_domain, which must still pass
# with the new test-only file. Run through run_guarded.py (the zk60 resource guard, class cpu). The receipt is
# fresh-entropy: every export writes a different corpus, and a corpus is checked only against itself.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a780d34bb1376bd36
OUT=$WT/results/zk60_lean_l56_20261110
M=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
start=$(date +%s)
env LEAN_L56_CORPUS="$OUT/l56_corpus.txt" $C lean_l56_export < /dev/null -- --nocapture --test-threads 1
rc=$?
echo "export rc $rc, $(( $(date +%s) - start )) s"
[ -f "$OUT/l56_corpus.txt" ] && ( cd "$OUT" && shasum -a 256 l56_corpus.txt && wc -c l56_corpus.txt )
crc=0
for f in s25_tests hash_domain; do
  $C $f < /dev/null > "$OUT/exp_$f.log" 2>&1
  r=$?
  echo "hashline $f rc=$r"
  grep -E "^test result" "$OUT/exp_$f.log"
  [ $r -ne 0 ] && crc=$r
done
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ $crc -eq 0 ]
