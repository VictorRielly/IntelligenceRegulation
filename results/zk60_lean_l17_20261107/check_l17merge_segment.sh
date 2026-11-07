#!/bin/bash
# check_l17merge.sh ran CheckR13Block on the COMMITTED segment_corpus.txt with the REGENERATED segment.bin. That pair is
# inconsistent: the D12a segment comes from run::prove_run, which draws fresh OS entropy, so each export writes a new
# segment and its corpus. fork_frame.bin and open_corpus.txt did regenerate with their committed sha256. This re-runs
# CheckR13Block and its negative control on the regenerated, consistent pair (segment_corpus.txt with segment.bin, both
# from the merged tree's export). One guarded job, class cpu.
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l17_20261107
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l17merge
L=$R/formal/ZK60Formal
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/l17merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/CheckR13Block.lean $O/block_corpus.txt $S/out/fork_frame.bin $S/out/segment_corpus.txt \
  $S/out/segment.bin > $O/l17merge_block_regen.log 2>&1; say "CheckR13Block on the regenerated consistent segment pair rc=$?"
tail -1 $O/l17merge_block_regen.log >> $P
python3 -I $O/mutate_block.py $O/block_corpus.txt $S/block_neg2.txt $S/out/segment_corpus.txt $S/segment_neg2.txt
$LAKE -d $R/formal env lean --run $L/CheckR13Block.lean $S/block_neg2.txt $S/out/fork_frame.bin $S/segment_neg2.txt \
  $S/out/segment.bin > $O/l17merge_block_regen_neg.log 2>&1
say "CheckR13Block negative control on that pair (8 changes must give exactly 8 failed)"
tail -1 $O/l17merge_block_regen_neg.log >> $P
say "segment re-check done"
