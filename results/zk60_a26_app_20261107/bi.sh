#!/bin/bash
# Lane A26, byte-identity job (one guarded gpu-class job): A24's pinned binary (A) and this lane's
# candidate (B; and Bk, the same binary with the prover's kept records and the verifier's
# verify-once on) prove one public post's three categories under FIXED PUBLIC TEST ENTROPY
# (fixed_entropy.c, macOS); every receipt file is compared byte for byte across the runs (A twice:
# the harness's own determinism control); then each verifier checks the other's receipts.
# usage: bi.sh <tag> <B binary>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a26_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a010958861d4921eb/results/zk60_a24_app_20261107/posts
A=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
TAG=$1; B=$2
P=$R/$TAG.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; B = $B ($(shasum -a 256 $B | cut -c1-16)); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
/private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python $R/byteid.py --tag $TAG --posts $A24P/one.json \
  --bin A=$A --bin B=$B --bin Bk=$B --env Bk:HL_A26_KEPT=1 --env Bk:HL_A26_VERIFY_ONCE=1 --order A,B,Bk,A > $R/byteid_$TAG.out 2>&1
say "byteid rc=$? $(tail -1 $R/byteid_$TAG.out | cut -c1-900)"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
