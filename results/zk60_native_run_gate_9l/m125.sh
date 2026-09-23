#!/bin/bash
# ROUND 9l: the new code at 125M, CHEAPLY -- the staged driver on each
# standalone 125M block bundle with only the stages that read what this
# round changed: load, replay, the per-commitment views (stage 3: the exact
# u-term, the sixteen-clause H-pair on A / H / both endpoints, and the 23
# per-clause controls) and stage 4 (the whole block, with the exact joint
# u-term).  No terminals, no arms, no run controls, and NOT an everything
# pass.  Two NEW records; the 125M records of rounds 9j and 9k are not
# touched.
set -x
M=/home/victor/zk60-artifacts/block-captures-20260923
W=/home/victor/wt-zk60-jointview
D=$W/scripts/zk60_native_rg_m125.py
E=$W/results/zk60_native_run_gate_9l
S="load,replay,commitments,boundary"
/usr/bin/time -v python3 $D --bundle $M/m125-dense --stages $S --evidence $E --name block-m125-dense-gc2 2> $E/time-block-m125-dense-gc2.log
/usr/bin/time -v python3 $D --bundle $M/m125-zero --stages $S --evidence $E --name block-m125-zero-gc2 2> $E/time-block-m125-zero-gc2.log
