#!/bin/bash
# 2026-11-10, coordinator, after D78 (Victor ruled the prover shortcut HL_A26_KEPT on for the media app's classifier
# server). Receipt byte identity on the real Shieldstral export under FIXED PUBLIC TEST ENTROPY (A26's
# fixed_entropy.c interposer), with lane A28's harness (results/zk60_a28_app_20261107/byteid.py), inside one guarded
# gpu-class job: the app's pinned A28 binary with the app's settings and HL_A26_KEPT off (A), the same binary with
# HL_A26_KEPT=1 (K), and A again (the harness's own determinism control). Three lanes of ten threads, one public
# post's three categories. Every receipt file is compared byte for byte; then each binary's verifier checks the
# other runs' receipts. The verifier switch HL_A26_VERIFY_ONCE stays off everywhere (not approved).
set -u
H=/Users/victorrielly/IntelligenceRegulation/results/zk60_a28_app_20261107
O=/Users/victorrielly/IntelligenceRegulation/results/zk60_a26kept_20261110
POSTS=/Users/victorrielly/IntelligenceRegulation/results/zk60_a24_app_20261107/posts/one.json
PY=/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python
B=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a28
P=$O/bi_kept.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; binary $B ($(shasum -a 256 $B | cut -c1-16)); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
if pgrep ds4-bench >/dev/null; then say "ds4-bench running (bytes only; no clock is read here)"; fi
E="HL_METAL_QUEUES=thread"
$PY $H/byteid.py --tag kept --posts $POSTS --bin A=$B --bin K=$B \
  --env A:HL_METAL_QUEUES=thread --env A:HL_METAL_SPIN_US=200 --env A:HL_A28_STAGGER_MS=300 \
  --env K:HL_METAL_QUEUES=thread --env K:HL_METAL_SPIN_US=200 --env K:HL_A28_STAGGER_MS=300 --env K:HL_A26_KEPT=1 \
  --order A,K,A > $O/byteid_kept.out 2>&1
say "A (KEPT off), K (HL_A26_KEPT=1), A rc=$? $(tail -1 $O/byteid_kept.out | cut -c1-900)"
rm -rf /Users/victorrielly/zk60-owner-private/a28-media-app-20261107/byteid-* /Users/victorrielly/zk60-artifacts/a28-media-app-20261107/byteid-*
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
