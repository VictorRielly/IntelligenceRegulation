# DeepProve gap prerequisite: receipt paths versus the rest

Run `20261030T204123Z-0f14d260`, cycle 0172, 2026-10-30 UTC.

**No measured proving improvement.** A source-derived size census falsifies
authentication-path repetition as the main explanation for the small-proof
gap. The frozen R18 T128 Shieldstral classifier has 13,656,064 path bytes in
an owner-reported 848,412,096-byte receipt: **1.6096%**. Even the impossible
deletion of every path would reduce receipt size by only 1.01636 times.
This is a size bound, not a wall-time speedup bound.

The new opaque path codec restores all original ordered path bytes. Across
50 synthetic cases, all 50 full synthetic tuples round-trip and 12,800
independent synthetic root checks pass. Ten negative controls fire. A
separately authored local audit passes 7,291 checks and 28 additional stream
comparisons. This is not an external review, native proof, PCS verification
or P1 privacy acceptance. SHA256 builds the synthetic oracle trees; native
keyed BLAKE3 is not reproduced.

## Source-derived census

One category comprises IN-C, 26 transformer blocks and OUT-C. There are four
openings in each of the 28 segments, with 256 column checks each. Tree depths:

| Segment | M | A | H | Incoming commitment |
|---|---:|---:|---:|---:|
| IN-C | 12 | 14 | 14 | 11 |
| Each block | 12 | 16 | 16 | 16 |
| OUT-C | 12 | 14 | 14 | 16 |

The classifier block indices are `k+1` in a run of `L+2` stages, so none is
the final run segment and none adds the block wire's external output opening.
The final classifier stage closes its boundary and publishes the verdict;
it has no output endpoint. Independent role counting gives M 2,752,512 B,
block A/H 6,815,744 B, boundaries 3,538,944 B, stage A/H 458,752 B and token
input 90,112 B. The uncompressed remainder is **834,756,032 B**.

The synthetic replacement-random query fixtures project 7,411,776 interned
path bytes, saving 6,244,288 B or **0.7360%** of that whole receipt. This is
not the actual receipt's compressed size: no real receipt or witness was
read. Repeated queries are deliberate: native `challenge_indices` samples
with replacement. A census that silently deduplicates the 256 columns would
change their multiplicity and the frozen bytes.

## Reproduce within the lane limits

From the research directory:

```sh
python3 -B experiments/deepprove-gap-ledger-20261030/run_bounded.py experiment
python3 -B experiments/deepprove-gap-ledger-20261030/run_bounded.py audit
```

Seed 20261030172; depths 0,1,2,5,8,11,12,14,16,17; 256 queries per
fixture; replacement-random, all repeated, alternating extrema, reversed
adjacent and sorted-random patterns. Audit seed 2026103017201. One nice-19
CPU affinity, 30 s CPU limit, 40 s alarm, 45 s parent timeout, 256 MiB
address-space cap, 96 MiB estimated memory. No build, installation or GPU.
Main 0.469 s / 40,844 KiB; audit 0.217 s / 29,368 KiB, Intel Core Ultra 9
185H, Python 3.10.12. These are diagnostic Python clocks only.

## Interface and review seam

`codec.encode(indices, paths, checks, depth) -> bytes` interns by public
`(level, sibling-index)`, in first-encounter order within exactly one root's
opening. `decode` takes the same trusted geometry and ordered indices and
restores all paths. It rejects out-of-range indices, changed query counts,
wrong depth, inconsistent repeated nodes, truncated streams and trailing
bytes. Digest corruption is left to the unchanged original verifier; the
synthetic oracle confirms that it fails there. Wrong role/root and query
order are controlled. Every column value, salt, vector, mask and query
occurrence stays in the original order. Dictionaries never cross roots,
roles, stages or proofs.

Potential Rust seam: `zkp-core/src/pcs.rs::OpeningZk::write_bytes`,
`hashline/src/zk.rs::MaskOpening::write_bytes`, and the bounded per-segment
transport in `private_block/wire.rs` and `private_block/token_io.rs`.
`source-pins.json` retains 11 read-only source snapshots and hashes. There
is **no Rust patch**, no native transport integration, and no change to the
native wire or transcript. A future wrapper must restore the original frame
before acceptance and keep bounds derived from the verifier's statement.

Baseline: full repeated paths. Eliminated work: duplicate path bytes in
transport only. Added costs: root-local coordinate dictionary, copy/expansion
and bounded decoding. NTT, commitment creation, masking and native Merkle
verification work are unchanged. End-to-end ceiling is `N/(T-I_removed+A)`;
exclusive I/O time and Rust added cost are unknown. A size fraction does not
bound a disproportionately expensive computational phase. Reject the lever
if restored bytes, multiplicities, native acceptance, bounds or privacy
change, or added work exceeds critical I/O saved. Demoted after this test.

[Gap analysis](GAP_ANALYSIS.md), [census](census.json),
[result](result.json), [audit](audit-result.json),
[ranked queue](ranking-current.json).
