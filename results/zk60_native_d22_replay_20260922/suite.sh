#!/bin/bash
# Round 9d, T6: the TOY gate's own tests and the record guard.
set -x
cd /home/victor/wt-zk60-jointview
date
python3 -m unittest -v tests.test_zk60_native_capture tests.test_zk60_native_gate_record tests.test_zk60_native_joint_view tests.test_zk60_native_mask_commit tests.test_zk60_native_privacy_gate tests.test_zk60_native_terminal_polys tests.test_zk60_native_small_model_groups 2>&1 | tail -40
echo "toy suite exit=${PIPESTATUS[0]}"
date
