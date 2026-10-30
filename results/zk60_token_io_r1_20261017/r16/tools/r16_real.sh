#!/bin/bash
# TOKEN ROUND 16: the REAL Shieldstral T128 classifier runs on native R13, one guarded leaf per step.
#   r16_real.sh act                    the three items' activations (the ignored test r16_write_item_activations)
#   r16_real.sh cli                    build examples/zk60_classify (release) and record its sha256
#   r16_real.sh prove CAT NEED CAP     prove the item under policy CAT (sexual|violence|hate)
#   r16_real.sh verify CAT NEED CAP    fresh-process verify (publishes <run>/statement/)
#   r16_real.sh owner CAT NEED CAP     input-owner check (fresh process)
#   r16_real.sh label CAT NEED CAP     label --expect-total 35 (fresh process)
# Marker logs/real-<step>[-CAT].done holds the guard's exit code. Every step: hold, gap, lean first.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/tools/r16_common.sh
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
ITEMS=/home/victor/zk60-artifacts/token-io/r16-items
RUNS=/home/victor/zk60-artifacts/token-io/r16-runs
BIN=$H/target/release/examples/zk60_classify
step=$1; cat=$2; need=$3; cap=$4
pol() { echo "shieldstral-1.0-3b-moderate-$1/1"; }
ident() { python3 -c "import json,sys; [print(j['trained_statement_identity']) for j in map(json.loads, open(sys.argv[1])) if j.get('event')=='loaded']" $L/real-prove-$1.log | head -1; }
if [ "$step" = act ]; then while [ -e $W ]; do sleep 30; done; else hold; fi; gap
case $step in
  act)
    lean
    $G --class cpu --need-gib ${need:-6} --cap-gib ${cap:-8} --label tio16-act --wait-secs 14400 --max-secs 3600 --log $L/real-act.log --done $L/real-act.guard.done --result-json $L/real-act.guard.json -- $ENV RAYON_NUM_THREADS=8 HL_R16_EXPORT=$EX HL_R16_ITEMS=$ITEMS/items.tsv $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_r16_tests::r16_write_item_activations --ignored --exact --nocapture
    echo $? > $L/real-act.done ;;
  cli)
    $G --class build --need-gib 2.5 --cap-gib 3.5 --label tio16-cli --wait-secs 14400 --max-secs 1800 --log $L/real-cli.log --done $L/real-cli.guard.done --result-json $L/real-cli.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
    rc=$?; sha256sum $BIN >> $L/real-cli.log; echo $rc > $L/real-cli.done ;;
  prove)
    lean; mkdir -p $RUNS
    $G --class cpu --need-gib $need --cap-gib $cap --label tio16-prove-$cat --wait-secs 14400 --max-secs 3600 --log $L/real-prove-$cat.log --done $L/real-prove-$cat.guard.done --result-json $L/real-prove-$cat.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $BIN prove --export $EX --tables $EX/token_io --policy $(pol $cat) --content-file $ITEMS/mod_$cat/content.ids --seq-dir $ITEMS/mod_$cat/seq --out $RUNS/$cat-run
    echo $? > $L/real-prove-$cat.done ;;
  verify)
    lean
    $G --class cpu --need-gib $need --cap-gib $cap --label tio16-verify-$cat --wait-secs 14400 --max-secs 3600 --log $L/real-verify-$cat.log --done $L/real-verify-$cat.guard.done --result-json $L/real-verify-$cat.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $BIN verify --export $EX --tables $EX/token_io --policy $(pol $cat) --artifact $RUNS/$cat-run --expect-statement $(ident $cat) --min-bits 95
    echo $? > $L/real-verify-$cat.done ;;
  owner)
    lean
    od=$(python3 -c "import json,sys; [print(j['owner_dir']) for j in map(json.loads, open(sys.argv[1])) if j.get('event')=='proved']" $L/real-prove-$cat.log | head -1)
    $G --class cpu --need-gib $need --cap-gib $cap --label tio16-owner-$cat --wait-secs 14400 --max-secs 3600 --log $L/real-owner-$cat.log --done $L/real-owner-$cat.guard.done --result-json $L/real-owner-$cat.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $BIN input-owner --export $EX --tables $EX/token_io --policy $(pol $cat) --artifact $RUNS/$cat-run --expect-statement $(ident $cat) --min-bits 95 --decommitment $od/input.dec --content-file $ITEMS/mod_$cat/content.ids
    echo $? > $L/real-owner-$cat.done ;;
  label)
    lean
    $G --class cpu --need-gib $need --cap-gib $cap --label tio16-label-$cat --wait-secs 14400 --max-secs 3600 --log $L/real-label-$cat.log --done $L/real-label-$cat.guard.done --result-json $L/real-label-$cat.guard.json -- /usr/bin/env RAYON_NUM_THREADS=8 $BIN label --export $EX --tables $EX/token_io --policy $(pol $cat) --runs $RUNS/$cat-run --expect-statement $(ident $cat) --expect-total 35 --min-bits 95
    echo $? > $L/real-label-$cat.done ;;
  *) echo "usage"; exit 2 ;;
esac
