#!/bin/bash
# PRIVACY GATE lane, gate round 20, queue A (frozen tools v23; light, after queue R1, before R2):
# the r17 RUNG values capture gated in full by v23; failing-first: frozen v22's whole gate on an r17 capture
# (refused by name on run_capture.rs, then the F19-G2 KeyError: exit 1 by a crash), the pin rule v22 vs v23
# (manifest only), F19-G2 by the CLI (v23 on an r14 capture: a written refusal, exit 3); the v23 suite in the
# frozen snapshot and in the WORKING COPY (F19-G1; v23 installed there by r20_install_wc.py before this queue).
# Light, need 1.3 / cap 2.0 for the rung gates (round 19: ~1.0 GiB), 0.8 / 1.5 for the rest.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round20/r20_common.sh
cd /tmp
toolcheck r20_queue_a
g r20_queue_a v23 v23-$RUNG17 light 1.3 2.0 7200 -- python3 -B $S/zk60_native_rg_classgate.py --bundle $C/$RUNG17 \
  --evidence $P/v23 --name v23-$RUNG17 --calibration-export $R13FX
g r20_queue_a ff ff-v22-gate-r17-rung light 1.3 2.0 3600 -- python3 -B $S22/zk60_native_rg_classgate.py --bundle $C/$RUNG17 \
  --evidence $P/ff --name ff-v22-gate-r17-rung --calibration-export $R13FX
g r20_queue_a ff ff-pins-v22-v23 light 0.5 1.0 600 -- python3 -B $P/ff_pins.py $S22 $S $P/ff/ff-pins-v22-v23.json
g r20_queue_a ff ff-v23-refuses-r14 light 0.8 1.5 600 -- python3 -B $S/zk60_native_rg_classgate.py \
  --bundle $C/classify-rc3-rung-L2-v1-short20 --evidence $P/ff --name ff-v23-refuses-r14
g r20_queue_a suite unittests-v23-frozen light 0.8 1.5 1800 -- python3 -B -m unittest discover -s $GT/frozen_v23/tests
g r20_queue_a suite unittests-v23-working-copy light 0.8 1.5 1800 -- python3 -B -m unittest discover -s $GT/tests
date -u > $P/r20_queue_a.finished
