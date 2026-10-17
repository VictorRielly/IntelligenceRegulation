# Split equality accumulation — cycle 0031

Run `20261004T130146Z-19e7c75c`, 2026-10-04. **Promising exact arithmetic/cost result; no proving speed improvement measured.** Research-only files; owner/Claude reviews and integrates. No production/runtime modification, native build, GPU job, dependency install, Git action, downloaded-code execution or external message.

The question was whether native grouped sumcheck needs to multiply both split equality weights on every row. The existing loop computes `left[a] * right[b]` and multiplies that result into every required bracket sample. This prototype accumulates `right[b] * bracket_t` within an outer-index run, then multiplies `left[a]` once when the index changes or the chunk ends. All groups share the same original MSB data scan. Each group has its own span/index/accumulator, so a short or delayed equality still broadcasts over ignored coordinates. Arbitrary Fp2 data and inconsistent synthetic witnesses remain in the tested relation.

[Candidate](candidate.py) inherits original-index construction/folding/finals from the inspected prior [tagged baseline](baseline.py). [Independent oracle](oracle.py) uses tuple-field schoolbook arithmetic and direct original-cube MLEs; it does not use candidate folding or split weights. [Fixture driver](experiment.py) checks every advertised degree sample and every final value. Tests here are generic grouped polynomial fixtures of degree up to five; the native SC_SZC closure/IR/layout is not executed. Existing symbolic equality storage is a separate candidate. Native weighting can be adapted before changing table storage, retaining all original Eq allocations/folds/finals.

## Result and controls

40 mixed fixtures plus 41 exhaustive `(start,length)` fixtures; 486 schedules (split/adaptive × chunks 1/3/1024). Dimensions n=0/1/2/3/5, cubes up to32 rows, shuffled original Eq/Pub/Priv indices, Rho/Flip/Fixed reads, multislices, empty/full/delayed/short spans, zero/Boolean/base/full Fp2 values. 1,128 independently computed original-cube samples match 6,768 candidate samples; 2,178 direct-MLE final values and 18,078 counter checks pass. Each strategy/chunk arm has232 recoveries/46zero-factor fallbacks, without resampling. First group claims are unset and subsequent recovery uses only actually computed unmasked group rounds.

12 controls cover wrong outer weight, omitted chunk drain, omitted trailing broadcast, invalid chunk/strategy/span/dependency/order/finals/fold, invented first subgroup claims, and a counted chunk1 regression. Native malformed-input refusal parity is not established by synthetic validation. Final run:10.406792s,18,332KiB RSS, seed2026100431, one low-priority pinned Intel Core Ultra9 185H thread, Python3.10.12/WSL2;59s wall/CPU and512MiB address-space caps, estimated experiment memory64MiB. No GPU used. These clocks measure the synthetic test, not witness/proof/verification.

Command from the writable research directory:

```sh
python3 experiments/split-eq-accumulation-20261004/experiment.py > experiments/split-eq-accumulation-20261004/run.log 2>&1
```

Initial syntax error (one unmatched parenthesis) is retained in `initial-syntax-failure/`; no experiment ran on that attempt. The first passing unguarded source/results/log are retained in `before-adaptive-guard/` (9.047992s,17,976KiB). Final source hashes are embedded in `result.json`; native/document/source-history pins and original durable files are in `input-pins.json`/`snapshots/`.

## Counted benefit and negative finding

For M row pairs, S required bracket samples and F contiguous outer-index runs, when both split tables have more than one entry, baseline equality weighting takes `M*(S+1)` Fp2 multiplications; two-layer weighting takes `M*S+F*S`. It adds `F*S` accumulator additions plus resets, index comparisons, metadata and chunk decisions. Bracket evaluations, table loading/interpolation, data folds, equality prefix/split-table setup, group recovery/interpolation, masks, PCS and cross-part reduction work remain. Native debug assertions require explicit sample1 even when release recovery can skip it; use the actual S in the guard.

NEW negative: at n8/j0/S5/chunk1, unguarded weighting takes1,280 multiplications versus768 baseline, and1,280 additions versus640. Across these mostly tiny fixtures, unguarded chunk1024 saves just96 multiplications versus the unit-aware baseline while adding1,537 additions. Literal native baseline includes avoidable multiply-by-one work; it is reported separately to avoid assigning that saving to split accumulation.

NEW refinement: `strategy='adaptive'` uses only public shape, group degree and availability of the existing recovery to choose split weighting when its multiplication count is smaller than ordinary unit-aware weighting. Otherwise it retains ordinary weighting. The guard passes exact rounds/finals and never increases counted equality multiplications versus that baseline in any tested round. It does not guarantee lower runtime: integer decisions, branches and extra additions remain. At chunk1024 on tiny fixtures it removes180 multiplications (3,614->3,434) and adds252 additions (5,053->5,305); all arms retain5,053 bracket calls and4,984 data loads. At chunk1 it retains the unit-aware baseline with no split benefit.

Illustrative allocation-free n23, Eq lengths23/14/23, padded bracket degrees4/2/2, K26 chunk threshold `half*K<=2^16`, otherwise1024, nonzero subsequent recovery: equality weighting104,857,589 literal /104,853,484 unit-aware ->79,773,652 adaptive multiplications. That removes25,079,832 versus unit-aware (about23.919%), adding83,904 additions. All-explicit/no-recovery counts also retained in `result.json`. This is **equality-weighting arithmetic only**, not23.919% of SC_SZC, proving or whole-model time. The illustrative cube is not an admitted model profile, actual context measurement or proof.

Extra accumulator payload for these three degrees is11 Fp2 slots=176bytes per parallel part, plus metadata/reset costs; existing split Eq tables/current differences/sums/pending vectors stay. This is logical payload, not a Rust allocator/host/VRAM peak. No extra raw-source scan or degree-sample contraction occurs. No field, transcript, mask schedule, commitment, challenge sampling or cross-proof cache changes are proposed.

## End-to-end bound and falsification

Baseline: current CPU grouped SC_SZC remains roughly half of the earlier GPU-assisted single-block proving diagnostic; complete private8B and equality-only phase clocks are absent. Current native still materializes Eq arrays; this experiment compares weighting independently of that separate storage proposal. Eliminate the per-row split-product multiplication and amortize only the outer weight; add chunk accumulators, flush/add/reset/mapping/decision costs. Keep all native polynomial/fold/commitment/witness work.

For N accepted positions and complete workload T, the candidate ceiling is `N/(T-Cweight+Cnew)`. With a measured equality-only fraction f, even deleting that entire cost would give at most `1/(1-f)` whole-workload speedup. Neither T nor f is known for an accepted8B workload; no numerical end-to-end ceiling or >=50/s claim follows. Required measurement: split weight generation/multiply/add/flush time, bracket time, Eq/data loads/folds, and surrounding SC_SZC, both witness builds, down, commitments, serialization and independent verification. Do not convert counted multiplication changes into seconds.

Falsify on any original degree sample/final/index/support/future-score/refusal/masked round/transcript/RNG continuation/extension/PCS/frozen-byte mismatch, lost coverage/privacy/soundness obligation, no counted improvement with the real shape, or enclosing timing/peak regression. Native Rayon scheduling and independent fresh-process receipt verification remain owner work under shared locks.

## Source assessment and rotating queue

Seven qualified LIVE primary records are in [source-records](source-records.json) and appended to `sources.jsonl`; queries/URLs are in [search-log](search-log.json). Older Dao/Thaler two-layer work is refined; March2026 combined paper, Jolt nested fold helpers/old PR dates, ICICLE API/release, Jolt final-opening architecture, September2026 packed-small-field revision and Flock revision were inspected. No author performance reproduced. GitHub runtime-history/full-SHA/raw-source and some PDFs failed, preserved exactly; local experiment was unblocked. Jolt PR965/970 are Sep29 **2025**, not current2026 runs. ICICLE's inspected abbreviated6c77775 diff only changes versions; release month/day lacks a verified year. Main source and modular Jolt documentation are unpinned revisions.

Packed matrix challenges/MW-MLE would replace PIOP/PCS and require a new mask/soundness/privacy review, not a byte-preserving Fp2 substitution. Flock's Boolean hash-circuit proving concerns a different cost from hashing a PCS commitment; retain as a future composition lead. ICICLE `batch` is documented as hash chunks, not completed resident-model pass throughput.

Next rotation: arithmetic/quantization -> composition -> NTT/commitments -> lookup/softmax -> memory traffic -> batching/amortization -> sumcheck/GKR. Preserve earlier slower fusion, small-phase ceilings, compiler conversion, LRU, prefix hashing, reconstruction and privacy negatives.

## Ranked hypotheses

| Rank | Expected enclosing impact / baseline and removed work | Prerequisites, integration cost, added work and falsification |
|---|---|---|
|1, owner|GPU SC_SZC plus recurring witness work; largest measured remaining proof scope, remove host arithmetic/transfers only when device execution supports it.|High CUDA/representation/masked-boundary work; isolate witness1/2, down, Eq/data/brackets/folds and device residence first. Fresh full-stack verification required. Any parity/privacy mismatch or enclosing regression rejects; complete ceiling unknown.|
|2, owner|Exact full-K split-int16 FFN-down, replace scalar integer products at the identified witness seam.|Moderate/high packing/two byte products/i64 accumulation/requantization/workspace/transfers; actual down share unmeasured. Exact arithmetic/range/refusal/native-byte tests; mismatch or parent regression rejects.|
|3, locally refined/tested|Symbolic Eq storage and **adaptive two-layer weighting** as independently reviewable changes; remove three Eq allocations/folds and per-row pair weight products respectively.|Moderate constructor/index/role/closure audit and per-group chunk scratch. Storage saves logical capacity; weighting adds sums/reset/decisions; do not double-count. Native masks/extensions/debug-release/receipt/peak/timing tests required. Any mismatch or enclosing regression rejects; ceiling above unknown.|
|4|Immutable public digest/TN owner; remove duplicate public setup and conditional allocation.|Moderate/high canonical-consumer/ownership work, certificates and import checks; current digest benefit setup-only, not repeated proof-stage model scan. No P3 private opening/mask reuse. Stale-owner/digest/peak/refusal mismatch rejects.|
|5|Fresh resident-model fixed-context complete passes amortize actual startup; remove paid-once setup only.|Measure pass-count slope, context, startup, lag/drain, memory and independent verification; preserve fresh masks. Distinct contexts aggregate throughput, not decode; longer context attention grows quadratically. Missing coverage/freshness or slope regression rejects.|
|6, NEW architecture filter|Matrix-packed base-field sumcheck or grouped final openings could amortize repeated relation/PCS work, if census identifies repetition.|High protocol/PCS/shape/commitment/mask/soundness integration; matrix state and higher degree/cost plus state binding. Recent papers are not native proof evidence. Any mismatch/privacy weakening or total-workload regression rejects.|
|7, demoted|Simple source reconstruction/hash-prefix reuse and unconditional tiny split weighting.|Prior rereads/arithmetic, constructor ownership and tiny-chunk regression remain; retain negative evidence. Strong staged streaming/composition is a separate question.|

## Proof accounting and next action

Accepted independently verified complete private8B proofs/passes:0; countable tokens:0. Device:CPU only; proof context:null; model passes:0. Steady-state and total-workload token rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain:unmeasured. No long-context prefill, resident-model proof pass or decode proof occurred. Larger workloads remain allowed; full attention/FFN coverage, fresh masks and decided privacy are unchanged. >=50 proved tokens/s remains unachieved.

Historical n1 cold synthetic12-block125M/T512 RTX4070Laptop diagnostic is unchanged:408.609226s wall,318.22 combined run-prover,12.15 in-process verification,484,107,456bytes, fresh-process verification false. It is not countable complete private8B evidence. Later CLI lacks a terminal result after recorded reboot; stale status is not liveness.

Next LOCAL: source-derived three-bracket SC_SZC operation census and adaptive accumulation oracle, including padded/unpadded gates, paired/odd-tail helpers, base-vs-extension operations, folds and original support domains. Establish equality-weighting share of counted complete slot work before asking for an owner A/B. OWNER: isolate native phases/capacities and review [handoff](../../handoffs/20261004-split-eq-accumulation.md), then native debug/release/frozen/masked/fresh independent verifier/device/full-stack A/B under shared locks. No heavy job queued. These are saved reports, not external notification-delivery evidence.
