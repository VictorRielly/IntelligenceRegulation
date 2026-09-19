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
| 1 | floor on the untouched tree: both binaries build, `cargo test --release`, every `gpu-probe` oracle, the twelve byte gates | PENDING |
| 2 | host attribution: the recorded logs, the source, this lane's own 12×512 timers; the table, reconciled to 11.9 s; which of the plan's three items are real | PENDING |
| 3 | build, largest real item first, each behind a default-off switch, each followed by the full floor and an A/B | PENDING |
| 4 | A/B at 12×512, old arm vs new arm, alternating, ≥5 runs each, CPU and GPU binaries; counted worth at 8B | PENDING |

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
