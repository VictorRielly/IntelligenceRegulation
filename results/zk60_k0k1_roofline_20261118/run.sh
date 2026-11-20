#!/bin/bash
# One guarded gpu-class job: the whole K1 (slots 14 and 18) and K0 timing sequence. Raw output goes to timing.log
# (the guard's --log). The pollution probes (other GPU users, ds4-bench) are sampled before, between and after.
R=/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118
B=$R/build
probe() {
  echo "PROBE $1 $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ) gpu_util: $(/usr/sbin/ioreg -r -d 1 -w 0 -c IOAccelerator | /usr/bin/grep -o '"Device Utilization %"=[0-9]*' | /usr/bin/tr '\n' ' ') ds4-bench pids: [$(/usr/bin/pgrep ds4-bench | /usr/bin/tr '\n' ' ')]"
  /usr/bin/uptime
}
echo "== start $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
probe start
echo "== K1 slot 14 shape (68 tables, cap 2^19), v13 / k1 / k1b interleaved"
$B/bench k1 $B/s14.metal $B/s14.tabs 68 19 4 15 3 slot14
echo "rc=$?"
probe after_slot14
echo "== K1 slot 18 shape (33 tables, cap 2^21)"
$B/bench k1 $B/s18.metal $B/s18.tabs 33 21 4 15 3 slot18
echo "rc=$?"
probe after_slot18
echo "== K0 fold and copy at slot 18 window-1 shape"
$B/bench k0 $B/k0.metal 15 3
echo "rc=$?"
probe end
echo "== end $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
