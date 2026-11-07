#!/bin/bash
# check_l15merge.sh found the regenerated L15 corpus differs from the committed one (cmp rc 1: the challenges differ).
# Hypothesis: the classifier fixture's honest run draws its salts from the operating system's generator (s25's
# `no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system`), so each export is a fresh
# receipt. Test: export TWICE on the merged tree, compare the two (they should differ too), and run StageCheckOutC on
# both fresh corpora (each must give 81 checks, 0 failed). One guarded job, class cpu.
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l15_20261107
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l15merge
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/l15merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
for k in a b; do
  env LEAN_L15_CORPUS=$S/corpus_$k.txt /opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
    --manifest-path $R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml --lib lean_l15_export -- --nocapture \
    > $O/l15merge_regen_$k.log 2>&1; say "re-export $k rc=$?"
done
cmp -s $S/corpus_a.txt $S/corpus_b.txt; say "two exports on the same tree identical? cmp rc=$? (1 = they differ: fresh salts)"
for k in a b; do
  $LAKE -d $R/formal env lean --run $R/formal/ZK60Formal/StageCheckOutC.lean $S/corpus_$k.txt > $O/l15merge_regen_check_$k.log 2>&1
  say "StageCheckOutC on fresh export $k rc=$?"
  tail -1 $O/l15merge_regen_check_$k.log >> $P
done
say "regen check done"
