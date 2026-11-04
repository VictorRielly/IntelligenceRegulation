#!/bin/bash
# v25 freeze fixes (FR25): re-gate the two registered R13 rung bundles on the FIXED tool state -- all 18 parts at an R13
# base, controls on, the run-level joint rank on, each with its pair as --other (J-C5), the PINNED Rust s25 printout --
# one after the other, guarded (cpu class, the shared heavy lock; about 28 min each at the rung, per the merged gate's
# mg-r13-rung-s0). Run only after the merged-gate queue ends. New record names, so nothing earlier is overwritten.
# Usage: regate.sh [tool tree]   (default: the fr25-fixes worktree; after a merge, the main checkout)
# Expected per record: status D55-PASS; not_here == ["G_k in the clear: ..."] with not_here_accepted naming
# "round 27 freeze review, §3 Q5 (to be recorded in the D60 row)"; controls_run and joint_run true; PINS.pin_set ok
# (75 / 75, the registered writer); PINS.self_read_pending_independent_check []; PINS controls P-1 .. P-5 and B-1 .. B-3
# all fired, not_applicable []; HASH-2 s25_printout.accepted true at bac4bbd6.
set -u
T=${1:-/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes}
F=$T/results/zk60_gate_tinyllama_20261017/round27/fixes
L=$F/logs
E=$F/records
S=$T/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
W2=/Users/victorrielly/zk60-artifacts/d60_20261102/s25_w2_printout_v2.log
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
mkdir -p "$L" "$E"
for pair in "s0 s1" "s1 s0"; do
  set -- $pair
  $G --class cpu --need-gib 24 --cap-gib 160 --label fr25-regate-rung-$1 --wait-secs 28800 --max-secs 43200 \
    --log "$L/regate-rung-$1.log" --done "$L/regate-rung-$1.guard.done" -- \
    env -u ZK60_NL_CHECK_DIR ZK60_D55TS_WORKERS=16 ZK60_S25_W2_PRINTOUT=$W2 \
    $PY -B "$S/zk60_native_rg_d55.py" --bundle "$B/d55-r13_rung_h24-$1" --evidence "$E" --name fr25-r13-rung-$1 \
    --other "$B/d55-r13_rung_h24-$2"
  echo "regate rung-$1 rc=$?"
  grep -E "^status:|^below D55-PASS|^pin set:|^controls_run" "$L/regate-rung-$1.log"
done
