#!/bin/bash
# Re-run of check_a24merge.sh's token_io::classify step with the R13 loader fixtures named, as the tests ask
# (HL_R13_LOADER_FIXTURES; the 7 failures of the first run were all "the R13 loader fixture ... is missing").
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_a24_app_20261107
env HL_R13_LOADER_FIXTURES=$R/results/zk60_1b_native_20261017/r13/loader-fixtures /opt/homebrew/bin/cargo test --release \
  --offline --locked -j 2 --manifest-path $R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml --lib token_io::classify \
  > $O/a24merge_token_io__classify_fixtures.log 2>&1
rc=$?
echo "$(date -u +%FT%TZ) hashline token_io::classify with HL_R13_LOADER_FIXTURES rc=$rc" >> $O/a24merge.progress
grep -E "^test result" $O/a24merge_token_io__classify_fixtures.log >> $O/a24merge.progress
exit $rc
