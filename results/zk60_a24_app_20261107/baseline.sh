#!/bin/bash
# Lane A24 baseline (one guarded gpu-class job): the current tree's zk60_classify `prove` + fresh
# `verify` of the public garden sentence, sexual category, all cores; once on the CPU (HL_GPU=0)
# and once with the Metal GPU (HL_GPU=1). HL_PB_TIMING=1 keeps the CLI's phase lines.
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5090f993c1401215
REPO=/Users/victorrielly/IntelligenceRegulation
R=$WT/results/zk60_a24_app_20261107
BIN=$WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify
EXP=$REPO/results/zk60_shieldstral_export_20261026/native_low_h24_t128
VEXP=$REPO/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier
PRIV=/Users/victorrielly/zk60-owner-private/a24-media-app-20261107
PUB=/Users/victorrielly/zk60-artifacts/a24-media-app-20261107
PY=/private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python
WRITER=$REPO/results/zk60_astra_20261026/a3_mac_writer_20261105/write_item_activations.py
POL=shieldstral-1.0-3b-moderate-sexual/1
export ZK60_MODELS=$REPO/results/zk60_astra_20261026/flashprove_runtime_20261104/models
export HL_PB_ORACLE=0 HL_PB_TIMING=1 HL_GPU_REQUIRED=0
TAG=${1:-b1}
say() { echo "[$(date -u +%H:%M:%S)] $*" | tee -a $R/baseline_$TAG.progress; }
pgrep ds4-bench >/dev/null && say "WARNING ds4-bench running (POLLUTED)"
now() { python3 -c "import time;print(f\"{time.time():.3f}\")"; }
sha256sum_bin() { shasum -a 256 "$1" | cut -d' ' -f1; }
say "binary sha256 $(sha256sum_bin $BIN)"
if [ ! -d $PRIV/garden-act ]; then
  t0=$(now)
  /usr/bin/env OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 VECLIB_MAXIMUM_THREADS=2 $PY $WRITER --request $PRIV/garden-act-request.json --out $PRIV/garden-act > $R/baseline_${TAG}_writer.log 2>&1
  say "writer rc=$? seconds=$(echo "$(now) - $t0" | bc)"
fi
for MODE in cpu gpu; do
  if [ $MODE = gpu ]; then export HL_GPU=1; else export HL_GPU=0; fi
  OUT=$PUB/base-$TAG-$MODE
  OWN=$PRIV/base-$TAG-$MODE-owner
  t0=$(now)
  $BIN prove --export $EXP --tables $VEXP/token_io --policy $POL --label zk60-classify-verdict \
    --content-file $PRIV/garden.ids --chunk 0 --seq-dir $PRIV/garden-act/sexual-c0 --out $OUT --owner-dir $OWN \
    > $R/baseline_${TAG}_${MODE}_prove.log 2>&1
  say "$MODE prove rc=$? wall=$(echo "$(now) - $t0" | bc)"
  ID=$(grep -o '"trained_statement_identity":"[0-9a-f]*"' $R/baseline_${TAG}_${MODE}_prove.log | head -1 | cut -d'"' -f4)
  say "$MODE identity $ID"
  t0=$(now)
  $BIN verify --export $VEXP --tables $VEXP/token_io --policy $POL --label zk60-classify-verdict \
    --artifact $OUT --expect-statement $ID --min-bits 95 > $R/baseline_${TAG}_${MODE}_verify.log 2>&1
  say "$MODE verify rc=$? wall=$(echo "$(now) - $t0" | bc)"
done
pgrep ds4-bench >/dev/null && say "WARNING ds4-bench running at end (POLLUTED)"
say "done"
