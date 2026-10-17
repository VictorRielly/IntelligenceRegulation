# Fp2 arithmetic candidate — owner review, not integration

Run `20260926T225233Z-f66107c9`. **Exact synthetic checks pass; speed is
unknown.** Main/Claude owns native review and any integration. No main source,
receipt, reviewer file, calibration, Git metadata or runtime state was changed.

Interface: unchanged `Fp2::mul(self, r: Fp2) -> Fp2` and
`Fp2::square(self) -> Fp2`, canonical Goldilocks limbs, `u²=7`, identical
16-byte encoding. Seam: `zkp-core/src/field.rs:158` and `:172`.

Patch: [fp2-arithmetic.proposed.patch](../experiments/fp2-arithmetic-20260926/fp2-arithmetic.proposed.patch).
Full proposed source, original main and grouped-candidate snapshots, baseline
and candidate SHA-256 values, and two-hunk provenance are adjacent. **Neither
patch application nor compilation occurred.** Do not import the whole snapshot
over newer native source; review the two methods against the pinned baseline.

Karatsuba removes one of four variable base products but changes two
additions into three additions plus two subtractions. The square uses two
variable products, one multiply by seven, five adds and one subtract. Compare
it to a compiler-shared three-product square, not the literal four calls.
Constant-seven strength reduction and extra carry chains can erase the gain.
The alternative that computes seven by doubles is tested only in Python and
is not in the patch. Native scalar/packed implementations may favor dot
products instead; the Plonky3 source assessment records that alternative.

[Validation and reproduction](../experiments/fp2-arithmetic-20260926/README.md):
24,641 product cases, 10,121 square cases, 35 powers; base primitive/wide
reduction oracles; 24 fused plus 13 grouped fixtures; eleven negative controls
and four fixture refusals. One CPU, seed 2026092607, 3.718 s, 22,496 KiB RSS.
Fixed-width Python transcriptions compare to unbounded polynomial reduction;
downstream synthetic round/challenge/final checks pass. This does not execute
Rust, native CFS/RNG/extension rounds, commitments or verification.

End-to-end reach is unresolved. The latest owner 125M CPU grouped softmax slot
is 8.601/7.832 s of 40.322/39.095 s known readiness, but the multiplier's
share is not measured. Encoding/merkle alone is 16.739/16.903 s and is not
removed by this patch. Proving, witness and serialization, and verification
separately, are pinned in the experiment. No 8B/GPU/prefill/decode result.

Proposed owner gates, under the shared build/heavy locks:

1. Compile the two changes separately and together, with existing native field
   oracles, wrap boundaries and independently computed canonical output bytes.
   Inspect release compiler output for duplicate-product elimination and
   constant-seven strength reduction. The public `Fp(u64)` representation is
   not permission to feed noncanonical limbs; keep the existing contract.
2. Compare dependent chains and independent arrays on the target CPU, then
   the actual grouped SC_SZC evaluator. Check masked bytes, challenges,
   finals, fresh RNG consumption and zero-factor fallback with identical
   synthetic randomness. Native invalid-witness/refusal behavior stays owed.
3. Verify fresh/archived receipts and corruption controls in separate native
   processes; retain D22's source-specific gate without enlarging its scope.
   Run an owner-approved complete dense A/B including witness and serialization
   only if useful kernel/slot evidence remains. Verification time stays separate.
4. Do not claim device improvement: no CUDA implementation was modified or
   tested. Any device transfer requires its own arithmetic and receipt gates.

Exact algebra needs no new field or protocol assumption, but broad core
arithmetic integration has a broad correctness footprint. D19b/D23 remain
proposed and D22 remains CPU toy only. No privacy acceptance transfers from
this research experiment. Reject promotion if native scheduling/register costs
erase the saving; a source operation count is not a performance result.
