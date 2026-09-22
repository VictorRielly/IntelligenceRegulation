#!/bin/bash
# Round 9f, T4: the RE-PIN.  Three tool digests move -- the two gates, each of
# which now calls the new manifest-pin check, and the check's own new file,
# which both gates list in their `TOOLS` table -- so every record that names
# them is re-taken with the command in its own README, unchanged.
#
# Nothing else is run: this round touches no bundle, copies nothing and reads
# the integrator's directory not at all.
set -x
S=/home/victor/wt-zk60-jointview/scripts
R=/home/victor/wt-zk60-jointview/results
C=$R/zk60_native_captures_20260919

date

python3 $S/zk60_native_privacy_gate.py \
  --captures $C --evidence $R/zk60_native_privacy_gate \
  --columns full --controls-on all
echo "repin_p10 exit=$?"

python3 $S/zk60_native_privacy_gate.py \
  --captures $C --evidence $R/zk60_native_privacy_gate_channels \
  --columns full --controls-on all
echo "repin_channels exit=$?"

python3 $S/zk60_native_joint_view.py \
  --captures $C --evidence $R/zk60_native_joint_view
echo "repin_jointview exit=$?"

date
