# Exact typed witness readers and lazy lookup preparation

Cycle 0017, run `20261003T230146Z-65ad9aeb`, seed **2026100317**.
No native proof, trained model, GPU job or measured end-to-end improvement.

Run from the research directory:

```sh
python3 experiments/typed-witness-readers-20261003/experiment.py
```

Final run: **2.432 s**, **23,200 KiB** peak process RSS, one Intel Core Ultra
9 185H CPU thread, Python 3.10.12. Script enforces 59 s wall, 55 s CPU,
512 MiB address space and one CPU affinity. Estimated workload <48 MiB.
`command.txt`, logs, exit marker, script SHA-256 and read-only source snapshots
are retained. These clocks measure validation, not witness/proof/verification.

**66** synthetic vectors produce **1,952** indexed exact signed-integer and
Goldilocks byte comparisons. Widths 1/2/4/8, signed and unsigned values,
promotion boundaries, i64 extrema, zeros, nonzero exp analogue and empty
histogram planes are included. Independent decoding uses `struct.unpack_from`
and field conversion uses unbounded modular reduction. Candidate indexed
decode uses `int.from_bytes` and signed magnitude conversion; no full i64
array is required by that interface. A 4,096-entry fixture is **4,096 typed
bytes versus 32,768 i64 bytes**; this is payload, not a global RSS saving.

**25** preparation fixtures compare materialized i64, typed lazy and raw-i64
lazy readers to a separately written preparation driver. **65,816** helper
limbs agree, along with A/H data bytes, offsets, indices and three histograms.
The reference uses polynomial-convolution/Fermat Fp2 inversion and expanded
denominator formulas; the candidate uses conjugate/norm inversion. Context
1/2/3/5/8, heads 1/2/3 with padded strides, odd lookup counts, 0/full-extension
beta, coincident zero tags, arbitrary invalid signed lookup values and
wrapping affine products are covered. One empty fixture tests only readers,
not a native zero-sized profile. Public nonlinear tables are synthetic.

**99** negative checks: 66 vector end bounds, three additional integer/index
refusals, ten semantic/layout mutation controls and **20** zero-denominator
refusals across four schedules. Used/unused byte entries, an invalid signed
value, and unused exp/activation entries refuse in all arms. Controls detect
unsigned decoding, two's-complement field conversion, lost i64 wrap, future
scores read without the mask, wrong head stride, invalid byte bucket alias,
zeroed nonzero E, missing empty histogram plane, lost extension limb and
wrong H limb layout. These are arithmetic/refusal fixtures, not native
transcript/RNG/refusal-order or full-block equivalence tests.

The first execution completed its arithmetic checks but failed while loading
the prior result's geometry key (`KeyError: 'layout_ledger'`). It is retained
under `initial-accounting-key-error/`; no successful result is claimed for it.
The later passing typed/materialized version is retained under
`typed-and-materialized-pass/`, with its exact hash reconstructed and checked
after the raw-reader refinement; final results are at `result.json`.

The baseline `protocol.rs` materializes the i64 witness, six-domain lookup
columns, exp deltas and activation indices. Lazy readers evaluate the exact
affine expression first for histograms and again for helpers. They eliminate
lookup/index buffers but add a second affine evaluation/read. U8 lookups
retain their full padded extent and bucket-zero fallback. Every public table
denominator is still inverted, including zero-multiplicity entries. Values
stay alive through both H pair denominators at the existing S2 seam. Fresh
mask/RNG/PCS/transcript behavior is untouched by the sketch and untested.

| Geometry | Baseline transient payload MiB | Raw lazy MiB | Typed lazy MiB | Typed+lazy removed MiB |
|---|---:|---:|---:|---:|
| synthetic 125M T512 | 1470.641 | 678.391 | 122.363 | 1348.277 |
| unregistered Llama-3-8B T512 | 4888.766 | 2296.516 | 385.184 | 4503.582 |
| unregistered Llama-3-8B T1024 | 13489.031 | 6256.781 | 1106.336 | 12382.695 |
| unregistered Llama-3-8B T2048 | 41826.062 | 19169.562 | 3556.672 | 38269.391 |

Source-counted payload only: excludes A/H committed data, encoded/gathered
data, helpers, weights, allocator, packing checksums/scan costs and retained
suffix cache. No modeled large shape is allocated. 8B rows require five norm
limbs; inspected builder accepts four. The prior conservative typed manifest
keeps E/SUM i64 and requires native validation. Raw-to-typed pack overlap is
**800.754 MiB** at m125 and **2681.699/7363.117/22726.234 MiB** at the three
8B shapes. Packing can raise an earlier peak even while lowering the later
A/H-construction payload. Current builder still generates i64; typed readers
alone do not remove its build-time peak or second forward build.

For native one-term U8 expressions, materialized raw preparation counts
32 bytes/value across source read, output write and two output reads. Raw
lazy counts 16 bytes/value across two source reads; admitted U8/int8 typed
lazy counts 2. General fallback is at most 16. Lazy preparation adds one
term multiply and wrapping add per lookup word: **98,598,912** at m125,
**322,994,176** at the T512 8B count. Index/helper traffic remains additional.
Counts are logical payload, not DRAM traffic or timing. Inlining, variant
dispatch, repeated decode, lost Rayon parallelism and cache behavior can
erase the gain.

End-to-end ceiling: if the removed materialization/conversion work costs M,
added packing/recomputation costs C, and total accepted workload takes T,
new rate is bounded by N/(T-M+C). M, C and T at trained 8B are unknown.
No numeric 8B saving or 50-token/s inference follows. If preparation consumes
only a small phase share, arithmetic-only improvement remains small; memory
benefit matters only if it lowers the actual maximum or enables streaming.
Falsify on native field/byte/refusal/RNG mismatch, public dtype/cache leakage,
overflow, no actual peak reduction, or no enclosing timing gain after C.

Current owner diagnostic remains synthetic 12-block T512, one cold shared-host
pass, RTX 4070 Laptop: 408.609 s wall, 318.22 s run prover including witness
and segment serialization, 12.15 s in-process verify, 484,107,456 bytes,
2,113 MiB sampled VRAM. Independent verification is false; its arithmetic
1.253 positions/s is not accepted private-8B throughput. CLI running status
is stale/interrupted per coordination, no liveness/relaunch inference.
This cycle: **passes=0; countable tokens=0**. Model context, steady/total
verified rates, startup fraction, separate witness/proof/serialization/
verification clocks, lag and drain are unmeasured. Long-context prefill,
resident independent passes and authenticated decode are separate workloads.

See [source search](search-log.md), [reader sketch](reader-seam.rs) and
[owner handoff](../../handoffs/20261003-typed-witness-readers.md). Next research:
public-layout-derived per-plane last-read lifetimes for lazy readers. Test
releasing unreferenced planes after A and lookup-only planes after their H
domain; retain S8/MX/E and G8/A16 through their actual denominator reads.
Measure counted overlapping lifetimes first, then request native owner gates
under the existing shared guard; do not launch a heavy benchmark here.
