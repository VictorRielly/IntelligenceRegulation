#!/bin/bash
# One guarded gpu-class job (third run): K5a/b/c on the two Shieldstral shapes, K5d on the two W16R2_8B shapes, K5e round 0.
# Raw output goes to k5_timing.log (the guard's --log).
R=/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118
B=$R/build
probe() {
  echo "PROBE $1 $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ) gpu_util: $(/usr/sbin/ioreg -r -d 1 -w 0 -c IOAccelerator | /usr/bin/grep -o '"Device Utilization %"=[0-9]*' | /usr/bin/tr '\n' ' ') ds4-bench pids: [$(/usr/bin/pgrep ds4-bench | /usr/bin/tr '\n' ' ')]"
  /usr/bin/uptime
}
echo "== start $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
probe start
# args: lib meta ntabs nxtabs log_cap np D1 reps warm label round0
echo "== Shieldstral R13 slot 14 (68 tables, 2^19)"
$B/k5_bench $B/k5_s14.metal $B/k5_s14.meta 68 0 19 4 6 15 3 sh14 0
echo "rc=$?"
probe after_sh14
echo "== Shieldstral R13 slot 18 (33 tables, 2^21)"
$B/k5_bench $B/k5_s18.metal $B/k5_s18.meta 33 0 21 4 6 15 3 sh18 0
echo "rc=$?"
probe after_sh18
echo "== W16R2_8B slot 14 (36 + 3 tables, 2^19, SC_D 4)"
$B/k5_bench $B/k5_b14.metal $B/k5_b14.meta 36 3 19 4 5 15 3 b14 0
echo "rc=$?"
probe after_b14
echo "== W16R2_8B slot 18 (19 + 3 tables, 2^21, SC_D 5)"
$B/k5_bench $B/k5_b18.metal $B/k5_b18.meta 19 3 21 4 6 15 3 b18 0
echo "rc=$?"
probe after_b18
echo "== W16R2_8B slot 18 round 0 (19 + 3 tables, 2^21)"
$B/k5_bench $B/k5_b18r0.metal $B/k5_b18r0.meta 19 3 21 4 6 15 3 b18r0 1
echo "rc=$?"
probe end
echo "== end $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
