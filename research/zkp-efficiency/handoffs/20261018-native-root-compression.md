# Native late-stage root compression: review candidate

Cycle0072, run `20261018T012105Z-ac328993`. [Experiment, costs and pins](../experiments/ntt-root-decomposition-20261018/README.md).
**No native proving speedup found; unapplied host-tested arithmetic candidate.**

Interface: `root_action(a, low, stage, k, inverse)` in
[`root_action.proposed.cuh`](../experiments/ntt-root-decomposition-20261018/root_action.proposed.cuh).
Requires canonical native gl primitives and a public immutable native-generator7
plan. Stage s>6 stores `2^(s-6)` consecutive low powers at offset
`2^(s-6)-2`. Split `k=l+2^(s-6)h`: multiply by the low power if l!=0,
then canonical-shift by `2^(39h)`; invert both factors for inverse stages.
Stage<=6 keeps the prior shift action. Host-only instrumentation defaults to
no-op for any later CUDA compilation; no CUDA compilation has been attempted.

At log16, both-direction root words1,048,560B ->32,736B; at log20,
16,777,200B ->524,256B. General-product count equals the prior sparse-shift
candidate, but adds285,727 /6,602,783 shifts per respective transform.
This is a public-table capacity/cache candidate, not 32x less traffic or speed.
The probe retains full oracle tables and measures no peak-memory saving.
Native host tables/temp construction still cost memory; public GPU tables are
already cached. Root logical loads for general late butterflies stay the same.
Generic two-factor OT is cost-demoted: stage20 nearly doubles general products.
Hybrid largest-stage-only census is available to limit added shifts.

Validation: final main280,366 checks/18 controls,3.353462s including compilation,
29,436KiB RSS; audit1,452 checks,6.312016s/24,344KiB; Core Ultra9 185H CPU0,
one thread, seed2026101872/audit+1, each59s/512MiB AS. All131,070 native roots
and actions through log16, sampled higher stages, direct DFT/Lagrange hiding
rows including q>n, pad skips and operation counters pass. Independent tiled
DIT/inverse DIF, swizzles, bit-reversed padding and original-polynomial samples
pass. Zero-only oracle and unaccessed-corruption controls preserve constructor
provenance obligations. No native transcript, mask/RNG, proof, GPU or privacy
theorem result. No private inputs copied.

Current owner seam (read-only source pins retained):
`ops/zkp-mvp/sonnet-hardening/hashline/src/gpu/cuda.rs::stage_major/ensure_twiddles`
for constructor/cache integration; `gpu/kernels.cu` k_ntt_p1/ntt_p2_body,
dif_pa_body/dif_pb_body, dit_p1_pad_body and gather/pruned counterparts.
Keep full tables for unmigrated routes, validate stage/direction/capacity/root
identity, preserve the monotonic cache prefix and mixed-size/mixed-direction
lifetimes. Never infer a root from unvalidated external metadata. No masks,
private openings, proof profile, padding, inverse scale or coset changed.

Owner/Claude next: inspect this helper and the actual row-width/cache profile;
if useful, propose a guarded device A/B alongside the old table/first6 shift
path, perhaps compressing only stage>=13. Gate exact CUDA arithmetic, all
mapped/DIF/swizzled/pruned/pad routes, q>n and stale-cache/refusal controls;
then native seeded proof bytes, transcript and RNG/extension parity, fresh
independent verifier. Price instructions/registers/occupancy, physical traffic,
module/table construction/upload and enclosing complete workload, including
witness/serialization/verification, startup and drain. Reject on any mismatch,
privacy/refusal change, peak regression or no enclosing gain.

Full private8B ceiling unknown without affected-phase/new-cost measurements.
>=50/s target unchanged/unachieved; new target proofs/passes/positions0/0/0.
Owner slot18 arithmetic/module cache and complete resident-pass measurements
remain higher priority. No integration, build/GPU request or external message
was sent. A saved handoff does not establish delivery.
