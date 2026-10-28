#!/bin/bash
# ROUND 9 (privacy review round 4: PR4-4, PR4-10, PR4-15, PR4-16, PR4-17; F-T1 subsumed), launched by
# hand AFTER the 8B T128 addendum is reported. Starts only when t34 (F-T1 failing first) and the r8
# 8B follow-up (logs/r8_8b.done) have both finished, so neither ever sees a source edit. Every heavy
# leaf is guarded on its own; each step's exit code in logs/<label>.exit; the chain ends by writing
# logs/r9_chain.done with the first failing step's number (0 = all passed), on success or failure.
#   t34 check  F-T1 failing first: exactly the stage-IN, block and endpoint tests failed
#   sync A2    wip-r9a2 (CLI stubs + the PR4 CLI tests) onto the working copy = manifest_r9B
#   t35        PR4 CLI tests failing first: exactly the seven pr4_* tests fail, every other passes
#   sync B     wip-r9b (the sealing pass, the CLI seal, PR4-15/16/17, the P-18 capture) = manifest_r9C
#   t36        token_io module, built: all pass
#   t37        tools: layer0_precheck --prompt-file (staged in wip-r9-tools) + r9_cli_demo.sh applied,
#              the pre-check's tests
#   b9         the NAMED CPU binary: release, default features (no gpu-cuda), sha256 + a build note
#   c9         the CLI-path capture (TinyLlama T32, L = 2; prove + verify by the named binary, then
#              the run directory verified with the recorder attached, P-18), under the captures tree
#   s13        the full suite;  then manifest_final_r9 (compared with r9C, final_r8)
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
S=$H/src/private_block/token_io
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
finish() { echo "$1" > $L/r9_chain.done; exit 0; }
g() { # class label need cap max -- cmd...
  local cls=$1 lab=$2 need=$3 cap=$4 max=$5; shift 6
  $G --class $cls --need-gib $need --cap-gib $cap --label tio-$lab --wait-secs 14400 --max-secs $max --log $L/$lab.log --done $L/$lab.guard.done --result-json $L/$lab.guard.json -- "$@"
  echo $? > $L/$lab.exit
}
until [ -f $L/t34-r9-failfirst.done ] && [ -f $L/r8_8b.done ]; do sleep 20; done
echo "r9 chain start $(date -u +%FT%TZ)"
# t34: F-T1 failing first, exactly the three expected failures (the stage-OUT control and the honest
# run pass)
python3 $R/tools/r9_expect.py $L/t34-r9-failfirst.log r9_a_stage_in_lookup_miss_is_refused_before_the_header r9_a_block_lookup_miss_is_refused_before_the_header r9_an_endpoint_that_is_not_the_witnesss_is_refused_before_the_header > $L/t34-expect.log 2>&1
echo $? > $L/t34-expect.exit
cat $L/t34-expect.log
[ "$(cat $L/t34-expect.exit)" = "0" ] || finish 34
# the working copy must still be manifest_r9A (nothing synced by hand since)
python3 $R/tools/manifest.py $R/manifest_r9_pre.sha256 $R/manifest_r9A.sha256 > $L/r9-pre-manifest.log 2>&1
grep -q "vs manifest_r9A.sha256: changed 0, added 0, removed 0" $L/r9-pre-manifest.log || finish 33
# sync A2: the failing-first CLI tests and the CLI stubs
cp $R/wip-r9a2/private_block/token_io/cli.rs $R/wip-r9a2/private_block/token_io/cli_tests.rs $S/ || finish 32
python3 $R/tools/manifest.py $R/manifest_r9B.sha256 $R/manifest_r9A.sha256 > $L/r9B-manifest.log 2>&1
g cpu t35-r9-failfirst-cli 3.5 5.5 2700 -- $CARGO test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- token_io::cli_tests --test-threads 4
python3 $R/tools/r9_expect.py $L/t35-r9-failfirst-cli.log pr4_4_a_parity_mismatch_is_refused_before_the_header pr4_4_an_extreme_input_is_refused_before_the_header pr4_4_the_cli_sealing_pass_runs_cs3_and_takes_the_token_from_the_builder pr4_15_leftovers_are_refused_by_name_and_removals_are_reported pr4_16_the_default_owner_base_is_outside_the_artifacts_tree pr4_17_the_prompt_never_goes_on_the_command_line pr4_17_the_owner_writes_the_token_to_a_0600_file > $L/t35-expect.log 2>&1
echo $? > $L/t35-expect.exit
cat $L/t35-expect.log
[ "$(cat $L/t35-expect.exit)" = "0" ] || finish 35
# sync B: the implementation
for f in $(cd $R/wip-r9b/private_block/token_io && ls); do cp $R/wip-r9b/private_block/token_io/$f $S/$f || finish 31; done
cp $R/wip-r9b/examples/zk60_token_io.rs $H/examples/zk60_token_io.rs || finish 31
python3 $R/tools/manifest.py $R/manifest_r9C.sha256 $R/manifest_r9B.sha256 $R/manifest_final_r8.sha256 > $L/r9C-manifest.log 2>&1
g cpu t36-r9-built 6.5 8.5 3600 -- $CARGO test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- token_io --test-threads 4
[ "$(cat $L/t36-r9-built.exit)" = "0" ] || finish 36
# t37: the tools (bounded Python; the pre-check's tests hash export files, small memory)
cp -p $R/wip-r9-tools/layer0_precheck.py $R/wip-r9-tools/test_layer0_precheck.py $R/wip-r9-tools/r9_cli_demo.sh $R/tools/ || finish 30
python3 $R/tools/test_layer0_precheck.py > $L/t37-precheck-tests.log 2>&1
echo $? > $L/t37-precheck-tests.exit
[ "$(cat $L/t37-precheck-tests.exit)" = "0" ] || finish 37
# b9: the named CPU token binary (release; default features: no gpu-cuda, so CPU kernels only)
g build b9-cli-build 3 5 2400 -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io
[ "$(cat $L/b9-cli-build.exit)" = "0" ] || finish 38
B=$D/zk60_token_io.r9.release.bin
cp $H/target/release/examples/zk60_token_io $B || finish 38
sha256sum $B > $D/binaries_r9.sha256
SHA=$(cut -c1-64 $D/binaries_r9.sha256)
{
  echo "zk60_token_io round-9 CPU binary (privacy review round 4, PR4-10)"
  echo "file:      $B"
  echo "sha256:    $SHA"
  echo "built:     $(date -u +%FT%TZ) on $(hostname), by tools/r9_chain.sh (step b9, log logs/b9-cli-build.log)"
  echo "command:   $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io"
  echo "toolchain: $(/home/victor/.cargo/bin/rustc -V); $($CARGO -V)"
  echo "features:  the crate's defaults only; gpu-cuda NOT enabled (cudarc is not compiled in): CPU backend only."
  echo "           stable-weight-storage not enabled. The binary's statement records its backend (check_prover_reported)."
  echo "profile:   [profile.release] opt-level 3, codegen-units 1, lto fat, panic abort, debug false (hashline/Cargo.toml)"
  echo "rustflags: none (no RUSTFLAGS, no .cargo/config in the tree or \$HOME); default target $(/home/victor/.cargo/bin/rustc -vV | sed -n 's/^host: //p'), no target-cpu"
  echo "source:    the lane working copy ops/zkp-mvp/token-io = manifest_r9C.sha256 (list sha256 $(sha256sum $R/manifest_r9C.sha256 | cut -c1-64))"
  echo "scope:     a build record, not a privacy acceptance"
} > $D/zk60_token_io.r9.BUILD.txt
# c9: the CLI-path capture with the named binary (work tree prover-side under the owners' base)
mkdir -p -m 700 $HOME/zk60-owner-private
chmod 700 $HOME/zk60-owner-private
CAP=$HOME/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9
WORK=$HOME/zk60-owner-private/token-io-cli-capture-r9
[ -e $CAP ] && finish 39
[ -e $WORK ] && finish 39
g cpu c9-cli-capture 4 6 3600 -- /usr/bin/env HL_PB_CAPTURE_DIR=$CAP HL_PB_CLI_WORK=$WORK HL_PB_CLI_BIN=$B HL_PB_CLI_BIN_SHA256=$SHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::capture_tests::capture_the_cli_verify_path_at_tinyllama_t32_l2 --exact --ignored --nocapture --test-threads 1
[ "$(cat $L/c9-cli-capture.exit)" = "0" ] || finish 39
# s13: the full suite (s12 peaked 7.11 GiB)
g cpu s13-suite 7.5 9.5 2700 -- $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
python3 $R/tools/manifest.py $R/manifest_final_r9.sha256 $R/manifest_r9C.sha256 $R/manifest_final_r8.sha256 > $L/r9-final-manifest.log 2>&1
[ "$(cat $L/s13-suite.exit)" = "0" ] || finish 40
finish 0
