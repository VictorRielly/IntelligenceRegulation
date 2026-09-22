#!/bin/bash
# ROUND 9c, the SECOND refresh: the committed bytes of every record of
# record, taken before it is re-run.  The first refresh missed two things
# and a third moved after it: the rung-P2 pair (round 9b's own records,
# whose `test_the_evidence_came_from_the_tool_bytes_now_in_the_tree` is
# what caught it), the six records THIS round produced, and one more edit
# to `rg_runpins` -- the `run_capture.rs` and `boundary.rs` entries gained
# the three new commits and six new bundles, which finding E32-F1's
# machine assertion needs.  TWENTY-SIX records, one baseline.
set -x
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_9c/before2
mkdir -p $D
for p in \
  zk60_native_run_gate/run-a-tame \
  zk60_native_run_gate/run-b-zero \
  zk60_native_run_gate_planeindex/run-c-tame \
  zk60_native_run_gate_planeindex/run-d-zero \
  zk60_native_run_gate_tagged/run-e-tame-tagged \
  zk60_native_run_gate_tagged/run-f-zero-tagged \
  zk60_native_run_gate_s20/run-g-dense-s20 \
  zk60_native_run_gate_s20/run-h-zero-s20 \
  zk60_native_run_gate_k4/run-i-dense-k4 \
  zk60_native_run_gate_k4/run-j-zero-k4 ; do
  git --no-pager -C $W show "HEAD:results/$p.json" > "$D/$(basename $p).json"
done
for p in \
  zk60_native_run_gate_preimage/run-g-dense-s20 \
  zk60_native_run_gate_preimage/run-h-zero-s20 \
  zk60_native_run_gate_preimage/run-i-dense-k4 \
  zk60_native_run_gate_preimage/run-j-zero-k4 ; do
  git --no-pager -C $W show "HEAD:results/$p.json" > "$D/pre-$(basename $p).json"
done
for p in \
  zk60_native_run_gate_mask/run-g-dense-s20 \
  zk60_native_run_gate_mask/run-h-zero-s20 \
  zk60_native_run_gate_mask/run-i-dense-k4 \
  zk60_native_run_gate_mask/run-j-zero-k4 ; do
  git --no-pager -C $W show "HEAD:results/$p.json" > "$D/mask-$(basename $p).json"
done
# round 9b's own two, missed by the first refresh
for p in run-k-dense-p2 run-l-zero-p2 ; do
  git --no-pager -C $W show "HEAD:results/zk60_native_run_gate_p2/$p.json" > "$D/$p.json"
done
# round 9c's own six
for p in run-m-dense-c6 run-n-zero-c6 run-o-dense-w14 run-p-zero-w14 run-q-dense-e32 run-r-zero-e32 ; do
  git --no-pager -C $W show "HEAD:results/zk60_native_run_gate_9c/$p.json" > "$D/$p.json"
done
