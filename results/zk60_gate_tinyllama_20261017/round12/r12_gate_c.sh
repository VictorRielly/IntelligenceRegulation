#!/bin/bash
# gate round 12, queue C (tools v16): NL-1 S1-S5 on the new slots, the
# calibration attribution, and the terminal surjection (token stages on all
# ten; the b4 block stage with the review's controls on TinyLlama L = 1).
# Measured (round 10): NL-1 0.11 GiB / 12-28 s; cal-all 0.61 GiB / 28 s;
# surjection 0.6 GiB / 8-25 min; block-stage surjection 0.54 GiB / 6-7 min.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round12/r12_common.sh
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v16.sha256 $GT/frozen_v16 > $P/r12_gate_c.toolcheck 2>&1 || exit 4
cd /tmp
CAPS="tinyllama-t32-L1-dense-pt1 tinyllama-t32-L1-fixed-pt1 tinyllama-t32-L2-dense-pt1 tinyllama-t32-L2-fixed-pt1 tinyllama-t32-L22-dense-pt1 tinyllama-t32-L22-fixed-pt1 llama3-8b-t32-L1-dense-pt1 llama3-8b-t32-L1-fixed-pt1 llama3-8b-t32-L2-dense-pt1 llama3-8b-t32-L2-fixed-pt1"
HAVE=""
for c in $CAPS; do
  wb $c || { echo "no capture $c" >> $P/r12_gate_c.progress; continue; }
  HAVE="$HAVE $c"
  g r12_gate_c nl r9-nl-$c 0.5 1.5 1800 -- python3 $S/zk60_native_rg_tokennl.py --bundle $C/$c --evidence $P/nl --name r9-nl-$c
done
g r12_gate_c cal r9-cal-all 1 1.5 1800 -- python3 $S/zk60_native_rg_tokencal.py --attribution $E/round10/r10-pr4-9-tinyllama.log --attribution $E/round10/r10-pr4-9-8b.log $(for c in $HAVE; do echo --bundle $C/$c; done) --evidence $P/cal --name r9-cal-all
for c in $HAVE; do
  g r12_gate_c ts r9-ts-$c 1 2 3600 -- python3 $S/zk60_native_rg_tokents.py --bundle $C/$c --evidence $P/ts --name r9-ts-$c
done
for c in tinyllama-t32-L1-dense-pt1 tinyllama-t32-L1-fixed-pt1; do
  g r12_gate_c ts r9-ts-block-$c 1 2 5400 -- python3 $S/zk60_native_rg_tokents.py --bundle $C/$c --evidence $P/ts --name r9-ts-block-$c --block-stages 1
done
date -u > $P/r12_gate_c.finished
