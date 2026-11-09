#!/bin/bash
# D63 Lean lane L29 (2026-11-09): one guarded job for an iteration AND the lane's check, so that the shared heavy lock is
# asked for once: build the named modules (stage.sh); only if they are green, run check_l29.sh (its output to
# check.log). usage: l29_iter_check.sh "<modules>"
OUT=$(dirname "$0")
/bin/bash "$OUT/stage.sh" "$1"
rc=$?
if [ $rc -ne 0 ]; then
  echo "iteration failed: check_l29.sh not run"
  exit $rc
fi
echo "== iteration green: check_l29.sh =="
/bin/bash "$OUT/check_l29.sh" > "$OUT/check.log" 2>&1
crc=$?
cat "$OUT/check.log"
echo "check_l29.sh rc $crc"
exit $crc
