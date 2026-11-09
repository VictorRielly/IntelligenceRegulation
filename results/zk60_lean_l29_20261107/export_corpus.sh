#!/bin/bash
# D63 Lean lane L29 (2026-11-07): build hashline's tests and run the TEST-ONLY export src/lean_l29_export_tests.rs (a
# child of the test-only private_block/token_io/classify_capture_tests.rs): an honest classifier run on the development
# rung (one block), proved, verified by the production verify_classify_run, and stage IN-C's and stage OUT-C's verifiers
# replayed with the production pieces (each replay asserted to end on the production verifier's transcript). Writes the
# text corpus here (corpus.txt) and the two stage segments' bytes OUTSIDE the repository (each over 1 MB; the repository
# takes no file over 1 MB): their sizes and sha256 are recorded in segments.sha256 here. Then the two census tests that
# list hashline's source files and hash inputs (s25_tests, hash_domain), which must still pass with the new test-only
# file. Run through run_guarded.py (the zk60 resource guard, class cpu). The receipt is fresh-entropy: every run writes
# a different corpus, and a corpus is only checked against the segments of the SAME run (the corpus records each
# segment's length and BLAKE3, which the Lean checker compares).
# (2026-11-09: the first export's segment files were in a session scratch directory under /private/tmp and were lost
# at the Mac's restart; the segments and the cargo target now live in the artifacts directory, outside the repository.)
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5e8655cfe4c9f794
OUT=$WT/results/zk60_lean_l29_20261107
SCR=${L29_SCR:-/Users/victorrielly/zk60-artifacts/resume-20261109}
M=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
mkdir -p "$SCR/l29"
export CARGO_TARGET_DIR=$SCR/l29_target
export LEAN_L29_CORPUS=$OUT/corpus.txt
export LEAN_L29_SEG_IN=$SCR/l29/l29_seg_in.bin
export LEAN_L29_SEG_OUT=$SCR/l29/l29_seg_out.bin
start=$(date +%s)
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$M" --lib lean_l29_export -- --nocapture
rc=$?
echo "export rc $rc, $(( $(date +%s) - start )) s"
if [ -f "$LEAN_L29_CORPUS" ]; then
  wc -c < "$LEAN_L29_CORPUS" | sed 's/^ */corpus.txt bytes: /'
  ( cd "$OUT" && shasum -a 256 corpus.txt ) | tee "$OUT/segments.sha256"
  ( cd "$SCR/l29" && shasum -a 256 l29_seg_in.bin l29_seg_out.bin && wc -c l29_seg_in.bin l29_seg_out.bin ) | tee -a "$OUT/segments.sha256"
fi
for f in s25_tests hash_domain; do
  /opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$M" --lib $f > "$OUT/rust_$f.log" 2>&1
  r=$?
  echo "hashline $f rc $r: $(grep -E '^test result' "$OUT/rust_$f.log")"
  [ $r -ne 0 ] && rc=$r
done
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
