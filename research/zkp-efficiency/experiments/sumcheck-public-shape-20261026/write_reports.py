import datetime
import json
from pathlib import Path

P=Path(__file__).resolve().parent
R=P.parents[1]
run='20261026T182925Z-b116a67c'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((P/'result.json').read_text())
audit=json.loads((P/'audit-result.json').read_text())

summary=f'''# ZKP efficiency progress

Cycle 0126 complete — `{run}` — 2026-10-26 UTC.

**No proving speedup measured.** A CPU arithmetic model replaces repeated
round-interpolation denominators with fixed inverse factorials and finite
differences. It passes {result['checks']:,} checks: 108 fixtures, 1,836 evaluation
points and 40 synthetic masked sumcheck chains covering 120 rounds, plus ten
control types. A separate source/count audit passes {audit['checks']} checks.
The checks use a separately authored Vandermonde/direct-cube oracle; the
transcript is a SHA256 mock. No native proof or privacy gate ran.

At degree 5, source-level work changes from 36 extension-field products and
six base-field inversions to five products and no inversions, adding 15
extension-field subtractions. The candidate adds a 96-byte stack buffer,
initialization/copy and dispatch. Compiler effects and end-to-end benefit are
unknown. The base R12 8B T128 block verifier has only 370 interpolation calls
(388 with DD32); this removes no dense cube scans, folds, commitments or masks.
The uncompiled, unapplied Rust patch is parked for native clocks.

Model: {result['elapsed_seconds']:.6f} s / {result['max_rss_kib']:,} KiB RSS;
audit: {audit['elapsed_seconds']:.6f} s / {audit['max_rss_kib']:,} KiB RSS. Both
used one Intel Core Ultra 9 185H CPU core, nice 19, 30-second CPU/alarm caps,
256 MiB address-space cap and a 64 MiB memory estimate. Diagnostic clocks only.
Seven primary-source records were appended from 13 LIVE result batches.
All 38 prior hypotheses remain; two were refined and one added.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Witness, proof, serialization,
verification, startup and initial-prefill clocks; startup fraction; proof
latency/bytes; steady-state and total-workload rates: **unmeasured**. No long
prefill, resident-model proof series or decode ran. Larger workloads remain
allowed; attention can grow quadratically. The complete private 8B / >=50
proved tokens/s high-end GPU target remains unachieved.

Next owner action: native interpolation/constructor and enclosing proof clocks,
then verified fixed-context resident 1/2/4/8 workloads under shared locks.
Next local test: build the 256 distinct challenge-encoded lookup rows once
within each proof, then tile them, preserving fresh challenges and all refusals.

[Experiment](experiments/sumcheck-public-shape-20261026/README.md),
[dated report](progress/{run}.md),
[handoff](handoffs/20261026-finite-difference-interpolation.md).
Saved reports do not establish user-message delivery or supervisor liveness.
'''

detail=f'''# Cycle 0126 — public preparation audit and exact interpolation candidate

Run `{run}`. Checkpoint UTC: {now}.

No complete-proof improvement was measured. The baseline is the source-pinned
native R12 `zkp-core/src/mle.rs::interpolate_eval`, unchanged in the separately
pinned earlier GPU tree and R12 review tree. For m samples at nodes 0 through
m-1, it builds m Lagrange denominators and calls m base-field inversions per
evaluation. Fixed sample counts can reuse inverse factorials; round values and
evaluation points cannot be reused between proofs.

The candidate computes forward differences in one six-word stack buffer,
scales difference k by the fixed inverse of k!, then uses nested Newton
evaluation. Only public sample count selects the fast path, for m=2..6.
Empty, singleton and larger inputs retain the original generic body.
No division by an evaluation point is introduced, so transcript challenges
equal to any interpolation node work without an extra refusal or resampling.
The native degree range 2..5 uses m=3..6; lower-degree grouped brackets are
also covered by m=2. All arithmetic is exact Goldilocks Fp2 with u^2=7.

Validation: {result['checks']:,} checks, 108 fixtures / 1,836 points, arbitrary
and boundary base/extension values, all sample nodes, 40 synthetic CFS-algebra
chains / 120 rounds, 240 masked-plus-unmasked rows and ten control types.
A separate modular Vandermonde solve followed by monomial Horner evaluates
arbitrary sample vectors. Direct original-cube MLE products and expanded CFS
algebra check all chain claims and terminals. Both reference and candidate
were authored by this researcher; this is algorithmic independence, not an
independent native prover implementation. The SHA256 transcript mock checks
diagnostic byte/challenge chains and equal malformed-round refusals; it does
not execute native BLAKE3, CFS masking, openings, PCS or the native verifier.

The final one-buffer model takes {result['elapsed_seconds']:.6f} s and
{result['max_rss_kib']:,} KiB RSS. The separate source/count audit passes
{audit['checks']} checks with 16 snapshot pins (15 code pins plus a concurrently
updated coordination document), in {audit['elapsed_seconds']:.6f} s /
{audit['max_rss_kib']:,} KiB RSS. One core, nice 19, 30-second CPU/alarm,
35-second parent timeout, 256 MiB address-space cap, 64 MiB estimated memory.
The initial two-buffer passing result is retained; the one-buffer refinement
justifies repeating the model. These are CPU diagnostic clocks, shared box,
not proving/verification speed measurements.

| Degree | Samples | Fp2 products before / after | Base inversions before / after | Added Fp2 subtractions |
|---:|---:|---:|---:|---:|
| 2 | 3 | 9 / 2 | 3 / 0 | 3 |
| 3 | 4 | 16 / 3 | 4 / 0 | 6 |
| 4 | 5 | 25 / 4 | 5 / 0 | 10 |
| 5 | 6 | 36 / 5 | 6 / 0 | 15 |

The audit checks executed API counts against independent closed forms.
For m samples, the baseline has m(m-1) base denominator products and
sub-base operations, m multiply-base operations and m additions. The new
path has m-1 multiply-base/sub-base/product/add calls and m(m-1)/2 new full
extension subtractions. The patch adds 96 bytes of stack scratch, its clear
and input copy, a public length dispatch and 48 bytes of constants. These are
source-level counts. Inlining, unrolling, constant folding, instruction
counts, stack traffic and total native latency are unknown. In particular,
the compiler may already remove some baseline constant arithmetic.

An honest base R12 8B T128 block verifier has 370 interpolation calls, 1,469
source inversions removed, 5,062 Fp2 products removed and 2,346 Fp2 subtractions
added. DD32 adds one slot: 388 calls, 1,559 inversions, 5,440 products removed
and 2,526 subtractions added. T32/T64 and frozen-toy counts are also retained.
These are verifier counts only, exclude token/endpoint stages, and do not
describe the selected LOW+h24 R13 fidelity profile. They do not measure a
prover speedup or establish complete-model GPU compatibility. The work grows
with round count, while dense attention work can grow quadratically with T.

The five public constructor audit distinguishes `B::supp`, `rope_tables_at`,
`table_values_u8_at`, `table_values_exp_at` and `table_values_act_at`.
Support/RoPE reuse requires full checked shape/domain/cube and authenticated
table identity; keep tiling and all admission checks. The last three finished
encodings depend on fresh gamma/beta and cannot be cached by shape. Equality
tables also depend on fresh points. Existing NTT/device residency and prior
partial-LRU, metadata, fraction-tree and masking negatives remain preserved.

Two initial audit failures are retained. One detected a concurrent change in
the coordination log; all tested code pins remained stable. The audit now
records the document change separately while enforcing code pins. The other
caught an incorrect cross-branch assumption: native R12's CUDA module lacks
`DevFzcRounds`, which exists in the earlier GPU tree. Both use the same core
interpolator, but GPU incidence must be established separately. The corrected
audit pins the earlier device implementation explicitly and asserts the R12
distinction. No failed test or source mismatch was silently discarded.

Integration seam: `ops/zkp-mvp/trained-1b/zkp-core/src/mle.rs:252`.
`finite-difference.patch` inserts one fast branch into this function and
retains the generic body. It is unapplied and uncompiled. Native
`ClosureRounds`, `GroupedEqRounds` and `sumcheck::verify` call the shared
function; the earlier GPU branch's host-side fold calls its own matching
copy. Owner review, compiler inspection, field differentials, golden masked
round/transcript/next-challenge/receipt bytes, failure/refusal controls,
independent fresh-process full-stack verification and current privacy gates
remain owed. No cached masks, challenges, witness data or openings.

Baseline / removed / added / ceiling / falsification: remove only the scalar
arithmetic counted above; retain dense scans/folds, witness, fresh masking,
commitments, transfer, serialization and verification. Add differences,
scratch and dispatch. With unknown truly removable critical-path fraction f,
even free deletion is bounded by 1/(1-f), before added costs. No numeric
end-to-end rate follows. Reject any arithmetic/node/order/coordinate/byte/
RNG/refusal/privacy mismatch, compiler-erased baseline cost, absent incidence,
or regression in the enclosing independently verified workload. Whole-prover
GPU/resident work, DD-context scaling and complete exclusive clocks remain
the top three priorities. The scalar candidate is parked behind them.

Sources searched: current StateSync preparation papers/article and release
metadata, Efficient Sumcheck, gnark's October release, the newly screened
zkDuel CUDA/Triton artifact, and newly assessed older Newton/Lagrange
interpolation via the author-hosted Berrut–Trefethen 2004 paper and NIST.
Thaler's paper was already assessed; its historical code/license landing was
newly inspected. Seven primary records append to 807 existing records.
No author timing was reproduced. StateSync's current license body is BSL1.1
for versions after v1.1.0, with a production verification grant; no code was
imported. Efficient Sumcheck's current wire domain differs. zkDuel has base
Goldilocks kernels, not this Fp2/private stack. Its exact date/commit and MIT
license body were unavailable. Commit429, cache misses and inconsistent
release-page/current-README version rendering are recorded, without bypass.
The older paper explicitly dates electronic publication July30,2004; the
publisher has a separate August4,2006 online label. Its numerical stability
claims do not transfer to finite fields. Exact records and all 13 native
LIVE result batches are retained. No external code was executed.

New completed independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context / accelerator: **none**. Device: one Intel
Core Ultra 9 185H CPU worker. Witness/proof/serialization/verification,
startup/initial-prefill durations, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long-context
prefill, resident-model proof series or decode ran. Longer workloads remain
allowed; attention may grow quadratically. The private 8B / >=50 proved
tokens/s RTX5090 or named high-end GPU target remains unachieved.

Carried historical diagnostic, not rerun/reverified: nonDD 8B T128/L32,
one 16-thread CPU pass, GPU off, total478.737s =0.267370positions/s.
prove_run393.785s includes witness98.348s and load17.595s. Seal84.824s overlaps
and is not additive. Receipt922711264B; freshverify42.709s+load13.681s;
recheck34.395s+load10.739s. Startup fraction, isolated serialization and
steady slope unknown. No GPU or 8B privacy acceptance follows. The latest
owner R12 diagnostics and chosen LOW+h24 fidelity stack do not replace the
research target or supply missing complete-GPU clocks.

Next local experiment: at native `table_values_exp_at` / `table_values_act_at`,
construct 256 distinct freshly challenge-encoded rows once, then repeat them
into the P3-lifted cube. Test every index/mod256, tag/beta change, zero case,
short/long length and malformed shape against direct constructors; charge
the 256-row scratch, copies and residual initialization. First consult prior
public table and cache results to avoid rediscovery. This is per-proof
arithmetic reuse, never cross-proof challenge or mask reuse.
Next owner action: exclusive interpolation/constructor and enclosing clocks,
native gates if material, then verified fixed-context resident1/2/4/8 sweeps
under shared build/heavy locks. No heavy job was queued here.

Only research outside runtime written. No production, Git metadata,
receipt/calibration/gate/instruction/reviewer edits, native builds, GPU jobs,
installation, external writes/messages, purchases or escalation. Main/Claude
reviews and integrates; no merge here. Saved reports do not establish delivery
or supervisor liveness.
'''

readme=f'''# Exact finite-difference interpolation research model

Run `{run}`. **No native proof or speed claim.**

The model tests a candidate for `trained-1b/zkp-core/src/mle.rs::interpolate_eval`.
Read [the dated report](../../progress/{run}.md) for counts, source limits,
failures, current target accounting and the handoff.

Reproduce from the research directory, one command at a time:

```text
python3 experiments/sumcheck-public-shape-20261026/run_bounded.py probe.py
python3 experiments/sumcheck-public-shape-20261026/run_bounded.py audit.py
```

`run_bounded.py` enforces one-core affinity, nice19, 30-second CPU/alarm,
35-second parent timeout and 256MiB AS; estimate64MiB. No dependencies.
Seed202610260126. Hardware is in `hardware.json`; exact commands and entry
hashes in `commands.jsonl`; all dependency hashes in the artifact manifest.
`reference.py` uses Vandermonde elimination and direct original-cube products.
The SHA256 chain is a mock, not the native transcript. The candidate and
oracle are separately authored locally. `result.json` and `audit-result.json`
measure arithmetic/count correctness only. Initial results/failures are kept.

`finite-difference.patch` and `candidate-mle.rs` are **uncompiled, unapplied**.
Do not execute web code or promote this patch without owner gates/clocks.
'''

handoff=f'''# Review candidate: exact scalar interpolation with fixed public constants

Run `{run}`; {now}. Main/Claude reviews and integrates; no merge here.

Interface: unchanged `interpolate_eval(vals: &[Fp2], x: Fp2) -> Fp2` at
`ops/zkp-mvp/trained-1b/zkp-core/src/mle.rs:252`. The baseline SHA256 is
`b20c8b75c9246471fe1cc395122558eba715f66d9efe1dc4cd5be1750f2e542e`.
Patch: `experiments/sumcheck-public-shape-20261026/finite-difference.patch`.
It is unapplied/uncompiled; generic behavior remains for m<2 or m>6.

For m=2..6, fixed Goldilocks inverse factorials plus reverse forward
differences and nested Newton evaluation replace repeated denominators.
Sample domain/order, points and output bytes stay fixed in the CPU model.
No RNG/transcript/claim-site/PCS or privacy change is proposed. At degree5,
36->5 Fp2 products and6->0 source Fp inversions, adding15 Fp2 subtractions;
one96B stack array and48B constants, initialization/copy/dispatch remain.
The native compiler may already fold some baseline arithmetic.

Validation: {result['checks']} model checks,108fixtures/1836points,
40 synthetic CFS-algebra chains/120rounds,10controls; independent local
Vandermonde/direct-cube oracle. Source/count audit66checks. All source
snapshots, commands, hashes and negative controls retained. Model
{result['elapsed_seconds']:.6f}s/{result['max_rss_kib']}KiBRSS ononeCPUcore.
No native proof/transcript/receipt/privacy or performance test.

Source incidence: baseR12T128blockverifier370calls,DD32 388; this does not
count native prover or R13LOW+h24. The earlier GPU tree has DevFzcRounds
host interpolation, while nativeR12's CUDA module lacks that implementation.
Core function hashes match; device incidence is not transferred between trees.

Before testing performance, establish exclusive interpolation time and
enclosing proof time on the actual owner build. If immaterial, park it.
If material, run native base/extension/zero/node/unsupported-length field
differentials, generic and grouped rounds, all masked samples and next
challenges, seeded golden receipts and failure/refusal controls; independently
verify complete receipts in a fresh process and retain current privacy gates.
Use shared build/heavy locks. Keep every mask/opening fresh per proof.

End-to-end ceiling remains unknown: free deletion <=1/(1-f) for measured
removable critical-path fractionf, before added costs. Reject any semantic,
byte/refusal/privacy mismatch or slower enclosing workload. No complete
private8B high-endGPU result or >=50tokens/s claim.

Full explanation: [dated report](../progress/{run}.md).
'''

(R/'PROGRESS.md').write_text(summary)
(R/'progress'/f'{run}.md').write_text(detail)
with (R/'FINDINGS.md').open('a') as f:f.write('\n\n## Cycle 0126 — exact interpolation, scalar incidence and stale public encodings\n\n'+detail.split('\n',2)[2])
(P/'README.md').write_text(readme)
(R/'handoffs/20261026-finite-difference-interpolation.md').write_text(handoff)

state=f'''# ZKP efficiency explorer — durable state

Cycle 0126 COMPLETE: `{run}`. Checkpoint UTC: {now}.
Started18:29:25UTC; deadline18:49:25UTC. Next cycle no earlier than19:29:25UTC.
Required memory and all807prior source records/findings are snapshotted in
`experiments/sumcheck-public-shape-20261026/startup/`. Seven source records
appended (now814). All38hypotheses retained;1/14refined,39added.

No proving gain measured. Exact one-buffer finite-difference interpolation
passes6244checks/108fixtures/1836points,40syntheticCFSchains/120rounds,
10controls against independent locally authored Vandermonde/directcubeoracle.
SHA256transcriptmock only; no nativeCFS/PCS/receipt/privacytest. Model
{result['elapsed_seconds']:.6f}s/{result['max_rss_kib']}KiBRSS;
source/countaudit66checks/{audit['elapsed_seconds']:.6f}s/{audit['max_rss_kib']}KiB.
OneCoreUltra9 185Hcore,nice19,30sCPU/alarm,35sparent,256MiBAS,64MiBestimate.

Atdegree5,sourceFp2products36->5,baseinversions6->0;add15Fp2subs,
96Bscratchclear/copy,48Bconstants,dispatch. No dense cube work removed.
BaseR12 8BT128honestblockverifier370calls/nonDD,388/DD32; noR13LOW+h24counts.
Uncompiled/unappliedfinite-difference.patch isparkedfornativeclocks.
CurrenttrainedR12 andearlierGPU sharecoreinterpolatorbutdifferentGPU paths;
nevertransferDevFzcRoundsincidence. Bothinitialauditfailuresretained:
concurrentcoordinationdocumentchange,andwrongcrossbranchdeviceassumption.
Alltestedcodepinsstableatcorrectedaudit. Fiveconstructorsaudited:
U8/exp/actfinishedencodingsremainfreshchallenge-dependent;shape-onlycachefails.

Newindependentlyverifiedfull-stackproofs/passes/positions:0/0/0.
Actualmodelcontext/accelerator:none. Witness/proof/serialization/verification,
startup/prefill, startupfraction, prooflatency/bytes, steady/totalrates:
unmeasured. No longprefill,residentproofseriesordecode. Largerworkloadsallowed;
attentioncangrowquadratically. Private8B>=50provedtokens/s on5090/named
high-endGPU remainsunachieved. OwnerR12diagnostics/LOW+h24fidelitychoice
andD37-D41applicationdirectiondonotchangethistarget.

Nextlocal: lookup/softmax rotation. Readpriorpublictable/cachefindings;
differential-test native table_values_exp_at/table_values_act_at constructing
256freshencodedrows onceperproof then tiling theP3cube. Charge scratch,
copy/init/refusals and prove everyindex/mod256; preservefreshbeta/gamma/masks.
Nextowner: exclusiveinterpolation/constructors andenclosingcompleteproofclocks;
nativegatesifmaterial,thenverifiedfixedcontextresident1/2/4/8 undersharedlocks.
Handoff: `handoffs/20261026-finite-difference-interpolation.md`.

Carriedhistoricalbaseline,notrerun/reverified:nonDD8BT128/L32,one16threadCPU
pass,GPUoff,total478.737s=0.267370positions/s;prove_run393.785sincludes
witness98.348s/load17.595s;seal84.824soverlaps,notadditive.Receipt922711264B;
freshverify42.709s+load13.681s,recheck34.395s+load10.739s. Startupfraction,
isolatedserializationandsteadyslopeunknown.NoGPU/8Bprivacyacceptancefollows.

Onlyresearchoutsideruntimewritten.Nobuild/GPU/install/Git/externalmessage/
productionmutation. Savedreportsdonotestablishdeliveryorliveness.
'''
(R/'STATE.md').write_text(state)
(P/'completion.json').write_text(json.dumps({'run_id':run,'cycle':'0126','checkpoint_utc':now,'result':result['status'],'new_proved_positions':0,'target_achieved':False,'next_cycle_not_before_utc':'2026-10-26T19:29:25Z'},indent=2)+'\n')
print('Reports, handoff, findings append and final state checkpoint written.')
