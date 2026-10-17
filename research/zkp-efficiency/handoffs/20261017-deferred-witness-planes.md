# Defer initial vectors that owned witness producers replace

Research cycle0061, run20261017T112624Z-88d6b64e. Candidate for owner review;
unapplied/uncompiled, no native speed or peak-memory result. Research does
not merge. The candidate is complementary to the owner's R3 one-pass work.

Interface: unchanged `build_shaped(shape, public, ff, input) -> Result<Witness,String>`.
Seam: `ops/zkp-mvp/trained-1b/hashline/src/private_block/witness.rs:555`.
Review baseline hashes in
`experiments/witness-plane-lifetimes-20261017/source-manifest.json`.
This targets the owner's isolated trained lane; the root production tree
need not match. Compare/rebase before applying if any pin changes.

Patch:
`experiments/witness-plane-lifetimes-20261017/witness-candidate.patch`.
Complete candidate and exact baseline are next to it. The only changed
operation initializes46 slots empty:30 complete-vector outputs and16 norm
limbs. Each original producer replaces its whole slot before any read.
All scatter planes retain full zero initialization. Histogram slots stay
empty, and the exponential plane's full padded pass remains. No arithmetic,
table/range/refusal order, profile, mask, RNG, transcript or verifier changes.
Only initialized safe Vec operations are used.

Validation:72 synthetic assembly fixtures,5928 planes,293384 words and7
controls; two/three score/probability limb ID variants, arbitrary producer
padding, scatter gaps and E's second padded pass. Independent sparse last-write
oracle; source-order first-access recognizer plus semantic family catalog.
Separate162-check arithmetic/provenance audit reconstructs the exact patch,
checks source/log hashes and12 closed-form payload rows. Final run0.379222s,
17456KiB RSS; audit0.002379s,14472KiB. One nice19 CPU0 thread,59s/512MiB caps.
These gates do not compile Rust or establish native parity, first-refusals,
masked transcript/RNG/PCS/proof bytes or privacy acceptance.

AtTinyLlamaT128, avoid103.754MiB of aggregate initial vector payload; final
217.816MiB witness planes stay. This is not simultaneous peak, physical zero
traffic or measured saving. The allocator may already leave zeros untouched.
The current prove_core still overlaps final witness, A and looked/H buffers.
This patch alone does not establishT256 fit. Three cloned D vectors and
sup_s are only counted, unchanged. Added costs are one small public flag Vec,
46 ID marks/dispatch and catalog maintenance. No hidden-value scheduling.

Owner gates, under the shared guard/build/heavy rules:

1. Recompare baseline pins and compile the narrow candidate. Exercise toy,
   padded/growing limb profiles, trainedTinyLlamaT32/64/128 and the current8B
   profile only where its owner has admitted it. No profile expansion here.
2. Compare every final i64 plane including padding and exp-exempt words with
   the unchanged builder and independent integer reference. Deliberately
   malformed/range inputs must preserve the first refusal, before/after stage.
3. Exact native RNG continuation, transcript and deterministic receipt-byte
   comparisons; all frozen receipts and independent fresh verifiers. No mask
   reuse, altered commitment openings or cached hidden input may be introduced.
4. Measure witness initialization/producer time, allocation count and actual
   HWM plus whole-workload phase clocks. Check that fewer allocations lower
   the real maximum or workload time; aggregate bytes alone do not suffice.

T128 retainedGPU-assisted diagnostic142.783s wall has12.872s witness/parity/
extraction. Even deleting that entire clock gives only1.09908x; this patch
is a small allocation/capacity candidate, not a route to50/s by itself.
The107.079s prove_run minus witness still includes boundaries and serialized
segment sink work. Profile slots/commitments before choosing the next large
GPU change, then measure fixed-context resident passes with fresh proofs.
Pure startup and serialization are unsplit; load fraction is not startup.

All six owner R3 samples have matching retained fresh-verifier logs and0
guard/completion status; researcher inspected logs, did not reverify receipts.
Different R2/R3 export identities make529s->56s an uncontrolled comparison.
No trained-shape privacy acceptance or accepted8B proof/pass/token is credited.

Next local: source-derived current trained Lk/lookup-materialization capture,
reconciling prior lazy/typed-reader results with R3/R4 before a separate owner
integration. Preserve wrapping affine semantics, indexed parallel order,
all padded values and all unused-table zero-denominator refusals.
