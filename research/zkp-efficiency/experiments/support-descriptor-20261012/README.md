# Compact public support descriptors — cycle 0038

Run `20261012T192555Z-2488fec6`, accessed 2026-10-12. **Synthetic exactness and
storage candidate; no native proving speed improvement measured.** No GPU,
native build, installation, Git, production edit, downloaded-code execution or
external write/message. Research writes exclude runtime/.

Command:

`python3 -B /home/victor/IntelligenceRegulation/research/zkp-efficiency/experiments/support-descriptor-20261012/experiment.py`

Final pass: **1.586442 s, 18,332 KiB peak RSS**, seed 2026101238, one pinned
nice19 Intel Core Ultra 9 185H thread, Python 3.10.12. Wall/CPU alarm 59 seconds,
512 MiB address-space cap, 32 MiB estimated memory. Command, wrapper completion,
log and code hashes are retained. This clock measures the synthetic test only.

84 fixtures, 113,792 endpoint values, 398,272 degree-0..6 samples, 568 folded
states, 2,009 independent original-cube MLE evaluations, 84 factored MLEs and
terminals, 336 public extension values, 70 support-sensitive complete tail sums
and 105 independently evaluated support-sensitive points pass. The fixtures
cover all nine domain layouts, arbitrary Fp2/base/Boolean/zero challenges,
ragged bounds, interleaved head padding, prefix tiling and row-lifted D/F/L/Tab.
Toy/rung attention geometry is exercised as public tables, without constructing
any native witness or receipt. Small synthetic geometries are not admitted
profiles. The 21 controls include native Q/Kv/S row-lift refusals.

The independent source port enumerates logical heads with the native head-slot
permutation and writes flat support indices. It imports neither the descriptor
nor its field/folding code. The oracle sums original Boolean cells against bit
products with schoolbook extension-field convolution. Native source snapshots
and hashes are retained under native/ and native-manifest.json.

The first run failed a negative control: assigning every coordinate the same
challenge gave equal values for two DIFFERENT head tables, because the changed
cells had equal bit weight. It did not reveal a candidate mismatch. The complete
initial source/log/command/completion is retained under
initial-negative-point-collision/. Distinct coordinate challenges correct the
control. The final pass is the only completed successful result; no selective
performance rerun or native result is claimed.

## Exact contract and mechanism

The source already has closed-form support CONSTRUCTORS (pad.rs:132), but they
still materialize a vector. B::supp at argument.rs:810 turns it into a full Fp2
table, repeating each coarse cell over trailing coordinates. The candidate
removes this materialization and its dense folds, preserving the same MLE.

For a threshold `[x < limit]`, binding MSB coordinates leaves only two values:
`lo` for a remaining suffix outside the threshold and `hi` for one inside.
At a bound bit r, if the limit bit is 1 set
`lo = hi + r*(lo-hi)`; if it is 0 set
`hi = lo + (1-r)*(hi-lo)`. At the last bit the scalar is lo. Full axes are
constant one. Completed factors are absorbed into the next factor's hi,
so no per-row field multiplication is added. Boolean endpoint readers check
the future axes, then select lo or hi from one residual integer comparison.
Three retained Fp2 fields and at most three axis records describe these domains.

Factorization is valid because the coordinate intervals are disjoint. The
constructor refuses overlaps. Multiplying arbitrary separately interpolated
predicates on shared coordinates, or replacing their product with the MLE of
their Boolean product, changes the polynomial. The control catches this for
causal mask times support: at t=2,j=3, the separate product is 8 while the
merged Boolean table's MLE is 2. The native mask and support remain separate.

Specific mapping obligations:

- True head slots satisfy `slot % (h_pad/kv_heads) < q_heads/kv_heads`, using
  LOW slot bits. A flat `[slot < q_heads]` changes grouped-head support.
- `supp_Ht` in SC_SZC occupies the LEADING h,t coordinates and is constant over
  the entire trailing padded j axis. It cannot be replaced by `supp_S`.
- Natural D/F/L/Tab support is zero on additional LEADING row-lift coordinates.
  Repeated byte TABLE VALUES under ruling P-3 do not authorize repeated byte
  SUPPORT: only the original 256 multiplicity entries are supported.
- Shape::new at shape.rs:257 refuses row-lifted Q/Kv/S; the candidate retains
  those refusals. Ruling P-3 means the domain-to-row-width lift here, not the
  separate P3 private-weight product scope. No admission or privacy ruling.
- The frozen toy carries no support-table machinery. The caller must preserve
  `carries_pad_rule`, `pads(dom)`, table count/order, degree and challenge gates.
  Public zero extensions still apply every `(1-e)` selector; native e=0/e=1
  refusals are unchanged and remain unexecuted here.

The sensitive expression covers the support-bearing RS summand, the SZC row
and score hosts, and both pad-zero groups on arbitrary synthetic planes. It
does not reproduce the full nonlinear/LogUp bracket or an honest witness.
LogUp arms must still speak on padded positions. No short-circuiting of entire
rows, future scores or private tables is justified by a zero support value.

## Baseline, eliminated work, costs and end-to-end ceiling

For the pinned m125 head geometry (12 query / 4 KV / 16 padded heads), T512
has N=4,194,304 words before public extension. SC_SZC materializes TWO N-word
support tables (S and tiled Ht), **128 MiB logical Fp2 payload**, and performs
2(N-1)=8,388,606 dense interpolations. With full token axes only the two low
head bits matter: this descriptor uses **four interpolations total** across
both supports, six retained Fp2 fields combined, and two axis records.
Native Vec capacity, allocator overhead and parent peaks are not measured.
The clock table displays the slot length INCLUDING its extension; that must
not double this initial data-table census.

| Conditional geometry | T | Two SZC support payloads | Dense -> descriptor interpolations |
|---|---:|---:|---:|
|16 padded heads, native m125 head map|512|128 MiB|8,388,606 -> 4|
|16 padded heads, hypothetical larger context|1,024|512 MiB|33,554,430 -> 4|
|32 padded heads, illustrative grouped map|512|256 MiB|16,777,214 -> 4|
|32 padded heads, hypothetical larger context|4,096|16 GiB|1,073,741,822 -> 4|

Larger rows are allocation-free counts, not admitted profiles or measured peaks.
The one S support in the sequential SC_RS slot is priced separately; its peak
cannot be added to SC_SZC. Prior causal-mask savings are another table, and the
largest simultaneous native savings require measuring actual lifetimes.

Added costs are index shifts/masks/comparisons, branch/dispatch and metadata
loads, construction/shape validation, typed total/round/census/final adapters,
and O(n) verifier evaluation. At the m125 T512 shape the two-support proposed
schedule needs 16,777,212 endpoint reads and at most that many comparisons.
General ragged S/Ht axes can require up to three/two comparisons per read.
Read counters in result.json include diagnostic repeats and are not native
schedule costs. Six transient field words per descriptor is a logical working
bound, not a measured allocation. No GPU occupancy or compiler cost is known.
Common cur/dif/sample arithmetic, private/Eq/mask tables, witness, per-proof
randomness, commitments, PCS, transfers and serialization remain.

For an accepted complete workload, ceiling is
`Npositions/(Ttotal-Csupport_build_fold_eval+Cnew)`, with ideal upper bound
`Npositions/(Ttotal-Csupport_build_fold_eval)`. There is no numeric accepted
8B ceiling because the total and isolated support clocks are absent.

Historical b2 GPU-assisted synthetic one-block T512/RTX4070Laptop/two-thread
profile: 5.77 s external witness, 16.864 s prover, 0.028 s serialization,
0.82 s in-process byte verification, 27.523873 s enclosing test wall.
SC_RS/SC_SZC are 0.600/7.794 s of proving; deleting BOTH WHOLE slots would save
at most 8.394 s on that diagnostic. Support work is a subset. Their verifier
clocks are 0.191/0.274 s, reported separately. Startup is not isolated; prove
also includes recurring native witness/commit preparation. Raw b2 log hash is
verified against its retained report. No one-block token count is promoted.

The historical synthetic 12-block diagnostic has 408.609226 s wall, 318.22 s
combined run-prover, 12.15 s in-process verification and 484,107,456 bytes;
fresh-process verification is false. The reboot-interrupted CLI has no terminal
result. Saved state=running is not liveness or completed proof evidence.

Falsify any original-cube value, partial endpoint/sample/terminal, mapping,
support-host/pad/future-score/extension/refusal/mask/RNG/transcript/receipt/privacy
mismatch, failure of the native shape/profile premise, or peak/enclosing runtime
regression after charging every adapter and reader cost. Lower fold counts
alone do not establish throughput.

## Integration and next action

Unapplied, uncompiled [Rust sketch](support.rs), validated Python descriptor,
independent source port and owner [handoff](../../handoffs/20261012-support-descriptor.md).
Actual read-only seams are private_block/argument.rs Tab:68, B::supp:810,
tile_rep:835, build_tables_at:338, total/run_slot:447, verifier terminal:613;
pad.rs:48/132/335; shape.rs:257/883; witness.rs:211; and
zkp-core/src/sumcheck/grouped.rs:99/149/175. Keep explicit original cube length
and table positions; a dense empty placeholder is not a valid adapter.

First owner gate: reconstruct descriptors from the admitted public shape and
prove verifier terminal/refusal/frozen-byte parity against dense tables. Then
add BOTH generic closure and grouped round readers, generic private total,
extensions and census; descriptors are immutable during parallel part scans
and bind once after reduction. Measure support constructor/reader/fold/final
shares before guarded complete-slot/block A/B with fresh independent verification.
No heavy job was launched or queued. Main/Claude owns review and integration.

Next LOCAL: a heterogeneous-table driver with explicit cube size, preserving
total/sample/final ordering and all public extension rounds for the causal and
support descriptors together. Use an independent original-cube polynomial
oracle and deliberately inconsistent synthetic witnesses. It complements the
owned native SC_SZC masked-transcript tests; it cannot close those obligations.

## Ranked queue and sources

|Rank|Hypothesis and expected complete-proof scope|Prerequisites, added costs and rejection|
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness; largest measured remaining block share.|CUDA/memory/mask integration; isolate both witness clocks, brackets/folds/transfers; native transcript/refusals/privacy and independently verified complete A/B; enclosing/peak regression rejects.|
|2 owner|Exact full-K split-int16 FFN down.|Packing/two products/i64/requant/workspace; isolated down share unknown; exact range/calibration/device gates and complete gain required.|
|3 tested|Global four-reduction canonical Fp2.|Prior 18.79% counted reduction scope is not runtime; canonical callers, compiler/carry/register and native bytes remain open; no enclosing gain demotes.|
|4 NEW refined/tested|Public support descriptors alongside separate causal descriptor.|Remove quadratic public support vectors/folds, add constant state and integer reads; moderate driver cost; arbitrary MLE/mapping/profile/extension/byte parity and measured enclosing/peak gain required.|
|5 tested|Compiled Unit/Neg/Scale denominators.|Preparation/tag binding and native compiler costs; 5.923% counted multiply scope is not timing; stale plan or enclosing regression rejects.|
|6 owner|Fresh fixed-context resident complete-pass startup/slope/lag/drain sweep.|Measure full workload/context/passes/bytes/independent verification with fresh masks; recurring >20 ms/new position rejects 50/s for that schedule; prefill T² and authenticated decode separate.|
|7 architecture, refined filter|Structured public PCS/GPU NTT/composition; projective basis demoted pending native affected share.|Field/layout/hiding/query/soundness/state migration and extra sumchecks; native cost profile required. Plonky3 author negative prevents adopting kernel-only projective claims.|

Six LIVE primary records with exact URLs/access dates/date bases/licenses and
inspected-commit scope are in source-records.json and appended to sources.jsonl.
Relevant new evidence is [Plonky3's author negative](https://github.com/Plonky3/Plonky3/pull/1949)
(binding gain does not become enclosing WHIR gain) and newly assessed older
[Jagged PCS](https://eprint.iacr.org/2025/917) (structured public indexing with
additional reduction/PCS obligations). Metadata inspected; its PDF fetch 403
prevents claiming a full protocol/code audit. The
[Oct8 resettable-NIZK revision](https://eprint.iacr.org/2026/1036) reinforces
keeping fresh per-proof randomness during residency; no compiler was adopted.
[September Plonky3 release](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0)
is pinned via its version/CHANGELOG diff, not an arithmetic diff.
[Jolt MLE traits](https://jolt.a16zcrypto.com/how/appendix/multilinear-extensions.html)
inform typed reading; the doc has no verified revision date. MIT terms were
inspected on Jolt, Apache terms and MIT-or-Apache manifest on Plonky3. No author
performance was reproduced. Commit/PDF fetch blockers and queries are saved.

Accepted independently verified complete private 8B proofs/passes: **0**;
countable tokens: **0**. CPU only; proof context null; passes 0. Steady-state
and total-workload rates, startup duration/fraction, witness/proof/serialization/
independent-verification, latency/lag/drain clocks are unmeasured. No long-context
prefill, resident-model pass or decode proof occurred. The >=50 proved-token/s
target remains unachieved. Larger workloads are allowed; quadratic attention,
fresh randomness, full coverage and decided privacy remain obligations.
