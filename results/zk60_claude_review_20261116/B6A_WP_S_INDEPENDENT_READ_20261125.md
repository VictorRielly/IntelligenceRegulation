# B6a WP-S soundness note: independent read (2026-11-25)

Reader: a Claude agent, for the coordinating agent. Read-only on Sol's files; nothing in Sol's tree, `formal/`, `ops/` or
`docs/` was changed. Scratch files: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/wps_read/`
(`B6aFoldSoundnessCopy.lean`, `recompute.py`).

Objects read:
- note `results/zk60_sol_20261105_w16r3/b6a/WP_S_SOUNDNESS_20261124.md` (35 lines)
- Lean `results/zk60_sol_20261105_w16r3/b6a/B6aFoldSoundness.lean` (91 lines), `formal/ZK60Formal/ThirdParty/FlashProve/Code/Half.lean`,
  `Code/Agree.lean:29-75`, `Code/Mutual.lean:59-81`, `formal/ZK60Formal/SoundGroups.lean:334-367`, `ExecOpeningCode.lean:274-304`
- plan `docs/zkmatrix-poc/ZK60_SIZE_B6A_BUILD_PLAN_20261124.md` (all, including the addendum)
- code: `integration-9fbc85292/zkp-core/src/tower.rs` (whole), `.../pcs/switched.rs` (whole), `.../pcs/switch.rs` (whole);
  production `ops/zkp-mvp/gpu-metal/zkp-core/src/transcript.rs:1-200`, `mle.rs` (`eq_table_msb`, `interpolate_eval`),
  `sumcheck/rounds.rs:1-30`; `profile-9fbc85292/hashline/src/private_block/shape.rs:870-892`, `b6a_protocol.rs:132-179`,
  `b6a_wire_tests.rs:13-36`; `source-wp0/complete/zk60_b6a_spike.rs:20`.

Labels: **PROVED-IN-LEAN** (a compiled declaration states it), **ARGUED-IN-NOTE** (the note gives an argument, I followed
it and found it correct unless said otherwise), **ASSERTED-ONLY** (stated or needed, no argument and no proof),
**WRONG**, **NOT-CHECKED**. "Verified by running" and "inferred by reading" are kept apart in each section.

---

## Verdicts, one line each

1. **Q1 (argument).** As an interactive, round-by-round sketch for the code as implemented, the chain is correct by my
   reading at every step it covers: commitments, each fold round (far case by MCA, close case by sumcheck), the
   carried claim, the switch, BASE, the samples, the stage-one batching. It is **not complete**: it gives per-round
   terms only and never composes them; Merkle binding/extraction is assumed; Fiat-Shamir is explicitly deferred; the
   bridge from the batched stage-one check to the D59 lemma's acceptance predicate is argued in two sentences, not
   stated. I found no step that is wrong.
2. **Q2 (Lean vs use).** Each of the five statements says what the note uses it for, with the right quantifier order,
   the right code (degree <= K-1 at the given points), and the right radius `floor((N-K)/2)`. They cover only the
   per-line algebra (one fold, uniqueness, the arithmetic, the rank obstruction). Everything probabilistic and every
   composition step is outside Lean. The field size never appears (the bound is a count, which is the right form);
   the instantiation at `E = Fp2`, `|E| = p^2`, and at the domain `7 * G_N` is not done.
3. **Q3 (compile).** Compiles, no errors, no warnings printed, no `sorry`. All five declarations rest only on
   `[propext, Classical.choice, Quot.sound]`.
4. **Q4 (table).** Every figure in the note's table and in its two pad-variant sentences reproduces to the printed
   precision. The note establishes per-round levels (111 to 116.2 bits). The whole tower for one block, composed
   from the note's own formulas at the implemented shape (W rate 1/8, 6 + 4 fold rounds), is **2^-108.16**
   interactively: **19.84 bits short of 128**. With the plan's unchanged stage-one terms for A and H added it is
   2^-108.01 (20.0 bits short). Across 26 blocks the tower terms alone sum to 2^-103.46.
5. **Q5 (code vs note).** The code matches the note on every parameter and check I traced (list in section 5). The
   plan's section 2.3 step 10 (W2 with 17 rows, 5 fold rounds) does not match the code (16 rows, 4 rounds); the
   addendum and the note already correct the plan, so this is a stale plan line, not a code defect.

---

## 1. The argument, step by step (Q1)

Notation as in the note: `E = Fp2`, `D = 7 * G_N`, `C = RS_E(D, K-1)`, `e = floor((N-K)/2)`, `d = N-K+1`.

| # | Step | Code site | My reading | Label |
|---|---|---|---|---|
| 1 | W is an E-linear RS code on `7 * G_N`, encoded per base-field component | `tower.rs:72-92` (coefficient `i` times `7^i`, size-N forward NTT), `generator` `:94-108` (point `7 * omega^pos`, powers `0..K-1`) | E-linear because the domain lies in `F_p`; storing an Fp2 row as two Fp rows does not change column disagreement sets. Degree cap = message length `K` (`encode` rejects other lengths, `:73`). | ARGUED-IN-NOTE (correct) |
| 2 | W's root is bound before the A/H column indices and before alpha, mu, theta | prover `switched.rs:425-436`, verifier `:472-480`; `bind_w` absorbs rows, width, positions, root `tower.rs:295-306` | Correct order. So the W word, and its unique decoding when close, is fixed before every stage-one challenge after lambda, rho. | ARGUED-IN-NOTE |
| 3 | Stage-one batching, error `2/|E|` | `switched.rs:306-366`, `switch.rs:224-281` | The combined check is `sum alpha_g e_g + sum_{g,x} mu_g theta_x s_{g,x}`, a polynomial of total degree 2 in independent challenges, with the errors fixed before the draws (W fixed by its root, x drawn, A/H columns fixed by their roots). Schwartz-Zippel gives `2/|E|` (times the bias factor). One theta per sample occurrence (`switched.rs:319-321`), so duplicate positions are fine. | ARGUED-IN-NOTE (correct) |
| 4 | Reduction to the D59 lemma | note line 30, cites `SoundGroups.lean:355` | `groups_sound_rs_half` takes vectors as a function `v : G -> (Cl -> E) -> (kappa -> E) -> mu -> E` of (lambda, rho) only, and its `GroupsAccept` checks each equation. The B6a analogue has (a) vectors defined only when W is close, (b) a batched acceptance. A bridging statement is needed: "B6a accepts and not good" is contained in "GroupsAccept(decoded W) and not good" union "tower accepts with W far or its claim false" union "batching error". The note's two sentences give the idea; the event inclusion is not written. | ARGUED-IN-NOTE (sketch only) |
| 5 | First fold, far case: at most N bad r per round | `prove_fold`/`replay_fold` `tower.rs:382-455`, `fold_in_place` `:359-366` (`a + r(b - a)`, first half of rows = L) | `mca_rsCode` applied to `(L, R - L)`; the affine form and the Lean `affineFold` agree. Per round, for a fixed prefix. Virtual rows: verifier treats rows 48..63 as zero (eq weights zipped against 48 values, `tower.rs:481`; coefficients zero-padded `:439`). | PROVED-IN-LEAN for one line (`exceptional_affine_folds`); per-round use ARGUED-IN-NOTE |
| 6 | First fold, close case: at most 2 bad r per round | `tower.rs:398-416` (round = values at 0, 1, 2, so degree <= 2 by construction), `:445` (`s(0)+s(1)` check), `:450` (`interpolate_eval` at 0,1,2, `mle.rs:337`) | Correct: the true round polynomial is degree 2, fixed by the decoded table and the verifier's coefficient rows; a false sum forces a different polynomial; they meet in at most 2 points. Combined per-round count `max(N, 2) = N` is a valid round-by-round state argument (a fixed prefix is either far or close). | ARGUED-IN-NOTE (correct) |
| 7 | Union over rounds | none | **Not done in the note.** 6 rounds at W, 4 at W2 in the implemented shape (`b6a_wire_tests.rs:32-33`). See section 4. | ASSERTED-ONLY (missing) |
| 8 | Hand-over: W2 root before W samples | prover `tower.rs:540-544`, verifier `:598-599` | Correct order; it is what makes the successor message `m'` fixed before sampling. | ARGUED-IN-NOTE |
| 9 | Switch: a wrong or far folded word is caught at `>= e+1` positions per sample | samples `tower.rs:543/599`; generator claim `switch_claim` `:457-487` | Three cases, all fine: folded word far (> e disagreements with any codeword); close to `m*` with `m' != m*` (`>= d - e >= e + 1`); `m' = m*` with a false carried claim (caught by the carry). With-replacement uniform indices (`transcript.rs:155-167`, low bits of a u64, exactly uniform for a power-of-two bound) give `((N-e-1)/N)^t`. | ARGUED-IN-NOTE (correct); uniqueness PROVED-IN-LEAN (`unique_successor`); the `d - e` count ASSERTED-ONLY in Lean terms (it uses `minDist_rsCode` but no lemma states it) |
| 10 | Carried claim enters W2's BAT with its own coefficient | `tower.rs:466-473` (first draw is the carry coefficient), then one weight per sampled column `:475-485` | Matches the note and the addendum. Errors fixed before the weights; linear combination with independent weights: `1/|E|`. | ARGUED-IN-NOTE (correct) |
| 11 | W2 far stays far; W2 folds as step 5/6 | `tower.rs:554-561` / `:617-624` | Same argument at N2 = 2^15, 4 rounds. | ARGUED-IN-NOTE |
| 12 | BASE: inner product checked on the sent row, then its encoding sampled after it is absorbed | `tower.rs:625-635` (length, canonical, `dot == base_target`, absorb), `:635-653` (indices after absorb, folded W2 columns vs `encode(base)`) | Correct; same distance argument as step 9. | ARGUED-IN-NOTE |
| 13 | Pad tail and degree cap | W: message width `n = 2^14`, pads in a separate 48th row (`switched.rs:283-303`, 47 x 280 = 13,160 <= 16,384); W2: `switch_rows = n.div_ceil(w2_width) = 16` (`switched.rs:277`), so the reshape uses every coordinate | The note's "K includes any pad tail if allocated" and "17th row only if a tail is allocated" match: no tail is allocated in either level. Coordinates the coefficients never touch (pad row entries 13,160..16,383, any W2 tail if `packed > width`, `tower.rs:538-539`) are unconstrained but enter no claim, so they do not affect soundness. | ARGUED-IN-NOTE |
| 14 | Challenge derivation | `challenge_fp2` `transcript.rs:139-148` (two 128-bit draws reduced mod p) | Per component max probability `<= (1/p)(1 + p/2^128)`, so `(1 + p/2^128)^2 / p^2` per Fp2 value, as the note says. Indices exactly uniform. | ARGUED-IN-NOTE (correct) |
| 15 | Merkle binding and extraction of W, W2 (and A/H columns) | `verify_openings` `tower.rs:258-293` (count, position, width, depth, canonical, keyed leaf, path) | The note's first sentence assumes "authenticated commitments". No argument. | ASSERTED-ONLY |
| 16 | Fiat-Shamir | whole transcript | Deferred by the note. Two things the FS proof must cover explicitly: (a) the BAT challenges are drawn **without absorbing the opened columns** (A/H columns before alpha, mu, theta: `switched.rs:474-480`; W columns before the carry and weights: `tower.rs:599-616`), which is sound only through the Merkle binding of roots already absorbed; (b) the first-fold target `T` and coefficient rows are not absorbed (they are recomputed by the verifier from absorbed data, which is fine). Under the usual RBR-to-FS transfer the loss is the hash-query budget times the largest single-round error (2^-111 at W rate 1/8). | ASSERTED-ONLY (deferred) |

Small citation issue (not a soundness issue): the note's "Affine fold convention" link points at
`ops/zkp-mvp/gpu-metal/zkp-core/src/sumcheck/rounds.rs#L13`, the generic sumcheck interface. The tower does not use it;
its fold is `tower.rs:359-366` (`a + r(b - a)`), which does match the Lean `affineFold`.

---

## 2. Lean statements against the note (Q2), inferred by reading

| Declaration | What it states | Used in the note for | Match? |
|---|---|---|---|
| `half_radius` | `2e + (K-1) + 1 <= N` and `2e < N - (K-1)` for `e = (N-K)/2`, `0 < K <= N` | "Then `2e+(K-1)+1 <= N` and `2e < d`" | Exact. |
| `endpoints_iff_difference` | both halves in `agreeOn S` iff `L` and `R - L` are | "Agreement of both halves ... is equivalent to agreement of L and R-L" | Exact. |
| `exceptional_affine_folds` | for fixed `left, right : R -> Fin N -> E`, the number of `r : E` such that some `S` with `N <= |S| + e` has every fold row in `agreeOn (rsCode points (K-1)) S` while not both halves are, is `<= N` | "a fold can become close at at most N values of r" | Right quantifier order (pair fixed, then r; S may depend on r, which is the strong form). Right code and radius. Rows arbitrary (`[Finite R]`), domain arbitrary (`Fin N ↪ E`). Slightly stronger than the note's use (the note's "far" hypothesis is a special case). **Not instantiated**: no statement fixes `E` to Fp2 or the points to `7 * omega^j`; the probability `N / p^2` and the bias factor are prose. |
| `unique_successor` | two codewords within `e` of the same word are equal | "Uniqueness at radius e" in the fold and the switch | Exact. It does not state the `d - e` disagreement count the switch uses; that follows from `minDist_rsCode` but is not written. |
| `mixed_columns_need_two_folds` | `a⊗u + b⊗v` is not a rank-one `x⊗y` when both 2x2 determinants are nonzero | design reason for keeping two coefficient rows (item 92) | Correct, and not part of the soundness chain. |

Nothing in the file is weaker than its use. What is missing is the rest of the chain (steps 3, 4, 6, 7, 9-16 above).

---

## 3. Compile and axioms (Q3), verified by running

Copy: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/wps_read/B6aFoldSoundnessCopy.lean`
(Sol's file already ends with five `#print axioms` lines inside the namespace; I appended five fully qualified ones
after `end`, plus three `#check` lines). One guarded run (the only one used of the three allowed):

```
[zk60-guard 16:01:25] START claude-b6a-wps-lean class=build need=8G cap=16G enforce=watchdog-only waited=0s run=7082f471f5dc
'Sol.B6aFoldSoundness.half_radius' depends on axioms: [propext, Classical.choice, Quot.sound]
'Sol.B6aFoldSoundness.endpoints_iff_difference' depends on axioms: [propext, Classical.choice, Quot.sound]
'Sol.B6aFoldSoundness.exceptional_affine_folds' depends on axioms: [propext, Classical.choice, Quot.sound]
'Sol.B6aFoldSoundness.unique_successor' depends on axioms: [propext, Classical.choice, Quot.sound]
'Sol.B6aFoldSoundness.mixed_columns_need_two_folds' depends on axioms: [propext, Classical.choice, Quot.sound]
(the same five lines again from the appended qualified prints)
@Code.mca_rsCode : ... (D : ι ↪ L) {e K : ℕ}, 2 * e + K + 1 ≤ Fintype.card ι → Code.MCA (Code.rsCode D K) e (Fintype.card ι)
[zk60-guard 16:01:36] END claude-b6a-wps-lean exit=0 child_wall=11s peak_rss=3.31G min_avail=204.62G
```

No error, no warning, no `sorryAx`. Command: `lake env lean <copy>` from `formal/` under the guard; nothing was built.

---

## 4. Parameter table and whole-opening level (Q4), verified by running

Script: `.../scratchpad/wps_read/recompute.py` (`python3 -I`), using only the note's formulas: `e = floor((N-K)/2)`,
sample bits `= -t log2((N-e-1)/N)`, fold bits `= -log2(N (1+p/2^128)^2 / p^2)`, `p = 2^64 - 2^32 + 1`.

| Geometry | N | K | e | d | t | sample bits (note) | fold bits (note) | t for 128 sample bits |
|---|---:|---:|---:|---:|---:|---|---|---:|
| W 1/8 | 131,072 | 16,384 | 57,344 | 114,689 | 138 | 114.553 (114.553) | 111.000 (111.000) | 155 |
| W 1/4 | 65,536 | 16,384 | 24,576 | 49,153 | 169 | 114.600 (114.600) | 112.000 (112.000) | 189 |
| W 1/2 | 32,768 | 16,384 | 8,192 | 16,385 | 280 | 116.227 (116.227) | 113.000 (113.000) | 309 |
| W2 1/32 | 32,768 | 1,024 | 15,872 | 31,745 | 120 | 114.683 (114.683) | 113.000 (113.000) | 134 |
| W 1/8, K + 280 | 131,072 | 16,664 | 57,204 | 114,409 | 138 | 114.175 (114.175) | — | 155 |
| W2 1/32, K + 120 | 32,768 | 1,144 | 15,812 | 31,625 | 120 | 114.069 (114.069) | — | 135 |

All reproduce. Fold rounds at the implemented T128 shape: W 48 rows, padded to 64, **6 rounds**; W2 16 rows, **4 rounds**
(same as `b6a_wire_tests.rs:32-33`).

**Whole tower for one block opening, interactive, composed from the note's own terms** (union bound; per-round count
`max(N,2) = N`):

| Term | W 1/8 | W 1/4 | W 1/2 |
|---|---:|---:|---:|
| W folds, 6 x N/|E| | 2^-108.415 | 2^-109.415 | 2^-110.415 |
| W2 folds, 4 x 2^15/|E| | 2^-111.000 | 2^-111.000 | 2^-111.000 |
| W samples | 2^-114.553 | 2^-114.600 | 2^-116.227 |
| W2 samples | 2^-114.683 | 2^-114.683 | 2^-114.683 |
| stage-one batching 2/|E|, W2 BAT 1/|E| | 2^-127, 2^-128 | same | same |
| **tower total** | **2^-108.159** | 2^-108.943 | 2^-109.619 |
| gap to 128 bits | **19.84** | 19.06 | 18.38 |
| + plan's unchanged stage-one terms for A and H, 2 x (2^-113 + 2^-113.93) (cited from plan §4.1, not recomputed) | 2^-108.013 (gap 19.99) | 2^-108.701 | 2^-109.249 |
| x 26 blocks, tower only | 2^-103.459 | 2^-104.243 | 2^-104.919 |
| largest single-round error (what FS multiplies) | 2^-111.000 | 2^-112.000 | 2^-113.000 |

Inferred by reading: the per-round "111 bits" in the note and the plan's "every new round is at most 2^-111" (§4.1) are
true per round, but the six W fold rounds alone sum to 2^-108.4, so no figure near 111 bits applies to the opening as
a whole. Also, at the unique-decoding radius each fold term is `N/|E|` with `|E| ~ 2^128`, so every fold round is
capped at `128 - log2 N` bits (111 to 113 here) whatever the query counts; 128 bits for this tower is out of reach
with Fp2 challenges at these domain sizes. The project's own working line in the plan is 2^-100 per run (plan §4.1,
§6 WP8); against that line the tower adds roughly 2^-103.5 per 26-block run (rate 1/8), which the plan's WP8 recount
has to absorb next to today's measured 2^-98.079 (not recomputed here).

---

## 5. Code against the note (Q5), inferred by reading

| Item | Note | Code | Match |
|---|---|---|---|
| W domain size, rate | N = 2^17, rate 1/8 (development) | `profile-9fbc85292/hashline/src/private_block/shape.rs:886` `w_positions: 1 << (W16R2_LOG_COLS + 3)`, `W16R2_LOG_COLS = 14` (`:344`); K = n = 2^14 (`switched.rs:411-412`) | yes |
| W queries | 138 | `shape.rs:887`; also `b6a_protocol_tests.rs:12`, spike `zk60_b6a_spike.rs:20` (138/169/280) | yes |
| W2 width, domain, rate | 1,024; 32,768; 1/32 | `shape.rs:888-889`; `switched.rs:413-414` | yes |
| W2 queries | 120 | `shape.rs:890` | yes |
| W rows, fold rounds | (not stated in note) | `switched.rs:265-269` (vectors + 1), `tower.rs:368-372`, round count enforced `tower.rs:436` | 48 rows, 6 rounds at T128 |
| W2 rows, reshape | 16 x 2^10, no rest row unless a tail exists | `switched.rs:277`; `tower.rs:120-146` (`packed >= width`, `packed - last.width < width`) | yes; plan §2.3 step 10 (5 rounds, rest row) is stale, corrected by the addendum |
| Coefficient RS code on `7 * G_N` | yes | `tower.rs:72-108` | yes |
| W root before A/H indices | yes | `switched.rs:428-431`, `:472-476` | yes |
| W2 root before W samples | "successor root fixed before sampling" | `tower.rs:542-543`, `:598-599` | yes |
| Carried claim in W2 BAT, own coefficient | yes | `tower.rs:466-473` | yes |
| Fold recurrence, degree 2 | yes | `tower.rs:441-452` (fixed `[Fp2; 3]`, `s(0)+s(1)` check) | yes |
| BASE inner product, then samples after absorb | yes | `tower.rs:625-635`, `:644-653` | yes |
| Query records rejected on wrong count, position, width, depth, non-canonical word, path | (implicit) | `tower.rs:258-293`; A/H `switched.rs:203-247` | yes |
| Uniform indices with replacement | yes | `transcript.rs:155-167` | yes |
| Fp2 challenges, two 128-bit draws reduced | yes | `transcript.rs:139-148` | yes |
| Parameters come from the trusted profile, not the receipt | (implicit) | `b6a_protocol.rs:141-143` | yes |

Source provenance checked by running (hashes and diffs): the production `zkp-core/src/pcs.rs` is an exact prefix of the
integration copy (the suffix only adds the `switch`/`switched` modules and re-exports); `source-wp1` `tower.rs` and
`source-wp2` `switch.rs` differ from the integration copies only in visibility (`pub(crate)` to `pub`) and
`#[cfg(test)]` attributes; `tower.rs`, `switched.rs`, `switch.rs` are byte-identical between `integration-9fbc85292` and
`profile-9fbc85292`; `transcript.rs` and `sumcheck/rounds.rs` are byte-identical to production.

---

## 6. Findings, most serious first

1. **No whole-opening composition (ASSERTED-ONLY, missing).** Note lines 19-26 give per-round terms only. Composed
   from its own formulas, the tower is 2^-108.16 per block at W rate 1/8 (19.84 bits short of 128; about 20.0 with the
   plan's stage-one terms), and 2^-103.46 over 26 blocks. Plan §4.1's "every new round at most 2^-111" should not be
   read as the opening's level.
2. **Fiat-Shamir not done (ASSERTED-ONLY, deferred by the note, line 3 and 34).** The FS proof must account for BAT
   challenges drawn without absorbing the opened columns (`switched.rs:474-480`; `tower.rs:599-616`), relying on
   Merkle binding of absorbed roots, and for the query-budget loss on a 2^-111 largest round.
3. **Merkle binding and extraction assumed (ASSERTED-ONLY),** note line 3 "authenticated commitments".
4. **Bridge from batched stage-one to the D59 lemma (ARGUED-IN-NOTE, sketch only),** note line 30 vs
   `SoundGroups.lean:355-367`: the lemma's `GroupsAccept` checks each equation for vectors given as functions of
   (lambda, rho); the B6a case needs an event inclusion covering W far and the batched check. Not wrong, not written.
5. **Per-round close-case count, max(N,2), sampling, switch, BASE (ARGUED-IN-NOTE),** note lines 11, 15-17. Correct
   by my reading; none of it is in Lean, including the `d - e` disagreement count.
6. **Instantiation gaps (ASSERTED-ONLY),** note lines 7 and 11: Lean is generic in `E` and the points; `|E| = p^2`,
   the domain `7 * omega^j` in Fp2, and that `ntt.roots[k]` has order exactly `2^k` are not instantiated
   (`ExecOpeningCode.lean:294` proves primitivity of `7^((p-1)/2^k)` in GF, and its comment says the code's tables are
   checked by a corpus; I did not check that link).
7. **Stale plan line (WRONG in the plan, already corrected by the addendum):** plan §2.3 step 10 "FOLD over W2's 5 row
   bits" and step 8 "plus a rest row"; code has 4 rounds and 16 rows.
8. **Citation (minor):** note line 9 links the affine fold to `sumcheck/rounds.rs#L13`; the tower's fold is
   `tower.rs:359-366`.

No finding is labelled WRONG against the note or the code.

---

## 7. Not checked

- Whether the Rust suites pass; I ran no cargo command. Completeness of `encode` vs `generator`, and of the MSB fold
  order vs `eq_table_msb` (`mle.rs:56-59`), is taken from Sol's recorded qualification logs, not re-run.
- `NttTables` root values (`ntt.rs:21-43`) against the Lean `rootGF`.
- The D59 lemma's proof and its hypotheses beyond the statement at `SoundGroups.lean:355-367`.
- `zk_rhos`, `group_zclaims`, `fold_rows_multi_zk`, `assert_mask_sites` (existing stage-one code), and `check_opening`.
- `b6a_wire.rs` codec bounds, `hash_domain.rs` census, the Metal path, the rung T32 vector count.
- The Fiat-Shamir chain files (`FSOpening.lean` etc.) and any query budget; the run-level recount (2^-98.079 figure).
- Hiding / zero knowledge (out of scope), timing, design alternatives.
- The note's link `hashline/src/private_block/protocol.rs#L215` (native group admission) and item 92.
