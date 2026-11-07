#!/bin/bash
# Lane A28, byte-identity job (one guarded gpu-class job): A27's pinned binary (A) and this lane's candidate
# (B; and B0, the same binary with every A28 switch OFF) prove one public post's three categories under FIXED
# PUBLIC TEST ENTROPY (A26's fixed_entropy.c interposer, macOS); every receipt file is compared byte for byte
# across the runs (A twice: the harness's own determinism control); then each verifier checks the other
# binaries' receipts (verify + input-owner + label). Every server with HL_METAL_QUEUES=thread (the app's pin).
# usage: bi.sh <tag> <B binary> [extra B env, K=V ...]
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a24_app_20261107/posts
A=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a27
TAG=$1; B=$2; shift 2
BENV=""
for kv in "$@"; do BENV="$BENV --env B:$kv"; done
P=$R/$TAG.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; A = $A ($(shasum -a 256 $A | cut -c1-16)); B = $B ($(shasum -a 256 $B | cut -c1-16)) extra B env [$*]; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
if pgrep ds4-bench >/dev/null; then say "ds4-bench running (bytes only; no clock is read here)"; fi
/private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python $R/byteid.py --tag $TAG --posts $A24P/one.json \
  --bin A=$A --bin B=$B --bin B0=$B \
  --env A:HL_METAL_QUEUES=thread --env B:HL_METAL_QUEUES=thread --env B0:HL_METAL_QUEUES=thread $BENV \
  --env B0:HL_A28_PRUNE=0 --env B0:HL_A28_HASH=0 --env B0:HL_A28_WQ=0 --env B0:HL_A28_STAGGER_MS=0 --env B0:HL_A28_QOS=0 \
  --order A,B,B0,A > $R/byteid_$TAG.out 2>&1
say "byteid rc=$? $(tail -1 $R/byteid_$TAG.out | cut -c1-900)"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
