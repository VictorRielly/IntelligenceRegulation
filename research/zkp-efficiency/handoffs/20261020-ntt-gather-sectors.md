# Native fused NTT gather: bounded handoff, no speed claim

Run `20261020T091854Z-d57182bc`, cycle0101. No merge or native job here.
Evidence: `experiments/ntt-gather-sectors-20261020/README.md`, result/validation
JSON, commands, source and research-code manifests.

Native seam: `hashline/src/gpu/kernels.cu::k_ntt_p1` first source-load loop;
Rust caller `Gpu::ntt_rows`, view and hiding/fused-opening counterparts in
`hashline/src/gpu/cuda.rs`. Current NTT_BLK4096 and default512 threads;
`n_src` remains both row stride and zero-extension bound. The uncompiled
fragment `experiments/ntt-gather-sectors-20261020/p1_load_rotation.proposed.cuh`
rotates one public loop-index bit only for tested logN8..13. Kernel API,
barriers, shared size, butterflies and stores stay literal. No host patch.

Independent public address/zero-tail model passes6239 checks,936 sampled
tile schedules,3326208 logical words,560 identities,nine rejected bad controls
and one expected null. Source audit188 checks/15 mutations/12 pins.

Useful negative: logN>=14 tile source stride is >=4 eight-byte words. Each
active scalar load already has a distinct32-byte sector; a within-tile load
permutation cannot reduce summed warp requests. Native already fuses reorder;
do not port a scheme aimed at deleting a separate upstream reorder pass.

Conditional small-size result: dense aligned logN12 per4096-word tile
4096->2048 requested sectors, unique1024 unchanged; logN13 also halves
requests, logN14 does not. Fixed16-lane shared-bank address demand rises1->2;
actual SASS/wavefronts/cache traffic and time unknown. No logical bytes,
capacity, arithmetic, fresh randomness, transform, barrier or proof removed.
Unknown affected fraction f gives only the hypothetical deletion bound1/(1-f).

Next owner should first measure actual NTT route/logN incidence and exclusive
versus enclosing clocks. Only then decide whether a tiny locked A/B deserves
resource admission. Require compiler/register/spill/shared/global sector and
cache metrics, exact forward/inverse/coset/compact/chunked outputs, seeded
masked rounds/next challenges/complete receipts, all refusals and strict-GPU
gates, fresh independent verification and current privacy gates. Fresh per-
proof pads/masks/salts and every original owner/opening remain mandatory.

Lane caveat: active GPU/frozen R9 have the newer additive pad producer;
older main producer is branched. Their P1 address formulas agree, but this
consumer-only experiment does not certify main q>n producer algebra. A source
audit caught that mistaken cross-lane assumption; failure retained. Profile
and privacy acceptance never transfer between these lanes by source similarity.

The large-size request negative and direct-float64 native-field negative
are useful now. The small-size fragment is a conditional research candidate,
not recommended production integration or measured proving improvement.
Local next: public PCS shape/incidence census, no private telemetry/GPU/build.
