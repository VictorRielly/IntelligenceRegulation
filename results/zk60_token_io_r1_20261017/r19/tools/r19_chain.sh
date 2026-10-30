#!/bin/bash
# TOKEN ROUND 19, the chain after the RED run (the green tree: the fail-closed module follower, the label scan's module
# check, E7's default_checkpoint, the R18-3 / R18-4 texts):
#  1. green: the focused batch (round 18's filter set + tied_tables for derive.rs), --test-threads=4; need 6.5 / cap 7.5
#     (r18's green 5.58 GiB RSS / 6.58 cgroup)
#  2. the RUNG BYTE-IDENTITY harness on the green test binary (round 18's ignored test, round 18's rung8 entropy and
#     run_fixed.sh): expect exit 0, unread 0; cpu 1.0 / 2.0
#  3. 18 test-killed mutants (r19/tools/mutate19.py): each an incremental build + its killing test(s), build class need
#     2.9 / cap 4.2 (r18: 2.32 GiB + 25%); judged by mutcheck.py (compiled, exit 101, every named test FAILED, every
#     named reason in the log); reverted with sha256 checks
#  4. 2 harness-killed mutants (job-order expect 101, reused-draw expect 97), as round 18
#  5. the tree manifest after the mutants = before
# Each step: turn (holds; Astra's app first). Marker logs/r19_chain.done = 0 or the failing step.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/r19_common.sh
finish() { echo "$1" > $L/r19_chain.done; step "chain end $1"; exit 0; }
M=$T/tools/mutate19.py
MC=$T/tools/mutcheck.py
RF=$R/r18/tools/run_fixed.sh
ENT=/home/victor/zk60-artifacts/token-io/r19/ent
EQT=private_block::token_io::classify_cli::batch::r18::r18_rung_batch_receipts_equal_single_proves_under_fixed_entropy
binof() { grep -o "Running unittests src/lib.rs ([^)]*)" "$1" | tail -1 | sed -E 's/.*\((.*)\)/\1/'; }
python3 $F snapshot $T/manifest_r19_green.sha256 > $L/green-manifest.log 2>&1
# 1. green
turn 6.5; step green
$G --class build --need-gib 6.5 --cap-gib 7.5 --label tio19-green --wait-secs 14400 --max-secs 3000 --log $L/green.log --done $L/green.guard.done --result-json $L/green.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify token_io::capture_tests s24_tests s25_tests s33_tests hash_domain run_capture trained_accuracy accuracy_profile_tests plane_index tied_tables --test-threads=4
echo $? > $L/green.exit
[ "$(cat $L/green.exit)" = "0" ] || finish green
BIN=$(binof $L/green.log); case $BIN in /*) ;; *) BIN=/home/victor/IntelligenceRegulation/$BIN;; esac
echo "$BIN" > $L/green.testbin
[ -x "$BIN" ] || finish green-testbin
# 2. the rung byte-identity harness
turn 1.0; step rung-eq
$G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio19-rung-eq --wait-secs 14400 --max-secs 300 --log $L/rung-eq.log --done $L/rung-eq.guard.done --result-json $L/rung-eq.guard.json -- bash $RF $ENT/rung8.bin -- $ENVC HL_R18_FIXED_ENTROPY=rung8 $BIN $EQT --exact --ignored --nocapture --test-threads=1
echo $? > $L/rung-eq.exit
[ "$(cat $L/rung-eq.exit)" = "0" ] || finish rung-eq
# 3. the test-killed mutants
python3 $F snapshot $T/manifest_r19_premut.sha256 > $L/mut-premut.log 2>&1
B=private_block::token_io::classify_cli::batch::r18
S=private_block::s25_tests
CEN=$S::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system
LAB=private_block::hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table
DER=private_block::tied_tables::derive::tests
GRAPH="the production module graph of the path moved"
declare -A TEST=(
  [fix1-revert]=$B::r18_a_failed_batch_leaves_no_receipt_statement_or_decommitment_behind
  [fix2-revert]=$S::r18_the_census_reads_the_batch_files_through_their_path_lines
  [rng-plant]=$CEN
  [label-plant]=$LAB
  [one-post-revert]=$B::r18_a_second_post_or_any_repeated_flag_is_refused_before_anything_is_read
  [e7-ignore-models]=$DER::r19_the_default_checkpoint_is_under_zk60_models_when_set_else_under_home_models
  [e7-empty-is-set]=$DER::r19_the_default_checkpoint_is_under_zk60_models_when_set_else_under_home_models
  [e7-precedence]=$DER::r19_a_declared_checkpoint_file_keeps_precedence_over_the_default
)
declare -A WHY=(
  [fix1-revert]="A FAILED BATCH LEFT RUN / STATEMENT / OWNER DIRECTORIES BEHIND"
  [fix2-revert]="$GRAPH"
  [rng-plant]="classify_batch.rs: the path constructs a generator with \`ZkRng::new\`"
  [label-plant]="classify_batch_plan.rs absorbs"
  [one-post-revert]="a repeated --content-file is refused as a bad argument"
  [e7-ignore-models]="ZK60_MODELS set: the checkpoint is under it"
  [e7-empty-is-set]="ZK60_MODELS set but EMPTY counts as unset"
  [e7-precedence]="a declared checkpoint_file wins over ZK60_MODELS"
)
for s in oneline comment pubin pubself grandchild; do
  case $s in grandchild) f=token_io/classify_cli/r19_plant.rs;; *) f=token_io/r19_plant.rs;; esac
  TEST[hide-$s-u]="$CEN,$LAB"; WHY[hide-$s-u]="$GRAPH|declares the production module src/private_block/$f, which this label scan does not read"
  TEST[hide-$s-l]="$CEN"; WHY[hide-$s-l]="src/private_block/$f: the path constructs a generator with \`ZkRng::new\`"
done
ORDER="fix1-revert fix2-revert rng-plant label-plant one-post-revert e7-ignore-models e7-empty-is-set e7-precedence hide-oneline-u hide-oneline-l hide-comment-u hide-comment-l hide-pubin-u hide-pubin-l hide-pubself-u hide-pubself-l hide-grandchild-u hide-grandchild-l"
RES=""
: > $L/r19_mut.jsonl
for m in $ORDER; do
  turn 2.9; step "mutant $m"
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 2.9 --cap-gib 4.2 --label tio19-mut-$m --wait-secs 14400 --max-secs 2400 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- ${TEST[$m]//,/ } --exact --nocapture
  echo $? > $L/mut-$m.exit
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  if python3 $MC $L/mut-$m.log $L/mut-$m.exit "${TEST[$m]}" "${WHY[$m]}" >> $L/r19_mut.jsonl; then RES="$RES $m=killed"; else RES="$RES $m=NOT-KILLED-AS-NAMED($(cat $L/mut-$m.exit))"; fi
done
# 4. the harness-killed mutants
for m in job-order reused-draw; do
  turn 2.9; step "mutant $m (build)"
  python3 $M apply $m > $L/mut-$m.apply.log 2>&1 || { RES="$RES $m=apply-failed"; continue; }
  $G --class build --need-gib 2.9 --cap-gib 4.2 --label tio19-mut-$m-build --wait-secs 14400 --max-secs 2400 --log $L/mut-$m-build.log --done $L/mut-$m-build.guard.done --result-json $L/mut-$m-build.guard.json -- $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib --no-run
  echo $? > $L/mut-$m-build.exit
  MB=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $L/mut-$m-build.log | tail -1 | sed -E 's/.*\((.*)\)/\1/'); case $MB in /*) ;; *) MB=/home/victor/IntelligenceRegulation/$MB;; esac
  if [ "$(cat $L/mut-$m-build.exit)" = "0" ] && [ -x "$MB" ]; then
    turn 1.0; step "mutant $m (harness)"
    $G --class cpu --need-gib 1.0 --cap-gib 2.0 --label tio19-mut-$m --wait-secs 14400 --max-secs 300 --log $L/mut-$m.log --done $L/mut-$m.guard.done --result-json $L/mut-$m.guard.json -- bash $RF $ENT/rung8.bin -- $ENVC HL_R18_FIXED_ENTROPY=rung8 $MB $EQT --exact --ignored --nocapture --test-threads=1
    echo $? > $L/mut-$m.exit
  else
    echo build-failed > $L/mut-$m.exit
  fi
  python3 $M revert $m >> $L/mut-$m.apply.log 2>&1 || RES="$RES $m=REVERT-FAILED"
  RES="$RES $m=$(cat $L/mut-$m.exit)"
done
# 5. the tree after = before
python3 $F snapshot $T/manifest_r19_postmut.sha256 > $L/mut-postmut.log 2>&1
python3 $F compare $T/manifest_r19_premut.sha256 $T/manifest_r19_postmut.sha256 >> $L/mut-postmut.log 2>&1
echo "$RES" > $L/r19_mut.done
WANT=""; for m in $ORDER; do WANT="$WANT $m=killed"; done; WANT="$WANT job-order=101 reused-draw=97"
[ "$RES" = "$WANT" ] || finish mutations
grep -q "^changed 0: \[\]" $L/mut-postmut.log && grep -q "^added 0: \[\]" $L/mut-postmut.log && grep -q "^removed 0: \[\]" $L/mut-postmut.log || finish mutation-manifest
finish 0
