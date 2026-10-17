# Masked SC_SZC device-round boundary — cycle 0013

Run `20260927T045233Z-e6183046`, 2026-09-27 UTC. This is one CPU-only
synthetic schedule/differential and source-level traffic study. No production
source, Git metadata, runtime file, receipt or privacy policy changed.

```sh
python3 experiments/sc-szc-device-round-20260927/experiment.py > experiments/sc-szc-device-round-20260927/run.log 2>&1
```

The final exit code was zero. [Machine result](result.json) pins seed
2026092713, the script/source SHA-256, dimensions, CPU and resource limits;
`run.log` preserves stdout. One thread on Intel Core Ultra 9 185H, Python
3.10.12/WSL2; 0.51 s, 17,140 KiB peak RSS; enforced 59 s wall, 55 s CPU,
512 MiB address space, estimated <8 MiB. Only generated field values are
used. No real token, prompt, weight or activation is present.

## Question, baseline and tested seam

The current `hashline/src/private_attention/argument.rs::SC_SZC` builds three
equality-weighted terms and calls `hashline/src/zk.rs::masked_prove`, which
runs `zkp-core/src/sumcheck.rs::prove` on the CPU. Each round reads the active
table pair, evaluates degree+1 polynomial samples, absorbs the *masked*
message through `Transcript::absorb_fp2`, draws a challenge and folds tables.
The CUDA `k_sc_round_zc*` kernels serve FFN zero checks, not this attention
slot. The native grouped softmax evaluator already improved CPU proving;
the later native fold/next-round fusion was slower, so this test does not
propose that same serial fusion.

Candidate boundary: upload this slot's tables once to a device, keep every
folded table resident, evaluate one round in independent pair tiles, reduce
the `(degree+1)` vector, perform unchanged CFS masking/transcript/challenge
on the host, return the challenge, then fold on device. The device route
could remove CPU table scanning from the hot slot, but **eliminates no
field arithmetic or table reads**. It adds input/final transfer, reduction,
two or three launches per round, a round trip after every masked message,
and device table residency. No mask coefficients or private openings are
reused, and the CPU owner would still generate fresh mask material.

The script uses a source-shaped **synthetic** degree-four polynomial with
three equality groups and 13 or 26 Fp2 tables. It is not the full SC_SZC
lookup/helper formula. `CfsMask::round`, `total` and `eval` use the source
coefficient layout and arithmetic. A deterministic SHA-256 test challenge
binds masked messages and round index, but it is **not** Rust's BLAKE3
transcript. Each of 110 round samples matches an independent evaluator that
reconstructs every queried MLE directly from the original Boolean cube,
without table folding. All 91 final table evaluations match the independent
MLE; masked `s(0)+s(1)` and terminal claims hold throughout. The two
128-row/26-table schedules, tiles of 16 and 3 pairs, give identical complete
masked-message digests. Ragged final tiles, zero entries, base and full
extension values occur. Eight mutation controls detect omitted/swapped mask,
message order, round index, extension-limb order, challenge order, wrong
pairing and dropped ragged tile. These are harness controls, **not** receipt
rejection tests.

## Source-derived cost and boundary

For `N` initial rows and `k` Fp2 tables, the generic separate round/fold
schedule reads `4k(N-1)` table elements and writes `k(N-1)`. The resident
device schedule retains those counts: there is no traffic saving within
the tables. Each Fp2 is 16 bytes. At the *synthetic* N=128, k=26, degree=4:

| Item | Count |
|---|---:|
| Initial table upload | 53,248 B |
| Round plus fold logical device reads | 211,328 B |
| Fold logical device writes | 52,832 B |
| Reduced round vectors to host, seven rounds | 560 B |
| Challenges to device, seven rounds | 112 B |
| Final table values to host | 416 B |
| Unreduced partial vectors if sent to host, tile 16 / tile 3 | 880 / 3,680 B |
| Sequential message/challenge dependencies | 7 |

The reduced-vector design needs an extra device reduction launch per round;
sending all tile partials saves that launch but increases transfers and host
reduction. The table read/write totals are logical interface counts, not
DRAM bytes or GPU timings. Neither route can precompute the next challenge
from the current unmasked vector without changing the transcript; masking
must precede absorption. In the [zorch issue](https://github.com/fractalyze/zorch/issues/327),
its authors revised a host-side Fiat–Shamir proposal to a separate device
composite on 2026-07-03. That is a different field/protocol and an upstream
design statement, not our measured result. The [SumCATS DATE 2026 paper](https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf)
and [NVIDIA July 2026 RTX 5090 report](https://developer.nvidia.com/blog/?p=119649)
measure binary-tower/GF(2^128) sumchecks; their 1.81x and 3–4x kernel
figures cannot transfer to this Goldilocks/Fp2 slot. Source dates, licenses
and uninspected commits are recorded in `sources.jsonl`.

## End-to-end ceiling, falsification and next gate

The latest owner A/B has one verified **synthetic 125M T512 block** on RTX
4070 Laptop: GPU whole process 30.055 s mean, prove 17.130 s, witness
8.215 s, verify 0.815 s, serialization plus other/startup residual 3.895 s.
Softmax is roughly half of GPU proving. Even deleting that entire approximate
8.565 s slot at zero cost would leave about **21.49 s** of that one-block
process, a modeled maximum ~28.5% wall reduction. This device schedule
deletes only some slot time and adds costs; its real ceiling is lower and
unmeasured. The old 512 positions are a block geometry, **zero** verified
complete-model positions. For 8B, complete proofs, accepted privacy, 5090
clocks, context length, pass count, startup fraction, steady/total rates,
separate serialization/verification and decode are absent.

Falsify this route if a native implementation fails exact masked round bytes,
challenge/final evaluations, verifier/receipt parity or refusal controls; if
table residency exceeds a measured VRAM budget; or if quiesced slot and
enclosing complete-proof A/B do not improve after transfer and synchronization.
The next small independent experiment should pin the **actual SC_SZC
polynomial** and transcript in native CPU tests, including ragged grouped
tables, then obtain an owner-run per-slot CPU/device transfer and launch
clock under the shared locks before any GPU promotion. No heavy job ran here.
