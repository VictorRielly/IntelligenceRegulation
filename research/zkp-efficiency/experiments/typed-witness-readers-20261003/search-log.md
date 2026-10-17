# LIVE primary search — 2026-10-03, cycle 0017

Queries: `zero knowledge prover small value witness memory compression sumcheck
2026 September GPU`; `site.github.com zk prover packed witness int16 Goldilocks
memory`; `zero knowledge streaming commitments witness memory Spartan 2026 paper`.
Used the native LIVE web tool. No downloaded implementation ran.

- [Pico 3.0 author announcement](https://blog.brevis.network/2026/09/30/pico-3-0-real-time-ethereum-proving-on-4-gpus-with-100-bit-provable-security/),
  dated **2026-09-30**, describes narrower records, larger chunks, and fewer
  committed lookup columns. The authors' four-GPU Ethereum results are not
  reproduced and do not measure this private model relation. Narrow records
  motivate the local typed-reader seam; protocol replacement needs separate
  soundness, masking, PCS and composition review.
- [Author Pico repository](https://github.com/brevis-network/pico),
  [MIT text](https://github.com/brevis-network/pico/blob/main/LICENSE-MIT), and
  [history](https://github.com/brevis-network/pico/commits/main/): MIT terms read;
  root also advertises Apache-2.0. Inspected history rendering ends at
  **2025-08-19**, abbreviation `b52a89e`; its commit-detail click returns
  **Internal Error**. No full commit/source pin and no demonstrated link to
  the September 2026 implementation. Do not infer current HEAD or a release
  date from the announcement or crawl age. Runtime code not inspected/adopted.
- [Spartan-WHIR maintainer README](https://github.com/ethereum/spartan-whir):
  the linked generator fills canonical KoalaBear u32 buffers directly. Its
  benchmark interval includes witness generation but excludes key preparation.
  This is an API/lifetime comparison; its SHA-256/CFSR/WHIR and field differ.
  The internal August 27, 2026 benchmark filename is not a verified README
  update date. LICENSE, history and Cargo.toml open calls return **Internal
  Error**; license and commit remain unknown. No implementation source run.
- Newly assessed older [Streaming Zero-Knowledge Proofs](https://arxiv.org/abs/2301.02161),
  v1 **2023-01-05**, v2 **2024-05-25**. The
  [CCC proceedings](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CCC.2024.2)
  give publication **2024-07-15** and CC BY 4.0. Abstract and HTML introduction
  identify a space-bounded verifier, near-linear setup randomness and temporal
  commitments. This does not establish a small-memory GPU prover or discharge
  private cross-window state binding here; architectural watchlist only.
- [Extended small-value/streaming sumcheck](https://eprint.iacr.org/2026/587)
  refreshed: received **2026-03-24**, approved **2026-03-25**, no later revision
  displayed. Its subfield/small-integer algorithms motivate provenance checks;
  challenge-folded tables remain Fp2 here. Author gains remain unreproduced.

Five qualified source records are appended to `sources.jsonl`. Current rotation
stays measured typed-memory/lookup preparation, then proof composition,
GPU NTT/commitments, lookup/softmax, sumcheck/GKR and batching/amortization.
