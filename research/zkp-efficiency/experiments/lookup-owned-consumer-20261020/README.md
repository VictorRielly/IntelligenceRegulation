# Owned lookup-layer consumer and equality factors

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
