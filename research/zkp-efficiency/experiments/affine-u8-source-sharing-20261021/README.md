# Affine U8 source sharing — cycle0122

Run `20261021T061854Z-553803c5`. **No measured proving gain.** Synthetic semantics and independent
source/cost audits PASS. Dense source-shared bitplanes still cost4.82–5.46x
native U8 helper data. Exact w_s16 aliases have a small conditional benefit:
8MiBdata+0.25MiBmask rows nonDD,2MiB+0.25MiB DD, at frozen8B T128 only.

| Counted frozen 8B per-block geometry | Native U8H data MiB | Shared source bit data MiB | Ratio | Exact-alias H data saving MiB |
|---|---:|---:|---:|---:|
| T128 nonDD | 420.25 | 2255.00 | 5.365854x | 8.00 |
| T128 DD | 390.25 | 2129.00 | 5.455477x | 2.00 |
| T512 nonDD | 2480.50 | 11960.00 | 4.821609x | 0.00 |
| T512 DD | 1760.50 | 9200.00 | 5.225788x | 0.00 |

Inventories count one transformer block at 8B dimensions; no full-stack
proof ran and no simultaneous 32-layer residency is assumed.

`candidate.py::groups/check_bits/check_bundle/dedup` supplies direct research
validators. `native_reference.py` independently interprets the pinned Rust
descriptor source and intersects original affine U8 memberships. `audit.py`
recomputes widths from allowed-set cardinalities and checks native source
roles. No private protocol, native patch, transcript, receipt or verifier.

Signed endpoint, scaled top-bit, Booleanity, ordered-source, padding and
histogram controls pass. 838native descriptors/608families/132564exhaustive
assignments;219independent source/cost checks.6source pins,seed202610210122.

Reproduce sequentially from research root:

```text
python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py probe.py
python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py audit.py
python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py artifact_audit.py
```

OneCPU/nice19;30sCPU/alarm,35sparent,256MiBAS,64MiBestimate. Script clocks
6.287969/0.173758s,
RSS17156/17548KiB. These are checker clocks.

Owner seam: layout::lookups_at; Shape counts/helpers/HIds/claim sites;
protocol::byte_histogram_at/helper construction; argument::helper_sum/SC_TAB.
Full native masking/refusal/profile/privacy and M/receipt/group deltas remain
open. New private bitproof costs are null, notzero. Exact aliases change
layout/transcript; do not mutate accepted profiles. See [dated report](../../progress/20261021T061854Z-553803c5.md),
[ranked queue](hypotheses.json), [source pins](source-manifest.json) and
[handoff](../../handoffs/20261021-affine-u8-sharing.md).

Primary search: [older range examples](https://github.com/BrianSeong99/Plonky3_RangeCheck),
[current compiled components](https://github.com/Plonky3/Plonky3/pull/2292),
[Twist/Shout revision](https://eprint.iacr.org/2025/105),
[Chimera revision](https://eprint.iacr.org/2026/1388). Nine LIVE queries/nine
records; dates/licenses/failures in source-records.jsonl. No upstream timing
or security claim reproduced. Tutorial license remains unknown.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel(R) Core(TM) Ultra 9 185H CPU worker.
Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model proof passes or decode ran. T32–T512 are
symbolic geometries; T512 remains counted-only, unregistered. Larger workloads
remain allowed; longer attention contexts can increase work quadratically.
The complete private8B >=50 proved tokens/s target on RTX5090 or another named
high-end GPU remains unachieved.
