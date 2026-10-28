#!/bin/bash
# PRIVACY GATE lane, gate round 14 (DD), queue C (frozen tools v17), added at
# 01:35 UTC: the development DD surjection on T128 L2 hit queue A's
# --max-secs 3600 (stage H alone takes ~1,260 s per stage at T128), so
# queue A's two T128 L2 surjections will time out. Queue A is running and
# its script is not edited. This queue runs, in parallel with it:
#   1. queue A's control tail (TL, export controls, schema, G-10, pin
#      controls, witness comparison) into controls_c/, so it does not wait
#      behind those timeouts (queue A's later copies are duplicates);
#   2. the DD surjection on T128 L2 dense and zero with --max-secs 14400,
#      into dd_long/.
# Declarations from measured peaks plus a margin (ddts T128 L2 1.07 GiB;
# TL 0.33; the rest < 0.8); a hold-file check before each job (EV/HOLD).
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round14/r14_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v17.sha256 $GT/frozen_v17 > $P/r14_gate_c.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r14_gate_c.finished; exit 4; }
Q=r14_gate_c
for b in dd-rung-l2-dense tl128dd-l1-dense tl128dd-l2-dense tl128dd-l2-zero; do
  g $Q controls_c tl-controls-$b 0.6 1.5 2400 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$b --evidence $P/controls_c --name tl-controls-$b
done
for c in tl128dd-l1 tl128dd-l2; do
  g $Q controls_c export-controls-$c-dense 0.8 1.5 1200 -- python3 $S/zk60_native_rg_exportcheck.py --bundle $A/$c-dense --export $X --record $P/v17/$c-dense-a.json --controls --evidence $P/controls_c --name export-controls-$c-dense
done
g $Q controls_c schema-dd 0.5 1.5 900 -- python3 $S/zk60_native_rg_schema.py --bundle $A/dd-rung-l1-dense --bundle $A/dd-rung-l1-zero --bundle $A/dd-rung-l2-dense --bundle $A/dd-rung-l2-zero --bundle $A/tl128dd-l1-dense --bundle $A/tl128dd-l1-zero --bundle $A/tl128dd-l2-dense --bundle $A/tl128dd-l2-zero --controls --evidence $P/controls_c --name schema-dd
for c in dd-rung-l1 tl128dd-l1 tl128dd-l2; do
  g $Q controls_c g10-$c 0.8 1.5 1200 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$c-dense --other $A/$c-zero --legacy $V3 --evidence $P/controls_c --name g10-$c
done
g $Q controls_c pincontrols-tl128dd-l1-dense 0.8 1.5 2400 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/tl128dd-l1-dense --evidence $P/controls_c/pincontrols --name pincontrols-tl128dd-l1-dense
g $Q controls_c witcmp-tl128dd-l2 0.3 1 600 -- python3 $S/zk60_native_rg_witcmp.py --record $P/v17/tl128dd-l2-dense-a.json --label "T128 DD layers 0..2 ho00 (dense)" --witness dense --record $P/v17/tl128dd-l2-zero-a.json --label "T128 DD layers 0..2 all-zero" --witness zero --out $P/controls_c/witness_comparison_tl128dd_l2.json
for w in dense zero; do
  g $Q dd_long ddts-tl128dd-l2-$w 1.5 2.5 14400 -- python3 $S/zk60_native_rg_ddts.py --bundle $A/tl128dd-l2-$w --evidence $P/dd_long --name ddts-tl128dd-l2-$w
done
date -u > $P/r14_gate_c.finished
