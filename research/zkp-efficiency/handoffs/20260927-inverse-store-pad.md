# Handoff: produce compact hiding coefficients at the inverse NTT final store

Run `20260927T035233Z-8a5c6f18`. Research only; main/Claude owns review,
native implementation, locks and integration. [Experiment and limits](../experiments/inverse-store-pad-20260927/README.md),
[result](../experiments/inverse-store-pad-20260927/result.json).
Source pins are for the read-only project checkout inspected here; the
owner's keyed-GPU candidate has different `cuda.rs`/`kernels.cu` hashes,
so its exact patch locations and lifetimes must be rechecked there.

## Interface and exact patch seam

Target the compact **chunked** hiding commit/opening path only, with
`pw=n+q<=nn`, `n` a power of two and fresh per-proof `pads`. Host seam:
`hashline/src/gpu/cuda.rs::encode_rows_view_zk` and
`encode_rows_view_zk_gather`, called by `commit_zk_chunked` and
`columns_chunked_zk`. Their current inverse call plus `k_zk_pad_scale`
becomes one inverse launch sequence whose final pass writes `coef2` at
stride `pw`. Forward `k_ntt_p1` still receives `n_src=pw` and the same
`coef2`, so its zero extension, p2, hashing and openings remain untouched.
Additive kernel names and an opt-in A/B switch should retain the current
reference route. Register the new kernel(s) in `FUNCS` without moving any
transcript draw or commitment construction.

CUDA seam: `hashline/src/gpu/kernels.cu::k_ntt_p1` final store when
`log_n<=12`, and `k_ntt_p2[_f]` final store when `log_n>12`. Input is the
existing inverse intermediate; output is a **different** allocation
`coef2[rows][pw]`. Preserve stage/twiddle order. After the inverse's
current scale, store

```
for 0 <= i < n:
    coef2[row*pw+i] = (inverse_raw[i]/n - (i<q ? pad[row*q+i] : 0)) * h^i
for n <= i < n+q:
    coef2[row*pw+i] = (pad[row*q+i-n] - (i<q ? pad[row*q+i] : 0)) * h^i
```

All operations are canonical Goldilocks arithmetic. For p2, map output
coefficient `i` using its current `t*4096 + tile*J + jj` mapping; assign
each of the `nt=n/4096` tiles one contiguous disjoint tail interval of
length `ceil(q/nt)` or shorter. The candidate script detects any missing
or duplicate writer. The n<=4096 one-pass variant may omit `coef` scratch
if its caller's allocation/lifetime changes; n>4096 retains `coef` for p1.
Do not alias `coef` to wider-stride `coef2` across rows.

## Validation and promotion gate

The synthetic oracle passes 56 cases (10 p2), 16 ragged multirow/chunk
comparisons and 816 direct-DFT/polynomial points; eight controls fire.
At n=16,384/q=256 it removes 262,144 **logical** bytes per row from the
inverse-final-plus-pad interface and changes modeled 32-byte warp-sector
requests 20,736 -> 12,544, with **no peak scratch reduction**. This is no
CUDA timing. Prior first-forward-load fusion had a sector regression; the
new path preserves forward source locality.

Native validation should compare the existing and opt-in forms with the
same seeded per-proof pad material, over both inverse branches, q=0/q<n/
q=n, ragged chunks, full/compact stride, resident fallback boundaries and
dirty pool tails. Compare complete encoded columns, keyed Merkle leaves,
openings and serialized independently verified receipts. Separate q>n:
the CPU polynomial overlaps correctly but current CUDA `k_zk_pad_scale`
loses the negative term in the overlapping tail. Treat that as a distinct
correctness repair and receipt change, with a failing-first vector, before
enabling q>n. Include the exact stage and refusal schedule.

Then under the shared GPU/heavy locks, A/B the inverse final pass, pad
kernel, complete encode/hash phase, full proof readiness, transfers and
peak VRAM on a named device at fixed n/q/rows/chunk size. Count new field
muls, register pressure, occupancy and extra tail work. A reduction in
modeled sectors is falsified as a performance claim if whole readiness
does not improve. The current ~16.5 s CPU A/H encode+Merkle parent phase
is only a loose one-block upper envelope; the complete 8B impact has no
measured ceiling. The newer keyed RTX 4070 Laptop A/B proves one synthetic
125M block in 17.13 s mean versus 32.95 s CPU, but gives no inverse-store/
pad phase attribution; remaining softmax work is roughly half the GPU
prover. This fusion is a lower-priority follow-up to that larger bottleneck.
No full-stack 50-token/s result follows.

## Unresolved proof/privacy obligations

Keep fresh pads/salts/masks, exact coset powers, committed column order,
keyed roots/openings, transcript/RNG event order and fallback behavior.
The only accepted D22 privacy statement covers the CPU toy profile; GPU
or 125M/8B privacy does not follow from this arithmetic test. D19b/D23
remain pending. Main/security owners must review any q>n repair and new
GPU memory lifetime. No external code or license material was copied.
