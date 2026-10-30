#!/bin/bash
# GPU CLASSIFIER lane (D53), the RUNG first (cheap): the lane's gpu-cuda test binary runs ONE development-rung
# classifier single prove under FIXED PUBLIC entropy (job0.bin, 64 bytes) and prints the SHA-256 of every file it
# wrote, then verifies the receipt in-process. Run 1: the CPU path (HL_GPU unset). Run 2: the GPU path (HL_GPU=1
# HL_GPU_REQUIRED=1), the ONE gpu-class step of this script. Then the two digest lists are compared.
# usage: rung.sh <test binary>      marker: logs/rung/rung.done = 0 or the failing step
set -u
TB=$1
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_classifier_20261030
T=$D/tools
LB=$D/logs/rung
R0=/home/victor/IntelligenceRegulation
G="python3 $R0/scripts/zk60_resource_guard.py run"
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-classifier/hashline
A=/home/victor/zk60-artifacts/gpu-classifier
FX=$A/fixtures
LF=$R0/results/zk60_1b_native_20261017/r13/loader-fixtures
ENT=$A/ent/job0.bin
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
TEST=private_block::token_io::classify_cli::batch::r18::gcl_rung_single_prove_digests_under_fixed_entropy
mkdir -p $LB $FX
step() { echo "$(date -u +%FT%TZ) $1" >> $LB/queue.log; }
turn() { python3 $T/wait_turn.py $LB/queue.log --need "${1:-0}"; }
finish() { echo "$1" > $LB/rung.done; step "rung end $1"; exit 0; }
step "rung start ($TB)"
turn 1.0; step rung-cpu
$G --class cpu --need-gib 1.0 --cap-gib 2.5 --label gcl-rung-cpu --wait-secs 14400 --max-secs 600 --log $LB/rung-cpu.log --done $LB/rung-cpu.guard.done --result-json $LB/rung-cpu.guard.json -- bash $T/run_fixed.sh $ENT -- /usr/bin/env -C $H TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF HL_R18_FIXED_ENTROPY=gcl64 LD_LIBRARY_PATH=$LD $TB $TEST --exact --ignored --nocapture --test-threads=1
echo $? > $LB/rung-cpu.exit
[ "$(cat $LB/rung-cpu.exit)" = "0" ] || finish rung-cpu
turn 1.5; step rung-gpu
setsid nohup bash $T/gpu_sampler.sh $LB/rung-gpu.guard.done $LB/rung-gpu.gpu.csv >/dev/null 2>&1 &
$G --class gpu --need-gib 1.5 --cap-gib 3 --label gcl-rung-gpu --wait-secs 14400 --max-secs 600 --log $LB/rung-gpu.log --done $LB/rung-gpu.guard.done --result-json $LB/rung-gpu.guard.json -- bash $T/run_fixed.sh $ENT -- /usr/bin/env -C $H TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$LF HL_R18_FIXED_ENTROPY=gcl64 HL_GPU=1 HL_GPU_REQUIRED=1 LD_LIBRARY_PATH=$LD $TB $TEST --exact --ignored --nocapture --test-threads=1
echo $? > $LB/rung-gpu.exit
[ -f $LB/rung-gpu.guard.done ] || echo "no guard marker" > $LB/rung-gpu.guard.done
python3 $T/cleanup_gcl.py $LB/cleanup.json $FX > $LB/cleanup.log 2>&1
[ "$(cat $LB/rung-gpu.exit)" = "0" ] || finish rung-gpu
step compare
python3 -c "
import sys, json
def lines(f): return sorted(l.strip() for l in open(f) if l.startswith('GCL-RUNG |') and ('| receipt |' in l or '| statement |' in l or '| owner |' in l))
a, b = lines(sys.argv[1]), lines(sys.argv[2])
be = [l.strip() for l in open(sys.argv[2]) if l.startswith('GCL-RUNG | backend')]
ok = len(a) > 2 and a == b
json.dump({'ok': ok, 'files': len(a), 'cpu': a, 'gpu': b, 'gpu_backend': be}, open(sys.argv[3], 'w'), indent=1)
print('rung byte identity', 'OK' if ok else 'DIFFERS', len(a), 'files', be); sys.exit(0 if ok else 1)
" $LB/rung-cpu.log $LB/rung-gpu.log $LB/rung-bytes.json > $LB/compare.log 2>&1 || finish compare
finish 0
