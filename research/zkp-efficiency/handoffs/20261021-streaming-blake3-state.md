# Review handoff — streaming BLAKE3 scratch state — 2026-10-21

Candidate only; no native performance claim or production modification.

Interface: current `Gpu::commit_zk_chunked`, `commit_chunked`,
`commit_chunked_upload` in `hashline/src/gpu/cuda.rs`; shared
`k_hash_cols_stream` in `hashline/src/gpu/kernels.cu`. Seven pins in the
[source manifest](../experiments/commitment-leaf-buffer-20261021/source-manifest.json).

[Uncompiled patch](../experiments/commitment-leaf-buffer-20261021/state-memset-elision.patch)
sets stack_len=0 at public row0==0 and removes three whole-state clears.
It retains the existing24-level capacity and every compression. The stronger
dynamic-depth memory reduction is a separate model, NOT in the patch.
Every plan starts0, nonfinal boundaries align128rows, and launches are ordered.
Every consumed CV must have been written in the same proof; prior-proof bytes
and post-final stack lengths are never trusted. No extra kernel or sync proposed.

Hash/state model: **328,043 checks, 27 synthetic matrix shapes and 11 control types PASS**.
Independent labelled-subtree/source/cost audit: **1,050,682 checks, 1,024 chunk counts,
seven native source pins PASS**. This researcher authored both models; the cryptographic
reference is independently implemented in the already-installed `blake3` 1.0.9 package,
one thread. Final checker clocks/RSS: 4.605481s/29,724KiB and
1.341245s/15,532KiB. These are diagnostic clocks, not proof clocks.
Every leaf has one-core affinity, nice19, 30s CPU/alarm, 35s parent timeout,
256MiB address-space limit and 64MiB estimated experiment memory.

The model tested up to11056 rows, partial tails, multi-launch plans, poisoned
entire storage including count and fresh contents on reused backing. Endian,
root/counter, stale count, short depth/input and shape-growth controls fire.
The installed independent blake3 binary/version is pinned in hardware.json;
not the separately inspected upstream release. No native masks/proof ran.

Optional public depth ceil(log2(ceil(rows/128))) needs host/kernel offset agreement
and native arithmetic guards; single chunk uses0CVlevels. Request savings38MiB
T128 /68–72MiB T512 per commit are conditional frozenR9 inventories. T512 is not
admitted and LOW/HIGH are excluded. Pooled::get_mut returns FULL best-fit backing,
so actual clear bytes can exceed193*nn*4; physical savings may be zero even with
smaller requests. Do not sum sequential A/H requests as one peak or convert bytes
into elapsed savings. Added public conditional may have nonzero device cost.

Owner gates before integration: inspect current tree/pins; failing-first poisoned
buffer/native hashes for all three entrypoints, 1/2/3/many chunks and tails; salted
leaves, Merkle roots/paths, exact full receipt and fresh independent verify;
mask/RNG/transcript/privacy/refusal gates; allocation/launch/download failures,
resident fallback and non-ZK callers. The removed memset API's own error no longer
exists; infrastructure-failure behavior needs explicit review. No stale data may
be exported or consumed. Do not carry a TinyLlamaCPU acceptance to8B/GPU.

Then under owner shared build/heavy locks record native incidence, actual
capacity, clear/request sizes, exposed device/host clear time and enclosing
verified workloads at fixed context1/2/4/8 passes. Unknown removable fractionf
gives free-deletion bound1/(1-f), not a forecast. Falsify on any mismatch/stale
read/privacy drift or enclosing regression; deprioritize if measured effect
is immaterial. This handoff is saved locally, not a delivered external message.
