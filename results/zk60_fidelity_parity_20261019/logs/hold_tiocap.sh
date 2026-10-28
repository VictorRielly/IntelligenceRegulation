#!/bin/bash
# coordinator hold (17:5x UTC): take the lane-Y lock (lane Y and lane X's weight-2 jobs wait on it) until both
# tio-cap-llama3 captures show END in the guard history; running jobs are never touched.
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
H=/home/victor/IntelligenceRegulation/results/zk60_resource_guard/history.jsonl
exec 9>$D/logs/laneY.lock
flock 9
echo "[$(date -u +%H:%M:%SZ)] hold acquired (lane Y paused; lane X weight-2 jobs wait)"
until [ "$(grep -c '"label": "tio-cap-llama3' $H)" -ge 2 ]; do sleep 20; done
echo "[$(date -u +%H:%M:%SZ)] both tio-cap-llama3 captures ended: hold released"
