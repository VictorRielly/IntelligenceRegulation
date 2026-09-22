#!/bin/bash
# Round 9e, S4 + S5.
#
#   1-3  the RE-PIN: the three guarded records re-taken with the documented
#        commands, because the tool's bytes changed and every record names
#        them (`tool_sha256`).  The commands are the ones each evidence
#        directory's own README / the gate's own header give, unchanged.
#   4-5  the round-9d replay ONCE more with the fixed tool, straight at the
#        integrator's directory and with NO shim: the manifest check must now
#        fire on its own.
#
# Nothing in the integrator's directory is written, renamed or staged.
set -x
E=/home/victor/wt-zk60-jointview/results/zk60_native_manifest_check_20260922
S=/home/victor/wt-zk60-jointview/scripts
R=/home/victor/wt-zk60-jointview/results
C=$R/zk60_native_captures_20260919
AS_DELIVERED=/home/victor/IntelligenceRegulation/results/zk60_security_probe_repin_20260922

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

python3 $S/zk60_native_privacy_gate.py \
  --captures $AS_DELIVERED --evidence $E/p10_as_delivered_fixed \
  --columns full --controls-on all
echo "p10_as_delivered_fixed exit=$?"

python3 $S/zk60_native_joint_view.py \
  --captures $AS_DELIVERED --evidence $E/jointview_as_delivered_fixed
echo "jointview_as_delivered_fixed exit=$?"

date
