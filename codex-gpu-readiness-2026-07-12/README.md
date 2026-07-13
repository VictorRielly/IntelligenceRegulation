# GPU-readiness implementation handoff

Date: 2026-07-12

Branch: `perf/zk-batch-optimizations`

## Outcome

The repository is now suitable for starting a **GPU kernel prototype** against
the U-K9 CPU reference. It is **not** ready to claim a secure, end-to-end,
8-billion-parameter proof in five seconds.

This tranche:

- recovered Fable's clean U-K9 work without taking its non-compiling residue;
- replaced public/deterministic lookup-mask derivation in the U-K8 CLI path
  with fresh operating-system CSPRNG entropy;
- made the U-K8 verifier recompute the lookup transcript prehash;
- repaired statement scale, signed-bound, table-identity, orientation and DAG
  validation;
- replaced runtime floating-point SiLU table generation with frozen integers;
- added executable GPU-kernel layout, capacity and boundary contracts; and
- ran the full Rust proof battery plus focused Python and performance checks.

Read these files in order:

1. [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md) — every change and why.
2. [GPU_PORT_CONTRACT.md](GPU_PORT_CONTRACT.md) — the exact CPU/GPU ABI.
3. [TEST_EVIDENCE.md](TEST_EVIDENCE.md) — commands and measured results.
4. [REMAINING_RISKS.md](REMAINING_RISKS.md) — what still blocks the headline.

## Decision

**GO:** implement and differentially test GPU versions of the packed U-K9
primitives.

**NO-GO:** advertise production zero knowledge, a complete transformer proof,
or five-second 8B proving. Those claims still lack both implementation and
evidence.
