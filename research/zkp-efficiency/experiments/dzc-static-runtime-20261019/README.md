# Static D coefficients with runtime parameters — cycle 0080

Run `20261019T121854Z-575be12a`, 2026-10-19 UTC.
**CPU compiler storage result; no proving speedup measured.** The current
unpadded D coefficient schedule now has compiled, named scalar locals and
runtime proof-local parameter arrays. With the unchanged native field source
and non-inlined Fp2 adapter calls, its emitted x86-64 caller stack allocation
decreases **1,160→360 bytes**, with the same arithmetic and **884 calls**.
This is an A/B between unintegrated coefficient prototypes. It is not an A/B
against the installed native sample evaluator, a GPU register measurement,
or full-prover peak memory/timing.

`run.py::graph(raw,p,driven)` captures public topology; `Lower.emit(name)`
emits `kernels.rs`. Both compiled entry points accept pointers to 118 Fp2
low/high inputs, 129 Fp2 parameters, 36 canonical base parameters, and five
Fp2 outputs. These are research C interfaces without a production admission
wrapper. Parameters come from this proof's `prior.plan`; no challenge-derived
scalar is compiled into code or reused between proofs. The code generation
dispatch uses topology and widths only. All zero coefficients keep their work.
Constants and repeated literal occurrences occupy runtime slots too: this is
an intentionally simple, non-minimal 2,352-byte parameter pack.

Run from the research directory:

```bash
python3 experiments/dzc-static-runtime-20261019/run.py --native-field
python3 experiments/dzc-static-runtime-20261019/audit.py
```

The no-flag mode uses the exact u128 substitute. The original successful
substitute artifacts are preserved in `u128-pass/`; rerunning either mode
overwrites root generated artifacts, so save each arm separately. Each script
sets nice19, CPU0 affinity, 59s CPU/wall and 512MiB address-space limits.
Compilation uses installed rustc1.97.1, one codegen unit, opt-level1, no Cargo
or dependency installation. No GPU or downloaded implementation is executed.

Native-field correctness run: **3.807474s**, including **1.055092s** compilation,
RSS37,976KiB, compiler130,212KiB. Independent audit: **1.005090s**, RSS24,252KiB.
Intel Core Ultra9 185H CPU0, WSL2. These are correctness/audit clocks; there
was no optimized kernel latency comparison. Substitute run19.470783s,
compiler16.597593s/RSS153,908KiB retained separately.

Six synthetic fixtures: two public scalar catalogs (TinyLlama1.1B/Llama3-8B),
N2/8/32, seed2026101980. They compare 780 compiled coefficients, 390 original
captured-Rust grid values,78 off-grid values,18 round messages,354 original
final evaluations and six final relations. Both schedules also agree with
independent Python clauses/cube evaluations. Thirty-six zero-input bindings
retain the same topology and runtime parameter packs and execute correctly.
Seven controls detect stale runtime parameters, bad signed base conversion,
parameter corruption, swapped endpoints, lost degree4, stale recovery claim
and a tampered original final. Independent **2,372-check audit** reconstructs
lifetimes by interval events and direct live sets, checks each source/parameter
slot exactly once, field/source hashes, assembly and ELF symbol sizes.

| Per D row pair | Affine-first baseline | Use-driven candidate |
|---|---:|---:|
|Scalar SSA peak incl. five-word accumulator, Fp2 equivalents|76|26|
|Native-field caller local stack allocation, bytes|1,160|360|
|Additional callee-saved pushes, bytes|48|48|
|Static x86 instruction lines in caller|6,986|7,011|
|Calls to shared Fp2 helpers|884|884|
|ELF caller symbol bytes|33,878|32,967|
|Requested raw-input bytes|1,888|1,888|
|Requested runtime-parameter bytes|2,352|2,352|
|Requested output bytes|80|80|
|Field add/sub/mul/base calls|272/209/331/72|272/209/331/72|

The 76→26 scalar model is a different abstraction from prior77→27 array
buffers. It includes parameter loads and per-primitive Fp2 results, avoids
array copy aliases, and excludes primitive-internal base arithmetic. Neither
number is a register count. The native caller has no conditional jumps; the
four shared field helpers are leaves, with zero conditional jumps in this
build and one eight-byte push in multiplication. ABI return addresses, other
callers, red-zone use and enclosing proof storage are not a dynamic peak
measurement. RSP-reference counts2,501→2,455 are static addresses, not bytes
of executed spills or DRAM. The2,352-byte pack is not all live simultaneously.

All59 original tables/folds/finals remain. Original folds still need118
reads/59writes and59 each add/sub/mul per row pair. Combined field counts
331/268/390/72 omit common coefficient reduction, conversion and planning.
Keeping all raw input values live raises candidate scalar peak to134 words.
The unpadded four-limb catalog is tested; no new native padding/profile,
alias/permutation admission, odd helper or D30 profile is compiled here.
Those broader Python tests remain prior evidence, not current compiler gates.

Preserved negatives:

- The first emitter interpreted two signed lookup multipliers as unsigned
  two's-complement values. Independent comparison caught it. Canonical `%P`
  conversion fixes it; `signed_base_wrap` keeps the failure executable.
- A rustc multi-output filename mismatch caused an earlier load failure.
  The proper generated filename is `libkernels.so`; original failure retained.
- Native field **all-inlined** compilation exceeded its **40-second timeout**.
  No completed output or native all-inline resource result is claimed. Using
  non-inlined Fp2 adapter calls completed, but adds a call boundary absent from
  a fully fused GPU row. Compile growth is a real integration prerequisite.
- Smaller stack allocation comes with25 more caller instruction lines. No
  latency saving follows without an enclosing measurement.

Baseline/eliminated/added/ceiling: eliminate early source lifetimes from the
unintegrated affine-first coefficient implementation. Retain arithmetic,
original tables and final-opening order. Add plan packing, parameter traffic,
generated code size, ABI/compiler effects and any native adapter costs.
`new_total = old_total - affected_D + replacement_D + integration_costs`.
Retained R6 8B T128/32blocks/one16-thread CPU pass: total471.580s, D44.833s.
Deleting ALL D at zero cost caps that diagnostic at1.105058x; it is not a
candidate prediction or GPU bound. Startup, serialization and resident slope
remain unisolated. See `target-accounting.json` for carried clocks and limits.

The actual seam is `SC_DZC` in pinned gpu-zerocheck `private_block/argument.rs`
through `SumcheckRounds`. Owner gates include actual shapes/challenges and
parameter provenance, seeded bytes/RNG/refusals, extension and mask rows,
PCS/original finals, fresh proof verification/tamper tests and joint-view
privacy. No additional private claim/opening, mask reuse, weaker privacy,
degree change or refusal change is proposed. Main/Claude reviews and integrates;
the [handoff](../../handoffs/20261019-dzc-static-runtime.md) is unapplied.

LIVE records include new [ReedWeave](https://eprint.iacr.org/2026/2147) and
[Quasar](https://eprint.iacr.org/2026/1839) architecture leads and compiler/NTT
references. PDFs and commit details had recorded access failures. No foreign
benchmark was reproduced. Records preserve dates, exact URLs, license scope
and uninspected commit identifiers.

Next: native-field helper-group functions that reduce the884 scalar call
boundaries while bounding compilation and preserving low liveness. Count
argument/return traffic, deepest call stack and generated code growth.
GPU register/whole-D/whole-stack timing stays with the owner under shared locks.
New target proofs/passes/positions0/0/0; target device none. Target context,
steady/total rates,startup fraction,witness/proof/serialization/verification
unmeasured. No prefill,resident series or decode ran. Larger workloads remain
allowed; attention can grow quadratically with context. Complete private8B
>=50 proved positions/s remains unchanged and unachieved.
