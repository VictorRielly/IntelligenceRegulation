#!/bin/bash
# TOKEN ROUND 14: the test-killing mutation runs (r14/tools/mutate.py). For each mutant: apply it to the r14
# tree, build + run ONLY the test that must kill it (guarded, need 2.7 / cap 3.5: an incremental build plus one
# test), record the exit code (101 = the test failed = the mutant is killed), revert, check the file's sha256.
# Afterwards the tree's manifest must equal the pre-mutation one. Marker logs/r14_mut.done.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r14
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r14/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
F=$T/tools/freeze14.py
M=$T/tools/mutate.py
python3 $F snapshot $T/manifest_r14_premut.sha256 > $L/mut-premut.log 2>&1
declare -A TEST=(
  [n2]=private_block::token_io::classify_tied_tests::r14_the_post_derivation_profile_digest_check_refuses_a_derivation_that_read_another_profile
  [pad]=private_block::token_io::classify_tests::r14_a_doctored_pad_position_is_refused
  [bind]=private_block::token_io::classify_r14_tests::r14_tables_bound_to_another_trained_statement_are_refused_at_every_entry_point
)
RES=""
for m in n2 pad bind; do
  while [ -e $T/HOLD ] || [ -e $W ]; do sleep 30; done
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 2.7 --cap-gib 3.5 --label tio14-mut-$m --wait-secs 14400 --max-secs 1800 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- /usr/bin/env TMPDIR=/home/victor/zk60-artifacts/token-io/tmp-r14 HL_TIO_FIXTURE_DIR=/home/victor/zk60-artifacts/token-io/tmp-r14 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- ${TEST[$m]} --exact
  echo $? > $L/mut-$m.exit
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  RES="$RES $m=$(cat $L/mut-$m.exit)"
done
python3 $F snapshot $T/manifest_r14_postmut.sha256 > $L/mut-postmut.log 2>&1
python3 $F compare $T/manifest_r14_premut.sha256 $T/manifest_r14_postmut.sha256 >> $L/mut-postmut.log 2>&1
echo "$RES" > $L/r14_mut.done
