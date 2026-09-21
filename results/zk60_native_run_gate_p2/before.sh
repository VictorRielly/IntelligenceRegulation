#!/bin/bash
# ROUND 9b: every record of record as the REPOSITORY has it, taken BEFORE
# the refresh, so the leaf diff compares against COMMITTED bytes and not
# against a file some other run overwrote.  The working tree is dirty with
# records written by round 9's own detached jobs across this round's tool
# edits; `git show HEAD:` is the only trustworthy baseline.
set -x
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_p2/before
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
# rounds 7 and 8's own evidence, which pins tool digests this round moved
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
