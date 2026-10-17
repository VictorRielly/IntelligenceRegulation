# Bounded exact FFN-down batch scheduling

Cycle0024, run `20261004T060146Z-96d1ccac`,2026-10-04UTC. **No proving speedup was measured.** A CPU schedule/ownership prerequisite passes 576 schedules, 11232 independently compared raw dots, 88272 column-major byte-output words, 1152 accepted z16/remainder words and 16 controls. Outcomes72 accepted arithmetic fixtures,192 down refusals,312 residual refusals. Arithmetic acceptance is not proof acceptance. Final 0.642347s/17156KiB RSS, one pinned nice10 CoreUltra9 185H thread, seed2026100424,59s alarm/CPU cap,512MiB address-space cap/64MiB estimate. Enclosing subprocess 0.672124s.

## Question, baseline and costs

Can public batch planning reduce calls and split-K re-packing while preserving bounded scratch, exact arithmetic, support and refusal order? The prior full-K coarse64-row route counts8 conceptual GEMM calls/36MiB payload. Narrow64×128/fullK counts256 calls/34.0625MiB; narrow splitK1024 counts4096 calls and512MiB packed traffic. Baseline full-K already packs a row once, so grouping cannot claim to eliminate that packing again. Current native down uses direct wide dots; these byte-GEMM alternatives are research models. Isolated native down/witness clocks are absent.

The model packs each public row/K tile once, leases it across all output-column batches, reserves disjoint partial slots for up to q equal-shaped problems, completes them in public forward/reverse/shuffled order, consumes every result, then recycles the pool. Ragged column tails enter separate shape buckets. Split-K keeps full row×true-N i64 reductions until all K tiles drain. That reduction adds memory but avoids re-packing for each output tile. Full-K has no reduction buffer. Public descriptors never depend on private values or refusal flags; changed synthetic private values leave the forward descriptor trace unchanged.

The work eliminated is potential API calls and redundant split-K packing. Two byte MACs still replace one original wide MAC, with i64 combination and the +128 column correction once after all K. Added costs are pointer arrays, descriptors, pools, packing, twice the byte work, reduction writes, weights/transfer/workspace, synchronization and private status reduction. An API call count is not a measured GPU kernel launch count.

## Independent validation and actual seam

`experiment.py` is self-contained stdlib Python. The independent reference uses checked direct-i64 dots and divmod rounding; it shares neither the packing identity nor descriptor indexing with the candidate. Raw dots compare even on refused inputs. Both inclusive int16 endpoints and weight -128 occur. All padded K coordinates are consumed; invalid dirty padded token rows are ignored. True support writes exactly once; zero output/remainder padding persists. The first support failure is reduced privately and residual checks wait until all down checks succeed. Nothing is published, absorbed or drawn from status.

True M/K/N combinations1/1/1,3/5/5,5/17/7,3/31/9; padded M/K/N2/4/4,4/8/8,8/32/8,4/32/16. Row/output/K/group combinations include1/1/full/1,2/3/3/2,3/4/7/4,64/128/full/32, with both weight orientations and three completion orders. Ownership controls catch overlap, duplicate slots, stale epochs, mixed shapes, pool bounds, early pack release/repack, live pool reuse and stale/duplicate completion. Numerical/order/address controls catch changed reconstruction, wrong first status, early residual, tile-local weight lda and API alignment assumptions.

A separate physical column-major scalar oracle compares every modeled byte output. For original row-major input/output weights: Cᵀ=Wᵀ·packedᵀ, BLAS(m,n,k)=(cols,2rows,width), A0=k0·Npad+j0, lda=Npad, opA=N; B is packed with ldb=width,opB=N; ldc=cols. Out/input weights use A0=j0·Kpad+k0,lda=Kpad,opA=T. Native code must use actual strides and four-byte alignment. This mapping is exact in the model; it does not establish device/algorithm support or IMMA. Necessary integer layout conditions pass2304 problems and fail8532; unsupported public shapes require unchanged CPU fallback.

Read-only source pins: `ops/zkp-mvp/candidate/hashline/src/private_block/witness.rs:312,685` (same hash in sonnet-hardening); root main is an older fixed shape with corresponding down call392. These paths are not interchangeable. Candidate down's raw accumulator is temporary; final z16/RDL remain. Device work would add audited integer witness buffers/FFI near candidate `hashline/src/gpu/cuda.rs`, not reuse field-NTT pool assumptions. Source snapshots/pins and previous memory prefixes retained. Initial passing schedule-only revision is under `initial-schedule-pass/`; final revision adds independent BLAS-address and fallback gates, with unchanged arithmetic digest. No Rust/CUDA/native witness/RNG/transcript/PCS/proof ran.

## Counted geometry tradeoffs

Public unadmitted Llama3-8B metadata,T512/Kpad16384/N4096. No matrices of that size allocated. Final z16/RDL32MiB retained in every row. Payload includes simultaneous final+pack+all batchpartials+(splitK full-row reduction), not a sum of unrelated phase maxima.

|row×column/K tile|q slots|local payload MiB|conceptual batch calls|GEMM problems|total pack MiB|
|---|---:|---:|---:|---:|---:|
|64×4096/16384|1|36|8|8|16|
|64×128/16384|1|34.0625|256|256|16|
|64×128/16384|4|34.25|64|256|16|
|64×128/16384|32|36|8|256|16|
|128×4096/16384|1|40|4|4|16|
|256×4096/16384|1|48|2|2|16|
|512×4096/16384|1|64|1|1|16|
|64×128/1024|1|34.1875|4096|4096|16|
|64×128/1024|4|34.375|1024|4096|16|
|64×128/1024|32|36.125|128|4096|16|

**Negative:** grouping all32 narrow columns recovers coarse-row8 calls/36MiB, with256 problems and extra descriptors. It has no demonstrated advantage over one wide GEMM per row tile. Group4 gives64 calls/34.25MiB, trading payload for calls. Wider row128/256 reduces calls to4/2 but restores40/48MiB. Row512 uses64MiB,16MiB worse than the prior lifetime-aware materialized split48MiB baseline.

**Conditional prerequisite:** K-first splitK1024 packs16MiB instead of512MiB, but retains2MiB i64 row reduction. Group4 uses34.375MiB/1024 conceptual calls versus the prior32.25MiB/4096 with re-packing. FullK already fits safe i32 byte partials at K16384. SplitK remains demoted for this geometry until actual traffic/peak evidence justifies it. Naive logical W reads512MiB per64-row schedule versus64MiB whole-matrix; cache/DRAM unknown. All schedules do the same counted byte products.

Counts omit input/weights/other witness planes, host/device mirrors, workspace, pointer descriptors/status, pool retention, transfers and preallocated destinations. They are one-tier local payload/traffic counts, not whole-builder peak or measured savings.

## Sources, obligations and next action

Native LIVE search read [cuBLAS13.4 contracts](https://docs.nvidia.com/cuda/cublas/index.html), [CUTLASS scheduler](https://github.com/NVIDIA/cutlass/blob/main/media/docs/cpp/grouped_scheduler.md)/[header](https://github.com/NVIDIA/cutlass/blob/main/include/cutlass/gemm/kernel/gemm_grouped.h), [September release](https://github.com/NVIDIA/cutlass/releases), older [2017 batching](https://developer.nvidia.com/blog/cublas-strided-batched-matrix-multiply/)/[2024 grouping](https://developer.nvidia.com/blog/introducing-grouped-gemm-apis-in-cublas-and-more-performance-updates/), and the [August B300 audit](https://arxiv.org/abs/2608.11693). API scope blocks integer grouped Ex and current zero-stride broadcast. Exact source dates/license/commit scope/errors in source-records.json/search-log.md; no author performance reproduced. The recent B300 audit has no measurements and establishes no5090 result.

New prerequisite question: original W orientation maps to NN while documented regular Lt IMMA uses TN. Can an identity-bound transposed public-weight cache give exact TN with useful enclosing gain? A full counted K×N int8 cache adds64MiB per active layer if original storage stays; layerwise tiling/residency and total-model startup matter. No cached private opening or mask reuse authorized; P3 cache/sums remain private and require owner review.

Owner should isolate both witness builds and down time, then compare full-K coarse row sizes64/128/256 with actual integer algorithm/traffic/workspace/peaks, complete native witness bytes/refusals/RNG continuation/masked transcript/receipts and independent full-stack verification under shared build/heavy resource locks. No job is launched here. Falsify any value/remainder/support/pad/first-refusal/ownership divergence, private scheduling leakage, altered domain or no actual enclosing benefit.

Complete-proof ceiling: P/(T−Cdown_all_builds+Cpack+Cupload+CGEMM+Cfinalize+Cdownload+Csync). Accepted8B terms are unknown; no kernel factor implies50/s. Current cycle0 accepted complete private8B passes/0 countable tokens,CPU only/contextnull; steady/total rates,startup fraction,witness/proof/serialization/independent verification/latency/lag/drain clocksnull. No longprefill,resident-pass or decode run. Larger workloads allowed; attention T², fresh masks, complete coverage and authenticated decode binding remain.
