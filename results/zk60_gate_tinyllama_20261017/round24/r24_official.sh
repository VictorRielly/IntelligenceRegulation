#!/bin/bash
# PRIVACY GATE lane, gate round 24: the official runs with FROZEN tools v24 (after round24/freeze_v24.py).
# All light class, each declared from its measured peak + margin (the lean-memory rule permits light <= 1 GiB
# beside a >= 3 GiB job; every step also waits for round24/lean_check.py and the hold files).
#  1. the v24 tool check (80 / 0 / 0);
#  2. step 2: round24/pin_census.py with frozen v24 (and frozen v23 as the control) -> PIN_CENSUS_R24.json;
#  3. the frozen v24 suite;
#  4. step 3, control: frozen v23's whole classifier gate on the r19b P-18 capture (REFUSED by name, exit 3);
#  5. step 3: frozen v24's whole classifier gate on the r19b P-18 capture;
#  6. v24 installed in the gate's working copy, and its suite there.
# Marker r24_official.done = 0 when every step gave its expected exit, else the first unexpected step's name.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round24
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
CAP=/home/victor/zk60-artifacts/token-io/captures/classify-rc3-cli-p18-r19b-gate24
mkdir -p $P/v24 $P/ff $P/suite
cd /tmp
prog() { echo "$(date -u +%H:%M:%S) $*" >> $P/r24_official.progress; }
g() {  # g <name> <need> <cap> <max> <expected exit> -- cmd...
  local nm=$1 need=$2 cap=$3 mx=$4 want=$5; shift 6
  until python3 $P/lean_check.py $need light gate24- > $P/lean.last; do sleep 30; done
  python3 $G run --class light --need-gib $need --cap-gib $cap --label gate24-$nm --wait-secs 7200 --max-secs $mx \
    --log $P/logs/$nm.log --done $P/logs/$nm.guard.done --result-json $P/logs/$nm.guard.json -- "$@"
  local rc=$?
  prog "$nm exit $rc (expected $want)"
  [ "$rc" = "$want" ] || { echo "$nm" > $P/r24_official.done; exit 0; }
}
prog start
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v24.sha256 $GT/frozen_v24 > $P/logs/toolcheck.log 2>&1 \
  || { prog "toolcheck failed"; echo toolcheck > $P/r24_official.done; exit 0; }
prog "toolcheck $(tail -1 $P/logs/toolcheck.log)"
g pin-census 0.8 1.5 900 0 -- python3 -B $P/pin_census.py --v24 $GT/frozen_v24/scripts --out $P/PIN_CENSUS_R24.json
g unittests-v24-frozen 0.8 1.5 1800 0 -- python3 -B -m unittest discover -s $GT/frozen_v24/tests
g ff-v23-gate-p18-r19b 0.8 2.0 1800 3 -- python3 -B $GT/frozen_v23/scripts/zk60_native_rg_classgate.py --bundle $CAP \
  --evidence $P/ff --name ff-v23-classify-rc3-cli-p18-r19b-gate24
g v24-gate-p18-r19b 0.8 2.0 2400 0 -- python3 -B $GT/frozen_v24/scripts/zk60_native_rg_classgate.py --bundle $CAP \
  --evidence $P/v24 --name v24-classify-rc3-cli-p18-r19b-gate24
python3 $P/r24_install_wc.py > $P/logs/install_wc.log 2>&1 || { prog "install failed"; echo install > $P/r24_official.done; exit 0; }
prog "install $(tail -1 $P/logs/install_wc.log)"
g unittests-v24-working-copy 0.8 1.5 1800 0 -- python3 -B -m unittest discover -s $GT/tests
echo 0 > $P/r24_official.done
