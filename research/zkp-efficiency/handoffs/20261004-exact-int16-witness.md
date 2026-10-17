# Exact int16 FFN-down adapter and clock attribution — review handoff

Cycle0022, `20261004T040146Z-c6dec297`, 2026-10-04. Nothing integrated.
Only main/Claude reviews and promotes this; no heavy/GPU job queued here.

An exact arithmetic prerequisite passed, with no measured speedup:
[experiment](../experiments/int16-split-witness-20261004/README.md),
[result](../experiments/int16-split-witness-20261004/result.json),
[uncompiled Rust primitives](../experiments/int16-split-witness-20261004/split-review.rs).
The prototype is Python; Rust primitives are a review interface, not compiled
code or a native/CUDA patch.

Patch seam: candidate `hashline/src/private_block/witness.rs::matmul_in_out`
line312, specifically the FFN-down call line685 after the product's existing
int16 check. Source SHA256 b9b66c024e7ca68d2a0ae4ba46241eb2abbccc8c8d94fe828041abbc710850ad.
Retain padded input/output strides and full K reads, weight orientation,
existing biased remainder and first-refusal order. No generic i64-to-int16
cast, changed precision, clamp, mask reuse or new private cache metadata.

Interface: packed signed-byte l=(x&255)-128,h=x>>8; exact8I*8I->32I products
with integer alpha1,beta0; output i64 `L+256H+128sumW`, widening first.
K<=16,384 has proven public bounds. Optional stacked rows `[l;h]` let one call
produce both partial groups. AllK coordinates consumed by the native helper
must also enter the weight-column sum. Valid padded token outputs remainzero;
their packed zeros cannot receive an unmatched correction. Public P1 sums may
be cached by immutable model+shape+layout identity; P3 sums stay private.

Validation: exhaustive65,536 int16 values/393,216 products,42 dots up to16,384,
72 matrices/two orientations/two scheduling models,6,162 rounding cases,
106 suffix fixtures and17 mutations+2 domain controls. One CPU thread,
0.660s,16,900 KiB RSS,seed2026100422. Independent checked direct integer,
byte-decode and floor-division references. No native transcript/RNG/PCS proof.

First useful owner action is finer clocks. Current run.rs starts `Phases`
before boundary preparation and `src.witness`; protocol.rs's first A mark
therefore includes those costs. Historic86.691s is NOT allocation-only.
The initial73.36s chain build also computes/drops all12 witnesses. Do not
subtract one chain pass twice or treat that time as measured startup.
The current source-to-historical-ELF match is not established. Source pins and
timing-only historical excerpts are retained in the experiment directory.

For T512/Kpad16,384/N4,096: counted32 MiB extra packed/partial scratch before
BLAS workspace; cached sums16 KiB. Input/output/weights still live. Added
byte work, pack, synchronization, transfers and replay costs may erase all
benefit. cuBLAS integer alignment/transpose/epilogue restrictions need actual
device validation. Current native GPU module has no inspected GEMM seam;
the owner must add an adapter rather than assume existing NTT kernels apply.

Review gates: exact native differential witnesses at toy/padded shapes,
MIN/MAX/support/dirty buffer/overflow/first-refusal controls, full RNG
continuation and receipt-byte parity, independently verified full stack,
matched-build scoped CPU/GPU A/B with all added costs and peaks under common
resource locks. P3 device handling/privacy requires its own review.
A change in accepted/refused relation or any enclosing regression rejects it.

0 full-stack passes/0 counted tokens this cycle; all target rates and proving
clocks unmeasured. Prior cold synthetic12-block125M/T512/4070 diagnostic is
not a private8B/5090 result and lacks independent verification. Target50/s
unachieved. Next local question: can tiled exact reconstruction+requant
stream the existing output while avoiding full partial buffers?
