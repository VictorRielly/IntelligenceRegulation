# FSP lane 3 — give the private prover lane AL's host fix

**Worktree** `/home/victor/wt-fsp-zkhost`, branch `fsp-zkhost`, from the
main-branch tip `ad0f50c`.
**Sole writer.** Files owned: `hashline/src/zk.rs`, `results/fsp3_*`, this
ledger. Everything else in this repository and every other worktree is
READ-ONLY for this lane. `hashline/src/gpu/*` and `hashline/src/ntt.rs`
belong to the second speed lane at `/home/victor/wt-fsp-l9`.

**What the lane is.** Lane AL (2026-09-04) took the PUBLIC 8B feed-forward
pass from 98.54 s to 58.40 s with two host-side changes in
`hashline/src/layer.rs` and no change to a single proof byte: a two-slot
host staging pool, and folding the matmul weight blocks straight off the
int8 planes instead of off a converted 64-bit copy. AL deliberately did not
touch `hashline/src/zk.rs`, which carries its own copy of the v3 prover
body with its own `w_data` / `a_data` allocations. This lane ports both,
behind environment switches in AL's style so the old arm stays in the
binary for the A/B and for rollback.

**The lane is strictly byte-preserving.** It changes HOW host buffers are
allocated, staged and folded — never WHAT is committed, in what order,
under what label, with what randomness. No transcript, mask-schedule,
endpoint or privacy-policy change is in scope. A change that moves any
frozen digest is a BUG: revert it, record it, move on. Never adjust a gate,
never re-freeze a digest.

**No privacy claim is made here.** The legacy `--zk` profile being sped up
is known to DISCLOSE private values (2026-09-08 finding, `START_HERE.md`
privacy correction). This lane neither repairs nor endorses it; it is the
machinery the repaired private feed-forward wraps, which is why its host
cost matters (see stage 1 below — the repaired path does run through the
body changed here).

Every number carries its shape, conditions and label: [MEASURED],
[COUNTED], [MODEL].

---

## Stages

| # | stage | status |
|---|---|---|
| 0 | Ledger, ownership, the two AL changes read in full | DONE |
| 1 | Does the repaired private FFN run through this body? | DONE |
| 2 | Baseline gates on the untouched tree | DONE — all green |
| 3 | Port the staging pool behind `HL_FSP_POOL` | DONE — gates green |
| 4 | Port the int8-plane fold behind `HL_FSP_I8FOLD` | DONE — byte gates green |
| 5 | A/B at 12 x 512 only, CPU and GPU binaries | CPU done (20 runs); GPU partial |

Owed to a quiet window (NOT run by this lane, by instruction): the
Mistral-width (4096 / 14336) tamper battery through the GPU zero-knowledge
prover, and any 8B A/B. This lane runs the 12 x 512 (125M-class) fixtures
and nothing wider, on either processor.

---

## Reference: what lane AL actually did

Commits on this branch's history:

* `a885695` — RUNG 1, the pooled host staging buffer. 4-layer prove
  10.94 -> 8.78 s (1.25x), proof byte-identical. [MEASURED, lane AL]
* `a0a342b` — RUNG 2, the matmul folds read the int8 planes and the two
  passes become one. matmul g/u 0.66 -> 0.39 s, matmul d 0.36 -> 0.24 s,
  4-layer prove 10.97 -> 8.40 s (1.31x), proof byte-identical.
  [MEASURED, lane AL]
* Write-up `results/hashline_convert_gpu.md` sections 1-7; the 8B row is
  section 7 and `results/hashline_convert_r3.log`.

AL's finding, in one line: `vec![Fp::ZERO; w_len]` does not specialise to
`alloc_zeroed` for a user type, so every layer wrote 1.4 GB of zeros over
~344k first-touch page faults — 0.60 s per layer against 0.05 s for the
`Fp::from_i64` fill that immediately overwrote them.

AL's switches: `HL_AL_POOL=0` and `HL_AL_I8FOLD=0` (default ON).

**AL's helpers are private to `layer.rs`** — `mod hostbuf` (layer.rs:337)
and `fn fold_block_i8` (layer.rs:405) are both module-private, not
`pub(crate)`. Per this lane's ownership rules a visibility change in a file
this lane does not own is NOT allowed, so both are re-implemented inside
`zk.rs` with the same semantics and separate statics. Consequence worth
recording: the two pools are independent, so a process that ran both the
public and the private v3 prover would retire one buffer in each. In
practice a run uses one path or the other. **Suggested follow-up for the
owner of `layer.rs`:** promote `hostbuf` and `fold_block_i8` to
`pub(crate)` and delete the copies in `zk.rs`.

---

## Log

### 2026-09-19 — stage 0, ledger opened

Read: `ZK60_FIVE_SECOND_PLAN.md` sections 1.2, 1.4, 3, 6/Lane 3;
`results/hashline_convert_gpu.md` sections 1-5; AL's two commits;
`hashline/src/layer.rs` 330-430 and 1289-1640; `hashline/src/zk.rs`
2279-2900; `results/cl1_floors.sh`; `scripts/hashline_cl_gpu_gates.py`
95-175.

### 2026-09-19 — stage 1, does the repaired private FFN run through this body?

**YES.** The chain, with file:line:

* `hashline/src/zk.rs:4183-4184` — `#[path = "zk_ffn_fresh_poc.rs"] pub mod
  fresh_poc;`
* `hashline/src/zk_ffn_fresh_poc.rs:14-15` — `#[path =
  "zk_ffn_fresh_io.rs"] pub mod io;`
* `hashline/src/zk_ffn_fresh_io.rs:165` — `prepare()` calls
  `prepare_layer_zk_v3_inner(w, 32, &parameters(), &NttTables::new(16),
  &cfg, &mut tr, true, true, rng)`.
* `hashline/src/zk_ffn_fresh_poc.rs:104` — `prove()` calls
  `prove_layer_zk_v3_inner(..)`, which at `zk.rs:2284` is exactly
  `prepare_layer_zk_v3_inner(..)?.finish(ntt, tr)`.
* `hashline/src/zk.rs:2337` — `fn prepare_layer_zk_v3_inner(..)` is the
  body that carries the allocations this lane changes:
  `w_data` at `zk.rs:2416`, `a_data` at `zk.rs:2476`.

So the repaired private feed-forward and the legacy `--zk --profile v3`
prover share ONE prover body, and a host fix landed in it serves both. (The
plan's "around zk.rs:925-966" is stale; the current sites are 2416 and
2476.)

### 2026-09-19 — stage 1b, what the port must do differently from AL's

Read before writing anything. Three differences between `layer.rs`'s v3
body and `zk.rs`'s, each of which would have been a byte bug if ported
blind:

1. **The zk buffers are NOT exactly tiled by the fills.** AL's safety
   argument is that `LayoutV3`'s blocks tile `w_len` / `a_len` exactly, so
   every element is written before any is read. In `zk.rs` the buffers are
   LONGER than `LayoutV3`'s: `ZkLayoutV3` (zk.rs:2001-2052) appends, after
   `lay.a_len / a_n` rows, the CFS mask rows, the table rows, the table
   mask rows, the predicate row and (fresh-IO) the endpoint mask rows; and
   under P3 it appends the W mask rows after `lay.w_len / w_n`. Inside that
   tail, two writes are PARTIAL and rely on the surrounding zeros:
   * the table multiplicity rows, written `j in 0..t.size` out of `n`
     columns (`zk.rs:2500`);
   * the predicate slack row, written `i in 0..PRED_BITS` (16) out of `n`
     (`zk.rs:2518`).
   Therefore the port takes a pooled buffer and zeroes exactly the tail
   `[lay.a_len, zl.a_len)` (and `[lay.w_len, w_len_p3)` under P3),
   leaving only the provably tiled prefix unzeroed. That prefix is where
   essentially all the bytes are, so essentially all of AL's win is kept.
2. **`a_data` is MOVED into the commitment** (`pcs::commit_zk_owned`,
   `zk.rs:2537`), and under P3 `w_data` is too (`std::mem::take`,
   `zk.rs:2461`). The public path in `layer.rs` only borrows, so AL could
   give the buffer back at the end of the layer. Here the buffer lives
   inside `pcs::CommittedZk::data` (`zkp-core/src/pcs.rs:555`, a public
   field) until the opening, which happens in `PendingV3::finish`
   (`zk.rs:2306`) — also in `zk.rs`, so the pool return goes there, after
   `pcs::open_zk` and before the commitment is dropped.
3. **`h_data` stays as it is.** `zk.rs:2608` allocates `vec![Fp::ZERO;
   zl.h_len]` and, on the device helper path, leaves most of it zero on
   purpose — `pcs::commit_zk_device` documents that `host_data` "holds the
   host-known rows at their offsets and zeros elsewhere"
   (`hashline/src/pcs.rs:70-73`). Its zeros are load-bearing; pooling it
   would be a byte bug. AL did not touch the corresponding buffer either.
   Recorded, not changed.

### 2026-09-19 — stage 2, the baseline on the untouched tree

**Builds.** The GPU build needs `CUDA_ROOT` — without it `cudarc v0.13.9`'s
build script exits 101 (`results/cl1_floors.sh:276` sets it; the plan's
lane brief does not). Recorded so the next lane does not lose the same
ten minutes. Both builds ran detached under `flock -w 3600
/tmp/zk-build.lock`, offline, `-j 2`:

* CPU: `cargo build --release -j 2 --offline --manifest-path
  hashline/Cargo.toml` — exit 0.
* GPU: the same with `CUDA_ROOT=/home/victor/cuda-root`,
  `LD_LIBRARY_PATH=<cuda-root>/lib64:...`,
  `CARGO_TARGET_DIR=hashline/target-gpu`, `--features gpu-cuda` — exit 0.

**Byte gates, untouched tree, `pass 12 512 --threads 2`** [MEASURED,
NOISY-SHARED]. Runner
`<scratch>/fsp3/gate.sh <label> <profile> <tag>`: one prover process per
invocation; for GPU labels the caller wraps it in `flock -w 1800
/tmp/zk-heavy.lock` and the script reads `nvidia-smi` WHILE HOLDING that
lock (so the reading cannot be the other speed lane's job) and refuses to
launch if any compute app is present or `memory.used > 1500 MiB`.

| gate | label | digest | bytes | verdict |
|---|---|---|---:|---|
| v2 | cpu | `50cf7bdf..` | 66,844,928 | GREEN ACCEPT |
| v3 | cpu | `5f368db6..` | 70,758,084 | GREEN ACCEPT |
| **zk** | cpu | `021485e4..` | 87,228,528 | GREEN ACCEPT |
| **zk-v3** | cpu | `40eb5479..` | 87,697,008 | GREEN ACCEPT |
| v2 | gpu | `50cf7bdf..` | 66,844,928 | GREEN ACCEPT |
| v3 | gpu | `5f368db6..` | 70,758,084 | GREEN ACCEPT |
| **zk** | gpu | `021485e4..` | 87,228,528 | GREEN ACCEPT |
| **zk-v3** | gpu | `40eb5479..` | 87,697,008 | GREEN ACCEPT |
| **zk** | gpu-zkchunk | `021485e4..` | 87,228,528 | GREEN ACCEPT |
| **zk-v3** | gpu-zkchunk | `40eb5479..` | 87,697,008 | GREEN ACCEPT |

The card read 0 MiB used and 0 compute apps before every GPU launch.
Prove clocks are NOT a baseline for anything — the CPU gates ran while the
GPU build held two rustc jobs. Timing belongs to stage 5.

**`cargo test --release -- --test-threads=2`: exit 0, 259 passed, 0 failed,
across 28 test binaries** (log `<scratch>/fsp3/test_base.log`).

**The floor is green. Work may proceed.**

### 2026-09-19 — stage 3, the staging pool (`HL_FSP_POOL`)

Four edits, all in `hashline/src/zk.rs`, all behind `HL_FSP_POOL`
(default ON; `HL_FSP_POOL=0` is the pre-lane arm, in the same binary):

1. **`mod zkhostbuf`** (before `prove_layer_zk_v3`) — AL's two-slot pool
   with one extra argument. `take(slot, len, tiled)` returns a buffer of
   `len` in which `[0, tiled)` is ARBITRARY and `[tiled, len)` is ZERO. The
   tail is zeroed with a rayon chunked `fill`, not a single-threaded
   `vec!` write. `give` drops a capacity-0 `Vec` rather than parking it, so
   a buffer emptied by `std::mem::take` cannot displace a real one.
2. **`w_data`** — `zkhostbuf::take(W, if is_p3 { zl.w_len_p3 } else {
   lay.w_len }, lay.w_len)`.
3. **`a_data`** — `zkhostbuf::take(A, zl.a_len, lay.a_len)`.
4. **The returns.** `drop(w_data)` after the d terminals became
   `give(W, w_data)` (P1: the real buffer; P3: an emptied `Vec`, dropped).
   In `PendingV3::finish`, after each hiding opening — its last reader —
   the buffer the commitment owns is retired:
   `give(W, std::mem::take(&mut cm.data))` in the private-W arm and
   `give(A, std::mem::take(&mut self.a.data))` before `drop(self.a)`.
   Without this step the pool would be empty on every layer, because
   `pcs::commit_zk_owned` takes the data BY VALUE — the difference from
   `layer.rs`, where the public commit only borrows.

`h_data` is untouched: its zeros are load-bearing on the device helper
path (`pcs::commit_zk_device`'s `host_data` contract).

**Gates after the port** [MEASURED, NOISY-SHARED]: every digest below is
the frozen one at the frozen length.

| profile | cpu | gpu | gpu-zkchunk | gpu, `HL_GPU_CHUNK_BYTES=100000000` |
|---|---|---|---|---|
| v2 `50cf7bdf..` | GREEN | — | — | — |
| v3 `5f368db6..` | GREEN | — | — | — |
| **zk `021485e4..`** | GREEN | GREEN | GREEN | GREEN |
| **zk-v3 `40eb5479..`** | GREEN | GREEN | GREEN | GREEN |

(The public v2/v3 gates on the GPU binary are re-run at the end of stage
4; this lane changes no source they reach.)

A note on the rung-1 commit message: a pair of backticks around the new
module's name was expanded by the shell before `git commit` saw it, so the
message reads "New : AL's two-slot pool". No amend (this lane may not
amend); the content is here. Commit messages after this one carry no
backticks.

### 2026-09-19 — stage 4, the int8-plane fold (`HL_FSP_I8FOLD`)

Four edits in `hashline/src/zk.rs`, all behind `HL_FSP_I8FOLD` (default
ON): `fn fsp_i8fold()`, a copy of `layer.rs`'s private `fold_block_i8`,
and the two fold sites of the v3 zero-knowledge body. Each site computes
the per-block folds FIRST, straight off the int8 plane, and then derives
the sumcheck's plane fold as their `lam` combination, instead of folding
the int8 plane once for the tables and the 8x-larger `w_data` copy again
for the terminals.

Byte-identical by construction: `Fp2` multiplication is bilinear over the
base field, so `(lam * eq) . v` and `lam * (eq . v)` are the same element;
summation order is irrelevant in an abelian group; skipping a zero adds
zero. Under P3 the terminals read the blocks out of the hiding
commitment's `data`, whose block region is the same conversion of the same
int8 planes (the P3 mask rows are appended after `lay.w_len`), so the
substitution holds in both modes.

**What this lane did NOT change, and why.** `zk.rs`'s OTHER prover body,
`prove_layer_zk` (the v2 zero-knowledge path, `zk.rs:1135`), still
allocates `vec![Fp::ZERO; ..]` at lines 1159 and 1175 and still folds
`w_data` at line 1408. That is deliberate and follows AL's own reasoning
for `layer.rs`: the v2 path runs only at the 125M shape (the driver at
`hashline.rs:367` sends every `--profile v3` pass — which is every 8B pass
— to `prove_layer_zk_v3`), where the same allocation is a few tens of MB.
It is not worth a byte-gate risk. Recorded, not changed.

**One thing found on the way, not acted on.** With `HL_FSP_I8FOLD` ON and
mode P1, `w_data` has NO reader at all after the commitment: the only two
sites that read `w_data_ref` under P1 were the two fold loops, and the
P3-only mask evaluations are behind `if is_p3`. So under P1 the
systematic 1.4-GB host W buffer is write-only from `commit W` to the end
of the layer, and could be retired to the pool there instead of after the
d terminals — which would also let W and A share one slot. Out of this
lane's two-port scope; recorded for whoever takes the next rung.

**Byte gates after the fold port** — every digest the frozen one at the
frozen length, no digest moved:

| profile | cpu | gpu | gpu + `HL_ZK_CHUNK=1` | gpu + `HL_GPU_CHUNK_BYTES=100000000` |
|---|---|---|---|---|
| v2 `50cf7bdf..` | GREEN | GREEN | — | — |
| v3 `5f368db6..` | GREEN | GREEN | — | — |
| zk `021485e4..` | GREEN | GREEN | GREEN | GREEN |
| **zk-v3 `40eb5479..`** | GREEN | GREEN | GREEN | GREEN |

plus the ROLLBACK arm: zk-v3 on the CPU binary with
`HL_FSP_POOL=0 HL_FSP_I8FOLD=0` — GREEN, so both arms of the A/B produce
the frozen proof from one binary.

**`cargo test --release` for this rung is QUEUED, not yet green.** At
11:47 another worktree (`/home/victor/wt-fsp-host`) took
`/tmp/zk-heavy.lock` for its `fsp4_oracles.sh` battery, which takes
`/tmp/zk-build.lock` internally for its cargo steps; this lane's suite is
blocked behind it, launched detached per the no-hangup protocol so it
completes whether or not this session survives:

    log    <scratch>/fsp3/test_fold.log
    marker <scratch>/fsp3/test_fold.done   (holds the exit code)

The rung is committed on its BYTE gates, which are the load-bearing gate
for a byte-preserving lane — 20 gate runs plus 20 A/B runs, every one the
frozen digest at the frozen length. **Whoever picks this lane up must read
that marker before the branch is merged.** The pool rung's suite, which
exercises the same new code paths, was 259 passed / 0 failed.

### 2026-09-19 — stage 5, the A/B at 12 x 512, CPU binary

`pass 12 512 --threads 2 --zk --seed 1 --profile v3`, one binary, arms
chosen by the switches, **20 runs**: 5 pairs run new-first (runs 1-5) and
5 pairs run old-first (runs 6-10). **Every one of the 20 produced
`40eb5479..` at 87,697,008 bytes.** Raw rows in
`results/fsp3_ab_cpu.log`. [MEASURED, NOISY-SHARED — another worktree
(`wt-fsp-host`) was building and then running its oracle battery
throughout.]

**The order confound is real and had to be removed.** `helpers + commit H`
and `zero-check F` contain NO code this lane touched, so their old/new
ratio must be 1.00. In the new-first pairs they read 1.039 and 1.024; in
the old-first pairs 0.949 and 0.942. Whichever arm runs SECOND is about
4-5% slower on this box. Averaged over both orders they return to 0.995
and 0.984 — which is the measurement's honest noise floor, about +/-2%.

**Both orders together, 10 pairs, mean seconds summed over 12 layers:**

| phase | new (mean, [min-max]) | old (mean, [min-max]) | old/new | verdict |
|---|---|---|---:|---|
| **matmul g/u (zk)** | **0.368** [0.306-0.457] | **0.425** [0.363-0.517] | **1.157** | the fold, real |
| **matmul d (zk)** | **0.130** [0.108-0.167] | **0.162** [0.131-0.196] | **1.248** | the fold, real |
| commit W | 5.446 [4.63-6.63] | 5.529 [4.63-6.43] | 1.015 | inside the noise |
| commit A (zk) | 10.692 [9.17-13.15] | 10.936 [9.08-13.11] | 1.023 | inside the noise |
| helpers + commit H | 12.315 | 12.251 | 0.995 | unchanged code |
| zero-check F | 8.229 | 8.098 | 0.984 | unchanged code |
| pcs openings | 2.157 | 2.199 | 1.019 | unchanged code |
| **PROVE** | **40.973** [35.28-49.89] | **41.210** [34.41-48.70] | **1.006** | inside the noise |

**Read this honestly: at 12 x 512 the FOLD is measurable and the POOL is
not.** That is what the buffer sizes predict and is not a defect. At this
shape `w_len` is 3 x 768 x 2048 = 4.72 Melem (37.7 MB) and the zero-
knowledge A buffer is 559 rows x 2^14 = 9.16 Melem (73.3 MB), so the
allocation AL charged at 0.60 s/layer at model width is a few
milliseconds here. At Mistral width `w_len` is 3 x 4096 x 14336 =
176.2 Melem (1.409 GB) — **37.3x larger** — which is exactly the regime
AL measured. The 12 x 512 A/B is therefore a BYTE gate for the pool and a
TIMING measurement for the fold; the pool's worth is counted below, never
measured here.

### 2026-09-19 — what this is worth at 8B [COUNTED, never measured here]

**This lane ran nothing at Mistral width, by instruction.** The figure
below is COUNTED from lane AL's MEASURED public 8B A/B, and is not a
measurement of the private pass. Do not quote it as one.

The two inputs, both [MEASURED] and both already in the repository:

* **The public 8B A/B**, 32 x 512, GPU, cold cache, both arms in one
  session on one binary (`PROGRESS_UPERF3.md` "AL rung 3" line 12958;
  log `results/hashline_convert_r3.log`): commit W 43.901 -> 19.823
  (**-24.078 s**), commit A 16.155 -> 4.838 (**-11.317 s**) — the POOL's
  two phases, **-35.395 s** together; matmul g/u 5.816 -> 3.441
  (**-2.375 s**), matmul d 3.070 -> 2.092 (**-0.978 s**) — the FOLD's two
  phases, **-3.353 s** together; openings -1.381 s as a side effect.
  Those sum to -40.13 s against the measured PROVE delta of 98.54 -
  58.40 = -40.14 s, so the phase attribution closes.
* **AL's own instrumentation of the allocation alone** (same write-up,
  section 1): W 0.573 / 0.611 / 0.631 s per layer, A 0.209 / 0.218 /
  0.260 — about 0.83 s per layer, **-26.6 s over 32 layers**. This is the
  conservative floor for the pool: it charges only the `vec!` zeroing,
  not the page-fault pressure the phase delta also removed.
* **The private 8B pass**, 32 x 512, GPU, cold cache (`lane AI`, log
  `results/hashline_zk_8b_pass_gpu.log`): **PROVE 265.34 s**, commit W
  54.176, commit A (hiding) 24.568, matmul sumchecks (g/u + d) 10.642.

**The arithmetic.** The host allocation and the host block folds are
absolute costs over the same buffers and the same int8 planes in both
modes — that is what AL's instrumentation measured them to be, and the
private pass's own commit W (54.176) and commit A (24.568) are LARGER
than the public arm's before-values (43.901 / 16.155), so the count is
not optimistic on that axis. Removing the same absolute costs:

    265.34 - 26.6 (pool, conservative floor) - 3.35 (fold) = 235.4 s   (1.13x)
    265.34 - 35.4 (pool, measured phase delta) - 3.35 (fold) = 226.6 s (1.17x)

**COUNTED: the 8B private pass should land between about 227 and 235 s
against the recorded 265.34 s — roughly 1.13x to 1.17x.**

**Why that band is soft, and it is the honest caveat.** The recorded
private 8B row peaked at **8,585 MB of video memory on an 8,188 MiB
card** and PAGED: layer 0 proved in 4.36 s and layers 1-31 averaged
8.42 s. A pass that is paging does not respond to a host-side saving the
way a resident one does — the saving could be partly hidden, or partly
amplified. Nothing settles it but running it, and this lane may not.

Note the contrast with the public arm: there the same two changes were
worth 1.687x, because 50.5% of that pass was host time. In the private
pass the dominant phase is **LogUp helpers + commit H at 146.259 s (55%
of the prove)**, which neither of these changes touches. That is where
the private pass's next lever is, not here.

### 2026-09-19 — stage 5, the A/B on the GPU binary (PARTIAL, 5 of 10 runs)

3 new / 2 old, order n,o,o,n,n, all byte-identical. Full table in
`results/fsp3_ab.md`. Old/new: **matmul g/u 1.500, matmul d 1.622,
commit W 1.235, commit A 1.194**, PROVE 1.097; controls (`helpers +
commit H`, `zero-check F`) 0.955 and 0.914, so the residual order effect
here favours the OLD arm and the four changed phases are if anything
understated.

**On the GPU binary the POOL is measurable even at 12 x 512**, unlike on
the CPU binary, and the reason is structural: the device does the commit
arithmetic, so the host allocation is a much larger share of the
`commit W` / `commit A` phases. That is a useful, independent
confirmation that the pool does what it is supposed to do, on the shape
this lane is allowed to run.

**This is 3 against 2, not the 5 against 5 the lane owes.** The sixth run
was launched and is still queued.

### 2026-09-19 — state at hand-off, and the exact next step

At 12:0x another worktree (`/home/victor/wt-fsp-host`) took
`/tmp/zk-heavy.lock` for `fsp4_oracles.sh`, which also takes
`/tmp/zk-build.lock` internally. Two of this lane's jobs are queued behind
it, both launched detached so they finish with or without a session:

1. `flock -w 1800 /tmp/zk-heavy.lock <scratch>/fsp3/ab.sh gpu old 3` — the
   sixth GPU A/B run.
2. `cargo test --release -- --test-threads=2` for the fold rung — log
   `<scratch>/fsp3/test_fold.log`, marker `<scratch>/fsp3/test_fold.done`.

**THE EXACT NEXT STEP, in order.**

1. Read `<scratch>/fsp3/test_fold.done`. Exit 0 with 259 passed / 0 failed
   closes the fold rung; anything else is a regression in `zk.rs` and the
   rung must be reverted, not adjusted. (`<scratch>` is
   `/tmp/claude-1000/-home-victor-IntelligenceRegulation/e277dbc7-36bc-4ae1-8184-db91a6d569e4/scratchpad`;
   if it is gone with the session, re-run the suite — the command is in
   the stage-4 entry above.)
2. Finish the GPU A/B to 5 runs per arm: two more NEW and two more OLD,
   `flock -w 1800 /tmp/zk-heavy.lock <scratch>/fsp3/ab.sh gpu <arm> <i>`,
   ONE run per invocation, never two chained, balancing the order. Then
   re-run the table in `results/fsp3_ab.md`.
3. Then, and only in a quiet window with the card verified idle and
   nothing else on `/tmp/zk-heavy.lock`: the eight v3 tamper legs at
   Mistral width through the GPU zero-knowledge prover (honest ACCEPT,
   then 8 of 8 REJECT), and the 8B A/B of these two switches, launched
   alone and detached. **Both are OWED and neither was run here** — this
   lane ran nothing wider than 12 x 512 on either processor, by
   instruction.

**Nothing in this lane moved a digest, at any stage, on any binary.**

**Follow-ups found but deliberately not taken** (each is a separate
rung, and each is recorded here so it is not re-derived):

* `layer.rs`'s `mod hostbuf` and `fn fold_block_i8` are module-private.
  Promoting them to `pub(crate)` and deleting the copies in `zk.rs` is
  the right end state, and belongs to that file's owner.
* With `HL_FSP_I8FOLD` ON and mode P1, `w_data` has no reader after the
  commitment, so the W buffer could be retired to the pool at `commit W`
  instead of after the d terminals — and W and A could then share one
  slot.
* `zk.rs`'s v2 zero-knowledge body (`prove_layer_zk`) still has both
  pre-lane forms; it runs only at the 125M shape, so it was left alone
  for the same reason lane AL left `layer.rs`'s v2 alone.
* `zk.rs:2608` allocates `vec![Fp::ZERO; zl.h_len]` even when the device
  helper path will fill it; the zeros are load-bearing there, so the
  allocation cannot be pooled, but it may be avoidable another way.
