# GPU code inventory for the production classifier path (Phase A, item 1)

Written 2026-10-30 by the GPU classifier lane (D53), from reading the source of the
reviewed production tree `results/zk60_token_io_r1_20261017/frozen-r19b/` (binary
`cli/zk60_classify.r19b.release.bin`, 6d65d32e…) and of the paused GPU zero-check lane
`ops/zkp-mvp/gpu-zerocheck/`. The two rung and real-scale runs that confirm the reading
are in `PROGRESS.md`, `PHASE_PROFILE.md` and `GPU_PORT_PLAN.md` §3.

## How the GPU code is switched

- **Build:** cargo feature `gpu-cuda` of the `hashline` crate (cudarc 0.13.9, driver API
  plus NVRTC; `src/gpu/kernels.cu` is compiled at first use, about 4.5 s). The production
  binary 6d65d32e… is built **without** it ("features: the crate's defaults only",
  `cli/zk60_classify.r19b.BUILD.txt`), so today's production classifier cannot use the GPU.
- **Run time:** `HL_GPU=1` turns the device path on (`gpu::enabled()` = requested and a
  device initialised). `HL_GPU_REQUIRED=1` makes every decline a panic (fail closed,
  `gpu::declined`). `HL_ZK_CHUNK=force|0|auto` and `HL_GPU_CHUNK_BYTES` (default 1 GiB)
  choose resident or chunked commitments; both give the same bytes.
- **Seam:** `zkp_core::pcs::Backend` (`zkp-core/src/pcs/backend.rs`). hashline plugs in
  `gpu::CudaBackend`, whose store `DevCommit` implements `EncodedStore::{fold_rows,
  columns}`. Without the feature the backend is `zkp_core::pcs::Cpu` and the store type is
  uninhabited.
- **The classify statement has no backend field** (unlike the token CLI's
  `prover_reported`), so a GPU-made classifier receipt is comparable to a CPU-made one on
  all 30 files (28 segments, `statement.json`, `input.dec`).

## Phase by phase

| Prover / verifier phase | GPU code that exists | Tree | Switch | Reached by the classifier CLI (`prove`, `prove-batch`)? |
|---|---|---|---|---|
| **Commitments: encode (LDE/NTT) + keyed BLAKE3 leaves** (A, H, M rows; the boundary B_k; the input endpoint; stages IN-C / OUT-C) | `dev_commit_zk_keyed` → `dev_commit_zk_from_inner` (resident or chunked; kernels `k_dit_p1_pad*`, `k_ntt_p2*`, `k_hash_cols(_stream)_keyed`, `k_zk_pad_scale`). Merkle tree above the leaves on the host | frozen-r19b (and every native tree) | `gpu-cuda` + `HL_GPU=1` | **Yes, with a gpu-cuda build.** Not in the production binary |
| **PCS openings: row combinations and column gathers** | `dev_fold_rows` (`k_fold_rows`, ≤ 4 weight vectors per call), `dev_columns` / chunked re-encode (`k_ntt_p2_gather*`, `k_gather_cols_off`) | frozen-r19b | same | **Yes**, for every commitment made on the device |
| Witness (exact int8 GEMMs, requant, RoPE, softmax chain, A planes) | none | — | — | No: CPU (`private_block/witness.rs`), built twice per prove (seal_chain and the run) |
| LogUp helper inverses (the H rows) | `dev_helpers` (`k_helper`, `k_sum_fp`) | frozen-r19b | same | **No**: used only by the legacy FFN prover (`zk.rs`, `layer.rs`) |
| Element-wise zero-checks, slots 14–18 (masked sumcheck body + folds) | (a) `dev_zerocheck` / `dev_zerocheck_blocks` / `dev_tab_zerocheck` (`k_sc_round_zc20/zc17`, `k_sc_fold`, `k_reduce_f2`); (b) `DevFzcRounds` for slot 18 (`gpu/fzc.rs`, `gpu/fzc_kernels.cu`, the split kernel: 25.9 ms per 2^20 body on the capped 4070) | (a) frozen-r19b; (b) `ops/zkp-mvp/gpu-zerocheck/` only, on the review-r3 base | (a) `HL_GPU=1`; (b) `HL_GPU_ZEROCHECK=1` | **No.** (a) serves the legacy FFN prover only. (b) is not in the classifier tree, and it would decline there anyway: the Shieldstral profile is on the R13 accuracy stack, whose slots 14–19 (and 23 at DD profiles; the classifier's profile is non-DD) are redefined in `private_block/argument_accuracy.rs` (`define_changed`). The R13 F polynomial has variable-length limb sums, a public activation-group column, a 2048 offset and per-layer shifts; the lane's `FzcDesc::check_layout` accepts only the legacy table order |
| Extension rounds (`mask_eval` + `zk::extension`) | none | — | — | No: CPU |
| Matmul slots (public weight folds + sumchecks), norms, lookup-table slots, endpoint slots | none | — | — | No: CPU |
| Multilinear evaluations of resident data | `dev_eval_many` | frozen-r19b | same | No: legacy FFN only |
| Transcript, CFS masking, challenges, randomness | host by design (they stay on the host in every plan) | — | — | — |
| **Verification** (model digest pass, tied-table recompute, weight folds, PCS column checks, sumcheck checks, public-table evaluations) | **none** | — | — | No: the verifier has no device code at all |
| Model hashing (SHA-256 of the padded layers, checkpoint pin) | none | — | — | No: CPU |

Other GPU work in the repository that does not reach the classifier: the zkVM block
(RISC Zero, CUDA Groth16 component not installed), `zkmatrix-rs`'s ring GPU module, the
legacy hashline FFN pass (`hashline pass … --profile v3`, the 58.4 s 8B public-IO number).

## What "gpu: ON" meant on the 8B and TinyLlama stacks

`zk60_trained_block stack-prove` built with `--features gpu-cuda` and run with `HL_GPU=1
HL_GPU_REQUIRED=1` (e.g. `results/zk60_gpu_zerocheck_20261017/stack_r2.sh`; native
`r3_stack_gpu.sh`). It prints `"gpu":"gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU …"` in
its `prover_start` event and writes `"backend": "gpu: on (built with gpu-cuda; the device
path live)"` into the stack statement's `prover_reported`. The device work in those runs
was the same as above: commitments and openings only (plus slot 18 in the zero-check
lane's own stacks).
