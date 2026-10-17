# Batched lookup domains — bounded research, cycle 0068

Run `20261017T212105Z-f1b8cd7d`, 2026-10-17 UTC. **No proving speedup found.**
The result is a private-scratch arithmetic adapter and a padding/claim inventory.
No GKR, PCS, native receipt, GPU job or zero-knowledge construction was run.

`batch.rs` exposes:

```rust
batch(index: &[usize], lengths: &[usize], active: &[usize],
      row_point: &[Fp2], column_point: &[Fp2], table_size: usize)
      -> Result<Vec<Fp2>, u32>
```

Columns are concatenated in `index`; each real column has a power-of-two
domain and a public synthetic active prefix. Dummy columns and out-of-domain
rows have zero support. Returned buckets and all test virtual claims are
PRIVATE scratch. Production hidden prompt lengths are not read or disclosed;
public fixture support does not implement the new D25 hidden-length relation.

The candidate computes
`Y[j] = sum_{c,i active, I[c,i]=j} eq(c,s) eq(i,r)`.
Its dense reference folds each supported table-lookup column over the row cube,
then folds over the column cube. Zero-lifting a shorter column includes
`prod_high(1-r[k])`; it is not replication and cannot be silently normalized
away when this factor is zero. Independent per-column evaluation points first
need a claim reduction; this adapter does not supply one. It does not prove
membership, ordered linkage to A or correctness of the returned buckets.

Source-captured native Goldilocks/Fp2 is compiled as a std-only Rust shared
library with a C ABI. No Cargo/native crate or external implementation is built.
Python arbitrary-integer arithmetic uses product weights, dense table lookup
and adjacent folds. All 96 fixtures, 3,744 bucket values, 96 virtual claims,
96 support checks and 1,800 real-column visits pass; these are synthetic
checks, not proved positions. Cases include C=1/2/3/5/9/13/34/83, maximum row
cube=1/2/8/32, table size8/256, odd columns, ragged row domains, empty/partial
support and base/extension/Boolean challenges. Nineteen controls pass.

The independent audit uses integer polynomial convolution and a flattened
row-plus-column bit index. It passes 4,136 checks, including every saved
bucket and claim, a mutated bucket, symbolic polynomial rank and exhaustive
F17 comparisons. Captured source hashes match. An initial 4,135-check audit
is retained before adding the symbolic rank check.

**New negative: repeating one random scalar across every column coordinate
breaks tensor batching.** Its equality weights depend only on a column's
Hamming weight. For the first83 columns of a128-column cube, the coefficient
matrix has rank7 over Goldilocks, leaving a76-dimensional space of fixed
claim errors that cancel for every repeated scalar. In particular, columns1
and2 always have the same weight. Independent two-coordinate F17 challenges
distinguish their opposite errors at272 of289 points; diagonal challenges
never do. This rejects our proposed shortcut, not an upstream/native attack.
Ordinary powers-of-one-challenge random linear combination is a different
construction and is not rejected by this test.

Other controls retain prior negatives: a raw batched virtual value reveals a
singleton after division by its known weight; compensating claims chosen
after batching coefficients cancel; uniform scalar marginals can leak jointly
under correlated pads. Every claim must be bound in the proper order and the
whole view must hide. The unused public-table zero is a reference refusal
event, not an optimized-protocol refusal replay. Native error order, RNG draws,
padding, full-i64 wrapping and all other prior refusal obligations stand.

The source-derived 8B T32 layout has six domains:

| Domain | Positions | U8 columns |
|---|---:|---:|
| L | 8,192 | 2 |
| D | 131,072 | 34 |
| Q | 131,072 | 13 |
| Kv | 32,768 | 12 |
| S | 32,768 | 13 |
| F | 524,288 | 9 |

Total83 columns /11,714,560 queries per block. `accounting.json` checks the
prior census against captured shape formulas and owner counted totals.

| Illustrative plan | Pushforwards | Dense cube visits / original | Logical bytes | Bytes at existing 8,192 row width |
|---|---:|---:|---:|---:|
| Per column | 83 | 1.000 | 339,968 | 10,878,976 |
| Six domains | 6 | 1.702 | 24,576 | 786,432 |
| Four equal-length groups | 4 | 1.523 | 16,384 | 524,288 |
| One global cube | 1 | 5.729 | 4,096 | 131,072 |

All bytes exclude masks, encoding and proof data. These are alternative
illustrations, not lower bounds or an implemented native protocol. A ragged
public-support traversal can skip dummy queries and visit11,714,560 real
entries in any plan; the protocol must still prove the supported relation.
No full 8B arrays are allocated here. Sparse traversal performance is untested.

The illustrative Powdr interface retains83 ordered-index evaluations before
further reductions, even when using one pushforward. Initial and GKR terminal
pushforward sites give166/12/8/2 additional private scalar channels in the
four respective illustrations. Public-table sites are separate. The inventory
explicitly leaves round masks, native A reserved rows, fresh-mask bytes and
net H/M displacement UNKNOWN. There is no valid exact native mask count until
the masked reduction and its joint view are designed. Combining roots is not
permission to discard these obligations or reopen a private commitment.

Baseline U8 H is1,514 base rows /99,221,504B; all H1,758rows /115,212,288B
per block. The query values are already uncommitted: extra query commitment
saving is zero. Candidate eliminated work is duplicated small pushforward
payload, in a future architecture that first replaces H correctly. Added work
includes equality weights, padding or support traversal, distinct-point
reduction, GKR, wrapping/affine A links, masks, PCS sites, transfers and
serialization. None has a native cost measurement here.

Owner baseline, carried rather than rerun: 8B,32 linked blocks,T32,one cold
pass,16CPU threads,GPU off. App total171.578s; guarded process171.641294s.
Diagnostic rates0.186504/0.186435positions/s respectively. Witness21.376s is
inside inclusive prove156.143s; reload15.993s also inside; remainder118.774s
contains proof, serialization and sink. Initial load15.294+seal0.051=15.345s,
partial startup8.943%; full startup and steady slope unknown.
Fresh verification now observed: initial load13.165s plus inclusive check
26.491s (reload13.071s, crypto remainder13.420s); process including11 refusal
controls115.868762s. Honest proof still verifies. Receipt465,815,776B.
Trained-shape privacy remains unaccepted, so this is a functional diagnostic,
not target-compliant private throughput. No new proof/position is credited.

Deleting all four enclosing H commit/open/U8/exp-act phases for free removes
19.5s, at most1.128224x or0.210418diagnostic positions/s with every other
cost fixed. It overcredits U8-only batching, excludes added costs and does
not bound a broader architecture or GPU/5090 result. Proof latency, lag,
drain, serialization, resident-pass slope, longer prefill and decode remain
unmeasured. The >=50/s target stands; larger workloads remain permitted with
fresh masks and dense context attention still grows quadratically.

Commands from the research directory, executed sequentially:

```
python3 experiments/logup-star-batch-domains-20261017/run.py
python3 experiments/logup-star-batch-domains-20261017/audit.py
python3 experiments/logup-star-batch-domains-20261017/account.py
```

Source preparation read/captured only public native source and owner metrics;
the prepare action and selected terminal event extraction are recorded in
`commands.json` and `native-pins.json`. Inspect captures before rebuilding
`field-only.rs`; do not refresh pinned evidence in place.
Final main0.416722s /20,600KiB; compiler128,868KiB. Final audit0.059436s /
16,284KiB. One Core Ultra9 185H CPU thread, CPU0,nice19,seed2026101768;
each run59s CPU/wall and512MiB AS caps; estimates main<96/compiler<192MiB.
Timings establish bounded execution only. Logs are derived from returned
result JSON, not independent raw stdout captures. First main execution had17
controls; the second added the repeated-coordinate controls without changing
the arithmetic fixtures. `initial-observations.json` labels that history.

Seven LIVE primary records added, including the current October16 Plonky3
release and October11 zkLLMPoT revision. The newly assessed older MLE-native
lookup paper2024/1058 is an encoding-compatibility lead, not a native PCS or
privacy match. The zorch issue's final author result remains slower than its
native baseline despite small device arithmetic time. Dates, license scope,
failed fetches and uninspected commit abbreviations are retained in
`searched-sources.json`; no author performance was reproduced.

Integration seam: lookup/H construction in native `private_block/protocol.rs`,
helper constraints and ordered links in `argument.rs`, H/M/claim geometry in
`shape.rs` and `layout.rs`. GPU arithmetic is a later step after protocol
review. No production patch was prepared or merged.

Next local question: can a ragged sumcheck over the four equal-length groups
avoid padded round work while retaining each independent initial point and
all terminal links? Start with independent dense-versus-ragged round
polynomials, public zero support, odd columns and the fixed-error control;
count active terms/rounds and leave fresh masks/PCS as explicit obligations.
Stop if this only moves unmasked private claims around. Owner whole-prover
GPU work and measured complete resident-workload slopes retain priority.
