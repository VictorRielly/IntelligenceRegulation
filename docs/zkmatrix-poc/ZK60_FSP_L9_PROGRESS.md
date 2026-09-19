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
| 1 | baseline: builds, `cargo test --release`, `gpu-probe` oracles, twelve byte gates, re-encode benchmark | DONE — every gate green |
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

### 2026-09-19 — stage 1, the baseline on the UNTOUCHED tree

Scripts written (this lane's own files): `results/fsp2_build.sh` (both
binaries, offline, `-j 2`, each cargo invocation under
`flock -w 900 /tmp/zk-build.lock`), `results/fsp2_floors.sh` (lane AO's
twelve-gate script re-pointed here, builds removed so it never takes the
build lock and may be wrapped in the heavy lock; `FSP_CPU_BIN` /
`FSP_GPU_BIN` let the same gates run against a saved pre-change build),
`results/fsp2_oracles.sh`, `results/fsp2_ab_reenc.sh` (the ABBA A/B).

The untouched binaries were copied aside before any edit, so every
baseline number below is from a build of `090ec2a` exactly.

**Builds** [MEASURED] `results/fsp2_build.log`, exit 0 — CPU binary and
GPU binary (`--features gpu-cuda`, `CARGO_TARGET_DIR=hashline/target-gpu`).

**`cargo test --release`** [MEASURED] `results/fsp2_cputest.log`, exit 0
— **202 tests passed, 0 failed** across 26 test binaries.

**`gpu-probe` device-versus-CPU oracles** [MEASURED]
`results/fsp2_oracles_base.log`, exit 0, on the RTX 4070 Laptop GPU:

* field probe: 1,048,576 pairs incl. edge values, **0 mul/add/sub
  mismatches**;
* **blake3 checks GREEN** (322 row counts x 64 columns, 0 failing);
* **ntt checks GREEN** (7 shapes, inv_rate 2/4/8 — the device RS encoding
  == the CPU encoder element for element);
* **chunked-commit checks GREEN** (15 shapes — streamed leaves == CPU
  `hash_columns`, AND the re-encoded OPENING COLUMNS == the CPU encoding
  at 16 indices, at inverse rates 2, 4 and 8, i.e. rb = 1, 2, 3).

**The twelve byte gates** [MEASURED] `results/fsp2_floors_base.log`,
exit 0 — **ALL TWELVE GREEN**: `50cf7bdfd6b5b182..` 66,844,928 B,
`5f368db6240e0614..` 70,758,084 B, `021485e4f80ec695..` 87,228,528 B,
`40eb54795e023c77..` 87,697,008 B, each on the CPU binary, on the GPU
binary, and on the GPU binary with `HL_GPU_CHUNK_BYTES=100000000
HL_GPU_CHUNK_ROWS=128` forcing the chunked commit and the opening
re-encode.

**Stage 1 verdict: the floor is GREEN.** Nothing was red on the
untouched tree, so the lane may build on it.

**The re-encode benchmark** [MEASURED] `results/fsp2_bench_base.log`,
`HL_GPU_BENCH_REENC=1 hashline gpu-probe`,
`HL_BENCH_ROWS=1024,3584,10752 HL_BENCH_REPS=7`, best of 7, two
processes, `nvidia-smi` 0 MiB before, box otherwise quiet:

| rows | `columns_chunked` p1 / p2 | `k_dit_p1_pad_s` | `k_dif_pb` | `k_dif_pa_f` | `k_ntt_p2_gather_sp` |
|---:|---:|---:|---:|---:|---:|
| 1,024 | 0.00994 / 0.01214 s | 0.00476 / 0.00643 | 0.00188 / 0.00219 | 0.00108 / 0.00125 | 0.00062 / 0.00077 |
| 3,584 | 0.02717 / 0.03918 s | 0.01899 / 0.01864 | 0.00553 / 0.00654 | 0.00321 / 0.00420 | 0.00267 / 0.00259 |
| **10,752** (the 8B W shape) | **0.09468 / 0.09791 s** | **0.05642 / 0.05458** | **0.01432 / 0.01676** | **0.01219 / 0.01237** | **0.00627 / 0.00688** |

**A finding that changes the size of the prize, and it must be said
first.** Lane AO recorded `columns_chunked` at **0.22231 s** at this
shape (`results/ao_l9_reencode.md` §2) and 0.17828 s after its three
levers (§5.1). On a quiet box today the same call on the same tree is
**0.0947-0.0979 s** — **1.8-2.3x faster than AO's post-lever figure**,
with `k_dit_p1_pad_s` at 124.9-129.1 GB/s rather than AO's 105, and
`k_dif_pb` at 168-197 GB/s rather than AO's 88-100. AO's header records
"lane AN on the CPU in a sibling worktree"; this box's documented ~2x
run-to-run variance is the obvious explanation. **Every per-kernel
second in AO's report, and therefore the -7 s that
`ZK60_FIVE_SECOND_PLAN.md` §5 step 3 counts from it, is measured on a
loaded box and is an over-estimate of what is left to win.** This lane
re-measures its own baseline and counts from that.

The shares at 10,752 rows on the quiet box, over the four kernels the
opening actually runs (`k_dif_pa_f` + `k_dif_pb` + `k_dit_p1_pad_s` +
`k_ntt_p2_gather_sp` = 0.0906 s, process 2):

| kernel | s | share | GB/s (of a 256 GB/s roof) |
|---|---:|---:|---:|
| `k_dit_p1_pad_s` | 0.05458 | **60.2%** | 129.1 (50%) |
| `k_dif_pb` | 0.01676 | 18.5% | 168.1 (66%) |
| `k_dif_pa_f` | 0.01237 | 13.7% | 227.9 (89%) |
| `k_ntt_p2_gather_sp` | 0.00688 | 7.6% | — |

So `k_dit_p1_pad_s` is still the elephant (60%, not AO's 56%), and it is
still the one kernel that is neither bandwidth- nor compute-bound; but
`k_dif_pb` at 168-197 GB/s is much closer to the roof than AO's 88-100
suggested, so less is available there.

Run-to-run spread between the two baseline processes at 10,752 rows:
`columns_chunked` 3.4%, `k_dit_p1_pad_s` 3.4%, `k_dif_pb` **17%**
(`k_dif_pb` is the noisy one — any claim about it needs the ABBA).

**A note on the bench's printed "residue" line.** It subtracts `kern`,
which is built from the DENSE `k_ntt_p2_gather`; the opening actually
runs the pruned `_sp`. The honest sum is
`k_dif_pa_f + k_dif_pb + k_dit_p1_pad_s + k_ntt_p2_gather_sp` = 0.0906 s
against `columns_chunked` = 0.0979 s, i.e. a host/d2h/launch residue of
about **0.0073 s (7.4%)** at this shape — not AO's 17.3%, and not the
negative number the line prints.
