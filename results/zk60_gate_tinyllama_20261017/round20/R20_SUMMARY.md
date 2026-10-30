# Gate round 20: round 19's two declared limits on a real Shieldstral capture

Privacy gate lane, 2026-10-29 16:35-21:3x UTC (token frozen-r17 on native R13). **This is NOT a privacy
acceptance.** Labels: [MEASURED] a run happened (laptop, shared box, n = 1); [COUNTED] exact arithmetic; [READ] read
from the code; [MODEL] an estimate.

## 1. Result in plain words

* **Are both limits closed? Yes, on one real capture.** The real Shieldstral-1.0-3B moderate-hate run, captured by the
  token lane's round 17 WITH its public block tables (442 tables, a 2.25 GB array file), was gated by frozen tools v23
  in ONE run, alone on the box. Its status is **PASS, with no declared limit**. Round 19's real capture had status
  PASS-WITH-DECLARED-LIMITS.
  * **Limit 1 (block slots):** all 23 block-stage slots hold in every one of the 26 real blocks, each block at its own
    gate denominator. Round 19 checked 11 of 23; the other 12 were open because that capture had no table values.
  * **Limit 2 (full preimage):** the zero-data preimage of the verifier's view was rebuilt for **all 84 commitments**:
    81,731,058 view entries, 0 differing. Round 19 used a declared sample of 15 commitments.
  * Everything else round 19 checked holds again on this capture:
    * disclosed dimension 0 on every A, endpoint and boundary commitment, and 2 on every H (the same per kind as
      round 19);
    * mask / CFS: 0 of 440,221 entries differ; joint figure 0 over 1,052,800 word pairs;
    * 19 classifier tables rebuilt, none taken; B-3 derived from the checkpoint, bit-exact;
    * all 15 controls fire, including C-13 at pad 11; all 7 R13 block controls fire (round 19 could fire only 2 of
      them on a real capture).
* **Tools v23** (frozen, 80 files, `64f4b757…`) read frozen-r17's one moved capture pin (`run_capture.rs`
  `cce0fc2a…`, test-only).
  * **F19-G1 fixed:** the tools now also run from the working copy (103 / 103 tests pass there).
  * **F19-G2 fixed:** a capture whose pins are not read gets a written refusal and exit code 3, not a crash.
  * **Failing-first:** v22 refuses both r17 captures by name, with one refusal each (`run_capture.rs`). Run whole,
    v22 still crashes with a KeyError.
* **The r17 rung capture with values** also passes, with no declared limit: 23 / 23 slots at both stages, and a full
  preimage of 2.25 M entries with 0 differing.
* **Cost** [MEASURED]: 14,605 s (4.06 h), peak RSS 6.47 GiB (declared 8.8 / cap 10.5), alone on the box.
  **The 7.7 GB checkpoint was streamed once in the round**, for B-3 inside this one run.
* **Not a privacy acceptance.** What a classifier privacy statement still needs is in §6.

## 2. The records [MEASURED, frozen v23]

| capture | made by | L | policy | n / pad / verdict row | status | block slots | classifier slots / rebuilt / taken | disclosed (A, E, B / H) | full preimage (commitments / entries / differing) | controls | time, peak |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **classify-r13-shield-t128-cli-hate-r17-values** (real) | frozen-r17's H19-2 hook on round 16's run (proved by e94cecf9…; re-verified by the r17 binary 81bd8624…) | 26 | moderate-hate (P0 78) | 35 / 14 at id 11 / 113 | **PASS** (no declared limit) | **23 / 23 in each of 26** (15 tables taken per stage) | 12 / 19 / 0 | 0 / 2 (84 commitments) | **84 / 81,731,058 / 0** | 15 + 7 R13 | 14,605 s, 6.47 GiB |
| classify-r13-rung-L2-v1-r17-values | frozen-r17's H19-1 hook | 2 | rung | 23 / 0 / 31 | PASS (no declared limit) | 23 / 23 x2 (G 20 / 21) | 12 / 19 / 0 | 0 / 2 | 12 / 2,247,034 / 0 | 14 + C13-1 n/a + 7 R13 | 926 s, 1.03 GiB |
| *round 19, for comparison:* classify-r13-shield-t128-cli-sexual-r16b | the gate's capture tree | 26 | moderate-sexual (P0 72) | 35 / 20 / 107 | PASS-WITH-DECLARED-LIMITS | 11 / 11 covered x26, 12 open | 12 / 19 / 0 | 0 / 2 | 15 (sample) / 9,668,010 / 0 | 15 + 2 R13 | 2,439 s, 5.17 GiB |

Records:
* `round20/v23/v23-classify-r13-shield-t128-cli-hate-r17-values.json` (`e94d6e7b…`);
* `round20/v23/v23-classify-r13-rung-L2-v1-r17-values.json` (`7bb0948a…`);
* the summary `round20/R20_SUMMARY.json` (`24e1d6b9…`).

More on the real record [MEASURED]:
* **Integrity:** 72 pins; the 26 stage gates are [19, 19, 18, 20 x 7, 19, 20 x 3, 19, 20 x 8, 19 x 3]. B_out's
  OUTC-00 claim decodes to row 113 = P0 + n + S - 1.
* **Replay:** 3,303 positions and 263,324 challenges, run binding reproduced. Hash layer: 28,672 columns (482.8 MB).
* **B-3:**
  * the whole checkpoint authenticated (`87753e30…`) and the tensor pin `67a138c1…`;
  * embedding `1cb276d1…` and margin `6429a242…` equal the statement's;
  * the receipt's margin vector equals the derived row (0 of 4,096 entries differ).
* **D41:** one chunk [0, 35), plan size 49.
* **Joint preimage:** all four couplings respected; C4 now has `block_stages = true`.
* **Time per part:** per commitment 221 s, CFS 192 s, block stages 489 s, controls 235 s, full preimage 13,381 s.

**The published `/3` statement of the hate run** (`r16-runs/hate-run/statement/statement.json`):
* 38 keys, all classified; item length 114 = 78 + 35 + 1, pad positions 14, verdict row 113, pad id 11;
* identity `29aeba6c…`;
* its input root `4cf9e8ae…` equals the capture's (and the r17 verify log's).

**Which capture for limit 2, and why:** the moderate-hate values bundle, not round 19's moderate-sexual capture.
* It is the only real capture that can close limit 1 (it carries the table values).
* Running the full preimage on the same capture gives one record with no declared limit at all.
* The preimage itself does not depend on the table values.

## 3. Tools v23 (frozen 16:57:05 UTC)

* **Freeze:** `frozen_v23/` (+ `original/`, `counts/`). Manifest `gate-tinyllama.tools.frozen.v23.sha256`: 80 files,
  `64f4b7572674caef31d21da014869b119a58b186418174ad97d21400f7440230` (80 / 0 / 0; staging == frozen).
* **Patches:** v22 -> v23 scripts `c94ba62d…` (21,092 B), tests `9b40b852…` (6,131 B); vs original `29776eb8…`.
  No new module (the TOOLS list is v22's).
* **Suite** [MEASURED, light]: 103 OK in staging (66.8 s), **103 OK in the frozen snapshot** (70.1 s) and **103 OK in
  the working copy** (68.1 s). That is 98 + 5 new tests (`ClassifierV23`). v23 is installed in the working copy, which
  round 19 had to leave at v21.
* **What changed from v22:**
  * **Pins** (`zk60_native_rg_classpins.classify_capture_pins_v23`, the dispatcher's rule now):
    * v22's rule with the frozen-r17 readings in front (`TOKEN_R17_READINGS`);
    * `r17_self_check()` re-counts the moved pins from the token manifests and re-hashes the three files;
    * an r16b capture is still accepted; an r14 or R-C1 capture is still refused by name.
  * **F19-G1** (finding the repository root): `classpins._repo_root()` and `r13_pins.repo_root()` search upward for
    the first directory holding `results/` and `ops/zkp-mvp/`. v22 counted a fixed five parent directories, which is
    true only in `frozen_v22/`. If there is no such directory, the tools refuse by name.
  * **F19-G2** (refused pins):
    * `classgate.gate` stops right after the integrity check when the source pins are refused, and writes a record with
      status `REFUSED` (`refusal`: by "source pins", each refusal by name);
    * `main` exits **3** (`EXIT_REFUSED`); 0 = PASS / PASS-WITH-DECLARED-LIMITS, 1 = NOT-OK;
    * CC-4 reads B-3 with `.get`: a terminal record without B-3 is a control that did not fire, never a KeyError.
  * **Memory:** `classgate._sha` reads 1 MiB at a time and caches per process on (path, size, mtime, inode). v22 read
    every listed file whole, six times per run (the integrity check plus five controls that re-run it on in-memory
    variants). With a values capture that is a 2.25 GB bytes object each time (F20-G1).

## 4. Failing-first and the [READ] list

| what | tools | capture | result [MEASURED] |
|---|---|---|---|
| the pin rule | frozen v22 | both r17 captures (real hate values, r17 rung values) | **refused by name**, exactly one refusal each: `src/private_block/run_capture.rs: cce0fc2a4062 has no reading` |
| the pin rule | frozen v23 | the same two; round 19's r16b captures; an r14 short and an R-C1 capture | 72 / 72 accepted; accepted; refused by name |
| the whole gate | frozen v22 | the r17 rung values capture | pins refused, then `KeyError: 'B3_margin_vector'` in the controls after 701 s, exit 1, no record (F19-G2) |
| the whole gate | frozen v23 | an r14 short capture | **REFUSED** by source pins (classify.rs / classify_run.rs / classify_tied.rs named), record written, **exit 3**, 0.7 s |
| the suite | frozen v23 | run in the working copy | 103 OK (round 19: 8 errors there, F19-G1) |

Records: `round20/ff/ff-pins-v22-v23.json`, `ff-v22-gate-r17-rung.log`, `ff-v23-refuses-r14.json`;
`round20/suite/*.log`.

[READ] (`round20/readings/R20_READINGS.json`, `910e1a4a…`):

| file | digest chain | diff | classification | moves a receipt / block-stage / statement byte |
|---|---|---|---|---|
| src/private_block/run_capture.rs | cad25086 (r16b) -> 8292b1c6 (the gate's H19-4) -> **cce0fc2a** (frozen-r17) | +436 / -9 against H19-4 (`round20/readings/run_capture.H19-4_to_r17.diff`, `907727b9…`) | test-only (`#[cfg(test)] mod run_capture;`, private_block.rs:258-259) | no |
| src/private_block/plane_index.rs | 13a7dd6f (r16b) -> **ce79803c** (= the gate's H19-3 byte for byte) | none against H19-3 | test-only (`#[cfg(test)] mod plane_index;`, :267-268) | no |

What the r17 `run_capture.rs` adds over H19-4:
* At an R13 BLOCK stage with values, each statement table is listed: the seven folds, gamma_a / gamma_m, the RoPE pairs
  on Q / Kv, the group column, exp / ACT3, and the ACT support. Each carries the same SHA-256 that
  `write_public_table` writes; the bytes written are unchanged.
* An R13 DD block stage with values is refused by name.
* `export_replay` re-derives each listed table from an export layer and refuses on any difference.
* `write_bundle` refuses a bundle that has not been replayed, and writes the replay into the README.
* No stage-file key, run.json key or value encoding moves.

Of the 72 pinned files, only these two move from r16b to r17 [COUNTED from the token manifests: 6 paths move; the
other four are test files the capture does not pin].

## 5. The measurement before the declaration, and one job for both limits

**Dev run** [MEASURED, `round20/dev/real_dev.json`; staging v23, guarded cpu 6.5 / 8, alone; 402.6 s; guard peak
5.09 GiB], on the real values bundle:
* after load, RSS 2.56 GiB, of which **2.12 GiB are file pages of the array store**: checking every reference's
  SHA-256 touches the whole 2.25 GB file;
* holding the 84 commitments' views: 4.32 GiB (round 19: 3.07);
* the R13 block terminals WITH values on blocks 0 (G 19), 2 (G 18) and 25 (G 19): 23 / 23 each, none open, 15
  captured tables per stage, ~15 s per block; the 7 R13 controls fire; transient peak 5.18 GiB.

So the values cost the store's resident pages, not working memory.

**Declaration for the official run:** round 19's in-process peak was 5.70 GiB. Adding the extra 1.30 GiB of store
gives ~7.0 GiB; + 25% gives **8.8 / cap 10.5** [MODEL from MEASURED]. Measured afterwards: peak 6.47 GiB.

**One job for both limits.** One gate process streams the 7.7 GB checkpoint for B-3: an authenticated whole-file
SHA-256 and the tied tensor; the tau fold is cached in the process. Separate limit-1 and limit-2 jobs would each run
B-3, so the checkpoint would be streamed twice, which the brief forbids. Both limits were therefore closed by one
detached run with the full preimage.

**Before launch** the run waited until no other guarded job, sol- / astra- included, was live or waiting
(`round20/alone_check.py`). Sol's short R14 jobs ran first; this run started at 17:30:10 with the box empty
(`round20/r20_gate_r.alone_at_launch.json`). Guard samples every ~10 minutes showed no other guarded job during the
run.

## 6. What a classifier privacy statement draft still needs

The two gate limits of round 19 are closed. Still owed, in order:

1. **The statement text:** the D36 analogue for one classifier run at
   `…shieldstral-3b-t128-r13-public-row/1`.
   * **Hidden:**
     * the content ids at positions P0 .. P0 + n - 1 and their embedding rows;
     * every activation and the 26 inter-block planes, pad rows included;
     * the final-norm values, the margin and its limbs.
   * **Public:**
     * the verdict bit;
     * n, the item length, pad id 11, the pad positions and the verdict row (D45(1));
     * the chunk facts (D41);
     * the policy id from the fixed list of three, its template ids, c and the yes / no ids;
     * the margin-vector digest and the model identity (`29aeba6c…`, the export profile, the per-layer gate
       denominators);
     * the tied source, the input endpoint root (D45(3)) and the 96-bit whole-run floor.
   * **The fail-closed rule**, and the **small-n sentence:** at n = 1 the verdict is a function of one hidden id, one
     of 130,072 non-control ids.
2. **The per-run distance figure at the Shieldstral R13 shape** (the analogue of D36's 2^-70.35 at L 22). It needs the
   blinding-law residuals (the G-R4 class) recounted over 26 R13 blocks (107 A planes, more claims per block) plus the
   IN-C / OUT-C draws. Not computed. The refusal term to add is **2^-108.25** (round 19 recount, replacing D40's
   2^-112.7).
3. **The refusal channel, R19-1, in plain words.** Proposed wording, for the review to attack:
   > *Whether a run produces a proof at all can depend on what the hidden item says. The honest prover stops before
   > writing any proof when an activation of the item, or of the pad rows after it, leaves one of the R13 stack's
   > fixed integer ranges: the norm word in int16, the widened words in [-32768, 32767], the attention score in
   > [-127, 127], the gate word in [-2048, 2047], the norm and softmax denominators and their remainder windows. Such
   > a run yields no proof and no verifier view, and the app shows "could not be verified" (D45(4)). Someone who
   > learns that an item could not be verified learns that one of these ranges was left, which is a fact about the
   > hidden content, and learns nothing else from the proof system. For an accepted run, the chance that a hidden
   > value makes the lookup argument divide by zero adds at most 2^-108.25 to the distance above.*

   At one dev calibration, 102 of 300 ids refused (R19-1). On the real model, none of the real runs proved so far
   refused: round 16's 35-id post under the three policies, and round 19's re-prove of it. The refusal rate on real
   content is not measured.
4. **Evidence the gate still owes or depends on:**
   * **The 15 statement tables per block stage are TAKEN, not derived.** These are the seven weight folds with the R13
     multipliers, the two gains, the two RoPE pairs, the group column, exp, ACT3 and the ACT support.
     * The gate checks their lengths, digests and structure: fold supports (ruling P-2), gains periodic in the padded
       width, the RoPE pairs zero off the live set with partner repeat / negation, the exp rows, the group column
       token-constant with ids < 4, the ACT support a prefix of 4096 G ones, and the ACT3 rows decoding to small
       integer words with 0 at gate 0.
     * It also checks the terminal identity on them.
     * That they equal the export's is the token recorder's export replay (r17: test-only, unreviewed; the
       coordinator's check stands in for a review).
     * Owed: a gate-side derivation from the export, or a review of the replay. This includes the ACT3 table against
       the SiLU generator.
   * T256: registered, but never proved or captured.
5. **Owner checks.** Done: the input owner's check on round 19's real run, by the gate, PASSED. The token lane ran the
   owner check on the hate run in round 16 (exit 0). Owed: a gate-side owner record on the hate run and on short items
   at other n, and the delivery of the opening that D45(3) keeps with the app.
6. **Scope rulings:** Victor's strict / moderate wording ruling (the registered list is the moderate one); the token
   lane's README text N20-1 (§7); the independent check of rounds 16b / 17.
7. **An independent privacy review round** on the draft (as REVIEW4-6 for D33 / D36).
8. **The security owner's sign-off and Victor's acceptance.** No lane can claim a privacy acceptance.

## 7. Findings and notes

* **F20-G1 (the gate's own tools, fixed in v23):** v22's `class_integrity` read each listed capture file whole, six
  times per run. At a values capture that is six transient 2.25 GB allocations.
* **O20-1 (operations, guard):** a capture's array store is memory-mapped and every reference in it is hashed, so the
  WHOLE store becomes resident file pages, which the guard's RSS watchdog counts (2.12 GiB here). Declarations for
  values captures must include the store size. The pages are reclaimable, but the watchdog kills when RSS exceeds the
  cap x 1.02. The cgroup peak was 9.08 GiB against a cap of 10.5 (page cache).
* **N20-1 (token lane, low, wording only):** the r17 real values bundle's README opens with "Bundle (privacy gate round
  19, test-only patch H19-2 in the gate's copy of token frozen-r16b)". That is the adopted hook's text, but frozen-r17
  and its binary 81bd8624… made this bundle; the manifest's `source_commit` "token-r17-uncommitted" and its 72 pins
  are r17's. The hook's text should name the tree that runs it.
* **Sol coordination:** Sol's 17:11 log line asks for no light job > 1 GiB beside a >= 3 GiB proof, and a bounded gap
  for its R14 attacks. This run held the box for 4.06 h. It started only when Sol's queue had drained, and this lane
  launched nothing beside it.
* **Not checked (declared, as in round 19):** the DD twins (no DD classifier profile exists; a DD bundle is refused by
  name), and T256.
