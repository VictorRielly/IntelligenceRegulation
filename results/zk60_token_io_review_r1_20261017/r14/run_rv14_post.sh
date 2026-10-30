#!/usr/bin/env bash
# Reviewer queue, second part (after run_rv14.sh's mutation runs): an incremental
# rebuild with S5b (the consistent pad-row forgery, under RV14_MUT=pv-all) and
# S8's refusal lines, then S5b, S8 again and the reviewer's tests once more.
# Same rules: WINDOW_HOLD + "no other non-light job live" before every launch.
# Declarations: build measured 2.21 GiB -> 2.7 / 3.5; test batches 0.76 GiB -> 1.5 / 2.5.
set -u
R=/home/victor/IntelligenceRegulation
SC=$R/ops/zkp-mvp/token-io-review-r14-scratch
EV=$R/results/zk60_token_io_review_r1_20261017/r14/logs
G="python3 $R/scripts/zk60_resource_guard.py"
HOLD=$R/results/zk60_guard_fix_20261021/WINDOW_HOLD
TMPD=/home/victor/zk60-artifacts/token-io/review-r14-tmp
CLI=$R/results/zk60_token_io_r1_20261017/cli
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

say "post queue start"
wait_clear
say "launch build2"
$G run --class build --need-gib 2.7 --cap-gib 3.5 --label rvtk14-build2 --wait-secs 7200 --max-secs 2700 \
  --log "$EV/rvtk14-build2.log" --done "$EV/rvtk14-build2.done" --result-json "$EV/rvtk14-build2.guard.json" -- \
  /usr/bin/env TMPDIR="$TMPD" /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path "$SC/hashline/Cargo.toml" --lib --no-run
rc=$?
say "build2 exit $rc"
if [ "$rc" != 0 ]; then say "stop: build2 failed"; echo "$rc" > "$EV/post.done"; exit "$rc"; fi
BIN=$(grep -o 'target/release/deps/hashline-[0-9a-f]*' "$EV/rvtk14-build2.log" | tail -1)
BIN="$SC/hashline/$BIN"
[ -x "$BIN" ] || { say "stop: no test binary ($BIN)"; echo 3 > "$EV/post.done"; exit 3; }
sha256sum "$BIN" > "$EV/test-binary2.sha256"
run_t() {
  local label=$1 need=$2 cap=$3; shift 3
  wait_clear
  say "launch $label"
  $G run --class cpu --need-gib "$need" --cap-gib "$cap" --label "rvtk14-$label" --wait-secs 7200 --max-secs 1800 \
    --log "$EV/rvtk14-$label.log" --done "$EV/rvtk14-$label.done" --result-json "$EV/rvtk14-$label.guard.json" -- \
    /usr/bin/env -C "$SC/hashline" TMPDIR="$TMPD" HL_TIO_FIXTURE_DIR="$TMPD" "$@"
  say "$label exit $?"
}
run_t s5b 1.5 2.5 /usr/bin/env RV14_MUT=pv-all "$BIN" --ignored token_io::review_r14_tests::rv14_s5b --test-threads=1 --nocapture
run_t xbin2 1.5 2.5 /usr/bin/env RV14_R12_BIN="$CLI/zk60_classify.r12.release.bin" RV14_R13_BIN="$CLI/zk60_classify.r13.release.bin" RV14_R14_BIN="$CLI/zk60_classify.r14.release.bin" \
  "$BIN" --ignored token_io::review_r14_tests::rv14_s8 --test-threads=1 --nocapture
run_t baseline2 1.5 2.5 "$BIN" token_io::classify token_io::review_r14 --test-threads=4
say "post queue end"
echo 0 > "$EV/post.done"
