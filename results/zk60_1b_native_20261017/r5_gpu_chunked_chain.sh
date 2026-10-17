#!/bin/bash
# NATIVE LANE task 3, GPU arm under the 4 GiB VRAM limit (coordinator,
# 21:53 UTC): the T64 resident-path run peaked at 4,417 MiB. After the task-3
# chain has ended (its T128 GPU step fails at exec: lib-test.gpu was made
# non-executable), re-enable the binary and run, one GPU pass per guarded
# command, (1) T64 with the chunked commit forced (HL_ZK_CHUNK=force: the
# encoded matrices are never resident; the proof bytes are the resident
# path's per cuda.rs), then (2) T128 forced ONLY IF 2 x the T64 peak VRAM is
# at most 4096 MiB (a conservative projection: T128's resident rows are about
# twice T64's).
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
until [ -f $D/r5_t3_chain.done ]; do sleep 20; done
chmod a+x $D/r5/ladder8b-testbin/lib-test.gpu
$D/r5_ladder_chunked.sh 64 gpu 3 6
P=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('peak_vram_mib') or 99999)" $D/r5/ladder8b-T64-gpu-chunked/prove.guard.json 2>/dev/null || echo 99999)
echo "T64 chunked peak VRAM ${P} MiB"
if [ "$P" -le 2048 ]; then
  $D/r5_ladder_chunked.sh 128 gpu 5 8
  echo "T128 chunked done; peak VRAM $(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('peak_vram_mib'))" $D/r5/ladder8b-T128-gpu-chunked/prove.guard.json 2>/dev/null)"
else
  echo "T128 GPU arm SKIPPED: 2 x ${P} MiB > 4096 MiB (lane VRAM limit)"
fi
chmod a-x $D/r5/ladder8b-testbin/lib-test.gpu
