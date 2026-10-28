#!/bin/bash
# ROUND 12 (rung R-C1) chain (re-run 2026-10-26 after the registry fix): the full suite s16, then the classifier CPU binary b12
# (zk60_classify, release, default features, no gpu-cuda) with its sha256 and build note, then
# manifest_r12C against manifest_final_r11. Marker logs/r12_chain2.done = 0 when all passed, else
# the failing step (15 suite, 12 build). Launch only after r12-t2-cli and r12-t3-classify pass.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
finish() { echo "$1" > $L/r12_chain2.done; exit 0; }
# 2026-10-26: every guarded step pre-checks outside the lock first (the coordinator's rule)
pre() {  # $1 = need, $2 = class
  until out=$(python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py check --class $2 --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
python3 $R/tools/manifest.py $R/manifest_r12B2.sha256 $R/manifest_final_r11.sha256 $R/manifest_r12B.sha256 > $L/r12B2-manifest.log 2>&1
pre 7.5 cpu
$G --class cpu --need-gib 7.5 --cap-gib 9.5 --label tio-s16-suite --wait-secs 14400 --max-secs 2700 --log $L/s16-suite.log --done $L/s16-suite.guard.done --result-json $L/s16-suite.guard.json -- $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s16-suite.exit
[ "$(cat $L/s16-suite.exit)" = "0" ] || finish 16
pre 3 build
$G --class build --need-gib 3 --cap-gib 5 --label tio-b12-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b12-cli-build.log --done $L/b12-cli-build.guard.done --result-json $L/b12-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b12-cli-build.exit
[ "$(cat $L/b12-cli-build.exit)" = "0" ] || finish 12
B=$D/zk60_classify.r12.release.bin
cp $H/target/release/examples/zk60_classify $B || finish 12
sha256sum $B > $D/binaries_r12.sha256
python3 $R/tools/manifest.py $R/manifest_r12C.sha256 $R/manifest_r12B2.sha256 $R/manifest_final_r11.sha256 > $L/r12C-manifest.log 2>&1
{
  echo "zk60_classify round-12 CPU binary (rung R-C1: the classifier CLI, D41 chunks; DESIGN_CLASSIFIER v2.2)"
  echo "file:      $B"
  echo "sha256:    $(cut -c1-64 $D/binaries_r12.sha256)"
  echo "built:     $(date -u +%FT%TZ) on $(hostname), by tools/r12_chain.sh (log logs/b12-cli-build.log)"
  echo "command:   $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify"
  echo "toolchain: $(/home/victor/.cargo/bin/rustc -V); $($CARGO -V)"
  echo "features:  the crate's defaults only; gpu-cuda NOT enabled (cudarc is not compiled in): CPU backend only."
  echo "profile:   [profile.release] opt-level 3, codegen-units 1, lto fat, panic abort, debug false (hashline/Cargo.toml)"
  echo "rustflags: none (no RUSTFLAGS, no .cargo/config in the tree or \$HOME); default target, no target-cpu"
  echo "source:    the lane working copy ops/zkp-mvp/token-io = manifest_r12C.sha256 (list sha256 $(sha256sum $R/manifest_r12C.sha256 | cut -c1-64))"
  echo "scope:     the development rung only (Shieldstral's profile is R-C2); a build record, not a privacy acceptance"
} > $D/zk60_classify.r12.BUILD.txt
finish 0
