# Literature parameter check — arithmetisation-oriented hash functions

Independent adversarial verification of hash-function parameters against
authoritative public sources (IACR ePrint papers, reference implementations).
Compiled 2026-09-19. Every figure below is either quoted from a named public
source or computed here; nothing is from memory.

Primary sources used (all public):

| Ref | Source |
| --- | --- |
| P2 | Poseidon2, Grassi/Khovratovich/Schofnegger, <https://eprint.iacr.org/2023/323> |
| RPO | Rescue-Prime Optimized, Ashur/Al Kindi/Meier/Szepieniec/Threadbare, <https://eprint.iacr.org/2022/1577> |
| MON | Monolith, Grassi/Khovratovich/Rechberger/Roy/Schofnegger, <https://eprint.iacr.org/2023/1025> |
| TIP5 | The Tip5 Hash Function for Recursive STARKs, Szepieniec/Lenngren et al., <https://eprint.iacr.org/2023/107> |
| P3 | Plonky3, <https://github.com/Plonky3/Plonky3> |
| HL | Horizen Labs poseidon2, <https://github.com/HorizenLabs/poseidon2> |

Arithmetic script: `sbox_gcd.py` in this directory; its full output is
reproduced in the appendix at the end of this file.

---

## Item 1 — Poseidon2 at Goldilocks, width 12

### 1(a) Round numbers R_F / R_P

- **CLAIM:** R_F = 8 full rounds and R_P = 22 partial rounds for a 64-bit
  Goldilocks-like field at state width 12.
- **STATUS: CONFIRMED** (four independent sources agree).
- **FIGURE:** R_F = 8, R_P = 22.
- **URL:** <https://eprint.iacr.org/2023/323>
- **QUOTE / LOCATION:** P2 §6, page 16, "Table 1: Some instantiations for
  Poseidon2π, where n = ⌈log2(p)⌉." The table columns are `(n, t, d) | RF | RP`
  and the rows read verbatim:

  ```
  (31, 16, 5)  8 14
  (31, 24, 5)  8 22
  (64,  8, 7)  8 22
  (64, 12, 7)  8 22
  (256, 2, 5)  8 56
  (256, 3, 5)  8 56
  ```

  The row `(64, 12, 7) 8 22` is exactly the Goldilocks width-12 case
  (n = 64 bits, t = 12, d = 7).

- **Corroboration 1 (P3):** `Plonky3/goldilocks/src/poseidon2.rs` —
  `pub const GOLDILOCKS_POSEIDON2_HALF_FULL_ROUNDS: usize = 4;` (so R_F = 8,
  four initial + four final) and
  `pub const GOLDILOCKS_POSEIDON2_PARTIAL_ROUNDS_12: usize = 22;`
  (also `_8 = 22` and `_16 = 22`).
  <https://github.com/Plonky3/Plonky3/blob/main/goldilocks/src/poseidon2.rs>
- **Corroboration 2 (HL):**
  `plain_implementations/src/poseidon2/poseidon2_instance_goldilocks.rs` —
  `Poseidon2Params::new(12, 7, 8, 22, &MAT_DIAG12_M_1, &MAT_INTERNAL12, &RC12)`
  i.e. (t, d, R_F, R_P) = (12, 7, 8, 22).
- **Corroboration 3 (MON):** Appendix D.2, "The Poseidon2 function (as well as
  Poseidon which has the same number of rounds and the same arithmetization)
  with t = 12 defined for p_Goldilocks has 8 full and 22 partial rounds".

**Security level.** P2 does not annotate Table 1 with a per-row κ. The rounds
come from P2 Eq. (1), stated for "a security level of κ bits with
2^80 ≤ 2^κ ≤ min{2^256, p^(t/3)}". Independent corroboration that these are the
128-bit numbers: MON Table 1 lists Monolith-64 at "Security 128" and MON
App. D.2 compares it against exactly this Poseidon2 t=12 / 8+22 instance;
RPO Table 1 fixes λ = 128 for the same field at m = 12.

*Minor caveat found while checking:* re-deriving Eq. (1) without its Gröbner
term, `ceil(1.075·(min(κ,log2 p)/log2 d + log_d t − 5))`, gives **21**, not 22,
for (64, 12, 7) — and is likewise low for every other Table 1 row (see the
appendix). So the published R_P values are set by the `R_GB` (Gröbner basis)
branch of the max, not by the first branch. This is consistent, not a defect,
but anyone re-deriving the round count from the first term alone will get 21
and should not conclude the table is wrong.

### 1(b) S-box count per permutation

- **CLAIM:** "8 full + 22 partial at width 12 gives 118 S-boxes per
  permutation", i.e. 8·12 + 22 = 118.
- **STATUS: CONFIRMED** — both the arithmetic and the round numbers.
- **FIGURE:** 118 S-box evaluations (equivalently 118 degree-7 constraints,
  118 witness values) per permutation.
- **Arithmetic:** computed in `sbox_gcd.py`: `8*12 + 22 = 118`. Correct.
- **Model check:** the claim's stated model (a full round applies the S-box to
  all t elements, a partial round to exactly one, so the count is R_F·t + R_P)
  is the correct description of Poseidon2. P2 §3.2 defines the external (full)
  round E and internal (partial) round I with exactly this structure.
- **Independent corroboration of the number 118 itself (MON):** Table 4,
  page 29, "Plonkish arithmetization comparison for various 64-bit schemes.
  The numbers are for a single permutation." — the row
  `Poseidon/Poseidon2(sponge) | 0 lookups | 118 nonlinear constraints |
  degree 7 | witness size 118 | area-degree product 826`.
  And App. D.2: "...has 8 full and 22 partial rounds, thus **118 degree-7
  functions in total**."
- **URL:** <https://eprint.iacr.org/2023/1025>

### 1(c) S-box degree for Goldilocks p = 2^64 − 2^32 + 1

- **CLAIM:** which of x^3 / x^5 / x^7?
- **STATUS: CONFIRMED — x^7.**
- **FIGURE:** d = 7.
- **URL:** <https://github.com/Plonky3/Plonky3/blob/main/goldilocks/src/poseidon1.rs>
- **QUOTE:** `pub const GOLDILOCKS_S_BOX_DEGREE: u64 = 7;` with the doc comment
  "The S-box raises each element to this power. The Goldilocks prime factors as
  `p - 1 = 2^32 * 3 * 5 * 17 * 257 * 65537`. Neither 3 nor 5 are coprime to
  `p - 1`, so the smallest valid exponent is 7."
  (This factorisation is reproduced independently in 1(d) below and matches.)
- **P2 corroboration:** Table 1 rows `(64, 8, 7)` and `(64, 12, 7)` — the third
  tuple entry is d.

Actual implementation parameters, **both widths as requested**:

| Source | Width t | S-box degree D | R_F | R_P |
| --- | --- | --- | --- | --- |
| Plonky3 `goldilocks` | 8 | 7 | 8 | 22 |
| Plonky3 `goldilocks` | 12 | 7 | 8 | 22 |
| Plonky3 `goldilocks` | 16 | 7 | 8 | 22 |
| Plonky3 `goldilocks` | 20 | 7 | 8 | (not read) |
| HorizenLabs poseidon2 | 8 | 7 | 8 | 22 |
| HorizenLabs poseidon2 | 12 | 7 | 8 | 22 |
| HorizenLabs poseidon2 | 16 | 7 | 8 | 22 |
| HorizenLabs poseidon2 | 20 | 7 | 8 | 22 |

Note R_P = 22 is used at **every** Goldilocks width in both implementations —
it does not vary with t in the range 8..20.

### 1(d) Is x^7 a permutation of the Goldilocks field?

- **CLAIM:** gcd(7, p−1) = 1 for p = 2^64 − 2^32 + 1.
- **STATUS: CONFIRMED** by own computation (`sbox_gcd.py`).
- **ARITHMETIC (computed, not quoted):**
  - p = 18446744069414584321
  - p − 1 = 2^64 − 2^32 = 18446744069414584320 = 2^32 · (2^32 − 1)
  - 2^32 − 1 = 4294967295 = 3 · 5 · 17 · 257 · 65537 (the five Fermat primes
    F0..F4) — reconstruction verified equal.
  - Full factorisation: **p − 1 = 2^32 · 3 · 5 · 17 · 257 · 65537** —
    reconstruction verified equal to p − 1.
  - **gcd(3, p−1) = 3** → x^3 is NOT a permutation.
  - **gcd(5, p−1) = 5** → x^5 is NOT a permutation.
  - **gcd(7, p−1) = 1** → **x^7 IS a permutation.**
  - (also gcd(2, p−1) = 2; gcd(11, p−1) = 1; gcd(13, p−1) = 1)
- This is why Goldilocks designs use d = 7 and not the cheaper d = 3 or d = 5:
  7 is the smallest exponent coprime to p − 1.
- **Cross-check:** the Plonky3 source comment quoted in 1(c) states the same
  factorisation and the same conclusion, independently.

---

## Item 2 — Sponge security bound

- **CLAIM:** for a width-t permutation over a ~64-bit field with capacity c and
  rate r = t − c, the standard claimed collision resistance is c·64/2 bits.
- **STATUS: CONFIRMED**, with the caveats stated below.
- **FIGURE:** κ = c · log2(p) / 2 bits, i.e. for log2(p) = 64: **c·64/2**.
  Capacity 4 → 128 bits; capacity 6 → 192 bits.
- **URL:** <https://eprint.iacr.org/2023/323>
- **QUOTE:** P2 §2, "Sponge Hash Functions ... Security. As proven in [15], if
  the inner permutation resembles a random one, the sponge construction is
  indifferentiable from a random oracle up to around p^(c/2) queries.
  Equivalently, in order to provide κ bits of security, p^(c/2) ≥ 2^κ."
  Reference [15] there is the Bertoni–Daemen–Peeters–Van Assche
  indifferentiability result, i.e. the flat sponge claim.
- **Caveats (important, and the claim as phrased omits them):**
  1. The bound is conditional on the permutation behaving like a random one —
     it is an indifferentiability statement about the *mode*, and says nothing
     about the permutation's own algebraic security. Item 6 is where the
     permutation's margin is assessed.
  2. It is an upper bound on the *mode*; the achieved security is
     min(capacity bound, digest-length bound). A capacity of 4 Goldilocks
     elements buys 128 bits only if the digest is also ≥ 256 bits
     (= 4 field elements).
  3. P2 additionally bounds the usable κ by `2^κ ≤ min{2^256, p^(t/3)}`.

**What the designers actually claim at width 12 / capacity 4 over Goldilocks:**

| Design | Params | Claimed level | Location |
| --- | --- | --- | --- |
| Rescue-Prime Optimized | m = 12, r = 8, c = 4 | **λ = 128** | RPO Table 1 (quoted in item 3) |
| Monolith-64 (sponge) | t = 12, c = 4, r = 8 | **128** | MON Table 1, "Security" column = 128 |
| Tip5 | m = 16, r = 10, c = 6 | — (see item 5) | TIP5 Table 1 |

Monolith states the rule it used verbatim (§4, "Sponge-Based Schemes"): "As we
uniformly suggest a security level close to 128 bits, we set c = ⌊256/ρ⌋ and
r = 2c." For ρ = log2(p) = 64 that gives c = 4 and r = 8 — which is precisely
the c·64/2 = 128 formula solved for c.

I did **not** find a Plonky3 document making its own numeric security claim for
width 12 / capacity 4; Plonky3 ships the permutation, and the sponge-level
claim in that ecosystem traces back to the papers above. Treat "Plonky3 claims
128 bits" as unsourced.

---

## Item 3 — Rescue-Prime / Rescue-Prime Optimized

- **URL:** <https://eprint.iacr.org/2022/1577>
- **QUOTE:** RPO page 2, "Table 1: Integer parameters for the two instances of
  Rescue-Prime Optimized" — verbatim rows (two columns = the two instances):

  ```
  prime field modulus p   2^64 - 2^32 + 1   2^64 - 2^32 + 1
  security level λ        128               160
  round number N          7                 7
  state size m            12                16
  rate r                  8                 10
  capacity c              4                 6
  ```

  And §2.1: "this choice for p fixes α and α^-1 ... Specifically, **α = 7** and
  α^-1 = 10540996611094048183".

- **STATUS of round count and alpha: CONFIRMED.** N = 7, α = 7, α^-1 = x^(1/7).
  For Goldilocks width 12 the instance is λ = 128, r = 8, c = 4.
- RPO §4.2 explains N = 7 is a deliberate reduction: "the formula gives rise to
  a recommended number of rounds of N = ⌈1.5 · 5⌉ = 8. Setting instead N = 7
  constitutes a 12.5% reduction in the number of rounds." **Note this**: RPO
  ships with 7 rounds where its own design formula says 8. The margin is
  12.5% smaller than the Marvellous strategy nominally prescribes.

### Total S-box evaluations per permutation

- Rescue does apply the S-box to the **full state in both half-rounds**, so the
  raw evaluation count is 2·N·t.
- **FIGURE (raw evaluations):** 2·7·12 = **168** per permutation for RPO at
  m = 12 (or 2·8·12 = 192 if N = 8).

### The "≈ 42 committed values per absorbed field element" claim

- **STATUS: CONTRADICTED.**
- **FIGURE:** the published arithmetisation cost is **96 degree-7 constraints
  and witness size 96 per permutation**, i.e. **12.0 committed values per
  absorbed field element** at rate 8 — not 42.
- **URL:** <https://eprint.iacr.org/2023/1025>
- **QUOTE (MON App. D.2):** "Regarding Rescue-Prime, an instance with t = 12
  defined for p_Goldilocks requires 8 rounds which each consist of two
  subrounds which alternate between nonlinear layers featuring the x^d and
  x^(1/d) power maps. Due to this construction **one can find degree-7
  constraints spanning a whole round of rescue, leading to 96 degree-7
  constraints in total**."
  MON Table 4 row: `Rescue-Prime (sponge) | 0 | 96 | 7 | 96 | 672`.
- **Why the claim is wrong:** it costs 2 committed values per raw S-box
  evaluation (2 · 168 / 8 = 42). Both halves of that are wrong. Rescue's
  two-subround structure collapses into **one** degree-7 constraint per state
  element per *round* (N·t = 84 at N=7, 96 at N=8), not 2·N·t, because the
  x^(1/7) half is verified rather than evaluated. Even the most pessimistic
  honest reading — one committed value per raw S-box evaluation — gives
  168/8 = 21. The correct figure is **12** (MON's accounting) and the claim is
  roughly **3.5× too high**.

---

## Item 4 — Monolith (Monolith-64, Goldilocks)

- **URL:** <https://eprint.iacr.org/2023/1025>
- **QUOTE (MON Table 1, page 17):** "Table 1. Parameters for Monolith." with
  columns `Name | p | Security | Rounds R | Width t (2-to-1, Sponge) | # Bar u`:

  ```
  Monolith-64   2^64 - 2^32 + 1   128   6    8   12   4
  Monolith-31   2^31 - 1          124   6   16   24   8
  ```

- **STATUS of rounds: CONFIRMED. R = 6.** MON §1 explains the choice: "initial
  analysis has found a 3-round attack on a weakened version, and also suggests
  that all potential attacks should stop at 4 rounds. Since improvements are
  expected, we set the number of rounds uniformly to 6."
- **Width:** t = 8 for 2-to-1 compression, **t = 12 for sponge**. Sponge rate
  r = 8, capacity c = 4 (from c = ⌊256/64⌋ = 4, r = 2c — quoted in item 2).

### The Bars / lookup layer

- **QUOTE (MON §4.3):** "Bars for Monolith-64. In Eq. (8) we set t ∈ {8, 12}
  (compression or sponge, resp.) and we set **u = 4** (i.e., 4 Bar operations
  are applied in each round). Operations D and C. We use a **decomposition into
  8-bit values** such that x = 2^56 x'_8 + 2^48 x'_7 + ... + 2^8 x'_2 + x'_1."
- So: **4 Bars per round × 6 rounds = 24 Bar operations per permutation**, and
  each Bar decomposes a 64-bit element into **8 bytes**, each byte passed
  through an 8-bit S-box table. **Table size = 2^8 = 256 entries.**
- **Total: 24 × 8 = 192 8-bit lookups per permutation.** MON Table 4 confirms
  this number directly: `Monolith-64-sponge | 192 lookups | 64 | 2 | 480 | 960`.

### The "≈ 24 lookups / 38 committed values per absorbed field element" claim

- **Lookups — STATUS: CONFIRMED.** 192 lookups per permutation ÷ rate 8 =
  **24.0 lookups per absorbed field element.** Exact.
  (Caveat on units: this counts *8-bit table lookups*. If "lookup" meant a Bar
  operation the figure would be 3, not 24. The claim's 24 is right under the
  byte-lookup reading, which is the one MON Table 4 uses.)
- **Committed values — STATUS: CONTRADICTED.** MON Table 4 gives witness size
  **480** per permutation for Monolith-64-sponge; ÷ rate 8 = **60.0 committed
  values per absorbed field element**, not 38.
- **Where the 38 comes from:** 38 is **Tip5's** figure (witness 380 ÷ rate 10 =
  38.0 exactly — see item 5). The claim appears to have transposed Tip5's
  committed-value count onto Monolith. Monolith's true cost is ~1.6× higher.
- **Cross-check on 480:** MON §D.1 gives the count as "6 · (2us + u) + 5t + u
  ... where {u = 4, s = 8} for the p_Goldilocks case". Evaluating: 6·(64+4) +
  60 + 4 = **472**, while Table 4 prints 480 (and 452 vs 460 for t = 8). Both
  rows are 8 higher than the stated formula. A minor internal inconsistency in
  MON; it does not change the verdict (472/8 = 59.0, still not 38).

---

## Item 5 — Tip5

- **URL:** <https://eprint.iacr.org/2023/107>
- **QUOTE (TIP5 Table 1, "Summary of parameters"), verbatim:**

  ```
  field modulus                      p  2^64 - 2^32 + 1
  number of rounds                   N  5
  state size                         m  16
  sponge rate                        r  10
  sponge capacity                    c  6
  digest length                      d  5
  power map exponent                 α  7
  number of split-and-lookups/round  s  4
  ```

  And §2.1: "Tip5 is a sponge construction instantiated with a permutation
  f : F_p^m → F_p^m and a state of m = 16 field elements. In every iteration of
  the absorbing phase, r = 10 field elements are read from the input and
  replace the first r elements of the state."

### Rate and capacity — the claim's assumption is wrong

- **STATUS: CONTRADICTED.** Tip5 is **width 16, rate 10, capacity 6** — not
  width 12 / rate 8 / capacity 4. Its sponge capacity buys 6·64/2 = 192 bits by
  the item-2 formula, though the digest is only d = 5 elements (320 bits).
- The width-12 variant does exist but it is **not Tip5**: MON §8 calls it
  "Tip4′, a faster instance of Tip5 with a fixed state size t = 12". If a
  width-12 Tip-family permutation was intended, the correct name and numbers
  are Tip4′, whose Table 4 row is `Tip4' | 160 | 40 | 7 | 360 | 2520`
  (= 20 lookups / 45 committed values per absorbed element at rate 8).

### Round structure and S-box counts

- **QUOTE (TIP5 §2.2):** the split-and-lookup S-box is
  `S : F_p → F_p, x ↦ R^-1 · ρ ∘ L^8 ∘ σ(R · x)` where
  "σ : F_p → F_p^8, x ↦ (a,b,c,d,e,f,g,h) where all outputs are at most 8 bits
  wide" and "L : F_p → F_p is defined only for field elements that are at most
  8 bits wide ... the lookup table L computes L : F_257 → F_257,
  x ↦ (x+1)^3 − 1". So one split-and-lookup = **8 byte-lookups**, table over
  F_257 (258 entries; 256 used).
- **QUOTE (MON App. D.2, independent count):** "The Tip5 function applies four
  64-bit S-boxes with lookups per round, so **32 8-bit lookups per round**. It
  also uses **12 degree-7 power functions per round**. We allocate variables
  for the outputs of the power functions in addition to 64 lookup variables
  per round."
- Per permutation: **160 8-bit lookups** (32 × 5) and **60 x^7 power S-boxes**
  (12 × 5). Per round the S-box layer is 4 split-and-lookup + 12 power maps
  = 16 = m. Confirmed by MON Table 4: `Tip5 | 160 | 60 | 7 | 380 | 2660`.

### The "≈ 16 lookups / 30 committed values per absorbed element" claim

- **Lookups — STATUS: CONFIRMED.** 160 ÷ 10 = **16.0 per absorbed element**.
  Exact. (But note this is only right *because* the rate is 10. If one assumed
  rate 8, as the claim apparently does elsewhere, the same 160 lookups give 20
  per element. The claim gets the right answer from the wrong rate only by
  coincidence of also having the wrong lookup total in mind.)
- **Committed values — STATUS: CONTRADICTED.** MON Table 4 witness size is
  **380** per permutation; ÷ 10 = **38.0 committed values per absorbed
  element**, not 30.
- **Reconstruction (verified in `sbox_gcd.py`):** per round, 4 split-and-lookup
  S-boxes × 8 bytes × 2 variables each = 64 lookup variables, plus 12 power-map
  outputs = 76 variables/round; × 5 rounds = 380. Matches Table 4 exactly.
  TIP5 §5.7 confirms the two-variables-per-lookup accounting: "The above
  analysis assigns two variables to every split-and-lookup gate."

### Summary table for items 3-5 (all per absorbed field element)

| Design | t | r | Lookups | Committed values | Claim checked | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| Poseidon/Poseidon2 | 12 | 8 | 0 | 14.75 | 118 S-box/perm | CONFIRMED |
| Rescue-Prime | 12 | 8 | 0 | **12.0** | "≈42" | CONTRADICTED (3.5× high) |
| Monolith-64 sponge | 12 | 8 | **24.0** | **60.0** | "≈24 / 38" | lookups CONFIRMED, committed CONTRADICTED |
| Tip5 | **16** | **10** | **16.0** | **38.0** | "≈16 / 30" | lookups CONFIRMED, committed CONTRADICTED; width/rate/capacity also wrong |
| Tip4′ | 12 | 8 | 20.0 | 45.0 | — | (the actual width-12 Tip variant) |

All derived from MON Table 4 (per-permutation figures) divided by the rate.

---

## Item 6 — Cryptanalysis 2024-2026

**Bottom line: I found nothing that breaks Poseidon2 at Goldilocks width 12
with R_F = 8 / R_P = 22, and no published recommendation from anyone to
increase Poseidon or Poseidon2 round numbers.** But two things below are worth
knowing before relying on those parameters, and one of them is a material
ecosystem signal.

### 6.1 Ethereum Foundation Poseidon Cryptanalysis Initiative

- **URL:** <https://www.poseidon-initiative.info/>
- Launched November 2024. Runs bounties on deliberately **round-reduced**
  challenge instances with low security targets (24-40 bits), not on deployed
  parameters.
- **Solved challenges, as listed on the site (verbatim parameters and dates):**

  | Programme | Instance | Params | Status |
  | --- | --- | --- | --- |
  | 2025 bounty | Poseidon-256 24-bit | RF=6, RP=8 | claimed 9 Dec 2024 |
  | 2025 bounty | Poseidon-256 28-bit | RF=6, RP=9 | claimed 31 Dec 2024 |
  | 2025 bounty | Poseidon-64 24-bit | RF=6, RP=7 | claimed 23 Apr 2025 |
  | 2025 bounty | Poseidon-64 28-bit | RF=6, RP=8 | claimed 27 Apr 2025 |
  | 2025 bounty | Poseidon-64 32-bit | RF=6, RP=10 | claimed 24 May 2025 |
  | 2025 bounty | Poseidon-31 40-bit | RF=6, RP=4 | claimed 5 Nov 2025 |
  | 2026 bounty | CICO problem | RF=6, RP=6 / 8 / 10 | verified 10 Apr / 6 May / 6 Jul 2026 |
  | 2026 bounty | Zero-test problem | RF=6, RP=7 … 12 | all solved Jun-Jul 2026 |

- **Deepest reach against Poseidon over a 64-bit field: RF = 6, RP = 12**
  (zero-test, July 2026). Against R_F = 8 / R_P = 22 that leaves a margin of
  2 full rounds and 10 partial rounds. Substantial, but the partial-round
  margin has been eroding steadily through 2025-2026 (RP 7 → 12 in about two
  months of the zero-test programme).
- **Poseidon1 collision prize:** the q = 3 tier (a three-element partial
  collision against the full-round Poseidon1 compression function) was
  "Claimed on April 6th 2026". The programme is marked "PAUSED STARTING
  1 AUG 2026 AoE".
- **The site issues no round-number recommendation and states no conclusion
  that existing parameters are adequate.** It frames everything as ongoing
  research: the stated aim is to "boost the security investigation" and
  "eventually decide whether there is sufficient evidence". Anyone citing the
  initiative as an endorsement of the current round numbers would be
  over-reading it.

### 6.2 Published algebraic attacks

| Paper | URL | Date | What it does | Affects R_F=8/R_P=22 at Goldilocks t=12? |
| --- | --- | --- | --- | --- |
| Ashur, Buschman, Mahzoun — "Algebraic Cryptanalysis of HADES Design Strategy: Application to POSEIDON and Poseidon2" | <https://eprint.iacr.org/2023/537> | Apr 2023, rev. Nov 2023 | Shows the HADES Gröbner-basis security argument is optimistic: "the complexity of a Gröbner basis attack for an instance of Poseidon with 1024 bits of security is 731.77 bits and the original security argument starts failing already at the 384-bit security level." | **No.** Failures are at ≥384-bit security levels; 128-bit/64-bit-field instances are not shown affected. Paper notes "the results were shared with the designers and the security arguments were updated accordingly." |
| Sanso, Vitto — "Attacking Poseidon via Graeffe-Based Root-Finding over NTT-Friendly Fields" | <https://eprint.iacr.org/2025/937> | 2025 | Graeffe-transform interpolation attacks on the challenges | No break of full parameters |
| Zhao, Ding — "Breaking Poseidon Challenges with Graeffe Transforms and Complexity Analysis by FFT Lower Bounds" | <https://eprint.iacr.org/2025/950> | 2025 | ~2^13 wall-time improvement on challenge solving | No. Authors report **memory access is the binding barrier**, "which makes the security margin much larger than expected" |
| Zhao, Sanso, Vitto, Ding — "Graeffe-Based Attacks on Poseidon and NTT Lower Bounds" (CRYPTO 2026) | <https://eprint.iacr.org/2025/1916> | 2025/2026 | Journal/conference version of the above | No |
| **Merz, Rodríguez García — "Skipping Class: Algebraic Attacks exploiting weak matrices and operation modes of Poseidon2(b)"** | <https://eprint.iacr.org/2026/306> | **18 Feb 2026** | **The most serious item found.** New algebraic attacks exploiting "the specific structure of the matrices that define the linear layers", improving round-skipping for CICO and — for the first time — making preimage finding easier than CICO, plus "the first algebraic collision attack that outperforms its algebraic preimage counterpart". Improves on state-of-the-art algebraic collision attacks "for one recommended 128-bit parameter set ... by a factor of 2^106". | **Authors say no:** "due to the algebraic security margin this does not mean the primitive falls short of its claimed security level." They "discuss how our attacks can be mitigated without affecting the efficiency of Poseidon2(b)". **COULD NOT VERIFY from the abstract whether the "recommended 128-bit parameter set" attacked is the Goldilocks t=12 one.** A 2^106 improvement against a *recommended* set is a large bite out of margin and this paper should be read in full before leaning on Poseidon2's margin. |
| Grassi et al. — "Poseidon and Neptune: Gröbner Basis Cryptanalysis Exploiting Subspace Trails" | <https://eprint.iacr.org/2025/954> | 2025 | Further Gröbner work | Not assessed |
| "A Better Bivariate Resultant Attack on Round-Reduced Poseidon" | <https://eprint.iacr.org/2026/1905> | 2026 | Round-reduced only | No |
| "From Round Skipping to S-Box Skipping" | <https://eprint.iacr.org/2026/1692> | 2026 | Not assessed | Not assessed |
| "Claiming bounties on small scale Poseidon and Poseidon2 instances using resultant-based algebraic attacks" | <https://eprint.iacr.org/2026/150> | 2026 | Small-scale challenge instances | No |

**No paper found recommends increasing R_F or R_P for any deployed instance.**
The one paper that found the original security *argument* wanting (2023/537)
led to the argument being updated, not the rounds.

### 6.3 Ethereum Foundation withdrew Poseidon from the L1 roadmap (Aug 2026)

- **STATUS: CONFIRMED that this happened; it is NOT a cryptanalytic break.**
- **Date:** 13-14 August 2026. Announced by Justin Drake (Ethereum Foundation),
  who described it as "the end of an eight-year, eight-figure rabbit hole" and
  said Ethereum was "abandoning Poseidon for Ethereum's layer 1 and pivoting to
  SHA or BLAKE".
- **URL:** <https://postquantum.com/security-pqc/ethereum-roadmap-drops-poseidon/>
  (secondary reporting; also covered by cryptobriefing, crypto.news, zkm.io)
- **Stated reason — performance convergence, not a break.** Drake's framing:
  "the key was not SNARK-friendly hashes but hash-friendly SNARKs". The
  reporting is explicit that **"No breaks of deployed parameter sets
  occurred."** Standard hashes became competitive in modern proof systems while
  carrying none of the open questions of a young algebraic hash, and SHA-256 /
  BLAKE3 are easier to argue about post-quantum.
- **Relevance:** this does not invalidate any parameter above. It does mean the
  largest single funder of Poseidon cryptanalysis has stopped planning to
  depend on it, so the rate of future scrutiny — and the argument "it is
  heavily analysed because Ethereum depends on it" — should be discounted
  going forward.
- I read this only through secondary reporting; I did not locate Drake's
  original post. Treat the exact wording as second-hand.

---

## Item 7 — SHA-256 / BLAKE3 arithmetisation cost (sanity check)

### 7.1 Lookup/row count per SHA-256 compression — PARTIALLY VERIFIED

- **STATUS: CONFIRMED at medium confidence** (official project documentation,
  but a single implementation and I did not read the source to double-check).
- **FIGURE:** in the Zcash halo2 `table16` SHA-256 gadget, a 16-bit
  spread-table Plonkish arithmetisation:
  - **24 lookups per compression round** (Ch: 8, Maj: 4, Σ0: 6, Σ1: 6)
  - 24 rows per round → **1792 rows for all of "step 3"** (the 64 rounds)
  - message scheduling: 547 rows; step-4 reductions: 16 rows
  - **total ≈ 2099 rows per SHA-256 compression**
  - table: "one table spread, with 2^16 rows and 3 columns" plus a tag column
  - → roughly **1536 lookups per compression** (24 × 64), excluding message
    scheduling.
- **URL:** <https://zcash.github.io/halo2/design/gadgets/sha256/table16.html>
- **LOCATION:** "Compression" / per-gate cost breakdown section.
- **Caveat:** this is a 16-bit spread table, not the byte-decomposed form named
  in the question. I did **not** find an authoritative figure for a specifically
  *byte*-decomposed SHA-256 AIR. For BLAKE3 I found **no** per-compression
  lookup/constraint figure at all — **COULD NOT VERIFY**.

### 7.2 Modern proving throughput for standard hashes — CONFIRMED

Useful as an order-of-magnitude anchor, and it is the technical basis for 6.3.

- **STATUS: CONFIRMED.**
- **FIGURE:** on a single Apple M4 Max core: **BLAKE3 ≈ 82,000 compressions/s,
  SHA-256 ≈ 42,000 compressions/s, Keccak ≈ 30,000 permutations/s**; about
  **250× overhead relative to native execution**. On ten cores, SHA-256 proving
  is ">9× faster than Binius64" and ">500× faster than the fastest elliptic
  curve-based SNARK tested".
- **URL:** <https://eprint.iacr.org/2026/1329>
- **QUOTE / LOCATION:** "Flock: Fast Proving for Batch Boolean Computations",
  Benedikt Bünz (NYU, Espresso Systems), Ron Rothblum (Succinct), William Wang
  (NYU); received 28 June 2026, revised 19 September 2026. Abstract: "For many
  applications of SNARKs, a key bottleneck is proving large batches of standard
  cryptographic hash evaluations, such as SHA-256, Keccak, or BLAKE3. We
  introduce Flock, a hash-based SNARK for extremely fast proving of such
  batched Boolean computations."

---

## Appendix — full output of `sbox_gcd.py`

```
p      = 2^64 - 2^32 + 1 = 18446744069414584321
p - 1  = 2^64 - 2^32     = 18446744069414584320
p - 1  = 2^32 * (2^32 - 1) ? True
2^32 - 1 = 4294967295 = 3*5*17*257*65537 = 4294967295 -> True
factorisation of p-1: 2^32 * 3 * 5 * 17 * 257 * 65537 = 18446744069414584320 -> True

gcd( 2, p-1) =     2   -> x^2 is NOT a permutation of GF(p)
gcd( 3, p-1) =     3   -> x^3 is NOT a permutation of GF(p)
gcd( 5, p-1) =     5   -> x^5 is NOT a permutation of GF(p)
gcd( 7, p-1) =     1   -> x^7 is A PERMUTATION of GF(p)
gcd(11, p-1) =     1   -> x^11 is A PERMUTATION of GF(p)
gcd(13, p-1) =     1   -> x^13 is A PERMUTATION of GF(p)

Poseidon2 S-box-count arithmetic (R_F full rounds hit all t elements, R_P partial rounds hit 1):
  t=12 R_F=8 R_P=22: 8*12 + 22 = 118 S-boxes/permutation
  t= 8 R_F=8 R_P=22: 8*8 + 22 = 86 S-boxes/permutation
  t=12 R_F=8 R_P=21: 8*12 + 21 = 117 S-boxes/permutation
  t=16 R_F=8 R_P=22: 8*16 + 22 = 150 S-boxes/permutation
  t=12 R_F=8 R_P=13: 8*12 + 13 = 109 S-boxes/permutation
  t=12 R_F=8 R_P=14: 8*12 + 14 = 110 S-boxes/permutation
  t= 8 R_F=8 R_P=13: 8*8 + 13 = 77 S-boxes/permutation

Rescue-Prime style RAW S-box evaluations (S-box on the FULL state in BOTH half-rounds: 2*N*t):
  t=12 N=7: 2*7*12 = 168 S-box evals/permutation
  t=12 N=8: 2*8*12 = 192 S-box evals/permutation
  t=16 N=7: 2*7*16 = 224 S-box evals/permutation
  t=16 N=8: 2*8*16 = 256 S-box evals/permutation
  t=12 N=9: 2*9*12 = 216 S-box evals/permutation
  NB: the ARITHMETISATION is cheaper -- Monolith App. D.2 reports a
  degree-7 constraint spanning a WHOLE Rescue round, so N*t, not 2*N*t.
  t=12 N=7: 7*12 = 84 degree-7 constraints/permutation
  t=12 N=8: 8*12 = 96 degree-7 constraints/permutation

Sponge security from the flat-sponge / indifferentiability bound p^(c/2) >= 2^kappa, i.e. kappa = c*log2(p)/2, for log2(p)=64:
  capacity c=4: 4*64/2 = 128 bits
  capacity c=6: 6*64/2 = 192 bits
  capacity c=8: 8*64/2 = 256 bits

Per-absorbed-field-element cost, from Monolith (eprint 2023/1025) Table 4 (per permutation) divided by the sponge rate r:
  Monolith-64-sponge  (t=12): 192 lookups /8 =  24.0   witness 480/8 = 60.00 committed values per element
  Tip5                (t=16): 160 lookups /10 =  16.0   witness 380/10 = 38.00 committed values per element
  Tip4'               (t=12): 160 lookups /8 =  20.0   witness 360/8 = 45.00 committed values per element
  Poseidon/Poseidon2  (t=12):   0 lookups /8 =   0.0   witness 118/8 = 14.75 committed values per element
  Rescue-Prime        (t=12):   0 lookups /8 =   0.0   witness  96/8 = 12.00 committed values per element

Reconstruction of the Table-4 witness sizes from Monolith App. D.2:
  Tip5: per round 4 split-and-lookup S-boxes * 8 bytes * 2 vars = 64 lookup vars, + 12 power-map outputs = 76; * 5 rounds = 380
  Monolith-64 formula 6*(2us+u) + 5t + u with u=4, s=8:
    t= 8: 452 (Table 4 prints 460 -- 8 higher)
    t=12: 472 (Table 4 prints 480 -- 8 higher)
  Poseidon2 t=12: 8*12 + 22 = 118 degree-7 S-boxes, one witness each
  Rescue-Prime t=12, N=8: 8*12 = 96 degree-7 constraints

Poseidon2 Eq.(1) round formula, ignoring the R_GB term:
  R_P >= ceil(1.075 * (min(kappa,log2 p)/log2(d) + log_d(t) - 5))
  (n= 64, t= 8, d=7): 20.281 -> ceil 21   paper Table 1 R_P = 22  <- formula alone is LOWER; the R_GB term dominates
  (n= 64, t=12, d=7): 20.505 -> ceil 21   paper Table 1 R_P = 22  <- formula alone is LOWER; the R_GB term dominates
  (n= 31, t=16, d=5): 10.829 -> ceil 11   paper Table 1 R_P = 14  <- formula alone is LOWER; the R_GB term dominates
  (n= 31, t=24, d=5): 11.100 -> ceil 12   paper Table 1 R_P = 22  <- formula alone is LOWER; the R_GB term dominates
  (n=256, t= 2, d=5): 54.349 -> ceil 55   paper Table 1 R_P = 56  <- formula alone is LOWER; the R_GB term dominates
  (n=256, t= 3, d=5): 54.620 -> ceil 55   paper Table 1 R_P = 56  <- formula alone is LOWER; the R_GB term dominates
```

---

## What I could not establish

1. **Whether the "recommended 128-bit parameter set" attacked in eprint
   2026/306 (2^106 collision-attack improvement) is the Goldilocks t=12 set.**
   I read only the abstract. This is the single most important open question
   in this review and warrants reading the full paper.
2. **A published figure for "committed values per absorbed field element"**
   as a named metric — no paper uses that term. Every committed-value number
   above is Monolith Table 4's *witness size* divided by the sponge rate.
   A different AIR/witness layout will give different numbers; these are
   Monolith's deliberately non-optimised accounting, and MON itself warns
   "we do not apply any constraint or witness optimization" and "these numbers
   are derived from non-optimized arithmetizations and are subject to change".
3. **Any Plonky3 document claiming a specific sponge security level** for
   width 12 / capacity 4. Plonky3 ships the permutation; the 128-bit claim
   traces to RPO and Monolith, not to Plonky3.
4. **Per-compression lookup/constraint counts for BLAKE3** in any lookup-based
   AIR — nothing found.
5. **A byte-decomposed (as opposed to 16-bit-spread) SHA-256 AIR cost** —
   nothing found; the halo2 figure in 7.1 is a 16-bit table.
6. **Justin Drake's original August 2026 announcement** — read only through
   secondary reporting.
7. The **8-value discrepancy** between Monolith's witness-size formula
   (§D.1) and its Table 4 — unresolved, immaterial to the verdicts.
