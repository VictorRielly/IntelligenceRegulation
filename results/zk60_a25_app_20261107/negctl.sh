#!/bin/bash
# Lane A25: native cross-checks and negative controls on REAL Shieldstral receipts (public text only):
# a W16R2 development receipt made by `serve --dev-w16r2-public-content-only` (stream <W>, post 0, the
# sexual category) and an R13 receipt made by the same binary without the switch (stream <R>).
#  1. the CLI verify / input-owner WITH the switch accept the W16R2 receipt;
#  2. the CLI verify WITHOUT the switch (the R13 profile and identity) refuses it, and the A24 binary
#     (R13 only) refuses it;
#  3. check-serve (W16R2) refuses: a tampered copy, the same length with other content, the wrong policy,
#     the post's prefix only, the R13 receipt; accepts the honest request after them;
#  4. check-serve WITHOUT the switch (R13) refuses the W16R2 receipt and accepts the R13 one;
#  5. a W16R2 verifier pinned to the R13 identity, and an R13 verifier pinned to the W16R2 identity,
#     refuse to start;
#  6. the A24 binary's CLI verify accepts the R13 receipt this binary made (the R13 path unchanged).
# usage: negctl.sh <W16R2 stream tag> <R13 stream tag>   (one guarded gpu-class job)
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a894d1898cebc946c
REPO=/Users/victorrielly/IntelligenceRegulation
R=$WT/results/zk60_a25_app_20261107
BIN=$WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify
A24BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/zk60_classify.a24
VEXP=$REPO/results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier
W=$1; RT=$2
PUBW=/Users/victorrielly/zk60-artifacts/a25-media-app-20261107/stream-$W/p0
PRIVW=/Users/victorrielly/zk60-owner-private/a25-media-app-20261107/stream-$W/p0
PUBR=/Users/victorrielly/zk60-artifacts/a25-media-app-20261107/stream-$RT/p0
PRIVR=/Users/victorrielly/zk60-owner-private/a25-media-app-20261107/stream-$RT/p0
N=/Users/victorrielly/zk60-owner-private/a25-media-app-20261107/negctl-$W
IDW=$(python3 -c "import json; print(json.load(open('$R/stream_$W/summary.json'))['prover_start']['trained_statement_identity'])")
IDR=e4f97455f9a301ea8646ae1754bb29de52e51798ae7e8e435a597eedbcf3279d
SW=--dev-w16r2-public-content-only
POL=shieldstral-1.0-3b-moderate-sexual/1
POLS=shieldstral-1.0-3b-moderate-sexual/1,shieldstral-1.0-3b-moderate-violence/1,shieldstral-1.0-3b-moderate-hate/1
export ZK60_MODELS=$REPO/results/zk60_astra_20261026/flashprove_runtime_20261104/models HL_GPU=1 HL_GPU_REQUIRED=0 HL_PB_ORACLE=0 HL_PB_TIMING=0
export HL_OWNER_PRIVATE_DIR=$N/refusals
P=$R/negctl_$W.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
mkdir -m 700 -p $N
say "binary $(shasum -a 256 $BIN | cut -d' ' -f1); W16R2 identity $IDW; R13 identity $IDR"
TOT=$(python3 -c "print(len(open('$PRIVW/content.ids').read().strip().split(',')))")
V="--export $VEXP --tables $VEXP/token_io --policy $POL --label zk60-classify-verdict --min-bits 95"
# 1. the CLI with the switch
$BIN verify $V --artifact $PUBW/sexual-c0 --expect-statement $IDW $SW > $R/negctl_${W}_cli_verify.log 2>&1
say "1 CLI verify --dev-w16r2 of the W16R2 receipt rc=$? $(grep -o '"published_by":"[^"]*"' $R/negctl_${W}_cli_verify.log)"
$BIN input-owner $V --artifact $PUBW/sexual-c0 --expect-statement $IDW --decommitment $PRIVW/sexual-c0-owner/input.dec --content-file $PRIVW/content.ids $SW > $R/negctl_${W}_cli_owner.log 2>&1
say "1 CLI input-owner --dev-w16r2 of the W16R2 receipt rc=$? $(grep -c content-checked $R/negctl_${W}_cli_owner.log) content-checked"
# 2. without the switch: R13 identity, then the W16R2 identity at the R13 load; and the A24 binary
$BIN verify $V --artifact $PUBW/sexual-c0 --expect-statement $IDR > $R/negctl_${W}_cli_verify_r13.log 2>&1
say "2 CLI verify (R13, no switch) of the W16R2 receipt rc=$? (1 = refused) $(grep -c '"outcome":"flagged"' $R/negctl_${W}_cli_verify_r13.log) fail-closed"
$BIN verify $V --artifact $PUBW/sexual-c0 --expect-statement $IDW > $R/negctl_${W}_cli_verify_r13w.log 2>&1
say "2 CLI verify (no switch, pinned to the W16R2 identity) rc=$? (1 = refused)"
$A24BIN verify $V --artifact $PUBW/sexual-c0 --expect-statement $IDR > $R/negctl_${W}_a24_verify.log 2>&1
say "2 the A24 binary's verify of the W16R2 receipt rc=$? (1 = refused)"
# 3. check-serve (W16R2): tampered, other content, wrong policy, prefix only, the R13 receipt, honest
rm -rf $N/tampered-c0; mkdir $N/tampered-c0; cp -R $PUBW/sexual-c0/. $N/tampered-c0/
python3 - $N/tampered-c0/segment-005.bin <<'EOF'
import sys
p = sys.argv[1]; b = bytearray(open(p, 'rb').read()); b[len(b) // 2] ^= 1; open(p, 'wb').write(bytes(b))
EOF
python3 - $PRIVW/content.ids $N/other.ids <<'EOF'
import os, sys
ids = open(sys.argv[1]).read().strip().split(','); ids[3] = str(int(ids[3]) + 1)
fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600); os.write(fd, (','.join(ids) + '\n').encode()); os.close(fd)
EOF
DEC=$PRIVW/sexual-c0-owner/input.dec
line() { echo "{\"id\": \"$1\", \"policy\": \"$2\", \"expect_total\": $3, \"content_file\": \"$4\", \"chunks\": [{\"artifact\": \"$5\", \"decommitment\": \"$6\"}], \"log\": \"$N/$1.log\"}"; }
{
  line tampered $POL $TOT $PRIVW/content.ids $N/tampered-c0 $DEC
  line other-content $POL $TOT $N/other.ids $PUBW/sexual-c0 $DEC
  line wrong-policy shieldstral-1.0-3b-moderate-violence/1 $TOT $PRIVW/content.ids $PUBW/sexual-c0 $DEC
  line prefix-only $POL $((TOT - 1)) $PRIVW/content.ids $PUBW/sexual-c0 $DEC
  line r13-receipt $POL $TOT $PRIVR/content.ids $PUBR/sexual-c0 $PRIVR/sexual-c0-owner/input.dec
  line honest $POL $TOT $PRIVW/content.ids $PUBW/sexual-c0 $DEC
} > $N/requests.jsonl
$BIN check-serve --export $VEXP --tables $VEXP/token_io --policies $POLS --label zk60-classify-verdict --expect-statement $IDW --min-bits 95 --lanes 1 --lane-threads 32 $SW < $N/requests.jsonl > $R/negctl_${W}_check.log 2>&1
say "3 check-serve --dev-w16r2 rc=$?"
grep -o '"id":"[a-z0-9-]*","status":"[a-z]*"' $R/negctl_${W}_check.log >> $P
# 4. check-serve without the switch (R13): the W16R2 receipt refused, the R13 receipt accepted
{
  line w16r2-receipt $POL $TOT $PRIVW/content.ids $PUBW/sexual-c0 $DEC
  line r13-honest $POL $TOT $PRIVR/content.ids $PUBR/sexual-c0 $PRIVR/sexual-c0-owner/input.dec
} > $N/requests_r13.jsonl
$BIN check-serve --export $VEXP --tables $VEXP/token_io --policies $POLS --label zk60-classify-verdict --expect-statement $IDR --min-bits 95 --lanes 1 --lane-threads 32 < $N/requests_r13.jsonl > $R/negctl_${W}_check_r13.log 2>&1
say "4 check-serve (R13, no switch) rc=$?"
grep -o '"id":"[a-z0-9-]*","status":"[a-z]*"' $R/negctl_${W}_check_r13.log >> $P
# 5. the wrong model at startup, both ways
echo "" | $BIN check-serve --export $VEXP --tables $VEXP/token_io --policies $POLS --label zk60-classify-verdict --expect-statement $IDR --min-bits 95 $SW > $R/negctl_${W}_wrong_model_w.log 2>&1
say "5 check-serve --dev-w16r2 pinned to the R13 identity rc=$? (1 = startup refused) $(grep -c '"outcome":"flagged"' $R/negctl_${W}_wrong_model_w.log) fail-closed"
echo "" | $BIN check-serve --export $VEXP --tables $VEXP/token_io --policies $POLS --label zk60-classify-verdict --expect-statement $IDW --min-bits 95 > $R/negctl_${W}_wrong_model_r.log 2>&1
say "5 check-serve (R13) pinned to the W16R2 identity rc=$? (1 = startup refused) $(grep -c '"outcome":"flagged"' $R/negctl_${W}_wrong_model_r.log) fail-closed"
# 6. the A24 binary accepts the R13 receipt this binary made
$A24BIN verify $V --artifact $PUBR/sexual-c0 --expect-statement $IDR > $R/negctl_${W}_a24_verify_r13.log 2>&1
say "6 the A24 binary's verify of this binary's R13 receipt rc=$? $(grep -o '"published_by":"[^"]*"' $R/negctl_${W}_a24_verify_r13.log)"
say "all done"
