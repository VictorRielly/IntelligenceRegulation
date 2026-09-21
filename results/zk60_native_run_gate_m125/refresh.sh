#!/bin/bash
# ROUND 9: every in-scope development bundle re-run under the tools that now
# carry the /5-run loader and finding M-F1's repair, into the SAME evidence
# directory each record of record lives in.  Round 6's command lines,
# unchanged.  What must move: the tool hashes (rg_bundle, rg_terminals,
# rg_runpins, rg_mask and the gate all gained bytes) and the new
# `array_store` block a /4-run bundle reports as "no store to resolve" plus
# the `shared_files` block reporting `pinned: false`.  What must NOT move:
# any rank, disclosed dimension, challenge count, slot check, control figure
# or channel count.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
python3 $G --bundle $B/run-a-tame --other $B/run-b-zero --old $B/run-b-zero --evidence $W/results/zk60_native_run_gate
python3 $G --bundle $B/run-b-zero --other $B/run-a-tame --old $B/run-a-tame --evidence $W/results/zk60_native_run_gate
python3 $G --bundle $B/run-c-tame --other $B/run-d-zero --old $B/run-a-tame --evidence $W/results/zk60_native_run_gate_planeindex
python3 $G --bundle $B/run-d-zero --other $B/run-c-tame --old $B/run-b-zero --evidence $W/results/zk60_native_run_gate_planeindex
python3 $G --bundle $B/run-e-tame-tagged --other $B/run-f-zero-tagged --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $W/results/zk60_native_run_gate_tagged
python3 $G --bundle $B/run-f-zero-tagged --other $B/run-e-tame-tagged --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $W/results/zk60_native_run_gate_tagged
python3 $G --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $W/results/zk60_native_run_gate_s20
python3 $G --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $W/results/zk60_native_run_gate_s20
python3 $G --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $W/results/zk60_native_run_gate_k4
python3 $G --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $W/results/zk60_native_run_gate_k4
