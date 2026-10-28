#!/bin/bash
# coordinator hold (20:16 UTC): ONE light job at a time from all lanes until the token lane's
# results/zk60_token_io_r1_20261017/logs/r8_round.done exists. Phase 1: hold the lane-Y lock until the
# running 8B job e8_dg_gn (lane X, no lock) has ended. Phase 2: lane X has no further jobs; lane Y runs
# one job at a time on its own lock.
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
exec 9>$D/logs/laneY.lock
flock 9
echo "[$(date -u +%H:%M:%SZ)] hold phase 1: lane-Y lock taken; waiting for e8_dg_gn to end"
until [ -f $D/logs/L_e8_dg_gn.done ]; do sleep 20; done
echo "[$(date -u +%H:%M:%SZ)] e8_dg_gn ended: lock released (lane Y alone, one job at a time)"
exec 9>&-
until [ -f /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r8_round.done ]; do sleep 30; done
echo "[$(date -u +%H:%M:%SZ)] r8_round.done present: hold over (two jobs at a time may resume)"
