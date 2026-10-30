#!/bin/bash
# GPU CLASSIFIER lane (D53), Phase A at real scale: ONE Shieldstral T128 category prove on the CPU path and ONE on the
# GPU path (commitments + openings on the device; `HL_GPU=1 HL_GPU_REQUIRED=1`), both under round 18's FIXED PUBLIC
# entropy job0.bin, each compared byte for byte with round 18's recorded job-0 digests (30 files), each followed by
# ONE fresh-process verify. Steps run one at a time; each heavy step waits for its turn (holds; Astra's app jobs
# astra* / pm-* first) and then for the guard's admission. Never two GPU passes in this script: exactly ONE gpu-class
# step (p-gpu). Test-only receipts (they hide nothing) are deleted after their checks are recorded (D46).
#   1 prepare the public post (Astra's 17-id sentence)                      light
#   2 its activations (Astra's writer, 3 items; only c0 is used)             cpu 1.5 / 3
#   3 p-cpu: CPU-path prove of job 0, HL_PB_TIMING=1, 8 threads              cpu 10.4 / 11.5
#   4 bytes-cpu (before any verify)                                          light
#   5 v-cpu: fresh verify of the CPU receipt by the lane CPU binary, timed   cpu 2.9 / 7
#   6 p-gpu: GPU-path prove of job 0, same entropy, timed, sampler beside    gpu 10.4 / 11.5 (VRAM cap 7,400 MiB)
#   7 bytes-gpu                                                              light
#   8 v-gpu: fresh verify of the GPU receipt by the FROZEN r19b binary       cpu 2.9 / 7
#   9 cleanup (receipts, owner dirs, activations, content ids)
# Marker: logs/pa/phase_a.done = 0 or the failing step.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_classifier_20261030
T=$D/tools
LB=$D/logs/pa
R0=/home/victor/IntelligenceRegulation
G="python3 $R0/scripts/zk60_resource_guard.py run"
EX=$R0/results/zk60_shieldstral_export_20261026/native_low_h24_t128
EXV=$R0/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier
TAB=$EXV/token_io
A5=$R0/results/zk60_astra_20261026/a5_batch_candidate
WRITER=$R0/results/zk60_shieldstral_export_20261026/write_item_activations.py
VENV=$R0/apps/proven-media/.venv/bin/python
A=/home/victor/zk60-artifacts/gpu-classifier
O=/home/victor/zk60-owner-private/gpu-classifier
JOB=$O/batch
ENT=$A/ent/job0.bin
RF=$T/run_fixed.sh
BCPU=$D/bin/zk60_classify.gcl1-cpu.bin
BGPU=$D/bin/zk60_classify.gcl1-gpu.bin
B19B=$R0/results/zk60_token_io_r1_20261017/cli/zk60_classify.r19b.release.bin
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
POL=shieldstral-1.0-3b-moderate-sexual/1
LBL=zk60-classify-verdict
ID=29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1
mkdir -p $LB
step() { echo "$(date -u +%FT%TZ) $1" >> $LB/queue.log; }
turn() { python3 $T/wait_turn.py $LB/queue.log --need "${1:-0}"; }
finish() { echo "$1" > $LB/phase_a.done; step "phase A end $1"; exit 0; }
step "phase A start"
# pins
{ grep zk60_classify.gcl1-cpu.bin $D/bin/binaries.sha256; grep zk60_classify.gcl1-gpu.bin $D/bin/binaries.sha256; echo "6d65d32ea783e36db2458ccce2d459cb29a91bcb45a89c4e23e484914126d609  $B19B"; echo "2e5b0a0c7b784cd4037bdaf0de28b8259074ff4e0a5bf18941af81717c009111  $ENT"; } | sha256sum -c > $LB/pins.log 2>&1 || finish pins
mkdir -p $A/batch $A/cpu $A/gpu
mkdir -m 700 -p $O $O/cpu-owner $O/gpu-owner
# 1. prepare
step prepare
$G --class light --label gcl-prepare --max-secs 300 --log $LB/prepare.log --result-json $LB/prepare.guard.json -- /usr/bin/env PM_PROVER=shieldstral $VENV -B -c "import sys; sys.path.insert(0, sys.argv[1]); import batch_request as b; plan=b.proof_plans.category_work_plan(17, b.runtime.templates()); m=b.prepare_text('a5eq', 'Today I planted basil and watered the garden. The afternoon was quiet and sunny.', plan, sys.argv[2], sys.argv[3], reserved_context=b.records.screening_context()); print(len(m['jobs']), m['content_total'])" $A5 $JOB $A/batch
grep -qx "3 17" $LB/prepare.log || finish prepare
# 2. activations
turn 1.5; step activations
$G --class cpu --need-gib 1.5 --cap-gib 3 --label gcl-act --wait-secs 14400 --max-secs 1800 --log $LB/act.log --done $LB/act.guard.done --result-json $LB/act.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 $VENV -B $WRITER --request $JOB/activation-request.json --out $JOB/activations
echo $? > $LB/act.exit
[ "$(cat $LB/act.exit)" = "0" ] || finish activations
# 3. the CPU-path prove
turn 10.4; step p-cpu
python3 $R0/scripts/zk60_resource_guard.py status > $LB/p-cpu.status.txt 2>&1
$G --class cpu --need-gib 10.4 --cap-gib 11.5 --label gcl-p-cpu --wait-secs 14400 --max-secs 1800 --log $LB/p-cpu.log --done $LB/p-cpu.guard.done --result-json $LB/p-cpu.guard.json -- bash $RF $ENT -- /usr/bin/env -u ZK60_MODELS HL_PB_TIMING=1 RAYON_NUM_THREADS=8 $BCPU prove --export $EX --tables $TAB --policy $POL --content-file $JOB/content.ids --chunk 0 --seq-dir $JOB/activations/c0 --out $A/cpu/c0 --owner-dir $O/cpu-owner/c0 --label $LBL
echo $? > $LB/p-cpu.exit
[ "$(cat $LB/p-cpu.exit)" = "0" ] || { python3 $T/cleanup_gcl.py $LB/cleanup-cpu.json $A/cpu $O/cpu-owner > $LB/cleanup-cpu.log 2>&1; finish p-cpu; }
# 4. bytes (before the verify: verify publishes into the run directory)
step bytes-cpu
python3 $T/compare_gcl.py $A/cpu/c0 $O/cpu-owner/c0 $LB/bytes-cpu.json cpu-path > $LB/bytes-cpu.log 2>&1
echo $? > $LB/bytes-cpu.exit
# 5. a fresh verify, timed
turn 2.9; step v-cpu
$G --class cpu --need-gib 2.9 --cap-gib 7 --label gcl-v-cpu --wait-secs 14400 --max-secs 1800 --log $LB/v-cpu.log --done $LB/v-cpu.guard.done --result-json $LB/v-cpu.guard.json -- /usr/bin/env -u ZK60_MODELS HL_PB_TIMING=1 RAYON_NUM_THREADS=8 $BCPU verify --export $EXV --tables $TAB --policy $POL --label $LBL --expect-statement $ID --min-bits 95 --artifact $A/cpu/c0
echo $? > $LB/v-cpu.exit
python3 $T/cleanup_gcl.py $LB/cleanup-cpu.json $A/cpu $O/cpu-owner > $LB/cleanup-cpu.log 2>&1
[ "$(cat $LB/bytes-cpu.exit)" = "0" ] || finish bytes-cpu
[ "$(cat $LB/v-cpu.exit)" = "0" ] || finish v-cpu
# 6. the GPU-path prove (the ONE gpu-class step of this script), the sampler beside it
turn 10.4; step p-gpu
python3 $R0/scripts/zk60_resource_guard.py status > $LB/p-gpu.status.txt 2>&1
setsid nohup bash $T/gpu_sampler.sh $LB/p-gpu.guard.done $LB/p-gpu.gpu.csv >/dev/null 2>&1 &
$G --class gpu --need-gib 10.4 --cap-gib 11.5 --label gcl-p-gpu --wait-secs 14400 --max-secs 1800 --log $LB/p-gpu.log --done $LB/p-gpu.guard.done --result-json $LB/p-gpu.guard.json -- bash $RF $ENT -- /usr/bin/env -u ZK60_MODELS HL_PB_TIMING=1 HL_GPU=1 HL_GPU_REQUIRED=1 HL_ZK_CHUNK=force RAYON_NUM_THREADS=8 LD_LIBRARY_PATH=$LD $BGPU prove --export $EX --tables $TAB --policy $POL --content-file $JOB/content.ids --chunk 0 --seq-dir $JOB/activations/c0 --out $A/gpu/c0 --owner-dir $O/gpu-owner/c0 --label $LBL
echo $? > $LB/p-gpu.exit
[ -f $LB/p-gpu.guard.done ] || echo "no guard marker" > $LB/p-gpu.guard.done
[ "$(cat $LB/p-gpu.exit)" = "0" ] || { python3 $T/cleanup_gcl.py $LB/cleanup-gpu.json $A/gpu $O/gpu-owner > $LB/cleanup-gpu.log 2>&1; finish p-gpu; }
# 7. bytes
step bytes-gpu
python3 $T/compare_gcl.py $A/gpu/c0 $O/gpu-owner/c0 $LB/bytes-gpu.json gpu-path > $LB/bytes-gpu.log 2>&1
echo $? > $LB/bytes-gpu.exit
# 8. a fresh verify of the GPU-made receipt by the frozen production CPU binary
turn 2.9; step v-gpu
$G --class cpu --need-gib 2.9 --cap-gib 7 --label gcl-v-gpu --wait-secs 14400 --max-secs 1800 --log $LB/v-gpu.log --done $LB/v-gpu.guard.done --result-json $LB/v-gpu.guard.json -- /usr/bin/env -u ZK60_MODELS RAYON_NUM_THREADS=8 $B19B verify --export $EXV --tables $TAB --policy $POL --label $LBL --expect-statement $ID --min-bits 95 --artifact $A/gpu/c0
echo $? > $LB/v-gpu.exit
# 9. cleanup
python3 $T/cleanup_gcl.py $LB/cleanup-gpu.json $A/gpu $O/gpu-owner > $LB/cleanup-gpu.log 2>&1
python3 $T/cleanup_gcl.py $LB/cleanup-inputs.json $A/batch $JOB > $LB/cleanup-inputs.log 2>&1
[ "$(cat $LB/bytes-gpu.exit)" = "0" ] || finish bytes-gpu
[ "$(cat $LB/v-gpu.exit)" = "0" ] || finish v-gpu
finish 0
