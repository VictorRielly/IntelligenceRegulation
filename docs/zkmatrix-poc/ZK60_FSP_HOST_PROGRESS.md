# Lane FSP-HOST — step 4 of the five-second ladder: the host floor inside the prove

Worktree `/home/victor/wt-fsp-host`, branch `fsp-host`, from the
`fsp-l9` tip `f0d3481`. Sole writer. Box: WSL laptop, Core Ultra 9
185H, 15 GB RAM, RTX 4070 Laptop GPU (8,188 MiB, sm_89), shared with a
second speed lane (`/home/victor/wt-fsp-zkhost`, sole writer of
`hashline/src/zk.rs`).

**What this lane is.** `ZK60_FIVE_SECOND_PLAN.md` §5 step 4: about
**11.9 s of the 58.40 s** 8B public-IO feed-forward prove is HOST work
inside the prove that no graphics card divides
(`results/hashline_convert_gpu.md` §7: device 46.47 s of 58.40 s). The
plan names three changes and counts them at about **−7 s**:

(a) hand `pcs::commit` the int8 planes directly instead of a converted
64-bit vector (the device half, `k_widen`, is already built and on the
live path);
(b) give the remaining host folds a device form;
(c) pool the opening's 22 MB allocation.

**Why the first job is attribution, not code.** The lane before this one
(`fsp-l9`) found that the table step 3 was counted from had been measured
while another lane loaded the CPU: `columns_chunked` at the 8B weight
shape is **0.095–0.098 s on a quiet box** against the 0.178 s the plan
counted from, so step 3 is worth 0.8–1.8 s and not 7 s. Step 4's −7 s
comes from the same era's numbers. So: establish where the host time
really goes, from the recorded logs, the source, and this lane's own
12×512 measurement, reconcile it against the recorded 11.9 s, and only
then build.

**Files this lane owns.** `hashline/src/layer.rs`,
`hashline/src/pcs.rs` (or wherever the host side of the commitment
lives, if inside this repository and not under `zkmatrix-rs/` or
`src/manifest.rs`), `hashline/src/wcache.rs`, `hashline/src/gpu/mod.rs`,
`hashline/src/gpu/cuda.rs`, `hashline/src/gpu/kernels.cu`,
`hashline/src/ntt.rs`, `results/fsp4_*`, this ledger.
**Read-only:** `hashline/src/zk.rs` (the other live lane's),
`zk_ffn_fresh_*.rs`, `private_*.rs`, `lib.rs`, `main.rs`, `Cargo.toml`,
everything under `scripts/`, `tests/`, `hashline/tests/`,
`src/manifest.rs`, `codex-audit-*`, every design document but this one.

**Honesty labels.** [MEASURED] a run happened, with its shape and box
conditions. [COUNTED] arithmetic on measured pieces. [MODEL] an
estimate. This lane runs only the 12×512 fixtures and the `gpu-probe`
benchmarks; **nothing at Mistral width**. Every worth at 8B is
[COUNTED], never measured here.

## Stages

| # | stage | status |
|---|---|---|
| 0 | ledger created and committed | DONE |
| 1 | floor on the untouched tree: both binaries build, `cargo test --release`, every `gpu-probe` oracle, the twelve byte gates | DONE — every gate green |
| 2 | host attribution: the recorded logs, the source, this lane's own 12×512 timers; the table, reconciled to 11.9 s; which of the plan's three items are real | PENDING |
| 3 | build: the matmul fold with the reduction deferred (`fold_block_i8`), plus the upload split timer | DONE — 1.21× (GPU binary) / 1.26× (CPU binary) on the item, digest unmoved in 20 runs |
| 4 | A/B at 12×512, old arm vs new arm, alternating, ≥5 runs each, CPU and GPU binaries; counted worth at 8B | DONE — **1.0–1.25 s counted** off the 58.40 s |
| 5 | the floor again on the changed tree | DONE — every oracle and all twelve byte gates green |

## Log

### 2026-09-19 — stage 0, ledger

Created this file. Read before touching anything:
`docs/zkmatrix-poc/ZK60_FIVE_SECOND_PLAN.md` §§1.2, 3, 4.2, the
CORRECTION block at the top of §5 (which lives in the main tree's copy,
commit `36b0017`; this worktree's copy predates it) and the ladder's
step 4; `docs/zkmatrix-poc/ZK60_FSP_L9_PROGRESS.md` in full;
`results/fsp2_build.sh`, `results/fsp2_floors.sh`,
`results/fsp2_oracles.sh`.

Box at the start: `uptime` load average 2.11 / 2.74 / 2.78 (the sibling
lane is working), `nvidia-smi` 0 MiB used.

Next step: stage 1, the floor — write `results/fsp4_build.sh`,
`fsp4_floors.sh`, `fsp4_oracles.sh` (the fsp2 scripts re-pointed at this
worktree), build both binaries, run the CPU suite, the oracles and the
twelve byte gates on the untouched tree.

### 2026-09-19 — stage 2 part A: THE 8B HOST ATTRIBUTION, RE-DERIVED FROM THE RECORDED LOG

Before any measurement of my own: `results/hashline_convert_r3.log` was
run with `HL_CONV_VERBOSE=1`, so it carries lane AL's per-layer host
lines for **both** arms of its A/B (64 `conv W` lines = 32 before + 32
after). Summing the AFTER arm — the arm that is the 58.40 s pass —
layer by layer (script
`/tmp/.../scratchpad/sum_al2.py`, a pure re-read of the log):

| printed item (32 layers, AFTER arm) | seconds |
|---|---:|
| `conv W` alloc | 0.580 |
| `conv W` fill (int8 planes -> `Vec<Fp>`) | 1.652 |
| `conv W` commit host residual (commit call − h2d − ntt − hash) | 0.876 |
| `conv A` alloc | 0.183 |
| `conv A` fill | 1.091 |
| `conv A` commit host residual | 0.254 |
| `fold gu` pre (eq tables + the int8 row/col folds) | 3.026 |
| `fold gu` 14 `w_data` block MLE evaluations | 0.309 |
| `fold d` pre (eq + i32 row fold + i8 col folds) | 1.790 |
| `fold d` 7 block MLE evaluations | 0.157 |
| **printed `layer.rs` host total** | **9.916** |

(The same sum over the BEFORE arm is 46.541 s, of which 33.864 s is the
`vec![Fp::ZERO]` allocation lane AL removed — the log reproduces AL's
1.687× from its own per-layer lines, which is the check that this
parse is reading the right thing.)

**Reconciliation against the recorded 11.93 s.** Phase by phase, host =
phase − the device counters charged inside it:

| phase | phase s | device charged inside | host s |
|---|---:|---|---:|
| commit W | 19.823 | h2d 6.558 + ntt 10.156 | **3.109** |
| commit A | 4.838 | h2d 2.039 + ntt 1.271 | **1.528** |
| helpers + commit H | 5.555 | helpers 1.378 + ntt 2.450 + hash 0.481 | **1.246** |
| matmul g/u | 3.441 | ~0 (its sumcheck tables are 2·4096 wide) | **3.441** |
| matmul d | 2.092 | ~0 | **2.092** |
| zero-check F + D | 5.468 | sumcheck 5.465 | **0.003** |
| pcs openings | 17.176 | re-encode 13.826 + fold 2.850 | **0.500** |
| **total** | **58.39** | **46.47** | **11.92** |

That is the recorded 11.9 s, item by item, and it agrees with the
`HL_CONV_VERBOSE` sum above (9.916 of the 11.92 is `layer.rs`'s printed
conv/fold work; the rest is the H phase's host work — the
multiplicities pass and the Merkle build — and the openings' host tail).
**Lane AL's write-up said "~7.5 s is `layer.rs` residue"; the log's own
lines say 9.92 s.**

**The largest host item is NOT one of the three the plan names.** It is
the two matmul folds: 3.441 + 2.092 = **5.53 s, 46% of the host time**,
of which `fold_block_i8` (the per-block column folds over the raw int8
weight planes, `layer.rs:405`) is ~95% of the element count at the 8B
shape (2·d·f + d·f = 176 M int8 MACs per layer against 9.4 M for the
`fold_rows_i8`/`fold_rows_i32` calls in `zkp-core/src/mle.rs`).

**And there is a host item hidden INSIDE the device column.** The
`secs_h2d` counter (8.597 s, 20% of the "device" 46.47 s) is not bus
time: `commit_chunked_upload` charges it `up.secs`, which is the time
inside `send_packed`, and `send_packed`'s body is `pack_narrow` — a host
pass that reads the 64-bit staging vector and writes one byte per
element (`gpu/cuda.rs:906`). At the 8B shape that is 9.33e9 elements =
**74.6 GB read + 9.3 GB written** per pass; 8.597 s over 84 GB is
~9.8 GB/s, which is the box's aggregate memory rate. So the counter is
plausibly almost all HOST work [MODEL until measured], and the true host
share of the 58.40 s is nearer **20 s (35%)** than 11.9 s (20%). This is
the first thing stage 2 part B measures.

Next step: stage 2 part B — the 12×512 measurement (`results/fsp4_attrib.sh`,
already queued on the heavy lock behind the floor) and the finer upload
timer behind `HL_FSP4_TIMING=1`.

### 2026-09-19 — stage 1, the floor on the UNTOUCHED tree: GREEN

Scripts (this lane's own, the previous lane's re-pointed here):
`results/fsp4_build.sh`, `fsp4_floors.sh`, `fsp4_oracles.sh`,
`fsp4_attrib.sh`, `fsp4_ab_fold.sh`. Every heavy job was launched
detached (`setsid nohup` + `flock /tmp/zk-heavy.lock` + a `.done`
marker), cargo under `/tmp/zk-build.lock`, offline, `-j 2`.

* **Builds** [MEASURED] `results/fsp4_build.log`, exit 0 — CPU binary
  (`hashline/target/release`) and GPU binary
  (`--features gpu-cuda`, `hashline/target-gpu/release`).
* **`cargo test --release`** [MEASURED] `results/fsp4_cputest.log`,
  exit 0 — **202 passed, 0 failed** over 26 test binaries.
* **`gpu-probe` oracles** [MEASURED] `results/fsp4_oracles_base.log`,
  exit 0 — field probe 1,048,576 pairs, **0 mismatches**; **blake3
  checks GREEN** (322 row counts × 64 columns); **ntt checks GREEN**
  (7 shapes, inv_rate 2/4/8); **chunked-commit checks GREEN**
  (15 shapes, including the re-encoded opening columns against the CPU
  encoder at rb = 1, 2, 3). Device test binaries:
  `zk60_gpu_commit` **34 passed**, `zk60_gpu_cache` **12 passed**.
* **The twelve byte gates** [MEASURED] `results/fsp4_floors_base.log`,
  exit 0 — **ALL TWELVE GREEN**: `50cf7bdfd6b5b182..` 66,844,928 B,
  `5f368db6240e0614..` 70,758,084 B, `021485e4f80ec695..` 87,228,528 B,
  `40eb54795e023c77..` 87,697,008 B, each on the CPU binary, the GPU
  binary, and the GPU binary with `HL_GPU_CHUNK_BYTES=100000000
  HL_GPU_CHUNK_ROWS=128`.

**The floor is GREEN; the lane may build on it.**

### 2026-09-19 — stage 2 part B: THE 12×512 MEASUREMENT, AND WHAT THE h2d COUNTER IS

`results/fsp4_attrib.sh` proves the frozen v3 fixture (12 layers × 512
tokens, d 768, f 2048) once on each binary with `HL_CONV_VERBOSE=1` and
`HL_TIMING=1`; `results/fsp4_attrib_base.log` is the untouched tree,
`fsp4_attrib_s2.log` the same with this lane's `HL_FSP4_TIMING=1` upload
split. Both runs reproduce `5f368db6240e0614..` at 70,758,084 B.

**The baseline run** [MEASURED, 12×512, GPU binary, load average 2.3,
`nvidia-smi` 0 MiB before]: PROVE **1.82 s**; device counters h2d 0.189
+ ntt 0.307 + hash 0.094 + sumcheck 0.348 + fold 0.154 + helpers 0.083 =
**1.175 s**, so host = **0.645 s = 35% of the prove** — the same host
share as the 8B pass has once the h2d counter is read correctly (below),
at a shape 37× smaller per layer.

| host item at 12×512 | s | how it scales | the same item at 8B |
|---|---:|---|---:|
| `conv W` alloc + fill + commit residual | 0.105 | fill ∝ layers × 3·d·f; residual ∝ Merkle leaves | 3.109 |
| `conv A` alloc + fill + commit residual | 0.156 | fill ∝ layers × (7f + 3d)·T | 1.528 |
| `fold gu` pre + blocks | 0.089 | pre ∝ layers × 2·d·f (+ T·d) | 3.441 |
| `fold d` pre + blocks | 0.053 | pre ∝ layers × d·f (+ T·f) | 2.092 |
| openings host (group_claims, rhos, absorb, column tail) | 0.110 | ∝ claims × rows | 0.500 |
| helpers + H host (multiplicities, Merkle) | ~0.13 | ∝ layers × T·(f + d) | 1.246 |
| **host total** | **0.645** | | **11.92** |

**The `secs_h2d` counter is 72% HOST WORK** [MEASURED, 12×512,
`results/fsp4_attrib_s2.log`, this lane's `HL_FSP4_TIMING=1`]: over the
24 narrow uploads of one run, `h2d counter 0.1675 s = host pack
0.1208 s + 0.0467 s rest`. Per upload the W plane (4,718,592 elements,
1 B/elem) is `0.0057 = 0.0045 pack + 0.0011 bus` and the A plane
(8,519,680 elements, 2 B/elem) `0.0101 = 0.0072 + 0.0029`. `pack_narrow`
reads the 64-bit staging vector and writes w bytes per element; the bus
part is the only real device time in that counter.

**What that does to the 8B split** [COUNTED]: the pack rate here is
1.05e9 elem/s, so the 8B weight plane (176.2 M elements) packs in
~0.168 s per layer against a measured h2d of 0.2009 s — i.e. **~84% of
the 8B h2d counter is host packing too**. Of the recorded 8.597 s h2d,
**6.2–7.2 s is host**, and the honest host share of the 58.40 s pass is
**≈ 18–19 s (31–33%)**, not 11.9 s (20%). No card divides any of it.

**The corrected host attribution of the 58.40 s pass** [8B seconds
MEASURED in `results/hashline_convert_r3.log`, the h2d split COUNTED
from the 12×512 ratio]:

| host item | 8B s | share of host | the plan's item |
|---|---:|---:|---|
| `pack_narrow` inside the "device" h2d counter | 6.2–7.2 | 36% | (a), and the plan did not know it was there |
| the two matmul folds (`fold_block_i8` + eq tables + block MLEs) | 5.53 | 29% | (b) |
| `conv` fill, the int8 → `Vec<Fp>` conversion | 2.74 | 14% | (a) |
| commit host residual (Merkle build, wcache key) | 1.13 | 6% | — |
| helpers + H host (multiplicities, Merkle) | 1.25 | 7% | — |
| `conv` alloc (the pooled buffers' first touch/resize) | 0.76 | 4% | — |
| openings host (groups, rhos, absorb, the column tail) | 0.50 | 3% | (c) |
| **total** | **18.1–19.1** | | |

**Verdict on the plan's three items.**

* **(a) hand `pcs::commit` the int8 planes directly — REAL, and the
  largest item on the page: ~9 s, not the ~3 s the plan's fill-only
  reading implies** [COUNTED]. It removes the fill (2.74 s), most of the
  alloc (0.66 s), and turns `pack_narrow` from a 74.6 GB read + 9.3 GB
  write into a 9.3 GB read + 9.3 GB write — about 4.5× less traffic on a
  memory-bound pass, so ~7 s → ~1.5 s. **It is also the one item that
  needs a design decision** (an entry point that takes the planes plus
  the block-tiling map, with the `Vec<Fp>` build kept as the CPU
  fallback), which is why this lane did not take it first.
* **(b) give the remaining host folds a device form — REAL, 5.53 s**
  [MEASURED at 8B]. But a device kernel is not the only way to collect
  it: 95% of the element count is `fold_block_i8`, whose inner loop is
  a field multiply per int8 value. This lane takes it **on the host**
  first (stage 3), which is byte-preserving by an exactness argument
  and needs no kernel, no upload and no oracle.
* **(c) pool the opening's 22 MB allocation — REAL but SMALL**: the
  whole openings host tail is **0.50 s of the 58.40 s** (3% of the host
  time), and the pooling is one part of it. It also remains **blocked on
  `hashline/tests/zk60_gpu_commit.rs`**, which asserts two scratch takes;
  that is owed to the integrator, exactly as lane fsp-l9 recorded.
* **Items the plan missed**: the packing pass (above), the commit host
  residual (1.13 s) and the H phase's host work (1.25 s).

Next step: stage 3, build item (b) on the host — the deferred-reduction
`fold_block_i8` behind `HL_FSP4_I128FOLD` — then the full floor and the
A/B.

### 2026-09-19 — stage 3: THE MATMUL FOLD WITH THE REDUCTION DEFERRED

**What was built** (`hashline/src/layer.rs`, `fold_block_i8`, one
function, plus the switch `i128fold()`). The inherited inner loop pays,
per int8 value, a `Fp::from_i64` (a branch and, for the negative half of
a plane, a 128-bit negate and a reduction) and an `Fp2::mul_base` (two
64×64 Goldilocks multiplies, each with a three-branch reduction) and an
`Fp2::add`. The new arm shifts the value to `u = v + 128 ∈ [0, 255]`,
accumulates `Σ_j c_j·u_j` per row as an exact **128-bit integer** — one
unsigned 64×8 multiply and one 128-bit add per component per element,
no branch, no reduction — and closes each row with

```
Σ_j c_j·v_j  =  red(Σ_j c_j·u_j)  −  128·Σ_j c_j
```

where `Σ_j c_j` is one `Fp2` sum computed once per call.

**Why it is byte-identical, not approximately**: every `c_j` is a
canonical representative in `[0, p)` and `Fp::from_i64(v) ≡ v (mod p)`,
so the integer sum reduced mod p IS the field sum; the regrouping is an
identity over the integers; `Z_p` arithmetic is exact, so no ordering or
association question arises. The overflow bound is written at the
accumulator: `|Σ| ≤ cols · 255 · (p−1) < 2^48 · 2^8 · 2^64 = 2^120`, and
a block wider than `2^48` falls back to the inherited arm.

**Also built**: the upload split timer (`gpu/cuda.rs`,
`HL_FSP4_TIMING=1`, default off, prints only) that produced the h2d
finding in stage 2.

**The A/B, ONE binary, alternating A-B-B-A-A-B-B-A-A-B, 5 runs per arm**
(`results/fsp4_ab_fold.sh`; A = `HL_FSP4_I128FOLD=0`, the inherited
fold; B = default). Every one of the 20 runs wrote the frozen v3 proof
and printed its digest: **`5f368db6240e0614` at 70,758,084 B in all
20** — the digest never moved.

*GPU binary, 12×512, `results/fsp4_ab_fold_gpu.log`* [MEASURED; box:
`nvidia-smi` 0 MiB before, load average 2.5–5.3, the sibling lane
`wt-fsp-zkhost` running CPU work in parallel]:

| quantity (sum over 12 layers) | A (inherited) | B (deferred) | ratio |
|---|---:|---:|---:|
| the fold item: `fold gu` + `fold d` **pre** | median **0.1556 s** (0.1530–0.1664, spread 8.6%) | median **0.1288 s** (0.1255–0.1326, spread 5.5%) | **1.208×** median, 1.219× best-of |
| the block MLE evaluations (untouched control) | 0.1164 | 0.1189 | 0.98 — noise, as it must be |
| PROVE | 2.450 s (2.38–2.52) | 2.450 s (2.42–2.53) | 1.00 |

**Every one of the five B runs is below every one of the five A runs on
the item.** The prove total does not move at this shape and this lane
does not claim it does: the item is 0.027 s of a 2.45 s prove (1.1%),
well inside the 5% run-to-run spread.

*CPU binary, 12×512, `results/fsp4_ab_fold_cpu.log`* [MEASURED; box
**heavily loaded** — the sibling lane `wt-fsp-zkhost` was running its
own CPU A/B and Codex was compiling in the main tree; load average rose
2.5 → 13.5 across the ten runs, so the absolute seconds here are worth
nothing and only the alternating comparison is]:

| quantity | A (inherited) | B (deferred) | ratio |
|---|---:|---:|---:|
| the fold item (pre) | median **0.1500 s** (spread 9.3%) | median **0.1187 s** (spread 21.1%) | **1.264×** median, 1.291× best-of |
| block MLE evaluations (control) | 0.1208 | 0.1149 | 1.05 — noise |
| PROVE | 18.74 s | 18.56 s | 1.01 — noise |

**What it is worth on the 8B pass** [COUNTED — this lane never runs the
8B pass]. The measured ratio is on the WHOLE "pre" item, which is the
eq tables, the row folds (`fold_rows_i8` over x, `fold_rows_i32` over
h16 — both in `zkp-core/src/mle.rs`, **not this lane's files and
untouched**) and the block folds. Separating by element count:

* at 12×512 the block folds are `3·d·f = 4.719 M` of the
  `3·d·f + T·(d+f) = 6.161 M` elements = **76.6%**;
* solving `0.766/x + 0.234 = 1/ratio` gives the block fold's own factor
  **x = 1.29** (GPU arm) to **1.38** (CPU arm);
* at 8B the block folds are `176.16 M` of `185.60 M` = **94.9%**, so the
  pre item improves by `1/(0.949/x + 0.051)` = **1.27–1.35×**;
* the 8B pre item is 4.816 s (3.026 gu + 1.790 d), so the saving is
  **1.0–1.25 s of the 58.40 s = 1.018–1.022×** [COUNTED].

Two honesty qualifications. First, the 4.816 s was measured on
2026-09-04 on a loaded box, so the true absolute saving on a quiet box
is probably smaller in seconds even though the ratio holds. Second, the
8B blocks are wider than the fixture's (2,048 and 4,096 columns against
2,048 and 256), and the new arm's per-row cost (two 128-bit modulo
reductions and one `Σ c_j`) amortises better over a wider block, so
1.27–1.35× is if anything a floor.

### 2026-09-19 — stage 5: the floor again, on the CHANGED tree

Defaults after this lane: the deferred fold ON, the upload timer OFF.

* **`gpu-probe` oracles** [MEASURED] `results/fsp4_oracles_s2.log`,
  exit 0 — field probe **0 mismatches**, **blake3 GREEN**, **ntt
  GREEN**, **chunked-commit GREEN** at all fifteen shapes (the oracle
  that compares the device's re-encoded opening columns against the CPU
  encoder element for element). Device test binaries:
  `zk60_gpu_commit` **34 passed, 0 failed** — the file that asserts the
  opening's ALLOCATION ACCOUNTING, so nothing moved there either —
  and `zk60_gpu_cache` **12 passed, 0 failed**.
* **The twelve byte gates** [MEASURED] `results/fsp4_floors_s2.log`,
  exit 0 — **ALL TWELVE GREEN**, the same four digests at the same four
  byte counts on the CPU binary, the GPU binary, and the GPU binary with
  the chunked path forced.
* The A/B itself is 20 more byte checks of the changed arm: every run
  wrote `5f368db6240e0614..` at 70,758,084 B.

**Switches this lane leaves behind**

| switch | default | what it does |
|---|---|---|
| `HL_FSP4_I128FOLD=0` | on | restores the inherited per-element field multiply in `fold_block_i8` (`layer.rs`) |
| `HL_FSP4_TIMING=1` | off | prints the upload's host-pack / bus split (`gpu/cuda.rs`); printing only |

Lane fsp-l9's `HL_GPU_P1_COMPACT`, `HL_GPU_SMEM_SWZ(_PB)` and lane AO's
and AJ's switches are untouched.

**Owed to the integrator (not this lane's files).**

1. **Pooling the opening's 22 MB output allocation** turns
   `expect_alloc(&p.alloc, 2, rc, rb, &tag)` in
   `hashline/tests/zk60_gpu_commit.rs` red (three scratch takes instead
   of two). Inherited from lane fsp-l9 and still owed; the whole
   openings host tail is 0.50 s of the 58.40 s, so this is a small item.
2. **The row folds** `fold_rows_i8` / `fold_rows_i32` / `fold_cols_i8`
   in `zkp-core/src/mle.rs` take the identical deferred-reduction
   treatment and are ~5% of the fold element count at 8B (~0.25 s).
   That file is not this lane's.

**What the next lane should do, in the order the counters now say.**

1. **Item (a), the int8-plane commit entry point — ~9 s at 8B
   [COUNTED], the largest single host item in the prove.** The design,
   concretely: `prove_layer_v3` today fills `w_data: Vec<Fp>` (a block
   tiling of the int8 planes) and hands it to `pcs_compact::commit` →
   `wcache::commit_w` → `zkp_core::pcs::commit_with` → the hashline
   backend → `commit_chunked_upload`, which re-reads all 8 bytes per
   element to emit 1. Give hashline's own `pcs.rs` an entry that takes
   the planes plus the tiling map, fill the pinned staging buffer
   directly from the int8 source per chunk (the byte image is
   bit-for-bit what `pack_narrow` produces today, so `k_widen` and every
   kernel after it are untouched), and keep the `Vec<Fp>` build as the
   CPU/decline fallback. The byte gates plus the `gpu-probe`
   chunked-commit oracle are the whole check. The A commitment gets the
   same treatment at `w = 2`.
2. **The remaining fold item**: the block fold is now ~1.3× faster; a
   two-rows-at-a-time inner loop (one `c_j` load feeding two rows)
   should pay again on this memory-latency-bound loop, and that is a
   dozen lines in the same function.
3. Only then the device form of the folds, which needs a kernel, an
   upload and a new oracle for a 5.5 s item that the host is already
   collecting a quarter of.

**THE EXACT NEXT STEP.** Take item (a) as scoped above, starting with
the W commitment on the GPU path only: add to `hashline/src/pcs.rs` a
`commit_planes` that takes `(&PcsParams, &PlaneTiling, &NttTables)`
where `PlaneTiling` is `prove_layer_v3`'s existing block map (the three
`lay.wg/wu/wd` offset tables plus `db`, `fb`, `d`, `f` and the three
`&[i8]` sources), have `gpu/cuda.rs::commit_chunked_upload` fill the
pinned staging buffer from that map instead of calling `pack_narrow`
(the bytes are identical: `pack_narrow` at `w = 1` emits exactly the
two's-complement int8 byte), and keep today's `Vec<Fp>` fill as the
fallback whenever the device declines or `HL_GPU` is off. Gate it on
the twelve byte gates, `results/fsp4_oracles.sh`, and an A/B of the
`[FSP4]` pack line at 12×512. The weight cache key
(`wcache::WKey::new`) already hashes the int8 planes, not `w_data`, so
it needs no change.

**Lane state at hand-back: GREEN.** Working tree clean, three commits
on `fsp-host` (`a4364cb` ledger, `7a2543c` attribution, `ba6b4b8` the
fold + the upload timer, `e6d241a` the evidence logs), nothing pushed
(this lane never pushes), no test expectation touched, no gate
adjusted, no digest re-frozen.
