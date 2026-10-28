# Lookup fraction-tree consumer lifetimes

Cycle0105 — `20261020T131854Z-4f8a9e18` — 2026-10-20 UTC.
**No proving speed improvement measured.** This is a cost-accounting and
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
