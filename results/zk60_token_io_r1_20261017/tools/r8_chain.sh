#!/bin/bash
# Round 8, part A: t33 (token_io incl. the T128 tests, every census, the native trained tests), then the
# R8-based round-8 CLI build, the verifier copies (public files only, hard links) of the three T128
# exports and `profile` on each copy (the pins the approval records are checked against).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
X=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
$G --class cpu --need-gib 5 --cap-gib 7 --label tio-t33-r8-built --wait-secs 14400 --max-secs 3600 --log $L/t33-r8-built.log --done $L/t33-r8-built.done --result-json $L/t33-r8-built.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path $H/Cargo.toml --lib -- token_io s24_tests s25_tests s33_tests hash_domain run_capture_tests::the trained_stack_tests trained_block_tests r8_tests --test-threads 4 --nocapture
echo $? > $L/t33-r8-built.exit
if [ "$(cat $L/t33-r8-built.exit)" = "0" ]; then
  $G --class build --need-gib 3 --cap-gib 5 --label tio-r8-cli-build --wait-secs 14400 --max-secs 1800 --log $L/r8-cli-build.log --done $L/r8-cli-build.done --result-json $L/r8-cli-build.guard.json -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io
  echo $? > $L/r8-cli-build.exit
  cp $H/target/release/examples/zk60_token_io $D/zk60_token_io.r8.release.bin
  sha256sum $D/zk60_token_io.r8.release.bin > $D/binaries_r8.sha256
  for EN in llama3_8b_pg_rot1_b7voc0_T128 llama3_8b_dg_rot1_voc0_T128 tinyllama_dg_rot1_T128; do
    V=$D/verifier-export-$EN
    if [ ! -d $V ]; then
      mkdir -p $V
      for x in $X/$EN/*; do n=$(basename $x); case $n in seq_*) ;; *) cp -al $x $V/$n ;; esac; done
    fi
    $G --class light --need-gib 4 --cap-gib 6 --label tio-r8-profile-$EN --wait-secs 14400 --max-secs 1800 --log $L/r8-profile-$EN.log --done $L/r8-profile-$EN.done --result-json $L/r8-profile-$EN.guard.json -- $D/zk60_token_io.r8.release.bin profile --export $V --emb $V/token_io --head $V/token_io
    echo $? > $L/r8-profile-$EN.exit
  done
fi
echo done > $L/r8_chain.done
