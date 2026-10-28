# Review candidate: exact scalar interpolation with fixed public constants

Run `20261026T182925Z-b116a67c`; 2026-10-26T18:44:42.316334+00:00. Main/Claude reviews and integrates; no merge here.

Interface: unchanged `interpolate_eval(vals: &[Fp2], x: Fp2) -> Fp2` at
`ops/zkp-mvp/trained-1b/zkp-core/src/mle.rs:252`. The baseline SHA256 is
`b20c8b75c9246471fe1cc395122558eba715f66d9efe1dc4cd5be1750f2e542e`.
Patch: `experiments/sumcheck-public-shape-20261026/finite-difference.patch`.
It is unapplied/uncompiled; generic behavior remains for m<2 or m>6.

For m=2..6, fixed Goldilocks inverse factorials plus reverse forward
differences and nested Newton evaluation replace repeated denominators.
Sample domain/order, points and output bytes stay fixed in the CPU model.
No RNG/transcript/claim-site/PCS or privacy change is proposed. At degree5,
36->5 Fp2 products and6->0 source Fp inversions, adding15 Fp2 subtractions;
one96B stack array and48B constants, initialization/copy/dispatch remain.
The native compiler may already fold some baseline arithmetic.

Validation: 6244 model checks,108fixtures/1836points,
40 synthetic CFS-algebra chains/120rounds,10controls; independent local
Vandermonde/direct-cube oracle. Source/count audit66checks. All source
snapshots, commands, hashes and negative controls retained. Model
1.096540s/15268KiBRSS ononeCPUcore.
No native proof/transcript/receipt/privacy or performance test.

Source incidence: baseR12T128blockverifier370calls,DD32 388; this does not
count native prover or R13LOW+h24. The earlier GPU tree has DevFzcRounds
host interpolation, while nativeR12's CUDA module lacks that implementation.
Core function hashes match; device incidence is not transferred between trees.

Before testing performance, establish exclusive interpolation time and
enclosing proof time on the actual owner build. If immaterial, park it.
If material, run native base/extension/zero/node/unsupported-length field
differentials, generic and grouped rounds, all masked samples and next
challenges, seeded golden receipts and failure/refusal controls; independently
verify complete receipts in a fresh process and retain current privacy gates.
Use shared build/heavy locks. Keep every mask/opening fresh per proof.

End-to-end ceiling remains unknown: free deletion <=1/(1-f) for measured
removable critical-path fractionf, before added costs. Reject any semantic,
byte/refusal/privacy mismatch or slower enclosing workload. No complete
private8B high-endGPU result or >=50tokens/s claim.

Full explanation: [dated report](../progress/20261026T182925Z-b116a67c.md).
