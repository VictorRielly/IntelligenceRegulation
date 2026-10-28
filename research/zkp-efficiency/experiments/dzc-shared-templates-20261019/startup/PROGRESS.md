# ZKP efficiency progress

Cycle 0081 — `20261019T131854Z-168a653c`, 2026-10-19 UTC.

**No speed improvement found.** Native-field D helper grouping passes six
synthetic differential fixtures and compiles in 4.63 seconds, but eight
alternating shared-CPU row pairs give medians **6.208→6.525 microseconds**
(5.1% higher with grouping). This is a cache-resident coefficient prototype,
not a full-D sampler or proof benchmark.

Fewer calls (884→19) and a smaller caller frame hide added costs: static
call-chain span **424→504 bytes**, code **33.5→145.7 KB**, and logical requested
row traffic **4,320→8,528 bytes**. Physical DRAM traffic is unknown. All 59
original tables/folds/finals remain. The generic grouping approach is demoted.

Correctness: 780 coefficients, 390 captured-Rust grid/78 off-grid values,
18 messages, 354 original finals and six final relations; seven native-path
controls and a separate 1,465-check boundary/assembly audit pass. Two public
scalar catalogs, N2/8/32, seed2026101981. One Core Ultra9 185H CPU0, nice19;
each experiment capped at59seconds/512MiB. No GPU or production work ran.

[Experiment](experiments/dzc-helper-groups-20261019/README.md) and
[negative handoff](handoffs/20261019-dzc-helper-groups-negative.md).
Integration seam: SC_DZC / SumcheckRounds. A census finds 19 groups share ten
abstract graph shapes. Next local test: share repeated helper code while
charging public address maps, traffic, compiler growth and the full call chain.
Owner whole-prover GPU D/A and completed resident-pass slopes remain first.

Seven LIVE primary-source records append435→442: new ComFuse, NVIDIA fusion
and older LLVM outlining; refreshed StateSync, current release/license,
Plonky3 and arkworks. Known StateSync work was already assessed in cycle0051;
no foreign speedup reproduced. Source/commit fetch failures are retained.

Carried R6/b7 CPU 8B diagnostic: T128,32 blocks,one pass,16 threads,GPU off;
total471.580s,proof region370.137s includes witness94.021/load17.408s;
seal101.279s,D44.833s,receipt922,711,264bytes. Fresh verify34.587s plus
load11.599s. Delete-all-D ceiling1.105058x applies only to that CPU diagnostic.
Serialization,startup fraction and steady slope remain unisolated.

New target proofs/passes/positions **0/0/0**, device none. Target context,
steady/total rates,startup fraction,witness/proof/serialization/verification
clocks unmeasured. No prefill,resident series or decode ran. Larger workloads
remain allowed; attention can grow quadratically. Complete private8B >=50
proved positions/s on5090/named high-end GPU remains unchanged and unachieved.
No masks or private openings reused; only research files written.

[Dated report](progress/20261019T131854Z-168a653c.md). Saved reports do not establish delivery.
