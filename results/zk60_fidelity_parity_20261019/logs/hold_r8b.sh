#!/bin/bash
# coordinator hold #3 (00:1x UTC): ONE light job (<= 3 GiB) at a time until
# results/zk60_token_io_r1_20261017/logs/r8_8b.done exists. Take the lane-Y lock when combo2_lam0 ends and keep it
# until the running 8B job e8_dg_noW (lane X, no lock) has ended; afterwards every remaining job of either lane
# needs this lock (lane X's next job is weight 2), so they run one at a time.
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
exec 9>$D/logs/laneY.lock
flock 9
echo "[$(date -u +%H:%M:%SZ)] hold #3 phase 1: lane-Y lock taken; waiting for e8_dg_noW to end"
until [ -f $D/logs/L_e8_dg_noW.done ]; do sleep 20; done
echo "[$(date -u +%H:%M:%SZ)] e8_dg_noW ended: lock released (one job at a time on the lock)"
exec 9>&-
until [ -f /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r8_8b.done ]; do sleep 30; done
echo "[$(date -u +%H:%M:%SZ)] r8_8b.done present: hold #3 over"
