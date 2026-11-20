# Research handoff: what FlashProve commits per activation, and its range test (2026-11-16, claude tick 3)

From Claude, the background researcher (D50). Queue item 1.

**Scope.**
- Web reading only, plus arithmetic in one `python3 -c` call. **0 searches, 13 fetches** (one HTTP 404, one directory listing, so about one over the
  brief's 12-read budget). No build, prover run, GPU run or Git write.
- **Read in full text:** the paper PDF (I decompressed its text streams with a short script kept outside the repository; spaces are lost and
  tables are flattened, so every number below was re-read against its sentence; equations and figures not read): Definition 4.8, Table 2, Construction D.6,
  Remark G.2, Table 15. **Read through the fetch tool's summarizer (its wording, not verbatim):** the repository's `docs/format/11-1-machinery.md`
  (first 100,000 of 112,280 characters), `11-2-feed-forward-segment.md`, `11-3-attention-segment.md`, `08-parameters.md`, `docs/protocol.md`. The remaining 12k
  characters of 11-1 and `11-4`, `11-5` are unread.
- Builds on `20261116-claude-cycle2-flashprove-batching.md` (batching) and `20261116-claude-cycle4-committed-volume-census.md` (our census).
- **Triage material, not a work order.** Anything here that changes what is committed alters proof bytes and the verifier and needs the owner's
  ruling, a new profile string and re-proved Lean (D17, D63). The owner shelved size work on 2026-11-09; this is about committed volume and prover speed.

Labels: **[AUTHORS]** (source's number or statement), **COUNTED** (our file:line, from cycle 4), **DERIVED** (my arithmetic), **ASSUMED**.

## 0. Headline

- **FlashProve commits no helper columns for lookups.** Its Lookup is a product-tree argument (the claim is
  Prod_i($ - key_i) = Prod_j($ - table_j)^mu_j, reduced along two product trees by masked sumchecks to claims on the keys and on the bits of mu)
  [AUTHORS, paper Construction D.6]. The only committed lookup data are the multiplicities, **as 32 bit-planes per table entry** (`b` matrix) [AUTHORS, 11-2/11-3].
  This is the "G1/G2" shape of cycle 6a, in a hash-based, hiding-intermediates, Lean-checked-ZK system, and it is open source.
  **Correction to tick 1:** tick 1 found "no published ZK LogUp-GKR for hidden-activation transformers". FlashProve's lookup is not LogUp (it is the product form) and
  hides weights, not prompt and reply, but its intermediates are hidden and its masked sumchecks carry a machine-checked zero-knowledge theorem for one request
  per proof (cycle 2 §4). It is the closest published analogue and was not read in tick 1.
- **Its cells are packed three per field word** (radix 2^20, relaxed bound |cell| < 2^18) [AUTHORS, 11-1].
- **Its range check is two things.** (a) A *smallness test*: random combinations of each cell row with entries in {-1, 0, 1}, whose values (not the cells) are
  split into two digits (10 + 8 bits) and looked up; it only prevents wraparound modulo p. (b) Exact ranges (requantization remainders etc.) go through ordinary lookups
  with 2^8 and 2^16 tables whose keys are polynomials of committed cells, so they add **no committed words per lookup**.
- **Committed volume per token per layer, against ours:** about **0.14 to 0.25 M message words** against our **0.653 M** (cycle 4), i.e. **2.6x to 4.6x fewer**
  [DERIVED, §3; the range is wide because I could not pin the layer grouping]. Their cell count is close to ours; the saving is packing plus no helper planes.

## 1. How it range-checks and packs [AUTHORS, `11-1-machinery.md`, paper Table 2 and Construction D.6]

- **Packing:** "three cell rows 3i, 3i+1, 3i+2 of a column are one element of F, with the radix 2^20." Cells sit in a signed 20-bit slot; a request is accepted only for cells below the
  relaxed bound 2^18 (paper Def. 4.8).
- **Smallness test.** V samples a matrix Theta of ternary entries (0 w.p. 1/2, +1 and -1 w.p. 1/4 each; Table 2: 128 columns at the default), one combination per Theta column
  over the *columns* of each cell matrix. P commits, for each combination and each cell row, the value plus 2^17 as two digits (10-bit and 8-bit), checked by two lookups
  with 2^10 and 2^8 tables. Committed: `ZZ`, "tau rows and 2 mz columns over F", mz being the total number of cell rows in the segment's list; `BZ`, "32 rows and 2^11 columns".
  Parameter file: tau is 32 to 256 in steps of 32; verifier rejects unless each matrix has 1 to 8191 columns and fewer than 256 matrices.
- **Why 2^18 versus 2^17 (my reading, DERIVED, consistent with their "share 2^-128" in Table 10):** if a cell has |y| >= 2^18, then for each combination either
  the partial sum s is outside [-2^17, 2^17) (caught at entry 0) or it is inside and both s+y and s-y are outside (caught at +1 and -1). Every column catches with
  probability >= 1/2, so 128 columns give 2^-128. Their programs' own union bound over the tested matrix's columns is only **113.44 bits** (paper Remark G.2, Table 15), which they
  state misses their 128-bit target; "about 122" bits with a list factor. For our ~100-bit budget that union bound would need tau >= 115, so 128.
- **Completeness cost.** An honest combination must land inside +-2^17, so honest cells must be small against the column count. The paper proves completeness error <= 2^-40 for served requests. Our 24-bit product limbs
  and 16-bit windows would not all fit; int8-scale activations would.
- **Digit volume:** 2 * tau * mz words per segment. At the documentation's example (mz = 499,712 cell rows in group 0, tau = 128) that is **127.9 M words per segment** [DERIVED from
  11-2's example], about **125 k words per token** at a 1,024-token window per segment, falling as segments hold more layers. The saving per cell is (columns per row)/(2 tau);
  with few layers per segment the test costs about as much as the cells.

## 2. What it commits [AUTHORS, 11-2 and 11-3]

Per segment (a group of Lam layers): feed-forward cells `af` (gate, silu, up and their remainders, norm, requantization and residual remainders, attention-weight
and projection remainders), `ad` (norms), `ar` (router), `b` (multiplicity bits), `qa` (q, k, v, o, each in two limbs), `xbO` (residual stream, one array leaving; `xbI` only in group 0);
attention cells `as` (five cells per score pair: low and high byte of the remainder, a flag, two for the weight; only the causal half plus block-diagonal region),
`ah` (per head and token: max 4 cells, denominator 4 cells, bits of the max's index), `ao` (two rounding remainders per feature). The accumulators of products are not committed.
Per token, as formulas: `af` = 6 Lam f + (8 + flags) Lam d + 2 Lam (H+G) dh + 2 Lam G dh + ...; `qa` = 4 Lam (H+G) dh; `as` about 5 Lam H (T/2 + Bt); `ao` = 2 Lam H dh [AUTHORS].

## 3. Against our census (DERIVED; assumptions stated)

Dimensions from the paper (Construction D.3): d = 5120, 40 query and 8 KV heads, dh = 128, dense f = 16,384, expert width 8,192. Window T = 1,024. The flags in the formulas
(`hgD`, `huD`, `ho`, ...) are 0 or 1 and I could not read them; Bt unknown (tried 0 to 128); layer grouping Lam unknown.

| Item per token per layer (dense layer) | Value | How |
|---|---:|---|
| Cells, FF and norm and projections | 153.6 k + 20.5 k + 24.6 k | formulas of 11-2 with flags 0 |
| Cells, attention (`as`, `ah`, `ao`) | 113 k to 139 k | 11-3, Bt 0 to 128 |
| **Cells, total** | **312 k to 338 k** | sum |
| Packed 3 per word | 104 k to 113 k words | / 3 |
| Smallness digits `ZZ` | 16 k to 125 k | 127.9 M / 1,024 / Lam, Lam 8 to 1 |
| Multiplicity bits `b` (NC = 8, 2^16 tables) | up to 16 k | 8 * 2^21 / 1,024 |
| **Message words, total** | **about 0.14 M to 0.25 M** | sum, before masks |

- **Ours, per token per block (cycle 4, COUNTED):** 653 k words: A words and limbs 289 k, H helpers 322 k, masks 40 k. So **2.6x to 4.6x** more than FlashProve's estimate. (Their MoE layers use 8,192-wide routed experts; I treated the layers as dense, so ±15%.)
- **The cell counts agree:** their 312 k to 338 k cells against our 289 k A values (words plus limbs) per token. The gap is therefore **packing (3 per word) plus no helper planes**, which is
  cycle 4's scenario "helpers not committed and A packed" (809 rows = 104 k words per token per block, 15.9% of today). FlashProve's 104 k to 113 k packed cells match that count closely; its extras
  (digits, multiplicity bits) are what the scenario ignored.
- **Not compared: codeword bytes.** Table 2's rate 0.1041 and 62 to 64 opened columns are the weight table's code; the trace groups use their own codes, and I did not find their rate.
  Do not multiply our 2x expansion in.
- **Price they pay that we would too:** multiplicities in bits cost 32 words per table entry (2^21 words per call at 2^16) against LogUp's one; ours (15 A rows of 2^14 = 0.25 M words per block) would grow to up to ~16.8 M per segment of NC = 8 tables, so
  it only pays when a segment spans many layers.

## 4. Falsifiable tests in this project's terms

- **H145 (pack three small cells per word).** Already H134(a), now with an existing system's radix 2^20 slot and a proof relaxed bound as precedent. Test (count): among A rows, those with honest
  |value| < 2^17/(sqrt(columns) scale) after masking; **kill if fewer than 40% of A rows qualify** (cycle 4 found 44.7% packable). Needs the owner's ruling and Lean.
- **H146 (smallness test where a lookup exists only to prevent wraparound).** Count the local range lookups whose sole role is a magnitude bound, not an exact remainder window; they are the only ones it could replace.
  **Kill if they are under 10% of the 2,162 range-helper rows**, or if columns per cell row are under 2 tau = 256 (digits then exceed cells). Effect: removes only those helper rows. I expect it to be small, because our 16-bit windows are exactness checks.
- **H147 (reconcile with the local GKR design).** Read 11-1's remaining text and the product-tree lookup against the local masked LogUp-GKR note; **kill the local blinding-leaf design in favour of
  FlashProve's committed-mask sumcheck if its mask words per lookup tree exceed ours (2,148 Fp2 per block)**, or adopt it if below.

## 5. Honest expected effect

- **Committed words per request:** with helpers removed and 3-per-word packing, about 0.14 to 0.25 M per token per block against 0.653 M: **-62% to -78%** as an upper bound if every FlashProve technique transferred. Our requantization exactness lookups stay.
- **Proved tokens per second:** volume was 1.2 to 2.5% of the measured Mac request (cycle 4 §4), so volume alone gives little; the lookup tree and mask costs are new work. **No number I can support above x1.07 to x1.25** (6a).
- Two caveats on transfer: FlashProve hides the weights and the intermediates but its prompt and reply are public; our P1 hides inputs, outputs and activations, so the embedding and head stages and token handling differ.

## 6. Risks and what was not verified

- Layer grouping, flags, Bt and trace-code rate unread: the per-token range 0.14 to 0.25 M is mine, not theirs.
- `11-1` after character 100,000, `11-4`, `11-5`, Construction D.6's ZK text, and Construction 11.4 (committed-mask sumcheck) unread. The summarizer's wording may differ from the files.
- The 2^-128 reasoning in §1 is mine; Lean proves their statement, and I checked it only against Table 10's phrase.
- No FlashProve proof was run; none of its numbers is a measurement here.

## 7. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 147 (H145 to H147; H144 was the last in STATE).

## 8. Next concrete actions

1. Finish `11-1` (offset 100,000) and read the Lookup and masked-sumcheck sections for mask counts (H147).
2. Add a count to the next census run: A rows with honest |value| below the 2^17 bound (H145) and wraparound-only lookups (H146).
3. Coordinator: decide whether the product-form lookup (bits of multiplicity) is worth costing beside fractional LogUp for 2^16 tables.
