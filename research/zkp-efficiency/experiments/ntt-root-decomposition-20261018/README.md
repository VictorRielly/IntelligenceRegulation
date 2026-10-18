# Native order-64 NTT root compression, cycle 0072

Run `20261018T012105Z-ac328993`, 2026-10-18 UTC. **Exactness and logical
capacity result; no native proving speedup found.** No production patch applied.

For the unchanged native Goldilocks roots from generator 7,
`w_64 = 2^39 mod p`. At stage `s>6`, put `d=s-6` and split
`k = l + 2^d h`, with `0<=l<2^d`, `0<=h<32`. Therefore
`a*w_s^k = (a*w_s^l)*2^(39h)`. Both factors invert for inverse stages.
The first six stages need shifts only, as in the cycle0045 candidate.
Every shift returns the canonical residue, including sign/carry boundaries.
No current root, coefficient order, scale, coset, padding or relation changes.

The locally authored [helper](root_action.proposed.cuh) contains the actual
tested action. A public immutable direction-bound table stores stage `s`
at offset `2^(s-6)-2`, with length `2^(s-6)`. Zero low indices need no
load/product. The helper uses the source-pinned native canonical primitives;
[host.cpp](host.cpp) replaces CUDA qualifiers and `__umul64hi` for a CPU
compilation. Host counter macros compile to nothing in a future device port.
**This is not a CUDA compiler/PTX, device, native-crate or proof-byte gate.**

Reproduce from the research directory with existing system tools:

```sh
python3 experiments/ntt-root-decomposition-20261018/experiment.py
python3 experiments/ntt-root-decomposition-20261018/audit.py
```

Each script enforces CPU0 affinity, nice19, 59s wall/CPU and 512MiB address
space. Main seed2026101872; audit seed2026101873. Compiler command and logs,
commands/status, original source pins and fixture hashes are retained.
The main run compiles only this small local C++ file with one compiler process;
it neither builds the native crate nor installs dependencies. An initial PASS
is retained as `initial-result.json`; zero-only-oracle and zero-schedule controls
were strengthened afterward, with no arithmetic change.

Final main: PASS, 280,366 counted checks and 18 controls, 3.353462s including
compilation/reference work, RSS29,436KiB; compiler24,980KiB. Intel Core Ultra9
185H, one CPU0 thread, no GPU. Full root/action census through log16 in both
directions: 131,070 roots and 131,070 host-helper actions; 14,016 shift checks;
4,096 sampled stage17..32 actions. Complete table construction is capped at
log16, ordinary transforms at log12. These are synthetic public data.

Validation includes forward/inverse parity, direct DFTs, round trips, immutable
table-prefix checks, executed-operation counters and zero-pad skips. Six hiding
rows use direct independent Lagrange interpolation plus `(X^n-1)*pad(X)`;
q>n overlap is included. Controls reject wrong direction/high bits, omitted/
corrupt low roots, missing scale, invalid bounds/generator and invalid pad-skip
premises. Numerical zeros preserve the action schedule. All-zero transform
checks alone miss a corrupt root, while the random fixture detects it.
An unaccessed corrupt table entry also demonstrates why public plan provenance
must be checked by the constructor, rather than inferred from one action.

Independent audit: PASS, 1,452 checks, 6.312016s /24,344KiB. Source-derived
serial tiled DIT and inverse DIF at logs7/12/13/14, swizzle on/off; bit-reversed
coefficient padding with rb2/rb3, skip on/off; 256 original-polynomial Horner
samples. This models indexing and values, not CUDA races, synchronization or
pruned stores. Native pruned-opening, concurrency, cache lifetime and proof/RNG
gates remain unrun. Generic two-table OT algebra also passes 1,048 sample
checks but almost doubles general products in a large stage.

Logical sizing/cost examples for one transform, both-direction table storage:

| Length | Native table bytes | Compressed bytes | General products | Extra shifts vs prior sparse-shift candidate |
|---:|---:|---:|---:|---:|
| 2^12 | 65,520 | 2,016 | 10,272 | 9,951 |
| 2^16 | 1,048,560 | 32,736 | 294,944 | 285,727 |
| 2^20 | 16,777,200 | 524,256 | 6,815,776 | 6,602,783 |
| 2^24 | 268,435,440 | 8,388,576 | 142,606,368 | 138,149,919 |

Larger rows in this table are algebraic counts, never full-size allocations
or transform runs. Baseline full-stage general-product count is `logN*N/2`;
the compressed action has the SAME general-product count as the prior sparse
shift candidate. At log20 the new action makes 9,224,192 nonidentity shifts.
Inverse final scaling remains a separate unchanged general multiply; the
prior inverse-scale shift opportunity is not counted again here.

For a stage, let `half=2^(s-1)`, `rep=N/(2*half)` and `L=2^(s-6)`.
For s>6: stored words `L`, general products/low-root reads
`32*(L-1)*rep`, shifts `31*L*rep`, prior sparse shifts `31*rep`.
For s<=6: no words/general products and `(half-1)*rep` shifts.
Summing from the actual executed first stage handles rb skips.
Both-direction compressed bytes for logN>6 are `16*(N/32-2)`.

`hybrid-census.json` also charges compressing only stages at/above a cutoff,
keeping earlier non-shift tables unchanged. At log16, compress from stage13:
95,232 bytes and +126,511 shifts; from stage16:539,648 bytes and +31,713
shifts (first-six tables implicit in both hybrid comparisons). This is a
possible owner A/B, not a tested hybrid device implementation.

**Limit:** this shrinks the public device-table representation, not all NTT
buffers or host memory. The probe retains full oracle tables, so its RSS is
not a measured memory reduction. Native `NttTables`, temporary stage-major
construction, existing cache ownership and setup costs remain unless separately
changed. Native already caches the uploaded table: no repeated upload/setup
saving is assumed. Compared with sparse-shift dispatch, late general-root
logical load count is unchanged; a smaller working set does not establish less
DRAM traffic. Shifts/reductions add dependencies and may lose on integer issue,
registers, divergence or cached-table latency. Generic OT stage20 uses1,047,040
general products versus524,288 in the original distinct-k stage, despite
shrinking that stage to1,536 root words. Keep that negative cost finding.

The Rust seam is `gpu/cuda.rs::stage_major/ensure_twiddles`: preserve its
monotonic prefix and separate forward/inverse identity, validate native root
provenance/capacity and retain old tables for unmigrated routes. CUDA seams
include k_ntt_p1/ntt_p2_body, dif_pa_body/dif_pb_body, dit_p1_pad_body and
their gather/pruned counterparts. The helper replaces only the corresponding
`gl_mul(value,w)` action; it must not reorder stores or remove pad stages
already skipped. `source-pins.json` pins the current owner sources.

Full ceiling: `Nproved/(T_total-Caffected+Cnew)`; no measured affected NTT
share or candidate timing establishes a numerical private8B ceiling. The
owner's current GPU slot18 round3 arithmetic/module cache is complementary
and remains higher priority. Any future guarded device A/B must first pass
CUDA arithmetic/layout/refusal, native seeded bytes/transcript/RNG, fresh
independent verification and all controls, then price cache/DRAM, instructions,
registers, startup and enclosing workload. No task was queued or integrated.

Primary LIVE source records and exact date/license/access limits are in
`source-records.json`: Kim2020 OT, new older Shivdikar2022 convolution fusion
(different seam), current CUDA/GPU repositories/releases, and a new Sep24,2026
CGLA paper whose q3329/FPGA/exact-FP32 scope does not transfer here. No foreign
code was executed or author speed claim reproduced.
