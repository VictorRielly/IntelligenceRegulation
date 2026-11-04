# W16R2 at Q = q_pad = 280 (D59 F2 ruling) and review F6 (the counters take the regime)

Date: 2026-11-03. Branch `worktree-agent-a7e40cbdbbf3f1b5d`, based on `perf/zk-batch-optimizations` at `19d85dad`
(fast-forwarded before any edit). Not merged, not pushed. Nothing here registers a W16R2 profile.

Ruling (Victor, 2026-11-02, D59 F2): Q = q_pad = 280 for `A`, `H`, every `B_k` and both endpoints of every W16R2
profile (`W16R2_RUNG_H24`, `W16R2_SHIELD_T128_H24`, `W16R2_8B_T128_H24`), code rate unchanged (1/2). `M` keeps
`zk::MASK_Q = 256`. Review F6 (`results/zk60_w16r2_20261101/REVIEW_W16R2_20261102.md:282`): the production bit
counters must take the profile's column regime before registration, and three stale comments are restated.

Status:
- Code: committed.
- Targeted chain: exit 0, 0 failed checks.
- Dev bytes: unchanged.
- New W16R2 goldens: CPU = Metal.
- Recount: confirmed.
- Privacy gates at Q = 280: pass.
- The full suite is deferred to `logs/q280_deferred.sh` and had NOT run when this was written (see "Runs").

## 1. The code change

| file | change |
|---|---|
| `hashline/src/private_block/shape.rs` | `W16R2_OPENED_COLS` 260 → **280** (the one constant every W16R2 site derives Q and the pad count from); its doc and the W16R2 block comment restated (2^-113.93 per opening, 266,624 data bytes per clear vector, `inv_rate2/Q280` keeps the W16 parameter line's length); `ColumnRegime`, `column_term_log2`, `Shape::column_regime` lose their test-only `dead_code` allowance (production reads them now) |
| `hashline/src/private_block/token_io.rs` | F6: `regular_opening_log2(regime, log_n, inv_rate, q)` (GeneralCode = exactly `hiding_opening_log2`, the same float; UniqueDecoding = BCIKS20 Thm 3.1 through `shape::column_term_log2`, `K = n + q_pad` from `ZkOpts::standard`) and `regular_opening_field_log2` (GeneralCode = the carried 2^-113; UniqueDecoding = `(N + 4096)/p^2`, 2^-112.83 at N = 2^15) |
| `hashline/src/private_block/token_io/run.rs` | F6: `push_block_openings` (the L blocks' A, H, M and the L + 1 boundaries, in the old order, at the block profile's regime), `omitted_bound`, `whole_run_words`; `WholeRun` carries `block_regime` and `block_regime_openings`; the token run's whole-run figure and parameter line go through them |
| `hashline/src/private_block/token_io/classify.rs` | F6: the classifier run's figure and parameter line through the same three helpers |
| `hashline/src/zk.rs` (comments only, :23 and :2032) | restated with both regimes: D15's delta/3 prices this path and `M`; D59's unique-decoding count is only the W16R2 profiles' rate-1/2 regular openings |
| `zkp-core/src/pcs.rs` (comment only, :15-19) | the stale `delta = 1 - 1/inv_rate` header restated: the ZK code is `RS(n + q_pad, N)`, both regimes with their formulas and figures, the regime a caller's profile fact |
| `hashline/src/private_block/wire.rs` (comment only) | the W16R2 Q named by its constant |
| `hashline/src/private_block/w16r2_tests.rs` | the two deliberate literal pins updated (the profile-facts test, renamed `..._q_280_...`, and the rung golden); two new tests (below); module and control docs |
| `hashline/src/private_block/w16_privacy_gate_tests.rs` | the doc's Q; `rank_fp` / `pad_codewords` / `pad_rank` made `pub(super)` for the new privacy test |

**Registered bytes cannot move:**
- Every non-W16R2 profile has `ColumnRegime::GeneralCode`. On that branch the new counter functions are the old
  float operations (the new F6 test asserts it bit for bit at every profile this lane builds: the column term, the
  field term, the pushed sequence, the omitted bound and the parameter-line words).
- The new parameter-line words appear only at a `UniqueDecoding` block shape, and no run profile carries one.
- The block, boundary and endpoint proofs of every non-W16R2 profile read no changed value. Dev bytes: see "Runs".

## 2. The soundness recount at Q = 280

`recount_q280.py` re-runs both existing scripts (`results/zk60_w16r2_20261101/count.py` and the independent
`accounting_recheck.py`) unchanged in their formulas, with the three W16R2 profiles' Q set to 280. Both check the
code's own printed `W16R2-ACCOUNTING` lines (`logs/accounting_inputs_q280.log`, from this branch's binary) against
their values. It then adds F2's two readings in `count.py`'s exact arithmetic. Output: `recount_q280.out.txt`.
`recount_preview_scratchlog.out.txt` is the same script run first on the builder's throwaway Q = 280 log
(`results/zk60_w16r2_20261101/logs/close/q280_experiment_tests.log`), and its figures are identical.

| figure (log2) | W16R2 Q 280 | W16R2 Q 260 | W16 (rate 1/4, Q 256) |
|---|---:|---:|---:|
| per regular opening, column term | **-113.932** (attained) | -105.946 | -105.609 proven; -172.443 best known attack |
| per regular opening, column + field | -112.278 | -105.934 | -105.604 proven; -113.684 attack |
| 8B T128 whole run (L 32: 97 regular + 32 M openings) | **-97.779** | -97.361 | **-97.269** proven; **-97.783** attack |
| Shieldstral T128 whole run (L 26) | -98.079 | -97.660 | -97.568 proven; -98.082 attack |
| dev rung L 1 / L 3 | -105.655 / -104.080 | -103.565 / -102.180 | -103.303 / -101.928 proven |

The coordinator's arithmetic is **confirmed**: 2^-113.9 per opening (2^-113.932) and 2^-97.78 for the 8B T128 run
(2^-97.779). One correction to the word "parity":
- Under the proven-bound reading, W16R2 at 280 is stronger than W16 by 0.510 bit (8B) and 0.511 bit (Shieldstral).
- Under the best-known-attack reading, it is 0.004 bit SHORT of W16 (2^-97.779 against 2^-97.783, both runs). No Q
  closes that: as Q grows the 8B figure tends to 2^-97.781. The residual is the rate-1/2 field term. Thm 3.1's
  `N/|Fp2|` at N = 2^15, plus the carried 4096 ceiling, is 2^-112.83 per opening, against W16's
  `(floor(delta N / 3) + 1 + 4096)/p^2` = 2^-113.68. The whole-run PCS field term is 2^-106.17 against 2^-106.97.
- So "parity under both readings" holds to 0.004 bit, and exactly only under the proven reading. Q = 278 is
  within 0.005 bit and Q = 275 within 0.010 bit (the sweep is in the output).
- Every figure clears D27's ~95 floor. The whole run stays LogUp-bound (LogUp 2^-97.922 of the 8B total).

The script asserts each of these figures.

## 3. The privacy argument at Q = 280

The argument of `results/zk60_w16r2_20261101/PRIVACY_RECHECK_20261102.md` §2 re-read at 280. It has four steps:
- (H1) Q ≤ pads. Q = q_pad = 280 by construction, and the s ≤ 280 distinct opened points see a full-rank pad block.
- (H2) No opened position is pad-free. Z_n ≠ 0 on the coset.
- (H3) Room for the pads: n + Q = 16,664 ≤ N = 32,768.
- (H4) The mask rows cover every clear combination. This step reads no Q.

Checked in code by the new test
`w16r2_tests::w16r2_at_q_280_the_pad_block_is_full_rank_on_any_q_distinct_opened_points`:
1. Q = q_pad by construction at every W16R2 shape and both geometries. That means `pcs_params_at`,
   `endpoint_pcs_params` and `ZkOpts::standard`, and the test reads `ZkOpts::standard`'s text. An honest opening
   draws exactly Q indices.
2. The production encoder's pad block, for all 280 unit pads at all 32,768 positions, is `diag(Z_n(x_j)) x_j^i`. The
   x_j are pairwise distinct and Z_n(x_j) ≠ 0 at every position. A Vandermonde block times a nonzero diagonal has
   full rank on ANY ≤ 280 distinct rows.
3. The rank is also measured: 280 at nine stress / random 280-point sets and at a real opening's draw, and exactly
   280 at 281 points.

The capture-level PG-R2 gate and its controls ran on this branch's binary. See "Runs".

## 4. F6 and what is not done here

- **Done (production tree):** the token and classifier whole-run counters price block and boundary openings by
  their profile's regime. That covers the column and field terms, and the parameter line names a non-D15 regime
  and its count. Test: `w16r2_tests::w16r2_f6_the_whole_run_counters_price_each_block_opening_under_its_profiles_regime`.
  - At each W16R2 shape the counters give 2^-113.932 per opening, where the old δ/3 formula gave 2^-72.27.
  - The 8B T128 block part is 2^-101.228, the same as `count.py`'s column term.
- **Not done: the R14 tier counter `split_security.rs`** (review §8 item 5's `Params` / `Claim` / digest). It is
  not in the repository. It exists only under the main checkout's `results/zk60_sol_20261031/r14-security-tier/source-tree/`,
  which is untracked, in no branch's history, and Sol's file, so off limits.
  - What it needs before it can count a W16R2 workload:
    - `Params` gains the regime, from `Shape::column_regime`, and `n + q_pad`.
    - `finish` uses `power_units(N - e - 1, N, q)` with `e = (N - K)/2` and the field erasure `N` under
      `UniqueDecoding`.
    - The regime enters `Claim::encode` and the digest only at `UniqueDecoding` (or under a new VERSION), so no
      existing claim digest moves.
  - Today that counter refuses a W16R2 workload (it fails closed), as the D59 row records.

## Runs

**`logs/q280_targeted.sh`.** Exit 0, 0 failed checks (`logs/q280_targeted.out`).
- Run detached, every leaf guarded with `ZK60_GUARD_POLL_SECS=0.5`.
- The heavy lock went to the merged gate queue first: the warm build waited 5.8 h, until 05:40 PST.
- The binary is `hashline-7ba0d0401b32d774`, sha256 `fd009444…` (`logs/binary.sha256`).
- These are not timing figures: the box was not quiesced, and no timing is used.

| step | result | floor |
|---|---|---|
| build (gpu-metal lib tests + no-feature `check --lib --tests`) | exit 0, **133 warnings** | 133 |
| targeted, CPU, `--nocapture` (`w16r2 shape token_io:: range16_tests::w16_limbs`) | **248 passed, 0 failed**, 28 ignored | — |
| targeted, Metal (`HL_GPU=1 HL_GPU_REQUIRED=1`; m32's set: `w16r2 run::fork w16_privacy_gate range16 s24_tests s25_tests s33_tests hash_domain r19b absorb d60 run_capture`) | **134 passed, 0 failed**, 23 ignored | m32: 132 / 0 / 23; the +2 are this branch's new tests |
| dev bytes, CPU = Metal, both batch-tail modes | **01fa1b2e / 992034f8 / 371e6b00 / 3ab090df** | unchanged |
| R13 / W16 trained digests | 2b0d04bb, 678953f6, 01a6d51d, c5e0bdac | unchanged |
| **W16R2 rung golden** (seeded core, `w16r2_rung_cpu_and_metal_digests_equal_the_golden`, both tail modes) | **c6d5c2d8**, CPU = Metal | was 334e168f at Q 260 |
| **W16R2 trained digests**, CPU = Metal at the cold pass and all three warm passes | **8B 4e189ccc**, **Shieldstral a9a19ee5**, **rung-trained fa656326** | were 5343008a / e0bb5917 / d6879fae; now pinned in `q280_targeted.sh` |
| W16 privacy gate + PG-R2 and C-R2a..c: rung CPU / Metal, 8B CPU (pair) / Metal, W16R2 D55 fork run | **22/22, 20/20, 22/22, 20/20, 25/25** PASS, 0 FAIL | the Q 260 re-check's counts |
| W16R2 rung run, L 3, D12a serial and D55 forks N2 | both verified | — |
| recount on this binary's printed inputs | both scripts: inputs equal; all assertions hold | — |

**What the runs show at Q = 280:**
- PG-R2 sees Q = pads = 280 and clear vectors of n + 280 at every regular opening. Every pad block has full rank
  at its 277–280 distinct opened positions, with a smallest margin of 0, by design.
- C-R2a: the systematic domain drops the rank to 122–145, so the control fires.
- C-R2b: W16's 256 pads drop the rank to 256 at 278–280 positions, so the control fires.
- C-R2c: W16's geometry is refused.
- Counted bytes per block, with codec = count at every W16R2 shape:
  - 8B T128: 26,046,904 B against 25,160,664 B at Q 260, +3.52% (W16: 25,016,184).
  - Shieldstral: 26,047,864 B.
  - Rung: 15,627,000 B.
- One boundary opening is 961,152 B and one endpoint opening at the rung is 692,288 B.

**`logs/q280_deferred.sh` (launched 05:50 PST, detached; marker `logs/q280_deferred.done`).** Order of work:
1. Waits for `q280_targeted.done`, which is already there.
2. Waits for the fr25-fixes worktree's `results/zk60_gate_tinyllama_20261017/round27/fixes/logs/after_queue.done`.
   This is the gate queue's follow-up checks. The runner reads that file and never writes it.
3. Runs the full lib suite, guarded, on the same binary (`logs/full.log`).

How to read the result:
- `.done` = 0 means the failures are exactly the known three and the totals are **898 passed / 3 failed / 92
  ignored**. That is 896 / 3 / 92 plus this branch's two new non-ignored tests.
- 1 means the failure set differs.
- 2 means the totals differ.
- 3 means both differ.
- 100 or more means there was no binary.

The known three are `review_tests::a_toy_receipt_made_before_the_lane_still_verifies`,
`accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces` and
`review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.

**Not run here:** the Python v25 staging gate on Q = 280 W16R2 captures (W16-DEV-PASS at 260, `PRIVACY_RECHECK_20261102.md` §3). It needs freshly written bundles, and its gate tree belongs to the gate queue.

**Notes on the scripts:**
- `accounting_recheck.py`'s section-1 table still marks Q 260 as "<- W16R2". That is the script's own fixed row,
  and its sections 4 and 6 are the lemma check's 260/258 rows. The Q = 280 figures are in the inputs check and in
  sections 3 and 5 of its output, and in `recount_q280.py`'s own section.
- `results/zk60_w16r2_20261101/logs/close/w16r2_close_gates.sh` still pins the Q 260 digests. It is the 260 record,
  so it is left as is.
