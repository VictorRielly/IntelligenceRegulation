#!/bin/bash
# PRIVACY GATE lane, gate round 19, queue R (frozen tools v22): the REAL Shieldstral-1.0-3B T128 capture
# (classify-r13-shield-t128-cli-sexual-r16b, 26 blocks, public tables as length + digest). Memory-heavy: CPU class
# (heavy lock, alone), need 7.2 / cap 9.0 = the staging dev run's measured peak 5.70 GiB + 25% (coordinator
# 12:00: never light). Declared limits (in the record, never silent): the block slots needing a captured table
# are open by the capture option; the full zero-data preimage runs on a DECLARED SAMPLE (stage IN-C, blocks 0,
# 12 and 25 with the boundaries they open, stage OUT-C with B_out): each block costs ~500 s at 5.7 GiB [MEASURED],
# the other 23 blocks (~3.2 h of a 7 GiB heavy job) are left for the coordinator to schedule. Every other part
# (per commitment, CFS, joint, B-3 from the checkpoint, the 12 classifier slots, NL-1, the block slots covered
# without tables, the controls incl. C-13 at pad 11) runs on all 26 blocks.
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round19/r19_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v22.sha256 $GT/frozen_v22 > $P/r19_gate_r.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r19_gate_r.finished; exit 4; }
lean() {
  while python3 $G status --json | python3 -c "import json,sys; s=json.load(sys.stdin); sys.exit(0 if any(j['need_gib'] > 1.0 for j in s['live_guarded_jobs']) else 1)"; do sleep 30; done
}
lean
NM=classify-r13-shield-t128-cli-sexual-r16b
SAMPLE="A-in@0,H-in@0,E-token-in,A@1,H@1,B0,A@13,H@13,B12,A@26,H@26,B25,A-out@27,H-out@27,B26"
g r19_gate_r v22 v22-$NM cpu 7.2 9.0 10800 -- python3 -B $S/zk60_native_rg_classgate.py --bundle $C/$NM --evidence $P/v22 --name v22-$NM \
  --calibration-export $EX --tied-export $EX --preimage-names $SAMPLE
date -u > $P/r19_gate_r.finished
