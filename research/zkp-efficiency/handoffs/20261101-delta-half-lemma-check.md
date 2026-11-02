# Review: the δ/2 column-test lemma for the hiding Ligero PCS (2026-11-01)

Independent cryptography review, requested by the coordinating Claude session, of the lemma proposed in
`handoffs/20261101-gpu-work-per-block.md` (§1, "Soundness arithmetic", and "Recommended next experiment").
**Read-only.** No source edited, no cargo, no git, no benchmark. Two Python scripts in the session scratchpad did
the arithmetic. Every formula they use is written out below, so nothing depends on them.

Labels: **READ** (checked in code or in the paper), **COUNTED** (exact arithmetic on a formula), **ESTIMATE**
(judgement or scaled figure).

## Verdict

**The lemma holds as stated** for every opening that goes through `pcs::verify_zk_tagged`: A, H, the boundaries B_k
and the two endpoints. Per opening, as an interactive bound:

  Pr[the verifier accepts, and the matrix is δ_t-far or a claim is false about the decoded matrix] ≤ (1 − δ_t)^Q + N/|Fp2|,

with δ_t = (1 − ρ)/2, ρ = (n + q_pad)/N and N = nn = n·inv_rate. This is the handoff's (1 − δ/2)^Q + nn/|Fp2|.

The theorem it needs is BCIKS20 **Theorem 3.1** (the interleaved RS test with uniform r), which follows from Theorem 1.7
in the unique-decoding regime. I read its exact text. Every condition holds for this construction as built.

Four refinements. None of them moves a figure by more than 0.02 bit:
1. **The two halves do not add.** The far case and the close case exclude each other, so the bound is the larger of
   the two, not their sum. The claim-batching term 1/|Fp2| is absorbed in N/|Fp2|. No union over the G + 1 checked
   vectors is needed.
2. **The exact integer form is slightly stronger:** (1 − (e + 1)/N)^Q with e = ⌊(N − K)/2⌋. That is 2^-105.946 rather
   than 2^-105.931 at the proposed point.
3. **The 128-bit reduction bias** of the m coefficients multiplies the bound by (1 + p/2^128)^(2m) = 1 + 2^-51.6 at
   m = 2,606 rows. RECOUNT §3's "(1 + 2^-64)" is the figure for one scalar. Either way it is negligible.
4. **It does not cover M**, the CFS mask commitment (`zk::mask_verify_tagged`). M's proximity combination is affine
   (Σ r·row + u, with a fixed Fp2 row u; `zk.rs:585-593`) and has its own verifier. M stays under δ/3 at (3/4)^256 =
   2^-106.25. Its Q is the separate constant `MASK_Q = 256` (`zk.rs:375`), so the proposal does not touch it.

The figures follow.
- **Rate 1/2 at n = 2^14 (T128) needs Q = 260:** 2^-105.93 per opening (2^-105.92 with the field term), against
  today's 2^-105.61 (2^-105.60). Q = 259 gives 2^-105.53, which falls short.
- **Whole run, W16 8B T128 (32 blocks):** 2^-97.27 today, 2^-97.36 at rate 1/2 with Q = 260. It still clears D27's
  ~95 by about 2.4 bits, and LogUp still sets the level.
- **At D27's named workload (8B T512):** the figure is unchanged at 2^-94.66 with Q = 258.

## 1. The construction as built [READ]

| Item | Value | Source |
|---|---|---|
| Field | Goldilocks p = 2^64 − 2^32 + 1; Fp2 = Fp[u]/(u² − 7), \|Fp2\| = p² = 2^127.99999999933 | task statement (I did not re-read `field.rs`); only \|Fp2\| = p² enters the bound |
| Committed matrix | m rows × N columns over Fp, N = n·inv_rate, n = 2^log_cols | `pcs.rs:44-58` |
| Row code | f = f_data + Z_n·g_pad, deg f_data < n, deg g_pad < q_pad, Z_n = X^n − 1. The verifier's encoder maps (msg, pad) ∈ Fp^(n+q_pad) linearly and bijectively onto **all** polynomials of degree < n + q_pad. So the code is exactly RS[D, K], K = n + q_pad | `pcs.rs:557-569`, `:656-677` |
| Domain | D = 7·G_N ⊂ Fp*, N distinct points. 7 generates Fp*, so D is disjoint from G_n. `coset_powers` asserts 7^N ≠ 1 | `pcs.rs:579-584`, `:644-654` |
| Pads | q_pad = Q (`ZkOpts::standard`) on every private-block path: A, H, endpoints, boundaries, D55 forks | `protocol.rs:1585-1586`, `:1986-1987`, `:2140`; `run.rs:1314`, `:1383`; `run_fork.rs:1075` |
| Proximity weights | `prox_rho = tr.challenge_fp2_vec(rows)`: one fresh 32-byte squeeze per row, each half a 128-bit value reduced mod p. All m rows are weighted, mask rows included | `pcs.rs:954`; `transcript.rs:120-133` |
| Group weights | Per group, λ-combinations of the claims' structured row weights. λ is uniform and drawn with prox_rho, before any vector is sent | `pcs.rs:936-957` |
| Order | claims absorbed (by the caller) → λ → prox_rho → G group vectors and the prox vector absorbed (n + Q entries each) → Q indices | `pcs.rs:1016-1029`, `:1193-1211` |
| Indices | Q independent uniform draws with replacement in [0, N), N a power of two (masked u64) | `transcript.rs:136-148` |
| Checks | Per group: ⟨v[..n], c⟩ = Σλ·value. At each sampled column j and for each of the G + 1 vectors: Enc(v)[j] = Σ_i ρ_i·col_i[j]. The verifier re-encodes every vector itself. Merkle path, keyed leaf/node and path length are checked under a tag | `pcs.rs:1183-1258` |

The lemma is a statement about the **verifier** only. How the prover encodes (CPU, Metal, coefficient form) does not
enter it.

## 2. What BCIKS20 says [READ]

Source: the Rutgers copy of the paper, dated July 7, 2020, 47 pages (the URL the handoff cites). The ePrint PDF and
the JACM PDF returned HTTP 403. The ePrint page says the last revision (2021-07-03) adds an appendix fixing a flaw in
the Polishchuk–Spielman lemma derivation and "makes no changes to our main statements". The unique-decoding proof
uses that lemma (Lemma 4.4, §4.3.2).

- **Convention:** RS[F_q, D, k] = polynomials of degree ≤ k on D, |D| = n, **ρ = (k+1)/n**, so ρ is dimension/length.
  For us ρ = K/N = (n + q_pad)/N.
- **Theorem 1.2, unique-decoding part:** affine spaces have a (δ, ε) proximity gap for δ ∈ (0, (1−ρ)/2], with
  **ε_U = n/q** (eq. 1.1). No field-size condition beyond that, and no structure on D: any subset of F_q.
- **Remark 1.5:** z may be drawn from an extension field F_q′, with q replaced by q′ in the error. The decoded
  codewords lie in the base-field code.
- **Theorem 1.6 (curves, i.e. powers of one challenge):** the error is **l·ε**.
- **Theorem 1.7 (affine spaces):** if Pr_{u∈U}[Δ(u, V) ≤ δ] > ε, then u_0..u_l have correlated agreement on a set of
  density ≥ 1 − δ. The error is the **same ε**, independent of the dimension l. In the unique-decoding regime the
  agreement set and the v_i are unique. The proof is in §6.3 (Lemma 6.3 plus the line theorem).
- **Theorem 3.1 (distributed proximity test for interleaved RS codes):** let ρ = (k+1)/n, δ ≤ (1−ρ)/2, u ∈ F_q^(l×n)
  and u′ = rᵀu with **r ∈_R F_q^l**. Soundness: if Δ(u, IRS(V, l)) > δ, then Pr[Δ(u′, V) ≤ δ] ≤ **n/q**.
  This is our test, verbatim.
- **Theorem 4.1:** the unique-decoding line case. It says that if more than n values of z are δ-close, then all are,
  with correlated agreement.
- **Cross-check:** Ben-Sasson, Carmon, Haböck, Kopparty and Saraf (Nov 2025) restate the BCIKS20 result as "up to the
  unique decoding radius, γ < δ/2, proximity gaps hold with a = n [exceptional z's] and proximity loss ε* = 0".

## 3. Conditions, one by one

| Condition | Holds? | Why |
|---|---|---|
| The code is Reed–Solomon | **yes** | The verifier's encoder is a linear bijection onto RS[D, n + q_pad] (`pcs.rs:663-676`). The pads are message symbols, so the code is the full RS code of dimension K, not a subcode |
| D is any set of N distinct field points | **yes** | A coset of G_N in Fp ⊂ Fp2. BCIKS20 needs no subgroup structure |
| Proximity parameter within the unique-decoding regime | **yes, at the edge** | δ_t = (1−ρ)/2 exactly, which the theorem allows (inclusive). e = δ_t·N = (N − K)/2 < d/2 = (N − K + 1)/2 |
| Coefficients uniform and independent over F_q^m (not powers) | **yes** | One `challenge_fp2` per row. Theorem 3.1 / 1.7 apply with ε = N/q. **Load-bearing:** with powers of one challenge, Theorem 1.6 gives (m − 1)·N/q = 2^-101.6 per opening at m = 2,606 and N = 2^15, worse than the column term [COUNTED] |
| Distribution exactly uniform | **within 1 + 2^-51.6** | Each coordinate is a 128-bit value reduced mod p, so its point-probability ratio is ≤ 1 + p/2^128. Over 2m coordinates, (1 + 2^-64)^(2m) ≤ 1 + 2^-51.6. Squeezes are independent under D19's random-oracle assumption |
| Field: entries in Fp, coefficients in Fp2 | **yes** | Apply Theorem 3.1 over F_q = Fp2 directly. A δ_t-far Fp matrix is δ_t-far over Fp2 too: any Fp2 codeword agreeing with an Fp row on ≥ (1 − δ_t)N ≥ K points of D ⊂ Fp interpolates Fp data, so it has Fp coefficients (Remark 1.5). The decoded matrix is in Fp |
| Interleaved codewords (one agreement set for all rows) | **yes** | This is exactly what Theorem 3.1 / 1.7 give (correlated agreement), and what column sampling tests |
| Every row is in the tested combination | **yes** | prox_rho has `rows` entries (`pcs.rs:954`) |
| U is fixed before r | **yes** | The Merkle root precedes the claims, λ and r. A unique U needs the tagged verifier: keyed leaf/node and the path-length check (`pcs.rs:1181-1188`). Untagged `verify_zk` checks no path length (D19 T-1); a new profile must be tagged |
| Indices uniform and independent, drawn after the vectors | **yes** | `transcript.rs:136-148`; `pcs.rs:1204-1211` |
| Hiding pads | **no effect beyond K** | The bound holds for adversarial pads. They only raise K = n + q_pad, which lowers δ_t (the fixed point in §5) |
| Coset domain, interleaving, dimension and length | **yes** | At the proposed point: K = 16,644, N = 32,768, ρ = 0.50793, δ_t = 0.24603, e = 8,062, ε_U = N/p² = 2^-113.00 |

## 4. The statement I stand behind

**Lemma (per opening, interactive).**
- **Setting.**
  - C = RS[Fp2, D, K], with D = 7·G_N ⊂ Fp, K = n + q_pad and q_pad ≥ Q.
  - ρ = K/N, δ_t = (1 − ρ)/2 and e = ⌊(N − K)/2⌋.
  - U ∈ Fp^(m×N) is the matrix the Merkle root binds (tagged profile).
  - The verifier is `pcs::verify_zk_tagged` as in §1: r ∈ Fp2^m uniform; Q independent uniform column indices drawn
    after all G + 1 vectors are absorbed; every vector checked at every sampled column.
- **Case (a), far: Δ(U, C^m) > δ_t.**
  - By Theorem 3.1, Pr_r[Δ(rᵀU, C) ≤ δ_t] ≤ N/|Fp2|.
  - Otherwise every codeword, in particular Enc(prox vector), disagrees with rᵀU on at least e + 1 columns.
  - So all Q columns miss with probability ≤ (1 − (e+1)/N)^Q ≤ (1 − δ_t)^Q.
- **Case (b), close: Δ(U, C^m) ≤ δ_t.**
  - There is a unique interleaved codeword V̂ within δ_t, with message (M̂, P̂) (Theorem 1.7, "furthermore").
  - Suppose some group vector y_g has Enc(y_g) ≠ ρ_gᵀV̂. These are two distinct codewords, so they differ in
    ≥ N − K + 1 positions. ρ_gᵀU differs from ρ_gᵀV̂ only on the ≤ e bad columns. So Enc(y_g) differs from ρ_gᵀU on
    ≥ N − K + 1 − e ≥ e + 1 positions, and the columns miss with probability ≤ (1 − (e+1)/N)^Q.
  - This holds for **any** ρ_g, so the structured group weights need no randomness.
  - Otherwise every y_g = ρ_gᵀ[M̂ | P̂], and a false claim survives the λ batching with probability ≤ 1/|Fp2|.
- **Conclusion.** U decides the case before any challenge. So

  Pr[accept ∧ (U far ∨ some claim false about M̂)] ≤ max((1−δ_t)^Q + N/|Fp2|, (1−δ_t)^Q + 1/|Fp2|) = **(1 − δ_t)^Q + N/|Fp2|**,

  times 1 + 2^-51.6 for the reduction bias.

**What it does not say.**
- It is an interactive bound. Under Fiat–Shamir it is a per-attempt rate, as D27 reads every term (REVIEW_R14 A2).
  The worst round is the column round, at (1 − δ_t)^Q, the same class as today.
- Merkle binding is the hash assumption, as today.
- It says nothing about M.

**Comparison with today's δ/3 accounting.**
- **The consistency half grows.** It was (1 − 2δ/3)^Q, 2^-248 and negligible (RECOUNT §5). Under δ_t it equals the
  proximity half, (1 − δ_t)^Q. The cases are exclusive, so it is not added.
- **The field term grows** from (e_δ/3 + 1)/|Fp2| ≈ 2^-114.0 to N/|Fp2| = 2^-113.0 at rate 1/2, and 2^-112.0 at rate
  1/4. This is the "larger field term" that the obligations doc §4.3 mentions.

## 5. Q tables [COUNTED]

**The formulas.**
- δ/2 rule: per opening = ((N + n + Q)/(2N))^Q + N/p².
- δ/3 rule (today): ((2N + n + Q)/(3N))^Q + (⌊δN/3⌋ + 1)/p², with δ = 1 − (n+Q)/N.
- In both, q_pad = Q, so ρ = (n + Q)/N, and raising Q lowers the distance.

**Minimum Q to match each width's own figure today** (rate 1/4, Q = 256, δ/3). The bits are the column term, with the
column-plus-field total in brackets.

| Row width n | Today, 1/4, Q 256, δ/3 | **δ/2, rate 1/2** | δ/2, rate 1/4 | δ/3, rate 1/2 (for comparison) |
|---|---|---|---|---|
| 2^12 (TinyLlama T32) | 103.69 (103.69) | **Q = 271**: 103.95 (103.95) | Q = 156: 104.07 | Q = 448: 103.85 |
| 2^13 (TinyLlama T64, 8B T32) | 104.97 (104.97) | **Q = 263**: 105.12 (105.11) | Q = 157: 105.59 | Q = 423: 104.99 |
| **2^14 (T128, W16 8B)** | **105.61 (105.60)** | **Q = 260: 105.93 (105.92)**; Q = 259 gives 105.53 | **Q = 157: 106.02 (106.00)** | Q = 413: 105.64 |
| 2^15 (T512, D27 workload) | 105.93 (105.92) | **Q = 258**: 106.10 (106.08) | Q = 157: 106.24 (106.19) | Q = 409: 106.11 |

**Minimum Q for fixed targets** (column + field total):

| Target | n = 2^12 | 2^13 | 2^14 | 2^15 | 2^16 |
|---|---|---|---|---|---|
| ≥ 105.6, rate 1/2, δ/2 | 276 | 265 | **260** | 257 | 256 |
| ≥ 105.6, rate 1/4, δ/2 | 159 | 158 | **157** | 157 | 156 |
| ≥ 106.25 (D15's old figure), rate 1/2, δ/2 | 278 | 266 | 261 | 259 | 258 |
| ≥ 106.25, rate 1/4, δ/2 | 160 | 159 | 158 | 158 | 158 |

**The handoff's arithmetic reproduces exactly:**
- rate 1/2, Q 260: 2^-105.93;
- rate 1/2, Q 413 under δ/3: 2^-105.64;
- T512, Q 258 under δ/2: 2^-106.10; Q 409 under δ/3: 2^-106.11;
- rate 1/4, Q 157: 106.0;
- rate 1/4, Q 256 under δ/2: 2^-172.4 (RECOUNT §1).

## 6. Whole run [COUNTED, except where marked]

**W16 8B T128, 32 blocks, 129 openings.**
- **Regular openings: 97.** A, H, 31 boundaries and 2 endpoints, at the profile's rule.
- **M openings: 32**, at (3/4)^256 = 2^-106.25 under δ/3.
- **PCS field term.**
  - Regular openings: the lemma term ((e+1) under δ/3, N under δ/2), plus the R14 counter's carried ceiling of 4096,
    over p².
  - M: (2·512 + 1 + 4096)/p².
- **LogUp:** 2^-97.92 (`results/zk60_limb16_20261031/REVIEW_W16_20261101.md` §1).
- **Sumcheck and zero-check:** about 2^-111.5. This is an ESTIMATE: REVIEW_R14's 26-block terms, scaled by 32/26.

| Profile | Column / opening | Column term, run | PCS field, run | **Whole run** |
|---|---:|---:|---:|---:|
| Today: 1/4, Q 256, δ/3 | 2^-105.61 | 2^-98.73 | 2^-106.97 | **2^-97.27** |
| **1/2, Q 260, δ/2 (#1)** | 2^-105.93 | 2^-98.99 | 2^-106.17 | **2^-97.36** |
| 1/2, Q 413, δ/3 (#1b) | 2^-105.64 | 2^-98.76 | 2^-107.96 | 2^-97.28 |
| 1/4, Q 157, δ/2 (#6) | 2^-106.02 | 2^-99.07 | 2^-105.28 | 2^-97.38 |
| 1/4, Q 256, δ/2 (accounting change only) | 2^-172.4 | 2^-101.25 (M sets it) | 2^-105.28 | 2^-97.78 |

The handoff's "98.6 → 98.9" charged all 129 openings at the A/H figure. With M at its own 2^-106.25, the column term is
98.73 → 98.99. **Against D27's ~95, #1 clears it by about 2.4 bits.** The run is LogUp-bound: the column change moves
the whole run by +0.1 bit, and even an accounting-only change at rate 1/4 moves it by only +0.5.

**8B T512 (D27's named workload, R13 layout).** These are MEMO_G02 §2's terms (LogUp derived 2^-94.73, sumcheck
2^-112.19). The W16 T512 LogUp has not been counted.
- Today: 2^-94.66.
- Rate 1/2, Q 258, δ/2: 2^-94.66.
- Rate 1/2, Q 260: 2^-94.68.

So the figure is unchanged, and LogUp-bound.

## 7. Zero knowledge and the δ/2 argument

- **The pads.** They interact only through the dimension: K = n + q_pad, so every extra pad lowers δ_t. That is the
  fixed point in §5. The argument assumes nothing about the pads' randomness, and it holds for a prover who picks them
  adversarially. In case (b) the pad half of each clear vector is bound too: Enc is a bijection, so Enc(y) = ρᵀV̂
  forces y = ρᵀ[M̂ | P̂]. The unconstrained pad entries in ⟨v[..n], c⟩ give the prover no freedom.
- **The mask rows and the prox mask row.** They are ordinary rows of U. Soundness neither uses nor needs their
  randomness. The proximity combination must keep weighting every row, mask rows included.
- **Salts.** They do not affect binding.
- **Nothing on the privacy side depends on the soundness regime.** The hiding lemma needs only q_pad ≥ (distinct
  opened columns), Z_n ≠ 0 on the coset and the Vandermonde bijection. The accounting change alone changes no byte and
  no distribution.
- **What does need privacy work** is the geometry that #1 or #6 changes (inv_rate, Q, pads; the coefficient form for
  #1):
  - re-run the joint-view and NL-1 gates on new captures;
  - a privacy statement for the new profile (D33/D36/D58 name their profiles).
- **The coefficient-form variant.** The lemma still applies if the new verifier encoder is an Fp-linear bijection
  Fp^(n+q_pad) → RS[D, n + q_pad]. f = Σ msg_i X^i + Z_n·g_pad is one. Its own review must confirm that, since
  soundness depends only on the verifier's encoder.

## 8. What adopting it needs

**Rulings and accounting documents:**
1. **A new entry in `docs/zkmatrix-poc/ZK60_DECISIONS.md`** (next free number; D59 at the time of writing). It records
   the ruling, signed off by the security owner:
   - the column test of `pcs::verify_zk_tagged` openings is counted at δ_t = (1 − (n + q_pad)/N)/2 by BCIKS20
     Theorem 3.1;
   - the field term is N/|Fp2| per opening;
   - the scope is A, H, B_k and endpoints; **M stays under δ/3**;
   - it applies per profile, bound into the statement, never as a silent re-rating of old receipts;
   - it records the July 2020 / 2021 version caveat.
2. **Amend:**
   - D15 (the clarification text);
   - `docs/zkmatrix-poc/ZK60_FABLE_SECURITY_OBLIGATIONS.md` §4.3 ("not adopted here") and §4.6;
   - `results/zk60_soundness_recount_20261017/RECOUNT.md` §5 and `MEMO_G02.md` §2 and §3.2: add δ/2 rows and the
     §4 statement above;
   - the next D24-class review's assumption list: REVIEW_R14 A3 ("δ/3 proximity regime") becomes A3′ for the new
     profiles;
   - `docs/zkmatrix-poc/MVP_STATUS.md` if a quoted figure moves.
3. **The header comment of `zkp-core/src/pcs.rs:16-19`.** It is already stale (it uses δ = 1 − 1/inv_rate, not the ZK
   code's 1 − (n+Q)/N). Restate it with both regimes. Also update the comments at `hashline/src/zk.rs:23` and
   `:2032`.

**Code (new profiles only; old bytes unchanged):**
4. **New opt-in profile(s)** with inv_rate 2 and opened_cols = q_pad:
   - 260 at log_cols 14; 258 at 15; 263 at 13; 271 at 12 (or 157 at rate 1/4 for #6).
   - `parameter_line` already carries inv_rate and Q (`private_block/protocol.rs:131-135`).
   - The endpoint rate must follow the core rate, or be counted separately. The R14 counter refuses a mixed geometry.
5. **The bit counters take the regime as a profile parameter** (D27: tier levers are profile parameters):
   - `hashline/src/private_block/token_io.rs:276-293`: `column_log2` hard-codes `(1 - delta/3)^q`.
   - The R14 tier counter, `split_security.rs::finish` (`results/zk60_sol_20261031/r14-security-tier/source-tree/hashline/src/private_block/split_security.rs:125-139`):
     - today: column ((2·enc + n + q)/(3·enc))^q, field erasure + 1 with erasure = (enc − (n+q))/3;
     - under δ/2: ((enc + n + q)/(2·enc))^q and enc;
     - the mask term stays ((2·dom + 2·mask_n)/(3·dom))^256.
   - The regime goes into `Params`, the `Claim` header and its digest. That makes it a new claim encoding.
   - The counters should use K = n + q_pad, not n + Q, in case the two are ever split.
6. **Pin the load-bearing invariants with tests or assertions:**
   - the proximity weights are `rows` independent `challenge_fp2` draws, never powers or a tensor (that would cost a
     factor m − 1 under Theorem 1.6);
   - every row is weighted;
   - the indices are drawn after every vector is absorbed;
   - q_pad ≥ Q;
   - the new profile verifies only through `verify_zk_tagged` (the path-length check).
7. **Malicious controls at a toy geometry where the bound is measurable** (for example log_cols 4, Q 4–8):
   - a matrix just beyond e = ⌊(N−K)/2⌋ corrupted columns;
   - a matrix just inside e with a wrong clear vector;
   - a wrong pad half;
   - the empirical acceptance rate over many seeds must sit at or below (1 − (e+1)/N)^Q.

## 9. What I could not verify

- **The paper version.** I read the July 7, 2020 copy (Rutgers mirror). ePrint 2020/654 and the JACM PDF returned
  403, so I could not read the 2021-07-03 revision's Polishchuk–Spielman fix (its abstract page says the main
  statements are unchanged), nor confirm that the theorem numbers (1.2, 1.7, 3.1) are the same in JACM.
- **The whole-run inputs.** The W16 8B T128 sumcheck and zero-check terms are scaled from REVIEW_R14, not counted.
  The W16 T512 LogUp count does not exist.
- **Fiat–Shamir.** The multi-round loss is not quantified anywhere in the project. As today, the figures are
  per-attempt rates.
- **M under δ/2.** I did not check it (an affine Fp2 u row and a different verifier).
- **The rate-1/2 and coefficient-form encoder.** It is not built, so I could not read it. The lemma covers it only if
  §7's bijection condition holds.
- **The proposal's other claims.** The handoff's GPU-time, byte and literature claims (Diamond–Gruen, Crites–Stewart,
  2026/782) are outside this check.
- **No run.** I did not run anything in the repository. Its tests and gates are not evidence here.

## Sources

- **Code:**
  - `ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs` (1-19, 44-58, 557-801, 934-1263);
  - `zkp-core/src/transcript.rs` (101-148);
  - `hashline/src/private_block/protocol.rs` (68-87, 128-140, 1585, 1986, 2036, 2066, 2140-2146);
  - `run.rs` (1314, 1383, 1413, 1445); `run_fork.rs` (1075); `token_io.rs` (255-293);
  - `hashline/src/zk.rs` (1-40, 373-375, 580-600, 614-638);
  - the R14 tier candidate `split_security.rs` (60-147).
- **Accounting:**
  - `docs/zkmatrix-poc/ZK60_DECISIONS.md` D15 (517-576), D24, D27;
  - `ZK60_FABLE_SECURITY_OBLIGATIONS.md` §4.3-4.6, §5;
  - `ZK60_L4_FEWER_HASHED_BYTES_MEMO.md` C.1-C.3;
  - `results/zk60_soundness_recount_20261017/RECOUNT.md` §1-5 and `MEMO_G02.md` §2-3;
  - `results/zk60_d24_review_20261017/REVIEW_R14.md` §3 and `REVIEW_R14_TIER.md`;
  - `results/zk60_limb16_20261031/REVIEW_W16_20261101.md` §1.
- **External:**
  - Ben-Sasson, Carmon, Ishai, Kopparty, Saraf, *Proximity Gaps for Reed–Solomon Codes*,
    https://sites.math.rutgers.edu/~sk1233/GS-FRI.pdf (read: Thms 1.2, 1.4, 1.6, 1.7, 3.1, 4.1, Remark 1.5, §6.3);
    ePrint record https://eprint.iacr.org/2020/654 (revision note only).
  - Ben-Sasson, Carmon, Haböck, Kopparty, Saraf, *On Proximity Gaps for Reed–Solomon Codes* (Nov 2025),
    https://www.math.toronto.edu/swastik/rs-proximity-gaps-2025.pdf (its restatement of the BCIKS20 unique-decoding
    result).
