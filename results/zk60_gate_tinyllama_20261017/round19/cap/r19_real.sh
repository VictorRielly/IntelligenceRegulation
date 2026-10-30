#!/bin/bash
# PRIVACY GATE lane, gate round 19: ONE real Shieldstral-1.0-3B T128 classifier capture through the CLI path
# (REVIEW_R16 §10 item 1; the P-18 pattern). Three guarded leaves, each its own process:
#   1. prove  : the NAMED r16b binary (dfb8025e...), the 35-id ToxicChat post (round 16's item; a SHORT item,
#               20 pad positions under the sexual template), policy shieldstral-1.0-3b-moderate-sexual/1.
#               cpu, need 10.3 / cap 11.5 (round 16's measured prove peaks 8.08-8.27 GiB + 25%); run ALONE:
#               lean() waits until no other live guarded job declares > 1 GiB.
#   2. verify : the named binary in a fresh process (publishes <run>/statement/); 2.9 / 4.5 (peak 2.32 + 25%).
#   3. capture: the gate's H19-2 hook (capture-tree-r16b test binary): the CLI's own door on the run directory
#               and the verification with the recorder attached, public tables as length + digest
#               (HL_RUN_CAPTURE_PUBLIC_TABLES=0: the 26 blocks' cube-size public tables would be several GB);
#               first measurement: need 5.5 / cap 7.0, lean.
# Between steps: gap() for waiting sol- / astra- / release / s4 guards. Marker r19_real.done = 0 or the step.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round19/cap/real
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r16b/hashline
C=/home/victor/zk60-artifacts/token-io/captures
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
FX=/tmp/claude-1000/-home-victor-IntelligenceRegulation/fd35cd14-b711-4cce-8e3f-39cf044eb009/scratchpad/fx19
CARGO=/home/victor/.cargo/bin/cargo
BIN=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/zk60_classify.r16b.release.bin
BSHA=dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
ITEM=/home/victor/zk60-artifacts/token-io/r16-items/mod_sexual
POL=shieldstral-1.0-3b-moderate-sexual/1
IDENT=29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1
WORK=$C/gate19-real-run
RUN=$WORK/sexual-run
# the owner's decommitment: the CLI's default owner directory (outside the run's parent, TR4-3), read from
# the prove log's `proved` event (attempt 1 at 11:40:57 refused --owner-dir inside the run's parent)
NM=classify-r13-shield-t128-cli-sexual-r16b
mkdir -p $P $FX
log() { echo "$(date -u +%FT%TZ) $*" >> $P/r19_real.progress; }
hold() { while [ -e $E/HOLD ] || [ -e $W ]; do sleep 30; done; }
lean() {
  while python3 $GUARD status --json | python3 -c "import json,sys; s=json.load(sys.stdin); sys.exit(0 if any(j['need_gib'] > 1.0 for j in s['live_guarded_jobs']) else 1)"; do
    log "lean: another live job declares > 1 GiB; waiting"; sleep 30
  done
}
gap() {
  local t0=$(date +%s)
  while :; do
    local waiting=$(ps -eo args | grep -E "zk60_resource_guard.py run .*--label (sol-|release|astra-|s4)" | grep -v grep | sed -E 's/.*--label ([^ ]+).*/\1/' | sort -u)
    [ -z "$waiting" ] && return
    local live=$(python3 $GUARD status --json | python3 -c "import json,sys; print('\n'.join(j['label'] for j in json.load(sys.stdin)['live_guarded_jobs']))")
    local pending=0
    for w in $waiting; do echo "$live" | grep -qx "$w" || pending=1; done
    [ $pending = 0 ] && return
    [ $(( $(date +%s) - t0 )) -ge 240 ] && { log "gap: 4 min given to $waiting"; return; }
    sleep 20
  done
}
echo "$BSHA  $BIN" | sha256sum -c > $P/binary-check.txt 2>&1 || { echo binary > $P/r19_real.done; exit 0; }
mkdir -p $WORK && chmod 700 $WORK
# ---- 1. prove
hold; gap; lean
log "prove start"
python3 $GUARD run --class cpu --need-gib 10.3 --cap-gib 11.5 --label gate19-real-prove --wait-secs 14400 --max-secs 3600 \
  --log $P/prove.log --done $P/prove.guard.done --result-json $P/prove.guard.json -- \
  /usr/bin/env RAYON_NUM_THREADS=8 $BIN prove --export $EX --tables $EX/token_io --policy $POL \
  --content-file $ITEM/content.ids --seq-dir $ITEM/seq --out $RUN
rc=$?; log "prove exit $rc"; [ $rc -eq 0 ] || { echo prove > $P/r19_real.done; exit 0; }
OWN=$(python3 -c "import json,sys; [print(j['owner_dir']) for j in map(json.loads, (l for l in open(sys.argv[1]) if l.startswith('{'))) if j.get('event')=='proved']" $P/prove.log | head -1)
log "owner dir $OWN"; [ -f "$OWN/input.dec" ] || { echo owner > $P/r19_real.done; exit 0; }
# ---- 2. verify (fresh process; publishes the statement)
hold; gap; lean
python3 $GUARD run --class cpu --need-gib 2.9 --cap-gib 4.5 --label gate19-real-verify --wait-secs 14400 --max-secs 3600 \
  --log $P/verify.log --done $P/verify.guard.done --result-json $P/verify.guard.json -- \
  /usr/bin/env RAYON_NUM_THREADS=8 $BIN verify --export $EX --tables $EX/token_io --policy $POL --artifact $RUN \
  --expect-statement $IDENT --min-bits 95
rc=$?; log "verify exit $rc"; [ $rc -eq 0 ] || { echo verify > $P/r19_real.done; exit 0; }
# ---- 3. the H19-2 capture (the test binary is the one r19_one.sh / r19_captures.sh built)
hold; gap; lean
python3 $GUARD run --class cpu --need-gib 5.5 --cap-gib 7.0 --label gate19-real-capture --wait-secs 14400 --max-secs 3600 \
  --log $P/capture.log --done $P/capture.guard.done --result-json $P/capture.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX RAYON_NUM_THREADS=8 HL_PB_CAPTURE_DIR=$C/$NM \
  HL_PB_REAL_EXPORT=$EX HL_PB_REAL_TABLES=$EX/token_io HL_PB_REAL_POLICY=$POL HL_PB_REAL_RUN=$RUN \
  HL_PB_REAL_EXPECT=$IDENT HL_PB_REAL_DEC=$OWN/input.dec HL_PB_CLI_BIN=$BIN HL_PB_CLI_BIN_SHA256=$BSHA \
  HL_RUN_CAPTURE_PUBLIC_TABLES=0 HL_TEST_SOURCE_COMMIT=token-frozen-r16b-04d94bc0-gate-copy+H19 \
  $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
  private_block::token_io::classify_capture_tests::gate19::gate19_capture_a_real_classify_cli_run --exact --ignored --nocapture
rc=$?; log "capture exit $rc"
cp $RUN/statement/statement.json $P/$NM.statement.json 2>/dev/null
echo $rc > $P/r19_real.done
