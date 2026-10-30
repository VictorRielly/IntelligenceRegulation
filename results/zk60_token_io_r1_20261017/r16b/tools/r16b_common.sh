# TOKEN ROUND 16b: shared helpers for the r16b queue scripts (sourced). As r16/tools/r16_common.sh, paths moved to r16b.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r16b
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r16b/hashline
CARGO=/home/victor/.cargo/bin/cargo
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
G="python3 $GUARD run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
F=$T/tools/freeze16b.py
FX=/home/victor/zk60-artifacts/token-io/tmp-r16b
# Sol's R13 public synthetic loader fixtures (read only; the native R13 tests' sibling dir)
LF=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
ENV="/usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF"
# the round's two test groups
T16B=private_block::token_io::classify_r16_tests::r16b::
T_F1=private_block::token_io::classify_r16_tests::r16b::r16b_each_r13_shieldstral_profile_admits_exactly_the_three_moderate_policies_and_refuses_the_card_by_name
T_N1=private_block::token_io::classify_r16_tests::r16b::r16b_the_r13_shieldstral_whole_run_floors_and_terms_are_pinned_exactly
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
# fairness: when a sol- / release / astra- / s4 guard is WAITING (its guard process exists but its label is not
# among the live jobs), leave it a gap: wait until it has started or 4 minutes have passed. One-shot ps reads.
gap() {
  local t0=$(date +%s)
  while :; do
    local waiting=$(ps -eo args | grep -E "zk60_resource_guard.py run .*--label (sol-|release|astra-|s4)" | grep -v grep | sed -E 's/.*--label ([^ ]+).*/\1/' | sort -u)
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
