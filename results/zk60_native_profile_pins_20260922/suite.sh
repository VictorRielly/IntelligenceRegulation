#!/bin/bash
# Round 9h, U5: the TOY gate's seven modules and the record guard, after the
# re-pin.  Queued on the same heavy lock as run.sh, so it self-starts when the
# re-pin is done.  Same command as round 9f's suite.sh, one module list.
set -x
cd /home/victor/wt-zk60-jointview
date
python3 -m unittest tests.test_zk60_native_capture tests.test_zk60_native_gate_record tests.test_zk60_native_joint_view tests.test_zk60_native_mask_commit tests.test_zk60_native_privacy_gate tests.test_zk60_native_terminal_polys tests.test_zk60_native_small_model_groups 2>&1 | tail -20
echo "toy suite exit=${PIPESTATUS[0]}"
python3 -m unittest -v tests.test_zk60_native_gate_record 2>&1 | tail -45
echo "record guard exit=${PIPESTATUS[0]}"
date
