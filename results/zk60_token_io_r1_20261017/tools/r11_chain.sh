#!/bin/bash
# ROUND 11 chain (after t40): the full suite s14, then the named round-11 CPU binary b11 (release,
# default features, no gpu-cuda) with its sha256 and build note, then manifest_r11C. Marker
# logs/r11_chain.done = 0 when both passed, else the failing step (14 suite, 11 build).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
finish() { echo "$1" > $L/r11_chain.done; exit 0; }
until [ -f $L/t40-r11-built.done ]; do sleep 20; done
[ "$(cat $L/t40-r11-built.done)" = "0" ] || finish 40
$G --class cpu --need-gib 7.5 --cap-gib 9.5 --label tio-s14-suite --wait-secs 14400 --max-secs 2700 --log $L/s14-suite.log --done $L/s14-suite.guard.done --result-json $L/s14-suite.guard.json -- $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s14-suite.exit
[ "$(cat $L/s14-suite.exit)" = "0" ] || finish 14
$G --class build --need-gib 3 --cap-gib 5 --label tio-b11-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b11-cli-build.log --done $L/b11-cli-build.guard.done --result-json $L/b11-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io
echo $? > $L/b11-cli-build.exit
[ "$(cat $L/b11-cli-build.exit)" = "0" ] || finish 11
B=$D/zk60_token_io.r11.release.bin
cp $H/target/release/examples/zk60_token_io $B || finish 11
sha256sum $B > $D/binaries_r11.sha256
python3 $R/tools/manifest.py $R/manifest_r11C.sha256 $R/manifest_r11B.sha256 $R/manifest_final_r9.sha256 > $L/r11C-manifest.log 2>&1
{
  echo "zk60_token_io round-11 CPU binary (review REVIEW6 TR7-5 / TR7-6 / TR7-7 on top of round 9)"
  echo "file:      $B"
  echo "sha256:    $(cut -c1-64 $D/binaries_r11.sha256)"
  echo "built:     $(date -u +%FT%TZ) on $(hostname), by tools/r11_chain.sh (log logs/b11-cli-build.log)"
  echo "command:   $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_token_io"
  echo "toolchain: $(/home/victor/.cargo/bin/rustc -V); $($CARGO -V)"
  echo "features:  the crate's defaults only; gpu-cuda NOT enabled (cudarc is not compiled in): CPU backend only."
  echo "profile:   [profile.release] opt-level 3, codegen-units 1, lto fat, panic abort, debug false (hashline/Cargo.toml)"
  echo "rustflags: none (no RUSTFLAGS, no .cargo/config in the tree or \$HOME); default target, no target-cpu"
  echo "source:    the lane working copy ops/zkp-mvp/token-io = manifest_r11C.sha256 (list sha256 $(sha256sum $R/manifest_r11C.sha256 | cut -c1-64))"
  echo "scope:     a build record, not a privacy acceptance"
} > $D/zk60_token_io.r11.BUILD.txt
finish 0
