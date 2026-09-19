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
| 2a | `k_dit_p1_pad_s`: remove the stage 3-4 bank conflicts | DONE — built, measured, **WITHDRAWN**: 0.93x mean, a regression. Default OFF behind `HL_GPU_SMEM_SWZ` |
| 2b | `k_dit_p1_pad_s`: fuse it with its one consumer | DONE — `k_dit_p1_pad_c` + `k_ntt_p2_gather_spc`, **1.24x** on the kernel, **1.16x** on the four, byte-identical. Default ON, `HL_GPU_P1_COMPACT=0` restores |
| 3 | `k_dif_pb`: the same treatment | DONE — same swizzle, **0.91x mean, also a regression**. Default OFF behind `HL_GPU_SMEM_SWZ_PB`. `k_dif_pb` is already at 66-77% of the memory roof |
| 4 | the host tail of `columns_chunked` | PARTLY — the serial 256-vector split is now parallel (byte-identical, unmeasured); pooling the 22 MB output buffer is **blocked by an allocation assertion in `hashline/tests/zk60_gpu_commit.rs`, a file this lane does not own**; the pinned download is not done |
| 5 | closing: gates, A/B, counted worth on the 8B pass | DONE — every gate green, **0.8-1.8 s counted** off the 58.40 s pass |

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

### 2026-09-19 — stage 2 part A and stage 3: THE BANK-CONFLICT ITEM IS A MEASURED NEGATIVE

**What was built.** `kernels.cu` `shz(x) = x ^ (bit4(x) ? 15 : 0)` — a
relabelling of shared-memory addresses that provably removes the 2-way
bank conflicts of the contiguous-tile kernels' low stages. The proof is
written out at the definition: shared memory is 32 banks of 4 bytes and
a warp's 64-bit access is served in two 16-thread phases, so a phase is
conflict-free exactly when its 16 u64 indices are distinct mod 16; at
stage `st` the tile index `((b >> (st-1)) << st) + (b & (half-1))` has
bit `st-1` always 0 and puts the fourth varying bit of `b` at bit 4, so
sixteen threads reach only eight banks for every `st <= 4`. XOR-ing the
low nibble by 15 when bit 4 is set splits those two groups of eight into
disjoint halves of the sixteen banks, and for `st >= 5` it is a constant
XOR that preserves the pattern that was already conflict-free. The
partner index is free: `SWZ(i + half) == SWZ(i) ^ half`, except
`^ 31` when `half == 16`. It is a permutation, hence byte-identical by
construction: same operand pairs, same twiddles, same order, same global
loads and stores.

Kernels: `k_dit_p1_pad_sz` (switch `HL_GPU_SMEM_SWZ`) and `k_dif_pb_z`
(switch `HL_GPU_SMEM_SWZ_PB`), both templated off the existing bodies so
the inherited kernels are untouched code paths.

**The A/B** [MEASURED] `results/fsp2_ab_s2.log`, ABBA over four
processes, best of 7, `nvidia-smi` 0 MiB before, quiet box:

| rows | `k_dit_p1_pad_s -> _sz` (4 processes) | `k_dif_pb -> _z` (4 processes) |
|---:|---|---|
| 1,024 | 0.907 / 0.897 / 0.948 / 0.914 | 0.921 / 0.908 / 0.923 / 0.917 |
| 3,584 | 0.905 / 0.909 / 0.917 / 0.910 | 0.920 / 0.928 / 0.864 / 0.936 |
| 10,752 | 0.968 / 0.937 / 1.012 / 0.933 | 0.941 / 0.897 / 0.905 / 0.814 |

**Eleven of twelve measurements on each kernel are below parity.** Mean
about **0.93x on `k_dit_p1_pad_s`** and **0.91x on `k_dif_pb`** — the
change makes both kernels **slower**, consistently, at every shape.

**What that means, and it is the useful part.** The four extra integer
operations per butterfly (`shz(i)` plus one XOR for the partner) cost
about 11% of this kernel, and the measurement says the net is about -7%.
So **removing the residual bank conflicts is worth only about 4% of
`k_dit_p1_pad_s`** — they are not what stands between this kernel and
the memory roof. The kernel is bound by the per-butterfly instruction
stream (a 64x64 Goldilocks multiply with a three-branch reduction, plus
index arithmetic and a twiddle load), not by the shared-memory pipeline.
A cheaper permutation does not exist: a padded layout (`x + (x >> 4)`,
`x + (x >> 3)`, `x + (x >> 5)`) leaves 4 of the 16 banks colliding at
`st = 2` and none of them fixes `st = 1`, which is why the XOR form was
chosen; and swizzling only the low stages would need an in-place
un-permute pass costing about half a stage to save about two stages'
conflict overhead.

**Disposition.** Both switches **default OFF**; the kernels stay in the
module behind `HL_GPU_SMEM_SWZ=1` / `HL_GPU_SMEM_SWZ_PB=1` so the
measurement is reproducible and no future lane re-derives it. The
default path is byte-for-byte lane AO's. **Stage 3 (`k_dif_pb`, the same
treatment) is answered by the same run and is also negative**;
`k_dif_pb` is in any case at 168-197 GB/s = 66-77% of the 256 GB/s roof
on a quiet box, which is where lane AO declared `k_dif_pa_f` closed.
This costs the `ZK60_FIVE_SECOND_PLAN` ladder's step 3 its
bank-conflict half.

**A note on the bench's printed "residue" line.** It subtracts `kern`,
which is built from the DENSE `k_ntt_p2_gather`; the opening actually
runs the pruned `_sp`. The honest sum is
`k_dif_pa_f + k_dif_pb + k_dit_p1_pad_s + k_ntt_p2_gather_sp` = 0.0906 s
against `columns_chunked` = 0.0979 s, i.e. a host/d2h/launch residue of
about **0.0073 s (7.4%)** at this shape — not AO's 17.3%, and not the
negative number the line prints.

### 2026-09-19 — stage 2 part B: FUSING THE EXPAND TRANSFORM WITH ITS ONE CONSUMER

The other half of lane AO's item 1: *"its 537 MB of writes per chunk are
read exactly once by the very next kernel, so the two can be fused."*

**A literal fusion is impossible and it is worth saying why.** The
consumer `k_ntt_p2_gather_sp` needs, for each residue `qq`, one element
from EVERY one of the row's `nt` = 16 blocks — i.e. the whole
65,536-wide encoded row, 512 KB, in one thread block. Ada has 100 KB of
shared memory per SM. No launch shape fuses them.

**What can be done instead: stop writing what the consumer never reads.**
In the pruned opening the consumer touches only the `nq` distinct
residues `col mod 4096` of the sampled columns — **244 of 4,096 at the
8B draw, 6.0%**. So 94% of `k_dit_p1_pad_s`'s 4,096 stores per block are
dead. Two new kernels:

* `k_dit_p1_pad_c` — `k_dit_p1_pad_s` with the final store loop replaced
  by `dst[(row * nt + blk) * nqp + jc] = sh[qlist[jc]]`. Every stage,
  every twiddle, every operand pair and every global LOAD is unchanged;
  `blk` IS the consumer's block index `t`, and `nqp` is the residue
  list's PADDED length, so the padding lanes re-store a duplicate and no
  address is written twice or needs a branch.
* `k_ntt_p2_gather_spc` — `k_ntt_p2_gather_sp` whose tile load reads
  `r[t * nqp + base + jc]` out of that compact block instead of
  gathering `r[t * NTT_BLK + qlist[base + jc]]` out of the full row. The
  value at that address is the same by the producer's store. Everything
  after the load — twiddles, operand pairs, stage order, the `sel`
  lookup, the output store — is the dense kernel's, byte for byte. The
  compact read is also CONTIGUOUS in `jc` where the old one was a
  scatter.

Switch `HL_GPU_P1_COMPACT=0` restores the pair lane AO left. The scratch
buffer is unchanged in size (the compact block simply occupies its first
`rows * nt * nqp` elements), so no allocation and no allocation counter
moves. It is used only where the pruned residue list exists, i.e. only
on the NON-hiding chunked opening; the hiding opening
(`encode_rows_view_zk_gather`) is untouched and is the obvious follow-up.

**Traffic** [COUNTED, printed by the bench], at 10,752 rows: the
producer's stores fall from `rows * nn * 8` = 5.64 GB to
`rows * nt * nqp * 8` = 0.35 GB, a **16.0x cut**; its reads (1.41 GB)
are unchanged. Total global traffic for the kernel **7,046 -> 1,762 MB,
4.0x**.

**The A/B** [MEASURED] `results/fsp2_ab_c.log`, six processes
A-B-C-C-B-A, best of 7, `nvidia-smi` 0 MiB before each. The per-kernel
arms run BACK TO BACK IN ONE PROCESS (the bench launches each kernel by
name, independently of the switch), which is why they are the stable
measurement:

| rows | `k_dit_p1_pad_s -> _c` (4 processes) | `k_ntt_p2_gather_sp -> _spc` | the pair | the four kernels |
|---:|---|---|---|---|
| 1,024 | 1.076 / 1.065 / 1.076 / 1.085 | 1.665 / 1.674 / 1.683 / 1.754 | 1.11-1.13 | **1.076** mean |
| 3,584 | 1.061 / 1.038 / 1.002 / 1.077 | 1.727 / 1.633 / 1.652 / 1.918 | 1.04-1.13 | **1.058** mean |
| **10,752** (the 8B W shape) | **1.240 / 1.228 / 1.232 / 1.270** | **2.162 / 2.209 / 2.194 / 2.225** | **1.287-1.327** | **1.162** mean |

At the 8B W shape, in seconds: `k_dit_p1_pad_s` **0.0546 -> 0.0441**,
`k_ntt_p2_gather_sp` **0.0062 -> 0.0028**, the pair **0.0609 -> 0.0469**
(**1.30x**), the four re-encode kernels **0.1035 -> 0.0898**
(**1.162x**, spread 3.4% over four processes).

Both halves move, and the consumer moves more in ratio than the
producer: its tile load was a SCATTER over the full encoded row and is
now a contiguous read of the block the producer just wrote.

**The gain grows with the row count** (1.076x at 1,024, 1.058x at 3,584,
1.162x at 10,752 on the four kernels) because at small row counts the
grid does not fill 36 SMs and the kernels are launch-latency bound, so
removing traffic buys less. The 8B shape is the large end, which is the
right end.

### 2026-09-19 — stage 4: the host tail of `columns_chunked`

Lane AO's item 2 has three parts. What this lane did with each:

1. **The serial loop copying 2.75 M `Fp` into 256 `Vec<Fp>`** — DONE.
   The `q` destinations are disjoint and each is a straight copy of a
   contiguous run, so the split is now a `rayon` `par_iter_mut` over the
   columns, each an `extend_from_slice` of the downloaded block
   reinterpreted as `&[Fp]` (`Fp` is `#[repr(transparent)]` over `u64`,
   asserted in the SAFETY comment). Duplicated indices still take their
   slot from `out_slot`, so the returned columns are identical.
2. **The unpooled 22 MB `cuMemAlloc` for the output block** — **NOT
   DONE, AND THE FILE THAT BLOCKS IT IS NOT THIS LANE'S.** Pooling it
   (`Pooled::take`) would add a third pooled scratch take and remove
   `rows * cols_out * 8` from the raw-allocation total, and
   `hashline/tests/zk60_gpu_commit.rs` asserts both exactly:
   `expect_alloc(&p.alloc, 2, rc, rb, &tag)` in the positive-control
   block — "the non-hiding opening: two scratch takes (coef, enc)" — plus
   the raw byte figure from `planned_raw`. Pooling it turns that green
   gate red. The brief forbids adjusting a gate and `tests/` is not this
   lane's file, so the change is described and not made. It needs the
   test's owner to move the expectation to three takes in the same
   commit.
3. **The 22 MB pageable download** — NOT DONE. `dtoh_sync_copy`
   allocates a fresh `Vec` per call and copies through the driver's own
   staging buffer; measured in isolation at 0.0146 s for 22 MB = 1.5
   GB/s, against roughly 6 GB/s for a pinned copy. `PinBuf` already
   exists in this file but there is no d2h pin cache, and a fresh
   `cuMemHostAlloc` of 22 MB per call would eat the win. It needs a
   small pinned-download pool, which is a clean follow-up but not a
   one-liner.

**The host tail could not be MEASURED in this session, and the reason is
worth recording.** In the six-process A/B run, `columns_chunked`
end-to-end at 10,752 rows came out 0.100 / 0.147 s in the two identical
arm-A processes — a **47% within-arm spread** — while the per-kernel
timings in the very same processes held to 3%. The bench allocates a
1.41 GB host vector per process at that shape on a 15 GB box, six times
in a row; the host side of the call (a 22 MB pageable download, a 22 MB
split, 256 vector allocations) is what that pressure hits. So the
end-to-end arm of this A/B carries no signal and this lane does not
quote one. The kernel A/B, taken back to back inside one process, does.
The parallel split is byte-identical and strictly less host work, and is
kept on that basis with **no measured gain** [NOT MEASURED].

### 2026-09-19 — stage 5: the gates after the change, and what it is worth

**Every gate green on the changed tree** (defaults: swizzles OFF, compact
pair ON, parallel split in):

* `gpu-probe` oracles, twice (`results/fsp2_oracles_s3.log`,
  `results/fsp2_oracles_s3b.log`): field probe 0 mismatches, **blake3
  checks GREEN**, **ntt checks GREEN**, **chunked-commit checks GREEN**
  at all fifteen shapes — including the six with `log_nn > NTT_LOG_BLK`
  that actually exercise the new pair, at inverse rates 2, 4 and 8
  (rb = 1, 2, 3). That oracle compares the RE-ENCODED OPENING COLUMNS
  against the CPU encoding element for element, which is the direct
  check on both new kernels.
* **The twelve byte gates GREEN** (`results/fsp2_floors_s3.log`,
  exit 0): the same four digests at the same four byte counts on the CPU
  binary, the GPU binary, and the GPU binary with the chunked path
  forced.
* `cargo test --release --features gpu-cuda --test zk60_gpu_commit`:
  **34 passed, 0 failed** — this is the file that asserts the opening's
  ALLOCATION ACCOUNTING (`expect_alloc(&p.alloc, 2, rc, rb, ...)`), so it
  also confirms the compact pair moves no allocation.
* `cargo test --release` (CPU, baseline run): 202/202.

A process note: the first attempt at the device tests exported `HL_GPU=1`
over the WHOLE suite, and `zk60_attention_schedule` is a CPU gate that
asserts `HL_GPU` is unset — `cargo test` then stopped at that target and
never reached the device tests. `results/fsp2_oracles.sh` now names the
device test targets instead. The failure was the script's, not the
tree's; the CPU suite run (`HL_GPU` unset) has that test passing.

**What it is worth on the 8B pass** [COUNTED — this lane does not run
the 8B pass and makes no measured claim about it].

The 58.40 s public-IO 8B feed-forward prove spends **13.826 s** in the
opening's re-encode (`results/hashline_convert_gpu.md` §7). On a quiet
box the four re-encode kernels are 92% of `columns_chunked`
(0.0906 of 0.0979 at the W shape). The four kernels improve **1.162x**
at the 8B W row count and **1.06-1.08x** at the smaller row counts the A
and H openings use. So:

* upper end (all three openings behave like W): 13.826 x 0.92 x
  (1 - 1/1.162) = **1.77 s**;
* lower end (the small-shape ratio throughout): 13.826 x 0.92 x
  (1 - 1/1.07) = **0.83 s**.

**About 0.8-1.8 s off the 58.40 s, i.e. 1.014x-1.031x** [COUNTED]. The
commit's 13.877 s encode is **not** helped: the commit needs every
column, so the compact store does not apply to it.

**Two honesty qualifications on that arithmetic.** First, the 13.826 s
itself was measured on 2026-09-04 under the same loaded-box conditions
that made lane AO's kernel table 1.8-2.3x pessimistic, so the true
absolute saving on a quiet box is probably smaller in seconds even
though the ratio holds. Second, `ZK60_FIVE_SECOND_PLAN.md` §5 step 3
counts **-7 s** for this lane's three items. The measured answer is
**-0.8 to -1.8 s from a mechanism the plan did not name**, and **zero
from the two the plan did name** (the bank conflicts are a regression;
`k_dif_pb` is already at 66-77% of the roof). Step 3 of that ladder
should be re-priced.

**What is left here, in order of what the counters now say:**

1. **The same compact pair for the HIDING opening.**
   `encode_rows_view_zk_gather` has the identical producer/consumer
   shape and CL7 already gave it the pruned kernel; it would take the
   same `k_dit_p1_pad_c` treatment, byte-gated by the two ZK digests.
   This is the tier the product needs and it is the cheapest remaining
   item in this file.
2. **The pinned download + the pooled output buffer** in
   `columns_chunked`'s tail (the latter blocked on a test file this lane
   does not own — see stage 4).
3. **`k_dit_p1_pad_c` is still the largest kernel** (0.0441 of 0.0898 =
   49% of the four) at about 57 GB/s of real traffic now that its stores
   are gone. It is no longer a bandwidth story at all: at 1.76 GB in
   0.0441 s it is 16% of the memory roof and 80e9 butterfly/s. The next
   lever on it is the per-butterfly instruction count (the Goldilocks
   reduction's three branches, the twiddle load, the index arithmetic),
   or a radix-4 stage pairing that halves the shared traffic and the
   barriers. Neither is a small change.
4. **The COMMIT's encode** (13.877 s of the 8B pass) is untouched by any
   of this and is now the larger of the two transform phases.

**THE EXACT NEXT STEP.** Give `encode_rows_view_zk_gather` (the HIDING
chunked opening, `hashline/src/gpu/cuda.rs` around line 1613) the same
treatment: pass the padded residue length through its `sp` tuple, launch
`k_dit_p1_pad_c` in place of `kn_dit_p1_pad()` and
`k_ntt_p2_gather_spc` in place of `k_ntt_p2_gather_sp` under the same
`p1_compact()` switch, and gate it on the two zero-knowledge byte
digests (`021485e4f80ec695..` 87,228,528 B and `40eb54795e023c77..`
87,697,008 B, CPU / GPU / GPU-chunked) plus
`results/fsp2_oracles.sh`. Both kernels already exist and are gated;
the change is the plumbing in one function.

**Switches this lane leaves behind**

| switch | default | what it does |
|---|---|---|
| `HL_GPU_P1_COMPACT=0` | on | restores lane AO's `k_dit_p1_pad_s` + `k_ntt_p2_gather_sp` pair |
| `HL_GPU_SMEM_SWZ=1` | off | the swizzled `k_dit_p1_pad_sz` (a measured regression, kept for the record) |
| `HL_GPU_SMEM_SWZ_PB=1` | off | the swizzled `k_dif_pb_z` (likewise) |

Lane AO's `HL_GPU_PAD_SKIP`, `HL_GPU_NTT_FAST`, `HL_GPU_PRUNE_P2` and
`HL_GPU_BENCH_REENC` are unchanged and still restore the inherited
kernels exactly; `HL_GPU_PAD_SKIP=0` and `HL_GPU_PRUNE_P2=0` both
override this lane's compact pair, because the compact form is a
descendant of both.

**Scripts** (all this lane's own): `results/fsp2_build.sh`,
`results/fsp2_floors.sh` (the twelve gates, `FSP_CPU_BIN`/`FSP_GPU_BIN`
to point at a saved build), `results/fsp2_oracles.sh` (every
device-vs-CPU oracle plus the two device test binaries),
`results/fsp2_ab_reenc.sh` (the swizzle ABBA),
`results/fsp2_ab_compact.sh` (the compact A-B-C-C-B-A).
