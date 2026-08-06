# References

## Repository evidence

The principal local sources for this follow-up are:

- [`M4_LOOKUP_DESIGN.md`](../docs/zkmatrix-poc/M4_LOOKUP_DESIGN.md) —
  unmasked lookup, leak inventory, costs, and original U-K5/U-K8 exits.
- [`M4_LOOKUP_ZK_DESIGN.md`](../docs/zkmatrix-poc/M4_LOOKUP_ZK_DESIGN.md) —
  designed-but-unbuilt masking adaptation and remaining proof obligations.
- [`M5_LITE_REPORT.md`](../docs/zkmatrix-poc/M5_LITE_REPORT.md) — chunking,
  commitment measurements, and modeled remainder.
- [`LLM_SCALE_ESTIMATE.md`](../docs/zkmatrix-poc/LLM_SCALE_ESTIMATE.md) — current
  performance ladder.
- [`SOUNDNESS_REFERENCE.md`](../docs/zkmatrix-poc/SOUNDNESS_REFERENCE.md) — R1,
  E2, parameter, sampler, and integer-exactness status.
- [`M3_REPORT.md`](../docs/zkmatrix-poc/M3_REPORT.md) — declared versus proven
  input/model ranges.
- [`ring_matmul.rs`](../zkmatrix-rs/src/bin/ring_matmul.rs) — batteries,
  lookup and M5 benchmarks, and chain caveats.
- [`ct_engine.rs`](../zkmatrix-rs/src/ring/ct_engine.rs) — R1 and proof round.
- [`link.rs`](../zkmatrix-rs/src/ring/link.rs) — E1/E2 slot target link.
- [`kfield.rs`](../zkmatrix-rs/src/ring/kfield.rs),
  [`sumcheck.rs`](../zkmatrix-rs/src/ring/sumcheck.rs),
  [`gkr.rs`](../zkmatrix-rs/src/ring/gkr.rs), and
  [`lookup.rs`](../zkmatrix-rs/src/ring/lookup.rs) — unmasked activation core.
- [`commit.rs`](../zkmatrix-rs/src/ring/commit.rs) — wide-object chunking.

## Primary cryptographic sources

- Ulrich Haböck, [*Multivariate lookups based on logarithmic derivatives*,
  IACR ePrint 2022/1530](https://eprint.iacr.org/2022/1530).
- Shahar Papini and Ulrich Haböck, [*Improving logarithmic derivative lookups
  using GKR*, IACR ePrint 2023/1284](https://eprint.iacr.org/2023/1284).
  The paper describes the fractional GKR lookup direction and presents itself
  as an informal note; it does not prove this repository's custom ZK masking
  adaptation.
- Tiancheng Xie, Jiaheng Zhang, Yupeng Zhang, Charalampos Papamanthou, and Dawn
  Song, [*Libra: Succinct Zero-Knowledge Proofs with Optimal Prover*, IACR
  ePrint 2019/317](https://eprint.iacr.org/2019/317).
- Alessandro Chiesa, Michael A. Forbes, and Nicholas Spooner, [*A Zero
  Knowledge Sumcheck and its Applications*, IACR ePrint
  2017/305](https://eprint.iacr.org/2017/305).

These papers support the general LogUp/GKR and masking techniques. The
repository explicitly changes the masking construction because its fold-based
boundary points and projective leaves do not match Libra verbatim. Therefore
the repo's toy rank checks and handwritten simulator must not be presented as
if they were directly inherited theorems from the cited papers.

## Primary GPU engineering sources

- [ICICLE lattice and negacyclic NTT Rust API](https://dev.ingonyama.com/api/rust-bindings/lattice/lattice-snarks)
- [ICICLE sumcheck API](https://dev.ingonyama.com/api/cpp/sumcheck) — currently
  documents that extension-field Fiat-Shamir results are unsupported.
- [NVIDIA CUDA C++ Best Practices Guide](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html)
- [NVIDIA Nsight Compute documentation](https://docs.nvidia.com/nsight-compute/NsightCompute/index.html)

These support the audit's recommendation to keep data resident, account for
transfers and synchronization, batch work, and use per-kernel roofline/profile
evidence rather than a single cross-workload speedup constant.

