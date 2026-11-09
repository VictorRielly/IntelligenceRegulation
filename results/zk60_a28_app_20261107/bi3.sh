#!/bin/bash
# Lane A28, the final candidate's byte identity (inside one guarded gpu-class job): A27's pinned binary (A) and
# the candidate prove one public post's three categories under FIXED PUBLIC TEST ENTROPY (A26's fixed_entropy.c
# interposer, macOS); every receipt file is compared byte for byte across the runs (A twice: the harness's own
# determinism control); then each verifier checks the other binaries' receipts (verify + input-owner + label).
# Every server with HL_METAL_QUEUES=thread (the app's pin).
#   part a (three lanes of ten threads, one category a lane): A, B (the candidate as built), B0 (the candidate
#     with EVERY A28 switch off: HL_A28_PRUNE, HL_A28_HASH, HL_A28_WQ, HL_A28_SEAL_AHEAD, no stagger, no QoS), A.
#   part b (ONE lane of thirty threads, so the three categories share a lane): A, Bs (the candidate with
#     HL_A28_SEAL_AHEAD=1 and a 300 ms stagger: the second category's sealing pass runs beside the first one's
#     run, the third waits its turn), Bn (the candidate with HL_A28_SEAL_AHEAD=0), A.
# usage: bi3.sh <tag> <B binary>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
A24P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a24_app_20261107/posts
PY=/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python
A=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a27
TAG=$1; B=$2
P=$R/$TAG.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; A = $A ($(shasum -a 256 $A | cut -c1-16)); B = $B ($(shasum -a 256 $B | cut -c1-16)); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
if pgrep ds4-bench >/dev/null; then say "ds4-bench running (bytes only; no clock is read here)"; fi
$PY $R/byteid.py --tag ${TAG}a --posts $A24P/one.json --bin A=$A --bin B=$B --bin B0=$B \
  --env A:HL_METAL_QUEUES=thread --env B:HL_METAL_QUEUES=thread --env B0:HL_METAL_QUEUES=thread \
  --env B0:HL_A28_PRUNE=0 --env B0:HL_A28_HASH=0 --env B0:HL_A28_WQ=0 --env B0:HL_A28_SEAL_AHEAD=0 \
  --env B0:HL_A28_STAGGER_MS=0 --env B0:HL_A28_QOS=0 \
  --order A,B,B0,A > $R/byteid_${TAG}a.out 2>&1
say "part a (3 x 10: A, B, B0 every switch off, A) rc=$? $(tail -1 $R/byteid_${TAG}a.out | cut -c1-900)"
$PY $R/byteid.py --tag ${TAG}b --posts $A24P/one.json --bin A=$A --bin Bs=$B --bin Bn=$B --lanes 1 --lane-threads 30 \
  --env A:HL_METAL_QUEUES=thread --env Bs:HL_METAL_QUEUES=thread --env Bn:HL_METAL_QUEUES=thread \
  --env Bs:HL_A28_SEAL_AHEAD=1 --env Bs:HL_A28_STAGGER_MS=300 --env Bn:HL_A28_SEAL_AHEAD=0 \
  --order A,Bs,Bn,A > $R/byteid_${TAG}b.out 2>&1
say "part b (1 x 30: A, Bs seal-ahead on + stagger, Bn seal-ahead off, A) rc=$? $(tail -1 $R/byteid_${TAG}b.out | cut -c1-900)"
grep -h '"seal_ahead"' $R/byteid_${TAG}b/prover_1-Bs.log $R/byteid_${TAG}b/prover_2-Bn.log 2>/dev/null | sed -E 's/.*("seal_ahead":[a-z]+).*/\1/' | tr '\n' ' ' >> $P; echo >> $P
rm -rf /Users/victorrielly/zk60-owner-private/a28-media-app-20261107/byteid-* /Users/victorrielly/zk60-artifacts/a28-media-app-20261107/byteid-*
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
