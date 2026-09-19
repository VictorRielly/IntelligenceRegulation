# FSP lane 3 — the byte gates, stage by stage

Lane: give the PRIVATE v3 prover (`hashline/src/zk.rs`) lane AL's two host
fixes, byte-preservingly, behind switches. Ledger:
`docs/zkmatrix-poc/ZK60_FSP_ZKHOST_PROGRESS.md`.

All runs: `hashline pass 12 512 --threads 2 --proof-out F <profile args>`,
`CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2`,
`M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl`,
v3 export `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export`.
Worktree `/home/victor/wt-fsp-zkhost`, branch `fsp-zkhost`, from `ad0f50c`.
WSL box, RTX 4070 Laptop (8,188 MiB), shared with another agent.
[MEASURED, NOISY-SHARED, 2026-09-19]

The frozen expectations (`scripts/hashline_cl_gpu_gates.py:110-113`):

| profile | prover reached | sha256 | bytes |
|---|---|---|---:|
| v2 | `layer.rs` v2 (public) | `50cf7bdfd6b5b182..` | 66,844,928 |
| v3 | `layer.rs` v3 (public) | `5f368db6240e0614..` | 70,758,084 |
| zk | `zk.rs::prove_layer_zk` (v2, **NOT changed by this lane**) | `021485e4f80ec695..` | 87,228,528 |
| **zk-v3** | **`zk.rs::prove_layer_zk_v3_inner` — the body this lane changes** | `40eb54795e023c77..` | 87,697,008 |

`hashline.rs:367` routes `--zk --profile v3` to `pass_zk_v3` and `--zk`
alone to `pass_zk`, so **zk-v3 is the gate that actually tests this lane's
tiling argument, twelve layers deep**; the zk gate is a no-regression
control on a body the lane does not touch, and the two public gates are a
control on files it does not own.

The GPU runner reads `nvidia-smi` WHILE HOLDING `/tmp/zk-heavy.lock` and
refuses to launch if any compute app is present or `memory.used > 1500
MiB`; every launch below read 0 MiB / 0 apps. One prover process per
invocation; no two GPU runs were ever chained.

## Stage 2 — baseline, untouched tree (must be green before any change)

| profile | cpu | gpu | gpu + `HL_ZK_CHUNK=1` |
|---|---|---|---|
| v2 | GREEN | GREEN | — |
| v3 | GREEN | GREEN | — |
| zk | GREEN | GREEN | GREEN |
| zk-v3 | GREEN | GREEN | GREEN |

`cargo test --release -- --test-threads=2`: **exit 0, 259 passed,
0 failed, 28 test binaries.**

## Stage 3 — the host staging pool (`HL_FSP_POOL`, default ON)

| profile | cpu | gpu | gpu + `HL_ZK_CHUNK=1` | gpu + `HL_GPU_CHUNK_BYTES=100000000` |
|---|---|---|---|---|
| v2 | GREEN | — | — | — |
| v3 | GREEN | — | — | — |
| zk | GREEN | GREEN | GREEN | — |
| zk-v3 | GREEN | GREEN | GREEN | GREEN |

Every digest is the frozen one at the frozen length.

`cargo test --release -- --test-threads=2`: **exit 0, 259 passed,
0 failed, 28 test binaries** — identical to the baseline count.

## Stage 4 — the int8-plane fold (`HL_FSP_I8FOLD`, default ON)

| profile | cpu | gpu | gpu + `HL_ZK_CHUNK=1` | gpu + `HL_GPU_CHUNK_BYTES=100000000` |
|---|---|---|---|---|
| v2 | GREEN | GREEN | — | — |
| v3 | GREEN | GREEN | — | — |
| zk | GREEN | GREEN | GREEN | GREEN |
| zk-v3 | GREEN | GREEN | GREEN | GREEN |

Plus the ROLLBACK arm: zk-v3 on the CPU binary with
`HL_FSP_POOL=0 HL_FSP_I8FOLD=0` — GREEN. Both arms of the A/B produce the
frozen proof from one binary, which is what makes the A/B a measurement
of the same computation and the switches a real rollback.

A further 20 A/B runs of the zk-v3 profile on the CPU binary (10 per arm,
`results/fsp3_ab_cpu.log`) each reproduced `40eb54795e023c77..` at
87,697,008 B, so the zk-v3 digest has now been reproduced 26 times across
both arms, both binaries and three device configurations in this lane.

**NO DIGEST MOVED AT ANY POINT IN THIS LANE.**

## Owed to a quiet window (NOT run here, by instruction)

* The eight v3 tamper legs at Mistral width through the GPU
  zero-knowledge prover (honest ACCEPT, then 8 of 8 REJECT).
* Any 8B A/B of these two switches. The last private 8B pass peaked at
  8,585 MB on an 8,188 MiB card and paged; it must be launched alone,
  detached, with the card verified idle, never chained behind another
  GPU job.
