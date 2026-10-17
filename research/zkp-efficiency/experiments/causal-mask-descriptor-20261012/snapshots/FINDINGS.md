# ZKP efficiency findings

## Cycle 0001 — 2026-09-22

**Best immediate lead: exploit equality-polynomial structure inside the existing
sumcheck evaluator.** The first isolated experiment produces identical field
messages and final evaluations. It is a candidate for native evaluation, not a
measured model speedup. Current project status still lacks a complete trained
8B GPU proof; five seconds remains unachieved.

The local reference is the frozen R1d candidate described in
`results/zk60_sumcheck_rounds_20260922/README.md`. Its `SumcheckRounds` interface
already isolates arithmetic from transcript/masking. Current commitments use
Goldilocks and challenges use its quadratic extension (`u²=7`).

| Priority | Lead and primary evidence | Fit / next gate |
|---|---|---|
| 1 | The [March 2026 extended sumcheck paper](https://eprint.iacr.org/2026/587) studies equality-factor structure, small values and high-degree/streaming algorithms; an [author's September explanation](https://www.cs.cmu.edu/~csd-phd-blog/2026/sumcheck-proving/) highlights round batching. The authors report benefits inside Jolt. | Equality factoring fits the existing evaluator seam. The local PoC tests one factor, not the entire softmax host. Next: exact multi-group SC_SZC oracle. |
| 2 | [TensorZKP, USENIX Security 2026](https://www.usenix.org/system/files/usenixsecurity26-lu-tao.pdf) maps finite-field work to limb matrix operations and Tensor Cores. Its evaluation uses H100 80 GB, BabyBear extension degree eight, HyperPlonk and Brakedown. | Promising GPU direction, but its encoder is Spielman coding, not our NTT. First build exact Goldilocks/Fp2 limb oracles and bounds. No hardware number is transferred here. |
| 3 | [Monomial-basis sumcheck, April 2026](https://eprint.iacr.org/2026/762) changes the interpolation domain/round identities and reports about 10% prover benefit in its fields. [Plonky3 issue 1890](https://github.com/Plonky3/Plonky3/issues/1890), opened June 22, discusses evaluating that idea. | Track separately. A projective protocol change is not automatically compatible with our transcript, masking and PCS; the issue is not evidence of an adopted implementation. |
| 4 | [DeepProve's model runner](https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/README.md) documents full transformer operations, integer calibration, cached parameters, and CPU/CUDA interfaces. | Useful trained-model integration reference. Its HyperKZG/BN254, quantization and endpoint/privacy contracts differ. README claims and CPU examples do not demonstrate our five-second private target. |
| 5 | [Jolt](https://github.com/a16z/jolt), [EPFL efficient-sumcheck](https://github.com/compsec-epfl/efficient-sumcheck), and [ZKSecurity's Sage illustrations](https://github.com/zksecurity/sumcheck-optimized-sagemath) provide implementation/reference leads. | Inspect algorithms and small test vectors before adopting code. No code fetched or executed; no release date or commit hash was established in this cycle. |
| Baseline | [zkLLM's official CUDA implementation](https://github.com/jvhs0706/zkllm-ccs2024) links the CCS 2024 system. | Useful attention/lookup baseline; an older reference, not evidence of a newly achieved performance target. |

### Executed experiment

`python3 research/zkp-efficiency/experiments/eq_factor_rounds.py` passes in about
0.24 seconds. The candidate splits the equality table, factors the current
coordinate outside the sum, reconstructs the missing highest-degree sample,
and uses the actual preceding unmasked sum where valid. All arithmetic is exact
over the project's Fp2. The reference already skips the redundant `s(1)`
evaluation after its first round.

At 1,024 rows, inner product evaluations fell from **3,581 to 2,558** for an
inner degree-two expression, and **4,604 to 3,581** for degree three. Retained
equality-table entries fell from 1,024 to at most 48; this excludes witness
tables and is not peak RSS. All four runs per degree have the same toy transcript
digest. Python timings are retained as diagnostics, not extrapolated to Rust,
GPU, model performance or privacy. [Results and limitations](experiments/README.md).

### Negative findings / limits that change the next action

1. **The complete softmax host has no single common equality factor.** In the
   inspected `argument.rs`, `SC_SZC` adds terms weighted by `tau`, `p_ht`, and
   `p_s`. Pulling one factor outside that sum is wrong; the PoC records a
   counterexample to that rewrite. Factor eligible groups separately.
2. A global host claim does not supply each group's sum. The experiment's
   recover-`h(1)` shortcut cannot be copied independently into all groups.
3. Assuming all initial tables are base-valued is unsound. The local IR's
   provenance explicitly identifies challenge-weighted public tables and fixed
   coordinates as extension-valued. The PoC includes full-extension data.
4. TensorZKP's reported 215.28 ms for 2²⁵ multiplication gates is an author
   measurement for a different system. The paper reports about 53 GB at that
   scale and larger single-device cases run out of memory; neither figure
   constitutes an 8B/512-token result. An official code repository was not
   located by this bounded search. [Paper, evaluation section](https://www.usenix.org/system/files/usenixsecurity26-lu-tao.pdf).
5. DeepProve's README distinguishes inference/PCS GPU support and lists CPU
   transformer benchmarks in minutes. It is a source of integration ideas,
   not a demonstrated drop-in five-second prover. Its privacy compatibility
   was not audited. [Maintainer documentation](https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/README.md).

No native receipt, masking implementation, verifier, GPU kernel or source of
randomness changed in this cycle. No whole-proof security claim follows from
this algebra experiment.

## Cycle 0002 — 2026-09-24 — SC_SZC groups and GPU-memory triage

Run `20260924T024433Z-0c043a75`. **Progress: a source-derived multi-group
softmax evaluator passes exact differential checks and reduces counted
bracket evaluations. No native, GPU, full-proof speed or privacy improvement
is established.** Production and runtime files remain untouched.

### Current bottleneck and ranking

Read the current project instructions, MVP status, decisions (including the
September 23 updates and proposed D23), active coordination and latest R1d
measurement summary. The two candidate 125M dense-block CPU runs spend
8.551/8.590 s in softmax sumcheck, with total proving 38.06/43.02 s; shared
two-thread measurements, extra test oracles included, no overall speedup
established. Separately, the stage-0.5 commitment ledger uses 22 Rayon
threads: A encode/hash 1.270/0.338 s and H 1.631/0.438 s, roughly 3.7:1.
Those clocks are different experiments and cannot be added or extrapolated
to a complete 8B proof. The public 58.40 s Mistral result remains FFN-only.

| Priority | Candidate and expected end-to-end relevance | Prerequisites / integration / exactness and privacy |
|---|---|---|
| 1, tested algebra | Group-specific equality evaluation in SC_SZC, using the equality-factor literature and each group's own computed running sum. Targets the measured slow slot; limited whole-proof reach. | Moderate Rust evaluator work behind R1d; exact field samples; native closure/IR and masked/RNG parity remain owed. No subgroup messages or protocol changes. [Handoff](handoffs/20260924-sc-szc-groups.md). |
| 2, next rotation | Goldilocks NTT layouts and memory traffic. [Qingming's benchmark contract](https://github.com/uulong950/qingming-g64-ntt/blob/main/docs/BENCHMARK_CONTRACT.md) reports a fast device-resident forward transform, with layout/transfer costs separate. Encoding is a measured commitment bottleneck locally. | Same prime helps, but HIP-to-CUDA, 2^27 single transform to many 2^16 rows, natural-order outputs, inverse NTT, coset and hiding-pad semantics impose substantial port work. MIT inspected; abbreviated docs commit `764f98e`, July 1. No timing transferred. |
| 3, newly assessed older technique | [Proving CPU Executions in Small Space (2025)](https://eprint.iacr.org/2025/611): streaming/prefix-suffix recomputation could relieve memory capacity or paging. | Moderate/high integration; may increase arithmetic and latency. Need a byte-traffic model including existing PCS storage before testing. Abstract/indexed roadmap only; PDF fetch blocked. Exactness and masked transcript need preservation. |
| 4, algorithm lead | [SumCATS (DATE 2026)](https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf): fewer global reads and GPU reduction/layout changes. | Binary towers and initial binary tables differ from our extension-valued helpers. Paper reports small A100 cases slower than baseline. Nested repository README states MIT; licensing of additions and commit not pinned. No blanket or model-speed claim. |

[NanoZK v2](https://arxiv.org/abs/2603.18046) was revised July 18, 2026:
its approximated nonlinear functions and per-layer commitment chain are not
a drop-in for our exact quantized relation and D12 composition. Its GPU
numbers are projections. Full verification still requires every layer;
Fisher-guided partial auditing does not satisfy the target. [SumcheckPIM](https://csarch.korea.ac.kr/publication/pim_sumcheck_ics26/)
requires specialized HBM hardware, so it informs memory-locality ideas only.
ICICLE v4 release notes were checked for sumcheck/program interfaces, but the
displayed July 11 date lacked a verified year and is **not** called a 2026
release; Goldilocks compatibility was not established. These are bounded
dispositions, not additional experiments.

### Experiment and interpretation

The [self-contained experiment](experiments/sc-szc-groups-20260924/README.md)
ports all SC_SZC clause types, three distinct equality points, short `p_ht`
support, hosted terms and both pad gates, using synthetic plane/lookup maps.
The separate oracle expands the scalar expression and evaluates original
tables by the direct cube-MLE definition. **23 cases, 189 independent round
points, five detected negative controls, four zero-factor fallback rounds,
and two malformed fixture refusals pass**, in 2.884 s with 23,428 KiB RSS.

At 256 rows, the expensive padded ZC bracket needs **1,148 evaluations instead
of 1,403 (18.2% fewer)**. Each much cheaper hosted bracket falls 1,403 → 638.
Unpadded counts are 1,148 → 893 and 1,148 → 383 respectively. Counts do not
price table traffic, interpolation, inversions or folds, and summing counts
as equal-cost operations would overstate the saving. No timing ratio claimed.

The important new mechanism is retaining each group's **actual** round
polynomial and interpolating it at the unchanged driver's challenge. This
produces a valid next subgroup claim without relying on an asserted host
claim. The first round computes enough samples explicitly; zero factors
fall back rather than discarding challenges. A control using the combined
claim independently for each group fails as expected. Additional controls
detect the wrong support gate, extending `p_ht` onto j, a changed limb and
factoring one equality out of the full sum. Arbitrary invalid witness values
are deliberately included; no new prover refusal is inferred.

**Remaining boundary:** the scalar formula and MLE algorithm are independently
checked, but native Layout wiring, Rust closure/IR execution, CFS masking,
RNG consumption, extension rounds and full receipts have not been tested.
The handoff is an algorithm candidate, not a Rust patch awaiting merge.
Native work belongs to the main owner under build/heavy locks. D22 remains
the specific accepted toy CPU artifact; no wider privacy or soundness ruling
is altered. The target is still the complete private 8B attention-plus-FFN
512-token prefill in five seconds, never autoregressive throughput.

### Source/access corrections and next action

- Native LIVE search refreshed September sumcheck discussion, 2026 GPU papers,
  releases, Goldilocks repositories, softmax/lookup composition and older
  memory techniques. Eleven dated source/disposition records appended.
- Live ePrint metadata corrects the prior 2024/1210 received date to
  **2024-07-27**; the original July 28 entry is preserved as superseded.
- Several GitHub commit/license fetches returned cache misses; metadata API
  URLs were inaccessible through the tool; the 2025/611 PDF returned a
  robots.txt denial. Null dates/licenses and abbreviated commit IDs are
  labelled. No shell network client, installation, GPU or bypass used.
- Queue rotates to **GPU NTT/commitments**, then lookup/softmax, memory
  traffic, batching/amortization, quantization/arithmetic, proof composition,
  and sumcheck/GKR. Next local test: a small Goldilocks radix/layout oracle
  comparing natural-order hiding row encodes with an explicitly permuted
  output path, including pad/coset and q>n overlap controls. Existing row
  conformance vectors are the read-only reference; do not duplicate main's
  R2a allocation implementation or launch a device benchmark.


## Cycle 0003 — 2026-09-26 — hiding-row NTT layout and pad overlap

Run `20260926T185233Z-aa002e55`. **Exact compatibility result and a small
correctness repair candidate; no measured proving improvement.** The fixed
current target is >=50 proved prefill tokens/s: <=10.24 s for the complete
private 8B/512 attention-plus-FFN contract, including witness preparation and
serialization. Five seconds is a stretch goal. Older cycle text naming only
five seconds is historical. No autoregressive claim follows.

### Current evidence and ranked choices

Re-read research memory, the separate forward-budget results, project
CLAUDE/MVP status/decisions/active coordination, current native candidate
records, conformance contract and relevant Rust/CUDA sources. The newer
`results/zk60_grouped_rounds_20260926/validation-1/validation.json` is **passed**:
nine CPU steps including the full native suite (README: 512 passed, 17 ignored).
Its dense A/B record says `waiting-for-heavy-lock`, with no runs. This
supersedes the status page's earlier queued-validation note; it is another
owner's retained evidence, not a native test performed by this cycle.
R2a shared two-thread timings remain inconclusive. Earlier 22-thread isolated
commitment measurements put encode around 51%, allocation/zero around 35–39%,
column hashes 13–14%; A encode/hash 1.270/0.338 s, H 1.631/0.438 s. They must
not be combined with the two-thread block clocks or extrapolated to 8B.

| Rank | Candidate / expected complete-proof relevance | Prerequisites, integration cost, exactness and privacy |
|---|---|---|
| 1 for this rotation | Batched NTT and mapped-layout consumption: targets measured encoding cost. Exact small adapter passes. No runtime gain found. | Moderate/high CUDA work. Existing Rust store can hide physical order only if leaves and gathered columns are identical. Actual hash/device/proof tests required. Current CUDA already stores natural order and fuses opening gathers, so there is no existing restore copy to remove. |
| 2 | Pair-table caching for exponential/activation lookup helpers: next small experiment; source still batch-inverts their full witness-length arrays. | Moderate Rust helper work. Existing byte-table cache already exists and is not a new idea. Cache only exact public pairs, preserve fallback for arbitrary invalid pairs, all table-denominator refusals, order and transcript. No changed numerical relation. |
| 3 | Older four-step/merged GPU NTT family, now reviewed through [GPU-NTT](https://github.com/Alisah-Ozcan/GPU-NTT) and [2023 paper](https://eprint.iacr.org/2023/1410). | Batched forward/inverse interface is relevant; full-width Goldilocks reduction still unverified. Apache-2.0 inspected, history abbreviation only; no code adoption or execution. |
| 4 | [2026 matched-hardware NTT/sumcheck comparison](https://arxiv.org/abs/2606.16146). | Useful locality/accounting evidence, abstract only. Protocol substitution has high soundness/privacy and integration cost; deferred. No kernel rate converted to a model target. |

The new [Qingming CUDA artifact](https://github.com/uulong950/qingming-g64-ntt-cuda)
is a layout lead, but its inspected source/report and README are not revision-
aligned, its license was not established, and its advertised transform sizes
are outside this experiment. Source records retain those gaps. No claim of a
new September release or reproduced upstream speed is made.

### Reproduced result and negative findings

[Experiment](experiments/ntt-mapped-layout-20260926/README.md): inverse DIF,
additive pad/coset access, mixed-radix forward with mapped output, and natural
logical-column adapter. **90 synthetic cases, 240 layout comparisons, 10,560
direct output points, 360 independent Lagrange checks and all 15 existing
small conformance vectors pass**. All 64 columns of a five-row store match
byte for byte, including chunk concatenation and repeated unsorted queries.
Nine negative controls detect wrong order, inverse map, missing coset,
wrong inverse scale, missing twiddle, pad overlap/mutation, lost duplicates
and changed row order. Three malformed algebra fixtures are refused.
Final execution: **0.5113 s, 16,968 KiB RSS**, one CPU, seed 20260926.
No native BLAKE3, proof serialization, verifier or GPU was run; proof-generation,
verification and complete-readiness clocks are explicitly null.

**Concrete source finding:** current `k_zk_pad_scale` fails the CPU polynomial
contract at admitted n+q<=nn shapes with q>n in a scalar transcription.
The data branch alone subtracts pads, dropping the negative contribution in
the overlap n<=i<q. Closed-form case n=8, nn=32, q=9, zero message and only
pad[8]=1: required x^16-x^8, inspected branch x^16; all 32 coset points differ.
q<=n controls pass. The actual caller only checks n+q<=nn; reviewed existing
pad-boundary tests use q<=n. This has **not** been executed on device, and
no affected production receipt or privacy failure is inferred.
[Unapplied patch and owner handoff](handoffs/20260926-ntt-layout-and-pad-overlap.md)
include exact source hashes and required resident/chunked/opening gates.

A mapped backend could avoid `16*rows*nn` bytes of an EXTRA restoration copy,
if it otherwise made one. At nn=65,536 that is 1,048,576 counted bytes/row.
**Negative disposition:** the existing natural-output CUDA path has no such
copy, so this is not a saving on that code. Mapping may worsen memory access.
The useful result is an exact acceptance oracle, plus the boundary repair.
No D19b/D23 ruling or D22 CPU-to-GPU/wider-profile acceptance changed.

### Durable follow-up and access

Six source records appended with access dates, verified/unknown update dates,
license scope and abbreviated-commit limitations. Native web search worked;
Qingming LICENSE returned Internal Error, two commit detail pages and its
release page returned Cache miss, and the primary journal PDF timed out.
No shell-network fallback or bypass used; the independent experiment completed.

The separate session's [forward-budget handoff](handoffs/20260926-forward-budget-and-traffic.md)
and source-record file remain intact; their fourteen checks are accounting,
not runtime measurements. They correct historical FFN process elapsed to
200.09 s (internal wall 196.79 s), still excluding prior witness export.
Their Mistral geometry does not identify an 8B checkpoint.

Next rotation: lookup/softmax, then memory traffic, batching/amortization,
quantization/arithmetic, proof composition, sumcheck/GKR, GPU NTT/commitments.
The next local experiment is exact pair-table inverse caching at
`private_block/protocol.rs` exp/activation helpers, including invalid pair
fallback, challenge collisions, unused zero-denominator entries, refusal
ordering and full public-table checks. Native/device review of this cycle's
patch belongs to main; no build/heavy/GPU job was launched or queued here.


## Cycle 0004 — 2026-09-26 — exact pair-table inverse cache

Run `20260926T195233Z-cef0b7d6`. **The arithmetic shortcut passes, but its
measured phase is too small to be a major end-to-end lever. No proving
improvement is established.** This run retains its explicit complete private
8B attention-plus-FFN 512-token prefill target: >=50 proved tokens/s,
<=10.24 s including witness/pre-proof preparation and serialization; five
seconds remains a stretch. Newer project notes permit larger workloads for
amortization; they are recorded without silently changing this run's target.
Neither interpretation establishes autoregressive decode throughput.

### Current bottleneck and ranked candidates

Read current project instructions/status/decisions/active coordination and
retained R2a and grouped-candidate results. Grouped correctness has passed;
its dense A/B still says `waiting-for-heavy-lock`, no runs. No duplicate job.
The **latest R2a non-warm candidate** spends 0.232/0.217 s on exp+activation
helper inversions, for 39.733/40.095 s proving: **0.58/0.54%**. Witness
preparation 8.35/7.26 s and serialization 0.024/0.027 s make the known sums
48.107/47.382 s, separate from internal verification 0.964/0.976 s (from-bytes
0.98/0.99 s). Removing that WHOLE helper phase saves **less than 0.5%**
of those accounted readiness sums. This candidate retains work and may save
less or nothing. These are another owner's synthetic dense 125M, shared
two-thread CPU logs with compilation overlap, not enclosing request clocks,
new benchmarks or 8B/GPU projections. Earlier R1d logs are separately pinned
in [bottleneck.json](experiments/pair-inverse-cache-20260926/bottleneck.json).

| Priority by expected end-to-end relevance | Lead and prerequisites | Exactness / integration / privacy |
|---|---|---|
| 1, next rotation | Fused fold/next-round evaluation targets the much larger softmax slot and avoids a table reread. Plonky3's [v0.8.0 release notes](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0) list bind/measure fusion in ordinary and hiding drivers. | Moderate evaluator work behind the existing `SumcheckRounds::fold/round` seam. Preserve MSB pairing, group claims, zero factors, masked challenge schedule and final table order. Exact source/PR fetches blocked; implementation and gain not reproduced. |
| 2, larger research change | Newly assessed [fractional-GKR LogUp technique](https://eprint.iacr.org/2023/1284), revised 2025-02-20, now represented by [Plonky3 PR 1968](https://github.com/Plonky3/Plonky3/pull/1968), merged 2026-09-07. Could reduce committed helper columns, a larger cost center than their inversion. | High integration and analysis cost. H masks, table links, padding, transcript, PCS and whole-proof composition need redesign/review. The PR describes explicit lookup-to-zerocheck binding fixes. No assumption that an external implementation preserves our private view. |
| 3, tested and handed off | Exact-pair inverse cache. Existing U8 cache is already implemented; this extends only exp/activation preparation. At most about 0.6% of present candidate proving phase is exposed. | Small Rust patch; independent algebra passes. Native receipt/RNG/refusal gates still owed. More table comparisons/cache reads; unchanged H output/commitment. Invalid-heavy and small-column cases can regress. |
| 4, deferred arithmetic lead | [Nonlinear-function lookup revision](https://eprint.iacr.org/2025/507) uses digit decomposition and small tables. Primary page identifies a 2025 revision of USENIX Security 2024 work. | Current tables already contain only 256 public pairs; oversized-table reduction is not this bottleneck. ROM-based protocol, numerical semantics and truncation differ, so no quoted author speed transfers. |

The underlying [LogUp paper](https://eprint.iacr.org/2022/1530), received
2022-11-04 and revised 2025-02-20, supplies the reciprocal/multiplicity
context; it is not evidence for a new native speed result. GPU NTT and
commitment work remains important and its prior findings are preserved.

### Experiment and negative findings

[Self-contained experiment](experiments/pair-inverse-cache-20260926/README.md):
**76 differential cases, 21,015 independent coefficient solves, 41 pipeline
stage/refusal models and 11 negative controls pass**, seed 2026092604.
Tables 1/4/16/256, columns 0/1/31/257/16384, arbitrary extension challenges,
beta=0, compressed-pair collisions, used/unused zero denominators, extreme
signed/invalid indices and altered values. The independent inverse uses
Euclidean modular inversion instead of the candidate/reference batch method;
a second table-helper oracle independently builds multiplicities/padding.
Final script 0.2075 s, 26,292 KiB RSS, one CPU. The earlier successful narrower
version is retained. No proof was run; proving, verification and complete
readiness fields are null, not zero or the script's runtime.

The candidate uses a cache only for exact public `(index,value)` pairs.
Other pairs retain original denominator arithmetic. Zero cache entries do
not refuse until used; every whole-table inversion still runs later, in the
same source-derived phase order. Public tables repeat modulo 256 in padded
rows, but their histogram multiplicities pad with zeros. No masking/RNG draw,
lookup relation, H row, public transcript or proof format is intentionally
changed. Native parity is nevertheless untested.

At 16,384 valid words, batch multiplication counts fall **49,152 to 768**,
with one field inversion in each path. That is **not a 64x runtime speedup**:
input scans, output writes, table checks, H commitment and later table helper
work remain. A 31-word column and 256-entry cache instead cost 93 vs 768
batch multiplications. For 257 invalid pairs the candidate performs 258 field
inversions vs one reference inversion. These negatives rule out a universal
fast path without workload/crossover measurement.

Controls detect index-only caching, negative/modulo index aliasing, stale
challenge/tag caches, eager unused-zero refusal, skipped whole-table/zero-
multiplicity inversions, preempted stage order, repeated padded histograms,
and dropped multiplicities. The refusal-order evidence is a helper schedule
model, not a replay of native transcript events or a full privacy proof.

[Owner handoff](handoffs/20260926-pair-inverse-cache.md) retains two proposed
Rust helpers and a **70-line unapplied patch** against the inspected shaped
candidate's `private_block/protocol.rs` at the exp/activation seam. Source
hashes/excerpts and in-memory patch checks accompany it. No compile, native
receipt test, integration, production/reviewer edit or GPU job occurred.
D22 remains the specific accepted CPU toy; D19b/D23 remain proposed.

### Access and next experiment

Native LIVE search worked; five primary-source records appended with access
dates and date/license/commit qualifications. The Plonky3 release page shows
September 23 without a year in the exposed text: the exact date remains null,
not inferred from crawl age. Full commit IDs came from hyperlinks, but commit
content could not be fetched. MIT text on main was inspected; a versioned
license could not be read. docs.rs/latest served 0.7.0, while the requested
0.8.0 page failed. Source/commit/PR pages returned cache misses; the GKR PDF
was denied by robots.txt. No alternate network client or bypass was used.

Next **memory traffic** experiment: for four synthetic tables, compare
`fold(r)` followed by next-round evaluation against a tiled four-quarter load
that forms both next-round endpoints and accumulates the same polynomial
samples in one pass. Count reads/writes and scratch, compare every Fp2 sample
and final against a direct MLE oracle; include n=2 final-fold handling,
non-power-of-two chunk boundaries, full-extension r, zero equality factors,
and a wrong-quarter negative control. Then restore the SC_SZC groups only
if the simpler fusion passes. Remaining queue: batching/amortization ->
quantization/arithmetic -> proof composition -> sumcheck/GKR -> GPU
NTT/commitments -> lookup/softmax. Main owns all native/heavy/device follow-up.


## Cycle 0005 — 2026-09-26 — fuse fold and next-round sampling

Run `20260926T205233Z-79c00f5e`. **An exact synthetic evaluator avoids a
next-round table reread; no native or end-to-end speed gain is measured.**
Read STATE/FINDINGS/source history, latest results, AGENDA, project
CLAUDE/status/decisions/active coordination and current throughput accounting.
The complete private 8B target stays >=50 proved tokens/s, with preparation
and serialization included. At the 512-token prefill reference that is
<=10.24 seconds; five seconds is a stretch. Larger-workload amortization is
an additional project direction, with total and sustained clocks retained.
No prefill result establishes decode throughput or new privacy acceptance.

### Current bottleneck and ranked hypotheses

The latest R2a non-warm source logs show slot-17 masked sumcheck
**9.858/9.686 s**, proving **39.733/40.095 s**, witness **8.35/7.26 s**,
serialization **.024/.027 s**, giving known preparation+prove+serialization
sums **48.107/47.382 s**. Internal verification is **.964/.976 s**;
verification from bytes **.98/.99 s**, separate. Removing the ENTIRE measured
sumcheck phase would save about **20.4%** of those known sums; fusion removes
only its reread and cannot claim that ceiling as a saving. Fold/read/cache
attribution is missing. These owner logs are synthetic dense 125M block,
shared two-thread CPU with compilation overlap, not enclosing request clocks
or GPU/8B measurements. [Pins and clocks](experiments/fused-fold-round-20260926/bottleneck.json).
The grouped candidate's dense A/B still records waiting-for-heavy-lock with
no runs; no duplicate queued or process-liveness inference made.

| Rank by expected usable end-to-end value | Hypothesis, prerequisites and cost | Exactness / privacy / falsification |
|---|---|---|
| 1, tested arithmetic | Fuse folds with next-round accumulation; moderate evaluator work, no protocol change. Removes a measured-code reread, but phase saving unknown. | Preserve MSB order, actual unmasked claims, all tables/finals and driver schedule. Native masked/RNG/extension/receipt gates still owed; cache hits or parallel/reg-pressure regressions could eliminate the benefit. |
| 2, newly refined batching question | Batch public int8 weight contractions for B independent fresh challenge vectors at `fold_cols_i8`, reading each weight tile once. Native P1 has no W commitment, and public objects already own reusable weights, so do not import a legacy W-commit cache saving. | Exact signed arithmetic and padding; per-proof challenges/masks remain separate. Requires several proofs reaching the same stage, additional accumulators and possibly prohibitive witness residency. Falsify via direct contractions, changed-challenge controls and an honest traffic/lifetime model; phase time is unmeasured. |
| 3, potentially larger but high cost | Fractional-GKR lookup design may reduce helper commitment columns, a larger phase than inverse preparation. | Separate protocol/PCS/masked-channel/composition analysis and review required. Prior source records stand; no implementation or privacy claim added. |
| 4, owner follow-up | Prior NTT pad-overlap correction and mapped-layout oracle. | Device parity remains owed; no existing restore-copy saving exists. Retain negative findings. |

### Reproduced experiment

[Self-contained experiment](experiments/fused-fold-round-20260926/README.md)
passes **108 differential cases, 180 full-cube direct-MLE round checks,
432 direct final evaluations, 54 synthetic masked-driver comparisons,
eight mutations, ten schedule refusals and eight malformed-fixture refusals**.
Four tables, lengths 1..1024, degree 2/3, full Fp2 and base values, vanishing
equality factors, zero/one/extension challenges, recovery on/off, chunks
1/3/7 including tails and reversed order. The reference uses separate
non-mutating passes; the direct cube oracle also uses independently expressed
field multiplication. Intermediate tables match after every fold.
**2.7433 s, 17,700 KiB RSS, one CPU**, seed 2026092605; limits enforced in
script. The first successful version is retained under `initial/`.

At old length 4q, fold quarters (0,2) and (1,3) into the two next-round
endpoints, write them into quarters (0,1), and sample while values are live.
Length two folds to final values without attempting another round. The
pending (requested) and ready (precomputed) round states are distinct.
Claim recovery uses the preceding actual unmasked polynomial, evaluated at
the unchanged driver challenge. Arbitrary table contents remain supported.

Four 1,024-row tables: **16,368 -> 12,280 counted Fp2 reads**, both write
4,092; logical table traffic **327,360 -> 261,952 bytes (19.98% less)**.
Polynomial call counts are unchanged. Across rounds, reads approach 25%
less and reads+writes approach 20% less. This excludes hardware caches,
write allocation, reduction/scratch traffic, finals and driver work; it is
**not** a DRAM measurement or runtime speedup. Final proof-generation,
verification and complete-readiness measurements are null.

[Handoff](handoffs/20260926-fused-fold-round.md) includes source snapshots and
an **uncompiled/unapplied serial Rust helper** at the proposed
`SumcheckRounds::{round,fold,finals}` seam. This is not a replacement for the
current parallel implementation. SC_SZC currently selects `GroupedEqRounds`;
it needs a grouped adaptation preserving per-group claims, prefix/suffix
updates, zero-factor fallbacks and equality tables. Reverting it to a generic
sampler would lose the already-tested arithmetic optimization. Native masked
transcripts, RNG, extension rounds, proofs and GPU execution remain untested.

### Primary-source assessment and next action

LIVE search refreshed [Plonky3's release list](https://github.com/Plonky3/Plonky3/releases),
including additional fusion across single-round calls and suffix-order/in-place
follow-ups. Main MIT text was inspected; code/PR/package pages were blocked by
Cache miss/Internal Error. The displayed September 23 release date lacks a
verified year, so exact publication/update dates remain null. Release target
is labelled abbreviated; no upstream code or performance was reproduced.

Newly assessed older [Thaler regular-circuit work reuse](https://arxiv.org/abs/1304.3812)
(first 2013-04-13, revised 2017-02-08) explains why geometric shrinking
matters; the local evaluator already has it, so it supplies no new asymptotic
gain here. The recent [GPU instruction-throughput study](https://arxiv.org/abs/2608.13696)
(2026-08-13) motivates measuring caches/occupancy/instruction work rather than
converting logical bytes into time; it studies database workloads, not our
proofs. Three dated source records appended; exact access limitations retained.
No shell-network fallback, external code execution or approval request.

Next rotation: **batching/amortization**. Test fresh-challenge batched
`fold_cols_i8` on small padded signed matrices for B=1/2/4/8 versus independent
contractions, with direct Fp2 integer-dot references and stale-challenge,
padding, sign-extension and mixed-model controls. Count all weight reads,
challenge-vector reads, accumulators and outputs. Inspect source scheduling
before assuming simultaneously available challenges or affordable concurrent
witnesses. Remaining queue: quantization/arithmetic -> proof composition ->
sumcheck/GKR -> GPU NTT/commitments -> lookup/softmax -> memory traffic.


## Cycle 0006 — 2026-09-26 — public-weight batching has a tiny phase ceiling

Run `20260926T215233Z-c6bf3a4b`. **385 arithmetic cases pass, but native
timings demote this candidate: its three enclosing slots account for less
than 0.1% of known readiness in the current CPU fixture. No complete-proof
speed improvement was established.** Read durable state/history/latest
results, AGENDA, project CLAUDE/status/decisions/coordination and throughput
accounting; checkpointed early. All writes stay in research, outside runtime.

The complete private 8B attention-plus-FFN target remains >=50 proved tokens/s,
including witness/pre-proof preparation and serialization. The 512-token
prefill reference is <=10.24 s; five seconds remains a stretch. The additional
larger-workload direction requires both total and sustained rates. No prefill
number establishes decode throughput; D22 remains the named CPU toy, with
D19b/D23 still proposed.

### Updated bottleneck evidence and ranking

**The grouped A/B has finished.** Its `dense-ab-1/comparison.json` says passed,
`run.done` is zero, and retained non-warm log hashes match. Earlier queued
entries in this research history and the owner's README are now stale; they
remain preserved. No process liveness is inferred and no job was duplicated.
New-arm proving **34.861/33.315 s**, witness **5.43/5.76 s**, serialization
**.031/.020 s** give known readiness sums **40.322/39.095 s**. Internal
verification **.900/.810 s**, from-bytes **.91/.82 s**, is separate. All receipts
remain 40,783,352 B. These are owner's dense synthetic 125M block runs on a
shared CPU with two Rayon threads, not enclosing request/GPU/8B measurements.
[Raw-log pins and accounting](experiments/batched-weight-fold-20260926/bottleneck.json).

The three complete FFN matmul slots took **.035/.032 s**. The inspected loop
calls both `define` and `run_slot` before recording each slot; the public-weight
fold is included. Deleting all three would save only **.087%/.082%** of known
readiness, from rounded phase clocks. Batching removes much less. Fold-only
attribution is absent, but is no longer needed to reject this as a major lever
at the measured shape. Slot RSS **8,548/8,591 MiB** is whole-process memory,
not a per-proof incremental requirement or a tested concurrency forecast.

For context, old-arm proving was 37.630/36.836 s. Complete softmax slot time
was 10.050/10.085 s old versus 8.601/7.832 s new. This is positive owner
diagnostic evidence for grouped evaluation, with only two non-warm runs per
arm on a shared box; it is neither this cycle's reproduced benchmark nor a
quiesced end-to-end result. A+H encode/Merkle is 16.739/16.903 s in the new
arms, much larger than public-weight contraction.

| Priority | Candidate and end-to-end relevance | Prerequisites, cost, exactness and privacy |
|---|---|---|
| 1, next bounded research test | Exact Fp2 Karatsuba and specialized squaring at `zkp-core/src/field.rs`. Current multiplication uses four variable base products plus multiplication by seven; square calls the same routine. Larger sumchecks use this arithmetic. | Small arithmetic seam, broad validation scope. Compare canonical bytes to independent polynomial reduction; count extra additions and reductions. No assumed runtime win: carry handling, compiler output and instruction dependency may dominate. Keep field/modulus/transcript unchanged. |
| 2, owner continuation | Group-aware fold/next-round fusion and GPU commitment memory work target materially larger phases. Existing fusion/pad-overlap oracles remain available. | Moderate native/device integration; preserve equality-group savings and pad semantics. Source-specific native/RNG/receipt/device gates remain owed. Tagged CPU fallback is not a measured GPU path. |
| 3, larger architecture | Fractional-GKR helper-column reduction could reduce H commitment work. ZKTorch/CQLin are alternative composition/preprocessing leads. | High PCS, masking, setup and soundness/composition cost. KZG preprocessing is not a patch for the current Merkle PCS. No privacy acceptance transfers. |
| 4, tested and demoted | B public int8 weight contractions with independently supplied challenges. | Arithmetic exact; small kernel but substantial proof rendezvous/lifetime work. Current complete-slot ceiling <0.1% and whole-process RSS make scheduling work unattractive. Revisit only if larger-model phase attribution reverses this. |

### Experiment and decisive negatives

[Experiment](experiments/batched-weight-fold-20260926/README.md): **385 cases,
29,290 compared field outputs, 13,260 independent equality entries, 360 direct
matrix-MLE checks, eight mutation controls and six fixture refusals pass**.
Seed 2026092606, one CPU, **3.2093 s, 16,300 KiB RSS**. Enforced wall/CPU/memory
limits; no build, GPU or dependency. Source and owner-log hashes rechecked.
Dimensions 1x1 through 65x128, B=1/2/4/8, row tiles 1/3/8/32, signed extrema,
padding, sparse/zero matrices, zero/one and full-extension challenges, near-p
coefficients and ragged row tiles. Reference one mirrors native per-term
arithmetic; reference two uses signed integer dots and final modular reduction.
Direct cube evaluation independently checks both contraction axes.

At a modeled, unallocated 1024x4096 matrix and B=8, weights read fall
**33,554,432 -> 4,194,304 bytes**. With row tile one, coefficient reads remain
536,870,912 bytes and outputs 131,072 bytes: only **5.15%** less ideal
input/output traffic. Tiles 8/32 model **29.13%/58.18%**, against an equally
tiled independent baseline. Arithmetic remains unchanged; local accumulator
updates total 1,073,741,824 logical bytes, with local coefficient reads and
initialization also retained. Tile 32 holds 4,096 accumulator bytes plus 128
coefficient bytes. Cache/spill/strided-access/allocator costs are unmeasured;
none of these counts is DRAM traffic or a speed ratio.

The native driver draws challenges slot by slot after preceding transcript
messages. Gate/up/down have different matrices; combining them does not reuse
one matrix. Separate proofs need to reach the same matrix/slot concurrently
while retaining their state. Stale challenges, unsigned bytes, lost extension
limbs, dropped tails, mixed matrices, dirty padding, proof order swaps and a
changed matrix digest are detected. No native schedule, RNG, receipt, refusal,
verifier or P3 privacy behavior was tested. The
[low-priority handoff](handoffs/20260926-batched-weight-fold.md) identifies the
interface and prototype; **no native patch exists or was integrated**.

### Primary sources and next action

LIVE search found the recent [SLP paper](https://arxiv.org/abs/2609.27367)
(2026-09-23): packing is interesting, but selected-chunk guarantees do not
meet complete coverage; its offset-dependent RoPE/rounding behavior and public
prompt/answer bindings are incompatible with a direct P1 transfer. Its
[artifact README](https://github.com/TrueOpen/slp-experiments) distinguishes
GPU inference from CPU proving and labels larger separate-proof baselines as
derived. No author timing is reproduced here.

New older assessment: [CQLin](https://eprint.iacr.org/2023/393) (received
2023-03-19, revised 2023-10-16) amortizes fixed-matrix work using KZG
preprocessing. [ZKTorch](https://arxiv.org/abs/2507.07031) (2025-07-09,
revised 2025-07-10) provides a parallel accumulation route and uses CQLin.
These are high-cost architecture alternatives, not evidence that public-weight
folds dominate this implementation. ZKTorch master Apache-2.0 text was read;
specific historical commit IDs are links only because their pages failed.
SLP repository data license remains undetermined. Plonky3 release notes were
refreshed; displayed September 23 still lacks a verified year. Six qualified
records appended; exact Cache miss/404/Internal Error fetch failures retained.
No shell-network fallback, downloaded script execution or approval request.

Next rotation **quantization/arithmetic**: test exact Goldilocks Fp2 schoolbook
versus Karatsuba and specialized square at `field.rs:158/:172`, with zero/base/
full-extension/near-p cases and independent big-integer polynomial reduction.
Include wrong nonresidue, missing cross-term, unreduced-sum overflow and u128
overflow controls (seven times a full product cannot be blindly deferred into
u128). Reuse small synthetic grouped/fused-round fixtures to check downstream
sample/final bytes. Count multiplies/adds/reductions; native compiler/device
timing and full receipts remain owner work under the shared locks. Remaining
queue: proof composition -> sumcheck/GKR -> GPU NTT/commitments -> lookup/softmax
-> memory traffic -> batching/amortization.


## Cycle 0007 — 2026-09-26 — exact Fp2 multiplication and squaring

Run `20260926T225233Z-f66107c9`. **The fixed-width arithmetic candidates pass;
there is no measured native or end-to-end speed gain.** Read durable history,
latest results, AGENDA, project CLAUDE/status/decisions/active coordination and
current throughput rules. The target stays complete private 8B attention+FFN
>=50 proved tokens/s including witness and serialization; the 512-token prefill
reference is <=10.24 s, five seconds stretch. Larger-workload amortization is
an additional project direction. Prefill does not establish decode throughput.
D22 remains CPU toy only; D19b/D23 remain proposed.

### Bottleneck, ranking and falsification

The completed grouped dense A/B is still the latest owner measurement. Four
non-warm logs and comparison hashes recheck, terminal zero. New proving
**34.861/33.315 s**, witness **5.43/5.76 s**, serialization **.031/.020 s**,
known readiness **40.322/39.095 s**; verification internal **.900/.810 s**,
from bytes **.91/.82 s**, separately. Synthetic dense 125M block, two CPU
threads, shared box and candidate with extra small-slot oracle work; no
enclosing request clock, GPU/8B measurement or new run by this lane.

| Rank by expected usable end-to-end relevance | Hypothesis and costs | Exactness, privacy and next gate |
|---|---|---|
| 1, owner work already handed off | Group-aware round fusion and GPU commitment work still target the large phases: softmax slot 8.601/7.832 s; A+H encode/Merkle 16.739/16.903 s. | Moderate native/device work; preserve grouped equality, masking and pad overlap semantics. No duplicate job. Existing device/privacy gates stay required. |
| 2, tested this cycle | Fp2 Karatsuba saves a variable base product; two-product squaring has a similar tradeoff. No phase attribution exists for the removed operations. Extra modular add/subtract/carry chains and compiler behavior may erase gains. | Small source seam, broad correctness footprint; same field, basis and bytes. Native sample/RNG/receipt/refusal validation and actual slot/readiness A/B required before promotion. |
| 3, next research rotation | Fractional-LogUp/GKR could reduce the H helper commitment, a much bigger target than computing its inverses. Need to count displaced H rows AND new fraction-tree/binding/masking work. | High construction/composition cost. Preserve every table-denominator refusal, multiplicity/padding relation and private helper sum. A tiny rational-tree oracle is the next feasibility test, not a new accepted proof protocol. |
| Deferred | Public-weight batching remains below 0.1% of known readiness; pair-inverse caching remains a tiny-phase optimization. | Previous positive arithmetic and negative cost evidence preserved. Do not reopen scheduling/preprocessing work without larger-shape measurements. |

Multiplication-specific speed is unknown; removing its entire parent softmax
slot would be 21.3%/20.0% of known readiness, but that is neither its share nor
a global Fp2 ceiling. The base-field commitment encoder is not sped up merely
by changing Fp2. Falsify this candidate with native release independent-array
and dependent-chain tests, then the actual grouped slot and complete readiness;
demote it if added instructions or dependencies erase the useful saving.

### Reproduced experiment and negative controls

[Experiment](experiments/fp2-arithmetic-20260926/README.md),
[result](experiments/fp2-arithmetic-20260926/result.json): **24,641 product
cases, 10,121 square cases and 35 powers pass**, against an independent
unbounded polynomial-convolution/reduction oracle. The base-field carry/borrow
transcription passes 10,121 input pairs and 10,007 u128 reductions. Three
product forms and four square forms are compared, including zero, base-only,
full-extension, signed-residue and near-p boundaries. Seed 2026092607,
**3.718 s, 22,496 KiB peak RSS, one CPU**; enforced <=59 s/512 MiB limits.
No native compiler, GPU or proof execution. Proving/verification/readiness null.

Pinned prior research fixtures test downstream arithmetic: 24 fused fixtures
(1–32 rows, four tables, degrees 2/3, extension/zero-equality, ragged tiles)
compare **630 round samples and 288 final MLEs across three arithmetic arms**;
24 synthetic schedule hashes match. Thirteen SC_SZC grouped fixtures add
**189 independent round-point checks** and four zero-factor fallback rounds.
Grouped original-arithmetic results are established before replacements.
Neither synthetic driver exercises the native CFS or commitment machinery.

Eleven controls detect wrong nonresidue, lost cross term/doubling, wrong
square coefficient, unreduced u64 sums, both real/cross u128 overflow,
missing carry/borrow corrections, swapped wire limbs and changed input.
Four malformed fixtures are refused only by the harness; native canonical
input preconditions are unchanged. Blind deferred `ac+7bd` can need 131 bits;
`ad+bc` can need 129, so fitting each product in u128 is insufficient.

Source-level general multiplication changes **4 variable products + 1
constant product + 2 additions** into **3 + 1 + 3 additions + 2 subtractions**.
The two-product square uses **2 variable products + 1 constant product + 5
additions + 1 subtraction**. Compare against a three-product square with
shared cross term: the current inlined `self.mul(self)` may already receive
that compiler optimization. Explicit three-product squaring is therefore
**not claimed as a saving**. Replacing times-seven by three doubles and a
subtraction removes a constant product but adds more dependencies. It is
tested but excluded from the proposed default patch.

The [owner handoff](handoffs/20260926-fp2-arithmetic.md) carries a two-hunk,
unapplied Rust patch to `zkp-core/src/field.rs::Fp2::{mul,square}`, at the
same source hash in main and the current grouped candidate. Native build,
canonical byte, RNG, invalid witness, fresh/archived receipt and device gates
remain owed. No protocol, privacy acceptance or production source changed.

### Sources and concrete next action

Newly assessed older technique: [Devegili et al., 2006/471](https://eprint.iacr.org/2006/471),
received **2006-12-14**, revised **2007-02-20**, gives the quadratic formulas;
its large-prime timings do not transfer here. Current
[Plonky3 arithmetic PR 2098](https://github.com/Plonky3/Plonky3/pull/2098)
merged **2026-09-09**, but the inspected
[main quadratic implementation](https://raw.githubusercontent.com/Plonky3/Plonky3/main/field/src/extension/binomial_extension.rs)
uses dot products, so it is a competing approach rather than evidence for
this patch. Main MIT license text inspected; raw file update dates and full
commit remain unverified. `4faefa9` is only a displayed abbreviation; commit
detail calls returned Internal Error. No external implementation executed.

[prime-ir issue 409](https://github.com/fractalyze/prime-ir/issues/409), opened
**2026-07-29**, reports addition/carry costs in a different Poseidon2 prover;
its GPU timing is not reproduced or attributed to our BLAKE3 path. The
[August instruction-wall paper](https://arxiv.org/abs/2608.13696) was refreshed
as general instruction-cost context, not a proving benchmark. Release
v0.8.0 was refreshed; exposed September 23 still lacks a verified year. Six
dated/qualified source records appended. Exact fetch failures and one corrected
local preparation `KeyError: 'status'` are retained; no bypass was attempted.

Next **proof composition**: compare a tiny fractional LogUp tree to direct
reciprocal sums for 1/2/3/8/32 leaves, full Fp2 challenges, signed
multiplicities and ragged padding. Detect zero-root/cross-multiplication
ambiguity, omitted zero-multiplicity table denominators and changed lookup
inputs; preserve full-table refusal behavior. Pin native
`private_block/protocol.rs::write_h`/helper production and shaped H layout,
count genuinely displaced helper rows and new tree state before predicting
any commitment saving. Remaining rotation: sumcheck/GKR -> GPU NTT/commitments
-> lookup/softmax -> memory traffic -> batching/amortization -> arithmetic.

## Cycle 0008 — 2026-09-26 — fractional LogUp tree and private binding

Run `20260926T235233Z-5f465072`. **Exact fraction algebra passes; the naïve
unmasked private adaptation fails, and no speed improvement is established.**
Read the durable state/history/latest results and current project
CLAUDE/status/decisions/coordination/agenda. Prior STATE is archived; history
prefix hashes are retained. The complete private 8B attention+FFN target
remains >=50 proved tokens/s, including witness and serialization; 512-token
prefill reference <=10.24 s, five seconds stretch. Larger-workload accounting
remains separate; no prefill result establishes decode throughput.

### Cost and ranking

The owner grouped A/B is still the latest measured bottleneck. Four non-warm
log hashes and the comparison file recheck. New-arm proving 34.861/33.315 s,
witness 5.43/5.76 s, serialization .031/.020 s give known readiness
40.322/39.095 s. Internal verify .900/.810 s, from bytes .91/.82 s, separate.
These are synthetic dense 125M, shared two-thread CPU measurements with extra
small-slot oracle work, not enclosing request, GPU/8B or this lane's benchmark.

H commitment alone is **9.377/9.593 s**, 23.3%/24.5% of known readiness.
That phase is a substantial target; its complete deletion is an accounting
ceiling, never this candidate's saving. U8 helper preparation is 1.046/1.134 s,
exp+activation inverses .193/.216 s. GKR construction, bindings, masks,
verification and serialization are new costs with no measured attribution.

| Rank by expected usable end-to-end impact | Hypothesis and prerequisites | Integration, exactness and privacy gate |
|---|---|---|
| 1, owner continuation / next research test | Group-aware fold/next-round fusion and hiding GPU commitments still target large phases. Refine fusion to retain all three actual SC_SZC group claims. | Moderate evaluator/device cost; use the existing interface and preserve field samples, zero-factor behavior, table finals and mask/RNG/receipt schedule. No duplicate owner job. |
| 2, existing arithmetic handoff | Fp2 multiplication/squaring may reduce recurring sumcheck work. | Small source patch, wide validation scope. Native independent-array and dependent-chain A/B needed; added carry dependencies may eliminate any gain. No measured phase share. |
| 3, architectural lead tested here | Replace inverse helpers with fractional GKR, avoiding some H commitment work. Can it remain private with streamed node lifetimes and all leaf links? | High construction cost. Root disclosure and whole-tree residency refute the naïve port. New masks, transcript/PCS links, refusal and joint-view accounting required; net row reduction unknown. |
| Deferred | Public-weight batching, pair-inverse caching and binary-specific GKR. | Preserve prior negative ceilings; binary preprocessing is not valid for challenge-valued Fp2 helpers. Revisit only with changed bottleneck/provenance evidence. |

### Experiment and falsification

[Experiment](experiments/logup-fraction-tree-20260926/README.md) passes
**150 fraction cases, 100 lookup identities, 300 independent MLE checks and
15 negative controls**, seed 2026092608, one CPU and under one second with
under 16 MiB RSS (exact final values in result.json). Lengths 1/2/3/8/32,
signed and zero numerators/multiplicities, base/full Fp2, repeated values,
near-p boundaries and ragged neutral padding. The binary recurrence agrees
with independent reciprocal sums (polynomial-convolution/Fermat arithmetic)
and an O(n²) product expansion. No native GKR or proof ran; prove/verify/
readiness are null. A diagnostic MLE link does not establish PCS soundness.

The meaningful negatives are:

1. **Publishing the denominator root can reveal the private lookup.** For one
   witness value v, D=(alpha-tag-v)C, with C the public table-denominator
   product, so v=alpha-tag-D/C. All four synthetic secrets are recovered
   exactly. Publishing a one-value helper sum also reveals it. This rejects
   a naïve unmasked port; it is not a finding against native or upstream ZK.
2. Two zero-denominator leaves can yield root `(0,0)`, which passes a weak
   cross-product equality. Dropping a table leaf with zero multiplicity
   changes a required whole-public-table refusal. Native draw/refusal order
   and privacy are not tested by this synthetic event check.
3. Omitting a witness occurrence and matching table count leaves root-zero
   true. Permuting leaves also preserves the root. Both require binding the
   ordered original witness/multiplicity schema, not just checking tree algebra.

The shaped H layout has **7,016 helper data rows**, a two-row zero-sum pair,
100 reserved mask rows and two proximity rows: **7,120** total. H input
933,232,640 B; encoded values at rate 1/4 **3,732,930,560 B**. Gross helper
rows are only candidates for displacement; **new binding rows, new GKR masks,
proof bytes and net saving remain null**, and no mask row is assumed removable.

A source-derived, unallocated 125M full-tree ledger has 103,890,944 leaves
including the lifted tables, padded to 2^27. Generic merges cost 402,653,181
Fp2 products and 134,217,727 adds. Retaining both values of every node is
**8,589,934,560 B, almost 8 GiB**; leaves alone 4 GiB, leaves plus first
out-of-place parent 6 GiB. These exclude scratch/masks/bindings/other live
state and are not lower bounds for an optimized tree. Flattening it into the
current commitment would need **65,536** base rows before masks, over 9x H.
Streaming, specialized numerators and neutral-node elision deserve separate
testing; none justifies an end-to-end saving now. The initial passing run's
row ledger rounded down by one; final code rounds up, with the original
source/result/log preserved and the arithmetic digest unchanged.

The [design handoff](handoffs/20260926-logup-fraction-tree.md) identifies shaped
`private_block/protocol.rs::{write_h,logup_sum_claim,prove_core}` and the H
layout/helper zero-check seams. Native source snapshots are pinned. There is
**no native patch**, no integration and no new D22/privacy acceptance.

### Primary sources and next experiment

LIVE search refreshed the [fractional-GKR note](https://eprint.iacr.org/2023/1284)
(2023-08-27, revised 2025-02-20) and the September
[Plonky3 lookup PR](https://github.com/Plonky3/Plonky3/pull/1968)
(opened 2026-07-30, merged 2026-09-07). Its mandatory trace link and padding
description inform the binding controls. Main MIT text was read; linked
commit content and raw lookup source returned Cache miss. The v0.8.0 release
timestamp still exposes September 23 without a year, so exact date stays null.

The [SP1 verifier source](https://docs.rs/sp1-hypercube/latest/src/sp1_hypercube/logup_gkr/verifier.rs.html)
shows explicit denominator and trace-link checks. Its surrounding privacy
wrapper was not audited. Main Apache-2.0 text was inspected; the versioned
source URL failed, so its association with crate/latest 6.0.2 (2026-02-26)
is not asserted. The June [sp1-zorch memory issue](https://github.com/fractalyze/sp1-zorch/issues/112)
motivates a layer-lifetime comparison, not a transferred benchmark.

New older assessments: [Winterfell's interface discussion](https://github.com/facebook/winterfell/issues/292)
(2024-07-17) makes oracle/final-claim binding explicit; it is a proposal.
[Boolean GKR](https://eprint.iacr.org/2025/717) (2025-04-21, revised 2025-05-03)
needs binary provenance absent from these helpers and explicitly withdraws
an earlier end-to-end comparison. [Jolt Atlas](https://arxiv.org/abs/2602.17452)
(2026-02-19) is a streaming/BlindFold architecture discovery, abstract only.
Eight qualified source records appended; no external claims reproduced.
PDF robots denial and source/PR fetch errors are recorded without a bypass.

Next rotation **sumcheck/GKR**: combine the prior generic fusion oracle with
the three source-pinned SC_SZC groups. Test fused folds plus next bracket
samples against unfused grouped rounds and direct cube MLEs for 1–256 rows,
full-extension challenges, different equality points, ragged tiles and zero
factors. Preserve actual per-group claims and extension/final scheduling;
count table traffic separately from bracket calls. A stale prefix/suffix,
combined-host-claim substitution or small-case extra-work regression should
falsify promotion. Remaining rotation: GPU NTT/commitments -> lookup/softmax
-> memory traffic -> batching/amortization -> quantization/arithmetic ->
proof composition. Architecture work resumes only with explicit masked root
and leaf-link treatment; no simpler disclosure-prone port is handed over.


## Cycle 0009 — 2026-09-27 — grouped fold / next-round fusion

Run `20260927T005233Z-ccb9384b`. **All three equality groups survive fusion;
logical table traffic falls, but no native or end-to-end speed gain is measured.**
Read durable state/history/sources/latest results/agenda and required project
CLAUDE/status/decisions/active coordination. Prior STATE and history prefixes
are pinned. Writes stayed within research, excluding runtime. The target stays
complete private 8B attention+FFN >=50 proved tokens/s including witness and
serialization; 512-token prefill reference <=10.24 s, five seconds stretch.
Larger-workload amortization is separately permitted; prefill is not decode.
D22 remains the named CPU toy only; D19b/D23 remain proposed.

### Measured bottleneck and ranked hypotheses

Rechecked the completed owner grouped A/B, four non-warm log hashes and terminal
zero. New-arm proving **34.861/33.315 s**, witness **5.43/5.76 s**, serialization
**.031/.020 s**, known readiness **40.322/39.095 s**. Internal verification
**.900/.810 s**, from bytes **.91/.82 s**, separate. Shared two-thread CPU,
dense synthetic 125M block, extra small-slot oracles; not enclosing request,
GPU/8B or this lane's benchmark. Complete softmax slot **8.601/7.832 s**;
A+H encode/Merkle **16.739/16.903 s**. Fold/cache attribution is absent.

| Rank | Hypothesis and expected complete-proof relevance | Prerequisites, integration cost and falsification |
|---|---|---|
| 1, tested for owner | Fuse folds with next-round accumulation while preserving grouped equality. Targets a large slot; deleting that entire slot is only a 21.3%/20.0% readiness ceiling. | Moderate evaluator/parallel ownership work. Preserve actual per-group claims, masks/RNG, exact samples and table finals. No saving forecast without native slot/readiness timing; lost parallelism/cache locality falsifies it. |
| 2, refined next research question | Fuse hiding pad/coset coefficient production into `k_ntt_p1`'s bit-reversed load, removing the existing `coef2` write/read pass and scratch lifetime. Baseline must use compact `pw=n+q`, not pretend the earlier pad-skip optimization is new. | Moderate CUDA load/ownership work. More scattered pad/power loads may erase savings; q>n overlap, inverse normalization, coset, chunk/gather order and tag-path availability all require exact tests. Current tagged shaped commitments still need an authorized keyed device path. |
| 3, existing arithmetic handoff | Fp2 Karatsuba and specialized square could reduce recurring sumcheck arithmetic. | Small source seam, wide validation footprint. Native release independent/dependent A/B and complete readiness remain owed; carry dependencies may lose. |
| 4, architectural queue | Masked fractional-GKR with streamed lifetimes could reduce H helper commitment costs. | High construction/PCS/composition cost. Preserve prior root-disclosure and tree-residency negatives; no net saving without new masks and original leaf links. |

Public-weight batching's <0.1% readiness ceiling and tiny-phase pair caching
remain demoted. Neither fusion nor Fp2 work affects base-field commitment
encoding automatically. No native/large build, device job or duplicate owner
measurement was launched or queued.

### Reproduced experiment and meaningful negative

[Experiment](experiments/grouped-fused-round-20260927/README.md) and
[result](experiments/grouped-fused-round-20260927/result.json): **37 cases,
651 total samples, 1,953 group samples, 962 independent final MLEs, six
zero-factor fallbacks, 37 synthetic driver comparisons, 10 controls,
12 schedule refusals and three fixture refusals pass**. Seed 2026092709,
**9.2027 s / 24,192 KiB RSS**, one CPU. Lengths 1/2/4/8/16/32/256,
base/full-extension/zero tables, padded/unpadded, short Ht equality support,
ragged tiles 1/3/7 and reversed traversal. No proof clocks: all null.

Every total sample is checked by an independent original-cube MLE oracle with
Boolean-zero terms elided, independent polynomial-convolution multiplication,
and a separately expanded scalar expression; 222 small points also use the
prior exhaustive oracle. All group rounds/claims, intermediate tables and
finals agree with pinned unfused grouped evaluation. The three native equality
tables are now physically retained/folded, despite not being used by brackets.
Synthetic wiring/26-table inventory is not a native layout execution.

At 256 rows, **26,520 -> 19,916 Fp2 reads**, unchanged **6,630 writes**:
**530,400 -> 424,736 logical bytes (19.9216% less)**. Padded bracket calls
remain **[1,148,638,638]**; unpadded **[893,383,383]**. Suffix metadata builds,
weight products and equality construction counts match. This excludes scratch,
allocator, cache/write-allocation, masks and driver traffic; no DRAM/timing
ratio follows. The two-row case saves nothing.

The first passing prototype added needless serial per-tile reductions: 11
field adds at four padded rows, 506 at 256 padded rows with tile three. That
path is rejected and preserved in `initial/`. The final serial path accumulates
directly; the retained partial-reduction arm reproduces the extra work without
changing arithmetic. Native parallel reductions/ownership need separate review.
Controls detect stale prefix/suffix, a combined host claim substituted for a
group claim, wrong quarters, dropped tails and schedule/final-order mutations.

The [handoff](handoffs/20260927-grouped-fused-round.md) identifies
`zkp-core/src/sumcheck/grouped.rs::{round,fold,finals}`, provides a **serial,
uncompiled/unapplied Rust helper sketch**, and calls for existing native
masked/RNG/extension/IR/receipt/refusal gates under the shared locks. No full
native patch, integration or wider privacy/soundness acceptance exists.

### Source findings and next action

LIVE search assessed an older [ICICLE fusion description](https://www.ingonyama.com/post/hardware-friendliness-of-hyperplonk-part2)
(**2025-04-01**): previous-fold/current-evaluation fusion and device-side
challenge processing were already described. Its L4 four-table EQ(AB-C)
profile does not prove this degree-five slot is memory-bound. Main frontend
MIT text was inspected; the README explicitly excludes separately distributed
backends, whose license was not established. No upstream code executed.

[Plonky3 release notes](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0)
still expose September 23 without a year. The newly readable strategy sources
show paired-product wrappers and tiled MACs, not a verified release-aligned
fusion implementation; raw main and docs differ and no commit was inspected.
[Jolt equality documentation](https://jolt.a16zcrypto.com/how/optimizations/eq.html),
the March extended paper and September author explanation were refreshed.
The [June hardware study](https://arxiv.org/html/2606.16146v1) methodology is
255-bit synthesized/simulated accelerator work plus a Xeon software baseline,
not measured Goldilocks GPU proving. Its simulator README was inspected only.
Eight qualified records appended; source/PR/package/commit Cache miss/Internal
Error/timeout and two corrected local path errors are recorded without bypass.

Next rotation **GPU NTT/commitments**: use the prior exact small hiding-row
oracle to compare materialized `k_zk_pad_scale -> k_ntt_p1` against computing
correct `data + (X^n-1)*pad` coefficients at each bit-reversed load. Test q<n,
q=n, q>n, non-unit coset, full/compact strides, ragged row chunks and duplicate
unsorted gathers. Count coefficient/pad/power reads, removed scratch writes,
and changed access locality separately. Preserve the known overlap bug as a
negative control. Remaining rotation: lookup/softmax -> memory traffic ->
batching/amortization -> quantization/arithmetic -> proof composition ->
sumcheck/GKR. Owner native fusion review can proceed independently.

Final artifact validation passes: 24 hashes, seven original/snapshot pairs,
four owner logs, both original history prefixes, previous STATE archive and
eight appended source records. AGENDA is unchanged; no native source changed.


## Cycle 0010 — 2026-09-27 — NTT pad-load fusion loses locality

Run `20260927T015233Z-c29b434c`. **Exact outputs and a removable scratch
buffer, but no speed improvement established. The large-row address model
counts more sector requests, so direct load fusion is demoted.** Read durable
history, latest results, agenda/progress and project CLAUDE/status/decisions/
active coordination. Prior state/progress and history prefix hashes retained.
All writes stayed in research outside runtime; no build, GPU, Git operation,
external message or production mutation. D22 remains the named CPU toy only;
D19b/D23 remain proposed. Complete private 8B >=50 proved tokens/s includes
witness and serialization; 512-token prefill reference <=10.24 s, five seconds
stretch. Longer-workload clocks remain separate; prefill is not decode.

### Bottleneck and ranked hypotheses

Four owner non-warm log hashes and comparison recheck, terminal zero. Latest
new-arm proving **34.861/33.315 s**, witness **5.43/5.76 s**, serialization
**.031/.020 s**, known readiness **40.322/39.095 s**; internal verification
**.900/.810 s**, from bytes **.91/.82 s**, separate. These are shared two-thread
CPU synthetic dense 125M-block diagnostics with extra test oracles, not new
research benchmarks or enclosing request/GPU/8B measurements. A+H encode/Merkle
costs **16.739/16.903 s**, softmax slot **8.601/7.832 s**. The GPU pad/p1 share
is unknown, so neither logical bytes nor deleting a whole CPU commitment phase
predicts seconds saved. [Pins and clocks](experiments/ntt-pad-load-fusion-20260927/bottleneck.json).

| Rank | Hypothesis and end-to-end relevance | Prerequisites, integration cost, exactness and falsification |
|---|---|---|
| 1, owner | Existing grouped fusion and keyed GPU commitment work address the large measured phases. | Native masks/RNG/IR/extension/receipt gates and complete evaluator/encode/readiness A/B; preserve Rayon and profile hashing. No duplicate job. |
| 2, materially refined memory question | Fuse pad/coset terms into the normalized inverse-NTT final store, retaining compact coef2 and forward locality while removing coef traffic. | Moderate CUDA/ownership work. In-place inverse p2 reads/writes and changed destination stride can require another buffer; count all lifetimes and sectors. Exact q overlap/normalization/chunk tests first. No seconds forecast. |
| 3, next lookup rotation | Write already cached U8 helper inverses directly into the two H limbs, eliminating the temporary Fp2 Vec and copy at helper_*_u8_at -> write_h. | Small/moderate Rust output-slice work, safe disjoint lifetimes and partial private writes on refusal. Current enclosing helper phase 1.046/1.134 s gives only a 2.6–2.9% readiness ceiling; retained work makes actual saving smaller or zero. Target memory as well as time; preserve invalid fallback and every full-table refusal. |
| 4, tested and demoted | Synthesize pad/coset values at k_ntt_p1's bit-reversed load. Removes compact coef2 materialization and one launch. | Exact scalar tests pass, but source-address sector requests rise at relevant large rows. Cache/SASS/occupancy and whole-encode timing required before native promotion. No whole-proof privacy or byte gate performed. |

Fp2 native arithmetic remains owner work. Fractional GKR retains its root-
disclosure/tree-residency negatives. Public-weight batching's <0.1% ceiling
and tiny-phase pair caching remain demoted; none is rediscovered as new work.

### Experiment and decisive qualification

[Experiment](experiments/ntt-pad-load-fusion-20260927/README.md),
[result](experiments/ntt-pad-load-fusion-20260927/result.json): **138 cases,
828 materialized comparisons, 12,912 direct polynomial output points,
15 native synthetic conformance rows, three sparse boundary cases with
20,480 outputs, 16 flat-array chunk/stride comparisons, 256 column-byte
checks, 13 controls and six malformed refusals pass**. Seed 2026092710;
**4.0622 s, 20,300 KiB RSS**, one CPU. Final run preserves the initial passing
narrower run. All proof clocks are null; no compiled CUDA or native proof.

Candidate loads the normalized natural coefficient plus both contributions
of (X^n-1)g, then applies the existing coset power at each bit-reversed index.
The independent oracle directly inverts the DFT and Horner-evaluates separate
data and pad polynomials. Dimensions n=2/8/16/64, q below/equal/above n,
cosets 7/11, zero/random/near-prime values; full and compact strides, ragged
chunks and repeated unsorted openings. Sparse cases exercise nn=4096/8192
around the real p1 split, but native p2 thread mapping is not simulated.

For **n=16,384/q=256/nn=65,536**, one row's pad/p1 data-interface bytes fall
**1,058,816 -> 792,576 (25.145%)**; logical scratch falls 133,120 bytes.
Both compact paths retain 16,640 coset multiplies. Coefficient, pad and power
reads are counted. The same model's sector requests **rise 45,568 -> 49,920
(9.551%)**, independently checked by closed-form formulas. At q=n the rise
is 26.316%. Reordering loads within their existing block helps small domains,
but leaves the large domain's every-16th-coefficient access unchanged.
This falsifies a claim of uniformly improved coalescing, not a measured runtime
claim. It does not prove a slowdown: cache reuse, compiler load merging and
instruction costs remain unknown. Counts exclude inverse NTT, p2, shared/
twiddle work, hashing, transfers and pool behavior; **25.145% is not a full
encoder or proof saving**, and removed scratch is not measured peak VRAM.

The previous **q>n pad-overlap bug remains a negative control**. Successful
q>n comparisons use the corrected materialized polynomial, not the current
broken CUDA branch. q<=n agrees with its source-derived semantics. The
x^16-x^8 versus x^16 counterexample is retained; no device or affected-receipt
claim is added. Dirty-tail, wrong-stride/chunk, pad-sign/mutation, inverse-scale,
coset, bit-reversal, duplicate and row-order mutations all fail as expected.

[Handoff](handoffs/20260927-ntt-pad-load-fusion.md) identifies
`cuda.rs::encode_rows_view_zk[_gather]` and `kernels.cu::k_ntt_p1`, includes
an **uncompiled/unapplied load-helper sketch**, and explicitly withholds a
large-row default recommendation. No complete native patch or integration.
Tagged shaped commitments still need the owner’s keyed device path and wider
privacy review; exact synthetic coefficients alone establish neither.

### Sources and next action

Native LIVE search assessed [cuPQC 0.6](https://nvidia.github.io/cuPQC/releases/v0.6/),
published **2026-08-28**: its device-side NTT fusion API is relevant, but the
explicit **p<2^62** bound excludes Goldilocks despite uint64 storage. No library
substitution or field change. New older assessment: [UniNTT](https://doi.org/10.1145/3669940.3707241),
published **2025-03-30**, emphasizes hierarchical locality; abstract-only,
eight-GPU author comparison, no local reproduction or located code artifact.

[yrrid/GoldilocksNTT](https://github.com/yrrid/GoldilocksNTT)'s README explicitly
qualifies its small-transform throughput by L2 residency. Source/license/history
fetches failed, so implementation license/date/commit stay unverified (MIT is
advertised only). [NVIDIA coalescing docs](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/)
justify the sector unit, not a measured result. GPU-NTT lists no releases;
the June NTT/sumcheck paper remains the prior simulation-based comparison.
Six qualified source records appended, with exact URLs and errors. No network
bypass or downloaded implementation execution.

Next rotation **lookup/softmax**: a tiny direct-H writer versus current cached
single/paired U8 helper Vec+write_h. Independently solve Fp2 denominators;
compare every limb, offset and padded tail, including empty/ragged columns,
invalid signed values and used/unused zero denominators. Verify the full-table
refusal schedule even if H already has partial private writes; no H commitment
or transcript/RNG event may move ahead of a refused stage. Count temporary
peak storage and all reads/writes, preserve safe split-slice ownership.
Then **memory traffic** tests inverse-store pad fusion as described above.
Remaining rotation: batching/amortization -> quantization/arithmetic -> proof
composition -> sumcheck/GKR -> GPU NTT/commitments. No improvement to complete
private 8B readiness or decode is claimed.

## Cycle 0011 — 2026-09-27 — Direct U8 helper planes: exact, small ceiling

Run `20260927T025233Z-f22c1025`. [Experiment](experiments/direct-helper-planes-20260927/README.md),
[traffic](experiments/direct-helper-planes-20260927/traffic.json),
[handoff](handoffs/20260927-direct-helper-planes.md). Read AGENDA, all durable
research/project status and latest local result before work. Only research files
outside runtime were written. No native/GPU builds, external scripts, Git,
dependency installs, production edits or external messages.

**New owner evidence changes ranking.** The current Sol fusion candidate
passes correctness but is slower in the complete synthetic 125M CPU A/B:
two non-warm old/new means, prove **35.0665/35.6490 s**, softmax slot
**8.332/9.197 s**, known witness+prove+serialization **41.2755/42.3105 s**.
The fusion sketch is demoted. The keyed GPU commitment attempt 2 passes
tagged correctness, including a full rung-G receipt, on an RTX 4070 Laptop;
no speed or 5090 measurement. The model team's source audit corrects the
materialized-host 25.70/70.57-GiB T512/T1024 floor: the accepted chunked GPU
PCS route does **not** retain full A/H codewords. It still holds raw host and
device planes, with a counted **9.86-GiB host H-construction payload floor**
at unregistered T512 Mistral geometry. The owner is already testing streaming
and GPU memory; do not duplicate it. None of this is a full private 8B result.

### Tested hypothesis and falsification

The grouped candidate at `private_block/protocol.rs:884-907` caches all 256
byte inverses, but creates one `Vec<Fp2>` per U8 helper and copies it into H's
two Fp planes. Baseline: **52,183,040** helper outputs in the 125M model;
one largest helper Vec has **64 MiB modeled payload**. Direct writing eliminates **1.555 GiB**
of counted temp write/read payload per block, while retaining input scans,
Fp2 arithmetic, H stores, all table-helper checks, A/H commitments, masks,
proof and serialization. No new payload scan is needed when the denominator's
extension coefficient is nonzero. When `alpha.c1 == g_u8.c1`, a successful
transactional preflight adds **752.25 MiB** of input payload reads. That guard
is public-challenge-only and is exact for every embedded signed integer;
preserve internal table-construction invariant. Neither byte count is DRAM
traffic or a timing result.

The one-thread standard-library Python test passed **63** differential cases,
**7,932** independently solved output words, **19** refusal cases, and **8**
negative controls in **2.097 s**, **16,500 KiB** RSS, Intel Core Ultra 9 185H.
The independent oracle exponentiates in Fp2, versus the candidate's norm/
conjugate inverse. It compares both H limbs, pair order, disjoint offsets,
empty/odd/1,024 lengths, signed extremes and used/unused zeros. It exposed
that unguarded streaming leaves a partial private H on late refusal while
the old Vec writer does not; the guarded version preflights that rare branch
and preserves no-partial-write behavior. This partial-buffer negative is
retained, not treated as a permissible publication. Native Rayon, RNG,
transcript, full-table refusal and receipt parity are **not** tested.

The latest owner's old-arm non-warm helper phase is **1.189/1.248 s**, known
readiness **41.462/41.089 s**: witness **6.74/5.63 s**, proof
**34.697/35.436 s**, serialization **.025/.023 s**, verification **.88/.87 s**
separately; one synthetic block, T512, zero complete-model passes, shared
two-thread CPU with test oracles. Even deleting
the **entire** helper phase caps improvement to **2.87/3.04%** of those known
sums; the candidate retains most work. Its falsification gate is native exact
proof parity followed by a smaller helper phase **and** enclosing readiness
with no lost parallelism or extra memory peak. A no-gain result demotes it.
Startup fraction, total/steady throughput, GPU device performance, proof lag,
complete private 8B stack and decode remain unknown. One block's 512 positions
cannot be counted as complete-model proved tokens.

### Ranked hypotheses after this cycle

| Rank | Question / expected complete-proof impact | Prerequisites, cost and falsifier |
|---|---|---|
| 1, owner | Keyed GPU A/H commitments and whole-root/opening memory schedule address 16.4–16.8 s of old-arm CPU A+H phases and GPU eligibility. | Owner has correctness, no GPU phase speed. Keep tags, masks, fresh per-proof pads/salts, exact roots/openings and fallback. Measure whole readiness/peak/transfer; no 50-token/s estimate from kernels. |
| 2, **refined** | At T512 with a resident model, can independent passes amortize setup without T² context growth or proof backlog? Compare fixed-context passes with long prefill and later decode separately. | First register actual full 8B profile and measure setup, per-pass witness/prove/serialize/verify, peak memory and drain. The current GPU chunk path removes a false codeword floor, but the 9.86-GiB host construction floor remains. A measured complete-proof drain slope slower than 20 ms per position on the proposed schedule, or memory overflow, falsifies its >=50 benefit. Never reuse masks/private openings. |
| 3, next research | Produce compact pad/coset terms at inverse-NTT final store rather than scattered first NTT load; it may reduce encoder traffic while preserving forward locality. | Exact q<n/q=n/q>n, normalization, in-place p2 hazards and source address sector model first; another full buffer or scatter may erase gain. No whole-phase estimate until GPU attribution. |
| 4, tested | Direct U8 H helper writer removes one-helper Vec/copy and 64-MiB largest modeled payload. | Small current end-to-end ceiling, source-level synthetic pass only. Native receipt/refusal/parallel gates and A/B required; may be valuable for host peak but insufficient alone for >=50 tokens/s. |

Native LIVE lookup rotation assessed the original
[LogUp paper](https://eprint.iacr.org/2022/1530) (received 2022-11-04,
revised 2025-02-20), [Jolt Atlas](https://arxiv.org/abs/2602.17452)
(v1 2026-02-19), [ICME Atlas repository](https://github.com/ICME-Lab/jolt-atlas)
and its [restricted LICENSE](https://github.com/ICME-Lab/jolt-atlas/blob/main/LICENSE),
and [Plonky3 v0.8.0 notes](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0)
(23 Sep displayed without verified year; commit fetch failed). ICME README's
GPT-2 times and the papers' speed/streaming comparisons are author claims;
no external implementation or timing was reproduced. Four qualified source
records appended. The custom ICME evaluation/platform license does not grant
general reuse; no code was copied. Next rotation **memory traffic**, then
batching/amortization, arithmetic, proof composition, sumcheck/GKR, GPU NTT/
commitments, lookup/softmax. Keep the prior NTT load-fusion locality loss and
fractional-GKR privacy/memory negatives visible.

## Cycle 0012 — 2026-09-27 — Inverse-store hiding fusion, then a new GPU bottleneck

Run `20260927T035233Z-8a5c6f18`. The [bounded experiment](experiments/inverse-store-pad-20260927/README.md),
[result](experiments/inverse-store-pad-20260927/result.json) and
[handoff](handoffs/20260927-inverse-store-pad.md) are research artifacts only.
One-thread synthetic arithmetic passed **56** cases, **16** ragged multirow
chunk comparisons, **816** direct DFT/polynomial checks and eight controls
in **1.394 s / 29,704 KiB RSS**. Seed 2026092712; Intel Core Ultra 9 185H;
source SHA-256 and production read-only pins are in `result.json`. No native
build, GPU job, real private input or full-stack proof was run.

### What the experiment established

For the compact chunked hiding encoder, the inverse NTT's final store can
arithmetically produce the already allocated `coef2` row of width `n+q`:
normalize, subtract pad, multiply coset power, and assign disjoint tail
writes to inverse blocks. The next forward p1 still has its current compact
contiguous source. Both p1-only (`n<=4096`) and p1+p2 inverse paths match
an independent direct inverse/definition at small sizes and a separate
materialized polynomial at larger sizes. q<n, q=n, q>n and dirty tails were
included. The current CUDA `k_zk_pad_scale` remains **wrong for q>n** relative
to the CPU polynomial: it drops the negative overlap term; that shape is a
separate correctness repair, not byte parity with the old GPU branch.
Aliasing the n-wide intermediate with widened-stride output across rows is
unsafe. The separate existing `coef2` destination avoids the alias, but for
`n>4096` it leaves the two-buffer scratch peak unchanged.

At `n=16384,q=256,nn=65536`, the isolated last-inverse-store plus pad
ledger falls from **663,552 to 401,408 logical bytes per row**, removing
262,144 B, and its source-address model falls from **20,736 to 12,544
32-byte warp-sector requests**. The prior first-forward-load fusion removed
similar logical bytes but raised sectors 9.55% at this size; this layout
preserves p1 locality. These are **not DRAM traffic or measured speed**.
Last-store coset/pad operations, q-tail work, registers and occupancy could
erase the gain. For q near n, each p2 block gets almost another full tile's
tail work. The p1-only path could remove an 8n-byte scratch allocation;
large n cannot. No mask, salt or private opening is reused.

Baseline for the tested hypothesis is inverse last store into `coef`,
separate `k_zk_pad_scale` into `coef2`, then forward p1. It eliminates one
`coef` write and read per coefficient and one launch; it adds arithmetic and
tail stores to the last inverse pass. The current CPU one-block A/H
encode+Merkle parent phase is roughly 16.4–16.8 s of 41.1–41.5 s known
readiness, so even deleting that **whole** phase caps that one-block CPU
improvement at about 40%; this narrower candidate's GPU/full-stack ceiling
is unmeasured. Native exact leaf/opening/receipt parity and a smaller
inverse+pad **and enclosing proof** clock with no peak regression are its
falsification gates. It remains a lower-priority handoff, not a 50-token/s
route by itself.

### New owner measurement and rank change

During this cycle the main team's [keyed GPU A/B](../../results/zk60_sol_gpu_20260927/attempt-5-dense-ab/report.json)
finished. Two non-warm samples per arm, one synthetic dense 125M T512
block, fresh process each, two CPU threads, RTX 4070 Laptop (8,188 MiB):

| Arm | Whole process | Witness | Prove | Verify | Serialization + other residual |
|---|---:|---:|---:|---:|---:|
| CPU | 39.895 s | 5.845 s | 32.950 s | 0.905 s | 0.195 s |
| Keyed GPU | 30.055 s | 8.215 s | 17.130 s | 0.815 s | 3.895 s |

All six receipts verify at 40,783,352 bytes. The residual combines
serialization, initialization and other time; no separate serialization or
startup clock is in this report. GPU peak host RSS is 4,411.5 MiB mean;
**VRAM peak unmeasured**. One GPU witness sample took 10.66 s versus 5.77 s
in the other; this explorer overlapped the shared host, so it is not a
quiesced timing estimate. The owner's approximate remaining softmax work is
about half GPU proving. Neither warm steady state nor full 8B was measured.
Context T512 is one synthetic block; **zero complete-model passes and zero
countable proved tokens**. Startup fraction, steady/total throughput, proof
lag, decode throughput and full-stack end-to-end ceiling remain unknown.

Ranked hypotheses after the new measurement:

1. **GPU softmax/sumcheck work:** highest measured remaining prover slot.
   Test exact grouped masked round generation and fold traffic at
   `private_attention/argument.rs::SC_SZC` -> `zk.rs::masked_prove` ->
   `zkp-core/src/sumcheck.rs::prove`. The existing `k_sc_round_zc*` CUDA
   kernels serve FFN zero checks, so an attention device path is **new,
   high-cost integration**. Retain challenge/RNG/transcript, generic
   polynomial and refusal semantics. Added device transfers/synchronizations
   could dominate.
   Native phase A/B and whole-proof clock falsify the gain; no numerical 8B
   ceiling without phase attribution.
2. **Fixed-context resident-pass amortization:** could spread initialization
   across independently proven passes without T-squared context growth.
   Needs registered 8B layout, actual startup, drain/lag, masks per proof,
   GPU/host peak and independent verification. A complete-proof drain slope
   above 20 ms per new position or memory overflow falsifies >=50 on that
   schedule. Do not call independent passes decode.
3. **Tested inverse-final-store fusion:** exact synthetic, narrower encoding
   traffic win, no native runtime/peak win yet. Integration moderate in
   `hashline/src/gpu/{cuda.rs,kernels.cu}`; q>n repair separate. Demote if
   whole proof does not improve despite fewer modeled sector requests.
4. **Direct U8 H helper writer:** still exact synthetic, but deleting its
   entire phase caps old CPU readiness gain at 2.87–3.04%; preserve its
   partial-private-write refusal negative and guarded preflight.

Native LIVE search refreshed [NVIDIA cuPQC NTT](https://docs.nvidia.com/cuda/cupqc/libraries/cupqc_ntt/cupqc_ntt_feature.html),
its [staged inverse guide](https://nvidia.github.io/cuPQC/applications/ntt-staged-transform/),
[0.6.0 notes](https://docs.nvidia.com/cuda/cupqc/additional/release_notes.html)
and [sample repository](https://github.com/NVIDIA/cuPQC), plus
[2023 GPU NTT locality](https://eprint.iacr.org/2023/1410) and the
[June 2026 NTT/sumcheck architecture paper](https://arxiv.org/abs/2606.16146).
cuPQC's documented custom-prime bound `<2^62` excludes this Goldilocks
prime; its examples are Apache-2.0, required SDK under NVIDIA terms.
Official final-store design is an analogy only. Dates, exact URLs, licenses,
unavailable commit ID and author-claim limits are in four appended JSONL
records and the [search log](experiments/inverse-store-pad-20260927/search-log.md).
No external code was copied or executed. Next local test: a bounded exact
SC_SZC tile/fold schedule and traffic oracle against the existing generic
masked Rust seam, with controls for challenge/extension limbs, mask schedule
and round order. Then revisit proof-window amortization when phase clocks
and a registered 8B layout exist.

## Cycle 0013 — 2026-09-27 — attention SC_SZC device-round boundary

Run `20260927T045233Z-e6183046`. **No complete private 8B proof or measured throughput improvement.** The leading recurring cost is still attention softmax in the keyed GPU-assisted 125M one-block diagnostic: about half of 17.130 s GPU proving, with 30.055 s mean whole process, 8.215 s witness, 0.815 s same-process verification, and 3.895 s combined serialization/other/startup residual on RTX 4070 Laptop. Two non-warm samples, fresh process each, shared host. Zero complete-model passes/countable positions; no 5090 or trained 8B timing. Prior results and negative findings remain above and in earlier handoffs.

### Tested hypothesis and bounded result

**Question refined this cycle:** Can an attention SC_SZC slot keep all folded tables on a device while leaving the exact CFS masking and Fiat–Shamir schedule on the host, and when would round trips erase the benefit? The baseline is current CPU generic `hashline/src/zk.rs::masked_prove` -> `zkp-core/src/sumcheck.rs::prove`. Candidate: upload once, compute/reduce one unmasked round vector on device, mask/absorb/draw on host, return challenge, fold all tables on device. It moves CPU table scanning but **eliminates zero table reads or field operations** in the source schedule. It adds upload, final transfer, 2–3 launches and one dependent host/device exchange per round, VRAM residency and integration cost. No mask, salt or private-opening reuse is proposed.

[One-thread experiment](experiments/sc-szc-device-round-20260927/README.md): seed 2026092713; four synthetic SC_SZC-shaped profiles with 8–128 rows, 13/26 Fp2 tables, degree four and tiles of 3/7/16 pairs. In 0.510 s/17,140 KiB RSS on Intel Core Ultra 9 185H, 110 round samples match an independently reconstructed original Boolean-cube MLE oracle; 91 finals, masked claim chain and eight negative controls pass. At 128 rows/26 tables, tiles 16 and 3 have identical complete masked-message digests. The source CFS formula is transcribed; the polynomial is a simplified three-group stand-in, and the challenge hash is a test SHA-256, **not** Rust BLAKE3. No native/GPU receipt parity or speed result. Source/script SHA-256, command, dimensions and limits are in `result.json`.

At synthetic N=128/k=26/d=4, once-only upload is 53,248 B; source-counted table round/fold reads 211,328 B and writes 52,832 B in **both** CPU-style and device-resident schedules. Reduced vectors total 560 B D2H, seven challenges 112 B H2D, finals 416 B. At least seven sequential challenge exchanges survive; a separate device reduction adds seven launches. Sending tile partials instead costs 880/3,680 B at tile 16/3. These are logical counts, not DRAM/time. The device route is useful only if measured GPU execution beats CPU work after transfers/synchronization. As a generous ceiling, deleting the entire *approximate* 8.565 s softmax slot at zero cost from the 30.055 s one-block wall leaves ~21.49 s, a ~28.5% wall reduction. This candidate can remove less. The complete private 8B ceiling and >=50 tokens/s feasibility are unknown. Falsify on byte/terminal/refusal mismatch, VRAM overflow, or no quiesced enclosing proof gain. [Handoff](handoffs/20260927-sc-szc-device-round.md) names the patch seam and validation.

### Primary search and ranking

Native LIVE search assessed [March 2026 equality/streaming sumcheck](https://eprint.iacr.org/2026/587), the [DATE 2026 SumCATS GPU paper](https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf) and [author-linked repository](https://github.com/SPIRE-GMU/sum_cats), [zorch's June/July device-Fiat–Shamir design issue](https://github.com/fractalyze/zorch/issues/327), [NVIDIA's July 2026 RTX 5090 binary-field sumcheck report](https://developer.nvidia.com/blog/?p=119649), and [2024 time-space sumcheck work](https://eprint.iacr.org/2024/524). SumCATS authors report 1.81x/1.62x kernel speedups on RTX 3090 Ti/A100; NVIDIA authors report 3–4x on RTX 5090, but both target binary fields, not this Goldilocks/Fp2 protocol, and neither is reproduced full-stack evidence. zorch's issue revised host FS to a separate device composite; that is a design statement, not proof that this host-FS route is too slow here. Exact URLs, access/date/license/commit qualifications are appended to `sources.jsonl`; external code was not copied or run.

1. **GPU attention SC_SZC, with a measured transcript boundary** — highest observed recurring proving cost, high integration and privacy review cost. The new gate is an actual-slot/native CPU byte oracle and owner-run per-round transfer/sync/launch clock. A later on-device BLAKE3/mask route might remove host exchanges but would need exact transcript/keyed-domain parity, fresh mask handling and larger-profile security review; it is a separate hypothesis, not inferred from this toy. End-to-end ceiling limited by the measured softmax fraction, then by witness/PCS/startup; 8B ceiling unknown.
2. **Resident fixed-context complete-pass amortization** — potentially higher total-workload effect if setup dominates, but no registered 8B setup/pass/drain clocks or VRAM peak. Need distinguish independent passes, long-context T-squared prefill, and decode with authenticated KV growth. More than 20 ms of complete proof drain per newly proved position falsifies a >=50 steady slope for that schedule, regardless of startup; total workload additionally needs measured startup fraction.
3. **Inverse-final-store pad/coset fusion** — previous exact synthetic and lower counted interface traffic, moderate integration, but q>n correction, receipt/peak/phase A/B absent. Falsify if native q<=n parity or enclosing readiness fails. The previous first-forward-load sector regression and slower native softmax fusion remain negatives; do not repeat them.
4. **KV/proof-window state and cached preprocessing** — future-pair masked-score relation and state binding remain mandatory; public-weight batching was <0.1% in prior cost analysis. Revisit after full-stack per-pass clocks or a separately reviewed causal-only relation, not by reusing private openings.

**Next bounded experiment:** pin the actual SC_SZC closure (all lookup/helper terms, padding and hosted claims) in a CPU-only differential oracle and compare per-round unmasked/masked vectors, BLAKE3 challenges, extension round and finals at ragged shapes. Then ask the owner for a locked native phase A/B only if byte parity and memory accounting pass. There is no authorized heavy/GPU run in this lane.

## Cycle 0015 — 2026-09-30 — bounded full-validation tile batches

Run `20260930T004944Z-77f0d93d`. **No measured complete-proof improvement or
private 8B throughput result.** Cycle 0014 left an incomplete
`sc-szc-full-poly-20260927/experiment.py` with no result/report; it is not
counted completed. Current CLAUDE/coordination assigns the native actual-SC_SZC
boundary to an owner lane. This cycle tested complementary preparation work.
All prior negative findings and handoffs are retained.

### Tested question and evidence

**Refined question:** can bounded tile requests share a whole-tensor integrity
scan, without reusing a mutable-file verified flag or weakening corruption
refusal? Actual inspected `TensorRef.read_tile` hashes the entire tensor per
request. [Experiment](experiments/validated-tile-batch-20260930/README.md),
[result](experiments/validated-tile-batch-20260930/result.json),
[handoff](handoffs/20260930-validated-tile-batch.md): the candidate buffers
an ordered tuple of requests and releases nothing until the **same entire
tensor SHA-256** matches. It retains no cross-call validation cache.

Seven synthetic tensors (2 through 2,097,158 bytes) pass **88** independent
slice comparisons against the actual local reader and original generated
bytes. Duplicates, overlaps, zero-length requests, shifted data starts,
chunk crossing and ragged tails are included. Eight negative-control
categories pass, including ten malformed batches refused before I/O,
mutation outside all requested tiles, late/during-scan mutation, truncation
and wrong pins. The unsafe skip-rehash control misses outside-tile corruption;
it is a rejected alternative. Final run **0.098 s / 37,096 KiB RSS**, seed
2026093015, one Intel Core Ultra 9 185H CPU thread; cap 59 s wall / 55 s CPU /
512 MiB AS. Script, local source/config/report hashes, stdout and command are
retained. No trained payload, quantization, calibrated witness, native/GPU
proof or foreign implementation ran.

Instrumented logical read bytes fall **58,245,640 -> 4,329,514** in the suite.
K tile requests ordinarily scan K*S bytes; a grouped request scans S.
Eliminated work is (K-1) complete read/hash passes and file opens. Added
costs: O(K) chunk intersection bookkeeping, delayed return and all requested
slice buffers. Default caps are 16 requests, 1 MiB each, 8 MiB aggregate;
bytearray-to-bytes conversion briefly retains about 18 MiB raw payload/scan
storage plus Python allocator overhead. Logical process reads are not SSD
traffic or GPU runtime.

Public-config accounting, **assuming** every raw block tensor is tiled once
in 1-MiB slices, gives 33.9884 -> 4.6408 GiB at TinyLlama's 22 blocks and
1244.0005 -> 155.5005 GiB at Llama-3-8B's 32 blocks with eight-tile grouping.
Initial inventory, non-stack tensors, conversion/upload/proof work are
excluded; no current measured caller uses this schedule. Independent request
enumeration agrees with the closed-form ledger and raw bytes match the
separately reported proved-stack parameter counts.

**Useful limit:** the existing `read_bytes` already validates a whole tensor
once, costing only 1.8049 / 13.0005 GiB across those stacks. Largest raw
tensors are 22 / 112 MiB; returned-copy lifetimes can double this payload.
Where it fits, use the existing interface first. The new API only benefits a
caller needing bounded partial reads; it does not remove an existing proof
phase. This negative prevents promoting a hypothetical tiled baseline as a
current end-to-end bottleneck.

Even deleting the whole measured import phase I can save no more than I /
total workload time. I is unmeasured; a scan-byte ratio is not a time ratio.
If import is startup only, this cannot improve resident steady proving.
Falsify by byte/refusal mismatch, partial return, excess live memory, or no
enclosing preparation improvement; already-single-scan callers eliminate
zero work. No numerical trained 8B ceiling or >=50-token/s estimate follows.
Future seam: additive importer `TensorRef.read_tiles` feeding calibrated
public words into Rust `BlockPublic` / `witness::build_shaped`; the calibrated
consumer is not built. Main/Claude integrates, not this lane.

### New owner evidence and missing clocks

The read-only owner report
`results/zk60_mvp_20260929/baseline-stack-gpu-attempt2/report.json` now records
one successful **synthetic dense 12-block T512** GPU diagnostic: **408.609 s
process wall, 318.22 s run prover, 12.15 s in-process verify**, 484,107,456
receipt bytes, 2,113 MiB sampled VRAM peak, 37 accepted keyed commits.
Device: one RTX 4070 Laptop (8,188 MiB), shared host, cold process, n=1.
Source `run.rs` places just-in-time witness and segment encoding inside the
run-prover region: do not call 318.22 s an isolated cryptographic proof clock.
Report explicitly says fresh-process verification false; diagnostic
512/wall = 1.253 positions/s is **not counted** as independently verified
private-8B throughput. See the pinned [evidence excerpt](experiments/validated-tile-batch-20260930/owner-evidence.json).
The separate CLI remains marked running at this cycle's check; no duplicate
job or independent verifier was launched by the researcher.

Full private 8B context/pass count, steady/total verified rates, startup
fraction, separated witness/proof/serialization clocks and proof lag remain
unknown. This research cycle proves zero complete passes and counts zero
positions. The older 3.895 s GPU residual combines serialization/other/startup;
it is not a measured initialization clock and cannot establish an under-1%
amortization claim without additional assumptions. Native `StackSource`
does one sealing pass, drops all witnesses, then restarts and rebuilds them
inside proving. That is recurring work per independent run, not process
startup. Larger independent passes, T-squared long-context prefill and
authenticated KV decode must remain separately measured.

### Ranked hypotheses and next experiment

| Rank | End-to-end question and expected scope | Prerequisites, integration cost, exactness/privacy and falsification |
|---|---|---|
| 1, owner | Device actual SC_SZC and then device witness: highest measured recurring CPU proving/witness costs. | Native masked/transcript parity, source-pinned phase/transfer/peak A/B; high Rust/CUDA cost. Fresh masks and accepted relation unchanged. Falsify mismatch, memory overflow or no whole-proof gain. 8B ceiling unknown. |
| 2, **new/refined next research** | Can bounded private replay of sealing-pass witnesses remove their second dense forward computation without storing the full model live? | `StackSource::prepass` / `restart` / `advance` discards then rebuilds L witnesses. Count actual typed-plane bytes, write/read/copy costs, peak and held state before considering a cache. Moderate/high caller integration and private storage review; no new commitment opening or randomness reuse. Falsify refusal/chain mismatch, overflow, or replay traffic >= avoided measured witness time. No speed estimate until both sealing/recurring clocks exist. |
| 3 | Fixed-context resident complete-pass amortization, with reusable public model setup. | Measure actual setup, per-pass witness/proof/serialization, verifier, drain and peak. High workload-interface cost; masks/openings fresh per run. More than 20 ms complete-proof drain per new position falsifies 50/s steady regardless of pass count; long-context/decode differ. |
| 4, tested conditional | Grouped full-validation raw tensor reads for a memory-bounded multi-tile caller. | Exact synthetic byte/refusal gates pass. Low additive Python integration; calibrated Rust consumer absent. Existing `read_bytes` may already remove all repeats. Whole-phase ceiling is import's measured fraction; startup-only benefit tends to zero in steady state. |
| 5, retained | Inverse-store pad/coset fusion and later proof composition. | Native NTT receipt/peak/phase parity absent; q>n repair separate. Sharing independently opened boundaries is prohibited by current D12/D11. Do not repeat slower native softmax fusion or the sector-regressing NTT load sketch. |

Native LIVE primary search examined [FlexGen](https://arxiv.org/abs/2303.06865)
and its Apache-2.0 archived [author repository](https://github.com/FMInference/FlexLLMGen),
the July 2026 [zkComposer](https://arxiv.org/abs/2607.08095) boundary masking
construction, and [DeepProve's setup recipe](https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/README.md).
Four source records retain exact dates, licenses and inspected full commits.
DeepProve's LICENSE is restricted; its release-detail click returned Internal
Error, so no full release commit was inferred. Paper/README gains remain
author claims. No code adopted. Next rotation: witness replay memory/traffic,
quantization/arithmetic, composition, GPU NTT/commitments, lookup/softmax,
sumcheck/GKR, then batching/amortization.


## Cycle 0016 — 2026-10-03 — bounded lossless suffix witness replay

Run `20261003T220146Z-cf20886e`. No native proof, measured complete-proof improvement or
private-8B rate. [Experiment](experiments/witness-suffix-replay-20261003/README.md),
[result](experiments/witness-suffix-replay-20261003/result.json),
[handoff](handoffs/20261003-witness-suffix-replay.md),
[dated report](progress/20261003T220146Z-cf20886e.md). Prior findings/negative results preserved.

**Refined question:** can bounded in-memory lossless integer packing retain
a suffix of the sealing pass's witnesses and skip their second forward builds?
Source `StackSource::prepass` drops all L; proving rebuilds all L after restart.
Only integer witness state may be cached for the same run, never proof state.
No private disk storage. Additional cost is scan/pack/unpack/private checksum
plus retained payload and packing/proof overlap. Budget exhaustion falls back
to recomputation; it must not add an input-dependent refusal. Current public
build counters could disclose data-dependent cache admission; metadata/hits/
occupancy/digests/build changes need private or public-fixed reporting.

**Reproduced synthetic result:** 110 independent `struct.pack` comparisons,
670 forward-plane comparisons across 13 schedules (T2/3/7/16, width4/8/16,
1/3/6/8 layers), 20 control categories including four overflow-budget fallback
cases. Final 0.097 s / 18,556 KiB RSS, seed2026100316,
one Core Ultra9 185H thread. Exact padding/nonzero exp analogue and empty
histograms preserved, foreign model/run/stage, input mismatch, bytes/length
corruption and late refusal detected. Reduced attention/FFN stand-in omits
native norm/RoPE/nonlinear tables and calibrated semantics. Mock fresh-state
digests are not native transcripts. No full-block equivalence or privacy proof.

Plane-count parser plus independent named type manifest agrees; i64 toy/m125
counts match retained independently probed native layout. Per-layer raw/typed
m125 payload 678.39/122.36 MiB. Unregistered Llama-3 T512/1024/2048 gives
2296.52/6256.78/19169.56 MiB raw and 385.18/1106.34/3556.67 MiB conservative
typed, E/SUM kept i64. Full typed stack 12.04/34.57/111.15 GiB. No allocator,
weights, looked/helpers/commitments/scratch or pack overlap included. 1GiB
payload retains only 2/0/0 layers of32; 6.25% of second-pass build count at
T512 assumes equal cost and is NOT an end-to-end percentage. Increasing T
makes attention quadratic. Full signed-int16 norm includes -32768/epsilon,
needs five limbs; inspected native builder refuses anything but four.

**Negative designs preserved:** initial synthetic fixture refused a score at
a late layer; its script/log/exit1 remain. Changing only the reduced fixture's
FFN divisor4->32 produced admissible test inputs; production calibration untouched.
Intermediate cache-budget refusal passed arithmetic but changes refusal domain;
rejected and retained separately. Final overflow skips/evicts and recomputes.
Full caching is not a small-memory fix; i64 reexpansion still pays >=5.24/
14.38/44.39 GiB logical read/write per cached layer at the three large shapes,
excluding checksums/extrema/copies, not measured DRAM traffic.

**Ceiling:** saving = measured cached second-pass witness time Wc minus pack P
and replay U. Enclosing rate <= N/(T-Wc+P+U). Wc/T for full private8B is unknown;
no number invented. Even zero-cost full replay removes <=half of an equal-cost
two-pass witness subtotal. Work recurs per independent pass and is not startup.
Falsify native plane/refusal/byte/RNG mismatch, new cache-dependent leakage or
refusal, peak overflow, or P+U>=Wc. Owner existing diagnostic remains synthetic
12-block T512 RTX4070 Laptop, one cold pass: 408.609s wall, 318.22s witness+
proof+segment serialization, 12.15s same-process verify, 484107456B, sampled
VRAM2113MiB. No independent verification. Model rates/startup/separate clocks
unknown; researcher countable positions/passes zero. Stale CLI running flag is
not liveness evidence.

| Rank | Expected end-to-end scope | Prerequisites/cost/obligations and falsification |
|---|---|---|
| 1, owner | Actual GPU SC_SZC then witness, highest measured recurring costs. | High native CUDA/transcript integration; fresh masks and exact generic slot. Native parity, transfers/peak and whole-proof clocks needed. Do not duplicate owner lane; mismatch/overflow/no enclosing gain falsifies. |
| 2, tested | Same-attempt suffix replay removes cached layers' second witness builds only. | Moderate caller/types work, retained private RAM/copies/checksums. No new refusals/public cache facts; native full-plane and proof-byte/RNG gates. Wc-P-U ceiling unknown; full memory cache demoted for long context. |
| 3, new follow-up | Keep active witness typed through Fp/lookup/helper readers to avoid i64 reexpansion and reduce current per-layer peak. | Moderate/high protocol consumer refactor; exact negative values/empty planes/nonzero exp pad and final helper reads. Memory benefit is counted, no time benefit unless enclosing allocation/transfer/streaming costs improve. Falsify any reader mismatch or no actual peak reduction. |
| 4 | Resident fixed-context independent complete passes with reusable public setup. | Fresh private masks/openings and complete independent verification; setup/pass/drain/peak clocks. >20ms per newly completed position falsifies50/s steady for schedule. Long prefill/decode separate. |
| 5 | Inverse-store pad/coset NTT fusion and later composition. | Native q<=n parity/phase/peak gates absent; q>n separate. No sharing completed-proof boundary openings under current D12/D11. Retain prior slower softmax and NTT sector regression negatives. |

LIVE primary sources: [Checkmate](https://arxiv.org/abs/1910.02653) and
[Apache-2.0 author repo](https://github.com/parasj/checkmate),
[Adacc](https://arxiv.org/abs/2508.00806),
[HybridServe](https://arxiv.org/abs/2501.01792),
[Sept2026 FASTAR](https://arxiv.org/abs/2609.25535). Five qualified records
appended to sources.jsonl. Adacc lossy INT4 cannot preserve exact witness;
HybridServe activation checkpoints do not authenticate full proof state;
FASTAR FPGA/FRI fields/protocol differ, no GPU gain transferred. Checkmate
history/activity/API failed (Internal Error/inaccessible/Cache miss), no commit
ID/update inferred. No foreign code executed; author gains not reproduced.

**Next local test:** exact typed planes feeding `protocol.rs` lines798–802
`Fp::from_i64` and lookup/exp/activation-helper readers through their last
reads around908–910, with independent field/lookup values and live-byte ledger.
Then owner native byte/refusal/whole-phase gate under common resource guard.
Rotation: quantization/arithmetic and typed memory -> composition -> GPU
NTT/commitments -> lookup/softmax -> sumcheck/GKR -> batching/amortization.


## Cycle 0017 — 2026-10-03 — typed readers and lazy lookup preparation

Run `20261003T230146Z-65ad9aeb`. No native proof, measured end-to-end gain or
private8B rate. [Experiment](experiments/typed-witness-readers-20261003/README.md),
[result](experiments/typed-witness-readers-20261003/result.json),
[handoff](handoffs/20261003-typed-witness-readers.md),
[dated report](progress/20261003T230146Z-65ad9aeb.md). All prior findings retained.

**Refined question:** keep exact typed values through A/Fp and H helpers; can
lazy indexed affine reads also remove materialized looked/index columns without
changing integer semantics, invalid fallback or unused-table refusals? Baseline
`protocol.rs` materializes witness i64, six-domain looked i64, exp deltas and
act indices. Candidate first rung stays i64 and recomputes lookups for histogram
and helper passes; typed rung avoids full reexpansion. Added cost is second
source read/affine evaluation, decode/dispatch, packing/scans and possible
parallel/cache regressions. No forward build, commitment row or mask is removed.

**Synthetic evidence:** 66 vectors,1952 indexed Goldilocks words,25 preparation
fixtures,65816 independent helper limbs,20 zero-denominator refusals,99 negative
checks pass. Final2.432s/23200KiBRSS, seed2026100317, one CoreUltra9 185H CPU thread.
Four schedules: materialized i64, raw lazy, typed lazy and independently written
reference with expanded denominators/convolution/Fermat inversion. Contexts
1/2/3/5/8, padded heads/strides, empty reader-only fixture, odd helper count,
full/zero beta, coincident zero tags, signed i64 extrema, affine wrapping,
future-score masking, bucket0 fallback, nonzero E/empty histogram planes.
Tables/planes are synthetic representative forms, not native Layout/full-block
execution. Initial key-error run retained; later typed-only pass retained with
reconstructed source SHA-256 checked equal to its original result. No foreign
code/native/GPU build or real private payload. All model clocks remain null.

**Counted memory result:** m125 T512 transient witness+looked+indices1470.641MiB
->678.391MiB raw lazy ->122.363MiB typed lazy. Raw-only saves792.25MiB; combined
1348.277MiB. Unregistered Llama3 T512/1024/2048 baseline4888.766/13489.031/
41826.062MiB ->typed385.184/1106.336/3556.672MiB. These exclude common A/H,
weights, helperVec/commitments, allocator and suffix cache. Packing raw->typed
itself overlaps800.754MiB m125,2681.699/7363.117/22726.234MiB at8B shapes.
No actual maximum/RSS reduction established. Existing builder stilli64 and
accepts4norm limbs; full4096 signed range count requires5. LargeT remainsT².
A4096-word microfixture retains4096typed bytes versus32768i64 bytes; validation
retains both references, so processRSS cannot be compared as prover peaks.

Native one-term U8 preparation counts32B/value materialized raw versus16B raw
lazy or2B for admitted byte/int8 typed values. General typed fallback<=16B.
Lazy adds98598912term multiplications/wrapping adds each per m125 layer;
8BT512322994176. Not DRAM or speed ratios. Native variant dispatch/parallelism
could erase gain. Timing ceilingN/(T-M+C), removed measured preparationM,
new pack/recomputeC; trained8B M,C,T absent. No numerical rate estimate.

**Negatives/obligations:** invalid signed inputs cannot be truncated, clamped,
modulo256 bucketed or newly refused. Full-table inversions cannot skip unused
or zero-multiplicity entries. Select table kind by schema, not coincident
gamma tags. Keep helper transactions and original refusal/draw/absorb order.
Do not drop whole witness at histogram: E/A16 needed through final H pair reads;
lazy lookup-only planes additionally live through their H domains. Dtype/cache
metadata private; no mask/opening/proof state reuse or widened D22 acceptance.
Falsify on native exact/refusal/RNG mismatch, leakage/new refusal, pack-peak
regression, or no enclosing phase/maximum improvement after added costs.

Owner diagnostic unchanged: synthetic12blocksT512,n1cold shared-host RTX4070
Laptop408.609wall,318.22run-prover includeswitness/serialization,12.15in-process
verify,484107456B,sampledVRAM2113MiB,independentverificationfalse. Its1.253
arithmetic positions/s is not counted8B throughput. CLI stale/interrupted,
no relaunch. Researcher0passes/0counted positions, steady/total rate/startup
fraction/separatewitness/proof/serialization/verification/drain/lag unknown.
Resident independent passes, long-context prefill and authenticated decode differ.

| Rank | Expected end-to-end scope | Prerequisites/cost/exactness/privacy/falsification |
|---|---|---|
| 1, owner | Actual GPU SC_SZC then witness, highest measured recurring costs. | High CUDA/transcript work; native byte/RNG/refusal, transfer/peak and enclosing proof gates. No duplicate lane. Mismatch/overflow/no gain falsifies;8B ceiling unknown. |
| 2, refined/tested | Raw lazy lookup/index readers reduce recurring host H-construction payload without typed builder. | Moderate protocol consumer refactor; extra one affine evaluation/read. Preserve helperpair/layout/unused zeros/Rayon and fresh proof state. Native max/phase gain needed; no speed prediction. |
| 3, tested | Typed active/cached plane readers avoid i64 expansion; follow public per-plane last reads. | Moderate/high owned Witness/StackSource signatures, output/chain binding, pack overlap and private metadata. No new narrowing refusal. Falsify no native byte/peak benefit or packing>=saved work. |
| 4, retained | Bounded suffix replay removes cached second witness builds only. | Wc-P-U ceiling unknown;1GiB retains2/0/0of32 atT512/1024/2048. Full long-context caching demoted; native privacy/byte/RNG gates owed. |
| 5 | Resident fixed-context complete independent passes. | Registered model/setup/pass/drain/peak clocks and fresh masks/openings/independent verification. >20ms/new completed position falsifies50/s steady for schedule; startup separately included for total. |

LIVE search: [September30 Pico3.0](https://blog.brevis.network/2026/09/30/pico-3-0-real-time-ethereum-proving-on-4-gpus-with-100-bit-provable-security/)
record width/chunk analogy and [MIT author repo](https://github.com/brevis-network/pico),
[Spartan-WHIR direct typed buffers](https://github.com/ethereum/spartan-whir),
new older [Streaming ZK](https://arxiv.org/abs/2301.02161) and
[CCC publication2024-07-15](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CCC.2024.2),
[small-value sumcheck refresh](https://eprint.iacr.org/2026/587).
Five qualified dated records appended. Pico history rendering stops atAug2025,
not currentHEAD/Sept2026 source evidence; detail clickInternalError, MIT read.
Spartan LICENSE/history/Cargo callsInternalError; license/commitunknown.
Streaming theorem bounds verifier memory, not a GPUprover; protocol not transferred.
No author gain reproduced or external implementation copied/run.

**Next:** public-layout-derived per-plane last-read oracle: drop A-only planes
afterA and lookup-only planes aftertheirH domain; retainS8/MX/E andG8/A16 through
actual final reads. Compare independent read traces and phase live-byte max,
including packing overlap, before owner's native guarded parity/phaseA/B.
Rotation: typed memory/lookup ->composition ->GPU NTT/commitments ->lookup/
softmax ->sumcheck/GKR ->batching/amortization ->quantization/arithmetic.


## Cycle0018 — public last-read witness release (2026-10-04)

Completed 2026-10-04T00:20:58.279502+00:00; 2026-10-04 UTC. Investigated whether public last-read release can improve the lazy witness-reader path. Twelve synthetic fixtures passed an independent named-catalog oracle:91,076 A/H field words,110,444 reads,356 lookup specs and ten negative controls. Final CPU run 3.309s, 27164KiB RSS, one thread on Intel(R) Core(TM) Ultra 9 185H. The initial refusal-fixture failure and intermediate pass remain saved.

At m125, including exp/act inversion prefixes, counted chunked-host maximum falls2423.611 to2203.283MiB for raw lazy readers with release; typed lazy falls1867.584 to1784.228MiB. This is partial payload accounting, not measured memory or proving throughput. Retained CPU A/H codewords erase the maximum saving (8037.627MiB for every strategy). Toy also has no extra maximum saving. Larger unregistered five-limb 8B shapes remain capacity warnings, not runnable model evidence. Detailed ledger and omissions: [experiment](../experiments/public-witness-lifetimes-20261004/README.md).

Read AGENDA, STATE, FINDINGS, sources, latest experiments, project CLAUDE/START_HERE and current MVP_STATUS/DECISIONS/active coordination/throughput direction. Owner baseline unchanged: synthetic12-block T512 single cold pass RTX4070 Laptop8188MiB, wall408.609s, prover318.22s includes witness/serialization, in-process verification12.15s, receipt484107456B, sampledVRAM2113MiB, independent verification false. Arithmetic1.253positions/s is not accepted private8B evidence; startup and separate witness/proof/serialization clocks absent. Stale interrupted receipt does not establish liveness.

This cycle: no GPU or full-stack proof, accepted passes0 and tokens0, model context null. Steady-state/total-workload rates, startup fraction, witness/proof/serialization/independent-verification clocks, proof lag and pipeline drain unmeasured. Synthetic contexts1/3/5; ledger prefill contexts32/512/1024/2048. No resident pass or decode benchmark. >=50 verified positions/s remains unachieved; larger workloads authorized, no fixed512 latency gate or privacy weakening.

Native LIVE sources searched: older ePrint2025/251 private step-by-step streaming; current Nova history/license and Aug21 0.75.0 release commit; hardware-memory study arXiv2606.16146 refresh; zk-stream scope/license/date limits. Author composition/hardware claims not reproduced. Exact URLs/dates/commit/access errors appended to sources.jsonl and search-log.md. GitHub Internal Errors prevented some license/commit inspections; continued independent local work without bypass.

Ranked hypotheses: (1) actual GPU SC_SZC/witness recurrence remains owner-held top impact; no duplicate native jobs. (2) tested public lifetime release has modest integration cost and capacity potential, no timing evidence; requires native ownership/RNG/refusal/proof-byte and actual peak validation. (3) new next experiment: reduce overlapping downloaded u64 gather and returned Fp column buffers at cuda.rs::columns_chunked_zk while preserving duplicate-query columns and exact order; no query/opening reuse. (4) resident fixed-context fresh-proof passes amortize measured startup only; clocks missing. (5) authenticated private state composition requires independent soundness/privacy work, Nova is not a drop-in KV proof.

Leading tested baseline: lazy readers keep source planes through H_ACT. Eliminate plane storage only after public last read; add metadata/ownership and optional typed pack/lazy load costs. End-to-end ceiling N/(T-M+C), unknown M/C. Falsify any value/read/refusal/proof-byte divergence, value-dependent schedule or no actual peak benefit. [Handoff](../handoffs/20261004-public-witness-lifetimes.md) is for owner review, no integration or merge performed. Prior negative fusion/cache/table/memory results preserved.

Next: CPU-light differential gather-materialization oracle using pinned CUDA opening implementation, independent row/column reference, duplicate/empty/out-of-range controls; count temporary/output overlap, preserving canonical Fp words and per-query receipt ownership. Native owner must measure opening share before expecting end-to-end impact.



## Cycle0019 — chunk-local opening gather ownership (2026-10-04)

Run `20261004T010146Z-23455eeb`, checkpoint 2026-10-04T01:19:50.577935+00:00. Read AGENDA/durable state, prior findings/source inventory/latest experiment, project CLAUDE/START_HERE and current MVP status/decisions/active coordination/target. New experiment/handoff are research only; no native build/GPU/Git/install/external messages or production changes.

**Result:** 98 synthetic cases,101868 raw gathered words,636 independently checked hiding-row encode words and15 controls pass, seed2026100419. Final0.276861s CPU/18720KiBRSS, one pinned low-priority CoreUltra9 185H thread, Python3.10.12, estimate64MiB/cap512MiB/59s alarm. Separate direct inverse DFT/polynomial coset reference and query-major/byte reference compare chunk-local addresses, exact duplicate order and separate ownership. Inputs include rows1/127/128/129/259/385, domain16/8192, chunks128/256, empty/range/malformed plans, fused/pruned/unfused output, padded residue lanes, q>n pad overlap and raw noncanonical bits (preserve Fp(v), do not silently normalize). Initial address-only pass retained; final adds pruned store-count/digest controls. No transcript/RNG/native proof was executed. [Experiment](experiments/opening-gather-ownership-20261004/README.md), [handoff](handoffs/20261004-opening-gather-ownership.md).

**Baseline/eliminated work/new costs:** native columns_chunked_zk retains full device gather8RC, downloaded host8RC and returned per-query8RQ. Candidate retains output8RQ plus stage8min(B,R)C, destination-only row0=0/rows_total=rc with global source/pad slicing preserved. Removes temporary gather storage, no NTT, commitment, semantic query or transfer bytes. Adds synchronous downloads1->ceil(R/B), final preallocation/scatter and ownership/bookkeeping; device/pool sync owed. Fused unique-query optimization already exists; do not claim it anew. Metadata and common NTT/source/receipt storage omitted from counts.

At all256distinct queries/B128, m125 A/H separately save10.846/13.656MiB host stage and respective device gather, but need45/56download calls. Final output remains11.096/13.906MiB. A/H peak savings cannot be summed as one simultaneous peak. No savings for one-chunk fixtures; larger B can enlarge NTT scratch and erase the benefit. Five-limb unregistered8B T512/1024/2048 host stage savings A36.143/98.021/299.783MiB and H44.734/125.484/394.988MiB are count-only, not accepted layout/peak/rate. Existing builder still refuses ln!=4; attention context growth remainsT².

**Decisive speed limit:** source-pinned synthetic12-blockT512 diagnostic logs sum A-open8.051s/H-open3.565s=11.616s,2.8428% of408.609s enclosing wall (3.6503% of318.22s run-prover). Deleting both ENTIRE phases at zero cost leaves396.993s, arithmetic1.2897positions/s. This is a parent-phase optimistic bound for an independently-unverified synthetic diagnostic, never candidate saving or counted private8B tokens. Chunk reencoding/copy costs are unmeasured separately and memory tier may differ. Demote this idea as a speed priority; retain exactness/capacity handoff. Trained8B ceilingN/(T-M+C_added), all phase terms unknown. Falsify mismatch/refusal/RNG/byte divergence, scheduling from hidden values, unchanged actual peak, or transfer-sync overhead >= avoided cost.

Read-derived negative: run.rs::prove_run already flushes/drops each owned serialized segment, DirSink retains metadata. There is no full484MB run buffer to eliminate in that path. Same retained log attributes86.691s to A allocation+witness-plane fill,4.231s to lookup+byte histogram,0.587s exp/act preparation. A-fill21.22% of enclosing wall is a large parent to inspect, not a proposed21.22% saving. Zero initialization may be optimized/calloc-backed already.

Ranked hypotheses after this cycle:
1. Owner actual GPU SC_SZC/witness recurrence remains highest measured scope; high CUDA/transcript integration, exact masked/RNG/privacy/byte and whole-proof clocks; do not duplicate jobs. Slower prior fusion retained.
2. Lazy/typed witness consumers and public last-read release/A construction: native moderate ownership/reader work pending. No new narrowing/refusal, metadata leakage or fresh mask reuse. Actual peak/phase benefit needed.
3. NEW next bounded test: public A-row coverage plan for zero-then-scatter versus write-once construction at protocol.rs A buffer/layout.rs offsets. Eliminate only overwritten initialization bytes; add checked coverage/schedule and fill costs. Include required domain padding, histogram and reserved mask/proximity writes. Native actual traffic/time must establish benefit; parent ceiling86.691s only for this diagnostic. Falsify missing/duplicate writes, native proof/RNG/refusal mismatch or no actual eliminated work.
4. Tested chunk-local opening stage: capacity candidate; moderate GPU plumbing,15 synthetic controls, added transfers and full native gates pending; speed ceiling above.
5. Resident fixed-context fresh complete passes: model/public setup reuse only, explicit startup/recurring verification/drain/lag/memory needed. Long prefill and authenticated decode remain separate; no mask/opening reuse.
6. Private authenticated state composition: high protocol/privacy cost, no compatible reproduced implementation.

LIVE sources: new older [ZKProphet](https://arxiv.org/abs/2509.22684) methodology/field bottlenecks; [ICICLE transfer concurrency](https://github.com/ingonyama-zk/icicle/blob/main/examples/c%2B%2B/best-practice-ntt/README.md), MIT license/history/version diff; refreshed [TensorZKP](https://eprint.iacr.org/2026/1250) dates/32-bit degree4 field. Three dated qualified records appended to sources.jsonl. ICICLE inspected full version-bump commit6c77775961b0e4dc2be359feec1ac11536c18043 is Jul10 2025, not a verified new2026 release or currentHEAD. Tensor receivedJun13/revisedJun16 2026, proceedings Aug2026; author artifact DOI inaccessible via native web (Internal Error after Zenodo redirect), code/license/commit unknown. No download/execution or author gain reproduced. RotationGPU NTT/commitment ->lookup/softmax and A construction ->sumcheck/GKR ->batching ->arithmetic ->composition.

Full-stack accounting: this cycle deviceCPU only, accepted complete private8B passes0/tokens0/contextnull; steady-state and total-workload rates, startup fraction, witness/proof/serialization/independent-verification clocks, lag/drain null. No prefill/resident/decode run. Prior single cold synthetic12-blockT512 RTX4070Laptop8188MiB diagnostic has318.22s prover includingwitness/serialization,12.15s in-process verify,484107456B, independent verification false; no current process inference or relaunch. >=50verified positions/s unachieved. Larger workloads allowed, fixed512 latency ceiling not adopted. Reports saved locally; saved reports do not prove delivery.

Next: source-pinned public-layout A-write-coverage CPU oracle, differential padding/histogram/mask schedule and missing/duplicate writes; count redundant zero stores, added costs and allocator caveat. Main/Claude reviews any native adoption, researcher does not merge. All prior findings preserved.


## Cycle 0020 — public A-row write coverage (2026-10-04)

Run `20261004T020146Z-c40246c9`, checkpoint 2026-10-04T02:19:09.124797+00:00. Read AGENDA and the requested durable memory, current measurements, source catalog and latest reader/lifetime/opening results. Work stayed in research; no production/runtime/Git/receipt/calibration/instruction/reviewer edits, builds, GPU jobs, installs, external messages or downloaded code execution.

**Result:** 18 synthetic cases, 800768 field words, 53646 required zero words, 48640 synthetic mask words and 18 controls pass. Seed 2026100420, CPU 2.156225s, peak RSS 29496 KiB, one pinned low-priority Core Ultra 9 185H thread. The source-derived plane catalog agrees with an independent family catalog. A row-address decoder and modulo/byte reference agree with zero-then-scatter and sequential construction. Cases use contexts 1/3/5/8/32, row widths 256/512/1024, four/five norm limbs, signed-i64 extrema, invalid lookup indices and pair mismatches. Required public row/table padding stays zero; supplied internal padded words are copied literally. Controls include malformed coverage/shape, padding/histogram/mask/proximity mutations, mask substitution and synthetic RNG continuation. Python PRNG is a stand-in, not native ZkRng. No native transcript/PCS/proof was tested. Initial pass retained. [Experiment](experiments/a-row-write-coverage-20261004/README.md), [handoff](handoffs/20261004-a-row-write-coverage.md).

**Baseline and work removed:** shaped protocol.rs::prove_core allocates zero A, then overwrites supplied planes, first256 histogram words and all mask/proximity rows. The candidate appends each region after unchanged histogram derivation, with initialized Vec operations only in the uncompiled Rust review sketch. m125 counts 709.146 MiB of overwritten initial zeros per block, 0.979 MiB required zeros and unchanged 710.125 MiB final matrix capacity. Historical unregistered Mistral T512/T1024 counts are 2328.271/6288.537 MiB, not literal trained 8B profile evidence or experiment allocations. Counts reconcile with retained layout payloads. No witness conversion, lookup work, fresh masking, encoding/hashing, opening, transfer or proof-byte work is removed.

**Added costs and caveats:** append/resize and public coverage checks; histogram-before-assembly scheduling and private lifetime changes. A lower-risk variant keeps original phase order and leaves only6144 bytes of repeated histogram zeros. Required table extension above255 and row tails cannot be skipped. The Rust generic Clone path differs from private primitive IsZero specialization; Fp is a custom wrapper. This is source-level reasoning only: LLVM/allocator may optimize fill; installed stable sources do not identify the production compiler. Physical traffic and runtime benefit remain unmeasured. Matrix capacity saving is zero.

**End-to-end ceiling:** the retained cold, synthetic twelve-block T512 RTX4070Laptop diagnostic has408.609226s wall,318.22s prover including witness/serialization,12.15s in-process verification,484107456B and independent verification false. A allocation+witness-fill sums86.691s (21.216% wall). Entire parent deletion at zero cost leaves321.918226s, arithmetic1.590466 positions/s. It is not candidate savings or countable private8B throughput. Table/mask overwrites fall in later timers, so this parent bounds the allocation/plane component rather than every zero store. Candidate ceiling N/(T-M+C) is unknown. Falsify native value/padding/refusal/RNG/transcript/proof-byte divergence, hidden schedule, already-eliminated zero traffic, unchanged phase time or added cost >= removed cost. No improvement measured.

Ranked queue, expected scope and obligations:
1. Owner-held GPU SC_SZC/witness recurrence remains highest measured impact; high CUDA/masked-transcript integration and full-proof gates. No duplicate lane; slower fusion retained.
2. Tested A assembly plus NEW conversion refinement: moderate assembly change, logical traffic potential but no capacity gain. Split native zero allocation from conversion/copy first. Next CPU question: can magnitude modulo be removed from signed-i64 conversion because abs(i64)<=2^63<P? Preserve i64MIN/MAX and every negative; compiler may already remove it. Actual end-to-end gain unknown.
3. Typed/lazy/public last-read witness consumers: synthetic parity and capacity potential, moderate ownership refactor; native refusal/RNG/proof-byte/peak/phase evidence pending. Retained CPU codewords can erase peak benefit.
4. Resident fixed-context fresh complete passes: measure setup, recurring clocks, verification, lag/drain and peaks with a registered trained model. No masking/opening reuse; >20ms/new verified position falsifies50/s steady state for that schedule. Long prefill T² and authenticated decode differ.
5. Opening gather: capacity review only, extra synchronization and only2.84% parent wall scope; final output/transfer bytes unchanged.
6. Private composition and decomposable lookups: high protocol/privacy/soundness cost, no compatible reproduced replacement for the current256-entry tables.

LIVE sources: [Bits Under ZK-LLM](https://arxiv.org/abs/2609.36437), sole v1Sep29 2026, with largest-model projection evidence and smaller GPT2 prefill clocks excluding graph preparation/inference/verification on32CPUthreads; no precision change authorized or author speed transferred. New older [TaSSLE](https://eprint.iacr.org/2024/1075), receivedJul2 2024/revisedMar8 2025; decomposition/private binding not established for this path. [Jolt](https://github.com/a16z/jolt) MIT/history inspected; memory/blinding titles are author claims, commit-detail clicks failed with InternalError and no full commit was inspected. [Rust Vec](https://doc.rust-lang.org/src/alloc/vec/spec_from_elem.rs.html) current source date unknown, local source hashes retained. Four qualified source records appended, no foreign code run.

This cycle: CPU only,0 accepted private8B passes/tokens, model context null. Steady/total rates,startup fraction,witness/proof/serialization/independent-verification clocks,latency/lag/drain null. No prefill,resident or decode proof. Larger workloads permitted;512/10.24s reference only. Target50/s remains unachieved. Prior findings preserved; saved reports do not establish delivery.

Next: exact signed-i64 conversion oracle and negative controls; owner split allocation/conversion and native full-proof A/B before promoting assembly. Rotate sumcheck/GKR, batching/amortization, quantization/arithmetic, composition, GPU NTT/commitments.


## Cycle 0021 — exact signed-i64 conversion and a compiled negative (2026-10-04)

Run `20261004T030146Z-711aedad`, checkpoint 2026-10-04T03:18:19.846706+00:00. Read AGENDA, durable state/findings/source catalog, latest A-row results and current project instructions/status/decisions/coordination/target. Research-only writes; no production/runtime edits, native build/proof, GPU, Git, install, external message or foreign-code execution. [Experiment](experiments/i64-field-conversion-20261004/README.md), [result](experiments/i64-field-conversion-20261004/result.json), [handoff](handoffs/20261004-i64-field-conversion.md).

**Result:**139,880 synthetic signed values match baseline, direct magnitude, signed-word correction and independent decoded-ELF arithmetic against a Euclidean-remainder oracle. Includes all65,536i16 values,616 boundaries,65,536 full-i64 random values and8,192 near extrema. Independent base256 byte extraction, canonicality and Fp2base embedding checks pass.60 vector arithmetic models/6,800words and25 representative A-row copies/3,208words pass, including odd/empty tails and supplied nonzero internal padding.20 controls fire. Seed2026100421;2.257907s,22,616KiBRSS,one pinned low-priority CoreUltra9 185H thread,Python3.10.12,estimated64MiB/cap512MiB/59s alarm. Initial final-assertion failure omitted the witness load from a static instruction count; script/log/exit1 retained before correcting9->10total/9arithmetic. No field mismatch suppressed.

**Baseline/eliminated work/new costs:** `zkp-core/src/field.rs::Fp::from_i64`, called per A witness coordinate at shaped `protocol.rs:801`, uses magnitude modulo and canonical constructor. Since abs(i64)<=2^63<p, candidate uses rawu64 minus signMask&(2^32-1). This preserves every i64, includingMIN/MAX, and exact bytes. No new narrowing/refusal, RNG draw, masks, memory reads/writes, capacity, transfers, commitments or proof work removed. Candidate signed-mask arithmetic/compiler behavior and broad shared-field regression costs remain. m125 A-row count88,918,016 supplied conversions/block is public geometry only, not timed work or negative-value statistics.

**Useful negative:** the apparent A conversion loop of the current ELF already has **no integer division**: a compare/cmov remains among9 arithmetic instructions after its witness load. Both decoded constant choices are tested; only the ordinary p correction can affect negative i64. Source `%` is not evidence of an expensive native division. Candidate instruction count/vectorization/runtime unmeasured. Current allocation has malloc+memset at0x525703..0x525770, narrowing the previous zero-store question for this build, not measuring physical traffic/execution.

**Provenance blocker retained:** current ELF SHA2562c617ae5203c2db3b785ee56da364ad73407b2c8012e646ea0b2fdc876460015 differs from old timing report's74abdad3a53e2010a5281329c2d985b8ee8676d75b3f68b9083e3840fb762337 at the same path. Source hashes are pinned but source-to-binary identity was not reconstructed. Do not attribute current assembly to the historical clock. No binary executed or rebuilt. Corrected disassembly metadata and initial metadata retained.

**A-only end-to-end ceiling:** prior onecold synthetic12-block125M T512 RTX4070Laptop8188MiB diagnostic408.609226s wall,318.22s runprover including witness/segment serialization,12.15s in-process verify,484107456B,independentfalse. Allocation+plane-fill86.691s is21.216%wall. Deleting ENTIRE parent at zero cost leaves321.918226s, arithmetic1.590466positions/s, not conversion savings or counted private8B throughput. Global shared-field change needs separate attribution outsideA. Trained8B ceiling N/(T-C_old+C_new), all terms unknown. Falsify canonical/byte/native refusal/RNG/transcript/proof mismatch, compiler already short, more expensive vectorization, or no enclosing gain. No improvement measured.

Ranked queue after current measured negative:

| Rank | Hypothesis and expected end-to-end scope | Prerequisites, costs, exactness/privacy and falsification |
|---|---|---|
|1, owner|Actual GPU SC_SZC and witness recurrence, largest retained recurring scope.|High native CUDA/masked-transcript work; no duplicate jobs. Byte/RNG/refusal/transfer/peak/full-proof clocks owed. Retain prior slowerfusion. Fails on mismatch/overflow/no enclosing gain.|
|2, NEW next local|Exact signed-byte decomposition of int16 FFN-down witness GEMM removes CPU dot work if GPU schedule pays.|Actual `witness.rs::matmul_in_out` at312/685, two int8 partials+i64 recombination and128sumW; publicK<=16384 givespartial<=2^28/full<=2^36. CPU oracle pending; pack,extraGEMM,transfers,recombine cost; high CUDA integration. Preserve all padding/weight orientations/requant/first refusal, no precision change. Fails on parity/overflow or GPU+copies>=CPU cost. Ceiling N/(T-W+added costs), W unknown for accepted8B.|
|3, tested|A write-once allocation and exact conversion, recurring A parent only.|Moderate assembly/localhelper change; no matrix capacity saving. Compiler already removes division; matched-build allocation/conversion clocks needed. Native proof/RNG/byte gates; no private sign statistics. Fails if no actual eliminated stores/instructions or no gain.|
|4|Typed/lazy/public last-read witness readers, capacity improvement can enable efficient tier.|Moderate ownership refactor; synthetic parity only, pack/recompute/lifetimes/native RSS gates pending. No cache metadata leak or new refusal. Retained codewords/pack overlap can erase peak benefit.|
|5|Resident fixed-context complete fresh passes amortize actual public/model setup.|NTT already once per complete run, not per layer. Measure repeated-pass startup/slope/lag/drain/independent verification/peaks; fresh masks/openings, P3 review. >20ms/new verified position falsifies50/s for measured schedule.|
|6|Opening chunk gather, capacity only;2.84%old wall parent.|Added synchronous downloads can regress. No final byte/transfer/query saving. Native lifecycle/peak/receipt gates pending.|
|7|Packed/matrix-challenge sumcheck and private composition.|High protocol/PCS/privacy/soundness cost. No compatible matrix-weighted commitment reproduced; author small-field gains not scalarFp2 drop-in. Current256entrylookup and old composition obligations stand.|

LIVE primary search records: new [packed sumcheck](https://eprint.iacr.org/2025/719), receivedApr22 2025/revisedSep14 2026; new older [combined small-value/equality paper](https://eprint.iacr.org/2025/1117), Jun13/revisedJun17 2025; refreshed [EPFL](https://github.com/compsec-epfl/efficient-sumcheck) representation/final-oracle docs; [Plonky3 release](https://github.com/Plonky3/Plonky3/releases) datedSep23 2026 in inspected version/changelog commit a21e3ed42905040ad49c519e402f018381c12d0c. Four records appended. Packed paper changes scalar messages/challenges and PCS; EPFL is plainnonZK with caller final-oracle binding and Montgomery SIMD assumptions; Plonky3 titles do not undo our slowerfusion finding. EPFLcommit429/licenseCachemiss, PlonkyPRInternalError/releaseCachemiss recorded; no bypass. No author performance reproduced.

Full-stack this cycle: CPUonly,0accepted8B passes/0countabletokens,contextnull. Steady-state/total rates,startup fraction,witness/proof/serialization/independent-verification clocks,latency/lag/drain null. No prefill/resident/decode proof. Larger workloads permitted; attentionT² and private state-binding distinctions retained.50/s unachieved. All prior findings/source prefixes preserved; local reports are not delivery evidence.

Next: bounded exact int16 split-dot/requant oracle using both native orientations; preserve signed endpoints/support and public overflow bounds. Owner action separately: matched-build A zero-allocation versus conversion/copy clocks, then guarded native proof-byte/refusal/A-B gates. Rotate batching/amortization ->quantization/arithmetic ->composition ->GPU NTT/commitments ->lookup/softmax ->sumcheck/GKR.


## Cycle 0022 — exact int16 FFN-down and corrected run clock attribution (2026-10-04)

Run `20261004T040146Z-c6dec297`, checkpoint 2026-10-04T04:21:18.017457+00:00. AGENDA and durable state/source register/latest results read. Project instructions, current target, MVP status, decisions and active coordination consulted. No native/GPU jobs, production edits, installs, Git or external messages. Prior memory prefixes pinned and previous STATE saved under the experiment.

Question: can exact int16 FFN-down witness work move to byte GEMM without changing precision, padding or the first refusal, and can low/high planes be stacked to amortize a launch? Baseline is `witness.rs::matmul_in_out` line312, down call685, after h16 has passed the product's inclusive int16 check. The candidate eliminates CPU direct down dots only if a device adapter wins; it doubles byte dot work and adds packing, sums, transfers, i64 reconstruction and synchronization. Stacking [low;high] can remove one API call; cache reuse or a device speedup was not measured. No proof relation, commitment, masks or randomness changed.

Identity x=((x&255)-128)+256*(x>>8)+128 is exact across all signed int16. Both slices fit signed bytes, including -32768/+32767. For padded K<=16384, byte partials <=2^28, column sums <=2^21, original dots <=2^36; i64 widening must precede reconstruction. Existing scalar requant and biased remainder remain exact, without clamp. Padded input zero maps to low=-128/high=0: applying the column correction to ordinary-zero packed token padding corrupts outputs. Every K coordinate read by the original helper stays in the candidate dot and column sum. Cache sums by immutable model/shape/layout identity; P3 sums stay private.

Reproduced synthetic evidence: 65,536 values/393,216 products;42 dots/192,132 terms with K up to16,384;72 matrices/1,680 output words across both orientations and both two-call/stacked models;6,162 requant checks;106 suffix cases,98 synthetic accepts and8 refusals covering gate/up/product/down/residual. Seventeen meaningful mutations plus two invalid-int16 controls detect offset omission, logical high shift, wrong low-byte signedness, high-byte carry endpoint failure, i32 reconstruction overflow, early rounding, truncation/ties, stale sums, token/internal padding, transpose, exclusive endpoints, excessive K and reordered first refusal. A 1,025-term control gives integer low partial 2^24+1; float32 loses one unit and reconstructs128 instead of129. Independent direct checked accumulation (separately pinned kernel), signed byte decode and floor-division references. Final 0.659741s, 16,900KiB RSS, one pinned/nice10 Core Ultra9 185H thread, Python3.10.12, seed2026100422;59s alarm,512MiB limit,64MiB estimate. Source/command/log hashes and earlier passing control-refinement revisions retained. Rust review primitives are uncompiled. No native/CUDA/transcript/RNG/PCS/proof or full-block parity result.

New source-based attribution correction supersedes allocation-only interpretations in cycles0019-0021 while retaining their raw measurements and arithmetic: `run.rs:565` starts Phases before boundary preparation and `src.witness(k)`; the first mark is only in `protocol.rs:804` after A filling; timing.rs measures elapsed since start. Thus86.691s first-mark parent also contains stage-prefix/boundary/witness work. RunStats documentation saying witness excluded disagrees with its actual timer start; stage timer spans witness and wire encoding/sink. `run_tests.rs::Chain` rebuilds each witness during proving after initial chain construction built/dropped it. The initial73.36s chain clock includes setup/census too, not isolated witness or measured startup. Current-source control flow is inspected, but source-to-historic timed ELF identity is not established. Do not infer separate down, conversion or allocation savings from the old label. A zero-cost deletion of BOTH entire initial-chain and first-mark parents leaves248.558226s out of408.609226s (arithmetic2.059880 positions/s); loose upper bound only, never a candidate saving/countable rate.

Count-only public Llama3-8B config at T512/Kpad16384/N4096 gives16MiB packed slices +16MiB i32 partials =32MiB extra scratch before BLAS workspace,16KiB column sums,64MiB padded weights, while64MiB existing i64 input and16MiB output remain. The geometry is not an admitted trained profile. No transfer/peak saving measured. End-to-end ceiling P/(T-C_down_all_builds+C_pack+C_upload+C_byte_GEMM+C_i64+C_download+C_sync), all accepted8B terms unknown. Falsify any byte/accumulator/remainder/support/refusal/RNG/transcript/receipt mismatch, integer/float epilogue error or added enclosing cost >= CPU cost removed.

Ranked queue:

| Rank | Hypothesis / end-to-end scope | Prerequisites, costs and falsification |
|---|---|---|
|1 owner|Actual GPU SC_SZC and witness recurrence remain highest measured recurring scope.|Native CUDA and full masked-transcript/receipt clocks; no duplicate jobs. Preserve slower fusion finding; mismatches or enclosing regression reject.|
|2 tested prerequisite|Exact split-int16 FFN-down GPU witness; broad witness scope, isolated down time unknown.|High native device integration, integer-only outputs, fresh masks; packing/twice byte work/copies/sync. Synthetic parity is not speed; full native and timing gates pending.|
|3 NEW next local|Tile K/output reconstruction and existing requant to avoid full partial-output buffers, retain stacked scheduling.|Moderate scheduling/ownership change; K tile bounds and i64 combination before rounding. Could save counted scratch; repeated launches/W reads can regress. Fails on bytes/padding/refusal or no peak/enclosing gain.|
|4|A write-once allocation/exact conversion, only unknown A-write subphase.|Existing compiled loop has no integer division; first-mark parent also includes witness/boundary. Matched allocation/conversion clocks and native byte/RNG gates needed. No measured traffic/capacity saving.|
|5|Typed/lazy last-read witness release enables better storage tier.|Moderate ownership changes; pack/replay/consumer lifetimes and peak costs pending. Retained codewords/overlap may erase benefit.|
|6|Resident fixed-context fresh complete passes amortize public model setup.|NTT already once/run, not/layer. Measure setup/slope/lag/drain/independent verify/peaks; preserve fresh randomness/P3 review. >20ms/new verified position falsifies50/s for tested schedule.|
|7|Packed/matrix sumcheck, lookups and private composition.|High protocol/PCS/soundness/privacy cost; no compatible replacement reproduced. Current small table and composition obligations remain.|

Six LIVE primary records: older Ozaki integer-engine paper (Jun21 2023/revisedMar30 2024, ozIMMU MIT inspected); June28 2026 scaling correction; GEMMul8 MIT inspected (HEAD date/commit unavailable); older gemmlowp offset handling Apache2 inspected (history Internal Error); September CUTLASS4.8 full commit098de2a652cf8f00fd70b2df54051c7eccbb855a (release displaySep22 noyear versus version changelog2026-09-17, discrepancy retained; license Internal Error); cuBLAS13.4 integer contract (update date/license unverified). No author performance reproduced. Numerical accuracy/CRT/small-field speed or Rubin FP8/FP4 release features are not our exact witness or5090 proof. cuBLAS documents integer input/output/scalars and alignment; Lt integer epilogues are constrained, so exact i64 reconstruction needs a separate audited path. No dependency installation or foreign code execution.

0 accepted private8B passes/0 countable tokens, CPU only, context null. All target throughput/startup/witness/proof/serialization/independent verification/latency/lag/drain clocks unmeasured. No prefill/resident/decode proof. Prior onecold synthetic12-block125M/T512/RTX4070Laptop8188MiB diagnostic unchanged:408.609226s total,318.22s runprover inclwitness/serialization,12.15s in-processverify,484107456B,independentfalse. Larger workloads permitted, context attentionT² and state binding remain. Target50/s unachieved. Handoff: handoffs/20261004-exact-int16-witness.md. Next: local tile/reconstruction/requant streaming oracle; owner isolates both witness passes and down cost before GPU/native A/B under shared guard.


## Cycle 0023 — exact row-tiled down/requant (2026-10-04)

Run `20261004T050146Z-1f54a8f9`, checkpoint 2026-10-04T05:17:45.049015+00:00. Read AGENDA, STATE, prior FINDINGS/source inventory/latest experiment, CLAUDE/START_HERE/current MVP/decisions/active coordination/throughput target. Work stayed inside research, excluding runtime; no production/reviewer/instruction/receipt/calibration/Git writes, native build, GPU, install or external message.

**Result:** 260 synthetic schedules,3380 independently compared raw dots,9508 accepted output/remainder words,162 rounding edges,14 mutation plus2 domain controls pass. Outcomes178 accepted arithmetic fixtures,81 down refusals,1 residual refusal. Final1.252728s/23096KiB RSS, one pinned nice10 CoreUltra9 185H thread, seed2026100423. CPU only, not native/CUDA/witness/proof evidence. Both weight orientations, forward/reverse public completion, full/split K, ragged output/K tiles, actual consumed internal K, ignored padded rows/columns and inclusive endpoints. K1023/1024/1025/14336/16384 and262146 tested; the last uses bounded1024 K tiles and synthetic shift18, not a registered profile. Independent raw-dot comparison includes refused cases. Initial nondiscriminating overflow control failure and intermediate pass preserved. [Experiment](experiments/tiled-down-requant-20261004/README.md).

**New source finding:** FFN-down matmul result at witness.rs685 is a temporary passed directly into quantize; only z16/RDL persist. Exact tiled reconstruction can remove the whole raw-accumulator temporary locally. Baseline materialized split releases packed after GEMM, partials after reconstruction, then allocates outputs. Candidate writes final planes after complete K sums. Final planes, proof work and fresh masks stay; no saved scalar product count (two byte MACs replace one wide MAC). First-refusal control shows early residual fusion returns residual instead of a later down failure: all down checks must finish before residual. Keep private status/order and unchanged site string. Native mask/RNG/byte/refusal gates owed.

**Lifetime-aware counts, not memory/speed measurements:** unadmitted public Llama3-8B metadata T512/Kpad16384/N4096 has local materialized split48MiB peak versus64-row/full-N/full-K36MiB with8 conceptual stacked GEMMs. Narrow64×128/full-K34.0625MiB with256; splitK1024 32.25MiB with4096 and512MiB packing. Untiled fused preallocation64MiB is16MiB worse. Final z16/RDL32MiB remains. Coarse64-row route naively reads512MiB logical weights versus64MiB once; actual cache/DRAM unknown. Counts omit workspace, mirrors, transfer/status/pools, input/weights/other planes and preallocated destination placeholders. Fine N/K tiling is demoted as a speed priority: little extra local payload benefit for many calls. K16384 full byte partials fit i32 already. Full builder/native peak is unknown.

End-to-end ceiling P/(T-C_down_all_builds+C_pack+C_upload+C_byte_GEMM+C_reconstruct+C_download+C_sync); accepted8B terms absent. Historical73.36s initial-chain and86.691s first-mark are combined parents, not down/alloc/startup clocks. Even zero-cost deletion of both leaves248.558226s of408.609226s, arithmetic2.05988positions/s only; not candidate saving or counted8B rate. Falsify raw/remainder/support/pad/first-refusal/native RNG/transcript/receipt divergence, new domain/refusal/privacy leakage, no native peak benefit or added enclosing costs>=removed down cost.

| Rank | Expected complete-proof scope | Prerequisites, added costs and falsification |
|---|---|---|
|1 owner|Actual GPU SC_SZC and witness recurrence, highest measured recurring scope.|High CUDA/transcript integration; full native byte/RNG/refusal, actual clocks/peak and complete proofs; no duplicate owned boundary lane. Preserve slower fusion. Mismatch/enclosing regression rejects.|
|2 refined/tested|Exact split-int16 down with coarse row-tiled finalization.|Arithmetic prerequisite passes; moderate/high native device work. Packing, twice byte products, W reads/launch/workspace/transfer costs; down time absent. No byte/refusal/peak/enclosing gain rejects.|
|3 NEW next local|Group/stride public row-tile scheduling to reuse packed slices and bound outstanding partials.|Moderate batch/pool/ownership work; exact independent address/status/completion checks, output ownership and CUDA lifetime gates. Fails on wrong bytes/order/stale sums or if grouping restores full scratch/call overhead.|
|4|Typed/lazy public last-read witness consumers.|Moderate ownership/reader integration; prior synthetic capacity evidence only. Pack/overlap/codeword retention can erase peak benefit; native RNG/refusal/privacy/byte/peak gates.|
|5|A write-once and exact conversion.|Compiled conversion has no division; unknown isolated allocation/conversion clocks, no full matrix capacity saving. Falsify already-eliminated stores/enclosing regression.|
|6|Resident fixed-context fresh independent complete passes.|Public setup/model reuse only; NTT already once/run. Record startup/slope/proof lag/drain/independentverify/memory. >20ms/new verified position rejects50/s for that schedule.|
|7 new literature filter|Certified lower-MAC integer fast matmul/composition.|High kernel or protocol integration; full -128/int16 domain, exact fixed relation/privacy review. Authors' reported slow kernel and our call/traffic counts demote MAC-count-only arguments; no target inference.|

Four LIVE source records appended: new Sep30[integer fast-matmul paper](https://arxiv.org/abs/2609.39816), older Oct25 2024[custom epilogue](https://research.colfax-intl.com/epilogue_visitor_tree/), [CUTLASS integer conversion/split-K source](https://github.com/NVIDIA/cutlass/blob/main/include/cutlass/epilogue/thread/linear_combination.h) and[Sep4.8 release](https://github.com/NVIDIA/cutlass/releases). Exact author claims remain unreproduced. HeaderBSD3 terms inspected; main update/fullcommit unknown; header history429TooManyRequests, tag header/LICENSE and ColfaxLICENSE InternalError. Release commit098de2a652cf8f00fd70b2df54051c7eccbb855a versiondiff inspected, not revisionmatched to main header; versionSep17 versus displaySep22 date distinction preserved. No bypass/foreign code execution.

Full-stack accounting: acceptedprivate8Bpasses0/countabletokens0,CPUonly/contextnull; steady/total rates,startupfraction,witness/proof/serialization/independentverification,latency/lag/drain clocksnull. No long-prefill,resident-pass or decode run. Prior n1cold synthetic12block125M/T512 RTX4070Laptop8188MiB unchanged408.609226s wall,318.22runprover includeswitness/serialization,12.15in-processverify,484107456B,independentfalse. Longer workloads permitted, attentionT² and authenticated decode binding remain;50/s unachieved. Local reports are not message delivery.

[Handoff](handoffs/20261004-tiled-down-requant.md) includes actual Rust/CUDA seams and uncompiled/unapplied tile interface. Owner first isolates both witness passes/down, then guarded coarse-row native/device parity/A/B. Next local: grouped/strided batch address-and-ownership oracle with fixed public schedule, output order/status/packing reuse, ragged/duplicate/nonoverlap and staggered completion controls. Rotate memory/batching ->composition ->GPU NTT/commitments ->lookup/softmax ->sumcheck/GKR ->quantization/arithmetic. Prior findings preserved.

## Cycle 0024 — public integer batch scheduling and a grouped-API negative (2026-10-04)

Run `20261004T060146Z-96d1ccac`, checkpoint 2026-10-04T06:16:07.388788+00:00. Read AGENDA and current durable memory/source register/latest results, CLAUDE/current target/MVP/decisions/active coordination. Early prior-prefix snapshots pinned at06:03:21UTC; early STATE's approximate06:05 label was ahead of wall clock and is superseded by this exact checkpoint. Research-only writes excluding runtime; no native build/GPU/proof/install/Git/external-message/production/reviewer/instruction/receipt/calibration writes.

Question: can public row/K-first batches reuse packed slices and reduce output-tile calls without restoring full scratch or changing private status? Baseline prior coarse row64/fullK8 calls/36MiB; N128256 calls/34.0625MiB, splitK1024 4096 calls/512MiB packing. Baseline fullK already packs once. Added pointer/descriptor/pool/synchronization and full row i64 splitK reduction costs must be counted; two byte MACs and final32MiB planes remain. Isolated native down/both witness-build clocks absent. Complete-proof ceiling P/(T−Cdown_all_builds+Cpack+Cupload+CGEMM+Cfinalize+Cdownload+Csync); no accepted8B terms measured.

Reproduced:576 synthetic schedules/11232 raw-dot comparisons including refusals/88272 separate column-major byte-output words/1152 accepted z16/remainder words/16 controls.72 accepted arithmetic fixtures,192 down refusals,312 residual refusals.0.642347s/17156KiB RSS, one pinned nice10 CoreUltra9 185H thread,seed2026100424,59s/512MiB caps,64MiB estimate. Supports both orientations, ragged output/K tiles, public staggered completion, exact K coverage, disjoint slots/epoch/lifetime, changed-value identical public traces, inclusive int16/-128, ignored dirty token pads and consumed internalK. Direct checked-i64/divmod reference independent of packing/plan; physical BLAS oracle independent indexing. Initial passing schedule-only revision preserved. Native/CUDA/RNG/transcript/proof evidence absent.

**Bounded negative:** at counted unadmitted T512/K16384/N4096, q32 grouped N128 tiles has36MiB/8 conceptual calls, identical payload/calls to coarse fullN but256 versus8 problems. No reason from these counts to prefer it. q4 gives34.25MiB/64calls versus34.0625MiB/256. Coarser row128/256 gives40/48MiB and4/2calls; row51264MiB is16MiB worse than materialized split48MiB. K-first1024/q4 reduces packed traffic512->16MiB but adds2MiB full-width reduction:34.375MiB/1024calls vsprior32.25MiB/4096. FullK partials safe already. Logical row64 W reads512MiB, actual cache/DRAMunknown. APIcalls are not measured launches; payload excludes workspace/mirrors/descriptors/status/transfers/pools/input/weights/other planes/preallocated outputs. No memory/speed improvement measured.

Native seam candidate witness.rs685 (matmul312/quantize284) pinned; same source in sonnet-hardening. Rootmain is older fixed shape, corresponding down392. Clarification avoids applying prior ambiguous relative685 to main. Full-domain exact temporary-down-to-z16/RDL interface retained. See [experiment](experiments/grouped-down-schedule-20261004/README.md) and [owner handoff](handoffs/20261004-grouped-down-schedule.md).

**Source filter:** [current official cuBLAS13.4](https://docs.nvidia.com/cuda/cublas/index.html) lists integer pointer-batched Ex but no integer grouped Ex, requires nonzero strided offsets/disjoint C, and distinguishes hard integer alignment from regular Lt IMMA TN. Model necessary layout checks2304pass/8532fail; no admitted device shapes. Older2017 zero-stride example cannot override current contract. New hypothesis: an identity-bound transposed model cache might enable a selected TN path where current in/out W yields NN. Full counted layer cache64MiB added if original stays; no integer5090 kernel speed or cache safety established.

Seven LIVE source records appended with dates/URL/license/revision limits: officialAPI, older2017/2024 blogs, CUTLASS persistent scheduler/header (BSD3 fullterms inspected), September4.8 release/full versiondiff commit098de2a652cf8f00fd70b2df54051c7eccbb855a, August12/revised14 B300 audit (explicitly no performance/5090 result). Main header/date unpinned; versionSep17 differs from release displaySep22 lacking year. Tagged scheduler/history `Internal Error` exact URLs retained; local experiment continued, no bypass/foreign execution. Source lists support scheduling/API rejection, not a literature-only result.

|Rank|Expected end-to-end scope|Prerequisites/costs/falsification|
|---|---|---|
|1 owner|Actual GPU SC_SZC and repeated witness work remain dominant measured recurring scope.|Existing owned native boundary lane; high CUDA/privacy/transcript cost, source-pinned full bytes/RNG/receipt clocks; preserve slower fusion. Mismatch or enclosing regression rejects.|
|2 refined/tested|Exact split-int16 down with coarse public row finalization.|Current scheduling/ownership prerequisite passes; moderate/high new integer adapter/transfer/workspace cost; down cost unknown. No supported integer path/actual peak/enclosing gain rejects.|
|3 NEW next local|Identity-bound TN transposed-weight/column-sum cache to avoid a generic NN path.|Public setup cache/tiled storage, actual integer algorithm/IMMA and device review;64MiB/layer if full duplicate, packing/startup/host-device costs. Any cache/dot/pad/model-identity mismatch or enclosing regression rejects; P3 stays private.|
|4|Typed/lazy last-read witness consumers.|Moderate ownership work; pack/replay/retained codewords/other planes can erase peak saving. Native byte/RNG/refusal/privacy and actual peak gates.|
|5|Resident fixed-context fresh independent complete passes.|Measure startup/slope/lag/drain and independent verification; NTT once/run already, model/P3 setup only reviewed reuse. >20ms/new verified position rejects50/s for tested schedule.|
|6|Composition/commitment/lookup architecture.|High soundness/privacy/PCS integration; no replacement accepted. Revisit with measured full-stack phase ceiling; preserve incompatible/small-parent negatives.|

Current CPU-only cycle0 accepted complete private8B passes/0 countabletokens/contextnull; steady/total rates,startupfraction,witness/proof/serialization/independentverification/latency/lag/drain clocksnull. Previous n1cold synthetic12block125M/T512/RTX4070Laptop8188MiB report unchanged408.609226s total,318.22s runprover including witness/serialization,12.15s inprocessverify,484107456B,independentfalse. No longcontextprefill/resident/decode inference. Longer workloads allowed; attentionT², fresh masks and authenticated decode state remain.50/s unachieved.

Nextlocal: independent TN transpose/cache/sum address-and-identity oracle plus local lifetime counts; cache stale/orientation/padding mutation controls. Owner isolates both witness/down clocks then guarded coarse64/128/256 device/native parity/complete-proof A/B. Rotation retains memory/batching ->composition ->GPU NTT/commitments ->lookup/softmax ->sumcheck/GKR ->quantization/arithmetic. Saved reports are not message-delivery evidence.


## Cycle 0025 — TN weight preprocessing and separated-scan residency (2026-10-04)

Run `20261004T070146Z-edcb9b00`, checkpoint 2026-10-04T07:17:56.512872+00:00. Read AGENDA, required durable memory/source inventory/latest experiment and project CLAUDE/target/MVP/decisions/active coordination. Research-only writes excluding runtime; no native build/GPU/proof/install/Git/external messages/production/reviewer/instruction/receipt/calibration changes. Prior prefixes pinned and retained.

**Result:**972 synthetic arithmetic cases,24138 raw dots,162864 independent physical TN byte outputs,46080 packed words,23640 accepted plane words,120 independent LRU/reuse-distance cases and23 controls pass. Seed2026100425;2.393366s/22068KiB RSS, one pinned nice10 CoreUltra9 185H thread;59s/512MiB caps,64MiBestimate. Arithmetic outcomes393accept/297down-refuse/282residual-refuse, not proofs. Both orientations, odd strides, aligned added zero tails, full/raggedK/N, inclusive extrema/-128, consumed dirty internalK, ignored stride/token pads, exact final pads/remainders/refusals. Initial syntax failure and pre-residency pass preserved. [Experiment](experiments/tn-weight-cache-20261004/README.md), [handoff](handoffs/20261004-tn-weight-cache.md).

Trusted synthetic immutable owner hashes content once; key binds model/layer/tensor/profile/calibration/epoch/orientation/dimensions/stride/content/ranges/layoutversion.1800builds/3600hits/zero content hash bytes on hits;42aligned output/input entries borrow storage. Current native down input/output still needs TN transpose. Independent storage/byte-product/reference dots agree. Stale/corrupt cache controls are startup/test audits, not runtime GPU protection or a native soundness/privacy argument. A Rust loader must enforce immutable admitted ownership; persisted caches need revalidation. No native witness/RNG/transcript/PCS/proof ran.

**Useful negative:** actual CLI StackSource seals layers0..L-1, restarts, then rebuilds0..L-1; boundary_plane/witness shares one cached witness, not a third build. Distinct32layer K16384/N4096 one-layerLRU still has64preparations/pass; it cannot halve preprocessing across those scans. All32down caches retain2048.5MiB extra plus original2GiB down weights;32preparationsonce vs64P atPpasses.128column cache2.000488MiB bounds capacity but tile-first64 vsrow-first8rowtiles512full-weight equivalent preps/pass. At4passes256 vs2048preps. Counts only, no large allocations; packX/residency/transfers/workspace omitted. Tile-first does not reuse across whole scans without retaining all tiles or changing source scheduling. Synthetic identical recipe weights can deduplicate differently; not assumed for trained distinct layers.

Baseline direct wide native down has no adapter cache overhead to remove. Versus a conditional uncached byte adapter, caching can remove transpose/sums/upload recurrence only with correct tier/lifetime. Adds loader identity scan, packing/startup/residency, leases/eviction/sync; no MAC/proof work removed. No isolated native down/preprocess clocks, accepted8B startup or rate. Ceiling N/(T-Cprep_removed+Csetup+Ccache+Ceviction+Ctransfersync) unknown. Falsify rawdot/plane/pad/support/refusal/identity/public schedule or native RNG/transcript/receipt mismatch, domain/privacy weakening or no enclosing gain. P3 cache/sums stay private; no masks/openings reused.

Ranked queue:
1. Owner actual GPU SC_SZC and witness recurrence: highest measured recurring scope, high CUDA/transcript/privacy/native gate cost; do not duplicate owned boundary work, preserve slower fusion.
2. Exact coarse-row fullK split-int16 down: current TN/identity prerequisite passes; moderate/high integer adapter/packing/transfer/workspace integration. Native down share/algorithm/peak/enclosing benefit unknown; full exact/native privacy/RNG/receipt gates.
3. NEW refined canonical TN public-weight owner with orientation-aware proof fold/digest reader: remove duplicate64MiB/layer only if all original consumers preserve canonical model bytes/support. Moderate/high ownership and verifier helper changes; independent Fp2/MSB fold and digest oracle next. Any coordinate/digest/refusal/byte divergence rejects. Current duplication remains.
4. Typed/lazy public last-read consumers: prior synthetic capacity findings, moderate reader/lifetime integration; codeword retention/packing may erase benefit. Actual peak/phase and native proof/privacy gates pending.
5. Resident fixed-context fresh complete passes: largerP may amortize all-layer setup; one-layer cache does not do so under current scans. Startup/slope/lag/drain/independentverify/peaks must be measured; no50/s if recurring complete verified work exceeds20ms/newposition for that schedule. LongprefillT²/decodebinding separate.
6. Composition rotation: newly assessed older ZKTorch pairing accumulation and FICS/FACS linear-code accumulation merit architecture analysis, high protocol/PCS/privacy integration; no compatible reproduced replacement or authorized protocol change.

Six LIVE source records appended: [cuBLAS13.4](https://docs.nvidia.com/cuda/cublas/index.html) contracts/heuristics/AlgoCheck; older [gemmlowp pack](https://github.com/google/gemmlowp/blob/master/internal/pack.h) and Apache2terms; [ZKTorch](https://arxiv.org/abs/2507.07031) Jul9/revised10 2025 pairingBN254,1tokenLlama2 author scope; [FICS/FACS](https://eprint.iacr.org/2025/737) receivedApr24 2025/revisedMay20 2026/CRYPTO2026; September [CUTLASS4.8](https://github.com/NVIDIA/cutlass/releases) and UIUCREADME scope. Full gemmlowp Androidlink merge16e8662c34917be0065110bfcd9cc27d30f52fdf inspected/historyNov3 2023; not main pack.h pin. Tagged pack/LICENSE Cachemiss; UIUC history/license/releases and actual ZKTorch anonymous code InternalError. CUTLASS full versiondiff098de2a652cf8f00fd70b2df54051c7eccbb855a versionSep17 vsrelease displaySep22withoutyear retained. No author gains reproduced, foreign code executed or blockers bypassed.

Full-stack accounting: CPUonly, accepted complete private8Bpasses0/countabletokens0/contextnull; steady/total rates,startupfraction,witness/proof/serialization/independentverification,latency/lag/drainnull. No longprefill,resident/decode proof. Historical n1cold synthetic12block125M/T512/RTX4070Laptop8188MiB diagnostic unchanged408.609226s wall/318.22combinedrunprover/12.15inprocessverify/484107456B/independentfalse.50/sunachieved; larger workloads allowed, fresh masks/full privacy/contextT²/authenticated decode preserved. Reports saved locally, not delivery evidence.

Next: independent orientation-aware fold_cols_i8 and canonical statement digest oracle at argument.rs1426/1433, private_block.rs575; pin actual consumers/loader/support, include stale/transposed/ragged controls. Owner first isolates both witness/down/preprocessing clocks then guarded supported integer native/device parity/full-stack A/B; no job launched. Rotation composition ->GPU NTT/commitments ->lookup/softmax ->sumcheck/GKR ->batching/amortization ->quantization/arithmetic. Preserve all prior negatives.


## Cycle 0026 — canonical TN readers and bounded digest transpose (2026-10-04)

Run `20261004T080146Z-55b15f9d`, checkpoint 2026-10-04T08:18:12.165349+00:00. Required agenda/state/findings/source inventory/latest result and project CLAUDE/START_HERE/MVP/decisions/active coordination/target read; baseline/source prefixes pinned. Research-only writes excluding runtime; no native/GPU/proof/install/Git/external messages or production edits.

**Result:**324 synthetic cases,3888 fresh Fp2 folds/40824 output words,10206 independent raw witness dots,1157652 canonical FFN bytes,315 support refusals,576 line-accounting cases and26 controls pass. 0.460062s/17392KiB RSS, seed2026100426, one pinned nice10 CoreUltra9 185H CPU thread,59s/512MiB caps. No measured proving improvement. [Experiment](experiments/tn-canonical-readers-20261004/README.md) and [owner handoff](handoffs/20261004-tn-canonical-readers.md).

Original signed-row bit-product/byte-pack/dot references agree with TN-column candidate, native MSB Fp2 equality order, full/ragged blocks, both challenge components/base/Boolean points, extrema and odd stride guards. Byte comparison covers exact FFN u64LE tensor lengths, original input/output order, signed byte representation and i16LE activation words. SHA256 diagnostic agrees; native BLAKE3/full statement/transcript/RNG/PCS/proof unexecuted. Startup identity/support audit models immutable admission, not Rust ownership. Dirty canonical pad is refused even if a folded row cancels at one challenge; aligned adapter tails are zero, ignored physical guards remain outside canonical bytes. Initial pre-witness/admission pass retained. All controls/source/commands/hardware pinned.

Conditional32layerK16384/N4096 all-layer original+TN down cache can lose2GiB original bytes only after **all** consumers migrate; TN2GiB+0.5MiB sums stay. Native currently has only original W, with no duplicated integer adapter to remove. Counts use unadmitted metadata; no big allocation/actual peak/GPU gain. Native per-tensor byte-cast collect Vec is64MiB for down; modeled64row canonical stream scratch256KiBRust/512KiBPythoncopy. Chunked hashing can separately bound current original-store cast allocations. No MAC/proof/mask work removed. Source-line episode model1row->64rows changes2,147,483,648->33,554,432 across32layers, assuming cache reset per block; real row footprint256KiB can remain cached. This is **not**64x measured DRAM/speed, and bounded transpose adds scatter/hash calls/workspace.

Baseline conditional original+packed cache; eliminate duplicate retention/full cast temporary/repacking only with valid residency. Add import/canonical identity, migration/leases, transpose/scratch/scatter/fresh fold/transfer/workspace/sync. Complete ceiling N/(Tbaseline-Cremoved+Cadded) unknown; isolated down/prep/digest clocks/actual peak absent. Falsify logical value/support/refusal/framing/model identity or native bytes/RNG mismatch, weakened privacy/domain or no enclosing/peak gain. P3 metadata/storage stay private and require reviewed binding; no blinding/opening reuse. Previous separated-scan LRU, slower fusion, small-parent and arithmetic negatives preserved.

|Rank|Hypothesis and expected enclosing impact|Prerequisites / cost / falsification|
|---|---|---|
|1|Owner GPU SC_SZC and witness recurrence; highest measured recurring scope.|High CUDA/masked-transcript/privacy integration; exact native polynomial/bytes/RNG and enclosing independently verified workload clocks. Preserve slower fusion; no duplicate job.|
|2|Exact coarse full-K split-int16 down; native down share unknown.|Moderate/high integer algorithm/packing/transfers/workspace; both witness scans and actual peak required. Any value/range/refusal/native receipt mismatch or enclosing regression rejects.|
|3 refined/tested|Canonical TN owner plus bounded canonical digest, enabling cache residency without duplicate W.|324-case prerequisite passes; moderate/high constructor/loader/witness/verifier/ownership migration. Conditional2GiB duplicate capacity, not current native saving. Native BLAKE3/RNG/byte/peak gates; canonical support/framing mismatch rejects.|
|4 NEW local|Admitted immutable public digest memoization / full public preimage streaming: remove repeat model scans and cast allocations.|Moderate callgraph/clone/identity work; digest calls found at BlockPublic614, RunStatement202, model_root289, protocol117. No challenge-dependent folds cached. Unknown phase share; stale tables/model/domain/calibration/shape or no enclosing benefit rejects.|
|5|Typed/lazy public last-read witness release.|Moderate reader/lifetime integration; retained codewords/packing can erase gain. Native lifetime/byte/refusal/privacy/actual peak gate.|
|6|Resident fixed-context fresh complete passes.|Startup/slope/lag/drain/verification/peaks required; one-layer LRU fails current separated scans. More than20ms recurring complete verified work/newposition cannot meet50/s for that schedule. No decode inference.|
|7|Composition/PCS/lookup architecture including August batch-evaluation compiler.|High protocol/soundness/privacy/commitment cost. New round/polynomial and univariate-vs-MLE/prover costs prevent a drop-in claim. No reproduced native replacement.|


Five LIVE primary records appended: [cuda-zkp-ntt release](https://github.com/Artemarius/cuda-zkp-ntt/releases) declares its full hierarchical transform incorrect; release day omits year, MIT main terms inspected, exposed commit fetchfailed (not inspected). New older [small-characteristic sumcheck](https://eprint.iacr.org/2024/1046), receivedJun27 2024, reports Algorithms3/4 slower in its BabyBear degree4 implementation; no Goldilocks2 transfer. Associated repository implementation license/history/source fetches failed. [Batch polynomial evaluation](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITC.2026.3) publicationAug12 2026/ePrintMar4-5 history verified; univariate extra-round/polynomial/O(dm) prover and unresolved multilinear efficiency retain high integration cost. Packed-mask repository only scoped as its distinct first-round construction, no native flaw/reproduction inferred. Exact URLs/date/license/exposed-vs-inspected commit/fetch limits saved; no bypass/foreign code execution or author performance reproduction.

Full-stack evidence: CPUonly, accepted complete private8B passes0/countabletokens0/contextnull/passes0; steady/total rates,startupfraction,witness/proof/serialization/independentverification/latency/lag/drain unmeasured. No longprefill/resident/decode proof. Historical n1 cold synthetic12block125M/T512/RTX4070Laptop8188MiB diagnostic unchanged408.609226s wall/318.22combinedrunprover/12.15inprocessverify/484107456B/independentfalse. Later CLI has no terminal result after recorded reboot; stale running state not liveness.50/sunachieved; larger workload allowed, attentionT²/fresh masks/authenticated decode preserved.

Next local: exact full public preimage and immutable-digest call/clone/identity audit, include attention tables/domain/calibration/shape mutations and resident-pass versus startup scan counts. Owner prioritizes isolated both-witness/down/prep/digest/peak clocks then guarded native/device parity and independently verified complete-stack A/B. Rotation NTT/commitments->lookup/softmax->sumcheck/GKR->memory->batching->arithmetic->composition. Reports saved locally; no notification-delivery claim.


## Cycle 0027 — complete public digest cache and scan attribution (2026-10-04)

Run `20261004T090146Z-73c03938`, checkpoint 2026-10-04T09:19:08.453675+00:00. AGENDA/current target and durable/project memory read; originals pinned under `experiments/full-public-digest-cache-20261004/snapshots/`. Research-only CPU lane, one thread, <=60s and <=512MiB. No native/GPU/build/install/Git/external writes. No proving improvement measured.

Tested complete attention+FFN public-preimage streaming and immutable owner-local digest cache. Independent original-order struct.pack reference versus separately typed streaming schema: 27 cases, 216 chunk comparisons, 696,744 exact bytes, 351 tensor mutations, 486 cached-digest comparisons, 81 model-root comparisons, 189 outer-binding mutations, eight independent scan schedules and 23 controls pass. Final 0.144145s / 17812KiB RSS, seed2026100427, one pinned low-priority Core Ultra9 185H thread; 59s wall/CPU, 512MiB AS caps. SHA256 diagnostic only; native BLAKE3/transcript/RNG/PCS/receipt/concurrency/ownership were not run. First invalid extrema mutation and first passing result with incorrect cross-process cache accounting preserved; final counts independently check cold resets.

Source-pinned seam: candidate/sonnet `private_block.rs`494/575/614, both SHA2569540a7e60a2d07f2988d57267e9971c618627407dc9109f691656ea300c5b96d. Constructor absorbs13 ordered arrays with u64 element-count frames; signed i8 bits and LE i64/i16 preserved. Review-only Rust source/diff adds safe64KiB cast scratch and OnceLock<Digest>; uncompiled/unapplied. Owner cache works only for unchanged owned words. Current getter/constructor scan finds no post-construction writer, but descendant modules can mutate private fields; a stale initialized-clone mutation control fails equality as intended. Imported/fresh verifier words independently hash; caller digest is never cache authority or model provenance. Profile/shape/calibration/endpoint/context/schedule stay in outer native checks; diagnostic binding projection is not native header parity.

NEW attribution negative: `run.rs`571/717 already reads stored block_digests during stages. There is NO full-model digest scan removed inside a proof stage. CLI model root and statement construction scan twice before proving; fresh verifier likewise. Repeated cold processes have2P->P scans, resident model/root with fresh statements P+1->1 conditionally, fixed existing statement has setup-only scans and does not establish distinct newly proved positions. Synthetic DenseRun clones before initialization, so cold Clone is not a shared warm cache. No resident driver/result or private randomness reuse.

Count-only unadmitted Llama3-8B padded public layout T512: model preimage7,801,753,824B (~7.266GiB), i8 cast payload7,784,890,368B, maximum64MiB cast temporary -> proposed64KiB scratch; cached digest payload1KiB + unknown cell overhead. No large allocation, DRAM/host/GPU peak or speed measured. T-dependent RoPE invalidates complete digest across longer contexts; attention remains quadratic. Removed conditional scans/temporary; added first hash/scratch/cache checks/ownership/import/clone and independent auth costs. Ceiling N/(T-Drepeated+Ccache+Cstream) unknown without isolated digest and accepted8B clocks. No matrix/SC_SZC/mask/proof work removed. Falsify any canonical/native digest, support/table/refusal, outer binding/provenance/RNG/transcript/receipt/privacy mismatch, stale clone, cross-process trust, peak failure or enclosing regression.

Ranked: 1 owner GPU SC_SZC + witness recurrence (highest observed recurring scope; high native/device cost); 2 exact coarse fullK split-int16 FFN-down (packing/transfers/twice byte products/i64/requant/refusal; isolated clocks unknown); 3 tested full public digest/cache (moderate local integration, native ownership/byte gates pending, stage benefit absent); 4 TN canonical weight owner/migration (all consumers before dropping duplicate); 5 NEW context-change incremental hasher prefix cache before first T-dependent table (unchanged digest framing; FFN after table still scans, bound before integration); 6 resident fresh complete-pass startup/slope/lag/drain/verify sweep; 7 lookup/composition/PCS (high protocol/field/privacy cost). Preserve all earlier slower fusion, small-parent, compiler division, separated-scan LRU and scheduling negatives.

Five LIVE primary records appended: new September30 GlueLUT revision (section7 excludes PCS/full SNARK, different composite ring); older newly assessed cq preprocessing (2022-12-25/2024-07-05, homomorphic/pairing large-table regime); official OnceLock source/Clone semantics; DeepProve public context cache/history pin and license-fetch limits; BLAKE3 latest version commit/licensing/date limits. Author gains not reproduced. Exact URLs/dates/commit/license qualifications/fetch errors in experiment records. Next rotation sumcheck/GKR then memory traffic/batching/arithmetic/composition/NTT.

[Owner handoff](handoffs/20261004-full-public-digest-cache.md), [experiment](experiments/full-public-digest-cache-20261004/README.md). Owner first isolates digest call/byte/cast clocks in setup/statement/fresh verification and actual peaks alongside witness/down/SC_SZC; then shared-lock native frozen bytes/refusals/RNG, device parity and independently verified complete-stack A/B. No heavy job queued. Next LOCAL: prefix-hasher copy across T changes, compare exact whole preimages and prove remaining-tail scan bound.

Accepted complete private8B passes0/countabletokens0,CPUonly/contextnull/passes0. Steady/total rate, startup fraction, witness/proof/serialization/independent verification and proof latency/lag/drain unmeasured. No prefill/resident/decode proof.50/s unachieved. Historical n1 cold synthetic12block125M/T512 RTX4070Laptop total408.609226s,combinedrunprover318.22s,inprocessverify12.15s,484107456B,independentfalse unchanged; old CLI lacks terminal result after recorded reboot. Larger workloads permitted, fresh masks/privacy unchanged. Reports local, not evidence of notification delivery.

## Cycle 0028 — public hash prefix reuse has a large remaining suffix (2026-10-04)

Run `20261004T100146Z-8793c93e`, checkpoint 2026-10-04T10:17:12.159921+00:00. AGENDA, durable memory/source history/latest results and project CLAUDE/status/decisions/active coordination/current target read; originals/source reports pinned under experiments/public-prefix-checkpoint-20261004/snapshots/. Research-only one-thread bounded CPU lane. No production/runtime edits, native build/proof/GPU/install/Git/foreign-code execution/external write/message. **No proving improvement measured.**

Exact unchanged-order public hash prerequisite passes:72synthetic cases,576byte comparisons/3,274,560bytes,576resumed diagnostic hashes,936tensor mutations,576branch checks,72cold imports,5schedule checks,22controls. Final2.623259s/20084KiBRSS, seed2026100428, one pinned low-priority CoreUltra9 185Hthread;59s wall/CPU/512MiB AS caps. Independent prior struct.pack canonical preimage vs separate typed signed stream; SHA256statecopy models ordinary incremental hashing. Native BLAKE3/RNG/masks/transcript/PCS/receipt/concurrency/immutability not tested. Initial54-case pass preserved before adding actual stale-owner mutation and a >1024Bprefix fixture. No real private data used.

NEW counted negative: dynamic RoPE length frames precede the entire FFN. Before the first frame, the ordinary checkpoint can reuse the domain/five attention tensors, but every suffix frame and FFN word still hashes. Unadmitted public32layerLlama/D4096/F16384/KV8/dh128/T512 prefix1,342,310,624B vs full7,801,753,824B(17.205%); suffix6,459,443,200B(82.795%). Four distinct contexts512/1024/2048/4096 remove4,026,931,872Bof31,391,564,672B(12.828%) including cold prefix. Same-context finished digest cache dominates after the first call. These are allocation-free logical hash bytes, not runtime/DRAM/peak gains or admitted profiles. No universal bound on other hashing algorithms claimed.

NEW ownership/cost negative: source constructors still support-scan and copy1,342,308,352prefix bytes per new32layervariant. Current Vec ownership does not provide cross-context shared weight identity; shared immutable owner/support-shape certificate would be added integration work, and all table/refusal/provenance checks remain. No validation/copy saving priced. Cached state is local, never imported/caller asserted; actual verifier content is independently hashed. Controls detect stale internal mutation, wrong owner/domain/order/framing, concatenated/finalized digest substitutions, obsolete context frame and omitted FFN. Public P1 cache provides no P3/private opening or mask reuse authority.

Native seam private_block.rs494/614, candidate/sonnet bothSHA9540a7e60a2d07f2988d57267e9971c618627407dc9109f691656ea300c5b96d. No Rust patch for the demoted candidate; tested oracle/interface in [handoff](handoffs/20261004-public-prefix-checkpoint.md) and [experiment](experiments/public-prefix-checkpoint-20261004/README.md). Removed only conditional prefixhash; added firsthash/statecopy/owner checks/stream/context validation/suffix/import/freshauth. Complete ceiling N/(T-Dprefix+Cstate+Cowner+Cstream) unmeasured. Falsify any native byte/hash/refusal/binding/RNG/transcript/receipt/privacy mismatch, staleowner/coldcache trust or enclosing regression.

Ranked:1owner GPU SC_SZC+witness recurrence;2exact full-K split-int16 down;3NEW memory-bounded exact SC_SZC reconstruction windows;4finished-public-digest stream/cache and TNowner;5residentfresh complete-pass startup/slope/drain/verify;6prefix checkpoint demoted. All earlier negatives preserved. Next local test reconstructs MSB-folded SC_SZC tables from immutable synthetic inputs/challenges with independent per-round/final cube checks; count rereads/field work/live payload including parent retained codewords. Exactseams zkp-core/sumcheck/rounds.rs19/grouped.rs22 and private_block/argument.rs495/553 pinned. Native uses MSBhalf-split; do not blindly transplant earlier Pythonpair-split conventions. Native masked-boundary owner work is not duplicated. Main/Claude reviews/integrates under shared locks; no heavy job queued.

Six LIVE qualified records appended: current sumcheck/Septemberauthor explanation, older newly assessed modularVE(2023-09-08/latest2024-04-18;PCS/privacy/compiler filters), EPFLstreamingdesign/security/history, ICICLErelease/versiondiff/MIT scope, BLAKE3 ordinaryClone/existingdependency/packagedate. BLAKE3 1.8.7 publication now verified2026-08-20, superseding cycle27unknownyear. EPFLlicenses/detailInternalError and explicitBLAKE3sourceCachemiss saved; no bypass, author gain reproduced or code adopted. Rotation nextmemorytraffic/batching/arithmetic/composition/NTT/lookup/sumcheck.

Accepted complete private8Bpasses0/countabletokens0; CPUonly/proofcontextnull/passes0. Steady/total rate/startupfraction/witness/proof/serialization/independentverification/latency/lag/drain unmeasured. No prefill/resident/decode proof;>=50/sunachieved. Historicalsynthetic12block125M/T512 RTX4070Laptop diagnostic408.609226swall/318.22combinedrunprover/12.15inprocessverify/484107456B/independentfalse unchanged; laterCLI lacks terminal result after reboot, no liveness inferred. Larger workloads allowed; attentionT² and fresh masks/privacy unchanged. Saved reports are local artifacts, not delivery evidence.


## Cycle 0029 — reconstruction tradeoff and symbolic equality storage (2026-10-04)

Run `20261004T110146Z-56ac7478`, checkpoint 2026-10-04T11:20:00.819612+00:00. AGENDA/current throughput target, durable memory/source inventory/latest result, new handoffs and project instructions/status/decisions/active coordination read. Early checkpoint at11:04:03 UTC and originals/source/report pins retained under experiments/sc-szc-reconstruction-windows-20261004/snapshots/. Research-only writes excluding runtime. No native/build/GPU/install/Git/downloaded execution/external write/message. **No proving improvement measured.**

72 synthetic window schedules over 24 fixtures passed: 1,485 degree samples, 297 independent original-cube samples, 1,548 final values, 360 independently checked cost counters and 14 controls. Added symbolic-equality-only evaluation passed 495 degree samples and 516 final values. Final run 5.502258 s / 19,792 KiB RSS, seed 2026100429, one pinned low-priority Core Ultra 9 185H thread; 59 s wall/CPU and 512 MiB address-space caps. Full/base/zeroFp2, pads, MSB half-split, short p_ht, ragged pairs and actual group-claim recovery preserved. There are66 zero-factor fallbacks and528 recoveries across window schedules, without resampling. Direct expanded original-cube oracle covers all degree samples for n<=4; n6 samples use materialized reference and every final uses direct MLE. Native IR/masks/RNG/transcript/extensions/PCS/receipts/privacy untested. Initial pass and later control/accounting refinement results retained.

NEW negative: simple per-round bounded reconstruction at illustrative n23/K23/B4096 reduces table buffer3,489,660,928->3,014,656B, excluding source/scratch owners. It adds11 source scans and1,929,379,840 reconstruction multiplies versus192,937,961 baseline data-fold multiplies; residual folds/prefix generation add more. A separate fullFp2source copy adds3,087,007,744B. No native memory/time gain follows; this is not staged Blendy/RW streaming and does not falsify those stronger methods. Existing A/H/codeword tier lifetimes remain; no duplicate-source capacity excluded silently.

NEW lower-cost refinement: why still build/fold Eq arrays when grouped brackets factor them? Symbolic-only Grouped port passes495samples/516finals against original materialized tables, preserving exact short equality and final order. Candidate removes only3Eq full arrays plus3*(2^n-1) multiplies/adds/subtracts, adding roles/compact point state/final synthesis and no source rereads. Count-only n23 gives384MiB; illustrative K23+3 capacity fraction11.538%, not parent peak/runtime. Native Vec::truncate does not shrink capacity; original grouped fold has no shrink call. Role-aware construction must precede eq_cube allocation, maintain all original indices/finals and pass native extension/mask/RNG/frozen receipt gates. No native patch applied.

Seams: SumcheckRounds at rounds.rs19; grouped.rs22/167/172; argument.rs195/311/495/553/1699; zk.rs1091. Source SHA256/snapshots pinned; [experiment](experiments/sc-szc-reconstruction-windows-20261004/README.md) and [handoff](handoffs/20261004-sc-szc-symbolic-equality.md). Baseline/eliminated/new costs and end-to-end formula documented; accepted8B and isolated phase clocks absent. Any sample/final/refusal/index/binding/RNG/transcript/receipt/privacy mismatch or no actual peak/enclosing benefit falsifies. Main/Claude reviews and integrates; no heavy job queued.

| Rank | Hypothesis and enclosing impact | Prerequisites, cost and falsification |
|---|---|---|
| 1 | Owner GPU SC_SZC and recurring witness work; highest measured recurring scope. | High CUDA/representation/masked-boundary integration. Isolate both witness builds, down and SC_SZC clocks; exact native samples/finals/RNG/receipts and independently verified workloads. Existing slower fusion stays demoted; no duplicate owner job. |
| 2 | Exact coarse full-K split-int16 FFN-down. | Moderate/high packing, twice byte products, i64 accumulation, requantization, workspace and transfers. Actual down share unknown. Any value/range/refusal/native-byte mismatch or enclosing regression rejects. |
| 3 NEW, prerequisite tested | Symbolic equality storage in grouped SC_SZC, while retaining ordinary data-table folds. | Moderate role-aware evaluator/constructor work. Removes three full allocations and their folds, no repeated source scan. Preserve original table indices/final order/short p_ht and native masking/extensions/PCS. Native capacity and phase clocks absent; any mismatch or no actual peak/enclosing benefit rejects. |
| 4 | Finished public digest/cache and TN immutable owner. | Moderate/high owner/canonical-reader migration. Setup-only digest benefit and conditional duplicate-weight capacity remain; no recurring proof-stage digest scan removed. Native ownership/byte/peak gates pending. |
| 5 | Resident fixed-context fresh complete-pass amortization. | Measure cold startup, recurring slope, drain, lag, verification, distinct proved positions and peak tiers; independent contexts are aggregate throughput, not decode. No freshness or privacy relaxation. |
| 6, tested and demoted | Per-round source reconstruction plus bounded pair windows. | High native source-reader/retention integration; repeated weighted field arithmetic and source reads. Could enable capacity only if no duplicate sources/actual blocking peak is removed. Round/final/refusal/order/binding/mask mismatch or enclosing regression rejects. |
| 7 | Read-write/staged streaming or composition architecture. | High private storage/transcript/PCS/soundness review. Scribe is a scheduling lead, not native PCS replacement. Read-write streams add I/O/leases; changing variable order is forbidden for a byte-preserving candidate. |

Seven LIVE records: newly assessed product sumcheck2025/1473 revisedFeb25 2026; older Blendy section4/7 refinement beyond cycle13; newly assessed Scribe2024/1970 revisedJul29/Aug2026proceedings and RW/symbolicEq scheduling; EPFL design/license refinement (MIT terms now inspected via old URL redirect, canonical failure retained); hardware study refresh; Jolt displayedOctober1release/date-year limitation and benchmark-only commit pin5101ad2143039de6f279613810414c3d071d1f8f; official Rust capacity contract. Paper/repository performance not reproduced. PDF/license/history failures retained without workaround. Rotation memory traffic -> batching/amortization -> arithmetic -> composition -> NTT/commitments -> lookup/softmax -> sumcheck/GKR. Preserve slower fusion, small-parent, separated-scan LRU, compiler conversion and all prior negatives.

Accepted independently verified complete private 8B proofs/passes: 0; countable tokens: 0. Device: CPU only; proof context: null; passes: 0. Steady-state and total-workload rates, startup fraction/duration, witness/proof/serialization/independent-verification clocks and latency/lag/drain are unmeasured. No long-context prefill, resident-model pass or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads remain permitted; attention work grows quadratically with context, and all coverage, fresh masks and decided privacy obligations remain. Historical n1cold synthetic12block125M/T512/RTX4070Laptop diagnostic unchanged408.609226s wall/318.22combined run-prover/12.15in-processverify/484107456B/independentfalse. LaterCLI still lacks terminal result after recorded reboot; stale state not liveness.

Next LOCAL: index-preserving tagged Eq/Pub/Priv reader/final oracle, arbitrary point starts/empty equality/N1 and source-derived Rho/Flip/Fixed/broadcast maps. OWNER: table length/capacity/allocation/fold and both-witness/down/SC_SZC clocks, then guarded native/device/fresh independently verified full-stack A/B. Reports are local artifacts, not external notification-delivery evidence.


## Cycle0030 — tagged equality storage and cubic contraction filter (2026-10-04)

Run `20261004T120146Z-d7433b90`, checkpoint 2026-10-04T12:19:53.569647+00:00. AGENDA/current target, durable state/findings/source history/latest results/handoff and project instructions/status/decisions/active coordination inspected; originals/source pins under experiments/sc-szc-tagged-equality-20261004/. Early checkpoint12:03:17UTC. Research-only CPU lane; no production/runtime edits, native/build/GPU/install/Git/downloaded execution/external writes/messages. **No proving speed improvement measured.**

40 mixed-table fixtures and 41 exhaustive equality-span fixtures passed: 1,128 source-map words, 1,128 independent original-cube degree samples (528 mixed + 600 spans), 363 direct-MLE final values, 240 synthetic extension samples, 120 count checks and 19 controls. Final run 7.695833 s / 17,212 KiB RSS, seed 2026100430, one pinned low-priority Core Ultra 9 185H thread; 59 s wall/CPU and 512 MiB address-space caps. Tuple-field original-cube oracle separately computes all samples/finals/source maps; mixed fixtures cover n0/1/2/3/5, base/full/zero/Boolean fields, Rho/Flip/Fixed/multislice coefficients, broadcasts, shuffled Eq/Pub/Priv indices and every permitted bounded(start,length). 122 recoveries/46 zero-prefix/factor fallbacks without resampling. Synthetic extensions only; native actual polynomial/IR/CFS/RNG/transcript/PCS/frozen receipts/privacy untested. Duplicate moving coords are outside the native schedule prerequisite, not a reproduced refusal domain. Initial30-case code/results/logs retained with exact original hashes; refinement keeps native common data scan and expands controls.

NEW refinement: symbolic build must preserve Eq/Pub/Priv original indices, explicit cube dimension even when first slot isEq, and final values for generic polynomial/extension consumers. SC_SZC is Host, so its scalar avoids total(), but generic private slots require a symbolic total adapter. Opaque bracket Fn needs audited dependencies or typed IR; replacing Eqcur/dif by unused placeholders cannot apply generically. Native census and old-table test comparisons require exact adapters. Data sources/full data folds/common scan/PCS owners remain. Remove3EqfullVecs and folds only before eq_cube allocation; Vec::truncate keeps capacity. Count-only n23 removal384MiB/11.538% illustrativeK23+3 capacity,25,165,821 fold multiplies/adds/subtracts each; <=69 compact scalar updates. Parent peak/traffic/time unmeasured; no masks/openings/challenges reused across proofs.

NEW negative: naive cubic contraction f*MLE(g*h) matches original triple product at Boolean endpoints but fails t2/t3 (t2:1320vs1192). Four deterministic tuple-oracle checks retained in highdegree-control.json. This is a transfer filter, **not a TensorZKP paper defect assertion**. Their August2026 proceedings use H10080GB/BabyBeardegree8, report52.9GBat2^25 and pipeline overhead; different field/PCS/highdegree mechanisms cannot provide nativeGoldilocks/Fp2degree4/5 rates. Source/history/license qualifications retained.

| Rank | Hypothesis / enclosing impact | Prerequisites, costs, exactness and falsification |
|---|---|---|
| 1, owner | GPU SC_SZC plus recurring witness work; largest measured recurring scope. | High CUDA/representation integration. Isolate both witness builds, down and SC_SZC before scheduling. Native masked samples/finals/RNG/receipt and independent complete workload verification required; any mismatch or enclosing regression rejects. No duplicate owner work launched. |
| 2, owner | Exact coarse full-K split-int16 FFN-down. | Moderate/high packing, two byte products, i64 accumulation, requant/refusal, transfer/workspace costs. Down share still unmeasured; any exact arithmetic/range/native-byte mismatch or enclosing regression rejects. |
| 3, materially refined/tested | Tagged symbolic Eq storage before SC_SZC allocation, preserving original table indices and final order. | Moderate role-aware build/evaluator/census/test adapter. Eliminate three full Eq tables and folds; retain all data folds and common scan. Add compact descriptors/validation/scalar finals. Native closure/IR, masking/extensions and receipt/peak clocks remain; any parity/privacy/peak or enclosing regression rejects. |
| 4 | Immutable public digest/TN weight owner. | Moderate/high consumer/owner migration; finished-digest benefit is setup-only in current path. No proof-stage full-model scan removed. Source identity/import/clone/native byte and peak gates remain; no P3 private opening reuse. |
| 5 | Fresh resident-model complete-pass amortization. | Measure fixed context/pass count, startup boundary, recurrence slope, lag/drain/verification and all memory tiers. Distinct contexts give aggregate throughput; decode requires authenticated growing KV state. Mask reuse or omitted proof work rejects. |
| 6, NEW next local question | Two-layer split-equality weighted accumulation instead of multiplying both split weights per pair. | First exact grouped-loop oracle and counted field operations for empty/delayed/short points, zero factors and arbitrary Fp2; preserve native common data scan and subgroup recovery. Additional accumulator/scratch and locality costs must be included. Any sample/final mismatch or no counted/owner enclosing benefit rejects. |
| 7, demoted | Simple per-round source reconstruction / hash prefix reuse. | Reconstruction adds many scans/multiplies; prefix hash leaves most FFN suffix and constructor scans. Prior negative results stand. Staged/RW architecture remains a separate high-cost privacy/storage/PCS question. |


Complete ceilingN/(T-Ceq+Croles) unknown: accepted8BT and isolatedEqphase clocks absent. Falsify any original sample/final/index/support/refusal/RNG/transcript/extension/receipt/privacy mismatch, lost coverage, actual peak failure or enclosing regression. Owner reviews/integrates [handoff](handoffs/20261004-sc-szc-tagged-equality.md); [prototype/results](experiments/sc-szc-tagged-equality-20261004/README.md). Native seams argument.rs195/284/311/495/553/570/1699,grouped.rs22/86/149/172,rounds.rs19,zk.rs1091. No Rust patch or heavy job queued.

SixLIVEqualifiedrecords appended: originalGruen2024/108 andDaoThaler2024/1210 (newly assessed original scopes), combinedMarch2026/587date correction approvedvsrevision, JoltEqdocs/source/MITterms plusPR953verified2025-09-19merge (latestOct1releaseyearstillunknown), TensorZKPAug2026proceedings memory/degree scope. Remotecommit/history/diffCachemiss/InternalError preserved; no inspectedremotecommit claimed. No author gains reproduced. Rotation nextbatching/amortization->arithmetic->composition->NTT/commitments->lookup/softmax->sumcheck/GKR. All earlier fusion/compiler/small-parent/LRU/privacy/reconstruction negatives preserved.

Accepted independently verified complete private 8B proofs/passes: 0; countable tokens: 0. Device: CPU only; proof context: null; passes: 0. Steady-state and total-workload rates, startup fraction/duration, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are unmeasured. No long-context prefill, resident-model pass or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are permitted; attention grows quadratically with context and fresh masks/full coverage/privacy remain mandatory. Historicalcoldsynthetic12block125M/T512RTX4070Laptop diagnostic unchanged408.609226swall/318.22combinedrunprover/12.15inprocessverify/484107456B/independentfalse. LaterCLI lacks terminalresult after recordedreboot; stale state not liveness.

NextLOCAL: exact two-layer split-equality weighted accumulation with operation/scratch accounting and allcurrent span/zero/order controls. OWNER: isolate Eq/data allocations/build/fold/interpolation and both-witness/down/SC_SZC clocks, then guarded native/device/fresh independent complete-stack A/B. Reports are local artifacts, not delivery evidence.


## Cycle 0031 — adaptive two-layer equality accumulation (2026-10-04)

Run `20261004T130146Z-19e7c75c`, checkpoint 2026-10-04T13:20:07.356852+00:00. AGENDA, durable state/findings/all165 prior source records/latest results and project CLAUDE/status/decisions/active coordination read; original files retained under `experiments/split-eq-accumulation-20261004/snapshots/`. Early checkpoint13:03:02UTC. Research-only CPU work; no runtime/production edits, native builds, GPU, installs, Git, downloaded execution or external writes/messages. **No proving speed improvement measured.**

40 mixed fixtures and 41 exhaustive equality spans, 486 split/adaptive chunk schedules, passed 1,128 independent original-cube samples against 6,768 candidate samples, 2,178 direct-MLE final values, 18,078 counter checks and 12 controls. Final run: 10.406792 s / 18,332 KiB RSS, seed 2026100431, one pinned low-priority Core Ultra 9 185H thread; 59 s wall/CPU and 512 MiB address-space caps. Separate tuple-field direct original-cube oracle computes every expected sample/final. n0/1/2/3/5, arbitrary span/start, shuffled original indices, Rho/Flip/Fixed/multislice maps, base/full/zero/Boolean values;232recoveries/46zero fallbacks per strategy/chunk arm. No resampling or asserted-host seed. Native actual closure/IR/CFS/RNG/masks/extensions/PCS/receipts/parallel scheduling/refusal/privacy untested.

NEW tested schedule: retain native common data scan, accumulate right-weighted bracket samples per group's current outer index, flush left weight on index change and chunk drain. All original degree samples/finals retained; no pair-product polynomial contraction. For M rows/S samples/F runs, nonunit split sides takeMS+FS multiplications versusM(S+1); extraFS additions plus resets/index/decisions/scratch. Data/bracket/fold work stays. Extra accumulator logical payload11Fp2=176B per parallel part for illustrative degrees4/2/2, plus metadata; not native peak. Storage/Eq allocation removal remains a distinct earlier candidate and need not be a prerequisite for a weighting-only native adaptation.

NEW negative and refinement: n8/j0/S5/chunk1:1,280multiplies vs768baseline,1,280adds vs640. Unconditional tiny chunk1024 arm saves only96multiplies vsunit-aware whileadding1,537adds. Adaptive per-group/per-chunk guard preserves exact output and never increases counted equality multiplications versusunit-aware in tested rounds; chunk1024tiny3,614->3,434mul,5,053->5,305add. Integer/branch/locality/runtime costs remain. Keep debug explicit sample1 when adapting native S. Initial unmatched-parenthesis syntax failure and first successful unguarded experiment retained separately.

Illustrative allocation-free n23/Eq23/14/23/paddeddegrees4/2/2/K26/nativechunks1024/nonzero later recovery counts104,857,589literal or104,853,484unit-aware ->79,773,652adaptive:25,079,832multiplications removed and83,904adds added. These are equality-only operation counts (about23.919% of unit-aware weighting), not whole SC_SZC/proof/runtime/model throughput. All-explicit counts retained. Baseline measured remaining SC_SZC roughlyhalf of earlier single-block GPU-assisted proving, but no accepted8B T or equality-only clock. CeilingN/(T-Cweight+Cnew) remains unknown. Falsify any sample/final/index/support/refusal/native mask/transcript/RNG/extension/receipt/privacy mismatch or enclosing timing/peak regression.

[Experiment](experiments/split-eq-accumulation-20261004/README.md), [owner handoff](handoffs/20261004-split-eq-accumulation.md). Seam is `GroupedEqRounds::round` part/weight/sum in nativegrouped.rs99/117/122 plus SC_SZCbracket argument.rs1782; hashes/snapshots retained. No Rust patch or heavy job queued; owner/Claude integrates after exact native/independent verification gates.

Ranking:1ownerGPU SC_SZC+recurringwitness;2exact full-K split-int16down;3materiallyrefined symbolicEqstorage plus independentlyreviewable adaptiveweighting;4publicdigest/TNowner;5fresh residentfixedcontext complete-pass startup/slope/drain/verify;6NEWmatrix-packed basefield/groupedopening architecture filter;7source reconstruction/hashprefix/unconditional tinysplitdemoted. README records prerequisites/integration/addcost/exactness/privacy/soundness/falsification for each. Preserve all prior fusion/compiler/smallphase/LRU/hashprefix/reconstruction/privacy negatives.

Seven LIVE qualified sources appended: oldDao/Thaler two-layer refinement, March2026 combinedsumcheck, Jolt actual nested-fold helper/oldPR965/970Sep29**2025** and currentrepoOct3**2026** scopes, ICICLEbatchAPI/versiondiff/MIT, Joltfinalopening architecture, newlyassessed oldpacked2025/719 revisedSep14**2026**, newFlock revisedSep19**2026**. No authorperformance reproduced. Packedmatrixchallenge/MW-MLE changes PIOP/PCS/state/masks; Flockhash-circuit proving is different from computing PCShashes; ICICLEbatch headerdescribeshashchunks, notresidentmodelpasses. Remote runtimehistory/fullSHA/rawsource and PDFs errors retained. Inspected6c77775 is an abbreviated version-onlydiff, notpinnedGPUkernel; Joltcurrentmain source/documentation revisionsunverified. Rotation nextarithmetic->composition->NTT/commitments->lookup/softmax->memorytraffic->batching->sumcheck.

Accepted independently verified complete private 8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; model passes: 0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are unmeasured. No long-context prefill, resident-model pass or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are permitted; attention grows quadratically with context, with full coverage, fresh masks and decided privacy preserved.

Historical n1coldsynthetic12-block125M/T512RTX4070Laptop unchanged408.609226swall/318.22combinedrunprover/12.15inprocessverify/484107456B/independentfalse. LaterCLI still lacks terminalresult after recordedreboot; no liveness inferred. NextLOCAL: source-derived completeSC_SZC bracket/fold operationcensus byarithmetic type plusadaptive oracle with all support/helper clauses. OWNER: isolate nativephases/capacities then shared-lockdebug/release/masked/frozen/fresh independent verifier/device/full-stackA/B. Reports are local artifacts, not externalnotificationdelivery records.


## Cycle0032 — actual SC_SZC clauses and weighting ceiling (2026-10-04)

Run `20261004T140146Z-7230b465`, checkpoint 2026-10-04T14:20:21.232707+00:00. AGENDA, durable state/findings/all172 prior source records/latest results and required project documents read/snapshotted; early state14:03UTC. Research-only one-thread CPU work, no production/runtime/GPU/build/install/Git/downloaded execution/external-write/message action.

64 source-derived clause fixtures passed 576 independent original-cube samples against 1,728 candidate samples, 5,280 direct-MLE final values, 192 arbitrary-input clause values, 36 even-lookup values, 128 native declaration checks, 192 independent arithmetic-formula checks, 576 repeated counter checks and 288 adaptive guards. Ten negative controls fired. Final run: 6.607152 s / 17,664 KiB RSS; seed 2026100432, one pinned nice19 Core Ultra 9 185H CPU thread; 59 s wall/CPU and 512 MiB address-space caps. No native proof or proving speed measured.

Illustrative n23/short-Ht14/ls3/padded/release nonzero-recovery case has 30 native-style tables, 15 lookups and eight helpers. The complete zero-check bracket takes 54 Fp2 mul, 21 mul_base, 65 add and 33 sub API calls per evaluation; host groups each take two mul. Equality accumulation removes 25,079,832 mul from 2,478,829,294 counted scan+table-fold mul (1.012%), adds 83,904 Fp2 additions and 176 B logical scratch per part plus metadata. Including source-lowered base multiplications (5 per Fp2 mul, 2 per mul_base) makes the removed fraction 0.894%. Literal API count reduction is 0.281%; none of these fractions is a time ceiling or native speedup. Table construction, Eq setup, inversions, group interpolation/recovery/reduction, masks/extensions, transcript, witness, PCS, transfers, serialization and verification are excluded and remain. Data/table folds are unchanged; symbolic Eq storage is a separate candidate.

Two preserved mistakes matter: the initial all-zero IR lost its source-declared degree (fixed with zero metadata sentinels); the first passing port incorrectly batched the exempt A_E plane and used the wrong S-plane order. An independent pad.rs/layout.rs declaration audit corrected both, and added explicit exempt-E and wrong-order controls. The before-pad-plane-audit result is not native-relation evidence. The tuple-field expanded oracle is algebraically independent, but both evaluators consume a descriptor; that descriptor needs its own source-derived gate. Preserve all earlier slower fusion, compiler/small-phase, LRU, hash-prefix, reconstruction, privacy and tiny-chunk negatives.

| Rank | Hypothesis / end-to-end scope | Prerequisites, added costs and falsification |
|---|---|---|
| 1, owner | GPU SC_SZC plus recurring witness work; greatest measured remaining scope in prior single-block GPU diagnostics. | High CUDA/representation/masking integration; isolate both witness builds and native slot phases. Full degree/samples, fresh randomness, native transcript/finals/receipt and independent complete-workload verification; mismatch or enclosing regression rejects. No duplicate job. |
| 2, owner | Exact full-K split-int16 FFN-down. | Moderate/high packing, two byte products, i64 accumulation/requantization, refusal, transfer/workspace costs. Native down share unknown. Exact integer/support/native receipt parity and enclosing benefit required. |
| 3, NEW refined local | Compile lookup denominators once per proof definition: precompute alpha-cst, tag Unit/Neg/Scale rather than general mul_base for +/-1. Actual ls3 S lookup list has ten +1 and one -1 coefficient. | Moderate typed local helper/definition seam; setup/tag/dispatch costs, constant binding and term order. Potentially remove 11 mul_base and 15 accumulation adds per bracket call, subject to exact negative-coefficient rewrite. No tested/runtime gain yet. Native helper range/layout/odd-pair/mask/refusal/bytes must remain. Lost parity or enclosing regression rejects. |
| 4, tested/reranked | Symbolic Eq storage and adaptive weight accumulation. Memory storage remains useful; weighting alone is about 1% of counted padded scan/fold mul. | Moderate role-aware builder/storage/part scratch/reset work. Both pads, all clauses/helpers, explicit debug sample1, zero fallback, extension/RNG/finals/native receipt/peak gates. Any mismatch or no actual peak/enclosing benefit rejects. Keep these independent adaptations. |
| 5 | Immutable public digest/TN weight owner. | Moderate/high admission, all-consumer/clone/lease migration; import/transposes/scatter/hash and transfer costs. Setup-only current digest benefit, conditional duplicate memory. P3 identities stay private/reviewed; native identity/RNG/peak and enclosing gates. |
| 6 | Fresh resident-model complete-pass amortization. | Startup/slope, fixed context/pass count, pipeline lag/drain/independent verification and peaks required. Every recurring mask/commitment stays. Independent contexts are aggregate throughput; decode needs growing KV-state binding. Sustained recurring cost >20 ms/newly proved position falsifies >=50/s for that schedule. |
| 7, new primary lead | One-multiplication contiguous Eq-table expansion and borrowed point view, suggested by recent Plonky3 PR2305. Native eq_table still uses two mul and an MSB reverse Vec. | Low/moderate local constructor seam, extra subtraction/packing/thread policy costs. Full MSB/suffix/chunk/zero parity, allocation/clocks required. Unknown small setup share; source subtraction saving cannot be a complete-prover gain. |


Five LIVE primary records cover 2024 equality/small-field techniques, the April2026 projective paper and newly inspected September benchmark methodology, plus Plonky3 PR2305 merged September23 2026. Native web search also checked recent release/mixed-field leads. Raw runtime files, some histories, PR2050/diff/full-commit and direct release-tag fetches failed with Cache miss/InternalError; exact attempted URLs are recorded below. No network bypass, installations, foreign-code execution or author-speed reproduction. MIT main terms inspected only for Plonky3; monomial repository license remains unknown.

Native seam: `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/argument.rs:894` helper_sum, `:1788` SC_SZC bracket; `zkp-core/src/sumcheck/grouped.rs:99` part and `:162` table fold. Pad schema: private_block/pad.rs a_rule/zero_rule_a_planes and layout.rs Dom::S plane order. Native source hashes/snapshots retained; no Rust patch compiled/applied. Owner/Claude reviews and integrates, this lane never merges.

Baseline keeps data/brackets/folds/commitments; added weighting accumulators/branches/reset scratch. Complete ceilingN/(T-Cweight+Cnew) remains unmeasured; exact arithmetic, full checked relation, masks/RNG/transcript/refusal/extension/receipt/privacy/peak/enclosing gates required.

Accepted independently verified complete private 8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; model passes: 0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are unmeasured. No long-context prefill, repeated resident-model pass or decode proof occurred. The >=50 proved-token/s target remains unachieved. Larger workloads are allowed; attention grows quadratically with context, with fresh masks and full coverage/privacy preserved.

Next LOCAL: exact compiled-denominator Unit/Neg/Scale prototype at argument.rs helper_sum/definition, using this complete-clause cube oracle; include paired/odd multi-term lookups, nonzero tags, arbitrary Fp2 and zero challenges, preparation counts and branch costs. Owner first measures native Eq-weight/helper/bracket/interpolation/fold/reset phases and both witness builds/down, then shared-lock native masked/frozen/fresh independently verified complete-stack A/B. No heavy job queued.

[Experiment](experiments/sc-szc-clause-census-20261004/README.md), [handoff](handoffs/20261004-sc-szc-clause-census.md). Reports are local artifacts, not delivery records.


## Cycle0033 — compiled lookup denominators and explicit dispatch costs (2026-10-04)

Run `20261004T150146Z-0acf7ff8`, checkpoint2026-10-04T15:16:50.159385+00:00. AGENDA/current required memory/project sources and latest results pinned/read;177 prior source records inventoried, early state15:03UTC. Research-only CPU lane, no runtime/production/build/GPU/install/Git/downloaded execution/external-write/message actions.

128 complete-clause fixtures passed 1,152 independent original-cube samples against 1,152 compiled samples, 3,456 direct-MLE finals, 384 arbitrary-input full-clause values, 160 general helper cases, 720 direct denominator values, 256 native declaration checks, 128 independent clause-counter checks, 320 general counter checks, 384 per-call counter checks, 160 preparation and 160 dispatch checks, and 36 prior loop-census checks. Eleven negative controls fired. Final run: 2.179922 s / 17,984 KiB RSS; seed2026100433, one pinned nice19 Core Ultra9 185H CPU thread, 59s wall/CPU and512MiB AS caps. These are synthetic algebra/accounting results, not native proofs or proving clocks.

Baseline: helper_sum evaluates alpha minus an affine lookup expression on every bracket sample. The candidate precomputes alpha-(cst+tag) from the CURRENT proof definition, then subtracts Unit, adds Neg and subtracts Scale products in original term order. Empty/multiple terms, aliases,0/non-unit/field-negative coefficients, arbitrary Fp2 constants/challenges, odd/even helper lists and zero denominators match an independent tuple-field expanded oracle. Full fixture n0..3,ls2/3,with/without both pads,full/base/zero/Boolean values; native A_E exemption and plane order retained. Partial support configurations, honest native witnesses, private source maps, native extensions/masks/RNG/transcript/PCS/refusals remain unexecuted. Stale alpha/tag plans fail controls: these plans are definition-local and cannot be cached between proofs. No private mask/opening reuse is authorized.

Illustrative n23/short-Ht14/ls3/padded/release nonzero-recovery census:30 tables,15 lookups,8 helpers; bracket54mul/21mul_base/65add/33sub becomes54mul/10mul_base/51add/32sub. Eleven general coefficient products,14 additions and1 subtraction are removed per call. Fp2 multiplication count is unchanged. Across37,748,732 zero-check calls,415,236,052 mul_base are removed; counting5 base mul per Fp2 mul and2 per mul_base yields830,472,104 fewer of14,021,556,775 counted base multiplications (**5.923%**). Literal API total falls11.033%, including15 extra setup subtractions. None of these fractions is a runtime ceiling or speedup. Unchanged folds, other brackets and all per-sample equality products are counted. Setup/Eq construction, inversions, interpolation/recovery/reduction, masks, witness, PCS, transfers, serialization and verification are excluded.15 tag classifications,15 new setup subtractions and566,230,980 recurring coefficient dispatches remain. The existing15 cst+tag additions are shared setup, not additional work. Native enum size, allocations and compiler elimination are unmeasured.

The first passing algebra run omitted weight*bracket products from the projection denominator. Its exact source/hash/result/log/command is preserved in initial-missing-weight-count/. Final corrected loop totals independently match36 previous literal census entries; the retained initial6.096% fraction is not the final5.923% fraction. Earlier pad-order/A_E, slower fusion, compiler/small-phase, LRU, hash-prefix, reconstruction and privacy negatives remain intact. The specialization still leaves54 full-extension multiplications per zero-check bracket and adds tag dispatch; algebraic success need not improve runtime.

Expected complete ceiling remains `N/(T-Cden_removed+Cplan+Cdispatch+Calloc)` with all recurring witness/proof/serialization/drain included. T and isolated denominator time for an accepted8B workload do not exist, so no numerical end-to-end ceiling can be justified. Falsify any native sample/final/helper/index/support/pad/RNG/transcript/extension/receipt/refusal/privacy mismatch, actual peak failure or enclosing slowdown. Phase clocks and native release/compiler behavior must precede a claimed benefit.

Native seam: ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/argument.rs:894 helper_sum and:1724/1782 SC_SZC definition/bracket; existing lk_tables already includes g_u8 in l.cst. Prepare after challenge draws and before GroupPoly capture. Python patch:prepared.py Plan/PreparedTerms plus source_port.py optional den_eval callback. helper_plan.rs is a review-only Rust insertion sketch, uncompiled/unapplied; no production patch or merge. Keep original lks in cfg(test) S35 captures. Other helper_sum call sites are not covered by the full-clause fixture. Owner/Claude reviews/integrates only after native gates.

| Rank | Hypothesis / expected complete-proof impact | Prerequisites, costs, exactness/privacy and falsification |
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness work; greatest measured remaining scope in prior single-block GPU diagnostics.|High CUDA/memory/masking integration; isolate both witness builds and all SC phases; exact samples/finals/native RNG/transcript/receipt and independent complete-stack verification. Mismatch, peak failure or enclosing regression rejects.|
|2 owner|Exact full-K split-int16 FFN-down.|Moderate/high two byte products, packing/i64/requant/refusal/transfer/workspace integration; isolated native down share unknown. Exact integer/range/support/receipt/privacy and enclosing gain required.|
|3 tested local|Compiled Unit/Neg/Scale lookup denominators; removes5.923% of counted illustrated scan/fold base mul, not time.|Low/moderate helper/definition change, per-proof preparation/enum dispatch/alloc costs. Current prototype passes; native frozen bytes/masks/extensions/refusal/privacy/RNG gate and isolated/enclosing clocks pending. Compiler already eliminating work or no enclosing gain demotes.|
|4 NEW refined local next|Can row-local denominator origin/delta be stepped through integer samples0..4, rather than rebuilding15 affine forms on every call?|Moderate grouped part/GroupPoly adapter, about480B logical origin/delta payload for15 lookups per part, stepping/reset/extra memory and setup arithmetic. Must preserve skipped sample1/debug explicit1/zero-factor fallback, ragged chunks and all paired/odd/multi-term clauses. Any sample/final mismatch or costs exceeding removed scalar work rejects.|
|5|Symbolic Eq storage, with weighting adapted separately.|Moderate role-aware builder/storage/part scratch migration, memory benefit separate from ~1% prior weighting count. Full short-span/support/index/zero/native masking/peak and enclosing gates.|
|6|Immutable public digest/TN owner.|Moderate/high admission/all-consumer/clone/lease and transpose/scatter/hash costs; digest is setup-only in current stages. P3 review required; no private opening reuse. Stale identity, byte mismatch or no enclosing benefit rejects.|
|7|Fresh fixed-context resident complete-pass workload.|Measure startup/slope, pass count/context, proof lag/drain, serialization and independent verification/peaks with fresh masks. Complete recurring cost>20ms/newly proved position falsifies50/s for that schedule. PrefillT² and growing-context authenticated decode stay separate.|
|8 architecture|Newly assessed Fold-DCS/SWIRL domain/round composition.|High PIOP/PCS/transcript/mask/privacy/whole-proof soundness migration cost; fewer rounds/helpers alone supplies no speed ceiling. Deferred until costed relation-preserving comparison; no implementation permission inferred.|


LIVE search covered current lookup/GKR/sumcheck implementations and releases, with five qualified source records: [Plonky3 lookup/link planning](https://github.com/Plonky3/Plonky3/pull/1968), [LogUp zero-denominator accounting](https://docs.rs/p3-security/latest/p3_security/logup/index.html), newly assessed older [Fold-DCS](https://arxiv.org/abs/2504.00693), newly assessed [SWIRL](https://openvm.dev/swirl.pdf), and [Plonky3 releases](https://github.com/Plonky3/Plonky3/releases). Current main MIT terms inspected for Plonky3/OpenVM only; no runtime commit diff inspected. Primary package/runtime/commit fetches returned Internal Error/Cache miss; exact URLs in search-log.json. Direct PDF dates and search snippets differ for SWIRL; p3-security/latest version differs from its search snippet. Unknown publication/update dates remain null; no network bypass or author-performance reproduction.

Accepted independently verified complete private8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; model passes:0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag and pipeline drain are unmeasured. No long-context prefill, resident-model pass or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are permitted; attention work grows quadratically with context, with fresh masks and full privacy/coverage preserved.

Next LOCAL: row-local affine denominator stepping against the same complete-clause original-cube oracle, comparing cold row setup, skipped/debug sample1, zero-factor fallback and ragged/reset costs to the tested plan. OWNER: native helper/bracket/fold/weight/interpolation and both witness/down phase clocks, then shared-lock masked/frozen/fresh independent-verifier complete-stack A/B. No heavy job is queued.

[Experiment](experiments/compiled-lookup-denominators-20261004/README.md) · [Owner handoff](handoffs/20261004-compiled-lookup-denominators.md). Rotation next:memory traffic/batching -> arithmetic -> composition -> GPU NTT/commitments -> lookup/softmax -> sumcheck/GKR. Preserve all prior findings; reports are local artifacts, not delivery records.


## Cycle0034 — row-local denominators pass algebra but worsen API count (2026-10-04)

Run `20261004T185034Z-0cf2c35e`, checkpoint2026-10-04T19:07:51.986983+00:00. AGENDA, durable state/findings/all182 prior source records/latest experiment results and required project memory read/snapshotted; early STATE checkpoint saved before the experiment. Research-only writes excluding runtime. One-thread bounded CPU work; no native build/GPU/install/Git/production/foreign-code execution/external write/message action.

128 source-derived complete SC_SZC fixtures/768 release/debug chunk schedules pass1,152 independent original-cube samples against6,912 candidate samples,20,736 direct-MLE finals,5,376 row-counter checks,48 previous-baseline census entries,160 general lookup rows and3,798 direct denominators. Eleven algebra/lifecycle negative controls fire.1,098 group recoveries and630 zero-factor fallbacks occurred. Final11.575187s/17,332KiB RSS, seed2026100434, pinned nice19 Core Ultra9 185H thread;59s wall/CPU/512MiB AS caps. n0..3,ls2/3,padded/unpadded,odd/even helpers,full/base/zero/Boolean values,chunks1/3/7,explicit-debug/release sample1; general empty/multiple/alias/zero/negative/non-unit terms. Zero denominators checked only algebraically. Native honest witnesses, extensions, mask/RNG/transcript/PCS/refusal/privacy parity unexecuted.

Baseline cycle0033 compiled Unit/Neg/Scale plan reevaluates affine denominators per bracket. Candidate prepares CURRENT-row origin and slope, advancing over EVERY sample including skipped1 and resetting per row/round/chunk. It preserves all helper products, clauses, padded domains and source indices; no masks or relation weakened. Differential source patch:stepping.py RowPlan/SteppedTerms and row_rounds.py hooks. Shared copied scheduler is qualified by the separate tuple-field expanded original-cube oracle. Initial passing result/source retained; final run added the48 cross-cycle count checks.

NEW negative: illustrative n23/ls3/padded/release removes83,886,072 mul_base but adds482,344,902 Fp2 adds, removes293,601,252 subs and leaves2,478,833,399 full multiplies unchanged. Lowered base-mul count falls1.271860%; total API operations INCREASE1.324854%. Debug explicitly sampling1 still increasesAPI0.292969%; unpadded n20/ls2 release increases2.425874%. Setup is two affine dispatch passes per row/round,480B logical origin/slope per part,566,230,980 logical reads/754,974,630 writes in the illustrated release census. Accesses may be registers/cache, not measured DRAM. Native allocation/compiler/occupancy/spill/phase costs unknown. Row stepping demoted; reduced multiplication count alone does not support integration.

Expected complete ceilingN/(T-Cold_den+Crow_setup+Cstep+Cscratch+Cdispatch) unmeasured because accepted8B T/denominator clocks are missing. Tables/interpolation/native Eq/data folds and weight products are charged unchanged; setupEqs/inverses/recovery/reduction/masks/witness/PCS/transfers/serialization/verification excluded. Falsify any complete original/native sample/final/helper/order/support/pad/refusal/RNG/transcript/extension/receipt/privacy mismatch, memory failure or enclosing regression. No runtime ceiling follows from1.27% counted arithmetic.

Ranked queue:1 owner GPU SC_SZC+recurring witness (largest measured remaining single-block scope; high CUDA/memory/native privacy integration);2 owner exact full-K split-int16 down (packing/i64/requant/workspace and isolated share unknown);3 compiled denominators pending native compiler/phase gates (low/moderate plan/dispatch costs);4 NEW exact delayed modular reduction in terminal Fp2 weighted sums (prove >u128 accumulation bounds and charge wider carries/flush/reduction/scratch before any speed claim);5 symbolic Eq/public causal-mask descriptors (memory benefit with full index/support/terminal gates, causal predicate includes padded heads);6 fresh fixed-context resident complete-pass startup/slope/lag/drain/verify sweep (20ms recurring/new position falsifies50/s for that schedule);7 row stepping demoted on API/scratch tradeoff;8 Vega/binary-field/SWIRL/Fold-DCS architecture filter (high PCS/PIOP/state/privacy/whole-proof soundness migration). Detailed prerequisites/costs/exactness/falsification in experiment README. Previous fusion/compiler/small-phase/LRU/hash-prefix/reconstruction/privacy negatives preserved.

Five LIVE qualified records appended: new older Vega paper received2025-11-14/revised2026-09-05; Vega MIT/history/conformance/July15 bounds; SumCATS setup regression refresh; NVIDIA2026-07-15 binary-field scope; June15 matched-hardware locality. Vega's cached July15 history is not verified currentHEAD; Feb25 delayed-reduction commit only exposed, fetch failed. No remote commit diff inspected. Current main complete MIT license inspected for Vega; SumCATS nested README MIT excerpt does not establish additions/third-party scope. API/code/license/commit Cache miss/Internal Error URLs/actions retained. No author performance reproduced or downloaded code executed; binary-field rates are not Goldilocks2 or private full-model rates. Vega rerandomizable preprocessing adds no mask/opening reuse permission.

Native seam: owner's argument.rs894/1724/1782 helper/definition/bracket; grouped.rs86/110 part/row/sample loops; GroupPoly at argument.rs76 immutableFn+Send+Sync. Any row adapter must create scratch separately per part; shared mutable closure state is unsuitable. No production patch or merge. [Owner disposition](handoffs/20261004-affine-denominator-stepping.md) · [experiment](experiments/affine-denominator-stepping-20261004/README.md).

Accepted independently verified complete private8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; passes:0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag and pipeline drain are unmeasured. No long-context prefill, resident-model passes or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are allowed; attention can grow quadratically with context. Fresh masks, privacy and full coverage remain required.

Historical synthetic12block125M/T512 RTX4070Laptop diagnostic remains408.609226swall/318.22combinedrunprover/12.15inprocessverify/484107456B/fresh independentfalse. LaterCLI lacks terminal result after recordedreboot; stale state is not liveness. No new model-scale/GPU clock. Next LOCAL: chunked wide Fp2 dot-product accumulation against independent integer-mod-p reference; prove maximum-value batch bounds and test carry/overflow/zero/ragged/flush failures, charging carry/reduction/scratch costs. OWNER: isolate native denominator/helper/bracket/weight/fold/recovery and both witness/down clocks, then shared-lock masked/frozen/fresh independent-verifier complete-stack A/B. No heavy job is queued.

Rotation next:arithmetic/reduction -> proof composition -> GPU NTT/commitments -> lookup/softmax -> sumcheck/GKR -> memory traffic/batching. Reports saved locally do not establish delivery.


## Cycle0035 — recovered exact wide-accumulation result (reported 2026-10-12)

Original run `20261004T195034Z-13077bdd` completed its retained CPU experiment
2026-10-04T19:59:37.839053Z but left STATE in progress and did not write its
final FINDINGS/PROGRESS/handoff. Cycle0036 recovered that evidence; all ten
result-recorded Python source hashes still match. No prior experiment was
restarted or treated as a native proof. Original result: pass,seed2026100435,
6.002594s,20,264KiB RSS,one nice19 Core Ultra9 185H thread,59s/512MiB caps.
125 dot fixtures/625 schedules,64 complete source-derived clause fixtures/320
schedules,576 original-cube/2,880 candidate samples,8,640 direct-MLE finals,
2,059 u128 and2,056 u192 reducer cases and16 controls passed.

Three u192 sums retain ac,bd,ad+bc. Two maximal canonical products overflow
u128; chunk1024 cross sums need139bits. Illustrated n23/ls3/padded/release
nonzero-recovery removes398,458,840-545,272 counted reductions,only3.016534%
of13,191,084,671 scan/fold reduction calls,while adding1,275,068,288 limb adds,
318,767,072 carry chains,233,688 reducer limb products,and792B logical extra
per-part scratch. Carry/scratch/compiler costs unmeasured. The competing
five-reduction fused MAC keeps all reductions but replaces four modular
base additions by four bounded u128 additions per term. Neither is a native
speed result. Wide accumulation demoted pending enclosing cost evidence.

Six retained LIVE source assessments recovered into sources.jsonl with original
2026-10-04 access dates and explicit Oct12 recovery provenance. They include
Plonky2 arithmetic,gnark October2 release,EPFL sumcheck,delayed-reduction papers
and a snippet-only unverified batching claim. Recovery is not new web access.
No accepted complete private8B proofs/passes/tokens; clocks unmeasured. Current
cycle tests a stronger four-reduction,canonical-only alternative. Original
sources/results/errors remain intact, including initial-accounting-key-error/.


## Cycle0036 — four-reduction Fp2 arithmetic and CUDA carry model (2026-10-12)

Run `20261012T172555Z-e8207bdf`, checkpoint2026-10-12T17:44:00.877931+00:00. AGENDA,current target,durable
state/findings/source history/latest results and project memory read/scanned;
startup snapshots and early STATE saved. Only research files written,excluding
runtime. No native build,GPU,install,Git,production modification,foreign code
execution or external write/message. Current records preserve interrupted
cycle0035 evidence and its six source assessments with original access dates.

**Exact synthetic result; no proving speed improvement measured.** Final
3.602309s/17,736KiB RSS,seed2026101236,one pinned
nice19 Intel Core Ultra9 185H thread;59s wall/CPU,512MiB AS,64MiB estimated.
54,848 arbitrary-accumulator MACs and products match unbounded integer-modular
convolution and the literal native five-reduction model;54,848 CUDA lo/hi MAC
emulations also match.2,060 reducer cases,2,09732-bit-schoolbook products,
4 carry checks,2,048 extension-law fixtures and256 ragged partitions pass.
64 source-derived complete SC_SZC clause fixtures/256 release/debug schedules
pass576 independent original-cube samples against2,304 candidate samples and
6,912 direct-MLE finals;368 recoveries,208 zero-factor fallbacks.19 negative
controls fire. Scope:n0..3,ls2/3,padded/unpadded,full/base/zero/Boolean,odd/even
helpers,short equality spans;primitive lengths0..1025,partitions1/3/7/1024.
Native honest witness/private maps/support,masked extensions,RNG/transcript,
refusals,PCS/receipt byte parity and device execution are untested. Initial
passing Rust-model-only run/source retained; repeat justified by CUDA/carry
coverage,not an attempt to improve timing.

Baseline:canonical Goldilocks2,u²=7,FP2 product has5 reduce128 calls and2
modular base adds;MAC adds2 more. Candidate reduces bd and ad first,then
ac+7*reduced_bd+acc0 and bc+reduced_ad+acc1. Bounds(p-1)²+8(p-1) and
(p-1)²+2(p-1) fitu128. Four reductions replace five;4 variable/1 constant
products stay. Product alone replaces2 modular adds with2 u128 adds;MAC
replaces4 with4. No persistent wide sums or extra arrays. Native canonical
precondition remains essential:public rawFp limbs are not self-validating.
Prototype refusals for invalid limbs do not establish native admission parity.
CUDA macro source avoids__int128;independent schoolbook lo/hi model preserves
low carries and the high bits of7bd. Draft CUDA helper is uncompiled and its
added MAC has no caller.

Illustrative n23/ls3/padded/release nonzero-recovery,baselineafter cycle0033
compiled denominator plan/before cycle0034 stepping:13,191,084,671 counted
scan/fold reductions. Weighted-only removes79,691,768(0.604134%);global full
FP2 products remove2,478,833,399(18.791733%). Weighted products are INCLUDED
in global count;fractions must not be added. Combined removes5,117,050,334
modular base additions and adds equal u128 additions;mul_base remains at2
reductions. These are literal call counts,not time/machine multiply reductions.
Constant7 reduction may already be simplified byLLVM/NVRTC;carry/dependency,
register/occupancy/spill effects are unknown. Setup/Eq,inverse,interpolation,
recovery,mask extension,transcript,witness,PCS,transfer,serialization and
verification remain outside census. Global patch has much greater arithmetic
scope than weighted-only,but shared-field regression cost is greater too.

Complete ceiling N/(T-Caffected+Cnew),ideal upper boundN/(T-Caffected),cannot
be numeric without accepted8B total/affected clocks. Falsify any canonical
result,sample/final,mask/extension,RNG/transcript,receipt/refusal/privacy mismatch,
canonical-callsite premise failure,peak/occupancy failure,or no enclosing gain.
Prior row-stepping API inflation,slower native fusion,compiler/small-phase,
LRU/hash-prefix/reconstruction/padding/privacy negatives all remain intact.

Current bottleneck evidence still historical:GPU-assisted synthetic one-block
125M/T512 b2 on RTX4070Laptop hasSC_SZC7.794s of16.864sprove,external witness
5.77s,serialization0.028s,in-process byte verify0.82s and27.523873s whole-test
wall;startup not isolated,not a complete model or private8B result. Pin includes
report/log. Prior12block diagnostic408.609226swall/318.22combinedrun-prover/
12.15in-processverify/484,107,456B/fresh independentfalse stays historical.
CLI report has no terminal result after reboot;state=running is not liveness.
No new complete-proof phase or GPU clock was obtained.

| Rank | Hypothesis / expected end-to-end scope | Prerequisites, added costs and falsification |
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness;largest measured remaining scope.|High CUDA/memory/masking cost;separate both witness builds and SC phases;native samples/terminal/extension/transcript/refusal/receipt/privacy parity and independent complete verification. Enclosing regression or peak failure rejects.|
|2 owner|Exact full-K split-int16FFN down.|Packing,two products,i64 accumulation/requant,workspace/transfer;isolated native down share unknown. Exact integer/range/support/private/frozen gates and enclosing gain needed.|
|3 NEW refined/tested|Canonical residue+raw-product fusion acrossFP2mul;four reductions without wide persistent sums.|Low/moderate implementation,wide shared-field review. Four-reduction model passes;LLVM constant folding/carries/dependency/register effects and native masks/bytes unknown. No native enclosing gain demotes. Weighted-only0.6% reduction scope is secondary.|
|4 tested|Compiled Unit/Neg/Scale denominators.|Per-proof preparation/tag dispatch/allocation;prior5.923%counted multiplication saving,not time. Native compiler/phase/receipt/privacy gates needed;stale plan or no enclosing gain rejects.|
|5 local next|Symbolic public padded causal-mask descriptor,charging its folded MLE cost.|Moderate typed builder/part-index seam;remove explicit plane/folds,addpredicate/evaluation scratch. Preserve every pad/head/future-score constraint and native final index. Any boundary/MLE/sample mismatch or extra-cost dominance rejects.|
|6 owner|Fresh fixed-context resident complete-pass startup/slope/drain sweep.|Measure context,passes,concurrency,proof lag/bytes/serialization/independentverify andpeak with fresh masks. Recurring>20ms/newposition rejects50/sfor that schedule;prefillT²/decodeprivate state stay separate.|
|7 architecture refinement|Shared operator composition with explicitly bounded terminal openings and fresh masks.|New2017/October2026 sources prompt query/degree/history accounting. High PCS/PIOP/Fiat-Shamir/privacy migration;public sequences/open evaluations and reusedweightroots are not P1 permission. Missing joint privacy or complete-cost gain rejects.|
|8 demoted|Wide accumulation and row stepping.|Retain carry/scratch/API cost negatives;lower reduction count alone is insufficient.|

Four current LIVE primary records saved:Plonky2 MAC/representation andMIT terms;
gnark-cryptoOctober2 release pinned commit550a513d798df79d8324697332e085498285bb63
(version/CHANGELOG/CI diff,not arithmetic);newOctober6 zkLLMPoT;newly assessed
olderApril7 2017 ZK sumcheck. Dates,exactURLs,licenses andcommit scope recorded.
Tag/main gnarkLICENSE/e2.go and old-org URLs failedCache miss;not bypassed.
zkLLMPoT usespublic audit sequences andsyntheticA10040GB operator aggregates,
with nonlinear interpolation/opening fits;no full-private8B rate inferred.
No author performance reproduced. Shared root/opening or blinding reuse remains
unauthorized. Full webpage text omitted from logs;requests/URLs/blockers retained.

Native seams:Sonnetread-onlyzkp-core/field.rs:158,grouped.rs:110,CUDAkernels.cu:63.
Alternative unappliedRust/CUDA patches andcandidate copies are source-pinned.
[Experiment](experiments/fp2-fused-mac-20261012/README.md) ·
[Owner handoff](handoffs/20261012-fp2-four-reduction.md). No production patch/merge.

Accepted independently verified complete private8B proofs/passes**0**;countable
tokens**0**. DeviceCPUonly;proof contextnull;modelpasses0. Steady-state and
whole-workloadrates,startup duration/fraction,witness/proof/serialization/
independent-verification,latency/lag/drain are unmeasured. No long-contextprefill,
resident-model pass ordecodeproof occurred. >=50provedtokens/sremainsunachieved.
Larger workloads allowed;context growth increasesattentionquadratically;fresh
masks,fullprivacy/coverage andindependentcompleteverificationremainrequired.

NextLOCAL:source-derived paddedcausal-mask descriptor andexactfoldedMLE against
explicitoriginalcube,includingpaddedheads,raggedTk,offdomainpoints,tampering and
predicate/scratch costs. OWNER:canonicalcaller/optimizedassembly audit;native
field/frozen/masked/extension/refusal/deviceconformance then guarded complete
slot/blockA/B. No heavyjobqueued. Rotation:proofcomposition -> GPU NTT/commitments
-> lookup/softmax -> sumcheck/GKR -> memorytraffic/batching -> arithmetic.
Reports saved locally are not external delivery evidence.
