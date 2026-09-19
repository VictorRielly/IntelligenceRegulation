# D14 memo: integration review of the headline accounting

Codex, 2026-09-19. Read-only review of the draft introduced at `d399b32`,
checked against `zkp-core/src/pcs.rs`, the current
`hashline/src/gpu/cuda.rs`, and `ZK60_FABLE_SECURITY_OBLIGATIONS.md` §5.
This is not acceptance of the memo's full construction or soundness argument.
No rate, field, query count or proof format changes are authorized here.

Two headline interpretations need correction before using the memo to choose
the next speed work or declare a five-second result impossible.

## The hash counter is incomplete by construction

`Gpu::commit_chunked_upload` enqueues both `encode_rows_view` and
`k_hash_cols_stream`, then downloads the leaves. It records
`secs_h2d += secs_up` and **`secs_ntt += total - secs_up`**. It does not
separately charge the streamed hashing to `secs_hash`. The latter counter's
0.481-second value therefore cannot establish that hashing accounts for 0.8%
of the full model proof. The draft notices the inconsistency in §H; the
implementation resolves its cause directly.

The 13.877-second `ntt` counter contains more than transform kernels, and the
13.826-second re-encode counter includes allocation, launch and download
costs. Summing those counters with `hash` is useful attribution, but it is
not a separately measured cost of only the work L4 would remove. Packing and
GPU work can also overlap. Treat the memo's Amdahl arithmetic as a model
conditional on those boundaries, not a hardware lower bound. In particular,
changing field width can affect transfers and arithmetic outside the named
encoding group; a ceiling for removing that group alone is not a ceiling
for every proposed change.

Required follow-up: preserve the current end-to-end phase clock, separately
measure the relevant kernel work with appropriate synchronization or device
events, and account for overlap before projecting a saving. Do not relabel
the present counter as isolated hashing or NTT time.

## The projected 94-bit bound is not the column-test union alone

For the cited conservative column test, direct arithmetic gives:

- Per opening: `-256 log2(3/4) = 106.2496` bits.
- Across 32 × 6 openings: `106.2496 - log2(192) = 98.6646` bits.
- The separate projected LogUp contribution is about 94.2 bits after
  composition. Combining it with the column term gives about 94.14 bits,
  before the remaining terms and Fiat–Shamir qualifications.

Thus the memo's approximate 94-bit number is consistent with its cited
**whole-relation projection**, but its opening paragraphs and §C attribute
that number to the PCS union alone. Raising the column-query count alone
does not remove the dominating LogUp term. The cited projection is also not
a verified bound for the implemented repaired private model profile.

The rate-half calculation itself checks out: 404 columns at miss probability
5/6 give 106.2659 column-test bits, approximately preserving the current
per-opening column term. That does not by itself preserve every other
soundness, privacy or proof-composition term.

These corrections preserve the memo's useful concerns about integer ranges,
query cost and proof size. They narrow what its current numbers prove. D14
remains a paper-only investigation; the five-second objective stays open.
