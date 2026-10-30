#!/bin/bash
# TOKEN ROUND 13 (R-C2 on native R12b): the freeze chain for ops/zkp-mvp/token-io-r12b.
#  1. candidate manifest r13A (before the suite; the native tests write pid-named dirs under results/)
#  2. the FULL suite s17, --no-fail-fast (need 7.5 / cap 9.5 from s16's measured 6.77 GiB)
#  3. manifest r13B after the suite, compared with r13A (expect no source change)
#  4. the ignored Shieldstral test through native R12b on Astra's actual export (streams the 7.7 GB
#     checkpoint once; ~0.9 GiB RSS for the 805 MB embedding read)
#  5. the classifier CLI binary (example zk60_classify), copied to cli/ with its sha256 and BUILD note
# Each guarded step honours the hold file r13/HOLD. Marker r13/logs/r13_chain.done = 0 when all
# passed, else the failing step's name. The freeze copy itself is done by hand after reading the
# results (tools/freeze13.py freeze).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
T=$R/r13
L=$T/logs
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r12b/hashline
CARGO=/home/victor/.cargo/bin/cargo
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
finish() { echo "$1" > $L/r13_chain.done; exit 0; }
hold() { while [ -e $T/HOLD ]; do sleep 30; done; }
python3 $T/tools/freeze13.py snapshot $T/manifest_r13A.sha256 > $L/r13A-manifest.log 2>&1 || finish manifest-A
hold
$G --class cpu --need-gib 7.5 --cap-gib 9.5 --label tio-s17-suite --wait-secs 14400 --max-secs 3600 --log $L/s17-suite.log --done $L/s17-suite.guard.done --result-json $L/s17-suite.guard.json -- $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > $L/s17-suite.exit
python3 $T/tools/freeze13.py snapshot $T/manifest_r13B.sha256 > $L/r13B-manifest.log 2>&1
python3 $T/tools/freeze13.py compare $T/manifest_r13A.sha256 $T/manifest_r13B.sha256 >> $L/r13B-manifest.log 2>&1
[ "$(cat $L/s17-suite.exit)" = "0" ] || finish s17
hold
$G --class cpu --need-gib 1.5 --cap-gib 2.5 --label tio-r13-shieldstral-r12b --wait-secs 14400 --max-secs 1200 --log $L/shieldstral-r12b.log --done $L/shieldstral-r12b.guard.done --result-json $L/shieldstral-r12b.guard.json -- /usr/bin/env ZK60_RC2_SHIELDSTRAL_EXPORT=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/dg_r12b_t256 $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- private_block::token_io::classify_tied_tests::rc2_the_shieldstral_export_tables_are_recomputed_through_native_r12b --exact --ignored --nocapture
echo $? > $L/shieldstral-r12b.exit
[ "$(cat $L/shieldstral-r12b.exit)" = "0" ] || finish shieldstral
hold
$G --class build --need-gib 1.5 --cap-gib 3 --label tio-b13-cli-build --wait-secs 14400 --max-secs 2400 --log $L/b13-cli-build.log --done $L/b13-cli-build.guard.done --result-json $L/b13-cli-build.guard.json -- $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify
echo $? > $L/b13-cli-build.exit
[ "$(cat $L/b13-cli-build.exit)" = "0" ] || finish b13
D=$R/cli
B=$D/zk60_classify.r13.release.bin
cp $H/target/release/examples/zk60_classify $B || finish copy
sha256sum $B > $D/binaries_r13.sha256
{
  echo "zk60_classify round-13 CPU binary (rung R-C2: the classifier CLI with the tables re-derived from the pinned tied tensor; native R12b base)"
  echo "file:      $B"
  echo "sha256:    $(cut -c1-64 $D/binaries_r13.sha256)"
  echo "built:     $(date -u +%FT%TZ) on $(hostname), by r13/tools/r13_chain.sh (log r13/logs/b13-cli-build.log)"
  echo "command:   $CARGO build --release --offline --locked -j2 --manifest-path $H/Cargo.toml --example zk60_classify"
  echo "toolchain: $(/home/victor/.cargo/bin/rustc -V); $($CARGO -V)"
  echo "features:  the crate's defaults only; gpu-cuda NOT enabled (cudarc is not compiled in): CPU backend only."
  echo "profile:   [profile.release] opt-level 3, codegen-units 1, lto fat, panic abort, debug false (hashline/Cargo.toml)"
  echo "rustflags: none (no RUSTFLAGS, no .cargo/config in the tree or \$HOME); default target, no target-cpu"
  echo "source:    the lane tree ops/zkp-mvp/token-io-r12b = r13/manifest_r13A.sha256 (list sha256 $(sha256sum $T/manifest_r13A.sha256 | cut -c1-64))"
  echo "scope:     the development rung registered (Shieldstral's tied path is wired and tested, no Shieldstral classifier run profile yet); a build record, not a privacy acceptance"
} > $D/zk60_classify.r13.BUILD.txt
finish 0
