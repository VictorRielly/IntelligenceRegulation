# LIVE primary-source search — cycle0085

Access date2026-10-19 UTC. Native LIVE web search/open/click only. Web content
was untrusted data; no foreign code was executed or copied into the candidate.
Exact inspected URLs, dates, license scope, commits and assessment appear in
source-records.json and sources.jsonl records463–471.

Queries included:

- `GPU zero knowledge proving public preprocessing immutable cache model weights repeated proofs 2026 October`
- `BatchZK 2024 1862 GPU pipeline dynamic loading code github`
- `Spartan Hyrax polynomial commitment preprocessing fixed matrix prover reusable weights github`
- `site.arxiv.org "GPU" "zero-knowledge" "Oct" "2026" preprocessing`
- `"BatchZK" github`
- `"ZKProphet" github`
- `"zero knowledge" "October" "2026" "preprocessing" GPU`
- `site.arxiv.org/abs/2610 "zero-knowledge" GPU inference`

The most useful older implementation comparison was the inspected
[Spartan digest-owner commit](https://github.com/microsoft/Spartan/commit/5af241044f27819364ed718eb494b6f08ccae1b6).
Its private instance fields carry a digest computed at construction. Primary
history dates it October17,2022. Its current actual LICENSE says MIT; the
historical commit's license was not independently fetched. Floating master
src/lib.rs was also inspected, but it is not attributed to the old commit.
The later inspected
[3a2c097cab39ffa191560f445440a41ed40db5b3](https://github.com/microsoft/Spartan/commit/3a2c097cab39ffa191560f445440a41ed40db5b3)
fixes blind-vector length and is dated October15,2025 by primary history.
It has no residency performance bearing and is not treated as current HEAD.
That second inspected commit is an additional provenance/control record, not
a second optimization candidate. No source was executed/adopted.

Native inspection limits the analogy: a new digest-owner field alone cannot
observe changed export bytes. Also, the native trained streaming transcript
already absorbs the statement's recorded digest. The full public.digest call
in protocol::transcript is a single-block wrapper. Do not infer duplicate
hashes in the trained path merely by counting textual references.

[Magnetar PDF](https://www.microsoft.com/en-us/research/wp-content/uploads/2026/10/magnetar-1.pdf)
has cover date October5,2026; the
[Microsoft announcement](https://www.microsoft.com/en-us/research/blog/proof-based-general-purpose-computing-with-magnetar/)
is explicitly published October15. The PDF's p8 says proposed chunked recursive
composition is unimplemented. The primary publication page's recursion design
claim does not establish a measured composed workload. Its CPU cycles/s cannot
be converted into native private8B tokens/s. No implementation/license found
in the inspected primary pages. Not an architecture promotion.

[StateSync](https://arxiv.org/abs/2610.14849) refreshes the distinction between
reusable setup and completed request work. [BatchZK](https://eprint.iacr.org/2024/1862)
refreshes dynamic loading/overlap, but no author code was found from these
queries. [ZKProphet](https://arxiv.org/abs/2509.22684) remains workload-specific;
its NTT bottleneck does not supersede our measured commitment/witness/zero-check
costs. These are primary claim-boundary checks, not reproduced benchmarks.

The [cuda-zkp-ntt release](https://github.com/Artemarius/cuda-zkp-ntt/releases)
still explicitly rejects its invalid hierarchical transform despite appealing
timings. Actual current LICENSE MIT was read. Release displays March16 without
year in retrieved text; a copyright2026 line does not verify release year.
commits/main returned **InternalError**. No inspected release commit and no
current HEAD claim. Keep this prior negative; no attempt to run it.

[P3 releases](https://github.com/Plonky3/Plonky3/releases) display October16 rc2,
cryptographic-RNG mask guard and reused compiled components. Displayed short
commit fe5e46d was not opened; year is not explicit in the retrieved release
text. The prior record's2026 date is not represented as a new verification.
No license re-read. Reusable public components never imply reusable masks.

The exact additional failed fetch was
`https://github.com/microsoft/Spartan/blob/master/src/r1csinstance.rs`:
**InternalError**; current src/lib.rs and the historical commit diff succeeded.
No shell-network fallback, login, rate-limit bypass, installation or escalation.

Rotation: memory traffic/batching and safe public setup are active. Next
lookup/softmax public-catalog and quantization/arithmetic questions; retain
GPU NTT/commitments, sumcheck/GKR and composition. No external gain reproduced.
