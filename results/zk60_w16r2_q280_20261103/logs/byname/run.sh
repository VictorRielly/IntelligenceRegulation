set -u
B=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7e40cbdbbf3f1b5d/ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-7ba0d0401b32d774
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
O=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7e40cbdbbf3f1b5d/results/zk60_w16r2_q280_20261103/logs/byname
run() { local name=$1; shift; echo "-- $name $(date +%H:%M:%S)"; "$@" > $O/$name.log 2>&1; echo $? > $O/$name.exit; echo "   exit $(cat $O/$name.exit)"; }
run bytes_default env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
run bytes_tail0 env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_METAL_BATCH_TAIL_US=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
run r2rung_default env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
run r2rung_tail0 env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_METAL_BATCH_TAIL_US=0 $B --ignored --exact --nocapture --test-threads=1 private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
run trained env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24,W16R2_RUNG_H24 $B --ignored --exact --nocapture --test-threads=1 $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
run pg_metal_rung env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_R13_LOADER_FIXTURES=$F $B --ignored --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16r2_privacy_gate_on_the_metal_path
run pg_metal_8b env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_W16PG_PROFILES=W16R2_8B_T128_H24 HL_R13_LOADER_FIXTURES=$F $B --ignored --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16r2_privacy_gate_on_the_metal_path
run pg_cpu_8b env HL_W16PG_PROFILES=W16R2_8B_T128_H24 HL_W16PG_PAIR=1 HL_R13_LOADER_FIXTURES=$F $B --ignored --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16_privacy_gate_at_the_trained_t128_shapes
run pg_cpu_rung env HL_R13_LOADER_FIXTURES=$F $B --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16r2_privacy_gate_at_the_development_rung
run pg_d55_rung env HL_R13_LOADER_FIXTURES=$F $B --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::d55_fork_run_capture_passes_the_w16_gate_checks_at_the_w16r2_rung
run r2run env HL_GPU=1 HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_R13_LOADER_FIXTURES=$F HL_D55_PROFILE=W16R2_RUNG_H24 HL_D55_L=3 HL_D55_WORKERS=2 HL_D55_PASSES=1 $B --ignored --exact private_block::run::fork::tests::d55_ab_one_request_serial_against_forks --nocapture --test-threads=1
exit 0
