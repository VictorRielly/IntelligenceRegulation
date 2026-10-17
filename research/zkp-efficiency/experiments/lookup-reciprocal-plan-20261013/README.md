# Bounded exact-pair inverse fallback and native denominator census

Cycle0046, `20261013T032555Z-3e60f70b`, 2026-10-13 UTC.
**Synthetic parity passes; no proving improvement measured. Low priority.**

Question: can the cycle0004 exact-pair cache avoid its per-invalid-word
inversion and full helper buffer, while retaining every original refusal?
This materially refines that prior candidate; it does not rediscover byte
caching, which is already native. No cross-proof inverse reuse is proposed.

The current owner and candidate `protocol.rs` still batch-invert the full
exp/activation occurrence vectors at908..911. Byte reciprocals are already
shared across all six domains at889. At m125, SC_SZC has15 byte lookups/eight
paired helpers and one exp pair helper. Its polynomial evaluator rebuilds
affine denominators but performs no inversion: a reciprocal cache does not
remove its dominant bracket work. Table-helper construction at941 processes
256 actual rows/family, although the timing mark reports3*sh.size(Tab)=49152
rows. SC_TAB separately constructs lifted16k periodic public tables; neither
mark quantity nor public-plane length is an extra16k reciprocal opportunity.

The proposed private helper constructs a public256-row optional reciprocal
plan after fresh challenges, admits only an exact signed `(index,value)`
match, and batches all other pairs within public input chunks. It writes
canonical words directly to the existing split H planes. Columns shorter
than the public table bypass cache preparation. All later full-table inversions,
histograms, private planes, masks, draws, absorbs, commitments and openings
retain their order and values. Partially written H on refusal must die before
H commitment/any subsequent draw or absorb; that native lifetime gate is owed.
The production insertion exposes no prepared handle or persistence API.

Run from the research directory:

```sh
python3 -B experiments/lookup-reciprocal-plan-20261013/experiment.py
python3 -B experiments/lookup-reciprocal-plan-20261013/cost_accounting.py
```

Seed2026101346; one nice19 CPU0 Core Ultra9 185H thread, Python3.10.12;
59-second wall/CPU and512MiB address-space caps,64MiB estimated memory.
Final0.761940s/31000KiB RSS.203 fixtures,669 chunk schedules,81968 independent
helper words,639 split-plane sentinel checks,3195 count-formula checks,
32 full-table checks/320 table words,44 modeled whole-attempt schedules
(36 refusals),1601 padded S/future-position words and21 controls pass.
Tables1/4/16/256, columns0/1/31/257/1025/16384/16385, chunks1/3/7/256/1024,
full-extension and beta0 challenges, collisions/all-public-zero denominators,
used/unused zeros, altered pairs, signed/i64 extremes and stale challenge/
tag/public plans are covered. The separate direct coefficient solver uses
Euclidean modular inversion; candidate/native batch models use Fermat
inversion and prefix products. Canonical helper words are not receipt bytes.
No honest/native witness, masked transcript, GPU or proof was produced.

Initial passing code/result retained before adding whole-attempt and padded
checks. One accounting-parser failure (percent field selected as time) is
retained and corrected; the arithmetic run did not fail.

For16384 valid words, batch multiplications49152->768, inversions1->1;
membership reads/comparisons and all16384 writes remain. For257 invalid words
atK1024, inversions fall from prior258 to2, versus native1; batch multiplications
are1539 versus native771. Small31-word valid columns now use93 multiplies/
one inversion atK1024, avoiding prior768 cache setup; K1 still costs31 inversions.
Sparse invalid rows require one inversion per occupied input chunk, not ceil(U/K).
These negative cases rule out a universal arithmetic or runtime gain.

Source-derived all-hit m125/T512 counts: exp4194304+act1048576 occurrences;
15728640->1536 batch products,5242880->512 literal beta products, two inversions
remain. H output remains80MiB. Native sequential denominator+prefix logical
peak is128MiB; proposed logical scratch bound45360B plus2048B activation
conversion, excluding headers/allocator/compiler stack. This is payload
accounting, not measured native memory, traffic or speed. All-hit is conditional
on admitted exact table pairs, including padded/future positions.

Historical shared synthetic125M one-block/T512/two-thread RTX4070Laptop b2:
pair helper0.197s, SC_SZC7.794s, prove16.864s, external witness5.77s,
serialization0.028s, in-process byteverify0.82s, enclosing test27.523873s.
Deleting the ENTIRE pair phase bounds savings at1.168% proving/0.715742%
test wall, reducing the latter only to27.326873s. Candidate saves a subset,
possibly none. This is a one-block diagnostic, never an8B throughput ceiling.
Historical12-block GPU-assisted synthetic diagnostic remains408.609226s wall/
318.22s run prover/12.15s in-process verify/484107456B, without fresh independent
verification. Interrupted CLI has no terminal result; status is not liveness.

Complete ceiling: `Nproved/(Ttotal-Cpair_old+Cplan+Creads+Cfallback+Cscatter)`;
accepted8B total/affected clocks are absent, so numerical ceiling is unknown.
Falsify on any word, pair, pad, refusal/order, native RNG/transcript/receipt,
mask/privacy, peak or enclosing mismatch/regression. Prerequisites: owner
native correctness/lifetime review and masked/frozen/fresh independent verifier
gates; only then phase/enclosing/peak A/B under shared build/heavy locks.
Main/Claude reviews/integrates. `pair_helper_into.proposed.rs` is uncompiled,
unapplied and unmerged, with no build/GPU job queued.

|Rank|Hypothesis and expected end-to-end scope|Costs, obligations, falsification|
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness; largest measured remaining scope.|CUDA/lifetimes/transfers, duplicate witness clocks, fresh masks and complete independent verification; no enclosing/peak gain rejects.|
|2 owner|Exact full-K int16 down.|Two products/packing/i64/requant/workspace/ranges/calibration; no enclosing benefit or integer mismatch rejects.|
|3 NEW next local|Construct source-derived SC_SZC bracket coefficients once per row, then evaluate original samples by Horner/finite differences.|Compare against current compiled denominators and actual skipped1/zero-factor fallback schedule; charge coefficient convolution/scratch/setup/additions. Any sample/final mismatch or total count regression rejects. No protocol or sample change.|
|4 prior|Canonical four-reduction Fp2.|Carry/canonical/compiler/register/native masked gates; no measured enclosing benefit rejects.|
|5 prior|Symbolic Eq/mixed grouped readers.|Source-bound dependency roles, generic census/total and ordered extensions; privacy/byte/peak/enclosing mismatch rejects.|
|6 prior|First6 native shift twiddles/inverse scale.|Preserve native roots/order/coset; shift/carry/dispatch/register costs; no native phase/enclosing improvement rejects.|
|7 workload|Fresh resident complete-pass slope.|Record startup, context/passes, recurring clocks, traffic, lag/drain, independently verified receipts; >20ms per newly proved position rejects50/s for that schedule.|
|8 refined/demoted|Bounded exact-pair fallback/direct H writer.|Small0.197s phase ceiling, comparisons/read/scatter/chunk inversion costs; use mainly if measured memory matters. Native parity or peak/enclosing regression rejects.|
|9 architecture|MLE-native lookup/GKR/PCS composition.|Changed commitments/wiring/setup/transcript/joint hiding/security analysis; external claims are not model measurements.|

LIVE sources: new older MLE compatibility paper2024/1058 (received2024-06-28,
revised2024-12-06); newly inspected Plonky3 chunk-local LogUp source and
Sep22,2026 PR2293; original LogUp metadata refreshed (2022-11-04/revised
2025-02-20). Current release search also inspected rc.1 listings with11Oct
timestamps but no verified year. Apache2 license text inspected; runtime
HEAD/commit/date unavailable; short PR hashes exposed but uninspected.
PDF/history/commit Internal Error blockers retained. No bypass, foreign code
execution or author performance reproduction. Exact URLs/dates/license/commit
qualifications and raw LIVE results are in source-records.json/search-log.json.

Accepted complete private8B proofs/passes/tokens0; proof context null; CPU only.
Steady/total-workload rates, startup seconds/fraction, witness/proof/
serialization/independent-verification clocks and latency/lag/drain unmeasured.
No long-context prefill, resident model pass or decode proof ran. >=50/s target
unchanged; larger workloads allowed, attention can grow quadratically, and
fresh masks/privacy/full coverage remain mandatory. No production/runtime/
Git/reviewer/calibration/gate/receipt write, installation or external message.
Saved progress reports are not evidence of notification delivery.
