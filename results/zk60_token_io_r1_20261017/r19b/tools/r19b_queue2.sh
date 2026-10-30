#!/bin/bash
# TOKEN ROUND 19b: after the chain. The chain's after-tests-label (13:17) was killed by its named test (the label scan
# FAILED, exit 101, compiled) but its named REASON was too specific: the scan reported the planted label as `, b` (its
# line extractor takes the first `b"` after the word `absorb`, and `("absorb", b"...")` has one inside `absorb"`), so
# mutcheck judged it NOT-KILLED-AS-NAMED and the chain will end "mutations", stopping r19b_queue.sh before the suite.
# This script, launched by hand at that point:
#  0. waits for logs/r19b_queue.done (no signals; a sleep loop on the marker);
#  1. requires: the chain ended "mutations", its tree check passed (premut = postmut), and EVERY other mutant's verdict
#     in logs/r19b_mut.done is killed / job-order=101 / reused-draw=97 - else it stops;
#  2. re-judges after-tests-label from its log with round 18's reason form ("tied_tables/derive.rs absorbs");
#  3. runs ONE extra mutant, after-tests-label-2 (tools/mutate19b_label2.py: `const r19b_absorb_plant: &[u8] =
#     b"r19b-planted-label";` after derive.rs's tests module), which the label scan must report by its label;
#     the tree after = before;
#  4. then suite -> checks -> freeze, each only if the one before ended 0.
# Marker logs/r19b_queue2.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/tools/r19b_common.sh
fin() { echo "$1" > $L/r19b_queue2.done; step "queue2 end $1"; exit 0; }
until [ -f $L/r19b_queue.done ]; do sleep 30; done
step "queue2 start (queue: $(cat $L/r19b_queue.done))"
[ "$(cat $L/r19b_queue.done)" = "chain mutations" ] || fin "queue-not-the-expected-stop"
grep -q "^changed 0: \[\]" $L/mut-postmut.log && grep -q "^added 0: \[\]" $L/mut-postmut.log && grep -q "^removed 0: \[\]" $L/mut-postmut.log || fin mutation-manifest
python3 - $L/r19b_mut.done > $L/queue2-verdicts.log 2>&1 <<'EOF' || fin other-mutants
import sys
got = open(sys.argv[1]).read().split()
bad = [g for g in got if not (g.endswith("=killed") or g in ("job-order=101", "reused-draw=97", "after-tests-label=NOT-KILLED-AS-NAMED(101)"))]
print(len(got), "verdicts; not killed besides after-tests-label:", bad)
assert len(got) == 28 and "after-tests-label=NOT-KILLED-AS-NAMED(101)" in got and not bad
EOF
# 2. the re-judge
LAB=private_block::hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table
python3 $T/tools/mutcheck.py $L/mut-after-tests-label.log $L/mut-after-tests-label.exit "$LAB" "tied_tables/derive.rs absorbs" > $L/rejudge-after-tests-label.json 2>&1 || fin rejudge
# 3. after-tests-label-2
M2=$T/tools/mutate19b_label2.py
m=after-tests-label-2
python3 $F snapshot $T/manifest_r19b_premut2.sha256 > $L/mut-premut2.log 2>&1
turn 2.9; step "mutant $m"
python3 $M2 apply $m > $L/mut-$m.apply.log 2>&1 || fin "$m-apply"
$G --class build --need-gib 2.9 --cap-gib 4.2 --label tio19b-mut-$m --wait-secs 14400 --max-secs 2400 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- $LAB --exact --nocapture
echo $? > $L/mut-$m.exit
python3 $M2 revert $m >> $L/mut-$m.apply.log 2>&1 || fin "$m-REVERT-FAILED"
python3 $T/tools/mutcheck.py $L/mut-$m.log $L/mut-$m.exit "$LAB" "tied_tables/derive.rs absorbs \`r19b-planted-label\`" > $L/mut-$m.verdict.json 2>&1 || fin "$m-not-killed-as-named"
python3 $F snapshot $T/manifest_r19b_postmut2.sha256 > $L/mut-postmut2.log 2>&1
python3 $F compare $T/manifest_r19b_premut2.sha256 $T/manifest_r19b_postmut2.sha256 >> $L/mut-postmut2.log 2>&1
grep -q "^changed 0: \[\]" $L/mut-postmut2.log && grep -q "^added 0: \[\]" $L/mut-postmut2.log && grep -q "^removed 0: \[\]" $L/mut-postmut2.log || fin mutation-manifest-2
# 4. suite -> checks -> freeze
for s in suite check freeze; do
  bash $T/tools/r19b_$s.sh; echo $? > $L/r19b_$s.sh.done
  [ "$(cat $L/r19b_$s.done 2>/dev/null)" = "0" ] || fin "$s $(cat $L/r19b_$s.done 2>/dev/null)"
done
fin 0
