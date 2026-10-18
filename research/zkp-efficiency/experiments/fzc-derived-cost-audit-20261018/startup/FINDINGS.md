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


## Cycle 0037 — public causal-mask descriptor (2026-10-12)

Run `20261012T182555Z-4bc569b3`; completed within 20 minutes. AGENDA/current target, durable notes/source history/latest results and project memory read/scanned; startup snapshots and early STATE retained. Only research writes excluding runtime. No native build, GPU, installation, Git, production change, downloaded-code execution or external write/message.

**A compact public-mask candidate passed synthetic differential checks; no native proving speed gain was measured.** Final 0.960794 s / 19,804 KiB RSS, seed2026101237, one pinned nice19 Core Ultra 9 185H thread; 59-second wall/CPU, 512-MiB address-space caps and 32-MiB estimated memory. Thirty-six fixtures cover leading axes0..3 and token bits0..4 with full/base/Boolean/zero Fp2. Results:13,920 endpoints,48,720 degree0..6 sample values,188 folded states,1,316 mask-sensitive point evaluations,224 complete tail sums of those contributions,7,952 independent original-cube MLEs,36 terminals,72 arbitrary off-domain comparator checks,144 public zero-extension terminals and19 negative/refusal controls. Two intermediate passes and all matching reconstructed code pins retained; later runs add coverage and correctly lift supp_Ht over j. This is not complete native SC_SZC, an honest witness, grouped-head/P3 support validation, masked-transcript/receipt evidence or a privacy proof.

The native mask at argument.rs:1013 is `j<=t` over PADDED T×T for every leading head/lift slot. Filtering true token bounds or padded heads changes the relation; separate support tables enforce padding. The descriptor keeps two prefix values per bound j prefix, interpolates once per prefix during t binding, then folds one T-entry vector over j. Its verifier recurrence includes equality. All public `(1-e)` selectors remain. The SH_S=6 score host remains independent of the causal mask, including future pairs; a control detects the relation change caused by gating it. No rectangular Tk/decode relation is implemented.

The baseline has one explicit N-word Fp2 mask plane per SC_RS/SC_SZC slot, N-1 dense folds, and original capacity retained by Vec::truncate. The candidate removes mask construction and dense folds, adds2(T-1) interpolation calls and O(T) state. Conditional T512/32-leading-slot counts:128 MiB explicit payload versus24 KiB compact temporary bound/8 KiB t-end payload;8,388,607 ->1,022 interpolations. Added proposed native work is2N-2T=16,776,192 predicate readers, O(T) preparation/drop, typed total/round/census/final adapters and O(log T) verifier recurrence. Common sample interpolation and other tables, private/support/Eq scans/folds, witness, per-proof randomness/commitments/PCS/transfers remain. These are counts, not measured parent peaks or speed. The two sequential slots' peak savings cannot be added. Longer contexts still increase attention quadratically.

The complete ceiling is `Npositions/(Ttotal-Cmask_build_fold+Cnew)`, with ideal upper bound `Npositions/(Ttotal-Cmask_build_fold)`. No numeric accepted8B ceiling exists because total and isolated affected clocks are absent. The historical shared synthetic125M one-block/T512 RTX4070Laptop b2 profile records SC_RS0.600 s and SC_SZC7.794 s within16.864 s proving,5.77 s external witness,0.028 s serialization,0.82 s in-process byte verification and27.523873 s whole-test wall. Removing both ENTIRE prover slots bounds savings at8.394 s on that diagnostic; the mask-only saving is a subset, not an8B rate. Verifier slots0.191/0.274 s are reported separately. Startup is not isolated. The historical synthetic12-block diagnostic remains408.609226 s wall/318.22 s combined run-prover/12.15 s in-process verification/484,107,456 B, without fresh independent verification. The interrupted CLI has no terminal result; state=running is not liveness.

|Rank|Hypothesis and end-to-end scope|Prerequisites, added costs and falsification|
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness; largest measured remaining block scope.|High CUDA/memory/privacy integration; isolate both witness andSC phases. Require native samples/refusals/masked transcript/bytes and independently verified complete A/B. Enclosing or peak regression rejects.|
|2 owner|Exact full-K split-int16 down.|Packing,two products,i64/requant/workspace; isolated down clock unknown. Require native range/calibration/device parity and enclosing gain.|
|3 tested|Four-reduction canonical Fp2.|Prior18.79% counted reduction scope is not time. Canonical callers,LLVM constant folding,carry/register/occupancy and native masked/frozen bytes remain open; no enclosing gain demotes.|
|4 NEW refined/tested|Two-state public causal-mask descriptor.|Moderate typed reader/total/terminal seam; O(T) state versus O(H*T²) plane, with integer predicates and allocation/dispatch. Any MLE/index/pad/future/selector/refusal/privacy/byte mismatch or peak/enclosing regression rejects.|
|5 tested|Compiled denominators.|Setup/tag/constant binding and native compiler/phase gates; prior5.923% counted multiply saving is not runtime. Stale plan or enclosing regression rejects.|
|6 owner|Fresh fixed-context resident complete-pass sweep.|Measure startup/slope/context/passes/concurrency/lag/drain/bytes/peak/independent verification with fresh masks. Recurring>20ms/new position rejects50/s for that schedule; prefill anddecode remain separate.|
|7 architecture|Structured/streaming/GPU NTT/PCS.|Qingming CUDA/cuButterfly need exact modulus,direction,layout,pad,transfer and cost pricing. LatticeJolt needs field/PCS/ZK/state/joint-privacy review; author kernel/cycle rates are not complete-model rates.|

Six LIVE primary records appended;203 total: newly assessed older Jolt comparator MLE(received2023-08-10; primary PDF/official-slide indexed formula, direct PDF403), Qingming CUDA(Jul7 2026 cached history, not liveHEAD; unpinned source/README contract mismatch), cuButterflyv0.9(undated framework/V100 scope; release date unverified), official Sep9 2026 LatticeJolt release/privacy filter, Apr3 2025 small-space prefix/suffix refresh, and Sep1 2026 author sumcheck explanation. Exact URLs, dates and qualified licenses are in source-records.json; search/open blockers retained. No commit diff inspected; exposed short hashes are not inspected commits. No author performance reproduced. LICENSE/history/capability/PDF fetch failures were not bypassed. One legacy source-schema append KeyError is preserved; optional-id correction appended six records once without changing older records.

Native seams:argument.rs Tab66/build338/run447/B::public716/mask1013/SC_RS1270/SC_SZC1709/verify613; grouped.rs99/149/175. GroupPoly Fn+Send+Sync lacks row index, so exact scalar reading belongs in the round adapter: immutable during part scans, bound once after reduction. Preserve explicit cube length, original table/final order, generic private total and public zero extensions. Dense placeholders alone are wrong. [Experiment and uncompiled Rust sketch](experiments/causal-mask-descriptor-20261012/README.md) · [Owner handoff](handoffs/20261012-causal-mask-descriptor.md). No production patch/merge. Native allocation/compiler/device/mask/RNG/transcript/refusal/receipt/privacy gates remain owed.

Accepted independently verified complete private8B proofs/passes: **0**; countable tokens: **0**. CPU only; proof context:null; model passes:0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification, latency/lag/drain clocks are unmeasured. No long-context prefill,resident-model pass ordecode proof. >=50 proved tokens/s remains unachieved; larger workloads allowed, with fresh masks/full privacy/coverage/independent verification required.

Next LOCAL: symbolic supp_Ht/supp_S descriptors with exact grouped-head/P3 mapping against original-cube MLE. Include negative products of separately interpolated predicates, terminal/extension values and predicate/scratch costs. OWNER: verifier descriptor frozen/terminal/refusal byte gates, then Closure/Grouped/total/census adapters, isolated mask clocks and shared-lock complete-slot/block A/B. No heavy job queued. Rotation: GPU NTT/commitments -> lookup/softmax -> sumcheck/GKR -> memory traffic/batching -> arithmetic -> proof composition. Prior slower fusion,row-step/API,compiler/small-parent,hash-prefix/reconstruction/padding/privacy negatives preserved. Saved reports do not establish external delivery.


## Cycle 0038 — compact public support descriptors (2026-10-12)

Run `20261012T192555Z-2488fec6`; checkpoint 2026-10-12T19:38:35.250893+00:00, within20minutes. AGENDA/current target, durable notes/source history/latest results and project CLAUDE/MVP/decisions/active coordination read/scanned; early STATE and startup snapshots retained. Only research writes excluding runtime. No GPU/native build/install/Git/production edit/downloaded-code execution/external write or message.

**A constant-state public support candidate passed synthetic differential checks; no native proving speed gain was measured.** Final1.586442s/18,332KiB RSS, seed2026101238, one pinned nice19 CoreUltra9 185H thread, Python3.10.12;59-second wall/CPU and512-MiB address-space caps,32-MiB estimated memory.84fixtures,113,792endpoints,398,272degree0..6samples,568folded states,2,009independent original-cube MLEs,84factored MLEs/terminals,336public extension values,70support-sensitive complete tail sums and105independent sensitive points pass;21controls. All nine domain layouts, arbitrary Fp2/base/Boolean/zero challenges, ragged bounds, grouped head padding, prefix tiling and D/F/L/Tab row lift covered. Native toy/rung PUBLIC tables only; small synthetic geometries not admitted profiles. Not complete native SC_SZC/honest witness/transcript/receipt/device/privacy evidence.

The two-state threshold recurrence replaces `[x<limit]` tables while preserving their exact MLE. With a limit bit1 bind lo=hi+r*(lo-hi), else hi=lo+(1-r)*(hi-lo); at axis end take lo. Completed factors are absorbed into the next hi, so Boolean endpoint readers use integer predicates and scalar selection with no per-read field MAC. Only disjoint coordinate factors compose this way. Native pad.rs already constructs some closed forms but materializes vectors; this changes representation, not the relation. Low head-slot bits encode each KV group's true prefix. Ht is tiled on LEADING coordinates and constant over all padded j. S cannot replace Ht for host/pad-zero groups. Lifted byte table VALUES repeat but SUPPORT zeros the extra leading positions. Native Q/Kv/S row-lift refusals are retained; ruling P-3 row lift is distinct from P3 private-weight scope. Frozen profile/table/challenge/degree/extension gates remain owner obligations.

The first run failed a negative control: the same challenge on every coordinate gave equal evaluations for two different grouped/flat head tables because changed cells had equal bit weight. No candidate mismatch was found. Its complete matching source/log/command/completion is retained under initial-negative-point-collision; distinct coordinate challenges correct the test and final pass. Other controls catch wrong head prefix, trailing coarse tiling, substituting S for Ht, row-lift repetition, stale/mutated values, lost extension limbs, overlap/index/shape/tile/native-lift refusals. Merging causal/support Boolean tables changes offdomain native multiplication: at t2/j3 the separate product is8 versus2 for the merged MLE. Causal/support remain separate; no whole-row, LogUp, private-table or future-score skipping is authorized.

At pinned native m125 head geometry12Q/4KV/16padded andT512, SC_SZC's two support tables are128MiB logical Fp2 payload and8,388,606dense lerps. Descriptor uses four lerps total, six retained Fp2 fields and two axis records combined. Added schedule upper bound16,777,212integer comparisons/endpoint reads, plus construction/shape validation, typed driver/total/census/final/extension adapters, branch/dispatch/metadata costs and O(n) verifier evaluation. General ragged shapes can need three/two comparisons per S/Ht reader. Six transient field words per descriptor is a logical working bound, not measured native allocation. Original capacity/parent peaks/compiler/GPU costs are unknown. Common cur/dif/sample arithmetic and other private/Eq/causal scans/folds, witness, fresh per-proof randomness/commitments/PCS/transfers/serialization remain. Sequential RS peak savings cannot be added. Larger-context counts are unadmitted arithmetic illustrations and attention still grows quadratically. Clock-table cube includes extension; it must not double initial data-table census.

Complete ceiling positions/(Ttotal-Csupport_build_fold_eval+Cnew), ideal upper bound positions/(Ttotal-Csupport_build_fold_eval). No numeric accepted8B ceiling exists: total and isolated affected clocks absent. Raw b2 log hash verified. Historical shared synthetic one-blockT512 RTX4070Laptop/two-thread profile remains externalwitness5.77s/prove16.864s/serialization0.028s/in-process byteverify0.82s/enclosingtest27.523873s;SC_RS0.600s/SC_SZC7.794s. Deleting BOTH WHOLE slots bounds savings at8.394s on that diagnostic; support is only a subset, not an8B rate. Verifier slots0.191/0.274s separate. Startup not isolated; recurring native witness/commit preparation also remains. Historical synthetic12block408.609226s wall/318.22combinedrun-prover/12.15in-processverify/484,107,456B lacks fresh independentverification. Reboot-interrupted CLI has no terminal result; state=running is not liveness.

|Rank|Hypothesis / end-to-end scope|Prerequisites, added cost and falsification|
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness; largest measured remaining block share.|High CUDA/memory/mask integration. Isolate both witness clocks, brackets/folds/transfers. Native samples/transcript/refusals/bytes/privacy and independent complete A/B required; enclosing/peak regression rejects.|
|2 owner|Exact full-K split-int16 down.|Packing/two products/i64/requant/workspace; isolated down share unknown. Exact range/calibration/device gates and complete wall gain required.|
|3 tested|Global four-reduction canonical Fp2.|Prior18.79% counted reduction scope is not time. Canonical callers, compiler/carry/register behavior and native masked/frozen bytes open; no enclosing gain demotes.|
|4 NEW refined/tested|Public support descriptors alongside separate causal descriptor.|Remove quadratic public S/Ht vectors and dense folds; constant field state plus integer predicates. Moderate typed driver/total/terminal/extension integration. Any MLE/map/profile/pad/host/future/extension/refusal/byte/privacy mismatch, peak regression or added-cost dominance rejects.|
|5 tested|Compiled Unit/Neg/Scale denominators.|Preparation/tag binding/native compiler costs; prior5.923% counted multiply saving is not time. Stale plan or enclosing regression rejects.|
|6 owner|Fresh fixed-context resident complete-pass startup/slope/lag/drain sweep.|Measure workload/context/passes/bytes/peak/independent verification, fresh masks. Recurring>20ms/new position rejects50/s for that schedule; long prefill T² and authenticated decode remain separate.|
|7 architecture, refined filter|Structured PCS/GPU NTT/composition; projective basis demoted pending native affected shares.|Field/layout/query/hiding/state/soundness migration and extra sumchecks. New enclosing-WHIR negative prevents adopting binding-only claims; original-cube final oracle required.|

Six LIVE primary records appended;209total. New [projective-WHIR author negative](https://github.com/Plonky3/Plonky3/pull/1949) reports faster binding with enclosing loss/parity;[issue1890](https://github.com/Plonky3/Plonky3/issues/1890) closesSep4. This is author evidence, not reproduced here; native64bit/Fp2 affected shares differ. Newly assessed older [JaggedPCS](https://eprint.iacr.org/2025/917) receivedMay21 2025/revisedApr13 2026 gives a structured public-indexing architecture lead with extra reduction/PCS/privacy obligations; metadata/abstract inspected, PDF403 prevents a full audit. [Oct8 resettable-NIZK revision](https://eprint.iacr.org/2026/1036) is a fresh-randomness filter for resident proving, not an adopted compiler. [Plonky3v0.8.0](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0) Sep23 is pinned by inspected version/CHANGELOG diff commit a21e3ed42905040ad49c519e402f018381c12d0c; no arithmetic diff. Jolt MLE traits refreshed with undated doc qualification; JoltMIT terms and Plonky3Apache terms plus MIT-or-Apache manifest inspected. April17 projective paper refreshed alongside the negative. No author performance reproduced. Commit InternalError/Cachemiss andPDF403 blockers retained; exactURLs/date/license/commit scopes in source-records.json, no source-page text retained.

Actual seams: private_block/argument.rs Tab68/B::supp810/tile_rep835/build338/run447/verify613, pad.rs48/132/335,shape.rs257/883,witness.rs211 and grouped.rs99/149/175. [Evidence and uncompiled unapplied Rust sketch](experiments/support-descriptor-20261012/README.md) · [Owner handoff](handoffs/20261012-support-descriptor.md). Typed readers require explicit original cube size/table order, BOTH closure/grouped rounds, generic private total, diagnostics/finals and public extensions. Descriptor is immutable during part scans, bound once after reduction. Empty dense placeholders are invalid. No production patch/merge or native-gate claim. Preserve slower native fusion, row-step/API inflation, small-phase/compiler/hash-prefix/LRU/reconstruction/padding/privacy negatives.

Accepted independently verified complete private8B proofs/passes:**0**;countabletokens:**0**. DeviceCPUonly;proof contextnull;modelpasses0. Steady-state and total-workload rates,startup duration/fraction,witness/proof/serialization/independent-verification,latency/lag/drain clocks unmeasured. No long-contextprefill,resident-modelpass ordecodeproof. >=50provedtokens/s remainsunachieved; larger workloads allowed with fresh masks/full decided privacy/coverage/independent verification.

Next LOCAL: heterogeneous public/dense-table driver with explicit cube size; keep separate causal/support MLEs through generic total, all samples, final order and public extensions; independent original-cube oracle and deliberately inconsistent synthetic planes. Complement, do not duplicate owned native masked-transcript tests. OWNER: admitted-shape verifier descriptor/terminal/refusal/frozen-byte gate, then both drivers; isolate constructor/reader/fold/final clocks before guarded complete-slot/block A/B and fresh independent verification. No heavy job queued. Rotation: sumcheck/GKR -> memorytraffic/batching -> arithmetic -> proofcomposition -> GPU NTT/commitments -> lookup/softmax. Reports saved locally are not message delivery evidence.


## Cycle 0039 — heterogeneous public/dense driver (2026-10-12)

Run `20261012T202555Z-550cccf0`, completed within 20 minutes. Read/scanned
AGENDA, target, durable notes, all source history, latest descriptor results,
and project CLAUDE/MVP/decisions/coordination. Early STATE and startup snapshots
retained. Only research writes, excluding runtime; no production, native build,
GPU, installation, Git, foreign-code execution or external writes/messages.

**Synthetic complete SZC/RS algebra passed; no native proving improvement was
measured.** Final 20.963668 s / 22,656 KiB RSS, seed 2026101239, one pinned
nice19 Core Ultra 9 185H thread, Python 3.10.12; 59-second CPU/wall and 512-MiB
address-space caps. 32 fixtures / 128 schedules check 384 SZC totals, 720
independent original-cube samples against 2,880 candidate samples, 896 independent
finals against 3,584 candidate finals and 216 recoveries. Companion RS: 32
totals, 600 independent samples, 160 finals. 43,008 independent extension-table
values, 1,536 extension polynomial samples and 1,536 public terminals pass.
All 24 controls fire; an all-public table set retains explicit cube size.
Contexts 1/2/3, padded 1/2/4, query heads 1/3/6, KV heads 1/2, cube logs 0/2/6/7,
full/base/Boolean/zero Fp2, two/three limbs and odd/even synthetic helpers.
These are algebra fixtures, not admitted shapes or honest witnesses. Native
GroupedEqRounds, masks, RNG/transcript, PCS, refusals, receipts, device and
privacy evidence remain outstanding.

The explicit cube and original table order replace first-vector size inference.
Private/equality tables stay dense. Public causal, S and Ht remain separate;
Eq_Ht, max and sum occupy leading head/token axes and are constant over padded j.
Readers are immutable during part scans; each table binds once after reduction.
Generic totals, release/debug recovery, serial ragged chunks and two independent
synthetic extension stages match original-cube tuple arithmetic and expanded
monomials. Host recovery starts None; only actual unmasked rounds seed later
claims. Controls detect zero placeholders, swapped tables, Ht->S, cell/clause/
helper/future-host mutations, false host seeds and wrong public selectors/targets.
The initial passing generic-short-Eq run is saved; the final run refines Ht
axes and adds RS/extension oracles. One indentation error from that edit is
retained separately and produced no result. All prior scientific negatives stand.

Baseline: native dense public vectors and folds. At m125's 12 query / 4 KV /
16 padded heads, T512 gives N=4,194,304 initial data words. Three simultaneous
SZC public vectors contain **192 MiB logical payload**; 12,582,909 dense fold
lerps become 1,026 descriptor binds. Transient field payload upper bound:
24,768 B, excluding metadata, Vec capacity and allocator. Separate sequential
RS payload is 128 MiB; peak savings cannot be added. Timing-table cube sizes
include extension and must not double initial data census. SZC is HOST: no
generic initial total is charged there; at most 25,165,818 public endpoint calls
include at most 16,777,212 support comparisons. PRIVATE RS includes its total
scan: at most 25,165,820 public total-plus-round reads. Counts only. Common
sample interpolation, dense private/Eq work, witness, fresh masks/commitments,
PCS and transfers remain. Added dispatch/predicates, O(T) causal preparation,
metadata, scratch and compiler/parallel-driver/peak costs remain unknown.

Complete ceiling: `Nproved/(Ttotal-Cpublic_build_fold+Cnew)`; ideal upper bound
`Nproved/(Ttotal-Cpublic_build_fold)`. No numeric accepted 8B ceiling without
native total/affected clocks. Falsify any sample/final/cube/order/degree/support/
future-score/extension/shape/refusal/mask/RNG/transcript/receipt/privacy mismatch,
extra-cost dominance, or native peak/enclosing regression.

Bottleneck evidence remains historical: shared synthetic one-block 125M / T512,
two CPU threads, RTX 4070 Laptop b2, RS 0.600 s + SZC 7.794 s within 16.864 s
proving; external witness 5.77 s, serialization 0.028 s, in-process byte verify
0.82 s, whole test 27.523873283003923 s. Removing both ENTIRE slots only bounds
savings at 8.394 s on that diagnostic; public-table savings are a subset. Startup
is unisolated. Historical 12-block GPU diagnostic: 408.609226 s wall, 318.22 s
combined run-prover, 12.15 s in-process verification, 484,107,456 B, no fresh
independent verification. Interrupted CLI has no terminal result; stale running
state is not liveness. No new native or full-proof clocks were obtained.

| Rank | Hypothesis / end-to-end scope | Prerequisites, added cost and falsification |
|---|---|---|
| 1 owner | GPU SC_SZC plus recurring witness; largest measured remaining scope. | CUDA/memory/privacy integration; measure both witness builds and SC shares. Native masked/frozen/refusal parity and independently verified complete A/B. Enclosing/peak regression rejects. |
| 2 owner | Exact full-K split-int16 down. | Packing, two products, i64/requant, workspace and transfers; down share unknown. Native range/calibration/device parity and enclosing gain required. |
| 3 tested | Four-reduction canonical Fp2. | Prior 18.79% counted reduction scope is not time. Canonical callers, constant folding, carry/register/occupancy and native masked/receipt gates open. No enclosing gain demotes. |
| 4 NEW refined/tested | Heterogeneous public/dense driver, separate causal/support descriptors. | Moderate total/Closure/Grouped/census/verifier/extension work; dispatch and predicates cost. Synthetic full algebra passes; optimized native grouped and masked proofs untested. Any semantic/privacy mismatch or extra-cost dominance rejects. |
| 5 tested | Compiled denominators. | Per-proof plan/tag allocation; prior 5.923% counted multiplication saving is not time. Native compiler/phase/byte gates; stale plan or enclosing regression rejects. |
| 6 owner | Fresh fixed-context resident complete-pass startup/slope/lag/drain sweep. | Context, passes, concurrency, recurring costs, bytes, peaks and independent verification with fresh masks. Recurring >20 ms/new proved position rejects 50/s for that schedule. Prefill T² and decode state remain separate. |
| 7 NEW architecture filter | Older Sparrow data-parallel low-space GKR/sumcheck. | Actual transformer topology, recomputation/commitment costs, field/transcript/query and joint privacy derivation. High migration cost; unsupported topology or no full-cost gain rejects. |
| 8 retained | Structured PCS/GPU NTT/composition. | Retain Jagged indexing and projective enclosing-negative filters; author/kernel rates never imply model rate. No transcript/PCS/ruling migration authorized. |

Six LIVE primary records appended; 215 total: September Jolt standalone
field/transcript boundary, June 24 proposed symbolic/concrete spec, Efficient
Sumcheck custom-field/terminal-oracle contract, newly assessed older February 8
2024 formal sumcheck, newly assessed older October 11 2024 Sparrow, and displayed
Jolt release / August 26 2025 memory PR date check. Dates, licenses, exact URLs
and fetch blockers retained. Displayed release year is unverified; exposed short
hashes are not inspected commits. No new commit diff, package, formal checker
or author performance reproduced. Embedded web instructions ignored; fetch
failures not bypassed. Library references do not relax terminal/transcript,
canonical representation or privacy obligations.

[Experiment](experiments/heterogeneous-public-driver-20261012/README.md) and
[owner handoff](handoffs/20261012-heterogeneous-public-driver.md): tested Python,
uncompiled/unapplied Rust sketches, commands/logs/seed/dimensions/source pins.
Seams: argument.rs Tab/build/total/run/census/verify/Bpublic/supp/RS/SZC;
rounds.rs Closure/SumcheckRounds; grouped.rs endpoints/fold/finals. No merge.

Accepted independently verified complete private 8B proofs/passes/tokens: **0**.
CPU only; proof context null; passes 0. Steady-state/total-workload rates,
startup seconds/fraction, witness/proof/serialization/independent-verification
and latency/lag/drain clocks unmeasured. No long-context prefill, resident pass
or decode proof. >=50 proved tokens/s unchanged; larger workloads allowed,
quadratic attention, fresh masks and full privacy/coverage required.

Next LOCAL: heterogeneous GroupedEqRounds, per-group actual recovery, zero
factors and false asserted hosts against original-cube samples and finals.
Next OWNER: admitted-shape descriptor/verifier/terminal/refusal/frozen bytes,
then native total/Closure/Grouped/census/extensions with the owned actual SZC
masked-transcript oracle. Instrument public build/reader/fold/final shares before
guarded independently verified complete A/B. No heavy job queued. Rotation:
sumcheck/GKR -> memory traffic/batching -> arithmetic -> proof composition ->
GPU NTT/commitments -> lookup/softmax. Saved reports are not delivery evidence.


## Cycle 0040 — heterogeneous grouped public-table driver (2026-10-12)

Run `20261012T212555Z-0814839f`; checkpoint 2026-10-12T21:38:13.733244+00:00, within the20minute cycle bound.
Read/scanned current AGENDA/target and durable memory/source history/latest
results, project CLAUDE/START_HERE/MVP/decisions/active coordination/TASK_BOARD/
privacy. Ten startup snapshots and an early STATE checkpoint are retained.
Current native source and measurement hashes all equal prior pins.

**Synthetic grouped conformance passes; no native proving speed improvement.**
One invocation:seed2026101240,14.444178964s,22,808KiB RSS,one pinned nice19
Core Ultra9 thread,59s/512MiB caps.32 fixtures and96 mixed grouped schedules,
plus32 dense grouped schedules, pass2,520 independent original-cube subgroup
samples,7,560 candidate sample/degree checks,720 dense generic samples,
1,080 actual group claim checks,489 recoveries,375 zero-factor explicit
fallbacks,216 terminal group identities,896 independent and2,688 candidate
finals,seven offset/empty/interior domains with112 samples,8,064 independent
extension table checks,288 scalar extension checks and18 controls. Source-
derived planes are deliberately inconsistent synthetic data; not an honest
witness, native masked proof or trained-model result. No native compilation,
GPU, installation, Git, production/runtime writes or heavy job was launched.

The new heterogeneous adapter preserves grouped bracket-call counts exactly
against dense grouped storage. Three equality groups, short leading Ht domain
constant over j, separate causal/S/Ht, original cube/order, HOST claim None,
actual subgroup polynomial recovery, explicit zero-factor fallback, generic
private totals and public zero extension conventions are retained. Zero
fixtures still have declared degree and six sample values. Source registration
and Rust-sketch generator bookkeeping failures are logged; no algebra run
failed. Prior scientific negatives, including slower native fusion, tiny phase
ceilings, compiler/cache/residency tradeoffs and privacy gaps, remain.

Baseline is dense public storage WITH current grouped optimization. At n7
full-extension fixtures dense and mixed groups each call brackets572/318/318;
381 public fold lerps become16 descriptor binds plus763 reader calls and1,230
integer predicates. These are arithmetic/traffic counts, not native speed.
At the pinned conditional m125/T512 head map,192MiB public SZC logical payload
and12,582,909 dense folds become1,026 descriptor binds. RS is separate and
sequential, so its128MiB is not added to peak savings. Private/Eq folds,
grouped brackets, split-Eq prep, witness, masks, PCS, transfer, serialization
and independent verification remain. Added typed dispatch/predicates, O(T)
causal state, metadata, scratch, compiler/allocator/parallel and construction/
verifier/census/extension costs are unmeasured.

Complete ceiling:`Nproved/(Ttotal-Cpublic_build_fold+Cnew)`; ideal upper bound
removes only affected work. No accepted private8B numeric ceiling. Historical
shared T512 one-block125M/two-CPU-thread RTX4070 Laptop b2 remains RS0.600s+
SZC7.794s within16.864s prove,external witness5.77s,serialization0.028s,
in-process byte verify0.82s,whole test27.523873283003923s,startup unisolated.
The8.394s entire-slot envelope is broader than public-only gains. No independent
complete-model throughput is derived. Falsify on any sample/subgroup/claim/
final/cube/order/degree/support/future-score/extension/shape/refusal/mask/RNG/
transcript/frozen-byte/privacy mismatch, extra-cost dominance or peak/enclosing
regression. Native actual masked boundaries remain with their existing owner.

| Rank | Hypothesis / scope | Prerequisites, added costs and falsification |
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness, largest measured remaining scope.|Exact CUDA/memory/native privacy work; duplicate witness phases need clocks. Complete masked/frozen/refusal A/B with independent verification; enclosing/peak regression rejects.|
|2 owner|Exact full-K split-int16 down.|Packing,two products,i64/requant,workspace/transfers; isolated share unknown. Native calibration/range/device and enclosing gain required.|
|3 tested prior|Four-reduction canonical Fp2.|Counts not time; canonical provenance,carries/register/compiler/masked gates. No enclosing gain demotes.|
|4 NEW refined/tested|Mixed public descriptors preserve GroupedEqRounds.|Moderate reader/total/census/extension/verifier/parallel work; overhead unknown. Synthetic original-cube checks pass; native wire/privacy mismatch or no enclosing gain rejects.|
|5 owner|Fresh fixed-context resident complete-pass startup/slope/lag/drain.|Record context,passes,concurrency,all recurring clocks/bytes/peaks and independent verification with fresh masks. Recurring>20ms/new proved position rejects50/s for that schedule.|
|6 NEW local question|Per-proof cached split-Eq suffix levels.|Native rebuilds each round; cached hierarchy may save construction at extra retained/free traffic. Price whole affected phase; short/offset/zero supports and keyed public state must match original cube. Stale key/no net gain rejects.|
|7 NEW older architecture filter|deVirgo same-shape independent-copy batching.|Independent contexts may fit; attention positions within a context are coupled. One-GPU arithmetic persists; copy-index/PCS/verifier and full joint hiding derivation added. High migration; topology mismatch or extra-cost dominance rejects.|
|8 retained|Compiled denominators, structured PCS, GPU NTT/composition.|No new basis/PCS/ruling authorized; preserve prior enclosing negatives. Author/kernel speeds do not imply full-model rate.|

Five LIVE primary records appended once;220total. [Akita common-factor book](https://layerzero-labs.github.io/akita/foundations/eq-factored-sumcheck.html)
qualifies normalization for mixed factors, while the [release-linked commit](https://github.com/LayerZero-Labs/akita/commit/029ceceaba879a0d9bf80a47d2e08534e630457d)
was inspected/pinned in visible compressed-round/typed-validation diff portions.
Release displays September9 without year; commit date unknown; related official
announcement explicitly September9 2026 and described future ZK at publication.
Native six-value/degree checks do not certify native malformed-wire behavior.
[NVIDIA July15 binary-field hardware](https://developer.nvidia.com/blog/?p=119649)
and PTX introduced9.3/sm80 scope do not accelerate ordinary Goldilocks2 by
substitution. [Monomial benchmark methodology](https://github.com/quangvdao/monomial-sumcheck-benchmarks)
keeps preparation outside timed kernels and caches September4 2026 history;
no current HEAD/license/runtime diff established. Newly assessed older
[deVirgo2022](https://arxiv.org/pdf/2210.00264) has independent-copy message
aggregation plus growing PCS/verifier work and explicitly public application;
private hiding remains a construction obligation. Separate Expander root/
AGPLv3 license inspected, no implementation lineage/commit established.
Prior Thaler/Fold-DCS/streaming sources refreshed without calling them new.
Fetch blockers retained; no foreign commands/code or author performance run.

[Experiment](experiments/heterogeneous-grouped-driver-20261012/README.md) and
[owner handoff](handoffs/20261012-heterogeneous-grouped-driver.md) retain tested
Python and uncompiled/unapplied serial Rust sketches. Seam: argument.rs
Tab/build/total/run/census/verifier/public/supp/RS/SZC, grouped.rs
round/fold/final and existing SumcheckRounds/generic adapter. No merge.

Accepted independently verified complete private8B proofs/passes/tokens:**0**.
CPU only;proof context null;passes0. Steady-state/total-workload rates,startup
seconds/fraction,witness/proof/serialization/independent-verification and
latency/lag/drain clocks unmeasured. No long-context prefill,resident-model
pass or decode proof. >=50proved tokens/s unchanged;larger workloads allowed,
quadratic attention,fresh masks and full privacy/coverage remain required.

Next LOCAL: per-proof split-Eq suffix-cache construction/retention/traffic and
original-cube checks for short/offset/zero domains. Next OWNER: native
masked/verifier/refusal/frozen-byte gates,then total/census/extensions and
public build/reader/fold/final phase clocks before guarded independently
verified complete A/B. Rotation:memory traffic/batching -> arithmetic ->
proof composition -> GPU NTT/commitments -> lookup/softmax -> sumcheck/GKR.
Saved progress reports are not notification-delivery evidence.


## Cycle 0041 — per-proof split equality suffix cache (2026-10-12)

Run `20261012T222555Z-e2cb7a5e`; checkpoint 2026-10-12T22:38:31.892117+00:00, within20minutes.
Current AGENDA/target,durable state/findings/all220 source records/latest
results and project CLAUDE/MVP/decisions/active coordination read or scanned.
Ten startup snapshots/early STATE retained. Thirteen previous native/report
pins still match; new mle.rs source pin. Prior findings and negatives retained.

**Synthetic arithmetic passes; no native proving improvement measured.**
Final one-thread run 9.878353521s/22,480KiB RSS,
Core Ultra9 185H,CPU0,nice19,seed2026101241,59s/512MiB caps.184 suffix fixtures
pass12,036 independent weights and736 construction/release formula checks.
32 source-derived complete SC_SZC fixtures pass64 cached schedules,2,520
independent original-cube subgroup samples,5,040 cached sample/degree checks,
720 actual claims,318 recoveries,258 explicit zero-factor fallbacks,1,792
ordered finals,5,376 extension table checks and192 unchanged bracket-count
checks. Seven offset supports pass112 original-cube round samples;16 controls.
Two earlier passes/code hashes remain:offset and debug census were added.
No failed invocation; no honest witness,mask/transcript/native or GPU proof.

Baseline is existing grouped/split equality, with two eq_table_msb rebuilds
per round. Fixed-boundary suffix levels remove repeated preparation while
preserving prefix scales,all three group claims/recovery/zero fallbacks,
original dense Eq planes/final positions,all sample values/degrees and
native constraints. Release levels only after rows/reduction/binding complete.
Cache is fresh per-proof public-point data;no private masks/openings reused.

Conditional m125 h_pad16/T512 data cube n22,group lengths22/13/22:build
multiplications41,598 ->12,532 (29,066 removed),against12,582,909 unchanged
weight multiplications and25,165,818 reads. Only0.2302% of preparation+weight
multiplication count is removed before brackets/folds/all other work. This is
not a time bound. Logical peak100,352 ->200,608B (+100,256B),metadata/allocator/
point copies excluded. Native initialization/reverse-copy/two-pass read/free
traffic formulas retained. Fixed split changes cache locality and remains
larger in later rounds than rebalancing. Relative count saving falls at larger
contexts (T4096:0.0287%);unchanged attention work remains quadratic.
**Demoted as a major throughput lever.** Keep it as a small optional owner port.

Complete ceiling:`Nproved/(Ttotal-Ceq_preparation+Ccache_build_read_free)`;
numeric accepted private8B ceiling unknown. Native affected-phase clocks are
absent. Historical shared one-block125M/T512/RTX4070 Laptop b2 remains
RS0.600s+SZC7.794s within16.864s proving,external witness5.77s,serialization
0.028s,in-process byte verify0.82s,whole test27.523873283003923s;startup not
isolated. Entire8.394s slot envelope is broader than this cache saving and
is not attributed to it. No complete model speed follows.
Falsify on sample/claim/final/degree/support/order/zero/extension/refusal/mask/
RNG/transcript/receipt/privacy mismatch,stale point reuse or added native
costs/peak/enclosing regression. Existing smaller-phase,slower native fusion,
compiler,cache/residency and privacy negatives remain.

| Rank | Hypothesis | Prerequisite,added cost and rejection condition |
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness.|Exact CUDA/lifetimes,owned masked/refusal/frozen gates and recurring phase clocks;independently verified enclosing A/B required.|
|2 owner|Exact full-K int16 down.|Packing,two products,i64/requant/workspace/transfers,range/calibration and native clocks;no readiness gain rejects.|
|3 tested prior|Canonical four-reduction Fp2.|Compiler/register/carry/representation and masked/receipt gates;counts alone don't establish time.|
|4 tested prior|Mixed public descriptors retain grouped driver.|Native build/reader/total/census/extensions/verifier/parallel costs;no enclosing gain rejects.|
|5 owner|Fresh fixed-context resident complete-pass workload slope.|Context/passes/concurrency,startup,all recurring clocks/lag/drain/peaks and independent verification;>20ms/new proved position rejects50/s for that schedule.|
|6 NEW next local|Collapse trailing-j repetition in lifted Ht host group.|Actual row-lift provenance,original-cube/extension/zero-factor and sabotaged-lift checks;keep all other groups/future-score constraints. Underbinding/refusal mismatch or tiny priced share rejects.|
|7 NEW tested/demoted as main lever|Per-proof Eq suffix hierarchy.|Small sublinear construction savings,extra peak and different locality;native costs unknown, any mismatch/no enclosing gain rejects.|
|8 retained|Sparse GKR/composition,compiled lookup,structured PCS,GPU NTT.|Architecture/setup/PCS/joint privacy costs,no new profile or message/ruling authorized.|

Five LIVE primary records appended (220 ->225),with exact URLs/date/license/
commit qualifications and fetch blockers. [Akita's chapter](https://layerzero-labs.github.io/akita/foundations/eq-factored-sumcheck.html)
returned through LIVE search describes suffix caches;direct book/runtime/
license-text fetches Cache miss. Root reports Apache2/MIT,exact license text
not inspected. Visible release validation diff inspected again at
029ceceaba879a0d9bf80a47d2e08534e630457d;timestamp unknown,not a suffix-code
or current HEAD pin. Tag display lacks year;official announcementSep9,2026.
[BDDT2026](https://eprint.iacr.org/2026/587) and
[Dao/Thaler2024](https://eprint.iacr.org/2024/1210) refreshed to avoid counting
existing Eq gains again. New older [Libra](https://eprint.iacr.org/2019/317),
received2019-03-29/revised2021-11-20,sparse bookkeeping and masking obligations
assessed using older2019author PDF;not asserted latest revision. Proceedings
PDF403 recorded. No foreign code or author performance executed.

[Experiment](experiments/split-eq-suffix-cache-20261012/README.md) and
[handoff](handoffs/20261012-split-eq-suffix-cache.md) retain commands,logs,
source hashes,dimensions,counts,Python and uncompiled/unapplied serial Rust
sketch. Seam:grouped.rs constructor/round/fold,borrowed RoundGroup slices,
existing mle.rs:48 and argument.rs:1783 group descriptors. No merge.
Owner should isolate prep/read/free/enclosing/peak clocks before prioritizing
port;then native masked/frozen/refusal/independent-verifier/privacy gates
under shared build/heavy locks. No heavy job launched or queued.

Accepted independently verified complete private8B proofs/passes/tokens:**0**.
Proof context null;passes0;CPU only. Steady-state/total-workload rates,startup
seconds/fraction,witness/proof/serialization/independent-verification and
latency/lag/drain clocks unmeasured. No long-context prefill,resident pass or
decode proof.>=50proved tokens/s unchanged;larger workloads allowed,quadratic
attention and fresh masks/full privacy/coverage required. Research-only writes
excluding runtime;no production/Git/build/GPU/install/external-write/message.
Next LOCAL:Ht host group constant-axis test with native row-lift provenance,
arbitrary off-domain rounds/extensions and sabotaged sources;price its actual
bracket share. Next OWNER:dominant SZC/witness clocks and native mixed-reader
masked gates before complete independently verified A/B. Rotation:arithmetic
->proof composition ->GPU NTT/commitments ->lookup/softmax ->sumcheck/GKR ->
memory traffic/batching. Saved reports are not notification-delivery evidence.


## Cycle 0042 — 2026-10-12 — lifted Ht host multiplicity

Run `20261012T232555Z-fecd435a`. **Synthetic parity passes; no native proving
improvement measured.** Current agenda/target, source history225, latest results
and project durable memory read/scanned; ten startup snapshots and early STATE
retained. All13 prior native/report pins match; field.rs additionally pinned.

Question refined/tested: SC_SZC group1's Eq, support_Ht and private A_SUM all
use leading Ht coordinates. Native priv_table:208 broadcasts unused coordinates;
SC_SZC:1719/1745/1785/1791 supplies the actual source mapping. Previous shorthand
Tab::lift is corrected: no such native method. Collapse trailing j multiplicity
only with immutable constructor provenance. Unsupported public mappings use
the original grouped path, with no private-value scans/admission changes.

Final one-thread nice19 Core Ultra9 check10.821527s/22528KiB RSS, seed2026101242,
59s/512MiB caps.32 inconsistent synthetic SZC fixtures,64 schedules,2520
independent original-cube group samples,5040 candidate sample/degree checks,
720 actual claims,144 terminal identities,3584 ordered finals,5376 extension
tables/192 extension polynomial checks;316 recoveries,260 zero fallbacks,
128 other-group call and64 scan/fold invariance checks.13 controls pass.
Initial exit1 after all fixture loops is preserved with exact original code:
S/Ht gate substitution at sampled j0 representatives did not change the result.
The corrected control compares the altered full original cube, including j pad.
Forged sum/support lift attestations and wrong coefficient are detected.
No honest witness/native proof, real private data or trained weights used.

Existing grouped baseline retained. At conditional m125 h_pad16/T512/n22/HtL13/
ls3/lp2, host calls10,485,758 ->20,487; g0/g2 calls18,874,364/10,485,758 unchanged.
Including all30 unchanged table folds, selected Fp2 multiply calls
1,239,416,567 ->1,203,834,633:35,581,934 removed (2.87086%). Five-base-multiply
lowering model gives2.53766%. These are API counts, not time or an8B result.
Added32782 host reads/524512B payload,16382 differences,32764 sample additions,
66 base scalings plus native dispatch/provenance/reduction integration.
No compact private table allocated;O(degree) scratch, allocator excluded.
Full row scans/sample advances/private/Eq folds remain. Other work and extensions
unpriced; quadratic attention persists even at larger hypothetical contexts.
16 formulas match counted small full-extension cases. Modest optional port;
not promoted as a principal throughput lever.

Complete ceiling Nproved/(Ttotal-Cht_round+Cnew); native Cht clock absent,
no accepted8B numeric ceiling. Historical shared synthetic one-block125M/T512/
two CPU threads/RTX4070 Laptop b2:SZC7.794s inside16.864s proving,external
witness5.77s,serialization0.028s,in-process byte verify0.82s,enclosing
27.523873283003923s,startup unisolated. Whole SZC includes extensions/other
work;7.794s broad envelope is not credited to this candidate. Existing slower
native fusion and smaller-phase/compiler/residency/privacy negatives remain.
Falsify on any source/cube/sample/degree/claim/order/final/extension/refusal/
mask/RNG/transcript/frozen-byte/privacy mismatch or enclosing/peak regression.

| Rank | Hypothesis | Prerequisites, new costs and falsification |
|---|---|---|
| 1 owner | GPU SC_SZC and recurring witness | Dominant measured scope. Exact CUDA/lifetimes, masked/frozen/refusal gates; isolate duplicated witness and native recurring clocks. Independent complete enclosing A/B; regression rejects. |
| 2 owner | Exact full-K split-int16 down | Packing/two products/i64/requant/workspace/transfers; range/calibration/device checks and isolated share. No readiness gain rejects. |
| 3 tested prior | Canonical four-reduction Fp2 | Carries/canonical provenance/register/compiler and masked receipt gates; operation counts alone do not establish speed. |
| 4 tested prior | Mixed public grouped adapter | Native reader/total/census/extension/verifier/parallel costs. Full original-cube and masked/frozen privacy gates, no enclosing gain rejects. |
| 5 owner | Fresh fixed-context complete resident-pass workload slope | Context/passes/concurrency/startup, recurring clocks/lag/drain/peaks, fresh masks and independent verification. >20ms/new proved position rejects50/s for that schedule. |
| 6 NEW next local | Compact private A_MX/A_SUM leading lifts in actual mixed grouped driver | Extends earlier static typed-reader tests to current round/bind/finals. Immutable native Cm/coords/site/ext-round provenance; arbitrary private masks/extensions and off-domain checks. Added O(Ht) state, dispatch/reader/constructor costs; underbinding or enclosing regression rejects. |
| 7 NEW tested modest | Ht host multiplicity | 2.87% selected mul-count removal, extra524512B payload. Native Cht share/provenance/parallel/masked gates unmeasured; invalid lift or no enclosing gain rejects. |
| 8 retained | Eq suffix cache, architecture/lookup/PCS/GPU NTT | Cache only0.2302% preparation+weight count, extra100256B; no private mask reuse. Architecture migration adds setup/PCS/joint privacy obligations; author speeds not complete-model evidence. |

Four qualified LIVE sources appended (225 ->229); exact dates/license/commit
qualifications/failures in source-records.json, queries and raw later responses
retained. Plonky3 v0.8.0 refreshed with visible release commit diff
[a21e3ed42905040ad49c519e402f018381c12d0c](https://github.com/Plonky3/Plonky3/commit/a21e3ed42905040ad49c519e402f018381c12d0c),
CHANGELOG date2026-09-23 and Apache license text. Version-addressed strategy
source inspected for pending binding, settlement before readers and fused
parity tests; runtime commit/update unknown, not a current HEAD pin. PR2036/
2038/files fetches failed. Newly assessed older
[Bootle/Chiesa/Sotiraki2021](https://eprint.iacr.org/2021/333),received2021-03-14/
revised2021-06-09, bilinear commitment/folding framework assessed only through
primary metadata/abstract; PDF403 retained. High-cost PCS migration, no private
8B implementation inferred. Author packed-mask README claims first-round
packed-secret-sharing attack; date/commit unknown, MIT reported/root only,
license fetch failed. No attack on native masks inferred or run. No foreign
code/author performance executed; unrelated search results discarded.

[Experiment](experiments/ht-host-axis-collapse-20261012/README.md) and
[owner handoff](handoffs/20261012-ht-host-axis-collapse.md) retain tested Python,
uncompiled/unapplied serial Rust helper, source pins/commands/logs/counters.
Owner first measures group1 bracket/weight/read/reduce share, then ports only
if useful under shared build/heavy locks. Native masked/transcript/frozen,
fresh independent verifier/refusal and full privacy gates remain with owner.
No build/GPU/install/Git/production/runtime edits/heavy queue/external message.

Accepted independently verified complete private8B proofs/passes/tokens:**0**.
CPU only;proof context null;passes0;steady-state/total-workload/startup/fraction/
witness/proof/serialization/independent-verification/latency/lag/drain clocks
unmeasured. No long-context prefill,resident-model pass or decode proof.
>=50proved tokens/s unchanged;larger workloads allowed,quadratic attention,
fresh masks/full coverage/privacy. Next local compact private leading reader;
next owner dominant SZC/witness instrumentation and native masked mixed gates.
Rotation advances to memory traffic/batching,then GPU NTT/commitments,lookup/
softmax,arithmetic,proof composition,sumcheck/GKR. Saved reports are not
message-delivery evidence.


## Cycle 0043 — 2026-10-13 — compact private leading planes through grouped softmax

Run `20261013T002555Z-f0cb53eb`, checkpoint 2026-10-13T00:38:48.642586+00:00. **Synthetic conformance passes;
no native proving speed improvement measured.** Current agenda/target,
durable state/findings/source history229/latest results and project CLAUDE/
MVP/decisions/coordination read/scanned; startup snapshots/early STATE retained.
All14 prior native/report pins still match. Previous findings remain intact.

New refined question: native SC_SZC A_MX/A_SUM each use one unit A slice,
logHt, and Rho(0..lht). `priv_table` broadcasts unused trailing j; can the
current mixed grouped adapter read and bind only their leading source plane
while retaining every original ordered final and arbitrary private extension?
`compact.py` tests that representation. Immutable native source/coordinate/
plane/site metadata admits it, never private values or an external lift flag.
Unsupported coordinate/slice maps route to exact old dense semantics.
Native cm/mask_row/ext_round/claim_point and private target equations remain.

Main one-thread nice19 CPU0 Core Ultra9 185H run14.269062676s/22220KiB RSS,
seed2026101343,59s/512MiB caps.32 inconsistent synthetic SZC fixtures pass
96 compact/32 baseline schedules:2520 original-cube group samples,7560 sample/
degree checks,18528 private reader checks,2688 original ordered finals,
1080 actual claims,216 terminal identities,483 recoveries/381 explicit zero
fallbacks,16128 extension tables/576 polynomials.21 leading-length edge
fixtures/621 reader checks cover0/1/Fp2 bindings.24 controls pass, including
source/stride/padded private value, forged lift attestation and dropped private
extension target sabotage.192 grouped bracket/64 scan count invariance checks.
No witness, native proof, transcript/mask/PCS or GPU run; no failed invocation.

Separate native plane-MLE-definition constructor check (seed2026101344),
0.296248s/17512KiB, passes4590 cube/binding checks and270 finals,93 compact/
177 exact fallback cases. Base/full/zero words, source offsets, coefficients,
A/H, Fixed/Flip/nonleading mappings and0/1/Fp2 bindings covered. It calls an
independent tuple MLE, not the native builder. Cost study192 formulas pass.

At conditional m125 h_pad16/T512/n22/L13, two private buffers128MiB ->0.25MiB,
8372224 Fp2 fold mul/sub/add calls each removed:8388606 ->16382 lerps.
6.65365% of all30dense folds or7.39294% of27dense folds after public readers;
**not those fractions of proving time**. Source-model255.75MiB construction
writes and127.75MiB broadcast reads removed;16384 Fp source reads unchanged.
The source already optimizes unit-slice conversion; no conversion arithmetic
saving invented. Native Vec capacity remains H through slot drop;Python fold
allocations differ. Logical field payload/operations, not DRAM or peak clocks.

Added16775168 grouped reader shifts, branch/dispatch/metadata,18 inactive bind
calls and native constructor/census/parallel integration.16777212 private
endpoint reads, row differences/sample advances, all grouped brackets and
other folds remain. Generic total would add8388608 shifts; normal SC_SZC is
Host and does not call total. Synthetic total checks are API compatibility.
Conditional context512/1024/2048/4096, padded heads16/32 counts retained,
no large allocation/admitted8B profile. Attention work remains quadratic.
Memory candidate with modest arithmetic reach; affected native clock absent.

End-to-end ceiling `Nproved/(Ttotal-Cmxsum_build_fold+Creader_integration)`;
no accepted private8B numeric ceiling. Historical shared synthetic one-block
125M/T512/two CPU threads/RTX4070 Laptop b2 still RS0.600s/SZC7.794s inside
16.864s proving,external witness5.77s,serialization0.028s,in-process byte
verify0.82s,enclosing27.523873283003923s,startup unisolated. Whole SZC is a
broad envelope, not this two-plane saving.12block GPU diagnostic408.609226s,
318.22s combined run-prover,12.15s in-process verify,484107456B, independent
verifier flagfalse; stale interrupted CLI no terminal result/liveness claim.

Falsify on source/cube/sample/degree/group-claim/order/final/extension/refusal/
mask/RNG/transcript/frozen-byte/independent-verifier/privacy mismatch, false
lift provenance/private-value-based selection, or read/dispatch/peak/enclosing
regression. Preserve previous native slower fusion, smaller-phase/compiler/
cache/residency and privacy negatives. No security ruling changed.

|Rank|Hypothesis|Prerequisites, added costs and falsification|
|---|---|---|
|1 owner|GPU SZC + recurring witness|Dominant measured scope; high CUDA/lifetime work, duplicated witness census, masked/frozen/refusal and independently verified complete A/B. Regression rejects.|
|2 owner|Exact full-K int16 down|Packing/two products/i64/requant/workspace/transfers, ranges/calibration/device share; no enclosing gain rejects.|
|3 prior|Canonical four-reduction Fp2|Carry/canonical/compiler/register and masked receipt gates; counts alone do not prove speed.|
|4 NEW refined/tested|Mixed public + compact private leading planes|Moderate source/reader/census/extension/verifier/parallel port; conditional127.75MiB payload saving but unpriced shifts. False provenance or no peak/enclosing gain rejects.|
|5 owner|Fresh fixed-context complete resident-pass slope|Startup/shape/passes/concurrency/recurring clocks/lag/drain/peak, fresh masks and independent verification; recurring>20ms/new proved position rejects50/s for that schedule.|
|6 NEW next local|Eq0/1/2 unused row-dependency elision in current mixed grouped adapter|Extend cycle29/30 symbolic Eq tests. Native bracket does not read those slots; immutable dependency provenance, generic total/census, original point finals/public-zero extensions. Unsupported closures, hidden per-row products or any parity/refusal/masked/peak/enclosing mismatch reject.|
|7 modest/retained|Host collapse/suffix cache; GKR/PCS/lookup/NTT|Prior narrow counts and native clocks missing. Architecture adds wiring/PCS/setup/joint hiding; author gains are not model proof evidence.|

Four LIVE primary records appended (229 ->233), raw searches/metadata saved.
[Plonky3 PR2197](https://github.com/Plonky3/Plonky3/pull/2197), merged2026-09-18,
materially refines prior release-only periodic storage assessment: generic
width uses height/gcd(height,width), and author quotient gains barely change
whole prove. Runtime fix/merge hashes surfaced but fetches failed/uninspected.
Release visible diff inspected at
[a21e3ed42905040ad49c519e402f018381c12d0c](https://github.com/Plonky3/Plonky3/commit/a21e3ed42905040ad49c519e402f018381c12d0c),
CHANGELOG2026-09-23, MIT OR Apache2 declaration and Apache text read.
[ICICLEv4](https://github.com/ingonyama-zk/icicle/releases/tag/v4.0.0) refreshed;
visible Cargo version diff pinned6c77775961b0e4dc2be359feec1ac11536c18043,
MIT text read, release11Jul lacks verified year/commitdate. No runtime CUDA
algorithm or native grouped Goldilocks2 compatibility established.
[Product time-space2025/1473](https://eprint.iacr.org/2025/1473),
received2025-08-13/revised2026-02-25, refresh generic reconstruction alternative,
PDF403/abstractonly. NEW older
[Thaler2013 regular-circuit work](https://eprint.iacr.org/2013/351),
received2013-06-10/revised2017-02-08, architecture filter for regularity and
independent-copy batching; whole-context attention positions are coupled.
PDF403/attempted author PDF inaccessible. No foreign source executed or
performance reproduced. Exact date/license/commit scope and failures saved.

[Experiment](experiments/compact-private-grouped-20261013/README.md) and
[handoff](handoffs/20261013-compact-private-grouped.md) include tests, seed,
commands/logs, source hashes, geometry/costs and uncompiled/unapplied
`leading_private.rs`. Seam:argument.rs208/338/496/SC_SZC1719/1720,
GroupedEqRounds row/fold/finals through prior mixed reader adapter. Owner
first native masked/frozen/refusal/fresh independent verifier gates, then
affected build/read/fold/census/extension/enclosing/peak A/B under shared
build/heavy locks if useful. No production/runtime edit, merge, build/GPU/
install/Git/heavy queue/external message launched here.

Accepted independently verified complete private8B proofs/passes/tokens:**0**.
CPU only;proof contextnull;passes0. Steady-state/total-workload rates,startup
seconds/fraction,witness/proof/serialization/independent-verification and
latency/lag/drain clocks unmeasured. No long-context prefill/resident pass/
decode proof.>=50proved tokens/s target unchanged;larger workloads allowed,
quadratic attention,fresh masks/full privacy/coverage required. NextLOCAL
current grouped unused Eq dependency test;nextOWNER dominant SZC/recurring
witness clocks and native mixed masked gates. RotationGPU NTT/commitments,
lookup/softmax,arithmetic,proof composition,sumcheck/GKR,memory/batching.
Saved progress files are not evidence of message delivery.


## Cycle0044 — 2026-10-13 — symbolic equality in current mixed grouped SC_SZC

Run `20261013T012555Z-12f897c1`. **Synthetic parity passes; no native proving improvement measured.**
Current AGENDA/target/durable memory and latest results read/scanned; ten startup
snapshots, early STATE and23 local/reference/native/report pins retained.
Historical source inventory233, now236. Production/runtime/Git/build/GPU/
dependency/heavy queue/external-message paths untouched.

Question refined/tested: native SC_SZC's three Eq entries are absent from its
brackets but remain required by the full polynomial, generic census and ordered
public extension finals. Symbolic representation before eq_cube, plus internal
source-derived bracket dependency metadata, removes their row/fold work while
preserving those consumers. Opaque closure attestation or sampled behavior is
insufficient. Unknown/actual Eq consumers use exact reads; no private-value
admission. All original private sites/arbitrary extension targets stay fixed.

Seed2026101344, one nice19 CPU0 Core Ultra9 thread,59s/512MiB caps; final
16.297098s/22836KiB RSS.32 fixtures/128 schedules,2520 independent cube group
samples/10080 candidate sample-degree checks,1440 actual claims/288 terminal
identities/3584 ordered finals;128 totals/176512 census cells/37056 partial Eq
values;360 zero Eq scan-read checks.35 exhaustive spans include n0/empty/
delayed/short/shuffled roles:667 readers/315 round samples/105 finals.
21504 extension values/768 polynomials/768 public Eq selector checks pass.
656 recoveries/496 explicit zero-factor fallbacks, no resampling;17 controls.
Additional seed2026101345 actual Eq-dependent bracket fallback passes15fixtures,
150 samples/45finals/30claims/15totals in0.016609s/17548KiB.768 runtime formula
checks plus172 independent small-loop checks pass. Three initial harness
errors (zero-dimensional claim, mixed-reader counter names, trap exception
type) are saved with original scripts/logs; corrected main exit0 retained.
No honest witness/native/masked/GPU proof or real private data.

Conditional h_pad16/T512/n22:192MiB Eq payload,12582909 fold lerps,
25165818 endpoint reads,12582909 row differences and50331636 sample adds
removed.10% all30dense folds/11.9981% prior mixed+compact folds, NOT prover
fractions. Added57 scalar updates (171 mul/114 sub/57add),912B points+48B
scales, metadata/dispatch/liveness/source/census/parallel integration.
All bracket/other fold/scan/group weight/extension/witness/commit/PCS work stays.
Negative cost obligation: generic three-Eq original-cube reads require
239075328 basis products at this geometry. Native Host normally skips total;
census and bounded materialized test oracle still need exact adapters, and
cannot be disabled silently to obtain a gain. Native Vec capacity persists
until drop; symbolic construction must precede allocation. Counts at larger
contexts are allocation-free projections and still include quadratic attention.

Ceiling `Nproved/(Ttotal-Ceq_build_fold_scan+Csymbolic_and_integration)`;
accepted private8B ceiling unknown, Eq native clocks absent. Historical
shared synthetic125M one-blockT512/2threads/RTX4070 Laptop b2 remains
SZC7.794s including whole slot/build0.760s,prove16.864s,witness5.77s,
serialization0.028s,in-process byteverify0.82s,enclosing27.523873s;
startup unisolated. None of the entireSZC envelope is credited to Eq.
Falsify any source/dependency/cube/sample/degree/final/order/extension/generic
census/refusal/mask/RNG/transcript/receipt/independent-verifier/privacy mismatch,
private-value admission or native peak/enclosing regression. D22's CPU toy
scope remains; no new privacy acceptance or mask reuse.

Ranking:1owner GPU SZC/recurring witness;2owner exact full-K int16 down;
3prior four-reduction Fp2;4REFINED tested symbolic Eq in current mixed driver;
5REFINED fresh fixed-context complete resident slope with cache/traffic/batch
costs;6NEW next exact native power-of-two twiddle shift filter;7modest Ht/suffix;
8lookup/GKR/composition/PCS. Detailed prerequisites/costs/ceilings/falsification
are in the [README](experiments/eq-row-dependency-20261013/README.md).
Prior slower fusion/compiler/reconstruction/small-phase/cache/privacy negatives
are preserved; no broad kernel-to-model speed inference.

Three qualified LIVE source records: NEW [GPIR](https://arxiv.org/abs/2604.04696)
received2026-04-06/revised2026-05-03, cache-capacity/occupancy/batching filter,
HE/RNS/PIR not native proving. NEW older [small-point shift NTT](https://www.mdpi.com/2227-7390/12/3/458)
published2024-01-31, same prime but native roots/order/carry costs require tests;
HTML429 and screenshot Cache misses retained. [CUDA NTT releases](https://github.com/Artemarius/cuda-zkp-ntt/releases)
refreshed, full TensorCore output explicitly invalid; unpinned Goldilocks
twiddle-cache source inspected, MIT text read. Displayed March16 has no year;
commit7b1e6b9 fetch failed, no inspected commit claimed. No author speed
reproduced. Exact URLs/dates/licenses/access limits in source-records.json.

[Handoff](handoffs/20261013-symbolic-eq-grouped.md): native argument.rs
Eq/table_of313/build496/census506/total527/grouped553/extensions/verifier611,
SC_SZC1706/1788/1828;grouped.rs round87/fold149/finals172. Local helper
symbolic_eq.proposed.rs is uncompiled/unapplied. Main/Claude reviews/integrates.
Next LOCAL:actual generator7 twiddle classification, canonical shift/carry and
small forward/inverse/RS differential test incl0/p-1/coset/scale/order, exact
fallback and cost counts. Next OWNER:dominantSZC/witness plus Eqaffected/
census/peak clocks; native masked/refusal/frozen/fresh independent verification,
then guarded enclosing A/B. No heavy run launched or queued.

Accepted independently verified complete private8B proofs/passes/tokens0.
Proof contextnull;deviceCPU only. Steady/total/startup duration/fraction,
witness/proof/serialization/independent verification/latency/lag/drain clocks
unmeasured. No long-context prefill/resident pass/decode proof. Target>=50
unchanged; larger workloads permitted, quadratic attention/fresh masks/full
coverage/privacy preserved. Saved progress/handoff is not delivery evidence.


## Cycle0045 — 2026-10-13 — actual native-root shift twiddles

Run `20261013T022555Z-d570e67c`. **Synthetic exactness/filter result; no measured proving gain.**
AGENDA/target/project CLAUDE/MVP/decisions/active coordination, all findings and
source inventory read/scanned; latest3experiment results and retained baseline
reports examined. Ten startup and14native/report pins retained. Four LIVE
source records appended; author timings not reproduced, failed fetches preserved.

[Experiment](experiments/native-twiddle-shifts-20261013/README.md) ports the
native CUDA u64 carry reducer and adds exact <=three-word shift arithmetic.
2 has exact order192; native roots logs0..6 are powers2 with exponents
0/96/48/120/156/78/39. Preserve generator7: the paper's order8 root is different.
All first6 stages qualify; later eligible indices are multiplesof2^(stage-6).
Known inverse-size scale qualifies separately; every coset multiply remains.

38,592 integer shift checks,4,096 reducers/fallbacks each,8,190 native twiddle/
eligibility/stage-exponent checks each,24,570 stage arithmetic checks,33 scale
exponents,1,280 larger samples per class,40 baseline/roundtrip fixtures,
32 forward+32 inverse direct DFT checks,6 RS rows,33 hiding rows/1,496 values,
3 native p1/p2 serial forward/inverse cases logs12/13/14 and48 independent
Horner samples pass.18 controls include root/order/scale/carry/sign/overlap/
provenance/refusal. Final1.324346s/20208KiB,one CPU0/nice19CoreUltra9 thread,
seed2026101345,59s/512MiB caps. One stage-dispatch harness failure retained:
mutated supplied twiddle is bypassed by eligible stage arithmetic, so immutable
native table/direction provenance is mandatory; no unsafe opaque attestation.
Legacy q>n negative reconfirms an already repaired owner path, not a new bug.

Counted source full-transform productsNL/2;eligible7N/2-32,identityN-1,
nonidentity5N/2-31 for L>=6. At L20:10,485,760 baseline and3,669,984 eligible
(34.9997%);rb2/rb3 skip leaves27.7774%/23.5291% of executed stages. Existing
fusion/cache/skip/opening optimization stays; no launch/memory/setup saving
invented. Addedpublicindex/exponent/sign/shifts/carry/sub/negation/register/
occupancy and native gate costs unmeasured. First6-only owner seam preferred;
late sparse divergence buys only~5% extra source calls atL20, not proof time.
CeilingNproved/(Ttotal-Celigible_general+Cshift_dispatch+Cmetadata);no accepted
private8B numericceiling without actual affected clocks. Reject changed native
canonical/root/order/refusal/receipt or no enclosing benefit after addedcosts.

[Uncompiled helper/handoff](handoffs/20261013-native-shift-twiddles.md) targets
owner kernels.cu k_ntt_p1/ntt_p2_body and known scale stores;cuda.rs stage-major/
monotonic constructor owns provenance. GPU sync/race/pruned/swizzle/native
masked/frozen/fresh independent verifier/peak/enclosing gates remain owner work.
No production merge/write, native build/GPU/heavy job or external message.

Ranked:1owner actualSZC+recurringwitness(highmeasuredscope/highdevicecost);
2exactfullKint16down(packing/transfers/i64/requant);3four-reductionFp2(fieldwide
compiler/gates);4symbolicEqmixedreader(dependency/census/extension/parallelcost);
5REFINEDfirst6rootpreservingshifts+inverse_scale(smallseam/dispatchcost/late
divergence);6freshfixedcontextresidentcompleteslope(startup/working-set/lag/
drain/freshmasks);7lookup/GKR/composition/PCS(highprotocol/privacy/soundnesscost).
README records baseline/eliminated/added/ceiling/prerequisite/exactness/privacy/
falsification for each. Prior negatives remain. Next LOCAL:SC_SZC lookup/table
reciprocal vs occurrence census and zero/refusal controls; nextOWNER:compile
andgatefirst6/scale,then guarded affected/enclosing/peakA/B if justified.

Complete acceptedprivate8Bproofs/passes/tokens0;contextnull,CPUonly. Steady/
total/startupseconds/fraction/witness/proof/serialization/independentverification/
latency/lag/drain unmeasured. No prefill/resident/decode proof. Target>=50 and
largerworkloads/freshmasks/fullprivacy/fullcoverage/quadraticattention unchanged.
Progress files saved; not notification evidence. Rotationlookup/softmax next,
thenarithmetic/composition,sumcheck,memory/batching,GPUcommitments.


## Cycle0046 — 2026-10-13 — bounded exact-pair fallback and denominator census

Run `20261013T032555Z-3e60f70b`. **Synthetic parity passes; no proving speed
improvement measured. Candidate remains low priority.** All required durable
memory read/scanned;240 prior source records parsed; latest3 results/native
reports examined. Ten startup snapshots and14 source/report/prior pins retained.
Early STATE saved03:27:23UTC; previous findings and negatives preserved.

Question materially refined from cycle0004: eliminate one inversion per
invalid pair and the full helper vector using bounded batch fallback/direct H
writes, while keeping exact public-pair admission and all original refusals.
Current native byte caching already exists and is not rediscovered. Public
reciprocals are constructed only AFTER fresh alpha/beta/gamma, privately in
one attempt. Signed index AND value must match; otherwise unchanged arbitrary
field arithmetic, including dishonest zero pairs. No cross-challenge/table/
tag cache, no private opening or mask reuse. Later ALL public table values
still checked even if unused. Partially written private H on failure must die
before H commit or any later draw/absorb; native lifetime proof is outstanding.

New source census: m125 SC_SZC has15 byte lookups/eight paired helpers and one
exp pair helper. Its sumcheck bracket contains no inversions. Native exp/act
reciprocals still batch over4194304+1048576 occurrences atprotocol908..911.
Table-helper mark says49152 rows but actual calls process256 per family into
zero-padded H; SC_TAB separately expands16k periodic public tables. Do not
interpret mark quantities as extra inversions or cache benefit to SC_SZC.

Seed2026101346, one nice19 CPU0 CoreUltra9 185H thread,59s/512MiB caps;
final0.761940s/31000KiB RSS.203 fixtures/669 chunk schedules/81968 independent
helper words,639 split-plane sentinel checks/3195 count-formula checks,
32 full-table checks/320 words,44 attempt schedules (36 refusals),1601 padded
S/future-position words,21 controls pass. Euclidean direct-coefficient oracle
versus Fermat/native batch model; tables1/4/16/256, columns0..16385,
chunks1/3/7/256/1024, full-extension/beta0/collisions/all-table zeros,
used/unused poles/signed/i64 extremes/altered pairs/stale public/challenges.
No honest witness/native receipt/masked/GPU/privacy or performance evidence.
Initial passing code/result preserved before extension. One accounting-parser
failure (percent selected as time) retained and corrected; arithmetic passed.

Executed all-validN16384: batchmul49152->768,inversions1->1. InvalidN257/K1024:
prior258->2 inversions, versus native1; candidate1539batchmul vs native771.
Short all-valid31 bypass now93batchmul/1inverse vs old768/1; K1 costs31 inverses.
Sparse fallback requires one inverse per occupied INPUT CHUNK, not ceil(U/K).
Conditional native m125 all-hit:15728640->1536 batch products,
5242880->512 literal beta products,2inversions unchanged. H output80MiB,
all polynomials/PCS/masks/witness/tablehelpers remain. Sequential denom+prefix
logical peak128MiB; proposed45360B scratch +2048B activation conversion,
headers/allocator/compiler stack unpriced. Not measured peak/traffic/speed.

Refreshed raw native clocks: pair phase CPU0.199/0.207s, GPU-arm0.202/0.197s;
shared synthetic125M one-blockT512/twoCPUthreads/RTX4070Laptop, not reproduced.
B2:SC_SZC7.794s,prove16.864s,externalwitness5.77s,serialization0.028s,
inprocessbyteverify0.82s,enclosingtest27.523873s,startup unisolated.
Deleting ENTIRE0.197s pair phase bounds1.168%prove/0.715742%testwall savings
(test27.326873s); actual candidate retains costs and may regress. No accepted8B
numeric ceiling: Nproved/(Ttotal-Cpair_old+Cplan+Creads+Cfallback+Cscatter).
Historical12block diagnostic408.609226s wall/318.22s runprover/12.15s inprocess
verify/484107456B lacks fresh independentverification; CLI no terminal result,
no liveness inferred. Neither contributes accepted8B tokens.

Ranked queue (full costs/prerequisites/exactness/privacy/falsification in README):
1owner GPU SC_SZC+recurring witness;2owner exact full-K int16 down;
3NEW nextlocal source-derived whole bracket row coefficients/Horner or finite
sample differences, against current compiled denominators and actual skipped1/
zero-factor fallback, charge convolution/scratch/prep/additions;
4canonical four-reduction Fp2;5symbolic Eq/mixed grouped readers;
6first6 native shift twiddles;7fresh resident complete-pass slope;
8REFINED/DEMOTED bounded pair inverse fallback/directH;9MLE lookup/GKR/PCS.
Parity, source/pad/refusal/order/RNG/transcript/receipt/mask/privacy mismatch,
actual peak failure or enclosing regression falsifies. Large architecture
changes require whole-proof PCS/composition/joint hiding review, not new claims.

Four LIVE qualified records appended240->244. NEW older MLE compatibility
[2024/1058](https://eprint.iacr.org/2024/1058),received2024-06-28/revised2024-12-06,
abstractonly/PDFInternalError, filters lookup-vs-PCS mismatch; no imported speed.
NEW inspected [Plonky3 LogUp source](https://github.com/Plonky3/Plonky3/blob/main/lookup/src/logup.rs)
uses1024-row fused chunks, explicitly calls for tuning; runtimeHEAD/historydate
unknown/historyInternalError. No foreign source copied/executed. NEW recent
[PR2293](https://github.com/Plonky3/Plonky3/pull/2293),merged2026-09-22, distinguishes
must_use warnings from enforced obligations and guards derived schedules;
short exposed commit fetch failed/uninspected. Apache2 text inspected onmain.
Original [LogUp](https://eprint.iacr.org/2022/1530) received2022-11-04/revised
2025-02-20 refreshed; poles/multiplicities do not authorize skipping table zeros.
Current release rc.1/11Oct display year unverified. Exact dates/URLs/license/
commit/access issues and raw queries saved; no bypass or author performance
reproduction. Primary2026 paper searches yielded no additional qualified new
paper for this seam; no paper list padded the result.

[Experiment](experiments/lookup-reciprocal-plan-20261013/README.md),
[costs](experiments/lookup-reciprocal-plan-20261013/cost-accounting.json) and
[low-priority owner handoff](handoffs/20261013-bounded-pair-inverse-fallback.md)
retain source pins, commands, initial/final code/results and uncompiled
pair_helper_into.proposed.rs. Owner reviews/integrates only after compiled
canonical/off-table/collision/pad/lifetime/frozen/masked/refusal/fresh independent
verifier gates; then affected/enclosing/peak A/B under shared locks if useful.
No production/runtime/Git/reviewer/receipt/calibration/gate edit/merge,
build/GPU/install/heavy queue/external message.

Accepted complete private8B proofs/passes/tokens0;proof contextnull;CPUonly.
Steady/total-workload rates,startupseconds/fraction,witness/proof/serialization/
independentverify/latency/lag/drain unmeasured. No prefill/resident/decode proof.
Target>=50 unchanged;larger workloads allowed,attentionT²,freshmasks/privacy/
fullcoverage required. NextLOCAL:row polynomial coefficient pricing and exact
original-cube checks;nextOWNER:dominantSC_SZC/witnessclocks. Rotationsumcheck/
arithmetic next,thencomposition,memory/batching,GPUcommitments/lookup.
Saved progress files are not evidence of notification delivery.


## Cycle 0047 — 2026-10-13 — selective SC_SZC row coefficients

Run `20261013T042555Z-29e31968`, checkpoint 2026-10-13T04:43:37.819277+00:00. AGENDA/current target,
required project/durable files and latest three prior results read/scanned.
Ten startup and eight native pins retained; prior findings/source prefix
preserved; sources249. Research-only CPU lane, no runtime/production/Git/build/
GPU/install/foreign execution/external writes or messages.

The baseline is cycle33's proof-definition-local compiled denominators.
The candidate substitutes `cur+X*dif` into the unchanged full SC_SZC bracket,
computes five coefficients once per row for the padded degree-four group,
and evaluates the original integer samples. Both host groups stay direct;
unpadded profiles stay baseline. Policy and coefficient lengths are public
shape decisions. First convolution contribution initializes an output by
public loop position; no private zero pruning, infinity sample, changed claim,
challenge, degree, relation or mask/opening reuse. Cycle33 remains a prerequisite,
not an integrated native baseline.

128 fixtures /768 schedules pass6,912 independent original-cube samples,
20,736 direct-MLE finals,1,536 arbitrary row values including full-extension
points,948 generic denominators (empty/multiple terms,aliases,zero/negative/
non-unit coefficients),100 convolution values,25 count checks,48 prior loop
census matches and ten controls.2,112 rows,1,080 recoveries,648 explicit
zero-factor fallbacks. Cubes n0..3,ls2/3,both pads,odd/even helpers,
full/base/zero/Boolean values,chunks1/3/7,debug/release sample1. Debug explicitly
compares recovered/computed1. Clause body is identical except arithmetic
carrier. These are arbitrary synthetic clauses, not native honest witnesses,
masks,RNG/transcript,PCS or receipts.5.737249s/17,764KiB RSS,seed2026101347,
one CPU0/nice19 Core Ultra9 thread,59s/512MiB caps. Commands/raw logs retained.

For n23/ls3/padded/release/nonzero recovery, full Fp2 multiplies fall from
2,478,833,399 to2,118,123,271; base multiplies398,458,838 to314,572,765;
adds3,305,111,186 to2,956,983,972; subtracts1,732,247,377 to1,245,708,155.
At inspected native5/2 base products per full/base call, counted base product
removal is14.944357%; field API removal16.163223%. Counts are not native
runtime/instructions/DRAM/end-to-end ceilings. Both census arms retain native
mixed-table loads/differences/interpolation/folds, equality weights and sample
weight products. The algebra fixture's symbolic Eq storage establishes no
native memory behavior. Per-row setup200mul/21mul_base/174add/86sub recurs
every row/round. Five output coefficients80logical bytes exclude carriers,
temporaries,allocator/register/spills. Dispatches566,230,980 to251,658,210.
Debug/no-recovery21.659%/21.680% fractions cannot replace release evidence.
Selected unpadded cases have zero saving.

Useful negatives: initial all-coefficient version passes algebra but increases
API work and regresses unpadded recovery; its initial API denominator omitted
fold subtractions. Final corrected denominator independently matches cycle33.
`failed-leading-coefficient-control/` retains the failed mutation test: deleting
the highest declared coefficient did not change round0 because the public mask
is constant along that axis. Final control checks all rounds and fires later.
No sample was deleted; no private coefficient selects a degree.

[Experiment](experiments/sc-szc-row-polynomial-20261013/README.md), result/cost,
commands/pins/source records and initial/failure artifacts retained.
[Owner handoff](handoffs/20261013-sc-szc-row-coefficients.md) proposes an optional
immutable row factory with per-part fixed5Fp2 output. Actual owner seams:
argument.rs SC_SZC1724/1782/helper894 and grouped.rs part86/sample110.
Native masked/frozen/tagged/refusal/final/extension/RNG/PCS and fresh independent
verifier gates remain. Compiler/copy/scratch/register/spill/peak/enclosing
clocks are unknown. No production patch, Rust/CUDA compilation, integration,
merge or heavy job queued. Whole-proof privacy and P3 remain separate.

Historical b2-gpu: synthetic one-block125M/T512/one pass, RTX4070Laptop8188MiB,
driver566.14,two CPU threads,shared host; witness5.77s, prove16.864s,
encode0.028s, decode0.013s, in-process verify0.806s/frombytes~0.82s,
wall27.523873s, SC_SZC7.794s, receipt40,783,352B. Residual serialization-and-other
4.073873s is neither pure serialization nor startup. Deleting all SC_SZC bounds
historical whole-wall savings to28.317235%; no8B/rate projection follows.
Historical synthetic12blockT5124070:408.609226s total,318.22s run prove,
12.15s in-process verify,484,107,456B,1.253diagnostic positions/s; fresh-process
verification false. Later CLI remains nonterminal; its label is not liveness.
Accepted8B workloadT and isolated bracket critical path remain unknown:
ceiling `N/(T-C_repeated_bracket+C_coefficients+C_horner+C_scratch+C_dispatch)`.
Both witness paths and recurring slope need measurements.

Ranked queue:

| Rank | Question, impact and obligations |
|---|---|
|1 owner|GPU dominant SC_SZC plus recurring witness; high integration/memory cost, exact masked/final/receipt/independent verification, measured peak/enclosing improvement required.|
|2 tested|Selective row coefficients; moderate factory plus prior compiled-plan integration, per-row convolution/Horner/scratch/dispatch. Reject compiler-eliminated opportunity, native sample/final/refusal/privacy mismatch, spills or enclosing regression.|
|3 owner|Exact fullK split-int16down; packing/two products/i64/requant/refusal/transfer/workspace, native phase share unknown. Require integer/profile/receipt/privacy and enclosing parity/gain.|
|4 NEW local next|Suffix-weighted coefficient accumulation before unchanged samples; charge five coefficient weights versus four/five sample weights, part reduction/Horner/scratch/setup. Reject higher total cost or any exact sample/recovery/zero-factor/final mismatch.|
|5 local|Four-reductionFp2/publicEq mixed readers remain pending native canonical/masking/representation/peak/clock gates.|
|6 workload|Fresh resident complete-pass startup/slope; measure context/pass/concurrency, lag/drain/serialization/verification and fresh masks. Recurring cost>20ms/new proved position falsifies50/s for that schedule.|
|7 demoted|Bounded pair fallback remains a memory/robustness candidate with only0.716% prior phase-removal ceiling.|
|8 architecture|GKR/MLElookup/PCS composition requires costed relation/setup/field/transcript/joint-hiding/whole-proof soundness redesign.|

LIVE five qualified records: NEWolder2021 coefficient framework receivedMar14,
revisedJun9; refined EPFL factory/EvalsInfty boundary and displayedJune24 history;
September4 monomial methodology and April17 projective paper; NEWOctober10
Hekate0.12.1 primary-search package metadata (conflicting older direct snapshots,
no current HEAD claim); March24 extended product paper refresh. Exact URLs,
license declarations, uninspected commit prefixes, unknown runtime dates,
PDF403/code/commit/license/tag Cache miss/Internal Errors retained. No author
performance or formal verification/security claim reproduced. Binary-field
public table-math timing cannot transfer to prime-field/private arithmetic.
Rotation next: composition, memory/batching, GPU commitments, lookup/arithmetic.

Accepted independently verified complete private8B proofs/passes/tokens:0;
context null/deviceCPU only. Steady/total-workload rates, startup seconds/fraction,
witness/proof/serialization/independent verification, latency/lag/drain unmeasured.
No long prefill,resident pass or decode proof. >=50/s unchanged; larger workloads
allowed, with quadratic attention, fresh masks, complete coverage/privacy.
Saved reports are not evidence of user-message delivery.

Next LOCAL: coefficient accumulation against this hybrid with independent cube
samples,ragged parts,debug/release1 recovery,zero-factor fallback,ordered finals
and every coefficient weight/part reduction/setup/Horner/scratch cost. Next
OWNER: native fixed arrays,byte/refusal/extension/fresh-verifier gates,then
shared-lock peak/enclosing A/B with both witness and SC_SZC subphase clocks.


## Cycle0048 — 2026-10-13 — suffix-weighted coefficients before samples

Run `20261013T052555Z-bb2755b6`; checkpoint2026-10-13T05:41:25.005992+00:00. AGENDA, current throughput target,
required durable/project memory read/scanned;12 startup snapshots and8 native
pins retained, latest three prior result hashes saved. Sources249 to253.
Earlier findings/negative results remain append-only and snapshotted.

**Synthetic candidate passes; no native proving time gain.** Baseline is
cycle47 selective padded row coefficients. Sum suffix-weighted group0
coefficients in five existing part slots, reduce, then evaluate unchanged
integer samples once per round. Group factors, host groups, table scan/steps,
folds/finals, recovery and explicit zero-factor fallback are retained.
Public half>=2/padded selection retains singleton/unpadded baseline.
No private coefficient inspection, trimming, wire/sample/degree/challenge/RNG
change or private blinding/opening/plan reuse is introduced.

128 fixtures/1,536 schedules pass13,824 independent original-cube samples,
41,472 ordered direct-MLE finals,60 arbitrary weighted-polynomial values,
144 executed counter/census comparisons and seven mutation/lifecycle controls.
2,124 recoveries,1,332 explicit zero-factor fallbacks; debug verifies computed
sample1. Logs, seed2026101348, source pins, commands, limits, exact initial
revision and final run retained. CPU-only one nice19CPU0 CoreUltra9 thread:
10.936208s/20,788KiB;59s/512MiB caps, estimate64MiB. No native/GPU/proof/mask
or independent receipt verification ran.

Illustrative n23/ls3/padded/release:1.906537% counted base products and
3.413346% field API operations removed relative to cycle47. Add4,194,302
full coefficient-weight products; Horner base products117,440,500 to280.
Same89,958 modeled binary part-reduction additions. Row construction remains
paid per row/round. Five Fp2 coefficient outputs replace five sample outputs:
80logical bytes per part, no additional output slots; row scratch remains.
Allocator/carriers/flags/registers/spills/thread scratch/peak/identity reductions
unmeasured. Combined16.565974% base-product census versus cycle33 compiled
denominators is not a runtime prediction. All384 shape/schedule cost cases
retained; unpadded selection has zero counted saving.

Useful negative: unconditional singleton reduction has equal algebra but adds
one full multiply and one add when sample1 is recovered (five base products).
Executed regression retained; public shape fallback avoids it. Initial passing
version only counted zero-factor schedules; final adds nonzero recovery counter
checks and actual singleton regression. Initial source reconstruction exactly
matches its original command hash; evidence preserved.

[Experiment](experiments/sc-szc-weighted-coefficients-20261013/README.md) and
[owner handoff](handoffs/20261013-sc-szc-weighted-coefficients.md) identify
argument.rs SC_SZC1699/groups1783/adapter553 and grouped.rs part93/sample107/
reduction121/recovery132. Optional immutable fixed5Fp2 factory and typed
coefficient reduction require cycle47 factory and compiled-plan review first.
Python tested; Rust sketch uncompiled. Native masked/frozen/tagged/refusal/
final/extension/RNG/PCS/fresh-independent-verifier, compiler/peak/spills and
enclosing workload gates remain. Main/Claude reviews and integrates; nothing
merged or queued here. P3/joint privacy/whole-proof soundness stay separate.

Historical one-block125M/T512/one-pass RTX4070Laptop:SC_SZC7.794s,
prove16.864s,witness5.77s,encode0.028s,decode0.013s,in-processverify0.806s,
whole-test27.523873s,40,783,352B. Encode is not full serialization; startup
boundary/fraction and both recurring witness paths are unmeasured. Entire
SC_SZC removal caps historical whole-wall savings at28.317%; no conversion
of count percentage to seconds or accepted8B rate. Synthetic12blockT5124070
408.609226s total/318.22s prove/12.15s in-process verify/484,107,456B remains
outside accepted8B evidence; fresh-process verification false. Nonterminal
later CLI saved state does not imply liveness. Actual complete ceiling:
`N/(T-C_per_row_sample_Horner_and_weight+C_weighted_coefficients+C_round_Horner+C_changed_reduction_and_scratch)`;
accepted8B critical-pathT and affected clocks unknown.

Ranked queue:

|Rank|Hypothesis, costs, prerequisites and falsification|
|---|---|
|1 owner|GPU dominantSC_SZC+recurring witness; high CUDA/memory cost. Measure both witness paths and actual complete/peak/receipt/fresh-verifier scope; reject mismatch or enclosing regression.|
|2 tested chain|Selective row factory+weighted coefficient reduction; moderate fixed-array/typed driver and compiled-plan prerequisite. Charge convolution,extra weights,scratch/reduction/Horner. Reject native sample/final/refusal/privacy/bytes/RNG/PCS mismatch or slower enclosing workload.|
|3 NEW local next|Public-axis specialization: use actual mask/support dependency metadata to simplify row construction on structurally constant leading axes. Charge public dispatch/carriers; retain fixed declared outputs/all samples and original folds/finals. Reject private-value branch, extension-oracle mismatch or larger setup/count/peak.|
|4 owner|Exact fullKint16down; packing/two products/i64/requant/refusal/transfer/workspace. Affected native clock unknown; integer/profile/privacy/receipt/enclosing parity and gain required.|
|5 workload|Fresh resident complete-pass slope: context/pass/concurrency,startup fraction,latency/lag/drain,serialization/independent verification. Complete recurring cost>20ms/new proved position rejects50/s for schedule; no mask/opening reuse.|
|6 architecture|GKR/MLElookup/PCS composition high relation/quantization/setup/final-oracle/joint-hiding/soundness migration cost; author public-input operator aggregates cannot establish target.|

LIVE sources materially refine coefficient reduction/wire boundary and full-text
zkLLMPoT composition/public-input/operator-aggregate scope; NEWOct11Plonky3
rc metadata (stable0.8 inspected,rc source failures); NEWolderMay2013Allspice
static public cost selection/protocol-specific batching. ExactURLs, verified
month/dates,license declarations/text,unknown commits and InternalError blockers
retained in four records. Foreign code not downloaded/executed; author timing,
formal verification/security claims not reproduced. Rotation next memory/
batching,then GPU commitments,lookup/softmax,quantization/arithmetic.

Accepted independently verified complete private8B proofs/passes/tokens:0.
Proof contextnull/deviceCPU only. Steady/total-workload rates,startup duration/
fraction,witness/proof/serialization/independent verification,latency/lag/drain
unmeasured. No long-context prefill,resident pass or decode proof. Larger
workloads allowed with quadratic attention accounting,fresh masks,complete
coverage/privacy;>=50/s unchanged/unachieved. Saved reports are not delivery.
NextLOCAL: actual public-axis dependency row-factory specialization with
extension/counter controls. NextOWNER: native fixedarrays,masked/refused/frozen/
final/extension/fresh-verifier gates,then shared-lock peak/enclosing A/B with
both witness and SC_SZCsubphase clocks. No production/runtime/Git write,
build/GPU,install/downloaded execution/external action or heavy job queued.


## Cycle0049 — recovered public-axis result, reported2026-10-14

Run `20261013T073440Z-ac1df939` completed its experiment on2026-10-13
07:43:25UTC but left STATE in progress and no final findings/progress report.
Cycle50 recovered its original result/exit/source hashes without rerunning or
editing evidence. Original source hashes all recheck. No uncheckpointed LIVE
search or delivery is inferred; sources remained253records at cycle50 startup.

Baseline cycle48 weighted coefficients. Public immutable mask/support axis
dependencies remove structurally zero slope carriers while retaining all
five output slots, original samples/folds/finals and private-valued slopes.
52fixtures/312schedules pass3,240independent cube samples,8,640direct finals,
40arbitrary full-clause extension values,84conservative dependency checks,
4native logical-head enumerations and8value-independent schedule checks.
Five negative controls reject forced-constant causal mask,swappedHt/S axes,
bit-order reversal,private-role metadata and contiguous-head-prefix layout.
546recoveries/354zero-factor fallbacks.7.537997s,20,508KiB,one nice19
CoreUltra9CPU thread,59s/512MiB caps. This is synthetic algebra, not proof time.
Illustrative hp16/kv4/qh12/T512/3limb count removes6.931212% base products and
5.284612% field API versus cycle48; charge12,582,909public axis tests,
fixed-output zero assignments,metadata and unknown native scratch/spills/time.

Recovered report: `progress/20261013T073440Z-ac1df939.md`. Cycle50 handoff
includes this prerequisite. No native performance or privacy gain established.
Accepted complete private8B proofs/passes/tokens0;rates,context,startup,
witness/proof/serialization/independent verification unmeasured;CPU only.


## Cycle0050 — 2026-10-14 — fixed affine Karatsuba and an API-cost negative

Run `20261014T203626Z-4afb917a`; checkpoint2026-10-14T20:43:41.891147+00:00. AGENDA/current throughput target,
required durable/project memory and latest three results inspected/snapshotted;
all253starting source records parsed; four LIVE source records appended.
Ten current native/measurement pins match cycle49; earlier negative findings
and interrupted CLI state remain preserved. No job liveness is inferred.

Baseline cycle49 public-axis row factory. For public coefficient width2x2,
replace schoolbook4mul+1add with3mul+2add+2sub. This exact ring identity
retains declared widths,original samples,recovery/fallback,folds and finals.
Selection uses public expression widths only; no private-value tests,degree
pruning,mask/opening reuse or protocol/PCS/transcript/RNG change. The tested
global switch is single-thread harness scaffolding, not a native interface.

100fixtures/600schedules pass5,832independent cube samples,16,272ordered
direct-MLE finals,300independent convolution values,40full-clause arbitrary
extension values,600executed row-census checks and8zero/random schedule checks.
876recoveries/672explicit zero-factor fallbacks.75public width cases include
1..5coefficients,zeros,boundaries and full extension values; even/odd lookups,
ragged parts,debug/release recovery,padded/unpadded fallback and logical-head
fixtures remain. Four deliberate arithmetic mutation detections and a
value-independent schedule assertion pass. Executed delta:17,340fewerFp2mul,
17,340moreFp2add,34,680moreFp2sub. Runtime8.321726s,peakRSS21,972KiB,one
nice19CoreUltra9CPU thread;59s/512MiB caps,64MiB estimate. No native/GPU proof.

**Useful negative:** illustrative hp16/kv4/qh12/T512/3limb count drops
51,904,500Fp2mul but adds51,904,500adds and103,809,000subs. Base-product
API calls5,121,506,608to4,861,984,108(-5.067308%); total field API
3,035,147,955to3,138,956,955(+3.420229%).226,492,362generic public width
tests are charged separately. Across six shape/limb cases base-product saving
4.9514–5.1328%,API increase3.3342–3.4859%. Five-productFp2 baseline includes
the constant7 product; compiler lowering and prior unintegrated4-reduction
arithmetic can alter real benefit. Output80logical bytes unchanged; temporary
liveness,code size,carriers/registers/spills,peak and enclosing clocks unknown.
Reject unconditional promotion from lower products. Break even requires
`C_Fp2mul > C_Fp2add + 2*C_Fp2sub + marginal dispatch/scratch`.

[Experiment](experiments/affine-karatsuba-20261014/README.md) and
[handoff](handoffs/20261014-affine-karatsuba.md) retain command,seed,source/
native/result hashes,controls,per-round census and review-only Rust sketch.
Actual Rust seam is SC_SZC argument.rs1699/groups1783/bracket1788,helper894,
and grouped.rs part93/sample107/reduction121/recovery132. It first needs the
optional fixed-array factory/weighted-driver/compiled-plan chain translated
and reviewed. Python passed; Rust sketch uncompiled. Native masked/frozen/
refusal/final/extension/RNG/PCS/fresh-independent-verifier,compiler/peak and
guarded enclosing A/B gates remain. Main/Claude reviews/integrates; no merge.

Historical one-block125M/T512/onepass RTX4070Laptop:SC_SZC7.794s,
prove16.864s,witness5.77s,encode0.028s,decode0.013s,in-processverify0.806s,
whole-test27.523873s,40,783,352B. Encode is not full serialization; startup
boundary/fraction and both recurring witness paths remain unmeasured.
EntireSC_SZC removal caps that historical whole wall saving28.317%, not an8B
rate or a scaling factor for these counts. Synthetic12blockT5124070 run:
408.609226s total,318.22s prove,12.15s in-processverify,484,107,456B;
fresh-processverification=false,trained=false,privacyaccepted=false. LaterCLI
saved nonterminal state is not a completed proof or liveness evidence. Actual
complete ceiling `N/(T_complete-C_products+C_add_sub_dispatch_scratch)` is
unmeasured because accepted8B critical-path and affected phase clocks absent.

Ranked hypotheses after this cycle:

|Rank|Expected end-to-end impact, cost/compatibility and falsification|
|---|---|
|1 owner|GPU dominantSC_SZC plus both recurring witness paths; highest measured phase opportunity,high CUDA/memory integration. Require exact masked/final/refusal/receipt/independent verification and measured peak/enclosing gain. Reject mismatch or enclosing regression.|
|2 tested conditional|Fixed2x2Karatsuba within reviewed row-factory chain; modest count opportunity,moderate translation,extra adds/subs/dispatch/scratch. Reject native exactness/privacy/bytes/RNG/PCS mismatch or cost inequality/enclosing regression. Count savings alone insufficient.|
|3 NEW local refinement|Public static multiplication schedule,including3x2blockedKaratsuba: remove repeated width tests and possibly another product; charge fixed-plan construction/code size,combination adds/subs,scratch. Prerequisite current factory; no hidden-value dispatch. Reject extension/cube mismatch or worse weighted cost.|
|4 owner|ExactfullKsplit-int16down; packing/two products/i64/requant/refusal/transfer/workspace. Native affected clock unknown; require full integer/profile/privacy/receipt and enclosing parity/gain.|
|5 workload|Fresh resident complete-pass slope,context/pass/concurrency,startup fraction,latency/lag/drain/serialization/independent verification and fresh masks. Recurring complete cost>20ms/new proved position rejects50/s for that schedule. Long context also charges quadratic attention.|
|6 architecture|GKR/MLElookup/PCS composition,high relation/field/quantization/setup/final-oracle/joint-hiding/soundness migration cost. Reject operator aggregates or public-input proofs as target evidence.|

LIVE search adds older HyperPlonk receivedOct10,2022/revisedDec21,2023 with
author-slide coefficientKaratsuba technique (slide date unknown; PDF fetch
failed). Plonky3Oct11rc exact release/Cargo version diff now inspectable at
5b23a4fbf7768136797f52263e4ae0bef3841dfe; PR2305Sep23 equality-table
traffic and PR2260Sep20 cryptographic mask-sampler bounds refine next gates.
Release commit is inspected manifest scope,not entire implementation. MIT
text on main and workspaceMIT/Apache declaration inspected; pinned license
and two merge-commit fetches InternalError. Matched-hardwareJune15 paper is
255-bit simulator/synthesized-engine work,not5090 performance. ICICLELatest
displayedv4July11 year unverified;mainMIT inspected. All source author runtime,
test/security claims remain unreproduced;foreign code not downloaded/executed.
Rotation next:memory/batching/GPUcommitments,lookup/softmax,quantization,
composition. Preserve earlier slower native fusion and denominator-count negatives.

Accepted independently verified complete private8B proofs/passes/tokens0.
Proof contextnull,CPU only. Steady/total rates,startup duration/fraction,
witness/proof/serialization/independent verification,latency/lag/drain
unmeasured. No long-contextprefill,resident pass or decodeproof. Larger
workloads permitted with quadratic attention,fresh masks and full privacy/
coverage;>=50/s unchanged/unachieved. Saved reports do not prove delivery.
NextLOCAL: static public multiplication plan3x2with independent convolution/
full-clause/cube controls and weighted costs. NextOWNER: native fixedarrays,
masked/frozen/refusal/fresh-verifier gates,then guarded subphase/peak/enclosing
A/B. No production/runtime/Git writes,build/GPU,install,external action or job queued.



## Cycle0051 — 2026-10-17 — public static plans and blocked3x2 cost tradeoff

Run `20261017T012624Z-ea61e714`; checkpoint 2026-10-17T01:33:28.468923+00:00.
Read AGENDA/current target,durable/project memory and latest three results;
snapshots and parsed257-source inventory retained. All10current native/
measurement pins match cycle50. Four LIVE primary-source records appended,
now261. No newer complete-proof result or job liveness is inferred.

Baseline: cycle50 public-axis/suffix-weighted coefficient factory with fixed
2x2Karatsuba. Question: can public static schedules extend multiplication to
3x2 while accounting for dispatch,preparation and temporary costs? A public
canonical-zero bracket trace,with no actual witness,records operand widths;
immutable multiplication plans are cached by public axis-dependency pattern
within a proof-definition object. Width3x2/2x3uses5Fp2mul+3add+2sub instead
of6mul+2add. Other widths retain cycle50 arithmetic. Declared output widths,
original samples/folds/finals,recovery and singleton fallback are unchanged.
No coefficient-value/degree pruning,mask/opening reuse or native protocol,
transcript,RNG/PCS change is introduced. Python adapter is single-thread test
scaffolding; native static helper/unrolling is a separate owner obligation.

100fixtures/600schedules pass5,832independent original-cube round samples,
16,272direct-MLE finals,400independent convolution values,40arbitrary
extension full-clause values,600executed row-delta checks and8zero/random
schema+count controls.888recoveries/660explicitzero-factor fallbacks;
even/odd lookups,raggedchunks1/3/7,debug/release,padded/unpadded and logical
head fixtures covered. Five arithmetic/order mutation detections and the
value-independent schedule assertion pass. Executed row delta:-10,452Fp2mul,
+10,452adds,+20,904subs. Final run 12.121455s/23,164KiB
RSS,one nice19CoreUltra9CPU thread;59s/512MiB caps,64MiB estimate. Initial
passing run retained; final refinement counts actual replayed field operations
and interpreter opcode steps instead of copying the plan's aggregate counts.
This is synthetic algebra/accounting,not proof time or a native speed result.

**Useful negatives:** illustrative hp16/kv4/qh12/T512/3limb removes30,670,839
Fp2mul but adds30,670,839adds+61,341,678subs. Base products4,861,984,108to
4,708,629,913(-3.154148%); total field API3,138,956,955to3,200,298,633
(+1.954206%). Across six shape/limb cases base saving2.9041–3.1541%,API
increase1.8075–1.9542%. Counts include all earlier factory/weighting work;
only the delta is attributable to this cycle. Five-base-productFp2mul is the
pinned source/API model,not a measured machine instruction count.

Repeated width tests are **replaced**,not automatically eliminated. T512
baseline226,492,362width tests become226,492,362plan cursor reads plus
4,194,303public-pattern lookups and1,042,546,425interpreter opcode steps.
Preparation traces3patterns,162width classifications,61base-scales,
482adds,559mul,248subs,90denominator-dispatch steps and9axis tests. Logical
pointer plan1,296bytes+512SSAbytes; actual Python representation is larger.
Output80logical bytes unchanged. Kernel liveness model5intermediate field
words excludes inputs and full-row state; interpreter retains15words per
multiplication. Other projected shapes need2–4patterns,784–1,728pointer bytes,
512–664IRbytes,5–6modeled live intermediate words,15–17retained field words.
Native code size,temporaries/registers/spills and enclosing/peak clocks unknown.

Break even: each blocked product must save more multiplication time than one
add+two subs plus the net trace/plan/dispatch/code/scratch cost. Reject native
sample/extension/final/refusal/bytes/RNG/PCS/privacy mismatch or enclosing
regression. Count reductions alone do not justify promotion. Actual complete
ceiling `N/(T_complete - saved_product_time + added_arithmetic_schedule_time)`
is unmeasured because accepted8B critical-path/affected clocks are absent.
The historical entireSC_SZC-removal ceiling28.317% is only an upper bound on
one125M/T512/onepass RTX4070Laptop whole-test saving,not a scaling factor for
these counts or an8B speed estimate. Preserve prior slower native fold-fusion.

Current historical context remains: one synthetic125M block,T512,RTX4070
Laptop/proof16.864s,witness5.77s,encode0.028s,decode0.013s,in-processverify
0.806s,whole-test27.523873s,SC_SZC7.794s,40,783,352B. Encode does not measure
all serialization; startup boundary/fraction and both witness paths unknown.
The synthetic12block/T512/onepass GPU test is408.609226s total,318.22sprove,
12.15sin-processverify,484,107,456B; trained=false,privacyaccepted=false,
fresh-processverification=false. Its1.253diagnostic positions/workloadsecond
is not accepted private8B throughput. CLI report remains nonterminal saved
state; no completed proof or live process is inferred from it.

[Experiment](experiments/static-poly-plan-20261017/README.md) and
[owner handoff](handoffs/20261017-static-polynomial-plan.md) retain exact
commands,seed,source/native/result hashes,controls and uncompiled Rust sketch.
Actual seam: SC_SZCargument.rs1699/groups1783/bracket1788/helper894 and
grouped.rs part93/sample107/reduction121/recovery132. First translate/review
the optional fixed-array factory/weighted/compiled-denominator chain. Native
masked/frozen/refusal/extension/final/RNG/PCS/fresh-independent-verifier and
guarded subphase/peak/enclosing A/B gates remain; main/Claude integrates.

Ranked hypotheses after this cycle:

|Rank|Expected end-to-end impact, prerequisites/costs and falsifier|
|---|---|
|1 owner|GPU dominantSC_SZC+both recurring witness paths; highest measured phase opportunity,high CUDA/memory integration cost. Preserve exact relation,masks,refusals,receipts and fresh independent verification; reject mismatch,peak overflow or enclosing regression.|
|2 tested conditional|Public fixed-array factory+weighted reduction+2x2/3x2helpers; modest count opportunity,moderate translation,extra arithmetic/plan/code/liveness. Reject break-even failure or native bytes/RNG/PCS/privacy/enclosing mismatch. Interpreted plans are not a dispatch speedup.|
|3 NEW local refinement|Whole-row SSA reuse by public expression identity: share affine sums and specialize structural squares. Prerequisite current public plans; charge graph setup,extra live values/code and instruction dispatch. Never compare private values for CSE. Reject extension/cube/final mismatch,private-dependent schedule or worse weighted cost/liveness.|
|4 owner|ExactfullKsplit-int16down; potential recurring witness saving but affected native clock unknown. Charge packing,two products,i64/requant/refusal,transfers/workspace; require exact full-range/profile/privacy/receipt parity and enclosing gain.|
|5 workload|Fresh resident complete-pass startup/slope; count independently verified newly proved positions,context/pass/concurrency,latency/lag/drain/serialization. Recurring completecost>20ms/new position rejects50/s for that schedule; no mask/private-opening reuse. Long context charges quadratic attention.|
|6 architecture|Reusable sparse GKR/lookup/PCS composition; potentially high but unknown full-stack effect,high relation/field/quantization/setup/final-input/joint-hiding migration cost. StateSync's external-wrapper privacy and sparse-MerkleCPU numbers do not transfer. Reject public-input/operator aggregates as target evidence.|

LIVE sources searched: NEWolder Roche July24,2009public code-generation/
scratch technique; NEWPlonky3October16rc.2 and September22immutable-plan PR;
NEWStateSync-GKROctober10paper/repository; Expanderrelease/date/license refresh.
Primary URLs,publication/update evidence,license scope and fetch failures are
in `sources-cycle51.json`/sources.jsonl. Plonky3release commitfe5e46d and
PRmerge7458be8 fetch InternalError; exact sumcheckrc.2 package also fails,
while sibling rc.2 packages explicitly dateOctober16,2026. Current mainMIT
text inspected; release-specific terms uninspected. StateSync currentBSL1.1
text inspected; <=1.1.0permissive status is README claim,not a pinned license.
Its paper source1b8d2f829792172b347dedbfde969016c2c05789fetch Cachemiss;
no inspected commit ID or author test/runtime/formal/security reproduction.
Expander'sLatest is January21,2026testdata,not a newGPUprover release; AGPLv3
maintext inspected. All foreign source text treated as data; no downloaded
code executed. Rotation next:lookup/softmax,memory reuse,quantization,GPU
commitments and proof composition. Sources inform gates,not acceptance.

Accepted independently verified complete private8B proofs/passes/tokens0.
Proof contextnull/deviceCPU only this cycle;steady-state/total-workload rates,
startup seconds/fraction,witness/proof/serialization/independentverification,
latency/lag/drain unmeasured. No long-contextprefill,residentpass or decode
proof. >=50/s unchanged/unachieved;larger workloads allowed with quadratic
attention,fresh masks and complete coverage/privacy. No production/runtime/
Git writes,build/GPU/install/downloaded execution/external action or heavy
job queued. Saved reports do not establish user-message delivery or liveness.
NextLOCAL: whole-row public expression identity/square reuse differential and
setup/liveness census. NextOWNER: reviewed fixedarrays/full proof gates,then
shared-guard SC_SZCsubphase/bothwitness/peak/enclosing A/B.


## Cycle 0052 — 2026-10-17 — public row CSE: no multiplication saving

Run `20261017T022624Z-f3bec81b`; checkpoint 2026-10-17T02:34:59.488164+00:00. AGENDA/current throughput target,
durable/project memory and latest three results inspected/snapshotted;
261 starting source records parsed, three LIVE primary records appended (264).
All ten native/measurement pins match cycle51. Main status updated02:20UTC
reports work resumed without a new proof; trained-profile D24 is proposed,
not accepted. Existing native/profile/calibration owners retain their lanes.

Tested whole-row expression sharing and affine coefficient-square specialization
against cycle51's public-axis/weighted/static multiplication factory. Symbolic
compilation receives public layout/dependency/input labels only. Challenges,
prepared denominator offsets and pad weights are distinct runtime public
slots. No hidden-value comparisons, degree pruning, new refusal, mask/opening
reuse or native transcript/RNG/PCS change. Four ablations: prior factory,
raw graph, graph CSE, CSE+direct affine square. The raw graph exactly matches
the prior coefficient-operation counts in256cases and every projected round.
Native PadTerm::add already precomputes pad weights:14proof-local products
are charged separately, not claimed as a new recurring saving.

100fixtures/600schedules pass5,832independent original-cube round samples,
16,272ordered direct-MLE finals,1,024arbitrary-extension clause values,
256raw/prior counter matches and256zero/random schema+count matches.
There are912recoveries and636explicit zero-factor fallbacks. Coverage:
2/3remainder limbs,1/2probability limbs,lookup counts1..8,all8public-axis
patterns,zero/full-extension/Boolean fixtures,raggedchunks1/3/7,debug/release,
padded/unpadded and logical heads. Sign/tail mutations are independently
caught; distinct equal-valued symbolic inputs do not become a square, and
changing one still yields the independent product. Final exit0,
seed2026101752, 24.749455s, 28,664KiBRSS,
one nice19CoreUltra9CPU thread;59s/512MiB caps,64MiB estimate. Initial
passing run retained; final refinement labels serialized JSON bytes accurately
and counts compiler product visits. No native/GPU proof or speed result.

**Useful negative:** no Fp2mul or mul_base saved. At illustrative
hp16/kv4/qh12/T512/3limb, CSEalone removes12,845,052adds; direct square adds
back4,194,303adds and removes8,388,606subs. Combined save8,650,749adds+
8,388,606subs; total field API3,200,298,633to3,183,259,278(-0.532430%).
Base products4,708,629,913unchanged. Across6illustrative cases API saving
0.529919–0.590470%; weighted wall-time fraction unknown. Executed small
fixture delta:-2,976adds/-2,688subs/zero multiplication change.

Added costs:3public pattern graphs compile162coefficient products through
1,465symbolic operator visits. Graph JSON30,268bytes (raw30,460); actual
Python object overhead larger. Fixed-trace live-word model including inputs,
literals and outputs rises119/121/122to120/122/123. Interpreter retains
590/612/619words. Replay pays4,194,303pattern lookups and1,996,226,061
arithmetic opcode steps; native direct code/registers/spills/peak unknown.
LLVM may already CSE. Demote a general whole-row graph implementation;
retain direct square cleanup only as an optional part of an already-owned
factory translation, subject to native measurement. Prior slower native
fusion and extra-operation negatives remain. Falsify on oracle/schema/native
bytes/refusal/RNG/PCS/privacy mismatch or added costs erasing saved adds/subs.

**New scope finding / next local question:** can the research factory represent
native optional supports exactly before estimating trained-shape costs?
Native B::supp(argument.rs810)returns None for full Ht/S domains; Gate978
supplies ONE; PadTerm934omits those groups. Inherited6case projections
still build both symbolic padded groups, including full-head/full-token
qh32/T512. Their scalar counts are illustrative, not exact native8B layouts.
Port independent optional Ht/S gate metadata and omitted-group controls next.
This corrects the research port; native already removes absent groups, so
there is no new native saving to claim. Existing padded examples remain valid
as synthetic formulas. A legacy synthetic factory is not the native profile.

Actual seam: SC_SZCargument.rs1699/groups1783/bracket1788 and grouped.rs
row93/sample107/reduction121/recovery132 under sonnet-hardening. Candidate,
commands,source/native/result pins and owner disposition:
[experiment](experiments/public-row-cse-20261017/README.md),
[handoff](handoffs/20261017-public-row-cse.md). Native masking/frozen/refusal/
final/extension/RNG/PCS/fresh-independent-verifier and guarded subphase/peak/
enclosing gates remain; main/Claude integrates, no merge here.

Baseline clocks unchanged: one synthetic125M block,T512,onepass,RTX4070
Laptop,SC_SZC7.794s,proof16.864s,witness5.77s,encode0.028s,decode0.013s,
in-processverify0.806s,whole-test27.523873s,40,783,352B. Encode excludes
some serialization; startup/both recurring witness clocks are absent.
EntireSC_SZC removal caps that historical whole-test saving28.317%,not an8B
ceiling or a scale factor for this count saving. Synthetic12block/T512/
onepassGPU:408.609226swhole,318.22sprove,12.15sin-processverify,
484,107,456B;trained=false,privacyaccepted=false,fresh-processverify=false.
LaterCLI nonterminal saved state is not completion/liveness evidence.
Actual accepted8B ceiling `N/(T_complete-saved_add_sub_time+
added_compile_dispatch_spill_time)` is unknown. Larger workloads cannot
amortize away recurring cost, although setup and initial prefill can amortize.

Ranked queue (expected end-to-end relevance, prerequisites/costs and falsifiers):

|Rank|Hypothesis and next gate|
|---|---|
|1 owner|GPUdominantSC_SZC plus both recurring witness paths; largest measured phase opportunity,highCUDA/memory integration. Exact masking/refusal/final/receipt/independent verification and measured peak/enclosing gain; reject mismatch/overflow/regression.|
|2 local NEW|Exact optional Ht/S support metadata and native-shaped row-factory census before further micro-optimizations. Small/medium port+independent-oracle cost; no native saving promised. Reject any changed sample/final/refusal or count credited to already-omitted native work.|
|3 conditional owner|Existing fixed-array/weighted/denominator/2x2+3x2chain; modest arithmetic opportunity,extra adds/subs/code/scratch. Require native tests then affected/enclosing clocks. Reject break-even/native privacy/bytes/RNG/PCS failure.|
|4 workload owner|Resident complete-pass startup/slope at fixed context and fresh masks; include both witnesses,serialization,proof lag/drain and independent verification. Recurring completecost>20ms/new proved position rejects50/s for that schedule. Long prefill chargesquadratic attention; repeatedpasses are distinct fromdecode.|
|5 owner|ExactfullKsplit-int16down projection; unknown affected witness fraction,packing/two products/i64/requant/refusal/transfer/workspace costs. Reject integer/profile/receipt mismatch or enclosing regression.|
|6 demoted tested|Whole-row CSE/directsquare:no multiplication saving,only~0.53–0.59%API and one more modeled liveword. General interpreter is unjustified; optional direct helper only if native compiler/enclosing evidence supports it.|
|7 architecture|ReusableGKR/lookup/PCS composition; potentiallylarge but unknown,end-to-end relation/field/quantization/hiding/statebinding migration costs. DeepProve's approximate normalization and Plonky3's binary components are not native exact private proofs.|

LIVE sources: NEWolder haggies(arXivv1July21/v2July29,2009)CSE/lifetime
technique; NEWspecific Plonky3compiled-componentPR2292mergedSep22,2026
and October16rc.2release refresh; DeepProvesoftmax fixed-table/exactness filter.
Primary URLs,dates,license scope,unknown commits and exact fetch failures
retained in sources-cycle52.json. Current Plonky3MIT and DeepProvecustom
license texts inspected; no foreign code copied/executed. PR/release commits
failed InternalError/Cachemiss; no inspected commit claimed. Current rc.2
full-year date relies on prior verified sibling metadata,fresh fetch failed.
Author benchmarks,byte identity,test/security claims not reproduced. Rotation:
nextquantization/arithmetic,GPUcommitments,composition; preserve scope filters.

Accepted independently verified complete private8B proofs/passes/tokens0/0/0.
Proof contextnull;deviceCPUonly. Steady/total rates,startupseconds/fraction,
witness/proof/serialization/independentverification,latency/lag/drain
unmeasured. No long-prefill,residentpass or decodeproof. >=50/s unchanged/
unachieved;largerworkloads allowed withquadratic attention,freshmasks/full
coverage/privacy. No production/runtime/Git writes,build/GPU/install/foreign
execution/external action or heavyjobqueued. Saved reports do not prove
message delivery or supervisor/job liveness. NextLOCAL: optional-support port
and differential/census. NextOWNER: current native profile gates,then guarded
SC_SZCsubphases/bothwitness/peak/enclosing clocks.

Checkpoint artifact audit:76 checks passed; current measured source/native pins,
result accounting, prior findings/source preservation and dated report parity
verified. No additional experiment or native performance check is implied.


## Cycle 0053 — 2026-10-17 — correct optional supports before estimating gains

Run `20261017T032624Z-1d6d29cb`; checkpoint 2026-10-17T03:38:04.897645+00:00. Read and snapshotted
AGENDA, the current target, durable/project memory and the latest three results.
Parsed264 starting source records; appended5 LIVE records, now269. Ten prior
native/measurement pins match cycle52; layout.rs is a new eleventh pin. Main
02:20UTC status reports resumed work without a new proof; D24 remains proposed.
Native/profile/calibration owners retain their lanes.

**No native speedup established.** Corrected independent optional Ht/S support
metadata in scalar, coefficient, expanded tuple-ring and graph ports. Native
B::supp returnsNone for full domains; Gate suppliesONE; PadTerm omits absent
groups. pad_on derives from hosted zero-rule planes and controls extra
challenges and declared degrees. Full hp32/kv8/qh32/T512 without S lift has
no supports or pad_on: bracket degrees3/1/1, outer degree4 and five original
samples. Padded degrees4/2/2 retain outer degree5 and six samples. No values
select a degree, schedule or privacy exception.

100 fixtures /600 schedules pass5,520 independent original-cube round samples,
14,532 ordered direct-MLE finals,384 arbitrary-extension clauses,144 zero/random
graph schemas,208 independent padding weights and924 public shape cases.
876 recoveries and636 explicit zero-factor fallbacks occur. Coverage includes
cube logs0–4,2/3 remainder limbs,lookup counts1/2/7/8,all four abstract presence
pairs,full-extension/zero/Boolean values,chunks1/3/7,debug/release recovery and
four independently enumerated h/t/j shapes. Controls catch Ht/S substitution,
restarted zeta powers,gated LogUp helpers and deleted present supports;bad
metadata refuses. Final exit0,seed2026101753,16.309020s,25,428KiB RSS,one nice19
Core Ultra9 CPU thread,59s/512MiB caps,64MiB estimate. No native constructor,
GPU proof,receipt or verifier ran.

The algebraic combinations are broader than native construction. The builder
expects Ht's two zero-rule planes whenever pad_on is true;the port preserves8
abstract S-only refusals. P3 lifts only domains with H planes:layout.rs170/191
excludes Ht. Nineteen additional S-only size-policy cases retain the builder
refusal;full Shape::new eligibility is untested. Ht-only has no geometry under
these size rules but its algebra is tested. No new profile or native defect
is claimed. Initial passing local work incorrectly lifted Ht;source inspection
caught it,and that superseded run remains. A later retained attempt used six
outer validation samples for all cases;final execution uses native five/six.

Three-limb hp32/kv8/qh32/T512 bracket-only API count is4,181,720,663 versus
6,698,302,780 in the old always-padded formula:37.5704% below that formula
(two limbs:37.5441%). Its support-payload formula falls256MiB to0 and synthetic
port carriers30 to28;these are not exact native slot lengths. **This eliminates
zero native work:the implementation already omits it.** Padded qh12/T512 and
qh24/T1024 counts are unchanged. Six cases retain dimensions,declared degrees,
setup and limitations without allocating model-sized arrays. Bracket-only
counts omit Eq/interpolation,recovery arithmetic,folds,PCS,masking,witnesses,
transfers and serialization. They are not the old all-phase API denominator.

Native PadTerm stores14 three-limb weights but executes16 setup products for
two groups,because the second add reconstructs the preceding two powers. Old14
was sequential cached weight generation. This tiny correction is not an
optimization recommendation. Added research costs are two public presence
flags,separate pad_on metadata,correct graph planning and independent references.
The port correction adds no native code,cost or performance benefit.

**New local hypothesis:** test a separate four-coefficient group0 factory on
the unpadded branch. The current padded_zero policy selects no group there;
previous padded improvement projections cannot predict an unpadded8B gain.
Baseline group0 evaluates4 samples on round0 and3 after nonzero-factor h1
recovery. Possible eliminated work is repeated scalar bracket evaluation.
Added costs are denominator preparation,four-word construction,weighted
reduction,Horner evaluation,setup,dispatch,code and scratch. Preserve the
original five outputs,per-group claims,finals,zero-factor fallback and refusals.
Reject any differential/native-boundary mismatch or added cost erasing savings.
End-to-end ceiling is unknown:
`N/(T_complete - saved_scalar_time + added_prepare_reduce_dispatch_time)`.
This cycle's accounting correction itself saves zero native time.

|Rank|Hypothesis, prerequisites and falsifier|
|---|---|
|1 owner|GPU dominant SC_SZC and both recurring witness paths. Largest measured phase opportunity;high CUDA/memory integration cost. Require masking/refusal/final/RNG/PCS/fresh-verifier gates and lower enclosing time/peak. Reject mismatch,overflow or regression.|
|2 local NEW|Four-word unpadded factory versus literal samples. Unknown affected time;charge all construction/reduction/Horner/setup/dispatch/scratch. Exact optional metadata and original samples/claims are prerequisites. Reject mismatch or break-even loss.|
|3 conditional owner|Existing padded fixed-array/weighted/denominator/2x2+3x2 chain. Modest arithmetic opportunity;extra adds/subs/code/scratch. Native byte/refusal/RNG/PCS/privacy/independent-verifier gates before affected and enclosing clocks. Reject changed relation or regression.|
|4 workload owner|Complete resident-pass startup/slope at fixed context with fresh masks. Include both witnesses,serialization,verification,latency/lag/drain. Recurring cost above20ms/new proved position rejects50/s for that schedule. Long prefill charges quadratic attention;resident passes and decode are distinct.|
|5 owner|Exact full-K split-int16 down witness. Unknown affected fraction;charge packing,two products,i64,requant/refusal,transfer and workspace. Reject integer/profile/receipt mismatch or enclosing regression.|
|6 demoted|General CSE graph saves no multiplication and only0.53–0.59% of old illustrative padded API operations;adds a live word and dispatch,compiler may already CSE. Model-changing sparsity/PoT or new PCS architecture needs exact relation,hiding and composition work.|

Baseline remains one synthetic125M block,T512,one pass,RTX4070 Laptop:
SC_SZC7.794s,proof16.864s,witness5.77s,encode0.028s,decode0.013s,in-process
verification0.806s,whole-test27.523873s,40,783,352B. Startup and both recurring
witness clocks lack the required split. Removing all SC_SZC would cap that
historical enclosing saving at28.317%;this is not an8B ceiling or a factor
for scaling kernel counts. Synthetic12-block/T512/one-pass GPU whole time is
408.609226s,prove318.22s,in-process verify12.15s,484,107,456B;trained=false,
privacy accepted=false,fresh-process verification=false. Later CLI nonterminal
state establishes neither completion nor liveness. Preserve prior native
fusion regression and all arithmetic/count/memory negatives.

LIVE primary search assessed new older SpaGKR (received June24/approved June28,
2024),new GoQuant (July27,2026 revision),and new specific Plonky3 jagged PR2285
(merged September23,2026) with October16rc.2. SpaGKR's model simplification and
GoQuant's changed quantization are not exact native improvements. Jagged claims
still need terminal PCS authentication,original-domain factors and composition.
GoldilocksNTT cache-residency and NanoZKv2 coverage refreshes add no new gain.
Five records retain exact URLs,dates,license scope and failed PDF/package/commit
fetches. Main Plonky3 MIT text inspected;merge dbca717... fetch failed Cache
miss. Release year relies on previously verified sibling metadata;fresh exact
and sibling package fetches failed. No author runtime,test,security or
correctness claim reproduced;no foreign code copied/executed. Next rotation:
GPU commitments/memory traffic,lookup/softmax,proof composition.

[Experiment](experiments/optional-support-port-20261017/README.md) and
[owner note](handoffs/20261017-optional-support-port.md) retain interface,
patch,commands,pins,controls and limits. Actual seam:sonnet-hardening
argument.rs SC_SZC1699/groups1783/bracket1788 and grouped.rs row93/sample107/
reduction121/recovery132. No native change/merge is requested by the correction.
Next LOCAL:four-word unpadded oracle and complete cost census. Next OWNER:
trained profile/privacy gates,then guarded SC_SZC subphases,both witnesses,
peak memory and enclosing resident workload measurements.

Accepted independently verified complete private8B proofs/passes/tokens0/0/0.
Proof context null;CPU only this cycle. Steady/total rates,startup seconds/
fraction,witness/proof/serialization/independent verification and latency/lag/
drain remain unmeasured. No long-context prefill,resident-pass or decode proof.
>=50/s unchanged/unachieved;larger workloads permitted with quadratic attention,
fresh masks and complete coverage/privacy. No production/runtime/Git/build/GPU/
install/external action or heavy job queued. Saved reports do not establish
message delivery or supervisor/job liveness.

Checkpoint audit:144 integrity/accounting checks passed at 2026-10-17T03:38:40.275030+00:00. Prior source/findings bytes,executed source hashes,current native pins,declared-sample arithmetic,census totals and dated-report parity verified. This is not another experiment or native proof gate.

## Cycle0054 — 2026-10-17 — only round0 repays unpadded cubic construction

Run `20261017T042624Z-0f7bf604`;checkpoint 2026-10-17T04:37:37.221578+00:00. **Promising arithmetic count;no native speed
improvement.** Current agenda,target and durable/project memory were read/
snapshotted;all269 starting source records parsed;whole historical findings
indexed for negative/next evidence. Latest three experiment results read.
Native status remains no new trained proof,D24 proposed.11 retained source/
measurement pins match;current candidate argument/grouped files also match
sonnet-hardening (root main differs). Native/profile/privacy lane stays owned.

**Question refined from cycle53:** does a four-word unpadded factory repay
construction when native h1 recovery removes a scalar sample? Baseline group0
needs4 samples on round0 and3 after nonzero-factor recovery. Broad coefficient
construction passes exact algebra but adds22 Fp2mul per later constant-mask row
(33 when mask moves) versus prepared scalar. It saves10/9 mul_base while adding
other work;the blanket policy is demoted. A public round-zero-only selection
instead saves17 mul,20 mul_base,5 add,17 sub per row plus a final Horner charge.
No private value or zero slope controls dispatch;round0 recurs every proof.

Final experiment:63 fixtures,1,890 complete synthetic schedules,19,650
independent round samples,43,920 final values,144 extension clause checks,
12 value-independent row censuses,20 concrete-versus-allocation-free counters,
3 padded-factory refusals. Five material mutations caught.732 recoveries and
708 zero-factor fallbacks agree across five modes. Source-declared widths,
per-group pending samples,claims,finals,fold and equality work agree with the
separate original-cube tuple oracle. CPU10.054167s,RSS22,184KiB,
one nice19 CoreUltra9 thread,exit0;59s/512MiB caps. No native constructor,
transcript,RNG,PCS,verifier,receipt or GPU execution.

hp32/kv8/qh32/T512,three limbs,no lift: scoped arithmetic follows.

|Mode|Fp2 mul|Fp2 mul_base|Fp2 add|Fp2 sub|API total|
|---|---:|---:|---:|---:|---:|
|literal|1,220,542,341|629,145,536|1,518,403,310|922,746,786|4,290,837,973|
|prepared_scalar|1,220,542,341|306,184,161|1,107,361,575|893,386,676|3,527,474,753|
|cubic_schoolbook|1,345,060,651|180,617,338|1,118,633,842|676,069,316|3,320,381,147|
|cubic_karatsuba|1,244,397,379|180,617,338|1,219,297,114|877,395,860|3,521,707,691|
|cubic_round0|1,149,239,173|222,298,090|1,086,390,064|822,083,508|3,280,010,835|

Round0-only versus prepared scalar removes7.0153% of the stated API scope;
versus literal removes23.5578%,which includes denominator preparation savings.
Native field-source expansion gives524,287,982 fewer base multiplies,
184,549,358 fewer adds,142,606,336 fewer subs versus prepared scalar;these are
literal API expansions,not instructions or timings. The scope includes bracket
construction/evaluation,weighted sums,modeled part reductions,Horner and
preparation;omits common Eq/interpolation/recovery/folds,PCS/masks,witnesses,
transfers and serialization. Model uses source1024/small chunk policy with
port carrier count;Rayon identity-fold additions are not specified and are
uncounted. Part width8 is unchanged. T1024 work is roughly4x,not automatic
amortization. Two-limb/hp16 rows retained. No native speedup inferred.

Added costs:15 denominator offsets (30 charged field ops),15 classifications,
4 coefficient output words/64 logical bytes per row,unknown polynomial
temporaries/registers,policy/axis tests and159,383,552 dynamic width tests in
T512 round0 replay. Denominator dispatch charged per actual scalar sample or
coefficient carrier. Native scratch/code/allocation/affected and enclosing
clocks unmeasured. Initial passing all-round attempt used512-row count chunks;
retained with its superseded accounting. Later1024/small-policy,value-independence,
dispatch and self-contained-input refinements all remain separately retained.

|Rank|Hypothesis, baseline / eliminated work / added costs / falsifier|
|---|---|
|1 owner|Move dominant SC_SZC and both recurring witness paths to GPU. Baseline native synthetic measurements below; remove CPU recurrence, add CUDA transfers/device storage/dispatch. Require native exact/masked/final/RNG/PCS/refusal and fresh-verifier gates; reject mismatch,overflow,peak or enclosing-time regression. Full8B ceiling unknown.|
|2 local, refined and tested|Use four coefficients only for unpadded group0 at round0; scalar evaluation after h1 recovery. Eliminates four repeated scalar brackets on that round; adds four-word construction/weighting,Horner,denominator setup and public dispatch/scratch. Counted scoped gain7.0153% versus prepared scalar at full-head T512,not time. Next: fixed straight-line factory to remove dynamic width dispatch. Reject native parity/refusal/RNG change or added costs erasing arithmetic savings.|
|3 workload owner|Measure resident complete passes at fixed context with fresh masks and full coverage. Baseline startup/slope unmeasured. Eliminate only actually reusable model/public setup; add residency/cache validation,all per-proof masks,lag/drain and verifier costs. Recurring wall above20ms/new proved position rejects50/s for that schedule. Long prefill and decode require separate measurements and state binding.|
|4 owner|Exact full-K split-int16 FFN-down witness. Remove slow scalar products; add packing,two products,i64 recombination,exact requant/refusal,transfer and scratch. Require integer/native receipt parity and lower enclosing time; affected fraction/8B ceiling unknown.|
|5 conditional owner|Existing padded fixed-array/weighted/denominator chain; useful only where native supports exist. Charge added adds/subs/code/scratch. Require native masked/refusal/RNG/PCS/privacy/fresh-verifier gates and lower elapsed time. No padded gain transferred to full-domain8B.|
|Demoted|Blanket unpadded cubic construction after recovery: on three-limb full-head axes it adds22 Fp2mul per row versus prepared scalar (33 on moving mask axes),while saving10/9 mul_base and adding other work. Keep negative. Prior native fold fusion was1.66% slower mean prove/10.38% slower softmax; prior CSE,twiddle,memory and arithmetic negatives remain. Dory/Fold-DCS/binary-field architectures need new relation/hiding/composition work.|


Historical measured baseline, not re-run: one synthetic125M block,T512,
one pass,RTX4070Laptop; SC_SZC7.794s,proof16.864s,witness5.77s,encode0.028s,
decode0.013s,in-process verification0.806s,enclosing test27.523873s,
40,783,352B. Startup and both recurring witness clocks are not separated.
Removing the entire SC_SZC phase would save at most28.317% of that enclosing
measurement. This is not an8B estimate; a7.0153% API-count reduction does not
imply that fraction of phase time. Complete8B ceiling remains
`N/(T_complete - saved_recurring_scalar_time + added_factory_dispatch_scratch_time)`.
Round0 recurs on **every proof**; it is not amortizable process startup.
The historical synthetic12-block/T512/one-pass GPU-arm test is408.609226s
whole,318.22s prove,12.15s in-process verify,484,107,456B (~1.253 complete
synthetic positions/s over enclosing test);trained=false,privacy accepted=false,
fresh-process verification=false. No accepted private8B token credit follows.


LIVE search covered GPU NTT/commitments and memory overlap,coefficient
sumcheck,lookup/softmax interfaces and composition. New older Dory paper
(received2020-10-14,revised2021-11-18) and v0.4.2(Aug20,2026) release inspection
add a PCS/state-binding filter; release commit5246da503c3e2c6baa40ec00d714987c73a3e6eb
was inspected. EPFL's concrete coefficient source uses EvalsInfty and plain
non-ZK sumcheck,so it cannot replace native samples/masking directly. Fold-DCS's
PCS instantiation explicitly does not require hiding. NVIDIA's July15 clmad
article concerns characteristic-two fields. ICICLE transfer overlap charges
two device vectors. October16 Plonky3 BLAKE2s metadata is not keyed BLAKE3
compatibility. New October FAEST discovery could not be primary-inspected:
eprint2026/2489 and its PDF were not accessible; no claim adopted. Seven
records retain exact URLs,verified versus unknown dates,failed license/commit/
package/PDF fetches and unreproduced author claims. Actual Dory/EPFL license
terms were unavailable; repository license labels are not a verified license.
No foreign code was copied/executed,installed or benchmarked. Next rotation:
lookup/softmax table traffic,public dependency-specialized kernels,composition.


Concrete seam:candidate argument.rs1699/1783/1788 and grouped.rs93/107/121/132.
Next LOCAL:fixed public straight-line unpadded round0 factory with independent
sample/counter/lifetime checks. Next OWNER:native/profile/privacy/refusal/RNG/
mask/PCS/independent-verifier gates,then guarded3-arm clocks (literal/prepared/
prepared+round0),both witness paths,peak and complete resident startup/slope.
[Experiment](experiments/unpadded-cubic-factory-20261017/README.md) and
[handoff](handoffs/20261017-unpadded-cubic-round0.md) retain exact interface,
research patch,pins,commands,seed,dimensions,hardware and risks.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**.
Proof context length is null. Current device: one Intel Core Ultra 9 185H CPU
thread, nice19, affinity CPU0; no GPU job. Steady-state and total-workload rates,
startup seconds/fraction, witness/proof/serialization/independent-verification
clocks, proof latency/lag/drain are **unmeasured**. No long-context prefill,
resident-model pass or decode proof ran. Synthetic cube tests use up to32 cells;
T512/T1024 rows below are allocation-free arithmetic, not accepted profiles or
proofs. Doubling context quadruples the modeled attention cube work. Larger
workloads remain allowed; no mask reuse, privacy weakening or target change.


No production/runtime/Git/build/GPU/install/external action or heavy job queued.
Reports do not imply delivery or liveness. Prior findings and negatives retained.

Final evidence audit: 445 integrity/accounting checks pass (2026-10-17T04:38:46.046132+00:00); no owner memory file changed during this cycle. The initial auditor incorrectly required an id on every historical source record; five old records omit it. That failure is retained, and the corrected check preserves the historical ledger and verifies seven new unique ids. No native proof or performance gate is implied.

## Cycle 0055 — 2026-10-17 — fixed unpadded round0 arithmetic and lifetimes

Run `20261017T052624Z-c8881557`; checkpoint 2026-10-17T05:36:29.568471+00:00. **No native speed improvement established.** Agenda, current target, durable/project memory and latest three experiment results read and snapshotted. All 276 starting source records parsed; 53 historical findings sections indexed without deleting negatives. All 11 native/measurement pins match; owner memory unchanged. D24 remains proposed; no new trained receipt or privacy ruling.

**Question refined:** can the first-round four-coefficient evaluator retain its arithmetic advantage without dynamic width/tag tests, and what temporaries does it need? A locally authored compiler emits separate bodies selected by immutable public layout and mask-axis metadata. Fixed SSA and recycled-slot variants match the prior dynamic factory. No private value, coefficient, degree or zero slope selects the path. Proof-local offsets are hoisted once per definition. Natural causal fixtures cover both head-leading and token-leading axes. The original five outer samples, group pending claims, terminal values, recovery and fallback agree in the synthetic port. No native constructor, transcript, RNG, PCS or verifier was executed.

Final bounded run: **2,790 schedules / 93 fixtures**, 28,650 independent round samples, 67,770 final values, 192 extension checks, 1,116 schedule cost comparisons, 48 executed field-operation censuses, 24 value-independent censuses, 24 generated bodies without loops/branches and three padded-factory refusals. There were 996 recoveries and 1,092 zero-factor fallbacks. Five mutations detect lost/reversed coefficients, a wrong sign, incorrect public mask metadata and premature live-slot overwrite. Final run: 13.144796 seconds, 26,948 KiB RSS, one nice19 CPU0 Core Ultra 9 thread, seed2026101755, exit0. Limits: 59s CPU/alarm, 512MiB address space, 64MiB estimated memory. A separate structural register-use/integrity audit passes 25,986 checks, including corrupt-RHS rejection. These are harness checks, not proof gates. Initial missing-local-import and stale-oracle-constant failures are retained; the corrected independent equation is rebuilt for each challenge fixture. Intermediate passes and later offset/lifetime/causal-axis refinements are preserved.

For three limbs and 15 lookups:

|Mask axis|Fp2 mul|mul_base|add|sub|API total|Peak logical temporary results|
|---|---:|---:|---:|---:|---:|---:|
|Constant|135|20|135|103|393|20 / 320B|
|Moving|146|21|146|106|419|23 / 368B|

The lifetime figure excludes read-only inputs/constants/offsets, caller arrays, equality/accumulators and native API internals. Four output coefficients occupy 64B but **do not establish peak scratch**. SSA and recycled-slot bodies have identical calls, values and logical last-use peaks. Native registers, stack, spills, occupancy, code size and elapsed time remain unmeasured. Shorter temporary lifetimes are now a concrete next hypothesis.

The full-head T512 / three-limb scoped API count is unchanged from cycle54: **3,527,474,753 prepared scalar -> 3,280,010,835 fixed round0**, a 7.0153% reduction. This cycle adds no arithmetic saving over the dynamic round0 prototype. It removes 159,383,552 dynamic width tests from that **research prototype**; the native scalar prover never had that added dispatcher. No incremental native speed factor follows. Denominator tags are compiled out of the fixed row; proof-local offsets are still charged. Hosted groups and later rounds retain prepared scalar. The scope includes bracket construction/evaluation, weighting, modeled part reduction, Horner and denominator preparation. It omits common equality/interpolation/recovery/folds, PCS/masks, witnesses, transfers, serialization and unspecified Rayon identity-fold additions. T1024 attention work is roughly4x. Prior all-round/padded/fusion/CSE/memory negatives remain.

Historical measured baseline, not re-run: one synthetic 125M-shape block, T512, one pass, RTX 4070 Laptop. SC_SZC 7.794 s; proof 16.864 s; reported witness 5.77 s; encode 0.028 s; decode 0.013 s; in-process verification 0.806 s; enclosing test 27.523873 s; 40,783,352 proof bytes. Startup and the two recurring witness paths were not separately resolved. Erasing all SC_SZC could remove at most 28.317% of that enclosing diagnostic. This is neither an accepted private8B proof nor an8B bound. The synthetic 12-block/T512/one-pass diagnostic remains 408.609226 s enclosing, 318.22 s proving, 12.15 s in-process verification, 484,107,456 B (~1.253 diagnostic positions/s); trained=false, privacy accepted=false, independent-process verification=false. No token credit is taken.

The complete8B ceiling remains `N/(T_complete - avoided_recurring_scalar_time + added_factory_dispatch_scratch_time)`, with native terms unmeasured. The first round recurs on every proof. Only generated public code can be reusable setup; no per-proof offsets, masks or openings are silently reused.

|Rank|Hypothesis and expected end-to-end impact|Prerequisites, integration costs, exactness/privacy, falsifier|
|---|---|---|
|1 owner|Dominant GPU SC_SZC and both recurring witness paths; highest measured phase opportunity, complete8B ceiling unknown.|Native profile/privacy/refusal/masked/final/RNG/PCS and fresh-verifier gates. Add device storage, transfers, launch/scratch. Reject mismatch, overflow, peak or enclosing-time regression.|
|2 local, refined this cycle|Fixed unpadded round0 evaluator, then public clause-streaming schedule to shorten lifetimes. Avoid four scalar brackets; keep prior 7.0153% scoped API-count reduction vs prepared scalar. No native-time gain established.|Use immutable layout/axis metadata and proof-local offsets. Add coefficient construction, weighting, Horner and 20–23 live logical temporaries; Rust helpers uncompiled. Falsify on native value/refusal/RNG mismatch or spills/extra work erasing savings. Next test: static streaming order, no changed operations, independent oracle and <=16-live-temporary goal (hypothesis only).|
|3 workload owner|Resident complete passes at fixed context with reusable public/model setup, fresh masks and full clocks; startup/slope unknown.|Add cache validation, residency, lag/drain and independent verification; no openings/blinding reuse. Recurring >20ms/new proved position rejects 50/s for that schedule. Long prefill and decode stay separate, with cross-window state binding.|
|4 owner|Exact full-K split-int16 FFN-down witness; enclosing affected fraction and8B ceiling unknown.|Add packing, two products, i64 recombination, exact requant/refusal, transfer/scratch. Integer/native receipt parity and lower enclosing elapsed are required.|
|Demoted|Broad cubic evaluation after claim recovery adds22 Fp2mul/row (33 on moving-mask axes). Prior native fusion, CSE, twiddle, memory and table-cache negatives retained.|No padded-layout gain imported into unpadded8B. New table/field/PCS architecture needs full relation, hiding and composition review; no migration authorized.|

**LIVE source result:** six records appended, 276->282, rotating through lookup/softmax query traffic, quantization, memory ownership and composition. New September29 quantization work separates floating utility exploration, large projections and T16/32-thread small-model proof measurements excluding inference/preparation/verification. Smaller tables do not remove an unchanged query count. October15 Range is inference restore, with startup and after-response integrity boundaries; its completion-owned physical batches inform lifetime questions but do not authenticate proof state. New older private matrix lookup treats private tables and malicious commitments; its PDF is blocked and no migration claim follows. VeriLoRA paper/CUDA inspection finds double-based table and shift construction, incompatible with the native exact integer relation; MIT-style terms inspected, history unavailable. DeepProve licensing commit `9d1a53e2ef49ffa2c902b8689cd3c58057a4e662` inspected, current custom terms recorded; no release artifacts on release page, release-commit/source fetch errors retained. The nonlinear small-table refresh preserves the existing byte-decomposition/ceiling finding; PDF blocked. Exact URLs, verified versus unknown dates, licenses, commit status and blockers are in sources-cycle55.json. No foreign code copied/executed or author performance/security result reproduced.

**Integration seam:** candidate `argument.rs:1699/1788` and `grouped.rs:93/107/121/132`. Research compiler/adapter, generated Python and uncompiled Rust helpers are self-contained. Native owner must translate research-port indices into immutable captured indices. Optional callback, mapping, constructor and original scalar fallback are still integration work. Next local experiment: public clause-streaming order over the same DAG, targeting <=16 live temporary results without extra field calls, with independent values/counters/last-use checks. Next owner gates: native privacy/profile/masks/refusals/RNG/finals/PCS/fresh verifier, then guarded three-arm timing, both witness paths/peak and complete resident startup/slope with fresh masks and latency/lag/drain. No heavy job queued.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**. Proof context length: unmeasured (null). Device: Intel Core Ultra 9 185H CPU only, one thread, nice 19, CPU0 affinity. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain: **all unmeasured**. No long-context prefill, resident-model pass or decode proof ran. Synthetic schedules use at most 16 cells. T512/T1024 arithmetic is allocation-free accounting, not a profile or proof; doubling context produces roughly four times the attention work. Larger workloads remain permitted with complete coverage and fresh masks. The >=50 proved-token/s target is unchanged and unachieved.

[Experiment](experiments/fixed-round0-factory-20261017/README.md) and [handoff](handoffs/20261017-fixed-round0-factory.md). No production/runtime/Git/build/GPU/install/external action or merge. Reports do not establish delivery or liveness. Historical findings and negatives retained.


## Cycle 0056 — 2026-10-17 — exact public DAG order reduces logical retention

Run `20261017T062624Z-e471348a`; checkpoint2026-10-17T06:33:15.417512+00:00. Agenda, target, durable/project memory and latest three results read/snapshotted. All282 starting source records parsed;6 appended,288 total. Prior findings and source prefixes retained.

A deterministic public DAG scheduler tests102 orders per public shape (96 depth-first operand/output orders,5 ready-list heuristics and the original order). All operations, operand order, outputs and even dead pure operations are retained; there is no CSE, algebraic rewrite, recomputation or private-value pruning. The full-head three-limb constant/moving-mask bodies retain393/419 field API calls. Their peak live logical field results after assignments fall20->18 and23->20 (320->288B and368->320B). Seven-lookup moving-mask shapes reach19. All12 shapes improve, but none reaches the proposed<=16 goal. This bounded miss is not a lower bound or an optimality result. Read-only inputs, proof-local offsets/constants, caller arrays, Eq/accumulators and field-API internals are excluded; native registers, spills, stack, occupancy and runtime remain unknown.

The final experiment passes2,790 synthetic schedules/93 fixtures,28,650 independent round samples,67,770 finals,192 extension checks,1,116 schedule counter comparisons,48 executed operation censuses,24 value-independent censuses and24 branchless generated bodies. There are1,026 recoveries/1,062 zero-factor fallbacks,3 padded refusals and5 detected arithmetic/metadata/lifetime mutations. Final wall=16.277544s, RSS=27,280KiB, one nice19 CPU thread, seed2026101756, exit0,59s/512MiB caps; estimated64MiB. The independent AST/DAG/integrity audit passes34,514 checks and refuses dropped, duplicate and use-before-definition schedules plus a corrupt RHS. It verifies the exact original operation/operand/output correspondence under the permutation. This is not a native proof or privacy gate.

Baseline for this cycle is the prior fixed unpadded round0 factory. Eliminated work: **no field operations**; only shorter logical retention of2/3 full-head intermediate results. Added costs: public generation/search, permutation/remapping, source/metadata and compiler scheduling constraints; static helpers can be generated ahead of time. These must not be presented as measured native startup. The prior scoped full-head hp32/kv8/qh32/T512/3limb count remains3,527,474,753 prepared scalar ->3,280,010,835 fixed round0 (7.0153% fewer API calls), with the same exclusions. No further arithmetic saving or timing factor is established. The earlier159,383,552 eliminated width tests concern a dynamic RESEARCH prototype, not native scalar work. Round0 recurs for every proof; it is not startup amortization.

End-to-end ceiling remains unknown: `N/(T_complete - avoided_native_spill_or_scheduling_time + added_native_setup_dispatch_time)`. All native terms for this scheduling change are unmeasured; a compiler may already find an equivalent schedule, yielding zero benefit. Even erasing all historical SC_SZC is only a28.317% ceiling on that one synthetic block's enclosing diagnostic, not an8B bound or a path to50/s by itself.

|Rank|Hypothesis / end-to-end opportunity|Prerequisites, added costs and falsifier|
|---|---|---|
|1 owner|GPU SC_SZC plus both recurring witness paths. Largest measured phase opportunity; complete8B ceiling unknown.|Exact native profile/refusal/masked/RNG/finals/PCS/privacy and fresh-verifier gates. Charge device storage, transfers, launches, scratch and both witnesses; reject mismatch, overflow or enclosing regression.|
|2 refined local / owner gate|Public DAG scheduling preserves prior first-round field savings while reducing logical scratch. Native benefit unknown; no additional arithmetic saving.|Next local: construct and independently validate immutable native-capture index mapping; do not derive indices from witness values. Owner: compile/profile literal, unscheduled fixed, scheduled fixed arms, including registers/spills/code size and enclosing clocks. Reject any value/refusal/RNG difference, or unchanged native code/no enclosing gain. Tested <=16-live goal failed; no optimality claim.|
|3 workload owner|Resident complete passes at fixed context can amortize public setup; startup/slope not measured.|Fresh masks/openings per accepted policy; cache identity, residency, lag, drain and independent verification. Recurring complete cost>20ms/new proved position falsifies50/s for that schedule. Long-context prefill and growing-context decode remain distinct; decode needs state binding.|
|4 owner|Exact full-K split-int16 down witness; affected complete-proof fraction unknown.|Packing, two products, i64 reconstruction, exact requant/refusal, transfer and scratch. Reject integer/native-receipt mismatch or enclosing regression.|
|5 conditional architecture|Commitment transfer overlap or different GKR/PCS designs might affect dominant phases; no native estimate.|Extra device buffers, completion ownership, field/profile migration, hiding, state binding, composition and verifier costs. ICICLE example alone does not establish our field adapter or bytes; Ethereum proof claims do not transfer.|
|Demoted|Broad later-round cubic, CSE, prior native fusion, twiddle/memory/table-cache negatives retained.|Do not credit padded savings to full-domain8B or treat table shrink as fewer queries. No reconstruction/spill optimization promoted without native measurement.|

Candidate seam: `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/argument.rs:1699` SC_SZC constructor and1788 bracket; `zkp-core/src/sumcheck/grouped.rs:93` part loop,107 row loop,121 samples and132 reduction. Review patch: `experiments/clause-stream-schedule-20261017/research-source-diff.patch`; generated Python/Rust and liveness schedules are under `generated/`. Interface remains four fixed coefficients from immutable current-row values, differences, constants and proof-local offsets. There is no production patch or merge.

Generated Rust is uncompiled and uses research-port carrier indices. Public topology scheduling changes no field formula, but native masked transcript, RNG, refusal, profile, terminal oracle, PCS, proof bytes and independent verifier gates remain mandatory for owner integration. Public helper code may be cached; offsets depend on the current proof's challenges. No witness, mask, private opening or proof-local denominator cache across proofs is authorized. All11 native/measurement pins and7 owner memory files match the starting snapshot. D24 remains proposed; no new profile or privacy ruling is accepted.

The initial scheduled arithmetic pass is retained under before-independent-dag-audit/. Expanding the independent audit after the wrapper had pinned every local Python file correctly triggered `AssertionError: audit.py`; that failure is retained under initial-audit-source-pin-refusal/. The final source freeze rerun and expanded audit pass. No arithmetic failure was hidden and no integrity check was disabled.

Six LIVE source records were appended (282->288), with URLs, access date, verified versus unknown dates, license scope, inspected commit and exact blockers in sources-cycle56.json. New October13 Airbender Prime is an author Ethereum/GPU claim; unversioned repository final-CPU documentation is not mapped to Prime. New older Sethi1975 register-allocation abstract supports bounded heuristic/optimality caution. ICICLE's NTT-overlap example explicitly charges extra device vectors; its release-target diff6c77775961b0e4dc2be359feec1ac11536c18043 includes a Goldilocks crate, correcting any inference from the previously incomplete advertised field list. Native Fp2/mask/challenge compatibility is unestablished. SumCATS register-storage discussion and2026-revised product-sumcheck time/space source were refreshed; hardware-locality/PIM scope retained. No author performance/security reproduced or foreign code copied/executed. PDF, license, history and example-source fetch failures did not block the local experiment.

Next local experiment: replace research-port carrier indices with an immutable captured-index adapter matching the native SC_SZC constructor (`idx`,`im`,`imx`,`isum`,`ihx`,`h0`, limb vectors and lookup terms), then differentially compare literal/native-shaped and generated clauses at arbitrary extension points. Preserve optional support refusals and original group/terminal order. Native owner next: guarded three-arm compile/profile and complete resident-workload startup/slope, with both witness paths, peak memory, all clocks, fresh masks, proof lag/drain and independent verification. Do not repeat heuristic search merely to obtain a smaller toy frontier before this integration question is answered.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**. Proof context length: unmeasured (null). Device: Intel Core Ultra 9 185H CPU only, one thread, nice19, CPU0 affinity. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are **all unmeasured**. No long-context prefill, resident-model pass or decode proof ran. Synthetic cubes contain at most16 cells; T512/T1024 figures are allocation-free accounting. Doubling dense-attention context produces roughly4x score work. Larger workloads remain permitted with fresh masks and complete coverage. The complete private8B >=50 proved-token/s target remains unachieved.

No production, runtime, Git, calibration, safety gate or reviewer files modified; no GPU, build, dependency install, external write/message, merge or heavy job queued. Saved reports do not establish message delivery or supervisor/job liveness.

Final checkpoint audit:168 checks pass. Checkpoint-only syntax and historical
source-schema assumption failures are retained; corrected checks preserve all
older records verbatim and validate uniqueness/noncollision of the six new IDs.
No native proof or performance gate is implied.


## Cycle0057 — 2026-10-17 — native capture mapping without a per-row gather

Run `20261017T072624Z-c38c878c`; 2026-10-17T07:34:34.159195+00:00. Agenda, target, durable/project memory and latest3 results read; all288 starting sources parsed. Prior findings/source prefixes retained. Full experiment: experiments/native-capture-adapter-20261017; handoff: handoffs/20261017-native-capture-adapter.md.

The final run passes 120 capture layouts (native push order plus relocated frames), 1,440 independent scalar group checks, 480 full-polynomial comparisons, 2,304 fixed-helper sample checks and 96 direct branchless generated Python helpers. Both constant/moving masks, 2/3 sigma limbs, 2/3 probability limbs, full/7/8 lookups, arbitrary Goldilocks2/base/zero/Boolean values and all four optional-support combinations are exercised. lp3, lookup subsets and relocated frames are synthetic robustness cases, not admitted profiles. Final wall 4.935856s, RSS 27,108KiB; one low-priority CPU thread, seed2026101757, exit0; 59s/512MiB caps, 96MiB estimated. Independent tuple arithmetic/source/index audit passes 13,047 checks in 0.385s, RSS19,008KiB, seed2026101757001. This is Python arithmetic and metadata evidence; no actual Rust constructor capture, native compile, masked transcript, RNG, proof, receipt or verifier ran.

Fourteen controls distinguish arithmetic mismatches, adapter metadata refusals, scalar fallbacks and a valid invariance. Swapping max/sum or lookups across pairs, stale proof-local offsets, a false constant-mask dependency, wrong remapping, the wrong Ht support and restarting zeta powers are detected. Removing a third sigma limb refuses because a lookup still references it. Malformed helper count/index/alias/sentinel cases refuse in the research adapter. These checks are not added native refusals. Pad-enabled profiles stay on the original scalar path even when both optional support captures are None; multi-term lookups and later rounds also retain scalar fallback. Within a single LogUp pair, swapping the two denominators is an expected algebraic invariance and supplies no speed benefit. The initial harness incorrectly demanded mismatches for the limb refusal and within-pair swap; both failed harness runs and source versions are retained in initial-negative-control-refusal/ and initial-within-pair-control-assumption/.

Baseline: pinned native literal/grouped SC_SZC and the prior fixed round0 research factory. Eliminated work this cycle: **zero field operations and no established native work**. The adapter rewrites graph input references once into captured native table indices, so its row helper needs no compact-array gather. Such a gather was not present in the existing native baseline; avoiding a hypothetical integration cost is not a measured gain. Added costs: public capture/layout validation, index remapping, generated code/dispatch and source maintenance; proof-local constants/offsets still refresh per proof. The full15-lookup/three-limb moving-mask helper retains419 field API calls and20 live logical results (320B); prior scheduling values and scoped T512 7.0153% API reduction are unchanged. Logical temporaries exclude inputs/constants/offsets, Eq/accumulators and field-API internals. Registers, spills, occupancy, code size and runtime are unmeasured.

End-to-end ceiling: unknown, N/(T_complete - saved_native_time + added_native_time); neither time delta is measured. A compiler may already achieve the same schedule. Historical one-block T512/one-pass synthetic125M RTX4070Laptop diagnostic: SC_SZC7.794s, prove16.864s, reported witness5.77s, encode0.028s, decode0.013s, in-process verification0.806s and enclosing test27.523873s; proof40,783,352B. The A/B JSON reports16.86s rounded proof and0.82s verification from bytes; raw0.806s verification plus0.013s decode is0.819s, consistent with that enclosing verification clock. Startup and both recurring witness paths remain unresolved. Even deleting all7.794s SC_SZC would remove at most28.317% of that enclosing diagnostic (~1.395x), not establish an8B bound. The historical12-block/T512/one-pass synthetic diagnostic remains408.609226s enclosing,318.22s prove,12.15s in-process verify,484,107,456B (~1.253 diagnostic positions/s). No target token credit is taken.

|Rank|Hypothesis / expected complete-proof impact|Prerequisites, added costs and falsifier|
|---|---|---|
|1 owner|GPU SC_SZC plus BOTH recurring witness paths; dominant measured opportunity,8B ceiling unknown.|Exact native integer/profile/refusal/masked/RNG/final/PCS/privacy and fresh-verifier gates; charge transfers, scratch, launches and device memory. Reject mismatch or enclosing regression.|
|2 refined local / owner|Captured-index helper now passes synthetic mapping without per-row gather. Next derive its mask-active selector from native public mask/axis metadata, then three-arm compile/profile.|No selector from witness or sampled differences. Include padding-rule identity, table order and extension axes. Current Boolean flag is caller-supplied; wrong flag is detected by the oracle. Any native masked/refusal difference rejects; no enclosing gain rejects performance promotion.|
|3 owner|Resident complete passes at fixed context may amortize public startup; actual slope unknown.|Fresh masks and accepted opening policy, all clocks, residency/peak memory, proof lag/drain and independent verification. Recurring complete cost>20ms/new proved position falsifies50/s for that schedule. Keep long-context prefill and decode with bound state separate.|
|4 owner|Exact full-K split-int16 down witness; end-to-end affected fraction unknown.|Packing/products/i64 reconstruction/transfer/requant/refusal overhead; reject integer/native receipt mismatch or enclosing regression.|
|5 conditional architecture|Updatable state/structured lookups and composition designs; low current integration fit.|PCS/field migration, query/commitment cost, exact pinned nonlinear relation and joint hiding. No native timing factor; tiny static tables are not shown to dominate.|
|Demoted|Broad later-round cubic, CSE, fusion, twiddle and table-cache negatives retained.|Do not repeat toy scheduling to lower a frontier or treat table shrink as fewer query helpers.|

Next LOCAL: derive and independently check the constant/moving-mask round0 selector from native causal_mask_at(sh), MSB-first data axes and appended terminal-extension axes, rather than a caller-supplied Boolean. Compare every paired difference and arbitrary extension evaluations on toy/head-padded/full-head shapes; mutate the head-axis role. This is a correctness prerequisite, not another scheduling search. Next OWNER: export real constructor captures into native differential fixtures, compile literal/unscheduled/scheduled arms under the shared guard/heavy lock, then measure registers/spills and enclosing clocks including both witnesses. Require original samples, claims, ordered finals, zero-factor fallback, optional support/refusal parity, RNG/transcript/proof bytes and fresh independent verification plus tamper refusals; then a resident complete-workload startup/slope sweep. No build or heavy job was launched or queued here.

Four LIVE records appended (288->292). Search rotation covered lookup/softmax, exact nonlinear/quantization and composition. Material updates: [zkLLMPoT v2](https://arxiv.org/html/2610.08258v2), revision2026-10-11; [current zkTransformer artifact](https://github.com/uiuc-kang-lab/zkTransformer). Newly assessed older [updatable lookup RAM](https://eprint.iacr.org/2024/840) and [conditional ZK-IOP composition](https://eprint.iacr.org/2026/307) remain architecture leads, not native speedups. Exact dates, license scope, null commit IDs and access errors are in sources-cycle57.json; no author performance/security was reproduced. Primary TenseUp/UC-lifting opens, several PDFs and GitHub history/license/release/source fetches failed; search-queries.json retains the exact limitations. No date/hash or license-text inspection was inferred from a search label.

Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**. Device: Intel Core Ultra 9 185H CPU only, one thread, nice19, CPU0. Proof context length, steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are **all unmeasured**. No long-context prefill, resident-model pass or decode proof ran. Fixtures use one two-cell affine row, not token contexts. T512 figures below are historical diagnostics or allocation-free accounting. Dense-attention score work grows roughly fourfold when context doubles. Larger workloads remain permitted with fresh masks and complete coverage; the private8B >=50 proved-token/s target remains unachieved.

Production, runtime, Git, calibration, safety gates, instructions and reviewer files were not modified. No GPU job, build, dependency installation, downloaded script execution, external write/message, merge or heavy queue action occurred. Saved reports are not evidence of notification delivery or supervisor liveness. D24 remains proposed; no new privacy/profile ruling is accepted.


## Cycle 0058 — 2026-10-17 — native public-axis selector prerequisite

Run `20261017T082624Z-8668a63c`; checkpoint2026-10-17T08:35:41.909809+00:00. Agenda/target/durable and project memory snapshotted;292 starting sources parsed,latest3 results read;5 LIVE source records appended,297 total. Prior findings/source prefixes preserved.

**No native improvement measured.** The public mask selector is derived from padded `(head,t,j)` MSB axes and separate zero-endpoint terminal extensions. Head axes are constant for every arbitrary folded prefix; token axes/terminal extensions are potentially active. Unsupported metadata/pad-on/later-round cases retain scalar fallback. Native constructor pad policy must come from ALL_DOMS/pad_zero_host/zero_rule_a_planes, not geometry alone. `native-selector-candidate.rs` is uncompiled. Actual native captures/Rust/transcript/RNG/proof/verifier were not executed. Public predicate metadata reuse is unrelated to fresh private blinding, which remains unchanged.

Final experiment:9 layouts,35,952 endpoint comparisons,13,872 zero head differences,192 folds,48 active-axis witnesses,27 independent tuple-field full-extension evaluations,336 helper samples/four generated bodies,18 controls. Wall2.614439s (subprocess2.696996s),RSS20724KiB,CoreUltra9 185H CPU0/one nice19 thread,seed2026101758,59s/512MiB caps,96MiB estimate,exit0. Independent scalar-only original-cube audit1431 checks,0.033887s/RSS16100KiB,seed2026101758001,32MiB estimate. All12 native/measurement pins unchanged. Wrong axis/terminal/support/head-zero-fill/pad-policy metadata and false constant helper selection are detected or fall back; varying head point is an expected invariance. Native extension0/1 refusals are not changed by algebra checks.

Incremental eliminated work: **zero field operations, zero established native time**. Added public validation/dispatch/source maintenance. Earlier factory arithmetic/logical retention and7.0153% scoped API accounting are unchanged. The comparator and conditional vector elimination were already studied in cycle0037; this rerun is a regression oracle for new dispatch, not a new algorithm or memory saving. Hpad32/T512128MiB,T1024512MiB,T40968GiB mask counts are allocation-free and conditional; verifier savings cannot be claimed as prover throughput. Complete8B ceiling remains unknown. Historical deleting all SC_SZC only28.317% (~1.395x) of one27.523873s synthetic125M diagnostic; target unchanged.

|Rank|Hypothesis and baseline|Removed work / added cost / complete-proof limit|Prerequisites, exactness/privacy and falsification|
|---|---|---|---|
|1 OWNER|GPU SC_SZC plus both recurring witness paths; native historical GPU-assisted synthetic125M block still spends7.794s in SC_SZC.|Replace host field loops/transfers; adds device storage/synchronization/reductions. Complete8B bound unknown. Erasing all SC_SZC only28.317% of the cited27.523873s one-block test.|High CUDA/native integration cost; all clauses/ordered finals/refusals/hosted claims, fresh randomness/transcript/PCS unchanged. Reject any mismatch or no enclosing gain.|
|2 REFINED/TESTED|Derive constant-mask selector from trusted native S axes and appended extension policy; prior adapter takes mask_active Boolean.|No new field work eliminated, no incremental descriptor saving. Adds public validation/dispatch; native complete-time delta unknown.|Moderate constructor/helper integration. Pad-on/later-round fallback; never receipt/witness-driven dispatch. Any selected-constant nonzero paired difference, extension mismatch or native byte/refusal change falsifies. Native compile/capture still owner work.|
|3 OWNER|Resident complete-stack workload sweep with explicit startup, recurring work and drain.|Amortize only genuine reusable public/model setup; adds residency/memory pressure and measured scheduling. No mask reuse. Unknown actual8B ceiling.|Complete linked stack/independent verifier plus all clocks, fixed context and distinct proved positions. Recurring>20ms/new proved position falsifies50/s for that schedule; larger single-context attention has quadratic cost.|
|4 LOCAL NEXT/OWNER|Audit new trained-block clock records to locate both witness builds and serialization boundaries before exact full-K split-int16 witness work.|Avoid duplicate or inefficient CPU witness arithmetic only if measured; packing/reconstruction/i64/requant/scratch may offset it. Current isolated share unknown.|Low-cost read-only accounting first; owner native/device gate later. Preserve exact trained integer values and refusal domain. Incomplete clocks block numeric ceiling; integer mismatch or no enclosing gain demotes.|
|5 ARCHITECTURE|Older Quarks preprocessing/PCS and structured public representations.|Potential setup/verification changes, substantial PCS/PIOP/migration cost; no native throughput factor.|Full composition, field/soundness/PCS and joint hiding review. Setup savings cannot erase recurring SC_SZC/witness. Not a drop-in path; no target or privacy change authorized.|


Next owner: actual capture/metadata export and guarded native three-arm differential/profile with all original samples, finals, host assertions/refusals, fresh masks, RNG/transcript/bytes and independent verification; then both-witness/enclosing clocks and resident complete-workload slopes. Next local: account the new trained-block retained phase records and missing two-witness/serialization/verification clocks. No more toy scheduling without native evidence. [Experiment](experiments/causal-axis-selector-20261017/README.md),[handoff](handoffs/20261017-causal-axis-selector.md).

LIVE search: EPFL MSB/streaming docs/June24 commit metadata, current ICICLE4 release/version diff, extended2026/587, new older Quarks2020/1275 and October Plonky3rc.2 refresh attempts. Extended paperMar25 says approved, not revised; preserve qualifier on older ledger records. Quarks PDF403, exact Plonky3/docs.rs pages and several license/commit opens blocked; full dates/licenses/pins scoped in sources-cycle58.json, raw responses retained. Existing Jolt less-than/Thaler/Jagged and cycle0037 comparator are refreshes; no author performance reproduced. Next rotation memory-traffic/batching/quantization, following native clocks.

Accepted independently verified complete private8B proofs/passes/tokens: **0/0/0**. Device: Intel Core Ultra9 185H CPU only, one thread, nice19, CPU0. Proof context length, steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain: **all unmeasured**. No long-context prefill, repeated resident-model pass or decode proof ran. Differential cubes use padded token axes up to32 and up to32 head slots, never an8B workload; T512/T1024/T4096 entries are allocation-free counts. Dense-attention score work grows roughly fourfold when context doubles. Larger workloads remain permitted; all CFS/PCS blinding remains fresh. The >=50 proved-token/s private8B target is unchanged and unachieved.

Research only. Production, runtime, Git, calibration, gates, instructions and reviewer files were not modified. No build, GPU, installation, downloaded script execution, external write/message, heavy queue action or merge. Main agent/Claude reviews and integrates handoffs. Saved reports are not evidence of message delivery or supervisor liveness. D24 remains proposed in the inspected register; no new privacy/profile ruling is accepted.


## Cycle 0059 — 2026-10-17 — trained witness and inclusive-clock audit

Run `20261017T092624Z-0a2ee588`, checkpoint 2026-10-17T09:36:09.547899+00:00. Agenda/target, durable/project memory and
latest3 results read/snapshotted; all297 starting source records parsed,96
historical findings headings indexed;6 LIVE records appended (303 total).
All previous findings/negatives and source bytes retained.

**No native improvement measured. New measured-scope finding:**22 retained
trained TinyLlama T32 one-block runs sum405.980s main-path total, including
294.314s sequence load/native witness/parity (72.49%),16.046s public load,
82.500s prove_run (20.32%),7.400s in-process verify/decode and5.720s unclassified
remainder. Fresh verifier load/read/statement18.822s and verify/decode7.265s are
separate. Receipt sizes sum255,800,336B. These are summed separate-process
CPU diagnostics, not a linked-model wall time or rate; no target tokens count.
Original native thread count is not established here. The local audit did not
rerun proofs or verification. Layer0 optional controls occur after its reported
total, so its67.669s guard child wall is not the same main-path clock. Guard
waits/controls/process teardown must not be called startup.

The historical CLI builds one witness before its prove timer and consumes it
once. New round2 StackSource performs a sealing pass, restart, and proving
rebuild; its boundary-plane/witness pair shares a cache. Sealing depends on each
new input and retains witness refusals; it cannot simply be amortized as public
model setup across distinct resident passes. Current files changed after t5;
we reconstructed historical trained_block.rs/run.rs from the retained patch and
matched both original manifest hashes before interpreting their clocks.

A native accounting defect: RunStats.prove_s's comment excludes witness work,
but both archived/current timer positions include source calls,encoding and sink.
Historical one-block disk writes lie outside prove_run; current stack DirSink
includes write,flush,rename,hash inside it. Verification combines decode/crypto,
and directory verification also includes reads. The5.720s remainder (±0.055s
aggregate rounding radius) cannot be assigned to serialization alone. A
research-only uncompiled patch adds setup/source/encode/sink counters with
explicit subset semantics; it does not optimize proving.

Experiment16,219 accounting/reference checks:22 retained fresh-verifier pairs,
200 synthetic traces/16,000 spans,15 controls. Decimal totals agree with an
independent integer-ms oracle; nested-span subtraction agrees with an independent
endpoint sweep. Synthetic resident fixtures cannot evade the recurring slope;
no timings were fitted to those fixtures. Wall0.107200s,RSS17,052KiB,seed2026101759,
one nice19 CPU0 CoreUltra9 thread,59s/512MiB limits,64MiB estimate. Independent
retained-ms/source/unified-diff audit499 checks,0.004319s,RSS15,100KiB,32MiB estimate.
All140 original evidence pins match. Controls reject missing/duplicate events,
wrong statement/hash/bytes,failed completion,scope relabels,invalid clocks and
invalid nested spans. No native compile/RNG/bytes/privacy/verifier gate ran.

**Baseline/eliminated work/added cost/ceiling:** accounting eliminates zero
native work; adds instrumentation overhead and diagnostic metadata. For the
retained sums only, eliminating all prove_run has a1.25504x ideal ceiling;
eliminating measured load alone1.04115x. Prove-only understates the reported
main-path denominator4.92097x. These are diagnostic Amdahl bounds, not8B
projections. Complete8B ceiling and genuine reusable startup remain unknown.

|Rank|Hypothesis and expected end-to-end impact|Prerequisites, added costs, exactness/privacy and falsifier|
|---|---|---|
|1 REFINED / OWNER|Accelerate both exact trained witness passes; new T32 evidence puts witness/parity at72.49% of its enclosing diagnostics. Local next: isolate matmul/requant/materialization.|Identify exact integer/full-K CPU/CUDA seams; charge packing,reconstruction,planes,transfers and duplicate passes. No new native speed factor. Any integer/refusal mismatch or no enclosing improvement rejects; keep all witness pre-header refusals.|
|2 OWNER|GPU native SC_SZC remains leading historical GPU-assisted proof-phase opportunity.|Original masked clauses/finals/hosted claims/transcript/RNG/PCS/fresh-verifier gates,transfers,scratch and occupancy. Old125M diagnostic deleting allSC_SZC only28.317%; not an8B ceiling.|
|3 TESTED ACCOUNTING / OWNER|Resident complete linked passes may amortize genuine public initialization; current trained load fraction only3.95%,not measured startup.|Split load,sealing,rebuild,encode,flush,decode,verification; fresh masks,accepted openings,peak and lag/drain. Recurring>20ms/new completed position falsifies50/s for that schedule; no target rate before complete linked independently verified workloads.|
|4 OWNER|Public-axis/factory candidate, earlier arithmetic/lifetime benefits unchanged.|Actual captures/native three-arm compile/profile required. No additional arithmetic saving in this cycle. Any original byte/refusal/RNG difference or enclosing regression rejects.|
|5 CONDITIONAL|MORPH layout-stationary arithmetic,older zkMatrix batching,TaSSLE preprocessing and TensorZKP architecture.|High field/PCS/hardware migration and joint-hiding costs; include conversions,working memory,forward witness and nonlinear relations. No native performance factor. Table/setup savings do not remove recurrent witnesses.|

Prior fusion,CSE,cubic,twiddle/table-cache negative findings remain demoted and
preserved. No more toy scheduling without native measurement demand.

LIVE rotation memory-traffic/batching/quantization: new MORPH Apr20,2026 primary
paper/repository (2x representation memory/conversion cost;TPU large fields),
new older zkMatrix Feb4/Feb7,2024 abstract (group batching is not forward witness
work),TensorZKP Aug2026 proceedings refresh (H100/BabyBear8 vs native field),
TaSSLE receivedJul2,2024/revisedMar8,2025 refresh. ICICLE docs explicitly lack
extension challenges; full release commit6c77775961b0e4dc2be359feec1ac11536c18043
resolved and version diff inspected; MIT repository license text inspected,
backend package license not inspected. DocsAug6,2025 date is verified; release
July11 has no year,so no full date asserted. MORPH history/license,zkMatrix PDF,
October Plonky3 exact release/crate fetches failed with recorded errors. No
foreign code copied/executed,installed or timed; author claims not reproduced.
Next rotation exact-witness quantization/arithmetic,then NTT/commitments as
native clocks warrant. Full records/queries/raw responses retained.

Next owner: reviewed diagnostic clocks and one linked trained stack,exact
witness/GPU optimization,then fixed-context resident complete-workload slope.
Next local: allocation-free witness source census into matmul/requant/range and
plane/helper materialization,with a concrete exact CUDA seam and refusal gates.
[Experiment](experiments/trained-phase-accounting-20261017/README.md),
[handoff](handoffs/20261017-trained-phase-accounting.md).

Accepted independently verified complete private 8B proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain and proof context: **unmeasured**. This cycle used one Intel Core Ultra 9 185H CPU thread (CPU0, nice19), no GPU. The retained native records are CPU-only T32, 22 separate one-block runs, zero linked complete-model passes; original thread count is not established here. No long-context prefill, resident complete-model workload or decode proof ran. Dense attention work grows approximately quadratically with context. Larger workloads remain allowed, fresh masks and privacy obligations remain unchanged, and the >=50 proved-token/s target remains unachieved.

Research only. Production/runtime/Git/calibration/gates/instructions/reviewer
files unmodified. No build,GPU,install,downloaded script,external write/message,
merge or heavy queue action. D24 remains proposed in the inspected register;
owner round2 fixes/review do not authorize a privacy claim. Reports are not
notification/liveness evidence.

Final checkpoint 2026-10-17T09:36:35.383884+00:00:28 accounting/artifact checks pass,49 artifact pins;303 source records and historical prefixes preserved;no concurrent owner-memory changes observed. Native compile/proof/privacy gates remain unrun.


## Cycle0060 — exact witness projection census and new linked-stack accounting (20261017T102624Z-c13de864)

Original pinned round-2 baseline: seven native dense projection calls use i64 activations and
accumulation. Six consume checked[-127,127] values; down consumes int16.
AtK2048/4096 the six calls' absolute accumulator bound is33,292,288/66,584,576,
well inside i32. Conservative Kmax132,104 protects every partial sum in any
order. Full down worst-case bounds2^35/2^36 do not fit i32. Score/PV, norms,
requant/range, planes/helper materialization, commitments and serialization
are separate work and are not optimized by this candidate.

Eliminated work: **zero MACs**, narrower operand/accumulator traffic and IO
strided traversal. Added costs: pack/range scan, packed Vec allocation/drop,
256B logical i32 tile, output widening, public route/shape guard and fallback.
The C timings include packing/checking/zeroing/widening but exclude caller
allocations in ALL arms; the Rust candidate allocates its packed Vec and output.
All six calls pack independently; reuse of QKV or gate/up packs is future work.
No native register/spill/peak or wall reduction is known.

Source-loop counts: trainedTiny T32 requires1,912,602,624 projection MACs per
build,1,375,731,712(71.93%) direct-i32 eligible; two builds across22blocks count
84,154,515,456 projection MACs. Allocation-free8B-shaped T512 count is
124,554,051,584/build,72.41% eligible,7,971,459,301,376 for two32-block builds.
These are loop counts over padded axes, not timings or admitted8B profiles.
Full-future-pair attention and pad semantics remain. No private data was read.

Complete-workload ceiling is N/(Ttotal-Csix_native+Cnew_native); neither
Csix_native nor Cnew_native is measured, so no numerical8B ceiling exists.
Even deleting BOTH ENTIRE retained witness-related families bounds that
diagnostic at7.0262× CPU/6.2532×GPU; deleting only sealing gives1.7733×/1.7297×.
Those unattainable deletions are not forecasts, and microbench ratios cannot
be multiplied by projection MAC fractions to infer complete proof throughput.

|Retained owner linked-stack diagnostic, T32 /22blocks /n=1|CPU|RTX4070Laptop-assisted|
|---|---:|---:|
|Reported main-path total, s|528.926|545.079|
|Public load, s|10.203|9.063|
|Input-dependent sealing/sequence-read/parity pass, s|230.648|229.941|
|Prove_run including witness rebuild and durable sink, s|282.618|296.036|
|Witness rebuild/source extraction subset, s|222.999|227.970|
|Prove_run minus that subset (not pure cryptographic proving), s|59.619|68.066|
|In-process verify/read/decode, s|4.872|4.901|
|Fresh-process verifier load/read, s|10.253|9.795|
|Fresh-process verifier verify/decode, s|4.886|4.979|
|Receipt bytes|250,855,088|250,855,088|
|Peak reported host HWM, MiB (not VRAM)|2,200|2,032|
|Raw reported32-position/total diagnostic rate, positions/s|0.060500|0.058707|
|Accepted target tokens|0|0|

These are existing public logs, not proofs or fresh verification rerun here.
Both have matching statement identity, block count and receipt length in the
owner's fresh-process log. Sealing includes input/sequence reads and parity;
source timing includes witness and boundary extraction. Their combined clocks
453.647s/457.911s are **85.77%/84.01% of total**, not isolated matmul clocks.
Neither is safely reusable model startup. Serialization is unsplit inside and
outside prove_run; true startup boundary/fraction and steady slope are unknown.
CPU/GPU totals differ by+16.153s; n=1 shared-host samples do not establish a
GPU slowdown distribution. GPU accelerates selected commitment phases, not
these CPU witness loops. Original native CPU thread count is unestablished.
No driver/power/VRAM measurements or high-end-device result were produced here.

Main experiment:200 synthetic fixtures;17,820
independent Python arbitrary-integer dot checks,59,496
kernel-output checks,318,888 independent divmod rounding
checks and6,348 zero-padding checks. K extrema2048/4096/8192/
16384 use one output only; benchmark shapes are4×128×256,8×256×512,4×512×1024,
both IO/OI orientations. Twelve controls include unchecked narrowing, K overflow,
weight signedness, orientation, dropped padded K, rounding, full-K completion,
and first gate/up refusal order. FP32 cancellation gives0 instead of exact1;
a constructed int16 down sum2^32 wraps to0 and falsely passes a native range
window. No native profile was run. Seed2026101760; total local compile+test
wall1.866833s, RSS37,876KiB and compiler
child peak37,876KiB. Compiler:gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0.
Independent source/patch/accounting audit:145checks,
0.001951s/15,080KiB. AWE arithmetic-only pass:
0.164614s/14,352KiB. Each experiment one thread,
nice19/CPU0,59s wall+CPU/512MiB AS caps; estimated96/32MiB. Tiny own C compile
only; no native Rust/application build, GPU, install, foreign execution or proof.

|Weight layout|T×K×N|wide / narrow literal median|wide / narrow tiled median|
|---|---|---:|---:|
|OI|4×128×256|4.81×|4.81×|
|OI|8×256×512|4.24×|4.64×|
|OI|4×512×1024|5.47×|6.09×|
|IO|4×128×256|0.85×|3.12×|
|IO|8×256×512|1.00×|7.25×|
|IO|4×512×1024|0.97×|7.72×|

Seven alternating-order samples/arm, three calls/sample, shared host, CPU-only
C helpers. These ratios are not trained witness, Rust compiler or end-to-end
speedups; narrowing alone regressed strided IO in these shared-host passes. Earlier
passes are retained; timing variability prevents a precise expected factor.

|Rank|Hypothesis / expected complete-proof opportunity|Prerequisites, added costs and falsifier|
|---|---|---|
|1 REFINED, TESTED SYNTHETIC / OWNER|Six exact int8-fed witness projections can use int32 accumulators. Original baseline had two witness passes; concurrent R3 owner code now tiles/parallelizes and builds once. Incremental benefit versus R3 is unknown.|Stale patch must be reviewed/rebased, then native compiler/witness/refusal/receipt and phase profile; charge packing/allocation/widening. Current R3 uses i32 products widened into i64 accumulators; our i32 accumulation is a potential further change. Keep full K, quantize order and fresh masks. Any mismatch or no enclosing improvement falsifies. Narrowing alone regressed strided cases.|
|2 OWNER|Accelerate remaining native GPU SC_SZC after witness work, following split clocks.|Masked polynomial/finals/RNG/PCS/transcript/privacy gates; launch, transfer, scratch/occupancy costs. Historical one-block phase share is not trained8B evidence. Any oracle/bytes/refusal mismatch or enclosing regression rejects.|
|3 OWNER|Reuse input-independent public setup across fixed-context linked resident passes. Concurrent R3 one-pass work supersedes proposing a cache just to eliminate the old sealing rebuild.|Identity/lifetime and memory/storage traffic; preserve endpoint/parity/refusal semantics, fresh masks/openings and drain. No endpoint-root chaining shortcut. Recurring cost>20ms/new completed position falsifies50/s for that schedule. R3 has no new accepted timing in this experiment.|
|4 OWNER|Exact full-K int16 FFN-down via prior two-byte products, separate from direct int8 route.|Packing, two products, exact i64 reconstruction, full-K final requant, original refusal order, transfers/scratch. Down is27.6–28.1% of these projection MAC counts, not a measured time fraction. Direct int32 down can falsely accept; reject it.|
|5 OWNER, DEMOTED LOCAL|Prior public selector/factory candidates retain their existing scope; no new scheduling toys until native demand.|Actual constructor capture and native literal/fixed/scheduled comparison. No extra arithmetic gain this cycle; compiler may already achieve it. Native parity and enclosing benefit required.|
|6 NEW CONDITIONAL / NEGATIVE FILTER|AWE exact FP4 reconstruction is algebraically valid but not a promising replacement for one native INT8 GEMM on hardware supporting INT8.|Six FP4 products plus plane generation/reconstruction versus native one; author RTXPRO6000/B200 theoretical ratio1/3 excludes those costs. B300 differs; no5090 measurement. Preserve exact integer/wide reconstruction, fixed-format semantics and privacy. Revisit only for a named architecture lacking efficient INT8 or a measured contrary bottleneck.|

LIVE primary review: [Integer Alibi](https://arxiv.org/abs/2608.13756)
(Aug13/18,2026) reinforced the accumulator/epilogue boundary; our weights include
-128, so the independent absolute-product bound is127×128, not127².
[CUTLASS PR3302](https://github.com/NVIDIA/cutlass/pull/3302) remains open;
March9 example commit382200f18f8a1f906799dde38afa7ad2840dcea5 was resolved from
metadata but its diff failed to load. C++ mma_sm80.h was inspected on main.
CUTLASS4.8.0 changelog saysSep17,2026 while release UI saysSep22 without a year;
keep these as different date evidence. C++ BSD-3-Clause license text inspected;
python/CuTeDSL has separate NVIDIA EULA terms. No foreign code imported.

[AWE](https://arxiv.org/abs/2609.24519), newSep21,2026 lead, passed our own
65,536-pair arithmetic reproduction of one six-product INT8 encoding; contiguous
coverage±148 with all stored planes≤6, FP32 absolute-sum boundK≤466,033.
Changing one coefficient failed42,849 pairs. This is algebra only. Its own
RTXPRO6000/B200 theoretical comparison gives1/3 nativeINT8 throughput before
plane generation/reconstruction; fewer products than its9-product baseline
does not beat a native1-product baseline. No author runtime replicated.

Older [Ozaki/ozIMMU](https://arxiv.org/abs/2306.11975) refreshed
(Jun21,2023/Mar30,2024), already assessed in cycle22; no new implementation gain.
[zkIE](https://github.com/trustless-ai/zkIE) README discloses public activations
and verifier forward reexecution; not a P1 replacement. History fetch failed,
so no verified update/commit for zkIE. Exact dates, license scope, commit scope,
queries and errors are in source records. Native LIVE search was used; source
text was treated as untrusted data, and no downloaded script was executed.

Owner next: compare the stale six-call research patch with the concurrent
R3 native path before any integration. R3 uses tiled/parallel i32 products with
i64 accumulation and removes the old pre-prove witness pass using exported
endpoints checked during proving; no new R3 timing/verification is reproduced
here. Our potential remaining delta is full int32 accumulation on six checked
int8 sites. Review/rebase only if that delta merits measurement, then compile under the
shared build/heavy guard, run native witness/reference and first-refusal gates
at toy/padded/trained geometries, then byte/RNG/transcript/fresh-verifier gates.
Profile all seven projections, norm/range/plane materialization and the current
one-pass source with allocation/packing included before committing GPU integration.
No heavy job was queued here; main agent/Claude owns review and integration.

Next local: allocation-free witness allocation/lifetime census, focused on
initial pl allocation/replacement and clones in the NEW one-pass path. Do not
duplicate the owner's parallel-loop or one-pass implementation. No private
fixture/cache is authorized for these research artifacts. Next search rotation: memory traffic and
NTT/commitments, following new native phase clocks; preserve architecture leads
and all previous negative results.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, context length, proof latency/lag/drain: **unmeasured**. Local experiments: one Intel Core Ultra 9 185H CPU thread, CPU0, nice19, no GPU. Retained owner diagnostics: TinyLlama1.1B, T32,22 linked blocks, one CPU pass and one RTX4070Laptop-assisted pass (not resident repeats); shape privacy acceptance is absent. No long-context prefill, resident-model sweep or decode proof ran. Longer contexts increase dense-attention work approximately quadratically. Larger workloads remain permitted with fresh masks and all privacy obligations; the >=50 proved-token/s target remains unchanged and unachieved.

[Experiment](experiments/exact-witness-limb-census-20261017/README.md),
[owner handoff](handoffs/20261017-exact-witness-projections.md). Historical findings,
fusion/cubic/CSE/twiddle/table-cache and privacy negatives remain preserved.
Production/runtime/Git/calibration/gates/instructions/reviewer files untouched.


## Cycle0061 — deferred witness planes after R3 moves the bottleneck (20261017T112624Z-88d6b64e)

Checkpoint2026-10-17T11:38:24.429802+00:00. AGENDA/current target,durable/project memory,source ledger
and latest3 experiment results read/snapshotted.309records read;6LIVE sources
appended,315total. Historical findings/negative prefixes preserved.

The new Python experiment passes72 synthetic fixtures,5928 planes,293384
word comparisons and7 controls. Local run0.379222s,
17456KiB; independent audit162checks,
0.002379s/14472KiB. One nice19 CPU0 thread,
seed2026101761,59s wall/CPU,512MiB AS,96MiB estimate. No native compile/proof,
transcript/RNG execution, GPU or fresh receipt verification.

Source-pinned R3 build_shaped eagerly initializes78 non-table i64
planes and replaces30 direct outputs plus16 norm-limb vectors. Candidate
leaves only those46 slots empty. Every scatter domain keeps its zero fill;
full owned producer vectors, padded words, E's second pass, arithmetic and
control flow remain unchanged. Three histograms stay empty. This differs
from cycle20's Fp A-matrix assembly and cycles17/18's lookup-reader work.
There is no clone removal in the patch. Independent family catalogs and
source first-use checks supplement the separate sparse last-write oracle;
variable two/three score/probability limb IDs test remapping, not new profiles.

AtTinyLlamaT32/T128/T256(count-only), aggregate initial allocation avoided is
24.438/103.754/223.508MiB; final raw planes46.204/217.816/555.633MiB unchanged.
Llama3-8B T32/f_e9 count avoids49.126MiB, final90.392MiB; T512 count avoids
906.016MiB, final2234.266MiB. Final four-limb/f_e9 census uses source row
widths; larger contexts are count-only continuations, not admitted results.
Aggregate allocation is not concurrent peak or physical zero traffic;
calloc/compiler may avoid touching pages. Actual peak can be at A/H/lookup
construction after the builder returns. This patch does not establishT256 fit.
TinyLlamaT128's three D clones6MiB and score-support indices4MiB stay unchanged.

Baseline is pinned R3 initial plane construction. Eliminated work is46
redundant initial vector allocations, not final storage or relation work.
Added cost: small public flags vector,46 ID marks, existing-map branches and
catalog maintenance. Candidate uses initialized safe Vec operations, no value
dispatch, unsafe reads, mask reuse or skipped constraint.8B ceiling remains
N/(T_complete-saved_native_time+added_cost), all times unknown. Falsify any
native plane/pad/first-refusal/RNG/transcript/byte difference, unchanged actual
peak for capacity, or enclosing regression for speed. Deleting ENTIRE T128
witness clock leaves155.781/129.911sCPU/GPU, only1.08237/1.09908x, arithmetic
~0.8217/0.9853diagnosticpositions/s. This is a parent-phase upper bound, not a
candidate prediction or8B bound. No actual physical saving measured.

All six owner diagnostic pairs have matching22blocks,statement identities,
bytes, successful guards and0completion markers. n=1,one cold pass,16Rayon
threads per arm;GPU isRTX4070Laptop8.6GB label,not5090. T128CPU/GPU sampled
processHWM4.82/3.03GiB;GPU VRAM3105MiB. GPU load9.393s is6.5785% of wall,
NOT isolated startup. Fresh verifier8.451s plus11.307s model load; in-process
verify8.742s. Prove_run minus witness includes boundary work,segment encoding
and sink; witness includes parity/extraction. Pure proving/serialization and
steady slope remain unknown. R2/R3 identities differ, so529s->56s is not a
controlled A/B. No trained-shape privacy acceptance is claimed.

Initial named-vs-unnamed-limb catalog assertion and a diagnostic f_e10/generic
8B-width census are retained and superseded. Final run source is hashed.
The independent162-check audit reconstructs the exact one-hunk patch,checks
12closed-form payload rows and retained source/log hashes. Seven native files
had no live drift at audit. Native gates remain unrun; owner must recompare
pins, guarded-build, all-plane/pad/first-refusal/reference check, exact native
RNG/transcript/frozen bytes and fresh verifiers, then phase/HWM/workload clocks.
Research does not integrate or merge. No real private data was copied.

|Context|Device arm|Whole process s|Diagnostic positions/s|Witness/extraction s|Prove-run minus witness s|Fresh verify s|Proof bytes|
|---:|---|---:|---:|---:|---:|---:|---:|
|32|CPU|56.230567|0.569085|2.683|40.169|3.152|250855088|
|32|GPU-assisted|60.758747|0.526673|2.774|40.776|3.431|250855088|
|64|CPU|84.925581|0.753601|5.085|64.831|4.925|333316880|
|64|GPU-assisted|89.300485|0.716681|5.246|63.507|5.011|333316880|
|128|CPU|168.612364|0.759138|12.831|136.177|11.100|497665904|
|128|GPU-assisted|142.783399|0.896463|12.872|107.079|8.451|497665904|

1. **OWNER, largest recurring-time opportunity:** obtain trained slot/commitment clocks, then move the largest measured phase to the GPU. T128GPU prove_run minus witness is107.079/142.783s but includes boundary/serialization/sink. The old synthetic SC_SZC share cannot be transplanted. High CUDA integration; charge launches/transfers/scratch/drain. Exact masked polynomial, terminal oracle, RNG, bytes, fresh verifier and privacy gates remain owed. Any mismatch or unchanged complete time falsifies a gain.
2. **OWNER, refined resident question:** after one-pass witness construction, which public model/NTT/digest setup survives repeated fresh complete proofs? Fixed-context pass sweeps with valid identities, fresh inputs/masks, recurring clocks/verification and lag/drain are needed. Cold load fractions5.76–17.26%CPU/6.58–15.05%GPU are not startup fractions. Costs are retained memory and recurring work; a recurring budget above20ms/new completed position falsifies50/s for that schedule. No endpoint-root reuse or decode inference.
3. **NEW/TESTED, demoted as speed priority:** defer46 initial i64 planes replaced by owned producers. Low/moderate initialization integration;103.754MiB aggregate allocation avoided atTinyLlamaT128, final217.816MiB unchanged. Added public flag vector/marks and catalog maintenance; physical allocator traffic unknown.8B ceilingN/(T-M+C), unknown. Native value/pad/first-refusal/RNG/bytes divergence or unchanged actual peak/workload rejects the corresponding claim. Deleting the entire T128GPU witness clock gives only1.09908x.
4. **NEXT LOCAL, capacity question:** reconcile cycles17/18 lazy/typed lookup readers with current R3/R4 lookup_values_at, byte_histogram_at and H-helper retention. Capture actual public Lk catalogs and count borrowed single-term versus computed affine/multi-term columns at trained geometries; retain wrapping-i64 and whole-table zero-denominator controls. This transfers earlier evidence to the new seam. Charge repeated scans, dispatch and lost Rayon parallelism in owner measurements; preserve indexed order and padded words.
5. **Deferred architecture leads:** Oct14 HybridSpartan correction, new older sublinear-space paper and hc-stark SSD orchestration need substantial PCS/composition or adapter work. Charge scratchIO, masks/state binding and verification; no author performance reproduced. Invalid hierarchical TensorCore NTT remains rejected; old fusion/CSE/quantization negatives preserved.

LIVE review found a new recent [HybridSpartan revision](https://eprint.iacr.org/2025/908),
receivedMay21,2025/revisedOct14,2026; its abstract corrects proof-size costs.
New older [Nye2025](https://arxiv.org/abs/2509.05326),Aug30/Sep17,2025, qualifies
linearPCS transcript identity separately from changed Merkle/FRI transcripts.
[hc-stark](https://github.com/logannye/hc-stark) is a new boundedSSD reference,
current READMEPlonky3 0.6.1/pre-production; legacy companion claims not reproduced.
History/license/releases blocked; MIT only README/repository claim this cycle.
Known [EPFL rewrite](https://github.com/compsec-epfl/efficient-sumcheck/blob/main/CHANGELOG.md)
is Unreleased and changes wire/transcript. Jun24,2026 history resolves full
merge target9e55dc3a020fe9e94a7617628587685eb39b32ce, but inspection returned429
thenInternal Error; it is exposed/uninspected, not a source pin. Known
[NTT release](https://github.com/Artemarius/cuda-zkp-ntt/releases) still labels
hierarchical output invalid; main MIT text inspected,release year unverified.
New ePrint2026/2494 primary/PDF blocked,so mirror date/content not accepted.
Six appended records retain exact dates,URLs,license and commit limits.
Search queries/access errors are in the experiment search log. No source was
executed,installed or treated as instructions. No author speed reproduced.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Its context, steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag and drain are **unmeasured**. Local device: one Intel Core Ultra9 185H CPU thread, CPU0, nice19; no GPU. Owner diagnostics: trained TinyLlama1.1B,22 linked blocks, T32/T64/T128, one cold pass per CPU or RTX4070Laptop-assisted arm,16 Rayon threads,n=1; fresh-verifier logs inspected,not rerun, no privacy acceptance at that shape. No resident sweep or decode ran here; no new prefill proof ran. Larger workloads remain allowed with fresh masks; dense attention grows approximately quadratically with context. The >=50 proved-token/s target remains unchanged and unachieved.

[Experiment](experiments/witness-plane-lifetimes-20261017/README.md),
[handoff](handoffs/20261017-deferred-witness-planes.md). Next local is current
R3/R4 Lk capture/borrowability census; owner needs trained phase clocks before
an end-to-end estimate. Rotation:memory/NTT ->lookup/softmax/GKR ->batching/
composition ->arithmetic. Production/runtime/Git/calibration/gates/instructions/
reviewer files untouched; no heavy jobqueued or external message/write.
Saved reports are durable files,not delivery or liveness evidence.


## Cycle 0062 — 2026-10-17 — borrowed lookup catalog; trained GPU phase correction

Run `20261017T122624Z-c30acfa0`. [Experiment](experiments/lookup-borrow-catalog-20261017/README.md),
[results](experiments/lookup-borrow-catalog-20261017/result.json),
[handoff](handoffs/20261017-borrowed-lookup-columns.md),
[dated report](progress/20261017T122624Z-c30acfa0.md). All historical findings remain intact.

**Tested question:** can current R3/R4 identity lookup expressions borrow an
existing padded witness slice rather than materialize another i64 column?
Yes in a synthetic semantic differential, including scaled expressions whose
public coefficient is 1. The current constructor has only single-plane terms;
general affine/multiterm cases retain owned fallback. Cow plumbing preserves
the original helper bodies, full padded prefixes, invalid bucket-0 behavior,
whole-table denominator refusals and drop order in the uncompiled proposal.
No private state or mask is reused across proofs.

48 fixtures, 288 domains, 4,176 columns, 23,834 i64 comparisons, 12,328 Fp2
helper values and 11 negative controls pass; five extra generic expressions
exercise fallback. Final run 1.050006 s / 17,464 KiB; independent 235-check
audit 0.011948 s / 14,904 KiB. Seed 2026101762, CPU0, one thread, nice 19,
59-second/512-MiB caps. The audit independently checks 12 closed-form census
rows and all 22 public layer manifests. Initial audit span-delimiter failure
is preserved and corrected. No native build/Rayon/proof/GPU/private payload.

At TinyLlama T128, 57/83 descriptors borrow: 221.25 MiB looked payload becomes
53.75 MiB owned, avoiding 167.5 MiB (75.706%). These are source payload counts,
not measured RSS/traffic/time. Final witness/A/H/masks/terms are unchanged in
the proposal. Added costs: classification/descriptors/generic histogram and
compiler/task-balance effects. Larger-context and 8B rows use hypothetical
geometry/calibration; no admission, fit or native speed claim follows.

**Decisive priority correction:** owner R4 instrumented T128 runs completed
during this cycle. CPU/GPU-assisted process 175.258632/161.857226 s; witness
13.236/15.899 s; prove-minus-witness 139.836/119.910 s includes boundaries,
serialization and sink; in-process verify 10.514/10.148 s. Startup and
serialization remain unisolated. Both use 22 linked trained 1.1B blocks,
one cold pass, 16 Rayon threads, n=1, and 497,665,904-B receipts. Guard records
and final events match; fresh-process verifier evidence was not inspected,
so these samples contribute zero credited positions. GPU is RTX 4070 Laptop.
Only filtered public timing/statistic lines and metadata hashes were retained.

GPU D/F zero-checks cost 25.353/19.484 s, softmax 11.834 s; D/F masked
sumcheck substeps cost 19.860/16.457 s. Commit A/H is 3.995/3.625 s. Lookup
construction plus histogram is just 0.748 s (CPU 0.517 s). Even deleting that
whole mark gives at most 1.004643x GPU / 1.002959x CPU directly with other
work fixed. Borrowing keeps histogram/H arithmetic, so demote it for speed
while retaining its unmeasured capacity opportunity. Do not transplant the
old synthetic softmax bottleneck into trained profiles. Source-captured
`SC_FZC` at argument.rs:1602 still uses extension multiplication by public
base constants; this is the next local test, with compiler effects unknown.

LIVE literature/implementation review added five source records (320 total).
New older HOBBIT, ring lookups, recent StateSync-GKR scope and repository
licensing/release metadata were assessed; source details and primary links
are in the dated report/sources.jsonl. No author performance was reproduced.
All access failures and uninspected exposed commit identifiers are explicit.

Current ranked queue:

1. **Owner: trained GPU D/F zero-checks.** New T128 GPU-assisted slot clocks are D 25.353 s and F 19.484 s, versus softmax 11.834 s. Their shared masked-sumcheck portions are 19.860/16.457 s. Follow these measured costs; retain slot-polynomial/final-oracle, RNG, transcript, PCS, fresh-mask and independent-verifier gates. Charge launches, transfers and scratch. A mismatch or unchanged enclosing workload cost falsifies a speed gain. This is one 1.1B diagnostic, not an 8B forecast.
2. **Owner: resident fixed-context fresh-proof slopes.** Reuse only valid input-independent public model/NTT/digest setup. Measure recurring witness/proof/serialization, verification, startup, backlog and drain. Added retained memory and identity maintenance; no reused private openings or masks. More than 20 ms recurring cost per newly proved position falsifies 50/s for that schedule. Keep prefill, resident passes and decode separate.
3. **Tested, demoted for speed: borrowed identity lookup columns.** Avoid 167.5 MiB of looked payload at TinyLlama T128; final witness unchanged. Public classification, Cow descriptors and possible compiler/task-balance costs are added. No extra affine recomputation or scan. Peak RAM is unmeasured. Deleting the entire lookup+histogram mark gives at most 1.002959x CPU / 1.004643x GPU directly with other costs fixed. Native word/refusal/bytes divergence rejects correctness; unchanged measured peak rejects capacity gain; unchanged complete time rejects speed gain.
4. **New next local experiment: specialize the current F zero-check's public base-field constants.** The pinned `argument.rs:1602` still uses extension multiplication by `p1`, `k_h` and `k_g`; D and softmax have prior Stage35 base-constant work. Capture the F closure's exact current grammar and compare a mul_base rewrite against an independent full-extension reference, including helper, pad and hosted terms. First census actual operations; the compiler may already simplify them. Native integration is small/moderate, but no end-to-end estimate exists. Deleting the entire F slot would give at most 1.136852x on this GPU diagnostic; this local change can remove only a subset. Any polynomial mismatch or no native enclosing benefit falsifies it. Do not redo a generic arithmetic identity toy without the actual F closure.
5. **Retained/deferred:** the duplicate-descriptor histogram idea removes at most 8.36% of histogram input visits at T128, inside a tiny phase, so demote it behind F work. Prior deferred witness allocations/int8 accumulation remain unintegrated owner candidates. HOBBIT is an architecture lead with streaming-access/PCS costs; ring lookup arguments are not a native field replacement. Preserve all prior negative results.

Next owner: D/F native phase optimization and all receipt/privacy/byte gates.
Next local: source-captured F polynomial base-constant specialization, with an
independent full-extension reference, pad/helper/host controls and exact cost
census. Histogram deduplication is demoted because its measured parent is tiny.
The borrow handoff remains review-only; no native build or heavy job queued.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Context, steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, latency, lag and drain remain **unmeasured** for that target. Local experiment: one Intel Core Ultra 9 185H CPU thread, CPU0, nice 19; no GPU. No prefill proof, resident-pass sweep or decode ran here. Larger workloads remain allowed with fresh masks; dense attention grows approximately quadratically with context. The >=50 proved-token/s target is unchanged and unachieved.

## Cycle 0063 — 2026-10-17 — F constants/support factoring; new 8B clocks

Run `20261017T132624Z-393ef603`. AGENDA/target/durable/project memory and latest
three results read, startup snapshots preserved, STATE checkpointed early.
Five LIVE primary records appended (325 total), with exact access/date/license/
commit scope and failed fetches. New older implementation leads: LambdaClass
2025 SVO implementation (one-linear-factor boundary), PRPLL consumer-GPU NTT
(different arithmetic; GPL3, no code copied). October16 Plonky3 rc.2 refreshed;
recent algebraic-geometry primary still Internal Error. No author speedup is
reproduced or transplanted.

Current trained-lane SC_FZC captured with its actual field/helper/pad/gate code.
Three variants against independent Python integer-pair Fp2 equations:480
fixtures /2,480 comparisons (528 ordinary round-sample and32 final-terminal
comparisons included),9 algebra mutation controls pass. All336 public-shift/
pad/helper-size combinations occur. Actual Rust executed API census:combined
37->30 general products unpadded,49->42 padded,9->14 mul_base calls. Three limb
and two shift constants become base products; three clause support factors
become one. Helper and activation LogUp remain ungated; host/pad terms intact.
Added one accumulator and one addition, no tables/transfers/randomness.

Isolated shared-host CPU medians:combined1.114x unpadded/1.098x padded;
**negative preserved:**support-only0.990x unpadded despite fewer calls.
Seven repeats x8,192 evals/variant/branch, first excluded; ranges overlap,
setup excluded. Isolated LLVM arithmetic/capture also shrinks, not native
instruction counts or peak. Differential1.692s/17,948KiB, compiler138,316KiB;
separate45-check audit2.049s/19,308KiB, compiler137,956KiB. Seed2026101763,
CPU0/IntelUltra9 185H, one thread, nice19,59s/512MiB caps. Two initial harness
failures retained. Standalone std-only rustc, no Cargo/production build/proof.
Unapplied patch and validation gates:
[handoff](handoffs/20261017-fzc-public-constants.md),
[experiment](experiments/fzc-public-constants-20261017/README.md).

NEW retained owner8B functional diagnostics:32 linked blocks,Llama3-8B
8,030,261,248 params,T32,one cold pass perCPU/GPU arm,16threads,public weights.
CPU/RTX4070Laptop process384.542564/391.287091s; witness18.629/18.109;
prove_run208.019/213.831 inclusive; block reload79.222/77.997;
prove-minus-witness/reload110.168/117.725 still includes sink/serialization.
Initial digestload83.012/79.490,seal.020/.044; partial pre-prove load/seal
fraction21.595%/20.341%, full startup/prefill fraction unmeasured.
Inprocessverify93.356/92.741;freshverify96.103/90.935 includes82.836/77.702
block reload, plus initial fresh load80.675/78.635. First fresh success
load+check176.778/169.570;CPU verifier guard456.227 includes11controls, GPU
169.595 no controls. All success markers/aggregate events inspected, not rerun.
Receipt465,815,776B perarm;sampledRSS1.90/1.57GiB, GPUVRAM2369MiB.
Diagnostic32/process rates.083216/.081781 positions/s; no resident/decode slope.
Shape privacy acceptance and8B independent review remain open; no target credit.
Full clocks/source qualification in
[dated report](progress/20261017T132624Z-393ef603.md) and owner-accounting.json.

Ranked:1 public authenticated setup/weight residency (actual8B loading);
2 owner D/F device/driver work;3 tested small F arithmetic candidate;
4 new next-local three-bracket F grouped equality seam. Borrowing retained
for capacity, demoted for speed; every prior negative/privacy finding preserved.
F-deletion ceiling on earlier1.1B T128 GPU diagnostic1.137x. New8B F subclock
absent. Deleting all new8B proof-minus-witness/reload caps cold-process ratio
1.402xCPU/1.430xGPU, with other costs fixed; no5090 prediction. Need owner native
shape/byte/RNG/PCS/transcript/privacy/fresh-verifier gates and enclosing A/B.
Next local:complete F grouped-bracket oracle; next owner:review candidate and
profile8B/public immutable reuse with real memory/lag/drain/serialization clocks.

Target-compliant accepted private8B proofs/passes/positions **0/0/0**; distinguish
the newly completed, freshly verified owner functional diagnostics above.
Steady-state, full startup fraction, serialization, latency/lag/drain remain
unmeasured. No long-context sweep/resident repeat/decode here. Larger workloads
remain allowed with fresh masks; dense attention scales quadratically with
context. >=50 proved tokens/s unchanged/unachieved. Research only; production,
runtime,Git,calibration,receipts,gates,instructions/reviewer files untouched.


Cycle0063 final addendum: live layout.rs/shape.rs changed with owner CS-8 validation methods. Initial final live-pin audit failed; exact drift/failure retained in experiment. Captured F argument/field stayed pinned; local results bind captured snapshot only. Rebase/review before native integration.


## Cycle0064 — current F three-bracket grouped arithmetic, 2026-10-17

Run `20261017T142624Z-6b84b6ef`. New captured F source test, not a repeat of
generic equality algebra: B0 degree3; two host brackets degree1 unpadded/2
padded. Current ClosureRounds.recover_one(None) baseline is retained and
independently compared to unoptimized rounds and GroupedEqRounds. Full
original-cube arbitrary-integer checks include off-grid extension points,
actual zero-factor fallbacks and separate extension-like polynomial rows.
72fixtures,1600 cross-evaluator round values,960 independent cube values,
1512terminal words,512bracket values,128extension-like values,12controls pass;
190recoveries/98fallbacks. Independent290-check degree/source/work audit passes.
Run7.059977s/74824KiB; compiler149768KiB; audit0.005162s/16112KiB. Seed2026101764,
IntelCoreUltra9 185H/CPU0,one thread,nice19,59s/512MiB limits. Native Rayon
substituted with serial iteration. No native crate/proof/transcript/PCS/privacy
or device gate. Three corrected harness/audit failures retained.

For H=2^(n-1), current full closure9H-4 calls; main bracket7H-3; each host
3H-1 unpadded/5H-2 padded. Added split Eq setup, weighting/interpolation,
up to3(n-1) inversions and subgroup state. Original tables/folds remain.
Small N16 grouped is slower (baseline/grouped0.633/0.731). N256/4096/8192
ratios1.034–1.423; N8192 crosses the serialized chunk cutoff and padded gain
falls to1.031. Shared-host microtiming, not a stable factor or native rate.
Do not multiply it by the prior constant rewrite or a device forecast.

Unapplied `handoffs/20261017-fzc-grouped-equality.md` identifies argument.rs
SC_FZC + existing GroupedEqRounds. Native correctness/bytes/masks/RNG/PCS/M/
shape-privacy and fresh-receipt verification remain owner gates. Active owner
F-device work takes precedence; no duplicate production edit or GPU job here.
Deleting ALL masked F16.457s from prior1.1B GPU161.857226s caps gain1.113184x;
whole F19.484s deletion caps1.136852x. No actual8B F subclock or5090 evidence.

Current owner public table/phase records re-read/pinned;8B T32 onepass perarm
384.542564CPU/391.287091GPU seconds, witness18.629/18.109, inclusiveproof208.019/
213.831 includes reload79.222/77.997 and remaining110.168/117.725. Diagnostic
32/process0.083216/0.081781. Partial startup load+seal21.595%/20.341%; full
startup/prefill and serialization isolated clocks absent. Fresh check96.103/
90.935 plus initialload80.675/78.635. Owner functional freshlyverified stack
evidence remains distinct from target credit; shapeprivacy/8Breview open.
Accepted newlyproved targetpositions0. No resident/decode/longprefill result.

Six LIVE primary records appended (331total). NEW older Arkworks product-list
prover is common-degree, adjacent-pair/MSB incompatible without translation;
not transplanted. Concrete Plonky3Eq PR has author small-shape and parallel
regressions and a one-product Eq fill; local harness deliberately keeps native
two-product fill. October preparation studies do not license private/mask
reuse. Failed target commit/docs/license fetches explicitly retained.

Rank:1owner F/D device arithmetic with full-workload costs;2owner immutable
public residency across fresh complete passes;3tested F grouping, keep small
negative;4NEW local audit of F-device logical-term bandwidth numerator versus
actual table/buffer/DRAM traffic and arithmetic cost. No expected speed without
measured subclocks/counters. Next local: source-captured buffer census, then
lookup/softmax/composition rotation. Full dated report and limits retained.


## Cycle 0065 — F-device source traffic, 2026-10-17

Run `20261017T182105Z-44205280`. No proving improvement established. Captured active owner
direct/lean CUDA functions executed only as serial CPU functions with ordinary
modular arithmetic. Independent Python semantic reference passes96fixtures/
384schedules,6288Fp2 round values,576recovered s(1),7968terminals,4128phase
access assertions,384closedforms and10controls. Separate148-check audit and
7687Eq outputs/3controls pass. Main0.759414s/audit0.368121s,oneCPUthread,nice19,
seed2026101765,59s/512MiB limits;compiler peak<35MiB. No GPU/native proof.

N=2^n,K=20/21: direct separate80K(N-1);direct fused64KN-48K. Lean either
schedule(32M+48K)(N-1),M32 unpadded/33+W padded(nonzero public pad weights).
Direct fusion eliminates20% table accesses,15.38% including counted504N build.
Owner Rust direct counter agrees;captured DESIGN fused TOTAL1344N should be
1848N asymptotically atK21. Lean stores then rereads stages;fusion eliminates
no source table accesses there. Compiler/register/cache/launch effects can
still affect time;no runtime ordering or DRAM regression is asserted. Eq
build counters charge outputs,not input/temporary reads. All tables incl
round0 are16B Fp2;compact/base first round remains future. The plan1224N is
a different normalization,not measured hardware traffic or a50/s verdict.

Unapplied handoff:`handoffs/20261017-fzc-device-traffic.md`;research code and
note patch under`experiments/fzc-device-traffic-20261017/`. Kernel/Rust pins matched at audit; owner progress ledger changed and both
versions are retained. Updated ledger records successor build and queued t2
test, without an accepted device result at inspection. No production/source/instruction/reviewer edits or GPU job.
Current owner testmarker143/ledger do not establish a successful device run
or liveness. Six LIVE primary records appended(337total):new older hierarchical
Roofline paper/NERSC workflow,modern NVIDIA replay/cache guide,August
instruction-wall/Valk artifact,October16 Plonky3 release. Access/date/license/
commit scope and failed fetches retained;no author speedup reproduced.

Ranked:owner full device residency;owner immutable public model residency;
new/tested variant-aware F measurement;next local helper producer/commit/Freader
representation/lifetime audit. Prior lookup privacy and small-phase negative
findings retained. Whole earlier1.1B T128GPU maskedF deletion ceiling1.113184x;
no 8B F subclock. Owner T32 cold diagnostics remain CPU 384.542564 s /
GPU 391.287091 s in the dated report with all clocks. No steady-state,
isolatedserialization,fullstartup/latency or high-end target result. Accepted
new target proofs/passes/positions0/0/0;50/s unchanged/unachieved. Larger
workloads allowed with fresh masks;resident prefill/decode remain distinct.


## Cycle 0066 — resident helper integer/field boundary, 2026-10-17

Run `20261017T192105Z-c342a26b`. No proving speedup established. AGENDA/target and durable/project
memory consulted; current sources and latest three results inspected, early
STATE/startup snapshots retained. Five LIVE primary records appended (342 total).

Source audit: the active F device builder already reads resident A/H; no per-F
helper host reupload is removed here. Earlier producer still materializes
wrapping-i64 lookup columns, makes U8 helpers on CPU, copies each Fp2 Vec into
planar H and uses the tagged owned committer. Existing legacy device-H API
needs tagged ownership and host-reader coherence before a block port.

NEW tested hypothesis: generate U8 H from resident A, drop looked after the
histogram. **A-only field affine evaluation fails.** Signed -2^63 and p-2^63
have the same A residue but native wrapping scale-2 yields 0/-8589934590 and
different H. Scale2 is a real Q/K rotation pin. Across 48 public catalogs,
4176columns/106962fieldwords, field-only has5323differences. Helper-stage zero
status reverses in both directions. This is malformed/internal full-i64
compatibility evidence, not an admissible-input attack or accepted-proof forgery.

Compiled research codec adds one PRIVATE bit for each relevant source word;
only residues [p-2^63,2^63) have two i64 preimages (2^32-1 residues). Unsigned
word reconstruction + wrapping affine evaluation exactly match native values.
Identity denominators need no bit; bounded synthetic arithmetic also matches
field evaluation. 67483identity and 35654bounded words pass.
86,029initialcodec entries include allint16/randomi64/ambiguity boundaries;
7,294,208codec visits include repeated FFI fixtures, not unique/proved positions.
35Hfixtures/2436Fp2values, sentinel gaps and5refusal cases pass;12controls.
Independent 5375-check audit +700full-extension inverse outputs and2bit-index
controls pass. Main 4.336897 s / 29740 KiB, compiler 133848 KiB;
audit 0.192148 s / 17664 KiB. OneCPU 0/CoreUltra 9 185H thread,nice 19,
seed 2026101766,59s/512MiB limits;std-only Rust, no Cargo/native proof/GPU.
Failed-buffer/Rayon/transcript/RNG/PCS/mask/receipt/privacy gates remain owed.
First passing evidence and a strengthened midpoint-control revision retained.

COUNTED illustrative TinyLlama T128: 221.25MiB looked (prior borrowing leaves
53.75MiB),0.609375MiB source ambiguity bitmap,235.25MiB U8 H still required.
No peak/traffic/time saving measured. Add packing/transfer/metadata/reconstruction,
fallback and tagged device H/CPU coherence. Earlier1.1B T128 cold GPU process
has8.844/161.857226s in allU8H: entire-parent deletion ceiling1.057799×;
CPU6.911/175.258632 ->1.041052×. No actual 8B helper clock or5090 estimate.

Unapplied handoff:`handoffs/20261017-resident-helper-integer-boundary.md`;
prototype:`experiments/lookup-helper-staging-20261017/resident_codec.rs`.
Rank:1owner whole prover GPU;2owner immutable public-model residency;3tested
resident U8 compatibility/capacity (secondary);4NEW older Logup* virtual lookup
architecture. Native looked columns are already uncommitted; do not deduct
that nonexistent commitment again. Next local: small pushforward/private view
and binding audit, preserving fractional-GKR D/C leakage and full-table
refusal negatives. Added GKR/PCS/masks/composition cost and exact displacement
must precede any proposed H-row saving. All older negatives remain.

Owner functional8B T32 cold baseline carried, not rerun:32 linked blocks,
one pass perCPU/RTX 4070 Laptop arm,16 threads. Process384.542564/391.287091s;
diagnostic32/process .083216/.081781 positions/s includes in-process check.
Witness18.629/18.109;inclusiveprove208.019/213.831 includes reload79.222/77.997;
remaining110.168/117.725 includes sink/serialization. Partial load+seal startup
21.595%/20.341%;full startup/steady slope/isolated serialization/latency/lag/drain
unknown. Fresh check96.103/90.935 plusinitialload80.675/78.635s;receipt465815776B.
D24 round 3 now explicitly accepts8B profile soundness (18:36UTC); shape privacy
still open, laterR5/GPU changes not thereby accepted. Owner captured ledger
has successful device-body fixtures and a failed seeded TEST header, then
queued successor gates; no complete new device receipt or speed claim here.

New target-compliant fullprivate8B proofs/passes/positions0/0/0. No resident
repeats, longer prefill or decode ran. >=50/s on5090/high-end unchanged and
unachieved; larger workloads allowed with fresh masks, and context attention
can grow quadratically. Research/runtime/production boundaries held. Full
clocks/ranks/sources/blockers:`progress/20261017T192105Z-c342a26b.md`.


## Cycle 0067 — private LogUp* pushforward boundary, 2026-10-17

Run `20261017T202105Z-363d38a1`. No proving improvement found. Current AGENDA,
target, durable/project memory,342prior sources and latest3results read;
startup bytes/hashes retained. Eight LIVE primary records appended(350total).

Source-field std-only Rust pushforward:405fixtures,23166Fp2 bucket values,
405virtual claims/405support checks,14controls pass. Table2/4/8/16/256,
N1/2/4/8/16/64,empty/single/odd/full support,full-extension/base/Boolean
challenges. Separate polynomial-convolution/count audit24014checks,17F17
challenges and3binding controls pass. Main0.356768s/28256KiB,compiler122168KiB;
finalaudit0.088526s/24432KiB. CPU0,CoreUltra9 185H,one thread,nice19,
seed2026101767,59s/512MiB caps. No native crate/proof/GPU.

New decisive negative: hiding Y's commitment alone does not hide a published
virtual lookup evaluation. With one active query,v(r)=eq(0,r)*T[I0],so a
known nonzero equality weight recovers the private table value.20Fp2 controls
recover it exactly. Same-histogram orderings differ at16of17F17 challenges;
r=1/2 is the expected exception. Self-consistent replacement arithmetic can
pass without original ordered index binding. These are naive-port diagnostics,
not attacks on native/upstream accepted proofs. A zero-sum Y mask usually
changes the value; an orthogonal one preserves the leaking scalar. Fresh
scalar masking is a marginal illustration only; reuse leaks differences.
Whole-table unused zero-denominator refusal remains; native draw/refusal
ordering not replayed. Prior D/C,zero-zero,padding and integer-wrap negatives
stand. No privacy weakening or mask reuse is authorized.

Actual8BT32 U8 data:83columns/11714560queries;H1514U8 base rows/99221504B;
totalH1758rows/115212288B,also exp/act,table,zero-sum,reserved/proximity rows.
Native looked arrays already uncommitted;additional query commitment saving0.
One256Fp2 pushforward4096logicalB becomes131072B at current8192-row width,
before masks. These are gross counts,not net saving,peak or DRAM traffic.
New GKR/ordered A-affine links/terminalPCS/fresh masks/support/refusal/encoding/
serialization/transfers are unmeasured costs. H/M schedules need new review.

Latest owner R5cli3 CPU8BT32 onepass diagnostic171.578s;witness21.376,
inclusiveprove156.143 inclreload15.993,remainder118.774 inclserialization/sink.
Partial load+seal15.345s=8.943%;fullstartup,prefill,steady slope,isolated
serialization/latency/lag/drain unknown. Freshcli3 verify not observed at
20:31:20UTC;no token credit or liveness claim. Hcommit/open/U8/exp-act
11.75/2.23/4.78/0.74s=19.5s;deleting all four for free caps ONLY their direct
fixed-other-work effect at1.128224x. Not a full-architecture/5090 ceiling or
accepted rate. R5oldercli2 CPU267.8s has freshverify45.777s;four controls had a
weaker cache refusal,subsequently strengthened. Different contention/check
placement precludes clean A/B inference. Public phase/counter pins retained.

Carried R4 verified functional8B T32 onecoldpass/arm CPU384.542564s/
RTX4070Laptop391.287091s,16threads. Diagnostic32/process0.083216/0.081781;
witness18.629/18.109,inclusiveproof208.019/213.831 inclreload79.222/77.997;
remaining110.168/117.725 inclserialization/sink. Partial startup21.595%/20.341%,
fullstartup/steady/isolatedserialization absent. Freshcheck96.103/90.935 plus
initialload80.675/78.635;receipt465815776B. D24r3 accepts8B soundness;shape
privacy open,R5/newprofile gates separate. New targetproofs/passes/positions0/0/0.
No resident repeat,long-context prefill or decode here;target rates and clocks
unmeasured. Larger workloads allowed with fresh masks,denseattentionT²;
>=50provedtokens/s on5090/high-end unchanged/unachieved.

Owner deviceF ledger now records t10 equality/seeded gates and a1.1BT128stack
with freshverify,not an8B/5090gain. Earlier VRAM limit violation and enclosing
~5xbody slowdown remain recorded;255register kernels spill. No duplicate job.

Rank:1owner complete device arithmetic/residency;2owner public residency after
R5 reduces old80s loads to15–16s;3tested private LogUp* architecture,unmasked
port rejected;4NEW83-column batching with explicit newterminal/mask-site budget;
5newolderDUPLEX/Locq backend leads,lowcompatibility. CurrentPlonky3release and
caller-obligations text read;must_use is not a guarantee terminals are checked.
Exact commits/PDF fetch failures and main-only MIT license scope retained.

Unapplied handoff:`handoffs/20261017-logup-star-private-view.md`;seam is
private_block protocol lookup/Hcommit plus argument/shape/layout H/M/PCS sites.
Next local:domain/column batching against83-column reference,odd padding and
full newclaim/mask census. Next owner:complete cli3 fresh/control gates and
fixed-context workload slopes. Full clocks/ranks/limits/sources in
`progress/20261017T202105Z-363d38a1.md`. Reports saved,not delivery evidence.


## Cycle 0068 — lookup batching domains, 2026-10-17

Run `20261017T212105Z-f1b8cd7d`. No proving speedup found. Current mandate,
durable/project memory, 350 sources and latest three results consulted; startup
originals retained. Seven LIVE primary records appended, 357 total.
Full report: progress/20261017T212105Z-f1b8cd7d.md.

Source-captured native Fp2 Rust batching passes 96 fixtures, 3,744 bucket values,
96 claims/support checks, 1,800 column visits and 19 controls. Independent
polynomial-convolution/rank/F17 audit: 4,136 checks. Main 0.416722 s / 20,600 KiB;
compiler 128,868 KiB; audit 0.059436 s / 16,284 KiB. One Core Ultra 9 185H CPU
thread, CPU0, nice 19, seed 2026101768; each run capped at 59 s / 512 MiB.
Public synthetic support/private scratch only; no GKR, PCS, native proof or GPU.

New negative: sharing one scalar across seven column tensor coordinates gives
83 weight polynomials rank seven, leaving 76 dimensions of fixed compensating
errors undetected for every such scalar. Independent two-coordinate F17 grid
detects the column 1/2 control at 272/289 points; diagonal never. This rejects
our shortcut, not an upstream/native protocol. Distinct evaluation points need
reduction; zero-lift factors can vanish. Raw batched singleton values still
leak. Correlated-pad marginals can be uniform while leaking jointly. Reference
unused-table-zero event retained; no native refusal/RNG replay. All earlier
negatives stand, including full-i64 wrapping and original ordered A links.

Counted 8B T32 per block: 83 columns / 11,714,560 queries. Dense cube padding:
six domains 1.702098×, four equal-length groups 1.523077×, one global 5.728671×.
Ragged public support can skip dummy visits but must prove the relation.
Four-group pushforwards: 16,384 logical bytes / 524,288 bytes at old row width
BEFORE masks. No net H/M/peak/traffic saving. U8 H: 1,514 rows / 99,221,504 bytes;
all H: 1,758 rows / 115,212,288 bytes. Extra query commitment saving: zero.
Four-group illustrative interface retains 83 ordered index links and eight
initial/GKR-terminal scalar sites before further reductions. Round masks,
native reserved rows and fresh-mask bytes remain unknown; no mask reuse.

Owner R5 cli3 CPU 8B T32 now freshly verified: 11 refusals, honest still verifies.
32 linked blocks, one cold pass, 16 threads, GPU off; shared box, n=1. App
171.578 s / process 171.641294 s; diagnostic 0.186504 / 0.186435 positions/s.
Witness 21.376 s inside inclusive prove 156.143 s, with reload 15.993 s;
remainder 118.774 s includes proof/serialization/sink. Partial initial load +
seal 15.345 s = 8.943%; full startup/steady/isolated serialization/latency/lag/
drain unknown. Fresh initial load 13.165 s + check 26.491 s (reload 13.071,
crypto remainder 13.420); whole verifier process 115.868762 s includes controls.
Receipt 465,815,776 bytes. Shape privacy acceptance open; no target credit.
Free deletion of all H commit/open/U8/exp-act phases, 19.5 s -> 1.128224× with
other work fixed, before added costs; not a whole-architecture/GPU/5090 bound.
D27's security-tier direction authorizes no lookup or mask weakening here.

Rank: (1) owner whole-prover GPU, (2) owner public-model residency, (3) tested
private batching, (4) NEW ragged-round oracle with independent points,
(5) NEW older MLE-compatible lookup 2024/1058, abstract-only. Recent October 16
Plonky3 release / October 11 zkLLMPoT refreshed. Dates, licenses and failed
fetches retained; no author performance reproduced. MLE encoding compatibility
does not establish native hash-PCS/privacy compatibility. Zorch's final author
GPU phase remains 2.8× its native baseline despite small device arithmetic time.
Unapplied handoff: handoffs/20261017-logup-batch-domains.md. Seam: protocol.rs
lookup/H, argument.rs relations, shape.rs/layout.rs H/M/PCS. No production patch.
Next: dense/ragged rounds over four groups with independent initial points and
all terminal obligations. Owner GPU and complete resident-workload slopes retain
priority. New target proofs/passes/positions: 0/0/0; no resident repeats, long
prefill or decode. >=50/s unchanged, unachieved. Larger workloads allowed with
fresh masks; dense context attention grows quadratically. Production/runtime/Git
untouched. Saved reports do not establish delivery.


## Cycle 0069 — public padding and native MSB bit placement, 2026-10-17

Run `20261017T222105Z-d6d7aa4d`. No proving speedup found. Current AGENDA,
throughput target, durable/project memory, 357 prior sources and latest three
results consulted. Early STATE/startup originals and hashes retained. Eight
LIVE primary records appended, 365 total; original source prefix preserved.
Dated report: progress/20261017T222105Z-d6d7aa4d.md.

Source-captured field/CFS plus research Rust public-support round evaluator:
94 synthetic fixtures, 1,424 degree-three round values, 282 ordered final
factors, 480 additional brute-force round values, 1,600 mask values and 356
masked-chain checks; 23 controls. Independent polynomial-convolution, direct
MLE, monomial-mask and support/point-provenance audit: 5,185 checks. Main
2.038018 s includes compilation/oracles, 22,404 KiB; compiler 134,544 KiB;
audit 0.552043 s / 17,724 KiB. Core Ultra 9 185H CPU0, one thread, nice19,
seed2026101769; each experiment <60 s and <=512 MiB address space. No GPU,
native proof, PCS, GKR, entropy/privacy proof or real private data. First
weaker-control passing revision retained alongside strengthened evidence.

NEW: native sumcheck uses MSB pairing. In minimally padded column-first
rectangles, dummy columns mix into live nodes in round zero, saving ZERO pair
visits. Row-first MSB preserves dummy columns through row rounds. Both layouts
reproduce their own dense round sequence; matched values and permuted terminal
coordinates preserve initial sum and all three final factors. This is not
native transcript, schedule, layout or PCS equivalence. The cubic E~ S~ V~ is
an explicit arithmetic probe, not a complete/minimal lookup arithmetization.

Counted 8B T32 four groups: L N8192/C2/W2, D+Q N131072/C47/W64, Kv+S
N32768/C25/W32, F N524288/C9/W16. Dense/column-first 17,842,172 pairs vs
row-first 11,714,587: 6,127,585 fewer, 34.3433%, pair-count ratio1.523073.
Sixty small rectangles check formulas N*W-1 and C*(N-1)+W-1. No large-shape
execution, runtime, traffic or peak saving. Full public E array would sum to
187,432,960 B; indices plus three factors sum to656,015,360 B (625.625 MiB)
across four groups BEFORE BTreeMap scratch. These are aggregate payloads, not
peak; sequential groups differ. Factorize public weights/support before
capacity/performance promotion. Extra query commitment saving remains ZERO.

NEW negative: zero Boolean products need not be zero off-cube: disjoint factor
supports can yield X(1-X). Retain union of factor supports, not product support,
and all final factors; S~ is not Boolean at random points. Preserve whole-cube
CFS masks independently of compact base arithmetic. Raw singleton virtual
values still disclose; coherent replacement needs original ordered A binding.
Fixed public shape padding only; hidden prompt length/selectors/mask rows must
not become public support. All earlier repeated-coordinate/rank, fractional
GKR D/C, full-i64 wrapping, unused-table-zero, joint-mask and endpoint-history
negative findings stand. No mask reuse/privacy weakening authorized.

Carried verified functional R5 cli3 CPU 8B T32, 32 linked blocks, one cold pass,
16 threads, GPU off, shared n=1: app171.578/process171.641294 s; diagnostic
0.186504/0.186435 positions/s. Witness21.376 within inclusive prove156.143;
reload15.993 within it; rest118.774 includes proof/serialization/sink. Partial
initial load+seal15.345 s =8.943454%. Full startup/prefill, steady slope,
isolated serialization, latency, lag and drain unknown. Fresh check26.491 s
plus initial load13.165; check reload13.071/crypto13.420; verifier process
115.868762 includes11 refused controls and honest recheck. Receipt465,815,776 B.
Shape privacy acceptance open. Deleting the19.5 s H commit/open/U8/exp-act
phase set for free yields1.128224x or0.210418 diagnostic positions/s, keeping
other work fixed and before added costs. Not a whole-architecture/GPU bound.

Owner R5b changes checked witness/parity/sealing before header, witness cache,
statement promotion, verifier export separation and bounded readers. Targeted
tests pass; suite queued at captured checkpoint. R5 reviewr4 accepts soundness
but adds reader fixes delivered in R5b; no privacy acceptance. Old R5 clocks
do not measure new lifecycle. Generic8B T64 GPU one-block4,417 MiB peak exceeded
lane4GiB cap; default queuedT128 GPU prevented. Owner1.1B T128 s4 stack159 s,
slot18 8.11/body6.25/freshcheck19 s; spin probe measures5–8x idle arithmetic
ramp. Isolated alsoP4, refuting earlier isolation=boost explanation. Charge
warm-up time; no duplicate owner build/GPU/proof here.

Rank: (1) owner whole-prover GPU/residency with contiguous useful work,
(2) owner public residency/full R5b startup slopes, (3) tested row-first lookup
architecture with83 original links/masks/GKR/PCS obligations, (4) NEW implicit
per-column equality/support to remove public E/index expansion, (5) NEW older
FLI/Deep Thought accumulation and power-circuit wiring, low compatibility.
Next local compares factorized independent points/selector terminals to this
saved oracle with odd columns and every final factor. Reject any mismatch,
private disclosure, changed refusal/support or added costs defeating savings.
Whole-architecture end-to-end ceiling remains unknown. Owner complete GPU
and independently verified resident-workload slopes retain priority.

LIVE October10 SP1 release includes NTT order/zerocheck work; PR2990 diff
inspected with explicit ordering/shift/input-preservation gates. Release full
commit page read; NTT commit/terms fetch failures recorded. EPFL/author CMU
variable-order/round-batching references refreshed; StateSync remains its own
sparse baseline; new older sources are watchlist leads only. CFS arithmetic
is not composition/privacy acceptance. Exact primary dates, URLs, license
scope, exposed versus inspected hashes and failures retained; no foreign code
executed or author benchmark reproduced. Rotation includes sumcheck/GKR,
memory/batching now, fresh NTT/commitment lead next, prior lookup/softmax,
quantization and composition queues retained. Unapplied handoff:
handoffs/20261017-ragged-logup-rounds.md; native seam is SumcheckRounds/prove_rounds
plus separate private_block lookup/H/argument/layout integration. No production
patch or merge. Target proofs/passes/positions0/0/0; target steady/total clocks
unmeasured. No resident repeats, longer prefill or decode; dense attention can
grow quadratically and decode needs bound state. Larger workloads/fresh masks
remain allowed. >=50/s complete private8B high-end-GPU target unchanged and
unachieved. Production/runtime/Git/receipts/calibration/instructions/reviewer
files untouched; no installs, external messages or escalation. Saved reports
do not establish notification delivery.


## Cycle 0070 — factorized distinct-column public equality, 2026-10-17

Run `20261017T232105Z-d713e393`. No native proving speedup found. Current
AGENDA/target/durable/project memory and latest three results consulted;
365 prior sources parsed. Early STATE/startup originals retained; six LIVE
primary records appended, 371 total, original prefix preserved. Full report:
progress/20261017T232105Z-d713e393.md.

Rust row-first MSB E*S*V evaluator avoids full public E/S/index arrays using
per-column prefix factors and a division-free suffix-weight traversal. One
owned column-major V buffer remains; polynomial bit order is unchanged from
this probe's row-first baseline. 84 synthetic fixtures (30 prior), 1,788 round
values, 252 terminals, 447 whole-cube masked-chain rounds, 197 quadratic-base
checks and 22 controls pass against dense Python/prior Rust. Independent
original-table/convolution/MLE/monomial audit: 4,768 checks. Future-challenge
causality: 1,699 unchanged-prior-round checks +1 sensitivity control. Main
3.151398 s /28,696 KiB incl compile/oracles; compiler135,348 KiB; audit
7.180672 s /21,272 KiB; causality0.111618 s /16,732 KiB. One Core Ultra9
185H CPU0 thread, nice19, seed2026101770; each command <59 s /512 MiB AS.
No native proof, PCS, GKR, entropy/privacy theorem or GPU result. Initial
21-control PASS retained. First audit failed its final extraction assertion
because it omitted eight doc-comment marker conversions; failed script and
finding retained, exact source check corrected, no arithmetic changed.

NEW: independent per-column row points remain distinct; after row rounds E
is a mixture across columns and S is non-Boolean. Retain all E/S/V terminals.
Quadratic base row rounds do NOT permit quadratic masked messages: cubic
CFS terms remain. Numerical private zeros preserve schedules. Raw singleton
values still leak. Fixed public shape support only, never hidden prompt
length/selectors/private mask rows. All prior rank/diagonal-coordinate,
joint-mask, D/C, i64 wrapping, unused-table-zero, off-cube-product and
endpoint-history negatives remain. Probe is not a complete/minimal lookup
argument or byte-preserving native lookup adaptation.

Counted prior 8B T32 four-group naive index+E+S+V payload625.625 MiB ->
178.783936 MiB including conservative small payload; largest group94.017731
MiB. Aggregate payload, not peak. Original source, allocator/recursion,
GKR/masks/commitments/PCS remain. Local caps refuse large groups, no full-shape
execution. Added suffix regeneration23,426,212 Fp2 multiplies; weighted and
fold passes each read23,428,954 values; fold writes11,714,477. Logical counts,
not DRAM traffic or runtime. All83 ordered original-A/wrapping links,
distinct-point reduction, GKR, fresh masks/extensions/terminals/PCS and
soundness/privacy remain. Extra query commitment saving zero.

NEW carried R5b 8B T32 CPU, 32 linked blocks, one cold pass, 16 threads,
GPU off, shared n=1: app191.755/process191.975140 s; diagnostic total rates
0.166880/0.166688 positions/s. Sealing37.214 s =19.407056%; cumulative load
35.798 and witness32.584 s OVERLAP within it. Prove154.427 includes reload
19.052, zero witness rebuilds; remainder135.375 includes serialization/sink.
Fresh load14.507 +check32.248 s (reload17.015/crypto remainder15.233);
verifier process141.571000 includes11 refused controls/honest recheck.
Receipt465,815,776 B; RSS4.73 GiB/cgroup7.09 incl cache. Full startup/prefill,
steady slope, serialization, latency/lag/drain unknown. Shape privacy acceptance
open. Free deletion of four direct H phase families21.568 s ->1.126731x,
0.188028 diagnostic positions/s with other work fixed BEFORE new costs; only
a phase-set ceiling, not whole architecture/shared zero-check/GPU/5090.
Owner suite692/0/31 over29 targets. GPU1.1B warm190 s vs prior159 includes
22*300 ms spin; no enclosing gain. Logical plan-byte bandwidth11.7% lean,
8.0% default is not measured DRAM. Next kernel round active at23:22, no duplicate.

Rank:1 owner whole-prover GPU kernel design/contiguous useful work;2 owner
R5b public residency plus complete pass slopes;3 tested factored private lookup
representation with all protocol costs;4 NEW pending-known-previous-challenge
fold plus NEXT weighted contraction;5 NEW older Orion code-switching backend.
Cannot fold using the current unknown challenge before its message. Next local
compares a stateful SumcheckRounds adapter to saved rounds/finals/causality,
charging equality work/read counts/final drain; reject mismatch or no enclosing
gain. Full new-architecture end-to-end ceiling unknown. Owner workload/device
work remains higher priority; no heavy job queued by researcher.

LIVE SP1 ordering/shift/input-preservation diff, EPFL raw split-Eq common-point
source, March2026 sumcheck, Jolt documented factoring/2025 PR dates, older
2024/524 refreshed. NEW older Orion2022/1010 revisionNov2,2023 explicitly fixes
inadequate masks and missing commit-and-prove; inspected repo bf9743cc... is
Sep19,2022 and does not establish those fixes. Apache2 terms plus dependency
exceptions scoped. Failed PDF/license/commit fetches, displayed release year
uncertainty and inspected versus exposed hashes recorded; no author runtime
reproduced. Rotation next NTT/commitments+memory traffic, other queues retained.
Unapplied handoff: handoffs/20261017-factorized-public-equality.md. Native
seam SumcheckRounds/prove_rounds; full lookup also needs private_block
protocol/argument/shape/layout H/M/PCS review. No production patch/merge.

New target proofs/passes/positions0/0/0; target steady/total rates and proof
clocks unmeasured. No resident repeats, long-context prefill or decode. Larger
workloads allowed with fresh masks, attention can grow quadratically, decode
needs proved state. >=50/s complete private8B high-end-GPU target stands,
unachieved. Production/runtime/Git/receipts/calibration/instructions/reviewer
files untouched; no installs/external writes/messages/escalation. Saved reports
are checkpoints, not external delivery evidence.


## Cycle 0071 — pending previous fold plus next weighted round, 2026-10-18

Run `20261018T002105Z-32d7e4fc`. No native proving speedup found.
AGENDA/current target, durable/project memory and latest three results
consulted; 371 starting sources parsed. Six LIVE records appended, 377 total,
original prefix preserved. Early STATE/startup/native hashes saved under
experiments/pending-fold-weighted-round-20261018/. Full dated report:
progress/20261018T002105Z-32d7e4fc.md. Prior findings preserved.

Rust PendingRows emits each message before its own challenge enters, then
combines the known previous row fold with the next weighted contraction.
132 synthetic fixtures (84 prior), 3,020 round values, 396 E/S/V terminals,
755 whole-cube masked rounds, 23 control categories with eight lifecycle
checks pass against Python dense/prior Rust. Challenge mutations preserve
3,031 current/earlier messages and change 753 finals. Independent original-
table/power-basis-convolution/MLE/monomial audit: 7,795 checks.
Main 1.959028 s / 33,392 KiB, compiler 143,700 KiB; audit 7.184318 s /
28,080 KiB; API counter 1.370311 s, compiler 144,844 KiB. One Core Ultra 9
185H CPU0 thread, nice 19, seed 2026101871; each command 59 s / 512 MiB AS.
Initial mutable-finish PASS retained. Native finals(&self) cannot settle:
refined adapter drains last fold/zero-variable constructor; copied native
trait matches. Actual native crate/transcript/RNG/proof-byte gates unrun.
No native proof, GKR, PCS, GPU or privacy theorem result.

Core row reads 4C(N-1) -> C(3N-2), writes C(N-1) unchanged; N1 no work,
N2 no saving. Prior T32 four-group census 46,857,908 -> 35,143,514 reads:
178.747467 MiB logical read reduction, asymptotic 25% reads /20% read+writes.
Same V allocation/O(logN) DFS. Input copies/common setup/output/original
witness/masks/links/GKR/PCS additional. Column tail adds 660 field reads /
330 Fp2 subs; executed API counters across 132 fixtures confirm add/mul
zero delta, sub 3(W-1). Suffix 23,426,212 multiplications/folds unchanged.
Core byte-only ratio 1.249998x is not runtime/DRAM or full-prover gain.
Full ceiling unknown without native Caffected/Cadded. Large census groups
not executed, caps preserved. All 83 original links/distinct-point/wrapping/
privacy obligations remain. No singleton/D-C/joint-mask/off-cube/endpoint
negative overturned. Only fixed PUBLIC shape support, never hidden prompt/
selector/mask or numerical witness sparsity. Prior slower native fusion
remains demoted.

NEW carried owner R5b 8B T128: 32 blocks, one cold CPU 16-thread pass,
GPU off, shared n=1, fresh verify, 11 controls and honest recheck. App606.598 /
process606.728291 s; diagnostic total0.211013 /0.210968 positions/s. Seal
105.287 s =17.356965%; cumulative load36.570/witness103.349 overlap within it.
Inclusive prove501.126 s includes32 rebuilds122.694 and reload21.176 s;
serialization/sink unisolated. Fresh load14.126 +check43.902 s, reload18.459
within check, arithmetic remainder25.443; verifier process186.088255 s with
controls. Receipt922,711,264 B; RSS6.55/cgroup8.47 GiB. Full startup/prefill/
steady/latency/lag/drain unknown; trained-shape privacy acceptance open.
Four direct H phase free-deletion95.882 s ->1.187740x/0.250629 diagnostic
positions/s, other work fixed before added costs. Only that phase-set bound,
not architecture/shared zero-check/GPU. T32 counts and T128 clocks are
separate evidence, not a combined measured estimate.

Owner GPU 255-register/spill findings and K1-K4 design remain first; small
gates pass23:58, trained gates queued23:59 at capture. No duplicate job.
Plan-byte11.7% is not measured DRAM; warm-up/drain remain charged.
Rank: (1) owner whole-prover GPU kernel design; (2) resident immutable public
setup and full fresh-pass slopes; (3) tested pending factored lookup arithmetic
with complete protocol costs; (4) NEW older Kim2020 consecutive precomputed
late-stage NTT root products versus cache/integer costs; (5) deferred Orion/
Hermes backend. Next local reads owner verdict, then exact root-product
oracle/census if still useful. Preserve roots/order/scale/padding/swizzles/
pruning and first-six-stage shift candidate. Reject mismatch, already-cached
table pressure or arithmetic erasing gains. Owner measurements keep priority.

LIVE primary versioned P3 pending-binding source, displayed Oct16 releases/
Sep9 IDFT PR and ICICLE release refresh; NEW older Kim2020 OT sectionVII adds
modular products rather than free roots; NEW Hermes2026 is U280 FPGA, not a
CUDA drop-in; Valk2026 instruction-roofline scope refreshed. Versioned docs/
GitHub main lengths differ; no inferred version mapping. Dates/licenses/
commit scopes and Cache miss/Internal Error failures saved. No foreign code
executed. Unapplied handoff: handoffs/20261018-pending-fold-weighted-round.md.
Native seam SumcheckRounds/prove_rounds plus separately reviewed private_block
lookup protocol/argument/shape/layout H/M/PCS. No production patch/merge.

New target proofs/passes/positions0/0/0; target steady/total rates/clocks
unmeasured. No resident repeats, long prefill or decode; attention can grow
quadratically, decode needs proved state. Larger workloads/fresh masks allowed.
>=50/s private 8B high-end-GPU target unchanged/unachieved. Production/runtime/
Git/receipts/calibration/instructions/reviewer files untouched; no installs,
GPU, external writes/messages or escalation. Saved reports are not delivery.


## Cycle 0072 — native order-64 late-root compression, 2026-10-18

Run `20261018T012105Z-ac328993`. No native proving speedup found. AGENDA,
current target, project/durable memory and latest three result JSONs consulted;
377 prior sources parsed, six LIVE primary records appended, 383 total with
original prefix preserved. Early STATE and startup originals/hashes retained.
Full report: progress/20261018T012105Z-ac328993.md.

NEW: native generator7 root64=2^39. For s>6, d=s-6,
k=l+2^d h, 0<=h<32: w_s^k=w_s^l*2^(39h). Apply one low-root product
(if l!=0) and canonical shift; invert both factors for inverse stages.
Stage-major low length2^d at offset2^d-2 has a monotonic size prefix.
First6 shift candidate retained. Existing field/root/order/scale/coset/padding,
private relation, blinding and proof security unchanged by the proposed action.
Source-derived native canonical primitives compiled only as a small local C++
CPU library; no CUDA/PTX/native-crate/proof/RNG/privacy result.

Main PASS280,366 checks/18 controls,3.353462s incl compile,29,436KiB RSS,
compiler24,980KiB. All131,070 root/action values through log16 in both
directions,14,016 shift checks,4,096 sampled stage17..32 actions; DFT,
roundtrip, counters and6 independent Lagrange hiding rows with q>n overlap.
Independent audit PASS1,452 checks,6.312016s/24,344KiB: tiled DIT/inverseDIF
logs7/12/13/14, swizzles, bit-reversed rb2/rb3 pad skip/full,256 original-
polynomial samples. One Core Ultra9 185H CPU0 thread,nice19,seed2026101872,
audit+1; each command59s/512MiB AS. Initial PASS retained; meaningful zero-only
and schedule controls refined without changing arithmetic. Zero-only tests
miss corrupted roots. Unaccessed corruption requires constructor provenance,
not inference from a single arithmetic result. Native pruned stores/sync/races,
cache lifetimes/transcript/masked RNG/fresh verification gates remain unrun.

Counted both-direction public device roots at log16:1,048,560->32,736B;
log20:16,777,200->524,256B; logs20/24 counted, not allocated/run. SAME general
multiplication count as prior sparse-shift candidate, but285,727 /6,602,783
extra shifts per respective transform. At log20 general6,815,776 plus total
nonidentity shifts9,224,192. Earlier sparse/first6/inverse-scale opportunity
must not be counted again. Hybrid only stage>=13 at log16:95,232B,+126,511
shifts, counted not device-tested. Native CPU tables/stage-major temporary
construction remain, probe full oracle tables remain: no peak-memory saving
measured. Native uploads already cached. Late general-root logical read count
unchanged versus sparse dispatch; no32xDRAM/throughput claim. Added shift/
reduction dependencies/registers/dispatch/cache behavior can erase benefits.
Generic OT comparator exact but stage20 general products1,047,040 versus
original524,288 despite1,536 root words: cost-demoted, no GPU ratio inferred.

Seam: owner gpu/cuda.rs::stage_major/ensure_twiddles, kernels k_ntt_p1,
ntt_p2_body,dif_pa/pb,dit_p1_pad and gather/pruned actions. Preserve immutable
native-root/direction provenance, monotonic mixed-size cache, old tables for
unmigrated routes, all skipped stages and fresh masks. Unapplied handoff:
handoffs/20261018-native-root-compression.md. Ceiling remains
N/(Ttotal-Caffected+Cnew), affected NTT share/new timing unknown. Reject any
arithmetic/refusal/profile/privacy/byte/RNG mismatch or no enclosing gain.

Carried R5b8B T128 CPU:32blocks,one cold pass,16threads,GPUoff,shared n1.
App606.598/process606.728291s, diagnostic total0.211013/0.210968 positions/s.
Seal105.287s=17.356965% is NOT isolated startup: load36.570/witness103.349s
overlap inside. Inclusive prove501.126 includes122.694s rebuilt witnesses
and21.176s reload; serialization unisolated. Fresh verifier load14.126+
check43.902s (reload18.459within; arithmetic remainder25.443). Verifier
process186.088255s includes11controls/honest recheck. Receipt922,711,264B;
RSS6.55/cgroup8.47GiB. NEW reviewR5 accepts soundness/T64/T128 arithmetic,
independently verifies128 and11controls; not privacy acceptance. Publication
marker race r5_A assignedR6, not proof-soundness finding. Full startup,
initial-prefill, steady slope, proof latency, lag/drain remain unknown.

Owner latest reread: round2 warm split34.7ms isolated/35.4–36.4in-stack,
plan-byte13.8–14.4% not measuredDRAM; cold173s versus prior159s, warm185s
includes spin, no enclosing gain. NEW round3 kernels23.02ms at2^20, REAL
T128 warm body28.25/29.83ms incl6.0–6.8build; module diskload0.01–0.02s.
Trained54equalities and seeded bytes all4shapes pass01:19, requiredGPU,
peak3,173MiB. Thermalreason0x20/P4 persists. CLIbuilt01:22, enclosing default/
warm+fresh verify queued; no enclosing result captured. Do not duplicate.

Rank1ownerwhole-prover GPU arithmetic/continuous useful work,2ownerimmutable
public residency/full-pass slopes,3testedrootcompressionunknowncachegain,
4factoredlookup/pendingfolds with fullGKR/PCS/links/mask cost,5genericOT/newPCS.
NEW nextlocal: audit source-captured derivedF-slot arithmetic versus original
closure, charge build/folds/base-round eligibility, preserve earlier cubic/CSE
negatives and avoid owned implementation duplication. Read owner enclosing
verdict first. Owner root nextprofile actualcache/NTTshare, then guarded
largest-stage-only A/B only after fullgates. Rotation sumcheck/GKR/arithmetic,
retain lookup/softmax,NTT/commitments,memory,batching and composition.

LIVE Kim2020 OT refined; NEW olderShivdikar2022 convolutionfusion needs a
missing two-polynomial-convolution seam; NEW Sep24,2026 CGLA q3329/FPGA/FP32
scope cannot transfer. CurrentCUDArepo source/cache/release negatives,
GoldilocksNTT L2qualification andICICLEreleases refreshed. Exact dates,
license inspection scope, exposed-versus-inspected commits and fetch errors
recorded; no foreign code executed or author performance reproduced.

New target proofs/passes/positions0/0/0. Target steady/total rates, startup
fraction and witness/proof/serialization/verification clocks unmeasured this
cycle; device none. No longprefill,resident repeats ordecode; context growth
can increase attention quadratically. Larger workloads/fresh masks allowed;
>=50/sprivate8Bhigh-endGPUtargetunchanged/unachieved. Production/runtime/Git/
receipts/calibration/safety/instructions/reviewer files untouched; no installs,
GPU/heavy job, externalwrites/messages or escalation. Savedreports do not
establish delivery. All previous negativefindings preserved.
