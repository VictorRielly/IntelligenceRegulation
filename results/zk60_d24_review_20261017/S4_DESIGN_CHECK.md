# S4 split-width layout: independent design check (soundness and privacy)

Reviewer: Claude (Opus 5.5 subagent), independent of Sol's lane. Written 2026-10-29, finished 07:42 UTC (`date -u`).

Packet checked: `results/zk60_1b_native_20261017/s4-split-width/`.
* `DESIGN_REVIEW_REQUEST.json` has sha256 `73dcff1f…`, recomputed and matching.
* Every source, binary and log matches `evidence.sha256.json`.
* Anchor: the frozen native R13 tree `bb9eb212…`. The R13 D24 review was running in parallel and has since closed (accepted on soundness). I did not duplicate it.

**This is a design check, not a privacy acceptance and not a native-code review.** No native split layout exists yet.

## Verdict: PROCEED WITH CONDITIONS

Construction B (one batched sumcheck over the two inner pieces, using a zero lift on the larger cube) is **sound**. It meets all four of the coordinator's 06:35 conditions in substance:
* the integer function is exact and rounded once;
* nothing is ever divided, and there is no retry that depends on the data;
* every new claim gets a fresh reserved mask pair;
* a new versioned profile is used.

It **discloses nothing new** in the per-commitment linear view at the real T128 row geometry.

Before native layout work starts, three things must be settled. Each is a condition below.

1. **Choose where the lift lives.** The check found a simpler placement than either style Sol offered. I recommend it.
   * **The placement (I call it "B-gate").** Keep the smaller piece's private table exactly as the native code builds it today: constant over the omitted feature bits, which is what `priv_table`'s broadcast already does. Put the zero lift only into the monomial's **one existing public factor**:
     * for matmuls, the folded weight of the smaller piece, zero-padded;
     * for the norm sums, `Tab::Eq` at the point `(r_t, 0^k)`, which equals `eq(r_t,t)·Π(1−b)`.
   * **What that buys.** The private claim is then the plain native claim at the projected point. No private functional ever carries the factor σ = Π(1 − r_b). The case σ = 0 needs no adapter, and none of these change: the claim audit, `open_zk`'s mask assertion, the group count, the wire format or the rank structure.
   * **The other two styles.** Sol's whole-functional lift is SOUND WITH CONDITIONS, because σ = 0 then needs extra handling (condition C-6). The independent-mask alternative is SOUND but gains nothing over B-gate.
   * **The choice is the coordinator's.** B-gate changes the wording of the 06:35 condition ("the masked functional is scaled by (1 − r_b)"), though not its intent, so it needs an explicit adoption.
2. **Apply the degree rule.** My own harness shows the trap. If the zero lift is added as a **separate** public gate table, the honest norm proof is refused: `eq·gate·Y1²` has degree 4 in the extension variable, against a declared degree of 3. The lift must be folded into the monomial's existing public factor, or the declared degree must be recounted including the extension round.
3. **Get a register ruling on two-piece endpoints.** D12 rule 2 and D12a describe a boundary as "one prover-generated boundary commitment". Two piece commitments per logical endpoint need a security-owner ruling or amendment. The alternative is one commitment per logical boundary that holds both pieces as blocks of rows; it costs fewer rows and no extra openings (see Q3).

The headline A/H savings reproduce exactly: 24.29 / 25.07 % at T128 and 21.31 / 23.49 % at T256 (non-DD / DD) [COUNTED, proposed schedule]. Three corrections to how the counts are reported:
* an internal boundary goes from 38 to **36** rows, not 34;
* two-piece boundaries add L + 1 PCS openings per run: 105 → 132 at L = 26, which costs 0.33 bit on the commitment term [COUNTED];
* lookup positions fall 23.5–28.5 %, which adds 0.39–0.48 bit on the lookup term [COUNTED].

## Per-question table

| # | Question | Verdict |
|---|---|---|
| 1 | Construction B identity, multilinearity and degree, terminal opening, no retries | **SOUND** (whole-lift: SOUND WITH CONDITIONS C-2, C-6) |
| 2 | Single rounding and no-wrap; no partial result committed or revealed | **SOUND** |
| 3 | Endpoints and boundaries (D12): swap, duplicate, drop, cross-run substitution; one logical cross-layer equality | **SOUND WITH CONDITIONS** (C-7; register ruling needed) |
| 4 | Masks, CFS and privacy: the σ scaling, the r_b = 1 case, the rank lemma, two-piece endpoints | **SOUND WITH CONDITIONS** (C-5, C-6; privacy gate items P-1 to P-6) |
| 5 | Lookups, DD and ACT3: one zero-sum claim, N, supports, nonzero-numerator premise | **SOUND WITH CONDITIONS** (C-8, C-10) |
| 6 | Isolated evidence (24 / 192) against the falsification list | **ADEQUATE for the paper stage**, with gaps to close at the native stage (C-11) |
| 7 | Counts (24.29 / 25.07 %, 21.31 / 23.49 %) | **REPRODUCED**, with three reporting corrections (§7) |

## 1. Construction B: identity, degree, terminal opening

**The identity is exact.**
* Write the smaller piece Y1 on the larger feature cube with b = the k leading feature bits (k = 1 for D, 3 for F) and σ(b) = Π(1 − b_j).
* On the Boolean cube σ(b) = [b = 0], so Σ_(b,j) [W0Y0 + (σW1)(σY1)] = Σ W0Y0 + Σ_j W1Y1, because σ² = σ there.
* With B-gate the same sum is Σ [W0Y0 + (σW1)·Y1], with Y1 broadcast. Only one factor needs the lift.
* For the norm: Σ eq(r_t,t)·[Y0² + σ·Y1²] equals the true row square sum over all 3072 channels.

**The polynomials are multilinear.**
* σ(b)·Y1~(t,j) is multilinear, and it is the unique multilinear extension of the zero-padded table. That is why the verifier's terminal map (the projected point, times σ) is exact.
* The broadcast table Y1~(t,j), constant in b, is also multilinear. It is exactly what native `priv_table` builds for variables the plane does not use.
* A broadcast table without a public gate is the "repeated cube" (it multiplies the sum by 2^k), so the gate is mandatory. My harness's `OmitGate` forgery is refused at the M sum.

**Degree.**
* Per variable:
  * matmul ≤ 2: the lifted bit has (1 − b)² under whole-lift and (1 − b) under B-gate;
  * norm ≤ 3.
* Extension round. Every public factor contributes one degree in each extension variable.
  * Folded B-gate and whole-lift stay at the declared 2 / 3.
  * **A separate gate table makes the norm degree 4.** That is condition C-2; it is demonstrated, not argued (§6).

**The source-to-cube map is correct at the real axes.**
* Native D and F planes are stored token-major with features as the low bits:
  * `SC_QMM` / `SC_GMM` / `SC_UMM`: `fixed(r_row) ++ rho(0..inner)`;
  * `SC_DMM`: the same on `A_H16`.
* So the omitted coordinates are the slot's leading inner variables: `rho(0..k)` for fixed-token slots and `rho(lt..lt+k)` for moving-token slots.
* Sol's adapter and my harness both use exactly these. Fixed token coordinates are never dropped.
* The fold for piece q must read **global** rows and columns (D1 j ↔ 2048 + j, F1 j ↔ 8192 + j), and the per-output coefficients must come from global channels.

**The terminal opening is sound.** Take the PCS claim of the smaller piece at the projected point. Under each style its coefficients are:

| Style | data | reserved pair |
|---|---|---|
| whole-lift | (1 − e)σ | eσ, euσ |
| independent | (1 − e)σ | e, eu |
| B-gate | (1 − e) | e, eu |

In every style:
* the terminal equals the extended table's correct value at (ρ, e);
* the verifier's final check is the slot polynomial evaluated at bound openings;
* ordinary sumcheck soundness applies unchanged, and no new soundness term appears.

The σ = 0 event does **not** weaken soundness. The slot polynomial is fixed by the commitments; at σ = 0 its true value at ρ simply does not depend on Y1, and that is what the verifier checks. Under whole-lift the omitted claim's terminal must be checked equal to 0 before it is dropped. Otherwise a cheating prover could choose it freely at σ = 0 in the norm (where it enters squared), though only with probability 2^-119 per run.

**Nothing is divided, and every refusal depends only on public challenges.** Native `run_slot` already discards on c = 0 and e ∈ {0, 1}.

## 2. Single rounding and no-wrap

* **One rounding.** Under B, the batched slot's single published scalar is s + cG, with s = acc~(output point) over **both** pieces. The host zero-check links s to the one requant expression per output entry: acc·c2 + 2^(s−1) = out·2^s + rem, with rem's limb range. No per-piece accumulator is committed, hosted or published; there are no partial planes.
* **No-wrap.** The integer acc is the same integer as R13's, whose pad lanes contribute zero. R13's no-wrap count used the padded widths 4096 / 16384, so it remains a valid, conservative upper bound for the summed expression. The R13 review measured the worst clause at 2^49.99.
* **Shared norm denominator.** The norm's S(t) is one sumcheck over both pieces. The T-domain zero-check hosts it, and each piece's D-domain relation reads the same denominator plane.
* Sol's scalar tests show that per-piece rounding, wrong offsets and a one-piece denominator each give different integers (6 / 48 / 779 / 3 counterexamples). These are scalar demonstrations; the construction simply never computes those quantities.

## 3. Endpoints and boundaries (D12 / D12a)

Two piece commitments per logical endpoint, each with its own derived geometry:
* external, `endpoint_g`: data + 5 rows, one site;
* internal, `boundary.rs`: data + 2·sites + 2.

Each attack against the piece list, and why it fails:
* **Swap or duplicate.** At Shieldstral the pieces differ in data rows (16 vs 8). A swapped or duplicated root therefore fails the opened-column hash against the verifier-derived row count. For profiles with equal-width splits, the piece index must still be in the spec digest, the generator domain and the absorb label (C-7c).
* **Drop.** The piece list, the IO slots and the claim schedule come from the profile, so a missing root or slot is refused by count.
* **Cross-run substitution.** Each root is absorbed before any challenge of the run. Soundness never relies on a root's origin: a foreign root must still satisfy every claim of this run. Reuse is a **privacy** matter (O-2, a commitment opened in two artifacts). It must be stated for each piece root, and the ordered pair must be the endpoint identity everywhere downstream, never a single piece root (C-7f).

**The one logical cross-layer equality is preserved.** Per piece, block k's `IO_OUT` piece claim and block k+1's `IO_IN` piece claim both open the same boundary piece commitment, once. The conjunction over the two pieces, under one profile-constant piece map, is the full-plane equality. There must be one scale per logical boundary, shared by both pieces (D12a).

**Register.** D12 rule 2 ("exactly two external endpoints") still holds logically. But D12a's "one prover-generated boundary commitment" does not literally cover two commitments per boundary, so the security owner must rule on it.

**An option worth recording.** One commitment per logical boundary, holding both pieces as blocks of rows, with geometry from the boundary rule (data + 2·sites + 2):
* external: 30 rows (2 sites), against 34 for two pieces and 37 in R13;
* internal: 34 rows (4 sites), against 36 and 38;
* **no extra PCS openings**;
* my rank model gives disclosed 0.

Today's external endpoint has a spare row (slack 1). The joint external version would have slack 0 unless a 31st row is added. Sol's two-piece form reuses the per-commitment analysis verbatim and is acceptable once the register ruling is made.

## 4. Masks, CFS and privacy

**The rank sketch** (`ops/zkp-mvp/s4-design-check-scratch/rank_model.py`, exact Goldilocks Fp2, T128 rows with N = 2^14) [COUNTED; linear view of one commitment only].

How it works:
* Per commitment, the opening reveals one row combination per column-key group plus the proximity combination: 2(G + 1) base-field vectors.
* The audit gives every claim an exclusive reserved pair, and the proximity pair is exclusive too. So the restriction to non-data rows is block-diagonal: rank 2(G + 1) if and only if each group has a member with Norm(λ·cm) ≠ 0 and det(prox) ≠ 0.
* Lifting changes cm only under whole-lift (cm·σ), which is nonzero unless σ = 0.

Results:

| Case | Disclosed |
|---|---|
| A-like commitment (batched norm, Q/K/V lifted claims, per-piece ZC and IO claims), R13 native padded reference | 0 |
| The same, whole-lift / independent / B-gate | 0 / 0 / 0 |
| σ = 0, whole-lift (claim omitted) / independent (pure-mask claim) / B-gate | 0 / 0 / 0 |
| **Negative: mask-only scaling at σ = 0** (data part kept, mask part zero) | **2** (unmasked evaluation) |
| Endpoint piece, external (data + 5, 1 site), D0 / D1 | 0 / 0 |
| Endpoint piece, internal (data + 6, 2 sites), D0 / D1 | 0 / 0 |
| Negative: single proximity row; 2 sites on a data + 5 piece; piece opened twice | 1 / 1 / 1 |
| Joint option: external 2 sites (30 rows) / internal 4 sites (34 rows) | 0 / 0 |

**Answers to the specific questions.**
* **Does a zero or small coefficient leak?** Nothing is "small" in a field: any σ ≠ 0 is a public invertible scale, so privacy is exactly the native case.
  * At **r_b = 1** (σ = 0), whole-lift zeroes the *entire* functional, both data and mask, so nothing is disclosed.
  * Independent leaves a pure mask evaluation, so nothing is disclosed.
  * B-gate never puts σ in a private functional.
  * The only leaking variant is scaling the mask without the data. No proposal does this, and the native code must never build it (C-5).
* **Probability.** Each omitted challenge equals 1 with probability 1/p² ≈ 2^-128. There are 15 coordinate events per block:
  * Q, K, V: 3;
  * gate and up output pieces × the D1 input: 4;
  * down output pieces × the F1 input, k = 3: 6;
  * the two norm sums: 2.

  Over 26 blocks that is **390/p² ≈ 2^-119.4 per run**.
* **What happens at σ = 0.** It depends on the style: whole-lift needs C-6, independent needs nothing, B-gate needs nothing.
* **Native interaction (the decisive point between styles).**
  * `audit_claims` refuses a zero coefficient on a site row ("zero terminal mask coefficient; discard attempt") and refuses any unused reserved pair.
  * `open_zk` asserts that every group touches a mask row.
  * So whole-lift's checked-zero normalization needs an audit change and a public-rule exemption for the dropped pair. The native-consistent alternative is a challenge-only discard.
  * Independent and B-gate need none of this. This is why I recommend B-gate.
* **The CFS channel.** Each new slot has its own CfsMask, and the extension-round message is masked by c·g_k exactly as native. With fewer variables per lifted slot, each mask message is shorter.
* **Two-piece endpoint openings.** 0 per piece. The pieces are independent commitments with independent masks, so the linear views do not mix. The run-level joint rank (`A_k` output rows, the boundary pieces, `A_{k+1}` input rows) is still owed, as it is in R13.

## 5. Lookups, DD and ACT3

* **One global zero-sum claim.** It holds if every helper column, including the new piece columns, stays in the single H commitment and is whole-row. The smallest H-bearing piece is T·1024 = 8N at both T, so this holds. Keep "every H-bearing piece ≥ N and row-aligned" as a named shape refusal. H's disclosed 2 (the public LogUp identity) is unchanged.
* **N recomputed** [COUNTED from COUNT and the native census]. Lookup positions fall, through the byte and ACT queries:

  | Profile | R13 | Split | Lookup-term gain |
  |---|---|---|---|
  | T128 non-DD | 66,896,384 | 48,677,376 | +0.46 bit |
  | T128 DD | 64,012,800 | 45,793,792 | +0.48 bit |
  | T256 non-DD | 154,747,392 | 118,309,376 | +0.39 bit |
  | T256 DD | 136,921,600 | 100,483,584 | +0.45 bit |

  The 917,504 / 1,835,008 pad-lane ACT queries (T = 128 / 256) disappear.
* **Supports.** The tables are unchanged (byte, exp, ACT, DD), and the T and L support tails stay. The histograms remain one per family, summed over pieces. There must be no per-piece families.
* **The nonzero-numerator premise.** The rational identity implies multiset inclusion when every inverted argument is nonzero and the counts stay below p. The counts here are N < 2^28, far below p ≈ 2^64. The prover inverts every argument, and the refusal residual (at most 768 distinct arguments per block) is unchanged.
* **ACT3.** The group coordinate must be the public table of **global** F-channel group ids.
* **DD.** The proposed ACT3 bound 2(N − 1)/p² must be re-evaluated at the new N. The R13 review covered it at R13; it is not re-reviewed here. DD is per attention row and untouched by the D/F split, so all six D30 conditions carry over unchanged.

## 6. Isolated evidence

**Reproduction** (guarded light job `s4dc-checks-1`, 0.48 GiB peak, 7 s) [MEASURED, shared box, n = 1]. I rebuilt Sol's `algebra.rs`, `scalar_split.rs`, `pcs_lift.rs` and `cfs_lift.rs` from source against the pinned rlib `bdb08e43…`. All four summaries and all 192 rejection lines are byte-identical to Sol's logs.

**My harness** (`s4_gate_check.rs`, sha256 `1c1b7f30…`, job `s4dc-gate-3`, 0.49 GiB, 3 s) [MEASURED]:
* **Scope.** Native CFS, sumcheck, PCS and M components. Three mask styles, including B-gate. Five geometries (ratio 2 and 8, with sub-row and multi-row sources). Three slot kinds: moving dot product, fixed-token matmul, moving norm.
* **45 honest microproofs pass.** 405 forgeries are rejected, 135 per style. B-gate's commitment-consistent `OmitGate` is caught at the M sum.
* **90 zero-edge checks.**
* **5 refusals of the separate-gate table** (the degree trap).
* **Earlier attempts, retained.**
  * Attempt 1's wrong-point control was **vacuous** under B-gate: it moved the omitted bit, which no private functional reads. It now moves a retained bit and asserts non-vacuity.
  * Attempt 2 found the degree trap.
  * Both attempts' outputs are kept in `out/`.

**Coverage of the falsification list:**

| Item | Covered by | Gap for the native stage |
|---|---|---|
| Piece swap | `SwapPieces` (claim-map level), both harnesses | Endpoint and boundary root swap: not built |
| Dropped D1 / F1 | `DropSmall`; my `OmitGate` (consistent tables) | — |
| Duplicated inner term | `DuplicateSmall` | — |
| Per-piece rounding | Scalar counterexample only (one minimal example × 6) | Receipt-level witness attack |
| Wrong global c2 / group offsets | Scalar counterexamples (48 / 779) | Receipt-level wrong-offset fold attack |
| One-piece norm | `DropSmall` (Norm kind) plus a scalar example | Receipt-level |
| Zero lift coefficient | Direct functional tests (Sol 24 + 48; mine 90). They cannot be forced through Fiat–Shamir, correctly | — |

All microproof geometries are tiny (log_cols 4). The real axes appear only in `algebra.rs`, which has no PCS. That is adequate for the paper stage and is not native evidence.

## 7. Counts

**Spot check against the native R13 census** (`r13/NATIVE_LAYOUT_CENSUS.json`) [COUNTED]:
* The baseline is (A + H)·N = 146,915,328 / 142,360,576 / 334,921,728 / 303,792,128 words. That is 4577 + 4390 rows × 16384 at T128 non-DD, and so on; it equals COUNT exactly.
* Removed pad words at T128:
  1024·128·(39 D planes + 2·17 D helpers) + 7168·128·(16 F planes + 2·8 F helpers)
  = 9,568,256 + 29,360,128 = 38,928,384.
  Twice that at T256.
* New site masks: 2·(74 + 25)·N = 3,244,032 at T128.
* So the split totals are 111,230,976 / 106,676,224 / 263,553,024 / 232,423,424, which are **24.29 / 25.07 / 21.31 / 23.49 %**. All four match.
* The extra-site budget (A: 41 + 16 + 2 + 3 + 1 + 6 + 3 + 2; H: 17 + 8) is consistent with the role census: 39 D planes plus 2 T-domain norm denominators in DZC1, 16 F planes, and 17 + 8 helpers. These are still a **proposed** schedule; the native census must replace them, as Sol's own entry condition says.

**Corrections to reporting** (the percentages themselves stand):
1. **Rows per boundary.** "34 rows per logical endpoint" is right for the two **external** endpoints. Each of the L − 1 **internal** boundaries is (16 + 6) + (8 + 6) = **36** rows, against R13's 38.
2. **PCS openings.** Two-piece boundaries add **L + 1 openings per run**: 4L + 1 = 105 becomes 5L + 2 = 132 at L = 26. At 2^-105.61 per opening (D15's correction, N = 2^14), the commitment term goes from 2^-98.90 to 2^-98.57, a loss of 0.33 bit. The lookup term gains 0.39–0.48 bit. The whole-run figure must be recounted on the native census before any registration. The lowest R13 profile is Shieldstral T256 non-DD at 96.09 bits against D27's 95 floor, so the margin is about 1.1 bit. The joint-commitment option avoids the extra openings.
3. **Not counted by Sol, in its favour.** The lifted matmul slots run on half-size (D) or eighth-size (F) inner cubes compared with R13's padded ones: 2048 against 4096, and 8192 against 16384. Prover sumcheck work falls as well as committed words. This is not counted here.

M rows go from 50 to 66 (non-DD) and from 52 to 68 (DD). That holds only if each new slot's CfsMask (n·d + 2 words) fits the 256-word message budget, which is plausible since the lifted slots have fewer variables, and the native census must confirm it.

## Conditions the native implementation must meet

* **C-1 Style.** The coordinator records the choice; B-gate is recommended. Whole-lift is acceptable with C-6. Independent is acceptable but has no advantage.
* **C-2 Fold and degree rule.** Every monomial containing a smaller piece has **exactly one** public factor, and that factor vanishes wherever b ≠ 0:
  * matmuls: the zero-padded global-index fold;
  * norm sums: `Tab::Eq` on `(r_t, 0^k)`.

  Otherwise the declared degree, including the extension rounds, is recounted by the slot IR. Required tests:
  * an IR assertion that this public factor is zero on every b ≠ 0 half-cube;
  * the separate-gate negative control;
  * the `OmitGate` / repeated-cube attack at receipt level.
* **C-3 Claim map.** The projected point comes from the verifier's own coordinate schedule. The omitted variables are the leading inner variables after any moving token variables, and fixed token coordinates are never omitted. Folds and coefficients use global indices. Receipt-level attacks: wrong omitted variable, wrong axis, wrong-offset fold, wrong group id.
* **C-4 Single rounding.** One host expression per output entry over the full sum; no partial accumulator committed, published or hosted. Recount no-wrap at the true widths; it must come out ≤ R13's.
* **C-5 Masks.** One reserved pair for each new physical claim, with the audit unchanged: one claim per pair and a nonzero site coefficient. **Never scale the mask part without the data part**, which discloses 2 dimensions at σ = 0.
* **C-6 Whole-lift only.**
  * σ multiplies the data coefficient, the mask coefficient and the extension value identically on both sides.
  * For σ = 0, use **either** a challenge-only refusal ("degenerate lift coefficient; discard attempt", added to the refusal residual: 15 events per block) — the simplest and consistent with native c / e handling —
  * **or** checked-zero normalization. That requires: terminal == 0 checked; the claim and its pair exempted from the audit by a public rule; the group count and transcript draws derived from challenges on both sides; and a wire length fixed by the normalized list.
  * Never call `open_zk` on a zero group, and never weaken its assertion.
* **C-7 Endpoints and boundaries.**
  * (a) The piece list (count, order, extents) and one shared scale per logical boundary are profile constants inside the bound profile and run digests.
  * (b) Each piece's geometry is derived (external data + 5 with one site; internal data + 2·sites + 2), and any other geometry is refused by name.
  * (c) A piece index and extent go into each spec digest, generator domain (alongside the role byte) and root absorb label.
  * (d) Each piece commitment is opened exactly once, with two IO slots per side.
  * (e) The register ruling on D12 / D12a for two commitments per boundary is obtained, or the joint single-commitment form is used.
  * (f) The ordered piece-root pair is the endpoint identity in the run statement, token I/O, classifier R-C2 and chain publication. O-2 applies to each piece root.
  * (g) The verifier refuses repeated roots across a run's commitments (defence in depth).
* **C-8 Lookups.**
  * One H commitment and one zero-sum claim.
  * The whole-row piece invariant is a named refusal.
  * Histograms are global per family.
  * Pad-lane ACT queries are removed (T·9216).
  * The ACT3 group column uses global ids.
  * D30's conditions are unchanged.
  * N and the ACT3 bound are recomputed.
* **C-9 Profile, wire and hash.** A new versioned profile and slot ids, registry distinctness, a canonical layout digest, and old/new schemas that fail closed. R13 and legacy bytes stay fixed, proven by the goldens.
* **C-10 Soundness recount.** Recount the whole run per D27 on the native census, covering the lookup term (improves) and the commitment term (worsens by 0.33 bit with two-piece boundaries), before any profile registration.
* **C-11 Native gates.** Sol's own list: all 19 trace sites compared with R13 bit for bit; T128 prove, fresh verify and tamper; a generic dense honest witness. Add the receipt-level attacks from §6's gap column, plus endpoint and boundary swap, duplicate and drop, a cross-run piece root, and a mixed pair.

## What the privacy gate must re-derive

No inherited approval applies. R13 itself has no privacy acceptance.

* **P-1.** The rank lemma per commitment on the **native census**: A, H (disclosed 2 = the public identity), M, and every endpoint and boundary piece, using the rank tool on the real layout. My model is a sketch.
* **P-2.** The CFS lemma for each of the 8 new slots, and the M message budget.
* **P-3.** NL-1 and joint-view captures of the new profile. The run-level joint rank across `A_k` output rows, the boundary pieces and `A_{k+1}` input rows (already owed) is now needed per piece.
* **P-4.** The refusal and zero-coefficient channel of whichever σ = 0 rule is chosen. With B-gate there is none.
* **P-5.** The two-piece endpoint statement: O-2 per piece root and the ordered-pair binding (or the joint option's own geometry).
* **P-6.** Confirmation that no partial matmul value is ever on a commitment or the transcript. This holds by construction B.

## Files

All under `ops/zkp-mvp/s4-design-check-scratch/`:
* `rank_model.py`, sha256 `c211ffcc…`, and its output `rank_model.json`, sha256 `29b0b92b…`;
* `s4_gate_check.rs`, sha256 `1c1b7f30…`, and its output `out/s4_gate_check.out`, sha256 `2a4397c3…`;
* the attempt-1 and attempt-2 sources and outputs;
* `run_checks.sh` and `run_gate.sh`;
* the guard records `s4dc-*.guard.json`.

Nothing of mine is running. No git writes. No Sol, frozen or register file was edited.
