# Token review, round 13: the classifier tables tied to the pinned tensor (rung R-C2)

Reviewer: independent soundness / code review of the frozen token tree `frozen-r13/` (2026-10-28/29 UTC).
**This is not a privacy review and not a classifier-fidelity review.**

## Verdict

**R-C2 is ACCEPTED on soundness for its scope. No fix is required before the next step.**

In plain words: before R-C2, the classifier proof trusted its own table files. Someone could swap in a
different "yes minus no" row (the margin row), update the file's checksum to match, and get a valid proof
of a verdict the model never gave. With the r13 binary, prove and verify rebuild those tables from the
pinned model tensor and refuse any file that differs. Every forgery I tried was refused, including
forgeries whose checksums were updated to match.

* **The five requirements** (REVIEW_R12B §5; the brief calls it §9) all hold in the shipped CLI. I checked the
  code, the arithmetic end to end, and 14 test-only mutations of the checks.
* **The rebase onto native R12b is clean.** My own three-way merge reproduces the lane's tree. The token
  tree differs from R12b only in 10 native files, and every one of those differences is accounted for.
  The round-13 visibility edits change no behaviour.
* **The dev-rung pin is reproduced independently.** My own reference matches all three digests: the tensor
  `bba6d094…`, the embedding `c0e816c9…` and the margin row `24e6ff4c…`.
* **Attacks.** 51 attack cases in my scratch copy, in 9 test groups. All are refused, before any proof work
  wherever the attack allows that. 3 control cases are accepted, as they should be: a doctored head (the
  classifier never reads it), the same scale written differently, and no `classifier.json` copies with the
  honest row.
* **No silent downgrade.** The r13 binary refuses R-C1 receipts (schema `/1`), and the r12 binary refuses
  R-C2 receipts.
* **The evidence is real.** The full suite ran (832 / 0 / 55). The failing-first log shows the 4 reds.

There are 12 notes, none of them a soundness defect in the shipped CLI (§9). Two of them matter before the
next steps:

* **N-r13-1 (low, API).** The binding is enforced in the CLI loader, not in the library API. The gate's
  library-path capture tool still builds R-C1-style tables. Close this before any non-CLI caller (such as
  Astra's app) or any gate claim about R-C2.
* **N-r13-2 (low, test gap).** One of the two profile-digest checks has no test that fails without it.

## What was reviewed

* **The freeze.** `results/zk60_token_io_r1_20261017/frozen-r13/`: 257 files, manifest
  `manifest_final_r13.sha256`, list sha256 `6edb1ce6…` (recomputed).
  * My copy `ops/zkp-mvp/token-io-review-r13-scratch/` matched it file for file before my edits
    (`r13/tree_check_r13.json`).
  * The frozen tree was not modified.
* **The native base.** R12b, `results/zk60_1b_native_20261017/r12b/frozen-tree/`: 229 files, tree
  `51de5b83…` (recomputed).
* **Read in full:**
  * `token_io/classify_tied.rs` and `classify_tied_tests.rs` (new);
  * the R-C1 → R-C2 diffs of `classify_cli.rs`, `classify.rs`, `token_io.rs`, `load.rs` and
    `examples/zk60_classify.rs` (saved in `r13/*.diff`);
  * the OUT-C norm and margin code, `stage_out_c.rs:166–194, 502`;
  * native `tied_tables/derive.rs` (R12b);
  * the classifier fixture `classify_cli_tests.rs::Cc`;
  * `cli/README.md` (R-C2 section) and `classifier/DESIGN_CLASSIFIER.md` §14.
* **My runs.** All guarded, serial, on a shared box, n = 1. A `WINDOW_HOLD` check came before every launch,
  and the build waited for a clear box (lean-memory rule).
  * The full suite was **not** re-run. The lane's run is complete (§8), and I found no reason to repeat it.
  * The Shieldstral path (it streams 7.7 GB) was **not** re-run, for the same reason (§5).

Paths below are `results/zk60_token_io_review_r1_20261017/` unless stated. Line numbers are those of the
frozen tree `frozen-r13/hashline/src/private_block/`.

## 1. Per-item table

| # | Item | Verdict | Where |
|---|---|---|---|
| 1a | ids / scale / threshold_c only from the bound profile's `classifier_margin_parameters`; the policy and the classifier.json copies must be equal | **HOLDS** | `token_io/classify_tied.rs:153–162` (read), `:164–172` (policy), `:175–190` (copies), `:211–213`, `:300` |
| 1b | the returned profile digest == the statement's `export_profile_sha256` | **HOLDS** (the second check is untested, N-r13-2) | `classify_tied.rs:195–202` (first read), `:228–230` (after the derivation), `:296` |
| 1c | the recomputed row is used; `margin_int16.bin` is compared, never trusted | **HOLDS** | `classify_tied.rs:278–280` (compare), `:303–304` (the run's `w` is `tied.w`); dev `:267–268`, Shieldstral `:218–219` |
| 1d | \|m\| > 32767 refused, never clamped | **HOLDS** | `classify_tied.rs:268` (R12b `quantize`, ±32767); native `derive.rs:180–187, 260–264`; door `token_io/classify.rs:380` (−32768) |
| 1e | final-norm weights γ and the rotation applied exactly once; OUT-C uses only g0 | **HOLDS**, arithmetic checked end to end (§2.5) | `stage_out_c.rs:179–192` (g0 · cn only; `FinalNorm` has no per-channel field); γ only in `w` (`classify_tied.rs:267`; native `derive.rs:258–262`) |
| 2a | BOS and final norm from `token_io_parameters` | **HOLDS** | dev `classify_tied.rs:247–253`; Shieldstral native `derive.rs:68–84`; compared `:281–286`; door `classify.rs:383, 404–415` |
| 2b | `--min-bits` floors 93 dev rung, 95 elsewhere (D27) | **HOLDS** | `classify_tied.rs:309–315`; `classify_cli.rs:614–617`, before the identity pin; every verifying command goes through `door` (`:596, 676, 716, 761`) |
| 3 | rebase R8 → R12b (42 files, 7 merges, 4 adjacency conflicts, the s25 double scan); visibility edits non-behavioural | **HOLDS** | §4; `r13/rebase_check_r13.json`, `r13/native_diffs/` |
| 4 | dev-rung pin `bba6d094…` and its tables; the swapped export honest; both verdicts reachable | **HOLDS** (N-r13-3: the second verdict needs the test-only policy) | §5; `r13/rv13_dev_tied_reference.{py,json}` |
| 5 | attacks (margin row, embedding, head, BOS, final norm with rehashed manifests; classifier.json-only edits; another export's profile; R-C1 receipt; min-bits) | **all refused** (the head is not read, by design) | §6; `review_r13_tests.rs` (scratch) |
| 6 | schema `zk60-classify-run/2`; no silent downgrade | **HOLDS** | `classify_cli.rs:85, 378–379`; §7 |
| 7 | evidence: s17 832 / 0 / 55 ran; failing-first shows the 4 reds | **HOLDS** (N-r13-11) | §8 |

## 2. The five requirements in detail (item 1)

**2.1 Ids, scale and threshold.**
* `MarginParameters::of_profile` reads `yes_id`, `no_id`, `public_scale` and `threshold_c` from the
  `classifier_margin_parameters` of the `profile.json` bytes whose SHA-256 is the statement's
  `export_profile_sha256` (`:195–213`). The scale is kept as exact binary64 bits.
* `check_policy` requires the registered policy's `(yes, no, margin_scale_bits, c)` to equal those four
  values.
* `check_copies` requires every copy present in `classifier.json` to equal them. Absent copies are allowed:
  the file is never an authority, so a missing copy changes nothing (my R5 confirms the run verifies, §6).
* The run's `c` is `cp.policy.c` (`stage_out_c.rs:502`), which therefore equals the profile's.
* The classifier profile text now carries `margin-scale` and `margin-scale-bits`
  (`classify.rs:521, 551–553`).

**2.2 The profile digest.**
* `bound_profile` reads `profile.json` once and refuses it unless it has the statement's digest (`:195–202`).
* After the derivation, the derivation's own digest is checked again (`:228`).
  * At the dev rung this second check repeats the first: the digest is computed from the same bytes.
  * At Shieldstral it is the only check between the token read and native R12b's own read.
  * Mutating it away fails no test (N-r13-2).
* In the CLI, the order is:
  1. `load_export`;
  2. the min-bits floor;
  3. the identity pin (`--expect-statement`);
  4. the policy;
  5. the tied loader (`classify_cli.rs:610–627`).

  So the profile digest checked by the loader is the pinned one.

**2.3 The recomputed row.**
* `load_tied_classifier_tables` returns `ClassifierTables::new(v, d, emb, tied.w)` (`:304`): the run's
  margin row is always the derived one.
* The file is compared (`:278`). The embedding is taken from the file only after its streamed SHA-256
  equals the derived table's digest (`read_exact_streamed` hashes the bytes it hands back, `load.rs:144–157`).
* The only production callers of the classifier prover and verifier are the CLI's prove (`classify_cli.rs:500`)
  and `door` (`:627`). `door` serves verify, input-owner and label.

**2.4 Refusal, not clamp.**
* Dev rung: `tied_tables::quantize(&diff, scale, −32767, 32767)`, R12b's own function, which refuses
  outside the range.
* Shieldstral: native `recompute_tied_tables`, whose refusal propagates through `?`.
* The door refuses −32768 (`classify.rs:380`).
* My reference counts the dev-rung refusal edge: 0 refusals down to scale 2^-9, then 15, 69 and 129 words
  at 2^-10, 2^-11 and 2^-12 [COUNTED]. The `clamp` mutant shows the lane's overflow test is load-bearing
  (§8.3).

**2.5 γ and the rotation exactly once, end to end** [COUNTED / MEASURED].

The structural argument:
* OUT-C computes `y_i = round(x_i · g0 · cn / (D · 2^tn))` with `D = isqrt(ceps + Σx²)`
  (`stage_out_c.rs:169–189`).
* `FinalNorm` has only `g0, cn, tn, ceps`. No per-channel weight can enter OUT-C.
* So `Δ = Σ y_i w_i` applies γ exactly where `w` carries it: `w = q(R((E_yes − E_no) ⊙ γ) / s)`.
  * Native: `derive.rs:258–262`, with R = signed block Hadamard / 32.
  * Dev rung: R = I, `classify_tied.rs:267`.
* The residual stream lives in the basis the embedding defines, `rotate(E_tok)` (same signs, same
  function). Because R is orthogonal, `⟨(E_yes − E_no) ⊙ γ, x̂⟩ = ⟨R((E_yes − E_no) ⊙ γ), R x̂⟩`.
  So R appears once, in `w`.

The numeric check (my R11, second run; see §8.3):
* On the fixture's honest item, OUT-C's own integer margin is compared with the float logit difference
  `k · Σ_i g_i (E_yes − E_no)_i x̂_i`, where `x̂ = x √d / √(Σx² + ceps)` and
  `k = g0 · cn / (2^tn √d) / scale`.
* The γ-once hypothesis must fit within the rounding bound, and better than "γ twice" and "no γ".
* Result: the integer margin is −174280, against k·L = −172950.5 with γ once (0.8 % off), −211252.5 with
  γ twice and −138648.8 with no γ (§8.3). The `no-g` and `g-twice` mutants each move the margin onto their
  own hypothesis, and R11 then fails.

## 3. BOS, final norm and `--min-bits` (item 2)

**BOS and final norm.**
* Dev rung: BOS and both final norms come from `token_io_parameters`. They are checked by R12b's own
  `norm(·, false)`: g0 = 127, cn, tn and ceps in their declared classes.
* Shieldstral: native `calibration` applies the classifier class (tn 10, ceps < 2^40, BOS 1, head tn and
  ceps equal to `profile_constants`).
* At both, the classifier door then pins the 32-bit remainder window (`classify.rs:413`). It also requires
  the policy's first template id to be BOS (`:383`). At the dev rung that forces tn = 11.
* `classifier.json`'s `bos` and `final_norm` must equal the derived values (`:281–286`). The run uses the
  derived ones.

**`--min-bits`.**
* The floor is applied in `door` before the identity pin, so it covers verify, input-owner and label.
* My R8 refuses 92, 0, −1, "abc" and 200 at verify, and 92 at input-owner and at label. 93 verifies at all
  three.
* The rung's run reports `whole_run_floor_bits` 94 [MEASURED], so the default `--min-bits` (95) refuses an
  honest rung run, as the README says.

## 4. The rebase (item 3)

I re-did the rebase myself (`r13/rebase_check_r13.py`):
* **Inputs.** Native R8 (`r8/frozen-tree`), native R12b, the lane's R8-based tree `ops/zkp-mvp/token-io`,
  and the frozen r13 tree. The R8-based tree's newest mtime is 10-26 19:35Z, before the 10-28 rebase, so
  it is the rebase's true input.
* **Classes** [COUNTED]:
  * 186 untouched;
  * 33 changed by native only, all byte-equal to R12b in the token tree (the lane's "26 copied + 9 added",
    minus 2, see below);
  * 1 changed by the token lane only (`s33_tests.rs`, kept);
  * 7 changed by both;
  * 2 changed by native only but differing in the token tree: `tied_tables.rs` and `tied_tables/derive.rs`,
    the round-13 visibility edits.
* **Merges.** My `diff3 -m` reproduces the lane's result exactly for `private_block.rs`, `s24_tests.rs` and
  `trained_block.rs` (0 residue lines).
  * For the other four, the residue is exactly one conflict hunk each, resolved keep-both. The summed array
    lengths are `lane` 24, `OWN_SOURCE_FILES` 26 and `CALL_SITES` 23. Rust checks array lengths at compile,
    and my build compiled.
  * Plus the round-13 edits: classifier source pins 4 → 5; the word "four" → "five" in the capture README
    template; and the s25 dedup (+6 lines).
* **The s25 double scan** (`s25_tests.rs:1602–1607`). With the dedup, `derive.rs` is scanned once when the
  token lane's submodule scan already reached it, and R12b's push remains the fallback. The census table
  still requires derive.rs's 5 `Sha256::new(` sites. This weakens nothing.
* **Native files that differ from R12b: 10** (`r13/tree_check_r13.json`). Each is either a token-lane
  edit carried from the reviewed earlier rounds, or one of these round-13 edits:
  * `pub(crate)` on `norm`, `bf16` and `quantize` (`tied_tables/derive.rs:53, 113, 180`);
  * one `pub(crate) use` line plus a comment (`tied_tables.rs:14–15`);
  * the 10 `pub(crate)` lines in `trained_block.rs` (earlier token rounds).

  None of these changes behaviour:
  * `pub(crate)` does not change what is exported outside the crate.
  * No module glob-imports `tied_tables` or `derive` (grep), so no name resolution can move.
  * The only behaviour-adjacent effect is the bytes of `derive.rs` itself. Its source pin in token-tree
    captures differs from native R12b's (N-r13-12).
  * No statement or transcript absorbs a source hash (`trained_statement.rs` has no source field; the dev
    fixture's `calibration_tool` hashes name `trained_block_tests.rs` / `trained_block.rs` inside a TEST
    export's profile only).
* **Carried, not re-reviewed.** The capture hooks and registry fixes of 10-26 (`run_capture.rs` +1473/−12
  vs R12b, s25 +341/−15) are carried unchanged from the R8-based tree. Their −12 lines are the token lane's
  own earlier edits vs R8, not lost R12b lines. Their review status is unchanged by this round.

## 5. The dev-rung pin and its tables (item 4)

**My reference** (`r13/rv13_dev_tied_reference.py`, 1.1 s, 34 MB) [COUNTED].
* How it was written: from the contract text, not from the lane's script.
  * BF16 is decoded by hand into exact fractions.
  * Every quantization is computed both exactly and in binary64.
  * The rung's `s_x` is read from the Rust fixture writer, not typed in.
* What it reproduces:

  | Table | Digest |
  |---|---|
  | tensor | `bba6d094…` |
  | embedding | `c0e816c9…` (\|q\| ≤ 5940) |
  | dev margin row (40 / 41, scale 2^-8) | `24e6ff4c…` (\|w\| ≤ 15305; first 8 words equal) |

* Exact vs binary64:
  * 0 coordinates where the exact and binary64 quantizations disagree, in the embedding (115,200 values)
    or the margin (384).
  * The margin has 8 exact half-up ties. Both paths round them up.
  * The product `(E_yes − E_no) · g` is exact in binary64 for every coordinate.

**The swapped export is honest.**
* It is the same tensor read with yes / no = 41 / 40, giving row `b4a059cd…` (reviewer reference).
* The fixture's tables there equal this row (my R1 asserts the digest through the loader).
* `w + w'` takes only the values {0, 1}: negation up to the 8 ties.
* Its export has the same block and embedding and its own profile, hence another identity. Its policy is
  registered only under `cfg(test)`.

**Both verdicts.**
* The fixture item gives verdict 0 under the registered dev policy and 1 under the swapped policy. Both
  prove and verify (lane e2e; my R10).
* Under the **production** dev policy alone, six contents I chose (starting at ids 9, 60, 120, 180, 240
  and 270) all give verdict 0 [MEASURED].
* So the rung's verdict 1 exists only under the test-only policy (N-r13-3).
* This does not weaken soundness, but a gate capture "at both verdicts" must use a test-registered policy
  with its own export.

**Shieldstral.**
* I did not re-run the 7.7 GB path. The lane's log (`r13/logs/shieldstral-r12b.log`) gives embedding
  `baff04d2…` and margin `1f5cb346…`, span −32767..31800, BOS 1 and norm (127, 1024, 10, 2439). Those are
  exactly the R12b reviewer's independent transcription (`results/zk60_d24_review_20261017/r12b/r12b_tied_reference.json`).
* The R-C2 code on that path is a thin call (`classify_tied.rs:216–224`) that the lane's ignored test
  exercises.

## 6. Attacks (item 5)

The attacks are in `ops/zkp-mvp/token-io-review-r13-scratch/hashline/src/private_block/token_io/review_r13_tests.rs`
(scratch only). They ran in the baseline (`r13/logs/rvtk13-baseline.log`, and `baseline2` after the second
build).

| Test | Attack | Result |
|---|---|---|
| R1 | margin row replaced, `classifier.json` rehashed: the swapped policy's honest row, all zero, doubled-and-clamped, one word ±1 | R-C1 reader accepts; **R-C2 loader, prover (nothing claimed) and verifier (nothing published) refuse** each; reference digests of both exports asserted |
| R2 | embedding replaced, `token_io.json` rehashed: a content token's row, the BOS row, the whole table re-quantized at s_x · 1.001 | refused by name at the loader, the prover and the verifier |
| R3 | head and multipliers doctored, `head_manifest.json` rehashed | an honest run **verifies byte for byte**: the classifier never reads the head (by design; at Shieldstral native R12b derives the export's head) |
| R4 | BOS 2 consistently in `classifier.json` and `token_io.json`; g0 / ceps / tn edits; the export's own `token_io_parameters.bos` edited (at the pin, and pinned to itself); cn moved consistently in export, tables and pin | all refused; the self-pinned cases before any segment (door / re-render) |
| R5 | `classifier.json` only: yes / no swapped; yes / no swapped plus the swapped row (rehashed); threshold_c ±1; scale doubled | refused at the loader and the verifier. Accepted: the same scale value in other text; no copies at all with the honest row. Refused: no copies with the swapped row |
| R6 | the other export's `profile.json` in the verifier's copy (at the pin; at its own identity with the dev policy); a dev-policy run under the swapped inputs; two honest runs recombined both ways (segments of one, statement of the other); `profile.json` swapped between the statement read and the derivation; statement `margin_scale` / `tied_source` / margin digest edited | all refused, nothing published; the untouched copies verify |
| R7 | an R-C2 statement rewritten as schema `/1` (alone, and in the full R-C1 shape) | refused by the r13 verifier before any segment |
| R7b | cross-binary with the lane's frozen r12 (`04036e26…`) and r13 (`e320c237…`) binaries | see §7 |
| R8 | `--min-bits` 92 / 0 / −1 / abc / 200 at verify; 92 at input-owner and label | all refused; 93 verifies at all three |
| R9 | dev tensor: a symbolic link to the honest bytes; all signs flipped; one norm weight changed; two bytes long | all refused at the loader |
| R10 | both verdicts under the production dev policy (6 contents) | all prove and verify; all verdict 0 (N-r13-3) |
| R11 | the integer margin against the float logit difference (γ once / twice / none) | §2.5, §8.3 |

## 7. Schema bump and downgrade (item 6)

* **The r13 side.** `CLASSIFY_STATEMENT_SCHEMA` is `zk60-classify-run/2` (`classify_cli.rs:85`).
  `found_statement` refuses any other schema (`:378`), and the verifier re-renders the whole statement.
  There is no flag, fallback or second schema. R7 confirms that a `/1` statement is refused.
* **Across binaries** (R7b, `r13/logs/rvtk13-xbin.log`) [MEASURED]:
  * The trained statement identity is **the same** under both binaries for the same export (`061340df…`).
    So the identity pin does not tell R-C1 from R-C2; the schema does.
  * The r12 binary refuses the r13 receipt.
  * The r13 binary refuses the r12 receipt, and so does this tree's in-process verifier.
  * Each binary verifies its own receipt.
  * **R-C1's gap, shown live.** With the r12 binary, a doctored (rehashed) margin row, namely the swapped
    policy's row, **proves "flagged" and the r12 verifier accepts it**. The r13 binary refuses that receipt
    with either set of tables.
  * After the second build: R-C1 segments placed under an R-C2 statement (an "upgrade") are refused by the
    r13 binary and in process (§8.3).
* **No silent downgrade path.** Nothing in r13 accepts `/1`. The remaining risk is choosing the wrong
  binary. README line 79 ("re-check R-C1 runs only with the r12 binary") should add that an R-C1 receipt is
  not evidence of the model's verdict (N-r13-8).

## 8. Evidence (item 7) and my runs

**8.1 The lane's evidence** [MEASURED, from the lane's logs].
* **s17** (`r13/logs/s17-suite.log`, guard record `s17-suite.guard.json`): exit 0.
  * The 29 `test result` lines sum to **832 passed, 0 failed, 55 ignored**.
  * 832 `... ok` lines.
  * All 8 `classify_tied_tests` appear (7 ok, the Shieldstral test ignored).
  * 883 s, peak 7.12 GiB, cgroup + watchdog.
* **b1-redfirst** (`r13/logs/b1-redfirst.log`): exit 101, 23 passed, **4 failed**, 3 ignored. The four
  are the margin-row, embedding, final-norm / BOS and min-bits tests, each failing at its prover or verifier
  assertion: R-C1's CLI proved the doctored tables and accepted `--min-bits 92`.
* **The Shieldstral R12b-path test:** 1 passed, 17.3 s recompute.

**8.2 My builds and baseline** [MEASURED, shared box, n = 1].
* **Builds.** `rvtk13-build` from scratch: 182 s, peak 2.16 GiB. `build2` (incremental): 173 s.
* **Baseline:** 38 passed, 1 failed (my own R10 expectation, since relaxed to a record), 4 ignored. 38.5 s,
  0.69 GiB.
* **`baseline2`:** 40 / 0 / 4.
* **`xbin` and `xbin2`:** 1 / 0 each.
* **14 mutation runs:** about 24 s and 0.56–0.61 GiB each.
* **Guard:** cgroup + watchdog for every job. All jobs were serial, and none was declared at 3 GiB or
  more beside another job.
* **The D44 window.** It came at 00:10:42Z, between my mutation runs. My queue held from 00:10:44 to
  00:34:44Z with nothing live ("RVTK13 VIEW CLEAR" is in the ledger).

**8.3 Mutation runs** (`r13/mutation_table.json`; `RV13_MUT`, compiled into the test build only).

A mutant is killed when a test that passes on the baseline fails with it.

Each mutant was run against the lane's `classify_tied_tests` and `classify_cli_tests` and my
`review_r13_tests`. My R10 is excluded: it failed on the unmutated baseline. "Sound?" says whether the
mutant would still be sound, because the run uses the derived value anyway.

| Mutant | What it removes | Sound? | Killed by the lane's tests | Killed by mine |
|---|---|---|---|---|
| `rc1` | every R-C2 check; files trusted (R-C1's behaviour) | no | margin row, embedding, final norm / BOS, margin parameters | R1, R2, R4, R5 |
| `skip-policy` | policy == profile parameters | no (c) | margin parameters | none |
| `skip-copies` | classifier.json copies == profile | yes, no authority (refusal lost) | margin parameters | R5 |
| `skip-bound` | first profile-digest check | no | dev tensor / derivation | R6 (e) |
| `skip-second-digest` | post-derivation digest check | yes at dev; no at Shieldstral | **none** | **none** (N-r13-2) |
| `no-g` | γ not folded | no | dev tensor / derivation (digest pin) | R1 (reference digest) |
| `g-twice` | γ folded twice | no | dev tensor / derivation (digest pin) | R1 (reference digest) |
| `clamp` | clamp instead of refusal | no | int16 overflow | none |
| `skip-emb-cmp` | embedding digest compare | no | embedding | R2 |
| `skip-w-cmp` | margin file compare (the run still uses the derived row) | yes (refusal lost) | margin row | R1, R5 |
| `use-file-w` | the file's row used, no compare | no | margin row | R1, R5 |
| `skip-bos-norm` | BOS / norm compare (derived values still used) | yes (refusal lost) | final norm / BOS | R4 |
| `use-file-bos-norm` | the file's BOS / norm used, no compare | no | final norm / BOS | R4 |
| `floor-off` | the `--min-bits` floor | no | min bits | R8 |

* **13 of 14 mutants are killed.** Every unsound one except `skip-second-digest` is killed by at least one
  of the lane's own tests.
* The `no-g` / `g-twice` mutants are caught only by the digest pins. The fixture derives its tables with
  the same (mutated) function, so the CLI end-to-end tests stay green. This shows why the independent
  reference pin matters.

**R11, the end-to-end arithmetic** (`r13/logs/rvtk13-baseline2.log`, `rvtk13-mut2-*.log`) [MEASURED / COUNTED]:

| Build | OUT-C integer margin | k·L, γ once | k·L, γ twice | k·L, no γ | Best fit |
|---|---|---|---|---|---|
| frozen code | −174280 | −172950.5 (off 1329.5, 0.8 %) | −211252.5 (off 36972) | −138648.8 (off 35631) | **γ once** |
| mutant `no-g` | −137415 | (off 35536) | (off 73838) | (off 1234) | no γ: R11 fails, the mutant is killed |
| mutant `g-twice` | −219091 | (off 46141) | (off 7839) | (off 80442) | γ twice: R11 fails, the mutant is killed |

* k = 1659.121.
* Verdict 0 throughout, and the float verdict (L < 0, c = 0) agrees. The run's statement says 0.
* The frozen code's integer margin is the float logit difference with γ applied once, to within 0.8 %.
* The two wrong hypotheses are off by about 20 %, and each mutant moves the margin onto its own hypothesis.
* At the dev rung, R = I, so this checks γ. The rotation's single application at Shieldstral rests on the
  structural argument of §2.5, plus native R12b's reviewed derivation, plus the embedding being in the same
  rotated basis.
* The second build's baseline: **40 passed, 0 failed, 4 ignored** (lane classifier tests + R1–R11).
* `xbin2`: PASS, including the upgrade attack (R-C1 segments under an R-C2 statement are refused by the
  r13 binary and in process).

## 9. Findings

None is a soundness defect of the shipped R-C2 CLI.

* **N-r13-1 (low, API hardening; do before any non-CLI caller).**
  * R-C2's binding is enforced in `load_tied_classifier_tables`, a CLI-layer function. The library entry
    points take any `ClassifierTables`:
    * `ClassifyRunStatement::new_chunk`;
    * `prove_classify_run_with` / `verify_classify_run_with` (`classify_run.rs:96, 224`);
    * `run_capture`'s replay.
  * Today every production entry point goes through the tied loader: prove, verify, input-owner and label.
  * But the gate's capture tool `capture_a_classify_rung_run` (`classify_capture_tests.rs:83–126, 391–`)
    still builds R-C1-style tables: a generic embedding and a random margin row.
  * Suggested fix: make the verifier's table argument a type only `classify_tied` can construct, before
    Astra's app links the library or the gate claims anything R-C2-specific from library-path captures.
* **N-r13-2 (low, test gap).** The post-derivation digest check (`classify_tied.rs:228`) survives
  mutation: no test fails without it. It is redundant at the dev rung and load-bearing at Shieldstral. Add a
  Shieldstral-path test that swaps `profile.json` after the token read, or factor the check into a function
  testable with a stub derivation.
* **N-r13-3 (low, coverage).** At the dev rung the registered policy reaches only verdict 0 on every
  content tried (§5). Verdict 1 comes from the test-only swapped policy. Gate captures and demos that need
  both verdicts must use a test-registered policy with its own export.
  * Astra's ledger reports the same independently for its `classifier_c2_fixture`
    (`results/zk60_shieldstral_export_20261026/PROGRESS.md`): a 327-input search found only verdict 0, with
    margins −232068..−179696.
* **N-r13-4 (low, documents).** Stale text:
  * `DESIGN_CLASSIFIER.md` §14.2 (line 611) still says yes / no / scale come "only from the
    pre-registered policy". The rule now in force: the export profile's `classifier_margin_parameters` is
    the authority and the policy must agree.
  * `cli/README.md`'s statement section (line 186) still says schema `/1`. Its "What verify does" step 1
    (line 153) still says "the margin vector from `--tables`".
  * §14.3's "about 55 s per call" (line 626) should be updated: 17.3 s warm was measured, and it happens
    twice per run (N-r13-5).
* **N-r13-5 (low, liveness, Shieldstral).**
  * Every prove and verify streams the checkpoint **twice**: once in `load_export` → `TrainedExport::load`
    → `tied_of`, and once in `recompute_tied_tables`. That is about 2 × 17 s warm.
  * Refusals of a wrong policy or scale come only after the first stream.
  * One derivation returning both the native check and the margin row would halve this.
* **N-r13-6 (low, future-proofing).**
  * The loader picks its source by **block** profile (`TiedSource::of`). The statement text uses the
    **run** profile (`of_run_profile`).
  * Registering a Shieldstral classifier run profile needs both maps updated, plus `CHUNK_OVERLAPS`.
  * If one is forgotten, `describe_under` silently writes `tied-source=unregistered`, while `render`
    refuses (fail-closed).
  * Suggested fix: derive one map from the other, or assert that they agree in the loader.
* **N-r13-7 (info, for the coordinator's "one export per category").**
  * An export binds one (yes, no, scale, c) set. Several registered policies with those four values but
    different templates are all admitted under the same export.
  * The template is bound by the policy registration, the classifier profile text and the statement.
  * So one export per category is needed only when the ids, the scale or c differ between categories.
* **N-r13-8 (low, documents).** R-C1 receipts have the same trained identity as R-C2 ones. The r12 binary
  accepts verdicts from doctored rows (§7). The README should say that R-C1 receipts and the r12 binary
  support no classifier claim.
* **N-r13-9 (low, hygiene; N-r12b-4 class).**
  * The `Cc` fixture writes under `std::env::temp_dir()`, and s17 ran without `TMPDIR`. The fixture
    cleans up on drop.
  * My runs set `TMPDIR` outside the repo (`~/zk60-artifacts/token-io-review-r13-tmp`).
* **N-r13-10 (cosmetic).**
  * In `classify_tied.rs:122`, the doc comment of `margin` sits on the previous field's line.
  * The R-C1 reader `load_classifier_tables` stays `pub(crate)` with only test callers. Gate it
    `#[cfg(test)]`, so that no future production path trusts files again.
* **N-r13-11 (evidence wording).**
  * b1 ran an earlier version of `classify_tied_tests.rs`, before the 23:15 rebuild (its panics are at
    lines 117–184, against 185–291 now).
  * The two tests added after b1 were never red-first: margin parameters only from the profile, and the
    int16 overflow.
  * My mutants supply the equivalent evidence: `skip-policy` and `skip-copies` kill the first, and `clamp`
    kills the second (§8.3).
* **N-r13-12 (capture format).**
  * `tied_tables/derive.rs` in a token-tree bundle's `source_pins` has the token tree's hash, not native
    R12b's (the three `pub(crate)` words).
  * Token bundles also list five classifier source pins (`classify_tied.rs` added).
  * The gate must not compare derive.rs pins across token and native bundles.

## 10. What the privacy gate must re-capture

R-C2 changes the classifier profile text (`margin-scale`, `margin-scale-bits`, `tied-source`). That moves
the classifier profile digest and so the transcript. It also moves the statement schema (`/2`, adding
`margin_scale` and `tied_source`) and the dev fixture: the embedding and margin rows are now derived from
`bba6d094…` instead of generic or random, and the second verdict uses the swapped policy and its own
export. **None of the gate's round-17 R-C1 captures carries over to R-C2.** For any R-C2 gate item,
re-capture:

1. **The rung captures** (classify-rung-L1 / L2 at v0 / v1 / tie, plus the D41 chunk), from tables
   produced by the R-C2 derivation. Today `capture_a_classify_rung_run` does not do this (N-r13-1).
   * The tie and verdict 1 need test-registered policies whose c and ids are the profile's, each with its
     own export (N-r13-3).
2. **The P-18 CLI-path capture** through the r13 binary. The lane's
   `~/zk60-artifacts/token-io/captures/classify-rc2-cli-p18-r13` is one, at verdict 0. The gate should
   read it and check its five classifier source pins.
3. **Re-checks of the bundle tools** on schema `/2` statements: the allow-list gains `margin_scale` and
   `tied_source`. Confirm that neither discloses anything beyond public profile constants. They are public
   constants of the registered policy and source.
4. **Shieldstral, once its classifier run profile is registered:** a capture through the CLI, whose
   tables are the native recompute. It costs two checkpoint streams per run (N-r13-5).

## Evidence

Everything is under `results/zk60_token_io_review_r1_20261017/` unless a path says otherwise.

* **Ledger:** `PROGRESS_R13.md`.
* **Tree and rebase checks:**
  * `r13/tree_check_r13.{py,json}`;
  * `r13/native_diffs/`;
  * `r13/rebase_check_r13.{py,json}`;
  * `r13/rebase_residue/`.
* **R-C1 → R-C2 diffs:** `r13/classify_cli_rc1_vs_rc2.diff`, `r13/classify_rc1_vs_rc2.diff`.
* **Dev reference:** `r13/rv13_dev_tied_reference.{py,json}`.
* **Queues:** `r13/run_rv13.sh`, `r13/run_rv13b.sh`; logs and guard records under `r13/logs/` (`rvtk13-*`).
* **Mutation table:** `r13/mutation_table.{py,json}`.
* **Scratch tree:** `ops/zkp-mvp/token-io-review-r13-scratch/`. Its `review_r13_tests.rs` and the
  `cfg(test)` mutation switch in `classify_tied.rs` are mine. The pristine copy is
  `r13/classify_tied.frozen.rs.orig` (sha256 `b0eb5047…`, equal to the frozen file).
