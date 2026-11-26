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

## Where it stands (2026-11-26)

Plain-words status with labelled numbers, starting with a short answer:
[docs/zkmatrix-poc/MVP_STATUS.md](docs/zkmatrix-poc/MVP_STATUS.md). Each figure below is repeated from a dated
entry there, where its limits are stated.

- **What runs today:** a local demo app, [Proven Media](apps/proven-media/README.md), a feed in which every item
  carries proved content labels. As installed on the project's machine it proves the verdicts of a trained 3B
  safety classifier (Shieldstral-1.0-3B, 26 layers, 128 tokens a request), and a separate verifier program checks
  the receipts. The proof system is built to hide the input and every intermediate value and to publish only the
  verdict. The profile the app runs on that machine is a development profile for public content, and privacy is
  not claimed for it (see the privacy and Lean lines below for what is missing). The app code for that profile is
  newer than the copy in this repository, which is the state of 2026-11-10.
- **The prover (Hashline)**:
  - Ligero-style hiding polynomial commitments over the Goldilocks field and its quadratic extension, BLAKE3
    Merkle trees and Fiat–Shamir, LogUp lookups and a masked sumcheck.
  - Exact integer semantics for the model: integer matrix products, lookup tables for the nonlinear functions, and
    exact rounding rules.
  - Backends: CPU, and Apple Metal (GPU). Every figure below is from one M3 Ultra Mac; a CUDA backend for the
    current prover is not in this tree.
- **The proof profiles**:
  - Registered run profiles at Llama-3-8B, TinyLlama-1.1B and Shieldstral-1.0-3B (classifier) shapes. The app
    runs the classifier profile named W16R2.
  - "Commit, fork, join" (D55) proves one request's blocks in parallel.
- **Speed** [MEASURED, Nov 22 and 23; a request counts as 128 tokens, padding included]:
  - The trained 3B classifier, six requests proved side by side: 48.6 to 50.0 proved tokens/s.
  - An 8B shape with test weights (not a trained 8B model), as a stream: 37.2 proved tokens/s at the defaults,
    40.2 with two optional GPU switches turned on.
  - The target is ≥ 50 proved tokens/s for a private 8B model on one high-end GPU.
- **Receipt size** [MEASURED]: 669.6 MB for one classifier request, 818.7 MB at the 8B shape. Making receipts
  smaller is current work; the first step about halves them by count but failed its timing test, so today it
  would be a separate, slower profile.
- **Trained 8B:** two development proofs on the CPU exist (one reported by its author and not yet read by a
  second party). Neither is at speed, and neither has a privacy acceptance.
- **Privacy evidence** (as of 2026-11-04):
  - An 18-part privacy gate reads real captures of the shipped prover's output. It passed on all 12 registered D55
    bundles (CPU-made, R13 profiles).
  - This is evidence, not a proof. No run of the gate on the profile the app runs today is recorded on the status
    page.
- **Formal verification** (Lean 4, in [formal/](formal/)):
  - For one classifier profile (R13), the approved production statement is proved about a Lean model of the prover
    and the verifier, on Lean's three standard axioms. Every module has been opened by a reader who did not write
    it; parts remain unread.
  - Limits: three of the code's header checks are taken as values the prover writes down, one boundary check
    differs from the Rust verifier's, nothing in Lean speaks about the Rust binary itself, and there is no compiled
    Lean verifier.
  - For the profile the app runs (W16R2), the port has begun: the shape of the 26 layers and single-block soundness
    are merged. The run level, zero knowledge and the final statement are open, so by our own rule this profile is
    not production.
- Every product and security ruling: [docs/zkmatrix-poc/ZK60_DECISIONS.md](docs/zkmatrix-poc/ZK60_DECISIONS.md).

## How this relates to Anthropic's FlashProve

[FlashProve](https://github.com/anthropics/FlashProve) (Apache-2.0) proves Llama 4 Maverick at about 110 tokens/s
of batched prefill on one H100, with Lean proofs. The two projects answer different questions:

| | FlashProve | This project (P1) |
|---|---|---|
| Hidden | the model weights | the user's inputs, outputs and activations |
| Public | the prompt and the reply | the model weights, and any output part we choose to publish (e.g. a verdict) |
| Question answered | which committed model produced this reply? | did the approved model produce this result on private data? |
| Speed | about 110 tok/s, batched, H100 | 48.6 to 50.0 tok/s for a trained 3B classifier, six requests side by side; 37.2 to 40.2 at an 8B shape with test weights; Apple M3 Ultra |
| Lean | soundness, completeness, ZK proved for its Lean model | the production statement proved for a Lean model of one classifier profile, with the limits listed above; the port to the profile the app runs has begun |

We intend to reuse FlashProve's Lean library where it fits, under its licence.

## Start here

- [docs/zkmatrix-poc/MVP_STATUS.md](docs/zkmatrix-poc/MVP_STATUS.md): the current state, short answer first.
- [docs/zkmatrix-poc/START_HERE.md](docs/zkmatrix-poc/START_HERE.md): the problem in plain words, the rules and a
  glossary. Last revised in mid-October 2026; its numbers and its list of what is built are out of date.
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
