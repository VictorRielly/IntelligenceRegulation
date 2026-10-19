# Independent adversarial privacy review, round 3 (final): the trained TinyLlama T32 draft on native R7

Reviewer: the same independent Claude Opus 5.5 agent as rounds 1 and 2
(`REVIEW.md`, `REVIEW2.md`). I did not write the draft, the gate tools or the
native code. Written 2026-10-19, 12:00–12:15 UTC. Paper only: no builds, no
proofs, no git writes, no jobs; only short read-only `python3 -I` checks.
The ledger is `PROGRESS.md`, section ROUND 3.

**This is not a privacy acceptance.** It advises the security owner. Rulings
are Victor's.

**Objects:**
- the draft `results/zk60_gate_tinyllama_20261017/PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md`
  (sha256 `080cddbc…`, checked);
- native R7 (`results/zk60_1b_native_20261017/r7/frozen-tree/`, tree
  `36a8aed1…`) and `R7_VERDICT.md`;
- the gate's evidence `EV/r7/` (summary `r7-summary.json`), `EV/r7cli/`,
  `EV/r7/cli/`, `EV/q6/` and `EV/g7/`;
- tools v8 (manifest sha256 `e047fb59…`, checked; the live `scripts/` equal
  it, 54 of 54 files);
- register entries D28, D29 and D31;
- Victor's sheet `docs/zkmatrix-poc/ZK60_RULINGS_FOR_VICTOR_20261017.md`
  (the D9 figures, 09:31 UTC).

---

## 0. Verdict, in plain words

**Yes, with one pending result and two wording errata.** Once G-7's R7
terminal-surjection re-run lands with the expected figures, I see nothing
that should stop the security owner accepting a statement of the draft's
form. The statement would cover:
- pg_rot1_export_T32, on the CPU path only;
- bound runs of L = 1, 2 and 22 blocks;
- native R7 and its 46 pinned source files.

The re-run is running now, started 11:58:49 UTC. Expected: A 36 of 36
groups surjective, disclosed 0; H 8 of 9, with the LogUp sum claim
disclosing exactly the declared 2; endpoints and boundary disclosed 0.
So far it shows A 36 of 36, disclosed 0, on the first R7 bundle, and a clean
claim structure on all four bundles.

**What I checked this round.**
- **All five of my round-2 closing items are closed.** That is shown by
  evidence, by the register, or (for the R5b → R7 carry) by reading I
  agree with (§1).
- **What R7 and tools v7/v8 changed holds up under attack** (§2):
  - G-4's tightened criterion;
  - PC-9b;
  - the capture through the CLI's own path;
  - R7's statement-writer changes.
- **No new channel on hidden data.**

**The two errata (wording, no figure moves; §3).**
- The draft's §0 and §10b still list the owner's confirmations as owed.
  They are in: D28, D29, and the D9 figures on Victor's sheet, all at 09:31
  UTC.
- §3 step 4 credits the census lane with a site-by-site reading "at the
  trained constants". That reading was of R5b, and asks for its own re-check
  on R7. The re-check is trivially true, because R7's `protocol.rs` is R6's,
  but the sentence should say so.

**The residual figures the statement would carry are in §4.** They are
unchanged from round 1. The headline is the sampler bias (D9):
**2^-74.82 (L = 1), 2^-73.82 (L = 2), 2^-70.37 (L = 22) per run**.

This keeps D22's caveat: each step survived one independent attack; it is
not a proof re-derived by the owner.

---

## 1. Round-2 closing items 1–5

| # | Item (REVIEW2 §5) | Evidence | State |
|---|---|---|---|
| 1 | Name the tree; read its changed pins; re-gate; one CLI-path capture | **R7 named.** R7 = R6 plus statement-writing changes in `trained_block.rs` only (R7_VERDICT). The six R5b → R7 changed pins were read in tools v8. A failing-first probe (the v7 driver) refuses R7's `run.rs` and suspends every stage. R7 captured at L = 1, 2, 22, on both inputs. **12 R7 records all PASS with 0 unexplained leaves and no pin moved** [READ, `r7-summary.json`]: L = 1 and 2 in full with every control family; L = 22 pass A; terminal identity 23 / 46 / 506. The CLI-path capture is in (§2.3). The L = 22 full-preimage and joint passes are carried from R5b by reading. I agree with that reading. I read every R5b → R6 hunk in a pinned file in round 2; R6 → R7 touches only statement writing; R6's `private_block.rs` hunk is one test-module line. For this run-wide calibration no hunk moves a draw, an absorb or a published segment byte | **closed** |
| 2 | G-7: NL-1 and the terminal surjection at the trained export | NL-1 S0–S5 PASS at the trained slot-IR export. The surjection on R5b captures: A 36/36 disclosed 0; H 8/9 with the sum claim disclosing 2; endpoints and boundary 0 [READ, `EV/g7/`]. The duplicate-lookup reading has been ruled (**D31**). The inputs (`argument.rs`, `layout.rs`, `slot_ir.rs`, `pad.rs`, `witness.rs`) are byte-identical R5b → R7. **The R7 re-run of the surjection is running** (`g7/r7/g7-ts-r7.log`): stage 1 clean on all four R7 bundles; stage 2 A 36/36 disclosed 0 on dense-l1 so far | **closed but for the one pending clause** |
| 3 | G-R4 at run scope (L = 2) | The stage-47 replay of a two-block run passes on R7 and R5b, both inputs [READ, `r7/gr4-run_l2_*.log`, `q6/q6-run_l2_*.log`]. All seven roots (B_0, A_0, M_0, H_0, A_1, M_1, H_1) are rebuilt from one stream; the prover consumed exactly the predicted 77,919,360 bytes; 5 of 5 non-vacuity perturbations move their roots, including a stream reset before stage 1. L ≥ 3 runs the same loop body and is stated as uncovered in the draft's §8 | **closed** |
| 4 | Text on R7: one basis; M-9 operational; `prover_reported`; P-7; admissibility with CS-3; census to completeness | One basis (R7), with history in Appendix H. §2 defines "accepted" by one's own fresh `stack-verify` (N-r6-a). §5 row Q-2 is enforced in R7 (one of three backend constants; reviewed r7). §1 and §6 call the backend a self-report and note N-r7-c. §2's admissibility includes CS-3 in the sealing pass (R7 `trained_block.rs:2075`). The census is a completeness item. Two small staleness errata remain (§3) | **closed** (errata E-1, E-2) |
| 5 | The owner's confirmations | **D28** (CS-2 / CS-5 not needed at trained profiles, 09:31). **D29** (census is completeness, 09:31). **D31** (identical lookup pairs kept, 10:29). **The D9 figures on Victor's sheet** (09:31: 2^-70.4 ≈ 6.6×10^-22 per run, 2^-50.4 ≈ 6.6×10^-16 per million runs; arithmetic checked) | **closed** (the draft has not caught up: E-1) |

---

## 2. What R7 and tools v7/v8 changed, attacked

### 2.1 G-4's tightened M9-3 criterion (tools v7, kept in v8)

`zk60_native_rg_m125controls.py:215-406` [READ]. Each unpadded domain is
made to look padded in two arms:
- **indicator arm:** the pad state forced everywhere;
- **draw-count arm:** only the host slot's `pad_on` forced.

**What counts as the control firing:**
- The host's refusal must match one of two regular expressions in full. These
  are the port's own refusal texts: the public-table count, and the
  definition-draw count.
- Its surplus must be exact: 1 table, or 2 draws (the pad `mu` and `ζ`).
- The set of slots that stop being checked must be exactly
  `pad::indicator_slots` (indicator arm), or exactly the host (draw-count
  arm).
- Any other refusal, by name or not, does not count. This is the opposite of
  the loosening I warned against in Q-8.

**Measured on every R7 full pass:** D 48/46, Kv 24/22, Q 28/26, S 32/30,
T 15/13, both arms ok [READ, `r7-summary.json`].

**False-negative risk.** None found:
- a port that ignored the pad state would refuse in neither arm and fail
  the control;
- a wrong honest pad term would break the terminal identity, which is
  506 / 506 at L = 22.

`INDICATOR_SLOTS` is a transcription of `pad.rs`, which is pinned and
byte-identical R5b → R7.

### 2.2 PC-9b (tools v7)

`zk60_native_rg_pincontrols.py:123-133` [READ]. The control builds a pre-G-2
writer: tree A's `run_capture.rs` digest, one of the three G-2 files pinned,
the other two dropped. It must make the gate refuse and hold stages 7, 8 and
10 on any bundle.

On R7 L = 1 it does exactly that: "PC-9: ok=False status=NOT-OK held=3
exact=True" (NOT-OK is the intended outcome). The draft reports 12 of 12 pin
controls exact.

v6's construction was a no-op on a writer that already pins all three files.
PC-9b closes that, and the general rule (a missing required pin is refused)
is exercised by PC-7, PC-8 and PC-11.

### 2.3 The CLI-path capture (P-18)

`EV/r7cli/p18-{prove,verify,capture}.log` [READ].

- **`stack-prove`** (the R7 binary):
  - prints `prover_start` with the constant CPU backend text;
  - seals with the builder's own pass before the run header ("parity
    bit-exact … before the run header: ruling H-1"), using a prover-private
    `--seq-dir`;
  - writes 2 segments: 11,320,120 B and 11,698,968 B. The lengths are fixed
    by the shape and the segment's position (first or last), not by data.
- **A fresh `stack-verify` process:**
  - verifies the run;
  - prints `statement-published` "from its own rendering and the hashes of
    the verified bytes";
  - removes the prover's copy.
- **The capture test:**
  - rebuilds the statement;
  - runs the CLI's own `verify_run_from_dir_hashed_with`;
  - finds the 23,019,088 segment bytes equal to `statement/segments.json`
    entry for entry;
  - finds every key on the allow-list.
- **The gate's E3** recomputes the layers 7–8 identity `ef061000…` from the
  export, equal to the published statement, for both the CLI bundle and the
  harness bundle (`r7/cli/e3-vs-cli-statement-*.json`, ok).
- **Pass A and every check pass on the CLI bundle**, with 0 unexplained
  leaves.

The prover's kept unverified statement (`r7cli/prover-unverified-statement/`)
holds only `UNVERIFIED.txt`, `expected.bin`, `segments.json` and
`statement.json`.

So the production CLI's receipts are now in evidence, and they agree with the
harness receipts.

### 2.4 R7's statement-writer changes

- **Q-2's backend allow-list** holds, per R7_VERDICT §2: one of three
  constants, checked by both provers and by the verifier before publishing.
  So `prover_reported` carries no free text.
- **N-r7-c:** a CPU prover can still name a device constant. It is a
  self-report, and the draft's §6 already scopes the statement by the named
  CPU binary's digest.
- **N-r7-b:** verifier refusals can echo a prover-chosen number. That is
  local output only, and §6 keeps verifier output unpublished.
- **N-r7-a:** the stale-directory cleanup depends on `/proc`. A live
  writer's temporary directory could then be removed, but its rename then
  fails and nothing is published. That is liveness, not a channel.
- **The cleanup itself never reads or publishes** the stale directory.

**No new channel.**

### 2.5 R7 records and tools

- All 12 R7 records ran under the 54-file v8 manifest ("54 listed, 0 moved,
  0 unlisted"), so the v8 tool-hash repair (G-14) applies to them.
- pass A at L = 22 shows the terminal family's controls as not requested,
  explained by rule (a); that is PASS by design.

---

## 3. Errata to the draft (wording; no figure moves)

- **E-1. The owner's confirmations are no longer owed.**
  - §0 "What is not done" and §10b item 2 list the three confirmations
    (CS-2 / CS-5, the census, the D9 figures) as owed. They were made at
    09:31 UTC: D28 and D29 in the register, and the D9 figures on Victor's
    sheet. D31 followed at 10:29.
  - §3 step 4 says "for the owner to confirm" on Q-7, and §3b P-13 says the
    same.
  - Repair: cite D28, D29 and the sheet, and move the item to §10a.
- **E-2. The census reading is credited too broadly.**
  - §3 step 4 says "the census sub-lane's site-by-site reading at the
    trained constants agrees". That reading lists R5b's lines and ends with
    "Re-check that list against R7's `prove_core` and `seal_and_record`"
    (`EV/census/PROGRESS.md:263-265`).
  - The re-check holds trivially: R7 changes only `trained_block.rs` from
    R6, and R6's `prove_core` fallible calls are the list REVIEW2 Q-7 read
    (shape checks, CS-3, the LogUp inverses, `argument`, `check_opening`).
    So D29 stands.
  - Repair: one sentence saying so.

---

## 4. The residual figures the statement would carry

All [COUNTED]; recounted independently in round 1 (`recount/`), and
unchanged on R7 because the shape, the draws and the commitment counts are
unchanged. Per run, at q = 2^128 hash queries.

| Term | L = 1 | L = 2 | L = 22 | Kind |
|---|---|---|---|---|
| **Total distance** (equal to the D9 sampler term; field draws 2,381,476 / 4,741,448 / 51,940,888 × 2^-96) | **2^-74.82** (≈ 3.0×10^-23) | **2^-73.82** (≈ 6.0×10^-23) | **2^-70.37** (≈ 6.6×10^-22) | distance |
| Refusal clause for an admissible input (S-4), two-world | 2^-117.42 | 2^-116.42 | 2^-112.96 | distance |
| Salt guessing | 2^-111.9 | 2^-111.1 | 2^-107.8 | distance |
| Challenge pre-query | 2^-115.5 | 2^-114.5 | 2^-111.0 | distance |
| Leaf-input / transcript-input collisions | 2^-224.8 / 2^-231.9 | 2^-223.2 / 2^-230.0 | 2^-216.6 / 2^-223.1 | distance |
| Constructor vs absorb (B10) | 2^-128.00 | 2^-128.00 | 2^-128.00 | distance |
| Generator-key collision | 2^-252.4 | 2^-252.4 | 2^-252.4 | distance |
| Tag-key collision | zero by test | | | distance |
| Generator | the named assumption (E-1; X-1 across runs); in-model alternative 2^-125.4 | | | assumption |
| Many runs, linear: 10^6 runs | 2^-54.89 | 2^-53.89 | 2^-50.44 (≈ 6.6×10^-16) | distance |
| Refusal on degenerate challenges, (3L+1)/p | 2^-62.00 | 2^-61.19 | 2^-57.93 | **liveness, not distance** |

Every distance term other than the sampler is at least 37 bits below it.

The statement's §2 sentence quotes exactly these:
- 2^-74.8 / 2^-73.8 / 2^-70.4 for the view;
- 2^-117.4 / 2^-116.4 / 2^-113.0 for the refusal clause.

These match the table to the rounding shown.

**Conditions it would carry**, as the draft's §5 and §6 list them:
- the toy's seven, at R7's 46 pins;
- the shaped invariants;
- C-R1, C-R4, C-R5 and Q-2 (the last two enforced in R7);
- P-4 as a hypothesis;
- the operating rules: M-9 by one's own fresh `stack-verify`; prover stdout
  and verifier output private; no `seq_*` in a verifier's export; the named
  CPU binary; D23.

**It lapses on any of the following** (draft §9):
- a pin change, including integration into a commit (re-read and re-gate,
  as D22 did at `4751b93`);
- any other calibration or T;
- a GPU-built receipt;
- a deployment that breaks a rule.

---

## 5. Evidence (this round)

**The draft, the native tree and the register:**
- the draft (sha256 `080cddbc…`): §0–§11 and Appendix H;
- `results/zk60_d24_review_20261017/R7_VERDICT.md`;
- `results/zk60_1b_native_20261017/r7/r7-vs-r6.patch` (files touched);
- `r6/r6-vs-r5b.patch`, the `private_block.rs` hunk;
- `docs/zkmatrix-poc/ZK60_DECISIONS.md` rows D28, D29, D31;
- `docs/zkmatrix-poc/ZK60_RULINGS_FOR_VICTOR_20261017.md`, the D9 block.

**The gate's evidence, under `results/zk60_gate_tinyllama_20261017/`:**
- `r7/r7-summary.json`;
- `r7/light_queue.toolcheck` and `r7/cli_queue.toolcheck` (54 / 0 / 0);
- `r7/l1/r7-pincontrols-l1.log` (PC-9);
- `r7/gr4-run_l2_*.log` and `q6/q6-run_l2_*.log`;
- `r7cli/p18-*.log`, `r7cli/prover-unverified-statement/`;
- `r7/cli/e3-vs-cli-statement-*.json`, `r7/cli/cli-published-statement.sha256`;
- `g7/PROGRESS.md`, `g7/r7/g7-ts-r7.log` (in progress at 12:02 UTC);
- `census/PROGRESS.md:55-75, 255-265`.

**The tools:** `ops/zkp-mvp/gate-tinyllama/scripts/` = v8 (54 of 54);
`zk60_native_rg_m125controls.py` (M9-3, two arms);
`zk60_native_rg_pincontrols.py` (PC-9b).
