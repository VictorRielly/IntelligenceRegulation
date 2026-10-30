#!/bin/bash
# PRIVACY GATE lane, gate round 20, queue R (frozen tools v23): LIMITS 1 AND 2 in ONE run on the REAL values bundle
# classify-r13-shield-t128-cli-hate-r17-values (token frozen-r17, moderate-hate, 442 recorded statement tables,
# arrays.bin 2.25 GB): the WHOLE classifier gate -- integrity, replay, hash layer, per commitment (84), mask / CFS,
# joint, the 12 classifier slots with B-3 derived from the checkpoint (streamed ONCE: one process), NL-1, ALL 23 block
# slots on ALL 26 blocks with the captured tables, the controls incl. C-13 at pad 11 and the 7 R13 controls -- and the
# FULL zero-data preimage over ALL 84 commitments (no --preimage-names), then the joint preimage.
# CPU class, need 8.8 / cap 10.5 = (round 19's in-process 5.70 GiB + the store's extra 1.30 GiB resident) + 25%
# (round20/dev/real_dev.json). Waits until NO other guarded job is live or waiting (sol- / astra- included) and no
# hold file is present, then launches; ~4.2 h [MODEL].
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round20/r20_common.sh
cd /tmp
toolcheck r20_gate_r
alone gate20-
cp $P/alone.last $P/r20_gate_r.alone_at_launch.json
date -u > $P/r20_gate_r.launched
g r20_gate_r v23 v23-$REAL cpu 8.8 10.5 28800 -- python3 -B $S/zk60_native_rg_classgate.py --bundle $C/$REAL \
  --evidence $P/v23 --name v23-$REAL --calibration-export $EX --tied-export $EX
date -u > $P/r20_gate_r.finished
