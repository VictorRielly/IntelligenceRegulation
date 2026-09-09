# O3 — audit of the implemented mask schedule (`ffn-v3-mr1-fresh-poc/1`)

**Reviewer:** Opus 5 (reassigned from Fable; Fable's FA3/FA6/FA8 analyses keep
their original attribution).
**Source pin:** `b41d036c4c1eb1ed9272494815d742d0ccf29934`
("Implement fresh paired-mask FFN proof of concept").
**Review worktree:** `/home/victor/wt-zk60-fa`, branch `zk60-fable-review`,
HEAD `a8a1bc7f239f98383f4b8991ee2941e5e96ed3f5` (= `b41d036` merged).
**Scope:** read-only. No Rust was changed. This supplies the **bounded
implementation portion** of FA8; it is **not** a privacy verdict and does not
certify the full cryptographic argument. Codex retains the overall judgment.

## 0. What was audited, with digests

| File | sha256 |
|---|---|
| `hashline/src/zk_ffn_fresh_poc.rs` | `6f201890d480be29d58bebf240798aca240814f0131e758ba0376a72d927d01e` |
| `hashline/src/zk_ffn_fresh_poc_tests.rs` | `fb7af41ca4a8a3a8bb8add4bf77d0583fae1b1410b9d377b137eeaf8c2082866` |
| `hashline/src/zk.rs` | `d80755acf7e47cc04f570942820332535420d90af3e597176081acea3041ecba` |
| `hashline/examples/zk60_fresh_ffn.rs` | `84c34212d05fed9f130213b2610cac5eb10bafa071743e91b8367e77eface767` |
| `hashline/src/zk_cfs_safety_tests.rs` (CFS guards, `a5aea1d`) | `ee45a49cda7816c5c64290c69386cec46ff70eec64c7f4457465488aa045fefd` |
| `zkp-core/src/pcs.rs` (grouping, `zk_rhos`, `assert_mask_sites`) | `2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d` |
| `zkp-core/src/rng.rs` (`ZkRng`) | `0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb` |
| `results/zk60_fable_fa6_a5aea1d_cargo.log` (cited evidence) | `9ac289f8c2ec1a2561d592625497cd4c18f6f4f302756441ff8e3365be3fd4ee` |

Measured against, in this worktree: `ZK60_FABLE_MASK_REPAIR.md` (FA3 §1, §2.2,
§2.4, §3, §6, §9), `ZK60_FABLE_CFS_CHANNEL.md` (FA6 §7.2 I1/I3, §7.3),
`ZK60_FABLE_TRANSCRIPT_REVIEW.md` (FA8 S1, S2, D.1–D.3), and
`results/zk60_fable_fa3_mask_schedule.json` (`schedule.commitments`).

The `zk.rs` diff of the pin was read in full
(`git --no-pager show b41d036 -- hashline/src/zk.rs`, 167 changed lines).
All line numbers below are the worktree copies at `a8a1bc7`.

## 1. The realised allocation at the fixed profile

The profile fixes T32/d16/f16, `log_cols` 8, inverse rate 8, Q 256, function 1
(`zk_ffn_fresh_poc.rs:40-46`, `:61-67`), which gives `nb_d = nb_f = 1`,
`n = a_n = w_n = 256`, `log_n = log_wn = 8`, `log_s = 16`, table sizes
`[256, 65536, 128, 1, 16384, 64]` for shifts `(7, 0, 14, 6)`.

I recomputed `ZkLayoutV3::with_masks` independently (exact integers, no field
arithmetic) and got **A 698 rows, H 1326 rows, W 3 rows (P1) / 11 rows (P3)** —
byte-for-byte the counts `ZK60_ROUND16.md` reports and the counts the live test
printed in this worktree (§5). Legacy (`mr1 = false`) recomputes to 681 / 1325 / 7,
so the +17 / +1 / +4 delta is exactly the pair repair.

Row map (mr1):

- **A** — data `0-19`; `a_mf` pairs at `20,22,24,26,28,30,32`; `a_md` at
  `34,36,38`; `a_mgu` `40`; `a_mdd` `42`; `a_prox` `44` (pair `44-45`);
  ACT16 data `46` / mask **pair** `47-48`; INT16 data `49-304` / mask **block**
  `305-560`; rem(7) data `561` / **pair** `562-563`; rem(0) data `564` /
  **pair** `565-566`; rem(14) data `567-630` / **block** `631-694`; rem(6)
  data `695` / **pair** `696-697`.
- **H** — data `0-15`; `h_mf` `(16,17) (18,19) (20,21)`; `h_md` `(22,23)`;
  `h_u` (zero-sum) `(24,25)`; `h_up` `(26,27)`; `h_prox` pair `28-29`; the six
  slots' `h_re/h_im/h_mre/h_mim` blocks from `30` to `1325`.
- **W (P3)** — data `0-2`; `w_mgu` pairs `3-4`, `5-6`; `w_mdd` pair `7-8`;
  `w_prox` pair `9-10`.

**No scalar (single-row) base-field mask remains anywhere in the FFN mr1
layout.** Every enumerated site is a pair, a pair block, or a ≥2-row base block.
(Attention is out of scope here; it is O4.)

## 2. The table

Row → allocation / randomness fill / prover use / verifier use / regression test.

### 2.1 A terminal pairs

1. **Allocation.** `zk.rs:2000-2001` (`with_masks`, `width = 2` under mr1),
   `:2012-2015` — `a_mf = (0..7*nb_f).map(|_| next(2))`,
   `a_md = (0..3*nb_d)`, `a_mgu = (0..nb_d)`, `a_mdd = (0..nb_f)`;
   function-2 pairs `a_pmb`, `a_pmz` at `:2027`. Enumerated by
   `a_mask_rows` `zk.rs:2075-2081` through `mask_range` `zk.rs:2055`.
   **Count:** `2·(7·nb_f + 3·nb_d + nb_d + nb_f)` rows (+`2·2` with the
   predicate) = **12 pairs / 24 rows** here.
2. **Randomness fill.** `zk.rs:2455-2461`: `a_random_rows = a_mask_rows() ∪
   mask_range(a_prox)`, `sort_unstable()` **only under mr1** (this sort is what
   makes the fill allocation-ordered — unsorted, `a_prox` would follow the table
   masks), one `rng.fp_vec(n)` per row. Stream: the single `ZkRng` created by
   `zk_ffn_fresh_poc.rs:108` (`ZkRng::from_os(PROFILE)`), after the P3 W rows
   and before `commit_zk_owned` (`zk.rs:2467`). Test-build row sanity check at
   `zk.rs:2463-2464`.
3. **Prover use.** `zl.eval_mask` (`zk.rs:2056-2058` → `MaskPoint::eval2`,
   `zk.rs:928-930`, i.e. `R_re~ + U·R_im~`) at `zk.rs:2690` (`a_mgu`, p2),
   `:2776` (`a_mdd`, p5), `:2907` (`a_mf`, rho_f), `:3001-3003` (`a_md`, rho_d),
   `:3170-3171` (`a_pmz`/`a_pmb`, rho_p). The value enters `masked_terminal`
   and is absorbed as `gu_term / d_term / zc20_term / zc17_term / pred.term`.
4. **Verifier use.** `build_claims_zk_v3` `zk.rs:3296-3299` (`masked` closure,
   wrapped in `zl.pair_claim` `zk.rs:2059-2067`, which clones the last part,
   shifts its offset by `1 << log_size` and multiplies its coefficient by
   `Fp2::U` — exactly FA3's `(k1, k1·U)`), `:3303`, `:3306-3308`, `:3316-3317`
   (`masked2` with the P3 coefficient pair), `:3336-3346`. Rank / λ / prox
   enforcement: `fresh_poc::check_masks` (`zk_ffn_fresh_poc.rs:228-299`) at
   `zk.rs:3705` (verifier) and `zk.rs:3218` (prover).
5. **Regression test.** `zk::mask_diagnostic::fresh_poc_tests::repaired_fresh_poc_verifies_twice_and_blocks_single_mask_recovery`
   (`zk_ffn_fresh_poc_tests.rs:47`), whose `check_pair_ambiguity` (`:16-45`) is
   run on **`a_mgu[0]` only** (`:73`) and **`a_mdd[0]` only** (`:74`).
   **Gap:** no assertion on any `a_mf[k]` or `a_md[k]` pair, and none on the
   function-2 pairs (function 2 is never proven by this profile).

### 2.2 Singleton table pairs

1. **Allocation.** `zk.rs:2023` —
   `let a_mask = next(if mr1 && rows == 1 { 2 } else { rows });`; enumerated
   `zk.rs:2078`. **Count:** 2 rows per slot with `rows_i == 1`; here 4 of the 6
   slots (`47-48`, `562-563`, `565-566`, `696-697`).
2. **Randomness fill.** the same `zk.rs:2455-2461` loop, in allocation order.
3. **Prover use.** `zk.rs:3088-3089` — `exts[1+3i] = coef·M~(pt)`, and under
   `mr1 && t.rows == 1` a second term `coef·U·R_im~(pt)` read from row
   `a_mask + 1`; feeds `extension` → `tab_term[2i]`.
4. **Verifier use.** `zk.rs:3319-3328` — the table claim is wrapped by
   `zl.pair_claim` **iff `t.rows == 1`**; then `check_masks` (`zk.rs:3705`).
5. **Regression test.** `repaired_layout_and_degenerate_mask_controls`
   (`zk_ffn_fresh_poc_tests.rs:175`), `:205-208`: for `log_cols ∈ {5, 8, 16}`
   every singleton slot's two mask rows must be in `a_mask_rows()`
   (the `log_cols = 16` case is the boundary where INT16 itself is a singleton).
   **Gap:** no test asserts a singleton table claim's realised mask coefficients
   have rank 2 in an actual proof — `check_pair_ambiguity` is never run on a
   table claim, though its shape predicate (`parts.len() == 3`) would match.

### 2.3 Larger table blocks

1. **Allocation.** `zk.rs:2023` `else { rows }` — unchanged legacy block;
   enumerated `zk.rs:2078`. **Count:** `rows_i = max(size_i, n)/n` rows per slot
   with `rows_i ≥ 2`; here INT16 (`305-560`, 256 rows) and rem(14)
   (`631-694`, 64 rows).
2. **Randomness fill.** the same `zk.rs:2455-2461` loop.
3. **Prover use.** `zk.rs:3088` only (no `U` term) → `tab_term[2i]`.
4. **Verifier use.** `zk.rs:3323-3328` (two-part legacy claim, no
   `pair_claim`). The block kind's 2^−64 degeneracy is guarded by
   `fresh_poc::check_table_point` (`zk_ffn_fresh_poc.rs:210-223`) at
   `zk.rs:3195` (prover) and `zk.rs:3684` (verifier): for every slot with
   `rows > 1`, every row-bit coordinate of `rho_tab[k_i..]` must have a nonzero
   imaginary part (i.e. lie outside Fp). `check_masks` additionally requires two
   of the block's eq row weights to be Fp-independent; because
   `det(s·a, s·b) = N(s)·det(a, b)` over `Fp2 = Fp[u]/(u²−7)`, that is exactly
   FA2 §14.3's condition on the eq weights, with the common `e_tab·ext` factor
   divided out.
5. **Regression test.** `repaired_layout_and_degenerate_mask_controls`
   `:209-214` — `check_table_point` accepts an all-`U` point and rejects after
   one row-bit coordinate is set to `Fp2::ONE`.
   **Gap:** no test asserts a block claim's realised mask coefficients have rank
   2 in an actual proof, and no test drives `check_table_point`'s rejection
   through a real prove/verify (only the unit helper).

### 2.4 H helper / zero-sum pairs

1. **Allocation.** `zk.rs:2033-2035` — `h_mf` (`3·nb_f`), `h_md` (`nb_d`),
   `h_u` (zero-sum), `h_up` all as `(next(1), next(1))`, i.e. **unchanged from
   the legacy layout**, which is what FA3 §2.2 asks ("pair (unchanged)",
   "zero_sum_pair (unchanged)"); table helper masks `h_mre`/`h_mim` at
   `zk.rs:2037-2040`. Enumerated `h_mask_rows` `zk.rs:2082-2088`.
   **Count:** `2·(3·nb_f + nb_d) + 2 + 2` rows plus `2·rows_i` per slot.
2. **Randomness fill.** `zk.rs:2592-2599` — `plain_rows` = `h_mf` pairs,
   `h_md` pairs, `h_up` pair, `mask_range(h_prox)`, then the per-slot
   `h_mre`/`h_mim` blocks, one `fp_vec(n)` each; then `zk.rs:2600-2604` fills
   `h_u`'s two rows with `n−1` draws each and last entry `−Σ`. **This is FA3
   §3 item 4's order exactly**, with the prox pair inserted where the legacy
   single prox row was. Test-build check `zk.rs:2606-2607`.
3. **Prover use.** `mp.eval2(h_data, zl.h_mf[..])` `zk.rs:2908`,
   `zl.h_md[c]` `zk.rs:3004`, table helpers `zk.rs:3090`; `h_u` is opened at
   `rho_zs` and reported as `zs_term`.
4. **Verifier use.** the four-part `masked2` re/im claim `zk.rs:3350-3358`
   (helpers `:3360-3366`, `hz` `:3368-3370`), the zero-sum claim
   `zk.rs:3372-3380`, the table helper claims `:3382-3391`, and the value-0
   LogUp sum claim `:3392-3413`; `check_masks` at `zk.rs:3711` / `:3223`.
5. **Regression test.** end-to-end only (`repaired_fresh_poc_verifies_twice_…`),
   plus `repaired_layout_and_degenerate_mask_controls` `:196-204` (H mask rows
   distinct and in range).
   **Gap:** no pair-ambiguity or rank assertion on any H claim.
   **Observation (important):** for the value-0 LogUp claim the rows that make
   `check_masks` pass are `h_u` itself (coefficients `1` and `u`;
   `det(1, u) = 1`) — i.e. the *constrained* zero-sum witness pair, not a free
   mask. `check_masks` is therefore a necessary structural condition here, not
   the privacy argument; the argument for that claim remains FA2 §14.5 / FA3 §9
   `h_logup_sum_zero_sum_u_prox_pair_n{4,8}` (residual = the public identity).

### 2.5 A / H / W proximity pairs

1. **Allocation.** `a_prox = next(2)` `zk.rs:2016` (rows `44-45`),
   `h_prox = next(2)` `zk.rs:2035` (`28-29`), `w_prox = next(2)` `zk.rs:2050`
   (`9-10`). **Count:** 2 rows per commitment.
2. **Randomness fill.** A: `zk.rs:2455` (`chain(zl.mask_range(zl.a_prox))`);
   H: `zk.rs:2595`; W: `zk.rs:2367` (P3 only).
3. **Prover use.** No claim. `zk_rhos` (`zkp-core/src/pcs.rs:835-855`) draws
   one fresh ρ per commitment **row**, so both prox rows automatically receive
   independent ρ's; `open_zk` (`zkp-core/src/pcs.rs:914-925`) folds them into
   `prox_vec`. Note `prox_mask_row` is still set to the **first** row only
   (`zk.rs:2393`, `:2469`, `:2635`).
4. **Verifier use.** `fresh_poc::check_masks` `zk_ffn_fresh_poc.rs:289-298`:
   it clones the transcript (`Transcript::clone_state`), replays λ per group in
   PCS first-occurrence order, then `challenge_fp2_vec(rows)`, and requires
   `prox + 1 < rows` and `determinant(rho[prox], rho[prox+1]) != 0` — Fp
   independence, which implies both are nonzero. Run on the verifier at
   `zk.rs:3695/3705/3711` and on the prover at `zk.rs:3209/3218/3223`.
5. **Regression test.** `repaired_layout_and_degenerate_mask_controls` `:233`
   exercises only `check_masks`'s **accepting** path (rows 5, prox 3).
   **Gap:** no negative control for an Fp-dependent prox pair (FA3 AM15); no
   test that a real proof's prox ρ touches both rows; `assert_mask_sites` was
   not extended as FA3 §2.4 asks (see D6).

### 2.6 P3 W terminal pairs

1. **Allocation.** `zk.rs:2048-2049` — `w_mgu = (0..2·nb_d·nb_f).map(|_| next(2))`,
   `w_mdd = (0..nb_f·nb_d)`; enumerated `w_mask_rows` `zk.rs:2070-2074`.
   **Count:** `2·(3·nb_d·nb_f)` rows = 6 here (`3-8`), plus the prox pair.
   Under P1 the indices exist but no rows are added: the verifier's expected
   count is `lay.w_len` (`zk.rs:3462-3463`).
2. **Randomness fill.** `zk.rs:2366-2371` — P3 only, `w_mask_rows() ∪
   mask_range(w_prox)`, one `fp_vec(w_n)` per row, **drawn first from the
   stream, before A**. Test-build check `zk.rs:2372-2373`.
3. **Prover use.** `zl.eval_mask(&mpw, w_data_ref, r)` at `zk.rs:2699`
   (`w_mgu` at p3) and `zk.rs:2779` (`w_mdd` at p6) → `w_mev` / `wd_mev` → the
   masked W block terminals `gu_term[nb_d + k]`, `d_term[nb_f + k]`.
4. **Verifier use.** `build_w_zclaims_v3` `zk.rs:3247-3250`, `masked` wrapped
   in `zl.pair_claim`, coefficient pairs `(cd_w_gu, e_gu2)` and `(cd_w_d, e_d2)`
   — FA3's `((1−e_gu2)(1−e_gu), e_gu2)` and `((1−e_d2)(1−e_d), e_d2)`;
   `check_masks` at `zk.rs:3695`. The P1/P3 opening slots are cross-refused by
   `fresh_poc::verify` (`zk_ffn_fresh_poc.rs:138-162`): a `Public` statement
   rejects a non-empty `w_open_zk`, a `FreshPrivate` statement rejects a
   non-empty `w_open`. The `--wcache` path is refused up front under P3
   (`zk_ffn_fresh_poc.rs:84-86`, ahead of the in-prover assert `zk.rs:2386-2389`).
5. **Regression test.** `repaired_fresh_poc_verifies_twice_…` `:75-77`
   (`check_pair_ambiguity` on `w_mdd[0]`) and `:82-86` (P3 W root differs
   between attempts; P1 W root identical).
   **Gap:** the `w_mgu` pairs are never directly asserted.

### 2.7 CFS challenges

1. **Allocation.** the M slots `SC_GU..SC_TAB` (+`SC_PRED`) `zk.rs:712-719`,
   sized by `mask_specs_v3`; the coefficient rows are committed by
   `mask_commit` (`zk.rs:430`) called at `zk.rs:2478`. Function 1 uses **six**
   slots. **Count:** one Fp2 challenge `c_s` per slot per proof.
2. **Randomness fill.** the mask polynomials come from the same `ZkRng` inside
   `mask_commit` (after A's commitment, before H's rows). The multipliers
   `c_s` are **transcript** challenges, each drawn exactly once by
   `fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)`
   (`zk_ffn_fresh_poc.rs:196-208`) at `zk.rs:2666, 2755, 2827, 2924, 3009,
   3101` (+`3143` for function 2). Under `mr1` a zero returns
   `Err("zero CFS mask challenge; discard attempt")`; under `!mr1` it delegates
   to the legacy `mask_challenge` (`zk.rs:961-965`), which panics.
3. **Prover use.** immediately after the draw: `proof.gu_claim`, `d_claim`,
   `gamma20`, `gamma17`, `gamma_tab`, `gamma_zs` = private sum + `c_s·G_s`,
   then `tr.absorb_fp2`; `masked_prove` (`zk.rs:971-980`) and `extension`
   (`zk.rs:984-996`) add `c_s·g_{s,j}` to each round message.
4. **Verifier use.** `c_s` redrawn at `zk.rs:3490, 3529, 3556, 3589, 3615,
   3637` (+`3659`); `div` (`zk.rs:3481`) returns
   `Err("zero mask challenge")` when `c_s = 0`; `mask_verify` opens M once at
   the θ-combination.
5. **Regression test.** `zk::cfs_safety_tests::zero_mask_challenge_aborts_without_resampling`
   (`zk_cfs_safety_tests.rs:5`), `…::malformed_extension_refuses_before_changing_transcript_or_output`
   (`:31`), `…::complete_extension_matches_the_masked_round_and_terminal_identity`
   (`:74`), plus the mr1 wrapper's no-resample assertion
   (`zk_ffn_fresh_poc_tests.rs:177-186`, `assert_eq!(draws, 1)`).
   **Gap:** no test forces `c_s = 0` **inside a real mr1 proof** (FA3 AM14), so
   the `?` propagation of that error out of `prove_layer_zk_v3_inner` is
   untested.

### 2.8 Summary

| Row | Allocation | Fill | Prover | Verifier | Test | Verdict |
|---|---|---|---|---|---|---|
| A terminal pairs | `zk.rs:2012-2015, 2027, 2075` | `zk.rs:2455-2461` | `zk.rs:2690, 2776, 2907, 3001` | `zk.rs:3296-3317, 3705` | `repaired_fresh_poc_verifies_twice…` (a_mgu[0], a_mdd[0] only) | **partial** — a_mf/a_md untested |
| singleton table pairs | `zk.rs:2023, 2078` | `zk.rs:2455-2461` | `zk.rs:3088-3089` | `zk.rs:3319-3328, 3705` | `repaired_layout_and_degenerate_mask_controls` (layout only) | **partial** — no rank assertion on a real claim |
| larger table blocks | `zk.rs:2023, 2078` | `zk.rs:2455-2461` | `zk.rs:3088` | `zk.rs:3323-3328`; `check_table_point` `zk.rs:3195/3684` | `repaired_layout_…` `:209-214` (unit only) | **partial** — unit-level only |
| H helper / zero-sum pairs | `zk.rs:2033-2040, 2082` | `zk.rs:2592-2604` | `zk.rs:2908, 3004, 3090` | `zk.rs:3350-3413, 3711` | none specific | **gap** |
| A/H/W proximity pairs | `zk.rs:2016, 2035, 2050` | `zk.rs:2455, 2595, 2367` | `zk_rhos` `pcs.rs:835-855` | `check_masks` `fresh_poc.rs:289-298` | accepting path only | **gap** — no negative control |
| P3 W terminal pairs | `zk.rs:2048-2049, 2070` | `zk.rs:2366-2371` | `zk.rs:2699, 2779` | `zk.rs:3247-3250, 3695` | `repaired_fresh_poc_verifies_twice…` (w_mdd[0] only) | **partial** — w_mgu untested |
| CFS challenges | `zk.rs:712-719`, `mask_commit` `zk.rs:430/2478` | transcript, one draw each | `zk.rs:2666…3143` | `zk.rs:3490…3659`, `div` `zk.rs:3481` | 3 `cfs_safety_tests` + `draws == 1` | **covered** (except an in-proof AM14 hook) |

## 3. The four required checks

### 3.1 S1 — no caller seed, RNG or reusable private commitment: **PASS**

- The only public prover entry point of the profile is
  `pub fn prove(w: &V3Witness, privacy: ZkPrivacy, context: &[u8]) -> Result<Proof, String>`
  (`zk_ffn_fresh_poc.rs:81`). No seed, no RNG, no prepared commitment, no
  transcript, no output parameter.
- The only public verifier entry point is
  `pub fn verify(st: &StatementV3, weights: WeightStatement, proof: &Proof, context: &[u8])`
  (`:131`). `WeightStatement` (`:13-18`) carries a `Digest` or the
  `FreshPrivate` marker and nothing else.
- The rest of the module's public surface is `PROFILE` (`:10`), `parameters()`
  (`:40`) and `Proof::{weight_root, activation_root, helper_root, payload_size}`
  (`:24-38`). `Proof.inner` is `pub(super)` — unreachable outside `crate::zk`.
- `prove` builds the config itself with `seed: None` (`:109-116`) and obtains
  `ZkRng::from_os(PROFILE)` (`:108`) **before any proof work**; a randomness
  failure returns `Err("fresh proof randomness: …")` before a single field
  element is produced. `ZkRng::from_os` reads 32 fresh bytes from
  `/dev/urandom` and fails closed on unsupported hosts
  (`zkp-core/src/rng.rs:29-51`).
- The seeded path is **not reachable** from the new API by construction:
  `prove_layer_zk_v3_inner` (`zk.rs:2265`) takes the `ZkRng` **by value** and
  the old `let mut rng = cfg.rng(...)` line was deleted at this pin, so even a
  hypothetical `Some(seed)` config could not steer it; and `ZkConfig::rng`
  (`zk.rs:334-340`) is a **private** method.
- The mr1 schedule itself is unreachable from the legacy API: it exists only
  through `ZkLayoutV3::with_masks` (`zk.rs:2000`, private);
  `ZkLayoutV3::new` (`:1996`) hard-codes `mr1 = false`, and the public
  `prove_layer_zk_v3` / `verify_layer_zk_v3` (`zk.rs:2262`, `:3417`) pass
  `false`. The two schedules cannot be mixed.
- The transcript is owned by the profile (`transcript(context)`, `:69-77`):
  domain = `PROFILE`, then `absorb(b"request-context", context)` and a fixed
  parameter string. Callers cannot supply or continue a transcript. This is
  FA3 AM24's binding, and it is tested (`zk_ffn_fresh_poc_tests.rs:108-110`,
  `context-b` fails).
- Cross-profile: `repaired_fresh_poc_rejects_tampering_and_legacy_profiles`
  (`:136-170`) builds a legacy proof with `seed: Some(5)` and shows that
  wrapping it as `fresh_poc::Proof` is rejected by `fresh_poc::verify`, and that
  the legacy verifier rejects a fresh proof.

**Residual, scoped to the legacy API, not to this one:** `ZkRng::new(seed, domain)`
(`zkp-core/src/rng.rs:20`) and the `pub seed: Option<u64>` field of `ZkConfig`
(`zk.rs:320`) remain crate-public. FA8 S1 accepts either "the block API takes
no seed" **or** "`ZkRng::new` unreachable outside `cfg(test)`". The first is
met; the second is not, so any *other* prover in the crate can still be seeded.

### 3.2 Private state does not escape: **PASS**, with three notes

- **Returned type.** `Proof` (`zk_ffn_fresh_poc.rs:20-22`) derives nothing —
  no `Clone`, no `Debug`, no serialization — and its single field is
  `pub(super)`. The four accessors return `Digest`s and a `usize`.
  `LayerProofZk` does derive `Clone, Debug` with public fields
  (`zk.rs:740-777`), but it is only reachable through `Proof.inner`, i.e. from
  inside `crate::zk` and its descendants.
- **Explicit drops.** `w_cm`/`w_cmz` at `zk.rs:3214-3215`, `a_cmz` at `:3221`,
  `h_cmz` at `:3226`. These own `data` (the full witness plus mask rows),
  `pads` and `salts`. `a_data`/`h_data`/`w_data` are moved into them
  (`commit_zk_owned`, `std::mem::take`) and die with them. `mc` (the
  `MaskCommit`: `a_coefs`, `b`, `u`, `salts`) and the `ZkRng` are function
  locals and are dropped on return — including on every `?` path, so a
  discarded attempt takes its secrets with it.
- **Nothing but the proof is returned.** `ProveOutputZk.timings` and
  `.sites` — the latter containing `zl.describe()` (`zk.rs:2098-2107`,
  including every mask row index) and `pcs::last_mask_sites()` — are
  **discarded** by `fresh_poc::prove` (`:127`, `Ok(Proof { inner: out.proof })`).
- **Capture hooks are test-only.** `mod mask_diagnostic` is `#[cfg(test)]`
  (`zk.rs:3720-3722`), and the observation-JSON exporter lives inside it. Its
  `Observation` (`zk_ffn_mask_diagnostic.rs:25-33`) holds only verifier-visible
  data, and the tampering test asserts nothing is published after a failed
  verify (`zk_ffn_fresh_poc_tests.rs:128-134`) — FA3 obligation 9.
- **Note 1 (gap).** Nothing is zeroized. Dropping frees the heap; mask rows,
  pads, salts, the RNG key/buffer and the CFS coefficients remain in freed
  pages until reused. FA3 §4.4 asks the discard to "drop the RNG instance with
  the secret state" — drop is implemented, wiping is not.
- **Note 2.** `pcs::last_mask_sites()`'s thread-local
  (`zkp-core/src/pcs.rs:898-905`) still holds the last commitment's site strings
  after `prove` returns. Contents are row indices and counts (public layout),
  not values.
- **Note 3.** There is no public serializer for a `Proof` (`to_bytes` is on
  `LayerProofZk`), so a repaired proof cannot leave the process at all yet.
  This restates round 16's "no wire decoder" and means "independent
  verification from bytes" is still unimplemented.

### 3.3 Degeneracies discard without redraw: **PASS**, with one placement caveat

- **No resample loop anywhere.** `mask_challenge` (`zk.rs:961-965`) and
  `draw_mask_challenge` (`zk_ffn_fresh_poc.rs:196-208`) each call `draw()`
  exactly once. `Transcript::challenge_fp2` (`zkp-core/src/transcript.rs:103-113`)
  has no rejection sampling and `challenge_fp2_vec` is a plain map. The only
  `while` loops in `zk.rs` are unrelated table padding (`:663`, `:1187`).
  `check_masks`, `check_table_point` and `div` return `Err`; no caller retries.
- **Placement vs. the draw:**
  - **CFS `c_s`:** the abort sits between the single draw and the computation +
    absorption of the masked claim / Γ, at all six (seven) sites — **before any
    transcript output or proof field that depends on the draw**. ✔
  - **`check_masks`:** called immediately before the corresponding
    `pcs::open_zk` / `pcs::verify_zk`, and it replays λ and ρ on a
    `Transcript::clone_state` clone (`zk_ffn_fresh_poc.rs:289`), so an abort
    leaves the live transcript unadvanced and **no group vector or prox vector
    absorbed**. ✔ (The replay faithfully mirrors `group_zclaims` /`zk_rhos`:
    the claim mappings it refuses — `bits < log_n`, `offset % n != 0`,
    `point.len() != bits` — are exactly the branches for which its tail-only
    group key would be wrong; see `zkp-core/src/pcs.rs:755-791`.)
  - **`check_table_point`: LATE.** It is called at `zk.rs:3195` (prover) and
    `zk.rs:3684` (verifier), i.e. **after** the table sumcheck rounds,
    `tab_term` and the whole `mask_open` have been absorbed into the transcript
    and written into `proof`, although `rho_tab` was drawn far earlier
    (`zk.rs:3007`). It is still a genuine discard — `prove` returns `Err`,
    nothing leaves the process, and a retry gets a fresh OS-keyed stream and
    fresh commitments — but it does **not** satisfy "abort before any proof
    field that depends on the draw". `check_table_point` needs only `zl` and
    `rho_tab`, so moving it to the point `rho_tab` is drawn is a one-line change.
    **Reported, not fixed** (read-only audit).
- **The rank test is exactly FA3 §6.5's `k1 ≠ 0`.** With
  `Fp2 = Fp[u]/(u² − 7)` (`zkp-core/src/field.rs:15,141,158`) and
  `determinant(a, b) = a₀b₁ − a₁b₀` (`zk_ffn_fresh_poc.rs:178-180`),
  `det(k₁, k₁·u) = k₁,₀² − 7·k₁,₁² = Norm(k₁)`, which is nonzero iff `k₁ ≠ 0` —
  the same expression `Fp2::inv` uses. So for the A-side P3 matmul roles the
  test is literally FA3's `e ≠ 0 ∧ e2 ≠ 1`, and the two error strings
  ("zero terminal mask challenge; discard attempt" when every mask coefficient
  vanishes, "mask coefficients do not span Fp2; discard attempt" otherwise)
  are the typed refusals FA3 §6.5 asks for. λ ≠ 0 per group member and the prox
  determinant are checked explicitly (`fresh_poc.rs:289-298`).
- **Verifier refuses, never resamples:** `div` (`zk.rs:3481`),
  `check_masks`/`check_table_point`, `pcs::verify_zk`'s structural refusals
  (`zkp-core/src/pcs.rs:967-968, 984, 989`). Row counts come from the
  verifier's own layout (`zk.rs:3462-3465`), which is FA3 obligation 2 for the
  mr1 counts; claims come from the verifier's own `build_claims_zk_v3` /
  `build_w_zclaims_v3`, which is obligation 3.

### 3.4 FA6 I1 / I3 and FA8 S2 (the `a5aea1d` guards): **CONFIRMED**

`git show a5aea1d -- hashline/src/zk.rs` converts **thirteen** CFS challenge
draws to `mask_challenge`: six in `prove_layer_zk` (v2) at the current
`zk.rs:1345, 1387, 1424, 1493, 1559, 1595`, and seven in `prove_layer_zk_v3`
now routed through `fresh_poc::draw_mask_challenge` at `zk.rs:2666, 2755, 2827,
2924, 3009, 3101, 3143`. At every one of the thirteen the guard sits between the
single `tr.challenge_fp2()` and the line that forms and absorbs the masked
claim / Γ. `mask_challenge` (`zk.rs:961-965`) draws once and refuses; it never
redraws.

The masked extension rounds check **before** zipping or touching state
(`zk.rs:984-996`): `assert!(!c.is_zero())`, then
`assert_eq!(degree, mask.degree)` (FA6 I1's degree condition), then
`assert_eq!(sk.len(), gk.len())` (FA6's proposed length hardening) — all three
ahead of the `zip`, the `rounds.push(sk)` and the `tr.absorb_fp2`.
`masked_prove` (`zk.rs:971-980`) asserts `c ≠ 0` before `tr.set_masker`.
This is FA6 I1's hardening **plus** the extra degree assert.

Evidence, as instructed (not re-run):
`results/zk60_fable_fa6_a5aea1d_cargo.log` (`sha256 9ac289f8…`), companion
`.done` = `0`, tail `test result: ok. 3 passed; 0 failed`, with
`zk::cfs_safety_tests::zero_mask_challenge_aborts_without_resampling` and
`…::malformed_extension_refuses_before_changing_transcript_or_output` listed ok
(log lines 98–99) and the three deliberate panics recorded at `zk.rs:963`,
`:976`, `:988`, `:989`.

**One difference from FA6 I3's wording:** the legacy path aborts by `assert!`
(panic), not a typed error. Both abort; only the mr1 path yields
`Result::Err`. And the *verifier* has no explicit `c_s ≠ 0` refusal at the draw
site — it refuses later, inside `div` — which is what FA6 I3 describes, but it
means the verifier's refusal comes after the claim has been absorbed and the
sumcheck verified. Neither is a leak (the verifier emits nothing on failure).

## 4. Differences from FA3's rule and FA6's approved specification

Site-for-site against `results/zk60_fable_fa3_mask_schedule.json`
(`schedule.commitments`), every FFN role that this profile implements matches:
`a_mf`, `a_md`, `a_mgu`, `a_mdd`, `a_prox`, `tab[i].a_mask` (pair iff
`rows_i == 1`), `a_pmz`/`a_pmb`, `h_mf`/`h_md`/`h_u`/`h_up`/`h_prox`/
`tab[i].h_mre,h_mim`, `w_mgu`/`w_mdd`/`w_prox` — including the coefficient
pairs (P1 `(1−e, e)`; P3 A-side `((1−e2)(1−e), (1−e2)e)`; P3 W-side
`((1−e2)(1−e), e2)`), the `(k1, k1·U)` pair form, the tail-point rule and the
group keys. The differences are:

- **D1 — omitted roles (declared scope).** `a_sx[c]`, `a_sz[c]`, `SC_SEAM_X`,
  `SC_SEAM_Z`, the attention side, the `Prepared → Pending → Bound → Finalized`
  type-state (FA3 §4, §12) and the wire decoder are all absent. Round 16 says
  so explicitly.
- **D2 — W(P3) is fresh per proof, not FA4's budgeted stable `C*_l`
  (declared scope).** Consequently FA3 §6.2's W obligations (root = the
  manifest's `C*_l`, `slot < k`, `q_pad = k·Q`) have no implementation, and
  `WeightStatement::FreshPrivate` **authenticates no model**:
  `fresh_poc::verify` accepts whatever W root the proof carries. FA8's E1/E2/E3
  are untouched.
- **D3 — profile identity lives in the transcript domain, not the header.**
  FA3 §5 specifies `HL-ZK/2|profile=ffn-v3-mr1|…|model=…|layer=…|slot=…|block=…`.
  The implementation keeps the **legacy** header bytes —
  `mode.header_v3()` = `b"P1-v3"` under P1 and
  `HL-ZK/1|profile=v3|…|model=w-root` under P3 (`zk.rs:269-286`) — and separates
  the profile by initialising the transcript at `PROFILE` and absorbing the
  request context (`zk_ffn_fresh_poc.rs:69-77`). Separation is sound (challenges
  diverge; tested at `zk_ffn_fresh_poc_tests.rs:144-170`) and FA3 obligation 1
  is realised as a **separate typed entry point** rather than a header check —
  but a party reading only the header bytes cannot tell which profile made the
  proof.
- **D4 — RNG domain.** FA3 §3 asks for `ffn-mr1/layer-{l}/attempt-{nonce}`;
  the implementation uses `PROFILE` alone, with no layer index and no attempt
  nonce (`zk_ffn_fresh_poc.rs:108`). Freshness rests entirely on `from_os`
  taking 32 new bytes of `/dev/urandom` per call. Under FA8 H3 that is the
  load-bearing assumption anyway, so this is a traceability difference rather
  than a weakening — but two attempts for the same layer in one process are
  separated only by the OS key.
- **D5 — consumption order.** FA3 §3 lists A rows → A pads/salts → M → H rows →
  H pads/salts (W drawn at registration). The implementation draws
  **(P3) W rows → W pads/salts → A rows → A pads/salts → M → H rows → H
  pads/salts**. Round 16 states the W-before-A part. Within A the order **is**
  allocation order, and only because of the `sort_unstable()` at `zk.rs:2456`
  (unsorted, `a_prox` would follow the table masks). H's order matches FA3 item
  4 exactly. This changes nothing about hiding, but it means "the order is part
  of the profile version" (FA3 §3) now names a different order than FA3's text.
- **D6 — `assert_mask_sites` was not extended.** FA3 §2.4 asks it to assert
  that the prox ρ touches **both** prox rows and that every group vector touches
  **both** rows of at least one pair. `zkp-core/src/pcs.rs:881-896` is unchanged:
  prover-side only, one `prox_mask_row`, "at least one mask row" per group
  vector; `prox_mask_row` is still a single index (`zk.rs:2393/2469/2635`).
  `fresh_poc::check_masks` supersedes it on **both** sides with a strictly
  stronger test (rank 2 per claim over its mask rows; `det(ρ_re, ρ_im) ≠ 0`,
  which implies both are nonzero). Net effect: the FA3 §2.4 property holds by a
  different mechanism. Worth Codex confirming this is the intended resolution
  rather than an oversight.
- **D7 — obligation 4's data/mask disjointness is not checked.** FA3 §6.4 asks
  the verifier to assert structurally that no claim's data slice overlaps a mask
  row. `check_masks` never looks at that. It holds by construction (I recomputed
  the tiny-shape allocation; every data range is disjoint from every mask
  range), and `repaired_layout_and_degenerate_mask_controls` `:201-203` asserts
  the mask rows are distinct and in range, but the tripwire FA3 asks for does
  not exist.
- **D8 — the constant / duplicate mask-row check is test-only.**
  `check_generated_rows` (`zk_ffn_fresh_poc.rs:182-194`, the AM3/AM4-adjacent
  gate) is `#[cfg(test)]` and is invoked under `#[cfg(test)]` at `zk.rs:2372,
  2463, 2606`. Release builds do not run it. Round 16 describes it accurately
  ("the test build also checks…"); recording it so nobody reads the gate as a
  production invariant.
- **D9 — legacy abort form.** FA6 I3 asked the prover to abort; the legacy
  path does so by `assert!`/panic rather than a typed error (`zk.rs:963, 976,
  988, 989`). Only the mr1 path returns `Err`.
- **D10 — FA6 I1 exceeded.** The extension round asserts `degree ==
  mask.degree` **in addition to** `sk.len() == gk.len()` (`zk.rs:988-991`).
  Stronger than the requested hardening.

## 5. Command run in this worktree

Launched detached under the shared heavy lock, with every `HL_*` variable
cleared (`env | grep '^HL_'` was empty before launch):

```sh
flock /tmp/zk-heavy.lock env -u HL_GPU -u HL_GPU_REQUIRED -u HL_ZK_CHUNK -u HL_TIMING \
  CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 \
  cargo test --release --locked --offline \
    --manifest-path /home/victor/wt-zk60-fa/hashline/Cargo.toml \
    --lib fresh_poc -- --nocapture --test-threads=2
```

**Exit code 0.** `test result: ok. 3 passed; 0 failed; 0 ignored; 56 filtered
out; finished in 0.90s` (build 50.20 s). The three tests are
`repaired_fresh_poc_verifies_twice_and_blocks_single_mask_recovery`,
`repaired_fresh_poc_rejects_tampering_and_legacy_profiles`,
`repaired_layout_and_degenerate_mask_controls`. Emitted lines:

```
FRESH_FFN_POC privacy=P1 attempt=0 verified=true A_rows=698 H_rows=1326 W_rows=3  payload_bytes=4733204 singleton_mask_rank=2 recovery=underdetermined
FRESH_FFN_POC privacy=P1 attempt=1 verified=true A_rows=698 H_rows=1326 W_rows=3  payload_bytes=4733204 singleton_mask_rank=2 recovery=underdetermined
FRESH_FFN_POC privacy=P3 attempt=0 verified=true A_rows=698 H_rows=1326 W_rows=11 payload_bytes=4770164 singleton_mask_rank=2 recovery=underdetermined
FRESH_FFN_POC privacy=P3 attempt=1 verified=true A_rows=698 H_rows=1326 W_rows=11 payload_bytes=4770164 singleton_mask_rank=2 recovery=underdetermined
```

These row counts and payload sizes reproduce `ZK60_ROUND16.md` exactly and match
my independent recomputation of the allocation (§1). **A passing test is not a
privacy verdict, and neither is a mask-site count.**

The `a5aea1d` CFS regressions were **not** re-run; the cited evidence is
`results/zk60_fable_fa6_a5aea1d_cargo.log` / `.done` (§3.4).

## 6. Gap list for Codex

Untested or missing, in rough priority order. None of these is a demonstrated
leak; they are places where the implementation's claim is not backed by a check.

1. **`check_table_point` aborts late** (`zk.rs:3195`, `:3684`) — after the table
   rounds, `tab_term` and `mask_open` are already in the transcript and in
   `proof`, though `rho_tab` was drawn at `zk.rs:3007`. Nothing escapes, but it
   violates "discard before any proof field that depends on the draw". Move it
   to the draw site.
2. **No AM14 hook**: no test forces `c_s = 0` inside a real mr1 proof, so the
   `?` propagation of "zero CFS mask challenge" out of
   `prove_layer_zk_v3_inner` is never exercised.
3. **No AM15 negative control**: `check_masks`' dependent-prox-pair branch and
   its "zero group member coefficient" (λ = 0, AM22) branch are never taken by
   any test.
4. **H is untested at the pair level**: no rank / pair-ambiguity assertion on
   any `h_mf`, `h_md`, `h_u`/`h_up` or table-helper claim. Related: for the
   value-0 LogUp claim, `check_masks` is satisfied by the *constrained*
   zero-sum pair `h_u` rather than by a free mask, so the structural test says
   less there than elsewhere — the argument remains FA2 §14.5 / FA3 §9.
5. **Table claims are untested at the rank level**: neither the singleton pairs
   nor the ≥2-row blocks have an assertion on the coefficients realised in an
   actual proof; `check_table_point` is only unit-tested.
6. **`a_mf`, `a_md` and `w_mgu` pairs** have no direct assertion —
   `check_pair_ambiguity` covers only `a_mgu[0]`, `a_mdd[0]` and `w_mdd[0]`.
7. **`assert_mask_sites` (FA3 §2.4) and the data/mask-disjointness tripwire
   (FA3 §6.4)** are not implemented; `prox_mask_row` remains a single index.
   Confirm that `check_masks` is the intended replacement.
8. **`check_generated_rows` is `#[cfg(test)]`** — the non-constant /
   non-duplicate mask-row gate does not run in release builds.
9. **No zeroization** of mask rows, pads, salts, the CFS coefficients or the
   `ZkRng` key on drop or on a discarded attempt.
10. **FA8 S1's second form is still open**: `ZkRng::new` and
    `ZkConfig::seed` remain crate-public, so other provers in the crate can
    still be seeded. The fresh-PoC API itself is clean.
11. **Untested minor paths**: the P3 `--wcache` refusal
    (`zk_ffn_fresh_poc.rs:84-86`), the `ZkRng::from_os` failure path
    (`:108`), and the witness length/shape preflights (`:87-107`).
12. **No proof bytes**: `Proof` has no public serializer, so "independent
    verification from bytes" (round 16 milestone 2) has nothing to verify yet.

## 7. Limits of this audit

- This is a **bounded implementation audit**: allocation, fill, consumption,
  reconstruction, the refusal paths, and the API surface. It says nothing about
  whether the construction is zero knowledge.
- **No whole-protocol conclusion may be drawn from it.** A passing regression
  and a correct mask-site count are not a privacy verdict; the joint-observation
  analysis (O2), the CFS/nonlinear channel (FA6 B1), transcript conditioning
  (FA8 B2), ranges (B3) and cross-proof correlation (B4) are all outside it.
- Function 2, stable-weight P3, attention, seams and any shape other than
  T32/d16/f16 at `log_cols` 8 are **not covered** — the profile refuses them
  (`zk_ffn_fresh_poc.rs:61-67`) and I did not exercise them beyond the layout
  test's `log_cols ∈ {5, 8, 16}` allocation checks.
- Line numbers and digests are pinned to `a8a1bc7`; they will move.
- No Rust was changed and no protocol judgment is made. **Codex retains the
  overall cryptographic judgment.**
