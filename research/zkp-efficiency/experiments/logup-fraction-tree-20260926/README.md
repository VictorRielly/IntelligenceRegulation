# Fractional LogUp tree: exact algebra, blocked naïve private integration

Run `20260926T235233Z-5f465072`, cycle 0008, 2026-09-26.
**No proving speed improvement established.** The tree arithmetic works, but
publishing its unmasked denominator is incompatible with hiding even a single
lookup. Retaining its whole tree also creates substantial new memory traffic.
This is a synthetic feasibility and negative-control experiment, not GKR.

Reproduce from the research directory, with existing Python and no dependencies:

```sh
python3 experiments/logup-fraction-tree-20260926/experiment.py > experiments/logup-fraction-tree-20260926/run.log 2>&1
python3 experiments/logup-fraction-tree-20260926/validate.py > experiments/logup-fraction-tree-20260926/validation.log 2>&1
```

The script pins one available CPU and enforces 59 s wall, 55 s CPU and 512 MiB
address-space limits; estimated memory is 32 MiB. See `result.json` for the
measured runtime, RSS, CPU, seed and source digest. No Rust compilation, GPU,
proof, network client, installation or production modification is involved.
All values are synthetic. Proving, verification and complete readiness are null.

## Hypothesis and native seam

Replacing committed inverse-sum H helpers with an uncommitted fraction tree
could avoid significant H encoding and Merkle work. The actual target seam is
the shaped `private_block/protocol.rs` helper construction at lines 877–984,
`write_h` at 633, and `logup_sum_claim` at 167. The companion layout is
`Layout::for_shape`, `HIds`, `Shape::{h_plane_doms,claim_sites}` and the helper
relations in `argument.rs`. Main is still a different, tiny layout; use the
pinned grouped candidate, not main's row constants, for the 125M ledger.
Snapshots/hashes in `native-reference/` and `source-pins.json` identify both.

Baseline H contains pairwise sums of U8 inverses, singleton exp/activation
inverses and multiplicity-weighted public-table inverses. `write_h` splits
Fp2 into real and imaginary base-field planes. The existing all-ones claim
checks the combined sum is zero, with a zero-sum masking pair; **no individual
helper sum is public**. Table denominators are checked even for unused entries.
The table domain is lifted to the row width and multiplicity padding is zero.

The candidate interface exercised here is
`tree(leaves: [(Fp2 numerator, Fp2 denominator)]) -> (private root, private levels)`.
Its merge is `(nL*dR + nR*dL, dL*dR)` and padding is `(0,1)`.
This is a local diagnostic interface; neither return value is safe to serialize
as a private proof. `link(leaves, q, theta)` evaluates `N(q)+theta*(D(q)-1)` as
a diagnostic for a required leaf binding. It is not a commitment or verifier.
No native patch is proposed by this cycle.

## Validation and decisive counterexamples

- 150 fraction cases of 1/2/3/8/32 leaves agree both with direct reciprocal sums
  and a separate O(n²) product-of-all-other-denominators expansion. The oracle
  uses polynomial convolution and Fp2 Fermat inversion; the candidate uses the
  binary merge and closed multiplication formula.
- 100 synthetic lookup/multiplicity identities have root numerator zero and
  nonzero denominator. Signed/zero multiplicities, repeated values, base and
  full-extension elements, near-modulus boundaries and ragged padding appear.
- 300 independent cube-MLE evaluations match folding for the numerator and
  shifted denominator tables. These are arithmetic checks, not PCS bindings.
- Fifteen controls cover altered inputs/multiplicities, dropped leaves, table
  signs, padding, ordered binding, omitted merge terms, zero denominators and
  the disclosure examples. A random diagnostic link is not a soundness proof.

Two zero-denominator leaves can merge to `(0,0)`. Checking just a zero
numerator or cross-multiplication then accepts a meaningless fraction. Dropping
a zero-multiplicity public-table leaf also changes a required refusal: the
retained fixture accepts after pruning but refuses when the full table is
checked. The experiment preserves the event of refusal; it does **not** replay
native refusal ordering, draws or transcript activity.

Deleting one witness occurrence and adjusting its table multiplicity leaves
the lookup identity true. The binding to the ORIGINAL committed witness and
public leaf schema must detect that. Reordering leaves preserves the root but
changes an ordered MLE link. Root algebra alone establishes neither binding.

For the privacy counterexample, let the hidden witness have one lookup `v` and
let `C` be the public product of all table denominators. The unmasked root is
`D = (alpha - tag - v) * C`. If it is published, then
`v = alpha - tag - D/C`. The script recovers each of four hidden synthetic
values exactly. Publishing its helper sum also reveals it by inversion.
This rejects the **naïve unmasked adaptation**, not fractional GKR in general,
and is not an attack on the existing native protocol, which publishes neither.
Masking only this root is not shown sufficient: all layer messages, leaf
openings, random draws, refusals and their joint view still need analysis.

## End-to-end cost boundary

Owner logs are read-only evidence, not a benchmark run here. The latest new-arm
dense synthetic 125M block has H commitment **9.377/9.593 s**, proving
**34.861/33.315 s**, witness **5.43/5.76 s**, serialization **.031/.020 s**,
known readiness **40.322/39.095 s**. Internal verification is **.900/.810 s**,
from bytes **.91/.82 s**, separately. H commitment alone is 23.3%/24.5% of
known readiness; deleting that entire phase is an accounting ceiling for
that phase, not this candidate's saving. U8 helper work is 1.046/1.134 s and
exp+activation helpers .193/.216 s. Two CPU threads on a shared box, extra
small-slot oracles, no enclosing request clock or GPU/8B timing.

The source-derived 125M ledger counts, without allocating the big arrays:

| State/work | Count |
|---|---:|
| Existing H helper data, excluding its zero-sum pair | 7,016 base-field rows |
| Existing H zero-sum pair + reserved pairs + proximity pair | 2 + 100 + 2 rows |
| Existing H total, 16,384 columns | 7,120 rows; 933,232,640 input bytes |
| Existing H encoded values, rate 1/4 | 3,732,930,560 bytes |
| Fraction leaves, including lifted table domain | 103,890,944 |
| One globally padded binary tree | 134,217,728 leaves; 134,217,727 merges |
| Generic construction work | 402,653,181 Fp2 products + 134,217,727 additions |
| Both values of every node, including leaves | 8,589,934,560 bytes (almost 8 GiB) |
| Leaf layer / leaves plus first out-of-place parent | 4 GiB / 6 GiB |
| If flattened and committed instead | 65,536 base-field rows before masks |

These are an explicit naïve schedule, not lower bounds. Known numerator ones,
neutral nodes, domain-specific trees and streamed/recomputed layers may remove
work. Counts exclude GKR scratch, masks, bindings, other commitments and
allocator overhead. The alternative 256-entry table-only representation
reduces active leaves to 103,842,560 but has the same global power-of-two pad.
It requires preserving the native multiplicity-padding relation separately.

**Net saved rows, new GKR masks, new binding rows and proof bytes are unknown.**
The 7,016 rows are gross candidates for displacement; no existing mask row is
assumed removable. Simply committing the full tree worsens row count by over
9x. Keeping it uncommitted requires GKR plus masked binding to A/multiplicities,
new transcript/PCS/soundness accounting and owner review. Larger token windows
increase the score domain quadratically and do not amortize this away by fiat.

## Sources, preserved correction and disposition

The [fractional-GKR note](https://eprint.iacr.org/2023/1284) motivates helper
commitment reduction; its PDF was blocked by robots.txt. The September
[Plonky3 lookup PR](https://github.com/Plonky3/Plonky3/pull/1968) describes
binding the reduction to committed traces and neutral padding. The
[SP1 verifier source](https://docs.rs/sp1-hypercube/latest/src/sp1_hypercube/logup_gkr/verifier.rs.html)
shows explicit denominator checks and trace-opening checks; no zero-knowledge
property of a surrounding wrapper was audited. These sources were inspected,
not executed or benchmarked. Exact dates, license scopes, missing commit
content and fetch failures are in `source-records.json` / `search-log.json`.

`initial/` preserves the first passing run. Its flattened-row estimate rounded
down to 65,535; final code correctly rounds up to 65,536. The arithmetic digest
is unchanged. No earlier finding or negative result was replaced.

Disposition: retain as an architectural lead with a clear privacy and memory
gate; do not port an unmasked tree into the private path. The highest near-term
owner work remains grouped fold/round fusion and GPU commitments. Next bounded
research test: adapt fusion to the source-pinned three SC_SZC equality groups,
preserving group running sums, prefix/suffix updates and zero-factor fallbacks.
