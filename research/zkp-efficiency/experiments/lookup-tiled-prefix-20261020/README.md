# Budget-adaptive tiled lookup prefix

Cycle0107 — `20261020T151854Z-beab78ce` — 2026-10-20 UTC.
**No proving speed improvement measured.** A budget-adaptive tiled consumer
improves the selected lookup-array memory/work tradeoff relative to streaming
every regenerated layer. This is unmasked arithmetic and a capacity model,
not a native private proof or measured device memory.

The consumer emits a complete cubic sumcheck row before accepting its global
challenge. For q early rounds it revisits the full ordered source q times,
then makes one more scan to materialize four independently folded residual
MLEs. A tile uses only preceding challenges. The degree-two bracket is
N_left*D_right + N_right*D_left + lambda*D_left*D_right, weighted by the
equality MLE, so the sampled row is cubic. Folding aggregate products instead
of the four original MLEs is rejected. No rounds, masks or openings are removed.

| Schedule, frozen R9 8B T128 | Modeled MiB | Tree nodes, nonDD / DD | Leaves, nonDD / DD |
|---|---:|---:|---:|
| Prior owned reference | 68.030029 | 3.870021x / 3.884890x | 5.664335x / 5.664165x |
| Fixed one streamed round | 36.022217 | 5.740043x / 5.769782x | 9.328671x / 9.328330x |
| Adaptive 32MiB destination cap | 36.022217 | 3.870021x / 3.884890x | 6.027740x / 6.054142x |
| Adaptive 16MiB destination cap | 20.018311 | 4.051723x / 4.079879x | 6.754551x / 6.834098x |
| Adaptive 8MiB destination cap | 12.014404 | 4.505980x / 4.567351x | 8.450441x / 8.556499x |


These are ratios to **one fraction-forest build**, not native H writing or
elapsed proof time. Scratch-aware q0 is68.030029MiB versus cycle0106's narrower
68.028503MiB; this cycle includes explicit temporary tiles, value-stack,
message/scalar allowance. Equality factor tables have fixed final capacity
and require no inversions, even at0/1 challenges. Direct equality products
were retained as a differential control; final streaming uses the prior
factorized equality tables, preserving its total table-entry count.

The adaptive32MiB destination threshold streams **nine leaf-layer services**
only. It adds18,874,368 original leaf reads: +6.4157%/+6.8850% over the
nonDD/DD q0 schedules. Tree-node and scalar-fold counts remain unchanged.
At a leaf layer regeneration has no internal tree nodes. Fixed q1 instead
streams every uncached layer and increases treework to5.740/5.770x; it is a
useful dominated schedule, not the recommended default. Adaptive16MiB saves
more arrays while adding internal recomputation and folds. Cached children
stay immutable and are copied exactly as in the prior consumer.

At COUNTED ONLY T512, adaptive32MiB destination gives36.022461MiB, versus
q0 260.053711MiB, but treework rises6.308577->7.459015x nonDD and
5.931400->6.799875x DD. Leaf work rises8.272625->12.538831x and
7.881293->11.307475x. The8MiB request with qmax4 misses its destination cap
and is explicitly flagged false (peak20.018555MiB). These are unregistered
T512 fixtures, not admitted profiles, allocations, proofs or throughput.

Ten public frozenR9 w32/fE9/cap32 fixtures are retained. The latest MVP_STATUS
fidelity-oriented LOW proposal changes layout and is excluded. Counts omit
original A/model/source storage, other H/M, private GKR masks/CFS/PCS, encoded
commitments/trees, device backing/allocator growth, transfers, launches and
concurrent owners. New mask/claim/PCS site counts are null. The symbolic
schedule is conditional on releasing each owner before the next service;
its value-stack allowance is not a compiler or native allocation bound.
The harness retains reference arrays; CPU RSS is not this modeled peak.

Final probe: 2934 checks, 225 tiny consumers,
14 controls. Independent audit: 240 randomized
cost schedules, 1680 cost mutations, 70 original Boolean-basis
cases, causal scan-boundary checks and9 unchanged source pins.
All cubic rows, interpolated claim chain, terminal values and four original
MLE evaluations match the independent reference and prior owned consumer.
Controls cover wrong-site permutation surviving a root, changed original
leaf/order/point, guessed challenges, source drift between scans, altered
samples/terminal, zero denominator at zero multiplicity, invalid prefix,
missing challenge and the incorrect aggregate-product shortcut.
F65537 tiny arithmetic only; native Goldilocks Fp2, masking, Fiat-Shamir,
receipt verification, privacy and native refusal equivalence remain untested.

Commands (seed20261020107, audit20261020108):
```
python3 experiments/lookup-tiled-prefix-20261020/run_bounded.py probe.py
python3 experiments/lookup-tiled-prefix-20261020/run_bounded.py validate.py
```
One CPU thread, first allowed core, nice19;59s CPU/alarm,60s parent,
512MiB address-space cap, estimated64MiB. Intel Core Ultra9 185H /WSL2;
accelerator not invoked. Probe 2.304326s /31796KiB;
independent audit 0.095858s /16308KiB.
Initial direct-equality version is retained. Successful passes were refined
with factorized equality, adaptive public budgets, source-drift control and
an explicit unmet-cap flag; final probe/audit pass. No failed experiment.

Baseline potentially removed is only selected recurring U8 helper work after
a reviewed protocol replacement. This experiment removes full-width arrays
inside that prospective consumer. Added costs include every source scan,
regenerated node, checkpoint copy, prefix reconstruction, fold, equality
evaluation, original ordered-A terminal link, global histogram, original
refusal and fresh private proof machinery. If f is the unknown exclusive
affected time fraction, even free deletion has speed ceiling<=1/(1-f), before
these new costs. No numeric complete high-end GPU rate follows. Falsify on
any original binding/exactness/refusal/privacy/soundness mismatch, hidden
retention/scan requirement, missing cap, irrelevant capacity cliff or slower
complete workload. A violated capacity model rejects this selected schedule,
not every possible streaming GKR construction.

Eleven LIVE queries produced eight primary source/disposition records,
ledger631->639. Existing [Plonky3 source](https://docs.rs/p3-sumcheck/latest/src/p3_sumcheck/strategy.rs.html)
uses resident table slices; its streaming tail is not a one-scan oracle.
The [rc.2 release](https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.2)
lists fused bind/measure and source-layout work; its full version commit
fe5e46d755b8a7d9069778361e21b33e5978b377 changes Cargo versions only.
Direct PR/pinned-source/history fetch failures and documentation/release
version differences are retained. Apache2.0 license text inspected; no
optimization diff pinned or external code run. Release month/day renders,
exact year/update timestamp unverified in this cycle.
Newly screened [2012 GPU GKR](https://arxiv.org/abs/1202.1350), revised
February22,2012, keeps the circuit in host memory and two layers on device,
including transfers in its author timings; old hardware gains do not transfer.
[Chimera](https://eprint.iacr.org/2026/1388), revised October16,2026, supplies a
different-backend chunk-to-resident method, not a reproduced gain here.
Hobbit,2024/524 and Fold-DCS are explicit refreshes, not new discoveries.
Exact dates, URLs, access limits, license and commit scope: source-records.json.

Twenty ranked hypotheses retained; top three remain whole-GPU clocks plus
verified resident1/2/4/8, DD larger-context scaling and actual capacity/exclusive
clocks. Rank7 now prefers budget-adaptive streaming over fixed q. Native
FZC compiler A/B remains ahead of this protocol redesign. Rotation retains
NTT/commitments, sumcheck/GKR, lookup/softmax, memory, amortization,
quantization/arithmetic and composition; next emphasize commitments.

Rust seam: frozenR9 protocol::u8_denominator_inverses/helper_inverses_u8/write_h,
shape::lookups_per_position/claim_sites, layout::lookups_at,
argument::helper_sum/SC_TAB. Research patch: tiled.py, probe.py, validate.py.
All roots/intermediates stay private, one global histogram is committed before
challenges,83 original ordered U8 links atT128/85 atcountedT512 remain required.
Do not treat root equality or semantic link counts as native binding or actual
mask/claim/PCS sites. Fresh randomness and restricted openings remain; no mask,
opening or cross-challenge inverse reuse. R9N-r9-a/b, DD privacy gate, D32
fidelity and narrow D33/D34/D35 scopes are preserved. No Rust patch ready.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; increasing context can increase attention work quadratically.
Private 8B >=50 proved positions/s on RTX 5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verification
42.709s + public load13.681s; recheck34.395s + load10.739s. Startup fraction,
isolated serialization and steady slope unknown. This is not a high-end GPU result.

Next local: port this consumer to exact native Goldilocks Fp2 arithmetic
with a synthetic ordered U8 reader using the same per-attempt denominator
cache/refusal rules. Differentially check every original helper term, all
sample rows and terminal MLEs, including zero denominators at zero multiplicity.
Keep source arrays immutable; never cache inverse results across challenges.

Next owner: complete GPU phase/capacity clocks and verified fixed-context
resident1/2/4/8 workloads, DD context scaling and all-eleven FZC compiler A/B
under shared locks. Count only independently verified complete receipts and
retain fresh masks. Main/Claude reviews any integration; no merge here.

Only research excluding runtime written. No production/Git/build/GPU/install/
external writes/messages/purchases/escalation. Saved reports do not establish
external delivery.
