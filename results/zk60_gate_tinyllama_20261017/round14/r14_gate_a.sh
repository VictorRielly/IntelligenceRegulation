#!/bin/bash
# PRIVACY GATE lane, gate round 14 (DD), official queue A: frozen tools v17
# (manifest ff68af54...) on the eight DD captures -- the DD rung (T32 / d256,
# L = 1, 2) and TinyLlama T128 DD (layers 0 / 0-1), each dense and zero.
#   FAILING FIRST: frozen v16 (no R9 reading) must refuse the R9 pins by name.
#   Then pass A, the validated prediction, the DD NL-1, the DD controls, the
#   DD surjection, TL controls (TL-5 / TL-6: the per-stage calibration), the
#   export controls, the schema, G-10, the pin controls, the witness
#   comparison, and the v17 unit suite. Queue B takes the everything passes.
# Declarations from the dev runs' measured peaks plus a margin (pass A
# T128 0.46 GiB, rung 0.1; ddts T128 L2 0.64; TL 0.33; ddnl / ddcontrols
# < 0.4); a hold-file check before each job (EV/HOLD).
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round14/r14_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v17.sha256 $GT/frozen_v17 > $P/r14_gate_a.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r14_gate_a.finished; exit 4; }
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v16.sha256 $GT/frozen_v16 >> $P/r14_gate_a.toolcheck 2>&1 || { echo "V16 MOVED" > $P/r14_gate_a.finished; exit 4; }
Q=r14_gate_a
# ---- FAILING FIRST: v16 on a DD bundle (rung L1 dense; T128 L2 dense)
g $Q ff ff-v16-rung-l1-dense 0.5 1.5 900 -- python3 $V16/zk60_native_rg_m125.py --bundle $A/dd-rung-l1-dense --stages load,replay,hash,terminals,commitments,boundary,preimage --evidence $P/ff --name ff-v16-rung-l1-dense
g $Q ff ff-v16-tl128dd-l2-dense 0.8 1.5 900 -- python3 $V16/zk60_native_rg_m125.py --bundle $A/tl128dd-l2-dense --stages load,replay,hash,terminals,commitments,boundary,preimage --evidence $P/ff --name ff-v16-tl128dd-l2-dense
# ---- pass A and the validated prediction, all eight
for c in dd-rung-l1 dd-rung-l2; do
  g $Q v17 $c-dense-a 0.5 1.5 1800 -- python3 $M --bundle $A/$c-dense --other $A/$c-zero --stages $PA_RUNG --evidence $P/v17 --name $c-dense-a
  g $Q v17 $c-zero-a 0.5 1.5 1800 -- python3 $M --bundle $A/$c-zero --other $A/$c-dense --stages $PA_RUNG --evidence $P/v17 --name $c-zero-a
done
for c in tl128dd-l1 tl128dd-l2; do
  g $Q v17 $c-dense-a 0.8 1.5 1800 -- python3 $M --bundle $A/$c-dense --other $A/$c-zero --stages $PA_T128 --export $X --evidence $P/v17 --name $c-dense-a
  g $Q v17 $c-zero-a 0.8 1.5 1800 -- python3 $M --bundle $A/$c-zero --other $A/$c-dense --stages $PA_T128 --export $X --evidence $P/v17 --name $c-zero-a
done
for c in dd-rung-l1 dd-rung-l2 tl128dd-l1 tl128dd-l2; do for w in dense zero; do
  g $Q v17 predict-$c-$w 0.5 1.5 1200 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$c-$w --validate $A/$c-$w:$P/v17/$c-$w-a.json --evidence $P/v17 --name prediction-$c-$w-validated
done; done
# ---- the DD tools, all eight
for c in dd-rung-l1 dd-rung-l2 tl128dd-l1 tl128dd-l2; do for w in dense zero; do
  g $Q dd ddnl-$c-$w 0.6 1.5 1800 -- python3 $S/zk60_native_rg_ddnl.py --bundle $A/$c-$w --evidence $P/dd --name ddnl-$c-$w
  g $Q dd ddcontrols-$c-$w 0.6 1.5 1800 -- python3 $S/zk60_native_rg_ddcontrols.py --bundle $A/$c-$w --evidence $P/dd --name ddcontrols-$c-$w
  g $Q dd ddts-$c-$w 1 2 3600 -- python3 $S/zk60_native_rg_ddts.py --bundle $A/$c-$w --evidence $P/dd --name ddts-$c-$w
done; done
# ---- TL controls (TL-5 / TL-6 apply at T128 L = 2)
for b in dd-rung-l2-dense tl128dd-l1-dense tl128dd-l2-dense tl128dd-l2-zero; do
  g $Q controls tl-controls-$b 0.6 1.5 2400 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$b --evidence $P/controls --name tl-controls-$b
done
# ---- export controls (EX-*), with the pass-A record for E4
for c in tl128dd-l1 tl128dd-l2; do
  g $Q controls export-controls-$c-dense 0.8 1.5 1200 -- python3 $S/zk60_native_rg_exportcheck.py --bundle $A/$c-dense --export $X --record $P/v17/$c-dense-a.json --controls --evidence $P/controls --name export-controls-$c-dense
done
# ---- schema over the eight, G-10, the pin controls, the witness comparison
g $Q controls schema-dd 0.5 1.5 900 -- python3 $S/zk60_native_rg_schema.py --bundle $A/dd-rung-l1-dense --bundle $A/dd-rung-l1-zero --bundle $A/dd-rung-l2-dense --bundle $A/dd-rung-l2-zero --bundle $A/tl128dd-l1-dense --bundle $A/tl128dd-l1-zero --bundle $A/tl128dd-l2-dense --bundle $A/tl128dd-l2-zero --controls --evidence $P/controls --name schema-dd
for c in dd-rung-l1 tl128dd-l1 tl128dd-l2; do
  g $Q controls g10-$c 0.8 1.5 1200 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$c-dense --other $A/$c-zero --legacy $V3 --evidence $P/controls --name g10-$c
done
g $Q controls pincontrols-tl128dd-l1-dense 0.8 1.5 2400 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/tl128dd-l1-dense --evidence $P/controls/pincontrols --name pincontrols-tl128dd-l1-dense
g $Q controls witcmp-tl128dd-l2 0.3 1 600 -- python3 $S/zk60_native_rg_witcmp.py --record $P/v17/tl128dd-l2-dense-a.json --label "T128 DD layers 0..2 ho00 (dense)" --witness dense --record $P/v17/tl128dd-l2-zero-a.json --label "T128 DD layers 0..2 all-zero" --witness zero --out $P/controls/witness_comparison_tl128dd_l2.json
# ---- the v17 unit suite in the working copy
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v17.sha256 $GT >> $P/r14_gate_a.toolcheck 2>&1 || { echo "WORKING COPY MOVED" > $P/r14_gate_a.finished; exit 4; }
g $Q suite unittests-v17 0.8 1.5 1200 -- python3 -m unittest discover -s $GT/tests
date -u > $P/r14_gate_a.finished
