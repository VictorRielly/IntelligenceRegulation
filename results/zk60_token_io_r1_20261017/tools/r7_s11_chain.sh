#!/bin/bash
# Round 7 close, after s10's one failure (the stage-25 hash call-site census counted the token capture's
# two new SHA-256 call sites in run_capture.rs; classified in s25_tests.rs): the final manifest and the
# full suite again (s11) on the final tree.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
python3 $R/tools/manifest.py $R/manifest_final_r7.sha256 $R/manifest_r7D.sha256 $R/manifest_r7_demo.sha256 > $L/r7-final-manifest-2.log 2>&1
$G --class cpu --need-gib 6.5 --cap-gib 8 --label tio-s11-suite --wait-secs 14400 --max-secs 2700 --log $L/s11-suite.log --done $L/s11-suite.done --result-json $L/s11-suite.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s11-suite.exit
echo done > $L/r7_s11_chain.done
