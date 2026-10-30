# TOKEN ROUND 19b: shared helpers for the r19b queue scripts (sourced). As r19/tools/r19_common.sh, paths moved to r19b.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r19b
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r19b/hashline
CARGO=/home/victor/.cargo/bin/cargo
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
G="python3 $GUARD run"
F=$T/tools/freeze19b.py
# the round's scratch (D46: deleted after use): test fixtures (incl. the sparse wrong checkpoints) under tmp/
FX=/home/victor/zk60-artifacts/token-io/r19b/tmp
mkdir -p $FX
# Sol's R13 public synthetic loader fixtures (read only; the native R13 tests' sibling dir)
LF=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
ENV="/usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF"
ENVC="/usr/bin/env -C $H TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF"
# wait for this lane's turn: holds; Astra's app jobs (astra* / pm-*) go first; everything else is the guard's admission
turn() { python3 $T/tools/wait_turn.py $L/queue.log --need "${1:-0}"; }
step() { echo "$(date -u +%FT%TZ) $1" >> $L/queue.log; }
