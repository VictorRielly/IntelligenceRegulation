# FZC affine arithmetic budget — cycle 0097

Run `20261020T051854Z-d5b6bbb8`, 2026-10-20 UTC.
**No proving speed improvement measured. No native patch, build or GPU run.**

The previous cycle proposed eliminating the global GL/PL affine tables from
slot 18. This cycle counts the recomputation cost against the pinned active
GPU source, and tests a smaller alternative: keep the existing tables, but
derive each round-zero value/difference pair directly. Precompute
`effective_pad[j] = mu_pad * pad_weight[j]` from the current public slot
descriptor. Constants enter the value only; differences use the homogeneous
linear form. All global table values, later folds and barriers stay in place.
The historical lean evaluator already uses value/difference linear forms;
the current raw split derivation still calls its endpoint evaluator twice.

The authored Python experiment passes **36 fixtures, 144 rounds, 1,599 checks
and seven negative controls**. Fixtures have 8/16/32 entries per table,
support on/off, 0/1/3/8/11 nonzero public pad weights, base or extension A at
round zero, and several allowed power-of-two requant constants. Seed is
`2026102097`, with case seeds and round hashes retained. Candidate arithmetic
follows the source's Karatsuba primitive calls; a separate schoolbook quotient
field, original SC_FZC polynomial and explicit original-table MLE give the
reference. Canonical round bytes and stored high endpoints agree. Challenges
are a synthetic SHA-256 recurrence, not native Fiat–Shamir. These arbitrary
synthetic tables are not valid transformer witnesses.

Seven controls reject omitted/stale preweighting, affine constants in
differences, missing extension differences, omitted public pad support,
incorrect high stores and componentwise extension multiplication. A separate
**720-case source-accounting study** checks event schedules against closed
forms with seven accounting controls; all pass. The raw-only option includes
reconstructing `hi = lo + difference` for its unchanged global high store.
The first partial cost output omitted that reconstruction; it is retained
under `before-store-reconstruction/` and superseded by the final results.

At an illustrative **L = 2^21 entries, support on, 11 nonzero pad weights,
no host tail**, final source-call deltas from the existing raw split path are:

| Candidate | Device base products | Device base adds + subs | Derived-operand shared reads | Saved derived global traffic | Extra chunk barriers |
|---|---:|---:|---:|---:|---:|
| Round-zero paired derivation, tables retained | -6,291,456 | -65,011,712 | -304 MiB | 0 | 0 |
| Full implicit tables, literal endpoints | +98,566,040 | +364,904,088 | +911.999 MiB | 255.999908 MiB | 32,772 |
| Full implicit tables, paired/preweighted | +85,983,134 | +226,492,122 | +303.999 MiB | 255.999908 MiB | 32,772 |
| Implicit PL only, paired/preweighted | +56,623,039 | +180,354,852 | +175.999 MiB | 127.999954 MiB | 32,772 |

These are **source calls and logical operand reads before compilation**,
not instructions, actual shared/DRAM transactions, timings or a GPU memory
peak. Shared counts assume unused loads are eliminated, and omit parameter
staging/common polynomial evaluation. Barriers are summed across CTA chunks;
they are not 32,772 serial device-wide waits. Register pressure, cache reuse,
occupancy, hardware wave scheduling and compiler common-expression elimination
can change the result. A table cube is not a token context.

Preweighting adds 11 host Fp2 products here (33 modeled base products),
at most 176 parameter bytes to transfer/store, and coefficient staging per
round-zero block. A separate staged coefficient array needs up to 176 shared
bytes per block and its parameter loads; preserve the original descriptor for
fallbacks and the host tail. The proposed setup is once per **sumcheck**, not
once per model or workload. It must be recomputed after each slot's own draws.
No mask, commitment opening or private value is reused.

For a host transition to H = 2^tail_log entries (or H = 1 without a tail),
the stored path derives L endpoints and folds L-H derived outputs per table.
Full implicit mode derives 2(L-H) endpoints. Avoided derived global bytes are
`16*d*(4*L - 3*H)`, where d is 1 or 2. Generic boundary folds use five base
products per Fp2 multiply; fused folds use three. The study includes that
distinction and host-tail thresholds through n-2. The original k tables'
packing, transfers, host rounds and finals are common, not removed work.
Dropping only the dead derived boundary fold saves merely 96 B in the example,
or 6 KiB at tail_log 6: useful correctness accounting, not a speed lever.

The dense-pad full-rematerialization option now falls behind the smaller
round-zero option. It needs about 0.3203 additional base products per saved
global byte before its added additions/shared work/barriers. This is only one
term of a break-even budget. Saved source bytes must actually reduce exposed
critical-path work, and actual backing/fit may still dominate the decision.
The prior partial pool model saved **zero additional backing in 24/24 resident
cases**, so the 64 MiB request saving cannot justify new compute by itself.
Sparse PL with 0/1 public nonzero weights reduces counted products, but retains
the new barrier and requires actual descriptor/peak evidence; no dispatch on
private zeros is proposed.

The round-zero candidate's end-to-end ceiling is unknown. If the exclusive
raw-derived phase fraction is f, even deleting it costs at most a factor
`1/(1-f)`; this candidate removes only part of it and adds setup. There is no
complete GPU workload measurement of f. An arithmetic reduction does not show
50 complete proved positions/s. Falsify the candidate on any round, high-store,
mask/challenge, refusal or receipt mismatch, unavailable raw eligibility,
compiler removal of the supposed redundancy, or enclosing elapsed regression.

`candidate_pair.cuh` is an **uncompiled adapter sketch**, not an applied patch.
The actual seam is `fzs_impl`'s raw round-zero phase 1b, replacing its two
`fzs_derived_at` calls; host preparation belongs at `DevFzcRounds::new` after
the public descriptor exists. The owner must stage the current coefficients,
retain all existing global stores, shared stores and the barrier, and preserve
raw-off / split-off / unfused / tail / dense fallbacks. The source manifest
pins eight native files, unchanged from cycle 0096 and at final validation.
The current CPU R9/DD tree is a distinct revision and needs its own gates.

Commands from the research directory:

```text
python3 experiments/affine-fzc-budget-20261020/run_bounded.py pair_probe.py
python3 experiments/affine-fzc-budget-20261020/run_bounded.py cost_probe.py
python3 experiments/affine-fzc-budget-20261020/run_bounded.py validate.py
```

Final Python algebra time 1.939 s, max RSS 16,820 KiB; cost study 0.349 s,
13,016 KiB, on Intel Core Ultra 9 185H / WSL2. Each authored leaf is one
thread on CPU 0, nice 19, <=59 seconds CPU/wall and <=512 MiB address space.
Logs, source/dependency hashes, commands, cases and hardware are retained.
No installation or downloaded-code execution occurred.

Carried owner baseline, not rerun/reverified here: complete 8B stack,
T128/L32, one CPU pass at 16 threads, GPU off: total 478.737 s,
0.267370 proved positions/s; prove_run 393.785 s includes witness 98.348 s
and load 17.595 s. Sealing 84.824 s overlaps those regions. Receipt
922,711,264 B; fresh verify 42.709 + 13.681 load s; recheck
34.395 + 10.739 load s. Startup fraction, steady slope and isolated
serialization remain unknown. The owner's new R9 DD T128 run reports
474.9 s versus 478.7 s, shared box, n=1, explicitly no measurable change;
it is built and under soundness/privacy review. Its smaller committed count
is not a reproduced speed improvement. Next-token runs are separate workloads.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context and accelerator: none. New witness/proof/serialization/
verification clocks, startup fraction, steady-state and total-workload proved
rates: **unmeasured**. No long-context prefill, complete resident-model pass
sweep or decode ran. Attention may grow quadratically with context. The
complete private 8B >=50 proved tokens/s target on RTX 5090 or another named
high-end GPU remains unachieved. D27/D30/D32/D33/D34/D35 scopes are unchanged.

Eight LIVE source records were appended, 557 -> 565. The useful new source is
[allocator-aware peak scheduling](https://arxiv.org/abs/2610.23328), dated
October 16; its GPU history-dependence result motivates measuring actual
backing. Newly assessed older [Moccasin](https://arxiv.org/abs/2304.14463)
adds latency-constrained recomputation scheduling. Recent
[SP1 6.9.0](https://github.com/succinctlabs/sp1/releases/tag/v6.9.0), Chimera's
October 16 revision, SumCATS, OpenVM-zorch44, ICICLE and efficient-sumcheck
were checked for compatible seams and limitations. These are author claims,
not reproduced performance. Exact dates, commit/license scope and cache/404
failures are in `source-records.json`; no access control was bypassed.

Next owner action: a small locked native round-zero A/B, exact masked rounds,
next challenges, frozen complete receipts and fresh independent verification,
with actual raw eligibility, public pad support, registers and enclosing clocks.
Next local question: can the existing public BASE flag safely specialize this
paired derivation further while retaining the extension-field fallback? Test
base products versus original-slot math before proposing another native change.
The explorer does not merge. Only this research directory excluding runtime
was written. Saved reports do not imply external message delivery.
