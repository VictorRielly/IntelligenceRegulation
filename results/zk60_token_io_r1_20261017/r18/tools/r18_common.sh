# TOKEN ROUND 18: shared helpers for the r18 queue scripts (sourced). As r17/tools/r17_common.sh, paths moved to r18;
# the hold / fairness / lean-memory checks are one script (r18/tools/wait_turn.py).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r18
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r18/hashline
CARGO=/home/victor/.cargo/bin/cargo
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
G="python3 $GUARD run"
F=$T/tools/freeze18.py
FX=/home/victor/zk60-artifacts/token-io/tmp-r18
mkdir -p $FX
# Sol's R13 public synthetic loader fixtures (read only; the native R13 tests' sibling dir)
LF=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
ENV="/usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF"
# the same, run from the package root (as cargo runs a test binary): for a test binary started directly
ENVC="/usr/bin/env -C $H TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF"
# the round's test module and its siblings
B18=private_block::token_io::classify_cli::batch::
# wait for this lane's turn: holds, other lanes' heavy jobs first (Astra's real post, Sol), the lean-memory rule
turn() { python3 $T/tools/wait_turn.py $L/queue.log --need "${1:-0}"; }
step() { echo "$(date -u +%FT%TZ) $1" >> $L/queue.log; }
