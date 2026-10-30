#!/bin/bash
# TOKEN ROUND 17: the h19-3-off mutant AGAIN (16:08). The chain's first h19-3-off did not compile (E0004: the guarded
# `Ok(low) if false` arm left the match non-exhaustive), so its exit 101 was a compile error, not a kill. The fixed
# mutant keeps the match exhaustive and always takes the legacy names, and the R13 slots' legacy push bodies. A kill
# now also requires the test to have RUN and panicked (grep "panicked at" in the log). Need 2.9 / cap 4.2.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r17/tools/r17_common.sh
M=$T/tools/mutate17.py
P17=private_block::token_io::classify_capture_tests::gate19::r17
python3 $F snapshot $T/manifest_r17_premut2.sha256 > $L/mut2-premut.log 2>&1
hold; gap; step "mutant h19-3-off (again)"
python3 $M apply h19-3-off > $L/mut2-h19-3-off.apply.log 2>&1 || { echo apply-failed > $L/r17_mut2.done; exit 0; }
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio17-mut2-h19-3-off --wait-secs 14400 --max-secs 2400 --log $L/mut2-h19-3-off.log --done $L/mut2-h19-3-off.guard.done --result-json $L/mut2-h19-3-off.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- $P17::r17_the_plane_index_builds_at_an_r13_shape_from_the_accuracy_layout $P17::r17_an_r13_rung_classify_run_is_recorded_under_the_classifier_schema --test-threads=2 --nocapture
echo $? > $L/mut2-h19-3-off.exit
python3 $M revert h19-3-off >> $L/mut2-h19-3-off.apply.log 2>&1 || echo REVERT-FAILED >> $L/mut2-h19-3-off.exit
python3 $F snapshot $T/manifest_r17_postmut2.sha256 > $L/mut2-postmut.log 2>&1
python3 $F compare $T/manifest_r17_premut2.sha256 $T/manifest_r17_postmut2.sha256 >> $L/mut2-postmut.log 2>&1
P=$(grep -c "panicked at" $L/mut2-h19-3-off.log)
E=$(grep -c "^error" $L/mut2-h19-3-off.log)
echo "exit=$(cat $L/mut2-h19-3-off.exit | tr '\n' ' ') panicked=$P compile_errors=$E" > $L/r17_mut2.done
step "mutant h19-3-off (again) end $(cat $L/r17_mut2.done)"
