#!/bin/bash
# PRIVACY GATE lane, gate round 19, queue A (frozen tools v22): the R13-rung classifier captures at full length
# and the 27-id item's two chunks; then failing-first, D41 over the item, the v22 suite in the frozen snapshot.
# Light class, need 1.3 / cap 2.0 (the staging dev run of the full preimage on an R13 rung capture peaked 1.01 GiB).
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round19/r19_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v22.sha256 $GT/frozen_v22 > $P/r19_gate_a.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r19_gate_a.finished; exit 4; }
for c in classify-r13-rung-L2-v1 classify-r13-rung-L2-v0 classify-r13-rung-L2-vtie classify-r13-rung-L1-v1 classify-r13-rung-L2-v1-chunk0o27 classify-r13-rung-L2-v1-chunk1o27; do
  g r19_gate_a v22 v22-$c light 1.3 2.0 7200 -- python3 -B $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v22 --name v22-$c --calibration-export $R13FX
done
# FAILING FIRST (1): frozen v21's whole gate on an R13-stack capture (expected: refused, nonzero exit)
g r19_gate_a ff ff-v21-gate-r13-short11 light 1.3 2.0 3600 -- python3 -B $S21/zk60_native_rg_classgate.py --bundle $C/classify-r13-rung-L2-v1-short11 --evidence $P/ff --name ff-v21-gate-r13-short11
# FAILING FIRST (2): v21's pin rule / integrity on every round-19 capture (refused), v22 on an r14 and an R-C1 capture (refused by name)
g r19_gate_a ff ff-v21-pins-and-v22-on-old light 0.8 1.5 1800 -- python3 -B $P/ff_v21_v22.py
# D41 over the 27-id item's two R13 chunk captures (and fail-closed variants)
g r19_gate_a d41 d41-item-27-r13 light 0.8 1.5 900 -- python3 -B -c "
import json, os, sys
sys.path.insert(0, '$S')
import zk60_native_rg_classgate as CG
C = '$C'
b0 = CG.load(os.path.join(C, 'classify-r13-rung-L2-v1-chunk0o27'))
b1 = CG.load(os.path.join(C, 'classify-r13-rung-L2-v1-chunk1o27'))
bs = CG.load(os.path.join(C, 'classify-r13-rung-L2-v1-short22'))
out = {'item_27_two_chunks': CG.d41_item_check([b0, b1]), 'item_27_chunk1_only': CG.d41_item_check([b1]),
       'item_27_chunk1_twice': CG.d41_item_check([b0, b1, b1]), 'item_22_short': CG.d41_item_check([bs]),
       'integrity_D41': {n: CG.class_integrity(b)['D41_chunk'] for n, b in (('chunk0o27', b0), ('chunk1o27', b1), ('short22', bs))}}
json.dump(out, open('$P/d41/d41-item-27-r13.json', 'w'), indent=1, default=str)
print(out['item_27_two_chunks']['label'], out['item_27_two_chunks']['fail_closed_reasons'], out['item_27_chunk1_only']['label'], out['item_22_short']['label'])
"
g r19_gate_a suite unittests-v22 light 0.8 1.5 1800 -- python3 -B -m unittest discover -s $GT/frozen_v22/tests
date -u > $P/r19_gate_a.finished
