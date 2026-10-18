# Unapplied candidate — pending previous fold plus next weighted round

Cycle0071, run `20261018T002105Z-32d7e4fc`,2026-10-18UTC.
[Code, evidence and clocks](../experiments/pending-fold-weighted-round-20261018/README.md).
**Arithmetic parity/logical read reduction only. No native proving gain.**

Interface: research `PendingRows` in
`experiments/pending-fold-weighted-round-20261018/pending.rs` implements a
whitespace-identical copy of native `SumcheckRounds`: n_vars,degree,round,
fold,immutable finals. It owns C*N Fp2 synthetic V values, independent public
row points per column, public column point and prefix weights. MSB row bits
precede MSB column bits. `round(j)` emits all4 unmasked samples; `fold(r)`
accepts only that message's challenge. Nonfinal row folds are pending;
the next row contraction folds the previous challenge while accumulating.
The last fold drains before immutable finals; zero-variable construction is
settled. No transcript/mask/randomness operation occurs in the adapter.

Native seam: captured current owner
`ops/zkp-mvp/gpu-zerocheck/zkp-core/src/sumcheck/rounds.rs:22` and
`prove_rounds:33`, masked driver in `zkp-core/src/sumcheck.rs`;
`hashline/src/private_block/argument.rs` owns the actual polynomial and
`protocol.rs`/`shape.rs`/`layout.rs` own H/M/PCS and links. Native hashes and
captures are in source-pins.json. No native files or production trait changed.
The E*S*V probe needs a complete separately reviewed lookup construction;
it is not a frozen native lookup transcript replacement or arbitrary ClosureRounds.

Validation:132 fixtures including84 prior,3,020 round values,396 terminals,
755 whole-cube masked-chain rounds,23 control categories (8 lifecycle checks),
3,031 challenge-causality checks and753 final sensitivities. Independent
original-table/convolution/closed-form-MLE/monomial audit:7,795 checks.
Final main1.959028s/RSS33,392KiB including compilation/references;
compiler143,700KiB; audit7.184318s/RSS28,080KiB. Fp2 entry-point counter
experiment1.370311s, compiler144,844KiB: added add/mul0, sub3*(W-1).
One Core Ultra9 185H CPU0 thread,nice19,seed2026101871,each<=59s/512MiB AS.
Initial mutable-finish passing adapter/results retained before native seam
refinement. No native proof/Fiat-Shamir/RNG/privacy theorem/GPU evidence.

Core row reads4*C*(N-1) -> C*(3*N-2), writes unchangedC*(N-1) forN>=2;
N1 no row work,N2 no saving. Prior T32 four-group census:
46,857,908 ->35,143,514 logical field reads;178.747467MiB fewer logical
reads,19.9999% fewer row read+writes. Additional column reads660/subs330;
23,426,212 equality-weight multiplications and all folds remain.
Counts exclude input-copy/materialization/common tail/output/masks/PCS/GKR
and original-witness buffers. Same V working allocation and O(logN) DFS.
Large counted groups refused by local cap; no large allocation or benchmark.
Byte-only core ratio<=1.249998x is not a runtime ceiling. Full end-to-end
ceiling unknown: Nproved/(Tbaseline-Caffected+Cadded), Caffected unmeasured.
Previous native fusion regression remains demoted.

Review gates: every round/final/order/refusal and 0/1/half extension point;
private-zero schedule independence; immutable terminal freshness and no
current/future-challenge access; original ordered-A and full-i64 wrapping
links for83 columns; distinct-point reduction; selector/E mixture terminals;
fresh whole-cube cubic masks/extensions/H/M/PCS; joint privacy/soundness.
All singleton/D-C/joint-pad/off-cube-product/endpoint-history negatives remain.
Fixed public shape support only, never hidden prompt length/selector or private
mask sparsity. No reused masks, openings or weaker privacy for amortization.
Native crate/transcript/RNG/proof-byte gates and independently verified full
workload timings/peak/transfer/serialization/drain are still owed.
Falsify on any mismatch, stale final, privacy/refusal change or no enclosing
gain after costs; do not infer speed from logical reads or synthetic elapsed.

Owner GPU K1–K4 verdict and complete resident-workload slopes stay first.
Next local question: actual native late-stage decomposed NTT root products
versus table words/cache/integer costs, retaining first6-stage shifts and all
prior memory negatives. Main/Claude reviews/integrates; no merge/heavy job.
New target proofs/passes/positions0/0/0; >=50/s unchanged/unachieved.
Saved handoff does not establish message delivery.
