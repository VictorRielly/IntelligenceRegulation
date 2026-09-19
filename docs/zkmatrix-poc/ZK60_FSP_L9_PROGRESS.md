# Lane FSP-L9 — the rest of lever L9 (the transform tile kernels and the opening's host tail)

Worktree `/home/victor/wt-fsp-l9`, branch `fsp-l9`, from the main tip
`090ec2a`. Sole writer. Box: WSL laptop, Core Ultra 9 185H, 15 GB RAM,
RTX 4070 Laptop GPU (8,188 MiB, sm_89), shared.

**What this lane is.** Lane AO (round 16, `results/ao_l9_reencode.md`)
attributed the opening's re-encode kernel by kernel and took three
byte-identical levers. It named three items and did not take them:

1. `k_dit_p1_pad_s` is still **56% of the four re-encode kernels**
   (0.06685 s of 0.11928 at 10,752 rows) at 105 GB/s (41% of the
   256 GB/s roof) and 52.7e9 butterfly/s (11% of the ALU roof) — the one
   kernel that is neither bandwidth- nor compute-bound. Two visible
   causes: residual shared-memory bank conflicts in stages 3-4 (a warp
   lands on 8 distinct 64-bit banks instead of 16), and the fact that its
   537 MB of writes per chunk are read exactly once by the very next
   kernel.
2. `k_dif_pb`, untouched, **27% of the four kernels** at 88-100 GB/s,
   same family (contiguous 4,096-element tile, 12 stages), same
   bank-conflict work.
3. The **host tail of `columns_chunked`**: an unpooled 22 MB device
   allocation, a 22 MB download, and a serial host loop copying 2.75 M
   `Fp` into 256 `Vec<Fp>`. ~0.048 s per call = 40% of what the four
   kernels now cost, jittery (3.6-21% of the call).

`ZK60_FIVE_SECOND_PLAN.md` §5 step 3 counts these three at about
**-7 s of the 58.40 s** 8B public-IO feed-forward prove. That figure is
[COUNTED], not measured, and this lane does not measure the 8B pass.

**Files this lane owns.** `hashline/src/gpu/cuda.rs`,
`hashline/src/gpu/kernels.cu`, `hashline/src/gpu/mod.rs`,
`hashline/src/ntt.rs`, `results/fsp2_*`, this ledger.
**Read-only:** everything else, in particular `layer.rs`, `zk.rs`,
`pcs.rs`, `wcache.rs`, `lib.rs`, `Cargo.toml`, `scripts/`, `tests/`.

**Honesty labels.** [MEASURED] a run happened. [COUNTED] arithmetic on
measured pieces. [MODEL] an estimate. Every kernel A/B here is measured
on small shapes; its worth on the 8B pass is COUNTED, never measured, by
this lane.

## Stages

| # | stage | status |
|---|---|---|
| 0 | ledger created and committed | DONE |
| 1 | baseline: builds, `cargo test --release`, `gpu-probe` oracles, twelve byte gates, re-encode benchmark | PENDING |
| 2 | `k_dit_p1_pad_s`: remove the stage 3-4 bank conflicts and/or fuse with its one consumer | PENDING |
| 3 | `k_dif_pb`: the same treatment | PENDING |
| 4 | the host tail of `columns_chunked` | PENDING |
| 5 | closing: gates, A/B, counted worth on the 8B pass | PENDING |

## Log

### 2026-09-19 — stage 0, ledger

Created this file. Read, before touching anything:
`docs/zkmatrix-poc/ZK60_FIVE_SECOND_PLAN.md` §§1.2, 3, 5, 6 (lane 2);
`results/ao_l9_reencode.md` in full; `PROGRESS_UPERF3.md` lines
14196-14260 (lane AO's closing); `results/ao_floors.sh` and
`results/ao_ab_reenc.sh` (the exact gate and A/B invocations);
`hashline/src/gpu/kernels.cu` lines 1030-1210 (`dif_pa_body`,
`k_dif_pb`, `dit_p1_pad_body`); `hashline/src/gpu/cuda.rs`
lines 1425-1600, 1860-2020, 2146-2214 (`encode_rows_view`,
`encode_rows_view_gather`, `columns_chunked`).

Next step: stage 1, the baseline — build both binaries, run
`cargo test --release`, the `gpu-probe` oracles, the twelve byte gates,
and record the re-encode benchmark at 1,024 / 3,584 / 10,752 rows.
