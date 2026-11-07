#!/bin/bash
# Lane A24 (the media app's classifier on resident servers), merged into perf after the Lean lanes L9, L11 and L12:
# the check on the MERGED tree in the main checkout. hashline: the census tests s25 (TEST_ONLY_FILES now 84) and
# hash_domain, every token_io::classify test (A24's serve tests included), r19b, and the L9 and L11 test-only exports,
# each corpus compared byte for byte with its committed one. Then zkp-core's suite and the app's whole suite. One
# guarded job, class cpu.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_a24_app_20261107
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/a24merge
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/a24merge.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
rm -rf $S; mkdir -p $S
for f in s25_tests hash_domain token_io::classify r19b; do
  n=$(echo $f | tr ':' '_')
  $C $f > $O/a24merge_$n.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" $O/a24merge_$n.log >> $P
done
env L9_OUT=$S $C lean_l9_export_the_w16r2_rung_block -- --test-threads 1 > $O/a24merge_l9export.log 2>&1
say "hashline lean_l9_export rc=$?"
cmp $S/corpus.txt $R/results/zk60_lean_l9_20261107/corpus.txt; say "L9 corpus byte-identical: cmp rc=$?"
env LEAN_L11_CORPUS=$S/l11_corpus.txt $C lean_l11_export > $O/a24merge_l11export.log 2>&1; say "hashline lean_l11_export rc=$?"
cmp $S/l11_corpus.txt $R/results/zk60_lean_l11_20261107/corpus.txt; say "L11 corpus byte-identical: cmp rc=$?"
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml \
  > $O/a24merge_zkpcore.log 2>&1; say "zkp-core suite rc=$?"
grep -E "^test result" $O/a24merge_zkpcore.log >> $P
/usr/bin/env PM_TINYLLAMA_TOKENIZER=$R/results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tokenizer.model \
  PYTHONPATH=$R/apps/proven-media PYTHONDONTWRITEBYTECODE=1 /private/tmp/zk60-astra-app-refresh-20261104-venv/bin/python \
  -m unittest discover -s $R/apps/proven-media/tests > $O/a24merge_app.log 2>&1; say "app suite rc=$?"
tail -3 $O/a24merge_app.log >> $P
say "all done"
