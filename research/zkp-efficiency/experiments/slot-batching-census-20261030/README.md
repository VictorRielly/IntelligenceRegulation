# R13 slot batching census

**No measured proving improvement.** A standalone Rust source-metadata
adapter agrees with independently authored Python schedule equations and DFS
on 401 geometry cases / 802 rows / 72,800 numeric comparisons.144 rows correspond
to 12 registered R13 geometries (repeated f_e/activation-group cases), one is
legacy toy and 256 are deliberately unadmitted metadata stress cases. Each is
tested with/without transcript edges; neither native constructors nor
`define`/prover/cryptography executed. The reviewed event ledger is not a
general Rust parser or an independent external review.

At R13 8B/T128,24 pairs share(n,extension,degree); **all 24 are ordered by the
current transcript**. Ignoring transcript edges leaves 21 pairs without the
reviewed point/host dependencies; it does not establish valid batching.
Sixteen named point and 12 host dependencies are retained, including QMM's
row-point reuse/WO overwrite and GMM/UMM's shared point. Optional 24th DD slot
and R13's seven replacement definitions are inspected. All48 controls pass:
28 same-count source mutations,one same-endpoint point-label shuffle,one
main/extension distinction and 18 exact source-anchor mutations. These are
metadata controls, not native soundness/privacy attacks.

Baseline: current serial 23/24-slot schedule. Work eliminated: zero. Added
costs for a redesigned aggregate include simultaneous tables,coefficients,
source/terminal binding and a new proof/privacy argument. Ceiling remains
unknown N/(T-C_critical+A_added); no native exclusive launch fraction exists
here. Falsified: naïve shape-only whole-slot merging that preserves the
current transcript. This does not rule out future versioned aggregation,
public preprocessing, intra-slot work or batching separate proofs.

New independently verified full-stack proofs / passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one affinity-pinned Intel Core Ultra 9
185H CPU worker; **no GPU**. Witness / proof / serialization / verification /
startup / initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model proof passes or decode ran. Metadata
contexts 17/32/64/127/128/256/512 are synthetic/public geometry, not model runs.
Larger workloads remain allowed; increased context can raise dense-attention
work quadratically. The complete private 8B **>=50 proved tokens/s target
remains unachieved**.

Carried historical CPU8B baseline (not rerun/reverified or newly counted):
T128/L32, one 16-thread pass, GPU off, total 478.737 s=0.267370positions/s.
prove_run 393.785 s includes witness 98.348 s / load 17.595 s. Earlier sealing 84.824 s
contains overlapping load 27.151 s / witness 80.897 s. Receipt 922,711,264 B;
verify 42.709 s plus 13.681 s load. Serialization,startup fraction and steady slope
unknown. Never sum nested/overlapping clocks. Current classifier 3B and
RTX 4070 one-block evidence remain different scopes.

Resource envelope: one CPU affinity, nice 19, 30 s CPU / 40 s alarm / 45 s parent,
384 MiB address cap; compile estimate 300 MiB, audit 64 MiB. Compile 0.569 s / 153,356 KiB;
final audit harness 0.418 s / 31,164 KiB (correctness execution,not proof timing).
Initial compile inner-attribute failure and corrected rung geometry inputs
are retained. The first matching algorithms did not authenticate input
geometry; the final 144 registry rows check all seven axes against the pinned
registry plus query width. 8B counts were unaffected by that correction.

Reproduce sequentially from the research directory:

```text
python3 experiments/slot-batching-census-20261030/run_bounded.py prepare
python3 experiments/slot-batching-census-20261030/run_bounded.py compile
python3 experiments/slot-batching-census-20261030/run_bounded.py audit
```

`prepare` intentionally reconstructs the source/metadata fixtures and starts
the copied hypothesis ledger at its prior state; do not run it over a finalized
copy if preserving reports. `reference.py` writes synthetic fixtures and
checks the scalar schedule equations/DFS independently of Rust's extracted
native methods/Floyd-Warshall. Commands and source hashes are retained.

The [integration boundary](INTEGRATION.md) records masks, source claims,
terminals, review prerequisites and the next experiment. No patch is proposed
for production. All counts concern slot metadata; they measure no native
table arithmetic, launch count, hardware parallelism or elapsed savings.
