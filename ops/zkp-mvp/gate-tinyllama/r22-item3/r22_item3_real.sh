#!/bin/bash
# gate round 22 item 3, chain B (the REAL hate values capture, cpu class): after chain A's NL-1 rung runs, and only
# when no other lane's guarded job is live or waiting (Astra's app post / tio18-* / sol- go first; gate22-* are
# this round's own: the guard's heavy lock serialises my cpu jobs with the parent's GR4 build). Lazy store / mmap
# (O20-1), NO checkpoint stream (B-3 refused in-process), no prove, no capture.
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/r22-item3
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round22/item3
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
A=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round20/alone_check.py
REAL=/home/victor/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values
cd /tmp
until [ -f $E/logs/chainA.nl.done ]; do sleep 20; done
quiet() {
  until python3 $A gate22- > $E/logs/alone.last 2>&1 && [ ! -e $W ]; do sleep 30; done
}
g() { # name class need cap max -- cmd
  local n=$1 cl=$2 need=$3 cap=$4 mx=$5; shift 6
  quiet
  cp $E/logs/alone.last $E/logs/$n.alone_at_launch.json
  python3 $G run --class $cl --need-gib $need --cap-gib $cap --label gate22-item3-$n --wait-secs 7200 --max-secs $mx \
    --log $E/logs/$n.log --done $E/logs/$n.guard.done --result-json $E/logs/$n.guard.json -- "$@"
  echo $? > $E/logs/$n.exit
  date -u +%FT%TZ >> $E/logs/$n.exit
}
NLF="--lazy-store --no-b3 --skip-classifier-t0"
g nl-real-dev cpu 2.0 3.0 1800 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classnl.py \
  --bundle $REAL --evidence $E/dev --name nl-real-dev-block0 --parts r13 --r13-blocks 0 $NLF
NEED=$(python3 -c "import json;g=json.load(open('$E/logs/nl-real-dev.guard.json'));print(round(max(1.0,(g.get('peak_rss_gib') or 2.0)*1.25+0.3),1))")
CAPG=$(python3 -c "print(round($NEED+1.0,1))")
echo "nl-real declared $NEED / $CAPG from the dev peak" >> $E/logs/chainB.notes
g nl-real cpu $NEED $CAPG 3600 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classnl.py \
  --bundle $REAL --evidence $E --name nl-real-hate-blocks0-2 --parts classifier,r13 --r13-blocks 0,2 \
  --real-pairs $REAL $NLF
g ts-real-classifier cpu 1.5 2.5 2400 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classts.py \
  --bundle $REAL --evidence $E --name ts-real-hate-classifier-stages
touch $E/logs/chainB.core.done
g ts-real-block1 cpu 2.0 3.0 5400 -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B $S/zk60_r22_classts.py \
  --bundle $REAL --evidence $E --name ts-real-hate-block1 --block-stages 1 --skip-classifier
date -u +%FT%TZ > $E/logs/chainB.done
