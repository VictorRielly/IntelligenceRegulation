# Public hash prefix reuse across contexts — cycle 0028

Run `20261004T100146Z-8793c93e`, 2026-10-04. **Exact synthetic prerequisite passes; no proving improvement measured.** The idea is demoted because it removes a limited setup scan, leaves the large FFN suffix and constructor work, and needs shared immutable ownership absent from current constructors.

Production source is read-only. AGENDA, durable memory/source history/latest experiment and project CLAUDE, current throughput target, MVP status, decisions and active coordination were read. Prior memory and inspected sources/reports are pinned under snapshots/ and source-pins.json. One bounded CPU experiment, refined once for an actual stale-owner mutation and a prefix exceeding 1,024 bytes. No native build, GPU, dependency installation, Git, production/runtime edit, foreign script execution or external write/message.

## Baseline, proposed work and result

`BlockPublic::digest`, candidate `private_block.rs:614`, currently starts a BLAKE3 hasher with `hashline/private-block-public/1`, then absorbs five attention i8 arrays, RoPE cosine/sine and exp i64 arrays, four FFN i8 arrays and the i16 activation table. Each array has a little-endian u64 **element-count** frame. Current public source SHA256 is `9540a7e60a2d07f2988d57267e9971c618627407dc9109f691656ea300c5b96d` in candidate and sonnet. Their other sources must not be assumed identical. Cargo.lock already pins BLAKE3 1.8.7; no upgrade is needed or proposed.

The reusable boundary for this ordinary prefix method is immediately before the RoPE cosine length frame. Retain the actual incremental hasher state after the domain and five attention arrays. For each new context, clone that state, absorb all eight remaining arrays in the original order, and finalize. Finalized prefix digests, concatenated component digests, reordered FFN words and cached obsolete length frames all change the original statement. This experiment proposes no BLAKE3 subtree/hazmat scheme and does not establish a universal lower bound on other algorithms.

Independent reference: the prior locally authored original-order `struct.pack` serializer, copied after inspection into reference_support.py, versus a separately implemented signed-word streaming candidate. Prefix plus suffix bytes match the full preimage; SHA256 incremental-state copies match monolithic hashes. SHA256 is a diagnostic model, **not native BLAKE3 or proof validation**.

Final result: **72 synthetic cases, 576 byte comparisons covering 3,274,560 bytes, 576 resumed hashes, 936 tensor mutations, 576 branch-isolation checks, 72 cold-import scans, five schedule checks and 22 controls pass**. Twelve base prefix owners span four geometries and zero/extrema/random data. Contexts are 1/2/3/8/16/33; true/padded widths 4/4, 6/8, 8/8, 24/32, hidden/padded FFN widths 8/8, 11/16, 16/16, 43/64; head dimensions 2/4/8, KV heads 1/2 and query-head holes. Chunk caps 1/7/8/31/64/257/4096/65536 split frames and signed words. The largest geometry crosses the BLAKE3-sized chunk boundary in its preimage, but no BLAKE3 implementation is exercised.

Controls cover stale internal owner mutation, routing a different model through a prior owner, changing the hash domain, finalized/nested/concatenated digests, moving/omitting FFN words, stale RoPE length, byte-count framing, table order, shared-state mutation instead of copying, caller-mutable inputs and original support/table/calibration refusals. Changed tensor hash tests include structurally invalid data deliberately; this does not imply those data are accepted. Explicit refusal tests remain separate. Native exact refusal strings/ordering, RNG, masked transcript, PCS, receipt bytes, concurrency and private ownership have not been tested.

Command: `python3 -B experiments/public-prefix-checkpoint-20261004/experiment.py`. Seed 2026100428; Python 3.10.12; Intel Core Ultra 9 185H, one pinned low-priority CPU thread, CPU only. Final **2.623259 s, 20,084 KiB RSS**; 59-second wall/CPU alarms, 512 MiB address-space cap, 64 MiB estimated experiment memory. Exact argv, clocks, stdout/stderr and hashes are retained. Initial 54-case passing result remains in before-owner-mutation-control/. This is correctness work on a shared host, not a benchmark comparison or performance ratio.

## Counted ceiling and important negatives

Unadmitted public Llama-3-8B geometry: 32 layers, padded D4096/F16384, eight KV heads, head dimension128. Allocation-free decomposition independently matches the previous whole-preimage counter:

| Context, counted only | Full model hash bytes | Prefix bytes reused after first variant | Suffix bytes per variant | Reusable fraction for this method |
|---|---:|---:|---:|---:|
| 512 | 7,801,753,824 | 1,342,310,624 | 6,459,443,200 | 17.205% |
| 1,024 | 7,818,531,040 | 1,342,310,624 | 6,476,220,416 | 17.168% |
| 2,048 | 7,852,085,472 | 1,342,310,624 | 6,509,774,848 | 17.095% |
| 4,096 | 7,919,194,336 | 1,342,310,624 | 6,576,883,712 | 16.950% |
| 8,192 | 8,053,412,064 | 1,342,310,624 | 6,711,101,440 | 16.668% |

These are logical hash input counts, not actual DRAM traffic, peaks, speed, admitted profiles or allocated 8B data. A four-context 512/1024/2048/4096 sweep removes 4,026,931,872 of 31,391,564,672 baseline hash bytes (12.828%) after counting the first prefix hash. The 1.208 full/suffix byte ratio at T512 is **only a byte ratio**, not a runtime speedup. The shared owner must actually survive across context variants; cold processes each pay the prefix again. For an unchanged context and unchanged complete public words, the prior finished-digest cache removes the entire repeated hash and dominates prefix-only reuse after the first call.

NEW integration negative: current `AttentionPublic::new_shaped` lines450–481 validates every weight's support and copies each array into new Vecs. The unchanged constructor still scans and copies 1,342,308,352 prefix weight bytes per 32-layer variant. Prefix-hasher reuse removes neither operation. Existing owned attention objects cannot simply share their weight Vecs across new context constructors. A shared immutable weight owner and support-shape certificate would be additional work; any such certificate must include width/head-slot/axis support, while every context table retains its original checks. Ordinary copying/validation must stay until that reviewed ownership path exists. Do not price a skipped constructor scan as part of this result.

Removed conditional work: hashing the unchanged attention prefix after the first context variant. Added work: first prefix hashing, state storage/copy, owner identity/lifetime checks, bounded byte conversion, context validation, suffix hashing/finalization, cache lifecycle and independent importer/verifier authentication. No witness matmul, sumcheck, commitment, per-proof mask, serialization or private state binding work is eliminated. Native hasher state size and isolated/enclosing clocks are unknown.

Complete-workload ceiling remains `N / (Tbaseline - Dprefix + Cstate + Cownership + Cstream)`, with all accepted 8B terms unmeasured. Under an explicitly hypothetical uniform byte-cost model, the retained digest phase at T512 is at least 82.795% for this method; this supplies no end-to-end numerical rate. Falsify any canonical byte/native hash/refusal/outer identity/RNG/transcript/receipt/privacy mismatch, stale owner, cross-process trust, context table omission, or enclosing added cost at least as large as saved work. Larger attention still has quadratic context work; hash prefix reuse proves no decode reuse or authenticated KV state.

## Ranked queue and concrete next experiment

| Rank | Hypothesis and end-to-end relevance | Prerequisites, cost and falsification |
|---|---|---|
| 1, owner | GPU SC_SZC plus witness recurrence addresses the largest observed recurring parent scope. | High native/device integration, supported memory, exact Fp2/masked/RNG/PCS parity and full phase clocks. Prior slower fusion stays negative. Reject any byte/privacy change or enclosing regression. |
| 2 | Exact coarse full-K split-int16 FFN-down moves recurring witness dots to device. | Prior arithmetic tests pass; packing, transfers, twice byte MAC work, i64 reconstruction, requantization and first-refusal gates remain. Isolated down clocks absent; no speed assigned. |
| 3, local next refinement | Stream/recompute SC_SZC folded tables in bounded windows while returning **every original MSB round**. | Moderate/high reader/evaluator work; remove resident folded-table storage, add repeated scans/recomputation and scheduling. Existing codewords may dominate peak, so count the enclosing lifetime. Preserve all three equality groups, invalid-host handling, finals and masks. |
| 4 | Complete public digest streaming/cache, then TN canonical shared weight ownership. | Existing CPU prerequisites pass; moderate/high native migration and ownership cost; cold imports verify real content, all readers migrate, peak/phase clocks needed. |
| 5 | Resident-model fresh complete-pass slope/startup/drain sweep. | Supported trained shapes, admitted layout/privacy, fresh masks and independent receipt verification. Fixed receipt replay does not count new positions. |
| 6, tested/demoted | Context-dependent public digest prefix checkpoint. | At most the counted prefix for this method; FFN suffix/support/copies remain, no common owner currently. Measure digest phase before any native implementation. |

Next local experiment: use the prior independently checked SC_SZC synthetic catalog to reconstruct original MSB folded MLEs from immutable inputs and recorded challenge prefixes under variable chunk/window caps. Compare every degree sample and final table value with an independent direct-cube reference, including full-extension helpers, three equality points/short p_ht support, zero factors, invalid asserted host sums, public padded supports and ordering mutations. Count original-input rereads, field operations and live payload versus materialized folding. No native masked-boundary job is duplicated.

Actual seams: `zkp-core/src/sumcheck/rounds.rs:19` SumcheckRounds; grouped.rs:22 GroupedEqRounds; private_block/argument.rs:495 table materialization and :553 grouped evaluator invocation. Native driver folds in **MSB** order; prior Python adjacent-pair conventions cannot be copied blindly. Keep round/fold/finals and transcript schedule unchanged, with final opening checks preserved. Source pins added for the next cycle. Main/Claude owns native integration under the shared build/heavy locks; no job queued here.

## Search and proof accounting

Six qualified LIVE primary records saved. The September author explanation and current repositories/releases were checked; a previously unassessed older modular-VE paper adds a PCS/composition filter, not a model-speed claim. EPFL design schedules inform the next oracle but its plain non-ZK library/final-oracle obligation prevent direct adoption. BLAKE3's package version list now verifies 1.8.7 publication **2026-08-20**, correcting cycle0027's unknown-year qualification. Exact URLs/dates/license/commit scope and fetch failures are in source-records.json/search-log.md. No author performance reproduced. Rotation: memory traffic → batching/amortization → quantization/arithmetic → composition → GPU NTT/commitments → lookup/softmax → sumcheck/GKR.

Accepted independently verified complete private8B passes **0**, countable tokens **0**; CPU only, proof context null, proof passes0. Steady and total-workload rates, startup fraction, witness/proof/serialization/independent-verification, latency/lag/drain clocks all unmeasured. No long-context prefill, resident complete-pass proof or decode proof. **>=50 proved tokens/s remains unachieved.** Synthetic context variants above are test dimensions, not proved workloads; privacy and mask requirements remain unchanged.

Historical n1 cold synthetic12-block125M/T512 RTX4070Laptop8188MiB diagnostic remains 408.609226s wall, 318.22s combined run prover, 12.15s in-process verification and 484,107,456 receipt bytes; independent verification false. Witness/serialization are inside the combined parent, not isolated. The later CLI report lacks a terminal result after the recorded reboot; no liveness inferred. Those positions are not target tokens.
