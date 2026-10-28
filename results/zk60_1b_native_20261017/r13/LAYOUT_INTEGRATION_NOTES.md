# R13 layout integration notes

Status: proposed native implementation contract, not an implemented layout.
The selected construction uses the amended full int16 word domain and exact
byte-aligned, verifier-derived activation tables. No inverse planes.

The legacy shape fields remain base calibration values. Precision derives
the effective shifts once. A new profile must independently declare its
stack and counts; no legacy profile may select these branches.

## Plane and byte-lookup counts to check against native definitions

Assuming the fixed counted classes (norm remainder 24 bits; Q/K/V/up/PV
remainders two bytes; AO/gate/score three bytes; down two bytes LOW or three
bytes H24; product remainder three full bytes LOW or two full bytes H24):

| Domain | A planes LOW | A planes H24 | U8 lookups / position LOW | H24 |
|---|---:|---:|---:|---:|
| T | 4 | 4 | 0 | 0 |
| Ht | 2 | 2 | 0 | 0 |
| L | 2 | 2 | 2 | 2 |
| D | 38 | 39 | 33 | 34 |
| Q | 14 | 14 | 14 | 14 |
| Kv | 14 | 14 | 14 | 14 |
| F | 16 | 16 | 14 | 14 |
| S, non-DD | 9+2*ls | 9+2*ls | 11+2*ls | 11+2*ls |
| S, DD | 7 | 7 | 6 | 6 |
| Dd, DD | 4+2*ls | 4+2*ls | 5+2*ls | 5+2*ls |
| Tab | 3 | 3 | 0 | 0 |

Here ls=ceil(wrho_s/8), unchanged by F_P=12 because it is derived from the
softmax denominator, not the quotient scale. The quotient still has two
limbs, with its top pin using F_P=12. Keep the existing extra pair/tuple
helpers separately from U8 helpers. Fixed-count remainder groups may retain
a redundant top pin when its scale is one, consistent with the counted
window. Norm remainders and byte-aligned product remainders have full-byte
groups with no top pin.

These are independent hand-derived counts. Recompute them from native Ids,
lookup declarations, claim sites, helper pairing and masks; do not use this
table as evidence of an implemented or accepted layout.

## Removed IDs and output identity

Norm groups shrink from four limbs to three. Map the removed fourth toy
IDs to an absent sentinel, never to the following plane. Existing
`B::a_range` skips absent IDs when outside the claimed physical range, but
new relations must use role accessors for all limb groups. Every additional
limb requires an accessor; do not infer it from the next legacy constant.

`Witness::output()` currently reads literal A_X2. That is valid only for the
legacy four-limb norm layout. The R13 witness/driver must obtain the output
through the new Ids map (or retain the output-plane ID in Witness), including
fresh endpoint preparation and internal stack boundaries. The same applies
to CLI parity extraction. A test must catch a shifted output-plane alias.

## Activation tables and padding

The ACT table is groups*4096 entries, with signed gate index i-2048, derived
scaled output and public group ID. Query compression binds ALL THREE.
Padding query (gate=0, output=0, group=0) is a genuine table row. Do not use
biased index zero as the query key for padding.

Dom::Tab must remain exactly the row width (the S-1 premise). Require ACT
entries <= row width on each new profile. Fill remaining public table
positions by repeating an actual table entry. Do not populate invalid group
IDs in those positions.

The existing tab pad rule uses a single U8/exp support bound of 256 for ALL
three histograms/helpers. That is insufficient for ACT: its real entries
extend through groups*4096. Retain zero padding for all three histograms and
table helpers, using an ACT-specific public support indicator in SC_TAB.
Do not relax the existing zero-padding premise or apply the 256 mask to
valid ACT counts. This adds a public indicator table beyond the group column
counted by the replica. It adds no committed plane or private claim; native
slot table/element-term counts and degrees must still be recomputed.

## Remaining argument changes

All seven public matrix folds consume their output-channel multipliers.
Gate uses the exact folded multiplier and common denominator. Never multiply
an interpolated output scalar by an interpolated multiplier after folding:
fold the scaled public matrix coefficients at the actual output channels.
This avoids changing the matmul polynomial degree.

Q/K/V/O and norm words need their new byte decompositions. RoPE still has a
one-byte biased remainder and the same shift. Score stays symmetric int8
with ALL future scores checked. F_P propagates through witness, softmax
relations, quotient pins, DD dictionary and diagnostics.

The product uses the already-scaled public ACT output times up, at R=16 or
24, with no extra public factor in that clause. Up gains two remainder
planes and its hosted relation becomes a requantization. AO/down/gate/score
host clauses reconstruct all new limbs. Public group membership and table
generation are verifier checked, not inferred from an honest witness.

After every consumer is wired, gate the profile on dense full proofs,
fresh-process byte verification, targeted relation/range/lookup mutations,
actual counts, legacy seeded goldens/retained receipts, full suites and D24.
