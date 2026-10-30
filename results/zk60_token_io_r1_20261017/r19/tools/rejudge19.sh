#!/bin/bash
# TOKEN ROUND 19: re-judge every test-killed mutant from its log with the FIXED mutcheck.py (10:32: its first form
# counted cargo's own "error: test failed, to rerun pass `--lib`" as a compile error, so r19_chain.sh's own verdict
# line for each mutant judged before the fix says NOT-KILLED-AS-NAMED although the test failed for the named reason).
# The TEST / WHY maps are r19_chain.sh's, copied verbatim. Writes logs/r19_mut_rejudged.jsonl and
# logs/r19_mut_rejudged.done (the verdict line, then the two harness mutants' exits).
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/r19_common.sh
MC=$T/tools/mutcheck.py
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
: > $L/r19_mut_rejudged.jsonl
for m in $ORDER; do
  if python3 $MC $L/mut-$m.log $L/mut-$m.exit "${TEST[$m]}" "${WHY[$m]}" >> $L/r19_mut_rejudged.jsonl; then RES="$RES $m=killed"; else RES="$RES $m=NOT-KILLED-AS-NAMED($(cat $L/mut-$m.exit))"; fi
done
for m in job-order reused-draw; do RES="$RES $m=$(cat $L/mut-$m.exit)"; done
echo "$RES" > $L/r19_mut_rejudged.done
WANT=""; for m in $ORDER; do WANT="$WANT $m=killed"; done; WANT="$WANT job-order=101 reused-draw=97"
[ "$RES" = "$WANT" ] && echo ALL-KILLED-AS-NAMED || echo "NOT ALL: $RES"
