#!/bin/bash
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
until grep -q "stream V finished" $D/logs/stream_V.out 2>/dev/null && grep -q "stream T1 finished" $D/logs/stream_T1.out 2>/dev/null && grep -q "stream F finished" $D/logs/stream_F.out 2>/dev/null; do sleep 20; done
exec $D/logs/lane.sh Y $D/logs/jobs_Y.txt ""
