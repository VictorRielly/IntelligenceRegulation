# TOKEN ROUND 17: shared helpers for the r17 queue scripts (sourced). As r16b/tools/r16b_common.sh, paths moved to r17.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r17
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r17/hashline
CARGO=/home/victor/.cargo/bin/cargo
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
G="python3 $GUARD run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
F=$T/tools/freeze17.py
FX=/home/victor/zk60-artifacts/token-io/tmp-r17
# Sol's R13 public synthetic loader fixtures (read only; the native R13 tests' sibling dir)
LF=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
ENV="/usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF"
# the round's tests
T17=private_block::token_io::classify_capture_tests::gate19::r17::
# the coordinator's hold files
hold() { while [ -e $T/HOLD ] || [ -e $W ]; do echo "$(date -u +%FT%TZ) hold: a hold file exists; waiting" >> $L/queue.log; sleep 30; done; }
# the lean-memory rule (LANE_RULES addendum 2026-10-29): before a job declaring >= 3 GiB, wait until every
# other live guarded job declares <= 1 GiB
lean() {
  while python3 $GUARD status --json | python3 -c "import json,sys; s=json.load(sys.stdin); sys.exit(0 if any(j['need_gib'] > 1.0 for j in s['live_guarded_jobs']) else 1)"; do
    echo "$(date -u +%FT%TZ) lean: another live job declares > 1 GiB; waiting" >> $L/queue.log
    sleep 30
  done
}
# fairness: when a sol- / release / astra- / s4 / gate guard is WAITING (its guard process exists but its label is
# not among the live jobs), leave it a gap: wait until it has started or 4 minutes have passed. One-shot ps reads.
gap() {
  local t0=$(date +%s)
  while :; do
    local waiting=$(ps -eo args | grep -E "zk60_resource_guard.py run .*--label (sol-|release|astra-|s4|gate|g19|g20|rg)" | grep -v grep | sed -E 's/.*--label ([^ ]+).*/\1/' | sort -u)
    [ -z "$waiting" ] && return
    local live=$(python3 $GUARD status --json | python3 -c "import json,sys; print('\n'.join(j['label'] for j in json.load(sys.stdin)['live_guarded_jobs']))")
    local pending=0
    for w in $waiting; do echo "$live" | grep -qx "$w" || pending=1; done
    [ $pending = 0 ] && return
    [ $(( $(date +%s) - t0 )) -ge 240 ] && { echo "$(date -u +%FT%TZ) gap: 4 min given to $waiting" >> $L/queue.log; return; }
    sleep 20
  done
}
step() { echo "$(date -u +%FT%TZ) $1" >> $L/queue.log; }
