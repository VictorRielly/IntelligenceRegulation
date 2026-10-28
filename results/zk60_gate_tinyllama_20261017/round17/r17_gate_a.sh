#!/bin/bash
# PRIVACY GATE lane, gate round 17, queue A: frozen tools v20
# (manifest f3cb140b...) on the R-C1 classifier rung captures:
# classify-rung-L1-v0 classify-rung-L1-v1 classify-rung-L1-vtie classify-rung-L2-v1-chunk1o27
# Each: classgate with controls and the full preimage. Declarations from the
# dev run's measured peak (0.28 GiB, 582 s at L1) plus a margin; a hold-file
# check before each job (EV/HOLD).
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round17/r17_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v20.sha256 $GT/frozen_v20 > $P/r17_gate_a.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r17_gate_a.finished; exit 4; }
for c in classify-rung-L1-v0 classify-rung-L1-v1 classify-rung-L1-vtie classify-rung-L2-v1-chunk1o27; do
  g r17_gate_a v20 v20-$c 0.8 2 7200 -- python3 $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v20 --name v20-$c
done
# FAILING FIRST: frozen v19's capture reader and pin check on a classifier capture
g r17_gate_a ff ff-v19-reader 0.3 1 600 -- python3 -c "
import json, sys
sys.path.insert(0, '/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v19/scripts')
import zk60_native_rg_classterminals as CT, zk60_native_rg_classpins as CP
import types
m = json.load(open('$C/classify-rung-L1-v1/manifest.json'))
r = CT.check_classify_terminals(types.SimpleNamespace(manifest=m, name='classify-rung-L1-v1'))
p = CP.check_classify_pins(m)
out = {'v19_reader': {k: r.get(k) for k in ('ok', 'checked', 'refused')}, 'v19_pin_check': p}
json.dump(out, open('$P/ff/ff-v19-reader.json', 'w'), indent=1)
print(out['v19_reader'], p['ok'], p['refusals'][:4])
"
# D41 over the item of the chunk capture (chunk 1 of 2 only: fail-closed)
g r17_gate_a d41 d41-item-chunk1o27 0.3 1 600 -- python3 -c "
import json, sys
sys.path.insert(0, '$S')
import zk60_native_rg_classgate as CG
b = CG.load('$C/classify-rung-L2-v1-chunk1o27')
r = CG.d41_item_check([b])
json.dump(r, open('$P/d41/d41-item-chunk1o27.json', 'w'), indent=1, default=str)
print(r['label'], r['fail_closed_reasons'])
"
# the v20 suite in the frozen snapshot
g r17_gate_a suite unittests-v20 0.8 1.5 1200 -- python3 -m unittest discover -s $GT/frozen_v20/tests
date -u > $P/r17_gate_a.finished
