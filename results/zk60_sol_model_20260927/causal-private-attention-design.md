# Separately versioned causal-only private attention: source-backed design

This is a design and arithmetic audit of the generic candidate at
`/tmp/zk60-groups-20260926`, not a change to its frozen relation. The
Mistral `T512/T1024, d4096, f14336, H32, Hkv8, dh128` counts are
**unregistered geometry probes** for a 7.24B-parameter historical proxy,
not an admitted >=8B trained profile. Source pins are in
`causal_attention_source_pins.txt`. No proof, calibration or throughput
claim was produced.

## What the frozen relation actually proves

`Shape::natural_log(Dom::S)` is `clog2(h_pad*t_pad*t_pad)` and
`Shape::size` makes it a power of two. S has `(head,t,j)` order. At these
probes, `H=32`, `t_pad=T`, so the dense domain is 8,388,608 positions
at T512 and 33,554,432 at T1024. `Shape::a_plane_doms` assigns
`5+limbs_p+2*limbs_sigma_s = 13` A planes to S; `h_plane_doms` assigns
`helpers(S)+1 = 9` H planes. The mask, proximity and site rows are
additional. `layout.rs` names the score, remainder, selector, exponential,
probability and softmax-limb A planes (`A_S8` through `A_SG1`), while H
contains S lookup helpers and the exponential helper.

The witness and constraints do **not** simply skip future scores.
`protocol.rs::row_max_at` substitutes `MASK_SCORE=-127` when `j>t`.
`argument.rs::causal_mask_at` supplies a public mask over the padded S
cube. `SC_SCORE` ties score entries to private Q and grouped K through a
bilinear identity over the head group, and `SC_PV` ties probability entries
to grouped V. `SC_RS` sums the masked exponential/probability over the
full padded cube. `SC_SZC` checks the softmax quotient, selector, limbs,
lookup helpers, pad-zero rules and a hosted Ht row-sum relation; its
`per_row` is `size(S)/size(Ht)`, the dense `t_pad`. The future and padded
entries are therefore part of the present commitment and refusal domain.
Dropping them from the stored plane without changing the relation would
leave assertions or identities unsupported. No change to this frozen
profile is proposed.

## Size arithmetic and the power-of-two trap

For each head, a causal triangle has `T(T+1)/2` score positions.

| Count | T512 | T1024 |
|---|---:|---:|
| Dense S positions (`32*T²`) | 8,388,608 | 33,554,432 |
| True causal positions (`32*T*(T+1)/2`) | 4,202,496 | 16,793,600 |
| Causal positions / 16,384, tightly packed | 257 rows | 1,025 rows |
| Dense positions / 16,384 | 512 rows | 2,048 rows |
| **Optimistic** savings per S plane with a new packed domain | 255 rows | 1,023 rows |
| Optimistic A/H savings at 13/9 S planes | 3,315 / 2,295 rows | 13,299 / 9,207 rows |
| If each head is row-aligned | 288 causal rows; save 224/plane | 1,056 causal rows; save 992/plane |
| Head-aligned A/H savings | 2,912 / 2,016 rows | 12,896 / 8,928 rows |
| Current power-of-two `Dom::S` after triangular count | **8,388,608** | **33,554,432** |
| **Actual savings under existing `Shape`/`Layout`** | **0 A / 0 H rows** | **0 A / 0 H rows** |

The inclusive triangle sits **just above half** the dense cube, so its
single `next_pow2` is the original dense cube. One possible *new*
representation splits the strict-lower triangle from its diagonal:
strict-lower true counts are 4,186,112 and 16,760,832, rounding to
4,194,304 and 16,777,216; diagonal domains add 16,384 and 32,768.
The two padded domains would total 4,210,688 (257 rows) and 16,809,984
(1,026 rows), respectively. Thus a split can recover roughly half the
storage arithmetically, but it adds a second committed domain for **each**
S plane, separate support/pad rules, and new cross-domain identities for
the score, PV, max, softmax, row sum, lookup helper and LogUp sum checks.
The strict-lower compact rank/unrank map is not the current affine
`(head,t,j)` MLE coordinate map; proving its bijection and preserving the
bilinear identities are unresolved proof obligations. Even this split is
only a design possibility, not an achieved row reduction.

The optimistic packed savings would remove at most 5,610 A+H rows
(735,313,920 raw bytes; 2,941,255,680 rate-4 encoded bytes) at T512,
or 22,506 rows (2,949,906,432 raw bytes; 11,799,552,768 encoded bytes)
at T1024. The GPU chunked store does not retain those encoded bytes, so
the relevant retained saving there is **raw** A/H data on each of host
and device, not full codeword storage. These figures are upper bounds
before any new support indices, masks, proof helper rows or row-alignment
cost. A new *power-of-two* S MLE with only the triangular true count
would pad straight back to the dense size, yielding **zero** row saving.

## New relation and integration seam

A legitimate causal-only profile needs a fresh profile/hash tag,
transcript/receipt version and new integer reference. It may either
retain the dense S MLE and prove only causal entries (saving compute only
if the omitted entries are canonically constrained), or introduce a
packed/segmented causal support with an explicit public map
`(head,t,j<=t) -> committed offset`. The latter must prove bijection and
bounds, make its packed padding canonical, and re-derive the score/PV
bilinear reductions, probability row sums, max/softmax windows, LogUp
lookup counts, pad-zero terms and `SC_SZC`'s hosted `per_row` factor.
The current `Shape::new`, `Layout::for_shape`, `argument.rs` slot builders,
`protocol.rs` witness/reference and fresh-process verifier are the
concrete integration seam. Register the new profile only after a
calibration and integer reference for the actual trained >=8B checkpoint
exist. Keep the existing dense relation and its receipts byte-stable.

Q/K/V remain private and proven: Q for each query position, grouped K/V
for every permitted key, RoPE on Q/K, the score, softmax and weighted V,
both norms, FFN and residuals for **each counted new position**. A
causal-only score domain alone does not make a reusable KV cache. For
incremental generation, each layer's prior private K/V and hidden
activations need authenticated state commitments carried into the next
step, with an append transition, position/RoPE binding, causal length,
model/calibration identity, and a proof that the private output token
chosen at step `t` is exactly the next step's private input. Boundary
roots and the receipt chain must bind these transitions; fresh masks,
pads, salts and proof randomness are required for every new commitment.
Reusing a mask or treating a cached byte array as already proved would
change the privacy and soundness claims.

The refusal domain changes visibly: a dense receipt still checks future
QK score entries while using a fixed sentinel in the masked softmax, and
rejects padded-cube violations; a causal-only receipt
must reject an illegal `(h,t,j>t)` mapping, duplicated or missing causal
positions, noncanonical packed padding, changed cached K/V or token,
and any attempt to verify under the dense profile tag. Future scores
must be absent by a checked public domain rule, not left as unconstrained
private values. A receipt from one relation must never be accepted by
the other verifier.

## Workload accounting

An **incremental within-one-window** proof can count each newly produced
position once, but only after the authenticated per-layer cache and token
transition relation exists. The first prefill still processes all prompt
positions, and every new step attends to its prefix. A **long prefill**
may amortize startup over many positions with a triangular attention
relation, yet input prompt tokens are not automatically generated output
tokens; the throughput denominator must state exactly what is counted.
**Repeated fixed-context** proofs re-prove the same positions and cannot
multiply their proved-token count by repetition. None of these workloads
follows from a causal-storage row estimate, and no tokens/s projection is
supported without a complete trained stack clock including transfers.

## Falsification gates for a new profile

1. At toy, 125M and a small non-power-of-two token count, compare every
   causal score/probability and final block output against a dense integer
   reference; check `j=t`, `j=t+1`, head-group boundaries and padded rows.
   Assert the actual constructor's row counts: a single power-of-two
   inclusive-triangle domain saves **zero** S rows at T512/T1024. For any
   proposed diagonal split, count both domains and all added helper/site
   rows before advertising memory savings.
2. Mutate one Q, grouped K, grouped V, RoPE position, causal score,
   softmax limb, probability, FFN output or residual; the appropriate
   slot or fresh-process verification must refuse. Mutate a future
   packed index or padding word; the new domain rule must refuse.
3. Try duplicate/missing packed positions, head-swapped KV groups,
   cross-profile roots, altered model/calibration IDs and a transcript
   replay; all must refuse with no dense-profile acceptance.
4. For two and three incremental steps, change a prior cache entry,
   prior token, step number, boundary root or newly selected token;
   the chained proof must refuse. Regenerate with independent entropy
   and check that no pads, masks or salts repeat across steps.
5. Measure row counts, RSS, VRAM, pool occupancy, transfer bytes and
   full-stack clocks only after those proof gates and a trained import
   pass. Record prefill and generated-token denominators separately.
