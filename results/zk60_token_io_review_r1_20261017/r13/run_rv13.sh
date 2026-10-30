#!/usr/bin/env bash
# Reviewer queue for the token round-13 (R-C2) review. Serial, every leaf guarded.
# Before EVERY guarded launch: honour the D44 swap-window hold file; before the
# >= 3 GiB build: wait until no other guarded job is live except light <= 1 GiB
# (coordinator lean-memory rule, 2026-10-28 21:54Z). Never edits a frozen tree.
set -u
R=/home/victor/IntelligenceRegulation
SC=$R/ops/zkp-mvp/token-io-review-r13-scratch
EV=$R/results/zk60_token_io_review_r1_20261017/r13/logs
G="python3 $R/scripts/zk60_resource_guard.py"
HOLD=$R/results/zk60_guard_fix_20261021/WINDOW_HOLD
TMPD=/home/victor/zk60-artifacts/token-io-review-r13-tmp
R12BIN=$R/results/zk60_token_io_r1_20261017/cli/zk60_classify.r12.release.bin
R13BIN=$R/results/zk60_token_io_r1_20261017/cli/zk60_classify.r13.release.bin
mkdir -p "$EV" "$TMPD"
say() { echo "$(date -u +%FT%TZ) $*" >> "$EV/queue.out"; }
hold() { while [ -e "$HOLD" ]; do sleep 30; done; }
heavy_clear() {
python3 - <<'PY'
import re, subprocess, sys
out = subprocess.run(["python3", "/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py", "status"], capture_output=True, text=True).stdout
bad = [l.strip() for l in out.splitlines()
       if (m := re.match(r"\s+job\s+(\S+)\s+(\S+)\s+need\s+([0-9.]+)G", l)) and not (m.group(2) == "light" and float(m.group(3)) <= 1.0)]
sys.exit(1 if bad else 0)
PY
}

say "queue start"
# ---- 1. build the scratch tree's lib tests (from scratch: lane a1 measured 3.24 GiB peak -> need 4.1)
hold
until heavy_clear; do sleep 20; hold; done
hold
say "launch build"
$G run --class build --need-gib 4.1 --cap-gib 5.0 --label rvtk13-build --wait-secs 0 --max-secs 2700 \
  --log "$EV/rvtk13-build.log" --done "$EV/rvtk13-build.done" --result-json "$EV/rvtk13-build.guard.json" -- \
  /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path "$SC/hashline/Cargo.toml" --lib --no-run
rc=$?
say "build exit $rc"
if [ "$rc" != 0 ]; then say "stop: build failed"; echo "$rc" > "$EV/queue.done"; exit "$rc"; fi
BIN=$(grep -o 'target/release/deps/hashline-[0-9a-f]*' "$EV/rvtk13-build.log" | tail -1)
BIN="$SC/hashline/$BIN"
[ -x "$BIN" ] || { say "stop: no test binary ($BIN)"; echo 3 > "$EV/queue.done"; exit 3; }
sha256sum "$BIN" > "$EV/test-binary.sha256"
say "test binary $BIN"

run_t() {
  local label=$1; shift
  hold
  say "launch $label"
  $G run --class cpu --need-gib 2.0 --cap-gib 3.0 --label "rvtk13-$label" --wait-secs 0 --max-secs 1500 \
    --log "$EV/rvtk13-$label.log" --done "$EV/rvtk13-$label.done" --result-json "$EV/rvtk13-$label.guard.json" -- \
    /usr/bin/env -C "$SC/hashline" TMPDIR="$TMPD" "$@"
  say "$label exit $?"
}

# ---- 2. baseline: the lane's classifier tests + the reviewer's attacks, no mutation
run_t baseline "$BIN" token_io::classify token_io::review_r13 --test-threads=4
# ---- 3. the cross-binary test (the lane's frozen r12 / r13 release binaries)
run_t xbin /usr/bin/env RV13_R12_BIN="$R12BIN" RV13_R13_BIN="$R13BIN" "$BIN" --ignored token_io::review_r13_tests::rv13_r7b --test-threads=1 --nocapture
# ---- 4. mutation runs (RV13_MUT, compiled into the test build only)
for m in rc1 skip-policy skip-copies skip-bound skip-second-digest no-g g-twice clamp skip-emb-cmp skip-w-cmp use-file-w skip-bos-norm use-file-bos-norm floor-off; do
  run_t "mut-$m" /usr/bin/env RV13_MUT="$m" "$BIN" token_io::classify_tied_tests token_io::classify_cli_tests token_io::review_r13 --test-threads=4
done
say "queue end"
echo 0 > "$EV/queue.done"
