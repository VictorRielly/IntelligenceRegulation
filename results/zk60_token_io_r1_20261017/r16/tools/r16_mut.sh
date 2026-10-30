#!/bin/bash
# TOKEN ROUND 16: the test-killing mutation runs (r16/tools/mutate16.py), as r14_mut.sh: apply, build + run ONLY the
# killing test (guarded; incremental build + one test; need 3.9 / cap 4.8 as g1), record the exit code (101 = the test
# failed = killed), revert with a sha256 check. The tree's manifest after must equal the one before. Marker r16_mut.done.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/tools/r16_common.sh
M=$T/tools/mutate16.py
python3 $F snapshot $T/manifest_r16_premut.sha256 > $L/mut-premut.log 2>&1
declare -A TEST=(
  [gate]=private_block::token_io::classify_r16_tests::r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies
  [prehdr]=private_block::token_io::classify_r16_tests::r16_a_block_at_another_stage_shape_and_the_run_seed_shape_are_refused
  [bits]=private_block::token_io::classify_r16_tests::r16_the_r13_whole_run_figure_charges_the_degree_two_tables_and_clears_95
  [reuse]=private_block::token_io::classify_r16_tests::r16_the_loaders_tied_derivation_is_reused_only_with_the_bound_margin_parameters
)
RES=""
for m in gate prehdr bits reuse; do
  hold; gap; lean
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 3.9 --cap-gib 4.8 --label tio16-mut-$m --wait-secs 14400 --max-secs 2400 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- ${TEST[$m]} --exact
  echo $? > $L/mut-$m.exit
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  RES="$RES $m=$(cat $L/mut-$m.exit)"
done
python3 $F snapshot $T/manifest_r16_postmut.sha256 > $L/mut-postmut.log 2>&1
python3 $F compare $T/manifest_r16_premut.sha256 $T/manifest_r16_postmut.sha256 >> $L/mut-postmut.log 2>&1
echo "$RES" > $L/r16_mut.done
