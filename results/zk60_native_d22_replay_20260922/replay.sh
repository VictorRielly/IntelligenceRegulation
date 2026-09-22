#!/bin/bash
# Round 9d: the toy joint gate replayed on the integrator's new-tree bundle.
# The commands are the ones the D22 record of record was produced with
# (results/zk60_native_privacy_gate/README.md, .../zk60_native_privacy_gate_channels/README.md,
#  scripts/zk60_native_joint_view.py's own header), with only --captures and
# --evidence pointed at this round's bundle and evidence.
set -x
E=/home/victor/wt-zk60-jointview/results/zk60_native_d22_replay_20260922
S=/home/victor/wt-zk60-jointview/scripts
AS_DELIVERED=/home/victor/IntelligenceRegulation/results/zk60_security_probe_repin_20260922

date

# 1. the P10 privacy gate on the staged bundle (the manifest check fires)
python3 $S/zk60_native_privacy_gate.py \
  --captures $E/bundle \
  --evidence $E/p10_staged \
  --columns full --controls-on all
echo "p10_staged exit=$?"

# 2. the same gate straight at the integrator's directory, nothing staged:
#    a control on the shim -- every figure must be identical
python3 $S/zk60_native_privacy_gate.py \
  --captures $AS_DELIVERED \
  --evidence $E/p10_as_delivered \
  --columns full --controls-on all
echo "p10_as_delivered exit=$?"

# 3. the native joint-view gate, eight stages
python3 $S/zk60_native_joint_view.py \
  --captures $E/bundle \
  --evidence $E/jointview_staged
echo "jointview_staged exit=$?"

python3 $S/zk60_native_joint_view.py \
  --captures $AS_DELIVERED \
  --evidence $E/jointview_as_delivered
echo "jointview_as_delivered exit=$?"

date
