# F-device traffic census — cycle 0065

Run `20261017T182105Z-44205280`, 2026-10-17 UTC. This is a source-access and
arithmetic experiment. No GPU, native crate, native receipt or speed test ran.

The captured owner lane is `ops/zkp-mvp/gpu-zerocheck/`. Its direct and lean
CUDA functions execute here as serial C++ functions, with fake CUDA builtins
and ordinary modular integer arithmetic over p = 2^64 - 2^32 + 1 and u² = 7.
Only `ld_f2` and `st_f2` gain source-access counters. The native fold is also
captured. This tests the expression and serial schedule; it does not test
CUDA arithmetic instructions, concurrency/races, occupancy, generated GPU
instructions, caches, DRAM, masks, transcript, PCS or proof acceptance.

Run from the research directory:

```
python3 experiments/fzc-device-traffic-20261017/run.py
python3 experiments/fzc-device-traffic-20261017/audit.py
```

Both runs pin CPU 0 on an Intel Core Ultra 9 185H, one thread, nice 19,
59-second wall/CPU limits and a 512 MiB address-space limit. Existing g++
11.4.0 compiles standalone shared libraries at O0. No Cargo, dependencies,
downloads, GPU APIs or production execution. The source calls remain observable
because of the counters; these are not counts of optimized GPU loads.

Main result: 96 fixtures, 384 variant schedules; 6,288 Fp2 round values,
576 independently recovered s(1) values, 7,968 Fp2 terminals, 4,128 phase
read/write assertions and 384 closed-form matches pass. It covers n = 1, 2,
4, 6; degree 4/5; support absent/present; 0/3/11 nonzero public pad weights;
direct/lean; fused/separate; arbitrary extension, base-field boundary and
zero-coefficient inputs. A separate Python arbitrary-integer semantic equation
and fold is the reference. The debug-style all-point and release-style
recovered-point paths both occur. The host masking driver is not executed.
Main: 0.759414 s, 16,820 KiB parent RSS, 34,620 KiB compiler RSS.

Audit: 148 independent schedule/source/pin assertions, 7,687 independent Fp2
equality outputs across 0/1/2/9/10/11/12 bits, and three additional negative
controls pass. It executes the captured Eq leaf/join functions with the same
CPU substitutes, across the native 10-bit split threshold. Final audit: 0.368121 s,
16,608 KiB parent RSS, 34,956 KiB compiler RSS. Ten main mutation controls
distinguish dropped final folds, halved fusion counts, lean rereads, support,
zero pad weights, plan counts, activation/limb mistakes and a changed output
coordinate. Kernel and Rust source pins matched. The owner progress ledger changed during
the final audit; both versions are retained. Hash pins and commands remain
beside the code; all inputs are synthetic.

Let N = 2^n, K = 20 without support or 21 with support, and W be the number of
nonzero public pad weights. Count table reads plus writes at 16 B per Fp2.
These formulas exclude construction, parameters, reduction buffers, finals,
transfers and any spill traffic:

| captured variant | table source-access bytes over all rounds/folds |
|---|---:|
| direct, separate | 80 K (N - 1) |
| direct, fused | 64 K N - 48 K |
| lean, either schedule | (32 M + 48 K) (N - 1) |

Here M = 32 without support and M = 33 + W with support. M counts staged
pair-load calls, including repeated table indices. Direct fusion saves the
next round's separate read. Lean fusion folds, stores and then rereads its
stages; it saves no source-level table accesses relative to lean separate.
It can still change launch overhead, compiler load elimination and cache
behavior. These observations do not rank the variants by elapsed time.

For N = 2^20 and K = 21, the direct separate/fused counts are
1,761,606,000 / 1,409,285,136 B: 20.00% less table traffic. Adding the owner's
504 N construction counter gives 2,290,088,304 / 1,937,767,440 B: 15.38% less.
The captured DESIGN.md instead calls the fused result approximately
40 K N + 504 N = 1,344 N B *including construction*. The captured Rust
FzcStats counter correctly yields 64 K N - 48 K for direct rounds/folds;
the note's fused total is the discrepancy. Its 1,344 N happens to approximate
the rounds/folds alone at K = 21. No owner file was changed.

The plan's 72 N × 17 = 1,224 N = 1,283,457,024 B is a different work model,
the direct total with the stated construction counter is about 1.51 times
that normalization at this N. The intended future compact/base-field first round must be distinguished
from this captured code: all tables here are widened to Fp2 before round 0.
Keep the plan number as a named normalization if useful; it is not a measured
DRAM numerator. Do not change an owner threshold or infer a 5090 verdict here.

Construction itself needs qualified labels. Base/paired builds count 24 N /
32 N per plane. For a full Eq point of n <= 10 bits, source reads+writes are
16(n+1)N; for larger n they are 48 N plus the two half-builder accesses.
The current counter charges only 16 N output bytes per Eq. Most repeated
point and half-table reads can hit caches. Equality input/temporary reads,
expanded-Eq gathers, per-block parameter reads, round partial/reduce traffic,
final reads/writes and D2H must be separate from a counter limited to table
traffic. Parameter/point H2D is also outside the current H2D plane counter.

The table allocation floor is 16 K N; at K = 21 this is 168/336/672/2688 MiB
for n = 19/20/21/23, on top of resident commitments and scratch. These are
counts, not new context profiles, fit results or proved tokens. All original
folds and fresh masks remain required.

The useful outcome is a measurement correction and a negative result for
interpreting lean fusion as an automatic traffic reduction. No proving
improvement was established. See the handoff for owner validation and the
dated progress report for baseline clocks, ranked hypotheses and next work.
