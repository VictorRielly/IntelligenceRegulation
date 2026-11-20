# Research handoff: committing small values compactly, and what it would do to 43.2 GB of codewords (2026-11-16, claude-cycle 6b)

From Claude, the standing researcher (D50). Part B of a three-part session (6a lookups, 6b packing, 6c linear chains).

**Scope.**
- **Web reading plus local counting.** 8 searches, 5 fetches in this part (the FHE-conference slide deck came back as binary and
  was not read; two FlashProve documents were summarised by the fetch tool, not read verbatim). No build, prover run, GPU run,
  Git write. Written: this file, `20261116-claude-cycle6b-small-value-packing.py` (standard library, reads no file) and a STATE.md entry.
- **Triage material, not a work order.** Every option below changes what is committed and the verifier, so it needs the owner's
  ruling, a new profile string and re-proved Lean. None is a privacy acceptance. Cycle 3's H134(a) asked whether packing is worth
  a test; this note answers it on paper and mostly says no for a prime-field code.

Labels: **COUNTED** (cycle 4 census), **[AUTHORS]** (a source's own claim), **[abstract]** / **[summary]** (read only an abstract or
a third-party summary), **DERIVED** (script or argument here), **ASSUMED**.

## 0. Headline

- **No published mechanism packs several small values into one prime-field word of a Merkle/Reed-Solomon commitment and still
  lets later constraints use the values separately.** The packing results I found are **algebraic embeddings in extensions of a
  small base field** (Diamond-Posen ring-switching; Blaze's binary-field codes). They save bytes because the values live in a
  small *field*. Goldilocks has no small subfield: a 16-bit integer is a full 64-bit field element. [DERIVED from the
  abstracts; the ring-switching abstract: "no embedding overhead: each input costs the same as a large-field commitment of the
  same bit size", which holds when the base field is the small one.]
- **A one-line argument why prime-field packing does not work by itself** [DERIVED]: commit `W = sum_s 2^(16s) V_s`. An opening of
  `W~` at a point gives one linear combination of `k` unknown values `V_s~(r)`. The sumchecks and lookups need each `V_s~(r)`.
  Binding them requires either the `V_s` committed (no saving) or an unpacking relation, which is not low-degree (a bit-field
  extraction). Packing for the linear ops fails too: a 16-bit activation times an 8-bit weight summed over 4,096 terms is a 36-bit
  accumulator, so two packed lanes overlap in a 64-bit word.
- **What does save bytes, and the ceiling** (script, DERIVED; today's 43.19 GB of codewords):

| Option | Codeword bytes per request | Share of today | Status |
|---|---:|---:|---|
| B1b: ideal 4x packing of the small rows, proof free (UPPER BOUND, no mechanism) | 28.6 GB | 66% | not available |
| B2: 31-bit prime base field with a degree-4 extension (the parked H116 rebase) | 32.2 GB | 74.5% | engineering exists in other stacks; large rewrite |
| B3: binary-tower symbols (GF(2^16) for 16-bit values) | 26.7 GB | 62% | breaks exact integer arithmetic; ZK unpublished (below) |
| **With Part A's G2 (helpers retired):** B1b / B2 / B3 | 7.5 / 11.1 / 5.6 GB | 17 / 26 / 13% | combined ceiling |

  The census explains the ceiling: small values are 2,279 of 5,103 rows (44.7%); the 2,514 helper rows are full-field (Fp2) and the
  310 mask rows are uniform field elements. Neither can be packed. **Packing alone cannot get below 62-66%; with helpers retired
  the combination reaches 17% (4x ideal) or 26% (31-bit base), which is about 0.8-1.4x the plain int8 bytes** (plain
  int8 7.9-9.0 GB; G2 + B1b = 7.5 GB, G2 + B2 = 11.1 GB).

## 1. The sources, per option

| Option | Bytes saved on small values | Effect on opened-column masking (ZK) | Prover cost | Maturity (as read) |
|---|---|---|---|---|
| **FRI-Binius / ring-switching** (Diamond-Posen, ePrint 2024/504; packed variant) | up to the bit width: 1 bit per bit for F_2 values; 16-bit values in GF(2^16) symbols = 4x fewer bytes than a 64-bit word | **no zero-knowledge statement** in the abstract; I found no ZK variant of FRI-Binius (a search for one found only Haboeck-Kindi's masking note for FRI STARKs, ePrint 2024/1037, and a data-availability use that wraps a ZK proof around row proofs, ePrint 2025/2292) | additions are XORs; multiplications costlier; **integer** arithmetic needs bit-level carry constraints | paper [abstract]; Python reference `binius-models`, Apache-2.0 [search result]; the production Rust library's licence **not confirmed here** |
| **Blaze** (Zeilberger-Fisch-Chen-Resch-Rothblum-Brehm, ePrint 2024/1609, EUROCRYPT 2025) | binary-field symbols, as above | none stated; its prime-field extension (ePrint 2026/524, 2.6x proof-size gain from improved RAA distance bounds [summary]) and a related NUS paper (2026/487, 127-bit Mersenne, no ZK or hashing discussed, cycle literature scan R3) are likewise silent | commit about 8n XORs plus one Merkle tree [AUTHORS, summary]; proof generation about 6n additions and 5n multiplications | paper; an implementation exists per the literature scan, not licence-checked |
| **Ligerito** (ePrint 2025/1187) | 32-bit binary field symbols | **no ZK found** (cycle 3) | 1.3 s at 2^24 on an M1 [AUTHORS] | paper plus a crate, per cycle 3 |
| **Basefold over Goldilocks / BabyBear** | none for small values: a small value is a full field element | as the base scheme | as the base scheme | prime-field Basefold exists [summary of a Jolt note]; no byte gain |
| **Small prime base field + extension (31-bit)** | 2x on every base-field row (4 B symbols) | pads stay one per opened column, uniform in the smaller alphabet; hiding is not weakened by the field size, soundness terms are | narrower multiplies, costlier extension multiplies (degree 4) | in production zkVMs; **our H116: x1.2-1.5, parked, "high cost" (20261101-logup-gkr-w16.md)**; planes such as the norm's squared row sums and the 36-bit accumulators exceed 2^31 so exactness needs new arguments |
| **Curve-based small-value commitments** (Jolt line: "commit cost depends on scalar size") | none in bytes: a commitment is one group element | n/a | MSM cost falls with scalar bits | not our PCS |
| **Ligero-style codes over small alphabets** | alphabet must be at least the codeword length (2^15 here), so 16-bit symbols are the floor | per-row pads Q = 280, unchanged | additive FFT over small fields | **no scheme found** for 16-bit values over a small-field code with extension challenges |
| **Lattice / ring commitments, SmallWood, Longfellow** | packing small values into ring elements is their native mode (a 2026 conference deck on packing small elements into one ring element with virtual oracles and a range proof surfaced) | not read | not read | **not read**; the deck was unreadable |

**Soundness cautions for any small-field code** (both found this session, read as abstracts or summaries):
- Fenzi-Sanso, ePrint 2025/2197, "Small-field hash-based SNARGs are less sound than conjectured" [abstract read]: for extension codes
  over a small base field, classical list-size lower bounds enable strong attacks **in the parameter regimes used in practice**.
- Dao-Kominers-Thaler-Zheng (2026) [summary]: beyond-Johnson proximity gaps fail over binary fields; for domains above 2^20 a
  single beyond-Johnson check over a 128-bit challenge field cannot give even 90 bits.
- The project's about-100-bit target must therefore be argued in the unique-decoding regime on any small-field code; this removes
  conjectured slack that the current Goldilocks stack may not need.

**FlashProve** (the closest published system: Goldilocks per its architecture page, hash-based, hidden weights and intermediates)
describes weights as "small signed digits" in a matrix, each row with random mask elements, Reed-Solomon encoded, salted Merkle leaves
per column [fetch-tool summary of `docs/architecture.md` and `docs/protocol.md`]. **Neither page says whether several digits share a
field element**, nor the committed table's size against its 4-bit raw size (400.7 billion weights, about 200 GB at 4 bits per cycle 2),
so I cannot say whether the best published system packs. This is the one fact worth settling: read its `blocks/README.md` or the
source of `cp_commit`. If it packs digits into Goldilocks words with a range proof, that is a mechanism this note says I could not find.

## 2. Effect on opened-column masking and receipt bytes (DERIVED)

- The ZK mask of a code row is the 280 random pad symbols inside each coset-code row (`pcs.rs:674-693`, cycle 4). The pad count is set by
  the number of opened columns Q = 280, not by the field or the packing: info-theoretic hiding of Q opened positions needs Q
  uniform pads in the code's alphabet.
- If packing made a row hold `k` times as many values at the same 2^14 symbols, pad share is unchanged (1.7%) and rows fall by `k`.
  If the row keeps the same number of values and shrinks to 2^14/k symbols, the pad share rises to 3.4% (k = 2) and 6.8% (k = 4) of the
  message, and each opened column still holds 280 symbols per row. The row count matters because the **opened column data is
  Q x rows x symbol bytes** (372 MB per request today, 280 x 164,548 x 8 B); it scales with the same shares as the table above.
- The mask rows (310 per block) and helpers do not shrink with packing, so the receipt's opened-column bytes cannot fall below
  about their share (55% of rows) from packing alone.

## 3. Candidates, each with a falsifiable test

- **H138: re-count which small rows could live in a 31-bit base field (the H116 gate, as a count).**
  - *Test.* On a captured W16R2 block (no new proof), compute the maximum absolute value of every committed A plane and every integer
    relation the zero-checks assert (including accumulator-to-remainder identities and the norm's sum of squares). **Kill** if
    more than 5% of the 2,279 small rows (114 rows) or any asserted relation exceeds 2^31 in integer value, because exactness
    then needs new range arguments.
  - *Expected effect.* (i) codewords **-25.5% (to 32.2 GB)**; (ii) tokens/s **x1.0-1.2** [ASSUMED from H116's parked x1.2-1.5, which
    also credits cheaper multiplies]; adds the Fenzi-Sanso soundness work and a full-stack field rewrite. **Rank low.**
- **H139: a proof-of-packing mechanism for prime-field RS codes.**
  - *Test.* Paper-level. A construction in which `k` small values in one Goldilocks word are consumed by sumchecks and
    lookups without a separate commitment, with a stated hiding argument. **My negative (one linear combination of `k` unknowns) is
    falsified by any such citation.** Cheapest check: FlashProve's source (above).
  - *Expected effect if it exists.* (i) up to **-34% alone, -83% with Part A's G2**; (ii) unknown, probably x1.0-1.1 on the 5090 (host-bound,
    cycle 3) up to x1.3-1.8 on the Mac's GPU-bound path [ESTIMATE from cycle 3's H134].
- **Dropped:** binary-tower and Binius-family commitments for this stack (exact-integer matmul and the Lean statements are
  integer-modular; the literature scan's R3 reached the same verdict), and curve-based small-scalar commitments.

## 4. Corrections and cautions

- Cycle 3's H134(a) said "an 8x cut on the activation planes if the checks hold". This note finds that the 8x is not available on a
  prime-field code and that the 4x of cycle 4's table is an upper bound with no mechanism behind it.
- The 62-66% ceilings assume the helper and mask rows are untouched; both are, by the derivation above.
- Ring-switching's "no embedding overhead" is quoted from its abstract page; I did not read the paper's cost tables.
- I did not read Binius, Blaze, Ligerito, SmallWood or Longfellow beyond abstracts and search summaries.

## 5. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains
  **unachieved**. Hypotheses: 139 (H138, H139 added). Search and fetch count this part: 8 searches, 5 fetches (cumulative after 6b: 17 searches, 19 fetches).
- Pointer posted to `ops/zkp-mvp/RECOVERY_COORDINATION.md`.

## 6. Next concrete actions (no new permission needed to prepare)

1. Read FlashProve's commit code or `blocks/README.md` for how a digit sits in a field element (settles H139's mechanism question).
2. H138's count needs a captured block and the existing witness code; it can wait for a quiet box and does not need a prover run.
3. Fold these ceilings into cycle 4's scenario table: with helpers retired, volume reaches about 0.8-1.4x plain int8 bytes only if the small rows also shrink.
