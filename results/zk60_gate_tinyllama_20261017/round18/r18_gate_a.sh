#!/bin/bash
# PRIVACY GATE lane, gate round 18, queue A: frozen tools v21 on the R-C2 / R-C3
# classifier captures of token frozen-r14 (L1 x v0 / v1 / vtie, the L1 short
# item at the tie, the P-18 CLI-path capture, chunk 0 of the 27-id item); then
# failing-first (frozen v20 on r14 captures; v21 on an R-C1 capture), D41 over
# the 27-id item's two chunks, and the v21 suite in the frozen snapshot.
# Declarations from round 17's measured peaks (0.28-0.32 GiB) plus a margin.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round18/r18_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v21.sha256 $GT/frozen_v21 > $P/r18_gate_a.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r18_gate_a.finished; exit 4; }
for c in classify-rc3-rung-L1-v0 classify-rc3-rung-L1-v1 classify-rc3-rung-L1-vtie classify-rc3-rung-L1-vtie-short20 classify-rc3-cli-p18-r14 classify-rc3-rung-L2-v1-chunk0o27; do
  g r18_gate_a v21 v21-$c 0.8 2 7200 -- python3 $S/zk60_native_rg_classgate.py --bundle $C/$c --evidence $P/v21 --name v21-$c
done
# FAILING FIRST (1): frozen v20's whole gate on an R-C3 capture (expected: refused, nonzero exit)
g r18_gate_a ff ff-v20-gate-short20 0.8 2 1800 -- python3 $S20/zk60_native_rg_classgate.py --bundle $C/classify-rc3-rung-L2-v1-short20 --evidence $P/ff --name ff-v20-gate-short20
# FAILING FIRST (2): frozen v20's pin check and capture reader on every r14 capture; v21's reader on an R-C1 capture
g r18_gate_a ff ff-v20-pins-and-v21-on-rc1 0.5 1 900 -- python3 -c "
import json, os, sys, types
C = '$C'
names = ['classify-rc3-rung-L1-v0', 'classify-rc3-rung-L1-v1', 'classify-rc3-rung-L1-vtie', 'classify-rc3-rung-L2-v0',
         'classify-rc3-rung-L2-v1', 'classify-rc3-rung-L2-vtie', 'classify-rc3-rung-L2-v1-chunk0o27',
         'classify-rc3-rung-L2-v1-chunk1o27', 'classify-rc3-rung-L2-v1-short20', 'classify-rc3-rung-L1-vtie-short20',
         'classify-rc3-cli-p18-r14']
sys.path.insert(0, '$S20')
import zk60_native_rg_classpins as CP20, zk60_native_rg_classterminals as CT20
out = {'v20_on_r14': {}}
for n in names:
    m = json.load(open(os.path.join(C, n, 'manifest.json')))
    p = CP20.classify_capture_pins(m)
    r = CT20.check_classify_terminals(types.SimpleNamespace(manifest=m, name=n))
    out['v20_on_r14'][n] = {'v20_pins_ok': p['ok'], 'v20_pin_refusals': len(p['refusals']), 'first_refusals': p['refusals'][:3],
                            'v20_terminals_ok': r.get('ok'), 'v20_slots_checked': r.get('slots_checked'), 'v20_findings': r.get('findings')[:2]}
for k in [k for k in list(sys.modules) if k.startswith('zk60_')]:
    del sys.modules[k]
sys.path.remove('$S20')
sys.path.insert(0, '$S')
import zk60_native_rg_classgate as CG
b = CG.load(os.path.join(C, 'classify-rung-L1-v1'))
i = CG.class_integrity(b)
out['v21_on_rc1'] = {'capture': 'classify-rung-L1-v1 (R-C1, token frozen-r12 hooked)', 'integrity_ok': i['ok'],
                     'pin_refusals': i['source_pins']['refusals'], 'other_findings': [x for x in i['findings'] if not x.startswith('source pin')][:6]}
out['all_v20_refuse'] = all(not v['v20_pins_ok'] and not v['v20_terminals_ok'] for v in out['v20_on_r14'].values())
out['v21_refuses_rc1'] = not i['ok']
json.dump(out, open('$P/ff/ff-v20-pins-and-v21-on-rc1.json', 'w'), indent=1, default=str)
print(out['all_v20_refuse'], out['v21_refuses_rc1'])
"
# D41 over the 27-id item's two chunk captures (and fail-closed variants)
g r18_gate_a d41 d41-item-27 0.5 1 900 -- python3 -c "
import json, os, sys
sys.path.insert(0, '$S')
import zk60_native_rg_classgate as CG
C = '$C'
b0 = CG.load(os.path.join(C, 'classify-rc3-rung-L2-v1-chunk0o27'))
b1 = CG.load(os.path.join(C, 'classify-rc3-rung-L2-v1-chunk1o27'))
bs = CG.load(os.path.join(C, 'classify-rc3-rung-L2-v1-short20'))
out = {'item_27_two_chunks': CG.d41_item_check([b0, b1]), 'item_27_chunk1_only': CG.d41_item_check([b1]),
       'item_27_chunk1_twice': CG.d41_item_check([b0, b1, b1]), 'item_20_short': CG.d41_item_check([bs]),
       'integrity_D41': {n: CG.class_integrity(b)['D41_chunk'] for n, b in (('chunk0o27', b0), ('chunk1o27', b1), ('short20', bs))}}
json.dump(out, open('$P/d41/d41-item-27.json', 'w'), indent=1, default=str)
print(out['item_27_two_chunks']['label'], out['item_27_two_chunks']['fail_closed_reasons'], out['item_27_chunk1_only']['label'], out['item_20_short']['label'])
"
# the v21 suite in the frozen snapshot
g r18_gate_a suite unittests-v21 0.8 1.5 1800 -- python3 -m unittest discover -s $GT/frozen_v21/tests
date -u > $P/r18_gate_a.finished
