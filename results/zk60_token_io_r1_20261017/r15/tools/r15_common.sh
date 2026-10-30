# TOKEN ROUND 15: shared helpers for the r15 queue scripts (sourced).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r15
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r15/hashline
CARGO=/home/victor/.cargo/bin/cargo
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
G="python3 $GUARD run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
F=$T/tools/freeze15.py
FX=/home/victor/zk60-artifacts/token-io/tmp-r15
ENV="/usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX"
# the coordinator's hold files
hold() { while [ -e $T/HOLD ] || [ -e $W ]; do sleep 30; done; }
# the lean-memory rule (LANE_RULES addendum 2026-10-29): before a job declaring >= 3 GiB, wait until every
# other live guarded job declares <= 1 GiB (one >= 3 GiB job box-wide, only light jobs of <= 1 GiB beside it)
lean() {
  while python3 $GUARD status --json | python3 -c "import json,sys; s=json.load(sys.stdin); sys.exit(0 if any(j['need_gib'] > 1.0 for j in s['live_guarded_jobs']) else 1)"; do
    echo "$(date -u +%FT%TZ) lean: another live job declares > 1 GiB; waiting" >> $L/queue.log
    sleep 30
  done
}
# fairness (brief): when a sol- / release / astra- guard is WAITING (its guard process exists but its label is not
# among the live jobs), leave it a gap: wait until it has started or 4 minutes have passed. One-shot ps reads, bounded.
gap() {
  local t0=$(date +%s)
  while :; do
    local waiting=$(ps -eo args | grep -E "zk60_resource_guard.py run .*--label (sol-|release|astra-)" | grep -v grep | sed -E 's/.*--label ([^ ]+).*/\1/' | sort -u)
    [ -z "$waiting" ] && return
    local live=$(python3 $GUARD status --json | python3 -c "import json,sys; print('\n'.join(j['label'] for j in json.load(sys.stdin)['live_guarded_jobs']))")
    local pending=0
    for w in $waiting; do echo "$live" | grep -qx "$w" || pending=1; done
    [ $pending = 0 ] && return
    [ $(( $(date +%s) - t0 )) -ge 240 ] && { echo "$(date -u +%FT%TZ) gap: 4 min given to $waiting" >> $L/queue.log; return; }
    sleep 20
  done
}
