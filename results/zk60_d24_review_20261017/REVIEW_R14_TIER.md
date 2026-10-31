# D24 review, round R14-tier: the D27 security-tier binding on the R14 native backend

Reviewer: Claude (Opus 5.5 subagent), independent of Sol's lane. Written 2026-10-31, finished 09:43 UTC (`date -u`).

## Verdict

**The R14 security-tier candidate is ACCEPTED on soundness.** It implements D27's MVP tier (95 bits whole-run, backend only) on the accepted R14 profiles. **No soundness finding.** The bound, its rounding, the workload count, the transcript binding, the verifier minimum, v1 compatibility and the macOS liveness fix all hold, and I checked each one in the code.

Three **low fixes** are recommended. None touches a relation, and none weakens a bound:

* **R14T-F1 (low; evidence, gates registration, not acceptance):** the CLI's tiered branch has never run end to end, in Sol's evidence or mine. It covers the recount over the streamed export in `stack-prove` and `stack-verify`, the 360-byte `expected.bin`, the `/2` statement and its canonical comparison, and the "minimum required" refusal. My guarded attempt stopped at the export loader, because the Shieldstral checkpoint is not on this Mac (§6).
* **R14T-F2 (low; policy hardening):** a repeated `--min-security-tier` resolves silently to its *first* value, so `… 95 … 128` applies 95 (§4).
* **R14T-F3 (low; evidence classification):** the two "bound substitution" refusals in `NATIVE_ACCEPTANCE.json` are the test harness's own string comparison of `statement.txt`. They are not native or CLI refusals (§3).

In plain words, question by question:

* **1. The bound** is REVIEW_R14's accepted formula term for term. That includes my zero-check and batching allowance, the PCS ceiling and the floor on its erasure term, both carried as is.
  * The rounding is upward everywhere it is computed.
  * No float touches admission.
  * My independent exact recount reproduces every native numerator bit for bit. It gives **97.2588 / 97.3118 (T128) and 96.2871 / 96.4811 (T256)**, non-DD / DD. The rounded bound sits 152 / 172 units of 2^-128 above the exact value, and never below it.
* **2. The workload** is counted by the verifier from its own authenticated blocks. The prover chooses only the tier code. A changed block, a wrong block count, a mixed geometry or a bad group count is refused.
* **3. The claim is bound before any challenge.** The whole 160-byte claim is hashed into the plan digest. That digest feeds the joint-endpoint contexts, the run binding and the first absorbs of the transcript, all before any prover randomness or challenge. The CLI compares the entire 360-byte policy byte for byte, and also the statement JSON.
* **4. `--min-security-tier` fails closed.** It refuses a receipt below the minimum, an unrated v1 receipt when a minimum is given, a tiered receipt when none is given, and an unknown or unimplemented tier code. It also refuses malformed values: only the exact strings `95`, `100` and `128` parse. The one gap is F2.
* **5. v1 is unchanged.** Every v1 constructor, digest, policy and statement byte is unchanged by construction, and all three saved v1 frames verify under my own build.
* **6. The liveness fix is correct.** Only a checked positive `pid_t` is ever signalled. ESRCH means dead, EPERM means alive, and anything else refuses. PID 0, negative values, overflow and process groups are impossible.
* **7. Nothing else weakens accepted R14.** The production delta is additive and is reached only on a tiered plan.

**This is a soundness review only.** It covers the binding, the accounting and the portability fix. Nothing here accepts privacy, registers or activates a profile, claims throughput, or covers the classifier and token composition. The tier figure is conditional on REVIEW_R14 §3's A1–A7, unchanged.

## What was reviewed

* **The candidate:** `results/zk60_sol_20261031/r14-security-tier/`.
  * The pins are in `FINAL_SOURCE.json`: tree `132edcb7…`, 293 files. I re-hashed 293 / 293 with no mismatch (`r14t/rv14t_tree_summary.json`). The 264 further files under `source-tree/results/` are restored loader and test fixtures; they are not in the pin, and I did not review them.
  * **The patch is exactly the delta.** I diffed the tree against Sol's F1/F2 base (`r14-followup/source-tree`): 10 files changed, 2 added, 0 removed. That set equals the 12 files of `FINAL_SECURITY_TIER.patch`, and every +/− line matches.
  * The F1/F2 base differs from the accepted R14 tree (`review-author-1/source-tree`, 271 code files) only in `split_attack_tests.rs` and `split_dense_tests.rs`, which are the two test-only R14 fixes. So **production code = accepted R14 + this patch**.
* **The changes:**
  * I read in full `split_security.rs` (249 lines) and `split_security_tests.rs` (119).
  * I read every changed hunk in `split_run.rs`, `trained_split.rs` and `trained_block.rs`, and around each the code it reaches: `Plan`, `Statement`, `Verifier`, `prove_with_source`, `PublicBlocks`, `bind_policy`, `render_statement`, `verify`, `flags` and `clear_stale_writing_dirs`.
  * I also read what the counter calls (`layout::lookups_at`, `Shape::lookup_doms`, `SplitLayout::new`, `SplitProfile::new`), what the digest covers (`BlockPublic::digest`, `AccuracyPublic::encode`) and the PCS constants (`zk.rs:373–375`, `Shape` PCS fields).
  * The edits to `argument.rs`, `private_block.rs`, `run_capture.rs`, `split_capture.rs`, `s25_tests.rs`, `Cargo.toml` and `Cargo.lock` are module declarations, test pins, call-site census rows and the locked `libc 0.2.189` Unix dependency.
* **The evidence:**
  * `NATIVE_ACCEPTANCE.json`: 15 stages on test binary `02dfcbb5…`, source `e64502b3…`.
  * `PORTABLE_ACCEPTANCE.json`: 5 stages on `ac58566b…`, source `132edcb7…`.
  * Also `EXACT_BOUNDS_CHECK.json`, `check_exact_bounds.py`, `COUNTED_WORKLOAD_BOUNDS.json`, `CLI_PREFLIGHT.json`, `RUST_SUITE_SUMMARY.json` and `WRAPPER_CORRECTIONS.json`, together with the logs they cite.
* **The rules:** D27 (and Victor's 20:22 UTC direction), REVIEW_R14 §3 with A1–A7 and N-r14-5.
* **My runs**, listed in §7. All were guarded, and none wrote to Sol's directories.
  * Light Python checks: the recount (twice) and the tree check.
  * One **build** of a scratch copy of the candidate tree. The copy adds one reviewer test module and nothing else (`r14t/rv14t_reviewer_tests.patch`).
  * One **cpu** battery on that binary against Sol's retained frames, read-only.
  * One **cpu** CLI attempt, refused at the loader (F1).

## 1. Question 1: the bound

### The formula, as implemented

The code is in `split_security.rs`. **Per block**, `Counter::add` (`:83–117`) counts:

* **Byte queries:** Σ over `sh.lookup_doms()` of `lookups_at(sh, ids, dom).len() × size`, where size is T·width for D, T·hidden for F and `sh.size(dom)` otherwise (`:95–101`).
  * These are the true pieces. `SplitLayout::new` refuses pieces that do not sum to width and hidden (`split_layout.rs:76–78`).
  * The prover's histogram iterates the same `lookups_at` list over the same piece lengths (`split_witness.rs:60–90, 92–113`).
* **exp:** `size(S)`. **ACT:** T·hidden. **DD:** `size(S)`, plus the `size(Dd)` table under DD (`:102–105`).
* **The table:** T_d = 512 + 4096·G + DD table. The lookup term adds N + 4·T_d − 1 (`:108–109`).
* **Per slot of `p.layout().slots`:** the sumcheck term (main + ext)·degree, and my allowance 3·(main + ext) + 3 (`:110–113`).

**The run** (`finish`, `:120–147`) takes:

* **Regular openings:** 3L + 1, which is A and H per block, L − 1 boundaries and 2 endpoints.
* **The PCS ceiling:** regular·(⌊(4n − n − q)/3⌋ + 1 + 4096) + L·(2·512 + 1 + 4096).
* **Field terms:** ⌈(lookup + sc + zc + pcs)·2^128 / p²⌉.
* **Columns:** regular·⌈((8n + n + q)/(12n))^q⌉ + L·⌈(3/4)^256⌉. The mask base is (2·4096 + 2·512)/(3·4096), which is exactly 3/4.
* **Admission:** refused when units > 2^(128 − 95).

This is REVIEW_R14 §3 term for term (`r14/reviewer_bits_r14.py` `main`). That includes the reviewer's zero-check and batching allowance, Sol's retained PCS ceiling with its floor on the erasure term, and the δ/3 column rule with δ = 1 − (n + q)/(4n).

The parameters are read from the profile:

* n = 2^log_cols, the rate and q = `opened_cols`.
* The mask parameters come from `zk::MASK_LOG_MSG / MASK_LOG_DOM / MASK_Q` = 9 / 12 / 256.
* `Params::of` refuses an endpoint whose rate or row width differs from the core's (`:64–75`), so the single column base also covers the joint commitments.

`SplitProfile::new` admits only the four reviewed R14 profiles (`split_profile.rs:47–55`), so the counter is unreachable at any unreviewed geometry.

### Rounding is upward, with no floats

* **`fraction_units`** (`:32–45`) is a 128-step binary long division, ⌈num·2^128/den⌉. The carry path is an exact wrapping subtraction: when the shifted remainder is 2^128 + r, it is ≥ den and the difference is < den. An overflow of the rounded quotient past 2^128 − 1 is refused.
  * I emulated it bit for bit in Python with u128 wrap semantics. It agreed with the exact big-integer ceiling on **20,008 / 20,008** cases, half of them with den ≥ 2^127, which is the carry path.
* **`scale_up`** (`:47–52`) is ⌈v·num/den⌉, split at den. It agreed on 20,000 / 20,000 cases.
* **`power_units`** chains q − 1 upward steps. Each step is monotone and ≥ exact, so the result is ≥ base^q. The excess is below 1/(1 − base) ≈ 4 units.
* **The threshold** (`:142`) is units ≤ 2^33 ⟹ bound ≤ 2^-95, which is the right direction.
* **`Claim::json`** prints `whole_bits_floor` = 128 − ⌈log₂ units⌉ in integers (`:177–181`), so it never over-states.
* No `f32` or `f64` appears in `split_security.rs`.

**The one floor (note N-t1).** ⌊(4n − n − q)/3⌋ (`:129`) is the accepted formula exactly: REVIEW_R14's script has the same floor. It sits inside the carried PCS ceiling (A5). A ceiling would add exactly 79 units (+2×10^-8 bit) at all four profiles. Prefer ⌈·⌉ whenever the ceiling is re-derived, so that every term is rounded the same way.

### Independent recount [COUNTED]

**Method** (`r14t/rv14t_bound.py`, light):

* The geometry is Shieldstral's: D = T·3072, F = T·9216, Q = 4096·T, Kv = 1024·T, S = 32·T², L = max(16·T, n), Dd = 1024·T.
* The per-position byte counts are the ones reviewed at R13: D 34, F 14, Q 14, Kv 14, L 2, S 11 + 2·ls (or 6 under DD), Dd 5 + 2·ls, with ls = ⌈(log₂T + 9)/8⌉.
* The slot list is transcribed from `SplitLayout::new` (`split_layout.rs:130–147`).
* Everything is exact `Fraction` arithmetic.
* I decoded Sol's 160-byte native claims and compared them field by field. Nothing native was used as an input.

**Results**, for 26 blocks with 12 × G3 and 14 × G4:

| | T128 non-DD | T128 DD | T256 non-DD | T256 DD |
|---|---:|---:|---:|---:|
| N per block | 48,660,480 | 45,645,824 | 118,292,480 | 100,204,544 |
| (main+ext)·deg / zero-check allowance per block | 1,365 / 1,536 | 1,437 / 1,593 | 1,432 / 1,599 | 1,508 / 1,659 |
| claim header (tier, L, T, dd, n, rate, q, mask n/dom/q) | equal | equal | equal | equal |
| lookup, sc, zc, pcs numerators | equal | equal | equal | equal |
| native units = Python port of the native algorithm | equal | equal | equal | equal |
| native units − ⌈exact·2^128⌉ | +152 | +152 | +172 | +172 |
| **exact whole-run bits** | **97.2588** | **97.3118** | **96.2871** | **96.4811** |
| margin to 2^33 (units) | 6.80·10^9 | 6.86·10^9 | 5.07·10^9 | 5.51·10^9 |

* **The one-block dense fixture** (G = 2) agrees as well: 101.85 / 101.90 bits, every numerator equal. It backs the native receipts.
* **The threshold is live.** At all-G4 workloads, my recount admits at most 124 blocks at T128, 63 at T256 and 72 at T256 DD. T128 DD reaches the 128-block cap first.
  * My reviewer test (§7) checks, on the native counter, that each of those maxima passes and that maximum + 1 is refused with "does not meet".
* These figures equal REVIEW_R14 §3 to four decimals, as they must, and equal Sol's `COUNTED_WORKLOAD_BOUNDS.json`.
* Sol's `check_exact_bounds.py` imports my R14 script's geometry, slots and column term; my recount here does not. It also re-derives the per-block numerators independently of both.

## 2. Question 2: who counts the workload

* **The counted inputs are all verifier-derived.**
  * The stage profiles come from `record.shape_at(base)` for the rebuilt model (`split_run.rs:99–110`).
  * The group count is `block.accuracy().groups().len()` for each block, after `check_block`: `check_for_shape` and digest equality with the model-bound `blocks[k]` (`:146–151, 178–185`).
  * `BlockPublic::digest` covers `accuracy.encode()` (`private_block.rs:881–892`), which writes the group count and every group (`accuracy_public.rs:227–228`).
* **The prover supplies only the tier code.** In the CLI, `verify` reads it from `expected.bin` (`trained_split.rs:458–461`). It then runs `with_security_source(tier, PublicBlocks(cache))` over the verifier's own `BlockCache`, built from its own export and the digests from `stack_records`.
  * The verifier never parses the prover's numerators. It only compares bytes against its own recount (§3).
* **The prover runs the identical recount** over its sealed cache (`:292–296`), so an honest claim always matches.
* **What is refused:**
  * a source of the wrong length (`split_run.rs:144`);
  * a block that is not the model-bound block. My test substitutes a block with one changed gain and gets "stage public block differs" (§7);
  * groups 0 or 5, over 128 blocks, and mixed tokens, DD or PCS parameters (`split_security.rs:86–93`). My test exercises T128 + T128-DD and T128 + T256.
* **No under-declaration is possible.** A prover who wants a smaller N would need the verifier to count different public blocks, and those are pinned by `--expect-statement`.

## 3. Question 3: binding before challenges, and the full policy comparison

**The order:**

1. `with_security_source` replaces the plan digest by H(v2 domain ‖ v1 digest ‖ H(claim domain ‖ 160-byte claim)) (`split_run.rs:153–158`; `split_security.rs:170–172`). The claim's ten u64 and five u128 fields are fixed-width, so the encoding is injective.
2. That digest is the context of both joint endpoints and of every boundary spec (`split_run.rs:186–210`). The run binding is H(digest ‖ input ‖ output) (`:211–223`), and the binding and the plan digest are the first two absorbs of the run transcript (`:274–289`).
3. The prover's entropy domain includes the binding (`:429–431`).
4. In `stack-prove`, `with_security_source` runs before either endpoint is prepared and before `bind` (`trained_split.rs:293–306`). It is preceded only by sealing and parity, which draw no challenge.
5. `plan.bind` consumes the plan, and a second `with_security` is refused (`split_run.rs:143`). The order cannot be inverted.
6. Sol's test confirms that the plan digest, the endpoint digest, the binding and the transcript position all change (`split_security_tests.rs:23–44`).

**What the CLI verifier compares** (`trained_split.rs:153–174`):

* the tier read from the policy against the recounted tier;
* policy words 0–2 against the rebuilt plan, model and context;
* the binding;
* and then **`policy(&st, model, context) != bytes`**: all 360 bytes, the full claim encoding included.

Sol's unit test flips one byte in each of the 15 claim fields and confirms all 15 are refused (`:531–559`). The statement JSON, with its `"security"` object and schema `/2`, must equal the verifier's own rendering (`:476–491`).

**Native evidence** that the tiered frame is bound to its claim:

* **The untiered reconstruction is refused.** With the same roots, it refuses Sol's tiered frame (`split_security_tests.rs:82–83`).
  * My rerun shows where: `R14 wire: another run binding`, the header's routing check (§7).
  * Beneath it, the transcript absorbs the binding and the plan digest before anything else. So even a frame that got past the header would diverge at slot 0, the same way R14's foreign boundary roots did.
* **The scalar + 1 mutation** is refused at slot 0, round 0, in both modes.

**R14T-F3 (low; evidence classification).**

* **Location:** `validate_native.py` (the `security` change); `split_security_tests.rs:111`; `NATIVE_ACCEPTANCE.json` stages `tier-refuse-security-{0,1}`.
* **What the refusal is:** these two "bound substitution" refusals flip the last hex digit of `security=` in `statement.txt`. The refusal is the harness's `assert_eq!` of that line against its own recount ("assertion `left == right` failed"). The native verifier never reads that line.
* **Failure scenario:** none for soundness. The risk is that a reader takes these as native or CLI evidence, the way N-r14-1 was for the envelopes.
* **The real evidence:** the CLI-level counterpart is the 15-field unit test above, and the native counterpart is the untiered-reconstruction refusal.
* **Fix:** classify them as harness checks in the report. No code change.

## 4. Question 4: does the minimum fail closed?

| Case | Where | Result |
|---|---|---|
| Below the minimum | `Claim::require` (`split_security.rs:173–176`); `Tier` derives `Ord` in 95 < 100 < 128 order | refused. Native: `tier-minimum-{0,1}-{100,128}`, and my library-API rerun |
| Unrated v1 with a minimum | `Statement::require_tier` (`split_run.rs:240–242`), called by the CLI after `bind_policy` (`trained_split.rs:463`) | refused: "unrated legacy statement has no tier" [library: Sol's `NoRead` test; CLI: read] |
| Tiered receipt, no minimum | `trained_split.rs:459` | refused before the recount [read] |
| Tier code 100 or 128 in `expected.bin` | `from_code`, then `finish` (`split_security.rs:123`) | refused: "only the MVP 95 tier is implemented" [read in the CLI; `finish` refusal run in my test] |
| Unknown tier code, wrong magic or length | `policy_tier` (`trained_split.rs:137–144`) | refused. Only (200, `HLR14IO1`) and (360, `HLR14IO2`) parse [Sol's unit tests] |
| Tier stripped (an `HLR14IO1` prefix of a tiered policy) | `bind_policy`: word 0 is the tiered digest, not the v1 digest | refused, with or without a minimum [read] |
| A malformed value | `Tier::parse` exact match (`:17–22`) | refused. My test covers `""`, `"095"`, `" 95"`, `"95 "`, `"+95"`, `"95.0"`, `"96"` and `"1e2"`. The CLI preflight refuses `unknown` |
| A flag with no value | `flags` (`trained_block.rs:1604–1606`) | refused: "needs a value", exit 2 [read] |
| **A repeated flag** | `flag()` returns the **first** match (`:1614–1616`) | **accepted silently (R14T-F2)** |
| The library API | `Verifier::with_source_minimum` checks before any block I/O (`split_run.rs:547–554`) | refused. Sol's `NoRead` test, and my rerun on the retained frames |

Rows marked [read] rest on reading the CLI. Running them is part of F1's gate: `rv14t_cli.py` covers each one except the flag with no value, which is generic parser behaviour.

**R14T-F2 (low; policy hardening).**

* **Location:** `trained_block.rs:1595–1616`, used by `trained_split.rs:59–72`.
* **Failure scenario:** a relying party's wrapper appends a stricter `--min-security-tier 128` to a base command line that already carries `--min-security-tier 95`. The verifier applies 95 and accepts a 95-bit receipt that the operator meant to refuse.
* The same first-wins rule already applies to `--expect-binding` and `--expect-statement`; this predates the patch. It is not prover-controlled.
* **Fix:** refuse a repeated value flag in `flags()`, or at least for `--min-security-tier`, `--security-tier`, `--expect-binding` and `--expect-statement`, with a unit test.

## 5. Questions 5 and 6: v1, and the liveness fix

### v1 compatibility

**By construction:**

* `Plan::new` and `from_records` still produce the v1 digest with `security: None` (`split_run.rs:111–132`).
* `bind` and `transcript` are unchanged.
* `policy` writes the identical 200 bytes under `HLR14IO1` (`trained_split.rs:122–136`).
* `render_statement` is byte-identical when there is no claim: the only insertion is an empty string, and the schema stays `/1` (`:190–193`).
* The read limit grew from 200 to 360 bytes, but `policy_tier` still accepts a v1 policy only at exactly 200 bytes.
* The `BlockCache` construction moved earlier in both commands. For v1 it performs no extra block reads before the point where it was used before.

**By execution:**

* My build verifies all three saved F1/F2 v1 frames in fresh processes: `dictionary-alias`, `dense-receipt-0` and `dense-receipt-1` (§7).
* Sol's two binaries verify them too.
* The v1 goldens and the R8–R13 receipts lie on paths this patch does not touch. Sol's suite run (843 / 0 / 78) includes them; I did not rerun the full suite.

### The liveness fix (`trained_block.rs:2707–2724`)

* **The PID check.** `pid: u32` comes from a name restricted to ASCII digits (`:2739–2742`, so no sign is possible). It is converted with `pid_t::try_from`, which refuses anything above `i32::MAX`, and filtered with `> 0`, which refuses PID 0. `kill` is therefore only ever called with a single positive PID. **PID 0 (the caller's own process group), −1 (every process) and < −1 (a process group) are unreachable.**
* **The probe.** Signal 0 delivers nothing. `errno` is read immediately: ESRCH means dead and the directory may be removed; EPERM means alive and it is refused; every other value refuses. The non-Unix build refuses.
* **Edge cases.** A zombie or a reused PID reads as alive, which is a conservative refusal and is already documented. A leading-zero name ("0123") reads as PID 123, unchanged from before.
* **What it fixes.** This repairs a real Mac defect, where `/proc` is absent and every PID therefore looked dead. Sol's regression `review_n_r6_b…` passes on Sol's binary and on mine.
* **N-t2 (editorial):** the doc comment at `:2699` still says "(`/proc/<pid>` absent)".

## 6. Question 7, and the CLI gap

**What else changed in production:**

* the optional `security` field and the v2 hash (`split_run.rs`);
* `Verifier::with_source_minimum`;
* the policy, statement and verify branches (`trained_split.rs`);
* `publisher_is_alive` (`trained_block.rs`).

None of them touches a relation, an opening, a challenge or the absorb order of an untiered run. On a tiered run they add only the plan-digest change before the first absorb. **Nothing weakens accepted R14.**

**R14T-F1 (low; evidence, gates registration).**

* **Location:** `trained_split.rs:292–296` (the prove recount), `:456–463` (the verify recount, the minimum and the 360-byte read) and `:190–193 / :476–491` (the `/2` statement).
* **What the evidence covers:** Sol's native gates use the library path through the test harness, on a one-block dense fixture. `CLI_PREFLIGHT.json` has four flag checks, and three of them stop at "--export is required". **No tiered `stack-prove` or `stack-verify` has run on an export.**
* **My attempt:** the guarded `rv14t-cli` job was written to close this gap. It runs a 2-layer tiered prove, 15 fresh verifiers on copies and a 1-layer v1 control on Sol's pinned CLI `82d87bf6…`. It refused at load in 2.5 s:

  ```
  profile.json: /home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors: No such file or directory
  ```

  The tied-table derivation (`tied_tables/derive.rs:10, :235`) needs the source checkpoint, and the checkpoint stayed on the laptop.
* **Failure scenario:** a defect in the CLI-only glue, such as the recount and the verifier sharing one block cache, or the `/2` rendering. It would surface first on a real run.
  * Every such defect I can construct is fail-closed (an honest receipt refused), because acceptance requires both the canonical policy equality and the full native verify.
  * So this is a completeness and evidence gap, not a soundness one.
* **Fix:** run `r14t/rv14t_cli.py` where the checkpoint exists. That is one guarded cpu job, about 8 GiB for about 5 min. Its 18 cases are:
  * honest acceptance and promotion, plus a re-verify;
  * no minimum; minimum 100 and 128; `95.0`;
  * flips of units, lookup, blocks and q; tier code 100; the strip to v1 with and without a minimum;
  * a `/1` statement; an edited `whole_bits_floor`;
  * v1 with a minimum, and v1 honest.

  Then add the result to the candidate's evidence before registration.

**Notes (no fix asked):**

* **N-t3 (scope of the number).**
  * "95" means at least 95 bits for *this receipt's own* backend workload, conditional on A1–A7.
  * It is not the whole application: the classifier and token stages must recount under the tier (N-r14-5(ii)).
  * It is not D27's Llama-3-8B T512 reference workload.
  * The T256 count still assumes the T128 export's 12 / 14 group split (N-r14-7), and T256 has no native proof.
* **N-t4 (the next tiers).** When 100 or 128 are built, the counter must take the lookup challenge field or repetition from the profile, as D27 requires for every tier lever. Today p² is a constant here (`:135`), which is correct for the one implemented tier.
* **N-t5 (order of the minimum check).** The CLI recounts all blocks before it applies the minimum (`trained_split.rs:458–463`), so a below-minimum receipt costs one extra pass over the export before it is refused. The library API checks first. This is a matter of cost, not soundness.
* **N-t6 (not reviewed).** I did not review the tier-aware privacy capture: `capture_header` carries no claim, and that belongs to the privacy lane. I also did not review the fixture and trace restorations (`RESTORED_FIXTURES.json`, `TRACE_RECOVERY.json`).

## 7. My runs [MEASURED, Mac M3 Ultra, shared, n = 1, `watchdog-only`; correctness only]

| Job | Class / declared | What | Result |
|---|---|---|---|
| `rv14t-bound` (×2) | light, python | exact recount (§1) on Sol's `tier-unit-final.log` and on my build's log | all numerators equal; all four profiles conservative; 20,008 + 20,000 rounding cases equal |
| `rv14t-tree` | light, python | 293-file re-hash; tree vs F1/F2 base vs patch; F1/F2 base vs accepted R14 | 293 / 293; delta = patch (12 files, every line); base − R14 = 2 test files |
| `rv14t-build` | build, 3 / 6 GiB | `cargo test --release --offline --locked -j 4 --lib --no-run` on a scratch copy of `source-tree/` (pins re-hashed 293 / 293 before the edit) + `rv14t_reviewer_tests.patch`; copied cargo cache | exit 0, 105.5 s, peak 2.77 GiB; test binary `88e905a6…` |
| `rv14t-tests` | cpu, 2 / 4 GiB | 13 runs, `RAYON_NUM_THREADS=2`, Sol's frames read-only | **13 / 13 as expected**, 28.6 s, peak 1.71 GiB (table below) |
| `rv14t-cli` | cpu, 8 / 12 GiB | CLI tiered gate on Sol's pinned `zk60_split_stack.portable.bin` `82d87bf6…` | refused at load, 2.5 s (F1) |

The 13 runs on my binary:

* **`split_security` (5 passed, 3 ignored).** Sol's three `split_security::tests` and the binding test, plus my `rv14t_count_source_is_authenticated_and_counter_fails_closed`. Mine covers:
  * the substituted-block refusal and the wrong-length source;
  * groups 0 / 5, T128 + T128-DD, T128 + T256, block 129, the empty counter;
  * the admission edge at 124 / 125 (T128), 63 / 64 (T256) and 72 / 73 (T256 DD), with all 128 T128-DD blocks admitted;
  * the eight malformed tier strings, the tier order, and 100 / 128 refused by `finish`.

  All **268 `R14_SECURITY_*` lines are byte-identical to Sol's `tier-unit-final.log`**, and the recount on my log matches every number (`rv14t_bound_mybuild.json`).
* **`split_cli_tiered_policy…` and `split_cli_policy_is_versioned…`:** pass. These are the 15-field substitution test and the v1 exact-length test.
* **`review_n_r6_b…`:** passes. This is the live / dead / foreign / symlink publication regression on macOS.
* **`rv14t_retained_frame_library_minimum` on Sol's `dense-0` and `dense-1`:**
  * `Verifier::with_source_minimum` accepts at 95 and refuses at 100 and 128;
  * the untiered reconstruction is refused with `R14 wire: another run binding`.

  That last refusal is the header's routing check. It sits on top of the transcript binding, which absorbs the binding and the plan digest first, so a frame that got past the header would still diverge at slot 0.
* **Sol's `split_security_native_fresh_verify` on `dense-{0,1}`:** minimum 95 verifies; minimum 100 is refused with "receipt tier is below the verifier minimum".
* **Sol's `split_accepted_control_fresh_process_verify` on the three saved v1 frames:** all verify.

**Not run:** the full Rust suite, any new native proof, and any T256 or classifier work. My build adds only a `cfg(test)` module, so its production code is Sol's.

## Evidence

Everything below is under `results/zk60_d24_review_20261017/r14t/`.

* **The bound recount:** `rv14t_bound.py` / `.json`.
* **The tree check and patch delta:** `rv14t_tree.py`, `rv14t_tree_summary.json`.
* **The reviewer tests:** `rv14t_reviewer_tests.patch`, applied to a scratch copy of `source-tree/` only. The battery is `rv14t_tests.py`, with its results in `rv14t-tests/RESULT.json` and logs in `rv14t-tests/`.
* **The CLI gate driver:** `rv14t_cli.py`, with its refused attempt in `rv14t-cli-attempt.log`.
* **Guard records:** `rv14t-*.guard.json`.

No author, frozen or register file was edited, and none of Sol's files were written. No git writes, no network access.
