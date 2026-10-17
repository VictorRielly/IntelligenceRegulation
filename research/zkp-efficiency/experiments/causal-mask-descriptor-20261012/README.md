# Public causal-mask descriptor — cycle0037

Run `20261012T182555Z-4bc569b3`, 2026-10-12. **Synthetic exactness and a storage
candidate; no native proving speed improvement measured.** Only research files
were written. No GPU, native build, installation, Git, production edit, external
write/message or downloaded code execution occurred.

`python3 -B /home/victor/IntelligenceRegulation/research/zkp-efficiency/experiments/causal-mask-descriptor-20261012/experiment.py`

Final pass: **0.960794 s, 19,804 KiB peak RSS**, seed2026101237, one pinned
nice19 Intel Core Ultra9 185H thread, Python3.10.12; 59s wall/CPU and512MiB
address-space caps,32MiB estimated. Commands/environment/completion are retained
in command.json/execution.json/run.log. All four final Python source hashes are
in result.json. The two intermediate passes and matching reconstructed source
pins are retained; repeats added extension, future-score, Ht-support and full
tail-sum coverage rather than seeking faster clocks.

36 fixtures cover leading axes0..3, token bits0..4, up to1,024 cube words,
base/full-Fp2/Boolean/zero challenges; 188 folded states,13,920 endpoint values,
48,720 degree0..6 sample values,1,316 mask-sensitive point samples,224 complete
tail sums of those contributions,7,952 independent direct-cube MLE evaluations,
36 terminals,72 arbitrary off-domain comparator checks and144 public
zero-extension terminals pass. Nineteen negative/refusal controls fire.
The independent oracle uses original-cube bit products and schoolbook extension
convolution, without importing the candidate recurrence, fold or reader.

The point/tail expressions contain the mask-bearing SC_RS and SC_SZC clauses,
with their actual512 softmax scale and-127 masked-score offset. Omitted helper,
limb, weighted-host and other clauses are unchanged algebraic consumers of the
same exact mask value; **this is not complete native SC_SZC or an honest
witness**. Ht support is separately lifted over j. Synthetic true bounds are
ragged (e.g.3/4,7/8,15/16); they are not newly admitted model profiles or a full
grouped-head/P3 support port. No distinct Tk exists in the inspected frozen mask:
both axes use t_pad. Rectangular decode would need a separate reviewed relation.

## Source contract and mechanism

Pinned native source is the read-only `ops/zkp-mvp/candidate/` tree.
argument.rs:1013 constructs `j <= t` using **padded** token stride on every
leading head/lift slot. It deliberately does not zero padded heads or true
token padding: pad.rs/support terms enforce those separately. The controls
catch strict `<`, swapped axes, true-bound filtering, padded-head filtering,
MSB reversal, lost extension limbs, mutated cells and stale prefix readers.
The mask-independent SH_S=6 score host still constrains future pairs; multiplying
it by the causal mask changes the relation and the control detects that change.

Write `L=leading_bits`, `l=log2(t_pad)`, `N=2^(L+2l)`, `T=2^l`.
Leading axes contribute one, even at arbitrary extension-field challenges.
For bit vectors t,j the <= MLE has recurrence
`C_i=t_i*(1-j_i)+eq(t_i,j_i)*C_(i+1)`, with terminal1 and
`eq=(1-t_i)*(1-j_i)+t_i*j_i`. Each monomial uses each coordinate once, so this
is the original Boolean comparator's MLE, not a polynomial approximation.

During MSB t binding keep two values for each bound j prefix: `lo` for a strict
prefix win and `hi` for a prefix win-or-equality. For old pair(a,b), compute
`m=a+r*(b-a)` and form j-bit0 `(lo=m,hi=b)`, j-bit1 `(lo=a,hi=m)`.
A residual row selects hi when `j_suffix <= t_suffix`, otherwise lo. After t
binding only hi remains; the j axis folds normally. The verifier evaluates the
bit recurrence in O(l). Public terminals still multiply by **every** `(1-e)`
extension selector, extending toward zero. Tests include e0/e1 as algebra
controls; native degeneracy refusals remain mandatory and unexecuted here.

## Baseline, removed work, added cost and ceiling

Baseline: one explicit Fp2 public mask plane per SC_RS/SC_SZC slot, moved into
the dense table set, folded N-1 times; Vec::truncate retains its original
capacity. Candidate removes its N-word construction and dense folds; it uses
T-1 t-prefix interpolations plus T-1 j folds. It retains all common sample
interpolation and all private/support/equality/other table scans and folds.

| Padded context,32 leading slots | Explicit plane payload | Compact temporary payload bound | Interpolations: dense -> compact |
|---|---:|---:|---:|
|512|128MiB|24KiB|8,388,607 ->1,022|
|1,024|512MiB|48KiB|33,554,431 ->2,046|
|2,048|2GiB|96KiB|134,217,727 ->4,094|
|4,096|8GiB|192KiB|536,870,911 ->8,190|

These are allocation-free arithmetic illustrations, not admitted larger
profiles, measured peaks or full-model savings. At T512, t-end retained payload
is8KiB; the logical temporary bound3T includes old and newly prepared vectors.
Allocator/capacity/metadata and other slot buffers are excluded. The two slots
run separately; their peak savings must not be added. Rust j folding may retain
T capacity until slot destruction, which stays O(T).

Added work: two index readers/predicates per Boolean pair until t finishes,
`2N-2T` predicate evaluations over all those rounds (16,776,192 at T512),
O(T) prefix preparation/drop/allocation, shifts/masks/one integer comparison,
typed driver/total/census/final adapters and O(l) verifier recurrence. Dense
endpoint loads were already2(N-1); common cur/dif/sample work stays. Test reader
counts deliberately include repeated diagnostic reads and are **not** native
scheduling estimates; cost-accounting.json states the proposed native schedule.
Predicate/dispatch/register/CPU/GPU costs could erase fold/traffic benefits.

Complete-workload ceiling is `Npositions/(Ttotal-Cmask_build_fold+Cnew)`, with
ideal upper bound `Npositions/(Ttotal-Cmask_build_fold)`. Neither accepted8B
Ttotal nor an isolated mask clock exists, so no numeric full-model ceiling is
available. The historical synthetic one-block b2 RTX4070Laptop profile records
SC_RS0.600s andSC_SZC7.794s within16.864s proving,5.77s external witness,
0.028s serialization,0.82s in-process byte verification and27.523873s test wall.
Even deleting both **entire** prover slots would save at most8.394s on that
diagnostic; the descriptor removes a small subset of those slots and this is
not an8B speed estimate. Verify slots0.191/0.274s bound the similarly limited
verification scope; verification is reported separately from the target's
workload timing. No startup/steady slope is isolated. The12-block diagnostic
408.609226s/318.22s combinedrun-prover/12.15s in-processverify is historical,
synthetic and lacks fresh independent verification. Interrupted CLI state is
not liveness or a completed proof.

Falsify any original Boolean value, off-domain MLE, index, point/tail sum,
terminal/extension selector, future-score/support/pad/refusal/RNG/transcript/
receipt/privacy mismatch; failure of the exact native public shape premise;
or memory/enclosing runtime regression after charging the new reader costs.

## Ranking and integration

|Rank|Hypothesis and end-to-end scope|Prerequisites, costs and rejection gate|
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness;largest measured remaining block scope.|High CUDA/memory/masked transcript integration;isolate both witness clocks,lookup/bracket/fold/transfer;exact samples/refusals/privacy and complete independently verified A/B;enclosing or peak regression rejects.|
|2 owner|Exact full-K split-int16FFN down.|Packing,two products,i64/requant/workspace;isolated down share unknown;exact range/calibration/native/device parity and complete wall gain required.|
|3 tested|Global four-reduction canonical Fp2.|Compiler constant folding,carry/register costs and canonical callers;prior18.79%counted reduction scope is not timing;native field/frozen/masks and enclosing gain needed.|
|4 NEW refined/tested|Two-state public causal-mask descriptor.|Moderate typed table/total/terminal adapter;remove O(H*T²) plane/folds,add O(T) prefix state and O(H*T²) lightweight predicates;arbitrary MLE/pad/future/extension/bytes parity and measured peak/complete gain required.|
|5 tested|Compiled Unit/Neg/Scale denominators.|Setup/tag dispatch and caller binding;prior5.923%counted multiply reduction,not clocks;stale plan or no enclosing gain rejects.|
|6 owner|Fresh fixed-context resident complete-pass sweep.|Startup/slope/context/pass/concurrency,lag/drain/bytes/independentverify andpeak;fresh masks everyproof;recurring>20ms/new position rejects50/s for that schedule.|
|7 architecture|GPU NTT locality/structured comparator/streaming/PCS changes.|Qingming CUDA andcuButterfly require modulus,direction,natural order,pads,workspace/hash/transfer pricing;LatticeJolt needs field/PCS/ZK/state review;microbenchmarks are not complete rates.|

Actual seams: argument.rs Tab:66,table_of:313,build/run_slot:338/447,
B::public:716,mask builder:1013,SC_RS:1270,SC_SZC:1709,
verification public terminal:613; grouped.rs:99/149/175 row reader/fold/finals.
The [Rust sketch](causal_mask.rs) is unapplied and uncompiled. Add a typed
causal descriptor before mask allocation, preserve original table positions,
explicit n/cube length, generic private total(), and all final indices.
GroupPoly is Fn+Send+Sync and lacks a row index; therefore implement reading in
the round adapter, then pass exact mask cur/dif into its existing scalar row.
Descriptor is immutable during part scans and bound once after reduction.
Private masks, extensions, RNG and openings are unchanged and fresh each proof.
Verifier Tab dispatch evaluates the recurrence then applies the same selector.
Small dense fallback is useful for frozen/native oracle checks. No merge here.

First owner gate: verifier descriptor/full native terminal refusal and byte
parity, then both closure/grouped/total/census adapters; instrument mask build,
reader and fold shares before complete-slot/block A/B under shared heavy locks.
Next LOCAL: symbolic supp_Ht/supp_S with original-cube MLE and P3/grouped-head
mapping, catching the incorrect product of separately interpolated predicates.
No heavy job was queued. Preserve slower fusion, row-step/API inflation,
small-parent/hash-prefix/reconstruction/padding/privacy negatives.

## Sources and accounting

Six LIVE primary assessments and exact URLs/dates/qualified licenses are in
source-records.json; queries and fetch errors in search-log.json. Newly assessed
older [Jolt comparator structure](https://eprint.iacr.org/2023/1217) informs
the algebra; [small-space](https://eprint.iacr.org/2025/611) informs scratch
accounting. New [Qingming CUDA](https://github.com/uulong950/qingming-g64-ntt-cuda)
and [cuButterfly](https://github.com/TruNcat3/cuButterfly) remain GPU contract
leads, not executed code. [September LatticeJolt](https://a16zcrypto.com/posts/article/lattice-snarks-jolt-post-quantum-faster/)
uses different field/PCS and advertises a forthcoming ZK companion; no P1
acceptance follows. [September author sumcheck explanation](https://www.cs.cmu.edu/~csd-phd-blog/2026/sumcheck-proving/)
was refreshed. PDF403,GitHub Cache miss/Internal Error and unavailable license/
history/commit/capability pages were not bypassed. No commit diff was inspected;
exposed short hashes are not inspected commits. Author rates were not reproduced.

Accepted independently verified complete private8B proofs/passes: **0**;
countable tokens: **0**. DeviceCPUonly; proof contextnull; model passes0.
Steady-state/total-workload rates,startup duration/fraction,witness/proof/
serialization/independent-verification,latency/lag/drain clocks are unmeasured.
No long-context prefill,resident-model pass ordecode proof occurred. Larger
workloads remain allowed; attention growth stays quadratic and fresh masks,
full coverage/privacy and independent verification remain required. >=50 proved
tokens/s remains unachieved.
