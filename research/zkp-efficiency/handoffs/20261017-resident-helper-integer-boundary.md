# Resident helper production must preserve the integer source representation

Cycle 0066, `20261017T192105Z-c342a26b`. Research-only; no source promotion,
merge, native build/proof or GPU job. [Evidence](../experiments/lookup-helper-staging-20261017/README.md).
No proving improvement found. This handoff adds a concrete compatibility gate
to a future device-H producer and a compiled private-bit prototype.

The captured active owner seam is
`ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/protocol.rs`:
`lookup_values_at:388`, `helper_one:551`, `prove_core` A conversion at 825,
`looked` at 834, H allocation at 908 and helper write at 928.
`layout.rs::lookups_at:701` fixes the catalog. Pins/copies are in
`experiments/lookup-helper-staging-20261017/native-pins.json` / `native/`.
Recompare the owner's source before integration; never edit the review copy.

Baseline uses i64 wrapping multiplication/addition before field conversion.
An affine evaluator on resident A can return different H words on malformed
inputs; a single scale-2 lookup can miss or introduce a helper refusal.
Worse, signed `-2^63` and `p-2^63` have identical A residues but scale-2
wrapping gives respectively 0 and -8589934590, with different H values.
No A-only deterministic implementation preserves both. Coefficient 2 is a
real Q/K rotation range pin. This is an all-internal-witness compatibility
counterexample, not an accepted-proof forgery or an admissible-input attack.

The [compiled research interface](../experiments/lookup-helper-staging-20261017/resident_codec.rs)
contains `ambiguity_bit(v, residue)`, `recover_word(residue, bit)` and
`resident_lookup(..., mode)`. The main/audit harnesses prove the residue has
two i64 preimages exactly in `[p-2^63,2^63)`. A private bit resolves which;
unsigned wrapping arithmetic then reproduces the original lookup. Identity
denominators can read A directly without bits. A caller must own the private
bits per proof, preserve plane/word order and retain them until the last
producer use. No public logs, receipt fields or cached cross-proof state.
The code is compiled on CPU only; there is no complete native or CUDA patch.

Tests compare 4,176 columns / 106,962 field words across 48 catalogs and six
domains, plus generic fallback expressions, against independent integer
formulas. Both H limbs, odd/paired helper order and used/unused/invalid zero
denominators are checked. Full int16 and full-i64 boundary codec tests pass.
The separate audit adds full-extension exponent inverses and mutated bit
indices. Final counts/timings are in `result.json` and `audit-result.json`.
Real Rayon, failed-buffer state, transcript/RNG, PCS, masks and receipts are
not covered by this isolated harness.

Potential removed work: looked buffers could die after the histogram and H
could be generated from resident A. No production work is removed here. At
the earlier 1.1B T128 geometry, source counts are 221.25 MiB looked payload
versus 0.609375 MiB packed source bits; H's 235.25 MiB output remains. The
prior borrowed-column alternative already reduces looked payload to 53.75
MiB. These are payload counts; peak and traffic are unmeasured. Add packing,
metadata, integer reconstruction, field/cache arithmetic, fallback and all
required transfers. Do not add this storage ratio to a bandwidth forecast.

The current F device builder already reads resident A/H and expands them
into its working tables. Reusing `gpu::dev_helpers` requires a new block
descriptor (arbitrary affine/pair/single lookup semantics, padding and zero
checks). `pcs.rs::commit_zk_device:124` calls the legacy device committer and
retains only host-known H rows; the block instead calls the tagged owned
committer and still has CPU H readers. A tagged device-owned H API and host
coherence must be designed, or D2H/H2D round trips explicitly charged. Do not
mix legacy and tagged domains or remove fresh mask/pad/salt generation.

Earlier shared-box 1.1B T128 whole-U8-helper deletion ceilings: GPU-assisted
1.057799x (8.844 / 161.857226 s), CPU 1.041052x (6.911 / 175.258632 s).
The prototype retains much of that phase. Actual 8B attribution is absent;
no 5090 or native speed factor can be justified. Keep this behind whole-prover
GPU work and authenticated public model residency unless capacity is blocking.

Owner validation before a port: original versus candidate at all shapes and
pool sizes, malformed/extreme/padded words and real refusal order; matching H
and table helpers; original failed-attempt behavior and publication boundary;
native RNG/transcript/extension/final/PCS and frozen proof bytes; fresh complete
receipts with tamper controls; actual peak/transfer and enclosing cold/resident
clocks. Shape privacy acceptance and whole-proof soundness obligations remain.
Any mismatch rejects compatibility; no enclosing gain rejects speed promotion.

Next local: a small Logup* pushforward/private-view and binding audit, to ask
whether avoiding committed helpers is worth more than preparing them faster.
Carry the existing unmasked fractional-GKR leakage and full-table-refusal
negatives forward. Owner reviews/integrates; nothing heavy is queued here.
