# Reversible fraction-tree storage — cycle0110

Run `20261020T181854Z-27090273`, 2026-10-20 UTC. **No proving speed improvement
measured.** Exact reconstruction passes; the full-column plan is demoted because
its selected-array peak exceeds the previous bounded consumer model.

The baseline is frozen R9 U8 helper payload: 420.25 MiB non-DD / 390.25 MiB DD
at 8B T128. The prior prospective adaptive consumer used 36.022216796875 MiB
of selected arrays and about 6.028 / 6.054 leaf generations per original leaf.
Neither that prior model nor this experiment is an implemented private proof.
No production work was removed. Complete private GKR, original-A consistency,
masking, CFS, commitments, PCS, histogram creation and native phase costs remain
unresolved. The previous naive mask-per-intermediate negative still applies.

The tested question was whether retaining one reversible leaf-size buffer could
avoid subtree/source regeneration. A parent satisfies
`N = N_left*D_right + N_right*D_left`, `D = D_left*D_right`.
Given the preserved right child, recover
`D_left = D/D_right`, `N_left = (N-N_right*D_left)/D_right`.
All denominators must be nonzero, including a leaf with zero numerator.

`reversible.py` stores subtree roots at each subtree's first natural-order leaf
slot and preserves right roots. It restores layers from root to leaves, then
feeds a nonmutating layer factory to the existing tiled cubic consumer.
The local layout uses strided reads. OpenVM's inspected implementation instead
bit-reverses leaves for contiguous accesses; no coalescing or bit-reversal gain
is reproduced here. The consumer cannot overwrite this retained buffer: its
folds would destroy right children needed by the next layer.

For n leaves, one build costs `3(n-1)` Fp2 multiplies and `n-1` adds.
Individual recovery costs `3(n-1)` multiplies, `n-1` subtracts and inversions.
Batch recovery costs `6(n-1)-3log2(n)` multiplies, `n-1` subtracts, `log2(n)`
inversions and at most `n/2` prefix elements. A backwards batch pass consumes
inverses directly; there is no copied denominator or inverse-output array.
These are field-operation counts, excluding inversion internals and consumer
arithmetic; they are not CPU instructions or device elapsed time.

At n=2^21, immutable tree storage is nearly128 MiB; reversible tree storage is
64 MiB. Batched reconstruction needs up to16 MiB of prefix scratch. Charging
consumer plane capacities, inactive tails, tiles and factorized equality tables:

| Early streamed rounds q | Selected peak MiB | Peak phase |
|---:|---:|---|
|0|128.0234375|leaf consumer|
|1|96.015625|leaf consumer|
|2|80.01171875|leaf consumer|
|3|80|leaf reconstruction|
|4|80|leaf reconstruction|

The tree alone already exceeds the prior36.022 MiB selected model. These peaks
assume reconstruction scratch is released before the consumer and that backing
can be reused. They exclude original A/source owners, histogram/caches, private
protocol, allocator pools, driver memory and transfers. No native net-memory,
device-fit or speed benefit follows. Larger q no longer helps at the batch-prefix
peak in this implementation. An individual-inverse plan has a different memory
tradeoff and millions of inversions; no native runtime advantage is asserted.

Sequential-column symbolic census for one frozen8B T128 forest:

| Quantity | non-DD | DD |
|---|---:|---:|
|Columns including one global table|84|84|
|Original leaf reads|51,937,536|48,398,592|
|Avoided reads vs prior adaptive model|261,128,448|244,613,376|
|Build Fp2 multiplies|155,812,356|145,195,524|
|Batched recovery Fp2 multiplies|311,620,005|290,386,395|
|Batched recovery inversions|1,569|1,551|
|Recovery subtractions|51,937,452|48,398,508|

Those savings compare prospective schedules. They eliminate no existing native
inverse-cache cost: the256-entry per-attempt U8 reciprocal cache already exists.
Histogram/source generation and final original-A links remain necessary. Ten
count fixtures are audited; T512 geometries are counted only, not admitted profiles.

If f is the unknown exclusive affected fraction of complete proving time, even
free deletion has ceiling `1/(1-f)` before every added cost. There is no numeric
prediction for complete high-end-GPU throughput. The full-column plan already
fails a <=36.022 MiB selected-array goal. Any binding/refusal/order/field drift,
omitted capacity, absent real capacity cliff or slower complete workload also
falsifies a proposed integration benefit.

## Validation and reproduction

Main: 2,838 checks,42 tree cases,306 unmasked consumers,768 control instances.
Sizes2,4,8,16,32,64,256; looked-U8 affine source, table multiplicities including
zero, and arbitrary extension-valued fractions. Both recovery modes complete
two build/restore cycles without a second source scan. Every recovered layer,
cubic row, terminal and four child MLEs matches immutable tuple-field arithmetic.
Zero/one/non-base challenges are included. Root-preserving source swaps change
ordered original MLEs; wrong right child, parent and aliased consumer folds fail
the reference comparison. Zero denominators at every tested leaf placement
refuse even with numerator zero. These controls are not a native privacy gate.

Independent audit: 5,745 checks,21 fixtures,174 restored layers,348 MSB MLE
evaluations,16 source pins,2,090 capacity events,30 rejected undercount shortcuts,
and10 forest profiles. It uses its own tuple multiplication/convolution, Fermat
inverse, immutable forward tree and MSB half-fold. It does not import candidate
mixing or capacity formulas to compute expected values. The earlier successful
audit before adding forest accounting is preserved. No failed experiment.

```
python3 experiments/reversible-fraction-tree-20261020/run_bounded.py probe.py
python3 experiments/reversible-fraction-tree-20261020/account.py
python3 experiments/reversible-fraction-tree-20261020/run_bounded.py validate.py
```

Probe28.352250s /17,768KiB RSS; accounting0.162193s /11,460KiB;
audit0.642078s /15,808KiB. Intel Core Ultra9 185H /WSL2; one worker on first
allowed core0, nice19. Each experiment caps59sCPU/alarm,512MiB address space;
probe/audit parent timeout60s. Estimated64MiB probe/audit,32MiB accounting.
Seed20261020110; source hashes, commands, fixtures and hardware retained.
No build, GPU, dependency installation or downloaded-code execution occurred.

## Primary-source disposition and next action

15 native LIVE queries,9 source records. OpenVM's
[reversible-storage description](https://github.com/openvm-org/stark-backend/blob/main/docs/cuda-backend/gkr-prover.md)
and inspected CUDA inverse step motivated the test. Mutable source date/full
commit alignment remains unavailable; MIT body inspected. Release phase-peak
accounting is a lead, not native evidence.
[Chimera](https://eprint.iacr.org/2026/1388)'s October16 revision reinforces
separating region and enclosing clocks. The newly directly assessed older
[Twist/Shout paper](https://eprint.iacr.org/2025/105), January22,2025 / revised
October17,2026, supplies a separate lookup architecture question; large-table
and curve-PCS claims do not establish a tiny-table private replacement.
ICICLE's inspected full release SHA is version-only, not a kernel diff.
Date/license/commit limits and access failures are in source-records.json.
No author speed was reproduced. External install instructions were ignored.

Twenty-two ranked hypotheses retained. Top3 remain completeGPU+verified
resident1/2/4/8, DDcontext scaling and complete capacity/phase clocks;
all-elevenFZC native A/B precedes lookup redesign. Rank21 is now a tested
capacity negative; rank22 screens one-hot addressing/increments.

Next local: test a bounded reversible-subtree tile with an immutable frontier
and original ordered layer consumer under the prior selected-array budget.
Charge tile reconstruction, frontier capacity, repeated source reads, consumer
tails and batch-prefix lifetimes. Check whether existing per-attempt leaf
reciprocals can avoid final-layer inversion scratch, including lookup/read costs;
this is untested. Keep full-column and all-intermediate-mask negatives intact.

Owner next: actual GPU phase/capacity clocks, independently verified fixed-context
resident1/2/4/8 workloads, DDcontext scaling and all-elevenFZC A/B, with shared
heavy/build locks. No such jobs are launched here.

New independently verified full-stack proofs / passes / positions: **0 /0 /0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model pass or decode occurred. Larger workloads
remain allowed; longer attention context can increase work quadratically.
The complete private8B >=50 proved positions/s high-end-GPU target is unachieved.
No mask/opening reuse, changed native refusal/RNG/transcript timing or privacy
weakening is authorized. R9N-r9-a/b, DDprivacy gate, D32 and narrow D33/D34/D35
scopes remain. Main/Claude reviews; no merge or production patch is proposed.
