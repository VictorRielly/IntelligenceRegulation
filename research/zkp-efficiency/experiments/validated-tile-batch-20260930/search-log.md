# Native LIVE search — 2026-09-30, cycle 0015

Queries: `site.arxiv.org 2026 zkML preprocessing batching model weights proof`;
`site.github.com Lagrange-Labs deep-prove releases 2026 cached setup`;
`site.arxiv.org FlexGen layer wise batch weight offload 2303.06865`.
Search/open/find/click used the native LIVE web tool. No shell network,
installation, external write or downloaded-code execution occurred.

- [FlexGen paper](https://arxiv.org/abs/2303.06865): v1 2023-03-13,
  v2 2023-06-12. Scheduling sections suggest public-weight locality across
  independent batches. No inference throughput is transferred to proving.
- [Author repository](https://github.com/FMInference/FlexLLMGen): Apache-2.0
  LICENSE read; inspected rename commit
  `004ffef82b46e8dc8685c55d0cdda650bdaf1269`, dated 2024-10-28 in history.
  Repository archived 2024-12-01. No external runtime code copied/run.
- [zkComposer](https://arxiv.org/abs/2607.08095): v1 2026-07-09; boundary
  masking must cover multiple evaluations. Its shared-boundary construction
  cannot bypass this project's one-opening rule. Author timings not reproduced.
- [DeepProve setup recipe](https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/README.md):
  public context save/load is a comparison only. Inspected LICENSE is restricted.
  Repository licensing commit `9d1a53e2ef49ffa2c902b8689cd3c58057a4e662`
  appears under 2026-05-26; v2.0.1 history under May 15, but release-detail
  click returned **Internal Error**. CHANGELOG and releases page are not current
  version evidence. No undocumented date or license inferred.

Four detailed qualified records appended to `sources.jsonl`. Their dates,
exact inspected URLs, licenses and commit qualifications are retained there.
Primary-source search rotated through batching/preprocessing and composition;
next: witness replay memory/traffic, then quantization/arithmetic, proof
composition, GPU NTT/commitments, lookup/softmax, sumcheck/GKR and batching.
