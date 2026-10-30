# Owner handoff — conditional public derivation sharing, zero direct 8B gain

Cycle 0131, `20261029T005649Z-c94ef085`, 2026-10-29 UTC. No native proving
speedup measured. Parked for the 8B target: current Llama-3-8B is untied and
never reaches this derivation. The conditional Shieldstral 3B result is saved
for owner review; main/Claude reviews and integrates, researcher does not merge.

The exact source chain has two sites: trained `tied_of` computes all three
derived-table digests without a margin; classifier `recompute_tied_classifier`
computes them again with the bound margin. Both prove and verify load through
these sites in the inspected R13 classifier tree. These are source observations,
not runtime incidence or measured clocks. See [source pins](../experiments/public-derived-cache-20261029/native-pins.json)
and [experiment](../experiments/public-derived-cache-20261029/README.md).

Interface proposal: a private-field authenticated result owned in a child
module, shared between base and margin consumers for one exact bound profile.
Keep original native binary64/f32 quantization. Model/profile/checkpoint/
consumed tensor/signs/calibration/algorithm-version and yes/no/scale/threshold
must all bind. Returned mutable public fields and caller-supplied hashes alone
cannot establish authentication. The [API design](../experiments/public-derived-cache-20261029/candidate-interface.rs.txt)
is locally authored, uncompiled and unapplied; no Rust implementation exists.

Validation: 1,717 synthetic checks, 1,067 negative controls, 32 fixtures at
vocabulary 2/3/8/17, width 4/8/16/32 and block 4/16. Separate dense Hadamard,
BF16/Fraction and source-style binary64 references. Final 0.648750 s /
18,856 KiB RSS, one pinned nice-19 Core Ultra 9 185H thread, seed202610290131,
40 s CPU /45 s alarm /256 MiB AS caps, 64 MiB estimate. Source audit724checks
passes with seven native pins unchanged. [Results](../experiments/public-derived-cache-20261029/result.json),
[commands](../experiments/public-derived-cache-20261029/commands.json).

Negatives that constrain integration:

- Metadata keys fail after a same-size edit with restored mtime and unchanged
  path/device/inode. ctime was not held fixed; this is no upstream bug claim.
- A snapshot still represents original data after live mutation or deletion;
  it does not preserve the live loader's refusal domain. Introduce only an
  explicitly reviewed snapshot API. Keep existing live APIs reproducible.
- Two rational fixtures change three head bytes relative to binary64. One
  edge quantizes to -64 in binary64 and -63 rational. Replacing the original
  quantizer with exact rational arithmetic changes the statement's tables.
- An unselected row changes global multipliers while keeping the verdict
  margin unchanged. Initial derivation must still cover the entire tensor.
- Actual export-table, manifest, policy and statement checks remain at their
  callers. A fresh independent verifier authenticates its own object.

The source lower bound per omitted derivation is 8,503,547,472 logical read
bytes before header rereads. This is not memory traffic or elapsed saving.
Owner's 17–18 s/load note is 3B only. Source count schedules are 2P->P for
per-request coalescing and conditionally 2P->1 for one fixed-profile resident
session; other setup/witness/proof/storage/verification costs remain. Baseline
`2D+R` to `D+R+a` has at most 2x free per-request ceiling, with no measured D/R/a.
Current untied 8B has zero savings through this seam.

First owner action: resolve current R-C2 library/capture work, then measure
exclusive site incidence and phase/enclosing clocks. If material, review
snapshot/refusal semantics and ownership before implementation. Native golden,
next-RNG, refusal order/races, capture, PCS, independently verified complete
receipts and privacy gates under current shared locks are all pending. All
fresh masks, pads, salts, challenges and openings remain; no P3 cache authority.
No heavy job was queued and no profile/privacy acceptance is claimed.

Next local research returns to current untied 8B load/reload conversion,
digest and owner lifetimes, after checking prior public-loader work. No more
3B-only cache refinement without owner incidence/enclosing evidence.

Final direction reread: D45, recorded 2026-10-29 01:04 UTC, fixes one policy
and threshold per classifier item, makes classifier content length public,
binds the proof to its post and requires fail-closed publication. Cache
parameter mutations are refusal tests, not permission to reprove the same
item under different policies. This classifier ruling does not alter generic
private 8B throughput acceptance. The changed decision-register snapshot and
diff are retained in final-direction-check.json; target and agenda unchanged.
