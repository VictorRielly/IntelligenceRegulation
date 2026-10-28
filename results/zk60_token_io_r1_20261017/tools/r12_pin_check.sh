#!/bin/bash
# ROUND 12: do the six approved next-token pins move under native R12? For every approval record:
# `zk60_token_io profile` with the round-11 binary (native R8 base, 0c9f247c...) and with the
# R12 rebase probe's binary (built here), each under the guard (light, 4 GiB: the measured 8B
# profile peak is 3.92 GiB). Then tools/r12_pin_compare.py writes logs/r12-pin-check.json.
# Marker logs/r12-pin-check.done = 0 when every run printed its pins.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
SP=/tmp/claude-1000/-home-victor-IntelligenceRegulation/c08c4558-9df4-474f-a0b5-1bf1cd034626/scratchpad
OLD=$R/cli/zk60_token_io.r11.release.bin
NEW=$SP/tio-r12/hashline/target/release/examples/zk60_token_io
finish() { echo "$1" > $L/r12-pin-check.done; exit 0; }
python3 $G run --class build --need-gib 3 --cap-gib 5 --label tio-r12-probe-bins --wait-secs 14400 --max-secs 2400 \
  --log $L/r12-probe-bins.log --done $L/r12-probe-bins.guard.done --result-json $L/r12-probe-bins.guard.json \
  -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $SP/tio-r12/hashline/Cargo.toml --example zk60_token_io --example zk60_classify
[ $? -eq 0 ] || finish build
for rec in $R/approvals/token_profile_approval_*.json; do
  name=$(basename $rec .json | sed 's/token_profile_approval_//')
  read -r EXPORT EMB HEAD < <(python3 -c "
import json,sys
j=json.load(open(sys.argv[1])); e=j['export']; t=j.get('table_dirs')
print(e, t['emb'] if t else e+'/token_io', t['head'] if t else e+'/token_io')" $rec)
  for which in old new; do
    BIN=$OLD; [ $which = new ] && BIN=$NEW
    python3 $G run --class light --need-gib 4 --cap-gib 5 --label tio-r12-pin-$which-$name --wait-secs 14400 --max-secs 900 \
      --log $L/r12-pin-$which-$name.log --done $L/r12-pin-$which-$name.guard.done --result-json $L/r12-pin-$which-$name.guard.json \
      -- $BIN profile --export $EXPORT --emb $EMB --head $HEAD
    [ $? -eq 0 ] || finish "pin-$which-$name"
  done
done
python3 $R/tools/r12_pin_compare.py > $L/r12-pin-compare.log 2>&1 || finish compare
finish 0
