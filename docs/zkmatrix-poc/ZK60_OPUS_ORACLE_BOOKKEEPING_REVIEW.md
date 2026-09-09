# O10 — the one-oracle bookkeeping, audited against the real hash call formats

Reviewer: Claude Opus 5, independent reviewer, 2026-09-09 (task O10 of
[ZK60_OPUS_QUEUE.md](ZK60_OPUS_QUEUE.md)).
Review baseline: `c5eb2019353fdf56f1a115edb0c424bf86a9c195`.
Sources: `scripts/zk60_endpoint_simulation.py`,
`tests/test_zk60_endpoint_simulation.py`,
`zkp-core/src/{pcs,merkle,transcript,rng}.rs`,
`hashline/src/private_seam.rs`, FA8 §A.2.
Companion: [O9](ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md) specifies the games
this bookkeeping would have to serve.

**Headline: no defect was found in the delivered bookkeeping.** Every
adversarial control written for this audit passes. The findings are about what
the *bound* omits, and about a separation that holds by dimension rather than
by design. Nothing here recovers a private endpoint value.

## 1. The exact call-format inventory

Every unkeyed BLAKE3 call in the commitment, transcript and RNG layers, read at
the baseline. "Tag" means a constant string inside *this* call's input.

| # | Call | Source | Input, in order | Length (bytes) | Tag in this call |
|---|---|---|---|---|---|
| 1 | `Transcript::new(domain)` | `transcript.rs:27` | `"hashline-v1/"` ‖ domain | 12 + \|domain\| = **53** for the IO profile | yes |
| 2 | `Transcript::absorb(label, data)` | `:44` | state(32) ‖ len(label) u64 LE(8) ‖ label ‖ len(data) u64 LE(8) ‖ data | **48 + \|label\| + \|data\|** | no |
| 3 | `Transcript::squeeze_bytes()` | `:85` | state(32) ‖ `"squeeze"`(7) ‖ counter u64 LE(8) | **47**, fixed | yes |
| 4 | `ZkRng::new(seed, domain)` *(fixtures only)* | `rng.rs:20` | `"hashline-zk-rng/"` ‖ domain ‖ seed(8) | 24 + \|domain\| | yes |
| 5 | `ZkRng::from_entropy_reader` | `:44` | **keyed** BLAKE3, key = 32 B `/dev/urandom`; input `"hashline-zk-os-rng/v1/"` ‖ domain | 22 + \|domain\| (63 for `PROFILE`, 50 for the seam `DOMAIN`) | yes, and a different function family |
| 6 | `ZkRng::refill()` | `:53` | key(32) ‖ counter u64 LE(8) | **40**, fixed | no |
| 7 | `pcs::hash_column` / `hash_columns` | `pcs.rs:137` / `:147` | rows × 8 LE bytes of `Fp` | **8 · rows** | no |
| 8 | `pcs::salt_leaf(leaf, salt)` | `:640` | leaf digest(32) ‖ salt(32) | **64** | no |
| 9 | `merkle::hash_pair(a, b)` | `merkle.rs:14` | left digest(32) ‖ right digest(32) | **64** | no |

Rows 1, 3, 4 and 5 are the only calls carrying a constant string. Rows 2, 6, 7,
8 and 9 — the overwhelming majority of queries in a proof — carry none.

### What actually separates the uses

- **8 = 9 exactly.** Both are untagged BLAKE3 on 64 bytes. They are *the same
  oracle point set*. This is a statement about inputs; no collision is searched
  for, and none is needed.
- **7 vs 8/9 is length only.** `8 · rows` equals 64 iff `rows == 8`.
- **7 vs 6 is length only.** `8 · rows` equals 40 iff `rows == 5`.
- **3 is uniquely separated**: 47 is below the 48-byte floor of row 2 and is not
  a multiple of 8, so it cannot be a column hash.
- **2 vs 8/9**: a 64-byte absorb needs `|label| + |data| = 16`. Its bytes 32..40
  are then a small little-endian length, whereas a node's bytes 32..40 are the
  head of a digest, so coincidence costs about `2^-64` — small, but a *bound*,
  not a structural impossibility.
- **2 vs 6**: impossible; absorb inputs are ≥ 48 bytes, refill is 40.
- **5 is genuinely separate**: keyed BLAKE3 is a different function family from
  unkeyed BLAKE3, so it does not share the table at all.

### FA8 §A.2 (H4), disposed

H4 claims the prefixes `hashline-v1/`, `hashline-zk-rng/`,
`hashline-zk-os-rng/v1/`, `hashline-stable-slot-record-v1/` "and the length
framing make the oracle points of the four uses disjoint".

**False as stated, and for a broader reason than salted leaves alone.** Those
prefixes appear only in rows 1, 4 and 5 — the three *initialisation* calls. They
do not appear in `absorb`, `squeeze_bytes`, `refill`, `hash_column`, `salt_leaf`
or `hash_pair`. Domain separation in the running protocol is carried by input
length and structural position, not by tags. Rows 8 and 9 share a domain
outright.

**H3, refined.** FA8 describes the stream as "the keyed XOF of
`ZkRng::from_entropy_reader` … counter-refilled". The key derivation is keyed
(row 5), but the refill that actually produces the stream is *unkeyed* BLAKE3
over `key ‖ counter` (row 6). The stream is still pseudorandom — the 32-byte key
is secret — but its queries live in the **same unkeyed table** as everything
else, at length 40. A reduction may not treat the RNG as an independent oracle.
This is a precision fix, not a break.

## 2. Bookkeeping audit of the candidate

| Obligation | Where | Verdict |
|---|---|---|
| fresh-query programming | `program_fresh` refuses an answered point (`:34`–`:36`) and fixes the width (`:37`–`:38`) | **correct**; no answered query is ever rewritten |
| one shared table | `RandomOracle.table` serves nodes, inner column hashes and salted leaves (`:23`–`:39`, `:101` comment) | **correct**, and it is the right choice given §1 |
| prepared leaf reuse | leaves are fresh handles per `PreparedSimulation` (`:72`); the tree is built before any column is seen (`:72`–`:77`) | **correct**; roots precede column choice |
| duplicate indices | `opened` dict returns the identical column, salt and path (`:92`–`:97`) | **correct** |
| conflicting duplicates | refuses on differing words for one index (`:93`–`:95`) | **correct**, and it burns the owner |
| prequeries | a pre-answered salted-leaf point forces a refusal (delivered test at `:46`) | **correct** |
| owner consumption | `spent` set before validation, "burn on failure too" (`:80`–`:82`) | **correct**; a failed attempt cannot be retried |
| abort visibility | distinct messages for "not issued", "consumed", "duplicate", "already answered" | **correct**, and observable — see O9 F6 |

Two behaviours worth stating explicitly because a bound must account for them,
neither of which is a defect:

- **`verify` is not read-only.** It answers through the same table
  (`:53`–`:63`), so a distinguisher's own verification attempts *consume oracle
  points*. A single forged opening adds thirteen entries (one inner hash, one
  salted leaf, eleven nodes). These count against `q`.
- **A mid-loop refusal keeps earlier programming.** The conflicting-duplicate
  path refuses after some leaves are already programmed, so a refused attempt is
  not a no-op on the oracle.

## 3. The `q / 2^256` bound: what it covers and what it omits

The model document states: if the inner column digest is fixed before the fresh
salt and at most `q` 64-byte inputs are already answered, the new salted-leaf
input is among them with probability at most `q / 2^256`.

**That statement is correct for one leaf.** It is a *local, per-event, per-leaf*
bound. It is not a proof-level or view-level distance, and the document says so.

The gaps between it and a whole-view bound, counted at the real dimensions
(7 rows, `LOG_COLS = 8` so `n = 256`, `INV_RATE = 8` so `nn = 2048`,
`q_pad = num_col_checks = 256`, `MASK_ROWS = 5`, `CHECKS = 256`):

1. **Union over programmed leaves.** 256 per endpoint × 2 endpoints = 512
   programming events per proof, not one. Multiply.
2. **Union over *unopened* leaves.** In the real world all 2048 leaves per
   endpoint are images of `salt_leaf(hash_column(col), salt)`. In the
   simulation only the 256 opened ones are; the other **1792 are free handles
   explained by nothing** (asserted in
   `tests/test_zk60_opus_oracle_bookkeeping.py::UnopenedLeavesAreUnexplained`).
   A distinguisher that guesses an unopened leaf's `(inner, salt)` preimage
   separates the worlds, so the union runs over all 2048 leaves per endpoint,
   not over the 256 programmed ones.
3. **The distinguisher's verification queries** (§2) enter the same table and
   must be inside `q`.
4. **Preparation history.** Points answered *before* `SimPrepare` runs can
   already block a later programming. The tool models the refusal but no bound
   is stated over the pre-preparation history.
5. **The field-reduction bias, which dominates.** Every `Fp` is a 128-bit draw
   reduced mod `p` — `ZkRng::fp` (`rng.rs:73`) and `Transcript::challenge_fp`
   (`transcript.rs:96`), each documented "bias 2^-64"; FA8 §D.4 derives the
   exact figure and this review does not re-derive it. The endpoints alone draw
   `5 · 256 = 1280` mask words plus `7 · 256 = 1792` pads
   (`private_seam.rs:211`–`:212`, `pcs.rs:673`) = **3072 per endpoint, 6144 for the
   pair**, giving a floor of `6144 · 2^-64 ≈ 2^-51.4` before `A`, `H`, `W`, `M`
   and every challenge are counted. For any realistic `q`, this term is larger
   than the hash-programming term by tens of orders of magnitude. **A whole-view
   bound that leads with `q / 2^256` is quoting the wrong dominant term.**
6. **Repetition.** Every count above is per proof; O9 F1 shows repeats must use
   fresh roots, so the union grows with the number of proofs.
7. **The unmodelled couplings** the document already lists: committed
   polynomials, sumcheck distributions, CFS rounds, pads and encoded columns.

## 4. Findings

**F10.1 — domain separation is dimensional, not designed.** Rows 8 and 9 share
a domain; row 7 avoids both only through its length. The current profile's row
counts are 7 (endpoints), 3 (P1 public `W`), 11 (P3 `W`), 20 (`M`), 702 (`A`)
and 1326 (`H`) — none is 5 or 8. A future commitment with **8 rows** would alias
the leaf/node domain, and one with **5 rows** would alias the RNG refill domain.
`column_bytes` pins seven words (`:43`–`:45`), which is what keeps the tool
clear of the degenerate case. Demonstrated by
`DomainSeparationIsDimensional::test_an_eight_word_column_would_alias_a_node_input`,
which builds one 64-byte string reachable both as an eight-word column encoding
and as a node input. This needs no format change and does not affect frozen
proofs; it is a constraint any completed reduction must carry, and an argument
for an explicit tag if the format is ever revised.

**F10.2 — the RNG stream shares the unkeyed table** (row 6). H3's "keyed XOF"
wording covers the key derivation, not the refill.

**F10.3 — the unopened leaves are the larger half of the union** (§3.2): 1792 of
2048 per endpoint, versus the 256 the tool counts in `programmed`.

**F10.4 — the reduction bias dominates the stated bound** (§3.5), with a counted
floor of `2^-51.4` from the endpoints alone.

**F10.5 — verification is oracle-consuming** (§2), so `q` must include the
distinguisher's own checking.

**F10.6 — index coverage.** The delivered suite opens only indices below 241
(`experiment()` uses `(i·37) mod 241`; the test suite uses `i mod 128`), so the
top three of the eleven path levels are never exercised on both sides. Closed
here by `HighIndexPaths`, which opens 2047, 2046, 1024 and 1023 and tampers with a
level-10 sibling. Both pass — this was a coverage gap, not a bug.

## 5. What real BLAKE3 still forbids

The candidate programs salted-leaf answers. Real BLAKE3 cannot be programmed, so
this tool produces nothing a real verifier accepts, and it says so
(`root_only_simulation: false`, `actual_blake3_programmed: false`,
`columns_sampled_from_PCS_distribution: false` in its own output). Combined with
O9's Game E, the position is: the ideal-oracle bookkeeping is consistent, and it
is not yet connected to any statement about the deployed hash.

## 6. Proposed fixes, not applied

Codex owns the implementation; these are proposals only.

1. Record in the tool's output the **union sizes** a bound must range over
   (2048 leaves per endpoint, 512 programmed points, the verification queries),
   so no later reader mistakes `programmed = 512` for the union.
2. State the bound as `Δ_hash + Δ_reduction` with the counted draw totals, and
   lead with the dominant term.
3. Add the high-index openings to the delivered suite (or import the controls
   added here) so the top path levels stay covered.
4. If the commitment format is ever revised, give rows 7, 8 and 9 distinct
   one-byte tags. This is cheap at revision time and removes F10.1 permanently.
   It must not be retrofitted into the frozen proofs.

## 7. Validation

Nine independent controls in
[`tests/test_zk60_opus_oracle_bookkeeping.py`](../../tests/test_zk60_opus_oracle_bookkeeping.py)
pass, alongside the eight delivered tests. The candidate tool runs clean. No
production Rust, transcript, proof format, privacy mode or benchmark parameter
was changed, and `scripts/zk60_endpoint_simulation.py` was not edited. Commands,
exits and SHA-256 digests are in
[`results/zk60_opus_oracle_bookkeeping_review.json`](../../results/zk60_opus_oracle_bookkeeping_review.json).
