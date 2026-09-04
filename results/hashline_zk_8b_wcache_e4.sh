#!/bin/bash
# [UPERF3-AI rung 3 / E4] --wcache ON THE ZK PATH: is it served, and is it byte-preserving?
# zk.rs used to commit W with plain `pcs::commit`, so lane AC's per-model weight cache was a
# silent no-op for the ZK prover; rung 1 routed it through `wcache::commit_w` with layer.rs's
# own `WKey::new("v3", l, d, f, ..)` key. Four runs, 2 real Mistral-7B layers at T=512 each:
#   1 ZK + --wcache, cold dir      -> expect MISS x2, entries written
#   2 ZK + --wcache, warm dir      -> expect HIT x2, SAME proof digest as run 1
#   3 ZK, no --wcache              -> SAME proof digest again (the flag changes no bytes)
#   4 NON-ZK v3 + --wcache (warm)  -> expect HIT x2: the ZK and non-ZK passes SHARE entries
set -u
R=/home/victor/wt-uperf3-ai
SP=$R/results/scratch-ai
MIS=/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
GPU=$R/hashline/target-gpu/release/hashline
CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
WC=$SP/wc_e4
L=2
mkdir -p "$SP"; rm -rf "$WC"; mkdir -p "$WC"

go () { # go <tag> <proof-out> <args...>
  local tag=$1 out=$2; shift 2
  echo; echo "=== $tag ==="; date '+%F %T'
  HL_GPU=1 HL_WCACHE_VERBOSE=1 LD_LIBRARY_PATH=$CUDA_LD \
    "$GPU" pass "$L" 512 --profile v3 --export "$MIS" --threads 8 --proof-out "$out" "$@" 2>&1 \
    | grep -Ei 'wcache|commit W|PROVE|PROOF sha256|ACCEPT|REJECT|error|panic|layer +[0-9]+:'
  [ -f "$out" ] && echo "PROOF $tag: $(sha256sum "$out" | cut -d' ' -f1)  $(stat -c %s "$out") B"
}

go "RUN 1  ZK + --wcache (COLD)" "$SP/e4_zk_cold.bin" --zk --seed 1 --wcache "$WC"
echo "wcache dir after run 1: $(du -sh "$WC" | cut -f1), $(ls "$WC" | wc -l) files"
go "RUN 2  ZK + --wcache (WARM)" "$SP/e4_zk_warm.bin" --zk --seed 1 --wcache "$WC"
go "RUN 3  ZK, NO --wcache"      "$SP/e4_zk_none.bin" --zk --seed 1
go "RUN 4  NON-ZK v3 + --wcache (WARM, written by the ZK prover)" "$SP/e4_v3_warm.bin" --wcache "$WC"

echo; echo "=== E4 VERDICT ==="
ok=1
cmp -s "$SP/e4_zk_cold.bin" "$SP/e4_zk_warm.bin" || { echo "FAILURE: cold != warm"; ok=0; }
cmp -s "$SP/e4_zk_cold.bin" "$SP/e4_zk_none.bin" || { echo "FAILURE: --wcache changes the proof bytes"; ok=0; }
[ $ok = 1 ] && echo "BYTE-IDENTICAL: cold == warm == no-cache (the ZK proof is invariant under --wcache)"
rm -f "$SP"/e4_*.bin
rm -rf "$WC"
date '+%F %T'
