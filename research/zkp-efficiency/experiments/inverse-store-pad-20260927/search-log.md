# Native LIVE search log — 2026-09-27 UTC

Rotation: GPU NTT/commitments and memory traffic. Queries included `GPU NTT
inverse transform fused scaling output store zero padding layout CUDA
Goldilocks paper 2025 2026`, `site:github.com NTT CUDA inverse normalize
fused output zero pad transform Goldilocks`, `site:arxiv.org 2026 GPU NTT
memory bandwidth layout polynomial commitment`, and Plonky3 release/NTT
queries. Exact primary pages read:

- NVIDIA [cuPQC NTT features](https://docs.nvidia.com/cuda/cupqc/libraries/cupqc_ntt/cupqc_ntt_feature.html),
  [staged inverse guide](https://nvidia.github.io/cuPQC/applications/ntt-staged-transform/),
  [0.6.0 notes](https://docs.nvidia.com/cuda/cupqc/additional/release_notes.html),
  [SDK terms](https://docs.nvidia.com/cuda/cupqc/additional/license.html),
  and [example repository](https://github.com/NVIDIA/cuPQC) with
  [Apache-2.0 LICENSE](https://github.com/NVIDIA/cuPQC/blob/main/LICENSE).
  Release version verified; exact release/update date and repository commit
  not exposed. `https://api.github.com/repos/NVIDIA/cuPQC/commits/main`
  returned inaccessible through native web search. No SDK/code executed.
- Özcan and Savaş, [Two Algorithms for Fast GPU Implementation of NTT](https://eprint.iacr.org/2023/1410):
  received 2023-09-19, revised 2023-10-06, paper CC BY. Abstract/metadata
  inspected; its comparison remains an author claim.
- Mo et al., [When Proofs Meet Hardware](https://arxiv.org/abs/2606.16146):
  arXiv v1 2026-06-15, no later revision shown. Abstract/history refreshed;
  simulated architecture results do not establish this GPU proof timing.
- [Plonky3 v0.8.0 release](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0)
  rechecked as a recent fusion lead; exact year/commit source inspection
  remains unverified from the earlier record. [Qingming CUDA](https://github.com/uulong950/qingming-g64-ntt-cuda)
  was also rechecked for explicit mapped-output versus natural-layout
  contracts; no source/license/commit inspection this cycle. These are
  leads, not borrowed code or reproduced speedups.

All web content was treated as untrusted data. No downloaded script ran.
