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


## Cycle0073 — base-aware derived construction, 2026-10-18

Run20261018T022105Z-6cb6453f. No native speedup found. Source-captured owner
round3 fzs_derive_impl uses general Fp2 products on base A planes. Candidate
constructs GL with scalar/mixed operations, prepares mu_pad*w once per proof,
and retains generic fallback/public zero-weight skips. Full-pad scalar-product
counts53N ->32N+33 (C++Karatsuba prep); Rustfive-product prep costs55 instead33.
N2/w11 generic LOSES27 products. New176B workspace, same source accesses,
same32N derived bytes and2(N-1) Fp2 folds/96(N-1) logical fold bytes. No masks,
protocol, quantization or security changed. Coefficients must be proof-local.

Main PASS120fixtures,4,644baseline+4,644candidate values,6,966fold values,
1,944offcube values,600counter checks,120,744unchanged source values,10controls.
Independent PASS32fixtures,2,960original full-F-polynomial comparisons,
720original-cube terminals,2,072prefix values,5controls incl MSB/finalfold/
nonlinear materialization. Main0.439298s inclcompile/RSS17,584KiB; compiler
24,716KiB; audit0.464633s/15,944KiB; oneCoreUltra9 185H CPU0,nice19,seed
2026101873/74, each59s/512MiB AS. N2..64; huge shapes counted only. Exactu128
CPU substitute arithmetic, no native field/PTX/CUDA/races/DRAM/proof/RNG/
privacy theorem. Artifacts experiments/fzc-derived-cost-audit-20261018/.

New retained owner round3 enclosing results: TinyLlama1.1B T128,22blocks,
16threads,RTX4070Laptop,each fresh-processverified497,665,904B. Default
app174.052/process174.196237s, diagnostic0.735412positions/s; inclusiveprove
132.202 includes15.473witness/11.181reload; load13.521,seal0.059,inprocess
verify23.290. Freshload11.009+verify9.394/process20.480536. Warmapp216.500/
process216.656004s,0.591224positions/s; prove153.729 includes17.952witness/
12.785reload; load29.322,seal0.100,inprocessverify24.227. Freshload13.082+
verify13.067/process26.236683. Sameidentity,0declines,peakVRAM3137MiB each.
Warm22spins6.6241s recur; not startup. Load+seal7.802%/13.590% phasefractions,
not isolated startup. Serialization/prefill/steady/lag/drain unknown. Default
kernel counters implausible/unsynchronized; use enclosing clocks, not derived
BW. Ownerthermalpolicy unchanged. Shared n1/settings differ, no causal A/B.

Slot18inclusivebody3.409578/1.268204s; build0.952456/0.533091s. Deleting ALL
build gives only0.547%/0.246% total-time upper saving; candidate touches a
subset. Actual derive time and8B ceiling unknown. Newdefault phases:
Arowallocation30.827s,Dzero-check26.691s,softmax11.381s; warm35.587/31.885/
14.063s, rounded diagnostic sums. Promote next local D affine-aggregate
cost audit, not more microconstructor tuning. Source GL/PL derivation8+w
reads +1+support writes; fullpadding336N sourcebytes vs208N owner's unique-
union count, neither measuredDRAM. Preserve original byte/eligibility gates.
Unapplied handoff handoffs/20261018-base-aware-derived-build.md.

Carried8B R5bT128CPU32blocks/onecoldpass remains606.598app/606.728291process,
0.211013/0.210968positions/s,seal105.287(17.357%phase,notstartup),overlapping
load36.570/witness103.349;prove501.126 includes122.694witness/21.176reload;
serializationunisolated;fresh14.126load+43.902check(process186.088255includes
11controls). R5 accepts soundness/T64/T128 arithmetic, notprivacy; marker race
assignedR6. Receipt922,711,264B,RSS6.55/cgroup8.47GiB. No targetmeasurementnew.

Ranks:1ownerwholeprover GPU/Dzero-check andArowwork;2owner publicresidency/
fixedcontext fresh-pass slopes;3new tested base-awarederive lowceiling;
4priorrootcompression unknown cache gain;5factoredlookup/newPCS withfull
GKR/link/maskingcost. Next D11clause affine aggregate plus4bilinear terms,
sourcecaptured fullpolynomial/offcube oracle andnetbuild/fold costs; avoid
owned implementation/build duplication. Preserve all previous cubic/CSE,
lookupjointmask/offcube/singleton/D-C/wrapping/history andslowerfusionnegatives.

LIVE6records: knownSumCATSrefresh (alreadycycles2/13/34/56), extendedePrint2026/
587receivedMar24approvedMar25 +Sep1authorpost; NEWolderZhangprecombineGKRarrays
(reportMay1,2025,thesis2023); Plonky3rc.2release tags16Octyearunverified,
PR2293/2297explicitSep22,2026; fullmergecommit fetchesfail, hashesexposedonly,
mainMIT/nestedMITlicense scopesrecorded. No foreigncode executed/performance
reproduced.383originalsources preserved,6appended=389.

Newtargetproofs/passes/positions0/0/0; targetsteady/totalrates/startupfraction/
witness/proof/serialization/verificationclocksunmeasured,device none. No
residentseries,longprefill ordecode; largeramortizationallowed but attention
can growquadratically; decode needsprovedstate. >=50/sprivate8Btargetunchanged/
unachieved. Production/runtime/Git/receipts/calibration/safety/instructions/
reviewer filesuntouched; noinstalls,GPU/heavyjobs,externalwrites/messages/
escalation. Savedreports do notestablish delivery.

## Final owner-source movement checkpoint

At the final hash check, the owner had begun round4 in `gpu/cuda.rs` and
`gpu/fzc_kernels.cu`. Captured round3 baseline/test hashes remain intact.
Separate snapshots/diffs are in `owner-update/`; the initial stable-source
assertion failure is retained as `audit-attempt-source-movement.json` and is
resolved as concurrent owner movement, not an arithmetic failure. No researcher
production write occurred.

Observed round4 code reads resident base/pair sources directly in rounds0/1,
derives GL/PL inside round0 through `fzs_derived_at`, uses mapped results, and
changes the default host tail. This cycle did not compile, test or measure
those changes. Rebase the handoff on BOTH `fzs_derived_at` and the standalone
`fzs_derive_impl` fallback; an old derive-only patch may miss the new default.
The base/mixed identities remain research candidates, but new inline register,
shared-memory, lifetime and synchronization costs need the owner's gates.
Round3's inclusive-build deletion bound is specific to its recorded runs;
round4 moves arithmetic into round0, so it is not a universal ceiling for
the new schedule. Do not transplant the old source-load/counter accounting.
Read the owner's newest results before another local experiment.


## Cycle0074 — D affine aggregate, 2026-10-18

Run `20261018T032105Z-8464ee28`, 2026-10-18 UTC. Started03:21:05Z; checkpoint2026-10-18T03:31:31.478029+00:00.
**No native proving speedup measured; no new complete proof.** Research only.

Completed: read AGENDA/target, STATE/FINDINGS/source inventory/latest results,
CLAUDE, MVP status, decisions and active coordination. Early STATE checkpoint
saved before experiment. Startup captures/hashes retained; MVP is aggregate
only and decisions omit the actual inference-token identifier. No private
prompt/activation/weight/token data entered experiments or search queries.
Prior findings and389source records preserved; six LIVE records appended=395.

The latest decisions register accepts next-token rungR2 on soundness following
independent review; token-stage privacy, hidden-length variant and stream
remain open. This is a1.1B/T32 milestone, not the target workload, and not
permission to change arithmetic/privacy or target. No token identifier saved.

Tested question: can D's eleven clauses be represented by one affine table
plus four bilinear terms, without changing any full-polynomial values?
The current closure already specializes public base constants, shares two
norm products and hoists its support gate. Candidate eliminates repeated
weighted affine clause evaluation at sumcheck points; retains four bilinear
products, all helpers/padding/hosts, original tables and original finals.

Baseline seam is owner `private_block/argument.rs::SC_DZC`, slot14;
`zkp-core/src/sumcheck/rounds.rs::SumcheckRounds` is the driver seam. Slot18's
existing GPU F template may inform a future D port, but no current D GPU
adapter is implied. Prototype `candidate.py` and captured Rust expression are
under `experiments/dzc-affine-aggregate-20261018/`. Eight native source pins.
[Review handoff](../handoffs/20261018-dzc-affine-aggregate.md), unapplied.

Main PASS96synthetic fixtures, seed2026101874: N2/4/16/64, padded/unpadded,
base/generic sources,1/2/9synthetic lookups,4/5limbs. Four is current trained
width; five and the toy-index bindings are generic tests, not native trained
layout validation. Exact captured Rust clause expression runs with independent
u128 modular substitutes, not native field/PTX. Independent Python original
clauses and candidate match9,840values; enclosing helper/pad/host equations
match9,840points;1,968fold values,6,240direct-cube terminal values,
1,032base constructor values and48base-contract refusals pass. Eight control
checks and two invariants pass. The full nonlinear-clause MLE shortcut fails
offcube as required; no polynomial degree or relation changes.

Independent PASS24fixtures, seed2026101875:1,536native-basis linear coefficients,
96bilinear coefficients,396full enclosing round sums at unchanged declared
D4/D5,24native terminals,24fifth differences,888synthetic boundary values,
seven negative controls. Controls cover coefficient swap, missing constant,
nonlinear-table folding, MSB reversal, wrong claim, stale mu and omitted last
fold. Original final vectors are retained. No proof/transcript/RNG/privacy
construction was executed or accepted.

Local resource clocks: main3.023713s including tiny local Rust
shim compilation; RSS18,296KiB, compiler122,356KiB.
Audit0.498599s/RSS16,104KiB; count audit
0.000597s/RSS13,920KiB. One CoreUltra9 185H CPU0
thread,nice19,WSL2. Every experiment limited59s/512MiB AS; no GPU, Cargo,
dependency installation, downloaded code execution or competing heavy job.
First PASS retained under `initial-before-base-constructor-gate/`; rerun added
the meaningful mixed-constructor/provenance check without changing algebra.

Four-limb clause API census per point:

| Scope | Fp2mul | mul_base | add | sub |
|---|---:|---:|---:|---:|
| Current native clause |15|23|39|15|
| Candidate online |8|0|5|0|
| Proof-local coefficient preparation |0|26|9|20|
| Generic constructor, per entry |33|0|34|0|

Base constructor replaces33general products with33mixed products. Charge
extra N-1Fp2 folds, native step additions and16N+608Bcapacity. Original
sources/finals/folds remain. At counted N2^19/D4/unknown first claim/four limbs:
scalar products285,474,332->183,500,687generic or131,596,175base; extra8MiB
table. At N2^21:1,141,898,780->734,003,087generic or526,385,039base; extra32MiB.
These are Rust5-scalar/Fp2,2-scalar/mul_base operation models, not CUDA/PTX
instructions, byte traffic, timings, whole-D speedup or target projections.
Generic construction at2^19 reads285,212,672logical source/output bytes;
extra folds25,165,776B and round reads16,777,184B. Actual DRAM/cache/peak RAM
and row0fusion costs remain unmeasured.

Accounting correction retained explicitly: initial `result.json` charges an
extra5scalar products per evaluation for conservative interpolation. Source
inspection shows native ClosureRounds steps with additions; `cost-result.json`
charges those additions instead. Host slot14 has unknown initial claim,
E=D(N-1)+N/2; later release rounds recover s(1). Known initial claim uses
E=D(N-1); debug evaluates every point. Padded schedule staysD5, unpaddedD4.
N2/D4/generic/unknown first claim costs605->587 under actual stepping; the
conservative model605->612 loses7. Known-first-claim generic484->547 loses63.
Do not repeat the conservative tiny loss as a native D-host timing result.

The inherited default1.1B full-D phase is26.691s within174.052s total. Deleting
ALL D gives at most1.18113x and0.868615diagnostic positions/s; the candidate
changes only the clause subset. Actual clause timing and8B ceiling unknown:
N/(Ttotal-Caffected+Cnew), with Cnew charging construction/folds/transfers,
verification separately and pipeline drain. Native compiler/common subexpression
work, CPU parallel cutoffs, added liveness/register pressure and shared memory
may erase the counted benefit. Falsify on polynomial/final/refusal/byte/RNG/
privacy divergence or no enclosing workload gain.

Owner movement read only: round4 small/trained device tests now exited0;
trained seeded proof-byte gate passes four shapes. At real TinyLlamaT128
resident slot18, printed known-claim raw bodies27.921/26.474ms versus
materialized25.964/25.855ms; raw round0~9.2ms vs~6.5ms. Raw eliminates some
build traffic but is not a clear body improvement. First raw build72.933ms;
warm3.883/3.249ms. Owner host-upload ladder n20 default486.86ms includes
336MBH2D, so it is not resident kernel throughput. No enclosing round4 stack
result captured, no new independent full-stack proof credited. Owner source
and metrics snapshots are distinct from this local D experiment. Current
thermal policy unchanged. No relaunch or claim of synchronized DRAM bandwidth.

Retained full-stack clocks, shared n1 diagnostics (no causal settings A/B):

| Scope | App/process seconds | Witness/proof clocks | Serialization | Verification |
|---|---|---|---|---|
| 8B R5b,T128,32blocks,1cold CPU pass,16threads,GPUoff |606.598/606.728291; diagnostic0.211013/0.210968positions/s|seal105.287 includes overlapping load36.570/witness103.349; prove501.126 includes witnessrebuild122.694/reload21.176|not isolated;922,711,264Breceipt|fresh load14.126+check43.902; verifier process186.088255 includes11controls|
| 1.1B ownerR3,T128,22blocks,1default pass,16threads,RTX4070Laptop |174.052/174.196237; diagnostic0.735412positions/s|load13.521,seal0.059,prove132.202 includes witness15.473/reload11.181|not isolated;497,665,904B|inprocess23.290; fresh11.009load+9.394check;20.480536process|
| 1.1B ownerR3,T128,22blocks,1warm pass,same device |216.500/216.656004; diagnostic0.591224positions/s|load29.322,seal0.100,prove153.729 includes witness17.952/reload12.785; recurring22spins6.6241|not isolated;same receipt bytes|inprocess24.227; fresh13.082load+13.067check;26.236683process|

Startup fraction remains unisolated:8B seal/app17.357% is a phase fraction;
1.1B load+seal/app7.802%/13.590% are phase fractions. Witness work overlaps
seal; none is an isolated startup or initial-prefill boundary. Steady-state
slope, initial prefill, lag/drain and proof latency are unknown. These all
predate this cycle and are not accepted trained-shape privacy measurements.
No long-context prefill/resident repeat series/decode equivalence follows.

Ranked questions after this cycle:

| Rank | Hypothesis and expected impact | Cost/prerequisites, exactness/privacy and falsifier |
|---|---|---|
|1 OWNER|Whole-prover GPU arithmetic/row construction; broadest measured bottlenecks,8Bimpact unknown|D/A descriptors,correct kernels,full build/fold/transfer/verify/drain costs; preserve all CFS/masks/PCS/refusals. Reject absent enclosing gain or any gate failure.|
|2 OWNER|Immutable public residency and fixed-context fresh-pass slopes; possible repeated startup amortization,unmeasured|Retain model/config identity and charge recurring witnesses/load/serialization plus fresh private masks/openings. Need multiple completed verified workloads. Reject backlog/stale identity or no slope gain.|
|3 TESTED NEW|D affine aggregation; exact clause arithmetic reduction,8Bimpact unmeasured|Moderate integration: realB/Ids binding and D adapter missing; adds scratch/build/folds. Preserve original finals/extension/degree/privacy. Reject any mismatch or net regression.|
|4 TESTED PRIOR|Root compression/F constructor; capacity or small-phase opportunities only|Cached roots still need provenance/dispatch and added shifts; F ownerR4 now inline. Actual affected timing and enclosing gain required; prior genericOT/small-N negatives retained.|
|5 DEFERRED|Recursive GKR/composed lookup/pooled commitments; potential architecture gains,high integration cost|New2024PoT and Hekate evidence require exact native relation,field/PCS/hiding/jointview/soundness and state links. No migration or privacy weakening authorized.|

NEW follow-up refinement: does D's real lookup/host/final dependency set allow
an aggregate table to remove any working-table reads, or only add one more
stream? Source-capture real TinyLlamaT128/8BT128 catalogs and shaped bindings;
count each mandatory dependency, test table-order permutations/alias/refusal
controls against the original full polynomial. No new GPU job requested.
Owner should profile clause construction/evaluation separately before porting.

LIVE sources: hardwareZeroCheck/SRAM fulltext, currentEPFL claim/oracle and
Sage precompute sources refreshed; NEW older [CCS2024training/GKR recursion](https://eprint.iacr.org/2024/162)
receivedFeb4/revisedJul22,2024; NEW Sep15,2026 [ROSETTA](https://arxiv.org/abs/2609.16915)
is encrypted inference, not verified proof; newly inspected [Hekate engine
releases](https://github.com/oumuamua-labs/hekate/releases) and helper-tree
postmortem extend prior math-only discovery. Hekate0.37date07Oct year
unverified; postmortem's check explicitly6Oct2026; verifier/coreAGPL claim and
full linking exception read, prover proprietary. No code adopted. All dates,
license scope, exposed versus inspected commits,403/cache failures and queries
are in source/search records. No external performance reproduced.

Target accounting this cycle: new completed full-stack proofs0,passes0,
proved positions0; target contextnone,device none. Steady and total-workload
rates,startup fraction,witness/proof/serialization/verification clocks are
unmeasured for the target. Test harness clocks above are synthetic only.
Larger valid workloads may amortize setup, but attention grows quadratically
with context, and decode requires proved state. Complete private8B>=50/s on
RTX5090 or another named high-endGPU remains unchanged and unachieved.
Production/runtime/Git/receipts/calibration/safety/instructions/reviewer files
untouched; no install/GPU/heavyjob/externalwrite/message/escalation. Saved
reports do not establish message delivery.

## Cycle0075 — actual D catalog and a memory negative, 2026-10-18

Run `20261018T042105Z-c9fe8fca`. No native proving speedup or target proof.
AGENDA and durable state/findings/source inventory, cycle74 results and project
instructions/target/status/decisions/coordination read; startup copies preserved.
Five LIVE source records appended to395 prior records,400total. No production,
runtime/Git, receipts, calibration, safety, instruction or reviewer files changed.

NEW question tested: does cycle74's D affine aggregate remove original input
streams once actual helper/host/padding/final dependencies are charged?
**Negative for memory.** Both current trained T128 public catalog descriptors
have35 D A columns,34lookups,17helpers,59tables and54 private terminal claims.
Only `A_X2` (returned table34) disappears from the unpadded arithmetic subset:
58original streams+L=59. Padding reads it again:60original+L=61. The existing
ClosureRounds explicitly reads/folds every table regardless of closure use,
so the current adapter is59->60, retaining all originals/finals/folds. It cannot
claim reduced table capacity, input streams or final-opening count.

Main PASS24fixtures, seed2026101875: N2/8/32, actual four-limb public descriptors
and generic four/five-limb partial-top cases, padded/unpadded D. Captured Rust
Ids/a_range/lookups_at/helper/pad/full-clause routines run with Shape/Layout
allocation substitutes and an exact u128 modular Fp2 reference. Native full
trained admission, PCS offsets and mask-site identity are NOT executed.
Independent Python semantic catalog and clause equations pass2,028full values,
468 round sums,1,488original-cube terminals,24full-expression permutations and
24alias cases.24harness binding refusals and10controls pass. Alias coefficients
must accumulate, not overwrite. Schema controls are not native verifier gates.
Independent audit83checks validates closed-form counts/source contracts/pins.

Meaningful harness error retained: initial derivation used32767 rather than
trained `INT16_ABS=32768`, yielding an incorrect provisional31bit8B norm window.
Final executes the captured native derivation core and both real profiles are
32bits. The wrong positive-only formula now fails a control. Initial failure
and superseded results remain under the experiment; no production calibration
was changed. Five-limb/partial-top and padded-D descriptors remain generic,
not admitted trained geometries. Actual current D axes do not pad.

Local clocks: main1.182008s including tiny local rustc shim, RSS18,924KiB,
compiler135,812KiB; audit0.001340s/RSS14,556KiB. One Intel CoreUltra9 185H CPU0
thread, nice19, WSL2; each59s wall/CPU and512MiB AS. No GPU/Cargo/installs or
downloaded code execution. Values synthetic; metadata whitelist contains only
public profile scalars. No native PTX/field, transcript/RNG/masking/privacy,
proof, serialization or fresh-verifier execution.

Allocation-free counts at T128: TinyLlama N262144 adds4MiB and142,606,336generic
build bytes/73,400,320base; 8B N524288 adds8MiB and285,212,672generic build
bytes/146,800,640base. All original data and final claims remain. Extra folds
48(N-1)logical bytes, pair endpoints32(N-1)unique logical bytes, N-1Fp2fold
products and4(N-1)step additions fordegree4. Source-level low-endpoint duplicate
mentions are reported separately; none is measured DRAM/cache/peak-RAM/register
usage. Complete typed base provenance is required or charge another full scan.
Fresh coefficients and masks per proof remain mandatory. Actual n_pad draws,
original degree, extension rounds and final order remain owner obligations.

Baseline: retained TinyLlama T128/22blocks/onepass RTX4070Laptop run174.052s
has26.691s all-D. Even deleting every D gives1.18113x/0.868615diagnostic
positions/s; this candidate changes only a clause subset and adds work.
Measured D clause share and8B ceiling unknown. Arithmetic result survives;
no native runtime gain follows from it. Reject a speed claim if prepare/build/
fold/transfer/verify/drain costs erase enclosing savings; reject correctness
on original polynomial/final/refusal, degree, transcript/RNG or privacy mismatch.

Unapplied follow-up handoff `handoffs/20261018-dzc-affine-read-catalog.md`;
interface `run.py::{prep,lin,fast}` uses actual returned table IDs and additive
collision handling. Seam owner `private_block/argument.rs::SC_DZC` plus
`SumcheckRounds`. L is driver scratch only: original polynomial/finals stay
in extension/mask stages; no extra private opening or independently masked L.
Native layout, frozen-byte/RNG, refusal and joint-view privacy gates remain.

Ranked queue after result:
1. OWNER whole-prover GPU/D/A and real residency slopes: highest measured
   recurring cost; include construction/transfers/drain/fresh verification.
2. NEW next local D row-coefficient plan on original endpoints, including the
   real34denominators/17helpers and hosts. Potential arithmetic reduction
   without full L scratch; moderate adapter cost; exactness, declareddegree,
   transcript/final and fresh-mask requirements unchanged. Falsify if all
   coefficient construction/interpolation/folding costs exceed original steps.
3. OWNER immutable public setup/resident fixed-context passes. Pay witness,
   fresh private masks/openings and drain each pass; no measured steady slope.
4. Cycle74 affine L: retain useful arithmetic identity; demote memory claim
   after this negative. Measure actual clause share before any device port.
5. Alternate lookup/GKR/PCS/composition: high integration/security cost; include
   all link/commitment/helper joint-view/field obligations. Retain all prior
   cubic/CSE/fusion/wrapping/offcube/jointmask negatives rather than retrying.

LIVE search: NEW inspection of older MSCProof implementation (paper knowncycle28):
README excludes activations/pooling, uses BLS12-381 and omits input preparation
from benchmarks; source historyFeb8,2024 observed, exposed commit fetch failed.
NEW Oct7,2026 Ziren design report and repo: jagged sumcheck/WHIR composition
and hardware claims not reproduced; stated whole-run assumptions remain.
Refresh extended sumcheck/CMU Sep1author explanation and Sage concrete factor
precompute, TensorZKP Aug2026proceedings, and Oct13Airbender with new release/
MIT-file inspection. Release tags omityear and Prime identity unverified.
LICENSE/commit/ePrint fetch blockers are recorded exactly; no bypass.
The negative local experiment proceeded independently of network failures.

Carried baseline remains R5b8B T128/32blocks/onecoldCPU pass/16threads/GPUoff,
shared n1: app606.598s/process606.728291s; diagnostic0.211013/0.210968positions/s.
Seal105.287s (17.357%phase, notstartup) overlaps loading36.570/witness103.349;
prove501.126s includes122.694witnessrebuild/21.176reload. Serialization unisolated.
Fresh verifier14.126load+43.902check (18.459reload inside), process186.088255
includes11controls. Receipt922,711,264B; no trainedprivacy/5090 acceptance follows.
All other baseline and owner R4 evidence retained in cycle74/startup STATE.

New accepted target complete proofs/passes/positions0/0/0. Target device none;
steady/total-workload rates, startup fraction, witness/proof/serialization/
verification clocks unmeasured. Synthetic cubes are not model tokens. No
long-context prefill, resident series or decode measured. Larger workloads
may amortize setup; context attention can grow quadratically. Complete private
8B>=50provedtokens/s on5090/namedhigh-endGPU remains unchanged/unachieved.

Final refinement: differential samples now include every declared D4/D5
point plus an independent off-grid point. Final2,028fullvalues/468rounds
replace the preserved initial1,560/360sample subset. No degree reduction.


## Cycle0076 — D endpoint coefficient schedule, 2026-10-18


Run `20261018T052105Z-217b5106`, 2026-10-18 UTC. Started 05:21:05;
completed within the 20-minute bound. Research only.

**No native proving improvement measured.** A new arithmetic candidate
computes the complete D row polynomial's coefficients from the original
endpoint pairs, sums them, then returns the original evaluation messages.
It avoids the full aggregate table whose memory claim failed last cycle.
Every original table, fold and final remains.

The baseline is the current host-slot schedule: full first round, then
evaluation-1 recovery. The generic driver still steps every table with
additions. Eliminated work is repeated scalar evaluation and stepping;
added costs are proof-local coefficient preparation, polynomial arithmetic,
five-word accumulation, conversion, scratch and dispatch. Native allocation,
reduction, register/spill and enclosing costs remain unknown.

PASS 30 synthetic fixtures, N=2/8/32, seed 2026101876. Actual TinyLlama and
Llama-3-8B T128 public four-limb catalog descriptors are exercised through
captured Rust Ids/B/catalog/full-expression code with Shape/Layout and exact
u128 field substitutes. Generic partial-top four/five-limb, odd-helper and
padded branches are algebra tests, not admitted trained profiles.

Results: 2,145 captured-Rust grid values, 390 off-grid values, 90 round
messages, 1,845 direct-cube original finals, 30 final polynomial relations,
1,950 schoolbook coefficients, 30 permutations, 30 aliases and 390 zero
censuses match. All eleven mutation/schema controls fire. These include
wrong recovered claim, helper order, lost leading coefficient, nonlinear
table folding, alias overwrite, missing final and support omission. Harness
schema controls are not native verifier controls. An independent 237-check
audit verifies closed-form counts, native source contracts and source pins.

The initial audit confused 33 affine inputs with 35 complete D A columns
when counting a padded branch; preserved failure and corrected formula are
under the experiment. The captured/measured operation census was correct.

At counted current 8B T128 D geometry N=524288, 19 sumcheck rounds, the
native Rust scalar-product model gives 1,317,795,621 -> 1,097,857,494
(-16.6899%), including preparation, conversion and all 59 original folds.
Fp2 add/sub calls fall 645,921,727 -> 316,669,728. No extra full-size table
is built, and no original/final is removed. Eighty bytes of output
coefficients is not peak scratch. Known-initial-claim counts save only
7.6312%. Later-row extension products rise 300->331 while base products
fall 236->72; speed depends on the arithmetic and register costs.
These are API counts, not elapsed time, GPU instructions or memory traffic.

Main test 1.900577s /19,332KiB RSS; tiny local compiler 133,488KiB;
independent audit 0.001987s /14,480KiB. One nice19 Intel Core Ultra9 185H
CPU0 thread, WSL2, each <=59s CPU/wall and512MiB AS. No GPU, Cargo,
installation, external code execution or competing heavy job.

Interface/seam: [candidate](../experiments/dzc-row-coefficients-20261018/README.md)
`plan/row/convert` -> owner `argument.rs::SC_DZC` and `SumcheckRounds`;
[unapplied handoff](../handoffs/20261018-dzc-row-coefficients.md).
Actual challenge plumbing, native layouts, seeded bytes/refusals/RNG,
extension/CFS/mask-site/final checks, fresh verification and joint-view
privacy gates remain owner work. Reject any mismatch or net enclosing loss.

The end-to-end formula remains total minus affected old D work plus all new
D work and integration costs. Actual D arithmetic share and8B ceiling are
unknown. Even deleting every D in the carried 1.1B 174.052s diagnostic
gives only1.18113x /0.868615 diagnostic positions/s. Arithmetic counts do
not establish the complete private8B >=50/s target.

Ranked questions after this cycle:

1. OWNER whole-prover GPU D/A and completed fixed-context resident-pass
   slopes: broadest measured costs. Include all construction, transfers,
   fresh verification, serialization and drain. Owner F round4 is19.4%
   isolated bandwidth under a thermal cap; it is not D or full-stack timing.
2. NEW LOCAL refinement: stream D denominator/helper coefficient pairs to
   reduce logical lifetimes without changing calls, degree, samples or
   originals. Moderate fixed-array/adapter cost. Falsify on any mismatch,
   no lower logical retention, or eventual native enclosing regression.
3. OWNER immutable public setup residency: possible amortization, no
   measured steady slope yet. Charge recurring witnesses and fresh masks/
   openings per pass; falsify on stale identity, backlog or no slope gain.
4. Affine aggregate: retain its identity, demote memory claim. Alternative
   lookup/GKR/PCS composition requires field/state/helper/joint-view and
   whole-run soundness review. Prior negative findings remain preserved.

Seven LIVE source records appended,400->407. NEW older implementation
inspection: [Spartan](https://raw.githubusercontent.com/microsoft/Spartan/master/src/sumcheck.rs)
confirms recovery/incremental points are baseline techniques and ZK uses
a separate wrapper; its MIT file and one2025 commit diff were inspected.
NEW recent [Pico3 report](https://blog.brevis.network/2026/09/30/pico-3-0-real-time-ethereum-proving-on-4-gpus-with-100-bit-provable-security/)
datedSep30 distinguishes heterogeneous batching, record compacting and
larger chunks; the served2025 public repo is not a verified Pico3 artifact.
Concrete EPFL MSB coefficient source, September monomial benchmark methods,
October Plonky3 releases, older commitment framework and Flock were refreshed.
All dates/license scope/exposed versus inspected commits and Cache-miss/
inaccessible-page blockers are in source records. No author speed/security
result reproduced; external source text was treated as untrusted data.

Carried baseline clocks, shared-host n1 diagnostics, not new acceptance:

| Scope | Total and rate | Witness/proof | Serialization | Independent verification |
|---|---|---|---|---|
|8B R5b,T128,32 blocks,1cold CPU pass,16threads,GPUoff|app606.598s/process606.728291s; diagnostic0.211013/0.210968positions/s|seal105.287s overlaps load36.570/witness103.349; prove501.126 includes witness rebuild122.694/reload21.176|not isolated;922,711,264B receipt|load14.126+check43.902;process186.088255 includes11controls|
|1.1B R3,T128,22 blocks,1default pass,RTX4070Laptop|app174.052/process174.196237s;diagnostic0.735412positions/s|load13.521,seal0.059,prove132.202 includes witness15.473/reload11.181|not isolated;497,665,904B|fresh load11.009+check9.394;process20.480536s|

Startup is unisolated.8B seal/app17.357% is a phase fraction, not startup.
Steady slope, initial-prefill boundary, lag/drain and proof latency remain
unmeasured. Native status's stale11.7% GPU F result is superseded by the
speed plan's04:30 round4 report19.4%; no new device run or thermal-policy
change was made here. Model projections and local counts are not acceptance.

New accepted target full-stack proofs/passes/positions **0/0/0**; device none.
Target steady-state and total-workload rates, startup fraction, witness/
proof/serialization/verification clocks unmeasured. No long-context prefill,
resident-pass series or decode ran. Longer attention context can grow
quadratically. Fresh masks/openings remain mandatory; no privacy weakening.
The complete private8B >=50provedtokens/s on5090/namedhigh-endGPU target
is unchanged and unachieved.

AGENDA/durable state/findings/source inventory/latest results and project
instructions/status/decisions/coordination/target were read; early STATE and
startup provenance preserved. Only research files changed; production,
runtime, Git, receipts, calibration, safety, instructions and reviewer files
untouched. No external writes/messages or escalation. Saved reports do not
establish user delivery. Next cycle no earlier than06:21:05UTC.


## Cycle0077 — D helper streaming: complete-lifetime negative, 2026-10-19

Run `20261019T091854Z-7d13829d`. **No native proving speedup measured.**
Pair streaming preserves the cycle76 complete D coefficients and all tested
original messages/finals with identical operation counts. Simultaneous
denominator retention falls68→4 Fp2 words; derived-buffer peak falls79→18.
But when original endpoint pairs also expire after last use, the current
actual unpadded T128 catalogs' complete logical peak, including accumulator,
falls only **130→129 words (0.7692%)**. The initially reported202→141 count
assumes the whole common endpoint bank stays allocated and describes a
separate scope. It is not a30.2% complete-lifetime/register/physical-memory
improvement. Initial narrower audit preserved. Generic padded194→131 does
not apply to actual unpadded T128; odd unpadded129→129 is another negative.

Thirty synthetic fixtures,N2/8/32,seed2026101977:1,950 coefficients,
2,145 captured-Rust grid and390 off-grid values,90 messages,1,845 original
cube finals,30 final relations,30 permutations/aliases,390 equal operation
censuses/value-independent traces,7 controls. Independent246-check audit
passes using interval and direct live-set methods plus source/formula checks.
A later consumer of all denominators destroys the streaming retention gain.
Six live production source pins unchanged. Main6.348416s/RSS33,804KiB;
compiler132,128KiB; audit0.118293s/RSS19,352KiB. One nice19 CoreUltra9 185H
CPU0 thread, each59s CPU/wall,512MiB address-space cap; no heavy/GPU job.

Both actual public T128 catalogs:35 A columns,34 lookups,17 helpers,59 tables,
4 limbs/32 bits, unpadded D. Partial-top/five-limb/odd-helper/padded branches
are generic algebra tests, not trained admission. Reference: actual captured
complete Rust D/catalog with Shape/Layout and exactu128 field substitutes,
independent Python clauses/direct cube; synthetic alpha/g_u8. Actual native
challenge plumbing/admission/transcript/RNG/masks/PCS/proof/serialization/
fresh-verifier/privacy gates remain owed. Seven synthetic controls are not
native verifier refusal tests. No external code executed.

Baseline/eliminated/added: versus cycle76, replace all-denominator retention
with helper-pair construction. All34 denominators still constructed; row
331 Fp2 mul/72 base/272 add/150 sub and preparation0/30/76/54 unchanged.
Charge new scheduling/dispatch/allocator/compiler costs. All59 original folds
and finals remain; no full table added or removed. Derived polynomial-buffer
counts exclude primitive scalar temporaries, plan data, allocator metadata,
physical memory, register allocation and all enclosing proof storage. Never
multiply per-worker logical savings by every row and call it VRAM.

8B affected D time/end-to-end ceiling unknown: total-old affected D+new D+
all integration costs. Deleting ALL D in the carried1.1B174.052s diagnostic
would give only1.18113×/0.868615 diagnostic positions/s, not this candidate's
prediction or an8B bound. Reject any original sample/degree/final/refusal/
transcript/RNG/privacy mismatch or enclosing regression. The large overall
retention hypothesis is demoted; cycle76 arithmetic identity remains useful.

Ranked queue:

1. OWNER whole-prover GPU D/A and actual fixed-context resident-pass slopes:
   broadest measured recurring work, high integration cost. Charge complete
   construction, transfers, serialization, verification/drain and fresh masks.
   Reject enclosing loss/correctness/privacy failure. Owner F round4's19.4%
   isolated/capped measurement is not D or full-stack timing.
2. NEW LOCAL next: construct original endpoint pairs on first public use
   instead of materializing59 pairs up front. Moderate adapter cost. Measure
   COMPLETE peak, every read/difference/alias/temporary/original fold; reject
   no lower peak, uncharged recomputation, value-dependent dispatch or any
   complete polynomial/sample/final mismatch. Native timing gates follow.
3. OWNER immutable public residency: possible setup amortization, no measured
   slope. Record context/pass count/concurrency; fresh witnesses, masks and
   openings per pass. Reject stale identity, backlog or no completed-proof gain.
4. Pair streaming alone is demoted; alternate lookup/GKR/PCS composition
   remains costly and requires field/state/helper/joint-view/soundness review.

[Experiment](experiments/dzc-pair-stream-20261019/README.md) and
[unapplied handoff](handoffs/20261019-dzc-pair-stream.md).
Interface: `run.py::row(v,p,streamed=True)`, prior plan/convert. Owner seam:
SC_DZC / SumcheckRounds. Graph nodes are instrumentation, not native allocation
advice. Preserve every original extension/mask/final-opening stage. No extra
private claim/opening or mask reuse. Real layout/actual challenges, seeded
bytes/RNG/refusals, fresh verification and joint-view privacy gates owed.

Seven LIVE records appended,407→414. NEW older Super-sumcheck prover source
and NVIDIA2015 indexing guidance inspected; current13.4 CUDA memory guide,
Plonky3 October release, ICICLE version-bump diff/MIT license, hardware
comparison and SumCATS refreshed. Exact access dates/URLs, publication/update
evidence, license scope, inspected/exposed commits and failed fetches retained
in source-records.json. Release years not exposed were not invented. Only
abbreviated6c77775 version-bump diff newly inspected; no full backend pin.
No author performance/security claim reproduced; source text is untrusted.

Carried8B R5b: T128,32 blocks,one cold CPU pass,16 threads,GPUoff,shared n1;
app606.598/process606.728291s, diagnostic0.211013/0.210968positions/s.
Seal105.287s is17.357% phase,NOT startup; overlaps load36.570/witness103.349.
Prove501.126 includes witness rebuilding122.694/reload21.176. Serialization
unisolated,922,711,264B receipt. Fresh verify14.126load+43.902check;
process186.088255 includes11controls. Startup/steady slope unknown; privacy/
5090 acceptance pending. Latest1.1B next-token result is a separate scope.
Owner round4F CLI still owes its22-block stack gate; no device job here.

New target proofs/passes/positions0/0/0; device none. Target steady/total rates,
startup fraction,witness/proof/serialization/verification clocks unmeasured.
No long-context prefill,resident series ordecode. Larger workloads allowed;
attention can grow quadratically with context. Fresh masks/openings mandatory.
Complete private8B≥50 proved tokens/s on5090/named high-end GPU unchanged and
unachieved. All prior sources/findings preserved; research-only writes.
[Dated full report](progress/20261019T091854Z-7d13829d.md). Saved reports do not establish delivery.


## Cycle 0078 — Lazy D endpoint construction, 2026-10-19

Run `20261019T101854Z-3562a78f`. **Useful logical-lifetime result; no native speedup measured.**
Constructing original endpoint pairs at first public use lowers the complete
polynomial-buffer peak **129→77 Fp2 words (40.31%, 832 logical bytes per active
row worker)** versus cycle 77's pair-streamed coefficient schedule. Both
schedules release all inputs and derived buffers after last use; construction's
extra high-value temporary and the five-word round accumulator are charged.
This is not physical memory, GPU registers or a proof clock. Python retains
its graph/cache and oracle values; native code must realize the modeled
release. No original full table is removed. Cycle 77's 130→129 negative remains
valid for its earlier scheduling question.

Both current public T128 catalogs (TinyLlama and Llama-3-8B) have 35 A columns,
34 lookups, 17 helpers, 59 tables, four limbs / 32 bits, unpadded D. Synthetic
N=2/8/32 is not a native T128 workload. Generic partial-top, five-limb, odd-helper
and padded tests are algebra controls, not trained profile admission.

Thirty fixtures pass, seed 2026101978: 1,950 lazy coefficients, 2,145 captured
Rust grid and 390 off-grid values, 90 messages, 1,845 original cube finals,
30 final relations, 30 remappings and aliases, 390 charged endpoint censuses
and value-independent traces; eight synthetic controls. Independent audit:
221 checks, canonical DAG hashes, inclusive interval/direct-live-set peaks,
source identity/counts, original fold/final contracts, six unchanged live
source pins. Captured complete Rust D/catalog with exact u128 field and
Shape/Layout substitutes agrees with independent Python clauses/direct cube.
Synthetic alpha/g_u8 are fixture constants, not native proof preprocessing.
No native transcript/RNG/mask/PCS/proof/refusal/privacy gate passed here.

Main 8.612566 s / RSS 47,748 KiB, compiler 138,144 KiB; audit 0.260665 s /
RSS 24,352 KiB. One nice19 Intel Core Ultra 9 185H CPU0 thread, WSL2; each
command capped at 59 s CPU/wall and 512 MiB address space. No GPU, Cargo,
installation or heavy job. [Experiment](experiments/dzc-lazy-endpoints-20261019/README.md).

Baseline, eliminated work and added costs: remove early endpoint lifetimes
only. Both schedules use 118 endpoint reads / 59 subtractions per row and
272/150/331/72 coefficient add/sub/mul/base calls. Every original fold/final
remains; folds separately require 118 reads / 59 writes and 59 each add/sub/mul.
Combined census: 331/268/390/72, excluding common round reduction, sample
conversion, plan and enclosing work. Charge public dependency/alias planning,
index dispatch, compiler scheduling, scalar scratch and actual spills.
Native 8B D share and end-to-end ceiling are unknown:
`old_total - old_affected_D + new_D + all_integration_costs`.
Deleting ALL D in the carried 1.1B 174.052 s diagnostic caps at 1.18113× /
0.868615 diagnostic positions/s; not an 8B bound or this schedule's prediction.
Falsify on any sample, final, degree, transcript, RNG, refusal or privacy
mismatch; no lower complete native resource use; uncharged recomputation;
secret-dependent dispatch; or enclosing regression.

Negative controls constrain the port: keeping endpoints until the end gives
136 words and loses the advantage; no memoization raises reads 118→198 and
differences 59→99. At the 77-word peak, 54 words are 27 endpoint pairs,
18 derived buffers and five accumulator words. The independent audit caught
saved metadata shadowing (`ll` reused by a baseline-lifetime loop); corrected
and main/audit rerun. Initial source/logs retained. Arithmetic and node traces
were unaffected.

[Unapplied handoff](handoffs/20261019-dzc-lazy-endpoints.md):
`run.py::lazy_row(raw,p)` → prior plan/reduce/convert, at `SC_DZC` /
`SumcheckRounds`. Static locals and compiler liveness are required; the Python
dictionary is instrumentation. Owner gates: actual native profile/challenges,
seeded bytes/RNG/refusals, extensions/masks/PCS/original finals, fresh verify,
tamper controls and joint-view privacy. D30's dictionary is an unbuilt new
profile, not implemented/admitted by this current-catalog prototype.
No extra private claim/opening, mask reuse or weakened privacy.

Ranked questions after this cycle:

1. **Owner: whole-prover GPU D/A and completed resident-pass slopes.** Broadest
   recurring-cost scope, high integration cost. Charge construction, transfers,
   serialization, fresh verification/drain and fresh masks. Reject no enclosing
   slope gain or correctness/privacy failure. Current speed plan now records
   the GPU F round-4 full 22-block stack gate complete, superseding cycle 77's
   pending statement; isolated 19.4% capped bandwidth is not D/full-stack timing.
2. **New local refinement: interleave affine contributions with endpoint use.**
   Baseline 77 words; 54 endpoint words remain live at peak. Accumulate each
   public aliased table's combined weight exactly once when helper/bilinear/
   host work needs it. Moderate adapter cost, unknown 8B ceiling. Charge every
   accumulator/read/difference. Falsify duplicate/missing terms, extra uncharged
   work, secret dispatch, any sample/final mismatch or no lower complete peak.
3. **Owner: immutable public setup residency.** Possible startup amortization,
   steady slope unknown. Track model/statement identity, context/pass count,
   concurrency and drain, with fresh witnesses/masks/openings per pass. Reject
   stale identity, growing backlog or no completed-proof slope improvement.
4. **Owner: D30 division dictionary / lookup-GKR composition.** Substantial
   counted geometry opportunity, separate unbuilt relation/profile/soundness/
   privacy obligations and high integration cost. Do not insert its counts
   into this 59-table catalog or equate counts with achieved throughput.

Eight LIVE records appended, 414→422. NEW primary Oct16 revisions:
[Chimera](https://eprint.iacr.org/2026/1388), received July7, studies resident
GPU state, compact transcript exchange, CPU tail and chunk-to-resident handoff;
[Sluice](https://eprint.iacr.org/2026/1758), received August21, trades external
stream I/O for prove-phase RAM after setup/witness streams exist. Abstracts
only, both PDFs403; no performance/security claim reproduced. New older
[linear-scan paper](https://web.cs.ucla.edu/~palsberg/course/cs132/linearscan.pdf)
(September1999) and [allocation paper](https://arxiv.org/abs/2011.05608)
(November11,2020) add complete-lifetime/compiler-cost filters. New recmo
Goldilocks lib wrapper and actual MIT file inspected; underlying NTT source
and version unavailable. Plonky3 October release/yrrid cache/zorch shape
sources refreshed. Exact URLs, dates, license scope and access failures in
source-records.json. No new inspected commit; exposed fe5e46d remains
uninspected. No external code executed or claimed benchmark reproduced.

Latest carried owner 8B diagnostic refreshed by reading/hashing clocks only
(receipt not reverified here): T32, 32 blocks, one public-row next-token pass,
laptop CPU, GPU off, shared n=1. Test total230.5 s / guard child230.645478 s;
prove191.7 s includes witness17.3 / block loads14.3; digest18.4 / tables1.8
separate. Fresh verify43.4 s includes block loads14.0; verifier digest17.7 /
tables1.6; verifier guard child81.314998 s includes other checks. Receipt
471,285,072 B. Startup, serialization and steady slope unisolated; Rayon
thread count not established beyond one test thread. Diagnostic prompt-position
rate32/230.5=0.138829/s differs from one output/230.5; neither is accepted
target or decode throughput. Review/privacy gate pending. Quiet stack
T32/T128156.2/432.5 s are status reports, not clocks independently reconstructed
here. Carried R5b T128606.598 s /0.211013 diagnostic positions/s retained
separately; don't mix shapes, versions or clock boundaries.

New target full-stack proofs/passes/positions **0/0/0**, device none. Target
steady/total rates, startup fraction and witness/proof/serialization/verification
clocks unmeasured. No long-context prefill, resident series or decode ran.
Larger workloads allowed; attention can grow quadratically with context.
Complete private 8B >=50 proved tokens/s on5090/named high-end GPU remains
unchanged and unachieved. Only research files changed; runtime, production,
Git, receipts, calibration, safety, instructions and reviewer files untouched.
Saved reports do not establish delivery.


## Cycle0079 — use-driven D affine lifetimes and actual8B ceiling, 2026-10-19


2026-10-19 UTC. **Useful logical-lifetime improvement; no native proving speedup.**

Completed: consume combined D affine terms on their source's first non-affine
use, with a public drain for affine-only sources and exactly-once alias
accumulation. Current unpadded catalogs' complete peak **77→27 Fp2 words**,
64.94%/800 logical bytes per active worker. Endpoint54→4,derived18,round
accumulator5 at the peak. All118 reads/59 differences and field arithmetic
unchanged. All59 original tables,folds,finals remain. Python retains its
graph/cache; no physical registers, RSS, VRAM or latency gain measured.
Baseline is the previous unintegrated coefficient prototype, not the installed
native sample evaluator. Generic padded93→87 and five-limb101→95 are smaller
gains; keeping sources until end gives136words. Candidate no-memoization
raises reads118→138/differences59→69. Prior negatives preserved.

Thirty synthetic fixtures,N2/8/32,seed2026101979:1,950candidatecoefficients,
2,145captured-Rustgrid/390off-gridvalues,90messages,1,845originalfinals,
30finalrelations,30permutations/aliases/affine-onlydrains,390charged/value-
independenttraces,12controls. Independent681-checkaudit passes. Actual
captured Rust D/catalog uses exactu128 field/Shape/Layout substitutes;
independent Python clauses/direct cube agree. Source/weight census verifies
every combined affine weight exactly once. Actual profile admission,
challenges/transcript/RNG/masks/PCS/proofs/privacy remain owner gates.
Six live native pins unchanged.

One nice19 CoreUltra9 185H CPU0 onWSL2,each59sCPU/wall/512MiBAS. Main12.651142s,
RSS56024KiB,compiler134256KiB; audit0.587274s/RSS27840KiB; cost audit0.021398s/
RSS21592KiB. One codegen unit/opt0 small local Rust reference only, no Cargo,
GPU, installation or foreign code execution. These are correctness-test clocks,
not an optimized timing A/B. Commands, seed, dimensions, source hashes, logs
and outputs retained in
[experiment](../experiments/dzc-use-driven-affine-20261019/README.md).

New measured-scope audit: parsed32 D-phase rows for each of three retained
8B T128 CPU stacks, with independent regex and application-event checks.
R6/b7,32blocks,one pass,16Rayonthreads,GPUoff:471.580s total,370.137s proof
region including witness94.021/load17.408,seal101.279,receipt922711264B.
D44.833s is9.507% of total. Even deleting ALL D at zero cost gives at most
**1.105058×/0.299944 diagnostic positions/s**, versus0.271428 baseline.
This is not this candidate's estimate or a GPU/accepted-private-throughput
bound. Earlier R5b shared606.598s/D61.164 and quiet432.539s/D43.292 are
separate runs. Fresh R6 verify34.587s+load11.599,guard146.473062s includes
controls; recheck32.311s+load9.903,guard42.276335. Serialization/startup
fraction/steady slope unisolated; sealing is not a startup boundary.
Owner independent review reverified R6 stack, but trained privacy pending;
researcher did not reverify any receipt.

Distinct latest next-token owner result:8B T32/32blocks/oneCPU pass,
test230.5s,proof191.7s includeswitness17.3/load14.3,verify43.4s,
receipt471285072B. Independent R3 review at10:58 permits this trained
next-token result to stand; reviewer fresh verify37.7s,secondroute41.8s.
No trained privacy acceptance, hidden-length variant or decode stream.

Ranked queue after this cycle:

1. **OWNER whole-prover GPU D/A and completed resident-pass slopes.**
   Broadest recurring scope; high integration cost. Preserve exact field/
   profile/refusal semantics and fresh per-proof witnesses/masks/openings.
   Measure native source construction, scalar arithmetic, all table/PCS
   traffic, reductions/transfers, serialization/fresh verify/drain. Existing
   F kernel's19.4% isolated laptop bandwidth is not a D/full-stack timing.
   Falsify on enclosing regression, growing proof backlog or privacy mismatch.
2. **NEW LOCAL static named-local realization of the27-word schedule.**
   Baseline77-word affine-first lazy prototype; eliminate early endpoint
   lifetimes only. Moderate incremental cost on unintegrated coefficient/
   streamed/lazy prerequisites. Charge proof-local planning, first-use/alias
   dispatch, scalar scratch, code size and actual compiler spills. Exact
   coefficients/original folds/finals are mandatory. End-to-end candidate
   ceiling unknown; CPU R6 delete-ALL-D bound above is deliberately broader.
   Falsify on any semantic/RNG/refusal/privacy mismatch, uncharged rereads,
   value-dependent planning, no actual resource reduction or enclosing loss.
3. **OWNER immutable public-setup residency and proof-window sweep.**
   Possible startup reduction; no measured repeated-pass slope. Verify cache
   identities/lifetimes/peak memory, fresh private draws and all completed
   proofs. High measurement/integration cost; existing public setup only.
   Falsify stale identities, reused private openings/masks, extra traffic,
   proof backlog or no total-workload gain.
4. **OWNER D30 dictionary/lookup-GKR composition.**
   Broader counted geometry opportunity; separate unbuilt profile and high
   soundness/privacy/integration cost. Keep all dictionary slots constrained,
   multiplicities committed before challenges and original refusal obligations.
   No full-table deletion follows from this27-word current-catalog row.

Integration seam: SC_DZC in pinned gpu-zerocheck argument.rs, through
SumcheckRounds. Interface `lazy_row(raw,p,use_driven=True)`; reduce its
five coefficients and convert to original messages with recovery.
[Unapplied handoff](../handoffs/20261019-dzc-use-driven-affine.md).
Main/Claude reviews and integrates; no merge here. Native actual challenges,
registered shapes, seeded bytes/RNG/refusals,extension/mask/PCS/final order,
fresh verify/tamper and joint-view privacy gates remain. No extra private
claims/openings, mask reuse or privacy weakening.

LIVE search rotation: lookup/softmax and quantization/arithmetic; five source
records appended422→427. Newly assessed older
[Min-Reg scheduling](https://arxiv.org/abs/2303.06855) supports the compiler
realization question. Refreshed
[Bits Under ZK-LLM](https://arxiv.org/abs/2609.36437) retains its excluded-clock
and projection-versus-full-proof boundaries. DeepProve softmax/current README/
actual custom license and licensing diff, current Plonky3 release/RNG PR and
known packed-sumcheck README were inspected. Exact primary URLs, dates,
license/commit scope and Cachemiss/InternalError blockers saved. No external
performance reproduced; inaccessible source was not bypassed. Not a paper list
substituting for the experiment.

Next: research-only static named-local Rust emitter, actual runtime
proof-local scalar parameters, differential full D against captured Rust,
and lowered scalar DAG/assembly lifetime audit. Native device compiler,
D benchmark and complete-stack resident series stay with owner shared
build/heavy locks. Rotation next: memory traffic/native realization and GPU
NTT/commitments; retain sumcheck/GKR,batching/amortization,composition queue.

New target proofs/passes/positions **0/0/0**, device none. Target context,
steady/total-workload rates,startup fraction,witness/proof/serialization/
verification clocks unmeasured. No long-context prefill,resident-pass series
or decode. Larger workloads allowed; attention may grow quadratically with
context. Complete private8B >=50provedtokens/s on5090/namedhigh-endGPU remains
unchanged/unachieved. Only research files changed; runtime/production/Git/
receipts/calibration/safety/instructions/reviewer files untouched.
Saved reports do not establish message delivery.


## Cycle0080 — 2026-10-19: static D runtime parameters and compiler boundaries

Run `20261019T121854Z-575be12a`. **Compiler storage result; no proving speedup.**
The prior use-driven affine schedule now has compiled Rust scalar locals,
proof-local runtime parameters and execution through the unchanged native
field source. Compared with the affine-first unintegrated coefficient arm,
the emitted CPU caller local stack allocation falls **1160→360bytes**, with
48 additional callee-saved push bytes in each, identical884Fp2calls and
272/209/331/72 add/sub/mul/base operations. Caller instruction lines rise
6986→7011;symbol bytes33878→32967. Static caller allocation and RSP references
are not executed spill traffic,GPU registers or proving time.

[Experiment](experiments/dzc-static-runtime-20261019/README.md),
[unapplied handoff](handoffs/20261019-dzc-static-runtime.md),
[dated report](progress/20261019T121854Z-575be12a.md).
`Lower.emit` produces `kernels.rs::driven(raw,params,bases,out)` with118Fp2
low/high inputs,129Fp2params,36canonicalbaseparams,fivecoefficients. Parameter
pack2352B,logical requested4320B/row in both arms;actualDRAMunknown. Planning
and values are proof-local,with no field-value/zero pruning. Primitive scalar
SSA peak incl.five-word accumulator76→26 is a different model from77→27
array buffers. All59 original tables/folds/finals remain. Keeping raw inputs
live defeats the storage benefit (candidate134words).

PASS:sixsyntheticfixtures,two publicscalarcatalogs,N2/8/32,seed2026101980;
780coefficients,390captured-Rustgrid/78offgrid,18messages,354originalfinals,
sixrelations,36zero bindings;sevencontrols and2372independent audits. Captured
complete Rust D/catalog with Shape/Layout substitutes,independentPython
clauses/cube,and actual native-field arithmetic agree. Sixnativepins and
fiveownerpins unchanged. Actual admission/challenges/alpha/g_u8,seededbytes/
RNG/refusals,extensions/masks/PCS/finals,fresh verify/tamper and privacy owed.
Current compiled scope is unpaddedfourlimb59tables;earlier generic Python
coverage remains distinct. D30 is a separate unbuilt profile.

Meaningful failures preserved: a u64 cast of signed lookup−1 broke equality;
canonical reduction modP fixes it with a live control. Initial rustc output
filename load failure retained. Fully inlined native compilation exceeded
40seconds;completed adapter uses noninlinedFp2 boundaries. This changes the
integration question: fuse within small helper groups while bounding compile
and argument/callee/codegrowth costs. Do not claim all-inlined/GPU resources
from the completed arm. The u128 substitute pass remains separate.

Native main3.807474s incl.compiler1.055092s,RSS37976KiB/compiler130212KiB;
audit1.005090s/RSS24252KiB. One nice19 CoreUltra9 185HCPU0,WSL2,rustc1.97.1,
opt1,onecodegenunit. Each59sCPU/wall,512MiBAS;noCargo/GPU/install/foreigncode.
These are correctness clocks,not kernel A/B latency. Original folds retain
118reads/59writes and59 each add/sub/mul. Combined331/268/390/72 excludes
common round reduction/conversion/plan and the enclosing proof.

End-to-end bound unchanged:carried R6/b7 8B T128,32blocks,one16-thread CPU
pass,GPUoff,total471.580s,proof370.137s incl.witness94.021/load17.408,
seal101.279s,D44.833s,922711264B. DeleteALLD bound1.105058x applies only to
that CPU diagnostic,not this candidate or GPU. Freshverify34.587+load11.599s;
startup/serialization/steady slope unisolated. Evidence read/hashed only,no
receipt reverified here. Distinct T32 next-token R3 review permits soundness,
reviewverify37.7s;privacy/hiddenlength/decode remainpending. R7 soundness
accepted. Current owner GPU F round4 gate remains complete at22blockT128;
its19.4%isolatedlaptop bandwidth does not measure D or full-stack target.

Ranked queue:1OWNER whole-proverGPU D/A and completedresident slopes;
2NEWLOCAL helper-groupcodegen to reduce884calls without>40scompile or lost
low lifetimes;3OWNER immutable publicsetupresidency withidentity/freshmask
and verifieddrain gates;4OWNER D30/architecturecomparisons. For2,baseline
and removed work are scalarcall overhead only,addedcosts include argument/
return traffic,callee scratch,compile/codegrowth,actualoriginalreads. Moderate
incremental integration cost;candidate ceilingunknown. Falsify any differential,
secret-dependent schedule,unchargedreads,compilelimitfailure or enclosingloss.

Eight LIVE primary records427→435. New
[ReedWeave](https://eprint.iacr.org/2026/2147) receivedSep22/revised24 offers
RSinterleaving;new [Quasar](https://eprint.iacr.org/2026/1839) receivedAug31
uses QAcode switching. Abstracts only,not native hiding/PCS acceptance;D10
stands. A new FHE-memory lead and older primary scheduling bibliography add
accounting constraints;known compiler/runtimekernel and NTTnegatives refreshed.
PDF/commit/history blockers and actual license scope saved. No external
implementation/performance reproduced. Rotationnext sumcheck/GKR,batching;
retainlookup/softmax,memory,NTT,quantization,composition.

New target proofs/passes/positions0/0/0,devicenone. Targetcontext,steady/total
rates,startupfraction,witness/proof/serialization/verification unmeasured.
No prefill,residentseries ordecode. Largerworkloadsallowed;attention may grow
quadratically. Completeprivate8B>=50provedpositions/s on5090/namedhigh-endGPU
unchanged/unachieved. No extra private claims,mask/opening reuse or privacy/
degree/refusal changes. Onlyresearchfileschanged;no production/runtime/Git/
receipts/calibration/safety/instructions/reviewerfilesmodified.


## Cycle 0081 — 2026-10-19 — generic helper grouping is a negative result

Run `20261019T131854Z-168a653c`. Native-field compilation can be bounded by
public-DAG groups,but fewer scalar calls do not produce an observed row win.
Same use-driven graph,884logical field primitives,19groups,max78scalar nodes:
compile4.626792s succeeds versus cycle0080's preserved fully inlined>40s
failure. Caller stack subtraction360→208B is misleading by itself: deepest
static call-chain span **424→504B**,including helper red zone and callee return
addresses. Relevant code33,543→145,739B;instructions7,171→39,737. Logical
row bytes4,320→8,528 because group crossing/final scratch adds4,208bytes.
PhysicalDRAM/cache miss/spill traffic is unknown; no GPU allocation inferred.

Eight alternating pairs of8,192cache-resident synthetic rows show medians
**6.208298→6.525496us** (grouped5.109%higher); seven pairs favor baseline.
One shared CoreUltra9 185H CPU0,nice19; baseline has artificial noinline field
adapters. No quiesced,p95,whole-D or enclosing performance claim. Generic
unique-group fusion is demoted; preserve this finding rather than promoting
884→19calls or the smaller caller frame.

PASS: sixfixtures,two public scalar catalogs,N2/8/32,seed2026101981;
780coefficients,390captured-Rustgrid/78off-grid values,18messages,
354originalfinals,sixfinalrelations,36zero bindings,sevennative-path controls.
Separate1,465-check boundary/source/assembly audit passes with missing-store,
stale-slot,caller-only-stack and ignored-traffic controls. Candidate field
source is byte-identical native source; captured D/catalog retains documented
field/Shape/Layout substitutes. Original59tables/folds/finals preserved;
fold traffic118reads/59writes and59eachadd/sub/mul stillowed. No additional
private claim/opening or reused masks. Native admission/challenges/alpha/
g_u8/RNG/refusals/transcript/masks/PCS/proofs/privacy remain owner gates.

Main7.215940s/RSS38,152KiB incl.compiler4.626792s/RSS131,768KiB;
audit0.122996s/RSS21,136KiB;microbench+harnesscompile1.181911s,
child0.841757s/maxchildcompilerRSS123,564KiB. Installedrustc1.97.1,opt1,
onecodegenunit;each59sCPU/wall/512MiBAS;noCargo/GPU/install/foreign execution.
[Experiment](experiments/dzc-helper-groups-20261019/README.md),
[negative handoff](handoffs/20261019-dzc-helper-groups-negative.md).
Seam: SC_DZC/SumcheckRounds; four-pointer runtime raw/params/bases/out ABI.
No production patch or merge; Main/Claude owns review/integration.

NEW refined question: can repeated helper topology share compiled code?
Address-abstracted census finds19groups/10shapes,including6- and5-instance
families. No deduplicated code was compiled. Charge public index maps,extra
argument/return loads,call-chain span and compiler/code growth. Reject any
slot/alias mismatch,extra field work,value-dependent schedule,compile-budget
failure,noresource benefit or enclosing regression. This follows the negative
rather than repeating the same generic groups.

Ranked queue:1OWNERwhole-proverGPU D/A and completedresident1/2/4/8slopes;
2OWNERimmutablepublicsetupresidency withidentity/lifetime/freshrandomness gates;
3LOCALsharedhelpertemplates,moderateincrementalcost/unknownenclosinggain;
4OWNERD30/architecturecomparisons,separateunbuiltprofile/highreviewcost.
HigherscopeGPU and completedverifieddrain outrank this small scalar seam.

Baseline/eliminated/added/ceiling: baseline current use-driven coefficient
prototype with884scalarcalls; remove call boundaries only,add scratch/frame/
code/plan costs. `new_total=old_total-affected_D+replacement_D+integration`.
CarriedR6/b7CPU8BT128/32blocks/one16-threadpass,GPUoff,total471.580s,
proof370.137s incl.witness94.021/load17.408s,seal101.279s,D44.833s,
receipt922711264B. DeleteALLD atzero cost caps only thatCPUdiagnostic at
1.105058x/0.299944diagnosticpositions/s vs0.271428baseline. No GPU or
candidateforecast. Freshverify34.587+load11.599s;recheck32.311+load9.903s;
serialization,startupfraction,steady slope unisolated;seal is not startup.
Owner evidence read/hashchecked;researcher did not reverify receipts.
DistinctT32next-token R3soundness maystand;trainedprivacy/hiddenlength/decode
remainpending. Allcarriedclocks are separately labeled in target-accounting.

Seven LIVE source records435→442: new[ComFuse](https://arxiv.org/abs/2608.03537),
new[NVIDIAfusion](https://developer.nvidia.com/blog/?p=119743),and older
[LLVMoutliningRFC](https://lists.llvm.org/pipermail/llvm-dev/2017-September/117814.html)
with currentcostsource; refreshedStateSync preparation/drain,actualBSLrelease
license,Plonky3strategy/rc2 andolderarkworks. StateSync known sincecycle0051,
not new. Actualdates/licenses and source/commitInternalErrors retained;
no external implementation or speedup reproduced. The initial legacyid-schema
recorder error occurred beforeappend;corrected,all435priorrows preserved.

Newtargetproofs/passes/positions0/0/0,devicenone. Targetcontext,steady/total
rates,startupfraction,witness/proof/serialization/verificationunmeasured.
No longprefill,residentpassseries ordecode;largerworkloads remainallowed,
attentioncangrowquadratically. Completeprivate8B>=50provedpositions/s on5090/
namedhigh-endGPU unchanged/unachieved. Onlyresearchfileswritten;no runtime,
production,Git,receipts,calibration,safety,instructions orreviewerfilesmodified.
Savedprogress files do not establishmessagedelivery.


## Cycle 0082 — 2026-10-19 — shared helper code shrinks; no speed gain

Run `20261019T141854Z-0a847d64`. Shared public D helper topology replaces
19 unique bodies with ten; still 19 calls and 884 field primitives on the
same 1,167-node graph. All 59 original tables, folds and finals remain.
Reachable function code falls 145,739→78,421 bytes (46.19%), plus 634 bytes
of public maps; instructions 39,737→21,420. Static call-chain span stays
504 bytes versus scalar baseline 424. Logical row bytes rise 8,528→9,162,
versus scalar 4,320. Physical DRAM traffic is unknown.

No speed improvement found. Final nine rotating triplets of 8,192 rows give
scalar/unique/shared medians 3.7134/4.5428/4.6577 µs; unique/shared ratio
0.975323, only 3/9 pairs favor shared. Pair ratios span 0.8004–1.2953.
These are shared-host, cache-resident synthetic rows with an artificial
noinline scalar baseline; no native sampler, whole-D, GPU, quiesced/p95 or
proof timing claim. Exploratory pre-control samples are retained separately.
The runtime hypothesis is demoted; preserve the code-size finding.

Six fixtures, two public scalar catalogs, N=2/8/32, seed 2026101982 pass:
780 coefficients, 390 captured-Rust grid/78 off-grid values, 18 messages,
354 original finals, six final relations, 36 zero bindings and eight native
controls. New compiled wrong-map changes an initialized in-bounds parameter
load and breaks equality. A separate 1,455-check address, initialization,
ownership, assembly and source audit passes six corruption controls. Native
field unchanged; captured D/catalog retains field/Shape/Layout substitutes.
Actual native profile/challenge/alpha/g_u8/RNG/refusal/mask/PCS/proof/privacy
and GPU integration remain owner gates. No additional opening or mask reuse.

[Experiment](experiments/dzc-shared-templates-20261019/README.md),
[unapplied handoff](handoffs/20261019-dzc-shared-templates.md).
Seam: SC_DZC / SumcheckRounds. Main/Claude owns review and integration.
Main 7.734896 s including compilation 5.503053 s; main/compiler RSS
37,472/147,156 KiB. Final audit and benchmark clocks are in the experiment.
One nice-19 Core Ultra 9 185H CPU0, rustc 1.97.1/LLVM 22.1.6, opt-level 1,
one codegen unit; each experiment ≤59 seconds CPU/wall and 512 MiB AS.
No Cargo, GPU, installation or foreign code execution.

Baseline/eliminated/added/ceiling: compared with unique groups, eliminate
nine compiled body copies, add map storage/loads and address arithmetic;
remove no field work. Candidate end-to-end gain unknown. Carried R6/b7 8B
CPU T128, 32 blocks, one 16-thread pass, GPU off: total 471.580 s; proof
370.137 s includes witness 94.021/load 17.408; seal 101.279; D 44.833;
922,711,264 bytes. Delete-all-D at zero cost bounds only this diagnostic at
1.105058× or 0.271428→0.299944 diagnostic positions/s. Fresh verification
34.587+load 11.599 s; recheck 32.311+9.903. Serialization, startup fraction
and steady slope unisolated; seal is not startup. Four D and five token-owner
evidence pins recheck; researcher did not reverify receipts.

Ranked queue: (1) owner whole-prover GPU D/A and completed verified resident
1/2/4/8 passes; (2) owner immutable public-setup residency; (3) NEW local
exact typed-pointer-offset census; (4) owner D30/architecture comparisons,
separate unbuilt profile. Full prerequisites, costs, exactness, privacy and
falsification criteria are in hypotheses.json. D32 float fidelity stands.
Next local experiment first checks whether raw/parameter/base maps differ by
exact typed offsets while retaining arbitrary scratch maps. Stop on
non-affine families; reject alias changes, value-dependent planning, extra
field work, no resource benefit or enclosing regression. Owner device and
completed resident measurements outrank further helper tuning.

Six LIVE primary records append 442→448: newly assessed older
[global function merger](https://arxiv.org/abs/2312.03214),
[LLVM parameterization patch](https://lists.llvm.org/pipermail/llvm-commits/Week-of-Mon-20231016/1225745.html)
and 2025 talk; current LLVM 23.1.3 (October 6); refreshed zkLLMPoT v2
(October 11) and zkIE. Inspected commit bb9d1badcda28bbea37938644fbb8887e0381038
belongs to the preliminary inline 2023 patch, not HEAD or an established
merged version. Actual LLVM license inspected. GitHub PR/zkIE release/license
InternalErrors and commit Cache miss retained. No external implementation
or performance reproduced; LLVM 23 not installed. Rotation next: batching,
amortization, public setup/lookup; retain NTT/commitments, sumcheck/GKR,
memory, quantization/arithmetic and proof composition.

New target proofs / passes / positions 0/0/0, device none. Target context,
steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No prefill, resident series or decode.
Larger workloads allowed; attention may grow quadratically. Complete private
8B / ≥50 proved positions/s on 5090/named high-end GPU unchanged/unachieved.
Only research files written; runtime, production, Git, receipts, calibration,
safety, instructions and reviewer files untouched. Saved reports do not
establish delivery.


## Cycle 0083 — 2026-10-19 — single raw-pointer translation falsified

Run `20261019T151854Z-4f2eec2a`. **No speed improvement found.** The two repeated D
helper families do not admit one uniform raw-pointer translation: all nine
non-reference instances fail exact source-address equality. Family 3 needs
two raw pointer groups, family 6 three (including a group-14 exception).
E.g. `[18,19,20,21,88,89]` becomes `[22,23,24,25,90,91]`, requiring shifts
`[4,4,4,4,2,2]`. The full naive proposal can request slot124 from118
endpoints; no invalid pointer was executed. Stop this lowering. This is not
a rejection of general affine maps or a multi-pointer alternative.

Partial parameter/base translation is exact on the captured graph. Retain
raw and scratch maps; remove only77+22 u16 index requests=198 logical
bytes/row (634→436 map bytes), add18 nonzero typed pointer shifts with the
same helper arguments. Proposed shared row requests9162→8964 (2.16%);
scalar4320 and unique8528 remain historical. No field work removed:
same1167-node DAG,884 primitives,59 original tables/folds/finals,208B
scratch. No lowered kernel, code/stack/runtime or physical DRAM measurement.
Previous negative grouped CPU timing stands; partial option is low priority.

PASS:2888 symbolic checks,33 arbitrary synthetic fixtures (24 random,
8 boundary,1 zero),165 coefficients per candidate arm,seed2026101983,
8 controls. Wrong in-bounds raw shift changes24/24 random and7/8 boundary
fixtures; zero values conceal it. Independent audit187 checks/3 controls
derives source matrices/minimal groups/byte costs and compares36 new fixtures,
180 coefficients to the retained own-research scalar native-field oracle.
Oracle source/binary match prior artifact manifest. Wrong extension polynomial
breaks35/36 fixtures. No new whole-D/catalog/native profile/fold/final/proof
or privacy gate. Two initial safe harness/control assertions and corrections
retained. All20 carried source/evidence pins recheck.

Main0.254043s/18980KiB; audit0.098289s/20532KiB. One nice19 Core Ultra9
185H CPU0,Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps,64MiB estimate.
No build,GPU,install or foreign execution. Native field oracle reused prior
rustc1.97.1/LLVM22.1.6 binary; no new compiler benchmark.
[Experiment](experiments/dzc-affine-address-census-20261019/README.md),
[unapplied handoff](handoffs/20261019-dzc-affine-address-census.md).
Native seam SC_DZC / SumcheckRounds; research translated_plan/partial JSON
could feed the previous grouping emitter. Fresh parameter/alpha/g_u8 binding,
native admission/RNG/refusals,masked extension/PCS/finals,independent receipt
verification,joint privacy and enclosing clocks remain owner gates. No new
opening or mask reuse. Main/Claude reviews integration; no production patch.

Baseline/eliminated/added/ceiling: shared maps versus99 fewer index requests,
18 added pointer shifts; no arithmetic/proof cost removed. Candidate
end-to-end gain unknown. Carried R6/b7 8B CPU T128,32 blocks,one16-thread
pass,GPUoff:471.580s total,proof370.137 includes witness94.021/load17.408,
sealing101.279,D44.833,receipt922711264B. Delete-all-D ceiling1.105058×,
0.271428→0.299944 diagnostic positions/s only; strict-subset candidate
cannot claim that gain. Fresh verify34.587+load11.599,recheck32.311+9.903.
Serialization,startup fraction,steady slope unisolated; sealing is recurring
input work. Researcher did not reverify receipts. T32 next-token clocks kept
separate in target-accounting.json.

Ranked queue:(1) owner whole-prover GPU D/A + verified resident1/2/4/8;
(2) refined immutable public setup lifecycle across R8 sealing/restart,
with full layer/calibration/manifest keys;(3) owner D30 dictionary, separate
unbuilt profile;(4) tested partial parameter/base translation,low priority;
(5) uniform raw translation,ELIMINATED. Full cost/prerequisite/exactness/
privacy/falsification criteria in hypotheses.json. D32 fidelity direction
and pending numeric thresholds stand. Next local: source-only public setup
lifetime ledger and synthetic stale-key controls. Prior witness-suffix replay
and its memory limits are known; do not relabel sealing as startup.

Seven LIVE primary records448→455: new MLIR,older Polygeist legality paper/
repository,older BatchZK scheduling; refreshed known super-sumcheck,
efficient-sumcheck and recent zkLLMPoT v2. Verified dates/license scope,
inspected Polygeist77c04bb2a7a2406ca9480bcc9e729b07d2c8d077 (ctz builtins,
not this optimization),cached-history limits and InternalError/Cache miss
retained. No current HEAD inferred from crawl dates; no external gain
reproduced. Rotation public setup/batching,then NTT/commitments,lookup/
softmax,quantization and composition; retain sumcheck/GKR and memory.

New target proofs/passes/positions0/0/0,device none. Target context,
steady/total rates,startup fraction,witness/proof/serialization/verification
unmeasured. No long prefill,resident series or decode; larger workloads
allowed,attention may grow quadratically. Complete private8B≥50 proved
positions/s GPU target unchanged/unachieved. Only research files written;
no runtime,production,Git,receipts,calibration,safety,instruction or reviewer
writes. Saved reports do not establish delivery.


## Cycle0084 — 2026-10-19 — public setup lifetime and partial-LRU negatives

Run`20261019T161854Z-4bc2599e`. **No speed improvement measured.** Read/pinned11 reviewed R8
sources and4 public evidence files. NTT is already shared across all blocks;
one other construction serves both external endpoints. Device twiddles are
already monotonic/process resident. Ideal CPU public owner2R->1 constructions
retains524560B atT128;0additional GPU uploads removed. Sealing already
deduplicates layouts by full calibration within fixed shape; CS8 independently
rebuilds each caller-provided layout and cannot silently be cached away.

Whole-stage layout caching by Shape fails105 synthetic stage maps over
1/2/4/32 blocks,T32/64/128; incoming/outgoing internal pairs begin at34/32
atT128. Use full checked Shape for public Layout base and freshly derive IO
overlay from RunStatement. Geometry omits calibration; full Shape also does
not identify a layer's public tables:31 real public R8 base-shape layers use
6 exp/SiLU key combinations. No native Shape/admission or exploit test.

72 public request traces: partial LRU capacity1/4/16/31 has0hits across
ordered32-layer scans. Fixed public pinned4 yields60/512 hits over8 sealing/
proving scan pairs. Retained4 payload973645824B=0.906778GiB; per block
243411456B,all32=7789166592B=7.254227GiB. Padded FFN16384 (true14336)
matters: dropping padding undercounts0.75GiB/stack. Allocation-free public
counts only,no model bytes retained,no actual peak/DRAM/runtime or GPU fit.

PASS:66129 checks,24 random/boundary/zero NTT fixtures,6 RS fixtures,
32768 full-capacity twiddles,222 IO-site checks,35 descriptor mutations,
13 controls. Separate audit1400 checks/5 controls,24 direct monomial
DFTs and32 fresh norm-coefficient counterexamples;no candidate import.
Main0.345412s/24872KiB,audit0.095730s/
16204KiB,one nice19 CoreUltra9 185H CPU0,Python3.10.12,WSL2;
59s CPU/wall/512MiB AS caps,64MiB estimate. No build/GPU/install/foreign
execution. Initial CPU-only census preserved; later GPU-source inspection
narrowed scope,no failing harness. Fifteen source/evidence pins rechecked.

Carried owner R8 CPU 8B diagnostic, T128 /32 blocks /one16-thread pass,
GPU off, n=1: total478.737s, diagnostic128/478.737=0.267370
positions/s. Prove_run393.785s includes witness hand-over98.348s, itself
including block loads17.595s. Sealing wall84.824s includes overlapping load
tasks27.151s and witness tasks80.897s. **The JSON load_seconds field is
seal.load_s only**, not all loads. These nested/overlapped clocks must not be
added. Receipt922711264B. Fresh verify42.709s plus initial load13.681s;
recheck34.395s plus load10.739s. Verification control time is separate from
the basic verify clock. Startup fraction, isolated serialization and steady
slope are unmeasured. Researcher did not reverify any receipt.

Baseline/eliminated/added/ceiling: remove only truly avoided immutable public
construction/reloads; add authenticated complete keys,fixed retention,
eviction/peak and layout copy/overlay costs. No per-input sealing/witness,
refusal,sumcheck,masking,commitment,serialization or verification removed.
Candidate ceiling T/(T-s+a),s/a unisolated. Deleting all reported load tasks
at zero cost gives only1.103104x on this CPU
diagnostic; overlap makes this optimistic,not a pinned4/NTT/GPU forecast.
Falsify stale identity/calibration/site,private dependence,gate mismatch,
peak failure or no enclosing gain.

Ranked:(1)owner whole-prover GPU+verified resident1/2/4/8;(2)NEW fixed public
pinned owner,partial LRU rejected;(3)owner reviewed bounded same-attempt
witness retention,prior cycle0016 limits retained;(4)owner D30 architecture;
(5)CPU NTT/layout residency demoted;(6)stale keys/partialLRU eliminated.
Full hypotheses and prerequisites/exactness/privacy/cost criteria saved.
[Experiment](experiments/public-setup-lifetimes-20261019/README.md),[unapplied handoff](handoffs/20261019-public-setup-lifetimes.md).
Seams seal_and_record/BlockCache::get and prepare_endpoints/prove_run_with;
no native patch. All owner admission,CS/H-1,fresh role-separated OS streams,
PCS/finals,receipt and joint privacy gates remain. No opening/mask reuse.

Seven LIVE records455->462: current October StateSync
paper/release,P3 rc2,ICICLE domain lifecycle,and newly assessed older cuZK
paper/author repo. Inspected88e3295cada379abe06240df23ec6c9fc0f648b2 is a
README-only historical change. Date/license scope qualified. Pipelonk
DOI/ACM403,Zenodo inaccessible,license/commit fetch failures retained;lead
unassessed,no external performance reproduced. Rotation batching/public
setup->lookup/softmax catalogs->quantization/arithmetic/composition; retain
NTT/commitments,sumcheck/GKR,memory.

Next local: build a public-only immutable-layer-owner trace with
synthetic contents and full model/manifest/layer/table identity, then test
fixed pinned admission against stale exports, layer-range/base changes,
cross-model swaps and peak lifetime overlap. Retain every native CS/H-1 check;
compare a streaming no-cache oracle. First derive where a retained Arc can
replace reconstruction at seal_and_record and BlockCache::get. Do not launch
a model build/proof or repeat the disproven partial-LRU policy. Owner request:
isolate public construction, CS rechecks, witness and serialization clocks,
then independently verify fixed-context resident1/2/4/8 workloads under locks.

New target proofs/passes/positions **0/0/0**, device none. Target
steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No long prefill, resident proof series or
decode ran. Synthetic pass counts are constructor requests, not proved work.
Larger workloads remain allowed; attention may grow quadratically. Complete
private8B / >=50 proved positions/s on5090/named high-end GPU remains
unchanged/unachieved.
Only research files written;runtime/production/Git/receipts/calibration/
safety/instructions/reviewer files untouched. Saved reports do not prove
message delivery.


## Cycle0085 — 2026-10-19: public owner freshness and live leases

Cycle0085 — `20261019T171854Z-d589849d` — 2026-10-19 UTC.

**No speed improvement measured.** A complete cache key does not observe
changed backing arrays. The key-only owner fails the streaming oracle's
source-mutation refusal semantics. A guarded owner matches the tested
outcomes but retains every raw source read observation; only construction
is avoided. This does not demonstrate an unsound proof: retained original
bytes still name the original model. It is a native behavior/compatibility
failure if silently substituted for the existing mutable-export loader.

The native seam is seal_and_record -> shared public owner -> BlockCache::get.
The frozen R8 source (15 source/evidence pins,11 matching its manifest) already
shares the current Arc between witness and proving. Full seal validation,
reduced reload, actual block digest checks, CS1/3/4/6/8/9 and H-1 remain owner
port gates. No native patch or merge. D33 covers only trained TinyLlama T32
pg_rot1 CPU R7; R8 needs re-pin, and 8B/GPU/token stages are outside it.
D32 fidelity thresholds remain binding.

The bounded synthetic experiment uses32 public fixtures,13 arrays per layer,
seven5x3 matrices padded8x4 and six1x3 vectors padded1x4. Each layer has123 raw
bytes; these are seeded random public miniatures, not model arrays or field
arithmetic. A tuple-of-bytes owner is immutable. The full19-field identity
includes model/checkpoint/approval/profile/manifest/layer, axes, context,
ordered layer selection, base/own calibration, exp/SiLU keys, RoPE and source
format. This conservative synthetic key is not an admitted native key.

Main PASS: 67404 assertions,4800 synthetic requests,8 controls.
Row-copy construction is compared byte-for-byte to independent elementwise
padding on every request. Mutations to all19 descriptor fields refuse.
All13 raw-array mutations under the ORIGINAL expected identity demonstrate
the key-only stale-source counterexample; guard rejects them. Length,
manifest, table and RoPE changes also refuse. No concurrent-writer/atomic
snapshot guarantee follows from sequential in-memory revalidation.

Separate audit PASS: 2738 assertions,32 fixtures,416 independent
content-mutation controls and64 fresh asymmetric padding fixtures. It imports
no candidate code. The fresh fixtures validate the audit's padding oracle;
they are not additional candidate differential cases. Main/audit clocks
0.450538/0.012894s; peaks
19420/15552KiB. One nice19 CoreUltra9 185H CPU0,
Python3.10.12,WSL2;59s CPU/wall,512MiB address space,64MiB estimate per command.
Exact argv/exits/stdout/stderr are retained in commands.json and*.log.
Seeds2026101985 (main),2026101986 (audit).

Pin4 across8 ordered sealing/proving scan pairs gives60/512 constructor
hits,452 constructions, but512/512 source-read observations remain with
strict revalidation. Public padded native T128 payload count:
243411456B/block. Pinned4 retention973645824B=0.906778GiB; plus current/next
envelope1460468736B=1.360168GiB. These logical counts allocate no model data
and exclude raw decode/pad temporary buffers, private witnesses, proof/device
buffers, allocator and runtime. They are not peak-RSS/VRAM admission.

On an abstract model-generation change, two old blocks remain borrowed.
Charging registry entries only admits four new pins and reaches8 logical
blocks1947291648B=1.813557GiB against a six-block budget. Charging the union
of live owners plus two streaming reserves admits2 and denies2, capped at6.
This is a lifetime stress model, not an observed native concurrency trace.
Eviction is not a deallocation guarantee while Arc borrowers remain.

Baseline is current separate ownership. Removed work: only authenticated
public padding/construction on actual hits. Added costs: all guarded source
reads/hashes, complete identity checks, retained ownership/admission and
temporary overlap. Exclusive construction clocks are absent. End-to-end
ceiling T/(T-s+a), saved exclusive wall s and extra a, is unknown. Do not use
hit ratios as time savings or transfer prior generous all-load deletion bounds
to this guard. Falsify if native refusal/receipt/privacy behavior changes,
memory budget fails, or extra work costs at least the saved construction.

Spartan's inspected historical digest-owner commit is a useful comparison,
not a license to cache native current-file checks. Source census also rules
out an apparent second full digest from protocol::transcript in the trained
streaming route: that call belongs to single-block wrappers. Preserve it.

Carried owner R8 CPU 8B diagnostic: T128, 32 blocks, one 16-thread
pass, GPU off, n=1. Total 478.737 s; diagnostic quotient
128/478.737 = 0.267370 positions/s. Prove_run 393.785 s includes witness
hand-over 98.348 s, itself including block loads 17.595 s. Sealing wall
84.824 s includes overlapping load tasks 27.151 s and witness tasks 80.897 s.
The JSON load_seconds is sealing load tasks only. Do not add these nested or
overlapped clocks. Receipt 922,711,264 B. Fresh verify 42.709 s plus initial
load 13.681 s; recheck 34.395 s plus load 10.739 s. The fresh verifier's
guard wall 165.982 s also includes control work, not just basic verification.
Startup fraction, isolated serialization and steady slope are unmeasured.
Researcher did not reverify a receipt and awards no new target credit.

Nine qualified LIVE primary records append sources462->471: newly assessed
Spartan digest-residency commit, older paper boundary, recent Magnetar paper
and announcement, StateSync, BatchZK, ZKProphet, cuda-zkp-ntt and P3 release
filters. Licenses/verified dates/commit scope and access failures are explicit
in source-records.json/search-log.md. No external performance reproduced.

Next local experiment: account for the R8 public loader's raw arrays,
aw/fw padded vectors and new_shaped-owned copies over the full constructor
lifetime. Compare borrowed-copy versus checked ownership-transfer on small
synthetic shapes with true-head permutation, zero pads and invalid-support
controls; derive a conservative public peak including current/next loads and
retained pins, without allocating model data. Preserve every constructor/CS
check and native reload/refusal. This closes a memory exclusion in the present
ledger. Cycle0027 already completed canonical public digest streaming/cache;
do not repeat it or claim a second stage hash from single-block wrappers.
Owner priority remains whole-prover GPU plus independently verified fixed-
context resident1/2/4/8 complete workloads under shared heavy locks.

New independently verified target proofs/passes/positions: **0/0/0**;
device none. Target steady-state and total-workload rates, startup fraction,
witness/proof/serialization/verification clocks: unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic scan
pairs are public constructor requests, not proof passes or proved positions.
Larger workloads remain allowed; longer context can increase attention work
quadratically. Complete private 8B / >=50 proved positions/s on one RTX 5090
or a named high-end GPU remains unchanged and unachieved.

Only research files written. No runtime, production, Git, receipt, calibration,
safety, instruction or reviewer files changed. No GPU/build/install/downloaded
code execution, external write/message, purchase or escalation. Saved reports
do not establish delivery. See hypotheses.json and the unapplied handoff.

Prior-findings check before final checkpoint: cycle0027 already tested full public digest streaming/cache and no per-stage model rescan. It remains completed/demoted. The next local task was redirected to raw/padded/owned constructor overlap, which this cycle explicitly excludes.


## Cycle0086 — 2026-10-19: checked public constructor transfer

Cycle0086 — `20261019T181854Z-f5bd1f03` — 2026-10-19 UTC.

**No speed improvement measured.** Checked public ownership transfer matches
48 synthetic layouts and preserves tested refusal/encoding outcomes. Native
R8 source shows12 vector clones totalling243410944B per8B T128 load that an
owned constructor could avoid. The512B inline activation copy remains.
No native code was modified, built or proved; proposed patch is unbuilt.

Main PASS 7074 assertions / 2200 rejected mutations;
independent audit PASS 1871 assertions /624 output-corruption controls.
Main/audit 12.308901/0.152414s, peaks
30416/26828KiB, one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s/512MiB caps. These are synthetic validation clocks,
not a native constructor benchmark.18 pins unchanged;14 match frozen R8.

The previous pins4+current/next1.360168GiB ledger excluded loader temporaries.
This cycle counts raw/padded/owned buffers, decode/maps, optional RoPE reserve
and full sealing record hash scratch. Enumerated public-payload envelope with
four distinct pins+current+next load, accounting for16 native hash workers:
**2.016689GiB borrowed ->1.789997GiB moved** [MODEL]. One-worker ledger:
1.852619->1.625927GiB. Not actual RSS/VRAM, complete memory or hardware fit;
private witness/proof/device/allocator/page-cache costs remain excluded.
Evicted live leases from prior findings must still be charged separately.

Carried owner R8 CPU 8B diagnostic: T128,32 blocks,one16-thread pass,
GPU off,n=1. Total478.737s (128/478.737=0.267370 positions/s diagnostic),
prove_run393.785s includes witness hand-over98.348s, itself including17.595s
block loads. Sealing wall84.824s includes overlapping27.151s load tasks and
80.897s witness tasks. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial load13.681s; recheck34.395s plus10.739s load.
Fresh guard wall165.982s includes controls. Startup fraction, isolated
serialization and steady slope are unmeasured. Researcher did not reverify
a receipt; no new target credit. Owner RSS6.69GiB/cgroup9.76GiB includes
existing allocations; do not add this public ledger to those peaks.

New independently verified complete-stack proofs/passes/positions: **0/0/0**;
device none. Target steady-state/total-workload rates, startup fraction and
witness/proof/serialization/verification clocks: all unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic48
fixtures are constructor cases, not proof passes. Larger workloads remain
allowed; attention work can grow quadratically with context. Complete private
8B / >=50 proved positions/s on one RTX5090 or a named high-end GPU is
unchanged and unachieved. No fresh masks, private commitments or openings
were reused or changed.

Owner: review the unbuilt two-file patch, then run locked native constructor
byte/refusal/parity gates and isolate allocation/copy clocks before any claim.
Whole-prover GPU and independently verified fixed-context resident1/2/4/8
workloads stay first. Next local: differential direct signed-byte padding
from Array.bytes versus i8s()+pad_matrix (all256 byte values, interleaved
query-head slots, strides, malformed lengths and zero-pad controls). Account
for whether removing58720256B decode scratch changes the dominant full-loader
peak; do not repeat cycle0027's completed public-digest streaming/cache study.


Baseline and eliminated work: native Array objects keep eleven raw source
buffers until loader return; aw/fw hold nine padded i8 vectors. Borrowed
constructors check_words, then copy twelve vectors into the block. The owned
proposal calls the SAME check_words before moving those vectors and retains
the typed[i16;256] table and original constructor order. No IO, table generator,
hash, support scan, CS recheck, witness, mask or proof work is eliminated.
Added costs are API/lifetime integration and native validation; native timing
is absent. Even deleting ALL load task time at zero cost gives only
1.103104x
on this CPU diagnostic. The copy subset is smaller; overlap lowers the bound.
No high-end GPU ceiling is known.

Falsification: any native byte, first refusal or gate mismatch; allocations
not actually avoided; actual peak regression; or overhead >= exclusive saved
copy time. Python consumed-wrapper checks model transfer, not Rust borrow
safety. Synthetic SHA256 framing is not native BLAKE3/transcript equivalence.

Negative findings retained: one KV group has tail-only head padding, so a
prefix map is valid there; the first test overclassified it, saved exit1.
An audit caught an accounting reservation accumulating between worker rows;
source, failed ledger and stderr saved before fixing. The final audit passes.
Key-only public owners, registry-only lease accounting, cyclic partial-LRU,
and repeated public digest claims remain rejected/demoted from prior cycles.

LIVE search rotation: lookup/softmax and quantization with memory ownership.
Seven records in source-records.json retain exact URLs/access dates/primary
date evidence/license qualifications. Expander's older clone/batch-scratch
history is newly assessed; exact PR/commit/source fetches were Cache miss or
InternalError, so inspected_commit_id stays null and short IDs are explicitly
uninspected. Plonky3 release views conflict with prior retrieval; do not infer
latest release/year. Known zkLLM, Bits Under ZK-LLM, zkLLMPoT and primitive
comparison refreshed; author evidence unexecuted. Next rotation GPU
NTT/commitments and sumcheck/GKR, retaining lookup/softmax,memory,batching,
quantization and proof composition in the queue.

Privacy/fidelity: D33 is trained TinyLlama T32 pg_rot1 CPU R7 only; R8/new
sources require re-pin and do not inherit8B/GPU coverage. D30's counted
dictionary is unbuilt; D32 thresholds stay binding. No P3 weight-cache or
mask/opening reuse is authorized.

Only research files changed. No runtime/production/Git/receipt/calibration/
safety/instruction/reviewer changes, downloads executed, installs, GPU jobs
or external messages. Reports alone do not establish delivery.
Checkpoint 2026-10-19T18:31:18.084399+00:00.

Final review refinement: the Python model now transfers exactly twelve vector buffers and explicitly copies the activation list, retaining the native inline [i16; 256] copy. The earlier all-list transfer model is saved under before-inline-act-model-refinement/. Layout bytes and payload counts are unchanged. No native ownership or proof equivalence is claimed.
Final main/audit: 7074/1871 assertions; 12.308901/0.152414 s; 30416/26828 KiB peaks. Checkpoint 2026-10-19T18:32:48.128067+00:00.


## Cycle0087 — 2026-10-19: direct signed-byte padding

Run `20261019T191854Z-6444ea2f` —2026-10-19 UTC.

**No speed improvement measured.** Direct signed-byte padding matches
432 synthetic matrices across48 layouts and three exhaustive0..255 byte
sweeps. Main5602 assertions,1728 malformed/type/shape controls and
942 wrong-output controls pass; independent audit2725 assertions
and864 output-corruption controls pass.
Main/audit clocks0.297901/0.086999s,peaks
25924/19196KiB,one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps. These are synthetic
validation clocks,not native padding benchmarks.18 pins unchanged;14 match
frozen R8. Review-only58-line Rust patch is UNBUILT/UNAPPLIED.

Counted work removed: nine complete signed-byte decode vectors totaling
218112000B/load (208.0078125MiB); largest58720256B (56MiB) at8B. Raw arrays,
padded public weights,table checks,hashes,constructors and all proof work stay.
The proposed safe cast loop replaces the identity branch's copy_from_slice;
compiler vectorization and any time benefit are unmeasured. At8B32 query heads
fill32 slots,so head maps are identity; this branch needs native measurement.

Decisive negative: every full-sealing public-payload envelope in the prior
one/16-worker,pins0/4,borrowed/owned ledger has **0B** reduction. The padding
envelope falls520672256->461952000B,but later record hashing dominates.
Four pins+current+next remain2.016689GiB borrowed and1.789997GiB with prior
owned constructors at16 hash workers [MODEL]. These are enumerated public
payload bounds,not actual RSS/VRAM,complete memory or hardware fit. Private
witness/proof/device,allocator/page-cache costs and extra live evicted leases
remain excluded. Do not subtract56MiB from the measured owner peak.

Carried owner R8 diagnostic: trained8B T128,32 blocks,one16-thread CPU
pass,GPU off,n=1. Total478.737s gives0.267370 positions/s diagnostic;
prove_run393.785s includes witness hand-over98.348s,which includes17.595s
block loads. Sealing wall84.824s contains overlapping load/witness tasks
27.151/80.897s. These clocks must not be added. Receipt922711264B.
Fresh verification42.709s plus initial public load13.681s; recheck34.395s
plus10.739s load. Fresh guard wall165.982s includes controls. Startup
fraction,isolated serialization and steady slope remain unmeasured.
Researcher did not reverify this artifact and gives no new target credit.

Even zero-cost deletion of ALL27.151+17.595s load tasks leaves433.991s,
an optimistic1.103104x /0.294937 positions/s CPU diagnostic ceiling. This is
not this candidate's saving; overlap and the smaller selected cost reduce it.
No high-end GPU end-to-end ceiling can be inferred.

Validation scope: independent per-destination signed decode reference and
separate persisted-artifact reconstruction cover all nine matrices,identity
and grouped query-head maps,true input stride,padded output stride and zeros.
Unsigned output is checked as signed values: byte hashes alone cannot detect
that error. Length/type/shape checks run in a synthetic prevalidation wrapper;
they do not execute native refusal messages or IO races. SHA256 artifact
digests are not native BLAKE3/receipt equivalence. Proposed diff preserves
native admission,table generators,constructor support checks and H-1.

Falsify if native bytes/records/first refusal/receipt change,any decode Vec
survives,the cast loop costs at least the saved copy work,or actual memory
regresses. Exact placement is reproduced; a proving improvement is not.

Ranked queue (full costs/prerequisites/privacy/exactness in hypotheses.json):
1.Owner whole-prover GPU + verified resident1/2/4/8 workloads.
2.Prior checked public constructor transfer,native gates/clock pending.
3.NEW public raw-array release before record hashing,next local test.
4.Tested direct-byte padding,demoted for unchanged full-loader envelope.
5.Guarded public owner with freshness and complete live lease accounting.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device none. No proof context/workload ran. Steady-state and total-workload
proved rates,startup fraction,and new witness/proof/serialization/verification
clocks are all unmeasured. Synthetic48 layouts/432 matrices/3 byte sweeps are
validation cases,not proof passes. No long-context prefill,resident proof
series or decode ran. Larger workloads remain allowed; longer context can
increase attention work quadratically. Complete private8B / >=50 proved
positions/s on one RTX5090 or another named high-end GPU remains unchanged
and unachieved. No masks,private commitments or openings were reused.

Owner: review the unbuilt one-file patch,then under shared locks run
native byte/first-refusal/record/receipt gates and exclusive decode+padding
clocks before promotion. Adjacent edits overlap the prior ownership patch's
loader context and need rebase; neither patch is integrated here.

Next local: differential public raw-array last-use/release before
LayerRecord::of_block,including full/reload paths,malformed inputs and exact
record/metadata bytes. Preserve all source freshness,CS and H-1 checks;
recompute every phase maximum rather than subtract218114560B from the peak.
Do not repeat cycle0027 public-digest streaming/cache or prior key-only/LRU/
registry-only lease shortcuts. Owner whole-prover GPU and independently
verified fixed-context resident1/2/4/8 complete workloads remain first.

Seven LIVE primary records appended478->485: newly assessed FluxZK,
older MoMA and recent Impeller; refreshed Chimera's October16 revision and
ICICLE v4 release. Source records distinguish future venue dates from
publication,conflicting FluxZK activity views,and actual SPIRAL license
inspection from unavailable component licenses. Only ICICLE's Cargo-version
bump commit was inspected; it validates no kernel. Several exact history,
license and code requests failed with Cache miss/InternalError; no bypass.
The inaccessible2026/2494 primary lead remains unverified. No author
performance reproduced. Rotation next lookup/softmax and proof composition;
retain memory,batching,quantization/arithmetic and GPU work.

D33 covers trained TinyLlama T32 pg_rot1 CPU R7 only; R8/new files need the
gate re-pin,and8B/GPU do not inherit that acceptance. D30 remains an unbuilt
construction; D27 soundness and D32 fidelity thresholds remain binding.
P1 hides inputs,outputs and intermediates; P3 weight privacy is not weakened.

Only research files written; no runtime,production,Git,receipt,calibration,
safety,instruction or reviewer files changed. No native builds,GPU jobs,
dependency installs,downloaded code execution,external writes/messages,
purchases or escalation. Saved reports do not establish message delivery.
Checkpoint 2026-10-19T19:27:43.233124+00:00.

Final consistency/provenance gate PASS: 230 checks,18 unchanged pins/14 R8 manifest matches,four patch hunks applied in memory only. No Rust compile/proof. Initial passed validator source/result preserved before making command-history validation repeatable. Final checkpoint 2026-10-19T19:30:10.331438+00:00.


## Cycle0088 — 2026-10-19: public raw-array last use

Run `20261019T201854Z-ec298e23` —2026-10-19 UTC.

**No speed improvement measured.** Explicit public raw-array release after
construction matches78 accepted synthetic full/reload paths across48 fixtures;
18 denied RoPE-mismatch paths preserve their modeled refusal. Main
10453 assertions and6720 mutation-path controls pass. Independent audit
10110 assertions,6720 first-error checks and1404 output/metadata corruption
controls pass. Main/audit clocks7.809640/0.273545s,
peaks40304/34256KiB,one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps. These are validation
clocks,not native loader benchmarks.18 pins unchanged;14 match frozen R8.
The21-line standalone Rust diff is **UNBUILT/UNAPPLIED**.

[MODEL] At8B T128,the11 raw source payloads total218114560B
(208.010254MiB). Moving their release before record hashing reduces the
borrowed-constructor sealing envelope772177408->705199616B with1 hash
worker (63.875MiB),or948346368->730231808B with16 workers (208.010254MiB).
The latter current+next+four distinct pinned blocks envelope falls
2.016689->1.813554GiB. These are conservative enumerated public payloads,
not actual RSS/VRAM,complete memory or proof speed. With prior checked-move
and direct-byte proposals,the16-worker/four-pin envelope becomes1.586862GiB;
all three patches remain unintegrated. Native decode+move instead reaches
1.618387GiB because padding takes over. Recompute phase maxima; savings
are not additive. Private witness/proof/device,allocator/page cache,JSON,
thread stacks and extra evicted live leases are excluded.

Decisive negative: every reload envelope has0B peak reduction. It skips record
hashing and the unchanged constructor/padding phase wins. Merely copying
SHA fields releases nothing;78 controls detect this.78 early-drop controls
refuse use-after-release;78 changed-source reload comparisons differ from
the sealed digest surrogate,so keeping the caller's real digest gate matters.

Carried owner R8 diagnostic: trained8B T128,32 blocks,one16-thread CPU
pass,GPU off,n=1. Total478.737s =>0.267370 positions/s diagnostic;
prove_run393.785s includes witness hand-over98.348s,including17.595s
block-load tasks. Sealing wall84.824s contains overlapping load/witness
tasks27.151/80.897s. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial public load13.681s; recheck34.395s plus
10.739s load. Fresh guard wall165.982s includes controls. Startup fraction,
isolated serialization and steady slope remain unmeasured. Researcher did
not reverify the receipt; no new target credit.

Baseline/eliminated work/added costs: R8 retains all11 raw Array values
through record hashing,after public constructors copied their data. The
proposal moves their destruction to immediately after BlockPublic::new and
captures the two Copy SHA fields before the move. It removes no IO,hash,
table generator,support check,constructor,witness or proof operation. The
same frees occur earlier; tuple movement and allocator/critical-path effects
are unmeasured. All-load zero-cost deletion leaves433.991s,at most1.103104x
and0.294937 positions/s on the carried CPU diagnostic. This is an overbroad
bound,not this candidate's saving,and gives no high-end GPU rate.

Independent destination-indexing reconstructs signed padded words,all public
word/table SHA256s,source-tensor sorting,manifest/member/per-layer metadata,
and absent/equal/opted-in RoPE branches. Source mutations cover dtype,shape,
exact lengths,SHA,generator failures,metadata and paired first errors.
The model does not execute Rust IO concurrency,constructor checks,refusal
strings,CS/H-1 or proofs. Block SHA256 and JSON framing are explicit
surrogates,not native BLAKE3/record wire/receipt equivalence.

Falsify if native bytes/records/first refusal/receipt change,a live borrow
survives the drop,the allocation is already released,another phase erases
the useful actual peak decrease,or moved frees regress elapsed time.

Ranked queue (costs,prerequisites,exactness/privacy/falsifiers in hypotheses.json):
1.Owner whole-prover GPU and verified fixed-context resident1/2/4/8.
2.Prior checked public constructor transfer,native gates/clocks pending.
3.Tested public raw postconstructor release,sealing capacity only.
4.NEW split matrix9 last-use before constructors,next local test.
5.Direct-byte padding alone,demoted for0B full-loader peak change.
6.Guarded public owner with freshness and complete live lease accounting.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device none; no proof context or workload ran. Steady-state and total-workload
proved rates, startup fraction, and new witness/proof/serialization/verification
clocks are unmeasured. Synthetic cases are validation paths, not proof passes.
No long-context prefill, resident proof series or decode ran. Longer workloads
remain allowed; dense attention can grow quadratically with context.
The complete private8B / >=50 proved positions/s target on one RTX5090 or a
named high-end GPU remains unchanged and unachieved. No masks, private
commitments or openings were reused.

Owner: review the one-method diff,then under shared build/heavy locks
run native full/reload malformed/first-refusal/record/receipt gates and
exclusive allocation+HWM clocks. No integration or merge occurred here.
Whole-prover GPU and independently verified fixed-context resident1/2/4/8
workloads remain first. Next local: split last-use of9 raw matrices after
aw/fw padding and before constructors,retaining exp/act through their own
reads; recompute full/reload timelines and preserve all source freshness,
CS and H-1 checks. This addresses the reload/constructor negative.
Do not repeat cycle0027's public digest streaming/cache or key-only/LRU/
registry-only lease shortcuts.

Eight LIVE primary records appended485->493. Newly assessed older
Jolt PR881 supplies a streaming/materialization lead (merged2025-08-19;
exact code/merge fetches failed,so no inspected commit). Atlas full text
makes extra-pass/staging costs explicit; its actual custom ICME license,
served history and empty release page were checked. New Zippel lead has
verified October16 metadata/abstract on the official index; landing/PDF
failed. Composition/sublinear-space conditions and October11 zkLLMPoT
covered-operator scope were refreshed. Rust's official drop-scope contract
supports the release boundary,but proves no allocator/RSS benefit.
No foreign code executed or author performance reproduced. A guessed
repository404,exact commit InternalErrors,and blocked ePrint pages are
retained in search-log.md. Next rotation memory traffic and batching;
retain GPU NTT/commitments,sumcheck/GKR,lookup/softmax,quantization/arithmetic
and proof composition. Licensing/date/coverage qualifications remain binding.

D33 remains trained TinyLlama T32 pg_rot1 CPU R7 only; R8/new files
need gate re-pin,and8B/GPU do not inherit that acceptance. D30 is an unbuilt
construction; D27 soundness and D32 fidelity thresholds remain binding.
Public buffer release authorizes no P3 weight/private opening cache.
Only research written;runtime/production/Git/receipts/calibration/safety/
instructions/reviewer files untouched. No installs,builds,GPU jobs,external
writes/messages,purchases or escalation. Saved reports do not imply delivery.

[Experiment](experiments/public-raw-last-use-20261019/README.md),
[handoff](handoffs/20261019-public-raw-last-use.md).
Checkpoint 2026-10-19T20:28:11.334785+00:00.

Final consistency/provenance gate PASS: 261 checks,18 unchanged source/evidence pins,14 frozen R8 manifest matches;two patch hunks applied in memory only. No native compile/proof. Final checkpoint 2026-10-19T20:28:11.449367+00:00.


## Cycle0089 — split public matrix release

Run `20261019T211854Z-fff84a98` —2026-10-19 UTC.

**No speed improvement measured.** Split public raw-matrix release matches 78 accepted synthetic full/reload paths over48 fixtures;18 denied RoPE paths preserve their modeled refusal. 6720 mutation-path controls pass. Main 10625 assertions; independent audit 10238 assertions,6720 first-error checks and1404 corruption controls. Early matrix/table release and digest-copy-only controls each catch78 bad paths;78 changed-source reload comparisons still differ from the sealed digest surrogate. Seed2026101989. Main/audit 5.322207/0.195933s, peaks 40556/34492KiB, one nice19 CPU0, Core Ultra9 185H, Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps. These clocks measure synthetic validation, not loader/proving speed.

[MODEL] At8B T128, nine raw matrices total218112000B. Releasing them after aw/fw padding lowers the borrowed-constructor reload payload envelope705199616->638116864B, saving67082752B (63.975098MiB). With current+next+four distinct pinned public blocks,1.790241->1.727766GiB. With16 hash workers,sealing948346368->730231808B (208.010254MiB), **0B incremental improvement beyond prior postconstructor release**. Split release adds0B peak saving when combined with prior checked moves, for both sealing/reload; unchanged padding or record hashing wins. Direct-byte+move+release sealing remains1.586862GiB. These are enumerated public payload envelopes, not actual RSS/VRAM, full model memory or elapsed savings; exclude allocator/page cache,JSON,thread stacks,private witness/proof/device state and extra evicted live leases.

Correction: Rust statement scopes allow all four `fw` decode temporaries to coexist:176164864B (168.003906MiB), rather than58720256B max-single. This adds117444608B (112.003906MiB) to the native-decode padding phase in the old model. The prior cycle's native-decode+move+release1.618387GiB envelope is superseded by1.727766GiB. Direct-byte variants and baseline sealing/reload maxima above are unaffected. Initial results before this correction are retained under before-temporary-scope-correction/. Semantic lifetime is source/reference-derived; native compiler/allocator behavior has not been measured.

Seam: frozen R8 `TrainedExport::load_layer_mode` in `hashline/src/private_block/trained_block.rs`,after aw/fw padding and after BlockPublic::new. The standalone review-only-split-release.patch is UNBUILT/UNAPPLIED; production untouched. Capture two Copy SHA fields before moving raw9; retain exp/act through their constructor reads. No IO/hash/padding/support/generator/witness/proof operation removed. Added costs are lifetime integration and earlier frees; actual critical-path impact unknown. Even deleting ALL load task time gives only the overbroad1.103104x CPU diagnostic bound (433.991s,0.294937 positions/s),not this candidate's saving or a high-end GPU estimate.

Falsify on native byte/metadata/record/first-refusal/receipt mismatch,live reads beyond drops,already-released allocations,no useful actual peak reduction,or moved frees regressing enclosing time. The independent Python oracle reconstructs destination-indexed signed words,SHA256 word/table hashes,metadata and first errors. Block SHA256 and JSON framing are explicit surrogates,not native BLAKE3/wire/proof equivalence. IO concurrency,constructor refusals,CS/H-1 and proofs are not executed here.

Carried owner R8 diagnostic only: trained8B T128,32 blocks,one16-thread CPU pass,GPU off,n=1,total478.737s =>0.267370 positions/s. Prove_run393.785s contains witness hand-over98.348s,including17.595s block-load tasks. Sealing wall84.824s contains overlapping load/witness tasks27.151/80.897s; do not add nested/overlapped clocks. Receipt922711264B. Fresh verify42.709s plus initial public load13.681s; recheck34.395s plus10.739s load; guard165.982s includes controls. Startup fraction,steady-state slope and isolated serialization remain unmeasured. Researcher did not independently reverify this receipt; no new target credit.

New independently verified full-stack proofs/passes/positions: **0/0/0**; device none,context none. Steady-state and total-workload proved rates,startup fraction,new witness/proof/serialization/verification clocks: unmeasured. Synthetic cases are not proof passes. No long-context prefill,resident proof series or decode ran. Larger workloads remain allowed; attention may grow quadratically with context. Complete private8B >=50 proved positions/s on one RTX5090 or a named high-end GPU remains unchanged and unachieved. No private masks,commitments or openings reused.

Ranked hypotheses: owner whole-prover GPU/resident series;prior checked public constructor transfer;tested split raw release;NEW per-call decode temporary scopes;prior postconstructor release;direct-byte padding;guarded public owners. Full obligations in hypotheses.json.

Owner: review the unbuilt one-method diff,then use shared build/heavy locks for native full/reload malformed/paired-first-refusal/record/receipt/CS/H-1 gates and exclusive allocation/HWM/enclosing clocks. Whole-prover GPU plus independently verified fixed-context resident1/2/4/8 workloads remain first. Next local experiment: split each aw/fw padding call into its own let statement to bound decode temporary overlap,with an event-lifetime reference and byte/refusal controls; recompute full-loader maxima and interactions. No repeated key-only/LRU/registry-only caching or cycle0027 digest-cache study.

Six LIVE primary records appended493->499: newly assessed older Streaming Zero-Knowledge Proofs (v1 Jan2023,v2 May2024; separate verifier/setup model),Efficient Sumcheck ownership/streaming history and failed license/release/commit fetches,Chimera Oct16 residency revision,NTT/sumcheck locality,HBM-PIM hardware scope,and Rust statement temporary scopes. No external performance reproduced or foreign code executed. See source-records.json/search-log.md for exact URLs,verified dates,license limits and429/Cache-miss blockers.

D33 remains trained TinyLlama T32 pg_rot1 CPU R7 only; R8/8B/GPU/new-file changes need their own gates/re-pin. D27 soundness,D32 fidelity and D30's unbuilt construction status remain binding. Public last-use changes authorize no P3 cache. Only research written;runtime/production/Git/receipts/calibration/safety/instructions/reviewer files untouched. No installs,builds,GPU jobs,external writes/messages,purchases or escalation. Saved reports do not establish message delivery.

Checkpoint 2026-10-19T21:33:01.766544+00:00.

Final consistency/provenance gate PASS: 319 checks,18 unchanged source/evidence pins,14 frozen R8 manifest matches,two patch hunks replayed in memory only. Direction documents unchanged during cycle. No native compile/proof. Final checkpoint 2026-10-19T21:35:12.285010+00:00.


## Cycle0090 — separate public decode statement scopes

Run `20261019T221854Z-a20c7a9f` — 2026-10-19 UTC.

**No speed improvement measured.** A small authored Rust1.90/edition2021
Drop probe confirms grouped borrowed argument temporaries coexist until the
statement ends. Owning each padded result in a separate statement reduces
tracked decode payload1216->400B,with identical outputs. The reference-binding
negative extends lifetimes and reaches1872B. These are observable wrapper
lifetimes,not original Vec allocator/RSS or production-loader measurements.
Compile/probe process walls0.744154/0.002000s; one CPU affinity,nice19,
one codegen unit,no dependencies. Compiler helper-thread count was not observed.

The deterministic Python schedule experiment passes48 inherited synthetic
fixtures and compares all9 padded vectors with78 prior accepted full/reload
paths. 480 new controls cover premature release and every injected pad-error
position; these are modeled errors,not native constructor/CS refusals.
Independent destination-indexed signed-byte oracle passes2411 checks,
432 output corruptions and432 first-error expectations. Main 898
checks. Main/audit wall0.607961/0.141210s,
peaks39836/35980KiB,one Python thread,nice19 CPU0,
CoreUltra9 185H,Python3.10.12,WSL2. Every launched experiment leaf has59s
CPU/wall and512MiB AS limits. Fixtures inherit seed2026101989; schedule/probe
use no RNG. No target-size arrays allocated.

[MODEL] At8B T128(d4096,f14336,dp4096,fp16384,kv1024,hd128),per-call
scopes reduce the conservative padding payload envelope638116864->520672256B:
117444608B(**112.003906MiB**). This removes overlapping lifetimes,not any of
the218112000 decoded bytes,9 allocations,padding copies or proof operations.
Other phases determine the actual modeled loader peak:

| Composition,16 hash workers | Sealing peak saving | Reload peak saving |
|---|---:|---:|
| Original borrowed constructors | 0B | 0B |
| Prior split raw release | 0B | 117444608B |
| Prior checked moves + postconstructor release | 117444608B | 117444608B |

With checked moves+post release,current+next+four distinct pinned public
blocks change1.727765560->1.618386745GiB. All compositions are unintegrated
proposals. Across48 full/reload/constructor/hash-worker/pin/release rows,
20 have0B and28 positive saving. Background includes a conservative two
RoPE-pair allowance. Allocator/capacity slack,page cache,JSON,thread stacks,
private witness,proof,serialization,GPU buffers and extra evicted live leases
are excluded. This is no RSS/VRAM,complete-model fit or elapsed claim.
Direct-byte+move+release remains the prior lower1.586862GiB model;
statement scopes do not remove decode allocations. Savings are not additive.

Baseline/eliminated work/added costs: frozen R8 aw/fw arrays contain5/4
borrowed i8s calls. The review-only one-method diff gives each pad result its
own let binding and moves results into the same arrays,in the same order.
All surrounding validation,table/record construction,source freshness,reload
digest gate,CS and H-1 remain unchanged by source comparison. Same decoding,
copies and destructors,earlier frees; native optimizer and allocator costs
remain unknown. Even deleting ALL load task time from the carried CPU
diagnostic leaves433.991s,at most1.103104x and0.294937 positions/s; this is
an overbroad bound,not the candidate's saving or a high-end GPU prediction.
Falsify on original Vec allocation elision,changed native bytes/first refusal/
record/receipt,a live read after drop,other phases erasing composed capacity
savings,or enclosing elapsed regression. The local Drop wrapper makes its
own lifetime observable and does not settle original Vec allocation behavior.

Seam: `TrainedExport::load_layer_mode`,frozen native R8
`hashline/src/private_block/trained_block.rs` aw/fw initializers (~1037).
Actual read-only tree is `ops/zkp-mvp/trained-1b-review-r8/`;18 source/evidence
pins match copied inputs,14 marked matches to the frozen R8 manifest.
`review-only-statement-scopes.patch` is **UNBUILT/UNAPPLIED** for the production
loader. Only the standalone authored probe was compiled. No merge/integration.
Owner must review and use shared build/heavy locks for native full/reload
malformed/paired-first-refusal/record/receipt/CS/H-1 gates,and exclusive
allocation/HWM/enclosing clocks,alone and composed with ownership/release.

Carried owner R8 diagnostic only:trained8B T128,32 blocks,one16-thread CPU
pass,GPU off,n=1,total478.737s =>0.267370 positions/s diagnostic.
Prove_run393.785s contains witness98.348s,including17.595s block-load tasks.
Sealing wall84.824s contains overlapping load/witness27.151/80.897s.
Do not add these nested/overlapping clocks or call sealing pure startup.
Commit121.32s(31.0% of summed391.9s block walls) and witness dominate loader
micro-work. Receipt922711264B;fresh verify42.709s plus13.681s initial load,
recheck34.395s plus10.739s load;guard165.982s includes controls.
Researcher did not independently reverify this receipt. Startup fraction,
steady slope and isolated serialization remain unmeasured.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device/context none. New witness/proof/serialization/verification clocks,
steady-state and total-workload proved rates,startup fraction: unmeasured.
Synthetic fixtures are not proof passes. No long-context prefill,resident
proof series or decode ran. Larger workloads remain allowed;dense attention
can grow quadratically with context. Complete private8B >=50 proved
positions/s on one RTX5090 or a named high-end GPU remains unachieved.
No masks,private commitments or openings reused;no weaker privacy authorized.

Ranked queue in hypotheses.json:1 owner whole-prover GPU and independently
verified fixed-context resident1/2/4/8;2 checked public constructor transfer;
3 tested statement scopes;4 split raw release;5 postconstructor release;
6 direct-byte padding;7 guarded public owner;8 NEW original-Vec allocation
probe. Costs,prerequisites,exactness,privacy/soundness and falsifiers retained.
Next local: a bounded original Vec/global-allocator probe with preallocated
logs and scalar pad analogue; compare counted live allocations to the scope
prediction without a custom Drop wrapper. Native Rayon loader measurement
and complete-proof resident sweeps remain owner work.

Eight LIVE primary records appended499->507. Newly assessed older Rust
2021 eager-drop discussion and SP1 rolled-GKR issue55 reinforce explicit
lifetime/cross-phase accounting;the latter corrects its own diagnosis and
later records composed-chain OOM despite standalone fit. Recent HERMES
(Oct18 received,Oct19 approved) proves no public ZKP relation;AG skip
(Oct15) uses binary fields and is not a Goldilocks drop-in. Chimera's Oct16
revision retains whole-prover residency priority;ICICLE old v4 release,
actual MIT root terms and version-only commit were inspected,without
assuming backend licensing. Efficient-sumcheck ownership/order history
refreshed. Exact dates,URLs,commit scope and access blockers are in
source-records.json/search-log.md. No author performance reproduced or
foreign code executed. Next search rotation: GPU commitments/NTT and
sumcheck/GKR;retain lookup/softmax,memory,batching,quantization/arithmetic,
proof composition. Avoid paper-list-only cycles.

D33 remains trained TinyLlama T32 pg_rot1 CPU R7 only;R8/8B/GPU/new-file
changes need review/re-pin. D27 whole-run soundness,D32 fidelity threshold
and D30 unbuilt construction remain binding. Public lifetime proposals
authorize no P3/private-opening cache. Only research written;runtime/,
production,Git,receipts,calibration,safety,instructions and reviewer files
untouched. No production build,GPU job,installation,downloaded code
execution,external write/message,purchase or escalation. Saved reports do
not establish message delivery. Checkpoint 2026-10-19T22:26:11.629637+00:00.

Final provenance/consistency gate PASS: 229 checks,18 unchanged source/evidence pins,14 frozen-R8 marked matches,one patch hunk replayed in memory only. Direction documents unchanged during cycle. No native production compile/proof. Final checkpoint 2026-10-19T22:28:07.326234+00:00.


## Cycle0091 — original Vec allocation-scope evidence

Run `20261019T231854Z-28e6b36b` — cycle0091 — 2026-10-19 UTC.

**No speed improvement measured.** This cycle closes one local evidence gap:
the previous statement-scope finding also holds for observed original Vec
allocations in a scalar analogue, without a custom decoded Drop wrapper.
It does not establish production/Rayon behavior or an elapsed improvement.

Rust1.90.0,edition2021,no dependencies,optimization levels0 and3,one codegen
unit. Eight synthetic shapes (identity/scattered head slots,odd FFN widths,
padding and both inner-map branches),five variants each,80 observed regions.
Original `Array::i8s() -> Vec<i8>` body is copied exactly from pinned R8;
the destination-row pad analogue replaces Rayon iteration with serial rows.
The wrapper forwards allocations to System and records pointer/size/phase
events into a fixed32768B atomic log. Raw inputs and spec maps are prepared
outside regions;outputs/logs are serialized after tracking stops. No
black_box,custom decoded Drop,per-region timing or target-size allocation.
The log itself does not heap-allocate. Compiler elision/merging is permitted
by Rust;these results describe these binaries only,not a language guarantee.

Largest proxy:qh32,kvh8,head_dim4,d128,f448,dp128,fp512,seed2026101991.
This reduces target widths by32;it is NOT a128-token proof or8B allocation.

| Variant | Peak live requested B | Peak decode B | Allocations | Total requested B |
|---|---:|---:|---:|---:|
| Grouped aw/fw statements |419200|172160|36|482848|
| Separate result statements |304384|57344|36|482848|
| Reference-binding negative |460288|213248|36|482848|
| Direct-byte control |247040|0|27|269600|
| Separate results plus clone negative |475648|57344|45|720672|

Opt0 and opt3 match all rows and all output bytes. Local scope saving114816B;
neither allocation count nor aggregate volume changes. All8 fixtures show a
strictly lower region peak. Retained output237824B in the largest proxy is
unchanged. Nine decode allocations remain;the direct-byte control removes
them but still carries the previous unmeasured cast-loop/native cost risks.
The reference-binding and extra-copy variants are value-equivalent and are
correctly rejected when presented as the intended scope implementation.

Independent audit uses a destination-indexed inverse-head-map byte oracle,
pointer-owned allocation replay and separate closed-form phase envelopes.
**1389 checks**,720 vector comparisons,720 one-byte corruptions,240 event
mutations (wrong size,missing allocation,missing free),32 reference/clone
masquerades pass. This is an authored single-agent differential audit,not an
external review. Original source/refusal/record/receipt gates remain owner work.
All byte fixtures and output SHA256s are retained. Audit0.856544s internal,
0.897139s process,18316KiB own HWM (runner child accounting18492KiB).
Compile opt0/3 processes0.568761/0.781899s,HWM136832/138848KiB;
probe processes0.026704/0.005584s,HWM8744/8556KiB. These process clocks include
synthetic output writing and instrumentation,not timed padding improvements.
One nice19 CPU0 affinity on CoreUltra9 185H/WSL2. Probe reports1 thread;
compiler helper-thread count unobserved,one CPU affinity/codegen unit.
Every leaf59s CPU/wall alarm and512MiB AS;no production/native build or GPU.

Baseline/eliminated work/added costs:grouped native5+4 argument temporaries
versus one owned padded result per statement. No decode,copy,pad,IO,hash,
constructor,witness or proof operation removed;only shorter requested-allocation
overlap,with the same frees earlier. Native optimizer,allocator bookkeeping,
threadpool and enclosing critical-path changes are unmeasured.

[MODEL,carried]8B T128 pad envelope638116864->520672256B (112.003906MiB).
Standalone original borrowed full/reload loader peak saving remains **0B**,
because constructor/hash phases dominate. With prior checked moves+post raw
release,current+next+four distinct pinned public blocks1.727765560->
1.618386745GiB. Direct-byte+move+release remains the prior lower1.586862GiB.
These are public payload models,not actual allocator/RSS/VRAM or complete
model fit. No additive peak savings;exclude page cache,allocator slack,JSON,
thread stacks,private witness/proof/serialization/device and extra live leases.
This cycle strengthens only the scalar allocation premise,not these full-loader
or target-size measurements. Falsify promotion on native bytes/first-refusal/
record/receipt/CS/H-1 divergence,already-elided native overlap,no lower actual
whole-loader peak,or enclosing elapsed regression.

Carried owner R8 diagnostic only:8B T128,32 blocks,one16-thread CPU pass,
GPU off,n=1,total478.737s=>0.267370 positions/s diagnostic. Prove_run393.785s
contains witness98.348s,including17.595s block-load tasks. Sealing84.824s
contains overlapping load/witness27.151/80.897s. Commit121.32s/31.0% of
summed391.9s block walls is a larger priority. Receipt922711264B;fresh
verification42.709s+13.681s initial load,recheck34.395s+10.739s load;
guard165.982s includes controls. Do not add nested/overlapping clocks or call
sealing pure startup. Researcher did not reverify this receipt. Even deleting
ALL load tasks leaves433.991s:at most1.103104x and0.294937 positions/s on that
CPU diagnostic,an overbroad bound for this candidate;no high-end GPU forecast.

New independently verified full-stack proofs/passes/positions **0/0/0**;
device/context none. New witness/proof/serialization/verification clocks,
steady-state and total-workload proved rates,startup fraction **unmeasured**.
No long-context prefill,resident complete-proof series or decode ran. Larger
workloads remain allowed;attention can grow quadratically with context.
Complete private8B >=50 proved positions/s on RTX5090 or another named
high-end GPU remains unchanged and unachieved. No private mask/commitment/
opening reuse or privacy weakening. D33 covers only the accepted TinyLlama
T32 pg_rot1 CPU R7 artifact;8B,R8,GPU and next-token stages need their own
scope/re-pin. D27 whole-run security,D32 fidelity and D30 unbuilt status stand.

Integration seam:TrainedExport::load_layer_mode aw/fw statements in frozen
R8 hashline/src/private_block/trained_block.rs (~1037). The prior
review-only-statement-scopes.patch is copied and remains UNBUILT/UNAPPLIED;
no new production diff. Native owner must review/rebase with checked
ownership/raw-release changes,then run full/reload malformed/paired-first-
refusal/record/receipt/CS/H-1 gates and exclusive allocation,HWM and enclosing
clocks under shared build/heavy locks. No merge here.

Queue:hypotheses.json retains prior negatives.1 owner whole-prover GPU and
verified fixed-context resident1/2/4/8;2 NEW device-pool live-capacity audit;
3 checked public constructor transfer;4 tested scopes;remaining raw releases,
direct bytes and public-owner guards are capacity candidates awaiting native
evidence. New pool question follows source facts:exact take plus best-fit
take_min already exist,64 cached buffers bound count rather than bytes,
and cumulative counters are not simultaneous live+idle capacity. Next local:
pin take/take_min/put and extract a public request trace;compare a bounded
event model to an independent live-capacity oracle under mixed-size/tail/
allocation-failure controls. Do not reimplement existing reuse,execute GPU
work,or infer time from hit counts. Owner actual-device clocks remain first.

LIVE sources and exact access/date/license/commit limits are in source-records
and search-log. Recent Chimera Oct16 retains whole-prover residency priority;
GPU NTT older sources distinguish L2 batches from whole memory traffic.
Newly assessed older Huerta2025 register-file/cache and software-dependency
scheduling is a possible future CUDA source-order lead,not a5090 speed claim;
the abstract and HTML differ on simulator error numbers,so none is imported.
No downloaded code executed or author performance reproduced. Current web
release/cache misses and unavailable PDF/license/history reads are recorded.
Rotation next:lookup/softmax and memory/batching;retain NTT/commitments,
sumcheck/GKR,quantization/arithmetic and composition in the queue.

Only research changed;runtime/,production,Git,receipts,calibration,safety,
instructions and reviewer files untouched. No installs,GPU jobs,external
writes/messages,purchases,privilege escalation or foreign code execution.
Saved reports do not establish user-message delivery. Checkpoint 2026-10-19T23:27:05.586443+00:00.

Freshness checkpoint 2026-10-19T23:29:44.252978+00:00: first final gate failed because owner MVP_STATUS
changed at23:25UTC. Updated text was read and preserved separately in
final-MVP_STATUS.md/direction-update.diff;initial startup snapshot remains.
Owner reports next-token-stage gate evidence,not a new privacy acceptance;
22-layer R8 re-pin pending. No new8B/GPU throughput evidence. Research result,
target and narrow D33 scope unchanged. Failed05-validate log retained;final
validator checks the reviewed new document pins. LIVE source ledger507->517
(10primary records);all inspected implementation commit IDs null because no
commit diff opened. No external author result reproduced.

Final checkpoint 2026-10-19T23:30:19.251633+00:00:provenance/consistency gate PASS,230 checks,
10 unchanged source/evidence pins,9 current direction pins (one owner status
update reviewed). Initial failed freshness gate retained;second failed gate
was an overly narrow report-wording assertion (handoff said "Limits:"),now
corrected. Neither failure was an experiment failure. Event/byte audit and
Rust opt0/3 observations remain passing. Static atomic log32768B;report size
corrected before closing. No native integration or new full-stack proof.


## Cycle0092 — public request pool retention, 2026-10-20

Run `20261020T001854Z-f39e44f4`. No proving speed improvement measured. Source-pinned capacity
model plus independent offline request/lifetime oracle,not Rust/CUDA execution.
Read current agenda,state,findings/source indexes,latest prior results and
project directions;startup pins saved. Early STATE checkpoint persisted.

Exact matching,smallest fitting take_min,64-entry cache,drain+synchronize and
reserve-hard retry already exist. Seven policy/gate/drain function hashes match
root,frozen R8 and GPU owner sources. R8 keyed commit body was separately
read:optional32-byte key upload has no RAW_ALLOC note. This tiny omission is
accounting scope,not a speed lever. Legacy zk.rs warns its historical-failure
comments are hypotheses;they are not newly reproduced measurements.

59 scenarios,4602 events,45703
independent request/interval/conservation checks,590
corruption controls;seed2026102092. Public chunked allocation formulas
include data,pads,powers,four scratch buffers,leaves and key. Fixtures include
ties,tail capacity,64-count limit,one-shot/cap/reuse-disable/raw behavior,
returned resident capacity,and explicit immediate/deferred-release brackets.
Only tiny Python records allocated. Final model0.191720s/
30832KiB;audit1.489127s/22856KiB;
one observed thread,CPU0,nice19,CoreUltra9 185H,WSL2,Python3.10.12.
Each leaf59s CPU/wall,512MiB AS;no compiler,dependencies or GPU.

NEW refined hypothesis:at a public shape boundary retain a MULTISET of next
exact/min requests rather than clearing all idle buffers. Baseline already
does reuse/drain/retry. Eliminates only irrelevant idle capacity and avoidable
scratch reacquisition. Added costs:searching <=64 candidates/request,release synchronization,
lost later-phase reuse,bookkeeping and first-touch. Synthetic mixed row
3033/3028/3031/3029,n16384,q64,nn65536,chunk128,four commit/drop iterations:
no drain peak1794484768B,8 fresh;full drain603304480B,20 fresh;selective
603304480B,8 fresh. All14 fixed-geometry pairs have identical peak across
full/no drains but fresh5->20. Negative finding:indiscriminate extra draining
can throw away useful reuse. This does not authorize removing existing drains.

The model uses actual source formulas but synthetic public dimensions and
constructed partial-commit order. Previous commits are dropped;openings,
other live commitments,twiddle/cache state,other phases,fragmentation and
concurrency are excluded. Event physical_bytes means symbolic owned capacity,
not VRAM. Device-time/fit gain is unknown. End-to-end ceiling has no numeric
estimate because allocation/sync/fallback exclusive share is unmeasured.
Falsify on absent avoidable idle,incorrect public horizon,stream/stale-value
or refusal/receipt divergence,or enclosing elapsed regression after overhead.

Carried owner R8 CPU diagnostic:8B T128,32blocks,one16-thread pass,GPUoff,
total478.737s=>0.267370positions/s;prove_run393.785s contains witness98.348s
and load17.595s;sealing84.824s overlaps witness80.897s/load27.151s. Commit
121.32s/31% summed block walls is a larger priority. Receipt922711264B;
fresh verify42.709s+13.681s load,recheck34.395s+10.739s load,guard165.982s
includes controls. Researcher did not reverify. Startup,steady slope and
isolated serialization unmeasured. Do not sum nested/overlapping clocks.

New independently verified full-stack proofs/passes/positions0/0/0;device/
context none. New witness/proof/serialization/verification clocks,steady/
total proved rates and startup fraction unmeasured. No long-context prefill,
resident complete-proof series or decode. Larger workloads allowed;attention
can grow quadratically. Complete private8B >=50/s RTX5090/high-endGPU
unchanged/unachieved. No mask/opening reuse or weakened privacy. D33 narrow
TinyLlamaT32 pg_rot1 CPU R7 scope and D27/D30/D32 obligations remain.

Ranked hypotheses in experiment/hypotheses.json:1 owner whole-prover GPU+
verified resident1/2/4/8;2 public-request pool retention/actual capacity census;
3 exact DD owner integration;4 prior public-loader ownership/scopes;5 NTT
output-order census. Actual native measurements outrank modeled memory wins.
Prototype patch location:capacity_model.py retain branch,no Rust patch or
integration. Handoff:handoffs/20261020-public-request-pool-retention.md.

LIVE seven primary records:CUDA guide,previously unassessed2021 allocator
blog,cuCascade reservations/release view,zkLLMPoT v2,SP1 October10 release
and its NTT/zerocheck PR diffs. Author results not reproduced. The inspected
full release commitb8387fa61e1361d90ee7de49f551863418ca0f08 is a CLI toolchain
tag change,not the GPU change. PR diff short IDs and full-SHA/license fetch
errors are explicit. No license inferred from a badge;source-records and
search-log retain dates/URLs/access blockers. No foreign code executed.

Next local:source-only census of all pooled/raw/cache allocations and current
trained/GPU caller/drain sites,especially raw key/twiddles and zerocheck/fold
scratch outside current counters. Build a public request-horizon coverage
table before proposing native retention. Do not repeat this synthetic schedule
as a benchmark or assume legacy drains cover every trained path. Owner owes
actual device telemetry/complete receipt gates and high-end GPU workload sweep.
Only research written;runtime/,production,Git,receipts,calibration,safety,
instructions/reviewer files untouched;no GPU/install/external write/message/
purchase/escalation. Saved reports imply no delivery. Checkpoint 2026-10-20T00:29:53.860450+00:00.

Final direction reading 2026-10-20T00:31:41.268533+00:00: D33 already includes the 00:10UTC token-tree re-pin note:10 gate records PASS, independent REVIEW4 and Victor acceptance still required. D34 (00:16UTC) prices token-stage input-dependent LogUp refusal as a counted distance term; it is an accounting rule,not privacy acceptance. No target or experiment scope changes.

## Cycle0093 — allocation coverage and host-backed staging,2026-10-20

Run `20261020T011854Z-224b9b69`.

**No proving speed improvement measured.** The tested staging reuse saves
**zero work when A/H are already device-resident**, which is the source path
after successful GPU commitments. A fallback-only capacity option is preserved.

144 synthetic fixtures,seed2026102093,n in1/2/3/4/6/8,
all four A/H residency combinations,both support flags,three seeds.
The independent destination-byte/event oracle passes **27301 checks**,
292 ordering/lifetime/alias/lexical controls and
1299 corrupted hash/capacity/completion/site records.
These are authored single-agent checks,not an external review or native proof.
36 all-resident cases allocate0 staging buffers before and after.

Largest synthetic fixture has256 entries/table: original host staging47656B
with23 allocations versus4144B with2; the+3u64 tail per buffer is deliberate.
H2D47104B,23 copy syncs+1 final explicit sync are unchanged by ordered reuse.
The conservative variant adds17 extra explicit syncs and is retained under
before-copy-order-refinement/. The unsafe no-order and aliased-pair controls
fail,as does use after release. These model hazards are not native failures.

[MODEL] At l=2^20,all-host source staging184->16MiB (168MiB less),
split/support tables368MiB unchanged. n20 is a cube dimension,not a token
context. This excludes other tables,eq scratch,live commitments,caches,
driver/module allocations,granularity and host/pinned memory. No model-size
or actual-device-fit claim. No inference of speed from allocated bytes.

Selected allocation API census independently agrees on298 sites:
R8 94 (52 raw/39 pooled requests/2 backing/1 host-pinned),
activeGPU113 (67/41/2/3),root91 (49/39/2/1). It includes probes/tests and
branches; it is not a runtime trace or complete CUDA-driver allocation count.
All source pins and exact line/function/arguments are in census.json.
The scanner's initial char-literal and array-signature bugs are fixed;
failed runs remain in commands/logs. No Rust parser/compiler was run.

10 direct drain/reservation call sites outside cuda.rs are indexed. Production
sites occur in legacy layer.rs/zk.rs; the private GPU test helper adds one
drain. No direct production call occurs in inspected private_block files.
This is a source census,not proof of whole-program reachability through macros.
The prior synthetic layer-drain schedule is therefore not an actual trained
private-stack trace. dev_pool_drain clears only idle POOL storage; it does not
clear monotonic twiddles,FZC_PUB,live commitments or raw scratch.

Twiddle growth retains old plus newly uploaded forward/inverse pairs until
assignment:16*((2^old-1)+(2^new-1)) symbolic bytes. FZC public-cache insertion
uploads before evicting,so a four-entry cache can transiently coexist with a
fifth table (80MiB for five equal2^20-entry Fp2 tables). These are partial
source-derived envelopes,not simultaneous full-proof peaks or new bugs.
New FZC raw allocations are outside commitment/opening RAW_ALLOC_SCOPE by
its documented design; counters were never claimed as whole-prover capacity.

The pinned local cudarc0.13.9 Cargo.lock checksum and .cargo_vcs_info
match release e12b2d96877d0bae7266c01df14f257e95bb0020. Its htod_sync_copy
allocates then calls htod_sync_copy_into; the latter uses the device stream
and synchronizes. Same-stream storage reuse can retain existing synchronization
counts. Native CudaDevice::new,mutex and source consumers were inspected.
The full release commit changes only the version; allocation semantics are
from the inspected package/tag. MIT/Apache texts pinned; no dependency executed.

[CARRIED owner diagnostic,not reverified here] CPU8B T128,32blocks,
one16-thread pass,GPUoff,total478.737s=0.267370 positions/s. prove_run393.785s
contains witness98.348s and block-load17.595s; sealing84.824s overlaps
load27.151/witness80.897s. Commit121.32s/~31% of summed block walls remains a
larger measured target. Receipt922711264B; fresh verify42.709s+13.681s initial
load,recheck34.395s+10.739s load;guard165.982s includes controls. Do not add
nested clocks or label sealing pure startup. Startup/steady/serialization
unknown. Today's MVP_STATUS also reports a newer next-token T128 CPU workload
at501.6/529.2s,~57s verification and~928MB receipt. Only documentation was read;
it is a different workload,not a new verified receipt in this cycle.

New independently verified complete proofs/passes/positions **0/0/0**;
GPU device/token context none; CPU-only synthetic experiment,0 proof passes.
New witness/proof/serialization/verification clocks, steady-state and
total-workload proved rates and startup fraction **unmeasured**. No long-context
prefill,resident complete-proof series or decode ran. Larger workloads remain
allowed; attention may grow quadratically. Complete private8B >=50 proved
tokens/s on RTX5090/another named high-end GPU remains unchanged and unachieved.
No mask/opening reuse or privacy weakening.

Final leaf clocks:census4.539115s/
21616KiB,model0.814387s/23024KiB,
audit0.523086s/28476KiB. One thread,nice19,CPU0,
Intel CoreUltra9 185H/WSL2/Python3.10.12. Every experiment
leaf59s CPU/wall alarm and512MiB AS; no native build/compiler/GPU/install.
These are validation-process clocks,not staging/proof speed measurements.

Seam: active GPU candidate hashline/src/gpu/cuda.rs,DevFzcRounds::new,
host-backed FzcSrc::Base/Pair None branches (~4351/4381 before patch).
review-only-host-stage-reuse.patch and candidate-cuda.rs are UNBUILT/UNAPPLIED.
Lazy local raw buffers replace only temporary uploads and drop after the
existing build synchronize. Reuse storage,never private values or randomness.
Fully resident sources allocate nothing on this branch. H2D volume,kernel
arguments,table order and st.bytes_h2d stay the same. Constructor allocation
failure order/site changes and Rust borrow/type correctness remain untested.

Owner must first establish nonresident sources in the intended workload.
If useful,review/rebase under existing lane ownership; shared build/heavy
locks govern all native builds/device work. Run host/mixed/resident differential
tables,shadow masked rounds+next challenge,full receipt bytes+independent
verify,refusal/failure/strict GPU,CS/H-1 and current privacy gates. Measure
actual allocation capacity/HWM and enclosing prove/witness/serialization/verify.
Do not build this just to claim a speed gain on an all-resident path. No merge.

LIVE sources searched: [Bits Under ZK-LLM](https://arxiv.org/abs/2609.36437),
[Efficient Sumcheck](https://github.com/compsec-epfl/efficient-sumcheck/blob/main/docs/design.md),
[gnark0.16.4](https://github.com/Consensys-Incorporated/gnark/releases/tag/v0.16.4)
and [batching PR1828](https://github.com/Consensys-Incorporated/gnark/pull/1828),
[cudarc0.13.9](https://github.com/chelsea0x3b/cudarc/blob/v0.13.9/src/driver/safe/alloc.rs),
[NVIDIA2015 stream ordering](https://developer.nvidia.com/blog/gpu-pro-tip-cuda-7-streams-simplify-concurrency/),
and [SumCATS](https://tanvirarafin.github.io/assets/pdf/DATE_2026.pdf).
DeepProve README/license/history also screened. Seven primary records appended
524->531. Exact access dates,verified/unknown publication/update dates,licenses,
full/resolved/uninspected commit distinctions and fetch failures are retained
in source-records.json and search-log.json. No author timings reproduced.
New gnark composition lead is lower priority: batching changes source-claim
binding/proof schedule and cannot be imported by matching degrees alone.

Next local experiment: derive the PRIVATE stage's actual commitment/opening
lifetimes from run.rs/protocol.rs (A,M,H,previous/current boundary and endpoints)
and combine symbolic requested capacity with raw/cache categories. Independently
check early-release and prior-boundary controls. Identify an actual peak phase;
do not replay the synthetic legacy four-commit schedule or infer device fit.
Highest-priority owner action remains whole-prover high-endGPU clocks and
independently verified fixed-context resident1/2/4/8 complete workloads.

D33 acceptance remains scoped to TinyLlama T32 pg_rot1 CPU R7; the token-tree
re-pin note and D34 refusal-distance accounting do not themselves accept R8,
GPU,8B or next-token privacy. D27 whole-run security,D30 unbuilt and D32
fidelity threshold stand. Production,Git,runtime/,receipts,calibration,safety,
instructions and reviewer files untouched. No external writes/messages,
purchases,escalation or downloaded-script execution. Saved reports imply no
message delivery. Current chat commentary/final are separate progress updates.

# Cycle0094 — private-stage commitment lifetimes

Run `20261020T021854Z-e084e681`, checkpoint 2026-10-20T02:30:25.208578+00:00. **No proving speed improvement found.**

The leading executable question was whether releasing private-stage owners
earlier could remove retained device capacity. The pinned source already drops
M, A and H immediately after their sole openings. An internal boundary is
opened in its consumer stage, after BOTH adjacent claims exist; moving it to
the producer stage fails the dependency oracle. Logical owners cannot be
released earlier under the unchanged schedule. Returning their `Pooled` buffers
to idle does not itself free device backing.

The baseline is source-derived, not a runtime trace. `prove_run_with` starts
with IN/OUT, commits current B before the core, retains previous B, runs the
core, opens the incoming owner, opens OUT only at the last stage, serializes
and sinks one segment, then hands current B to the next stage. The core commits
A, M, H, runs23 slots, and opens/drops M, A, H in that order. Source pins cover
native R8 and the separate active GPU candidate. They are different revisions:
R8's stage-specific shape differs from the older GPU door. Numeric geometry is
R8 f_e9,8B T32/64/128; this is no assertion that the active GPU tree supports
the newer complete workloads. M's50x4096 encoded field buffer is HOST memory,
not a device PCS owner (1.5625MiB encoded payload, other mask buffers excluded).

Independent authored single-agent checks pass: **182348 checks,
330 negative controls**,6 traces with1/2/3/4/8/32 BLOCKS,
36 public-capacity cases and36 synthetic byte fixtures; seed2026102094.
The reference derives owner/read/claim/open obligations from adjacent-block
relations, checks interval overlaps separately from the forward simulator,
and compares immutable host checksums with output cache eviction/restore.
It rejects premature/missing/double openings, incorrect boundary claim sides,
wrong stage/read/open order, missing sink, stale/short restore and pooled-free
misaccounting. These are accounting/193-byte toy storage tests, not native
polynomials, hiding encodings, masks, transcripts, receipt bytes or verification.

A new, separate question from SlackSwap/vDNN is whether OUT's device backing
can be evicted while retaining its logical owner until the last stage. It is
**demoted**, with no native patch recommended. At T128,32blocks,row2^14:

| Hypothetical store policy | Persistent-owner device subset | With OUT device backing omitted until final opening | Difference |
|---|---:|---:|---:|
| All resident |4568.750MiB|4545.625MiB|23.125MiB (0.506%)|
| All chunked |930.527344MiB|925.330078MiB|5.197266MiB (0.559%)|

Both are public requested-storage models, not actual VRAM, hardware fit or
full peaks. Mode/threshold and allocation success determine real mixed stores.
At this subset's maximum, live owners are A/H/M, previous B,current B,OUT;
M adds no GPU bytes. Host data/pads/salts/tree persist. The model omits
initial endpoint sealing transients, commit/open scratch, raw sumcheck tables,
idle/oversized pool backing, twiddles,FZC public cache, driver allocations,
proof vectors and other host memory. Thus the actual peak phase remains unknown.
Naive output-device drop moves23.125MiB to idle in resident mode, releasing
ZERO pooled backing; in chunked mode4.625MiB becomes idle and only0.572266MiB
raw pads/powers could be directly freed. Restoring needs the original hiding
material and exact encoding/copy work, not new random masks. Whole-workload
time benefit is unknown and can be negative. Initial seal or scratch peaks can
erase any global saving. The tested release-only hypothesis has zero opportunity
within the unchanged schedule; physical storage changes are different work.

Final model leaf: 0.086969s/27744KiB;
audit: 0.439804s/20572KiB. One nice19 CPU0 thread,
Intel CoreUltra9 185H,Python3.10.12/WSL2; leaf CPU/wall59s and512MiB AS caps.
These are harness validation clocks. Three initial extraction failures
(prover/verifier duplicate anchors,stage-shape spelling) and one later Python
indentation failure are retained in commands/logs; corrected runs pass.

Status correction discovered while reading owner public counts: D30/DD is no
longer wholly unbuilt. `r9_counts.json` and `r9-check.log` show counted T128
layouts and85 tests passing/1ignored/519filtered, including a generic DD proof
test. At8B T128,owner counts A/H3405/3790 ->3283/3634 (-3.86% words), smaller
than the earlier20.82% T512 anchor. This log was not rerun here. It establishes
neither independently reviewed DD full-stack throughput nor privacy acceptance.
The experiment retains the R8 baseline; no R9 production/source edit occurred.

New independently verified complete proofs/passes/positions **0/0/0**.
New token context/device none; CPU-only synthetic/accounting scope. New witness,
proof,serialization and verification clocks; steady-state and total-workload
proved rates; startup fraction all **unmeasured**. No long-context prefill,
resident-model complete-proof series or decode ran. Blocks in a trace are not
model passes. Carried owner CPU8B T128,32blocks,one16-thread pass,GPUoff:
total478.737s,0.267370positions/s; prove_run393.785s contains witness98.348s
and load17.595s; sealing84.824s overlaps witness/load. Receipt922711264B;
fresh verify42.709s+13.681s load, recheck34.395s+10.739s load. Not reverified.
Startup/steady/isolated serialization unknown; nested clocks must not be summed.
The newer CPU next-token501.6/529.2s owner workloads remain distinct.

LIVE sources searched: [SlackSwap](https://arxiv.org/abs/2610.13003),
[vDNN](https://research.nvidia.com/publication/2016-10_vdnn-virtualized-deep-neural-networks-scalable-memory-efficient-neural-network),
[ICICLE NTT/release](https://github.com/ingonyama-zk/icicle/releases/tag/v4.0.0),
[SP1 NTT diff](https://github.com/succinctlabs/sp1/pull/2990/files),
[zkLLMPoT](https://arxiv.org/abs/2610.08258),
[matched NTT/sumcheck study](https://arxiv.org/abs/2606.16146),
[archived zkLLM](https://github.com/jvhs0706/zkllm-ccs2024).
Seven records appended531->538. Exact dates/unknown dates,license scope and
inspected/unresolved commits are saved. SlackSwap is a simulation; vDNN is
older training evidence. No author performance reproduced. ICICLE full commit
6c77775961b0e4dc2be359feec1ac11536c18043 is a VERSION change only. ICICLE
repository and zkLLM MIT texts inspected; SP1 license/full PR commit and the
backlinked fork5090 PR fetches failed. No performance claim from that fork.

Rankings and baseline/eliminated work/added costs/ceilings/falsifiers are in
hypotheses.json. First owner action remains whole-prover high-endGPU clocks
and independently verified fixed-context resident1/2/4/8 workloads. Next local
experiment: add exact source-derived H-commit and FZC/DZC raw scratch intervals
to this owner trace, check overlapping/deferred-opening controls, and specify
native per-phase actual capacity counters. Do not repeat the release-only or
fallback staging experiments. No eviction build without an actual capacity cliff.

Integration seam: `prove_run_with` (R8 run.rs917..1031; GPU684..791),
`prove_core` (R8 protocol.rs1018..1172; GPU882..1039), and `DevCommit`/`Pooled`
in cuda.rs. The handoff provides telemetry fields/phase points; no production
patch, build, integration or merge. Native phase/memory counters, complete GPU
receipts,independent verification and current security/privacy gates remain
owner work under shared build/heavy locks. D33 remains scoped to its accepted
R7 artifact; D34 accounting does not accept new profiles. D32 fidelity and D27
whole-run obligations persist. No mask reuse or privacy weakening.

Complete private8B >=50 proved tokens/s on RTX5090/another named high-end GPU
is unchanged and unachieved. Larger workloads may amortize startup; increasing
context can increase attention work quadratically. Only research changed,
excluding runtime; no GPU,build,install,Git,external write/message,purchase or
escalation. Saved reports are not evidence of delivery to Victor.

# Cycle0095 — private transients and mixed FZC arena

Run `20261020T031854Z-e03e28dc`, checkpoint 2026-10-20T03:33:04.456870+00:00. **No proving speed improvement measured.**
Read the current agenda,durable state/findings/source ledger,prior results,
projectCLAUDE,MVP_STATUS,DECISIONS,coordination and throughput target. Early
STATE checkpoint saved; no source promotion or native/GPU work.

New question:can the already-raw slot18 source path reserve less storage,
and would that lower backing at the private stage's real peak? The existing
code still reserves uniform-stride `kd*l` Fp2 tables. Raw tables3..19 borrow
original A/H rows for rounds0/1; the first fused fold writes HALF length.
Eq/public tables need full constructor input; raw-round0 derived tables are
written at FULL length. A mixed layout reserves17 tables at l/2 and all others
at l. A global half stride or quarter raw buffer is invalid.

**Synthetic result:**30 fixtures,n3/4/5/6/8,support on/off,three
seeds,2-lane mod101 values and base-scalar challenges. Random-order in-place
folds match direct Boolean-weight multilinear evaluation of immutable
originals. 535848 checks/121 controls pass,including
naivehalf,unsafequarter,missingderived,offsetalias and mixed-without-raw.
This is an independent authored reference algorithm,not an independent review,
native Goldilocks Fp2,actual fzc polynomial,masked rounds,transcript or receipt.

**New partial source accounting:**72 traces/23094 events
combine private previous+current B and OUT owners,A/H commits and slot18.
The separate lifetime-interval oracle agrees on 646591 checks and
441 corruptions,80random traces,64idle-limit andoversize
controls. R8 f_e9 8B T32/64/128 geometry is applied to separately pinned active
GPU allocator source; this is hypothetical,not a supported native workload.
Repetitions1/2/4/8 repeat a partial allocation slice,not complete model passes.
No raw or pooled allocation counter is silently promoted to full-proverHWM.

At illustrativeT128,F2^21,support,kd23,the mixed request is736->464MiB
(-272MiB,36.9565%). A source-order allocation projection,one partial repetition:

| Commitment mode | Baseline backing MiB | Mixed backing MiB | Saving MiB |
|---|---:|---:|---:|
| Resident |9097.779842|9097.779842|0|
| Chunked/fullpad |1890.932186|1618.932186|272|
| Chunked/compactpad |1843.182186|1571.182186|272|

These are integers,not observedVRAM,fit,time or complete proof peaks. The
resident pool already owns larger eligible slabs; lower request savesZERO
backing. In selected chunked cases a fresh table buffer shrinks. Other actual
phases can erase the effect. Raw-source mode by itself changes neither this
baseline reservation nor the logical owner lifetime. Earlier release-only,
OUT-only eviction and all-resident host staging remain negative/demoted.

The model distinguishes requested/livecapacity/idlebacking/rawlifetimes and
cumulative allocation traffic. Idle pooled bytes remain allocated. Across
partialrepetitions4->8 backingHWMplateaus while rawallocationtrafficgrows;
cumulativebytes are notpeak. Omitted:seedownercommithistory,Hhelperconstruction,
opening scratch,other slots,failedattempts,twiddles,multiplepubliccaches,
driver/modules/granularity,pendingphysicalfrees and host/pinned/mappedmemory.
Rawfreesareimmediate inthismodel. ActualwholeGPUHWM/peakphase stillunknown.
SC_DZC in the active argument source has no deviceFzc descriptor; legacy
CUDA zerocheckscratch must not be added as if it ran in this private slot.

Eliminatedwork:storage forunusedrawinitialtails,no arithmetic or proofwork.
Addedcosts:offsetmetadata/upload,addressindirection/registerpressure,constructor
and every stride consumer,fallback/refusal/streamcompletion handling. No
end-to-end time ceiling is justified without exclusive native phase costs.
The target implication is only a possible capacity improvement in a particular
allocation route; no>=50/sprojection. Falsify on native out-of-bounds/uninitialized
or alias/round/final/proof mismatch,rawunavailable,changedrefusal/privacy,
noactualHWMbenefit or enclosing regression. No mask/opening reuse.

Seam:`cuda.rs::DevFzcRounds::new` and all later stride consumers;
`fzc_kernels.cu::fzs_ld/fzs_impl`,derivedwriters,fold/finals/hosttail.
Toy patch:layout_probe.py widths/run_fixture;projection:model.py fzc packed.
No native candidate exists. Source hashes/copies,commands,seed2026102095,
results and limits retained. Handoff:`handoffs/20261020-mixed-fzc-arena.md`.
Owner must establish usefulness then require nativeGoldilocksF2,actualpolynomial,
shadowmaskedrounds+nextchallenge,fullreceiptbyteidentity/independentverify,
fallback/refusal/strictGPU and CS/H-1/currentprivacy gates under sharedlocks.

New independently verified full-stack proofs/passes/positions**0/0/0**.
No actualtokencontext/GPU; new witness/proof/serialization/verification clocks,
steady/total rates,startupfraction**unmeasured**. No long-context prefill,
complete resident-pass series or decode. Larger workloads authorized; attention
may growT^2. Private8B >=50/s RTX5090/highendGPU unchanged/unachieved.
Carried ownerCPU8B T128,L32,one16-threadpass,GPUoff:total478.737s=>0.267370
promptpositions/s;prove_run393.785s includeswitness98.348/load17.595;
sealing84.824overlapswitness/load. Receipt922711264B;freshverify42.709+
13.681load,recheck34.395+10.739load. Not reverified. Startup/steadyslope/
isolatedserializationunknown. Ownernext-token501.6/529.2s aredistinctworkloads.

Final leaves:model0.448228s/98652KiB,
audit0.978800s/48928KiB,
layout0.832819s/49076KiB. These are validationprocess
clocks. One nice19 CPU0 thread,CoreUltra9 185H,WSL2,Python3.10.12;
59s CPU/wall alarm and512MiBAS perleaf. Initial sourcearm extraction failures
and interim hi/lofix remain recorded;final passes usecorrectsourceorder.

LIVEsources: new [StateSync-GKR](https://arxiv.org/abs/2610.14849) and formal
companion/release, [SP1GKRPR3005](https://github.com/succinctlabs/sp1/pull/3005),
SP1Oct10release,olderSP1-zorch55composedOOM,INT4toyFFN,Sumcheck201,
BitsUnderZKLLM andefficient-sumcheck. Tenrecords538->548;exactURLs,
verified/unknowndates,scopedlicenses/unresolvedcommits andfetchfailures in
source-records.json/search-log.json. Noauthorspeedreproduced. StateSyncformal
abstract excludes multiroundFS; currentBSLdistribution differsfromhistorical
MIT/Apacheversion. INT4 8->16->8ReLUFFN isnotfullattention. Sumcheck201
primaryfullread verifiesFeb2,2024; newlyappendedbatch date refined,initialbatch
retained andprior538records byte-identical. No foreigncodeexecuted.

Ranked:1ownercompleteGPU+verifiedresident1/2/4/8;2ownerexactDDprototype;
3NEWmixedrawarena;4actualphase/capacitytelemetry;5priorpublicloader;
6OUTevictiondemoted;7earlyrelease rejected;8NTTcomposition;9publicmetadata.
Nextlocal:actualGoldilocksF2/fzcpolynomial toy+completeaddressconsumer census,
coverrawround0derived,firstfusedfold,hosttail/finals anddensefallback. Owner
measurement ofactualraweligibility/peakbacking precedes native implementation.
D27,D30,D32,D33R7scope/D34accounting preserved. Onlyresearch(excludingruntime)
written;noGPU/build/install/Git/production/receipt/calibration/safety/instruction/
reviewer/externalmessage-write/purchase/escalation. Savedreportsimplynodelivery.


## Cycle 0096 — FZC arena algebra and implicit affine tables (2026-10-20T04:33:40.848204+00:00)

Run `20261020T041854Z-f70297a5`. **No measured proving improvement.**
Experiment: `experiments/native-fzc-arena-20261020/README.md`.
Owner handoff: `handoffs/20261020-implicit-affine-fzc.md`.
The agenda, current project/status/decision/coordination files, complete prior
findings/source ledger and latest experiment results were read. A short STATE
checkpoint preceded the experiment; prior findings and negative results remain.

The mixed arena now has an authored Python model over the native field
 definition (p=2^64-2^32+1, u^2=7) and actual SC_FZC polynomial. It matches a
separate schoolbook quotient-field implementation, original-slot polynomial
and explicit Boolean-weight original-table MLE across 108 fixtures and 468
modeled rounds. Canonical field bytes, s(1) recovery, finals and a synthetic
SHA-256 challenge recurrence match. This is not native Rust/CUDA instruction,
masking, Fiat–Shamir, PCS/receipt equivalence, proof verification or a privacy
review. Both algorithms were authored by one researcher. The final probe took
14.2743105 s and 17060 KiB RSS, one CPU, seed 2026102096. Cube logs 3/4/6
are table dimensions, not token contexts. Cases cover support/pads,
base/extension A, degrees 4/5, dense/raw/mixed/implicit and host tails.
Eleven negative controls reject unchanged full constructor slices and uniform
stride consumers, missing raw eligibility, omitted affine constants, treating
affine differences as values, and independent residue lanes mistaken for Fp2.

NEW hypothesis: reconstruct affine GL/PL endpoints from already staged A in
shared memory each round, rather than globally storing and folding them.
The existing split polynomial retains exactly its field meaning. Constants
belong in low values, never in the difference. At illustrative T128,
F-cube L=2^21 and support, requests fall from 736 MiB dense to 464 MiB mixed,
then 400 MiB with implicit GL/PL. Source-counted device-only traffic removed is
16*(1+support)*(4L-3) bytes, just under 256 MiB at this example, plus
(1+support)*(L-1) derived Fp2 folds. Candidate affine endpoints total 2L-2,
versus baseline L, adding L-2 evaluations, shared work and a later chunk
barrier; register/occupancy effects are unknown. This is not measured traffic
or an end-to-end speed forecast. No relation, private owner or mask work is
removed. The exclusive native slot-18 time share is unmeasured.

The prior partial capacity model was extended across 72 schedules. Its
separate interval oracle exercised 234426 assertions and rejected 72 corrupt
capacity events. **All 24 resident cases save zero additional backing**;
selected chunked cases save another 64 MiB, 336 MiB versus dense. Noncompact
T128/support/one-slice backing is modeled as 1890.932186 -> 1618.932186
-> 1554.932186 MiB; resident remains 9097.779842 MiB. These combine pinned
R8 geometry with a different GPU allocator revision and omit other slots,
openings, earlier history, H helper scratch, retries, multiple caches, driver
and granularity. No actual GPU peak, fit or elapsed gain is established.
Allocation repetitions 1/2/4/8 are not complete model passes. The prior
resident-pool negative finding therefore remains a strong promotion filter.

A lexical census indexes 107 selected sites, 21 functions and 43 allocation,
address or stride sites. Constructor full-slice anchor was initially selected
at another class's identical expression (3225), then corrected by scoping to
DevFzcRounds (4332); earlier command hashes/logs remain. Allocation is 4326;
raw loader 755; split stores 838..843 and 867..868; host generic fold 4756,
pack 4773 and finals 4788; device pack 919 and finals 1664. The source index
includes legacy variants, but is not complete compiled-program coverage.
Every consumer needs offsets or a dense fallback. Proposed shared-derived
mode stages K0, reconstructs shared derived slots and folds only stored
original tables. No native patch was applied or built.

Ranked queue: (1) owner whole-GPU clocks and independently verified resident
1/2/4/8; (2) owner exact DD prototype; (3) actual raw/peak capacity telemetry;
(4) refined mixed plus implicit affine arena; (5) public loader; (6) OUT
 eviction demoted; (7) early release rejected; (8) NTT/public constants;
(9) prepared public metadata. Full baseline, eliminated work, added costs,
prerequisites, compatibility, exactness/privacy obligations, unknown ceiling
and falsification are recorded in hypotheses.json. The tested local candidate
is conditional on owner measurement. Any address/round/final/receipt/refusal/
privacy mismatch, no lower actual backing or enclosing time regression
falsifies promotion. Next local: coefficient-aware operation/shared/barrier
budget and host-tail break-even; no native/GPU build from this lane.

LIVE primary sources: 548 -> 557 (nine new records). New NTT-TensorCore is
filtered by different field/FP64 arithmetic and its consumer large-N negative;
SP1's October release/full tag commit and October 5 PR2993 constant
simplification/scratch cap were inspected. ICICLE full release commit and root
MIT license were inspected with separate backend/date limits. zkLLMPoT v2
(October 11) supplies different operator/softmax/composition scope; zkIE's
public witness and forward verifier do not satisfy P1/P3. Newly assessed older
Theodosian (2025-12-20, revised 2026-03-17) motivates L2/NoC measurement and
cache-bounded batching; its CKKS speedups are not native proving evidence.
NTTSuite (2024-05-18) adds no-copy Pease/Stockham layout ideas, 32-bit field
and device-only timing limits. A search hint falsely assigned it arXiv2406.16972;
that primary page is unrelated NAS work. Correct id is 2405.11353; reject the
hint and numerical speedup. Source dates, exact URLs, commit/license scope
and failed fetches are retained. The linked October 17 hemilabs RTX 5090 PR7
was a cache miss; its headline is not reproduced evidence. No downloaded code
ran and no author performance was reproduced.

Carried owner CPU 8B T128/L32, one 16-thread pass, GPU off: total 478.737 s,
0.267370 positions/s; prove_run 393.785 s includes witness 98.348 and load
17.595 s. Sealing 84.824 s overlaps those phases; receipt 922711264 bytes;
fresh verify 42.709 + 13.681 load s. Not rerun/reverified; startup, steady slope
and isolated serialization unknown. New verified full proofs/passes/positions
are 0/0/0; actual model context/device none. All new witness/proof/serialization/
verification clocks, steady/total proved rates and startup fraction are
unmeasured. No long-context prefill, complete resident passes or decode ran.
Complete private 8B >=50 proved tokens/s on RTX 5090/another named high-end
GPU remains unchanged and unachieved. Larger workloads are allowed; attention
may grow quadratically; no mask/opening reuse or privacy weakening. D27/D30/
D32 obligations, D33 frozen R7 TinyLlama T32 scope and D34 accounting remain.
Only research excluding runtime was written; no production, Git, build, GPU,
install, receipt/calibration/safety/instruction/reviewer change, external
message/write, purchase or escalation. Saved reports imply no delivery.


## Cycle 0097 — paired affine derivation and rematerialization cost


Run `20261020T051854Z-d5b6bbb8`, 2026-10-20 UTC.
**No proving speed improvement measured. No native patch, build or GPU run.**

The previous cycle proposed eliminating the global GL/PL affine tables from
slot 18. This cycle counts the recomputation cost against the pinned active
GPU source, and tests a smaller alternative: keep the existing tables, but
derive each round-zero value/difference pair directly. Precompute
`effective_pad[j] = mu_pad * pad_weight[j]` from the current public slot
descriptor. Constants enter the value only; differences use the homogeneous
linear form. All global table values, later folds and barriers stay in place.
The historical lean evaluator already uses value/difference linear forms;
the current raw split derivation still calls its endpoint evaluator twice.

The authored Python experiment passes **36 fixtures, 144 rounds, 1,599 checks
and seven negative controls**. Fixtures have 8/16/32 entries per table,
support on/off, 0/1/3/8/11 nonzero public pad weights, base or extension A at
round zero, and several allowed power-of-two requant constants. Seed is
`2026102097`, with case seeds and round hashes retained. Candidate arithmetic
follows the source's Karatsuba primitive calls; a separate schoolbook quotient
field, original SC_FZC polynomial and explicit original-table MLE give the
reference. Canonical round bytes and stored high endpoints agree. Challenges
are a synthetic SHA-256 recurrence, not native Fiat–Shamir. These arbitrary
synthetic tables are not valid transformer witnesses.

Seven controls reject omitted/stale preweighting, affine constants in
differences, missing extension differences, omitted public pad support,
incorrect high stores and componentwise extension multiplication. A separate
**720-case source-accounting study** checks event schedules against closed
forms with seven accounting controls; all pass. The raw-only option includes
reconstructing `hi = lo + difference` for its unchanged global high store.
The first partial cost output omitted that reconstruction; it is retained
under `before-store-reconstruction/` and superseded by the final results.

At an illustrative **L = 2^21 entries, support on, 11 nonzero pad weights,
no host tail**, final source-call deltas from the existing raw split path are:

| Candidate | Device base products | Device base adds + subs | Derived-operand shared reads | Saved derived global traffic | Extra chunk barriers |
|---|---:|---:|---:|---:|---:|
| Round-zero paired derivation, tables retained | -6,291,456 | -65,011,712 | -304 MiB | 0 | 0 |
| Full implicit tables, literal endpoints | +98,566,040 | +364,904,088 | +911.999 MiB | 255.999908 MiB | 32,772 |
| Full implicit tables, paired/preweighted | +85,983,134 | +226,492,122 | +303.999 MiB | 255.999908 MiB | 32,772 |
| Implicit PL only, paired/preweighted | +56,623,039 | +180,354,852 | +175.999 MiB | 127.999954 MiB | 32,772 |

These are **source calls and logical operand reads before compilation**,
not instructions, actual shared/DRAM transactions, timings or a GPU memory
peak. Shared counts assume unused loads are eliminated, and omit parameter
staging/common polynomial evaluation. Barriers are summed across CTA chunks;
they are not 32,772 serial device-wide waits. Register pressure, cache reuse,
occupancy, hardware wave scheduling and compiler common-expression elimination
can change the result. A table cube is not a token context.

Preweighting adds 11 host Fp2 products here (33 modeled base products),
at most 176 parameter bytes to transfer/store, and coefficient staging per
round-zero block. A separate staged coefficient array needs up to 176 shared
bytes per block and its parameter loads; preserve the original descriptor for
fallbacks and the host tail. The proposed setup is once per **sumcheck**, not
once per model or workload. It must be recomputed after each slot's own draws.
No mask, commitment opening or private value is reused.

For a host transition to H = 2^tail_log entries (or H = 1 without a tail),
the stored path derives L endpoints and folds L-H derived outputs per table.
Full implicit mode derives 2(L-H) endpoints. Avoided derived global bytes are
`16*d*(4*L - 3*H)`, where d is 1 or 2. Generic boundary folds use five base
products per Fp2 multiply; fused folds use three. The study includes that
distinction and host-tail thresholds through n-2. The original k tables'
packing, transfers, host rounds and finals are common, not removed work.
Dropping only the dead derived boundary fold saves merely 96 B in the example,
or 6 KiB at tail_log 6: useful correctness accounting, not a speed lever.

The dense-pad full-rematerialization option now falls behind the smaller
round-zero option. It needs about 0.3203 additional base products per saved
global byte before its added additions/shared work/barriers. This is only one
term of a break-even budget. Saved source bytes must actually reduce exposed
critical-path work, and actual backing/fit may still dominate the decision.
The prior partial pool model saved **zero additional backing in 24/24 resident
cases**, so the 64 MiB request saving cannot justify new compute by itself.
Sparse PL with 0/1 public nonzero weights reduces counted products, but retains
the new barrier and requires actual descriptor/peak evidence; no dispatch on
private zeros is proposed.

The round-zero candidate's end-to-end ceiling is unknown. If the exclusive
raw-derived phase fraction is f, even deleting it costs at most a factor
`1/(1-f)`; this candidate removes only part of it and adds setup. There is no
complete GPU workload measurement of f. An arithmetic reduction does not show
50 complete proved positions/s. Falsify the candidate on any round, high-store,
mask/challenge, refusal or receipt mismatch, unavailable raw eligibility,
compiler removal of the supposed redundancy, or enclosing elapsed regression.

`candidate_pair.cuh` is an **uncompiled adapter sketch**, not an applied patch.
The actual seam is `fzs_impl`'s raw round-zero phase 1b, replacing its two
`fzs_derived_at` calls; host preparation belongs at `DevFzcRounds::new` after
the public descriptor exists. The owner must stage the current coefficients,
retain all existing global stores, shared stores and the barrier, and preserve
raw-off / split-off / unfused / tail / dense fallbacks. The source manifest
pins eight native files, unchanged from cycle 0096 and at final validation.
The current CPU R9/DD tree is a distinct revision and needs its own gates.

Commands from the research directory:

```text
python3 experiments/affine-fzc-budget-20261020/run_bounded.py pair_probe.py
python3 experiments/affine-fzc-budget-20261020/run_bounded.py cost_probe.py
python3 experiments/affine-fzc-budget-20261020/run_bounded.py validate.py
```

Final Python algebra time 1.939 s, max RSS 16,820 KiB; cost study 0.349 s,
13,016 KiB, on Intel Core Ultra 9 185H / WSL2. Each authored leaf is one
thread on CPU 0, nice 19, <=59 seconds CPU/wall and <=512 MiB address space.
Logs, source/dependency hashes, commands, cases and hardware are retained.
No installation or downloaded-code execution occurred.

Carried owner baseline, not rerun/reverified here: complete 8B stack,
T128/L32, one CPU pass at 16 threads, GPU off: total 478.737 s,
0.267370 proved positions/s; prove_run 393.785 s includes witness 98.348 s
and load 17.595 s. Sealing 84.824 s overlaps those regions. Receipt
922,711,264 B; fresh verify 42.709 + 13.681 load s; recheck
34.395 + 10.739 load s. Startup fraction, steady slope and isolated
serialization remain unknown. The owner's new R9 DD T128 run reports
474.9 s versus 478.7 s, shared box, n=1, explicitly no measurable change;
it is built and under soundness/privacy review. Its smaller committed count
is not a reproduced speed improvement. Next-token runs are separate workloads.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context and accelerator: none. New witness/proof/serialization/
verification clocks, startup fraction, steady-state and total-workload proved
rates: **unmeasured**. No long-context prefill, complete resident-model pass
sweep or decode ran. Attention may grow quadratically with context. The
complete private 8B >=50 proved tokens/s target on RTX 5090 or another named
high-end GPU remains unachieved. D27/D30/D32/D33/D34/D35 scopes are unchanged.

Eight LIVE source records were appended, 557 -> 565. The useful new source is
[allocator-aware peak scheduling](https://arxiv.org/abs/2610.23328), dated
October 16; its GPU history-dependence result motivates measuring actual
backing. Newly assessed older [Moccasin](https://arxiv.org/abs/2304.14463)
adds latency-constrained recomputation scheduling. Recent
[SP1 6.9.0](https://github.com/succinctlabs/sp1/releases/tag/v6.9.0), Chimera's
October 16 revision, SumCATS, OpenVM-zorch44, ICICLE and efficient-sumcheck
were checked for compatible seams and limitations. These are author claims,
not reproduced performance. Exact dates, commit/license scope and cache/404
failures are in `source-records.json`; no access control was bypassed.

Next owner action: a small locked native round-zero A/B, exact masked rounds,
next challenges, frozen complete receipts and fresh independent verification,
with actual raw eligibility, public pad support, registers and enclosing clocks.
Next local question: can the existing public BASE flag safely specialize this
paired derivation further while retaining the extension-field fallback? Test
base products versus original-slot math before proposing another native change.
The explorer does not merge. Only this research directory excluding runtime
was written. Saved reports do not imply external message delivery.


## Cycle 0098 — BASE paired affine derivation and an upstream negative

Run `20261020T061854Z-03bda577`, 2026-10-20 UTC. **No proving speed
improvement measured; no native patch, build, GPU or proof.** Read current
agenda, durable memory, latest results and required project documents;
checkpointed state early. Production untouched.

Refined cycle0097's paired raw round-zero slot18 derivation using the existing
BASE host dispatch: GL scalar clauses multiply extension mu; PL extension
preweights multiply scalar A. Coefficients and derived outputs remain Fp2.
Keep both global endpoints (hi=lo+dif), shared stores/barrier and later
extension folds. No new private-value scan/dispatch; existing Host/Public
coordinate eligibility must not be broadened or exposed. No privacy claim.

Independent Python original-slot schoolbook polynomial/direct-original-MLE
checks pass **36 fixtures, 144 rounds, 1,669 checks, 18 negative controls**,
plus **90 partial source-cost cases**. Lengths8/16/32; support on/off;
k0/1/3/8/11; base/extension A; extension helpers/coefficients; modular edges.
Kh=2^1/2^20 cases stress algebra outside admitted trained sh_h9..16.
Only18 first rounds use BASE; later/extension fallback passes. Synthetic
hash challenges and arbitrary tables are not native Fiat–Shamir or trained
witnesses. Controls detect BASE on each of11 extension A inputs, extension
differences and postfolds; lost imaginary outputs, stale/unweighted pads,
affine constants in differences and incorrect high stores. Initial17-control
evidence retained; final adds an extension-difference control. Validation:
67 checks/eight native pins unchanged. One CPU thread/core0, nice19, final
leaf1.555s/16,948KiB on Core Ultra9 185H/WSL2. Every leaf <=59CPU/alarm seconds,
60wall seconds and512MiB address space; no dependency/external code executed.

Illustrative L=2^21/support/k11 derived-phase counts (current literal / prior
paired / BASE): base products111,149,056 /104,857,600 /67,108,864;
adds+subs423,624,704 /358,612,992 /76,546,048; logical shared operand
reads912 /608 /304MiB. Against current source: remove44,040,192 products,
347,078,656 adds/subs and608MiB reads. Counts are precompiler calls/reads,
not instructions, actual traffic or time; scalar reads assume DCE. A cube
length is not a token context. No global/capacity saving or extra barrier.
Add k fresh host Fp2 preweights/sumcheck(11here), <=176parameter bytes/staging
and template code; relative to prior pair no extra setup. Compiler/register/
occupancy/enclosing effects unknown. Unknown exclusive phase fraction f:
even deleting the whole phase permits at most1/(1-f), candidate narrower
plus setup. Reject any parity/refusal/receipt/eligibility failure or enclosing
regression, including compiler elimination of the alleged redundancy.

Ranked queue retained/refined (12 full entries in hypotheses.json): owner
whole GPU+verified resident1/2/4/8; owner DD larger-context scaling after T128
null; actual peak/raw/BASE/public-pad/exclusive-phase telemetry; tested BASE
pair; public loader; capacity-gated mixed arena/implicit tables; demoted OUT
eviction; rejected earlier release; NTT/constants; prepared metadata; NEW
upstream carry negative; NEW older packed-protocol filter. Each records
baseline, removed work, costs, prerequisites/integration, exactness, privacy/
soundness, compatibility, ceiling and falsification. Prior negative findings
are preserved; arithmetic count reductions do not establish GPU throughput.

Six LIVE primary records appended565->571. Newly assessed older
[packed sumcheck](https://eprint.iacr.org/2025/719), received April22,2025,
revised September14,2026, requires matrix challenges/MW-MLE PCS; it is no
permission to truncate native Fp2. Newly assessed
[prime-ir409](https://github.com/fractalyze/prime-ir/issues/409), July29–30,2026,
records the author's rejection of shorter carry/128-bit accumulation forecasts.
Preserve that negative and require compiler/register/occupancy measurements.
SP1 latest6.9.0/full tag commit, Bits Under ZK-LLM, October zkLLMPoT v2 and
extended sumcheck refreshed. Exact URLs, dates, license/commit scope and
Internal Error failures in source-records.json. No author performance
reproduced, downloaded code run or native arithmetic/lookup/field change.

The decisions register now records R9/DD soundness accepted at three profiles
(05:59UTC), with N-r9-a row Sum/slot17/Ht and N-r9-b M_dd in A/commit before
challenges; DD privacy gate remains owed. OwnerT128478.7->474.9s comparison
is n=1/shared-box and explicitly null. D33 frozen R7 TinyLlama T32 privacy
scope is not extended; D27/D30/D32/D34/D35 obligations continue. R10 range
work remains owner-owned.

Carried non-DD CPU8B T128/L32/one16-thread pass, GPU off: total478.737s
=0.267370positions/s; prove_run393.785 includes witness98.348/load17.595;
seal84.824 overlaps; receipt922,711,264B; fresh verify42.709+load13.681s;
recheck34.395+load10.739s. Not rerun/reverified. Startup/steady/isolated
serialization unknown. New independently verified full proofs/passes/positions
0/0/0; actual model context/device none. New witness/proof/serialization/
verification clocks, startup fraction and steady/total proved rates unmeasured.
No long prefill, complete resident pass or decode. Complete private8B>=50
proved tokens/s on5090/another named high-end GPU remains unachieved. Larger
workloads allowed; attention may grow quadratically. No mask/opening reuse
or privacy weakening.

[Experiment](experiments/base-affine-fzc-20261020/README.md) and
[handoff](handoffs/20261020-base-paired-affine-fzc.md) retain interface,
uncompiled adapter, pins, seed, commands, dimensions, hardware and risks.
Owner next: locked tiny native A/B, registers/spills, exclusive/enclosing
clocks, masked rounds/next challenges/full receipt identity, fresh verify
and current gates. Local next: compare BASE GL-only needing no new host
coefficients with full prepared pair; independent math and sparse-pad costs.
Explorer does not merge. Only research excluding runtime written; no
production/Git/build/GPU/install/receipt/calibration/gate/instruction/reviewer
changes, external messages/writes, purchases or escalation. Reports imply
no external message delivery.

## Cycle 0099 — host-free BASE GL-only derivation (2026-10-20)

Run `20261020T071854Z-1076bec1`. **No proving speed improvement measured.**
The refined question is whether a smaller GL-only raw-round-zero BASE adapter
can avoid host pad preweights while retaining useful source savings. Python
algebra says yes; native/compiler/enclosing benefit remains unknown. Top
three hypotheses need owner GPU/heavy measurements, so this was the leading
locally testable candidate under the standing resource limits.

Independent original-slot quotient-field polynomial/direct-original-MLE
checks pass: 36 fixtures, 144 rounds, 2,372 checks, 15 negative controls and
90 partial source-cost cases. Seed 2026102099; 8/16/32 cube entries; support
on/off; 0/1/3/8/11 public nonzero pad weights; base/extension A; modular edges;
Kh shifts 9/10/12/15/16. Canonical round bytes, high stores, original-table
finals, final derived values and final polynomial agree. Only 18 first rounds
use BASE. Synthetic data/hash challenges are not native masks, Fiat–Shamir,
PCS, valid transformer witnesses, receipts or verifier execution. Three
PL-only imaginary-input probes do not broaden native eligibility. Validation:
223 checks, eight current source pins unchanged. One CPU thread/core0, nice19,
final leaf 2.415 s / 17,012 KiB RSS; 59 s CPU/alarm, 60 s parent, 512 MiB caps.
Initial evidence retained before added final-value checks.

The candidate changes GL only. PL and non-BASE paths remain literal; mu,
derived values and both high/low stores keep extension coordinates. No host
preweights, parameter bytes, global storage, barriers or private scans added.
At illustrative L=2^21, support on, k=11, literal -> GL-only -> full BASE pair:
products 111,149,056 -> 96,468,992 -> 67,108,864; adds/subs 423,624,704 ->
326,107,136 -> 76,546,048; logical shared reads 912 -> 656 -> 304 MiB.
GL-only saves 14,680,064 products, 97,517,568 adds/subs and 256 MiB reads
versus literal, independent of pad support in this partial model. Full BASE
saves more source work with k fresh host Fp2 preweights and <=176 parameter
bytes. Both save zero global/capacity bytes. These are precompiler calls and
logical reads, not instructions, DRAM traffic or time. Compiler elimination,
registers, branch/occupancy costs and exclusive fraction f unknown; even
whole-phase deletion is bounded by 1/(1-f). Reject any parity/refusal/receipt
or eligibility mismatch, absent compiler savings or enclosing regression.

Integration: pinned fzc_kernels.cu fzs_impl<...,BASE> raw&&!FOLD phase1b,
~line855. candidate_gl_only.cuh returns lo/dif/hi using existing parameters;
keep all stores/barriers and current BASE/next==0 host rules. Sketch remains
uncompiled, not an applied patch. Owner needs a shared-lock literal/GL-only/
full-pair A/B, ptxas registers/spills, eligible incidence/public pad counts,
exclusive/enclosing clocks, masked round/next-challenge/full-receipt parity,
fresh independent verification and strict-GPU/refusal/CS/H-1/privacy gates.
No native masks/draws/openings are reused, and no merge is performed here.

Six LIVE primary records appended (571 -> 577). New older
[sumcheck non-malleability](https://eprint.iacr.org/2026/335), first posted
February20/revised June15, 2026, has PCS/compiler-specific assumptions and
supplies no native privacy or opening-reuse clearance. New
[TenseUp](https://eprint.iacr.org/2026/2435) has an October10 update in the
[primary index](https://eprint.iacr.org/2026/), but direct page/PDF fetches
failed; constants/security/implementation remain unassessed. DeepProve,
NanoZK, SP1 and October zkLLMPoT refreshed. Exact dates, license/commit scope
and access failures in source-records.json. DeepProve's exact custom license
was inspected, not assumed permissive; no external code adopted. SP1 full
tag commit b8387fa61e1361d90ee7de49f551863418ca0f08 inspected. No author
performance reproduced. Irrelevant search results were discarded.

Fourteen ranked hypotheses retain the earlier negative findings. First:
owner complete GPU + verified resident 1/2/4/8 passes; DD larger contexts
after T128 null; actual peak/raw/BASE/phase telemetry; this native adapter
choice; prior public loader; capacity-gated mixed arena. New lookup and
composition screens are lower-priority, with costs/security/prerequisites
explicit. R9 DD soundness is accepted with N-r9-a/b; DD privacy gate remains
owed. T128 478.7 -> 474.9 s is explicitly a shared-box n=1 null. D33's frozen
R7 TinyLlama T32 scope is not extended; other current obligations remain.

Carried non-DD CPU 8B T128/L32, one 16-thread pass, GPU off: 478.737 s total
=0.267370 positions/s; prove_run393.785 includes witness98.348/load17.595;
seal84.824 overlaps; receipt922,711,264 B; fresh verify42.709+load13.681 s;
recheck34.395+load10.739 s. Not rerun/reverified. Startup, steady slope and
isolated serialization unknown. New verified proofs/passes/positions0/0/0;
actual model context/device none. New witness/proof/serialization/verification
clocks, startup fraction and steady/total proved rates unmeasured. No long
prefill, resident-model pass or decode. Complete private8B >=50 proved tokens/s
on RTX5090/another named high-end GPU remains unachieved. Larger workloads
allowed; attention may grow quadratically. Privacy/fresh masking unchanged.

[Experiment](experiments/gl-only-fzc-20261020/README.md),
[handoff](handoffs/20261020-gl-only-affine-fzc.md). Next local: census Rust
public pad-weight descriptors and existing raw/BASE/SUPP gates to establish
reachable k without private scans. Owner compiler/phase results take priority
over further source counts. Next owner: native three-arm A/B above. Only
research excluding runtime written; no production/Git/build/GPU/install/
external writes/messages/purchases/escalation. Reports imply no external delivery.

## Cycle 0100 — reachable public pad weights and affine dispatch (2026-10-20)

Run `20261020T081854Z-6e7df31f`. **No proving speed improvement measured.**
The refined local question was which public pad-support sizes actually reach
the proposed raw BASE phase1b adapter. The source census rules out the earlier
synthetic sparse1/3/8 cases for accepted padded FFN descriptors. All eleven
F A planes are ZERO-rule; the only exemption A_E is outside F. SC_FZC hosts
one pad group, refuses zero zeta, and starts powers at zeta^0. Original FZ_PADW
therefore has eleven nonzero weights; unpadded slots carry none. Zero mu_pad
is allowed and makes PL zero, but does not zero the original parameter weights.
Do not retry or weaken the existing refusal to manufacture sparsity.

Independent public parameter bytes, quotient-field pad polynomial and gate
predicates pass7,616 checks:640 descriptor/challenge cases,3,132 dispatch cases,
46 negative controls,eight zero-zeta refusals. Ten public geometry fixtures
include TinyLlama/8B T32/64/128, toy/development/125M and a synthetic P3 lift.
All model gates retain split/fused/raw,n>=3,n-1>tail_log,resident tables3..19,
BASE on every A3..13 and S20, and next==0. Helpers stay extension-valued; no
private-value scan added. Source audit51 assertions,six source mutations and
13 unchanged pins. One CPU thread/core0/nice19,final leaf0.442s/12,268KiBRSS;
59s CPU/alarm,60s parent,512MiB address-space caps. Initial wrong8B row label
retained in initial-row-labels/, corrected to actual13/13/14; cube sizes and
conclusion unchanged. No native build,Cuda,masks,transcript,PCS,receipt,valid
transformer witness or verifier ran. This is not a full sumcheck benchmark.

Both inspected source lanes retain all eleven F planes, including frozen R9
DD/non-DD branches. Keep lanes separate: active GZC registers8B T32; R9
registersT32/64/128 and its F slot does not contain this GZC descriptor adapter.
Nominal R9 T128 FFN cube2^21 is not current GPU admission or execution.

No native work eliminated here. The all-eleven conclusion selects the prior
source-cost row: at L2^21, GL-only removes14,680,064 counted base products,
97,517,568 adds/subtracts and256MiB logical shared reads versus literal; full
BASE pair removes44,040,192 products,347,078,656 adds/subtracts and608MiB.
GL-only adds no preparation/parameter bytes; full pair needs eleven fresh
Fp2 preweights/up to176 parameter bytes per supported padded sumcheck.
Both retain full-coordinate high/low stores and save zero global/capacity
bytes/barriers. Counts are from cycle0099's pinned artifact, not compiler
instructions,physical traffic or timing. Compiler DCE,registers/spills,
occupancy and exclusive f remain unknown; even full-phase deletion ceiling
is1/(1-f),candidate narrower plus setup. Reject widened eligibility,source
drift,any round/refusal/receipt mismatch,absent compiler savings or enclosing
regression. Prior negative findings are preserved.

Fifteen ranked hypotheses retained: owner whole GPU+verified resident1/2/4/8;
DD larger-context scaling after explicitT128null;actual capacity/raw/BASE/
exclusive/enclosing telemetry;all-eleven native adapter choice;public loader;
capacity-gated arena;demoted OUT and rejected premature release/arithmetic.
Refined NTT filter: native k_ntt_p1 already gathers bit-reversed input inside
its first shared-memory transform pass. New consumerBlackwell/olderCOBRA
leads support examining actual gather sectors, not deleting a nonexistent
standalone reorder pass. New Pico3.0 helper-commitment reduction requires
census of saved bytes versus additional GKR rounds/final openings, with new
masking/transcript/PCS/security/privacy analysis. No protocol change adopted.

Eight LIVE primary records577->585. New
[consumer Blackwell report](https://github.com/pscamillo/icicle-blackwell-ntt)
is an unreplicated RTX5070/BabyBear author claim; primary history/license/code
fetches failed, no primary publication date/immutable commit established.
New older [COBRA](https://csaws.cs.technion.ac.il/~itai/Courses/Cache/bit.pdf)
primary paper dates FOCS98 (November8–11,1998); CPU cache constants not
transferred. New [Pico3.0](https://blog.brevis.network/2026/09/30/pico-3-0-real-time-ethereum-proving-on-4-gpus-with-100-bit-provable-security/)
September30,2026 announcement is different-field/PCS,four-GPU Ethereum.
ICICLE4 full version commit, gnark0.22 full commit/dateOctober2,2026,
efficient-sumcheck unreleased-wire-format caveat, olderZeroCheck and
LogUp-GKR refreshed. Exact URLs/dates/license scope/pins in source-records.json.
Source commit429,PDF403 andCache-miss/Internal-Error failures retained; no
bypass,external code execution or reproduced author performance.

Carried non-DD CPU8B T128/L32 one16-thread pass,GPU off:total478.737s
=0.267370positions/s;prove_run393.785 includes witness98.348/load17.595;
seal84.824 overlaps phase accounting;receipt922,711,264B;fresh verify
42.709+load13.681s;recheck34.395+load10.739s. Not rerun/reverified.
Startup,steady slope,isolated serialization unknown. New completed independent
full proofs/passes/positions0/0/0; actual model context/device none. All new
witness/proof/serialization/verification clocks,startup fraction,steady and
total rates unmeasured. No long-context prefill,resident pass or decode.
Complete private8B>=50 proved tokens/s on5090/another named high-end GPU
remains unachieved. Larger workloads allowed; attention may grow quadratically.
R9 DD soundnessN-r9-a/b remains binding; DDprivacy owed; D33's frozenR7
TinyLlamaT32 scope is not extended. No mask/opening reuse or privacy weakening.

[Experiment](experiments/public-pad-eligibility-20261020/README.md),
[owner handoff](handoffs/20261020-public-pad-eligibility.md). Next owner: locked
literal/GL-only/full-pair native A/B with ptxas,incidence,exclusive/enclosing
clocks,complete parity,fresh independent verification and current gates.
Next local: public sector-address census of actual fused NTT loads with
independent indexing and stride/padding/permutation controls; no bandwidth
forecast. Only research excluding runtime written; no production/Git/build/
GPU/install/receipt/calibration/gate/instruction/reviewer changes,external
messages/writes,purchases or escalation. Reports imply no external delivery.

## Cycle 0101 — fused NTT sector requests and ownership limit (2026-10-20)

Run `20261020T091854Z-d57182bc`. **No proving speed improvement measured.**

**No proving speed improvement measured.** An independent public-address
experiment finds that changing lane ownership in the fused NTT gather
cannot reduce source sector requests at transform length>=16384 with the
current4096-word tile. These transform lengths are not model context lengths.
At sampled smaller sizes, one-bit rotation halves requested sectors while
unique sectors stay unchanged and a fixed16-lane shared-bank demand model
rises1->2. Cache/physical traffic/native timing remain unknown.

Final: **6,239 checks,936 tile schedules,3,326,208 logical words**;
nine rejected bad controls plus one expected null. Source audit188 checks,
15 mutations,12 unchanged pins. One CPU thread:9.725s,
22,752KiB RSS. Initial audit caught an older main-tree pad producer;
source lanes and the retained failed assertion are explicitly scoped.

New independently verified full-stack proofs/passes/positions:**0/0/0**.
Actual model context/device:none. Witness/proof/serialization/verification
clocks,startup duration/fraction,steady and total rates:**unmeasured**.
No long prefill,resident-model pass or decode. Private8B>=50/s on5090/another
named high-end GPU remains unachieved. No mask/opening reuse or weaker privacy.

Six LIVE primary records added,including SP1v6.9.0,October14 memory placement,
and an older GNTT direct-float64 negative. Exact dates/license/commit scope
and fetch blockers retained; no author performance reproduced.

Next local: public PCS log_cols/q_pad/expanded-transform census to establish
actual small-size eligibility. Next owner: actual exclusive/enclosing GPU
clocks and verified fixed-context resident1/2/4/8 complete passes; existing
FZC compiler A/B remains higher priority than this conditional sketch.


The exact public stride identity is `r=rev_lb(q)*2^lt+rev_lt(blk)`, with
lb=min(logN,12),lt=logN-lb. At logN>=14 source stride>=4 words. A scalar
within-tile permutation cannot combine32-byte sectors that are all distinct
within the tile. This is not a claim about cache hits,DRAM or elapsed time.
At N4096 the one-bit rotation changes4096->2048 requested sectors per tile,
unique1024 unchanged; at N8192,4096->2048/unique2048; N16384 and larger
unchanged4096/4096. N is transform length,not context/tokens. Candidate
removes zero logical source bytes,capacity,proof arithmetic,passes,barriers,
fresh masks or commitments. Added index and shared-store costs remain unknown.
Fixed16lane bank address demand1->2 while wholewarp2 stays2; do not call it
bank-free or measured conflict latency. Full reversal gives wholewarp32,
fixed16group16 at N4096. The initial wholewarp-only result was preserved
before adding the issue-model sensitivity; no address conclusion changed.

The final model checks every element of936 sampled tile schedules across
21public geometries,32/512threads,rows0/1/2 and at mostthree blocks at larger
sizes. Compact/full synthetic values agree includingq>n and ragged/misaligned
controls,without certifying pad algebra. Independent bitstring/per-byte oracle
matches bitwise CUDA-style indexing. Nine bad controls reject plus one expected
large-size null; source audit188/15mutations/12pins. Initial audit assumed
all three lanes had the same pad producer and failed; main is the older
branched form,activeGPU/frozenR9 additive. Failure preserved and scope corrected;
no current producer/profile/privacy acceptance inferred from consumer parity.
Existing DIF/PAD_SKIP paths remain separate; fewer lane loads need not reduce
requested sectors due to broadcasts. Python checking clocks are not NTT clocks.

The existing CPU non-DD baseline is carried, not rerun/reverified:8B
T128/L32,one16-thread pass,GPU off,total478.737s=0.267370positions/s;
prove_run393.785s includes witness98.348/load17.595s; seal84.824s overlaps
accounting; receipt922,711,264B; fresh verification42.709+load13.681s,
recheck34.395+load10.739s. Startup,steady slope and isolated serialization
unknown. Increasing context may increase attention quadratically; repeated
independent contexts are aggregate resident passes, never decode.

Baseline: native fused bit-reversed gather, no standalone reorder. Eliminated
work: some small-transform load-sector requests only; zero logical global
bytes,capacity,proof arithmetic,transforms,barriers or fresh masks. Added
costs: index rotation and shared-bank pressure, plus unknown compiler/cache/
occupancy effects. End-to-end deletion ceiling1/(1-f) needs the unknown
exclusive affected fraction f; the actual sketch is narrower and adds cost.
Falsification: large-N request gain disproved at unchanged tile ownership;
any native parity/refusal/receipt mismatch or enclosing regression rejects
the remaining small-size candidate. No numeric complete GPU rate is supported.

17 ranked hypotheses retained in hypotheses.json: owner whole GPU/resident
workloads; DD larger-context sweep after T128 null; actual raw/BASE/capacity/
phase clocks; all-eleven affine native A/B; public loader; capacity-gated
arena; retained OUT/early-release negatives; tested NTT scope; public GKR
metadata; carry/packed-sumcheck negatives; dynamic lookup/composition/Pico;
new direct-float GNTT negative and memory-placement methodology. Each keeps
prerequisites,added costs,exactness/privacy and falsification.

Six source records585->591. Primary author issue dates the Blackwell report
claim toMay29,2026 (July2 discussion), not a new October report or repository
revision. SP1 releaseOctober10,full inspected version SHA
b8387fa61e1361d90ee7de49f551863418ca0f08; merged NTT PR metadataSeptember30,
its actual source diff not established. New primary memory paperOctober14,
2026; new older GNTT paperFebruary16,2025. Code's float64 cast inspected,
local p-2->p-1 cast negative; no upstream implementation run. NVIDIA13.4 and
NTT-TensorCore exact page update dates unavailable. Repository history/license,
merge-commit/relatedPR Cache-miss and docs.rs errors retained; no bypass.

Validation source assumptions were refined after an initial failure: main
uses an older branched pad producer; active GPU/R9 use the additive form.
The consumer address model does not certify producer algebra,profile admission
or q>n behavior of the older producer. Fixed16-lane bank pressure is an
issue-model sensitivity; actual SASS/wavefront decomposition is unmeasured.
The successful original whole-warp-only experiment is also preserved.

Only research excluding runtime written. No production/reviewer/calibration/
safety-gate/receipt/instruction/Git changes,builds,GPU,installations,external
writes/messages,purchases or escalation. Handoff is an uncompiled research
fragment for owner review; no integration or privacy acceptance here.

[Experiment](experiments/ntt-gather-sectors-20261020/README.md),
[handoff](handoffs/20261020-ntt-gather-sectors.md),
[dated report](progress/20261020T091854Z-d57182bc.md).

## Cycle 0102 — private PCS small-transform incidence (2026-10-20)

Run `20261020T101854Z-5d2a545a`. **No proving speed improvement measured.**
The useful refinement is to count inverse and expanded forward transforms
separately. Current hiding rows run inverse at log_cols and forward at
log_cols+log2(inv_rate); using only expanded size misses small inverse work.
Source-backed R9 TinyLlama contexts32/64/128 use log_cols12/13/14; 8B uses
13/13/14. Active GPU contains TinyLlama32/64/128 and 8B32, not R9's 8B64/128.
All trained rows use rate4/q256. Endpoints/boundaries follow their own profile
parameters. This is a selected per-row source census, not observed launches,
a complete registry audit, current GPU admission or workload incidence.

At lc12 inverse requests4096->2048; expanded forward stays16384 full-width
or4352 compact. At lc13 inverse8192->4096; expanded forward stays32768 or8448.
Thus one row's P1 load-pair requests drop10% full-width or24.2424/24.6154%
compact. At lc14 (currentT128, includingR9DD), inverse16384 and expanded
65536/16640 are unchanged: no gain by this guarded mechanism. NTT lengths
are not context lengths. Summed warp32-byte-sector requests are not physical
traffic/cachemisses/time; no bytes/capacity/transforms/masks/commitments or
proof arithmetic removed. Added index/shared-bank costs remain unknown.
CPU M has fixed4096 domain,50rows nonDD/52DD, and no accelerator route;
small size alone does not make the CUDA sketch applicable. Prior large-NTT
negative and fixed16-lane shared-bank1->2 concern are preserved.

Final619 independent integer/address/request checks:16 lane/profile entries,
160 role/phase rows,13 distinct transform geometries,444 boundaries,nine wrong
controls. Every tile enumerated in tested rows; rows0/1 and aligned8bytebase
sensitivity checked. Source audit933 assertions/64fragments/48rejected fragment
mutation controls/16unchangedpins. These are model/source checks, not native
NTT/value/transcript/refusal/proof validation. Probe3.850s/20,620KiB,onecore/
thread/nice19; audit0.284s/23,424KiB;59sCPU/alarm,60sparent,512MiBAScaps,
64MiBestimate. Initial counts retained before adding explicit census fields.
Seed270536706; exactcommands/sourcehashes/hardware/limits in experiment.

Actual seam: private ntt_rows/ntt_rows_view -> k_ntt_p1 firstloadloop.
Prior uncompiled sketch remains unchanged. Non-hiding DIF/DIT and CPU M are
separate. S-1/P-3 Tab/log_cols guards, original owners, all fresh masks/salts/
pads and one-opening schedule stay intact. Owner needs actual role/context/
phase incidence, SASS/shared/cache/exclusive/enclosing clocks, then a locked
native A/B only if justified; full parity/refusal/receipt and independent
verification/current gates owed. Delete-all-load ceiling<=1/(1-f),f unknown;
sketch narrower plus overhead. At unchangedT128 no request saving/possible
added cost; no numeric full-model GPU speed prediction. Reject any mismatch
or enclosing regression. All-elevenFZCcompiler A/B remains higher priority.

Seven LIVE primary records plus a prior-assessment correction: zkLLMPoT
Oct6/v2Oct11 covered-operator scope; DeepProve May26 licensing commit fullSHA
inspected, May15releasecommit body Cachemiss, restrictive LagrangeLicense;
Expander AGPL3 text/testdataJan21 metadata, commit fetchInternalError.
Older Caulk+2022/957 is absent from starting591recordledger: receivedJuly25,
lastrevisionOctober10,2022, authorpostAugust1; subsetsizequadratic/table-
independent author claim is a filter for our256table, not a saving. Subset
size is not total repeatedquerycount. PDF403, noimplementation inspected.
cq and LogUp-GKR refreshed with primary revisiondates. MLElookup2024/1058
already assessed0046/0068: exactURLaudit corrected initial NEW label, with
original record preserved; publisherdate2025-01-09 reconciled, PDFInternalError.
No author timing or externalcode reproduced. ExactURLs/dates/license/commit
and failure scopes retained in source-records.json. Ledger591->599 (seven
primary records plus one correction),19ranked hypotheses; topthree unchanged.

Carried CPU nonDD8B T128/L32 one16threadpass,GPUoff,total478.737s=
0.267370positions/s; prove_run393.785 includes witness98.348/load17.595;
seal84.824 overlaps accounting; receipt922,711,264B; freshverify42.709+
load13.681,recheck34.395+load10.739. Not rerun/reverified. Startupfraction,
steady slope and isolatedserialization unknown. New fullproofs/passes/
positions0/0/0; actualmodelcontext/device none; everynew fullstackclock,
startupfraction,steady/totalrate unmeasured. No longprefill,residentpass or
decode. Private8B>=50/s on5090/anothernamedhighendGPU unachieved; larger
workloads allowed; longercontexts may add quadratic attention. R9N-r9-a/b,
DDprivacyowed and narrowD33scope remain. No privacy weakening or mask reuse.

[Experiment](experiments/pcs-small-ntt-census-20261020/README.md),
[handoff](handoffs/20261020-pcs-small-ntt-census.md).
Next LOCAL: public per-domain H helper-word/lookup-multiplicity census atR9
trainedDD/nonDD; distinguish tinypublictable inversecache from recurringprivate
commitments and cost LogUp-GKR extra rounds/finalopenings before prototype.
Next OWNER: completehighendGPU clocks/verifiedresident1/2/4/8 and FZCcompiler
A/B before conditional smallNTT. Onlyresearch excludingruntimewritten; no
production/Git/build/GPU/install/externalwrites/messages/purchases/escalation.
Reports do not establish external delivery.

## Cycle 0103 — recurring private U8 helpers versus fraction-tree storage (2026-10-20)

Run `20261020T111854Z-3f58f916`. **No proving speed improvement measured.** Refined question:
after DD, does recurring helper data still justify a private GKR replacement,
and can original column structure avoid a larger-memory fraction tree?
Frozen R9 public norm-window 32 / fE 9 fixture matches the owner's T128
A/H/U8 counts for both models, DD/non-DD. COUNTED ONLY 8B T512 matches the
unregistered owner anchor. Norm windows 32/33/40 and sigma 16->17-bit
boundaries are sensitivities, not calibrated profile admission. The newer
fidelity LOW layout is outside this frozen R9 census.

8B T128 non-DD/DD: U8 helper data 420.25/390.25 MiB per block, 88.707/85.911%
of H input and 46.727/45.135% of A+H input including reserved rows. D/F
136/160 MiB remain unchanged by DD. At counted T512: 2480.5/1760.5 MiB;
83 ordered original U8 columns at T128, 85 at T512. Logical data counts
are not net removable bytes, physical traffic, proof bytes, capacity or time.
Fractions exclude M, endpoints/boundaries, encoded expansion, tree/scratch.
Private H data recurs every block/pass. The existing 256-entry U8 reciprocal
cache is fresh-alpha/gamma dependent, per attempt, never cross-pass setup.

Useful negative: full global fraction tree about 4 GiB at T128; exact column
forest 3.096/2.885 GiB non-DD/DD, still larger than the helper data removed.
At counted T512, global 32/16 GiB and exact forest 18.254/13.098 GiB before
scratch. Tiny explicit trees independently confirm 2*leaves-1 node counts.
One-column/adjacent-level storage is smaller but is not whole GKR fit:
retained or recomputed reductions, ordered A links, masks/CFS/PCS sites,
refusals, scratch and launches remain unpriced. Literal three Fp2 products
and one addition per internal node is not an optimized lower bound.
Per-domain tables require new bound local histograms; duplicating the
native global histogram is unsound. The forest retains one original table.

Validation: 1098 checks / 46 fixtures / 13 controls,
including 120 tiny F65537 direct-inverse versus fraction-tree cases. Audit:
1381 checks, 34 source fragments and 34 mutation controls, 624
altered-census controls, 160 explicit topology checks and five unchanged
pins. One CPU thread/core 0, nice 19; 59 s CPU/alarm, 60 s parent, 512 MiB AS,
64 MiB estimate. Probe 0.008066 s / 16,248 KiB RSS;
audit 0.019911 s / 16,336 KiB. Seed 20261020103.
No native Rust/GKR/CFS/transcript/refusal/receipt validation. An initial
join-count assertion used 2k instead of k internal root joins and failed;
source/logs and prior results retained. Duplicate parameter cases removed.
No owner source changed.

Actual seam: R9 shape::lookups_per_position/helpers/h_plane_doms/claim_sites,
layout::lookups_at/P-3/HIds, argument::helper_sum/SC_TAB/SC_DD,
protocol::u8_denominator_inverses/write_h/logup_sum_claim/H commit. JSON
census plus tiny fraction oracle only; no native patch ready. Hypothetical
gross U8 H deletion adds ordered A links, one committed global histogram,
all unused/table denominator refusals, degenerate (0,0) exclusion, fresh
masks/CFS/PCS sites and a new joint-view argument. Prior unmasked-root
and weak-leaf negatives remain binding. Unknown exclusive affected time
fraction f gives free-deletion ceiling <=1/(1-f); byte shares do not give f.
Reject binding/refusal/privacy failure or added cost exceeding avoided work.

Six LIVE primary records appended 599->605; twelve queries retained.
LogUp-GKR refreshed (received 2023-08-27, revised 2025-02-20). Newly screened
older flookup 2022/1447 is absent from starting ledger (received 2022-10-23,
revised 2024-04-22, CC0 paper, PDF Internal Error). Table independence does
not itself address the native 256-entry cache. OpenVM-zorch issue44 July24
natural-width/unroll and capture negatives refreshed; author timings not
reproduced. 5087bfa is reported short metadata only; commit/license fetches
returned Internal Error. Stwo main LICENSE Apache-2.0 inspected; short
commit c1bf3e1 version metadata diff inspected, full SHA/date unavailable.
Rendered v1 release July18 lacks a year/loading errors, never called latest;
official 2.0 announcement January27,2026 noted. zkLLMPoT October6/v2October11
covered-operator scope refreshed. No external code executed. Twenty ranked
hypotheses retain whole-GPU/resident work, DD context scaling and actual
capacity/phase clocks as top three; all-eleven FZC compiler A/B remains
higher priority than protocol redesign. Sources and limits are recorded in
[primary records](experiments/lookup-helper-census-20261020/source-records.json).

Carried CPU non-DD 8B T128/L32, one 16-thread pass, GPU off: total478.737 s =
0.267370 positions/s; prove_run393.785 includes witness98.348/load17.595;
seal84.824 overlaps accounting. Receipt922,711,264 B; fresh verify42.709+
load13.681, recheck34.395+load10.739. Not rerun/reverified. Startup fraction,
steady slope and isolated serialization unknown. New independently verified
full-stack proofs/passes/positions0/0/0; actual context/device none; all new
full-stack clocks/startup/steady-total rates unmeasured. No long prefill,
resident pass or decode. Larger workloads allowed; attention can grow
quadratically. Private 8B>=50/s on5090/another named high-end GPU unachieved.
R9 N-r9-a/b, DD privacy gate owed, D32 fidelity and narrow D33 R7 scope retained.

[Experiment](experiments/lookup-helper-census-20261020/README.md),
[handoff](handoffs/20261020-lookup-helper-census.md). Next local: mixed-height
forest lifetime/recomputation ledger, one histogram, all ordered columns,
independent tiny roots and wrong-site/multiplicity controls before any private
protocol prototype. Next owner: complete GPU phase/capacity clocks, verified
fixed-context resident1/2/4/8 and all-eleven FZC compiler A/B under locks.
Only research excluding runtime written; no Git/build/GPU/install/external
writes/messages/purchases/escalation. Reports do not establish delivery.

## Cycle 0104 — private fraction-forest lifetime and recomputation (2026-10-20)

Run `20261020T121854Z-ee6ad7b9`. **No proving speed improvement measured.** Refined rank7:
can a mixed-height forest avoid the prior materialized-storage negative
without ignoring recomputation? Ten frozen R9 w32/fE9 public fixtures retain
one global histogram and all ordered U8 columns. They exclude the newer LOW
fidelity proposal. The owner R11 report separates counted sizes from modeled
time; none of those proposals is a new proof or privacy acceptance.

At 8B T128 non-DD/DD, materialized fraction storage is 3170.016/2954.016 MiB,
versus U8 helper data 420.25/390.25 MiB. One initial root reduction followed
by one-column full reconstruction uses at most 128.006 MiB of arithmetic
arrays, with nearly 2x fraction-tree internal work and 2x leaf generation.
Retaining top12 depths gives 84.766 MiB at 6.676/6.677x internal work and
8.663x leaves; roots only gives 64.005 MiB but 18.663x work and 20.663x leaves.
Top16 gives 390.016 MiB at 2.870/2.885x work. At COUNTED ONLY T512, one-column
needs 512.006 MiB; top12 needs 277.266 MiB at 9.275/8.884x work. No T512
profile/proof admitted. Symbolic large arrays were never allocated. Ratios
compare constructing one fraction forest, not the native H writer or proving.
Bounds exclude A/model, other H/M, GKR folds/scratch, masks/CFS/PCS, commitment
encoding/trees, transfers and launches. Net memory/time/actual fit is unknown.

`plan(sizes,b)` counts retained top caches, one service array and DFS frontier.
`serve` reduces blocks for each lower layer; tiny tests retain output copies
for comparison. Their RSS is not a production streaming-memory measurement.
The 84 private root pairs / 83 original ordered A links at T128 are semantic
obligations, not 84 public messages or 83 required PCS openings. Actual new
mask/claim/PCS site counts are null until the protocol is designed. Preserve
one histogram committed before challenges and all denominator refusals.
Wrong-site permutation preserves a fractional root while changing ordered
leaf binding. Prior unmasked-root and weak-binding negatives remain binding.

Probe: 959 checks, 116 tiny cases, nine controls. Independent audit: 5641
checks, 1500 cost mutations, 1000 tiny column services, 30 mixed-height direct-
inverse roots and five unchanged native source pins. Synthetic F65537, not
native Fp2. Controls include dropped multiplicity, duplicated histogram,
zero denominator with zero multiplicity, degenerate(0,0), fresh challenges
and fixed-floor stacking. Initial singleton construction had zero internal
nodes, causing a reporting division by zero; corrected to null, with source
and failure retained. No production defect inferred. One thread/core0,
nice19; 59 s CPU/alarm, 60 s parent, 512 MiB AS, 64 MiB estimate. Probe
0.066202 s/16284 KiB; audit 0.165969 s/14980 KiB. No native Rust/GKR,
transcript, refusal, receipt, CFS or privacy validation.

Eleven LIVE queries yielded eight primary records, appended 605->613. Newly
screened older Virgo2019/1482: received 2019-12-24, revised 2020-07-16, paper
CC BY. Masked GKR plus terminal delegation is not native compatibility.
Refreshed Chimera (July7 / October16 revision), StateSync (October10),
LogUp-GKR and Sparrow (October11 received / October14 approved,2024).
New zorch issue362 (July2) reports fixed-floor stacking and runtime RAM blowup;
author evidence only. SP1 issue112 (June17 / closureJune18) includes later
corrections to fusion/padding diagnoses. Repository README states Apache2;
license/raw/source/commit/release fetches failed as recorded. Short53d8dfb
is reported metadata only; no inspected SHA or verified latest release.
No external code executed or author performance reproduced. The rotating
queue retains NTT/commitments, sumcheck/GKR, lookups/softmax, memory,
amortization, quantization/arithmetic and composition. Owner priorities stay
full GPU clocks/resident work, DD scaling, actual capacity and FZC compiler A/B.

Baseline: recurring original U8 helpers. Hypothetically eliminated work is
gross U8 H data/processing only under a reviewed replacement. Added costs:
all fraction construction/recomputation, leaf generation, ordered A links,
one histogram, refusals, reductions, fresh masks/CFS/PCS, transfers and
launches. With affected exclusive time fraction f unknown, even free deletion
has ceiling <=1/(1-f). Counts cannot supply f or a GPU rate. Falsify on changed
binding/exactness/refusal/privacy/soundness or added complete-proof cost
exceeding avoided work. Actual seam: frozen R9 shape lookup/helper/site counts,
layout::lookups_at, argument::helper_sum/SC_TAB and protocol::u8_denominator_
inverses/write_h/H commit. Research interface only; no Rust patch ready.
Main/Claude reviews and integrates any future candidate.

Carried CPU non-DD 8B T128/L32, one16-thread pass, GPU off: total478.737 s
=0.267370 positions/s; prove_run393.785 s encloses witness98.348/load17.595;
seal84.824 s overlaps. Receipt922711264 B; fresh verify42.709+load13.681 s,
recheck34.395+load10.739 s. Not rerun/reverified. Startup fraction, isolated
serialization and steady slope unknown. New independently verified full-stack
proofs/passes/positions0/0/0; actual model context/device none; all new proof
clocks, startup/fraction, steady/total rates unmeasured. No long prefill,
resident passes or decode. Private8B>=50/s remains unachieved. Larger workloads
allowed; attention can grow quadratically. R9 N-r9-a/b, DD privacy gate,
D32 fidelity, D33's frozen-R7 scope and D34 remain. Only research excluding
runtime written; no production/Git/build/GPU/install/external writes/messages/
purchases/escalation. Reports do not establish external delivery.

[Experiment](experiments/lookup-forest-schedules-20261020/README.md),
[handoff](handoffs/20261020-lookup-forest-schedules.md). Next local: per-column
checkpoint/rebuild frontier under an explicit layer-consumer contract before
selecting storage or protocol. Next owner: full GPU phase/capacity clocks,
verified resident1/2/4/8 and all-eleven FZC compiler A/B under shared locks.

## Cycle 0105 — explicit lookup layer-consumer capacity (2026-10-20)

No proving speed improvement measured. The key refinement is to include the
chosen consumer's immutable child and five mutable fold/equality arrays in
the lookup recomputation ledger. This changes the one-column T128 figure
from128.006MiB (arithmetic only) to208.005MiB, with nearly2x tree construction
work. The prior result remains valid within its stated exclusion.

This is a cost-accounting and
tiny arithmetic experiment at a prospective private U8 lookup seam.

The useful negative is that cycle0104's arithmetic-only schedule explicitly
excluded consumer folds. Once one concrete dense consumer is specified, a
regenerated layer of width w retains 32w bytes of immutable fraction pairs,
four independent Fp2 fold arrays totaling32w bytes, and an equality array8w
bytes. Its selected contract therefore needs72w bytes before checkpoints.
At 8B T128 the largest width is2^21, giving144MiB; at COUNTED ONLY T512 it
is2^23, giving576MiB. These are **contract-specific**, not universal GKR
lower bounds, native peaks, VRAM fit, net savings or time measurements.

The baseline remains frozen R9 normwindow32/fE9/cap32, excluding the newer
LOW fidelity proposal. Original U8 H data420.25/390.25MiB at T128 nonDD/DD;
all other H/M, A/model, commitment encoding/trees, masks/CFS/PCS, transfers,
allocator behavior and launches are excluded from these modeled peaks.
Actual mask/claim/PCS-site counts stay null until a private protocol exists.

| T128 8B schedule | Modeled arrays MiB, nonDD / DD | Tree construction work versus one materialized forest, nonDD / DD | Leaf generations versus one build, nonDD / DD |
|---|---:|---:|---:|
| Full forest + consumer | 3250.018 / 3034.018 | 1.000 / 1.000 | 1.000 / 1.000 |
| Global top12 + consumer | 164.768 / 164.768 | 6.676 / 6.677 | 8.663 / 8.663 |
| Per-column top12 + consumer | 144.255 / 144.255 | 7.676 / 7.677 | 9.663 / 9.663 |
| Per-column top16 + consumer | 148.005 / 148.005 | 3.870 / 3.885 | 5.664 / 5.664 |
| Full one-column rebuild + consumer | 208.005 / 208.005 | 2.000 / 2.000 | 2.000 / 2.000 |

All global roots/joins persist; the ledger conservatively also keeps roots
inside top caches, so some root bytes are duplicated. Forest caches persist
across all columns. Per-column mode reduces all roots first, then reconstructs
one column's checkpoints and consumes it before the next column. That adds
one entire tree build compared with global caching; lower-layer regeneration
adds more. A common cache depth is swept, not a globally optimal adaptive
allocation. A full one-column rebuild is208.005MiB atT128 and832.005MiB at
countedT512, compared with prior128.006/512.006MiB figures that excluded folds.
AtT512 top12 global597.268MiB; percolumn576.255MiB, with10.275/9.884x
treework. No T512 profile or proof is admitted by this count.

The model counts fraction-node construction and leaf generation separately
from the consumer. It also records five-plane scalar fold updates (same
for every schedule), but does not count every consumer multiply/launch or
claim an optimized field-operation lower bound. Work ratios are **not**
ratios to native H generation, full GKR, complete proving, or elapsed time.

`consumer.py::serve(read,n,b,p)` supplies immutable complete child layers.
`consume(child,point,challenges,lambda,p)` allocates four independent fold
planes and one equality plane, folds in place at fixed capacity, and checks
the cubic arithmetic `eq*(aL*bR+aR*bL+lambda*bL*bR)`. The reference evaluates
the original MLEs by explicit Boolean basis sums and checks parent claims,
all degree3 sample rows, interpolation and terminal values. TinyF65537 only.
Challenges are synthetic test inputs; this is unmasked arithmetic with no
Fiat-Shamir or private GKR claim, no cross-layer reduction/PCS completion.
The test harness retains reference outputs; its RSS is not the modeled peak.

Final validation: **1515** probe checks, **51** tiny column services,
**183** layer consumers, **12** controls. Independent audit: **480** randomized
allocation schedules, **1440** altered-cost controls, **80** direct-basis
consumer cases, **80** alias controls and **five unchanged native source pins**.
Controls cover wrong-site permutation surviving a root, ordered binding,
zero denominators even at zero multiplicity, fresh challenges, omitted folds,
reconstruction cost, altered sample/terminal, equality bit order, duplicated
histogram and changed multiplicity. The ordered digest is a test detector,
not a proposed privacy-preserving commitment. No native refusal/privacy test.
Validation was refined after a successful initial pass to include independent
arithmetic trace rejection and all cache-cut dominance comparisons; no failed
experiment or production defect occurred. Commands retain both run entries.

```text
python3 experiments/lookup-layer-consumer-20261020/run_bounded.py probe.py
python3 experiments/lookup-layer-consumer-20261020/run_bounded.py validate.py
```

Seed20261020105 (audit20261020106). One CPU thread, first allowed core,
nice19; 59s CPU/alarm, 60s parent, 512MiB address-space caps; estimated64MiB.
CPU Intel(R) Core(TM) Ultra 9 185H, WSL2; accelerator not invoked.
Probe 3.665034s / 20808KiB RSS;
audit 0.319388s / 15404KiB RSS.
Large arrays were never allocated; Fp2 byte counts are symbolic.

Baseline potentially removed: only recurring original U8 helper data and
its processing under a reviewed replacement. Added costs are every fraction
build/rebuild, leaf generation/source access, five-plane folds, ordered A
links, one global histogram, every refusal and fresh private masking,
CFS/PCS, whole-run soundness and terminal binding. A free-deletion ceiling
is <=1/(1-f) for affected exclusive elapsed fraction f; f is unknown, and
the candidate adds work. No numeric high-end GPU throughput ceiling follows.
Reject binding/exactness/refusal/privacy/soundness failure or a regression in
complete workload elapsed time. A smaller budget falsifies this chosen
consumer, not all possible streaming GKR designs.

Eight LIVE queries produced eight primary records (613->621), with exact
access/date/license/commit/fetch scope in `source-records.json`. Recent
[Chimera](https://eprint.iacr.org/2026/1388) revisionOctober16 is a different
field/backend schedule lead; [SP1v6.9.0](https://github.com/succinctlabs/sp1/releases/tag/v6.9.0)
releaseOctober10 and version commit b8387fa61e1361d90ee7de49f551863418ca0f08
were inspected. The full version commit changes the toolchain, not the NTT
optimization source. [Hobbit](https://eprint.iacr.org/2025/1214), already
screened via USENIX, prices stream access and trades proof/verification size
against memory. Newly screened [SP1-zorch182](https://github.com/fractalyze/sp1-zorch/issues/182)
is an author scheduling negative; no timings reproduced. The
[companion streaming repo](https://github.com/logannye/space-efficient-zero-knowledge-proofs)
explicitly retains full-vector opening paths. [Stwo's README](https://github.com/starkware-libs/stwo/blob/dev/README.md)
reports its development migration; destination release loading limitations
are recorded. No latest-release or code-update inference from crawl dates.
No external code executed or paper performance reproduced.

Twenty ranked hypotheses remain in `hypotheses.json`; top three remain full
GPU phase clocks plus verified fixed-context resident1/2/4/8, DD scaling
after T128 null, and actual capacity/exclusive clocks. All-eleven FZC compiler
A/B remains ahead of this protocol redesign. Lookup rank7 now includes the
consumer negative and reconstruction cost. The rotating queue retains NTT/
commitments, sumcheck/GKR, lookup/softmax, memory traffic, amortization,
quantization/arithmetic and composition; it is not a paper-count objective.

Actual Rust seam: frozenR9 `protocol.rs::u8_denominator_inverses/write_h`,
`shape.rs::lookups_per_position/claim_sites`, `layout.rs::lookups_at`,
`argument.rs::helper_sum/SC_TAB`. No Rust/CUDA patch is ready. Every root and
intermediate stays private; retain one committed global histogram,83 ordered
U8 column links atT128/85 atcountedT512 and original denominator/refusal
policy. No new public roots, mask reuse or weaker binding. R9N-r9-a/b,
DD privacy gate, D32fidelity and narrow D33/D34 scopes remain.

New independently verified complete-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. The CPU experiment clocks below measure research checking only.
No long-context prefill, repeated resident-model pass or decode was performed.
Larger workloads are allowed; increasing context can add quadratic attention.
Private 8B >=50 proved positions/s on RTX5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s has overlapping subwork and is not an exclusive extra witness clock.
Receipt922711264B; fresh verification42.709s + public load13.681s;
recheck34.395s + load10.739s. Startup fraction, isolated serialization and
steady slope unknown. This baseline is not a high-end GPU result.

Next local: test transferring a freshly regenerated child directly into its
four mutable planes, keeping ordered source access and checkpoint ownership
explicit, plus symbolic equality instead of its dense plane. Compare against
the immutable consumer under identical tiny polynomial/refusal controls;
include regeneration/source work and capacities. This is a separate contract,
not permission to overwrite original private A or retained checkpoints.
Next owner: complete GPU phase/capacity measurements, verified resident1/2/4/8
and all-eleven FZC compiler A/B under shared locks. Main/Claude reviews any
integration; no merge here. Only research excluding runtime was written.

## Cycle 0106 — owned lookup-layer buffers and factorized equality (2026-10-20)

Cycle0106 — `20261020T141854Z-e43b78d7` — 2026-10-20 UTC.
**No proving speed improvement measured.** The selected regenerated-layer
consumer can drop its extra immutable child representation and dense equality
plane. This reduces modeled arrays, while preserving expensive source work.

For child width w, four Fp2 fold planes need32w bytes. Regenerated values are
written directly into those planes. A retained checkpoint is copied and stays
immutable. Equality is a challenge-prefix scalar times two suffix factor
tables, built in fixed final capacity with no division. At maximum T128 width
2^21 this is64MiB of planes plus24KiB factor tables before caches/roots.
The prior regenerated-layer contract needed144MiB. This is a different,
explicitly tested ownership contract, not a native peak or universal bound.

| T128 8B schedule | Prior MiB | New MiB | Tree work, nonDD / DD | Leaf generations |
|---|---:|---:|---:|---:|
| Global top12 |164.768|84.792|6.676 /6.677|8.663x|
| Per-column top16 |148.005|68.029|3.870 /3.885|5.664x|
| Full one-column cache |208.005|192.029|nearly2x|2x|

Both DD/nonDD have the same modeled peak in these schedules. The full-cache
plan saves only16MiB because its immutable cache cannot be consumed in place.
Per-column top16 copies21,365,424 scalar Fp2 values from checkpoints across
all layers; those copies are counted. Tree/leaf ratios compare one fraction
forest build, not native H writing or elapsed proving. No tree/leaf work was
removed relative to cycle0105. Roots-only needs64.029MiB but19.663x treework
and21.663x leaves at nonDD T128. This remains an expensive memory tradeoff.
At COUNTED ONLY T512, top16 is260.052MiB versus580.005MiB, at6.309/5.931x
treework; full-column768.052MiB versus832.005MiB, atnearly2x work.
No T512 profile/proof admitted and no large arrays allocated.

Ten frozenR9 w32/fE9/cap32 fixtures exclude the newer LOW fidelity proposal.
Counts omit original A/model/source storage, all other H/M, private GKR
masking/CFS/PCS, encoded commitments/trees, transfers, allocator backing,
device launch costs and concurrent owners. Actual new mask/claim/PCS site
counts remain null. Net complete memory/time and actual device fit are unknown.
The prototype retains reference objects; its RSS does not measure the modeled
streaming peak. The symbolic model assumes consumed owners are dropped before
the next service. Provenance labels are test contracts, not Rust ownership or
a security boundary. Four fixed-capacity planes remain until layer completion.

Baseline potentially removed is recurring original U8 helper data/processing
only after a reviewed protocol replacement. The chosen experiment removes
child copies and equality storage within a prospective consumer. Added costs
include every ordered source access/regeneration, checkpoint copy, fraction
node, equality factor table/product, fold and terminal claim, histogram,
original denominator refusal and fresh private proof machinery. Equality-table
entry/product counters are algorithmic counts, not optimized field instructions
or GPU clocks. If affected exclusive time fraction f is unknown, even free
deletion has ceiling<=1/(1-f); no numeric complete GPU rate follows.
Falsify on any original binding/exactness/refusal/privacy/soundness failure,
hidden retained-child requirement or slower complete workload. Capacity beyond
the selected model falsifies its contract accounting, not every GKR schedule.

Final probe: 3383 checks, 68 tiny column services,
244 layer consumers and 11 controls. Independent audit:
260 allocation schedules, 1300 altered-cost controls,
90 direct original-MLE cases and 9 unchanged sourcepins.
Original MLE values, all cubic sample rows, interpolation, terminal values and
folded plane values match the prior immutable consumer and explicit Boolean
basis reference. Ordered sources are read as full0..n-1 scans; caches and
original leaves are unchanged. Controls reject borrowed/aliased/reused buffers,
zero denominator at zero multiplicity, altered sample/terminal/equality order,
and changed histogram; wrong-site permutation still survives a root, so its
ordered binding is required. Zero equality factors and0/1 challenges need no
inversion. F65537 tiny arithmetic only; no native Fp2, GKR, transcript,
receipt, CFS/PCS, privacy or native refusal validation.

Commands (seed20261020106, audit20261020107):
```
python3 experiments/lookup-owned-consumer-20261020/run_bounded.py probe.py
python3 experiments/lookup-owned-consumer-20261020/run_bounded.py validate.py
```
One thread, core0, nice19; 59s CPU/alarm,60s parent,512MiB address-space cap;
estimated64MiB. Intel Core Ultra9 185H /WSL2; accelerator not invoked.
Probe21.745664s /33928KiB; audit0.360016s /15872KiB.
Initial successful result retained; fixed-capacity equality generation and
explicit generator reference release were added and probe/audit re-passed.
No failed experiment. All commands and hashes retained.

Ten LIVE queries refreshed primary dates/releases; ten records appended to
the621-record ledger. Newly screened older[CTY11](https://arxiv.org/abs/1109.6882)
has a streaming verifier; this does not establish a low-memory private prover.
The new[author tensor discussion](https://www.fractalyze.io/blog/flock-without-writing-a-kernel)
supports factorizing equality while disclosing narrower timing scope.
[Efficient-sumcheck design](https://github.com/compsec-epfl/efficient-sumcheck/blob/main/docs/design.md)
distinguishes source access and caller terminal binding; its rewrite is
Unreleased. License/ownership-commit fetch failures and short metadata are
retained; no inspected full commit this cycle. [Chimera](https://eprint.iacr.org/2026/1388)
October16 revision and[SP1v6.9.0](https://github.com/succinctlabs/sp1/releases/tag/v6.9.0)
October10 release refreshed. The algebraic-geometry primary fetch remains
blocked, with dates unverified here. No author timing or external code run.
Exact access/date/license/fetch scope is in source-records.json/search-log.json.

Twenty hypotheses retained in hypotheses.json; rank7 now includes ownership,
checkpoint-copy and source-work evidence. Top three remain complete GPU clocks
with verified resident1/2/4/8, DD larger-context scaling after T128 null, and
actual capacity/exclusive clocks. All-eleven FZC compiler A/B remains ahead.
Rotation: sumcheck/GKR and memory this cycle; next rotate batching/amortization
and commitments, retaining lookup/softmax, quantization/arithmetic, NTT and
composition. Paper counts are not progress measures.

Rust seam: frozenR9 protocol.rs::u8_denominator_inverses/write_h,
shape.rs::lookups_per_position/claim_sites, layout.rs::lookups_at,
argument.rs::helper_sum/SC_TAB. Proposed owned layer interface in handoff;
no native patch ready. All roots/intermediates remain private. Keep one global
histogram committed before challenges,83 original ordered U8 links atT128
(85 atcountedT512), every denominator refusal, fresh masks and full terminal
binding. No mask/opening reuse or privacy weakening. R9N-r9-a/b, DD privacy
gate owed, D32 fidelity, narrow D33 and D34/D35 scopes remain.

New independently verified full-stack proofs / passes / positions: **0 /0 /0**.
Actual model context/device: **none**. New witness/proof/serialization/verification
clocks, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. Research CPU clocks measure checking only. No long-context
prefill, repeated resident-model pass or decode performed. Larger workloads
remain allowed; attention work can increase quadratically with context.
Private8B >=50 proved positions/s on RTX5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one16-thread CPU pass, GPUoff. Total478.737s =
0.267370positions/s; prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verification
42.709s + public load13.681s; recheck34.395s + load10.739s. Startup fraction,
isolated serialization and steady slope unknown. This is not a high-end GPU result.

Next local: test a bounded tiled first-round consumer that combines ordered
regeneration with a small fold prefix, and explicitly prices subsequent source
rescans/reconstruction. Compare all original-MLE sample rows and terminal
values under0/1/nonbinary challenges. Reject any plan that loses the full
ordered leaf relation or silently reuses private openings. Do not assume the
64MiB whole-layer arrays are a universal streaming-GKR lower bound.
Next owner: complete GPU phase/capacity clocks, verified fixed-context
resident1/2/4/8 passes and all-eleven FZC compiler A/B under shared locks.

Only research excluding runtime written. No production/Git/build/GPU/install/
external writes/messages/purchases/escalation. Main/Claude reviews integration;
no merge here. Saved reports do not establish external delivery.

[Experiment](experiments/lookup-owned-consumer-20261020/README.md), [handoff](handoffs/20261020-lookup-owned-consumer.md).

## Cycle 0107 — budget-adaptive tiled lookup prefix (2026-10-20)

Cycle0107 — `20261020T151854Z-beab78ce` — 2026-10-20 UTC.
**No proving speed improvement measured.** A budget-adaptive tiled consumer
improves the selected lookup-array memory/work tradeoff relative to streaming
every regenerated layer. This is unmasked arithmetic and a capacity model,
not a native private proof or measured device memory.

The consumer emits a complete cubic sumcheck row before accepting its global
challenge. For q early rounds it revisits the full ordered source q times,
then makes one more scan to materialize four independently folded residual
MLEs. A tile uses only preceding challenges. The degree-two bracket is
N_left*D_right + N_right*D_left + lambda*D_left*D_right, weighted by the
equality MLE, so the sampled row is cubic. Folding aggregate products instead
of the four original MLEs is rejected. No rounds, masks or openings are removed.

| Schedule, frozen R9 8B T128 | Modeled MiB | Tree nodes, nonDD / DD | Leaves, nonDD / DD |
|---|---:|---:|---:|
| Prior owned reference | 68.030029 | 3.870021x / 3.884890x | 5.664335x / 5.664165x |
| Fixed one streamed round | 36.022217 | 5.740043x / 5.769782x | 9.328671x / 9.328330x |
| Adaptive 32MiB destination cap | 36.022217 | 3.870021x / 3.884890x | 6.027740x / 6.054142x |
| Adaptive 16MiB destination cap | 20.018311 | 4.051723x / 4.079879x | 6.754551x / 6.834098x |
| Adaptive 8MiB destination cap | 12.014404 | 4.505980x / 4.567351x | 8.450441x / 8.556499x |


These are ratios to **one fraction-forest build**, not native H writing or
elapsed proof time. Scratch-aware q0 is68.030029MiB versus cycle0106's narrower
68.028503MiB; this cycle includes explicit temporary tiles, value-stack,
message/scalar allowance. Equality factor tables have fixed final capacity
and require no inversions, even at0/1 challenges. Direct equality products
were retained as a differential control; final streaming uses the prior
factorized equality tables, preserving its total table-entry count.

The adaptive32MiB destination threshold streams **nine leaf-layer services**
only. It adds18,874,368 original leaf reads: +6.4157%/+6.8850% over the
nonDD/DD q0 schedules. Tree-node and scalar-fold counts remain unchanged.
At a leaf layer regeneration has no internal tree nodes. Fixed q1 instead
streams every uncached layer and increases treework to5.740/5.770x; it is a
useful dominated schedule, not the recommended default. Adaptive16MiB saves
more arrays while adding internal recomputation and folds. Cached children
stay immutable and are copied exactly as in the prior consumer.

At COUNTED ONLY T512, adaptive32MiB destination gives36.022461MiB, versus
q0 260.053711MiB, but treework rises6.308577->7.459015x nonDD and
5.931400->6.799875x DD. Leaf work rises8.272625->12.538831x and
7.881293->11.307475x. The8MiB request with qmax4 misses its destination cap
and is explicitly flagged false (peak20.018555MiB). These are unregistered
T512 fixtures, not admitted profiles, allocations, proofs or throughput.

Ten public frozenR9 w32/fE9/cap32 fixtures are retained. The latest MVP_STATUS
fidelity-oriented LOW proposal changes layout and is excluded. Counts omit
original A/model/source storage, other H/M, private GKR masks/CFS/PCS, encoded
commitments/trees, device backing/allocator growth, transfers, launches and
concurrent owners. New mask/claim/PCS site counts are null. The symbolic
schedule is conditional on releasing each owner before the next service;
its value-stack allowance is not a compiler or native allocation bound.
The harness retains reference arrays; CPU RSS is not this modeled peak.

Final probe: 2934 checks, 225 tiny consumers,
14 controls. Independent audit: 240 randomized
cost schedules, 1680 cost mutations, 70 original Boolean-basis
cases, causal scan-boundary checks and9 unchanged source pins.
All cubic rows, interpolated claim chain, terminal values and four original
MLE evaluations match the independent reference and prior owned consumer.
Controls cover wrong-site permutation surviving a root, changed original
leaf/order/point, guessed challenges, source drift between scans, altered
samples/terminal, zero denominator at zero multiplicity, invalid prefix,
missing challenge and the incorrect aggregate-product shortcut.
F65537 tiny arithmetic only; native Goldilocks Fp2, masking, Fiat-Shamir,
receipt verification, privacy and native refusal equivalence remain untested.

Commands (seed20261020107, audit20261020108):
```
python3 experiments/lookup-tiled-prefix-20261020/run_bounded.py probe.py
python3 experiments/lookup-tiled-prefix-20261020/run_bounded.py validate.py
```
One CPU thread, first allowed core, nice19;59s CPU/alarm,60s parent,
512MiB address-space cap, estimated64MiB. Intel Core Ultra9 185H /WSL2;
accelerator not invoked. Probe 2.304326s /31796KiB;
independent audit 0.095858s /16308KiB.
Initial direct-equality version is retained. Successful passes were refined
with factorized equality, adaptive public budgets, source-drift control and
an explicit unmet-cap flag; final probe/audit pass. No failed experiment.

Baseline potentially removed is only selected recurring U8 helper work after
a reviewed protocol replacement. This experiment removes full-width arrays
inside that prospective consumer. Added costs include every source scan,
regenerated node, checkpoint copy, prefix reconstruction, fold, equality
evaluation, original ordered-A terminal link, global histogram, original
refusal and fresh private proof machinery. If f is the unknown exclusive
affected time fraction, even free deletion has speed ceiling<=1/(1-f), before
these new costs. No numeric complete high-end GPU rate follows. Falsify on
any original binding/exactness/refusal/privacy/soundness mismatch, hidden
retention/scan requirement, missing cap, irrelevant capacity cliff or slower
complete workload. A violated capacity model rejects this selected schedule,
not every possible streaming GKR construction.

Eleven LIVE queries produced eight primary source/disposition records,
ledger631->639. Existing [Plonky3 source](https://docs.rs/p3-sumcheck/latest/src/p3_sumcheck/strategy.rs.html)
uses resident table slices; its streaming tail is not a one-scan oracle.
The [rc.2 release](https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.2)
lists fused bind/measure and source-layout work; its full version commit
fe5e46d755b8a7d9069778361e21b33e5978b377 changes Cargo versions only.
Direct PR/pinned-source/history fetch failures and documentation/release
version differences are retained. Apache2.0 license text inspected; no
optimization diff pinned or external code run. Release month/day renders,
exact year/update timestamp unverified in this cycle.
Newly screened [2012 GPU GKR](https://arxiv.org/abs/1202.1350), revised
February22,2012, keeps the circuit in host memory and two layers on device,
including transfers in its author timings; old hardware gains do not transfer.
[Chimera](https://eprint.iacr.org/2026/1388), revised October16,2026, supplies a
different-backend chunk-to-resident method, not a reproduced gain here.
Hobbit,2024/524 and Fold-DCS are explicit refreshes, not new discoveries.
Exact dates, URLs, access limits, license and commit scope: source-records.json.

Twenty ranked hypotheses retained; top three remain whole-GPU clocks plus
verified resident1/2/4/8, DD larger-context scaling and actual capacity/exclusive
clocks. Rank7 now prefers budget-adaptive streaming over fixed q. Native
FZC compiler A/B remains ahead of this protocol redesign. Rotation retains
NTT/commitments, sumcheck/GKR, lookup/softmax, memory, amortization,
quantization/arithmetic and composition; next emphasize commitments.

Rust seam: frozenR9 protocol::u8_denominator_inverses/helper_inverses_u8/write_h,
shape::lookups_per_position/claim_sites, layout::lookups_at,
argument::helper_sum/SC_TAB. Research patch: tiled.py, probe.py, validate.py.
All roots/intermediates stay private, one global histogram is committed before
challenges,83 original ordered U8 links atT128/85 atcountedT512 remain required.
Do not treat root equality or semantic link counts as native binding or actual
mask/claim/PCS sites. Fresh randomness and restricted openings remain; no mask,
opening or cross-challenge inverse reuse. R9N-r9-a/b, DD privacy gate, D32
fidelity and narrow D33/D34/D35 scopes are preserved. No Rust patch ready.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; increasing context can increase attention work quadratically.
Private 8B >=50 proved positions/s on RTX 5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verification
42.709s + public load13.681s; recheck34.395s + load10.739s. Startup fraction,
isolated serialization and steady slope unknown. This is not a high-end GPU result.

Next local: port this consumer to exact native Goldilocks Fp2 arithmetic
with a synthetic ordered U8 reader using the same per-attempt denominator
cache/refusal rules. Differentially check every original helper term, all
sample rows and terminal MLEs, including zero denominators at zero multiplicity.
Keep source arrays immutable; never cache inverse results across challenges.

Next owner: complete GPU phase/capacity clocks and verified fixed-context
resident1/2/4/8 workloads, DD context scaling and all-eleven FZC compiler A/B
under shared locks. Count only independently verified complete receipts and
retain fresh masks. Main/Claude reviews any integration; no merge here.

Only research excluding runtime written. No production/Git/build/GPU/install/
external writes/messages/purchases/escalation. Saved reports do not establish
external delivery.

[Experiment](experiments/lookup-tiled-prefix-20261020/README.md), [handoff](handoffs/20261020-lookup-tiled-prefix.md).


## Cycle 0108 — native Fp2 ordered U8 consumer prerequisite (2026-10-20)

Run `20261020T161854Z-f0b8edce`. **No proving speed improvement measured.** The prior tiled
fraction-tree consumer now uses the native Goldilocks quadratic extension
Fp[u]/(u²−7), rather than F65537. Every helper, sampled cubic row and terminal
MLE in the tested scope matches a source-pinned native Rust field/helper
reference and independent original Boolean-basis oracle.

Main10386checks,3168 helper entries,100tiny consumers/40native resident-layer
cases,16controls. Independent1766checks:96 exponent inverses,40 original-MLE
fixtures,164native affine/wrapping values,all256 zero table-denominator sites,
28additional consumers including256-row table,6pins/3source mutations and
4overflow controls. Total128unmasked consumer cases; no masked protocol.
Shapes2..64 looked leaves/depth<=5 and256-row table/depth8, prefixq<=4,
0/1/non-base challenges. Original source/order and q+1 rescans checked.
Probe0.313142s/19016KiB; audit2.924653s/17392KiB;
dependency-free native-reference build0.423489s/136596KiB.
Intel Core Ultra9 185H/WSL2, first allowed core/nice19, one CPU worker/codegen
unit;59sCPU/alarm,60sparent,512MiBAS; probe/audit estimate64MiB/build256MiB.
Successful earlier stages preserved; no failed experiment or external code run.

Useful negatives: the256-entry reciprocal cache ALREADY exists per attempt.
An absent byte whose denominator is zero accepts in a looked column that
does not contain it, but later refuses at the global table even with m=0.
Skipping that row changes the refusal domain. All256 placements checked.
Stale cache across changed challenge fails. Naive unbounded Lk arithmetic
differs from native wrapping i64 on four overflow fixtures; these are dishonest
witness controls, not profile admission. Root-preserving wrong-site swap still
changes original MLEs. LSB consumer to native MSB binding remains unimplemented.

Refined rank7: generate original ordered leaves through immutable synthetic
A/affine descriptors and a fresh denominator table (4KiB payload if retained
beside inverse cache). This avoids prospective looked-column materialization
and repeated byte-denominator arithmetic, but removes no production work.
Source scans/regeneration/folds/equality, full table refusals, all83/85 ordered
links, one global histogram, original pad constraints and private masks/CFS/PCS
remain. Do not move refusal/RNG/draw/absorb order or reuse private masks/openings.
Previous68.030->36.022MiB selected-array result is carried evidence only;
no native net-memory, device fit or speed claim. If f is unknown exclusive
affected time, free-deletion ceiling<=1/(1-f) before all new costs. Falsify on
binding/exactness/refusal/order/privacy/soundness drift, hidden retention/PCS
cost erasing savings, absent capacity cliff or enclosing slowdown.

Thirteen LIVE queries/11records639->650. LogUp-GKR and ChimeraOct16 refreshed;
Plonky3 field polynomial, equality/mask PRs and rc2 release scope inspected.
No new external commit diff successfully inspected; failed files/commit fetches
and inconsistent release-list/cache views retained. Older newly screened
OpenSSLNTRU2022 section2.2 shows batch inversion already present natively;
ECC2K2012 abstract/PDF403 retained as a field/hardware applicability blocker.
Prior mu-seek/Jolt/LogUp assessments retained, not labeled new. Verified date,
license, access and claim/reproduction scope in source-records.json. No author
performance or private-proof guarantee reproduced. Twenty hypotheses retained;
top3 wholeGPU+resident1/2/4/8, DDcontext scaling and complete capacity/clocks;
all-eleven FZC compiler A/B remains ahead of protocol redesign.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks below measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; longer context can increase attention work quadratically. The complete
private 8B target of >=50 proved positions/s on RTX 5090 or another named
high-end GPU remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verify42.709s
+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown. This is not a high-end GPU result.

Build a source-pinned claim/mask/PCS site ledger for a prospective private
fraction-tree replacement: both child branches per layer, all83/85 ordered
original U8 links and one global table. Make the LSB consumer to native MSB
point mapping explicit. Reject count-preserving wrong-site merges; keep
unknown private costs unknown before making a net-memory or time claim.

Owner next: complete GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and the all-eleven
FZC compiler A/B under shared build/heavy locks. Retain fresh masking and count
only completed, independently verified full-stack receipts.

Only research excluding runtime written; no production/Git/GPU/install/external
writes/messages/purchases/escalation. R9N-r9-a/b, DDprivacy gate, D32 fidelity
and narrow D33/D34/D35 remain; LOW layout excluded. Main/Claude reviews,
no merge. Saved reports do not establish delivery.

[Experiment](experiments/native-fp2-u8-consumer-20261020/README.md),
[handoff](handoffs/20261020-native-fp2-u8-consumer.md).

## Cycle 0109 — ordered fraction-tree sites and native point mapping (2026-10-20)

Run `20261020T171854Z-0041295d`. **No proving speed improvement measured.**

The baseline is frozen R9 U8 helper data, carried as420.25MiB nonDD /
390.25MiB DD at8B T128. No native proof work was removed. A reviewed fraction-tree
replacement might eliminate those helpers, but adds every source scan, tree
operation, fold, original-A/table link, mask, CFS functional, PCS group, encoding
and transcript/refusal obligation. Existing per-attempt inverse caching is retained.

This ledger counts **semantic evaluation obligations, not actual PCS sites**.
For the unbatched candidate topology, every layer returns both N,D on both child
branches. At the leaves, looked-U8 numerators are public1; their denominators
depend on ordered original A. The single global256-entry table has private
histogram numerators and public denominators. T128 has166 looked-column branch
links +2 histogram links =168 unmerged original-A obligations. Actual native
Ids, mask pairs, extension rounds, CFS coefficients and opening groups remain
null. These obligations can be reduced only by a separately reviewed protocol,
not by equating equal counts or reusing a private opening.

If **all** private intermediate/leaf terminals each retain a fresh native pair
at the current T128 row width2^14, reserved BASE-field mask rows alone total
1527MiB nonDD /1509MiB DD. Formula: C *2rows *2^14words *8B. Even only168 leaf
sites would add42MiB under that same conditional rule. These are conditional
payload subcosts for a naive contract, not universal lower bounds or measured
peaks. Intermediate fractions are challenge-derived, so appending them to the
original pre-challenge A commitment is not an implementation. New commitment
timing/lifetimes and an integrated masked recursion need their own design.
This rejects the naive all-intermediate native-pair approach as a memory win;
it does not reject GKR generally or establish a net leaf-only saving.

The prior36.022MiB selected-array model still omits private protocol costs and
is not repriced as native memory. If f is the unknown exclusive affected time
fraction, even free deletion has speed ceiling<=1/(1-f), before added costs.
There is no numeric complete-GPU throughput prediction. Falsify on original
binding/exactness/refusal/RNG-order/privacy/soundness drift, omitted capacity,
no relevant device capacity cliff or slower complete workloads.

Main: 2715checks,105 complete tiny layer consumers,420 branch/component
point checks,834 tiny original-A affine-expression links and4 zero-table-lift
cases, up through the native T128 row width2^14. Seventy-seven control instances
cover11 families. Every cubic row, parent claim chain and original MLE terminal
matches independent Boolean-basis arithmetic. Challenges include0/1 and non-base
Goldilocks Fp2. Unmasked arithmetic only; synthetic leaf sizes2..64, depths1..6.

Independent audit: 29703checks; all834 descriptors are reconstructed by a
restricted interpreter of the pinned Rust lookups_at source and its frozen
shift constants, then matched in original order across10 public count fixtures.
It independently checks834 tiny affine links,126 MSB half-fold values, four
saved ledgers and all14 source pins. Three in-memory native descriptor mutations
preserve counts but change the binding and are detected. No external code ran.
The symbolic plane names are not numeric native Ids or captured native claims.
Fixtures use w32/fE9 and frozen requantization shifts; they are not real trained
export captures, and exclude the newer LOW fidelity proposal.

Adjacent children2j+b map from LSB row challenges rho to native MSB
reverse(rho)||b. Merging with an internally supplied eta gives reverse(rho)||eta;
the next consumer's LSB parent point is eta||rho. Eta is only an unmasked
arithmetic fixture, not an approved new native transcript draw. Reversing the
whole point, moving the branch to the front or swapping original sites fails.
Native terminal-extension/mask axes are outside this data-axis adapter.
The table lift requires the product of(1-high_coordinate) over zero-pad axes;
omitting that factor fails. Roots alone still permit wrong ordered-source swaps.

Probe 4.375987s /48304KiB RSS;
audit 1.987379s /37176KiB.
One worker, first allowed core0, nice19,59sCPU/alarm,60sparent,512MiB address
space; estimated64MiB. Intel Core Ultra9 185H /WSL2; no GPU, native build or
dependency install. Seed20261020109; independent audit uses deterministic
source interpretation and saved fixtures. These are diagnostic research clocks.
The first audit failed because its parser searched a comment after stripping
comments; exact logs and script are retained in failed-audit-source-boundary/.
The corrected brace-boundary parser passes. Earlier successful stages and the
refinement to a unique count-preserving site permutation are retained.

Ten native LIVE queries;11 primary source/disposition records appended650->661.
New [OpenVM SWIRL implementation](https://github.com/openvm-org/stark-backend/blob/main/docs/cuda-backend/gkr-prover.md)
and [input-consistency documentation](https://github.com/openvm-org/stark-backend/blob/main/docs/interactions.md)
separate tree checks from original trace expressions and PCS/WHIR. The inspected
CUDA revert excerpt motivates the new reversible-storage question; its generic
revealed roots/claims cannot be published by this private construction. Main's
MIT terms were read; source/update/full-commit alignment is unverified. Release
v2.0.1 advertises pinned host pools and phase peaks, but month/day render without
year and commit fetches fail. No latest-version/date inference or speed adoption.

New older [Virgo++](https://eprint.iacr.org/2020/1247), received2020-10-09 /
revised2021-05-19, targets unlayered circuit padding; that benefit is not shown
for this already layered tree. Full primary PDF403; author repo license body /
history cache misses retained, MIT only advertised there. Prior LogUp-GKR,
ZK-sumcheck2017 and streaming-ZK2024 assessments are refreshed, not called new.
[Chimera](https://eprint.iacr.org/2026/1388)'s October16 revision and resettable
randomness October8 revision keep whole-proof clocks and fresh masks in scope.
Boolean-GKR primary abstract withdraws an earlier Keccak end-to-end comparison
after a circuit-size error; no author speed was used. Dates, exact URLs, license,
fetch/commit limits and claim/reproduction scope are in source-records.json.

Twenty-one ranked hypotheses retained: top3 whole-GPU+verified resident1/2/4/8,
DD context scaling after T128 null, and actual capacity/exclusive phase clocks.
All-eleven FZC compiler A/B stays ahead of protocol redesign. Rank7 is refined
by this mask-budget negative; rank21 adds reversible storage with inverse and
capacity costs. Rotation covered sumcheck/GKR, memory and composition; next
rotate batching/amortization and NTT/commitments, retaining lookup/softmax and
quantization/arithmetic. Source counts are not proving progress.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, repeated resident-model pass or decode was performed. Larger workloads
remain allowed; attention work can increase quadratically with context. The
complete private 8B target of >=50 proved positions/s on RTX 5090 or another
named high-end GPU remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verify42.709s
+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown. This is not a high-end GPU result.

Next local: test reversible fraction-tree storage against an independent
immutable native-field tree. Recover both N,D at every layer using preserved
right children, keep source order explicit, and count inversions/batch scratch,
leaf-buffer capacity and avoided rescans. Include zero denominator at zero
multiplicity and original ordered-A terminal checks. The OpenVM source is a
lead, not imported code or a private proof design. Do not revisit a full protocol
replacement until its private input-consistency/claim-reduction design is reviewable.

Owner next: complete GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and the all-eleven
FZC compiler A/B under shared build/heavy locks. Retain fresh masking and count
only completed, independently verified full-stack receipts.

Only research excluding runtime written; no production/reviewer/instruction/
Git/GPU/install/external writes/messages/purchases/escalation or merge. R9N-r9-a/b,
DD privacy gate, D32 and narrow D33/D34/D35 scopes remain. Main/Claude reviews
integration. Saved reports do not establish message delivery or supervisor liveness.

[Experiment](experiments/private-fraction-site-ledger-20261020/README.md),
[handoff](handoffs/20261020-private-fraction-site-ledger.md).

## Cycle0110 — reversible fraction tree: exact, full-column capacity negative (2026-10-20)

Run `20261020T181854Z-27090273`. **No proving speed improvement measured.**
Baseline: frozenR9 U8 helper data420.25/390.25MiB(nonDD/DD) at8B T128;
prior prospective adaptive consumer36.022216796875MiB selected arrays and
6.028/6.054x source leaves. No production work removed. Original-A, global
histogram, private recursion, fresh masks/CFS/PCS and native phase costs remain.

Parent N=NL*DR+NR*DL,D=DL*DR. Preserve right child, reconstruct DL=D/DR,
NL=(N-NR*DL)/DR. The tested natural-order strided layout is different from
OpenVM's bit-reversed coalesced layout. A consumer must not fold retained tree
storage because future layers need its right children. Both N,D and the original
ordered child MLEs match independent immutable native-Fp2 tree arithmetic.

For n leaves: build3(n-1)Fp2mults/(n-1)adds; individual restoration3(n-1)mults,
(n-1)subtracts/(n-1)inversions; batch restoration6(n-1)-3log2(n)mults,
(n-1)subtracts/log2(n)inversions, maxn/2 prefixE elements. No inverse-output or
copied-denominator array. At2^21leaves retained tree64MiB versus immutable
nearly128MiB, but batch-prefix16MiB and separate consumer capacity must be added.
q0..4 selected peaks128.0234375/96.015625/80.01171875/80/80MiB. All exceed prior
36.022MiB; even64MiB tree alone does. This demotes the whole-column plan at that
budget, not reversible subtrees generally. Assumes prefix release/backing reuse;
sourceowners/caches/histogram/masks/CFS/PCS/allocator/driver/transfer costs excluded.

Symbolic sequential-column8B T128:84columns including one global table;
source leaves51937536/48398592(nonDD/DD), avoids261128448/244613376 generations
versus the prior adaptive model. Build155812356/145195524 Fp2mults; batch
restoration311620005/290386395mults,1569/1551inversions,51937452/48398508subtracts.
Counts only, no instructions/time. Existing256-entry per-attempt inverse caching
is baseline work, not a new saving. Native array/profile/full-proof benefit
unknown. Unknown exclusive affected fraction f gives free-deletion ceiling
<=1/(1-f) before added costs. Falsify on binding/field/refusal/order drift,
omitted capacity/no real capacity cliff, or slower complete workload.

Main2838checks/42trees/306unmasked consumers/768control instances; sizes2..256,
looked affine U8, table multiplicities including zero and full-extension leaves;
zero/one/non-base challenges. Two build/restore cycles per tree without reread.
Zero denominator at every tested placement refuses even for numerator0.
Root-preserving swaps change original ordered MLEs; wrongright/parent/aliasedfold
controls fail the reference. These are research controls, not native refusals,
privacy gates, numeric Ids, masks, GKR/CFS/PCS/transcript or saved-proof verification.

Independent5745checks/21fixtures/174layers/348MSBMLEs,16pins,2090capacity events,
30rejected capacity shortcuts and10symbolic forest profiles. Its own tuple-field
convolution/Fermat inverse/immutable forward tree/MSBfold and allocation events
compute expected values. Earlier passing audit before forest addition retained.
Probe28.352250s/17768KiB; accounting0.162193s/11460KiB; audit0.642078s/15808KiB.
OneCPUworker/core0/nice19,59sCPU/alarm,512MiBAS; probe/audit60sparent. Estimated
64MiB probe/audit/32MiB accounting; IntelCoreUltra9 185H/WSL2. Seed20261020110.
No build/GPU/dependency installation/downloadedcode execution; no failed experiment.

15native LIVE queries/9source records appended661->670. OpenVM docs/CUDA show
inverse-based reversal; MITbody inspected, main date/commit alignment blocked by
history/API fetch failures. v2.0.1 phase peaks/pinned pools refreshed, year/full
commit unverified. ICICLE fullSHA6c77775961b0e4dc2be359feec1ac11536c18043 is
version-only, not a kernel diff; MITbody inspected, date year unverified.
ChimeraOct16 and sumcheck2026/587 refreshed. Newly directly assessed older
Twist/Shout(2025-01-22,revised2026-10-17) supplies one-hot lookup alternative,
not a tiny-table/private-PCS fit. Jolt MITbody read, algorithm commit uninspected.
Prior DeepThought2024/325 composition screen refreshed, not called new.
New author issue71 retracts contention-inflated GKR ranking and preserves a
byte-exact scan regression. No author performance reproduced. Exact URLs,
dates/licenses/SHA/scope and PDF403/GitHub fetch/IEEErobot blockers retained.

22ranked hypotheses maintained; top3 ownerGPU+verified resident1/2/4/8,DDscaling,
complete capacity/exclusive clocks. All-elevenFZC A/B remains ahead of protocol
redesign. Rank21 refined by exact reconstruction and selected-budget negative;
rank22 adds one-hot/increments screen. Rotation covers NTT/commitments,
batching/amortization,sumcheck/GKR,memory,lookup and composition. Next rotate
quantization/arithmetic underD32 and private input-consistency/composition.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, repeated resident-model pass or decode was performed. Larger workloads
remain allowed; attention can grow quadratically with context. The complete
private8B >=50 proved positions/s target on RTX5090 or another named high-endGPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD8B T128,L32,one16-threadCPU pass,GPUoff; total478.737s =
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verify42.709s
+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown. This is not a high-endGPU result.

Next local: test a bounded reversible-subtree tile plus immutable frontier
under the prior36.022MiB selected-array budget, against an immutable native-field
tree and original ordered layer consumer. Charge tile rebuilds/frontier/prefix/
inactive fold tails and all source rereads. Check whether the existing fresh
per-attempt U8 reciprocal cache can remove last-layer inversion scratch without
uncounted source/lookup work. This is untested. Preserve full-column and naive
per-intermediate-mask negatives; do not claim a new private protocol.

Owner next: actual GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DDcontext scaling and all-elevenFZC
compiler A/B under shared build/heavy locks. Keep fresh masking; count only
completed independently verified full-stack positions. No owner job launched here.

Only research excluding runtime written; no production/reviewer/instruction/
Git/GPU/install/externalwrites/messages/purchases/escalation/merge. R9N-r9-a/b,
DDprivacy gate,D32 and narrowD33/D34/D35 scopes remain. No mask/opening reuse or
changed native refusal/RNG/transcript timing authorized. Main/Claude reviews.
Saved reports do not establish external delivery or supervisor liveness.

[Experiment](experiments/reversible-fraction-tree-20261020/README.md),
[handoff](handoffs/20261020-reversible-fraction-tree.md).

## Cycle0111 — disposable reversible tiles: matched-budget cost negative (2026-10-20)

Cycle0111 — `20261020T191854Z-93bbe548` — 2026-10-20 UTC; checkpoint2026-10-20T19:29:45.531119+00:00.

**No proving speed improvement found.** The disposable reversible-subtree
schedule passes exact arithmetic and ordered-consumer checks. At matched
frontier/consumer settings it has the same source rereads and the same selected
peak as direct subtree reduction, with extra build/recovery arithmetic. Demote
this schedule. This is a bounded operation/payload negative, not a universal
GPU timing result or a new private protocol.

The baseline is frozenR9 U8 helper payload420.25MiB non-DD /390.25MiB DD for one
8B T128 block layout. A prospective replacement already has a direct adaptive
frontier/tiled consumer at36.022216796875MiB of selected arrays. The last cycle's
whole-column reversible buffer requires80–128MiB selected storage at2^21 leaves.
No native helper, commitment or proof work has been removed in either study.

`Frontier(read,n,f,mode,leaf_inverse).layer(d)` retains immutable upper levels
through depthf. Belowf, direct mode reduces only the source subtrees required
for that layer. Batch mode builds a disposable leaf tile ofB=n/2^f, then reverses
it back to the requested layer. Every global message precedes its challenge;
discarded tiles must be rebuilt on the next scan. Cached mode uses current-
attempt U8 inverses only for original right leaves at the last expansion and
charges a separate original-source key evaluation per such inverse.

For one below-frontier scan at depthd, direct mode mixes n-2^d internal nodes.
Disposable tiles mix n-2^f nodes first, then recover2^d-2^f nodes. Thus the
extra construction alone is3(2^d-2^f)Fp2 multiplications, besides positive
recovery costs, while the source scan is identical. Smaller scratch is not
evidence of a saved scan. This tests natural-order strided storage; OpenVM's
bit-reversed/coalesced GPU layout is a separate untested implementation.

| One 8B T128 block forest, frontier depth 16 | non-DD | DD |
|---|---:|---:|
|Source leaf generations, every arm|313,065,984|293,011,968|
|Direct build Fp2 multiplications|602,998,017|564,069,633|
|Disposable tile build multiplications|890,832,129|834,209,025|
|Tile recovery multiplications|467,140,608|440,598,528|
|Tile recovery inversions|36,175,872|33,226,752|
|Cached recovery multiplications|378,667,008|357,433,344|
|Cached recovery inversions|30,277,632|27,328,512|
|Additional cache-key source reads|35,389,440|33,619,968|

Both non-DD/DD cases include84 columns, one global table and the preliminary
root-forest source pass. They model one block's lookup forest, **not32 complete
model passes or a32-layer execution**. Consumer folds/equality work is shared
between the three arms and is additional to these source-service counts.
The cache also adds unknown key evaluation, checking and lookup costs; it is
not fresh proof randomness and is never retained across alpha/gamma attempts.

All three arms peak at36.022216796875MiB selected payload at frontier16,
including immutable frontier/root forest, full resident capacities/inactive
tails, source tile, batch-prefix scratch, consumer tile, equality factors and
the prior scalar allowance. The largest column has2^21 leaves andB32. At
frontier15/B64, peak34.022216796875MiB in every arm, but source reads rise to
364,970,496 /341,377,536; the smaller frontier is available to direct reduction
too. Forty profiles (10 input geometries times4 frontier caps) compare all
three arms. Counts are symbolic; exact-capacity backing/release is assumed.
Original A/source owners, histogram/cache allocation, private masks/CFS/PCS,
allocator pools, driver memory and transfer costs remain excluded. No fit,
actual-device peak or enclosing runtime saving is established.

Even free deletion of an unknown exclusive affected fractionf of complete
proving has ceiling1/(1-f); this candidate adds costs and removes no measured
native work. There is no numerical complete high-endGPU forecast. Falsification
of the proposed scan-saving benefit is already observed: identical source
counts plus extra arithmetic at an equal peak. Revisit only a materially
different retention/algorithm or a measured GPU access effect. Cross-tile
batch inversion and alternative protocol scheduling are not tested here.

Validation: 3,470main checks,45synthetic fixtures over2..64leaves,
472unmasked cubic consumers, 592layers
and63negative controls. U8 affine leaves, table-style multiplicities including0,
full-extension fractions, zero/one/non-base challenges, ordered layer MLEs and
both numerator/denominator components are covered. Root-preserving swaps change
the ordered children; stale-attempt inverse reuse fails the reference; zero
denominators refuse even at zero numerator or absent looked-table value.
No native refusal/RNG/transcript order or private view has been validated.

Independent audit: 6,280checks,354consumers/444layers, Boolean MLE
and native MSB point reversal,528allocation events,22source pins and all10prior
profile counts. Expected values use tuple polynomial convolution and immutable
trees, with a separate cubic round evaluator and enumerated operation graph.
The direct arm exactly reproduces prior source and tree-work counts.
One initial audit failed on imported-snapshot pin bookkeeping: the local runner
was adapted at the pinned path and prior outputs had been renamed. Arithmetic
checks had passed. Original snapshots were preserved under corrected paths;
source hashes stayed unchanged and the rerun passes. Initial stderr and the
failed command are retained in `initial-audit-failure.json` and `commands.json`.

Main probe: 0.313116 s / 12,896 KiB RSS.
Symbolic accounting: 0.294192 s / 16,904 KiB.
Independent audit: 0.349016 s / 16,696 KiB.
Intel Core Ultra 9 185H, Linux/WSL2; one worker on first allowed CPU core,
nice19; each leaf has 59 s CPU/alarm, 60 s parent timeout and 512 MiB address
space cap. Estimated experiment memory64MiB. No native build, GPU job,
dependency installation or external code execution. These clocks time research
checking, not witness/proof phases or an old/new native benchmark.

12native LIVE queries /12source records appended670->682. Source scopes,
verified histories, exact URLs and access/license/commit limits are retained
in source-records.json and the append-only ledger. OpenVM release and streaming
sumcheck source were refreshed; current code timestamps/full commits were not
established. Two older leads first enter the ledger: NeutronNova group folding
(received2024-10-09,revised2026-08-18) and the Scorpius/Orion correction
(2024-07-18,revised2025-02-14). They motivate source-binding/repaired-PCS checks,
not a drop-in backend. Nova's MIT body was inspected; its NeutronNova source
fetch failed, and no commit was inspected. Hobbit's chunk-folding input-
consistency discussion was revisited. No author speed is reproduced.

The detailed September29 quantization paper separates QDQ utility simulation
and actual small-model proving; some attention/RoPE/reduction operators remain
floating in its utility evaluator. This sharpens the D32 exactness screen;
its large-model projection numbers are not complete private8B evidence.
Owner r11 already distinguishes F_P9->12 from finer S12 and models the latter
as incompatible with DD's cap. The next local question is to reproduce exact
public-table/cardinality counts, complementing the owned fidelity lane.

23ranked hypotheses retained. Top3 are completeGPU+resident workloads, DD
context/fidelity scaling and exclusive phase/capacity telemetry. All-elevenFZC
A/B remains ahead of lookup protocol redesign. Rank21 now includes this
disposable-tile negative; rank23 adds exact D32/DD public-cardinality work.
Rotation this cycle emphasizes memory, sumcheck/GKR, batching, quantization,
source binding and composition. Next emphasis: public arithmetic/cardinality,
then GPU NTT/commitment freshness and the owner whole-prover evidence.

New completed independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. Research device:
**Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and
verification clocks: **unmeasured**. Startup duration/fraction, steady-state and
total-workload proved rates: **unmeasured**. No long-context prefill, repeated
resident-model pass or decode was run. Symbolic T32/T64/T128/T512 fixtures are
cost studies, and T512 is counted geometry, not an admitted proof result.
Longer workloads remain allowed; dense attention may grow quadratically with
context. The complete private8B >=50 proved positions/s target on RTX5090 or
another named high-endGPU remains unachieved.

Historical diagnostic carried from the prior checkpoint, not rerun or
independently reverified here: non-DD 8B T128, L32, one 16-thread CPU pass,
GPU off; total478.737s =0.267370positions/s. prove_run393.785s includes
witness98.348s/load17.595s; seal84.824s includes overlapping subwork.
Receipt922,711,264B; fresh verify42.709s + public load13.681s; recheck34.395s
+load10.739s. Isolated serialization, startup fraction and steady slope remain
unknown. This is a historical CPU result, not a high-endGPU result.

Next local experiment: independently enumerate exact public exponential-table
outputs versus score resolution/f_e and include0 in the DD cardinality. Pin the
owner's r11 public table/count definitions; distinguish F_P output precision
from S12/finer exponential inputs. Check the cited32-entry cap and cost any
larger dictionary domain/limbs/lookups without admitting a new profile.
The owner already models S12 as DD-infeasible; reproduce the actual public
cardinality before carrying DD savings to a D32 fidelity configuration.
Avoid duplicating native implementation or model-quality/calibration jobs.

Owner next: whole-prover GPU phase/capacity clocks and independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and all-elevenFZC
compiler A/B under shared build/heavy locks. No such job was launched here.

Only research excluding runtime written. No production/reviewer/instruction/
Git edits, GPU/build/install/external writes or messages, purchases, escalation
or merge. D32 and narrow D33/D34/D35 scopes, DDprivacy gate and R9N-r9-a/b
remain binding. No mask reuse, repeated private opening, weaker privacy or
changed native refusal/transcript/RNG schedule is authorized. Main/Claude
reviews any integration; saved reports are not evidence of message delivery
or supervisor liveness.

[Experiment](experiments/reversible-subtree-frontier-20261020/README.md).


## Cycle 0112 — 2026-10-20 — exact S12/DD cardinality and larger public caps

Run `20261020T201854Z-91cdb36a`. **No measured proving improvement.** Read agenda, durable state/findings/source ledger, latest0111results and required project documents; retained their startup snapshots. Initial682 source records validated; now692. No production write or GPU/heavy job.

Question refined and tested: does finer softmax input precision make DD impossible in principle, or just exceed today's cap32? R11 already models the current cap failure. Exact enumeration gives S12 n_col156/94/55 at head_dim128, f_e9 and base e_s2/3/4 (actual e_s is base minus4), including0. Required power-of-two caps are256/128/64. At e_s0/1 the counts are370/248. All410 public arrays from15 existing exports reproduce their native256-entry generator and cardinalities6,8,11,14,19,24,32. No private trace statistics or model weights copied.

F_P and f_e must remain separate. F_P9->12/15 leaves table/cardinality and counted widths unchanged;16adds a third P limb. S12 changes the input grid and the statement. Higher f_e can independently increase the dictionary and softmax remainder widths. The theoretical513 limit at f_e9 is a bound, not an observed cardinality.

Complete R11 HIGH per-block COUNTED comparison, F_P12/f_e9:

| Geometry | Direct S12 HIGH | DD cap256 (base e_s2) | DD cap128 (base e_s3) | DD cap64 (base e_s4) |
|---|---:|---:|---:|---:|
| 8B T128 |152,256,512|167,133,184 (+9.771%)|156,647,424 (+2.884%)|151,404,544 (-0.560%)|
| 8B T512 |836,337,664|803,176,448 (-3.965%)|752,844,800 (-9.983%)|727,678,976 (-12.992%)|

Counts include A/H data, fresh mask rows and claim sites; they are not32-layer runs, proof times/bytes or fidelity results. T512 remains hypothetical. Even cap256 HIGH's803M words exceed old R9 non-DD's663M; do not carry the old20.8% reduction to this configuration. S12 alone saves4.875/12.275/15.975% atT512, a different denominator from full HIGH. T128 cap256/128 regressions are preserved. Cap>=T examples add costs.

Eliminated work is hypothetical per-score division limbs/U8 helpers moved to the dictionary. Native work actually eliminated: none. AtT512 fe9/FP12 there are10 dictionary A planes,7H pairs and11 byte lookups per dictionary slot; cap256 data payloads320MiB A/448MiB H;6extra claim sites require393,216 fresh mask words (3MiB). Total delta `-16*S +24*Dd +12*row_width` matches independent counting. T128 identity is `-12*S +20*Dd +12*row_width`. The wider public exp table fits R11's lifted table domain but still needs new loader/digest/lookup/profile implementation. Full transient allocation/backing/device transfer/PCS/histogram work is unmeasured; these payloads do not prove fit.

Probe486,630 checks/1,080 synthetic rows and7negative controls pass. Independent audit1,927checks,265,728entries via90-digit recurrence, key130-digit repeats,410 actual public arrays and16pins passes; min half-integer rounding margin~5.53e-5. Cost612checks includes four retained native phase-size anchors and exact R11 HIGH baseline rows. Probe0.308050s/15,928KiB, audit0.444542s/16,004KiB, count0.043956s/14,688KiB. One CPU worker, nice19, first allowed core; each <=60s,512MiB AS,64MiB estimated. Intel Core Ultra9 185H/WSL2. These are arithmetic/count studies; no native proof or timing reproduced.

Two initial accounting assertions failed: first omitted removed S U8 helper pairs and understated claim sites; second omitted S12's score-lookup effect on helper ceilings. Both code/logs retained; corrected identities pass. An initial startup snapshot referenced an absent prior audit-result filename and was corrected without altering prior evidence. No permission boundary was bypassed.

Nine LIVE queries/10records: precision/zkLLM exactness, known nonlinear digit decomposition (official PDF now accessible), October16 Chimera, DeepProve license/release interface, FLI and Locq. Newly screened older SIMD Spielman paper (received2025-12-22/revised2026-01-08) and MIT implementation are absent from starting ledger. Cache slicing is a methodology lead for a different CPU code-PCS, not native NTT replacement. SIMD PDF403, two algorithm-file cache misses/release cache miss and DeepProve docs robots denial recorded; no external code run or author performance reproduced.

24 ranked hypotheses retain prior negatives. Top3: whole-GPU plus independently verified fixed-context resident1/2/4/8; native DD context/fidelity scaling; complete phase/capacity clocks. All-eleven FZC owner A/B remains rank4. Tested precision/cap lead now rank5; new SIMD screen low priority. Unknown exclusive fraction f gives even free-deletion ceiling1/(1-f), before added costs. No numerical complete high-endGPU speed forecast.

Integration seam: native `tables_attn` generator/digest; `dd_e_column_of`; Shape caps, Dd/no-lift checks and P limb class; trained public table validation. Research-only implementation and copied count oracle under `experiments/public-exp-dd-cardinality-20261020/`. Handoff `handoffs/20261020-public-exp-dd-cardinality.md`; no native patch or merge. Next local: uniform versus per-layer public caps over a labeled32-layer schedule, counting masks, slot/receipt changes and actual payload lifetimes. Actual HIGH/S12 tables and D32 quality must first come from owner fidelity lane; existing e_s distribution is sensitivity only.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode was run. Synthetic row lengths 32/128/512 and counted T128/T512 geometries are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private 8B >=50 proved positions/s target on an RTX 5090 or another named high-end GPU remains unachieved.

D30 N-r9-a/b, DD privacy gate, D32 and narrow D33/D34/D35 scopes remain. No mask/opening reuse, weaker privacy or target change. Research-only writes excluding runtime; no instruction/reviewer/calibration/Git/production/receipt edits, GPU/build/install/external messages/writes/purchases/escalation. Saved reports do not imply delivery or supervisor liveness.


## Cycle0113 — 2026-10-20 — public per-layer dictionary caps: limited diversity and unchanged peak

Run `20261020T211854Z-71297104`; checkpoint 2026-10-20T21:30:19.165784+00:00. **No proving improvement measured.** Startup agenda/state/latest0112results, historical findings index,692-record ledger and required project documents read/pinned; early state checkpoint retained. Prior findings and negative results preserved.

Tested/refined question: can an entire-public-table cap per layer retain S12 DD savings more efficiently than one uniform cap? Baseline: owner R11 HIGH direct layout152,256,512 /836,337,664 words per8B block atT128/T512. Existing b7 schedule30e_s2/1e_s3/1e_s4 is only a sensitivity fixture; actual HIGH calibration tables are missing. Other synthetic schedules vary diversity; no private trace information used.

| Counted context | Public policy | A+H words, all 32 layers | Versus direct | Body receipt delta, B | Selected dictionary peak |
|---:|---|---:|---:|---:|---:|
| 128 | direct | 4,872,208,384 | +0.000000% | 0 | 0 MiB |
| 128 | uniform | 5,348,261,888 | +9.770795% | 85,254,144 | 160 MiB |
| 128 | layer | 5,322,047,488 | +9.232756% | 81,977,104 | 160 MiB |
| 128 | hybrid | 4,871,356,416 | -0.017486% | 697,952 | 40 MiB |
| 512 | direct | 26,762,805,248 | +0.000000% | 0 | 0 MiB |
| 512 | uniform | 25,701,646,336 | -3.965051% | -15,404,032 | 768 MiB |
| 512 | layer | 25,575,817,216 | -4.435215% | -23,268,592 | 768 MiB |
| 512 | hybrid | 25,575,817,216 | -4.435215% | -23,268,592 | 768 MiB |

AtT512 public per-layer caps remove another125,829,120 words (0.489576% versus uniform), with7,864,560 fewer projected body bytes, yet selected dictionary peak stays768MiB. Cumulative dictionary requests fall24,576->23,616MiB; neither sum nor mean is peak or actual VRAM. T128 per-layer DD remains a9.232756% regression. A public minimum-word hybrid uses31direct+1cap64 and saves only851,968words/0.017486%, while adding697,952 projected body bytes. With uniform exponents there is no per-layer benefit. Balanced/broad synthetic distributions show conditional larger benefits but provide no fidelity evidence.

Every HIGH DD layer adds6 A/H claim sites,12*row-width fresh mask words,3PCSgroups and1slot. Across32 DD layers that is48/96MiB extra A/H mask words atT128/T512 irrespective of cap. +2M encoded rows cost64KiB encoded and8KiB a-coefficient payload perDDlayer, plus fresh CFS coefficients and512base pads. T512caps64/128/256 have20/21/22mainDDrounds; smaller b7caps save only24base CFS draws versus uniform, not the A/H masks. Resident1/2/4/8 accounting repeats every per-proof cost. No mask/opening reuse.

Native work actually eliminated:none. Conditional receipt deltas use the R9 fixed wire skeleton and include messages,terminals,Mrows,A/Hrows andPCSgroups, matching its235,008B T128 DDdelta. HIGH/new stage metadata and degree/group/endpoint validity still need native review. The rows-only cost shortcut fails. Let f be unknown exclusive affected full-prover fraction; even free deletion has ceiling1/(1-f), before added costs. No numerical fullGPU rate forecast.

53,836probechecks/120syntheticrows/10negativecontrols PASS (1.777999s,18,720KiB). Independent8,915checks PASS (0.021773s,18,000KiB),90digit20,480publicentries,3,360independentpositions,4,096allocationevents,15sourcepins/9controls; Mrowbudget holds. An earlier successful audit is preserved before the Mbudget addition. One worker/nice19/first allowedcore;59sCPU+alarm/60sparent,512MiBAS,64MiBestimate. Intel CoreUltra9 185H/WSL2; no native proof. Copied inspected local R10/R11 code only, no downloaded scripts executed.

9LIVEqueries/10records appended692->702. Primary current ePrint/Chimera October16, ICICLE release/full tagcommit/MIT/pipelinecapacity, Qingming/GoldilocksNTT,cq,ringlookups refreshed. Older new MARLUT paper received2025-11-17/revised2026-04-13 and Rust artifact: three-partyMPC/distributedZK differs from native publicly verifiable Goldilocks. PDF403, two LICENSEbodycachemisses recorded; no bypass. MARLUT/yrrid MIT labels are not fulllicenseinspection. ICICLE full inspectedcommit6c77775961b0e4dc2be359feec1ac11536c18043; releaseyear unavailable, no date inferred. No author gain reproduced.

26ranked hypotheses retain all prior negatives. Top3 unchanged: wholeGPU/resident workloads, DD scaling/fidelity, complete phase/capacity clocks; FZC owner A/B4. Publiccap/mode5refined; next dyadic padding question26added. Review seams: Shape dd_cap/check_dd_geometry/slots/receipt_bytes, publicE loader, trainedstatement,RunStatement stage_shape/stage_layout/schedule_digest. Calibration API refuses plane-list changes; no new profile/native patch. [Experiment](experiments/public-layer-dd-caps-20261020/README.md), [handoff](handoffs/20261020-public-layer-dd-caps.md).

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode ran. Synthetic rows use lengths 32/128/512; counted layouts use T128/T512, 32 heads, head dimension 128 and 32 sequential layers. These are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private 8B >=50 proved positions/s target on an RTX 5090 or another named high-end GPU remains unachieved.

Historical CPU diagnostic, carried without rerun/reverification: non-DD 8B T128, 32 layers, one 16-thread CPU pass, GPU off; total 478.737 s = 0.267370 positions/s. prove_run 393.785 s includes witness 98.348 s and load 17.595 s; seal 84.824 s contains overlapping subwork. Receipt 922,711,264 B; fresh verify 42.709 s + public load 13.681 s; recheck 34.395 s + load 10.739 s. Isolated serialization, startup fraction and steady slope remain unknown. This is not a high-end GPU result.

Next local: Test a public dyadic dictionary partition against the proposed cap256: 156 distinct public outputs could occupy 128+16+8+4 slots per attention row instead of 256. First use synthetic direct-versus-sharded tuple/divmod checks and count every additional slot, fresh mask pair, PCS group, histogram and row-Sum binding. Check the no-lift premise for every shard; small shards may erase the gain. This is an untested new-profile idea, not authorization to alter native D30 or its privacy requirements. Actual HIGH/S12 tables must come from the owner fidelity lane before promotion.

Owner priorities remain whole-prover high-end GPU phase/capacity clocks and independently verified fixed-context resident 1/2/4/8 workloads, DD context/fidelity scaling, and the all-eleven FZC compiler A/B under shared heavy/build locks. No such job was launched here.

Only research excluding runtime was written. No production, reviewer, instruction, calibration, Git, receipt or safety-gate edits; no GPU/build/install, external writes/messages, purchases or escalation. Fresh masks/openings and D30 N-r9-a (row Sum/slot17/Ht), N-r9-b (M_dd in A before lookup challenges), the DD privacy gate, D32 and narrow D33/D34/D35 scopes remain. Main/Claude reviews and integrates; no merge. Saved reports do not establish external delivery or supervisor liveness.


# Cycle0114 — public dyadic dictionary union feasibility

Run `20261020T221854Z-d390b45f`, checkpoint `2026-10-20T22:28:41.218430+00:00`. Started22:18:54UTC; deadline22:38:54UTC. Prior cycle started21:18:54UTC; hourly limit respected.

**No proving improvement measured.** Read AGENDA, STATE, FINDINGS, all702source records, prior0113results and required project documents. Early STATE checkpoint and byte snapshots retained. Production remained read-only; prior findings/negatives preserved.

The leading feasible local hypothesis was refined from unused public cap padding. Split156 public E values across128+32 domains and keep one query helper over their union. Each shard keeps its own committed histogram and table helper, every table helper has sign-1 in the one value0 sum, and every division slot is constrained/inverted even when unused. No private routing or per-shard sum is published. This is a prospective new-profile interface, not a change to admitted R9.

At counted8B T512, HIGH/S12/f_e9/F_P12/base e_s2:

|Public partition|Committed A+H words/block|Versus single cap256|Versus direct HIGH|Selected dictionary A+H payload|
|---|---:|---:|---:|---:|
|256|803,176,448|0%|-3.965051%|768MiB|
|128+16+8+4|767,393,792|-4.455143%|-8.243545%|468MiB|
|128+32|766,607,360|-4.553058%|-8.337578%|480MiB|

An extra T512 shard adds11A+7H claim sites,36row-widths in fresh mask words (9MiB),3PCSgroups,1DDslot and2Mencoded rows. Exact156 positions save12MiB over160 but add18MiB in masks. Native no-lift requires cap>=4 atT128 or>=2 atT512; raw55=32+16+4+2+1 fails. Splitting248 outputs regresses at both contexts. AtT128 e_s2, the best128+32 choice remains+4.928441% versus direct; e_s4 keeps single64. These are useful negative findings.

For the existing30x e_s2 /1x e_s3 /1x e_s4 distribution, used only as HIGH sensitivity, T512 committed words25,575,817,216->24,466,554,880 (-4.337153% versus per-layer singles; -8.580006% versus direct). Selected dictionary peak768->480MiB. T128 sharded+4.649333% versus direct; public direct/DD choice is unchanged at only0.017486% fewer words. Actual HIGH calibration may change every exponent. Partial payload is not whole-device HWM; all other planes, masks, witness, PCS, histograms, pools, driver and transfers remain unmeasured.

Wire accounting includes fresh claim/mask rows, slots, terminals and PCS groups;32-layer conditional body delta versus direct atT512 is-40,092,272B. HIGH/new schema metadata and degree/group assumptions are not validated. No complete receipt was produced. Hypothetical eliminated work is unused dictionary slots, helper lookups and inversions; native eliminated work is zero. Extra masks, Sum reads, commitments, schema binding and challenge scheduling are added costs. The exclusive full-prover affected fractionf is unknown; even free deletion has ceiling1/(1-f), before new costs. No numerical50-token/s projection.

Validation: probe53,680checks/60synthetic rows/19,200query positions/16controls; independent audit8,128checks/20,480public entries by90-digit recurrence/3,360positions/13source pins. Both PASS. The audit imports no producer/vendor code, uses exact rational identities and enumerates the complete optimal distinct-power partition set. Seed20261020114; hardware Intel CoreUltra9 185H/WSL2. Probe0.146128s/17,640KiB; audit0.035228s/18,480KiB. Each child: one worker,first allowed CPU,nice19,59sCPU/alarm,60sparent,512MiBAS,64MiBestimate. These are research checking clocks.

The first audit failed on a flawed negative control: moving a count between two padded0 entries leaves the multiset unchanged. Initial source/stderr retained. Corrected distinct-value mutation rejects; final runs add full public-table hash, insufficient-support and no-lift API controls. Commands, final source hashes, dimensions and limitations are retained.

Eleven native LIVE queries/seven primary records appended702->709. Refreshed October16 Chimera and current OpenVM release/GKR integration, TaSSLE and LogUp-GKR. Newly assessed older Verifying Jolt zkVM Lookup Semantics (received2024-11-09,revised2024-11-20) supplies an independent semantic-validation methodology; no native redundancy or author speed reproduced. OpenVM MIT body and release commit362c7ad8c6b042b320471a137e3eadec7ec69a44 inspected; full release date unavailable. TaSSLE PDF403 and initial OpenVM LICENSE404 are recorded without bypass; LICENSE-MIT succeeded. Exact URLs/dates/license limits are in source-records.json. Source text was untrusted and never executed.

28ranked hypotheses retain prior negatives. Top3 remain whole-GPU/resident workloads, DD fidelity/context scaling and complete phase/capacity clocks; all-elevenFZC A/B rank4. Tested shard union is rank5; prior public per-layer cap work remains preserved at6. New semantic-validation and public-preprocessing/capacity questions are included. Rotation emphasized lookup, exact arithmetic, input consistency, composition and memory; next returns to GPU commitments/NTT and amortization.

Integration: Shape/Layout Dd domains/claims/slots, SC_DD/A_SUM slices, HIds/table signs, E-column loader, witness histograms and trained/run statement schedule binding. Research functions count/best_caps/shard_column and tuple checker are in probe.py; no native patch. Handoff: handoffs/20261020-dyadic-dd-shards.md. Native rank/NL-1/joint privacy, soundness/refusal, domain/no-wrap, metadata/challenge order and actual fidelity remain unresolved.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode ran. Synthetic row lengths32/128/512 and counted T128/T512,32heads,head_dim128,32-layer layouts are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private8B >=50 proved positions/s target on RTX5090 or another named high-end GPU remains unachieved.

Historical CPU diagnostic carried without rerun/reverification: non-DD8B T128,32layers,one16-thread CPU pass,GPUoff; total478.737s=0.267370positions/s. prove_run393.785s includes witness98.348s and load17.595s; seal84.824s has overlapping subwork. Receipt922,711,264B; fresh verify42.709s+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,startup fraction and steady slope unknown. This is not a high-end GPU baseline.

Next local: Read the current native CUDA PCS/NTT setup and public-cache call sites alongside prior pool/lifetime negatives. Count once-per-process versus per-proof root/twiddle/index preparation and retained capacity for fixed-context resident1/2/4/8 passes. Use an independent event oracle with cache-off, shape-change and eviction controls, charging fresh masks on every proof. If already cached or negligible, preserve the negative and rerank; launch no GPU/build work.

Owner priorities remain complete high-end GPU exclusive/enclosing phase and capacity clocks, independently verified fixed-context resident1/2/4/8 workloads, actual HIGH/D32 fidelity tables and DD context scaling, and the all-eleven FZC compiler A/B under shared build/heavy locks. No such job was launched here.

No production, reviewer, calibration, instruction, receipt, Git or runtime edits; no native build, GPU, installation, downloaded-script execution, external write/message, purchase or escalation. D30 N-r9-a/b, DD privacy gate, D32 and narrow D33/D34/D35 scopes remain binding. Every per-shard/per-proof mask and opening stays fresh; no security/profile acceptance is inferred. Main/Claude reviews and integrates; no merge. Saved reports are durable files, not evidence of external delivery or supervisor liveness.

Final evidence-integrity audit:443checks PASS; original702 source records and prior findings prefix preserved; agenda/project pins unchanged and sensitivity counts independently reaggregated. Finished UTC 2026-10-20T22:30:00.866956+00:00.


## Cycle 0115 — public coset leases after the NTT cache negative (2026-10-20)

Run `20261020T231854Z-2da27679`; checkpoint 2026-10-20T23:29:35.214325+00:00. **No proving improvement measured.**
Agenda, mandatory durable memory, 709-record ledger, latest 0114 results and project
instructions/status/decisions/active coordination were read/scanned and pinned.
Early and midcycle state checkpoints preserved; prior findings and negatives retained.

Question refined: does public PCS preparation still recur across fixed-context resident
proofs? GPU NTT roots/twiddles are already process-resident and monotonically growing;
the earlier cycle 0084 negative is confirmed in active/R9 sources. CPU NTT construction
is shared across all blocks in a run, not per block. Opening-index plans depend on current
transcript challenges; shape-only reuse is invalid. A different repeated object exists:
public coset powers at every hiding commitment, separately uploaded and, for deferred
GPU commitments, retained by ZkReenc. M builds its own CPU powers too.

Source-backed T128/L32 skeleton: 2 endpoints + 31 boundaries + 64 A/H hiding offers,
plus 32 CPU M commitments. Conditional on all main offers taking the GPU path,
public powers uploads 48.5 -> 0.5 MiB for one cached pass and 388 -> 0.5 MiB for eight
synthetic passes; host power builds 129/258/516/1032 -> 1. One-pass public loop words
6,488,064 -> 65,536. Every private pad/salt/mask/proof remains fresh. Salt generation
207,618,048 B per trace is unchanged; pad count sum(rows*q) not numerically censused.
No production work actually eliminated. These are incidence counts, not observed launches,
traffic, actual memory or time. Active GPU and reviewed R9 profiles are separately pinned;
no combined GPU admission or T512 profile assumed.

Selected deferred device public-powers peak 2.5 -> 0.5 MiB; fully resident peak unchanged
at 0.5 MiB. Add 0.5 MiB idle device retention and a separate 0.5 MiB host owner. These
exclude private data/pads, masks, PCS buffers, pooled/idle/driver and all other owners.
Evict-between-passes requires eight uploads. Immutable growth charges old+new overlap;
the 32+64 B control peaks at 96 B and eviction preserves outstanding leases.

Baseline/eliminated/added/ceiling: replace only repeated public powers generation/uploads,
adding full public identity, immutable lease/view lifetime handling, actual-size coset
validation and retained/growth capacity. CPU source loop includes a multiplication per
entry; this is not a compiled instruction count. Unknown exclusive affected fraction f
gives even free-deletion ceiling 1/(1-f). Resident workload slope and startup are unknown;
amortization cannot exceed context/recurring. Falsify on changed values/refusals/column
order/RNG consumption, stale identity, bad async lifetime, meaningful retained-capacity
regression, or no enclosing improvement. Cache is low priority pending exclusive clocks.

Probe 286 assertions, 192 synthetic rows, 7392
encoded positions and 15 control families PASS. Cache-on/off matches independent quadratic
interpolation/Horner. Independent explicit polynomial construction/evaluation and separate
live-lease oracle pass 92,531 checks, 50,240 events, 145 schedules
and 21 source/prior pins; no producer imports. Census 1442 checks/22 source
fragments PASS. Growth from a valid nn16 to invalid nn32 coset refuses; h=0 helper behavior
preserved without profile admission. Zero/one/monomial/field-edge rows, fresh pads/salts,
device/context/representation keys, immutable growth and eviction are covered. No native
leaf hashes/transcript/refusal/privacy gate or saved-proof verification was run.

Probe 0.393082 s/18,052 KiB RSS; census 0.211661 s/
84,740 KiB; independent audit 0.830058 s/72,684 KiB.
One worker, nice19, first allowed core; 59s CPU/alarm, 60s parent, 512MiB AS.
Initial 64MiB memory estimate was low for census/audit; corrected estimate 128MiB,
still well below cap. Initial passing results retained before tightening identity controls
and adding degenerate fixtures. Wrong source/module and prior audit filenames corrected
without touching prior artifacts. No native build, GPU or downloaded-code execution.

Six LIVE queries/nine primary records appended 709 -> 718. ICICLE official domain contract
(version3.0, updated2025-08-06), v4 release/full version-only commit/MIT body and October16
Chimera refreshed. Known hardware-comparison/on-the-fly GPU work retained. Newly screened
older OpenNTT paper received2024-10-24/revised2024-11-13 and FPGA artifact/MIT body were
absent from starting ledger; not a CUDA plug-in. PDF403, guessed v4 docs path inaccessible
and pinned ICICLE LICENSE cache miss recorded. MainMIT body inspected, release year and
OpenNTT commit/update date unverified. No author speed reproduced.29 ranked hypotheses
preserve all prior negatives; top4 unchanged, rank28 tested/refined, OpenNTT rank29 added.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: Intel Core Ultra 9 185H CPU, one worker, no GPU.
Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction,
steady-state and total-workload proved rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Counted T32/T64/T128, L1/L2/L32,
1/2/4/8-pass schedules and 192 tiny encoded rows are synthetic diagnostics, not proved positions.
Larger workloads remain allowed; attention can grow quadratically with context.
The complete private 8B >=50 proved tokens/s target on RTX 5090 or another named high-end GPU remains unachieved.

Historical CPU diagnostic carried without rerun/reverification: non-DD 8B T128,
32 layers, one 16-thread CPU pass, GPU off; total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s and load 17.595 s. Seal 84.824 s contains
overlapping subwork; do not add those clocks. Receipt 922,711,264 B; fresh verify
42.709 s + public load 13.681 s; recheck 34.395 s + load 10.739 s. Isolated serialization,
startup fraction and steady slope are unknown. This is not a high-end GPU baseline.

Integration seam: R9 core pcs::coset_powers/commit_zk_owned_with_tag,
mask_commit_tagged and device ZkReenc/dev_commit_zk_from. Larger cached host slices
cannot be passed whole because current GPU entry asserts pows.len()==nn. Exact prefix
views/lease signatures, raw capacity accounting and async completion require owner review.
No native patch/merge. D30 N-r9-a/b, DD privacy gate, D32 and narrow D33/D34/D35 remain.

Next local: inspect inverse-size scaling in actual private PCS commit/open kernels,
count repeated fixed public inversions separately from per-row multiplies and CPU/GPU
batch boundaries, then test a public scale table against independent Fermat inverses
and direct DFT. Preserve a negative if the count ceiling is negligible; launch no build/GPU.
Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident 1/2/4/8 workloads, DD fidelity/context scaling and the
all-eleven FZC compiler A/B under shared heavy/build locks. No such job ran here.

Only research excluding runtime written; no production/reviewer/instruction/calibration/
Git/receipt edits, native build/GPU/install/external writes/messages/purchases/escalation.
Saved reports do not establish delivery or supervisor liveness. Main/Claude integrates.
[Experiment](experiments/public-ntt-cache-incidence-20261020/README.md),
[handoff](handoffs/20261020-public-coset-lease.md).

Final evidence-integrity audit: 215 checks PASS across 67 experiment pins; prior 709 source records, prior findings prefix and first27 ranked hypotheses preserved; mandatory public documents unchanged. Finished UTC 2026-10-20T23:30:19.144717+00:00.


## Cycle0116 — 2026-10-21 — inverse-length scaling: exact small cleanup, GPU fusion already present

Run `20261021T001854Z-77f04b06`; checkpoint 2026-10-21T00:29:38.730899+00:00. **No proving improvement measured.**

Read AGENDA,current durable memory/source ledger718records,latest0115/0114results,
project CLAUDE/target/MVP/decisions/active coordination, and current CPU/CUDA seams.
The concurrent public decisions update is retained under end-read/ and listed in
concurrent-document-updates.json. D32 now records <=1.02x held-out perplexity and
zero refusals; >=98% LAMBADA is explicitly the coordinating session's reading of
Victor's 1–2% allowance. D37 adds the classifier/media-app product direction, owned
by the main lane. D33's token-lane frozen-r9 extension and D36's named TinyLlama
T32 CPU next-token acceptance do not cover native DD R9, 8B, GPU or accuracy-fix
profiles. Preserve D30 N-r9-a/b and the outstanding DD privacy gate. No ruling
or instruction was edited here.

CPU NttTables::inverse calculates one public1/n per row; GPU calculates one per
row-batch wrapper, with scale already fused in final store. Separately pinned
nativeR9,root and gpu-zerocheck copies agree: six definitions each (one benchmark,
five wrappers), not observed invocations. The proposed Goldilocks-only identity
`(2^k)^-1=p-((p-1)>>k)` holds exactly for0<=k<=32. A33entry/264B scale table is
also exact; closed form needs no table. Retain validation before shifts and all
row multiplies. No private preprocessing, pad/mask/salt or opening reuse.

Baseline: literal pow(P-2) costs127source-level field multiplies; compiler may
optimize them. Removed: that calculation per actual inverse invocation. Added:
guard plus public shift/subtract (or table costs). GPU launches/transfers/bytes
removed:0. Illustrative n16384,rate4,q256 CPU row-encode multiply share0.018895%;
inverse-only share0.096800%. Neither is a time bound. A4096row resident batch has
one host inverse; size1chunks have4096. Conditional T128/L32 resident commit
offers imply97inverses/pass,776over8passes, excluding openings/fallbacks. No
actual incidence, elapsed saving, admission, native memory peak or GPU rate.
Unknown exclusive elapsed fractionf gives only the free-removal bound1/(1-f).
Falsification: byte/refusal mismatch, compile-folded existing inverse, negligible
exclusive time or enclosing slowdown. This demotes inverse scaling to rank30.

Probe 515checks/200rows/6900encoded positions/15controls PASS. Census
381checks/144batch cases/36schedules/18definitions/5controls PASS. Separate
audit 1601checks/200rows/30CPUoverlap rows/144batch cases/36schedules/18pins
PASS; no producer imports. Euclid/Fermat, direct DFT and original polynomial
oracle agree. Probe0.126729s, census0.134015s,
audit0.404522s; maxRSS82684KiB.
One worker,nice19,first allowed core,59sCPU/alarm,60sparent,512MiBAS; estimated
64MiBprobe/audit,128MiBcensus. Seed202610210116. Source/Rust sketch/commands/logs
retained. No native NTT, mask, BLAKE3 leaf, transcript, receipt or verifier ran.

Nine LIVE queries/nine primary records append718->727. Dated cuPQC0.6Aug28 and
ChimeraOct16 refreshed. cuPQC custom p<2^62 excludes full Goldilocks despite
uint64 storage. Newly assessed older NTTFusion author pageOct6,2023 informs
stage fusion, already present for normalization (rank31). GPU-NTT and NVIDIA
sample/docs Apache2.0 bodies inspected; SDK license distinct. Commit429,
NTTFusionPDF InternalError and AG-skip inaccessible recorded without bypass;
unverified dates/commits null. No author performance reproduced. Prior29ranked
hypotheses and every earlier negative remain. Top4owner priorities unchanged.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: Intel Core Ultra 9 185H CPU,
one worker, no GPU. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic row lengths
1..32 and conditional T32/T64/T128, L1/L2/L32, 1/2/4/8-pass schedules are diagnostics.
Larger workloads remain allowed; attention can grow quadratically with context.
The complete private 8B >=50 proved tokens/s target remains unachieved.

Historical CPU diagnostic, carried without rerun/reverification: non-DD 8B T128,
32 layers, one 16-thread CPU pass, GPU off; total478.737s =0.267370positions/s.
prove_run393.785s includes witness98.348s and load17.595s. Seal84.824s contains
overlapping subwork; do not add clocks. Receipt922,711,264B; fresh verify42.709s
+public load13.681s; recheck34.395s +load10.739s. Isolated serialization, startup
fraction and steady slope unknown. This is not a high-end GPU baseline.

Next local experiment: count download/pack/synchronization incidence around the
EXISTING DevFzcRounds host-tail policy (FZC_TAIL_DEFAULT=5), then use an independent
challenge/fold schedule oracle at thresholds0/5/8/10. Charge the one-time tail copy,
remaining host rounds and fused-round boundaries; do not invent a crossover time.
Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.

[Experiment](experiments/public-inverse-scale-20261021/README.md),
[low-priority handoff](handoffs/20261021-public-inverse-scale.md).
Only research excluding runtime written; no build/GPU/install/downloaded-code,
external write/message/purchase/escalation/Git/production edits. Main/Claude
reviews/integrates. Saved reports do not establish delivery or liveness.


## Cycle0117 — FZC CPU-tail boundary: exact small launch/traffic candidate

# Cycle 0117 — FZC tail boundary — 2026-10-21

Run `20261021T011854Z-d7ab1017`. Checkpoint: 2026-10-21T01:34:28.434635+00:00. Started 01:18:54 UTC; deadline 01:38:54 UTC.

**No proving speedup measured.** The active GPU FZC code already switches late
sumcheck rounds to the CPU at a default threshold of 32 entries. The tested candidate
folds the original tables directly into the packed download buffer. It could remove
one boundary kernel and avoid folding derived tables that the host no longer uses.

For the illustrative n=21, k=21, kd=23 case at threshold 5, the count model changes
18 body/tail kernel launches to 17 and removes 24 KiB of logical device traffic and
64 derived Fp2 fold outputs. It retains the 10.5 KiB copy, pinned buffer, synchronization
and host polynomial/fold work. The minimum device-table request stays 736 MiB until
the evaluator drops; pooled capacity may be larger. No actual VRAM peak saving follows.

Increasing the threshold from 5 to 8 or 10 changes the copy from 10.5 KiB to 84 or
336 KiB, host pair evaluations from 31 to 255 or 1,023, and Rayon regions from 0 to
1 or 3. It can also disable raw-source construction for small cubes. These counts
establish no crossover time. Keep threshold 5 until the owner measures the tradeoff.
The existing bytes_d2h counter records only the tail copy; mapped round messages
still write system memory, while normal fallback and final copies are counted elsewhere
in this study. Moving computation to the host does not release the device arena.

Baseline: k_sc_fold over kd tables followed by k_fzc_pack over the original k tables.
Removed work: one launch, intermediate stores/rereads and unused derived folds at this
boundary. Added costs: a small kernel, module registration/cache rebuild and native
validation; allocation, copy and synchronization costs remain. With unknown exclusive
boundary fraction f, even free removal gives only a total speedup bound of 1/(1-f).
This candidate removes part of that fraction. No numeric full-proof rate is supported.
Falsify it on any canonical round, next challenge, final, receipt or refusal mismatch,
stale/raw read, later use of a derived table, device failure or enclosing-time regression.

The probe passes 859 checks across 48 actual-FZC synthetic cases (160 modeled
rounds), 80 fold/pack boundary cases and nine controls. The original 20/21 table order,
MSB pairs, both Goldilocks Fp2 coordinates and all eleven geometric pad powers are
retained. The independent audit passes 55,423 checks over 6,144 schedules,
11 source pins and six controls. The census passes 30,720 checks.
Probe/census/audit clocks are 14.028644 / 0.350108 /
0.761975 s; maximum RSS is 40,632 KiB.
Seed: 202610210117. Every experiment used one worker/core, nice 19, a 59-second
CPU/alarm limit, a 60-second parent timeout and 512 MiB address-space limit;
estimated memory <=128 MiB. No native build, GPU kernel, masker, transcript, PCS,
receipt or verifier ran. Synthetic challenge-chain hashes are not native proof hashes.

Thirteen LIVE queries produced ten primary-source records (727 -> 737). The search
refreshed Chimera's October 16 revision, the September 1 CMU sumcheck article,
ICICLE's latest v4.0.0 release/adapter and Efficient Sumcheck. NVIDIA's September 5,
2019 CUDA Graphs article is a newly assessed older lead: replay can reduce submissions
inside one fixed segment, but fresh host-derived challenges prevent blind replay
across rounds. Native default rounds already use one fused split kernel. Graph setup,
parameter updates and buffer lifetimes must be charged before considering that route.
ICICLE's current MIT license body and release commit
6c77775961b0e4dc2be359feec1ac11536c18043 were inspected. Efficient Sumcheck's commit
page returned 429; other license/PDF cache/access failures are recorded without bypass.
No upstream code or author benchmark was executed. The queue has 34 ranked hypotheses;
all 31 prior entries and negative findings remain, and the top four owner priorities
are unchanged. The tested tail candidate is rank 13; graph replay and scratch leases
are ranks 33 and 34.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research ran on one Intel Core Ultra 9
185H CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration and fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic table
lengths 2–2,048 and modeled cube logs 1–26 are diagnostics, not model context lengths.
Larger workloads remain allowed; increasing context can raise attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Historical CPU diagnostic, carried without rerun or reverification: non-DD 8B,
T128, 32 layers, one 16-thread CPU pass, GPU off. Total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s and load 17.595 s. Seal 84.824 s contains
overlapping work. Receipt: 922,711,264 B. Fresh verify: 42.709 s + public load 13.681 s;
recheck: 34.395 s + load 10.739 s. Isolated serialization, startup fraction and steady
slope are unknown. This is not a high-end GPU baseline.

D32's fidelity bar, D37's classifier direction and the narrow D33/D36 frozen-r9
TinyLlama T32 CPU acceptance were reread. They do not admit 8B/GPU/DD or a new fidelity
profile. Preserve D30 N-r9-a/b and the outstanding DD privacy gate. No ruling was edited.

Next local experiment: count recurring FzcMapped/PinBuf allocation and mapping
calls per slot attempt, including the fallback PinBuf allocated even when mapping
succeeds. Test an independent lease/sequence oracle across changed degree/support,
shrink/grow, failure, stale matching sequence and incomplete device work. Reuse only
storage; preserve fresh contents, challenges, masks, openings and every fallback.
No native adapter or runtime saving is justified until owner phase evidence supports it.

Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident 1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.

[Experiment](../experiments/fzc-tail-boundary-20261021/README.md),
[handoff](../handoffs/20261021-fzc-tail-fold-pack.md).

Only research files outside runtime/ were written. No production, reviewer,
instruction, calibration, Git or receipt edits; no native build, GPU job, installation,
downloaded-code execution, external write/message, purchase or escalation. Main/Claude
reviews and integrates. Saved reports do not establish delivery or supervisor liveness.

Evidence integrity: 213 checks PASS; 54 artifact hashes and 11 source pins match. All 727 prior source records, the prior findings prefix and all 31 prior hypotheses are preserved. No concurrent source/document changes observed. Final audit UTC: 2026-10-21T01:35:13.986602+00:00.


## Cycle 0118 — FZC scratch reuse: allocation counts and lifecycle gates

# FZC scratch storage study — cycle 0118

Run `20261021T021854Z-dc9711cc`. Checkpoint UTC: 2026-10-21T02:33:40.559814+00:00.

**No proving speedup measured.** The active GPU FZC constructor allocates a
cached-read fallback host pin even when mapped output succeeds. A separate host
pin serves its CPU tail. Reusing these allocations can remove driver allocation,
free and mapping calls; it removes no proof arithmetic, transfer, device arena,
masking or serialization. Exact native incidence and exclusive time are unknown.

In a conditional fixed-shape sequence of 32 attempts (degree 5, support present,
tail_log 5, each reaching half=32), host allocation events fall from 96 to 3 and
mapping queries from 32 to 1, retaining 10,952 B. A changing-shape sequence agrees
with the independent audit: 96 -> 6 allocation events; cumulative allocated bytes
513,792 -> 32,112; idle retention 21,704 B. Growth raises transient host capacity
from a 21,704 B fresh baseline peak to 31,944 B. Driver page granularity is unknown.
This is a request-count opportunity, not a memory-peak saving or a runtime result.

The storage probe passes **1,418 checks**, 96 fixtures / 320 synthetic messages,
36 changed-shape cases and 17 negative-control types. Its independent reference
allocates fresh byte arrays and compares every returned word and synthetic hash
chain; it does not evaluate the FZC polynomial. The source/order census passes
24 checks over 120 event interleavings in 16 families. All eight cases
with the same stream and reset after successful synchronization are safe in this
logical model; pre-sync reset and foreign-stream writers expose stale observations.
The separate reviewer imports no candidate code and passes six checks with matching
changing-shape allocation counts. No native concurrency or memory ordering was tested.

Critical constraints: a retained seq=1 can satisfy a new attempt that restarts at
seq=0; changing degree moves the flag into prior payload. Clear the new active
range only after every prior writer completes. Cudarc 0.13.9's existing constructor
synchronize is stream-scoped; it may supply the fence without an added barrier
only for uses on that stream. Publication of mapped results is not final completion.
A generation plus last-submission completion event, bounded quarantine, and
requested-length views remain necessary. Copying a cached 12-word capacity from
a new 10-word d_sums would overread it. Never pass capacity as the active slice.

Keep fallback acquisition eager. Lazy fallback moves a resource failure into a
proof; cache hits also cannot reproduce every physical allocator refusal. Preserve
all mathematical refusals and process-wide mapped-broken behavior. Existing native
timeout drops the mapping before explicit fallback sync: this is a source-level
lifetime risk for review, not a confirmed native use-after-free. No native adapter
is justified by these tests alone.

Baseline: per-attempt FzcMapped + fallback PinBuf, and a separate tail PinBuf.
Eliminated work: conditional recurring host registration/map/free calls only.
Added costs: owner/lease management, exact-length views, fresh active clearing,
completion binding, growth capacity and failure quarantine. With unknown exclusive
allocation fraction f, free deletion is bounded by 1/(1-f); added costs reduce it.
No numeric end-to-end rate follows. Falsify on stale words, length/sequence/refusal
mismatch, unsafe cleanup, unbounded retention, negligible allocation cost or slower
enclosing complete-proof time.

Five native LIVE queries produced seven primary records (737 -> 744): current
Chimera's October 16 revision, ICICLE's latest v4.0.0 release and inspected commit,
CUDA 13.4 guidance, the October 14 Grace-Blackwell study, and older 2012/2021 CUDA
allocation/transfer methodology. The 2012 pinned-transfer article is newly assessed;
2021 device stream-ordered allocation is not a host-pinning replacement. ICICLE
commit 6c77775961b0e4dc2be359feec1ac11536c18043 and current MIT license body were
inspected; release year was not rendered, so none is guessed. NVIDIA sample paths
returned 404; its current BSD-style license body was inspected but not the sample.
No external code or author performance was executed/reproduced. Source dates,
licenses, exact URLs and access failures are in source-records.jsonl.

Thirty-four ranked hypotheses are retained. Rank 34 is materially refined with
this tested storage protocol and the question of reusing the existing constructor
stream fence. The top four owner priorities stay unchanged: complete high-end GPU
phase/capacity clocks; DD at larger supported contexts; actual private lifetime
telemetry; all-eleven FZC native A/B. D32's new <=1.02x perplexity amendment is
recorded; D33/D36 remain narrow TinyLlama CPU acceptances. D37's classifier
application does not replace the private 8B research target.

## Reproduce and scope

From the research directory, run sequentially:

1. `nice -n 19 python3 experiments/fzc-scratch-leases-20261021/audit/independent_audit.py`
2. `python3 experiments/fzc-scratch-leases-20261021/run_bounded.py probe.py`
3. `python3 experiments/fzc-scratch-leases-20261021/run_bounded.py census.py`

The probe checks the independently generated audit counts. commands.jsonl preserves
all local probe/census launches and successful refinements. Seed: 202610210118.
Probe/census clocks: 0.021853 / 0.019860 s;
RSS: 16,340 / 14,712 KiB. One worker/core, nice 19,
59 s CPU/alarm, 60 s parent timeout, 512 MiB address space; estimated <=64 MiB.
Independent audit: one worker/core, nice 19, 30 s CPU/alarm, 256 MiB address space,
under one second as reported by the reviewer. These are diagnostic script clocks.
No build, GPU, native FZC, CFS masker, PCS, receipt or verifier ran. Storage payloads
include arbitrary u64 bit patterns; they are not claims of canonical field inputs.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per experiment. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
The 32-attempt traces are synthetic allocation schedules, not 32 model passes.
Larger workloads remain allowed; longer contexts can increase attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Next local experiment: model mapped timeout/error cleanup with a pinned last-use
oracle across copy/sync failure, context poison and other-stream access; distinguish
known-safe retirement from quarantine without assuming cuMemFreeHost synchronizes.
Native owner first needs allocation incidence and exclusive/enclosing phase clocks.
Keep GPU/native work under shared heavy/build locks; do not launch it in this lane.

Integration seam, interface and validation gate:
[handoff](../../handoffs/20261021-fzc-scratch-leases.md). Main/Claude reviews and
integrates; no merge here. Only research files outside runtime/ were written.
No production, reviewer, instruction, calibration, Git or receipt changes; no GPU,
installation, downloaded-code execution, external writes/messages or escalation.
Saved reports do not establish delivery or supervisor liveness.

Checkpoint update, read at 2026-10-21 02:34 UTC: production status and decisions
changed during this cycle. Their complete new text and diffs are preserved under
startup/checkpoint__*. D33 and D36 now extend to frozen-r11 by the register's
02:27 ruling; they remain scoped to named TinyLlama CPU artifacts. D38 records
Shieldstral-1.0-3B text classification and a public-threshold yes/no logit statement,
with only verdict/model/policy disclosed. This application direction does not
replace this lane's private 8B throughput target. The status also reports the first
eight DD gate captures passing (gate evidence, not a new privacy acceptance) and
LOW + 12-bit-score 8B fidelity at 1.011x/1.010x with zero refusals. These are owner
reports, not reproduced here; new profile/gate and complete GPU clocks remain owed.
The status heading labels 02:40 UTC; the actual read time above is retained.

Evidence integrity: 145 checks PASS; 50 artifact hashes and 10 live/source-copy pins match. All 737 prior source records, the prior findings prefix and all 34 hypothesis entries are retained. Concurrent owner updates were read and snapshotted. Finalized UTC: 2026-10-21T02:36:20.454182+00:00.


## Cycle 0119 — FZC error retirement and recorded completion, 2026-10-21

Run `20261021T031854Z-a1dbfeef`. AGENDA and durable state were read; the full 10,123-line prior
findings text and 744 JSONL records were parsed/snapshotted. Production CLAUDE,
status, decisions, active coordination and target were read without modification.
All 34 ranked hypotheses remain in the experiment's hypotheses.json; rank 34 is
materially refined. The top four owner priorities stay unchanged.

**No proving improvement measured.** The metadata-only retirement probe passes
5,037 checks across 4,800 exhaustive differential cases and
105 topological interleavings. A separate implementation imports neither
candidate nor operation-set oracle: it matches the permutation/control counts,
checks four pinned native/library files and produces 36 role/error path cases;
61 checks pass. This is independent reference code by this researcher,
not an external review or a CUDA run.

The candidate requires closed submissions, context/generation identity and successful,
recorded completion covering every relevant stream's last submission. The operation-set
reference tracks individual use tokens rather than stream counters. Unrecorded events,
failed recording/query/sync, old generations, wrong contexts and earlier-round captures
do not retire live storage. Late successful synchronization can establish retirement
while the proof attempt remains refused. A poisoned context stops new admission and
keeps resources quarantined. Reserve capacity before launch across active/idle/quarantined
leases; a failed release stays charged. An ambiguous free result prevents reuse and blind
free retries. This does not prove eventual safe release or liveness after persistent errors.

Negative policies retire before the conservative operation-completion bound in 67
(timeout-drop), 46 (publication-only) and one (A-stream-only) of 105 schedules. Those
counts are synthetic counterexamples to the model policies, **not evidence of a native
use-after-free**. Kernel completion is a sufficient upper bound on last use; the native
flag is its final mapped store and this study does not establish later mapped accesses.
Existing source drops mapping before fallback copy+sync, destructors have no explicit
fence, and Cudarc0.13.9 synchronization is stream-scoped; implicit driver behavior remains
unmeasured. A second stream is an adversarial future-use control, not a claim the current
round submits there.

Baseline: per-attempt mapped/fallback pins and a separate tail pin. Potential eliminated
work remains the prior conditional repeated host allocation/map/free calls; none was
removed from the native prover. Added costs are ownership metadata, exact-length views,
post-completion clearing, record/capture tracking, retirement fences if needed, bounded
retention and failure admission refusal. With unknown exclusive allocation fraction f,
free deletion is bounded by 1/(1-f); added costs reduce it. No numeric full-stack ceiling
or 5090 rate is justified. Falsify on unsafe retirement, stale values, changed refusal/
transcript behavior, unbounded capacity, negligible allocation cost or slower enclosing proof.

| Rank | Hypothesis and expected enclosing relevance | Prerequisites / costs / falsifier |
|---:|---|---|
| 1 | Whole-prover high-end GPU work and verified fixed-context resident 1/2/4/8 passes | Complete phase/capacity clocks, actual fit and current profile gates; include transfers, witness, fresh masks, serialization and drain. Fails if full recurring slope stays below target or backlog grows. |
| 2 | DD at larger admitted contexts and the cheapest passing fidelity stack | T128 owner A/B was a measured null; T512 is a distinct geometry. Dictionary/helpers and new fidelity layout cost work; binding, privacy and refusal gates remain. Fails on cap/binding/refusal or worse full workload. |
| 3 | Actual private H-commit/slot18 lifetime and exclusive phase telemetry | Public role/shape counters, driver+raw+pooled+idle capacities and transient overlap, under owner locks. Added instrumentation must not leak private data or distort the measured run. Fails if no avoidable capacity/cost exists. |
| 4 | Native all-eleven pad-coefficient A/B | Existing research arithmetic candidates need owner native parity, registers/occupancy and enclosing clocks; no kernel gain assumed. Fails on parity, refusal, privacy or elapsed regression. |
| 34, refined/tested | Reuse host scratch only with recorded last-use coverage and reserved quarantine | This cycle closes a synthetic error-lifetime gate. Added lease/record/frontier/poison accounting and retained capacity; native fences and allocation clocks absent. Park runtime promotion until evidence exists. |

Eight native LIVE search queries and seven primary records are preserved (744 -> 751).
Current CUDA 13.4 documents that an event before its first recording can query SUCCESS,
and that captures exclude later stream submissions; older CUDA 8 documentation explicitly
updated 2017-06-02 independently corroborates the rule and is newly assessed in this ledger.
Chimera's  October 16 revision and ICICLE/Plonky3 release views were refreshed. Plonky3's
release commit fe5e46d755b8a7d9069778361e21b33e5978b377 and current MIT body were
inspected; its PR2038 and pinned sumcheck source tree cache-missed. Release list/search
views disagree, and month/day without a rendered year is not promoted to a verified year.
No upstream code or performance claim was executed/reproduced. Exact URLs, dates, licence
scope and access failures are in source-records.jsonl. Current CUDA documentation is not
proof that cuMemFreeHost provides the required all-stream fence.

Probe/source-audit diagnostic clocks: 0.039483 / 0.012096 s;
RSS 16,024 / 14,908 KiB. Seed 202610210119. Each child is pinned to one
CPU, nice 19, 30 s CPU/alarm, 35 s parent timeout, 256 MiB AS, estimated <=32 MiB. No CUDA,
native build, witness, mask, transcript, receipt or verification ran. Commands and source
hashes are retained; earlier successful model refinements are superseded by final result.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per experiment. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
The 64-attempt budget trace is a synthetic ownership schedule, not 64 model passes.
Larger workloads remain allowed; longer contexts can increase attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Concurrent decisions updates were read/snapshotted: D37 now uses proved category labels
for distribution and three confirmed categories; D39 restricts the POC to text+image;
D40 specifies the classifier's single endpoint/public verdict construction. These do not
amend this lane's private 8B throughput direction. D32's <=1.02x fidelity bar and zero
refusals, and the narrow D33/D36 TinyLlama CPU scope, remain recorded.

Next local experiment: source-backed non-overlapping clock and role schema for constructor,
round and tail allocation boundaries, validated on an independent interval replay. Prepare
only a research measurement proposal, preserving existing transcript and masking order.
Owner next: public-role allocation incidence plus exclusive/enclosing complete-proof clocks,
then native retirement/failure parity under shared locks if a material allocation fraction
exists. Park this scratch candidate pending those measurements; no native adapter or merge.
Integration constraints: handoffs/20261021-fzc-error-retirement.md.
