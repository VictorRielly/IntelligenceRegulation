#!/bin/bash
# One guarded gpu-class job (second run): K3a, K3b (both shapes) and K4. Raw output goes to k3k4_timing.log (the guard's --log).
R=/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118
B=$R/build
probe() {
  echo "PROBE $1 $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ) gpu_util: $(/usr/sbin/ioreg -r -d 1 -w 0 -c IOAccelerator | /usr/bin/grep -o '"Device Utilization %"=[0-9]*' | /usr/bin/tr '\n' ' ') ds4-bench pids: [$(/usr/bin/pgrep ds4-bench | /usr/bin/tr '\n' ' ')]"
  /usr/bin/uptime
}
echo "== start $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
probe start
echo "== K3 slot 14 shape (68 tables, cap 2^19)"
$B/k3k4_bench k3 $B/k3k4_s14.metal $B/k3k4_s14.prog $B/k3k4_s14.meta 68 19 4 15 3 slot14
echo "rc=$?"
probe after_slot14
echo "== K3 slot 18 shape (33 tables, cap 2^21)"
$B/k3k4_bench k3 $B/k3k4_s18.metal $B/k3k4_s18.prog $B/k3k4_s18.meta 33 21 4 15 3 slot18
echo "rc=$?"
probe after_slot18
echo "== K4 operation costs"
$B/k3k4_bench k4 $B/k3k4_k4.metal 15 3
echo "rc=$?"
probe end
echo "== end $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
