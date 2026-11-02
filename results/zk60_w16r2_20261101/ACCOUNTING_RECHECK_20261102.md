# W16R2 (D59) accounting: the independent re-check (condition 2)

Written 2026-11-02 by an independent re-checker (Claude), who did not write `ACCOUNTING.md` or `count.py`.
Read-only on the tree; nothing built, nothing run but Python. The recomputation is `accounting_recheck.py`, and its
output is `accounting_recheck.out.txt`. The script does not import `count.py`. It derives the slot table, the lookup
counts and the range-table size from the shape parameters by replicating the Rust rules, parses the code-printed lines
with its own parser, and takes log2 by a different method.

**Verdict: CONFIRMED WITH CORRECTIONS.**
- Every number in `ACCOUNTING.md` reproduces to the printed digit.
  - Per regular opening: 2^-105.934.
  - Whole run: 2^-97.361 for 8B T128 and 2^-97.660 for Shieldstral T128.
  - W16 today: 2^-105.604 per opening and 2^-97.269 for the 8B run.
- The openings counted are the openings the code runs. The δ/2 lemma's hypotheses hold at every one of them, and M is
  untouched.
- The corrections are to the text, not to any figure: findings 1 and 2. The Low items 3 to 5 are follow-up gaps.

## Recomputed figures beside ACCOUNTING.md

All entries are log2 and exact (rational arithmetic, with log2 taken at the end).

**Per regular opening.** n = 2^14 and N = 2^15. K = n + Q, since q_pad = Q (`ZkOpts::standard`). e = ⌊(N − K)/2⌋. The
field term is (N + 4,096)/p².

| Q | K | e | column, exact (1 − (e+1)/N)^Q | column, (1 − δ_t)^Q | column + field | against W16's −105.604 |
|---:|---:|---:|---:|---:|---:|---|
| 256 | 16,640 | 8,064 | −104.346 | −104.331 | −104.342 | short |
| 257 | 16,641 | 8,063 | −104.739 | −104.731 | −104.733 | short |
| 258 | 16,642 | 8,063 | −105.146 | −105.131 | −105.139 | short |
| 259 | 16,643 | 8,062 | −105.539 | −105.531 | −105.529 | short |
| **260** | **16,644** | **8,062** | **−105.946** | −105.931 | **−105.934** | **meets it (minimum Q)** |
| 261 | 16,645 | 8,061 | −106.338 | −106.331 | −106.322 | meets it |
| 262 | 16,646 | 8,061 | −106.746 | −106.730 | −106.725 | meets it |

**Headline figures.**

| Figure | ACCOUNTING.md | Re-check |
|---|---:|---:|
| W16 per opening: column / field / both | −105.609 / −113.684 / −105.604 | −105.609 / −113.684 / −105.604 |
| W16R2 per opening: column / field / both | −105.946 / −112.830 / **−105.934** | −105.946 / −112.830 / **−105.934** |
| M per opening: column / field / both | −106.250 / −115.678 / −106.248 | −106.250 / −115.678 / −106.248 |
| Minimum Q at rate 1/2, column only and column + field | 260 | 260 and 260 |
| Per block, 8B and Shieldstral: N_lk / T_d / LogUp | 34,897,920 / 127,668 / −102.922 | 34,897,920 / 127,668 / −102.922 |
| Per block, Σ(main + ext)·deg: 8B / Shieldstral / rung | 1,099 / 1,159 / 924 | 1,099 / 1,159 / 924 (derived from `Shape::slots`) |
| Per block, zero-check allowance: 8B and Shieldstral / rung | 1,179 / 957 | 1,179 / 957 |
| **W16R2 8B T128, L 32, 97 + 32 M.** Column / field / LogUp / sumcheck / zero-check / **whole** | −99.004 / −106.166 / −97.922 / −112.898 / −112.797 / **−97.361** | the same, **−97.361** |
| W16 8B T128 whole | −97.269 | −97.269 (+0.092 bit for W16R2) |
| **W16R2 Shieldstral T128, L 26, 79 + 26 M.** **Whole** | **−97.660** | **−97.660** (column −99.301, LogUp −98.222) |
| W16 Shieldstral T128 whole | −97.568 | −97.568 |
| W16R2 rung, L 1 / L 3 | −103.565 / −102.180 | −103.565 / −102.180 |
| W16 rung, L 1 / L 3 | −103.303 / −101.928 | −103.303 / −101.928 |
| Margin over D27's ~95: 8B / Shieldstral | 2.36 / 2.66 | 2.361 / 2.660 |
| 8B T512 (carried; R13 layout, MEMO_G02 terms): today / Q 258 / Q 260 | 94.66 / 94.66 / 94.68 | 94.656 / 94.662 / 94.684 |

**Sensitivities** (8B T128, whole run):
- If the far and close halves were **added** per opening, without the lemma check's refinement 1, the whole run would
  be 2^-97.036. See finding 7.
- Dropping the carried 4,096 ceiling leaves 2^-97.361. Multiplying it by 100 gives 2^-97.317.
- The reduction bias of the row weights, (1 + p/2^128)^(2m) − 1 at m = 2,606, is 2^-51.65, and it multiplies the bound.
- With powers of one challenge instead of independent weights (BCIKS20 Thm 1.6), the field term would be 2^-101.65
  per opening. So A3′(a) is load-bearing, as stated.

## Findings

**1. Low (a wrong explanation; the number is right).**
- **Location:** `ACCOUNTING.md`, "Notes on the inputs", the bullet "Σ(main+ext)·deg … differs between 8B and Shieldstral
  because their attention geometry differs".
- **What is wrong:** the attention geometry is identical (T 128, 32 heads of 128, 8 KV heads).
  - The difference of 60 comes from the model width: Shieldstral's d = 3,072 pads to 4,096.
  - So `Dom::D` pads, and the support indicator adds one degree to the three `Dom::D` slots of
    `INDICATOR_SLOT_DOMAIN` (SS, SSM, DZC): 3 × (19 + 1) = 60.
  - 8B's D domain (128 × 4,096) does not pad. Both models' F domains pad.
  - Re-derived in `accounting_recheck.py` §2.
- **Fix:** replace the clause with this reason.

**2. Low (overstated reproduction claim).**
- **Location:** `ACCOUNTING.md` in two places:
  - the Headline bullet "These figures reproduce the lemma check's §6 exactly";
  - "Whole run" checks, "W16R2 at 8B T128 reproduces its row #1 (2^-98.99, …)".
- **What is wrong:** the counted column term is 2^-99.004, not 2^-98.99.
  - The lemma check priced each opening in the non-integer form (1 − δ_t)^Q = 2^-105.931.
  - With that form, I get 2^-98.992. With the exact integer form, I get 2^-99.004.
  - The whole run is 2^-97.36 either way.
- **Fix:** say that the column term agrees to 0.012 bit, the gap being the lemma check's non-integer form, and that the
  whole run is identical to two decimals.

**3. Low (follow-up from the lemma check §8 item 5; not listed under "What is not done here").**
- **What is missing:** the in-tree bit counters still count δ/3 only. They are:
  - `hashline/src/private_block/token_io.rs:274-287` (`column_log2`, `hiding_opening_log2`);
  - `token_io/run.rs:146-190` (`whole_run_of`; the D27 policy gate is at `:916`);
  - `token_io/classify.rs:872-910` (`whole_run_of_classifier`; the gate is at `classify_run.rs:250`).
- **Where the regime lives today:** `ColumnRegime`, `column_term_log2` and `regular_column_terms_log2` are test-only
  (`#[cfg_attr(not(test), allow(dead_code))]`, `shape.rs:303-331` and `:793-811`). The regime enters no counter, claim
  header or digest. It is bound only through the profile string.
- **What would happen:** a W16R2 block shape reaching a token or classifier run would be priced at (1 − δ/3)^260 at
  rate 1/2. That is 2^-67.20 per opening, and 2^-60.6 over 97 openings (`accounting_recheck.py` §7). The D27 policy gate
  would then refuse the run.
- **Severity reasoning:** this fails closed, so nothing is over-claimed. But D27 makes the regime a profile parameter
  of the counters.
- **Fix:**
  - List the gap in ACCOUNTING.md.
  - Before any W16R2 profile is registered or composed with token I/O, route these counters through
    `Shape::column_regime()`, with N/|Fp2| as the δ/2 field term.
  - Put the regime into any tier claim header.

**4. Low (accounting documents not amended; the lemma check §8 items 2–3).** These documents still describe δ/2 as
"not adopted", or are δ/3-only, with no pointer to D59 or W16R2:
- `docs/zkmatrix-poc/ZK60_FABLE_SECURITY_OBLIGATIONS.md:376` and `:431`;
- `results/zk60_soundness_recount_20261017/RECOUNT.md:211` and §5 (`:294-296`);
- `MEMO_G02.md` §2 and §3.2;
- D15's row text;
- the header comment of `zkp-core/src/pcs.rs:16-19`, which is stale and also uses δ = 1 − 1/inv_rate;
- the comments in `hashline/src/zk.rs`.

Condition (2) names "the accounting documents (D15/D24/D27 figures)".
- **Fix:** add dated one-line notes in those places pointing to ACCOUNTING.md for the W16R2 profiles. Otherwise, list
  them under "What is not done here".

**5. Low (a test-coverage gap; no defect today).**
- **Location:** `w16r2_the_lemmas_load_bearing_invariants_are_pinned` (`w16r2_tests.rs:807-853`).
- **What it covers:** it pins the tagged verifier in `protocol::verify_core` and `run.rs`, but not in `run_fork.rs`.
  ACCOUNTING A7 says a D55 run can take a W16R2 base, and the D55 preflight is profile-agnostic.
- **What the code does today:** `run_fork.rs:1075`, `:1095` and `:1101` do call `verify_zk_tagged`, with path-length
  checks at `:1046-1049` (and `:941-943` in each fork). So A3′(d) holds there.
- **Fix:** add `run_fork.rs` to the same `!contains("pcs::verify_zk(&")` scan.

**6. Info: the union bound is complete at the printed digits.** The terms counted are REVIEW_R14's and REVIEW_W16's:
column, PCS field, LogUp, sumcheck and zero-check, over 3L + 1 regular openings, L M openings and L blocks. The terms
not itemised are all negligible:
- **M's θ batching** of 34 functionals (powers of one θ, `zk.rs:521-535`, `:652`): ≤ 32·36/|Fp2| = 2^-117.8 per run,
  counted conservatively at 36.
  It is plausibly inside M's carried ceiling.
- **The λ claim batching:** absorbed (lemma §4).
- **The reduction bias:** ×(1 + 2^-51.65).
- **Merkle and FS hash collisions:** not budgeted, as before (A1/A2, REVIEW_R14 A2).

The figures remain interactive, per-attempt rates (A2), as D27 reads them.

**7. Info: one step carries D59's "no bits traded per opening" claim, and it is sound.**
- **The dependence:** the claim rests entirely on refinement 1 (the far and close cases are exclusive, so the bound is
  the max of the two halves, not their sum). Without it, a W16R2 opening would be 2^-104.93, below W16's 2^-105.60.
- **The re-derivation:** I re-derived refinement 1 and agree with it.
  - The root fixes U before λ, r and the indices, so exactly one case applies.
  - Far: ≤ N/|Fp2| + (1 − (e+1)/N)^Q.
  - Close: ≤ 1/|Fp2| + (1 − (e+1)/N)^Q, because a wrong clear vector is a distinct codeword at distance
    ≥ N − K + 1 − e = e + 1 from ρ_gᵀU.
- **Fix:** ACCOUNTING should name this dependency in its "Terms" §1 so that a later reviewer attacks the right step.

**8. Info: the choice of baseline.**
- "No soundness given up" is measured against W16 under δ/3 (D59's own baseline, about 105.6 per opening), and it
  holds there.
- Under the same δ/2 lemma, today's rate-1/4 W16 would be 2^-172 per opening and 2^-97.78 for the whole run (lemma
  check §6). So W16R2 sits 0.42 bit below what rate 1/4 could claim under δ/2.
- This is within D59's wording, and it is worth one sentence for later white-hat readers.

**9. Info: the printed inputs.**
- **The match:** every integer field of all six `W16R2-ACCOUNTING` lines equals my derivation or the code constant
  it names, 21 fields per profile:
  - geometry and q_pad;
  - the e at δ/2;
  - endpoint geometry;
  - M constants 12 / 9 / 256 and m_rows = 2·23 + 4;
  - the lookup words, from `lookups_w16`'s per-domain counts times the lifted domain sizes;
  - exp, ACT, Σ2^w over distinct widths, the slots, Σ(main + ext)·deg and the zero-check sum.

  `column_log2` matches to 4 decimals. The six lines in `logs/accounting_inputs.log` are identical to those in
  `logs/w16r2_tests_nocapture.log` (diffed). The sources they were printed from have no uncommitted changes.
- **Not re-derived:** the row counts (2,501 / 2,602 / 37). They enter only the bias and the byte counts.
- **Inferred, not read:** the rung's 1,015,808 lookup words reproduce only with 9 S lookups instead of 7. I inferred
  that SR/SG are two-limb at the rung (wrho_s = 17, the (1, 1) family). I did not read the rung's calibration.
- **Cosmetic issues:**
  - (a) The W16 (δ/3) lines print `"e_unique": 24448`, the δ/2 value at rate 1/4, which nothing uses. Print `null` or
    16,298 there.
  - (b) `count.out.txt` line 1 names a worktree path (`.claude/worktrees/agent-ac8a2b43086591196/…`). Re-run it with
    the in-repo path.
  - (c) The Rust gate and `count.py` accept the Q = 259 term within 0.01 of −105.53. Its exact value is −105.5385,
    0.0085 from the tolerance edge. Assert −105.539 instead.

**10. Info: D27's named workload.**
- No W16R2 profile exists at 8B T512, as ACCOUNTING says.
- I reproduced the lemma check's carried T512 figures from MEMO_G02 §2's terms: 2^-94.656 today, 2^-94.662 at Q 258,
  2^-94.684 at Q 260. These are R13-layout figures with the derived LogUp convention, not W16 ones.

## The five checks, in brief

**1. Every figure, from first principles.** Done; see the table. All of 2^-105.934, 2^-97.361 and 2^-97.660 confirm.

**2. The δ/2 lemma's hypotheses at every rate-1/2 opening, and the opening count.** Read in code:
- **Row weights:** `prox_rho = tr.challenge_fp2_vec(rows)`, one squeeze per row over every committed row
  (`pcs.rs:954`; `transcript.rs:120-133`).
- **Index order:** the indices are drawn after both `pcs-vec` and `pcs-prox` are absorbed. They are masked u64 draws
  with replacement over a power-of-two N (`pcs.rs:1199-1211`; `transcript.rs:136-148`).
- **Pads:** q_pad = Q (`pcs.rs:582-584`), and the verifier refuses q < Q and any wrong vector length.
- **Code:** the verifier's encoder is f_data + (X^n − 1)·g_pad on 7·G_N, a bijection onto degree < n + q_pad
  (`pcs.rs:644-677`).
- **Path length:** checked at `pcs.rs:1183-1188`.
- **Geometry:** `pcs_params_at`, `endpoint_pcs_params` and `BoundarySpec::params` (`protocol.rs:72-88`;
  `run.rs:678`; `boundary.rs:162`) all give (14, 2, 260). `Shape::build` refuses any other geometry under a W16R2
  string (`shape.rs:1014-1023`), and CS-8's rebuild checks the result.
- **Openings:**
  - Per block, A and H go through `verify_zk_tagged` (`protocol.rs:2036`, `:2066`), and M is opened once (`:2023`).
  - Per run: each B_k is opened once, in stage k + 1, with both blocks' claims (`run.rs:1371-1383`). The input
    endpoint is opened in stage 0 (`:1413`) and the output endpoint in stage L − 1 (`:1445`). That is 3L + 1 regular
    openings and L M openings.
  - The D55 path has the same count (`run_fork.rs:1061-1101`).
- **Result:** nothing is counted that the code does not do. Nothing the code does at rate 1/2 is left uncounted,
  except the token and classifier counters of finding 3, which are outside A7's scope and fail closed.

**3. M is untouched.**
- M's constants are its own: `zk.rs:373-375` gives MASK_LOG_MSG 9, MASK_LOG_DOM 12 and MASK_Q 256.
- `mask_verify_tagged` reads no shape field (`zk.rs:648-700`).
- The wire uses `MASK_CHECKS = zk::MASK_Q` (`wire.rs:25`; `run_fork_wire.rs:77`, `:155`, `:231`), and the byte count
  uses `MASK_PADS`.
- M is counted at its old bound: (3/4)^256 and (1,025 + 4,096)/|Fp2|, L per run.

**4. The union bound is complete,** and the whole run clears D27's ~95 at T128: by 2.36 bits for 8B and 2.66 for
Shieldstral. See finding 6. D27's named T512 workload is not counted for W16R2 (finding 10).

**5. The printed numbers equal the code's constants** (finding 9).
