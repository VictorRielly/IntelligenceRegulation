#!/usr/bin/env bash
# Reviewer queue for the token round-14 review. Serial, every leaf guarded.
# Before EVERY guarded launch: honour the D44 window hold file and wait until no
# other guarded job is live except light <= 1 GiB (coordinator lean-memory rule:
# at most one >= 3 GiB job box-wide). Never edits a frozen tree.
# Usage: run_rv14.sh [all|build|baseline|detail|xbin|mut|post]   (default all)
# Declarations: build measured 2.21 GiB -> 2.7 / 3.5; test batches measured 0.76 GiB (baseline, 4 threads) -> 1.5 / 2.5.
set -u
R=/home/victor/IntelligenceRegulation
SC=$R/ops/zkp-mvp/token-io-review-r14-scratch
EV=$R/results/zk60_token_io_review_r1_20261017/r14/logs
G="python3 $R/scripts/zk60_resource_guard.py"
HOLD=$R/results/zk60_guard_fix_20261021/WINDOW_HOLD
TMPD=/home/victor/zk60-artifacts/token-io/review-r14-tmp
CLI=$R/results/zk60_token_io_r1_20261017/cli
WHAT=${1:-all}
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
wait_clear() { hold; until heavy_clear; do sleep 20; hold; done; hold; }

say "queue start ($WHAT)"
if [ "$WHAT" = all ] || [ "$WHAT" = build ]; then
  wait_clear
  say "launch build"
  $G run --class build --need-gib 2.7 --cap-gib 3.5 --label rvtk14-build --wait-secs 7200 --max-secs 2700 \
    --log "$EV/rvtk14-build.log" --done "$EV/rvtk14-build.done" --result-json "$EV/rvtk14-build.guard.json" -- \
    /usr/bin/env TMPDIR="$TMPD" /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path "$SC/hashline/Cargo.toml" --lib --no-run
  rc=$?
  say "build exit $rc"
  if [ "$rc" != 0 ]; then say "stop: build failed"; echo "$rc" > "$EV/queue.done"; exit "$rc"; fi
fi
BIN=$(grep -o 'target/release/deps/hashline-[0-9a-f]*' "$EV/rvtk14-build.log" | tail -1)
BIN="$SC/hashline/$BIN"
[ -x "$BIN" ] || { say "stop: no test binary ($BIN)"; echo 3 > "$EV/queue.done"; exit 3; }
sha256sum "$BIN" > "$EV/test-binary.sha256"
say "test binary $BIN"

run_t() {
  local label=$1 need=$2 cap=$3; shift 3
  wait_clear
  say "launch $label"
  $G run --class cpu --need-gib "$need" --cap-gib "$cap" --label "rvtk14-$label" --wait-secs 7200 --max-secs 1800 \
    --log "$EV/rvtk14-$label.log" --done "$EV/rvtk14-$label.done" --result-json "$EV/rvtk14-$label.guard.json" -- \
    /usr/bin/env -C "$SC/hashline" TMPDIR="$TMPD" HL_TIO_FIXTURE_DIR="$TMPD" "$@"
  say "$label exit $?"
}

if [ "$WHAT" = all ] || [ "$WHAT" = baseline ]; then
  # the lane's classifier tests + the reviewer's attacks (S1-S7), no mutation
  run_t baseline 1.5 2.5 "$BIN" token_io::classify token_io::review_r14 --test-threads=4
fi
if [ "$WHAT" = all ] || [ "$WHAT" = detail ]; then
  # the reviewer's attacks alone, with their output (the refusal sites)
  run_t detail 1.5 2.5 "$BIN" token_io::review_r14 --test-threads=2 --nocapture
fi
if [ "$WHAT" = all ] || [ "$WHAT" = xbin ]; then
  # S8: the lane's frozen r12 / r13 / r14 release binaries, each command its own process
  run_t xbin 1.5 2.5 /usr/bin/env RV14_R12_BIN="$CLI/zk60_classify.r12.release.bin" RV14_R13_BIN="$CLI/zk60_classify.r13.release.bin" RV14_R14_BIN="$CLI/zk60_classify.r14.release.bin" \
    "$BIN" --ignored token_io::review_r14_tests::rv14_s8 --test-threads=1 --nocapture
fi
if [ "$WHAT" = all ] || [ "$WHAT" = mut ]; then
  for m in n2 pad bind src check-tables n-free size-from-n vr-last replay empty; do
    run_t "mut-$m" 1.5 2.5 /usr/bin/env RV14_MUT="$m" "$BIN" token_io::classify token_io::review_r14 --test-threads=4
  done
fi
say "queue end ($WHAT)"
echo 0 > "$EV/queue.done"
