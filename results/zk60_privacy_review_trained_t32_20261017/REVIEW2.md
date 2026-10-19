# Independent adversarial privacy review, round 2: the revised trained TinyLlama T32 draft, the R5b evidence and R6

Reviewer: the same independent Claude Opus 5.5 agent as round 1 (`REVIEW.md`).
I did not write the draft, the gate tools or the native code.
- Round 2 opened 2026-10-18 04:40 UTC and was cut off by the usage limit at
  about 04:50.
- It resumed 2026-10-19 09:25 UTC and was written 09:25-09:30 UTC.

It was paper only: no builds, proofs, git writes or heavy jobs, and the only
code run was short read-only `python3 -I` checks. The ledger is `PROGRESS.md`,
section ROUND 2.

**This is not a privacy acceptance.** It advises the security owner. Rulings
are Victor's.

**Objects:**
- the revised draft
  `results/zk60_gate_tinyllama_20261017/PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md`.
  It was last changed 2026-10-18 04:43 UTC and has not moved since; its §3b
  maps my P-1..P-22.
- the gate's R5b evidence `results/zk60_gate_tinyllama_20261017/r5b/` and its
  ledger, round 5 table;
- the gate tools v6, `gate-tinyllama.tools.frozen.v6.sha256`. The live
  `scripts/` equal the manifest, 53 of 53 files [checked];
- the native R5b freeze `results/zk60_1b_native_20261017/r5b/frozen-tree/`
  (2026-10-18T00:06:31Z, tree `44013397…`);
- the native R6 freeze `results/zk60_1b_native_20261017/r6/` and its patch
  `r6-vs-r5b.patch`;
- the soundness verdicts `results/zk60_d24_review_20261017/R5_VERDICT.md` and
  `R6_VERDICT.md`.

Labels:
- **[READ]**: a source line or record I read;
- **[MINE]**: my own reading, checked by nobody else;
- **[COUNTED]**: exact arithmetic.

---

## 0. Verdict, in plain words

**Close, but not yet acceptable.** Both round-1 blockers are closed:
- the CLI sealing and publication rules (P-1): repaired in R5b, and R5b's
  remaining publication defect r5_A closed in R6;
- the gate's unenforced pins (P-2): repaired in tools v5 and v6.

The gate re-ran everything on bundles captured from the post-port tree R5b,
on both inputs at L = 1, 2 and 22. Every pass is green except G-4's known
wording criterion. The root-rebuild check passes on R5b. Nothing I found in
round 2 leaks hidden data.

**What still separates the draft from an acceptable statement is mostly
procedural and textual, not mathematical:**

1. **Name R6, not R5b.** The statement must name R6 (or its integrated
   successor), because R5b's CLI still has r5_A, the unbound promotion of the
   statement directory. R6 changes six files the gate pins.
   - My reading of the diff: for this calibration, R6 moves **no random draw
     and no absorbed byte**, so the R5b figures carry over in substance.
   - But the statement's own condition 7 requires the gate to read those six
     pins and re-run (cheap: L = 1 and 2 in full, L = 22 pass A). One capture
     through the CLI's own path, already planned, belongs in the same re-run.
2. **G-7 is still owed.** The non-linear machine check and the terminal
   surjection have not been run at the trained export.
3. **The root-rebuild check covers one stage and one boundary.** It does not
   yet cover a run's stage loop. Either extend it to L = 2 (cheap), or the
   owner accepts the present scope in writing.
4. **The text needs a consolidation pass.** It still mixes three evidence
   generations (tree A, R5, R5b). It describes R5b's promotion rather than
   R6's verifier-written statement. It omits R6's unauthenticated writer
   label (N-r6-a), and it over-claims the backend field as an audit rather
   than a self-report.

   R6's `prover_reported.backend` is a new, short **free-text field** that the
   verifier republishes. It needs the same condition as the context label
   (C-R4).

**One owed item shrinks.** With R6's lookup-miss refusal (CS-3) moved into
the sealing pass, the refusal census (GN-1 / GS-14) is no longer a condition
of the privacy sentence. It becomes a completeness question (Q-7); the
owner should confirm this.

**The closed list is in §5.**

---

## 1. What I read (round 2)

- The revised draft, all of it, including §3b.
- `R5_VERDICT.md` and `R6_VERDICT.md`.
- The gate ledger's round-5 results and the round-6 opening. Round 6's
  sub-lanes (G-7, the census, tools v7, P-18 on R6) have left no evidence
  directories.
- **R5b source:**
  - `stack_prove_inner`, `stack_verify_inner` and `promote_statement`;
  - `label_of`, `c_r1`, `SeqSource`, `refuse_prover_private_entries` and
    `load_seq_dir`;
  - `PARITY_REFUSAL`, and the sealing pass's refusal sites.
- **The R6 patch:** the `protocol.rs`, `run.rs`, `shape.rs` and
  `trained_statement.rs` hunks. In R6 `trained_block.rs` itself: the writer
  and prover-claims code, the sealing-pass CS-3 call, and the fallible calls
  in `prove_core`.
- **Tools v6:**
  - the driver's pin enforcement (`zk60_native_rg_m125.py:275-278, 482-485`);
  - the status classifier (`zk60_native_rg_status.py` `explain`, `classify`);
  - the export check;
  - the schema check;
  - M9-3.
- **The R5b records:**
  - every status file;
  - pass F (dense), including its pins, stage 14 and CH-1..CH-7;
  - pass T's M9-3 refusal texts;
  - the capture, schema and TL-4 logs;
  - the stage-47 logs.

---

## 2. P-1..P-22 against where the draft says they landed

States:
- **closed**: done, and the draft text matches;
- **partly**: done in code or evidence, but the text or scope still lags;
- **open**: not done.

| # | Where §3b says it landed | What I find | State |
|---|---|---|---|
| P-1 | R5b sealing before the header; unverified statement until `stack-verify`; loud removal | **True in R5b** [READ, `trained_block.rs` 1973-2045 `seal_and_record` / `fail_run`; R5_VERDICT §2]. R5b's promotion is not bound to what was verified (r5_A): it can promote extra prover files, a forged `statement.json` or a symlinked directory. **R6 closes r5_A**: the verifier writes the statement from its own rendering and the verified bytes' hashes (R6_VERDICT §1). R6 also moves CS-3 into the sealing pass (`trained_block.rs:2073`), so H-1 is now code, not an argument. The draft's §3 step 4 and §6 still describe R5b's promotion | **closed in code (R6)**; text partly (Q-3, Q-5) |
| P-2 | Tools v5: pins enforced, stages suspended, PASS needs explained leaves | True [READ]: the suspension map is enforced at load, `ok` needs the pins' `ok`, and PASS needs every false leaf explained by (a) or (e), with no non-bool leaf and no raised stage. R5b pass F: pins ok, 0 false leaves | **closed** |
| P-3 | §5 rows C-R1, C-R4, C-R5; R5b label allow-list | True [READ]: `label_of` admits only `zk60-trained-stack`; `c_r1` refuses a 40-byte context input. New in R6: a C-R4-class free field (Q-2) | **closed**; new item Q-2 |
| P-4 | §2 hypothesis, §5 row, §6 | Folded as a hypothesis. It remains an operating condition, as it must | **closed** (as a hypothesis) |
| P-5 | `--seq-dir`; the verifier refuses `seq_*` | True [READ, :1289-1321]. The guard is on top-level names only (N-r5-b), so the operating rule in §6 stays | **closed** (with the rule) |
| P-6 | `PARITY_REFUSAL` constant; generic sequence errors | True [READ, :1122, :1022]. Builder refusals still name the **layer** and the check site (`:2011`), which depends on the hidden input. They are acceptable only under §6's prover-private-stdout rule, which the draft keeps | **closed** (with the rule) |
| P-7 | R5b records `backend` | Recorded, but as a **self-report** (R5 N-r5-c; R6 labels it `prover_reported`, N-r6-e). The draft's §6 says "the scope can now be audited from the artifact", which over-claims. Its §1 "Path" row still says `statement.json` does not record the backend, which is stale. CPU-only stays an operating rule, tied to a named binary digest | **partly** (Q-4) |
| P-8 | §0, §2 admissible defined | True. R6 adds CS-3 to the sealing predicate, so "admissible" should list it (Q-7) | **closed**; refine with Q-7 |
| P-9 | Export cross-check E1-E4 | True [READ]: R5b pass F stage 14 ok, no findings; the 22-block identity equals the native CLI's | **closed** |
| P-10 | Closed schema S1-S3 | True: all six R5b bundles have their keys on the allow-list and `arrays.bin` covered exactly [READ, `r5b-schema-six-bundles.json`] | **closed** |
| P-11 | Classifier negatives, CT-4 / CH-6 fire, M9-3 named | True [READ]: CH-6 fires in R5b pass F (CH 7 of 7); M9-3 is named when skipped, and pad-state errors fail it. Only G-4's criterion remains (Q-8) | **closed** |
| P-12 | Stage-47 passed on R5b | True [READ, the three `gr4-*.log`]: block dense and zero, and boundary B_0, all PASS, with non-vacuity shown. Scope: one stage of a one-block run plus B_0's preparation. Not covered: the stage loop for L ≥ 2, the production prover on OS randomness, and ordering at the endpoints | **partly** (Q-6) |
| P-13 | CS-2 / CS-5 unnecessary on code facts; census owed | The reading has been adopted by the coordinator, but it is not a register ruling. The census is owed, but with R6 it leaves the privacy list (Q-7) | **partly** (the owner confirms) |
| P-14 | §4 reading | Folded | **closed** |
| P-15 | §3 step 2 | Folded, but the same paragraph still says the CS-3 / S38-F1(a) rulings are "absent … untested … not yet captured", which is stale since R5b | **closed**; text Q-5 |
| P-16 | §4 table | Folded (B10, the split tag-key rows, 10^6, the L = 1 provenance) | **closed** |
| P-17 | §0, §10 | Folded for round 1. Rounds 4-5 left new stale text (Q-5) | **closed**; text Q-5 |
| P-18 | §1 evidence path | Folded as wording. The capture through the CLI's path is planned on R6 in gate round 6, and not done | **open** (in Q-1) |
| P-19 | §1 coverage | Folded | **closed** |
| P-20 | TL-4 | 3 of 3 at L = 22 on tree A and on R5b [READ, `r5b-tl4-l22.log`] | **closed** |
| P-21 | G10-5..G10-8 | 8 of 8 on R5b at L = 1, 2, 22 | **closed** |
| P-22 | §4 note for the owner | Folded. The owner's page still has to print the figures | **closed** (as text) |

---

## 3. New findings, round 2 (Q-1..Q-8)

Severity scale, as in round 1:
- **blocking**: acceptance is impossible even after the owed list closes,
  unless repaired or ruled;
- **must-fix**: required before acceptance;
- **wording**: text only, no figure moves.

### Q-1 — must-fix (procedural). The statement must name R6 or its integrated successor, and the gate must read R6's six changed pins

**Facts [READ].**
- R6 changes six pinned files: `run.rs`, `protocol.rs`, `shape.rs`,
  `private_block.rs`, `trained_block.rs` and `trained_statement.rs` (gate
  ledger, round 6).
- The gate's evidence is R5b's.
- R5b's own CLI still has r5_A, so the statement should not name R5b.

**Why the substance carries [MINE, from the patch].** For `pg_rot1_export_T32`,
every R6 prover-path hunk is inert or prover-private:
- `protocol.rs`: the CS-3 histogram loops are moved into two helpers with
  identical bodies, plus the new `check_lookup_misses`, which runs before
  anything is public.
- `run.rs`: `stage_shape(k)` is the run shape whenever no layer carries its
  own `sh_s`. This export's `sh_s` is run-wide (6, not in
  `per_layer_constants_differ = [exp_e_s, silu_member]`), so the schedule
  lines are unchanged.
- `run.rs` also adds hashing of the verified bytes, which is verifier-side.
- `shape.rs`: `with_score_shift` is only called for a per-layer `sh_s`.
- `trained_statement.rs`: `sh-score-layer` is encoded only when present, so
  the identity bytes are unchanged. R6_VERDICT confirms that run-wide
  identities are unchanged on two other exports.
- No draw site is touched.

**Why it still matters.** Condition 7 is the D22 discipline: a changed pinned
file suspends step 3 until it is re-read, re-pinned and re-gated.

**Repair.**
- Tools v7 reads R6's digests.
- Re-gate on R6 captures: L = 1 and 2 in full, plus the 22-block pass A,
  about 12 min. If the reading holds, the figures equal R5b's in kind.
- Do the planned CLI-path capture (P-18) on R6 in the same round.
- A full 22-block pass F is owed again only if a hunk turns out to move a
  published byte.

### Q-2 — must-fix. R6's `prover_reported.backend` is a free published field (the C-R4 class)

**Location.** R6 `trained_block.rs`, `ProverClaims::of_statement` (the lines
after 2178). `stack-verify` copies `prover_reported.backend` from the prover's
statement into the published one when the prover's statement is canonical.
The field may be any printable string of up to 256 characters (R6_VERDICT
attack (c'), N-r6-e: "published under `prover_reported` (by design)").

**Why it matters.** It is prover-chosen text in the published object. That is
exactly the class C-R4 closed for the context label: a deployment that put
request- or input-derived text there would make the public statement a
function of the input. The honest CLI writes `gpu::label()`, which on a CPU
build is the constant "gpu: off (built without --features gpu-cuda)" (R6
`gpu/mod.rs:744-746`). So nothing leaks today. But the rule is missing from
the draft, and the verifier enforces only the field's length.

**Repair.**
- Add a §5 / §6 condition: the `prover_reported` fields are the build's
  constants, never derived from a request or an input.
- The statement covers a run only if `backend` is the CPU build's label and
  `gpu_declines = 0`, and these are self-reports (Q-4).
- Cheapest code repair: the verifier admits only an allow-listed backend
  label, as `label_of` does for the context label.

### Q-3 — must-fix (wording). M-9's publication rule must follow R6 and N-r6-a

**Location.** The draft's §6 M-9 bullet says "publish only a directory whose
statement was promoted". That is R5b's mechanism.

**Fact.** In R6 the verifier writes `statement/`. But the writer label is
unauthenticated (N-r6-a): a prover can write a canonical `statement/` that
names `stack-verify` as its writer. The directory's existence therefore never
proves that a verification happened.

**Repair.** Restate M-9 operationally: a run directory is published only by a
party that has itself run `stack-verify` on it and seen `statement-published`
or `statement-checked`. Never publish on the directory's existence or its
writer label. A non-verifying directory is a rejected receipt (D21).

### Q-4 — must-fix (wording). P-7 is over-claimed in one place and stale in another

The draft's §6 says the backend field means "the scope can now be audited from
the artifact". It cannot: CPU and GPU receipts have the same form, so the
field is a self-report (N-r5-c, N-r6-e). The §1 "Path" row still says
`statement.json` does not record the backend.

**Repair.** One sentence in both places: CPU-only is an operating rule; the
artifact carries the prover's self-report of it; the deployment binary is
named by digest (R6 `binaries.sha256`).

### Q-5 — must-fix (wording). Consolidate the text on one evidence basis

The draft now carries tree A, R5 and R5b side by side, and several sentences
still speak of tree A as "the captured tree":
- §3 step 2: GS-12, "Both rulings are absent … untested";
- §5 rows 4, 7 and S ("CS-3 … ABSENT from the captured tree", "pinned by no
  bundle", "absent from the captured tree");
- §7 G-1 ("Still blocking: capture from R5b") and G-8 ("untested and not yet
  captured");
- §8: "every bundle here is of the pre-port tree", which is false now;
- the §10a header: "closed means the work is done on the CAPTURED (pre-port)
  tree";
- §1 "Evidence path", which still says R5.

§0 and §3 step 3 quote the tree-A figures (25,005,697, 24,976,715), while the
R5b figures (24,987,331, 24,961,026, and so on) appear only in §10a and the
ledger.

**Repair.**
- One evidence column for the named tree (R6 after Q-1, or R5b until then),
  with tree A and R5 moved to a history section.
- §3b and the tables updated to that column.
- §8 corrected.

### Q-6 — must-fix, or an explicit owner acceptance. G-R4's machine check stops at one stage

**Facts.** The stage-47 replay (R5b `gr4-*.log`) rebuilds A, M and H for
stage 0 of a one-block bound run, and boundary B_0's preparation, from the
seeded stream. It checks the consumed byte counts and shows non-vacuity.

The draft lists what it does not replay:
- the stage loop for L ≥ 2 (B_k drawn before A_k, and stage k on the stream
  after stage k−1);
- the production `prove_run` on OS randomness;
- ordering at the endpoints (checked in place only).

Ruling R-3 asked for every draw of a **run** accounted for by role. That was
never met at 125M either.

**What is covered.** The copy-mutation class (m1, m2, m4) lives in the
per-commitment construction, which the check covers. What is not covered is
cross-stage reuse, for example a stream reset between stages. The generator
not being `Clone` covers that at the type level.

**Repair (either one):**
- extend the seeded replay to L = 2 (stage 1 after B_0 on the same stream; a
  few seconds); or
- the owner records that the present scope plus the non-`Clone` generator
  suffices.

### Q-7 — reading that shrinks an owed item. With R6, the census is no longer a condition of the privacy sentence

**Facts [READ].**
- R6 runs `check_lookup_misses` (CS-3: byte, exp and activation misses) on
  every sealed witness before the run header (R6 `trained_block.rs:2073`).
- The fallible calls in R6's `prove_core` are:
  - shape checks;
  - `refuse_lookup_misses` (CS-3);
  - the LogUp `inverses` (the S-4 event);
  - `argument(…)`, whose refusals are challenge-only (c, e, ν, ζ: the
    round-1 recount);
  - `check_opening`, which is challenge-only (proximity determinants, group
    coefficients).

**Reading [MINE].** Define "admissible" as R6's sealing predicate: the door,
the builder, parity, and CS-3. Then for every admissible input:
- `prove_core` never reaches CS-3;
- every witness-side LogUp argument is a table row;
- so whether an attempt is refused is a function of the challenges and the
  public tables. This is the §2 clause, now by code.

The refusal census at the trained constants then answers a different
question: **how many honest inputs are refused** (completeness and utility).
It no longer bears on the privacy sentence.

**Repair.**
- §2's admissibility definition gains CS-3.
- §10b item 4 moves from the privacy list to a completeness item.
- The owner confirms. A sub-lane can also check that list of `prove_core`'s
  fallible calls in a few minutes.

### Q-8 — wording (tool). G-4's criterion: the control fires, but for a different reason than its criterion expects

**Facts [READ].** In R5b pass T, M9-3 makes each unpadded domain
(D, Kv, Q, S, T) look padded. The host slot refuses each time, so it fires
5 of 5, but with "the port declares N public tables, the capture has N−1". It
never mentions "definition draws". So `the_refusal_names_the_two_numbers` is
false, and for D and S `only_this_slot…` is false too, because their
indicators gate other slots.

**Risk assessment.**
- Not a false negative for the privacy figures: the terminal identity fails
  closed (honest 506 / 506; a wrong pad state refuses).
- But loosening the criterion to "any refusal by name", as first proposed,
  would let a refusal for an unrelated reason count as the control firing.

**Repair (v7).** Accept the refusal only if it names the host slot's
indicator mechanism (the public-table count or the definition-draw count),
and record which. Keep "only the slots `pad::indicator_slots` lists stop".

---

## 4. Does it matter that the gate's evidence was captured on R5b, not R6?

**For the figures: no, by reading. For the statement: yes, procedurally.**

- **What the gate measures is the receipt**, from capture bundles produced
  through the shared prover core. For this run-wide calibration, R5b → R6
  moves no draw site and no absorbed byte (Q-1). The R5b figures therefore
  describe R6 receipts of `pg_rot1_export_T32` as well [MINE].
- **What changed in R6 is outside the gate's view:**
  - the published `statement.json` is now schema /2, with
    `statement_written_by` (one of three constant strings) and
    `prover_reported` (Q-2);
  - who writes it changed (Q-3).

  These are covered by conditions and operating rules, not by gate figures.
- **The statement must still name R6**, for two reasons:
  - R5b's CLI has r5_A, and on R5b, CS-3 still runs mid-run (N-r5-a, closed
    in R6);
  - condition 7 suspends step 3 until R6's six changed pins are read and the
    gate re-run (Q-1). That is cheap and, if my reading holds, moves no
    figure.

---

## 5. What still separates the draft from an acceptable statement (closed list)

1. **Name the tree (Q-1).** R6, or its integrated successor, with its pin set.
   - Tools v7 reads R6's six changed pins.
   - Re-gate on R6 captures: L = 1 and 2 in full, plus the 22-block pass A.
   - One capture through the CLI's own path (P-18).

   The draft's own §10b item 2 (an integrated tree) is part of this item.
2. **G-7.** NL-1's `nl_check.py` and the terminal-surjection computation at
   the trained slot-IR export.
3. **G-R4 at run scope (Q-6).** The stage-47 replay extended to L = 2, or the
   owner's written acceptance of the present scope.
4. **The text, on R6 (Q-2 to Q-5, Q-7):**
   - one evidence basis;
   - M-9 restated operationally (N-r6-a);
   - `prover_reported` as a constant self-report under a C-R4-class
     condition;
   - P-7's wording corrected;
   - admissibility including CS-3;
   - the census moved to completeness.
5. **The owner's own confirmations:**
   - CS-2 / CS-5 unnecessary at trained profiles (P-13);
   - the census's reduced role (Q-7);
   - the per-run and million-run D9 figures printed for Victor (P-22).

**Not on the list:**
- G-4's criterion (Q-8): tool bookkeeping, fail-closed;
- the refusal census itself: completeness, per Q-7 if the owner agrees;
- GPU coverage: a scope limit, not an item.

When items 1-5 are done, I see nothing in the arguments, the residuals, the
code read or the evidence that would stop the security owner accepting a
statement of the draft's form, for:
- `pg_rot1_export_T32`, on the CPU, as a bound run;
- the figures 2^-74.8 / 2^-73.8 / 2^-70.4 per run.

It would carry D22's caveat: each step survived one attack. It is not a proof
re-derived by the owner.

---

## 6. Evidence

**The draft and its revision state:**
- `PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md` (mtime 2026-10-18 04:43 UTC);
- the §3b map;
- §5, §6, §10.

**The native trees and verdicts:**
- R5b source: `r5b/frozen-tree/hashline/src/private_block/trained_block.rs`,
  lines 1022, 1122-1147, 1289-1321, 1973-2063, 2164-2335, 2338-2436;
- R6 source: `r6/frozen-tree/.../trained_block.rs`, lines 2073 and 2135-2200;
  `r6/frozen-tree/hashline/src/gpu/mod.rs:744-746`; `r6/r6-vs-r5b.patch`;
- `results/zk60_d24_review_20261017/R5_VERDICT.md` (r5_A, N-r5-a..d) and
  `R6_VERDICT.md` (r5_A closed, N-r6-a..e).

**The gate's R5b evidence:**
- `r5b/l22/r5b-l22-{dense-f,zero-f,dense-t,zero-a}.status.json`;
- `r5b/l22/r5b-l22-dense-t.json` (the M9-3 refusal texts);
- `r5b/l22/r5b-l22-dense-f.json` (pins, stage 14, CH 7 of 7);
- `r5b/gr4-*.log`, `r5b/r5b-schema-six-bundles.json`, `r5b/l22/r5b-tl4-l22.log`;
- `r5b/capture-r5b-l22-*.log`.

**The gate tools:** v6, `ops/zkp-mvp/gate-tinyllama/scripts/` = the frozen v6
manifest, 53 of 53 files equal (checked 2026-10-18 ~04:45 UTC).

**The export:** `pg_rot1_export_T32/profile.json`,
`per_layer_constants_differ = [exp_e_s, silu_member]`, `sh_s` = 6, run-wide.
