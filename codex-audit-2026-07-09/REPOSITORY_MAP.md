# Repository map and maturity assessment

## Core proof work

| Area | What exists | Maturity |
|---|---|---|
| `zk_matrix/` | Python reconstruction of the zkMatrix Algorithm 4-style reduction, recursive inner-product proofs, optimized and naive masking variants | Useful reference/toy implementation. Its additive backend is explicitly non-binding; pure-Python groups are not a deployment backend. |
| `zk_matrix_fast/` | Native toy finite-field implementation used for scaling comparisons | Benchmark baseline, not a cryptographic proof system. |
| `zkmatrix-rs/src/bin/structured_matrix.rs` | BLS12-381 structured-SRS matrix proof prototype, batching and chain demo | Cryptographic arithmetic is real, but setup is generated locally from a known deterministic trapdoor in demos; no ceremony, SRS import validation, serialization, or production API. |
| `zk_lattice/` | Python Route Z reference with OS entropy and higher-precision rejection decisions | Clearer reference implementation; far too slow for the target. |
| `zkmatrix-rs/src/bin/lattice_matmul.rs` | Native Route Z demos, gadgets, links, and the M3 FFN demo | The most complete end-to-end computation proof, but only a tiny ReLU FFN and hundreds of seconds at the published reference shape. |
| `zkmatrix-rs/src/ring/` and `ring_matmul.rs` | Custom Route R ring/lattice protocol, fast commitment kernels, ct claims, ARP, links, quadratic claims, Pi1/Pi2, committed-executions gate | Serious research prototype. It is custom, not externally reviewed, and currently carries open soundness/ZK/composition obligations plus insecure benchmark sampling. |
| `zkmatrix-rs/src/manifest.rs` | Order-sensitive hash container for commitment and operation metadata | A useful start, not a general statement schema or verifier. No parser, validation, canonical wire format, quantized model header, or activation-table digest field exists. |
| `scripts/` | Benchmarks, parameter chains, estimator shim, algebra checks, activation approximation/cost harness | Valuable reproducibility aids. Several outputs are models extrapolated from anchors, not end-to-end measurements. |
| `tests/` | 42 Python-driven behavioral tests plus Rust binary self-tests | Strong negative-test emphasis. Rust `cargo test` itself contains zero unit tests; integration behavior is hidden in command-line self-tests. No fuzzing or untrusted-proof parsing tests. |

## The best complete model proof

The strongest full computation claim is the Route Z M3 demo in
[`M3_REPORT.md`](../docs/zkmatrix-poc/M3_REPORT.md):

- one FFN block only;
- `T=16`, `d=32`, `f=64`;
- two matrix multiplications, bias broadcast, one rescale/range family, ReLU,
  transpose links, and a residual;
- 1,024 activation elements;
- about 316.27s prove and 83.71s verify in the recorded run;
- declared input/weight widths are not proved;
- no attention, normalization, softmax, RoPE, multi-layer execution, or model
  import.

The automated test uses an even smaller `T=4,d=8,f=8` instance.

## The Route R chain demo is not a transformer

`ring_matmul chain-demo 128 128 16 4` covers a small matmul, rescale/range
wave, and a standalone slot-packed Hadamard triple. The Hadamard is not tied to
the rescale chain. The source itself labels the q31 binary non-wrap condition as
open. A successful runtime therefore does not establish a sound transformer
subgraph.

## M4 status

M4 delivered a Python reference and design/cost study for a declared
piecewise fixed-point approximation to SiLU. It did **not** add a Rust
activation proof. The design concludes that this construction is structurally
too expensive and recommends a new lookup primitive. It also finds that the
existing slot-packed multiplication is unsafe when composed unless
slot-constancy is enforced.

## Legacy / unrelated areas

`ComputationIdentification/`, `ComputationMonitor/`,
`approximatematrixmultiplication.py`, and `contentzkpfilterpoc (1).py` are
earlier model-identification or approximate-verification experiments. They are
not part of the current cryptographic proof path and should be moved to an
`archive/` area or a separate repository to avoid confusing the security
boundary.

## Repository engineering state

- Approximately 35k lines across the reviewed Python/Rust/C implementation,
  tests, and scripts.
- No CI workflow was found.
- No repository license was found; the root README still contains the
  placeholder `[Specify your license here]`.
- The root README has placeholder install, usage, requirements, and contact
  sections and does not provide a reproducible quick start.
- The Rust crate is a collection of large stand-alone binaries rather than a
  reusable library. Core verification is tightly coupled to demo construction.

