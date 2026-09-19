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
| 4 | The first measurement at 12 x 512, CPU and GPU binaries, >= 5 repeats/arm, alternating order | IN FLIGHT |

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
