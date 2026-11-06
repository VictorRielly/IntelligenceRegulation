# A18: the forks' host work after A16 and A17, and A13 re-tested on the fork-bound stream (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A18. Byte-preserving. It follows A17
(`../a17/README.md`, §6 "What is left") and A16 (`../a16/README.md`) on perf `a4ce8763`, where the 4-request stream
is fork-bound (about 2.6 s of sealing beside the forks against about 3.9 s of fork work per request).

Labels: [MEASURED] a number from a log in this directory; [CODE] read from the source; [INFERRED] derived from measured
numbers; [ESTIMATE] a judgement, not a measurement.

All runs: W16R2 8B T128, 32 blocks, the D55 fork run at N = 6 (A11's per-fork pools of 6), `HL_GPU=1 HL_PB_ORACLE=0
HL_METAL_TIMING=0`, on the shared M3 Ultra, every stage one guarded job (class gpu, the shared heavy lock). Every timing
stage waited for a quiet GPU (no `ds4-bench`) and recorded that none ran at its end; no clock below was taken beside
one. The timing fixture's public weights are synthetic and diagonal at the 8B geometry.

## Plain summary

- **A13's window pays now, on the fork-bound stream, but stays OFF by default** (`HL_D55_AHEAD`; §4.3, §4.5)
  [MEASURED, 6 passes, both orders, the GPU quiet]:
  - window 16 (2 side workers of 6 threads), a clean 2-arm A/B: **the 4-request stream +5.0% steady** (32.11 → 33.70
    tok/s, 6 of 6 pairs; +5.8% and +4.1% in the two orders), **one request from its input −2.3%** (5 of 6), amortized
    +0.8%;
  - everything on (the A18 forms and window 16) against the code before A18: **the stream +3.5% steady** (32.48 →
    33.63 tok/s, 6 of 6), one request −1.9%, amortized −0.1%;
  - the mechanism [INFERRED]: a request's forks phase falls about 7% (its first 16 forks start from parts parked during
    the sealing pass) while its sealing pass rises 7–9%, inside the slack the sealing side now has beside the previous
    request's forks; on A13's sealing-bound stream the same move slowed the bottleneck;
  - window 8 +2.5%, window 16 at utility QoS +4.2%, window 32 +0.5% with the amortized rate −5.7%; the stream's peak
    footprint 74.5 → about 86 GiB at window 16 (80 at 8, 130 at 32);
  - **off by default because no production entry point can use it yet:** `stack-prove`'s D55 path builds its
    statement, `ForkRun` and fork blocks only after the whole sealing pass (§6 lists the port). With it off nothing is
    parked and no byte, path or wording of the fork run changes.
- **The forks' host work in this lane's files: two small forms on, two measured and removed** (§4.2, §4.5):
  - `HL_A18_TABINV` (on): the range table helpers read the families' inverse tables already made for the looked
    columns' helpers instead of inverting the same denominators again; the byte and exp table helpers invert their 256
    distinct entries. Phase clock: "the three table helpers" **4.65 → 0.78 ms per block**;
  - `HL_A18_REGISTRY` (on): the preflight's record (A17's `CheckedPublic`) stands in for `define`'s per-slot
    `check_for_registry` (23 per block, about 3 ms), only for that very block's accuracy data at an equal shape,
    fail-closed;
  - together, against the code before A18: **one request −2.0% (6 of 6 pairs)**, proof only +0.2%, the stream steady
    −0.6%, within the ±2% noise floor of these A/Bs on every clock but one request (whose sealing pass, untouched,
    also moved −2.8%). They are kept on because they only remove work, add no parallel region and move no byte; `0`
    turns either off;
  - **measured and removed:** the range tables and the activation table helper in parallel chunks (`TABPAR`: +3.2% and
    +1.6% slower, sys CPU +6%) and `define`'s public tables in parallel maps (`PUBTAB`: +1.2%, +1.4%, sys CPU +4–7%).
    In the forks phase six 6-thread pools oversubscribe 32 cores, and a short parallel region's wake and spin costs
    the other forks more than the few ms of serial work it saves (A15's lesson, from the forks' side) [INFERRED];
  - A11's per-fork pool width re-swept: 6 stays (`fp4` −2.1% on the stream, `fp5` −0.5%).
- **No byte moves** (§3): the W16R2 rung golden `96e4f0b6` under every setting on the CPU and on Metal, through
  `prove_core`, `prove_core_with` beside the record and the core split across threads; the R13 rung's digest; one 8B
  T128 block's core proof `90003b760eb7ad80` in all 25 proofs of the final tree; A13's parked forks equal whole forks
  byte for byte on every path (CPU and Metal); every D55 receipt of every A/B 818,728,672 B (D12a 818,728,480 B).
  Refusals are the old strings under the old conditions, challenge-only (D66).
- **Acceptance on the final tree** (§5): build, no-feature check, the full suite 939 passed / exactly the known 3 /
  113 ignored, zkp-core 81, every earlier lane's byte test, the rung golden (CPU = Metal) and the six post-F12
  digests. D55 default (window off): proof only 33.30 tok/s best, one request 23.47 tok/s best (5.454 s), the stream
  33.38 steady / 29.44 amortized.
- **The stream is still fork-bound** with the window off (about 2.6 s of sealing beside the forks against about 3.6 s
  of forks per request). The window is the measured lever; its production port is the next item (§6).

## 1. The profile, before (stage 1) [MEASURED]

**Method** (`s1.sh`): A17's (A14's `rank.py` / `rank_detail.py`, A17's `leaf_detail.py`, A11's sampler window of 3
proof-only fork calls under `/usr/bin/sample` at 2 ms) on the base tree, the GPU quiet. The raw call graph stays in
`raw/` (not committed).

- Each fork's main line waits on the GPU 54.5% of its samples; its host time is **1.113 s per fork per call** (A17's
  profile after: 1.141 s). The GPU is busy 75–79% of the forks phase (`s1_d55_phases.log`).
- The ranking (`s1_rank.md`; per bucket `s1_rank_detail.txt`, `s1_leaf_detail.txt`), main line per fork per call:

| bucket | whose file | % of non-GPU | s | pool CPU-s per call |
|---|---|---:|---:|---:|
| the openings' store fold (A8's) | `gpu/metal.rs` | 14.8% | 0.164 | 5.07 |
| A/H zero-fill and free | `protocol.rs` | 13.1% | 0.146 | 0.08 |
| LogUp helper inverses | `protocol.rs` | 10.9% | 0.121 | 2.65 |
| public weight folds and public tables (`define`) | `mle.rs` (zkp-core) folds; `argument.rs`, `pad.rs` tables | 10.9% | 0.121 | 1.97 |
| randomness | zkp-core `rng.rs` | 9.5% | 0.106 | 2.59 |
| commit host parts | `pcs.rs`, `metal.rs` | 7.3% | 0.081 | 1.64 |
| lookups (the W16 histograms) | `protocol.rs` | 6.2% | 0.069 | 1.82 |
| witness planes into `A` | `protocol.rs` | 4.0% | 0.044 | 1.30 |
| per-block public checks (`define`'s registry re-check) | `argument_accuracy.rs` call | 1.5% | 0.017 | 2.15 |

**What the buckets in this lane's files hold** (`s1_leaf_detail.txt`):
- **The LogUp helper inverses** (0.121 s): the looked columns' helper writes (0.037 s, the main line's share of a
  parallel region), the main line's sequential batch inversions (0.054 s: the range sub-planes' and the three tables'
  table helpers, 2^14 entries each, and the main line's share of the exp / activation helpers' chunks) and
  `range16::denominator_inverses` (0.010 s, the range families' 2^w-entry tables, sequential).
- **`define`'s public tables** (main line, outside zkp-core's folds): `B::supp` (the support indicators) 0.0127 s,
  `pad::closed_form_indicator` 0.0118 s (`pad.rs`, not this lane's), `rope_tables_at` 0.0078 s, `causal_mask_at`
  0.0043 s: sequential loops with a division per entry. The folds themselves are zkp-core's `fold_cols_i8` (1.44
  CPU-s per call in the pools), not this lane's.
- **The per-block checks** (0.017 s): all of it `define`'s per-slot `check_for_registry`, which rebuilds the registry's
  public tables (`silu_table`'s `exp`, `group_folds_for`, `derive_aligned_for`) for every one of the 23 slots.
- **The A/H zero-fill** (0.146 s): `from_elem` 0.075 s, `__bzero` 0.031 s, `vm_deallocate` 0.021 s, all in
  `prove_core_with` (the 328 + 341 MB of `A` and `H` per block).
- **The phase clock** (`s1_d55_phases.log`, ms per block summed over the forks): `A` allocate + planes 24–25, lookups
  15, mask rows 11, `A`'s commit 60, `M` 4 (the before-challenge part: about 117 ms per block); `H`'s helpers 27–28,
  exp + activation 12–13, the three table helpers 4.7, `H`'s commit 41; all phases 602 ms per block.

## 2. What changed

Every form sits behind a switch; `0` restores the code before A18, `1` turns the form on, unset is the default. The
harness's arm words are in `run_fork_tests.rs`'s `[A18]` block (joinable with every other word).

### 2.1 A13's split and window, ported onto A14–A17 (`protocol.rs`, `run_fork.rs`; the window off by default)

A13's code (branch commits `8158de49`, `35573146`) was taken onto the base with `git merge-tree` and its three
conflicts resolved by hand; then adapted to A17:
- **`protocol.rs`.** `prove_core_with` is now `prove_core_before_with` then `prove_core_after_with`, with a
  `CoreAhead` state between them (A13's `prove_core_before` / `_after`, with A17's views and record):
  - the before-part is the old body up to `M`'s commitment: the CS-8 / CS-1 / CS-4 checks (A17's record skips CS-1 /
    CS-4 only for the very block object it checked), `A`'s rows, the looked columns (A17's `built` columns; the
    views are made again from the same witness and columns in the rest), the histograms and the CS-3 refusal, `A`'s
    mask rows, `A`'s and `M`'s commitments. It reads and absorbs no transcript;
  - the one reordering (A13's): `A`'s root is absorbed in the rest, right before `M`'s. `M`'s commitment reads no
    transcript, so the transcript sees the same absorbs in the same order and the generator the same draws;
  - **[A18] new:** the state records the shape (whole), the layout's rows, the block object's address and the A17
    view form; the rest refuses a state made for another shape or layout, or for another block object (an equal copy
    included), before anything is absorbed.
- **`run_fork.rs`.** A13's `ForkCtx` / `ForkLate` / `Parked` / `Slots` / side workers / `seal_ahead` /
  `prove_run_with_forks_ahead` / `prove_run_with_forks_sealing` and the test-only seeded generators, unchanged in
  substance, with:
  - `ForkLate` now also carries A17's preflight records (`checked`); a fork made during the sealing pass has none
    and checks its block itself (the preflight has not run yet; it runs after the sealing pass and checks every block
    again, as before);
  - a parked fork's rest asks the block source for its block again, and `prove_core_after_with` refuses it unless it
    is the very object the before-part was made from;
  - the switches are A13's: `HL_D55_AHEAD=<window>` (default **0, off**), `HL_D55_AHEAD_WORKERS` (2),
    `HL_D55_AHEAD_POOL` (6), `HL_D55_AHEAD_QOS` (0).
- **The harness** (`run_fork_tests.rs`): A13's arm words `noahead`, `ahead<W>`, `aw<k>`, `ap<t>`, `qos<q>` and a new
  `stsl` (every arm's stream statements made on its sealing thread, which a window needs; the harness before A18 made
  them on the prover thread). One request's form runs `prove_run_with_forks_sealing`, the stream's `seal_ahead` then
  `prove_run_with_forks_ahead`; their lines are A13's (`A13 SEALED`, with the forks parked and the footprint) and
  A15's (`A15 SEALED`, `A15 PIPE-SEAL`), so `a13/seal_pairs.py` and `a15/seal_pairs.py` read them; `A18 PIPE-MEM`
  prints a stream's footprint. A13's byte tests moved into `run_fork_tests.rs` (no new test file, so `s25_tests.rs`'s
  file list is untouched).
- Not ported: A13's harness-only sealing pool (`sp<t>`); A15's production `SealPool` and its arm words replace it.

### 2.2 `HL_A18_TABINV` (on): the table helpers from the inverse tables already made (`protocol.rs`)

- **The range table helpers** (W16): each range sub-plane's table helper `m / (alpha - (v + g))` used to build its
  2^14-entry table column and batch-invert it, sequentially on the fork's main line, though the family's inverse table
  (`range16::denominator_inverses`, made a few lines earlier for the looked columns' helpers) already holds every
  `1 / (alpha - (v + g))`. `range_table_helper` reads it: entry `i` of sub-plane `s` is `range16::value(f, s, i)`,
  whose denominator is the table's entry (the same expression, the same `g = range16::g_range(g_u8, width)`).
- **The byte and exp table helpers**: their tables are periodic (entry `i` is entry `i % 256`,
  `argument::table_values_*_at`) and their multiplicities fit one period, so `table_helper` inverts only the first 256
  entries (every distinct one; the periodicity is checked entry by entry before they stand for the rest). The
  accuracy profile's activation table is not periodic and is inverted whole, as before.
- It adds no parallel region. Refusals: where any entry's denominator is zero, the old code refused with
  `ZERO_DENOMINATOR` from `inverses`; so does the new one, at the same point (a family's table holds `None` exactly
  where the column's denominator is zero, and a periodic table's zero is among its first 256 entries).

### 2.3 Measured and removed: the range tables and the activation table helper in parallel chunks (`HL_A18_TABPAR`)

In stage 3 `TABINV` also made the families' inverse tables side by side, each in parallel chunks (entry for entry
`denominator_inverses`), and inverted the activation table helper in parallel chunks. It measured slower in both of
its A/Bs (§4) with sys CPU +6%, so stage 5 split it off as `HL_A18_TABPAR` and it is now removed; the code is kept as
a record in this lane's work-in-progress commit `805c7cb9` (and in `169879d9`, where it was part of `TABINV`).

### 2.4 `HL_A18_REGISTRY` (on): the preflight's record stands in for `define`'s registry re-check

(`argument.rs`, `argument_accuracy.rs`, `protocol.rs`.)
- `argument_accuracy::define_changed` ran `check_for_registry` for every one of the 23 slots of every block. It now
  skips it when `Points::registry_checked` is set, and only `argument::argument_with` sets it: when a D55 fork's
  preflight record covers THIS argument's accuracy data at THIS shape (`CheckedPublic::covers_accuracy`: the record's
  own block's accuracy data, the same object by `ptr::eq`, and an equal shape at an accuracy profile).
- The record's check (`check_for_shape` → `check_accuracy_for_shape`) ran `check_for_registry` with exactly the
  arguments `define_changed` passes (the shape's registry, geometry, base and stack), and the record borrows the block,
  so the data cannot have changed since. Every other caller (the verifier, D12a, the single block, the tests, a fork
  with no record or another block) checks as before, slot by slot.
- `prove_core_after_with` calls `argument_with` with the fork's record when `HL_A18_REGISTRY` is on; every other
  path calls `argument` (no record).

### 2.5 Measured and removed: `define`'s public tables in indexed parallel maps (`HL_A18_PUBTAB`)

`B::supp` (the support indicators), `causal_mask_at` and `rope_tables_at` built in indexed parallel maps (each
entry the same function of its index; tables of 2^15 entries or more). It measured slower in both of its A/Bs (+1.2%,
+1.4%; sys CPU +4% and +7%), so it is removed (`argument.rs` is the base's but for `REGISTRY`); the code is in the
work-in-progress commits `169879d9` and `805c7cb9`.

## 3. Why no byte can move, and the byte evidence

### 3.1 Why no byte can move

- **A13's split** (A13's argument, unchanged): every fork is the same calls on the same inputs in the same order;
  `prove_core_with` is its before-part then its rest, `A`'s root absorbed after `M`'s commitment, which reads no
  transcript. Each fork's ONE generator is built in `ForkCtx::prove_one` under its own per-`k` domain (the s25 census:
  two `from_os` sites in `run_fork.rs`, no `ZkRng::new`, no generator in `ForkCtx`), drawn from in the same order
  (`A`'s mask rows, `A`'s pads and salts, `M`'s masks, then everything after) and moved by value with its parked fork.
  Which thread or pool runs a part changes no word (A11). The window decides only WHEN a part runs.
- **The A17 forms inside the split**: the views are made again in the rest from the same witness and the same built
  columns (`looked_cols` borrows; it computes nothing), so every helper word is the one the whole core wrote; the
  record skips CS-1 / CS-4 only for the very object it checked, as in A17.
- **`TABINV`**: an inverse is unique, so a family table's `1 / (alpha - (v + g))` is the word the column's batch
  inversion made for the same denominator (the same field expression, the same `g`); a periodic table's first 256
  entries are every distinct entry, and its multiplicities are zero past them (the old column was `inv.zip(m)`, so
  its length was `m.len()`). The refusal is the same string under the same condition (some entry's denominator zero),
  and depends on the challenges and the public table only (D66).
- **`REGISTRY`**: `check_for_registry` reads public words and returns `Ok` or a refusal; it draws, absorbs and writes
  nothing. It is skipped only where the record's check ran it on the same object with the same arguments.
- **`TABPAR`, `PUBTAB`** (measured, then removed): indexed parallel maps and per-chunk batch inversions: each entry
  is the same function of its index (an inverse is unique), so the same vectors.
- **Timing (privacy)**: no new branch reads a hidden value. Which table a helper reads, whether a slot re-checks,
  whether a public table is built in parallel and when a before-challenge part runs are decided by the shape, the
  challenges, the public tables, the block's address and the window. The range table helpers' gathers are indexed by
  table positions (public), not by looked words.

### 3.2 The evidence [MEASURED]

Stage 2 (`s2.progress`, all passed) ran on the work-in-progress tree with all four forms (TABINV with its parallel
tables, REGISTRY, PUBTAB); the acceptance (§5, stage 4) reran every byte test on the final tree (TABINV, REGISTRY).

- **The W16R2 rung golden** `96e4f0b6` under every A18 setting, on the CPU and on Metal, through three entries:
  `prove_core`, `prove_core_with` beside the block's record, and the core SPLIT (its before-part on another thread in a
  rayon pool of 1, 2 or 6, the generator moved there and back) (`s2_a18rung.log`;
  `w16r2_tests::a18_w16r2_rung_golden_under_every_a18_setting`).
- **The rungs in the suite** (CPU, `a18_the_rung_digests_under_a18_forms_and_the_split_core`): the W16R2 rung
  (`96e4f0b6`) and the R13 rung (`ddd29ae0`, not W16), every form off and on, the three entries, split pools 1 and 6:
  one digest each. A before-challenge state continued with an equal copy of its block, or at another shape, is refused
  before anything is absorbed (the transcript's state unchanged).
- **The forms against the old code** (CPU, `a18_the_record_covers_only_its_own_data_and_the_table_forms_equal_the_old_code`):
  a record covers its own block's accuracy data at its shape, not a copy's data, not another shape, not `None`; (stage 2
  only) the parallel range tables equal `denominator_inverses` entry for entry at widths 1–16, with and without a zero
  denominator; the range table helpers equal the old column on every sub-plane of the rung's families, refusal for
  refusal; the table helper equals the old inversion on periodic and non-periodic tables (and a "periodic" table that
  is not), lengths 64–16384, with no zero, a zero in the first period and a zero in the last entry (at stage 2 also in
  parallel chunks).
- **One W16R2 8B T128 block** (Metal, `HL_PB_ORACLE=0`, `a18_the_8b_block_proves_the_same_under_every_a18_setting`;
  `s2_a18_8b.log`): the seeded core proof's digest `90003b760eb7ad80` (the post-F12 trained digest) through
  `prove_core` with every form off, then under each of the settings through the three entries, each twice: equal in
  all 31 at stage 2 (five settings) and all 25 on the final tree (four settings, §5).
- **A13's parked forks against whole forks** (`run_fork_tests::a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung`,
  CPU, in the suite; `..._on_the_device`, Metal, under `a18old` and `a18new`; `s2_a18_suite.log`,
  `s2_a18_bytes_metal.log`): with test-only seeded generators, on one statement, one commit phase and the preflight's
  records, every fork of an L = 4 W16R2 rung run proved whole equals the same fork parked (parts in pools of 1, 2, 6,
  finished in reverse order in pools of 1, 3, 2): the fork frame, the end state and the joined claims, byte for byte;
  and the three real paths (`prove_run_with_forks`, `prove_run_with_forks_sealing`, `seal_ahead` on another thread then
  `prove_run_with_forks_ahead`) at windows 1, 2, 4, 9, N = 1, 3 (CPU) and 1, 3, 6 (Metal), side workers (1, global),
  (2, 3), (3, 6): every receipt verifies (78 on the device), its head is the replayed commit phase's, the forks parked
  are the window's, each interior fork equals that fork recomputed the other way, every receipt 61,301,184 B.
- **The D55 fork-run suite** (26 tests: the honest runs, the tamper families, A17's turncoat) and the source audits
  (s24, s25, `hash_domain`: 45 tests) pass (`s2_fork_suite.log`, `s2_audits.log`).
- **Every receipt of every A/B call** verified at 818,728,672 B (stages 3, 5, 6).
- The final tree differs from stage 2's by the removal of TABPAR and PUBTAB (`argument.rs` back to the base but for
  REGISTRY); the acceptance reran every byte test on it.

## 4. The A/Bs, in-process, both arm orders [MEASURED]

N = 6. "Base first" / "test first" are the passes in which that arm ran first (`HL_D55_AB_ALTERNATE=1`); the
bias-solved column is their mean (the second arm of a pass runs about 4.5% faster, A7). (n pairs, n favouring the
test.) From `../a11/pairs.py ... --alternate --n 6`, `../a15/seal_pairs.py`, `../a13/seal_pairs.py`. Every fork
receipt 818,728,672 B; each arm's first proof-only and sealed receipt and every stream receipt verified.

**The noise floor.** In these 6-pair A/Bs a single form's proof-only wall moves ±1.5–2% between runs (REGISTRY alone
measured +0.3% in stage 3 and −1.4% in stage 5; TABINV alone +1.6% and, with REGISTRY, −2.6%). An effect smaller
than about 2% is not resolved by one A/B; the decisions below rest on repeated A/Bs and on the mechanism.

### 4.1 Stage 3 (a): the forms together, stage 3's form set (`s3a_pairs.md`, `s3a_seal.md`, `s3a_seal13.md`)

`a18old` against `a18new` = TABINV with the parallel tables (now TABINV + TABPAR) + REGISTRY + PUBTAB, 6 passes:

| metric | base first | test first | order bias solved out | means |
|---|---|---|---|---|
| proof only | −1.8% (3, 2) | +0.9% (3, 1) | −0.4% | 3.961 / 3.941 s |
| forks phase | −2.1% (3, 2) | +0.8% (3, 1) | −0.6% | 3.601 / 3.575 s |
| one request from its input | +1.7% (3, 1) | −1.1% (3, 3) | +0.3% | 5.457 / 5.472 s |
| the stream, steady | +1.0% (3, 2) | +0.2% (3, 2) | +0.6% | 32.57 / 32.76 tok/s |
| the stream, amortized | | | +0.2% | 28.94 / 28.99 tok/s |
| user / system CPU | | | +1.2% / +1.7% | |
| the stream's sealing passes beside the forks | +2.6% (3, 1) | +6.2% (3, 0) | +4.8% | 2.56 / 2.68 s |

Nothing moved beyond noise; the forks' extra parallel regions took CPU from the sealing pass beside them.

### 4.2 The forms one by one, proof only (stage 3 (b): 8 passes, five arms; stage 5: 2-arm A/Bs, 6 passes)

| against `a18old` | stage 3 (b), proof wall | stage 5, proof wall (pairs favouring) | stage 5, sys CPU |
|---|---:|---:|---:|
| TABINV + TABPAR (stage 3's `tabinv1`) | **+3.2%** (8 of 8 worse) | +1.6% (2 of 6) | +6.3% |
| TABINV (the gathers only) | — | +1.6% (1 of 6) | +0.7% |
| PUBTAB | +1.2% | +1.4% (2 of 6) | +7.3% |
| REGISTRY | +0.3% | **−1.4%** (4 of 6) | −5.3% |
| TABINV + REGISTRY (the default, `a18def`) | — | **−2.6%** (5 of 6) | −0.7% |
| all four (`a18new`, stage 3) | +1.6% | — | — |

**The phase clock** (stage 5, `s5_phase_table.md`, ms per block summed over the forks, 4 passes): TABINV's "the three
table helpers" falls **4.65 → 0.78 ms per block** (−3.9), exactly the inversions it removes; TABPAR adds about
+3.9 ms to `A`'s commit and +4.3 ms to `H`'s (the commits' host parts in the other forks lose CPU); REGISTRY's own
saving (about 3 ms per block, `check_for_registry` × 23) is inside the slots' rows, which move ±3 ms between arms.

**Why the parallel forms lose** [INFERRED]: in the forks phase six forks each run a 6-thread pool (36 threads; 44
beside a stream's 8-thread sealing pool) on 32 cores. A short parallel region wakes a fork's idle pool threads, which
then spin before sleeping (rayon), taking CPU from the other forks' commits; the measured sys CPU rises 6–7%. It is
A15's finding (the sealing pass's short parallel regions on a wide pool) seen from the forks' side: on this machine a
fork's serial step of a few ms is cheaper on its main line than in its pool.

### 4.3 A13's window on the new base (stage 3 (c), 3 arms; stage 6, a clean 2-arm A/B and two variants)

All arms with the A18 forms on and `stsl` (every stream statement on the sealing thread); 2 side workers of 6 threads
unless named.

**Stage 6 (a), the decision run** (`s6a_pairs.md`, `s6a_seal.md`, `s6a_seal13.md`): `a18def+noahead+stsl` against
`a18def+ahead16+stsl`, 6 passes:

| metric | base first | test first | order bias solved out | means, no window / window 16 |
|---|---|---|---|---|
| **the stream, steady** | **+5.8% (3, 3)** | **+4.1% (3, 3)** | **+5.0%** | 32.11 / 33.70 tok/s |
| the stream, amortized | +1.6% (3, 2) | +0.1% (3, 1) | +0.8% | 28.56 / 28.80 tok/s |
| **one request from its input** | −2.9% (3, 3) | −1.6% (3, 2) | **−2.3%** | 5.569 / 5.442 s |
| its prove call | −6.6% (3, 3) | −6.6% (3, 3) | −6.6% | 4.014 / 3.749 s |
| its forks phase | −7.8% (3, 3) | −7.6% (3, 3) | **−7.7%** | 3.631 / 3.352 s |
| its sealing pass | +6.7% (3, 0) | +11.3% (3, 0) | +9.0% | 1.555 / 1.693 s |
| its sealing CPU-s | | | +68.5% | 8.35 / 14.07 |
| the stream's sealing passes beside the forks | | | +2.8% | 2.73 / 2.81 s |
| proof only (the control; no sealing pass, no part) | +0.7% (3, 1) | +0.9% (3, 2) | +0.8% | 3.933 / 3.963 s |
| peak footprint, the stream | | | | 74.2–75.2 / 84.9–87.8 GiB |

**The other windows** (stage 3 (c) and stage 6 (b), against no window, order bias solved out):

| window | the stream, steady | amortized | one request | its sealing pass | its forks phase | peak footprint, stream |
|---|---:|---:|---:|---:|---:|---:|
| 8 (stage 6 b) | +2.5% (6 of 6) | +0.7% | −2.2% | +6.3% | −5.6% | 80 GiB |
| 16 (stage 3 c) | +2.5% (5 of 6) | −0.6% | −1.7% | +10.5% | — | 87–92 GiB |
| **16 (stage 6 a)** | **+5.0% (6 of 6)** | +0.8% | **−2.3%** | +9.0% | −7.7% | 85–88 GiB |
| 16 at utility QoS (stage 6 b) | +4.2% (6 of 6) | +0.1% | −1.5% | +13.1% | −8.1% | 84–87 GiB |
| 32 (stage 3 c) | +0.5% | **−5.7%** (0 of 6) | +0.6% | +24.9% | — | 126–133 GiB |

- **The kill rule is passed:** at N = 6, both orders, window 16 raises the stream's steady rate in every pair of the
  decision run (+5.0%), and by +2.5% in stage 3's 3-arm run.
- **Why it pays now and did not on 2026-11-05** [INFERRED]: the stream is fork-bound. Window 16 takes about 0.28 s off
  a request's forks phase (its first 16 forks start from parked parts) and adds about 0.14 s to its sealing pass, which
  has about 1.2 s of slack beside the previous request's forks. On the sealing-bound stream of A13's day the same move
  slowed the bottleneck.
- **Window 32 is too much:** its 32 parts lengthen the sealing pass by a quarter, the first request's latency rises
  (amortized −5.7%), and a stream holds up to two requests' parts at once (126–133 GiB).
- **It stays OFF by default** (`HL_D55_AHEAD` unset = 0): no production entry point uses it (§6), so a default would
  change only the harness's clocks; with it off nothing is parked and no byte, path or wording of the fork run changes.

### 4.4 A11's per-fork pool width re-swept (stage 5, `s5_pairs_pools_*.md`, `s5_seal_pools_*.md`)

`fpauto` (the default rule, `ceil(32 / 6) = 6` threads per fork) against `fp4` and `fp5`, 6 passes, three arms:

| against `fpauto` (6) | proof only | one request | the stream, steady | amortized | user / sys CPU | sealing beside the forks |
|---|---:|---:|---:|---:|---:|---:|
| `fp4` | +3.1% (0 of 6) | +2.1% (0 of 6) | **−2.1% (0 of 6)** | −2.2% | −6.5% / −21.6% | −10.5% |
| `fp5` | +1.3% | +1.5% | −0.5% | −0.8% | −3.6% / −4.1% | −3.5% |

Narrower pools cut the CPU and free the sealing pass beside the forks, but the forks themselves slow more; A11's rule
stays (no code change).

### 4.5 Stage 7: the final tree against the code before A18 (`s7a_*.md`, `s7b_*.md`, `s7*_d55_ab.log`)

**(a) The A18 default** (`a18def`: TABINV + REGISTRY; the window off) against `a18old`, 6 passes:

| metric | base first | test first | order bias solved out | means, before A18 / A18 |
|---|---|---|---|---|
| proof only | +1.5% (3, 0) | −1.0% (3, 2) | +0.2% | 3.973 / 3.981 s |
| **one request from its input** | −2.3% (3, 3) | −1.7% (3, 3) | **−2.0%** | 5.609 / 5.494 s |
| its forks phase | −2.1% (3, 3) | −2.0% (3, 2) | −2.1% | 3.661 / 3.585 s |
| its sealing pass (no A18 form acts here) | −4.9% (3, 3) | −0.6% (3, 3) | −2.8% | 1.572 / 1.528 s |
| the stream, steady | −0.3% (3, 1) | −0.9% (3, 1) | −0.6% | 32.98 / 32.78 tok/s |
| the stream, amortized | | | −0.6% | 28.99 / 28.80 tok/s |
| user / system CPU | | | +0.4% / −4.7% | |

The one request favours A18 in every pair, but its sealing pass, which no default form touches, moved −2.8% too: part of
it is noise. Across the four A/Bs that include both forms (§4.1, §4.2, here) their effect is within the noise floor,
between −2.6% and +0.2% on proof only.

**(b) Everything, with A13's window 16** (`a18def+ahead16+stsl`) against the code before A18 at the same statement
placement (`a18old+noahead+stsl`), 6 passes:

| metric | base first | test first | order bias solved out | means, before A18 / A18 with window 16 |
|---|---|---|---|---|
| **the stream, steady** | +4.1% (3, 3) | +3.0% (3, 3) | **+3.5%** | 32.48 / 33.63 tok/s |
| the stream, amortized | +0.6% (3, 1) | −0.9% (3, 1) | −0.1% | 28.52 / 28.48 tok/s |
| **one request from its input** | −1.3% (3, 2) | −2.4% (3, 2) | **−1.9%** | 5.679 / 5.571 s |
| its forks phase | −6.4% (3, 3) | −7.5% (3, 3) | −6.9% | 3.645 / 3.391 s |
| its sealing pass | +6.8% (3, 0) | +6.8% (3, 1) | +6.8% | 1.657 / 1.767 s |
| proof only (the window does not act) | −0.5% (3, 2) | −1.7% (3, 2) | −1.1% | 3.979 / 3.934 s |
| user / system CPU | | | −0.9% / −8.4% | |
| peak footprint, the stream | | | | 73.7–75.2 / 85.3–86.4 GiB |

This is the configuration a production port would give the stream; window 16's own +5.0% (§4.3, against the A18
forms at an equal placement) and this +3.5% (against the code before A18) agree within the noise floor.

## 5. Acceptance [MEASURED]

**Stage 4** (`s4.sh`, `s4.progress`, `s4_*.log`, `s4.guard.json`) is the final tree (perf `a4ce8763` + A18: A13's
split and window ported, the window off; `TABINV` and `REGISTRY` on), `check_a16merge.sh`'s whole list pointed at this
worktree plus A18's tests. One guarded job (02:53–03:11 UTC), the GPU quiet at the D55 clock:
- **build:** rc 0. **The no-feature `cargo check --tests`** (no `gpu-metal`): rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures; `s4_full.log`): **939 passed, 3 failed, 113
  ignored**. The three failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
  - 939 is A16's acceptance's 936 plus A18's three suite tests (`a18_the_rung_digests_under_a18_forms_and_the_split_core`,
    `a18_the_record_covers_only_its_own_data_and_the_table_forms_equal_the_old_code`,
    `a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung`); 113 ignored is 110 plus A18's three. The D55
    fork-run suite tests and the source audits (s24, s25, `hash_domain`, C-H4') pass.
- **zkp-core's lib tests:** 81 passed, 2 ignored.
- **A18's byte tests:** the W16R2 rung golden `96e4f0b6` under all four settings, CPU and Metal, through the three
  entries with split pools of 1, 2 and 6 (`s4_a18rung.log`); the 8B block's core proof `90003b760eb7ad80` in all 25
  proofs (`s4_a18_8b.log`); A13's parked forks equal whole forks on the device under `a18old` and `a18new`, every path
  (`s4_a18_bytes_metal.log`).
- **A16's 8B witness planes in every form, A17's rung golden and 8B block under every setting, A15's 8B chain in every
  pool, A14's 8B private tables, rung golden and 8B block, A8's rung test, A12's census and rung-mode tests, A11's pool
  tests (CPU and Metal), A7's queue test:** all pass.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the default** (`s4_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4`;
  the window off, so this is the production-equivalent form):

| W16R2 8B T128, 32 blocks, N = 6 | this run | A16's merged acceptance (`../a16merge_d55.log`), for reference |
|---|---:|---:|
| proof only, the two calls | 4.047, 3.844 s | best 3.796 s |
| proof only, best | 33.30 tok/s | 33.72 |
| one request from its input, the two calls | 5.502, 5.454 s (sealing passes 1.523, 1.467 s) | best 5.347 s |
| one request from its input, best | 5.454 s = 23.47 tok/s | 23.94 |
| stream of 4, steady / amortized | 33.38 / 29.44 tok/s | 33.02 / 29.09 |
| the stream's sealing passes | 1.49 s alone; 2.77, 2.30, 2.71 s beside the forks | — |
| serial D12a, best | 9.154 s = 13.98 tok/s | — |

- **Receipts:** every receipt the harness verifies verified (the D12a verifier, the D55 verifier on the first
  proof-only and sealed passes, all 4 stream receipts after the clock in 9.5 s). Fork receipts 818,728,672 B and D12a
  receipts 818,728,480 B, unchanged (and in every call of every A/B of stages 3, 5, 6 and 7).
- The A16 column is another process on another state of the box; the in-process A/Bs of §4 are the measurement.

## 6. What is left

- **A13 in production (the largest item left).** The window's gain is measured in the harness only. Production's D55
  path (`trained_block.rs`, `stack-prove --d55-workers`) runs `seal_and_record` to the end, then builds the bound
  statement (its endpoints come from the sealed chain's first and last planes), the `ForkRun`, and the fork blocks
  (`load_fork_blocks`, other objects than the sealing pass's), then `prove_run_with_forks`. A port needs:
  - the parts' inputs before the statement exists: the stage shapes and layouts (from the run shape) and the D55
    profile string (the fork seed domain), so a `ForkCtx` that does not borrow a `ForkRun`;
  - the fork blocks loaded before (or shared with) the sealing pass, so a parked part's block is the very object the
    fork finishes with (A18's `prove_core_after_with` refuses any other);
  - `seal_and_record` handing each witness to the slots as it is built (the witness cache would then hold only the
    window's outside parts), and the memory budget counting the parked parts (about 0.65 GB host each at 8B T128,
    plus `A`'s device copy);
  - a ruling that drawing a fork's generator and committing its `A` and `M` during the sealing pass (before the run
    header exists) is within H-1 (every refusal of an inadmissible chain still happens in the sealing pass, and a
    refused chain drops its parts), and the privacy gate's re-read of W-8(5) (§7).
  Measured in the harness, one request −2.3% and the 4-request stream +5.0% steady at window 16, for about +12 GiB of
  peak footprint [MEASURED]; on the RTX 5090 box the window would be bounded by device memory (about 1 GB of device
  rows per parked fork [ESTIMATE, A13]).
- **Fewer, longer parallel regions in the forks phase.** Stage 3 and 5 show the forks phase is sensitive to short
  parallel regions (§4.2). The fork path's existing short regions (a few per block below 1 ms of work: the small
  `inverses` chunks, `write_h` from 2^16 words, the exp histogram from 2^17, `accuracy_act::histogram`) could be
  tested run sequentially, one at a time, with the phase clock [ESTIMATE: each well under 1%]; and A11's pool width
  was re-swept (§4.4).
- **The exp / activation helper inverses from their tables** (`H: exp + activation helper inverses`, 12.4 ms per block;
  about 1 CPU-s per call of batch inversion): every admitted row of the exp and activation lookups IS a row of its
  table (CS-3 refuses a miss before any draw), so its inverse is the table entry's. A gather with a per-row equality
  check (a direct inversion for a non-row, which only the test-only cheating prover makes) would replace about 2.3 M
  inversions per block by gathers [ESTIMATE: about 0.6% of the forks phase]. The gather is indexed by a hidden lookup
  index (the class of `helper_one_any`'s existing table reads), so the privacy gate should see it first; not built.
- **The A/H zero-fill** (13% of a fork's host time): three forms have lost (A11's pool, A8's `calloc`, A17's kept
  matrices); A18 tried none. Untried: `A` allocated as the device's shared buffer (no host matrix, no upload copy:
  `gpu/metal.rs` and zkp-core `pcs.rs`, Sol's files).
- **In other lanes' files:** the openings' store fold (`gpu/metal.rs`, A8's, 14.8%), the public weight folds
  (`zkp-core` `mle.rs`'s `fold_cols_i8`, 1.4 CPU-s per call), the randomness (`rng.rs`, 9.5%; A14's lane XOF is
  opt-in), `pad::closed_form_indicator` (`pad.rs`, 0.012 s per fork per call, serial), the bulk salt draw (`pcs.rs`).
- **Not measured:** a trained 8B export (none is on the Mac; the synthetic diagonal block is the model, as in A3–A17),
  and any machine but this one.

## 7. Files, the privacy gate, merge risks

**Production code (privacy-gated digests that move):**
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/protocol.rs` (a `SHARED_SOURCE_FILES` pin of the run capture):
  A13's split (`CoreAhead`, `prove_core_before_with`, `prove_core_after_with`; `prove_core_with` is the two),
  `CoreHints` now `Copy`; the `[A18]` block after `CoreHints` (`HL_A18_TABINV`, `HL_A18_REGISTRY`, their test setters,
  `CheckedPublic::covers_accuracy`, `table_helper`, `range_table_helper`); the call sites in the rest.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_fork.rs` (a source pin of the D55 capture): A13's port
  (`ForkLate` with the preflight's records, `Parked`, `Done`, `Job`, `Slots`, side workers, `seal_ahead`,
  `prove_run_with_forks_ahead`, `prove_run_with_forks_sealing`, the test-only seeded generators, `ForkStats`'s four
  A13 fields). Every production caller (`trained_block.rs`'s `stack-prove`, `stack-verify`) calls the same
  `prove_run_with_forks` / verifier as before; with `HL_D55_AHEAD` unset nothing is parked.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/argument.rs`: `argument_with` (and `argument` as it with no
  record), `Points::registry_checked`.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/argument_accuracy.rs`: `define_changed` skips its
  `check_for_registry` when `Points::registry_checked`.
- Unchanged by A18: `trained_block.rs`, `witness.rs`, `witness_accuracy.rs`, `private_block.rs`, `range16.rs`,
  `accuracy_*.rs`, `run.rs`, `gpu/*`, `metal_kernels.metal`, zkp-core.

**For the privacy gate:**
- No path whose running time depends on a hidden value is added (§3.1). The record holds a reference to a public
  block and a copy of a public shape; `CoreAhead` holds what the core's locals held (the witness and the commitments'
  openings) for as long as a parked fork waits, and is consumed or dropped like them.
- **A13's window changes the D55 fork run's wording if it is ever turned on:** W-8(5) "built in its worker" becomes
  "built by the thread that starts the fork's proof, moved with the parked fork" (A13's note); one generator per fork,
  `L + 1` per run (the s25 census holds: two `from_os` sites in `run_fork.rs`). Off by default, it moves nothing.
- Nothing new is printed in production; no dependency is added; no new module, generator, absorb label or byte-string
  literal on the block path (the s24 / s25 / `hash_domain` / C-H4' audits pass in the suite).
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

**Tests:**
- `run_fork_tests.rs`, the block marked `[A18]` at the end: `A18Arm`, `a18_word`, `a18_apply`, `a18_stsl`,
  `A18Mem`, `a18_sealed_report`, `A18Sealed`; A13's byte tests (`A18Fix`, `a18_check_direct`, `a18_check_paths`, the
  suite test and the ignored device test). Hooks outside the block: `GpuArm::a18`, `gpu_arm`'s `[A18]` words, the A/B
  loop's apply and reset, `forked_sealed`'s window path, and **`piped` rewritten** (its channel now carries the
  statement made on the sealing thread when `stsl` or a window is in force, and an `A18Sealed`).
- `w16r2_tests.rs`, the block marked `[A18]` at the end: `A18_SETTINGS`, `a18_split_digest`, `a18_three`, two suite
  tests and two ignored tests (§3.2).

**Merge-conflict risks against perf:**
- `run_fork_tests.rs`: the most exposed. Other lanes append to `GpuArm`, `gpu_arm` and the A/B loop's apply / reset
  lists (A14–A17 did); keep every lane's lines. `piped` and `forked_sealed` are rewritten here (A13's form, adapted):
  a lane that edits either needs a hand merge (the sealing loop moved into a `seal_all` closure that hands each
  witness over).
- `w16r2_tests.rs`: an appended block; conflicts only at the end of the file (keep both).
- `protocol.rs`: `prove_core_with`'s body is split in two at `M`'s commitment; a lane editing that body (Sol's W16R3
  B1 is in `pcs.rs` / `metal.rs`, not here) must put its change on the right side of the split. The `[A18]` block sits
  after `CoreHints`.
- `run_fork.rs`: `ForkCtx` lost `roots` / `in_data` / `out_data` / `binding` / `checked` to `ForkLate`, and
  `prove_one` / `finish` replace the old `prove_one`; a lane editing the fork worker needs a hand merge.
- `argument.rs`: `argument` now forwards to `argument_with`; `Points` gained a field.

**This directory:** `s1.sh` (the profile before), `b.sh` (a compile check), `s2.sh` (the byte evidence), `s3.sh`
(the A/Bs of the forms and A13's window), `s5.sh` (the diagnostic: the phase clock of each form, each form in a 2-arm
A/B, A11's pool width re-swept), `s6.sh` (A13's window confirmed), `s7.sh` (the final default against the code
before A18), `s4.sh` (the acceptance); their progress files, guard records and trimmed logs; `run_stage.py`,
`phase_table.py`; the tables `s1_rank.md`, `s1_rank_detail.txt`, `s1_leaf_detail.txt`, `s3*_pairs*.md`,
`s3*_seal*.md`, `s5_*.md`, `s6*_*.md`, `s7_*.md`. The raw logs and the sample call graph stay in `raw/` (not
committed).
