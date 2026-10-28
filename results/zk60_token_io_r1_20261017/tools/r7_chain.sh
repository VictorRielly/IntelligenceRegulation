#!/bin/bash
# Round 7, part A: wait for the failing-first run t28 (T-A), sync T-B from wip-r7b/ into the lane's
# working copy, run t29 (token_io + every census + the native trained / R4 / R6 / R8 / D24 tests), and if
# green build the R8-based CLI, make the verifier copy of the fidelity lane's b7voc0_T32 export (public
# files only, hard links) and run `profile` on that copy (the pins the approval record is checked
# against). The demo (tools/r4_cli_demo.sh, TAG=r7) is launched after the approval record is written.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
W=$R/wip-r7b
X=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
until [ -f $L/t28-r7-failfirst.done ]; do sleep 30; done
cp $W/src/private_block/token_io/run.rs $H/src/private_block/token_io/run.rs
cp $W/src/private_block/token_io/cli.rs $H/src/private_block/token_io/cli.rs
cp $W/examples/zk60_token_io.rs $H/examples/zk60_token_io.rs
python3 $R/tools/manifest.py $R/manifest_r7B.sha256 $R/manifest_r7A.sha256 > $L/r7-sync.log 2>&1
date -u +%H:%M:%S >> $L/r7-sync.log
$G --class cpu --need-gib 4 --cap-gib 6 --label tio-t29-r7-built --wait-secs 14400 --max-secs 2400 --log $L/t29-r7-built.log --done $L/t29-r7-built.done --result-json $L/t29-r7-built.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- token_io s24_tests s25_tests s33_tests hash_domain run_capture_tests::the trained_stack_tests trained_block_tests r4_tests r6_tests r8_tests review_d24_tests --test-threads 4 --nocapture
echo $? > $L/t29-r7-built.exit
if [ "$(cat $L/t29-r7-built.exit)" = "0" ]; then
  $G --class build --need-gib 3 --cap-gib 5 --label tio-r7-cli-build --wait-secs 14400 --max-secs 1800 --log $L/r7-cli-build.log --done $L/r7-cli-build.done --result-json $L/r7-cli-build.guard.json -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io
  echo $? > $L/r7-cli-build.exit
  if [ "$(cat $L/r7-cli-build.exit)" = "0" ]; then
    cp $H/target/release/examples/zk60_token_io $D/zk60_token_io.r7.release.bin
    sha256sum $D/zk60_token_io.r7.release.bin > $D/binaries_r7.sha256
    V=$D/verifier-export-$(basename $X)
    if [ ! -d $V ]; then
      mkdir -p $V
      for x in $X/*; do n=$(basename $x); case $n in seq_*) ;; *) cp -al $x $V/$n ;; esac; done
    fi
    $G --class light --need-gib 3.5 --cap-gib 5 --label tio-r7-profile-voc0 --wait-secs 14400 --max-secs 900 --log $L/r7-profile-voc0.log --done $L/r7-profile-voc0.done --result-json $L/r7-profile-voc0.guard.json -- $D/zk60_token_io.r7.release.bin profile --export $V --emb $V/token_io --head $V/token_io
    echo $? > $L/r7-profile-voc0.exit
  fi
fi
echo done > $L/r7_chain.done
