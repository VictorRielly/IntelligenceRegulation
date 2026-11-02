#!/bin/bash
# W16R2 (D59) A/B on ONE binary (the gate chain's): W16 against W16R2 at 8B T128. Every leaf guarded (gpu
# class, one shared heavy lock), one process per arm set (Metal concurrency and compiles: M10), HL_PB_ORACLE=0.
#  1. ab:        the block core, warm n = 5 per arm, interleaved, verify n = 3, bytes; HL_METAL_TIMING unset
#  2. ab-rev:    the same with the arm order reversed (a drift check)
#  3. ab-gpu:    HL_METAL_TIMING=1, warm n = 2: the GPU commit attribution only (its timings are not compared)
#  4. d55-*:     one request, 32 blocks, D12a serial and D55 forks N = 6, two warm passes, W16 and W16R2 in
#                ABBA order (the D55 A/B harness, synthetic diagonal weights)
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ac8a2b43086591196
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_20261101/logs/ab
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
B=${1:-$(cat $R/results/zk60_w16r2_20261101/logs/chain/binary.path)}
AB=private_block::w16r2_tests::w16r2_ab_w16_against_w16r2_on_one_binary
D55=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
mkdir -p $L
step() { echo "== $1 $(date +%H:%M:%S)"; }
P=$L/prior-$(date +%Y%m%dT%H%M%S); for f in $L/m_*; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done
echo "B=$B"; shasum -a 256 $B

step ab
$G --class gpu --need-gib 60 --cap-gib 160 --label w16r2-ab --wait-secs 7200 --max-secs 3000 --log $L/m_ab.log --done $L/m_ab.done -- \
  env HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_W16R2_AB=W16_8B_T128_H24,W16R2_8B_T128_H24 HL_W16R2_AB_WARM=5 HL_W16R2_AB_VERIFY=3 $B --ignored --exact $AB --nocapture --test-threads=1
grep -h "W16R2-AB\|test result\|panicked" $L/m_ab.log | cut -c1-500
sleep 10
step ab-rev
$G --class gpu --need-gib 60 --cap-gib 160 --label w16r2-ab-rev --wait-secs 7200 --max-secs 3000 --log $L/m_ab_rev.log --done $L/m_ab_rev.done -- \
  env HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_W16R2_AB=W16R2_8B_T128_H24,W16_8B_T128_H24 HL_W16R2_AB_WARM=5 HL_W16R2_AB_VERIFY=3 $B --ignored --exact $AB --nocapture --test-threads=1
grep -h "W16R2-AB\|test result\|panicked" $L/m_ab_rev.log | cut -c1-500
sleep 10
step ab-gpu
$G --class gpu --need-gib 60 --cap-gib 160 --label w16r2-ab-gpu --wait-secs 7200 --max-secs 3000 --log $L/m_ab_gpu.log --done $L/m_ab_gpu.done -- \
  env HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_METAL_TIMING=1 HL_W16R2_AB=W16_8B_T128_H24,W16R2_8B_T128_H24 HL_W16R2_AB_WARM=2 HL_W16R2_AB_VERIFY=1 $B --ignored --exact $AB --nocapture --test-threads=1
grep -h "W16R2-AB SUMMARY\|ZK60-METAL\] commit\|test result\|panicked" $L/m_ab_gpu.log | cut -c1-300 | tail -40
for arm in W16_8B_T128_H24:w16a W16R2_8B_T128_H24:r2a W16R2_8B_T128_H24:r2b W16_8B_T128_H24:w16b; do
  p=${arm%%:*}; t=${arm##*:}
  sleep 10
  step d55-$t
  $G --class gpu --need-gib 80 --cap-gib 180 --label w16r2-d55-$t --wait-secs 7200 --max-secs 5400 --log $L/m_d55_$t.log --done $L/m_d55_$t.done -- \
    env HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_R13_LOADER_FIXTURES=$F HL_D55_PROFILE=$p HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 \
    $B --ignored --exact $D55 --nocapture --test-threads=1
  grep -h "D55-AB\|test result\|panicked" $L/m_d55_$t.log | cut -c1-400
done
step done
