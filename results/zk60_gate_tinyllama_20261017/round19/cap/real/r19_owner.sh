#!/bin/bash
# gate round 19: the input owner's check on the gate's real run (the named r16b binary, `input-owner`, a fresh
# process re-verifying all 28 segments, then the owner's decommitment against the verified input root and the
# content file). Waits for the real-capture gate (queue R, cpu 7.2) to finish. cpu 2.9 / 4.5 (round 16's
# input-owner peak 2.29 GiB + 25%). Read only: the decommitment and the content stay in place.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round19/cap/real
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
BIN=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/zk60_classify.r16b.release.bin
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
RUN=/home/victor/zk60-artifacts/token-io/captures/gate19-real-run/sexual-run
ITEM=/home/victor/zk60-artifacts/token-io/r16-items/mod_sexual
OWN=$(python3 -c "import json,sys; [print(j['owner_dir']) for j in map(json.loads, (l for l in open(sys.argv[1]) if l.startswith('{'))) if j.get('event')=='proved']" $P/prove.log | head -1)
until [ -f $E/round19/r19_gate_r.finished ]; do sleep 30; done
while [ -e $E/HOLD ] || [ -e $W ]; do sleep 30; done
python3 $G run --class cpu --need-gib 2.9 --cap-gib 4.5 --label gate19-real-owner --wait-secs 14400 --max-secs 1800 \
  --log $P/owner.log --done $P/owner.guard.done --result-json $P/owner.guard.json -- \
  /usr/bin/env RAYON_NUM_THREADS=8 $BIN input-owner --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-moderate-sexual/1 \
  --artifact $RUN --expect-statement 29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1 --min-bits 95 \
  --decommitment $OWN/input.dec --content-file $ITEM/content.ids
echo $? > $P/owner.done
