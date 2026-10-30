# Token review, round 14: short items (rung R-C3) and the table binding in the library

Reviewer: independent soundness / code review of the frozen token tree `frozen-r14/` (2026-10-29 UTC).
**This is not a privacy review and not a classifier-fidelity review.**

## Verdict

**Round 14 is ACCEPTED on soundness for its scope. No fix is required before the next step.**

In plain words:

* **Short posts.** Before round 14 a post shorter than one chunk (fewer than 23 tokens at the rung) could not
  be proved at all. Now it is proved as one chunk of its true length, and the empty slots after it are filled
  with a fixed public "pad" token. I tried to cheat this in every way the brief lists. The proof refused each
  attempt. The pad slots cannot change the verdict: I checked that in the proof's own equations, not only in
  the honest code, and a cheating prover that makes a pad slot feed the verdict is caught.
* **The table binding (N-r13-1).** The library functions behind prove and verify now accept only tables that
  were rebuilt from the pinned model tensor. A program that links the library directly can no longer hand in
  doctored tables. The only other way to build such tables exists in test builds only, and captures refuse it.
* **No downgrade.** Each of the r12, r13 and r14 binaries verifies only its own receipts. Short receipts work
  only with r14.
* **The lane's evidence is real.** The full suite ran (845 / 0 / 56), the failing-first runs show the 3 reds,
  and the fresh-process proof of a 22-token item ran through the named r14 binary.

There are 6 notes (§9). None is a soundness defect of the shipped CLI. One matters before the app relies on
short items:

* **N-r14-1 (low, app contract).** `label` cannot know how long the post really is. A proof of only the
  first few tokens of a post labels cleanly with `content_total` = that smaller number. The input-owner check
  refuses it, and D45(3) ties each proof to its post. But the app's recipe in `cli/README.md` does not tell the
  app to compare `content_total` with the post's length. Round 14 widens this case: before, a cut-down proof
  still had to cover at least one full chunk (23 tokens); now it can cover any length from 1 up.

## What was reviewed

* **The freeze.** `results/zk60_token_io_r1_20261017/frozen-r14/`: 258 files, manifest
  `manifest_final_r14.sha256`, list sha256 `0b4c429b…` (recomputed).
  * My copy `ops/zkp-mvp/token-io-review-r14-scratch/` matched it file for file before my edits
    (`r14/tree_check_r14.py`, ledger 02:16Z). The frozen tree still matches after all my runs.
  * Against frozen-r13: 14 files changed, 1 added, 0 removed, the same list as the lane's
    `r14/r14A_vs_frozen_r13.txt`. Among native files, only `run_capture.rs` changed (+11).
* **Read in full:** every r13 → r14 diff (saved in `r14/diffs/`): `classify.rs`, `classify_tied.rs`,
  `classify_run.rs`, `classify_cli.rs`, `stage_in_c.rs`, `stage_out_c.rs`, `run_capture.rs`,
  `examples/zk60_classify.rs`, and the test files. I also read the new test file `classify_r14_tests.rs`,
  and native R12b's attention relation: `argument.rs` SC_RS, SC_PV and SC_SZC, plus `causal_mask_at`.
* **My runs.** All guarded and serial, on a shared box, n = 1. Before every launch the queue checked for
  `WINDOW_HOLD` and waited until no other non-light job was live (lean-memory rule).
  * The full suite was **not** re-run. The lane's run is complete (§7) and I found no reason to repeat it.
  * The Shieldstral path (it streams 7.7 GB) was **not** re-run either. Round 14 changes only a test seam
    there.
  * The coordinator's fairness request (~02:55Z) came just as my mutation chain ended. My next build waited
    behind Sol's `release-1-build`, which had started at 02:54:46Z.

Line numbers below are those of `frozen-r14/hashline/src/private_block/`. Evidence paths are under
`results/zk60_token_io_review_r1_20261017/` unless stated.

## 1. Per-item table

| # | Item | Verdict | Where |
|---|---|---|---|
| 1a | N-r13-1: every run entry point takes only `BoundClassifierTables` | **HOLDS** | `token_io/classify_run.rs:90, 103, 224, 231` (signatures); `classify.rs:738, 762` (`new`, `new_chunk`) |
| 1b | the type is constructible only through `load_bound_tables` (re-derivation + comparison), plus one clearly test-only constructor | **HOLDS** | struct `classify_tied.rs:354` (private fields); literals only at `:472` (`load_bound_tables`, `:461`) and `:442` (`synthetic_for_relation_tests`, `#[cfg(test)]`, `:437`); no `&mut` accessor; the crate exports only the four CLI commands (`private_block.rs:126`, `mod token_io` private `:131`) |
| 1c | statement / prove / verify check the binding | **HOLDS** | `check_for` `classify_tied.rs:413–431` called by `new_chunk` `classify.rs:796`; `check_tables` `classify.rs:823` called at `classify_run.rs:123, 243` |
| 1d | the replay refuses synthetic-constructor runs | **HOLDS** | `run_capture.rs:931`; the lane's test plus my `replay` mutant (§6) |
| 1e | no public path re-admits unbound tables | **HOLDS** (N-r14-3: stage-level crate-internal primitives still take raw tables) | `load_classifier_tables` is `#[cfg(test)]` (`classify_cli.rs:241`); grep in §2 |
| 1f | N-r13-6: block and run profile name one tied source | **HOLDS** | `classify_tied.rs:415`; an unregistered run profile has no source, so `describe_under`'s "unregistered" text cannot reach a statement |
| 1g | N-r13-3: one export per test policy | **HOLDS** | `classify_capture_tests.rs:86` (`bind_policy`: a new export profile per placed policy); `Cc`'s swapped policy has its own export |
| 2 | N-r13-2: the stubbed-recompute test fails without the post-derivation check | **HOLDS, reproduced** | check `classify_tied.rs:245`, seam `:255–257`; my `n2` mutant fails the lane's test with "A DERIVATION THAT READ ANOTHER profile.json WAS ACCEPTED" |
| 3 | short items: one chunk `[0, N)`, pads pinned, OUT-C at row P0+N+S−1, empty refused; every attack in the brief | **HOLDS** | §3, §4; `classify.rs:223–227, 412, 431, 493–531`; `stage_in_c.rs:195–209`; `stage_out_c.rs:302`; `classify_run.rs:366, 432` |
| 3c | causality: pad rows cannot reach the verdict row, **in the relation** | **HOLDS** (N-r14-2: the design text cites the witness) | `argument.rs:1053` (public mask), `:1308–1321` (SC_RS), `:1431–1456` (SC_PV), `:1939` (SC_SZC division), `:1817` (DD tuple); my S5 / S5b |
| 3d | nothing beyond D45(1) revealed | **HOLDS** | the four new statement fields and the profile-text terms are functions of (n, T, P0, S, policy); proof length depends on T only |
| 4 | schema `zk60-classify-run/3`; no downgrade either way | **HOLDS** | `classify_cli.rs:95, 395, 667`; my S8 cross-binary matrix (§5) |
| 5 | evidence: s18 845/0/56; r14-red 3 reds; fresh-process 22-id run; Shieldstral digests unchanged | **HOLDS** | §7 |
| 6 | low items: stale docs, /tmp writes, `load_classifier_tables` test-only | **mostly done** (N-r14-2, N-r14-4) | §8 |

## 2. The binding in the library (item 1)

* **One type, private fields.** `BoundClassifierTables` (`classify_tied.rs:354`) keeps its tables, BOS, final
  norm, source, margin parameters, profile digest and model identity private.
  * It has only read accessors. `Clone` copies a bound value; it cannot change one.
  * A grep of `src/` finds exactly two struct literals (`:442`, `:472`). The lane's source-scan test asserts
    the same.
* **The two constructors.**
  * `load_bound_tables` (`:461`) re-derives under `model.calibration.export_profile_sha256` and the
    statement's residual unit, then compares every file (`check_files_against`).
  * `synthetic_for_relation_tests` (`:437`) is `#[cfg(test)]`, marked not-derived. Its only callers are test
    files and `census_classify_statement` (`classify.rs:272`, itself `#[cfg(test)]`).
* **The checks.**
  * The statement constructor runs `check_for` (`classify.rs:796`): the tied source agrees for block and run
    profile, the tables were derived for this trained statement (identity and profile digest), the policy is
    the bound margin parameters, and the width matches.
  * Prove and verify run `check_tables` (`classify_run.rs:123, 243`): same model, profile digest, derived
    flag, embedding and margin digests, BOS and norm as the statement.
* **What remains outside.** The stage-level `stage_in_c::prove/verify`, `stage_out_c::prove/verify`,
  `ClassifierProfile::new` and `honest_classify` still take raw `ClassifierTables` (N-r14-3).
  * They are `pub(crate)` building blocks, not run verifiers: none checks a statement, an input endpoint or
    the whole-run figure.
  * The crate's external API is only the four CLI commands. They all go through `load_tied_classifier_tables`
    (`classify_tied.rs:488`), which also refuses a residual unit that differs from the statement's.
* **The replay** (`run_capture.rs:931`) refuses a header whose `tables_derived` is false. In production builds
  `is_derived()` is constantly true. The field is not absorbed and adds no run.json key.
* **The capture fixture** (N-r13-3, §10 item 1 of REVIEW_R13).
  * `bind_policy` writes a tiny dev export per placed policy. It names that export's profile in a synthetic
    trained statement over the fixture's generic blocks, and loads the tables through `load_bound_tables`.
  * So the gate's rung captures carry the derived margin row `24e6ff4c…`. The blocks are still generic, as the
    bundle note says.

## 3. Short items: the construction (item 3)

For an item of N content ids with `1 <= N < size = T − P0 − S` (rung: P0 = 8, S = 1, T = 32, size = 23):

* **The split.** `chunk_ranges` (`classify.rs:223–227`) refuses N = 0 and returns `[(0, N)]`. The statement
  constructor derives the plan size from the shape and the policy, never from n (`:798`). It then requires
  `n` = the derived chunk's length (`:800`). So a short `n` under a full chunk is refused, and so is a full
  `n` under a short chunk (my S1).
* **The layout.**
  * `tokens_of` is prefix ‖ content ‖ suffix ‖ pad^(T−P0−N−S).
  * `is_template` covers suffix and pads (`:508`); `kappa` gives the pad id there (`:513–520`).
  * `ctl_q` gives `ctl(pad)` there (`:540`).
  * The door refuses N = 0, P0+N+S > T and pad ≥ V (`:412, :431`).
* **The pinning, in the relation.**
  * Stage IN-C's template clause `π(t)·(tok(t) − κ(t))` has its own coefficient (`stage_in_c.rs:195–209`). It
    is zero-checked over every position, so every pad position must hold the pad id.
  * Without π over the pads, a control id other than the pad id would pass the LogUp: the control column is 1
    there. The lane's `pad` mutant shows this, and mine kills it too (S3, id 0 at the pads).
* **The verdict row.** Stage OUT-C's IO claim is at `fixed_bits(cp.verdict_row())` (`stage_out_c.rs:302`), a
  public row the verifier computes from (P0, n, S). The prover's pipeline reads the same row
  (`classify_run.rs:432`, `classify_cli.rs:538`).
* **The owner's check** (`classify_run.rs:357–380`) rebuilds the root and compares the whole plane against
  `tokens_of(content)` (`:366`), pads included. The CLI's `input-owner` refuses a content whose length is not
  the statement's total (`classify_cli.rs:743`).
* **The pad id is bound.**
  * It is a registered policy constant: `registered_policies().contains` compares every field, pad included.
  * It is named in the profile text (`pad-id=`) and so in the transcript.
  * It is in the statement, which is re-rendered byte for byte.
  * Both registered pad ids are control ids: dev 2 < 5, Shieldstral 11 < 1000. So content positions can
    never hold them.

**Causality, in the relation (3c).** The design (§15.2) says the pad rows cannot reach the verdict row
because the witness puts `MASK_SCORE` at masked scores. That alone would not suffice:
* the exp of `max − MASK_SCORE` is in general nonzero;
* what a cheating prover faces is the relation, not the witness.

What actually holds, in native R12b's relation:
* `causal_mask_at(sh)` (`argument.rs:1053`) is a public column, 1 on j ≤ t.
* SC_RS (`:1308–1321`) sums `mask · E`, so the row sum is causal.
* SC_SZC's division clause (`:1939`, `c2 = mask·E·2^F_P − P·Sum − ρ`) has P, ρ and σ in byte limbs, with
  σ = Sum − 1 − ρ ≥ 0, and P·Sum + ρ far below p (about 2^40 at the largest registered shape). At mask = 0 it
  forces P = ρ = 0.
  * On a DD profile, the tuple `(Sum, mask·E, P)` (`:1817`) looks P up as floor(0 · 2^F_P / Sum) = 0.
* SC_PV (`:1431–1456`) sums P·V over every source position s, so a masked weight is the only way in.
* Every other block operation is row-local (norms, RoPE, FFN, residuals). The max selector's value can be
  read only from the row's own scores: at a masked j it equals −127, which is attainable only if every true
  score is −127.

Hence each block's row t is a function of rows ≤ t of its input, and the verdict row P0+N+S−1 is a function
of the prefix, the content and the suffix only. My S5 / S5b test this against a cheating prover (§4).

## 4. Attacks (items 3 and 4)

All in `ops/zkp-mvp/token-io-review-r14-scratch/hashline/src/private_block/token_io/review_r14_tests.rs`
(scratch only). Relation tests (S1–S6) use the lane's relation fixture: the trained-calibration rung, L = 2,
generic tables under the test-only binding. S7–S8 use the CLI fixture `Cc` with the derived tables. Logs:
`r14/logs/rvtk14-detail.log`, `rvtk14-xbin.log`, `rvtk14-s5b.log`, `rvtk14-xbin2.log`.

| Test | Attack | Result |
|---|---|---|
| S1 boundaries | n = 1 (22 pads), n = 22 = T−P0−S−1 (1 pad), n = 23 = T−P0−S (no pad): layout, prove, verify, owner check; n = 0 and n = 24 at the door; short n under a full chunk and the reverse; the opposite verdict | each boundary proves and verifies with item length / pads / verdict row (10, 22, 9), (31, 1, 30), (32, 0, 31); every mismatch refused |
| S2 n declared ≠ actual (verifier) | the 20-id receipt re-stated by the verifier's own constructor as n = 1, 19, 21, 22, 23 (same root and verdict) | all refused ("this segment belongs to another run": n is in the transcript); the owner's check under those statements refuses both the 20-id content and one of the stated length |
| S3 forged layouts (prover) | the cheating prover seals a 20-id plane as n = 21; a 21-id plane as n = 20; the full 23-id plane as n = 20; a 20-id plane as n = 23 (pads read as content); pads inside the content range (n = 23, content tail = pad ids); pads before the suffix (n = 20, suffix at T−1); the suffix id over the pads; content ids at the pads; control id 0 at the pads; another control id at the last pad | all 10 refused at stage IN-C: the template clause (slot 01), or the LogUp's H opening for control ids at content positions. The honest pipeline and the honest prover refuse each before any header |
| S4 verdict row shifted | the margin from row vr−1 (27), vr+1 (29, a pad row), 0 and T−1 (31) instead of row 28 | all refused at stage OUT-C slot 00 (the IO claim at the public row) |
| S5 masked weight | P[h, t, j] forged 0 → 1 at masked entries (t = 28 → j = 29; 28 → 31; head 1, 25 → 30), in both blocks (native D24 forge hook) | all refused (block 0, slot 15: the PV product no longer matches) |
| S5b consistent masked weight | as S5 with P = 64 (1/8) **and** the cheating prover's PV summing over every source position (`pv-all`, scratch only), so P, O and every later plane are consistent and the pad row really moves the verdict row | see §4.1 |
| S6 another pad id | the same 20-id content under pad 2 (dev), 3 (another control id) and 200 (a content-class id), each a registered test policy | each proves and verifies; every block's rows 0..28 are **identical** across the three, the pad rows differ, the margins are equal (5,269,429); each receipt refused under the other pad id's statement, and so is its owner's check; pad 300 (= V) refused |
| S7 CLI coverage and fields (derived tables) | truncation: the 22-id proof offered to the owner of the 23-id post and of a 27-id post; label mixes: short + long chunk 0, short + long chunk 1, short twice, long without chunk 1; `--chunk 1` of a short item; `pad_id`, `pad_positions`, `verdict_row`, `item_length`, `T`, `range` and `schema` edited one at a time in a copy | truncation refused by input-owner both times; every mix refused; chunk 1 refused; each edit refused at the door, nothing published; controls: the honest copy verifies, the 27-id item's two chunks label, the short run labels alone (`content_total` 22, one chunk) |
| S8 cross-binary | see §5 | only the diagonal verifies |

**4.1 S5b, the consistent forgery** [MEASURED, `r14/logs/rvtk14-s5b.log`]. S5's refusals came at block 0 slot
15, where the PV product hosted by the Q zero-check failed. That is because the honest PV sum excludes j > t,
so the forged weight never reached O. S5b removes that crutch:
* A scratch-only switch (`RV14_MUT=pv-all`, `witness.rs`) lets the cheating prover's PV read every source
  position. P, O and every later plane are then consistent with the forged weight.
* With P = 64 (1/8 of 2^F_P), the pad row really reaches the verdict row. For head 3, row 28 → pad row 31,
  the margin moved from 5,269,429 to **5,214,444**. For the other two forgeries the change rounded away.
* All three were **refused at block 0, slot 17, "06 softmax zero-check"**: the division clause, the one
  constraint the analysis in §3 relies on.
* The switch leaves honest witnesses unchanged: the honest control verifies under it. `baseline2`
  (49 / 0 / 6, the same test binary) is green.

So a prover that makes the pad rows influence the verdict is caught by the relation itself.

## 5. Schema `/3` and downgrade (item 4)

* **This tree.** `CLASSIFY_STATEMENT_SCHEMA` is `/3` (`classify_cli.rs:95`). `found_statement` refuses any
  other schema (`:395`), and the door re-renders the whole statement (`:667`). There is no flag or fallback.
  The new terms in the profile text change the classifier profile digest, so a relabelled statement cannot
  re-render either.
* **S8** [MEASURED, `r14/logs/rvtk14-xbin.log`, `rvtk14-xbin2.log`]. The fixture's full 23-id item was proved
  by each of the lane's frozen binaries: r12 `04036e26…` (schema `/1`), r13 `e320c237…` (`/2`) and r14
  `48dac988…` (`/3`), each command its own process. Each receipt was verified by each binary, a fresh copy
  per verify:

  | receipt \ verifier | r12 | r13 | r14 |
  |---|---|---|---|
  | r12 (`/1`) | **0** | 1 | 1 |
  | r13 (`/2`) | 1 | **0** | 1 |
  | r14 (`/3`) | 1 | 1 | **0** |

  * The 22-id short item: r14 proves it; r12 and r13 refuse the prove. r12 and r13 refuse r14's short
    receipt; r14 verifies it.
  * Upgrade: r13's segments under r14's statement, with r13's root, are refused by r14. Downgrade: r14's
    segments under r13's statement, with r14's root, are refused by r13.
  * An r13 receipt relabelled `/3` is refused by r14.
  * This tree's in-process verifier refuses the r12 and r13 receipts.
* The trained statement identity is the same under all three binaries (`061340df…`). Only the schema and the
  profile text tell the rounds apart, as REVIEW_R13 found. The README now says R-C1 receipts support no
  classifier claim (N-r13-8, done).

## 6. Mutation runs (items 1–3)

`RV14_MUT=<name>`, a `#[cfg(test)]` switch in my scratch only. One test build; each mutant ran the lane's whole
`token_io::classify*` set plus my S1–S7: 49 tests, which all pass on the baseline [MEASURED, about 60 s each,
peak 0.76 GiB]. A mutant is killed when a baseline-green test fails. Table: `r14/mutation_table_r14.{py,json}`.

| Mutant | What it removes | Sound without it? | Killed by the lane | Killed by mine |
|---|---|---|---|---|
| `n2` | the post-derivation profile-digest check (`classify_tied.rs:245`) | no (Shieldstral) | yes: "A DERIVATION THAT READ ANOTHER profile.json WAS ACCEPTED" | n/a (stub test is the lane's) |
| `pad` | π over the trailing pad positions (`stage_in_c.rs:195`) | **no**: a short-item forgery verifies | yes | S3 (control id 0 at the pads verified) |
| `bind` | `check_for`'s trained-statement test | partly (prove / verify's `check_tables` still refuse) | yes (message) | — |
| `src` | `check_for`'s N-r13-6 agreement | yes (the next check refuses) | yes (message) | — |
| `check-tables` | prove / verify's `check_tables` | no against a confused library caller (the proof refused the honest receipt only because it was made with other tables) | yes | — |
| `n-free` | `n` = the chunk's length (`classify.rs:800`) | **no**: a statement claims a range its proof does not cover | yes | S1 |
| `size-from-n` | the plan size from the shape (`:798`; r13's behaviour) | **no**: a prover-chosen split | yes (3 tests) | S1, S2, S7 |
| `vr-last` | the verdict row (`verdict_row()` = T−1) | no: the verdict read at a pad row | yes (4 tests) | S1, S4, S5, S6, S7 |
| `replay` | the replay's derived-tables refusal (`run_capture.rs:931`) | capture hygiene | yes | — |
| `empty` | `chunk_ranges`' N = 0 refusal | yes (the door refuses n = 0) | yes | S1 |

**All 10 are killed.** Every unsound one is killed by at least one of the lane's own tests. `src`, `empty` and
part of `bind` are defence in depth: the kill is on the refusal message, and a later check still refuses
(N-r14-5).

## 7. Evidence (item 5)

From the lane's logs, re-tallied by me:
* **s18** (`r14/logs/s18-suite.log`, guard record `s18-suite.guard.json`):
  * exit 0; 29 `test result` lines summing to **845 passed, 0 failed, 56 ignored**; 845 `... ok` lines;
  * all 14 new round-14 tests `ok`, and the binary test ignored;
  * 838 s, peak 7.22 GiB, cgroup + watchdog, TMPDIR and `HL_TIO_FIXTURE_DIR` outside the repository.
* **r14-red** (`red-tests.log`): exit 101, **0 passed, 3 failed**, 1 ignored. The three are exactly the
  claimed ones:
  * "THE LIBRARY PROVED AND VERIFIED A DOCTORED MARGIN ROW (N-r13-1)";
  * the short item refused by name;
  * "the capture fixture's margin row is not the one derived".

  `red-r13-binary.log`: the frozen r13 binary refuses the 22-id prove in a fresh process ("short content is
  not built").
* **The fresh-process 22-id run** (`bin-short-r14.log`): 1 passed, with `HL_PB_CLI_BIN` = the r14 binary.
  * I recomputed its sha256: `48dac98818f7…`, equal to `cli/binaries_r14.sha256`.
  * My S8 repeats it independently: r14 prove, then verify in separate processes.
* **The Shieldstral path** (`shieldstral-r12b.log`): 1 passed. Embedding `baff04d2…`, margin `1f5cb346…`,
  span −32767..31800, BOS 1, norm (127, 1024, 10, 2439): byte-equal to round 13's log (14.4 s warm against
  17.3 s).
* **The lane's mutation logs** `mut-{n2,pad,bind}.log`: each 0 / 1 / 0 (killed), and the pre- and
  post-mutation manifests are equal.

My runs [MEASURED, shared box, n = 1]:
* build 181.6 s, peak 2.21 GiB;
* baseline 49 / 0 / 5, 60.7 s, 0.76 GiB;
* detail 7 / 0 / 1;
* xbin 1 / 0;
* 10 mutants, 56–64 s each, peak 0.65–0.82 GiB;
* all under cgroup + watchdog.
* build2 (incremental, S5b added) 199.6 s, peak 2.15 GiB;
* s5b 1 / 0, 13.9 s, 0.22 GiB;
* xbin2 1 / 0, 10.0 s;
* baseline2 49 / 0 / 6, 62.3 s, 0.76 GiB.

The S8 refusal reasons (`rvtk14-xbin2.log`):
* r12 and r13 refuse the short prove by name ("short content is not built");
* the short receipt by schema ("not schema …/1", "…/2");
* the upgrade and the downgrade by the proof ("this segment belongs to another run");
* the relabelled `/3` statement at the door ("not byte for byte the canonical statement").

## 8. Low items the lane claims done (item 6)

* **N-r13-10.** `load_classifier_tables` is `#[cfg(test)]` (`classify_cli.rs:241`). The doc-comment slip in
  `classify_tied.rs` is fixed. **Done.**
* **N-r13-9 (the `Cc` fixture's /tmp writes).** `fixture_root` (`classify_cli_tests.rs:136`) is
  `HL_TIO_FIXTURE_DIR` or `$HOME/zk60-artifacts/token-io/test-fixtures`. **Done for the classifier
  fixtures.**
  * Residue (N-r14-4): the next-token fixtures `cli_tests.rs:74–75` and `r3_tests.rs:321, 588` still use
    `std::env::temp_dir()`. s18 set TMPDIR, so nothing reached /tmp.
* **N-r13-4 (stale documents).** Done:
  * DESIGN §14.2 now names the export profile as the authority;
  * §14.3 gives the 17.3 s warm figure;
  * the README's statement section names `/3` / `/2` / `/1`, and its R-C1 note says the margin vector is
    re-derived.

  Still stale (N-r14-2): DESIGN's ruling table rows C-4, C-5, C-6 and C-8 (lines 33–37) and the §5 / §6
  headers (lines 271, 279, 294) say "[RULING PENDING]" after D45. Only §3.4 and §15 were updated.
* **N-r13-8.** The README says R-C1 receipts support no classifier claim. **Done.**
* **N-r13-5** (two checkpoint streams per Shieldstral call). Open, as the lane says; nothing at Shieldstral is
  registered.

## 9. Findings

None is a soundness defect of the shipped round-14 CLI.

* **N-r14-1 (low, app contract; close before Astra's adapter drops its short-item refusal).**
  * What happens now:
    * `label` checks that the chunk runs cover `[0, content_total)` of one item;
    * it cannot check `content_total` against the post;
    * the README's "How an app drives it" does not tell the app to compare the two.
  * The case: a truncated proof set (the first N ids of a longer post, N ≥ 1) labels exit 0. So do two
    short items standing for one post. Before round 14, such a set covered at least 23 ids.
  * The defences:
    * `input-owner` refuses a content of another length (`classify_cli.rs:743`; my S7, for 23- and 27-id
      posts);
    * D45(3) ties each proof's sealed input to its post.
  * Suggested fix: `label --expect-total N` (N is public by D45(1)), and one README line: the app checks
    `content_total` = the post's token count, with one item per post.
* **N-r14-2 (low, documents).**
  * DESIGN §15.2 gives the witness's `MASK_SCORE` as the reason the pad rows cannot reach the verdict row.
    The reason that holds against a cheating prover is the relation (§3 above: the public causal mask in
    SC_SZC's division clause or the DD tuple, SC_RS and SC_PV). Cite that.
  * The DESIGN ruling table and the §5 / §6 headers still say [RULING PENDING] (§8).
  * `ctl_q`'s comment ("0 at content and pad positions", `classify.rs:538`) predates the trailing pads, which
    now carry `ctl(pad)`.
* **N-r14-3 (info, API).** The type boundary sits at the run level. The stage-level primitives and
  `ClassifierProfile::new` are still `pub(crate)` with raw tables. Narrowing them to `pub(super)` would make the
  module boundary enforce N-r13-1 as well. No external path exists today.
* **N-r14-4 (low, hygiene).** The next-token fixtures still default to `/tmp` without TMPDIR (§8).
* **N-r14-5 (info, evidence).** Three of the round's checks are defence in depth (`src`, `empty`, half of
  `bind`). Their tests kill the mutants only by the refusal message, which is fine. The load-bearing ones are
  all killed by behaviour.
* **N-r14-6 (liveness, carried from the lane, Shieldstral).**
  * Scores of masked entries are still computed and range-checked (`witness.rs:702`: "an out-of-range masked
    score still refuses"), and pad rows run every block.
  * So a short item can be unprovable where the full-length one is not, and D45(4) then fails it closed.
  * Measure this when the Shieldstral classifier run profile is registered, with its pad id 11.

## 10. What the privacy gate must cover for short items (C-13)

Round 14 took the trailing-pad route. **It does not create T < T_pad:** the blocks run at the profile's T,
and the pad rows are ordinary rows. Their token ids are public, but their activations depend on the hidden
content, through attention to earlier rows. The gate's padded-position zero rules (rows ≥ T) do not apply to
them. What the gate must cover before any figure about short items:

1. **The input endpoint.**
   * In stage IN-C's joint view, the pad positions `P0+n+S .. T` are public, known words, like the template
     positions.
   * The count of public words now varies with n: from P0+S up to T−1. At n = 1, one hidden id remains.
   * The disclosed-rank / CFS computation must take the pad words as known constants at each n.
2. **The pad rows' planes in every block** (and the masked score entries from content-row queries to
   pad-row keys) are hidden witness. They are functions of the content, so they must sit in the hidden set
   exactly like content rows.
3. **The verdict row moves with n.**
   * Stage OUT-C's IO claim opens `B_out` at row P0+n+S−1, not T−1.
   * Re-check that this opening discloses nothing beyond the verdict, at several n.
   * Row T−1 is now a pad row whose value is never opened.
4. **Captures.**
   * Re-capture at n = 1, 22 (= T−P0−S−1) and a middle value, at verdict 0 / 1 / tie.
   * Use derived tables: `capture_a_classify_rung_run` with `HL_PB_CLASSIFY_CHUNK=0/<n>`, each placed
     policy with its own export.
   * Add the P-18 CLI path through the r14 binary for one short item.
5. **The statement allow-list** gains `item_length`, `pad_id`, `pad_positions` and `verdict_row`. Confirm they
   are functions of (n, T, P0, S, policy). They are, by construction (`classify_cli.rs` render). Also confirm
   the receipt length does not depend on n.
6. **Refusals.** Pad rows can trip range refusals (N-r14-6), so whether a short item proves depends on its
   hidden content. Count pad-row refusals in the refusal analysis.
7. **Small n.** At n = 1 the public verdict is a function of one hidden id. D45(1) and (2) accept this. The
   classifier privacy statement should say it in plain words (the entropy left in a short post), as a
   property of the rulings, not a proof defect.

## Evidence

Everything is under `results/zk60_token_io_review_r1_20261017/` unless a path says otherwise.

* **Ledger:** `PROGRESS_R14.md`.
* **Tree check:** `r14/tree_check_r14.{py,json}`. The json was last written after my edits, so it lists my
  scratch's 8 edited files. The frozen tree shows 0 changed / missing / extra.
* **Diffs:**
  * r13 → r14, per file: `r14/diffs/`;
  * my scratch against frozen-r14: `r14/review_scratch_vs_frozen_r14.diff`. 8 files: the test module, the
    `RV14_MUT` switch and its 10 sites, the forge wrappers and the `pv-all` switch, all test-only.
* **Queues:** `r14/run_rv14.sh`, `r14/run_rv14_post.sh`. Logs and guard records are in `r14/logs/`
  (`rvtk14-*`, `queue.out`).
* **Mutation table:** `r14/mutation_table_r14.{py,json}`.
* **Scratch tree:** `ops/zkp-mvp/token-io-review-r14-scratch/`. Fixtures and TMPDIR:
  `~/zk60-artifacts/token-io/review-r14-tmp/`, synthetic public data only.
