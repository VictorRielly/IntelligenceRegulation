# Implicit affine FZC tables — research candidate for owner review

Cycle 0096, `20261020T041854Z-f70297a5`. No native patch, build, GPU run or
proving improvement. Mathematical candidate code is
`experiments/native-fzc-arena-20261020/probe.py::derive/fixture/Arena`;
`reference.py` is a separate original-slot/direct-MLE reference.

The active GPU source stores GL/PL as full-domain affine combinations of A,
then folds them with every other table. They can instead be reconstructed
from already staged original A endpoints, because an affine form commutes
with multilinear folding. **The constant belongs in the low value; it must
not be added to the difference.** Both omitted-constant and affine-difference
controls fail in the model.

Proposed interface, not implemented: public-shape
`ArenaLayout { offsets, capacities, mode: Dense | RawHalf | RawHalfSharedDerived }`.
RawHalf keeps tables 3..19 at L/2 and all other tables full. The new shared
derived mode gives GL/PL zero global capacity, stages K0 original tables,
fills shared derived low/difference slots from the staged A values before
`fzs_group`, and folds only stored original tables. Shared K/derived slots may
retain their current layout. Existing raw eligibility stays binding. Dense
legacy/unsupported/unfused paths keep their exact original representation.

Native seams, pinned active GPU revision (full SHA-256 manifest in experiment):

- `hashline/src/gpu/cuda.rs`: `DevFzcRounds::new`, allocation line 4326 and
  full destination views line 4332; `try_round` launch stride parameters;
  `try_fold` generic kd fold line 4756, pack line 4773, finals line 4788.
  Move destination views inside the branches that write a table and apply
  per-table offsets; a skipped raw upload still creates a full view today.
- `fzc_kernels.cu`: `fzs_ld` line 755, `fzs_impl` staging/fold stores
  838..843 and raw-round0 derived writes 867..868. In shared-derived mode,
  stage original tables on every round and run a shared derivation phase;
  remove global derived writes/folds only in that mode. Later rounds add
  work and a block barrier per chunk. `fzs_derived_at` supplies the existing
  affine expressions but needs review for all BASE/FOLD variants.
- Generic `kernels.cu::k_sc_fold` line 896 must use offsets and the stored
  table count; `k_fzc_finals` line 1664 and `fzc_kernels.cu::k_fzc_pack`
  line 919 must use offsets. Finals/host pack cover original k tables only.
  Legacy direct/lean/derive variants also appear in the lexical census.

Validation: 108 authored Python fixtures / 468 modeled rounds, native
Goldilocks Fp2 definition, actual FZC polynomial, direct original MLE reference,
11 negative controls, canonical field bytes and a synthetic challenge chain.
Includes support/pads, base/extension A, dense/raw, host tails, generic/fused
folds and finals. No Rust/CUDA instruction execution, native masks/transcript,
PCS/receipt equality, verifier or security review. The 107 selected source
sites are a lexical index, not complete compiled-program coverage.

At illustrative support/F2^21: dense 736 -> mixed 464 -> shared-derived
400 MiB requested. It saves zero additional backing in all 24 resident partial
schedules; selected chunked cases save another 64 MiB. Actual GPU high-water
mark and fit are unknown. R8 geometry and the GPU allocator are separate
versions. Do not claim request bytes are physical memory or throughput.
Device-only counted work eliminates `(1+support)*(L-1)` derived Fp2 folds
and about 256 MiB of derived writes/fold traffic at support/F2^21; it adds
L-2 affine endpoint evaluations relative to the initial baseline L, shared
work, barriers and possible register/occupancy costs. No end-to-end speed
ceiling can be estimated without exclusive full-workload phase clocks.

First owner action: measure raw eligibility and fresh/reused allocation
capacity at the complete workload's actual peak. Only then consider an
isolated native prototype under lane ownership and shared build/heavy locks.
Require native dense/mixed/shared-derived differential rounds and finals,
shadow masked rounds plus next challenge, actual full receipt identity,
fresh independent verification, raw-disabled/dense fallback, host tail,
strict GPU/failure/refusal/CS/H-1 controls and current privacy gates.

Original A/H owners, original field/relations, one opening per commitment,
fresh masks/pads and the native transcript remain binding. No caching or reuse
of private masks, openings or cross-proof state. No new public telemetry may
contain values, addresses, randomness or private-dependent content. D33 R7
TinyLlama T32 acceptance does not cover GPU/8B/next-token; D27/D30/D32/D34
scopes remain. The main agent/Claude reviews and integrates; explorer does
not merge or edit production.

Falsify on any address/initialization/alias error, omitted affine constant,
round/final/next-challenge/receipt/refusal mismatch, changed privacy, unavailable
raw path, no lower actual backing/peak, or enclosing elapsed regression.
Next local experiment: coefficient-aware derivation/fold/barrier cost budget
and host-tail break-even. Highest priority remains whole-prover high-end GPU
clocks and independently verified fixed-context resident 1/2/4/8 complete
workloads. New verified full proofs/passes/positions remain 0/0/0; all new
proof clocks, proved rates and startup fraction are unmeasured.
