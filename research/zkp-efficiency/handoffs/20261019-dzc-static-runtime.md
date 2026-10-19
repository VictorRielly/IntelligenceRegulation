# Unapplied handoff: static D kernel with proof-local parameters

Cycle0080, `20261019T121854Z-575be12a`, 2026-10-19 UTC.
Owner: main agent/Claude reviews and integrates. No production edits or merge.

The research-only coefficient schedule compiles with the unchanged native
Goldilocks/Fp2 source. Compared with the preceding unintegrated affine-first
coefficient schedule, use-driven affine accumulation lowers the emitted
CPU caller's local stack allocation **1,160→360bytes**. It preserves884
Fp2 calls and all59 original tables/folds/finals. These are static CPU code
observations with non-inlined Fp2 wrappers, not a proving/GPU speedup.

Patch location and interface:

- `experiments/dzc-static-runtime-20261019/run.py::CaptureGraph/Lower` emits
  named scalar locals; `graph(raw,p,driven=True)` binds public topology.
- `kernels.rs::driven(raw,params,bases,out)` takes118 Fp2 low/high inputs,
  129 Fp2 parameters,36 canonical base scalars and returns five coefficients.
  The pack is2,352bytes; it is rebuilt from this proof's plan. Generated
  pointer interfaces are research adapters without production length checks.
- Plan provenance remains `prior.plan`; coefficient reduction/message
  conversion and original challenge-dependent folds remain unchanged.
- Actual seam: pinned gpu-zerocheck
  `hashline/src/private_block/argument.rs`, `SC_DZC`, and
  `zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`.

The native field is copied byte-for-byte to `native-field.rs`. Source hashes
are in `source-pins.json`; all six live native source pins and five retained
owner evidence pins recheck. The original captured Rust D/catalog remains
the oracle with Shape/Layout fixture substitutions; field execution in the
candidate now uses the actual source. Parameter catalogs refer to T128;
the synthetic N2/8/32 arrays process no actual model context.

Validation commands:

```bash
python3 experiments/dzc-static-runtime-20261019/run.py --native-field
python3 experiments/dzc-static-runtime-20261019/audit.py
```

Six fixtures, seed2026101980:780 coefficients,390 captured grid/78 off-grid
values,18 messages,354 original finals/six final relations; Python equations
and direct cube agree. Seven negative controls and2,372 independent audit
checks pass. Native check3.807s including1.055s compiler; audit1.005s, one
Core Ultra9 185H CPU. Each process<=59sCPU/wall,512MiBAS, nice19/CPU0.
No Cargo,GPU,installation or foreign code execution.

Critical integration details:

1. Signed lookup coefficients **must reduce moduloP** before entering a
   base scalar slot. A u64 cast of−1 caused the first real differential
   failure. Its corrected regression control remains.
2. Runtime slot layouts must follow role/index topology, alias combination
   and public widths. No deduplication or pruning by field value, including
   zero weights. No proof-local challenge/mask/opening may become reusable setup.
3. Fully inlined native-field compilation timed out after40s. The successful
   adapter deliberately uses884 scalar call boundaries. Do not substitute its
   stack numbers for a fully fused device implementation's resources.
4. Caller instruction lines rise6,986→7,011 despite the smaller frame; code
   bytes33,878→32,967. Static RSP references do not measure executed spills.
   Shared field helpers are leaves; ABI/callee/parameter/plan costs remain.
5. Registered profiles, odd helpers, padding, aliases and permutations need
   actual native gates. Previous generic Python coverage is not compiled
   current-profile admission. D30 remains a separate unbuilt profile.

Before integration acceptance: actual admission/challenges/alpha/g_u8, seeded
proof bytes/RNG/refusals, extension/mask/PCS/original-final order, fresh proof
verification/tamper controls and joint-view privacy, followed by whole-D and
complete-stack clocks. No masks/openings/transcripts/degree/refusals change.
Current all-D zero-cost CPU ceiling is only1.105058x at8B T128; candidate and
GPU ceilings unknown. No target tokens counted.

Next bounded research experiment: group several native operations into each
helper function, preserving first-use scheduling while reducing call overhead
and avoiding all-inline compile growth. Owner GPU/compiler and full-stack
measurements require the shared build/heavy locks; they were not launched.
