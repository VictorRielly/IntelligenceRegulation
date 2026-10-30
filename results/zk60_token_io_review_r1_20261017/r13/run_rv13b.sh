#!/usr/bin/env bash
# Reviewer queue, part 2: rebuild with R11 (end-to-end margin arithmetic), the R7b upgrade
# attack and R10 as a record; re-run the baseline, the cross-binary test, and the g mutants
# against R11. Same rules as run_rv13.sh (hold file before every launch; heavy-clear wait
# before the >= 3 GiB build).
set -u
R=/home/victor/IntelligenceRegulation
SC=$R/ops/zkp-mvp/token-io-review-r13-scratch
EV=$R/results/zk60_token_io_review_r1_20261017/r13/logs
G="python3 $R/scripts/zk60_resource_guard.py"
HOLD=$R/results/zk60_guard_fix_20261021/WINDOW_HOLD
TMPD=/home/victor/zk60-artifacts/token-io-review-r13-tmp
R12BIN=$R/results/zk60_token_io_r1_20261017/cli/zk60_classify.r12.release.bin
R13BIN=$R/results/zk60_token_io_r1_20261017/cli/zk60_classify.r13.release.bin
say() { echo "$(date -u +%FT%TZ) $*" >> "$EV/queue2.out"; }
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
say "queue2 start"
hold
until heavy_clear; do sleep 20; hold; done
hold
say "launch build2"
# incremental: the lane's b2 incremental build peaked 2.92 GiB -> need 3.7
$G run --class build --need-gib 3.7 --cap-gib 4.5 --label rvtk13-build2 --wait-secs 0 --max-secs 2700 \
  --log "$EV/rvtk13-build2.log" --done "$EV/rvtk13-build2.done" --result-json "$EV/rvtk13-build2.guard.json" -- \
  /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path "$SC/hashline/Cargo.toml" --lib --no-run
rc=$?
say "build2 exit $rc"
if [ "$rc" != 0 ]; then echo "$rc" > "$EV/queue2.done"; exit "$rc"; fi
BIN=$(grep -o 'target/release/deps/hashline-[0-9a-f]*' "$EV/rvtk13-build2.log" | tail -1)
BIN="$SC/hashline/$BIN"
[ -x "$BIN" ] || { say "no test binary"; echo 3 > "$EV/queue2.done"; exit 3; }
sha256sum "$BIN" > "$EV/test-binary2.sha256"
run_t() {
  local label=$1; shift
  hold
  say "launch $label"
  $G run --class cpu --need-gib 2.0 --cap-gib 3.0 --label "rvtk13-$label" --wait-secs 0 --max-secs 1500 \
    --log "$EV/rvtk13-$label.log" --done "$EV/rvtk13-$label.done" --result-json "$EV/rvtk13-$label.guard.json" -- \
    /usr/bin/env -C "$SC/hashline" TMPDIR="$TMPD" "$@"
  say "$label exit $?"
}
run_t baseline2 "$BIN" token_io::classify token_io::review_r13 --test-threads=4 --nocapture
run_t xbin2 /usr/bin/env RV13_R12_BIN="$R12BIN" RV13_R13_BIN="$R13BIN" "$BIN" --ignored token_io::review_r13_tests::rv13_r7b --test-threads=1 --nocapture
for m in no-g g-twice; do
  run_t "mut2-$m" /usr/bin/env RV13_MUT="$m" "$BIN" token_io::review_r13_tests::rv13_r11 --test-threads=1 --nocapture
done
say "queue2 end"
echo 0 > "$EV/queue2.done"
