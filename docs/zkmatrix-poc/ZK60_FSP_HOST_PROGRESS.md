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
