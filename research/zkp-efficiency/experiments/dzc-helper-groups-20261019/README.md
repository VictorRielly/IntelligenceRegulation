# Native D helper groups: bounded negative result

Cycle 0081, `20261019T131854Z-168a653c`, 2026-10-19 UTC.

Generic public-DAG grouping passes the coefficient oracles and bounds native
compilation, but provides **no observed speed improvement**. The CPU row
median rises by 5.1%, the static call-chain stack extent increases, and code
and logical scratch traffic grow. Do not promote this candidate on its much
smaller call count or caller frame alone.

The baseline is cycle 0080's **use-driven** coefficient graph with separate,
non-inlined Fp2 adapters. Both arms have the same graph, parameter slots,
primitive counts, source loads, degree-four outputs and original final order.
This is not a comparison against the installed native D sampler. Native field
source is byte-identical to its pinned project source. The captured original
D/catalog oracle still uses the previously documented field/Shape/Layout
substitutes; full native profile admission is outside this test.

`grouping.py::partition` cuts the public 1,167-node scalar DAG into 19 groups,
each at most 78 scalar nodes. It chooses low crossing-state boundaries in a
48–80-node interval, using dependencies and widths only. No witness value or
challenge value selects code or removes zero work. `emit` inlines native field
arithmetic inside each separate group. Runtime raw endpoints, proof-local
Fp2 parameters and canonical base parameters remain inputs. A validated
13-slot scratch allocation carries crossing values; all inputs to a group
are loaded before output stores may recycle slots.

| Observed scope | Scalar-call baseline | Grouped candidate |
|---|---:|---:|
| Logical field primitives per row | 884 | 884 |
| Executed row call boundaries in emitted straight-line code | 884 | 19 |
| Caller local stack subtraction, bytes | 360 | 208 |
| Caller saved-register pushes, bytes | 48 | 40 |
| Static deepest span below exported entry RSP, bytes | 424 | 504 |
| Sum of relevant ELF function bytes | 33,543 | 145,739 |
| Sum of relevant static instruction lines | 7,171 | 39,737 |
| Logical requested bytes per row, excluding original folds | 4,320 | 8,528 |
| Cache-resident row median, microseconds | 6.2083 | 6.5255 |

The call-chain span includes caller allocation, callee return addresses,
saved registers and leaf red-zone extent. It excludes the exported caller's
own return address, harness/enclosing stack and dynamic instrumentation. The
largest group leaf uses 248 bytes including its red zone. The smaller caller
frame therefore does **not** reduce the complete static call-chain extent.

The baseline's 4,320 logical bytes are 118 raw Fp2 loads, 129 parameter Fp2
loads, 36 base-u64 loads and five output Fp2 stores. The candidate adds 127
crossing Fp2 loads, 131 crossing stores and five final scratch loads:
**4,208 additional bytes**. These are source-level requested accesses, not
physical cache misses, spill bytes or DRAM traffic. Both arms retain all 59
original tables, their 118-read/59-write folds, and their original final
evaluations. Those folds add 59 each of field add/sub/mul. Common reduction,
coefficient-to-message conversion, planning and the enclosing proof remain
outside both row timing and this byte total.

Run from the research directory, serially:

```bash
python3 experiments/dzc-helper-groups-20261019/run.py --native-field
python3 experiments/dzc-helper-groups-20261019/audit.py
python3 experiments/dzc-helper-groups-20261019/bench.py
```

Each experiment limits itself to one affinity CPU, nice 19, 59 seconds
CPU/wall and 512 MiB address space. Installed rustc 1.97.1, opt-level 1 and
one codegen unit; no Cargo, dependencies, GPU or foreign implementation runs.
Intel Core Ultra 9 185H CPU0, WSL2. Native main: 7.215940 seconds including
4.626792 seconds compilation; main/compiler RSS 38,152/131,768 KiB. Audit:
0.122996 seconds, 21,136 KiB. Microbenchmark including its harness compiler:
1.181911 seconds; benchmark child 0.841757 seconds, child/compiler maximum
RSS 123,564 KiB. These are bounded shared-host diagnostics.

Six synthetic fixtures, two public profile scalar catalogs, N=2/8/32,
seed 2026101981: 780 compiled coefficients, 390 captured-Rust grid values,
78 off-grid values, 18 messages, 354 original finals and six final relations
agree with independent Python clause/direct-cube references. Thirty-six
zero-input bindings preserve graph and runtime parameters. Seven native-path
controls detect stale/corrupt parameters, signed-base wrap, endpoint swap,
lost degree four, stale recovered claim and a tampered original final.
The separate 1,465-check audit reconstructs crossing ownership and initialization,
checks slots/source pins/assembly/ELF sizes, and includes missing-store and
stale-slot controls plus misleading caller-only/uncharged-traffic controls.

`bench.rs` compares 32 arbitrary synthetic canonical input rows and a single
synthetic parameter pack, checks all 32 outputs, warms 256 rows per arm and
times eight alternating pairs of 8,192 rows. The baseline/grouped median
ratio is 0.95139; seven of eight pairs favor the baseline. This is a small
cache-resident row test with artificial scalar-call baseline adapters, not
whole-D, full-stack, GPU, quiesced, p50/p95 or startup/resident measurements.
No statistical or hardware-cause attribution follows from these samples.

The tested hypothesis removed scalar ABI boundaries, adding frontier stores,
group frames and native inlined code. It failed its observed improvement gate.
The earlier fully inlined >40-second compile failure remains preserved in
cycle 0080; this 19-group compilation completes within the limit. That is a
compiler feasibility result, not a proving speed win.

`template-census.json` finds 19 groups normalize to ten opcode/dependency
shapes when public load addresses become arguments: six instances of one
shape and five of another. This is only a census. A **new** question is
whether code sharing for these repeated shapes can avoid code growth without
extra field work or excessive parameter/index traffic. Charge explicit slot
maps, dispatch and full call-chain storage; reject stale/aliased slots and any
value-dependent planning. No outlined template implementation is tested here.

Integration seam: pinned GPU-lane `SC_DZC` in `private_block/argument.rs`,
through `SumcheckRounds`. Research interface is
`driven(raw: *const Fp2, params: *const Fp2, bases: *const u64, out: *mut Fp2)`.
Owner gates include actual profile/parameter provenance, seeded proof bytes,
RNG/refusal behavior, extension and mask rows, original PCS/finals, fresh
verify/tamper tests, joint-view privacy and enclosing phase clocks. No new
claim/opening, mask reuse or weakening is proposed. Main/Claude reviews;
no production edit or merge is part of this cycle.

The carried R6/b7 CPU 8B T128/32-block/one-pass diagnostic has total 471.580
seconds and D=44.833 seconds. Removing **all** D at zero cost bounds only that
CPU diagnostic at 1.105058x; our candidate is a strict subset of that cost.
This is not a GPU or candidate speed prediction. See `target-accounting.json`
for carried witness/proof/sealing/verification clocks and explicit unknowns.

Seven LIVE source records append 435→442: new ComFuse, NVIDIA fusion and older
LLVM outlining; refreshed StateSync-GKR, its release/license, Plonky3 and
arkworks. Exact URLs, dates, license scope and failed source/commit fetches
are recorded. StateSync was already assessed in cycle 0051 and later cycles;
it is not a new discovery. No foreign speedup or security result is reproduced.

New target proofs/passes/positions: **0/0/0**, target device none. Target
context, steady/total rates, startup fraction and witness/proof/serialization/
verification clocks are unmeasured. No long-context prefill, resident-model
pass series or decode ran. Longer workloads remain allowed; attention may
grow quadratically. Complete private 8B at >=50 proved positions/s on a
5090 or named high-end GPU remains unchanged and unachieved.
