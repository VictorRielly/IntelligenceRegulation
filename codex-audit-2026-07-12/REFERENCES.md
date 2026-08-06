# References

## Repository evidence

- `zkmatrix-rs/src/bin/ring_matmul.rs` — U-K5 batteries, U-K8 chain, statement
  inventory, CLI, and benchmark output.
- `zkmatrix-rs/src/manifest.rs` — unvalidated manifest and Statement v2.
- `zkmatrix-rs/src/ring/gkr_masked.rs` — mask/blinder objects and freshness
  marker.
- `zkmatrix-rs/src/ring/sumcheck.rs` — deterministic lookup transcript.
- `zkmatrix-rs/src/ring/mod.rs` — SplitMix64 prover/benchmark randomness.
- `docs/zkmatrix-poc/M4_LOOKUP_DESIGN.md` — original U-K8 exit and live
  row-block measurements.
- `docs/zkmatrix-poc/TARGET_CONTRACT.md` — benchmark boundary and honest status.
- `PROGRESS.md`, `PROGRESS_UK9.md` — unfinished orchestration ledgers.
- `codex-audit-2026-07-10/` — prior findings and exit criteria used for this
  regression audit.

## Primary external sources

- Xie et al., [Libra: Succinct Zero-Knowledge Proofs with Optimal Prover
  Computation](https://eprint.iacr.org/2019/317.pdf), Cryptology ePrint
  2019/317. The construction masks sumcheck/GKR leakage with genuinely random
  polynomial coefficients; it supports the masking direction, not public
  deterministic pads.
- NIST, [SP 800-90C Random Bit Generator
  Constructions](https://www.nist.gov/news-events/news/2025/09/recommendation-random-bit-generator-constructions-nist-publishes-sp-800-90c),
  together with SP 800-90A/B. This is a production-randomness reference; the
  current SplitMix/fixed-seed harness does not meet that role.
- Fenzi et al., [How to Prove False Statements: Practical Attacks on
  Fiat–Shamir](https://eprint.iacr.org/2025/118.pdf), Cryptology ePrint
  2025/118. This is not asserted to be the same attack as C-02; it is relevant
  background on why the exact statement, circuit/commitment digest, and
  Fiat–Shamir instantiation must be reviewed as one protocol rather than as
  local hash calls.

