# Intelligence Regulation: private, provable AI inference

We build zero-knowledge proofs that an approved AI model produced an answer **on private data, without revealing
the data**. A regulator, auditor or user can check that the approved model ran and what it decided (for example a
safety classifier's verdict) without seeing the prompt, the answer or anything computed in between.

- **P1 (current):** inputs, outputs and every intermediate activation are hidden; the model weights are public.
- **P3 (later):** the weights are hidden too.

Why we are doing this: [docs/VISION.md](docs/VISION.md).

> **Research prototype.** It has not been audited, and no proof made with it is in production use. Our rule
> (decision D63) is that nothing goes into production before its soundness and zero-knowledge statements are proved
> in Lean. See [SECURITY.md](SECURITY.md) to report a break.

## Where it stands (2026-11-04)

Plain-words status, with labelled numbers: [docs/zkmatrix-poc/MVP_STATUS.md](docs/zkmatrix-poc/MVP_STATUS.md).

- **The prover (Hashline)**:
  - Ligero-style hiding polynomial commitments over the Goldilocks field and its quadratic extension, BLAKE3
    Merkle trees and Fiat–Shamir, LogUp lookups and a masked sumcheck.
  - Exact integer semantics for the model: integer matrix products, lookup tables for the nonlinear functions, and
    exact rounding rules.
  - Backends: CPU, and Apple Metal (GPU). The CUDA port for an RTX 5090 is next.
- **The proof profiles**:
  - Registered run profiles at Llama-3-8B, TinyLlama-1.1B and Shieldstral-1.0-3B (classifier) shapes.
  - "Commit, fork, join" (D55) proves one request's blocks in parallel.
- **Speed** [MEASURED on an M3 Ultra Mac, 8B shapes with synthetic weights, one request, 128 tokens]:
  - 22.9 proved tokens/s proof-only, or about 9 counting witness generation.
  - The target is ≥ 50 proved tokens/s on one high-end GPU.
- **Privacy evidence**:
  - An 18-part privacy gate reads real captures of the shipped prover's output. It passes on all 12 registered D55
    bundles (CPU-made).
  - This is evidence, not yet a proof. GPU-made bundles still have to pass it.
- **Formal verification:** the two production statements are written in Lean 4 in [formal/](formal/). The proofs
  are the work ahead.
- Every product and security ruling: [docs/zkmatrix-poc/ZK60_DECISIONS.md](docs/zkmatrix-poc/ZK60_DECISIONS.md).

## How this relates to Anthropic's FlashProve

[FlashProve](https://github.com/anthropics/FlashProve) (Apache-2.0) proves Llama 4 Maverick at about 110 tokens/s
of batched prefill on one H100, with Lean proofs. The two projects answer different questions:

| | FlashProve | This project (P1) |
|---|---|---|
| Hidden | the model weights | the user's inputs, outputs and activations |
| Public | the prompt and the reply | the model weights, and any output part we choose to publish (e.g. a verdict) |
| Question answered | which committed model produced this reply? | did the approved model produce this result on private data? |
| Speed | about 110 tok/s, batched, H100 | 22.9 tok/s proof-only, one request, Apple M3 Ultra |
| Lean | soundness, completeness, ZK proved for its Lean model | statements written; proofs ahead |

We intend to reuse FlashProve's Lean library where it fits, under its licence.

## Start here

- [docs/zkmatrix-poc/START_HERE.md](docs/zkmatrix-poc/START_HERE.md): what is built, the measured numbers, the
  rules, and a glossary.
- [docs/zkmatrix-poc/ZK60_MAC_BRINGUP_20261031.md](docs/zkmatrix-poc/ZK60_MAC_BRINGUP_20261031.md): building and
  proving on Apple silicon. The prover crate is `ops/zkp-mvp/gpu-metal/hashline`.
- [docs/zkmatrix-poc/ZK60_LEAN_PRODUCTION_STATEMENTS.md](docs/zkmatrix-poc/ZK60_LEAN_PRODUCTION_STATEMENTS.md)
  and [formal/](formal/): the statements every proof must satisfy before production.
- [research/zkp-efficiency/](research/zkp-efficiency/): the efficiency research lane (hypotheses, experiments,
  handoffs).
- [docs/zkmatrix-poc/TASK_BOARD.md](docs/zkmatrix-poc/TASK_BOARD.md): small, self-checking tasks with exact
  commands.

An older CPU component demo (synthetic public inputs; it does not establish privacy) runs with
`python3 scripts/zk60_p1_demo.py --output <new directory>`; see
[docs/zkmatrix-poc/ZK60_P1_DEMO.md](docs/zkmatrix-poc/ZK60_P1_DEMO.md).

Heavy builds and proofs on a shared machine go through `scripts/zk60_resource_guard.py`; see
[docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md](docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md).

## Other directions in this repository

- [Music provenance](docs/provenance/MUSIC_PROVENANCE_POC.md): proving music is human-made (attested capture, a ZK
  edit chain), and the honest limits of a classifier screen.
- `zk_lattice/`: a lattice-based (post-quantum) proof of matrix multiplication, the reference implementation of an
  earlier route.

## License

Apache License 2.0: [LICENSE](LICENSE) and [NOTICE](NOTICE). Third-party components keep their own licences. Model
weights are not included; they are fetched pinned and used under their own licences.

## Contact

Victor Rielly, victorrielly@gmail.com.
