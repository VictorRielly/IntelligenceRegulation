# Build plan: proof-size step B6a, "switch the clear vectors" (2026-11-24)

**Summary for a non-specialist (fifteen lines).**
1. Today one 128-token request produces a receipt of about 0.67 GB (the installed classifier) to 0.85 GB.
2. About half of it is "clear vectors": long lists of numbers the prover sends so the checker can test the commitments.
3. B6a stops sending them. The prover locks them into one small new commitment per block and proves the same tests
   about it with a short chain of folding steps (a "tower"), borrowed in design from FlashProve.
4. Modelled result: the installed classifier's receipt goes from 669.6 MB to about 354 MB, or 333 MB if the
   boundary openings are included; the 8B profile from 818.7 MB to 405 MB. These are MODEL figures, nothing is built.
5. The other half of the receipt (the opened columns) stays. Going below 50 MB needs a later, larger step (B6b).
6. The prover's extra work is modelled as small (a few ms per block); the checker gets faster (about 5 to 15 times on
   its commitment work). Both must be measured before the full build.
7. B6a does not need the unmerged W16R3 work (B1). It can be built on today's W16R2 rows; the checker pays a few
   extra milliseconds per block for that.
8. The first build should target the installed classifier's geometry (W16R2 Shieldstral T128), under a NEW profile
   name, off by default. Old receipts stay byte-identical.
9. Hiding: the new messages are computed only from values the checker already sees today plus fresh randomness, so
   the existing hiding proof extends by a short added step. The study's wording of that claim needs one correction.
10. Soundness needs a new written argument for the tower; every new error term is modelled at 2^-111 or smaller.
11. Lean: the opening's model, its Fiat–Shamir chain and the run's query counts change; the circuit, lookup and slot
    proofs do not. Rough size: 3 to 6 weeks of Lean (ESTIMATE), more if the classifier's W16R2 chain must be built.
12. Sol is the builder. Two packages (the tower module and the generator-claim helper) are new files only.
13. A half-day guarded timing spike, with pass and kill lines fixed below, comes before the integration packages.
14. Two rulings are asked of the owner (§9): which base profile, and whether B6a waits for W16R3 (recommended: no).
15. Nothing here is claimed sound or private. Nothing ships as production before its two Lean statements (D63).

Written by a Claude agent for the coordinator, 2026-11-24 (clock 08:38:54Z at the last reading). Authority: D82
(Victor, 2026-11-24: "Go ahead and start on the size work."). Design source: `W16R3_DESIGN_B6_20261105.md` (the
"study"), its model `results/zk60_effplan_20261105/b6/model.py` (re-run today, `python3 -I`, output identical to the
recorded study figures). Builder: Sol, after this plan is posted and the wave-2 branch (agy/host-wave2) has merged.

**Labels.** MEASURED (a record is cited), COUNTED (file:line in today's tree, HEAD `9d59fe96c`), MODEL (the study's
model, parameters stated), INFERRED (a residual of a measured total and counted formulas), ESTIMATE (my judgement).
Paths below are relative to the repository root; Rust paths under `ops/zkp-mvp/gpu-metal/`.

**Terms used.** *Opening*: the proof that committed rows satisfy linear claims. *Clear vector*: one row combination
`v_g = ρ_gᵀ[M | pads]` (n = 16,384 message entries plus Q = 280 pad entries, each an Fp2 number of 16 B) sent per
claim group, plus one "proximity" vector. *Column*: one position of every committed row's codeword, opened with a
Merkle path. *W*: the new small commitment that holds a block's clear vectors. *Tower*: BAT (batch all claims into
one), FOLD (a sumcheck that folds W's rows into one), CS (code switch: commit the folded row as a smaller new
commitment, check old positions against it), BASE (send the last small row). *Generator claim*: "the codeword symbol
at position x equals a known linear form of the message".

---

## 1. Prerequisites: what is in the tree, what is a candidate, which profile to target

### 1.1 What exists today

| Item | State | Evidence |
|---|---|---|
| W16R2 profiles (rate 1/2, Q = q_pad = 280, log_cols 14) | in the tree | COUNTED `hashline/src/private_block/shape.rs:296-323` (`W16R2_RUNG_H24`, `W16R2_SHIELD_T128_H24`, `W16R2_8B_T128_H24`) |
| R13 profiles (rate 1/4, Q = 256) | in the tree | COUNTED `shape.rs:206-217`, `COL_CHECKS = 256` at `shape.rs:602`; Lean `OpeningR13.lean:49` `r13Prm := ⟨14, 4, 256, 256⟩` |
| Row encoder | evaluation form only (inverse NTT, then `(X^n − 1)·g` pads on the coset 7·G_N) | COUNTED `zkp-core/src/pcs.rs:674-693` (inverse NTT at `:680`) |
| Any `W16R3` string or code | **absent** | COUNTED: `grep -rl W16R3 ops/zkp-mvp/gpu-metal` returns no file |
| B1 (coefficient rows) | **candidate only**: `results/zk60_sol_20261105_w16r3/b1/B1_CANDIDATE_V3.patch` (17 files) and the isolated tree `b1/source-perf-forward-3` | Sol's `b1/FINAL_IMPLEMENTATION.md`; profile strings in the patch, lines 325-327: `…-rung-lh-t32-w16r3-d/1`, `…-shieldstral-3b-t128-lh24-w16r3/1`, `…-llama-3-8b-t128-lh-w16r3/1` |
| B2, B3 | not in the tree; B2 retained, B3 work lives in Sol's isolated D26 trees | Sol's `results/zk60_sol_20261105_w16r3/PROGRESS.md`, `b1/FINAL_IMPLEMENTATION.md:48` |
| W16R3 freeze | not approved (D67, D78: "its freeze still needs Victor's approval") | `ZK60_DECISIONS.md` rows D67, D78 |
| Executable Lean opening checker | has both a W16R2 (Lagrange) and a W16R3 (coefficient) column encoder | COUNTED `formal/ZK60Formal/ExecOpening.lean:942-967` (`w16r2Prm`, `w16r2OpenCheck`, `w16r3OpenCheck`), `:283-299` (`encLagAt`, `encCoefAt`) |

### 1.2 Sol's preflight (`results/zk60_sol_20261105_w16r3/b6a/PREFLIGHT_20261124.md`), checked

1. **"B1 exists only in the isolated tree; the active tree and wave-2 use the evaluation encoder."** Agree for the
   active tree (COUNTED above). I did not check out the wave-2 branch, so its encoder is Sol's claim, not my check.
2. **"The original B1 patch has three dry-run conflicts on the active tree and four on wave-2."** Reproduced for the
   active tree: `git apply --check` of `B1_CANDIDATE_V3.patch` on the working tree at `9d59fe96c` fails in exactly
   `gpu/metal.rs:1835`, `private_block/s25_tests.rs:2691` and `private_block/w16r2_tests.rs:159` [MEASURED, this
   session, read-only]. The fourth conflict on wave-2 (`gpu/mod.rs`) is not reproduced here.
3. **"The 405.0 MB and 387.2 MB models use different row censuses."** Agree, and it is worse than that: neither
   matches the measured D55 fixture exactly. 405.0 MB uses the standalone W16R2 census (A 2,501 / H 2,602 rows);
   387.2 MB uses Sol's standalone B1–B3 census (2,397 / 2,462); the measured 818,728,672 B fixture is the calibrated
   census (2,504 / 2,606 rows; Sol's `b6_interaction/REPORT.md:9-23`), whose extra 15,680 B/fork of columns the
   study hid inside its "slot" residual. **This does not move the B6a figure.** B6a removes only clear vectors,
   whose count depends on the group counts (36 + 1 and 9 + 1), which are the same in the standalone and calibrated
   censuses. So this plan uses ONE rule everywhere (§3): *measured receipt − clear vectors + towers*. It gives
   405,015,152 B for the 8B profile, identical to the study's 405.0 MB. The 387.2 MB figure needs B1–B3 and is not a
   target of this build.

### 1.3 Can B6a be built on W16R2 as it is? Yes.

- **W is new, so its own encoding is free.** W and the later tower stages can use coefficient form (cheap generator
  claims) without touching A/H's bytes. The coefficient encoder itself is ten lines (Sol's
  `encode_row_zk_encoding`, patch lines 1394-1410); B6a can carry a copy in its own module, or use the existing
  evaluation encoder for W (correct, a little more verifier work). The spike decides (§8).
- **Only the stage-1 generator claims see A/H's evaluation encoding.** Under the stage-1 column test the verifier
  needs, per opening, `Γ = Σ_x θ_x G(x)`, where `G(x)` is the encoder's row at opened point x. For W16R2 rows,
  `G_i(x) = (ω^i/n)(x^n − 1)/(x − ω^i)` for message entry i (Lagrange, the same form the Lean model uses in
  `ExecOpening.lean:228-246`, `baryW`) and `x^k(x^n − 1)` for pad k (encoder `pcs.rs:685-691`).
- **What the verifier pays without B1.** Dense: t·(n + Q) = 280 × 16,664 ≈ 4.7 M products per opening, about 9.3 M
  per block for A and H, 10–40 ms on one thread [ESTIMATE; the study's §8 gives 10–20 ms for one opening's worth].
  A cheaper exact route exists: `Σ_x a_x/(x − y)` over the n points y of the subgroup is one rational function
  N(y)/Z(y) of degree < 280, so Γ costs two size-2^14 NTTs and one batch inversion, about O(n log n) [ESTIMATE; the
  builder must test it against the dense form]. With B1 the cost is O(t log n). Either way it is small beside
  today's 3.08 M NTT points and 33.2 M column products per block (study §3.3, MODEL).
- **The prover pays the same Γ once per opening** (host, ~5–15 ms on one thread, ESTIMATE, parallel across threads).

### 1.4 Which profile the first build targets, and why

**Recommendation: a new profile on the installed classifier's geometry, `W16R2_SHIELD_T128_H24` + B6a.** Reasons:
1. It is the first product (D81). The app runs it (`--dev-w16r2-public-content-only`, the A15–wave-2 app records).
2. It gives the largest cut of a receipt anyone uses: 669.6 → 354 / 333 MB (§3).
3. Its block core (`protocol::prove_core` / `verify_core`) is the same code as the 8B D55 fork core, so the 8B
   profile follows with only the join added (WP7).
4. Development and malicious controls run first on the rung sibling (`W16R2_RUNG_H24` geometry, T32), as every
   W16R2 control did.

**The open cost of this choice:** the Lean chain that exists is for R13 Shieldstral (`HonestShieldTop.lean:2-8`,
"concrete honest Shieldstral T128 R13 prover"). No W16R2 classifier chain exists, so production (D63) on this base
needs one. That is ruling R1 in §9.

---

## 2. B6a against the code

### 2.1 What an opening sends in the clear today

`pcs::open_zk` (`zkp-core/src/pcs.rs:1040-1069`): draws λ per group and the proximity weights (`zk_rhos`,
`:952-973`, uniform independent Fp2 on every row), computes the vectors (`fold_rows_multi_zk`, `:976-1000`; on the
device through `fold_rows_with_pads`, `hashline/src/gpu/mod.rs:884`, `gpu/metal.rs:1690`), **absorbs every vector**
(`:1049-1052`), draws Q column indices (`:1053`), and returns `OpeningZk { group_vecs, prox_vec, columns }`
(`:622-629`). Wire length per opening: `(groups + 1)(n + Q)·16 + Q·(8 + 8·rows + 32 + 32·path)`
(`hashline/src/private_block/wire.rs:106-108`).

Per block (W16R2, n = 2^14, Q = 280, path 15; groups 36 / 9 from `shape.rs:2806-2835`):

| Opening | vectors | vector bytes | column data | paths + salts + indices | total |
|---|---:|---:|---:|---:|---:|
| A (2,501 rows) | 37 | 9,865,088 | 5,602,240 | 145,600 | 15,612,928 [MEASURED `results/zk60_w16r2_q280_20261103/logs/targeted_cpu.log:1539`] |
| H (2,602 rows) | 10 | 2,666,240 | 5,828,480 | 145,600 | 8,640,320 [MEASURED, same] |
| boundary (38 rows, 2 groups) | 3 | 799,872 | 85,120 | 145,600 | 1,030,592 [COUNTED formula] |
| M (mask, unchanged by B6a) | 2 | 32,768 | 102,400 | 108,544 | 243,712 [MEASURED, same] |

**Reconciliation with the measured receipts:**
- **8B D55, 32 blocks:** the study's census reproduces 818,728,672 B exactly (model `§1` asserts; MEASURED total
  `a12merge_d55.log:233`). Clear vectors are 427,913,600 B (52.3%), column data 371,864,320 B (45.4%).
- **Installed classifier (W16R2 Shieldstral, 26 blocks):** **669,561,472 B per request** [MEASURED,
  `results/zk60_classifyhost_app_20261123/raw/ch_smoke/t2_results.json`, every completion]. Its row census equals
  the 8B's (A 2,501, H 2,602, endpoint 37; MEASURED `results/zk60_w16r2_q280_20261103/logs/accounting_inputs_q280.log:3`).
  26 × (A + H + M + boundary) = 663,716,352 B; the residual 5,845,120 B (0.9%) is the slots, the frames and the IN-C
  and OUT-C stage segments [INFERRED; not traced item by item]. Clear vectors: 26 × 13,331,200 = 346,611,200 B (52%).
- **R13 Shieldstral (rate 1/4, Q 256, path 16; A 4,577 / H 4,390 rows MEASURED
  `results/zk60_lean_resume_20261109/regen_l17export.log`):** 848 MB [MEASURED, rounded, `MVP_STATUS.md:2958`,
  2026-10-30]. 26 × 32,421,888 = 842,969,088 B; residual about 5.0 MB [INFERRED].

### 2.2 What is committed instead: the matrix W

- **Shape** [MODEL, study §2.2]: one W per block (per D55 fork, or per classifier block segment). Rows are Fp2: the
  47 vectors' first 2^14 entries, one row each, plus one row holding all 47 × 280 pad entries (13,160 ≤ 16,384):
  **48 Fp2 rows × 2^14 = 96 Fp rows**. With the classifier's boundary vectors included, 50 vectors and 51 rows.
- **Code:** a Reed–Solomon code on a coset, rate 1/8 in the model (N = 2^17, t_W = 138 positions per list at
  today's 2^-113.93). Rate 1/4 (t_W = 169) costs +37 KB per block; rate 1/2 (t_W = 280) +178 KB [MODEL, re-run
  today]. The rate is a spike decision: 1/8 means 100 MB of encoded W per block to hash, 1/4 means 50 MB.
- **Where it enters the transcript:** absorbed with `absorb_root` (`protocol.rs:154-158`, label, rows, log-cols)
  after both openings' λ and ρ draws and before both openings' index draws. Nothing else of the vectors is absorbed.

### 2.3 Transcript order, prover and verifier (one block core)

Today (`protocol.rs:3089-3103` prover, `:3203-3270` verifier): M opening; `check_opening(A)`; A's λ, ρ; A's vectors
absorbed; A's indices; A's columns; then the same for H. B6a:

| Step | Message | Challenge drawn after it |
|---|---|---|
| 1 | M opening, unchanged (`zk::mask_open`, `protocol.rs:3089`) | as today |
| 2 | `check_opening(A)` replay, then A's λ per group and ρ_prox (`zk_rhos`) — no message | λ_A, ρ_A |
| 3 | `check_opening(H)` (its replay clone taken AFTER step 2's draws), H's λ, ρ_prox | λ_H, ρ_H |
| 4 | prover computes the 47 vectors (A8's store fold, as today); sends nothing | — |
| 5 | W root (+ rows, log-cols) | A's 280 indices, then H's 280 indices (`challenge_indices`, as today) |
| 6 | A's and H's opened columns, salts, paths — exactly today's column bytes | BAT: α_g (one per vector, for the `<v_g, c_g> = want_g` checks), μ_g (one per vector), θ_x (one per opened position, per opening) — uniform, independent |
| 7 | FOLD over W's 6 row bits: the claimed sum, then 3 Fp2 coefficients per round (degree 2) | one Fp2 challenge per round |
| 8 | W2 root (the folded row, reshaped to 16 rows × 2^10 plus a rest row) | t_W positions of W |
| 9 | W's opened columns at those positions (96 Fp each, salt, path) | BAT on W2's claims (β) |
| 10 | FOLD over W2's 5 row bits | one challenge per round |
| 11 | BASE: the last folded row (2^10 Fp2) in the clear | t positions of W2 (opened in step 12) |
| 12 | W2's opened columns | — |

Notes:
- **Refusals stay challenge-only (D66).** `check_opening`'s replay (`protocol.rs:327-337`) must clone the state at
  the point its own draws start; for H that is after A's draws. A zero α, μ, θ or fold challenge only costs its
  counted 1/|Fp2|; it never stops the prover. No division by a challenge in the tower.
- **The model's third stage (W3) and BASE masking oracle are dropped** in this "plain" design: BASE sends the folded
  W2 row and the verifier checks W2's positions against it directly. This is smaller than the model (it drops about
  68 KB per block); the model figures in §3 are kept as an upper bound. Hiding does not need tower masks in B6a (§4.3;
  toy I3, study §5.2).

### 2.4 The verifier's algorithm (per block core)

1. Rebuild groups and draw λ, ρ exactly as `verify_zk_tagged` does (`pcs.rs:1263-1267`), for A then H; run the two
   `check_opening` audits.
2. Absorb W's root; draw A's and H's indices; check path lengths, Merkle paths and salts of every opened column
   (`pcs.rs:1255-1262`, `:1317-1320`), unchanged.
3. Draw α, μ, θ. Compute the target `T = Σ_g α_g want_g + Σ_O Σ_x θ_x (ρ*_O)ᵀ col_x`, with one combined weight
   `ρ*_O = Σ_{g∈O} μ_g ρ_g` per opening (rows × groups once, then 280 dot products per opening: about 1.4 M
   products per block against today's 33.2 M; MODEL study §3.3).
4. Compute the coefficient rows of W's claim: row g gets `α_g c_g + μ_g Γ_O` (c_g are today's column weights,
   `zkey_weights`, `pcs.rs:911-923`; Γ_O from §1.3). The claim is `<W, C> = T`.
5. Check FOLD's rounds (each round's two-point sum equals the previous value), ending in a claim on the folded row
   `m(X)` with coefficients `C(X) = Σ_g eq(X, g) C_g`.
6. Absorb W2's root; draw t_W positions of W; for each, check W's column (Merkle), compute its folded value
   `Σ_g eq(X, g) col[g]` and turn it into a generator claim `<G_W(y), m(X)> = value` on W2.
7. BAT the claims on W2, FOLD, receive the last row, check its claim and its encoding at W2's opened positions.

Where the verifier time goes [MODEL study §3.3]: 4 K NTT points instead of 3.08 M; about 1.7 M column products instead
of 33.2 M; the same bytes hashed; no 12.5 MB absorb. Modelled PCS verify for a 32-block 8B receipt on 6 threads:
2.31 s → 0.15 s, quoted as ×5–15 (ESTIMATE). Without B1, add Γ (§1.3).

### 2.5 The prover's new work and where it runs

| Work | Where | Size per block | Cost [ESTIMATE, study §3.2 unless noted] |
|---|---|---|---|
| the 47 vectors | device (`fold_rows_with_pads`), as today | unchanged | 0 |
| no absorb of the vectors | host, removed | −12.5 MB of BLAKE3 | −4 to −10 ms host |
| W commit (encode + hash 96 Fp rows) | **device**, through the existing tagged commit hook (`gpu/mod.rs:903` `try_commit_zk_keyed`), if it accepts rate 1/8 or 1/4 (a spike question); else host | 12.6 M points at rate 1/8 | +2 to +4 ms GPU; on the host it would be tens of ms (ESTIMATE, mine) |
| Γ_A, Γ_H; BAT; W's FOLD (48 × 16,664 dense) | host | ~10 M Fp2 products | +2 to +8 ms host |
| W2 commit, its FOLD, BASE | host | ~1 M points | +0.5 to +2 ms host |
| W column gather (t_W columns) | host, from W's encoded copy | 138 × 96 words | negligible |

Sum [MODEL from the study's ranges]: GPU +2.2 to +6.0 ms, host −7.5 to +6.5 ms per block; the 8B forks phase
×0.99–1.05.

---

## 3. Receipt size after B6a, one row census, three profiles

**Rule (the only one used):** receipt after B6a = measured receipt today − the switched clear vectors + the towers
(W's tower bytes from the study's `best_tower`, re-run today; 395,184 B per block with 48 W rows, 401,808 B with 51,
505,616 B for the 8B join's `W_join` of 97 vectors). Row counts do not enter except through column data, which B6a
does not touch. Labels: MODEL, parameters: n 2^14, W at rate 1/8, every list at 2^-113.93 (δ/2), the model's
three-stage tower (an upper bound for the plain design of §2.3).

| Profile | today | B6a, A + H per block | B6a, + boundary / join vectors | ratio |
|---|---:|---:|---:|---:|
| `W16R2_SHIELD_T128_H24` (installed classifier, 26 blocks) | **669.6 MB** [MEASURED] | **354.0 MB** | **333.4 MB** (boundary in each segment's W) | 0.53 / 0.50 |
| `W16R2_8B_T128_H24` (D55, 32 forks) | **818.7 MB** [MEASURED] | 430.4 MB | **405.0 MB** (join vectors in one `W_join`) | 0.53 / 0.49 |
| `R13_SHIELD_T128_H24` (rate 1/4, Q 256) | **848 MB** [MEASURED, rounded, 2026-10-30] | 532.9 MB | 512.3 MB | 0.63 / 0.60 |

R13 gains less because its column data is larger (rate 1/4 and more rows: 18.4 MB per block against 11.4 MB).

**What remains after B6a, classifier W16R2 with boundaries switched (333.4 MB)** [MODEL / INFERRED]:

| Part | Bytes | Share |
|---|---:|---:|
| opened column data, `Q × rows × 8` (A, H, boundary) | 299,411,840 | **89.8%** |
| Merkle paths of the stage-1 columns | 10,483,200 | 3.1% |
| the 26 towers | 10,447,008 | 3.1% |
| M openings | 6,336,512 | 1.9% |
| slots, IN-C / OUT-C stages, frames (the INFERRED residual) | 5,845,120 | 1.8% |
| salts and indices | 873,600 | 0.3% |

**The next largest item is the opened column data**, about 90% (8B: about 369 MB of 405 MB; R13: 94%). Only wider
rows reduce it (B6b, study §2.2: 40–52 MB at rows of 2^18–2^20). B6a is the step that makes B6b possible (compact
masks need the vectors to be gone), not a substitute for it.

---

## 4. Soundness and hiding

### 4.1 New error terms against 2^-100 [MODEL, `model.py` §3, re-run today]

| Round | Error |
|---|---:|
| BAT with product coefficients μ_g θ_x (degree 2) | 2^-127 |
| α batching of the `<v_g, c_g>` checks | 2^-128 |
| FOLD sumcheck round, degree 2 (6 + 5 rounds) | 2^-127 each |
| FOLD line, mutual correlated agreement, N_W/|Fp2| (`mca_rsCode`) | **2^-111** at W rate 1/8 (N = 2^17); 2^-112 at rate 1/4 |
| positions of W and W2, `(1 − (e+1)/N)^t` | 2^-114.07 |
| stage 1 (A, H) field and column terms | unchanged: 2^-113 and 2^-113.93 |

- **The rate stays 2^-102.93** (LogUp α); every new round is at most 2^-111.
- **8B zone (query-free floor):** 155/2^110 → about 163/2^110 = 2^-102.65 [MODEL, study §4.1].
- **Classifier whole run:** today 2^-98.079 (W16R2 Shieldstral L26, MEASURED recount
  `results/zk60_w16r2_q280_20261103/recount_q280.out.txt:28`). Adding about 3.5 × 2^-110 per block × 26 gives about
  2^-98.04 [ESTIMATE, mine; the recount script must be extended, WP8].

**Is D59 untouched?** What is drawn is untouched: the same λ, the same independent uniform proximity weights on every
row (`zk_rhos`), the same Q = 280 indices sampled the same way. What changes: (a) the indices are drawn after W's
root instead of after the absorbed vectors; (b) the per-column, per-group equations are batched (μ θ, error 2/|Fp2|);
(c) their right-hand side is read from W's extracted message, not from a sent vector. D59's lemma
(`opening_sound_rs_half`, `SoundOpening.lean:238`; `groups_sound_rs_half`, `SoundGroups.lean:355`) applies to the
extracted vectors provided W binds them before the indices (Merkle binding plus a δ/2 extractor for W).

**What has to be proved (none of it is):**
1. W binds one message: unique decoding at δ/2 (list size 1 when 2e < d) and Merkle extraction for W, W2.
2. The tower is sound at δ/2: BAT, FOLD (sumcheck plus `mca_rsCode` per line), CS (generator claims; the old
   codeword symbol is a public linear form of the new message), BASE, and their composition. FlashProve's own switch
   argument is "our own; no one has refereed it" (study §1.1). A written argument for OUR codes (coset, Fp rows under
   Fp2 challenges, sampling with replacement) comes first (WP-S below), with an independent read.
3. The stage-1 reduction: if the tower accepts, the extracted vectors pass today's column test except with the batching
   error; then D59's lemma as proved.
4. The Fiat–Shamir chain: the new order of §2.3 instantiated in the round-by-round framework (`FSOpening.lean`).
5. The zone recount at the new constant (`zone_budget_le`), for each base profile used.

### 4.2 What FlashProve's Apache-2.0 library gives, and what is new

- **Already ported, reusable as is:** 15 files, 2,882 lines [COUNTED, `wc -l` over
  `formal/ZK60Formal/ThirdParty/FlashProve/`]: `Code/Half.lean` (`caOn_rsCode` `:125`, `mca_rsCode` `:135`, the
  per-line agreement needed by every FOLD round), `Code/Mutual`, `Code/Agree`, `Code/Third`, `Code/Lines/*`.
- **Not in this repository and not in the local snapshot.** The snapshot
  `results/zk60_astra_20261026/flashprove_comparison_20261104/upstream/` holds only `docs/`, `guide/`, `lean/THEOREM.md`
  and a few C++ headers; the tower files the study cites (`Cb/Ld/LdTower*.lean`, `LdSwitch*`, `LdBase*`,
  `LdTowerThird.lean`) were read from a scratch checkout of commit `9e2bdd8f`. Reuse needs a pinned fetch of that
  commit (Apache-2.0, as for the 15 ported files). For the plain B6a tower, the zero-knowledge files (`LdHide*`,
  `LdSumZk*`, `LdZkPair`) are not needed.
- **New for us:** the δ/2 assembly (FlashProve's `LdTowerThird.lean` is the δ/3 model; ours uses `mca_rsCode` at
  2e < d); BAT with product coefficients; the stage-1 generator claim for the Lagrange (W16R2) or coefficient (B1)
  encoding; the plain BASE; the bridge into our Fiat–Shamir chain.

### 4.3 The hiding claim, checked against the Lean files

**The study's claim (§0, §5.2):** "with today's site masks kept, its hiding follows from the merged `HidingOpening`
lemmas by post-processing."

**Verdict: true in substance, not as written.**
1. `HidingOpening.lean` proves the joint law of one opening's view (every claim's row combination, the proximity
   vector, all opened columns) is data-independent (`openingView_law_eq`, `:285`; on the protocol's points `:405`).
   Its post-processing lemma `openingView_law_eq_comp` (`:423`) covers only a **deterministic** map of the view.
2. B6a's new messages use **fresh prover coins** (W's salts, any W pads, the tower's own salts). The lemma that covers
   a map with independent fresh coins is not in `HidingOpening`; it is `map_pair_eq_bind` in `HidingBlock.lean:40`
   (law of `G (Y ω) c` over independent uniform `(ω, c)`). With it, the argument works: the W layer is
   `G(X₁, c_W)` where `X₁` is the A and H opening view, which `HidingBlock` already treats as one layer (`:5-7`).
3. Still owed, all short but real: (a) a stated **link** that W's message is exactly the clear vectors (and, in the
   classifier, the boundary's) plus fresh coins, in the style of `block_view_law_eq`'s link hypotheses
   (`HidingBlock.lean:20-23`), with a code test that W's rows come only from the vector fold; (b) a four-layer
   `block_view_law_eq`; (c) the view restated, since the verifier no longer sees the vectors but sees W's root and
   columns, the fold messages, W2 and the last row; (d) as today, the Merkle layer and Fiat–Shamir are outside these
   files (`HidingOpening.lean:43-48`). The toy rank test (study §5.4, I2 and I3) agrees and is a falsifier, not a proof.
4. **A condition to keep:** the stage-1 opened positions stay ≤ q_pad (280 = 280, `pcs.rs:740`, `:1017`); toy N6 shows
   hiding fails without it.

---

## 5. Lean impact

| Area | Files | Change | Size [ESTIMATE] |
|---|---|---|---|
| executable opening model | `ExecOpening.lean` (`pcsVerify` `:578`, `w16r2OpenCheck` `:947`), `ExecOpeningCheck.lean`, `ExecOpeningFS.lean`, `ExecBlockWire.lean` | a second checker with no `absorbVecs` (`:570`) and a tower checker; the old one stays for old profiles | 600–1,200 lines |
| opening soundness | `SoundOpening.lean`, `SoundGroups.lean` | `ok` predicate on W's extracted message; batching term; reuse `opening_sound_rs_half` / `groups_sound_rs_half` | 200–400 |
| tower soundness (new) | new `SoundTower*.lean` on `ThirdParty/FlashProve/Code/*` | BAT, FOLD, CS, BASE, composition at δ/2 | 1,500–3,000 |
| Fiat–Shamir | `FSOpening.lean` (`OMsg` `:183` is today's vectors; `fs_opening_knowledge` `:644`), `FSComposeBlock`, `FSPathBlock`, `FSTreeD55` (8B join) | new message list and rounds; re-prove knowledge extraction with W | 800–1,500 |
| zone | the `zone_budget_le` instance | recount at ≈163/2^110 (8B) and the classifier's constant | 100–200 |
| hiding | `HidingBlock.lean` + a new link file | fourth layer by `map_pair_eq_bind` | 150–300 |
| ZK query counts | `HonestShieldZKCount.lean` (today 112 trees, 5,359,616 salted leaves, 283,879 transcript points, budget T = 2^20; `:9-14`), `HonestShieldZKView/Vis/Prog`, and the open witness `W_zk : ShdZKProgWitness` (`HonestShieldTop.lean:16-30`, still unconstructed) | +2 trees per block segment (W, W2): 164 trees; about +4.3 M salted leaves at W rate 1/8 (+2.6 M at 1/4); the 47 vector absorbs leave the transcript count; re-prove `shdRunErrRes` against `εzkTarget` | 300–800 |
| run geometry | `RunOpenGeo*`, `RunCloseBPcs`, `ExtractW16Open`, `OpenKnowBlock` | opening geometry with W | 300–600 |

**Total: 3 to 6 weeks of Lean for B6a [ESTIMATE, agrees with study §7.3]**, on whichever base profile has a chain.
The HonestShield chain is R13 (rate 1/4, δ/3 at stage 1). On a W16R2 base, the classifier chain itself has to be
instantiated at W16R2 first (rate 1/2, δ/2, the W16 lookups); that is a separate and larger item I have not sized.

**What does not change:** `Statements.lean` (never touched); the circuit and `CircuitIff` work; slots, LogUp, zero
checks, M (`HidingM*`, `SoundMProduct`); `SoundColumnTest`, `SoundProximity*`, `SoundMerkle`, `SoundSumcheck`;
the Fiat–Shamir machinery (`FSChain*`, `FSWide*`, `FSRbr`, `FSChallenge`); `HidingOpening`, `HidingOpeningSum`,
`HidingRows`, `HidingRefusal`.

---

## 6. Work packages for Sol, in order

Rules for every package: Sol's own isolated tree (as for B1), the resource guard on every heavy leaf, two build jobs,
`--offline --locked`; old profiles' receipts byte-identical whenever the new profile is not selected (the W16R2
golden, the six post-F12 digests, the pinned trained digests 8B `5343008a`, Shieldstral `e0bb5917`, rung `d6879fae`,
the 818,728,672 B D55 receipt, the 669,561,472 B classifier receipt). Sizes are changed lines including tests
[ESTIMATE].

| WP | Files | What it adds | Tests | Acceptance | Size | Depends on |
|---|---|---|---|---|---:|---|
| **WP0 spike** (§8) | one new ignored test file, e.g. `hashline/tests/zk60_b6a_spike.rs` | timings only, existing functions | — | the lines of §8, fixed before it runs | 150–300 | nothing |
| **WP-S soundness note** | `docs/zkmatrix-poc/` (one note) + a written check in the style of `research/zkp-efficiency/handoffs/20261101-delta-half-lemma-check.md` | the tower argument at δ/2 for our code; the per-line N/|Fp2| term reproduced for coset, Fp rows under Fp2 challenges, interleaving, with replacement | an independent read | the study's kill line: B6 stops if the per-line term does not reproduce | doc | nothing |
| **WP1 tower module** | new `zkp-core/src/tower.rs` (+ `tower_tests.rs`), one `mod` line in `zkp-core/src/lib.rs` | BAT, FOLD, CS, BASE prover and verifier over a generic linear code trait; tagged transcript calls only; plain variant (no masks) | completeness on random instances; every tampered message rejected (each fold coefficient, the W2 root, a W column, a salt, a path entry, the last row, a position set chosen before the root); error-free on degenerate challenges (0) | all honest instances verify; all tampers rejected at the asserted site; no panic on adversarial lengths | 1,200–1,800 | nothing (**can start before wave-2 merges**: new files only) |
| **WP2 generator-claim helper** | new `zkp-core/src/pcs/switch.rs` (+ tests) | Γ for the evaluation encoding (dense and rational-sum) and for the coefficient encoding; the verifier's T and C rows | dense = rational = brute force at toy and full size; duplicates among positions | exact equality on 1,000 random draws at n = 2^14, Q = 280 | 300–500 | nothing (**can start before wave-2**) |
| **WP3 switched opening** | `zkp-core/src/pcs.rs` (additive) | `open_zk_vectors` (draws, vectors, no absorb), `open_zk_columns` (indices, columns), `verify_zk_switched`; old `open_zk` / `verify_zk_tagged` byte-unchanged | old functions' outputs identical on the existing conformance tests; new path verifies; the controls of D59 (far matrix, wrong column, columns before the challenge, pad forgery, close case (f)) ported to the switched path | full zkp-core suite green; byte-identity of old outputs | 400–700 | WP1, WP2; after wave-2 merges |
| **WP4 profile and block core** | `private_block/shape.rs` (new strings, regime, `Shape::build` geometry pin like `:1083-1092`), `protocol.rs` (`prove_core` `:3088-3104`, `verify_core` `:3203-3270`), `wire.rs` (`Dim`, `encoded_len` `:133-140`, `validate` `:143-167`), `hash_domain.rs` (path depths) | the §2.3 order behind the profile; codec; counted length = encoded length | rung: CPU = Metal digest; new goldens; receipts verify; tampered tower messages rejected at the asserted site; s24/s25 census (new absorbs, equal-length pairs), source-invariant scans, `w16_privacy_gate_tests` mask-site and PG-R2 parts on stage 1 | rung receipts verify on both paths; every old golden and digest unchanged | 600–1,000 | WP3 |
| **WP5 device placement** | `hashline/src/gpu/mod.rs`, `gpu/metal.rs` (only if the spike shows the existing commit hook cannot take W's rate) | W commit on the device; host fallback byte-identical | CPU = Metal bytes for W; no-feature build | W commit within the spike's measured band | 100–300 | WP4 |
| **WP6 classifier run** | `token_io/classify_run.rs` (`verify_classify_run_with` `:871-1033` and the prover loop), the segment codec, the classify CLI's profile selection | the classifier at the new profile; increment b: the boundary opening's vectors into the same W (needs the boundary's draws moved before W) | a full 26-block classify receipt verifies in a fresh process; `check-serve` rejects a W16R2 receipt under the new profile and the reverse | measured receipt = counted (§3: ≈354 MB, then ≈333 MB) | 300–600 | WP4, WP5 |
| **WP7 8B D55** | `run_fork.rs` (join, `:2939-2971`), `run_fork_wire.rs` | forks inherit WP4; the join's `W_join` | D55 malicious controls of D55's ruling plus a swapped `W_join` | receipt ≈405 MB counted = measured; the study's kill rule on the N = 6 forks phase | 400–700 | WP4 (parallel with WP6) |
| **WP8 gates and accounting** | test files; `results/` accounting scripts (Sol's directory) | the recount with the tower terms; the run-level joint rank rerun over W's view; the D59 lemma check's conditions restated | Python rank gate, D55 replay gate where they apply | recount within the 2^-100 target; documented | 800–1,200 | WP6 or WP7 |

**Parallelism.** WP0, WP-S, WP1 and WP2 are independent and can run at once; WP1 and WP2 touch only new files, so
they can start before wave-2 merges if the coordinator allows. WP3 → WP4 → WP5 are sequential and wait for the
wave-2 merge (they touch `protocol.rs`, `gpu/*`). WP6 and WP7 run in parallel after WP5. The Lean lanes (§5) can start
from WP-S's note and WP1's interfaces, without waiting for WP6/WP7.

---

## 7. How it is switched on

- **A new profile string per geometry (D17's naming rule; D59 condition 3's pattern).** Proposed constants
  `W16S1_RUNG_H24`, `W16S1_SHIELD_T128_H24`, `W16S1_8B_T128_H24` ("W16R2 rows, size step 1"); the exact strings are
  the builder's, checked by the s25 hash-input census for equal-length pairs as W16R2's were (`shape.rs:283-294`).
  Not a flag: the transcript order and the wire differ, so the verifier must take the choice from the profile it
  trusts, never from the receipt (the rule B1's candidate follows, patch lines 1375-1377).
- **Off by default and unregistered** until its gates pass, like W16R2 at D59 condition 3: `Shape::build` refuses the
  string at any other geometry; no run profile lists it.
- **App adoption later (Astra's lane; `apps/proven-media/` is not touched by this plan):** a new classify CLI
  profile option beside `--dev-w16r2-public-content-only`, a new pinned prover binary, a new verifier export, then
  the app's qualification run against the separate verifier. The receipt-size field the app reports changes; nothing
  else in the app should.

---

## 8. Measurements before the full build (the spike, WP0)

**What:** one ignored test under the guard, existing functions plus WP2's Γ code, on synthetic data of the real shape
(the vectors are uniform-looking, so real weights add nothing to these timings). About half a day including the
guarded run. Quiet box required; the GPU and the heavy lock held only by this run.

| Measurement | Shape |
|---|---|
| M1. W commit, device and CPU | 96 Fp rows × 2^14 at inv_rate 8, 4 and 2 (`commit_zk_owned_with_tag`; device hook `gpu/mod.rs:903`) |
| M2. the absorb that B6a removes | `absorb_fp2` of 47 vectors of 16,664 Fp2 (12.5 MB) on one thread |
| M3. prover host work | Γ_A, Γ_H (dense and rational), BAT, W's dense FOLD (48 × 16,664), W2 commit (34 Fp rows × 2^10 at rate 1/32) |
| M4. verifier host work | the same Γ and the per-opening T, on one thread |
| M5. receipt bytes | the counted formula for the three profiles (no prover run needed) |

**Pass and kill lines (to be posted before the run, and not moved after it):**
- **Net added GPU time per block (M1 at the chosen rate):** pass ≤ 3.0 ms; kill > 6.0 ms. Basis: the app stream at
  about 54 tok/s is 2.37 s per 128-token request, 91 ms of stream time per block [MEASURED rate,
  `results/zk60_hostw2_app_20261124/README.md` and the coordination entry of 06:20:36Z]; 3 ms is 3.3% if the GPU is
  the limit.
- **Net added host CPU time per block (M3 − M2):** pass ≤ +5 ms; kill > +15 ms (the study's ESTIMATE range is
  −7.5 to +6.5).
- **Between pass and kill on either line:** no decision from the spike; run the end-to-end A/B after WP6 and decide
  there.
- **End-to-end (after WP6, app geometry, eight legs A B B A B A A B as in `w2_ab8`):** pass if the new profile's mean
  rate is at least 97% of W16R2's in the same binary; kill (not adopted in the app) if below 95%; between, the owner
  decides (smaller receipts against a few percent of speed). For the 8B profile, the study's rule: kill above +3% on
  the N = 6 forks phase.
- **Receipt:** measured length must equal the counted length exactly (failing that is a bug, not a trade); pass if
  ≤ 0.55 × today's for the classifier (≤ 368 MB) and the 8B (≤ 450 MB); kill if above 0.60 ×.
- **Verifier:** pass if a whole receipt's verification is at most half of today's on the same box; kill if it is
  slower than today's.

---

## 9. Rulings for the owner

**R1. Which base profile carries B6a first: the installed classifier's W16R2 geometry, or R13?**
Recommendation: **W16R2** (the app's profile; 669.6 → about 333–354 MB, MODEL). Cost: the Lean chain exists only for
R13, so production on this base needs a W16R2 classifier chain plus the B6a re-proof. R13 would reuse the existing
chain but gives less (848 → about 512–533 MB) and the app does not run it. This is the D81 question "which profile a
first product ships", asked again with sizes attached.

**R2. Does B6a wait for W16R3 (B1–B3), or go on today's W16R2 rows?**
Recommendation: **do not wait.** W16R3's freeze is not approved, B1 is a candidate that no longer applies cleanly
(§1.2), and B6a is correct without it at a few ms of verifier time per block (§1.3). If W16R3 lands later, its B1
and B6a combine in a later profile (387 MB 8B model).

Not a ruling needed now, noted for the owner's list: D79's repair A (absorb the classifier's input root separately)
would ride most cheaply in the next classifier profile version, which this one is.

---

## Not read

- The wave-2 branch (agy/host-wave2) and its encoder; the fourth B1 conflict Sol reports on it.
- Sol's isolated trees (`b1/source-perf-forward-3`, the D26 trees) beyond the B1 patch's `zkp-core/src/pcs.rs` hunks
  and its profile lines; Sol's `b1/COORDINATOR_REVIEW.md`.
- FlashProve's tower Lean files and `blocks/` C++ (not in this repository; the study's citations of them are taken as
  given).
- `ZK60_LEAN_L3_FINDINGS_20261104.md` (the zone figures are quoted from the study); `HidingOpeningSum.lean`,
  `HonestShieldZKView/Vis/Prog.lean` beyond their names, `FSOpening.lean` beyond its declaration list.
- The classifier's IN-C / OUT-C stage codecs (`stage_in_c.rs`, `stage_out_c.rs`): their bytes are in the INFERRED
  residual of §2.1 and are left as today.
- The Metal commit kernel's support for inv_rate 8 or 4 (`gpu/metal.rs`): left to the spike.
- A current measured R13 classifier receipt (the 848 MB record is from 2026-10-30) and any measured classifier
  verification time.
- `docs/zkmatrix-poc/START_HERE.md` (not opened; the terms above are defined here instead).
- `ZK60_DECISIONS.md` beyond rows D17, D55 (its first 566 characters only), D59, D63, D67, D78, D79, D80, D80a, D81
  and D82.

## Addendum, 2026-11-24 19:08 UTC (from the builder's soundness note; recorded by the co-coordinator)

Sol's note `results/zk60_sol_20261105_w16r3/b6a/WP_S_SOUNDNESS_20261124.md` (in Sol's working tree when this was
written) refines section 2.3. No figure of this plan is changed here; the size model of section 3 is re-run once the
implemented widths are fixed.

1. **Step 9.** The second batch (the BAT on W2's claims) must include the inner-product claim carried from the first
   fold, with its own coefficient, together with the new generator claims. All of them are linear in the same
   successor message.
2. **Step 8.** The "rest row" of W2 exists only if W's message carries a pad tail. With a plain message of width
   2^14, the reshape into 16 rows of 2^10 uses every coordinate. The degree cap and the sample counts are computed
   from the implemented message width.
3. **Per-round figures at the unique-decoding radius** (the note's table; arithmetic re-checked by the co-coordinator,
   nothing compiled): W at rate 1/8 with 138 samples, 114.55 bits; at rate 1/4 with 169 samples, 114.60; at rate 1/2
   with 280 samples, 116.23; W2 at rate 1/32 with 120 samples, 114.68; each affine fold 111 to 113 bits. The
   Fiat-Shamir translation, the run-level recount and the hiding argument for W are open.
