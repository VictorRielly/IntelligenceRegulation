set -x
W=/home/victor/wt-zk60-jointview
C=$W/results/zk60_native_captures_20260919
python3 $W/scripts/zk60_native_privacy_gate.py --captures $C --evidence $W/results/zk60_native_privacy_gate --columns full --controls-on all
python3 $W/scripts/zk60_native_privacy_gate.py --captures $C --evidence $W/results/zk60_native_privacy_gate_channels --columns full --controls-on all
python3 $W/scripts/zk60_native_joint_view.py --captures $C --evidence $W/results/zk60_native_joint_view
