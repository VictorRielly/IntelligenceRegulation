# FZC arena and implicit affine tables — cycle 0096

Run `20261020T041854Z-f70297a5`, 2026-10-20 UTC.
**No proving speed improvement measured. No native patch or build.**

The previous mixed arena has now been checked in an authored Python model
over the native field definition, `p = 2^64 - 2^32 + 1`, `u^2 = 7`, using
the actual slot-18 FZC polynomial. A further candidate avoids storing the
derived GL/PL tables and computes their affine values from staged A values.
This is mathematical and address-layout evidence. It does not execute Rust,
CUDA field instructions, native sumcheck masking or Fiat–Shamir, a PCS, a
receipt encoder or an independent receipt verifier.

`reference.py` independently implements schoolbook polynomial convolution
modulo `u^2 - 7`, the original SC_FZC closure, and explicit Boolean-weight
MLE evaluation of the original tables. `probe.py` uses tuple Karatsuba
arithmetic, an offset arena, in-place/disjoint four-entry fused folds, and
the split polynomial with its affine derived values. The two implementations
share public parameters and field constants, not arithmetic/fold/poly code.
Both were authored by this researcher; this is not an external code review.

Final result: **108 fixtures, 468 modeled rounds, 11 negative controls**.
The fixtures cover cube logs 3/4/6 (8/16/64 entries per table), support on/off,
base or extension A at round zero, empty/nonempty pad weights, degrees 4/5,
device-only or host-tail-log 1, and dense/mixed/implicit layouts. They use
seed `2026102096`, with per-case seeds in `cases.json`. Every fold is
compared with direct MLEs of the original tables; all round sums, recovered
s(1), canonical field bytes and finals match. A synthetic SHA-256 recurrence
derives extension challenges from matched round bytes. It is explicitly not
the native transcript or a masked proof. Arbitrary synthetic field tables
are not valid transformer witnesses and do not prove a zero-check claim.

Negative controls reject unchanged constructor full slices, unchanged
uniform-stride first/later fused folds, generic fold, round reads, packing
and finals; omitted affine constants; treating an affine form on differences
as a linear form; compressed storage without raw eligibility; and independent
residue-lane multiplication mistaken for extension multiplication.

The source census indexes **107 selected sites in 21 functions**, including
43 address/allocation/stride sites, across the pinned active GPU source.
It covers the constructor, split and legacy round variants, raw source reads,
derived writes, generic fold, host-tail pack and finals. It is lexical and
does not prove complete-program reachability or validate the generated CUDA.
The first source-facts pass incorrectly selected another constructor's
identical slice expression at line 3225. Scoping the anchor to
`impl DevFzcRounds` corrected it to line 4332; earlier command logs/hashes
remain retained. Base-address definitions were added to the selected census.

The baseline allocates `16*kd*L` bytes. Mixed storage gives the 17 resident
raw A/H tables 3..19 half capacity and retains full Eq/public/derived tables.
The new implicit variant retains only original tables in global storage and
derives GL/PL into shared staging each round. At illustrative F-cube
`L = 2^21`, support on, `k=21`, `kd=23`:

| Requested table storage | Dense | Mixed | Mixed + implicit GL/PL |
|---|---:|---:|---:|
| MiB | 736 | 464 | 400 |

The additional 64 MiB request reduction is not an observed VRAM saving.
The prior partial allocation model was extended across 72 schedules and
checked by its separate interval oracle, with 72 corrupted-capacity controls.
All **24 resident cases save zero additional backing**. Some chunked T128
cases save 64 MiB more backing than mixed storage, 336 MiB relative to dense.
The noncompact support/T128/one-slice projection is
1890.932186 -> 1618.932186 -> 1554.932186 MiB; resident stays
9097.779842 MiB. These combine pinned R8 geometry with a different GPU
allocator revision and omit other slots, opening scratch, earlier history,
H helper scratch, retries, multiple caches, driver and allocation granularity.
They do not establish a complete GPU peak or device fit. Repetitions
1/2/4/8 are allocation slices, not complete model passes.

Eliminated work: derived global writes and folds, plus the smaller reservation.
For a device-only route, the baseline computes the affine forms at L endpoints
once, then folds `(1+support)*(L-1)` derived values. The implicit variant
computes the forms at `2L-2` endpoints, an increment of `L-2`, and eliminates
`16*(1+support)*(4L-3)` bytes of derived writes/fold traffic. At support and
L=2^21 this traffic is just under 256 MiB. This is symbolic source accounting,
not measured traffic. Extra shared-memory work and a block barrier per later
chunk, field operations, register lifetimes and offsets can erase any gain.
The full-workload ceiling is unknown because the exclusive slot-18 share and
actual allocation backing at the peak have not been measured.

Owner seam: `DevFzcRounds::new/try_round/try_fold`,
`fzs_ld/fzs_impl/fzs_derived_at`, `k_sc_fold`, `k_fzc_pack`,
`k_fzc_finals`. A possible interface is a public-shape `ArenaLayout` holding
offsets, capacities and a mode; implicit mode stages original K0 tables,
recomputes shared derived slots, and does not globally fold derived tables.
Do not change only the allocation or the first kernel. Preserve a dense
fallback for raw-disabled, unfused and unsupported paths. See
`../../handoffs/20261020-implicit-affine-fzc.md` for the full review contract.

Commands, from the writable research directory:

```text
python3 experiments/native-fzc-arena-20261020/run_bounded.py probe.py
python3 experiments/native-fzc-arena-20261020/run_bounded.py census.py
python3 experiments/native-fzc-arena-20261020/run_bounded.py capacity.py
python3 experiments/native-fzc-arena-20261020/run_bounded.py validate.py
```

Each authored leaf is restricted to one CPU, nice 19, <=59 CPU/wall seconds
and 512 MiB address space. Latest field/address probe: 14.2743 s, 17060 KiB
RSS on an Intel Core Ultra 9 185H; partial capacity study: 0.6835 s,
48784 KiB RSS. These are experiment clocks, not witness/proof clocks.
No production source, Git metadata, runtime, receipts, calibration, safety
gates or reviewer files were changed. No GPU job, native build, installation,
downloaded-code execution, external write/message or escalation occurred.

New independently verified complete proofs/passes/positions: **0/0/0**.
Actual model context/device: none; no accelerator used. New witness, proof,
serialization and verification clocks, startup fraction, steady-state and
total-workload proved rates: **unmeasured**. No long-context prefill,
complete resident-pass sweep or decode ran. Larger workloads are allowed;
attention can grow quadratically. The complete private 8B >=50 proved tokens/s
target on RTX 5090 or another named high-end GPU remains unachieved.

The carried owner CPU result remains separate: 8B T128/L32, one 16-thread
pass, GPU off, total 478.737 s (0.267370 positions/s), prove_run 393.785 s
including witness 98.348 and load 17.595 s. Sealing 84.824 s overlaps those
phases; do not add it twice. Receipt 922711264 bytes; fresh verification
42.709 s plus 13.681 s load. It was not rerun or reverified here. Its startup,
steady slope and isolated serialization are unknown. Owner next-token runs
are different workloads. No D33 extension beyond its accepted frozen R7
TinyLlama T32 scope is inferred; D27/D30/D32/D34 obligations remain.

Nine LIVE primary source records were appended (548 -> 557). The useful new
filter is [ntt-tensorcore](https://github.com/MMRROOO/ntt-tensorcore): its
field and FP64 route differ from native Goldilocks; its dates, source commit
and actual license text could not be verified. Recent
[SP1 PR2993](https://github.com/succinctlabs/sp1/pull/2993/files) retains all
assertion roots while simplifying public constants and capping scratch.
[zkLLMPoT v2](https://arxiv.org/html/2610.08258v2) uses different arithmetic
and operator aggregation. [zkIE](https://github.com/trustless-ai/zkIE) states
its witness is public and its verifier reruns forward work. Those source
claims were not reproduced. Exact URLs, dates and failed fetches are recorded;
ICICLE and SP1 release commits were inspected, with license scope separated.

Next: owner telemetry must establish actual raw eligibility and lower fresh
backing at the real peak. Locally, derive a public-coefficient-aware operation
and barrier budget for shared GL/PL rematerialization versus stored folds,
including host-tail break-even; reject it if it only reduces a request that
the pool already satisfies or increases the enclosing cost. Native builds,
shadow masked rounds, receipt identity and fresh verification belong to the
owner under shared locks. No merge by the explorer. Saved reports do not
imply external message delivery.

Late source check: [Theodosian](https://arxiv.org/html/2512.18345v2)
adds an L2/NoC measurement and cache-capacity batching lead from older FHE
work; its gains are not transferred to proving.
[NTTSuite](https://arxiv.org/html/2405.11353v1) adds older no-copy layout
ideas, with different fields and timing scope. A search hint gave an unrelated
arXiv identifier for NTTSuite; the primary pages exposed that error and the
hint was rejected. Neither source was executed. Rank 4 is the most useful
local bounded experiment here; ranks 1–3 require owner device/prototype/telemetry
work outside this research lane.
