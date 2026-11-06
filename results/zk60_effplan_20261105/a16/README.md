# A16: the sealing pass's serial remainder (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A16. Byte-preserving. It follows A15
(`../a15/README.md` §7: "the builder's serial remainder, about 1.6 s of the 2.9 s pass").

Labels: [MEASURED] a number from a log in this directory (or A15's); [INFERRED] derived from measured numbers;
[ESTIMATE] a judgement; [CODE] read from the code.

All runs: W16R2 8B T128, 32 blocks, the D55 harness at N = 6 (A11's per-fork pools of 6), `HL_GPU=1 HL_PB_ORACLE=0
HL_METAL_TIMING=0`, on the shared M3 Ultra (32 logical CPUs), every stage one guarded job (class gpu, the shared heavy
lock), on perf `910c2ac4` (A15 merged) with A16. The fixture's public weights are A15's synthetic diagonal ones at the
8B geometry (see §6 on what that does and does not affect).

## Plain summary

- **The result** [MEASURED, §4, a quiet GPU, every pair in both orders, order bias removed]:
  - **one request from its input −22.1%**, 7.45 → 5.80 s (17.2 → 22.1 tok/s; best 22.5), 6 passes;
  - **the 4-request stream +7.0% steady** (29.1 → 31.1 tok/s) and **+12.8% amortized** (24.3 → 27.4 tok/s);
  - **the sealing pass −49.1%** (3.38 → 1.72 s; beside the forks in the stream 4.52 → 2.67 s);
  - proof only, the control without a sealing pass: +0.9%, noise;
  - **production's builder** (`build_for_block`, where its doubled checks are now run once), 4 passes: one request
    −23.9% (7.54 → 5.74 s, 17.0 → 22.3 tok/s), the stream +10.0% steady, +14.4% amortized.
- **What was slow** (§0). After A15, about 1.1 s of the sealing pass's 2.6 s main line per 32-block pass was the
  builder's own serial work: the supports and chunk plans rebuilt every block, `quantized`'s serial read-back,
  `normalized`'s i128 divisions on one thread, `build`'s per-position loops; and production checked each block's
  public data twice more inside the build.
- **The fix** (§1): seven byte-preserving forms in the witness builder (`witness.rs`, `witness_accuracy.rs`), `HL_A16`
  (default: every form; `HL_A16=0` restores the builder before A16): `cache` (supports and chunk plans kept per
  geometry), `quant` (chunked requantization), `norm` (rows in parallel, i64 where exact), `loops` (the per-position
  loops on the pool), `kernels` (the score and PV sums over contiguous int16 rows), `overlap` (Q/K/V and gate/up side
  by side), `once` (production's checks once). In the sealing pass alone every form pays on top of all the others
  (§2: 3.12 → 1.63 s, −47.7%). The serial part of the main line fell from 1.15 to 0.04 s per pass.
- **The acceptance** (§7) holds: the suite (933 / the known 3 / 108), the goldens, the six digests, every receipt at
  its size; its D55 default run: one request 5.54 s = 23.1 tok/s best, the stream 31.8 tok/s steady.
- **The pool rule stays** (§4.2): with less serial work, 12 threads won the sealing pass alone (−6.6%) but lost in the
  D55 process in every pair (one request +2.1%, the stream −1.2%); 16 lost more. `(cores / 4).clamp(1, 8)` is kept.
- **No byte moves** (§5): every plane of every witness of the 32-block 8B chain has A15's digest under all 18 arms;
  every plane or refusal equal under 16 form sets at the rungs, TinyLlama T128 and the 8B block (CPU and device
  products), with refusals reached at the norm, score, gate and residual sites.
- **Now** the stream is fork-bound (§4.1): its steady state is the fork run's own rate.
- **A caution on stage 2** (§3): it ran beside an outside GPU job; its clocks are discarded, stage 3 is the measurement.

## 0. Measure first: the ranking, written before any code change

Source: A15's raw `/usr/bin/sample` call graph of the sealing pass ALONE in the default sealing pool (`sp8`, 8
threads; two passes of the 32-block chain, 2 ms interval; A15 stage 1, the builder code identical to this tree's
before A16), re-split here by the builder's phase and by serial / inside a parallel region / waiting on the GPU
(`mainline_split.py`, `mainline_leaves.py`; output `s0_a15sp8_split.txt`). The main line is the thread holding
`witness::build_accuracy`. Per pass (the two passes halved) [MEASURED]:

| # | where the main line's time goes | kind | s per pass | % of main line |
|---|---|---|---:|---:|
| 1 | the seven weight products on the device (`matmul_in_out` 0.36, `matmul` 0.18) | GPU wait | 0.54 | 21% |
| 2 | `build`'s parallel regions (scores and softmax/PV heads, the -128 scan, the CS-1 scans) | parallel (8 threads) | 0.45 | 17% |
| 3 | `quantized`'s serial read-back of its parallel chunks (0.27) and the zeroing of its two output planes (`__bzero` of a reused allocation, 0.06) | **serial** | 0.33 | 13% |
| 4 | `assign`'s supports (`Geom::support`, 0.11) and chunk plans (the grouping loop and its `realloc`s, 0.19), rebuilt every block | **serial** | 0.33 | 13% |
| 5 | `assign`'s limb planes (`fill_planes`) | parallel | 0.30 | 12% |
| 6 | `normalized` (norm_a, norm_m): 2 x 524k i128 divisions (`__divti3`) on one thread | **serial** | 0.17 | 6% |
| 7 | `build`'s own per-position loops (the ungated exp lookup, `a_scaled`, the `hacc` collect, the `oacc` scatter, the `zsel` clones) | **serial** | 0.15 | 6% |
| 8 | `Geom::support` in `build` (5 domains) and in `residual` (2 x D) | **serial** | 0.12 | 5% |
| 9 | waiting on its own regions, `residual`'s loop, `rotate`, `check_for_registry` | serial / wait | 0.12 | 5% |
|   | **main line total** | | **2.57** | |

(The sealing pass alone took 2.94 s at `sp8` unsampled, 3.28 s under the sampler [MEASURED, A15].)

**What it said.**
- The **serial** items (3, 4, 6, 7, 8 and most of 9) were about **1.1 s of the 2.57 s main line** [INFERRED]. Each has
  a byte-identical form: 4 and 8 are pure functions of the public geometry; 3, 6, 7 are element-wise or per-row with
  fixed refusal strings.
- The GPU waits (1) are the device's own work; the builder can only overlap them (Q, K, V are independent, so are
  gate and up). `gpu/metal.rs` is another lane's.
- The parallel regions (2, 5) shrink with less work per element or more threads.
- **Production only** [CODE]: `witness::build_for_block` ran `BlockPublic::check_accuracy_for_shape`, then
  `build_accuracy` ran three of its checks again, then `accuracy::build` four of them again (§3, `once`). The harness
  calls `build_accuracy` directly, so the A15 sample did not contain the doubled work.

## 1. What changed (`witness.rs`, `witness_accuracy.rs`; the blocks marked `[A16]`)

Seven byte-preserving forms, one bit each, chosen by `HL_A16` (unset, empty or `auto`: the default, **every form**;
`0` (or `old`, `none`): none, the builder before A16; `all`; or a `,`/`+` list of the words). The forms are read once
per build at its entry (`build_accuracy`, `build_for_block`) and carried into its parallel regions; the builder's
sequential reference (`with_sequential`, tests) takes none.

| word | what | the sequential path it replaces | why the same words |
|---|---|---|---|
| `cache` | every domain's support and chunk plan kept for the process (`ShareCache`, keyed by `Geom::cache_key`: the true extents, the padded strides, the domain's size and every head's slot; at most 64 entries) | `Geom::support` in `build` (5 domains), `residual` (2) and `assign` (per domain), and `chunk_plan`'s grouping loop, every block | a pure function of the public geometry: the cached vector is the one a fresh call builds |
| `quant` | `quantized` writes its two planes chunk by chunk on the pool (each support position is in one chunk), zeroed on the pool | H124c's parallel chunks, then a serial read-back into the planes | the same per-position function at the same positions; on any refusal `quantized` itself runs and names its (the sequential loop's) first |
| `norm` | `normalized`'s 128 rows in parallel; each row's divisions in i64 when every intermediate fits (the bound uses at least the int16 maximum and the isqrt window, so for an int16 row it is a function of public constants) | one thread, i128 `div_euclid` / `rem_euclid` (`__divti3`) | Euclidean division is the same integers in any width that holds them; the first refusal in row order is the sequential one (a row's refusal depends on that row only) |
| `loops` | `build`'s per-position loops on the pool: the input scatter, the PV scatter, the ungated exp lookup, `a_scaled`, the `hacc` products, both residuals; its zero planes zeroed on the pool instead of cloned on the thread | the same loops on one thread | indexed writes of the same function; the exp lookup and the residuals re-run their sequential loop on any refusal; `a_scaled` does on any lookup it would not make in bounds |
| `kernels` | the two largest parallel regions' inner loops over contiguous int16 rows: the scores (`qr . kr` over the head dimension) and the PV sums (accumulated `j` by `j` over the value rows) | i64 products through `qix` / `kvix` per element, the PV sum strided over `j` | QR, KR and V were range-checked to int16, P is at most 2^12: every product fits i32, and each sum adds the same terms in the same order onto 0 |
| `overlap` | the independent products and their requantizations side by side (`rayon::join`): Q (with its rotation), K (with its rotation) and V; gate and up | one after another | exact products and the same functions; the refusals taken in the sequential order (Q, K, V, QR, KR; gate, up) |
| `once` | production's `build_for_block` checks the block once | see below | see below |

**`once`: which checks run where** [CODE]. `BlockPublic::check_accuracy_for_shape(sh)` (`private_block.rs:850`) is
steps 1-9: 1 the stack is not Legacy; 2 `sh.check_constructed()`; 3 the attention half's CS-1; 4 the feed-forward
half's CS-1; 5 the data present; 6 `check_for_registry(sh.accuracy_registry(), geometry(sh), sh.accuracy_base(),
sh.accuracy_stack())`; 7 the folded gate shift equals `sh.accuracy_gate_shift`; 8 the -128 scan of the nine weight
arrays; 9 the DD column.

| path | before A16 | with `once` |
|---|---|---|
| `build_for_block(sh, blk, x)` (production: `seal_and_record`, the stack source's rebuild, the token CLI and the classifier pipelines) | 1-9; then `build_accuracy` 2, 6, 7; then `accuracy::build` 3, 4, 8, 6 | 1-9 once; then the input's own checks |
| `build_accuracy(sh, a, f, d, x)` called directly (the D55 harness, tests, `trained_accuracy`'s parity tools) | 2, 6, 7; then 3, 4, 8, 6 | 2, 6, 7; then 3, 4, 8 (the second 6 is skipped) |

Why it is sound: within one call each repeat is the same function of the same `sh` and the same `&BlockPublic` halves
(`blk.attention()`, `blk.feed_forward()`, `blk.accuracy()`), shared borrows that nothing changes in between, so it
cannot refuse after the first has passed; on bad public data the refusal is the first check's, in its order, with its
message, exactly as before (fail-closed). `build`'s step 6 uses `BaseShifts` built from `sh`'s fields, which is
`sh.accuracy_base()` field for field, and `accuracy.stack()`, which step 6 passing pins to `sh.accuracy_stack()`: the
same call. `once` changes no check of `prove_core`, `verify_core` or the loaders.

**Switches and test hooks.** `HL_A16` (above); `witness::set_a16_for_test` (the process) and `witness::with_a16` (this
thread's builds); `witness::A16_*` (the bits). The D55 harness's arm words (`run_fork_tests.rs`, `[A16]`): `a16old`,
`a16all`, `a16def`, `a16<form>`, `a16x<form>` and `prod` (every witness through production's `build_for_block`), joinable
with A14's and A15's words (`spauto+a16old+prod`); `HL_A16_SEAL_AB` (the sealing pass alone, A15's form), `HL_A16_SAMPLE`
(A15's sampler handshake), `HL_A16_ONLY`.

**Test-only.** With `with_device_products` pinning a thread's products, `overlap` stays off on that thread (A4's test
counts the products on the calling thread; a product made on another thread would not see the switch).

## 2. The sealing pass alone (stage 1) [MEASURED, `s1_alone_table.md`, `s1_alone.log`]

`HL_A16_SEAL_AB`, 4 passes, the whole arm order reversed in odd passes, the base (`a16old`, the builder before A16)
first or last; device products; the default sealing pool (8 threads here) unless named.

| arm | wall s | user CPU s | sys CPU s | vs before A16, bias out |
|---|---:|---:|---:|---:|
| before A16 (`a16old`) | 3.116 | 7.29 | 2.47 | — |
| `cache` | 2.653 | 6.83 | 2.39 | −14.9% |
| + `quant` | 2.333 | 6.22 | 3.30 | −25.1% |
| + `norm` | 2.111 | 6.14 | 3.45 | −32.2% |
| + `loops` | 2.038 | 6.34 | 4.04 | −34.6% |
| + `kernels` | 1.868 | 4.94 | 4.06 | −40.0% |
| **every form (the default)** | **1.630** | 5.09 | 4.02 | **−47.7%** |
| every form but `overlap` | 1.817 | 4.92 | 4.06 | −41.7% |
| every form but `kernels` | 1.927 | 6.47 | 4.02 | −38.3% |
| every form but `cache` | 2.079 | 5.54 | 3.84 | −33.2% |
| every form but `quant` | 1.842 | 5.71 | 2.93 | −40.9% |
| every form but `norm` | 1.831 | 5.15 | 3.81 | −41.2% |
| every form but `loops` | 1.832 | 4.93 | 3.60 | −41.2% |
| production's builder (`prod`), before A16 | 3.223 | 7.92 | 2.40 | +3.4% |
| `prod`, every form | 1.672 | 5.14 | 4.06 | −46.3% |
| `prod`, every form but `once` | 1.756 | 5.78 | 4.12 | −43.6% |
| every form, a pool of 12 | 1.522 | 6.28 | 5.70 | −51.1% |
| every form, a pool of 16 | 1.741 | 7.52 | 10.43 | −44.1% |

- **Every form pays on top of all the others**: each "every form but one" arm is slower than every form (by 0.19 to
  0.45 s). `cache` is the largest single form, then `kernels`, `overlap`, `quant`.
- **`once`** (production's path): the doubled checks cost production 0.11 s per pass before A16 (`prod` against
  `build_accuracy`, +3.4%); on top of every other form `once` takes 0.084 s off (1.756 → 1.672 s).
- **The pool**: alone, 12 threads beat 8 (−6.6%), 16 does not. The stream decides (§4).
- System CPU rose from 2.5 to 4.0 s (more of the pass is short parallel regions); user CPU fell from 7.3 to 5.1 s.
- The minor faults stay about 529,000 per pass (the 32 kept witnesses' fresh pages; not a difference).

**The ranking after A16** (the sampler, 2 passes of every form against 2 of none in the same process;
`s1_sample_s0.split.txt`, `s1_sample_s1.split.txt`, `s1_sample_s*.summary.txt`) [MEASURED], per pass:

| | before A16 | every form |
|---|---:|---:|
| the main line (the build's own thread) | 2.49 s | 1.24 s |
| of which serial | **1.15 s** | **0.04 s** |
| waiting on the device | 0.48 s | 0.36 s (part of it moved to the overlapped halves' threads) |
| in its own parallel regions (`assign`'s limb planes; `quantized`; the scores and heads; the zeroing) | 0.76 s | 0.77 s |

With `overlap` part of the build runs on other threads of the pool, so the main line no longer holds all of it. What
is left is the device's products and the parallel regions: `assign`'s limb planes (0.29 s), `quantized`'s fills
(0.20 s), the zeroing on the pool (0.05 to 0.10 s by the two scripts' classifications; it is where most fresh pages
are first touched), the scores and heads.

## 3. Stage 2 was polluted; stage 3 is the measurement

Stage 2 (`s2.sh`, `s2.progress`, `s2_*.md`) ran the same A/Bs from 22:57Z, and from 22:58:15Z an outside GPU job (a
frugal-lm SSD-streaming benchmark, `ds4-bench-frugal`, RSS above 128 GB, outside the guard) ran beside it (the
coordinator's note). Its clocks are POLLUTED (its proof-only calls took 5.0 s against 4.1 s): its files are kept as a
record and nothing here is drawn from them. Its byte results stand (every receipt verified at its size). Stage 3
(`s3.sh`) re-ran the A/Bs with the coordinator's quiet-GPU wait (`quiet` / `seen`, `../check_a17merge.sh`): no
`ds4-bench` process at the start or the end of any of its three clocks (`s3.progress`). Stage 1's clocks (22:37 to
22:43Z) ended before the outside job began.

## 4. The A/Bs (stage 3, a quiet GPU) [MEASURED, `s3_pairs_*.md`, `s3_seal13_*.md`, `s3_seal_*.md`]

In-process, N = 6, `HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4` (A15's `s3.sh` env): each arm and pass a
proof-only fork call (the control: no sealing pass), one request from its input and a 4-request stream (every stream
receipt verified after its clock; each arm's first proof-only and sealed receipt verified; every fork receipt
818,728,672 B). "Base first" / "test first": the passes in which that arm ran first; the bias-solved figure is their
mean. (n pairs, n favouring the test.) From `../a11/pairs.py --alternate --n 6`, `../a13/seal_pairs.py`,
`../a15/seal_pairs.py`.

### 4.1 The builder before A16 against A16's default, 6 passes (`spauto+a16old` against `spauto+a16def`, both in the default sealing pool of 8)

| metric | base first | test first | order bias solved out | means, before / A16 |
|---|---|---|---|---|
| **one request from its input** | −21.6% (3, 3) | −22.6% (3, 3) | **−22.1%** | 7.450 / 5.800 s = 17.18 / 22.07 tok/s |
| its sealing pass | −47.7% (3, 3) | −50.4% (3, 3) | **−49.1%** | 3.382 / 1.721 s |
| its sealing pass's user CPU | −30.1% (3, 3) | −31.3% (3, 3) | **−30.7%** | 7.69 / 5.33 s |
| its sealing pass's system CPU | +59.8% (3, 0) | +38.8% (3, 0) | +49.3% | 2.91 / 4.34 s |
| its prove call (preflight to last byte) | −0.1% (3, 1) | +0.7% (3, 1) | +0.3% | 4.068 / 4.080 s |
| **the 4-request stream, steady** | +5.2% (3, 3) | +8.7% (3, 3) | **+7.0%** | 29.05 / 31.06 tok/s |
| **the 4-request stream, amortized** | +11.2% (3, 3) | +14.4% (3, 3) | **+12.8%** | 24.31 / 27.41 tok/s |
| the stream's sealing passes beside the forks (requests 1–3) | −39.5% (3, 3) | −42.5% (3, 3) | **−41.0%** | 4.522 / 2.667 s |
| proof only (the control) | +1.4% (3, 1) | +0.4% (3, 2) | +0.9% | 4.063 / 4.099 s |
| proof only, user / system CPU | | | +0.6% / −1.4% | 41.1 / 41.4 s; 7.23 / 7.12 s |

- **One request and the stream favour A16 in every pair, in both orders.** The proof-only call (no sealing pass)
  moves +0.9% with 1 and 2 of 3 pairs: noise.
- Bests: one request 7.338 → 5.697 s (17.44 → 22.47 tok/s); the stream steady 29.68 → 31.53 tok/s.
- **The stream is now fork-bound.** Its sealing passes beside the forks (2.7 s) are well under a fork run (4.1 s), so
  the sealing thread runs ahead and each sealed request waits for the forks: inside the stream the per-request latency
  (measured from the start of the request's sealing pass) is 6.2–6.5, 8.9–9.2, 10.1–10.5 and 11.6–12.2 s with A16
  against 7.7–8.0, 8.7–9.0, 8.6–8.9 and 8.4–8.8 s before (`s3_default_d55_ab.log`'s PIPE lines). The steady
  state, 31 tok/s (4.1 s per request), is the fork run's own rate.

### 4.2 The pool re-sweep on A16's default, 4 passes (exploratory; 8 = `spauto` against 12 and 16)

| metric | 12 threads, bias out | 16 threads, bias out | means, 8 / 12 / 16 |
|---|---|---|---|
| one request from its input | +2.1% (4, 0) | +7.0% (4, 0) | 5.609 / 5.729 / 6.000 s |
| its sealing pass | +11.1% (4, 0) | +25.2% (4, 0) | 1.517 / 1.685 / 1.900 s |
| the stream, steady | −1.2% (4, 0) | −1.3% (4, 0) | 31.54 / 31.17 / 31.13 tok/s |
| the stream, amortized | −2.3% (4, 0) | −3.2% (4, 0) | 28.07 / 27.44 / 27.18 tok/s |
| the stream's sealing passes beside the forks | +8.2% (4, 0) | +15.2% (4, 0) | 2.619 / 2.833 / 3.018 s |
| proof only (control) | +0.2% | −0.7% | 4.060 / 4.069 / 4.033 s |

**8 threads stays: the rule `(cores / 4).clamp(1, 8)` is not changed** (every pair favours 8 on one request and the
stream). Alone (stage 1) 12 threads was 6.6% faster than 8; inside the D55 process, with the forks' pools beside it,
it is slower in every pair. The RTX 5090 box should re-measure the rule with its own CPU.

### 4.3 Production's builder, 4 passes (`spauto+a16old+prod` against `spauto+a16def+prod`: every witness through `build_for_block`, as `seal_and_record` builds it; here `once` acts too)

| metric | base first | test first | order bias solved out | means, before / A16 |
|---|---|---|---|---|
| **one request from its input** | −22.8% (2, 2) | −25.0% (2, 2) | **−23.9%** | 7.540 / 5.738 s = 16.98 / 22.31 tok/s |
| its sealing pass | −49.3% (2, 2) | −52.6% (2, 2) | **−50.9%** | 3.518 / 1.723 s |
| **the stream, steady** | +10.0% (2, 2) | +10.1% (2, 2) | **+10.0%** | 28.47 / 31.32 tok/s |
| **the stream, amortized** | +14.1% (2, 2) | +14.6% (2, 2) | **+14.4%** | 24.07 / 27.52 tok/s |
| the stream's sealing passes beside the forks | −40.0% (2, 2) | −41.3% (2, 2) | **−40.7%** | 4.604 / 2.731 s |
| proof only (control) | −0.6% (2, 2) | +1.0% (2, 0) | +0.2% | 4.053 / 4.061 s |

- Before A16, production's builder was slower than the harness's (`build_accuracy`) by its doubled checks: 3.52
  against 3.38 s of sealing in these processes (and +3.4% alone, §2); with A16 both are 1.72 s.
- Bests: one request 7.410 → 5.673 s (17.27 → 22.56 tok/s); the stream steady 28.77 → 31.85 tok/s.
- Per-request latency inside the stream: 6.3–6.4, 8.9–9.1, 10.2–10.4, 11.5–11.6 s with A16 (fork-bound, as in 4.1).

## 5. Why no byte moves, and the byte evidence

**The argument** (§1's table, and the `[A16]` comment block in `witness.rs`). Every form writes the same words at the
same positions: a cache returns the vector a fresh call builds; each parallel loop is an indexed write of the same
per-position function, each position written by one task; integer division is the same integers in any width that
holds them; the int16 kernels sum the same exact products in the same order. Refusals: a new parallel loop only
detects that some position refuses and then runs the sequential loop it replaces, which names that loop's first
refusal; the per-row form returns the first row's refusal in row order; `overlap` takes its halves' refusals in the
sequential order; `once` skips only checks that cannot refuse after the identical first one passed. Nothing in the
builder draws randomness or touches a transcript.

**The words** [MEASURED]:
- **The 8B chain, 32 blocks, every plane of every witness** (the harness's `HL_A16_SEAL_AB`, device products, one digest
  per arm; `s1_alone.log`): `c0d2266503df6675` (A15's) under all 18 arms of §2: the builder before A16, each form added,
  every form, every form but each one, production's `build_for_block` before A16, with every form and every form but
  `once`, and every form in pools of 8, 12 and 16.
- **The suite** (`c2.progress`; in the acceptance's full suite too):
  - `w16r2_tests::a16_every_form_builds_the_same_planes_and_refuses_the_same`: at the W16R2 and R13 rungs, the R13 DD
    rung and R13 TinyLlama T128 (every chunked form active), 11 inputs each, through `build_accuracy` and production's
    `build_for_block`, in no form and in 16 form sets (each form alone, every form but each one, all, the default):
    every plane equal, or the same refusal (the DD rung refuses all 11 identically at its dictionary column).
  - `w16r2_tests::a16_every_form_refuses_as_the_builder_before_a16_at_every_site`: calibration variants of the rungs
    (norm multipliers 30,000; the gate shift 1; the shift variants that do not build are skipped and named), 11 inputs,
    both entries, 16 form sets: the same planes or the same refusal, at four sites reached (`norm quotient/remainder`,
    `score`, `FFN gate`, `residual 1`).
  - `w16r2_tests::a16_the_rung_chain_in_every_form_and_every_pool`: A15's three-block rung chain (three different
    inputs) in 16 form sets at A15's 11 places (rayon pools of 1, 4, 8, 16; the sealing pool at 0, 1, 4, 8, 16 and the
    default): every plane equal; the first witness is `rung_case`'s.
  - `witness_accuracy::tests::a16_*`: `quantized` over chunks against a hand-made plan visited out of support order
    (two refusals of different kinds in two chunks: the first in SUPPORT order is returned, in both orders);
    `normalized` by rows against the reference (the i64 and i128 forms; two bad rows of different kinds, in both
    orders); `residual` over chunks; the switch's words.
  - The existing equality tests, now running the default forms: H124c's parallel-against-sequential test (six
    profiles including the W16R2 8B block and the R13 8B DD block) and A4's device-against-CPU test (all seven
    products on the device, every route).
- **The 8B block, CPU and device products** (`w16r2_tests::a16_the_8b_witness_planes_in_every_form`, ignored, run in
  stage 1 and in the acceptance; `s1_a16_8b.log`): A15's three-witness 8B chain through `build_for_block` in no form
  and the 16 sets, on the calling thread and in the default sealing pool with CPU products, and on the calling thread
  and in sealing pools of 8, 16 and the default with device products: 102 chains, every witness `5808a1cd…` (A15's);
  `build_accuracy` in no form, every form and the default: the same; 7 wider inputs (all admissible here) in every set;
  and the calibration variants at the 8B shape with device products: the same planes or the same refusal
  (`score`, `FFN gate`, `residual 1`).
- **The caveat A15 named still holds**: the synthetic 8B block is a fixed point (its output is its input), so its
  chains repeat one build; the rung chain and the suite's 11 inputs per profile are the different-input evidence.
- **The proofs**: the W16R2 rung golden, the six trained digests and the receipt sizes in the acceptance (§7); every
  D55 receipt of every A/B call verified at 818,728,672 B.

## 6. The synthetic diagonal weights

The fixture's public weights are diagonal (A15's recipe, `grow_tests::tame_case`). None of A16's forms reads a weight:
the products are untouched (they run on the device, A4), and the forms act on the supports (geometry), the
requantizations, the norms, the softmax/PV loops and the limb planes, whose work per position does not depend on the
weights' values. The one weight-dependent saving is `once`'s (it skips scans over the weights), whose cost is the
weights' size, not their values. So no gain here depends on the weights being diagonal [INFERRED from the code].

## 7. Acceptance [MEASURED, `s4.sh`, `s4.progress`, `s4_*.log`, `s4.guard.json`]

The final tree (perf `910c2ac4` with A16; the default every form; the pool rule unchanged): A15's `s4.sh` pointed at
this worktree, plus A16's 8B test, and the coordinator's quiet-GPU wait around the clock. One guarded job (00:04 to
00:16Z):
- **build:** rc 0. **The no-feature `cargo check --tests`:** rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures; `s4_full.log`): **933 passed, 3 failed, 108
  ignored.** The three failures are exactly the known ones, at A15's panic sites:
  `review_tests::a_toy_receipt_made_before_f12_is_refused` (`review_tests.rs:738:5`),
  `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`
  (`trained_accuracy.rs:515:96`, a fixture file not found, before the builder: unchanged), and
  `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`
  (`trained_stack_tests.rs:553:44`). 933 is A15's 926 plus A16's seven suite tests; 108 ignored is A15's 107 plus
  A16's 8B test. H124c's, A4's, A15's, A14's, A12's and A8's suite tests pass in the default forms, and the trained
  stack's CLI tests (which run `seal_and_record` through `build_for_block`, and with `--witness-cache-gib 0` the
  rebuild) pass with `once`.
- **zkp-core's lib tests:** 81 passed, 2 ignored.
- **A16's 8B test** (`s4_a16_8b.log`): as in stage 1 (§5): 102 chains `5808a1cd…`, refusals equal.
- **A15's 8B test** (CPU and device products, 22 places): every plane `5808a1cd…`.
- **A14's byte tests:** the 8B private tables under both sums (56 tables, 8.56 M words equal); the rung golden
  `96e4f0b6` on the CPU under three settings and on Metal under six; the 8B block's core proof under every setting,
  twice each, one digest (`a32cb0dd0fc2ec46`).
- **The A8 rung test, the A12 census and rung-mode tests, the A11 pool tests (CPU and Metal), the A7 queue test:** all
  pass, `96e4f0b6` throughout.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the default** (`s4_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4`;
  no `ds4-bench` at the start or the end of the clock):

| W16R2 8B T128, 32 blocks, N = 6 | this run (`s4_d55.log`) | A15's acceptance (`../a15/s4_d55.log`), for reference |
|---|---:|---:|
| proof only, the two calls | 4.202, 3.982 s | 4.061, 4.044 s |
| proof only, best | 32.15 tok/s | 31.65 |
| one request from its input, the two calls | 5.538, 5.694 s (sealing passes 1.495, 1.495 s) | 7.213, 7.205 s (3.160, 3.226 s) |
| one request from its input, best | **5.538 s = 23.11 tok/s** | 17.76 |
| stream of 4, steady / amortized | **31.83 / 28.34 tok/s** | 28.60 / 24.49 |
| per-request latency in the stream | 6.00, 8.89, 10.15, 11.58 s | 7.48, 8.65, 8.91, 8.74 s |
| the stream's sealing passes | 1.50 s alone; 2.62, 2.38, 2.86 s beside the forks | 3.28 s alone; 4.42, 4.47, 4.79 s |
| serial D12a, best | 9.610 s = 13.32 tok/s | 9.574 s |

- **Receipts:** every receipt the harness verifies verified (the D12a verifier on the first serial pass, the D55
  verifier on the first proof-only and sealed passes, all 4 stream receipts after the clock). Fork receipts
  818,728,672 B and D12a receipts 818,728,480 B, unchanged (and in every call of every A/B of stages 2 and 3).
- The A15 column is another process on another state of the box; the in-process A/Bs of §4 are the measurement.

## 8. Privacy-gate notes

- **The production digests that moved: `private_block/witness.rs` and `private_block/witness_accuracy.rs`** (the
  witness builder; `witness_accuracy.rs` is privacy-pinned as part of it). `trained_block.rs`, `private_block.rs`,
  `protocol.rs`, `argument.rs`, `run_fork.rs`, `gpu/*` and zkp-core are unchanged by A16.
- **Timing.** No form adds a path whose running time depends on a hidden value. The sequential re-runs happen only on
  a refusal (which ends the build, as before). The int16 kernels and the i64 norm decline only for words outside the
  classes the earlier range checks enforce (QR, KR, V int16 after their requantization; P at most 2^12; the norm's
  bound uses at least the int16 maximum and the isqrt window with the public multiplier and shift), so for an
  admissible trace the same form is taken whatever the values. `overlap` and the pool size are public settings.
- The new caches hold supports and chunk plans: public geometry only. Nothing new is printed, kept or hashed; no
  dependency is added. `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## 9. What is left

- **The stream is now fork-bound** [INFERRED from §4]: the sealing pass beside the forks is well under a fork run's
  proof time, so the stream's steady state is set by the forks (about 4.1 s of proof per request). A further stream
  gain needs the forks faster (A17, W16R3); further sealing gains help one request's latency only.
- **The sealing pass's remainder** [MEASURED, §2]: the device's seven products (about 0.5 s of device time per pass,
  partly overlapped now), `assign`'s limb planes (0.29 s; one parallel region per limb plane: fusing a role's planes
  into one region would halve the passes for two-limb roles), `quantized`'s fills (0.20 s), the zeroing on the pool
  (where most of the pass's 529,000 fresh pages are first touched: a domain whose support covers every position, as
  D, Q, Kv and S do at 8B, could be written in one pass by an indexed collect instead of zeroed first), and the
  attention half's `assign` work, which could run beside the feed-forward half's device products.
- **Production's other doubled check**: `seal_and_record` loads each layer through `TrainedExport::load_layer`
  (`load_layer_mode`, `trained_block.rs:1414`, beside the previous layer's build), which runs
  `check_accuracy_for_shape` at the layer's calibration, and the build checks the block again at its own shape;
  removing that one crosses a function boundary and two shapes (a checked-block token in `TrainedLayer`), so it was
  left.
- **Sites 7 and 8 of A15** (the MVP driver's and the token CLI's sealing passes) take every A16 form already (they call
  the same builder); A15's pool is still theirs to adopt.
- **Not measured**: a trained 8B export's own sealing pass (no trained 8B export is on the Mac), and any machine but
  this one (the RTX 5090 box's CPU should re-measure the pool size).

## 10. Files

- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/witness.rs` (production): the `[A16]` block (the switch
  `HL_A16`, `a16_parse`, `a16_forms`, the `A16_*` bits, `ShareCache`, `zeros`, `GeomKey`; test-only `set_a16_for_test`,
  `with_a16`, `products_pinned`); `Geom::cache_key`, `Geom::support_shared`; `build_accuracy` → `build_accuracy_with`
  and `build_for_block`'s `once` path.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/witness_accuracy.rs` (production): `Checked`, `shared_plan`,
  `support_of`, `plan_for`, `quantized_with`, `norm_row`, `normalized_par`, `residual_with`, `narrow16_par`,
  `dot16_16`; `build` → `build_with` and `assign` → `assign_with` with every form (the old paths kept beside them);
  `ChunkPlan::count`; the `[A16]` unit tests.
- Tests: `w16r2_tests.rs` (the `[A16]` block at the end: `a16_form_sets`, `a16_inputs`, `a16_same`, `a16_outcome`,
  `a16_variant`, `a16_variant_edits`, `a16_chain`, the three suite tests and the ignored 8B test); `run_fork_tests.rs`
  (the `[A16]` block: `a16_form`, `a16_word`, `A16_PROD`, `a16_apply`, `a16_seal_arm`; the arm fields `a16`, `prod`;
  `HL_A16_SEAL_AB`, `HL_A16_SAMPLE`, `HL_A16_ONLY`; the harness's `build` honours `prod`).
- No new module, so no census list changes.
- This directory: `c1.sh`, `c2.sh` (compile and correctness), `s1.sh` (the sealing pass alone, samples, the 8B byte
  test), `s2.sh` (the A/Bs, POLLUTED by an outside GPU job: kept as a record only), `s3.sh` (the A/Bs on a quiet GPU),
  `s4.sh` (the acceptance); their progress files and guard records; `run_stage.py` (A15's runner), `alone_table.py`
  (A15's, for the A16 lines), `mainline_split.py`, `mainline_leaves.py`; the tables (`s0_a15sp8_split.txt`,
  `s1_alone_table.md`, `s1_sample_s*.split.txt`, `s1_sample_s*.summary.txt`, `s3_pairs_*.md`, `s3_seal*_*.md`; the
  polluted `s2_*.md`); the logs `c2_unit.log`, `c2_a16.log`, `c2_speed.log`, `s1_alone.log`, `s1_sample.log`,
  `s1_a16_8b.log`, `s3_default_d55_ab.log`, `s3_pools_d55_ab.log`, `s3_prod_d55_ab.log` and `s4_*.log` (each under
  150 KB). The raw sample call graphs (3–6 MB) and the other raw logs stay in `raw/`, not committed.
