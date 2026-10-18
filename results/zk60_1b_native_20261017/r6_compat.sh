#!/bin/bash
# NATIVE LANE R6 item 1: build the R6 CPU release CLI, then show that RUN-WIDE
# exports keep their statement identities AND schedule digests under R6: the
# R6 CLI stack-verifies the PROOF BYTES of two R5b runs (8B T32 quiet run,
# TinyLlama T32) from the R5b verifier copies, pinned to the R5b identities.
# Under R6's publication rule (review r5_A) an R5b-format statement/ is not
# the R6 rendering, so each run is copied into a fresh r6/compat-<v>/ with an
# R6-layout unverified statement (r6_compat_prepare.py); pass 1 verifies and
# publishes statement/, pass 2 re-verifies against it (the byte check).
# Then the R6 GPU-feature CLI build (compile check of the gpu-cuda path).
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
O=$D/r6
X=$O/zk60_trained_block.release.bin
pre() {  # $1 = need, $2 = class
  until out=$(python3 $G check --class ${2:-cpu} --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
python3 -B $D/r5_manifest.py $O/manifest_cli.json "sources at the R6 CLI build"
pre 2.5 build
python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label r6-cli-build --wait-secs 14400 --max-secs 3600 \
  --log $O/cli-build.log --done $O/cli-build.done --result-json $O/cli-build.guard.json \
  -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block
rc=$?; echo "cli-build exit $rc"
[ $rc -eq 0 ] || exit $rc
cp $H/target/release/examples/zk60_trained_block $X
sha256sum $X > $O/binaries.sha256
R=$D/r5b
for spec in "llama3_8b_pg_rot1_T32 stack-llama3_8b_pg_rot1_T32-ho00-cpu-quiet 259dad7cb2c9739e44cfdf5c27c4c87090458cf330e9d39b592221094ae3537f" \
            "pg_rot1_b4_T32_cal128 stack-pg_rot1_b4_T32_cal128-ho00-cpu 9b71dfb0a2b4608d4a60d3bc4310a59573b6fcdf4a638f53a246c17b2cf24868"; do
  set -- $spec
  A=$O/compat-$1
  python3 -B $O/r6_compat_prepare.py $R/$2/run $A || exit 1
  for pass in publish recheck; do
    pre 2.5
    python3 $G run --class cpu --need-gib 2.5 --cap-gib 8 --label r6-compat-$pass-$1 --wait-secs 14400 --max-secs 3600 \
      --log $O/compat-$pass-$1.log --done $O/compat-$pass-$1.done --result-json $O/compat-$pass-$1.guard.json \
      -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export $R/verifier-exports/$1 --artifact $A/run --expect-statement $3
    echo "compat $pass $1 exit $(cat $O/compat-$pass-$1.done 2>/dev/null)"
  done
done
pre 3 build
python3 $G run --class build --need-gib 3 --cap-gib 5 --label r6-gpu-cli-build --wait-secs 14400 --max-secs 3600 \
  --log $O/gpu-cli-build.log --done $O/gpu-cli-build.done --result-json $O/gpu-cli-build.guard.json \
  -- /usr/bin/env CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD CARGO_TARGET_DIR=$H/target-gpu \
     $C build --release --offline --locked -j2 --manifest-path $M --features gpu-cuda --example zk60_trained_block
rc=$?; echo "gpu-cli-build exit $rc"
[ $rc -eq 0 ] || exit $rc
cp $H/target-gpu/release/examples/zk60_trained_block $O/zk60_trained_block.gpu.release.bin
sha256sum $X $O/zk60_trained_block.gpu.release.bin > $O/binaries.sha256
cat $O/binaries.sha256
