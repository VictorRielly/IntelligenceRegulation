#!/bin/bash
# Lane A24: native cross-checks and negative controls on a REAL Shieldstral receipt made by `serve`
# (stream s8a, post 0, the public garden sentence). One guarded gpu-class job.
#  1. the UNCHANGED CLI `verify` and `input-owner` accept the server's receipt (its statement was
#     published by check-serve: verify re-checks it byte for byte and verifies every segment);
#  2. check-serve refuses: a tampered copy (one byte of a block segment), the same length with
#     different content, the wrong policy, and the wrong model (a server pinned to r16b's identity);
#     the honest request after the controls is accepted.
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5090f993c1401215
REPO=/Users/victorrielly/IntelligenceRegulation
R=$WT/results/zk60_a24_app_20261107
BIN=$WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify
VEXP=$REPO/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier
PUB=/Users/victorrielly/zk60-artifacts/a24-media-app-20261107/stream-s8a/p0
PRIV=/Users/victorrielly/zk60-owner-private/a24-media-app-20261107/stream-s8a/p0
N=/Users/victorrielly/zk60-owner-private/a24-media-app-20261107/negctl
ID=e4f97455f9a301ea8646ae1754bb29de52e51798ae7e8e435a597eedbcf3279d
R16B=29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1
POL=shieldstral-1.0-3b-moderate-sexual/1
POLS=shieldstral-1.0-3b-moderate-sexual/1,shieldstral-1.0-3b-moderate-violence/1,shieldstral-1.0-3b-moderate-hate/1
export ZK60_MODELS=$REPO/results/zk60_astra_20261026/flashprove_runtime_20261104/models HL_GPU=1 HL_GPU_REQUIRED=0 HL_PB_ORACLE=0 HL_PB_TIMING=0
export HL_OWNER_PRIVATE_DIR=$N/refusals
P=$R/negctl.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
mkdir -m 700 -p $N
say "binary $(shasum -a 256 $BIN | cut -d' ' -f1)"
$BIN verify --export $VEXP --tables $VEXP/token_io --policy $POL --label zk60-classify-verdict --artifact $PUB/sexual-c0 --expect-statement $ID --min-bits 95 > $R/negctl_cli_verify.log 2>&1
say "CLI verify of the server's receipt rc=$? $(grep -o '"published_by":"[^"]*"' $R/negctl_cli_verify.log)"
$BIN input-owner --export $VEXP --tables $VEXP/token_io --policy $POL --label zk60-classify-verdict --artifact $PUB/sexual-c0 --expect-statement $ID --min-bits 95 --decommitment $PRIV/sexual-c0-owner/input.dec --content-file $PRIV/content.ids > $R/negctl_cli_owner.log 2>&1
say "CLI input-owner of the server's receipt rc=$? $(grep -c content-checked $R/negctl_cli_owner.log) content-checked"
# a tampered copy: every file of the run, one byte of segment-005 flipped
rm -rf $N/tampered-c0; mkdir $N/tampered-c0; cp -R $PUB/sexual-c0/. $N/tampered-c0/
python3 - $N/tampered-c0/segment-005.bin <<'EOF'
import sys
p = sys.argv[1]; b = bytearray(open(p, 'rb').read()); b[len(b) // 2] ^= 1; open(p, 'wb').write(bytes(b))
EOF
# the same length, one id changed (public ids: the fixture sentence)
python3 - $PRIV/content.ids $N/other.ids <<'EOF'
import os, sys
ids = open(sys.argv[1]).read().strip().split(','); ids[3] = str(int(ids[3]) + 1)
fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600); os.write(fd, (','.join(ids) + '\n').encode()); os.close(fd)
EOF
DEC=$PRIV/sexual-c0-owner/input.dec
line() { echo "{\"id\": \"$1\", \"policy\": \"$2\", \"expect_total\": $3, \"content_file\": \"$4\", \"chunks\": [{\"artifact\": \"$5\", \"decommitment\": \"$DEC\"}], \"log\": \"$N/$1.log\"}"; }
{
  line tampered $POL 14 $PRIV/content.ids $N/tampered-c0
  line other-content $POL 14 $N/other.ids $PUB/sexual-c0
  line wrong-policy shieldstral-1.0-3b-moderate-violence/1 14 $PRIV/content.ids $PUB/sexual-c0
  line prefix-only $POL 13 $PRIV/content.ids $PUB/sexual-c0
  line honest $POL 14 $PRIV/content.ids $PUB/sexual-c0
} > $N/requests.jsonl
$BIN check-serve --export $VEXP --tables $VEXP/token_io --policies $POLS --label zk60-classify-verdict --expect-statement $ID --min-bits 95 --lanes 1 --lane-threads 32 < $N/requests.jsonl > $R/negctl_check.log 2>&1
say "check-serve rc=$?"
grep -o '"id":"[a-z-]*","status":"[a-z]*"' $R/negctl_check.log >> $P
# the wrong model: a verifier pinned to the reviewed r16b identity refuses to start
echo "" | $BIN check-serve --export $VEXP --tables $VEXP/token_io --policies $POLS --label zk60-classify-verdict --expect-statement $R16B --min-bits 95 > $R/negctl_wrong_model.log 2>&1
say "check-serve pinned to r16b's identity rc=$? (1 = startup refused) $(grep -c '"outcome":"flagged"' $R/negctl_wrong_model.log) fail-closed line"
say "all done"
