# Gate round 22: the draft's owed items 2, 3 and 4, the review's blocking findings, and draft v2

Privacy gate lane, 2026-10-29 22:51 UTC – 2026-10-30 02:0x UTC. **This is NOT a privacy acceptance.** Labels:
[MEASURED] a run happened (laptop, shared box, n = 1); [COUNTED] exact arithmetic; [READ] read from a record or the
code.

## 1. Result in plain words

* **The review's two blocking findings are answered by measurement.**
  * **P-2, the draw discipline (G-R4) by value: PASS at the R13 rung, L = 1 and 2.** The classifier prover's body was
    replayed on one seeded generator (a test-only port of D36's token replay). The production verifier accepted the
    replica. Stage by stage, the prover consumed exactly the bytes the gate's formula predicts. Every root (IN-C,
    each R13 block, OUT-C, every boundary) was rebuilt in the predicted order, and 5 / 5 non-vacuity perturbations
    fired.
  * **P-1, NL-1 and the surjection: PASS on the rung and on the real capture's classifier stages.** NL-1 S1–S5 passes
    on the 12 classifier slots and the 7 R13-changed block slots, on the rung and on the real capture. The terminal
    surjection with TS-1 passes on the rung (12 roles) and at the real classifier stages (6 roles, TS-1 6 / 6). On a
    real R13 block it is **partial**: block 0's three roles pass, but TS-1 did not run there; the rest is named (§4).
* **Item 4, the hash-input census: done.** C-R1 holds by reading; C-R2 and W-2 hold, measured. The transcript-query
  count is now measured, **A = 287,237**, replacing the 2^20 bound.
* **The owner check at n = 17 is recorded**, read from the app lane's public records: r16b under all three policies,
  all pass.
* **Draft v2 is written:** `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v2.md`. It
  takes in P-3 to P-10 and the notes, and §12 maps each finding to where v2 answers it. v1 is kept unchanged as
  `..._DRAFT_v1.md` (`db89f427…`).
* **The per-run figure is unchanged at 2^-68.19.** A post of J proofs is J times that: 2^-66.60 at J = 3, 2^-63.73 at
  J = 22.

## 2. Item 2: the seeded G-R4 replay [MEASURED, `round22/gr4/`]

* **Code:** `gr4_classify_tests.rs` (`14791f3c…`), in the gate copy `ops/zkp-mvp/gate-tinyllama/gr4-tree-r17/`.
  * That copy is token frozen-r17 (303 / 303 files equal), plus one `#[path]` line in `gate19_capture_tests.rs` (not a
    capture pin) and the new module.
  * Built with `--class build` 2.7 / 3.5 (3 min 17 s, compiled first time). The tests ran as `--class cpu` 2.0 / 3.0.
* **Three tests at the R13 h24 rung, all PASS:**

| test | L | gates | n | verdict | seeded prove / verify / whole |
|---|---|---|---|---|---|
| `gr4_classify_r13_rung_l2_v1_whole…` | 2 | 20, 21 | 23 | 1 | 2.23 / 0.25 / 13.2 s |
| `gr4_classify_r13_rung_l2_v0_short1…` | 2 | 20, 21 | 1 | 0 | 2.25 / 0.25 / 13.7 s |
| `gr4_classify_r13_rung_l1_vtie_whole…` | 1 | 20 | 23 | 0 (tie) | 1.18 / 0.14 / 7.1 s |

* **What each test checks:**
  * the production `verify_classify_run` accepts the replica;
  * per stage, the formula's bytes equal what the prover drew (a fresh-generator probe) and what the replay stream
    drew. IN-C: 6,259,840 B. Each R13 block: 118,593,824 B. OUT-C: 7,161,056 B;
  * every root is rebuilt;
  * 5 / 5 perturbations move exactly their roots and nothing earlier;
  * the input endpoint's 2,816 drawn words and 2,048 salts are pairwise distinct.
* **The bytes match the review's form.** At L = 2 the run stream is 14,581,690 draws + 540,672 salts = 250,608,544 B,
  which equals (counted draws − the endpoint's) × 16 + (salts − the endpoint's) × 32.
* **Cross-check [COUNTED]:** round 21's counting function, applied to the rung captures' files (`count_rung.py` →
  `COUNT_RUNG_L2_v1.json` `474309f8…`, `COUNT_RUNG_L1_v1.json` `3f186a8d…`), reproduces the replay's per-part counts
  exactly. It is the same function that gives §4's Shieldstral figure from the real geometry.
* **Not run:** a seeded re-prove at the real shape. It would stream the checkpoint (~8 GiB), and the review says it
  is not required.
* **Order of runs:** the first chain's build guard waited 23:23–00:24 behind the fork's heavy jobs. It was withdrawn
  while still queued (SIGTERM, guard exit 70, never started) so that it could not race Astra. The relaunch waited for
  Astra's three categories (done 01:44) and then ran alone, 01:45–01:52.

## 3. Item 3: NL-1 and the surjection [MEASURED, `round22/item3/ITEM3_REPORT.md` `3be42c0a…`; the fork]

* **Slots:**
  * the 12 classifier slots;
  * the 7 R13-changed block slots: SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC and SC_TAB, which R13 redefines, and
    SC_LZC, whose Dom::L lookups R13 changes. SC_DD is not applicable: no classifier profile is DD.
* **NL-1 S1–S5 (frozen `nl_check`, four challenge modes): PASS.**
  * Rung: three captures. Classifier T-0 12 / 12; R13 T-0 / E-0 14 / 14; S1 / S4 all pass; S3 35 / 35 and 25 / 25;
    every S5 control fires.
  * Real hate capture: the classifier slots, plus blocks 0 and 2 at G 19 / 18 (100 s, 1.53 GiB). R13 T-0 / E-0
    14 / 14; S3 55 / 55 at the real (N, d). The classifier T-0 needs the checkpoint stream; round 20 already measured
    it 12 / 12.
* **The surjection with TS-1:**
  * Rung (`ts-rung-L2-v1-r17-values.json`, `2cbcbe39…`; 3,864 s, 1.14 GiB): 12 roles. A / E / B / Input disclose 0,
    every H exactly 2, TS-1 12 / 12. The review's controls C1 / C2 / G7-D3 fire and the other five do not, as
    predicted.
  * Rung short item n = 1: PASS, TS-1 6 / 6.
  * **Real classifier stages** (`ts2-real-hate-classifier-stages.json`, `6da6296a…`): PASS. A-in 3 / 3, E 1 / 1,
    A-out 16 / 16 and B-out 2 / 2 disclose 0. H-in and H-out disclose exactly 2. TS-1 6 / 6. This job was run by the
    parent with the fork's v2 wrapper, after Astra, alone (353 s, 0.11 GiB).
  * **Real block 0: partial** (`ITEM3_REAL_BLOCK1_PARTIAL.json`, `565be37a…`). A 36 / 36 disclosed 0; H 8 / 9
    disclosed 2 (joint {7, 8}); Input 2 / 2 disclosed 0. It took 2,580 s at 0.85 GiB. On the coordinator's 00:54
    instruction the partial was saved first, then the job was stopped by SIGTERM to its guard: guard exit 75, child
    143, never SIGKILL. **One real block partial, the rest named.**

## 4. What is named, not run (commands and measured costs)

1. **TS-1 on a real R13 block, and the surjection on further real blocks.** About 1 h of a cpu slot per block
   [MODEL from MEASURED: the three roles took 2,580 s, and TS-1 adds at least about 900 s]. Command per block k:
   ```
   python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 2.0 --cap-gib 3.0 \
     --label gate22-item3-ts2-real-block<k> --max-secs 5400 --log <EV>/round22/item3/logs/ts2-real-block<k>.log \
     --done <...>.guard.done --result-json <...>.guard.json -- /usr/bin/env OPENBLAS_NUM_THREADS=1 python3 -B \
     /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classts2.py \
     --bundle ~/zk60-artifacts/token-io/captures/classify-r13-shield-t128-cli-hate-r17-values \
     --evidence <EV>/round22/item3 --name ts2-real-block<k> --block-stages <k> --skip-classifier
   ```
   The R13 block commitments have the same structure (rows, groups, claims) in every real block. The rung's two
   blocks pass with TS-1, and real block 0's roles agree, so the re-review decides whether more is needed.
2. **NL-1 on the other 24 real blocks.** About 26 × 25 s at about 1.6 GiB (cpu):
   ```
   zk60_r22_classnl.py --bundle <real> --parts r13 --lazy-store --no-b3 --skip-classifier-t0
   ```
   Run without `--r13-blocks`. The blocks run so far cover every gate denominator of the real model: {18, 19}
   real, plus 20 / 21 at the rung.
3. **The classifier T-0 at the real capture.** It needs one checkpoint stream (B-3), so it was not repeated; round 20
   measured it 12 / 12.

## 5. Item 4: the census [MEASURED / READ, `round22/census/`]

* **C-R2 and W-2** (`CENSUS_REAL_HATE.json`, `9868205e…`; the frozen replay, lengths only, a lazy array store; 27 s,
  0.80 GiB):
  * replay ok, 263,324 challenges;
  * the constructor input is 85 B, not 47;
  * no absorb input is 84–86 B;
  * every one of the 287,236 F_T calls is keyed.
* **A, measured: 287,237.** The pre-query term becomes 2^-109.87; the total stays 2^-68.19. On the rung the
  constructor is 77 B (`59614924…`).
* **C-R1** (`C_R1_READ.json`, `d3923ea0…`): 13 unkeyed sites, read. None is 40 B except the generators' refill (the
  reserved class), and none depends on the content.

## 6. The n = 17 owner record [READ, `round22/OWNER_RECORD_N17.json` `dcf54d86…`]

* **Sources:** the app lane's public `real_app_demo_1/input_owner_capture.json` and its per-category records. No
  `.dec`, content or activation file was opened.
* **The post:** 17 ids, proved by the named r16b `dfb8025e…` under all three moderate policies.
* **Each category:** input-owner exit 0, content-checked, content_total 17, range [0, 17), not-flagged.
* **Consistency:** each statement digest equals the owner record's; identity `29aeba6c…`; three distinct roots.

## 7. Draft v2 (the coordinator's list)

* **File:** `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v2.md`. v1 is
  `..._DRAFT_v1.md`.
* **The rename:** the original `..._DRAFT.md`, which held v1's bytes, is retired (see the ledger). **The register's
  pointer should now name `_DRAFT_v2.md`.**
* **What v2 takes in:**
  * P-3: the one-post corollary J × 2^-68.19, with its four hypotheses;
  * P-4: `prove-batch` / r18 not covered until named, fixed and byte-identity checked;
  * P-5: admissibility revealed (§0, §2, §8; the rate required before non-public posts, C-8; the Cn 4,000 result);
  * P-6: the three plain-words fixes;
  * P-7: R1–R4 with the app's state, condition C-7, and "profile (T), chunk plan" in P-4;
  * P-8: D20 out of scope, `timings.work_s`, the guard-cap margin, the app's salted SHA-256;
  * P-9: the binary per piece of evidence, including r16b's n = 17 receipts;
  * P-10: the end-aligned overlap;
  * the notes P-11 to P-15;
  * the review's §2 item 8 wording ("who sees the post", "for a post that passes the ranges");
  * §12, the disposition table.
* **§10 item 3's wrong v1 wording is corrected.**

## 8. Notes

* **N22-1 (operations):** the fork's real-block surjection held the heavy lock 00:04–00:54 with no stop hook. It
  delayed Astra's post by about 40 minutes. The v2 wrapper writes its record as it goes. A future real-block run
  should be bounded by `--max-secs` to the slot it is given.
* **N22-2:** the first GR4 chain's marker `round22/gr4/r22_gr4.done` = "build" records a withdrawal, not a failed
  build. The relaunch's marker `r22_gr4b.done` = 0.
* No checkpoint stream, prove or capture this round. **No job of this lane is pending.**
