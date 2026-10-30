# Privacy re-review: Shieldstral-1.0-3B T128 classifier privacy statement, DRAFT v2

Reviewer: Claude (independent; the same reviewer as for v1, and not the author). Read-only. Written 2026-10-30 from
02:12 UTC (read from `date -u`).

Object: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v2.md`, sha256
`cfbfeafe13069b71b36f1fa43dc9b04d7ea8e666ac97eb85a0912294caa56299` [MEASURED]. v1 is kept at `..._DRAFT_v1.md`, and
its hash is `db89f427…`, the bytes I reviewed [MEASURED]. My v1 review is
`CLASSIFIER_T128_PRIVACY_REVIEW.md` in this folder.

Labels: [MEASURED] I ran a light check (hashes, tree diff, a re-run of a light counting script, arithmetic; under
1 GiB, seconds). [COUNTED] exact arithmetic. [READ FROM FILE] read in a cited record. [MINE] my own reasoning.

Nothing was built, proved, verified or streamed. No git. No owner-private file was opened. The only files I wrote
outside this folder are scratch outputs in my session scratchpad.

## Verdict: ACCEPTABLE WITH CHANGES

In plain words: the two blocking items of v1 have been measured, and the records say what the summary says. The
draw replay passes at the rung exactly as asked. NL-1 passes everywhere it was asked. The surjection passes
everywhere except one control on a real block, which did not run. v2 takes in every must-change of v1.

Four small text corrections remain (R-1 to R-4). One cheap measurement should become a condition before the
statement comes into force: TS-1 and the claim census on one real R13 block, about 1 hour of a cpu slot at under
1 GiB, with no checkpoint stream. It need not hold up the security owner's ruling (answer (b)).

## (a) Are P-1 and P-2 closed?

### P-2 (the draw discipline by value): CLOSED, at the rung, as asked

What I checked:
- **The gate tree is what v2 says** [MEASURED: SHA-256 of every file, `target/` excluded]. Against frozen-r17,
  `ops/zkp-mvp/gate-tinyllama/gr4-tree-r17/` has one file changed and one added. The change is
  `token_io/gate19_capture_tests.rs`: four added lines, a comment and `#[path = "gr4_classify_tests.rs"] mod gr4;`.
  The addition is `gr4_classify_tests.rs`, byte-equal to the copy in `EV/round22/gr4/`, hash `14791f3c…`. No
  production file differs.
- **The method is D36's (PR4-8)** [READ FROM FILE: the test's header].
  - Only the top-level body of `prove_classify_run_with` is replicated on a seeded generator. The draws happen inside
    the production stage functions (`stage_in_c::prove`, `boundary::prepare`, `protocol::prove_core`,
    `stage_out_c::prove`).
  - The production verifier must accept the result.
  - The roots are rebuilt independently, "never through the production commit calls".
  - A fresh-generator probe checks what the prover consumed.
- **All three tests pass** [READ FROM FILE: `l2-v1-whole.log`, `l2-v0-short1.log`, `l1-vtie-whole.log`; the guard
  records exit 0, child 0, not killed]:
  - L = 2 verdict 1; L = 2 short item n = 1, verdict 0; L = 1 tie.
  - In each: the verifier accepts. Per stage, the predicted bytes equal both the prover's probe and the replay stream:
    IN-C 6,259,840 B, each block 118,593,824 B, OUT-C 7,161,056 B.
  - Every root is rebuilt, and 5 / 5 perturbations move exactly their roots.
  - The endpoint's 2,816 drawn words and 2,048 salts are distinct.
- **The bytes add up** [COUNTED].
  - IN-C: (35,328 + 44,542 + 6,474) × 16 + 36,864 × 32 + B_in's 100,096 × 16 + 65,536 × 32 = 6,259,840.
  - Block: (4,994,304 + 1,898,494 + 17,812) × 16 + 135,168 × 32 + 100,096 × 16 + 65,536 × 32 = 118,593,824.
  - OUT-C: 373,838 × 16 + 36,864 × 32 = 7,161,056.
  - L = 2 total: 250,608,544, which equals 14,581,690 × 16 + 540,672 × 32.
- **The Python counting function agrees with the replay at the rung.** I re-ran `count_rung.py` on the L = 2 rung
  capture. Its output is equal, as JSON, to the gate's `COUNT_RUNG_L2_v1.json` [MEASURED]. This is the function
  that gives §4's 235,660,902 from the real geometry.
- The real shape is carried by the formula, as D36 carried L = 22. I said in v1 that this is enough.

### P-1 (NL-1 and the surjection): CLOSED for NL-1 and for the classifier stages; the real R13 block is partial

What I checked [READ FROM FILE; hashes MEASURED, all equal to the prefixes the summary cites]:
- **NL-1 S1–S5 at the real capture** (`nl-real-hate-blocks0-2.json`, `ab078cf3…`): status PASS.
  - Blocks 0 and 2, G 19 / 18. R13 slots used [3, 14, 15, 16, 17, 18, 19].
  - T-0 (the port equals the recorded terminal polynomial) and E-0 hold on 14 / 14 instances, and the T-0 control
    fires on each. S1 and S4 hold 14 / 14 in each of the four challenge modes. S3 holds 30 / 30. S5 fires.
  - At the real pairs, S3 holds 55 / 55.
  - The classifier slots: S1 and S4 12 / 12 in all four modes, S3 35 / 35, S5 fires. The classifier T-0 was skipped
    (it needs the checkpoint stream); round 20 measured it.
- **NL-1 on the rung** (three records, `0e2e2c7a…`, `b681bf93…`, `9df89d54…`): status PASS.
- **The surjection on the rung** (`ts-rung-L2-v1-r17-values.json`, `2cbcbe39…`): status PASS on 12 roles.
  - Every A, endpoint, boundary and Input role discloses 0; every H discloses 2. TS-1 fires 12 / 12, including both
    blocks' A, H and Input. The census finds no identical claims and no equal published values.
  - The n = 1 short item (`bd22065b…`) passes, TS-1 6 / 6.
- **The surjection at the real classifier stages** (`ts2-real-hate-classifier-stages.json`, `6da6296a…`): PASS on
  6 roles, TS-1 6 / 6, B-out at 2^14 included.
- **The real R13 block** (`ITEM3_REAL_BLOCK1_PARTIAL.json`, `565be37a…`; its source log hash `28d986c3…` matches):
  - A 36 / 36 surjective, disclosed 0; H 8 / 9, disclosed exactly 2 (joint {7, 8}); Input 2 / 2, disclosed 0.
  - TS-1 and the census were not reached. The guard record shows exit 75, child 143, "guard received signal 15",
    peak 0.85 GiB: a clean stop, not a failure.

So P-1 is closed apart from one control: TS-1 and the claim census on a real block. See (b).

## (b) Is TS-1 on a real R13 block required before a ruling?

**My answer: not before the security owner's ruling. Make it a stated limit, with a condition before the
statement comes into force (Victor's acceptance) and a lapse trigger. One block is enough; the other 25 are not
needed.**

Reasons, against D36's precedent:
1. **What D36 required is met.** D36 ran TS-1 on every *new* role at the real shape on every capture (round 10,
   7 / 7 roles). This statement's new roles are the six IN-C / OUT-C roles, and they have TS-1 6 / 6 at the real
   capture [MEASURED, above].
2. **Block evidence in D36 was carried from D33.** D33's G-7 ran the surjection on real-shape block stage files, with
   controls of the TS-1 kind on a real group: C1 (shared reserved pair) and C2 fire, G7-D3 fires, and the others
   do not [READ FROM FILE: the D33 statement, "Terminal surjection at the trained width"]. So the precedent's end
   state *does* include a non-vacuity control on a real block. Here that control is the one missing piece, and it
   costs about 1 hour.
3. **The tool's non-vacuity at the real block is shown another way.**
   - On the real block, H's group discloses exactly the declared 2. The tool found a genuine 2-dimensional relation
     at the real shape. A blind tool would have reported 0.
   - The same wrapper, reading the same memory-mapped store, fired TS-1 on all six real classifier roles, one of
     them a 2^14 role like the block's.
   - TS-1 and C1 / C2 / G7-D3 fired on the rung blocks.
4. **The real blocks are identical to one another** [MEASURED: round-20 per-commitment records]. All 26 have A with
   4,577 rows, 36 groups and 146 claims, and H with 4,390 rows, 9 groups and 54 claims. Their mask specs are
   identical too [MEASURED: the 26 stage files]. So one real block stands for all; the other 25 are not needed.
5. **But the rung is not identical to the real block** (R-1). The rung's A has 437 rows and 148 claims, and its H
   has 248 rows and 55 claims [MEASURED: round-20 rung record]. So the rung's TS-1 shows the tool works; it does not
   show it on the real block's exact claim set. That is why the job should still run.
6. **D31's reopen check needs the real-shape census.** D31 reopens "if a capture ever shows a duplicated plane, a
   repeated terminal coordinate or equal published values" [READ FROM FILE: register]. The census that would show
   this (identical claims, equal published values) was recorded at the rung but not on a real block: the job stopped
   before it. The same one-block job writes it.

The condition to add (C-9): before the statement comes into force, run the named one-block job. Use the v2 wrapper on the
block already partly analysed (block 0, `stage-01`), with `--block-stages` and `--skip-classifier`, cpu 2.0 / 3.0, with `--max-secs` sized to the slot it is given (note N22-1). The
statement lapses if TS-1 does not fire on A, H and Input, or if the census finds identical claims or equal published
values. The command is in `EV/round22/R22_SUMMARY.md` §4 item 1.

If the security owner prefers to have it before ruling, it is cheap and nothing else waits on it. I do not require it.

## (c) Does v2 take in every must-change? Yes, with three small corrections

| v1 finding | Where v2 answers it | Taken in? |
|---|---|---|
| P-3 whole-post corollary | §2 corollary, four hypotheses; §0; §4 row and note; §8; §9 | **Yes.** I re-checked the figures [COUNTED]: J = 3 gives 2^-66.60, J = 22 gives 2^-63.73; 22 × 287,237 < 2^23; the total with q + 22·A is unchanged at 2^-68.188. **One wording conflict (R-2).** |
| P-4 prove-batch / r18 | §0, §1, §6, §8, §9 | Yes |
| P-5 admissibility revealed | §0 bullet, §2 sentence, Step 4, §8, C-8, the Cn 4,000 result | **Yes, but** the "16 cells" sentence came from my own v1 text and is imprecise (R-3) |
| P-6 three wording errors | §0 lines 110–113 and 126–129; §2 lines 236–240 and 296–301 | Yes |
| P-7 R1–R4, C-7, P-4 additions | §5 C-7 and P-4; §6 R1–R4; §9 | Yes. I re-checked R3 against `store.py`: re-screening is refused once any work ran, and refused under another context |
| P-8 D20 timing and memory | §1, §2, §6 "guard cap", §8 | Yes (one note: N-2) |
| P-9 binary per piece of evidence | §0 "by which binary", §1, Step 4, §8 | Yes |
| P-10 to P-15 (notes) | §0, §1, §4, §5, §6 | Yes |
| §10 item 3's wrong v1 wording | §10, the paragraph after the "Closed" table | Corrected |

The n = 17 owner record also checks out [READ FROM FILE: `OWNER_RECORD_N17.json`, `dcf54d86…`]. All three
categories pass, the roots are distinct, and it was made from public app records only. The item lengths are
consistent [COUNTED]: 72 + 17 + 1 = 90 and 78 + 17 + 1 = 96.

## (d) Corrections to v2 (R-1 to R-4: must-change before the ruling, text only)

- **R-1. Do not imply that the rung and real blocks share one structure** (§3 Step 4, lines 406–408).
  - The sentence "the structure … is the same in every real block … and the rung's two blocks pass with TS-1"
    invites the reading that the rung's TS-1 covers the real block's structure. It does not.
  - Add: the rung blocks are smaller (A 437 / H 248 rows against 4,577 / 4,390) and carry two more A claims and one
    more H claim (148 / 55 against 146 / 54).
  - The carry to the real blocks rests on four things: the 26 real blocks being identical; D33's real-block controls
    on the same group structure (36 A groups, 9 H groups); H's exact disclosure of 2 at the real block; and TS-1 at
    the real classifier roles.
- **R-2. Corollary hypothesis 1 conflicts with the scope** (§2, line 249).
  - "Also when runs share a process" sits beside the sentence's "one run per process call" and the exclusion of
    `prove-batch`.
  - Say: "each run makes two fresh, independent OS-entropy reads; under the named binaries each run is its own
    process. Several runs in one process (`prove-batch`) need their own reading (§6)."
- **R-3. Fix "one of at most 16 cells"** (§0, lines 94–95). This was my own wording in v1, and it is loose.
  - The three verdicts and the three policies' admissibility define a public partition of the ids.
  - A published post (all three runs accepted) lies in one of at most 8 cells: the verdict patterns, among ids that
    pass all three policies' ranges.
  - Say: "the published facts place the id in one cell of a partition anyone can compute with the public model: one
    of at most 8 verdict patterns among the ids admissible under all three policies".
- **R-4. State the real-block TS-1 as a limit with condition C-9** (from (b)).
  - It belongs in §0 "What is still open", §3 Step 4, §5 as a new C-9 (with its lapse trigger), §9 and §10.
  - Today v2 says "if the re-review asks for it". Replace that with the ruling of (b).

## Notes (no change needed for the ruling)

- **N-1. The 16 unchanged block slots.**
  - v2's "R13 changes only their matmul folds' public values, not their polynomials" is unlabelled. It is [READ]
    (the `r13slots` docstring, per the item-3 report).
  - It is supported by measurement: round 20's terminal identity holds 23 / 23 at every real block with the legacy
    bodies for those slots, and control R13-L shows the identity refuses a wrong body. Cite both.
  - S3 has not been checked at five (rounds, degree) pairs that only the legacy slots use at the real shape: (8, 3),
    (12, 3), (15, 2), (20, 2), (20, 3) [MEASURED: the capture's mask specs]. Fact 2.1 is an argued lemma, so this is a
    numeric confirmation only.
  - The mask budget holds for all 23 slots: the worst L is 112, and L + 256 ≤ 512 [MEASURED].
  - Recommended, not required: add these pairs to the named NL-1 run on the other 24 real blocks (about 11 minutes
    at 1.6 GiB). The same run also covers G = 20 at the real shape. v2 says the G values {18, 19, 20} are covered,
    but G = 20, which 18 of the 26 real layers use, was checked only at the rung shape. G enters only as a public
    coefficient, so this too is a confirmation.
- **N-2. The guard cap.**
  - The guard enforces cgroup memory. The real sexual prove reached the 11.5 GiB cap in cgroup terms (page cache)
    with 8.15 GiB RSS; hate peaked at 9.97 and violence at 9.42 GiB cgroup [READ FROM FILE:
    `r16/logs/real-prove-*.guard.json`].
  - v2's "margin above the class maximum (8.08–8.27 GiB)" is in RSS terms. Say so: about 3.2 GiB of RSS margin under
    an 11.5 GiB cap, with cgroup usage at the cap being reclaimable checkpoint page cache.
- **N-3. Provenance of the rung counts.**
  - `EV/round22/gr4/count_rung.log` and `count_rung.guard.json` record a *failed* guarded attempt (round 21's
    script, exit 1, on its Shieldstral-only refusal check).
  - The `COUNT_RUNG_*.json` files came from `count_rung.py` run about 20 seconds later, with no log.
  - I reproduced the L = 2 file exactly [MEASURED]. The gate summary should add one line on this.
- **N-4. ITEM3_REPORT.md is stale on one point.** Written at 00:57 UTC, it says TS-1 at the real classifier stages
  "did not land". The later `ts2-real-hate-classifier-stages.json` (02:00 UTC) supersedes it. R22_SUMMARY and v2 are
  right.
- **N-5. Dangling pointers.** The register's round-21 entry, and my v1 review, point at `..._DRAFT.md`, which no
  longer exists. Point the register at `_DRAFT_v2.md`, and note that v1 sits at `_DRAFT_v1.md` with the same hash.

## What I did not check

- I did not run any gate tool, replay, NL-1 or surjection check myself. I read their records, logs, guard files and
  hashes, and re-ran one light counting script.
- I did not read `zk60_r22_classnl.py`, `zk60_r22_classts.py` / `classts2.py` or the memory-mapped `Arrays` change
  line by line.
- I did not check the classifier T-0 at the real capture, which needs the checkpoint stream; round 20's record
  stands for it.
- I did not read the app's records behind `OWNER_RECORD_N17.json` beyond the gate's summary of them.
- I did not re-read the parts of v2 that are unchanged from v1 beyond confirming that the sentence, the assumptions
  and the residual table are as before, apart from the stated additions.
