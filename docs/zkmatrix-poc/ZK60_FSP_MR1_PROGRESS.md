# FSP lane 5 — the public-endpoint repaired-mask timing probe (`mr1`)

**Worktree** `/home/victor/wt-fsp-mr1`, branch `fsp-mr1`, on top of the
finished lane `fsp-zkhost` (tip `fb850b8`).
**Sole writer.** Files owned by this lane: `hashline/src/zk.rs`, the new
`hashline/src/zk_mr1_probe_tests.rs` and its one registration line,
`hashline/examples/zk60_repaired_mask_probe.rs`, `results/fsp5_*`, and this
ledger. Everything else in this repository and every other worktree is
READ-ONLY for this lane. In particular `hashline/src/layer.rs`, `pcs.rs`,
`wcache.rs`, `ntt.rs` and `hashline/src/gpu/*` belong to the other speed
lane; `zk_ffn_fresh_*.rs`, `private_*.rs`, `bin/hashline.rs`, `scripts/`,
`tests/` and every design document but this one are read-only here.
`/home/victor/IntelligenceRegulation` (Codex works live there) and
`/home/victor/wt-fsp-zkhost` (detached jobs still queued against its
sources) are never written by this lane.

**What the lane is.** Every PRIVATE timing in this repository was measured
on the legacy privacy profile, which the 2026-09-08 finding showed
DISCLOSES private values. A repaired mask schedule exists in code — `mr1`:
paired mask rows, refusal instead of resampling, a rank check before every
opening — and `ZK60_PRIVATE_FFN_COST_PROBE.md` establishes by reading the
constructors that it is already shape-general. But NOTHING CAN CALL IT
above the tiny T32/d16/f16 shape: `prove_layer_zk_v3` hard-codes
`mr1 = false` and the two inner functions are private. So nobody knows what
the repaired profile COSTS at a real shape. By row count it should be the
legacy cost plus about 2% at T = 512 — that is a COUNT. This lane produces
the first MEASUREMENT, at the 125M-class shape (12 layers, width 768,
hidden 2048, 512 tokens) and at nothing wider.

**THIS IS A COST PROBE, NOT A PRIVACY CLAIM.** The entry pair this lane
adds runs the repaired mask schedule with **PUBLIC endpoints**. The
hiding-endpoint half (`zk_ffn_fresh_io.rs`, `private_seam.rs`, their size
pins) is OUT OF SCOPE and is not touched or unpinned. Running this probe
establishes NO privacy property whatsoever — not P1, not anything. It
measures what the repaired mask schedule costs in seconds, bytes and
committed rows.

**The lane is strictly byte-preserving for every existing path.** The
legacy default stays `mr1 = false`; the tiny private-IO entry points stay
pinned to their tiny shape; no transcript label, mask schedule, endpoint or
privacy-policy change is made to any existing path. If the repaired profile
at a larger shape REQUIRED such a change, the instruction is to stop and
report rather than make it. A moved frozen digest is a BUG in the change:
revert, record, move on. Never adjust a gate, never re-freeze a digest.

Every number carries its shape, conditions, box load and label:
[MEASURED], [COUNTED], [MODEL].

---

## Stages

| # | stage | status |
|---|---|---|
| 0 | Ledger, ownership, the scoping memo and the previous lane's ledger read | DONE |
| 0b | Inherited red: one doctest on the base branch, comment-only fix | DONE |
| 1 | FLOOR on the untouched tip: suite + the four frozen digests on CPU, GPU, GPU forced-chunked | DONE — 12/12 green, 259 tests + 5 doctests |
| 2 | The entry pair in `zk.rs` (one commit) + its cfg(test) file; then the whole floor again | DONE — 265 tests, 12/12 gates, NO DIGEST MOVED (`9c45f1c`) |
| 3 | The driver: `hashline/examples/zk60_repaired_mask_probe.rs`, three arms | DONE |
| 4 | The first measurement at 12 x 512, CPU and GPU binaries, >= 5 repeats/arm, alternating order | DONE — 30 runs (`150acc1`) |
| 4b | The CPU ladder repeated on a quiet box | DONE — 15 runs (`3d1cdab`) |

**Not in scope and not run, by instruction:** anything at Mistral width
(4096 / 14336) on either processor; any model-width GPU run; the
hiding-endpoint (`io`) half at any shape above the tiny one.

---

## The frozen floor (from lane `fsp-zkhost`, stage 2)

`pass 12 512 --threads 2` against
`/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export` (v3 profiles)
and the built-in fixture (v2 / zk):

| profile | digest | bytes |
|---|---|---:|
| v2 | `50cf7bdf..` | 66,844,928 |
| v3 | `5f368db6..` | 70,758,084 |
| zk | `021485e4..` | 87,228,528 |
| zk-v3 | `40eb5479..` | 87,697,008 |

Build notes inherited from that lane: the GPU build needs `CUDA_ROOT` set
or `cudarc v0.13.9`'s build script exits 101; the GPU binary lives in a
separate target directory, `hashline/target-gpu/release/hashline`.

---

## Log

### 2026-09-19 — stage 0, ledger opened

Read in full: `docs/zkmatrix-poc/ZK60_PRIVATE_FFN_COST_PROBE.md` (1,077
lines, read from the main tree — it is not yet on this branch's history)
and `docs/zkmatrix-poc/ZK60_FSP_ZKHOST_PROGRESS.md` (478 lines). Read in
part: `hashline/src/zk.rs` (the layout constructors, the two entry pairs,
the pending lifecycle, every `mr1` site), `hashline/src/zk_ffn_fresh_poc.rs`
(all 342 lines), the previous lane's gate script.

**Line numbers verified against this branch's `zk.rs`** (the memo's were
written before lane `fsp-zkhost` landed and several have moved):

| what | memo says | this branch |
|---|---|---|
| `ZkLayoutV3::with_masks` | 2002-2054 | **2002-2055** (unmoved) |
| the masking-commitment specs | 2149-2174 | **`mask_specs_v3` at 2149** (unmoved) |
| `prove_layer_zk_v3` hard-codes `mr1 = false` | 2280 | **2429-2431** |
| `prove_layer_zk_v3_inner` (private) | 2283 | **2433** |
| `prepare_layer_zk_v3_inner` (private) | 2337 | **2494** |
| `verify_layer_zk_v3` (public, `mr1 = false`) | — | **3697-3699** |
| `verify_layer_zk_v3_inner` (private) | 3467/3471 | **3701** |
| `verify_layer_zk_v3_with_seams` (private) | — | **3705** |
| the `mr1` refusals | `zk_ffn_fresh_poc.rs:221-341` | **unmoved: 221-341** |

So the memo's central claim holds on this branch: `with_masks` takes the
shape as a parameter, every refusal in `zk_ffn_fresh_poc.rs` is written
against `rows` / `log_n` / `mask_rows` / `prox`, and the only thing missing
is a caller.

### 2026-09-19 — stage 0b, an inherited red: one doctest, comment-only

Reported by the orchestrator and confirmed by reading the source: on the
base branch `fsp-zkhost`, `cargo test --release` fails exactly ONE doctest,
`src/zk.rs - zk::fsp_i8fold (line 2381)`, with
`expected one of `!` or `::`, found `[``. Every functional test passes.

**Cause.** In the doc comment lane `fsp-zkhost` wrote above `fsp_i8fold`
(zk.rs 2369-2394) the formula line

    wgk[c*db + kp] = sum_j cw_gu[j] . src = sum_b lam_f[b] * blk_b[kp]

is indented four spaces, which is Markdown for an indented code block;
rustdoc defaults an unmarked code block to Rust and tries to compile the
formula. Doctests are collected from private items too, so a private
`fn` is not exempt.

**Fix.** Wrap that one line in a fence marked `text` and un-indent it to
one space after `///`. Nothing else in the file has a four-space-indented
doc line at module level: the only other hits (zk.rs 4186-4201) are
continuation lines of a numbered list inside `#[cfg(test)] mod tests_v3`,
which rustdoc does not collect and which are list continuations, not code
blocks. The `HL_FSP_POOL` module's doc comment (zk.rs 2288-2314) is clean.

**It is comment-only: no proof byte can move.** The four frozen digests are
run anyway, in stage 1, on the tree that carries this fix — so the floor
below is the base tip PLUS this comment change, and that is what stage 2
is compared against.

### 2026-09-19 — stage 1, the floor

**Builds**, both detached under `flock -w /tmp/zk-build.lock`, offline,
`-j 2`, from an empty target directory:

* CPU: `cargo build --release -j 2 --offline --manifest-path
  hashline/Cargo.toml` — exit 0, 1 m 12 s.
* GPU: the same with `CUDA_ROOT=/home/victor/cuda-root`,
  `LD_LIBRARY_PATH=<cuda-root>/lib64:...`,
  `CARGO_TARGET_DIR=/home/victor/wt-fsp-mr1/hashline/target-gpu`,
  `--features gpu-cuda` — exit 0, 1 m 20 s. (The previous lane's note holds:
  without `CUDA_ROOT` the `cudarc` build script exits 101.)

**Byte gates, `pass 12 512 --threads 2`, 12 of 12 GREEN** [MEASURED,
NOISY-SHARED — another worktree's oracle battery and a second lane's cargo
jobs were on the box throughout; the digests are what this table is for,
the seconds are not]. Runner
`<scratch>/mr1/gate.sh <label> <profile> <tag>`: exactly one prover process
per invocation; each GPU label runs inside its own detached
`flock -w 10800 /tmp/zk-heavy.lock` job, with a wrapper that polls
`nvidia-smi` WHILE HOLDING that lock and only launches when the card reads
<= 1,024 MiB with no compute apps. The card read **0 MiB / 0 apps** before
every one of the eight GPU launches. Nothing was chained.

| gate | label | digest | bytes | verdict | prove |
|---|---|---|---:|---|---:|
| v2 | cpu | `50cf7bdf..` | 66,844,928 | GREEN | 35.30 s |
| v3 | cpu | `5f368db6..` | 70,758,084 | GREEN | 35.67 s |
| zk | cpu | `021485e4..` | 87,228,528 | GREEN | 36.01 s |
| zk-v3 | cpu | `40eb5479..` | 87,697,008 | GREEN | 37.34 s |
| v2 | gpu | `50cf7bdf..` | 66,844,928 | GREEN | 2.24 s |
| v3 | gpu | `5f368db6..` | 70,758,084 | GREEN | 1.99 s |
| zk | gpu | `021485e4..` | 87,228,528 | GREEN | 3.80 s |
| zk-v3 | gpu | `40eb5479..` | 87,697,008 | GREEN | 4.20 s |
| zk | gpu, `HL_ZK_CHUNK=1` | `021485e4..` | 87,228,528 | GREEN | 3.76 s |
| zk-v3 | gpu, `HL_ZK_CHUNK=1` | `40eb5479..` | 87,697,008 | GREEN | 3.92 s |
| zk | gpu, `HL_GPU_CHUNK_BYTES=100000000` | `021485e4..` | 87,228,528 | GREEN | 3.87 s |
| zk-v3 | gpu, `HL_GPU_CHUNK_BYTES=100000000` | `40eb5479..` | 87,697,008 | GREEN | 3.92 s |

**`cargo test --release -- --test-threads=2`: exit 0 — 28 test binaries,
259 passed, 0 failed, 0 ignored, plus 5 doctests passed** (log
`<scratch>/mr1/test_base.log`). The inherited doctest red of stage 0b is
gone: `Doc-tests hashline` now runs 5 tests and all pass.

**The floor is green, everywhere. Work may proceed.**

### 2026-09-19 — a note for the integrator about stage 0b

The previous lane's agent has since fixed the SAME `fsp_i8fold` doc comment
on `fsp-zkhost` itself (same shape of fix — the formula fenced as a text
block); that branch's tip is now `e45ebda` with 259/0 and green doctests.
This branch was cut from the older tip `fb850b8`, so it carries its own
copy of the fix and is green on its own. **Both branches therefore carry a
comment-only change to the same doc comment: expect a trivial conflict
there at merge.** This lane did not merge, rebase or cherry-pick anything —
the orchestrator reconciles the two branches.

### 2026-09-19 — stage 2, the entry pair

**One commit, `hashline/src/zk.rs` plus a new `cfg(test)` file and its one
registration line. No other file.** 80 lines added to `zk.rs` (53 of them
comment or doc comment, 27 code; nothing removed and no existing line
altered), and a new 247-line `hashline/src/zk_mr1_probe_tests.rs`.

**What was added.**

1. `pub const MR1_PROBE_PROFILE: &[u8] =
   b"hashline-zk-mr1/ffn-v3-mr1-probe/1"` — the probe's Fiat-Shamir domain
   separator.
2. `pub fn prove_layer_zk_v3_mr1(w, t_rows, params, ntt, cfg, tr) ->
   Result<ProveOutputZk, String>`, next to `prove_layer_zk_v3`. It refuses a
   deterministic seed, draws `ZkRng::from_os(MR1_PROBE_PROFILE)`, absorbs the
   separator, and calls the EXISTING private
   `prove_layer_zk_v3_inner(.., mr1 = true, rng)`.
3. `pub fn verify_layer_zk_v3_mr1(st, proof, params, ntt, tr, mode) ->
   Result<(), String>`, next to `verify_layer_zk_v3`. It absorbs the same
   separator and calls the EXISTING private
   `verify_layer_zk_v3_inner(.., mr1 = true)`.
4. `pub fn zk_v3_committed_rows(st, params, is_p3, mr1) -> [usize; 4]` — the
   A / H / W / M committed row counts from the layout alone, nothing proven
   and nothing allocated. It exists because `ZkLayoutV3::with_masks` is
   private, so the driver could not otherwise report the row counts it is
   measuring.

**No new protocol, no new cryptography.** The whole change is a caller: the
mask schedule, the transcript labels inside the prover body, the layout, the
CFS specification and every refusal are exactly the ones that already
existed. The endpoints are PUBLIC — this pair does not hide the input or the
output and establishes no privacy property.

**How the two profiles are bound apart** (asserted, not assumed):

* **The domain separator.** Both new entries absorb
  `(b"zk-mask-profile", MR1_PROBE_PROFILE)` into the transcript before
  anything else they do; neither legacy entry absorbs it. Every challenge
  downstream therefore differs. The test asserts this directly on the
  transcript state, not merely through the two rejections.
* **The commitment shape.** The repaired layout commits strictly more rows,
  so a verifier on the wrong profile rejects on the A commitment's row count
  before it reaches a challenge at all.

**Tests** (new file, 6 tests, all passing):

| test | what it asserts |
|---|---|
| `the_repaired_entry_proves_and_its_verifier_accepts` | honest ACCEPT at the tiny shape; the repaired layout reports itself; the size breakdown matches the serialization |
| `the_two_profiles_are_not_confusable` | the separator is in the transcript state; a repaired proof is REFUSED by `verify_layer_zk_v3`; a legacy proof is REFUSED by `verify_layer_zk_v3_mr1`; the repaired A commitment is strictly larger |
| `every_tamper_leg_is_rejected_through_the_repaired_entry` | all 7 legs of the existing v3 tamper battery (`TamperV3::FlipX / FlipW / RemainderOutOfRange / WrongTableEntry / WrongRequant / WrongZ / OutOfRangeInt16`) proved through the new entry and REJECTED by the new verifier; the test additionally requires at least 4 legs to have reached the verifier rather than being refused at prove time |
| `the_legacy_entry_is_unchanged` | the legacy entry is still byte-deterministic under a seed, still verifies, and still builds the legacy (width-1) layout with the same A commitment row count |
| `the_repaired_entry_refuses_a_deterministic_seed` | the repaired entry refuses a seeded config |
| `the_repaired_layout_is_the_legacy_layout_plus_the_counted_rows` | at three shapes, the repaired A row delta equals the counted `7 nb_f + 3 nb_d + nb_d + nb_f + 1` paired sites plus one per single-row table mask; H gains exactly one row; the public W plane is unchanged |

**`cargo test --release -- --test-threads=2 --nocapture`: exit 0 — 28 test
binaries, 265 passed (259 + the 6 new), 0 failed, plus 5 doctests.**

**Byte gates on the CHANGED tree, 12 of 12 GREEN — NO DIGEST MOVED**
(same runner, same frozen digests and lengths as stage 1; the card read
0 MiB / 0 apps before each of the eight GPU launches):

| gate | cpu | gpu | gpu `HL_ZK_CHUNK=1` | gpu `HL_GPU_CHUNK_BYTES=1e8` |
|---|---|---|---|---|
| v2 `50cf7bdf..` 66,844,928 B | GREEN | GREEN | — | — |
| v3 `5f368db6..` 70,758,084 B | GREEN | GREEN | — | — |
| zk `021485e4..` 87,228,528 B | GREEN | GREEN | GREEN | GREEN |
| zk-v3 `40eb5479..` 87,697,008 B | GREEN | GREEN | GREEN | GREEN |

**The counted row deltas the layout test harvests** (`--nocapture`;
`inv_rate 4`, function 1, P1 — pure layout arithmetic, nothing proven at
these widths here) [COUNTED]:

| shape | A legacy -> repaired | H | W (P1) | M |
|---|---|---|---|---|
| T2 / d16 / f16, log_cols 5 | 5,173 -> 5,187 (+14, +0.271%) | 10,321 -> 10,322 | 24, unchanged | 16 -> 16 |
| **T512 / d768 / f2048 (125M), log_cols 14** | **559 -> 585 (+26, +4.651%)** | 485 -> 486 | 288, unchanged | 16 -> 16 |
| **T512 / d4096 / f14336 (Mistral), log_cols 14** | **3,599 -> 3,665 (+66, +1.834%)** | 3,029 -> 3,030 | 10,752, unchanged | 16 -> 16 |

**Two corrections to `ZK60_PRIVATE_FFN_COST_PROBE.md` fall straight out of
this table**, and they matter for how the measurement is read:

1. The memo's Mistral row is **+70 rows / +1.94%**; that figure includes
   the FOUR endpoint mask pair rows of the `io` profile
   (`ZkLayoutV3::with_io` adds `4 * a_n` on top of `with_masks`). The
   repaired MASK schedule alone — which is what this lane can run — adds
   **+66 rows / +1.834%**. The memo's legacy A count, 3,599, reproduces
   exactly. [COUNTED]
2. The memo predicts `mask commit` **grows, 6 -> 8 CFS slots**. That is
   also `io`-only: `mask_specs_v3` adds the two extra slots under
   `zl.a_io.is_some()`, and under `mr1` alone the specification is
   unchanged, so **M stays at 16 rows in every arm** (2 per mask + 4).
   Any `mask commit` movement in the measurement below is therefore noise,
   not the repair. [COUNTED]

**And the relative cost of the repair is LARGER at 125M than at Mistral,
not smaller** — +4.65% of A's rows against +1.83% — because the mask rows
depend only on `nb_d` / `nb_f` while the data rows scale with the width.
The memo makes this point about T; it applies to the width as well. The
12 x 512 measurement below is therefore an UPPER bound on the repair's
row-proportional cost at Mistral width, by a factor of about 2.5.

### 2026-09-19 — stage 3, the driver

`hashline/examples/zk60_repaired_mask_probe.rs` (new file; `src/main.rs` is
NOT touched and examples are auto-discovered, so `Cargo.toml` is untouched
too).

```
zk60_repaired_mask_probe <layers> <tokens> <public|legacy|repaired|all> \
    [--export DIR] [--threads N] [--log-cols N] [--inv-rate N] [--col-checks N]
```

It loads the witness exactly as `hashline pass --profile v3` does — the
same library calls, `export_dir_v3` / `V3Sidecar::load` / `load_layer_v3` /
`derive_v3`, with the same `compare_planes` element-wise check and the same
`range_ok` assertion — and defaults to the CLI's `log_cols 14, inv_rate 4,
col-checks 256`. The device is controlled exactly as the CLI controls it
(`HL_GPU`, read by `hashline::gpu`), and the header prints `gpu: ON` or
`gpu: OFF` beside `gpu::label()`.

Each arm PROVES and then VERIFIES every layer, and prints the prover's own
phase breakdown summed over the layers, the device counters when the GPU is
on, prove and verify seconds, proof bytes, the committed rows of A, H, W and
M, and peak resident memory — plus one `PROBE_JSON` line per arm for the
analysis. The header states, in the output itself, that this establishes no
privacy property and that all three arms have public endpoints.

Both private arms draw fresh OS randomness (no seed), so the ONLY difference
between them is the mask schedule. One arm per process is the measurement
form; `all` in one process is a convenience and says so, because `peak RSS`
is a process high-water mark and the device counters accumulate.

**The first execution of the repaired mask schedule above the tiny shape**
(smoke test, 1 layer x 128 tokens, CPU, 125M export): all three arms ACCEPT.
**No refusal fired** — not `check_masks`, not `check_opening_challenges`,
not `check_table_point`, not `draw_mask_challenge`. The memo's open
question 2 ("whether `mr1 = true` actually runs at a shape other than the
tiny one — nobody has tried") is now answered: **it does.** Committed rows
at that shape, legacy -> repaired: A 169 -> 195 (+26, as counted), H
161 -> 162, W 288 unchanged, M 16 unchanged. [MEASURED]

### 2026-09-19 — stage 4, the first measurement at 12 x 512

**Method.** `zk60_repaired_mask_probe 12 512 <arm> --export
/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export --threads 2`,
`RAYON_NUM_THREADS=2`. **One arm per process**, so each arm's peak resident
memory and device counters are its own. 5 repeats x 3 arms per binary, and
the ORDER IS ROTATED across the five repeats —

| repeat | order |
|---|---|
| 1 | public, legacy, repaired |
| 2 | repaired, legacy, public |
| 3 | legacy, repaired, public |
| 4 | public, repaired, legacy |
| 5 | repaired, public, legacy |

— because lane `fsp-zkhost` measured a 4-5% order effect on this box
(whichever arm runs second is slower). Each arm therefore occupies each
position at least once and the effect averages out instead of being
charged to one arm.

Every run records `uptime` and `nvidia-smi` before and after, in its own
log under `results/fsp5_probe_12x512/`. The GPU runs are sequential by
construction: the controller starts one child at a time and waits for it to
exit; each child takes `/tmp/zk-heavy.lock` for itself and polls
`nvidia-smi` WHILE HOLDING that lock until the card reads <= 1,024 MiB with
no compute apps. Exactly one GPU process exists at any moment.

**Box conditions, stated once because they bound every second below.** This
was NOT a quiesced box: two other worktrees (`wt-fsp-host`'s A/B planes
battery and `wt-zk60-normrange`'s test lane) were running throughout, the
1-minute load average sat between 4.5 and 7.5 on a box this lane was using
2 threads of, and the CPU and GPU probe ladders ran concurrently with each
other. Every second below is therefore **[MEASURED, NOISY-SHARED]** and the
run-to-run spread is wide. The BYTES and the ROWS are exact and are not
affected by any of this.

**30 runs, 15 per binary, every one ACCEPT.** Raw per-run logs, the
per-run `PROBE_JSON` lines and the full ratio table are under
`results/fsp5_probe_12x512/` (`probe-<label>-<arm>-<i>.log`,
`fsp5_probe_<label>.jsonl`, `fsp5_analysis.txt`).

#### What is exact, and identical on both binaries [MEASURED, exact]

| | public | legacy | repaired | rep/leg | rep/pub |
|---|---:|---:|---:|---:|---:|
| proof bytes (12 layers) | 70,758,084 | 87,697,008 | **88,356,464** | **1.0075** | 1.2487 |
| A rows | 520 | 559 | **585** | **1.0465** | 1.1250 |
| H rows | 432 | 485 | **486** | **1.0021** | 1.1250 |
| W rows | 288 | 288 | 288 | 1.0000 | 1.0000 |
| M rows | — | 16 | 16 | 1.0000 | — |

Every one of the 30 runs produced exactly these bytes and rows. **The
repaired mask schedule costs +659,456 proof bytes over 12 layers —
54,955 B per layer, +0.75%.** That is the 26 extra A rows read at each of
the 256 opened columns (256 x 26 x 8 = 53,248 B) plus the extra group- and
proximity-vector entries. [COUNTED, and it matches the measurement to
1,707 B per layer.]

#### The GPU binary — the clean measurement [MEASURED, NOISY-SHARED but tight]

`HL_GPU=1`, RTX 4070 Laptop 8,188 MiB, card verified idle (0 MiB, 0 compute
apps) before every run. The device does the commitment arithmetic, so the
prove clock is short and the spreads are ~2%: the three arms' prove ranges
do NOT overlap, which is what makes this the arm to quote.

| phase (summed over 12 layers) | public | legacy | repaired | rep/leg | rep/pub | leg/pub |
|---|---:|---:|---:|---:|---:|---:|
| commit W | 0.431 | 0.636 | 0.677 | 1.064 | 1.571 | 1.476 |
| **commit A** | 0.604 | 1.140 | **1.278** | **1.121** | 2.116 | 1.887 |
| mask commit | — | 0.036 | 0.038 | 1.048 | — | — |
| helpers + commit H | 0.374 | 1.302 | 1.311 | 1.007 | 3.505 | 3.482 |
| matmul g/u | 0.157 | 0.115 | 0.123 | 1.070 | 0.788 | 0.736 |
| matmul d | 0.101 | 0.092 | 0.097 | 1.057 | 0.958 | 0.906 |
| zero-check F | 0.336 | 0.456 | 0.446 | 0.980 | 1.327 | 1.354 |
| zero-check D | 0.084 | 0.090 | 0.101 | 1.126 | 1.201 | 1.066 |
| table zero-check | — | 0.149 | 0.181 | 1.213 | — | — |
| zsum + mask open | — | 0.032 | 0.034 | 1.048 | — | — |
| pcs openings | 0.180 | 0.339 | 0.361 | 1.064 | 2.001 | 1.881 |
| **PROVE** | **2.269** [2.079-2.758] | **4.389** [4.225-4.547] | **4.649** [4.561-4.771] | **1.0592** | **2.0492** | **1.9345** |
| VERIFY | 0.393 | 0.545 | 0.573 | 1.052 | 1.460 | 1.388 |
| peak VRAM | **2,430 MB** | **3,068 MB** | **3,101 MB** | 1.011 | 1.276 | 1.263 |
| peak host RSS | 548 MB | 637 MB | 644 MB | 1.011 | 1.175 | 1.163 |

**The repaired mask schedule costs +5.92% of prove at 12 x 512 on the
GPU binary** (+0.260 s on 4.389 s), and the phase attribution CLOSES:
summing the eleven per-phase deltas gives +0.260 s against a measured
PROVE delta of +0.260 s. **53% of it is `commit A`** (+0.138 s) — the
encode, the Merkle leaves and, on the host, the generation of 26 x 16,384
fresh field elements per layer for the added mask rows. The rest is
`commit W` +0.041 (W's rows are UNCHANGED, so this is the measurement's
noise), `table zero-check` +0.032, `pcs openings` +0.022 and eight smaller
terms.

**Two cross-checks that the arms are the right ones.** The peak VRAM of
the public and legacy arms, 2,430 MB and 3,068 MB, reproduce the recorded
125M figures (`ZK60_CLAUDE_PROFILE.md:25-29`, P0 2,430 / P1 3,068)
**exactly**. And every arm's proof digest-length matches the frozen gates.

#### The CPU binary — the same shape, and why it says less [MEASURED, NOISY-SHARED]

| | public | legacy | repaired | rep/leg | rep/pub | leg/pub |
|---|---:|---:|---:|---:|---:|---:|
| **PROVE** | **37.116** [34.5-43.2] | **41.266** [36.5-46.2] | **40.927** [37.9-46.0] | **0.9918** | **1.1027** | **1.1118** |
| VERIFY | 0.409 | 0.673 | 0.629 | 0.935 | 1.539 | 1.647 |
| commit A | 9.176 | 10.687 | 11.033 | 1.032 | 1.203 | 1.165 |
| commit W | 5.280 | 5.534 | 5.230 | 0.945 | 0.990 | 1.048 |
| helpers + commit H | 10.892 | 12.317 | 12.016 | 0.976 | 1.103 | 1.131 |
| zero-check F | 7.818 | 8.248 | 8.061 | 0.977 | 1.031 | 1.055 |
| pcs openings | 2.289 | 2.280 | 2.332 | 1.023 | 1.019 | 0.996 |
| peak host RSS | 1,167 MB | 1,257 MB | 1,274 MB | 1.014 | 1.092 | 1.077 |

**On the CPU binary the repair is BELOW the noise floor.** The
repaired/legacy prove ratio is 0.9918 — the repaired arm measured
*faster*, which is impossible and is the point: the per-arm ranges span
[36.5-46.2] and [37.9-46.0], a +/-12% band on a box carrying two other
worktrees' batteries at load average 4.5-7.5. `commit W`, whose rows are
identical in all three arms, reads 0.945 and 1.048 in the two directions,
which is the honest calibration of that noise. **The CPU rows and bytes
are exact and agree with the GPU binary's; the CPU seconds bound the
repair at "under about 10%" and nothing sharper.** The GPU binary's
+5.92% is the number to quote.

#### Against the scoping memo's counted prediction

| | memo | here |
|---|---|---|
| legacy A rows, one Mistral layer, T 512 | 3,599 | **3,599** — reproduced exactly |
| repaired A rows, same | 3,669 (+70, +1.94%) | **3,665 (+66, +1.834%)**; the memo's extra 4 are the `io` endpoint mask pairs, which this profile does not have |
| H | +1 row | **+1 row** |
| W under P1 | unchanged | **unchanged** |
| `mask commit` / M | "grows, 6 -> 8 CFS slots" | **unchanged, 16 rows** — the two extra slots are `io`-only (`mask_specs_v3` adds them under `zl.a_io.is_some()`); measured `mask commit` moves 1.048 on the GPU, which is noise |
| "structurally the legacy private profile plus a few per cent, not 3x and not 30x" | prediction | **confirmed: +5.92% of prove, +0.75% of bytes, +1.1% of VRAM at 12 x 512** |
| `pcs openings` "the largest relative growth" | prediction | **wrong here: `commit A` is, at +12.1%; openings grew 6.4%** |
| does `mr1` even run above the tiny shape? (memo, could-not-determine 2) | unknown | **yes — 30 runs at 12 x 512 plus the smoke test, zero refusals** |

#### COUNTED: what this is worth at one Mistral-width layer and at 32 layers

**NOTHING AT MISTRAL WIDTH WAS RUN BY THIS LANE, on either processor, by
instruction.** Everything in this subsection is [COUNTED] from the rows
above and from figures already measured elsewhere in the repository.

The added cost is the added MASK ROWS: their host generation (fresh field
elements), their encoding, their Merkle leaves and their entries in each
opened column. Rows are `a_n = 2^log_cols = 16,384` wide at both shapes,
so the added work scales as the added row COUNT:

```
125M   12 x 512:  +26 A rows/layer   (559 -> 585)
Mistral   1 x 512: +66 A rows/layer  (3,599 -> 3,665)
scale factor = 66 / 26 = 2.538
```

**Prove time.** Measured GPU delta 0.260 s over 12 layers = **0.0217 s per
125M layer**; scaled, **0.0551 s per Mistral-width layer** [COUNTED].
Against the recorded legacy P1 one-Mistral-layer GPU clock of **3.453 s**
[MEASURED, `ZK60_CLAUDE_GPU.md:262-265`]:

```
one Mistral layer : 3.453 + 0.055 = 3.508 s     -> +1.60%
32 layers          : 32 x 3.508 = 112.3 s vs 110.5 s  -> +1.76 s, +1.60%
```

The 32-layer figure carries the memo's own caveat (§4.3): 32 x a measured
one-layer clock is only valid **on a card that does not page**; the
recorded 32-layer legacy GPU pass was 265.34 s because it spilled to
8,585 MB on an 8,188 MiB card, and against that number the same +1.76 s
would read +0.66%. Quote the 110.5 s base, not the 265.34 s one.

**Proof bytes.** 256 opened columns x 66 extra rows x 8 B = **135,168 B per
Mistral layer**, on the measured 40,186,228 B legacy private Mistral layer
proof [MEASURED, `ZK60_CLAUDE_GPU.md:262-265`] -> **+0.34%**; over 32
layers, +4.33 MB. [COUNTED]

**Video memory.** Measured +33 MB at 125M for 26 added rows; scaled by
2.538, **about +84 MB at one Mistral layer**, on the recorded 5,282 MB
legacy one-layer anchor -> **~5,366 MB**, still 2.8 GB inside the card.
[COUNTED]

**In one sentence, and it is the lane's headline: fixing the mask leak
costs about six per cent of the prove clock at 125M and, counted, about
one and a half per cent at Mistral width — the relative cost SHRINKS with
width, because the mask rows depend on `nb_d`/`nb_f` and the data rows do
not.** It was never plausibly the thing standing between this project and
five seconds, and now that is measured rather than assumed.

**None of this is a privacy claim.** The endpoints were public in all
three arms. What has been measured is the cost of the repaired MASK
SCHEDULE; the hiding-endpoint half is untouched, still pinned to
T32/d16/f16, and still unmeasured above that shape.

### 2026-09-19 — state at hand-off, and the exact next step

All four stages are DONE and the branch is green: `cargo test --release`
265 passed / 0 failed / 5 doctests, and 12 of 12 byte gates on the changed
tree with **no digest moved at any point in this lane**.

Three commits on `fsp-mr1`:

| commit | what |
|---|---|
| `2c0c70a` rung 0 | the ledger, the ownership, the memo's line numbers re-verified |
| `e0edca5` rung 0b | the inherited doctest, fixed as a comment |
| `9c45f1c` **rung 1** | the entry pair in `zk.rs` + the new `cfg(test)` file |
| `72b00f0` **rung 2** | the driver example |
| rung 3 (this commit) | the 12 x 512 measurement, its raw logs and the counted extrapolation |

**THE EXACT NEXT STEP, in order.**

1. **The integrator reconciles `fsp-mr1` with `fsp-zkhost`'s new tip
   `e45ebda`.** Both branches carry a comment-only fix to the same
   `fsp_i8fold` doc comment; expect exactly one trivial conflict there.
   This lane did not merge, rebase or cherry-pick.
2. **The bounded runner / CPU ladder is Codex's**, per the standing
   instruction. The driver it needs already exists and takes the shape on
   the command line; nothing further is required from this lane for it.
3. **A quiesced repeat of the CPU arm.** The CPU seconds here are
   worthless beyond "under about 10%" because two other worktrees were
   running. The same 15 runs on a quiet box would settle whether the CPU
   binary also shows ~+6% or whether the repair is genuinely free there
   (it plausibly is: the CPU arm's `commit A` is dominated by arithmetic
   the added rows do not change).
4. **Still owed and NOT run here, by instruction:** anything at Mistral
   width on either processor, and any model-width GPU run. The §COUNTED
   numbers above are the substitute, and they are labelled.
5. **The hiding-endpoint (`io`) half remains unmeasured above T32/d16/f16
   and unbuilt above it.** It is the other half of "the repaired private
   feed-forward" and the one with eleven shape pins
   (`ZK60_PRIVATE_FFN_COST_PROBE.md` §2.2 A). Nothing in this lane touched
   it, unpinned it, or says anything about what it costs.

### 2026-09-19 — stage 4b, the CPU ladder repeated on a QUIET box

The box went quiet at 13:25 (the two other worktrees' batteries finished;
1-minute load average 0.16). The CPU ladder was immediately repeated —
same 15 runs, same rotation, this time holding `/tmp/zk-heavy.lock` for the
whole ladder so nothing else could start beside it. Load average during
the runs: **0.12 to 1.96** (against 4.5-7.5 for stage 4). Raw logs under
`results/fsp5_probe_12x512_quiet/`. Every run ACCEPT; bytes and rows
identical to stage 4 to the byte.

| CPU binary, quiet | public | legacy | repaired | rep/leg | rep/pub | leg/pub |
|---|---:|---:|---:|---:|---:|---:|
| **PROVE** | **32.259** [32.06-32.58] | **35.369** [34.11-37.25] | **35.417** [34.13-36.23] | **1.0013** | **1.0979** | **1.0964** |
| VERIFY | 0.340 | 0.493 | 0.538 | 1.090 | 1.583 | 1.452 |
| commit W (control: identical rows in all three arms) | 4.612 | 4.679 | 4.575 | **0.978** | 0.992 | 1.015 |
| commit A | 8.167 | 9.278 | 9.637 | **1.039** | 1.180 | 1.136 |
| helpers + commit H | 9.671 | 10.912 | 10.769 | 0.987 | 1.114 | 1.128 |
| zero-check F | 6.683 | 6.934 | 6.865 | 0.990 | 1.027 | 1.038 |
| pcs openings | 1.763 | 1.740 | 1.741 | 1.001 | 0.987 | 0.987 |
| mask commit | — | 0.033 | 0.032 | 0.959 | — | — |
| table zero-check | — | 0.458 | 0.468 | 1.023 | — | — |
| peak host RSS | 1,165 MB | 1,252 MB | 1,270 MB | 1.014 | 1.090 | 1.077 |

**On the CPU binary the repaired mask schedule is FREE within the
measurement: repaired / legacy prove = 1.0013, against a control phase
(`commit W`, whose rows are identical in all three arms) reading 0.978 —
so the noise floor is about +/-2% and the repair is inside it.** The one
phase that does move is `commit A`, +3.9%, which is where the 26 added
mask rows are generated, encoded and hashed; the CPU's `commit A` is
dominated by arithmetic the extra rows barely touch, so 4% of that phase
is 1% of the prove and the other phases absorb it.

**The two binaries disagree, and the reason is structural, not a
contradiction.** On the GPU binary the device does the commitment
arithmetic, so the host's mask-row generation and the extra encode are a
much larger SHARE of a much shorter clock: the same +0.26 s absolute lands
on a 4.39 s prove instead of a 35.37 s one. This is the same structural
effect lane `fsp-zkhost` recorded for its staging pool ("on the GPU binary
the POOL is measurable even at 12 x 512, unlike on the CPU binary").

**So the honest headline is a pair, not a number:**

* **GPU binary, 12 x 512: +5.92% of prove [MEASURED], ranges disjoint.**
* **CPU binary, 12 x 512: +0.1%, i.e. free inside a +/-2% floor
  [MEASURED, quiet box].**
* Bytes +0.75% and rows +4.65% of A, exact and binary-independent.
* VRAM +33 MB, 3,068 -> 3,101 MB, exact and repeatable across 5 runs.

The COUNTED Mistral extrapolation above is built on the GPU delta, which
is the larger of the two, so it is the conservative direction.
