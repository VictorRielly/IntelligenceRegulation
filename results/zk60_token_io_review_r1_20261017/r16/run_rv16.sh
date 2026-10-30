#!/usr/bin/env bash
# Reviewer queue for the token round-16 review. Serial; every leaf guarded.
# Before EVERY guarded launch: honour the coordinator's WINDOW_HOLD and wait until no
# other guarded job is live except light <= 1 GiB (lean-memory rule: at most one >= 3 GiB
# job box-wide); after each heavy job, a 60 s gap if a sol-/astra- job is waiting.
# Never edits a frozen or lane tree. At most ONE checkpoint stream (the `verify` step).
# Usage: run_rv16.sh [all|build|tests|mut|verify]   (default all)
# Declarations: build: r14 reviewer's from-scratch test build 2.21 GiB -> 2.8 / 4.0;
#   tests: one 805 MB synthetic V x d table + one clone, --test-threads=1 -> 2.4 / 3.5 (first measurement);
#   real verify: the lane's measured 2.24-2.32 GiB RSS (cgroup page cache to the cap) -> 3.0 / 5.0.
set -u
R=/home/victor/IntelligenceRegulation
SC=$R/ops/zkp-mvp/token-io-review-r16-scratch
EV=$R/results/zk60_token_io_review_r1_20261017/r16/logs
G="python3 $R/scripts/zk60_resource_guard.py"
HOLD=$R/results/zk60_guard_fix_20261021/WINDOW_HOLD
ART=/home/victor/zk60-artifacts/token-io/review-r16
TMPD=$ART/tmp
FIX=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
EXP=$R/results/zk60_shieldstral_export_20261026/native_low_h24_t128
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
others_waiting() {
python3 - <<'PY'
import subprocess, sys
out = subprocess.run(["python3", "/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py", "status"], capture_output=True, text=True).stdout
sys.exit(0 if any(("sol-" in l or "astra-" in l) and "wait" in l.lower() for l in out.splitlines()) else 1)
PY
}
wait_clear() { hold; until heavy_clear; do sleep 20; hold; done; hold; }
gap() { if others_waiting; then say "gap: another lane's job is waiting"; sleep 60; fi; }
ENVS="TMPDIR=$TMPD HL_TIO_FIXTURE_DIR=$TMPD HL_R13_LOADER_FIXTURES=$FIX RV16_T128_PROFILE=$EXP/profile.json"

say "queue start ($WHAT)"
if [ "$WHAT" = all ] || [ "$WHAT" = build ]; then
  wait_clear
  say "launch build"
  $G run --class build --need-gib 2.8 --cap-gib 4.0 --label rvtk16-build --wait-secs 7200 --max-secs 2700 \
    --log "$EV/rvtk16-build.log" --done "$EV/rvtk16-build.done" --result-json "$EV/rvtk16-build.guard.json" -- \
    /usr/bin/env TMPDIR="$TMPD" /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path "$SC/hashline/Cargo.toml" --lib --no-run
  rc=$?
  say "build exit $rc"
  if [ "$rc" != 0 ]; then say "stop: build failed"; echo "$rc" > "$EV/queue.done"; exit "$rc"; fi
  gap
fi
BIN=$(grep -o 'target/release/deps/hashline-[0-9a-f]*' "$EV/rvtk16-build.log" | tail -1)
BIN="$SC/hashline/$BIN"
[ -x "$BIN" ] || { say "stop: no test binary ($BIN)"; echo 3 > "$EV/queue.done"; exit 3; }
sha256sum "$BIN" > "$EV/test-binary.sha256"
say "test binary $BIN"

run_t() {
  local label=$1 need=$2 cap=$3; shift 3
  wait_clear
  say "launch $label"
  $G run --class cpu --need-gib "$need" --cap-gib "$cap" --label "rvtk16-$label" --wait-secs 7200 --max-secs 1800 \
    --log "$EV/rvtk16-$label.log" --done "$EV/rvtk16-$label.done" --result-json "$EV/rvtk16-$label.guard.json" -- \
    /usr/bin/env -C "$SC/hashline" $ENVS "$@"
  say "$label exit $?"
  gap
}

if [ "$WHAT" = all ] || [ "$WHAT" = tests ]; then
  # the lane's round-16 tests and the reviewer's S1-S4, one at a time, with their output
  run_t tests 2.4 3.5 "$BIN" token_io::classify_r16 token_io::review_r16 --test-threads=1 --nocapture
fi
if [ "$WHAT" = all ] || [ "$WHAT" = mut ]; then
  # bits-l: the whole-run term charges one block instead of L (expected: the lane's tests stay
  # green, the reviewer's S2 fails); prehdr-cs6: CS-6 dropped from the verifier's pre-header pass
  for m in bits-l prehdr-cs6; do
    run_t "mut-$m" 2.4 3.5 /usr/bin/env RV16_MUT="$m" "$BIN" token_io::classify_r16 token_io::review_r16 --test-threads=1
  done
fi
if [ "$WHAT" = all ] || [ "$WHAT" = verify ]; then
  # item 5: the FROZEN-tree binary (dae5abd7...) re-verifies the real moderate-hate receipt (made by e94cecf9...)
  # in a fresh process; ONE checkpoint stream; the receipt is hard-linked into the reviewer's own directory
  ID=29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1
  sha256sum "$CLI/zk60_classify.r16-frozen.release.bin" > "$EV/verify-binary.sha256"
  wait_clear
  say "launch verify-hate"
  $G run --class cpu --need-gib 3.0 --cap-gib 5.0 --label rvtk16-verify-hate --wait-secs 7200 --max-secs 1200 \
    --log "$EV/rvtk16-verify-hate.log" --done "$EV/rvtk16-verify-hate.done" --result-json "$EV/rvtk16-verify-hate.guard.json" -- \
    /usr/bin/env RAYON_NUM_THREADS=8 "$CLI/zk60_classify.r16-frozen.release.bin" verify --export "$EXP" --tables "$EXP/token_io" \
    --policy shieldstral-1.0-3b-moderate-hate/1 --artifact "$ART/hate-run-link" --expect-statement "$ID" --min-bits 95
  say "verify-hate exit $?"
fi
say "queue end ($WHAT)"
echo 0 > "$EV/queue.done"
