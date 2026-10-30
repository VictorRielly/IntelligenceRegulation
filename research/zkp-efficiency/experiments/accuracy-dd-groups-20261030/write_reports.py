"""Finalize reports within research only; no publication or owner integration."""
from pathlib import Path
import json,hashlib,datetime,re
E=Path(__file__).resolve().parent
ROOT=E.parents[1]
RUN='20261030T194123Z-776cb104'
NOW=datetime.datetime.now(datetime.timezone.utc).isoformat()
main=json.loads((E/'experiment-execution.json').read_text())
audit=json.loads((E/'audit-execution.json').read_text())
assert main['returncode']==audit['returncode']==0
result=json.loads((E/'result.json').read_text())
ar=json.loads((E/'audit-result.json').read_text())
assert result['status']==ar['status']=='PASS'
assert result['checks']['generic_folded_values']==result['checks']['grouped_folded_values']==9504

measurement="""New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**; passes: **0**. Device: **one CPU affinity on Intel
Core Ultra9 185H; no GPU**. Witness, proof, serialization, verification, startup
and initial-prefill clocks, startup fraction, proof latency/bytes, steady-state
and total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
attention may grow quadratically. Complete private8B **>=50 proved tokens/s on
RTX5090 or another named high-end GPU remains unachieved**. No mask, pad or
private-opening reuse, changed relation, or weaker privacy is proposed.
"""
historical="""Historical older-profile CPU8B diagnostic carried only, not rerun,
reverified or newly counted: T128/L32, one16-thread GPU-off pass, total478.737s
(0.267370/s). Prove393.785s includes witness98.348s/load17.595s; seal84.824s
overlaps load27.151s/witness80.897s. Receipt922711264B; verify42.709s plus
load13.681s. Nested clocks are not summed; exclusive serialization, startup
fraction and steady slope remain unknown. This is not current-profile or
high-end GPU throughput evidence.
"""
next_step="""Next local experiment: pin the native CFS masked-round and extension wrapper,
then replay source-derived generic/grouped messages and synthetic draw counts
with the same independently authored reference. Preserve host first-round
evaluation on inconsistent witnesses. This still cannot replace native proof
verification. Next owner action: review the unapplied diff, run release-mode
LOW/LOW+h24 DD masked-byte/RNG/transcript/refusal/final/PCS gates, then measure
exclusive scan/scalar/slot/enclosing clocks under current shared build/heavy
locks. Do not duplicate the owned R14 freeze/review or classifier jobs.
"""
sources="""Eight LIVE primary-source records appended1150->1158, including newly
assessed older [ideal-cache transpose/FFT](https://www.fftw.org/~athena/abstracts/abstract12.html)
(FOCS1999; page updated2019-09-16) and [FFTW3 shape-only planning](https://fftw.org/fftw-paper-ieee.pdf)
(2005), [Dao/Thaler equality factoring](https://eprint.iacr.org/2024/1210)
(received2024-07-27), [Efficient Sumcheck](https://github.com/compsec-epfl/efficient-sumcheck)
(current rewrite Unreleased), [StateSync-GKR v2](https://arxiv.org/abs/2610.14849)
(2026-10-26), [Longfellow draft00](https://datatracker.ietf.org/doc/draft-irtf-cfrg-longfellow/)
(updated2026-10-22), and known Sparrow/GPU-GKR screens. Dates and unknowns,
license-label limits and no inspected commit are recorded in sources-cycle.json.
Sparrow PDF403/repo Cache miss, Effsc LICENSE Cache miss and cache-paper
compressed fulltext unsupported-content limits remain. No bypass, external code
execution or reproduction of author performance occurred. Search snippets
are distinguished from full-text inspection; old techniques are not called new
when previously assessed.
"""
timing=f"""Final main {main['wall_s']:.6f}s / {main['maxrss_kib']}KiB RSS; standalone
audit {audit['wall_s']:.6f}s / {audit['maxrss_kib']}KiB. Python3.10.12, seed20261030171,
one nice19 CPU affinity;30s CPU/40s alarm/45s parent timeout/256MiB address-space
caps,64MiB memory estimate. No native build or GPU ran. Commands:
python3 -B experiments/accuracy-dd-groups-20261030/run_bounded.py experiment
and the same launcher with audit. Each experiment stayed below60s and512MiB.
"""
finding="""**No measured proving improvement.** H103 now has an exact arithmetic
projection of the selected unpadded R14 accuracy DD relation. Non-Legacy
dispatch enters argument_accuracy.rs::szc_dd; its three Rs limbs and six
ordered lookups/three helpers make18tables,14private terminals. The source
base-score1..8 and derived-score17..24 constraints intersect at reachable
derived shifts17..20. All four were tested. Legacy15table evidence remains
preserved with its original limitation.

Both generic and grouped evaluators match48 arbitrary synthetic fixtures
(n3/span1 and n4/span2; base/extension, zero-factor, annihilated-prefix,
half-equality and late-zero cases). Each arm matches840round values,
9504intermediate folded values and864ordered finals against separately
authored schoolbook Fp2/expanded-polynomial original-cube MLE equations.
All96 literal count formulas match instrumented executions. Full degree4
and bracket degrees3/1/1 are retained. These are arbitrary synthetic algebra
tests, not honest-model witnesses, native proofs, external review or privacy
verification.

All10 negative controls fire and are independently reexecuted in the audit:
missing high/middle score limbs, stale legacy shift, missing third helper,
cross-pair lookup order, wrong top-byte range, dropped tuple key/mask,
swapped equality factors and reordered Rs finals. Initial drop-tuple-mask
control failed because its only row had mask1; the mutant equals the original
there. Retained initial-control-coverage-failure/ records the failure. The
corrected saved row has mask0. There was no positive-arm arithmetic failure.

The source-selected slot is a HOST with nonempty hosted claims. Its generic
first round therefore computes all five samples; later rounds recover sample1
from their own actual unmasked round. The candidate recovers only actual prior
group rounds and falls back to explicit evaluation for zero factors. No host
assertion seeds individual group claims; no resampling or new refusal.
"""
cost="""| Source-expanded product census | Generic | Grouped | Count change |
|---|---:|---:|---:|
| Synthetic n7/span4, recovery |119348|118719|−0.527%|
| Synthetic n7/span4, all fallback |119348|127440|+6.780%|
| Public T128-sized n19/span12, recovery |469514108|334407627|−28.776%|
| Public T128-sized n19/span12, all fallback |469514108|381323556|−18.783%|

Counts include all scalar prefix/split-Eq/inverse/recovery/degree-completion/
group-claim scaffold and original18table folds. They use the current source
arithmetic expansion (5base products per Fp2 multiply,127 per base inverse,
132 per Fp2 inverse), not machine instructions or time. Constants may be folded
by the compiler. The n19 row uses public T128/32-head dimensions; larger n21/n23
rows are dimension-only projections, not admitted new profiles or model runs.
Allocation, source setup clones/Arc, dispatch, Rayon reductions, locality,
physical memory/occupancy and enclosing proof time remain unpriced.

Baseline: actual unpadded accuracy-DD generic closure. Eliminated work:
repeated equality-weighted bracket samples and one interpolation step per
original column, while retaining every fold/final. Added costs: the full
counted scalar/weighting work plus unpriced nonfield/setup costs above.
End-to-end ceiling is N/(T-C_removed+A_added), **unknown** without exclusive
critical clocks; necessary >=50/s condition is T-C+A<=N/50. Reject any
selected-path/limb/lookup/degree/key/host/value/byte/RNG/transcript/refusal/
final/PCS/privacy mismatch, absent material incidence, or A>=C. This refines
H103; it is not additive to prior symbolic-Eq/interpolation savings.
"""
ranking="""Ranked queue:1complete independently verified high-endGPU resident1/2/4/8
workloads;2admitted context/DD/fidelity scaling with quadratic attention;
3exclusive native phase/capacity evidence;H103conditional priority4.
All105 prior hypothesis dictionaries remain, with an added H103 refinement.
NewH106(priority5) screens recursive locality/public-shape NTT planning.
Native4096-element shared tiles already run two passes and fuse sampled-column
gather; no free materialization/pass deletion remains established. Only a new
critical-traffic census could justify transposes/planning costs. CPU ideal-cache
asymptotics do not establish GPU sector/coalescing/occupancy behavior.
"""
patch="""Review artifact accuracy_dd_groups.uncompiled.diff and candidate source
are **uncompiled and unapplied**. The patch adds three equality-group
descriptors and a separately captured source-derived bracket closure. The
original verifier/extension polynomial is byte-identical, checked by hash.
An explicit ght/gs support-absent guard retains the generic path for other
support cases. Proposed interface: ordered original tables plus3group
descriptors and (group,values)->Fp2 through SlotDef.groups to existing
GroupedEqRounds. Clone/setup costs are additional and unmeasured. No
subgroup values leave the prover. Native maskers, extension, openings,
fresh entropy, hosted multiplicities and current privacy gates remain owed.
"""
limits="""Only research outside runtime/ was written. No production source, Git
metadata, receipts, calibration, safety gates, instructions or reviewer files
were modified. No build, GPU job, installation, downloaded script execution,
external write/message, purchase, privilege escalation, merge, duplicate
researcher or supervisor-liveness action. Main/Claude reviews and integrates.
Saved reports do not imply a user message was delivered.
"""

readme='\n\n'.join([
 '# Actual accuracy-DD equality groups — cycle0171',
 f'Run {RUN}. Started19:41:23Z; checkpoint {NOW}; deadline20:01:23Z.',
 finding,cost,patch,ranking,timing,
 f'Standalone audit passes {sum(ar["checks"].values())}checks, including16source pins, all saved folds/rounds/finals and reexecuted controls. Both references are locally authored, not an outside reviewer.',
 measurement,historical,sources,next_step,limits,
 '[Source pins](source-pins.json) · [Counts](cost-census.json) · [Handoff](../../handoffs/20261030-accuracy-dd-groups.md).'])
(E/'README.md').write_text(readme+'\n')

dated='\n\n'.join([
 f'# Cycle0171 — {RUN}',
 f'Start2026-10-30T19:41:23Z; checkpoint {NOW}; deadline20:01:23Z. AGENDA and durable history/documents read and snapshotted; early STATE checkpoint19:42:05Z. No prior cycle repeated.',
 finding,cost,patch,ranking,timing,
 f'Standalone audit passes {sum(ar["checks"].values())}checks; includes16source pins, saved original-cube equations, all folds and ten reexecuted controls.',
 measurement,historical,sources,next_step,limits,
 '[Experiment](../experiments/accuracy-dd-groups-20261030/README.md) · [Handoff](../handoffs/20261030-accuracy-dd-groups.md).'])
(ROOT/'progress'/f'{RUN}.md').write_text(dated+'\n')
findings_path=ROOT/'FINDINGS.md'
marker=f'\n\n## Cycle0171 — {RUN}: actual accuracy-DD algebra and count projection\n\n'
prior_findings=findings_path.read_text().split(marker)[0]
root_relative=dated.replace('(../experiments/','(experiments/').replace('(../handoffs/','(handoffs/')
findings_path.write_text(prior_findings+marker+root_relative+'\n')

handoff='\n\n'.join([
 '# Current accuracy-DD grouping — owner review only',
 f'Cycle0171, {RUN}. No measured proving improvement or new complete proof.',
 finding,patch,
 'Actual seam: R14 final-working-tree/hashline/src/private_block/argument_accuracy.rs::szc_dd -> SlotDef.groups -> zkp-core/src/sumcheck/grouped.rs::GroupedEqRounds. The selected branch previously returned groups=None; legacy argument.rs branch identity does not validate this path.',
 cost,timing,
 'Patch validation is Python algebra/counting and static preservation only. Owner must inspect clone ownership, build the exact selected profile in release mode, retain the untouched oracle, and compare masked messages, entropy draw order, transcript state, invalid-witness refusals, extension values, PCS terminals/openings and independently verified receipts. Include zero/annihilated factors and all current score shifts; no challenge resampling or stale15table fixture.',
 next_step,measurement,
 '[Review diff](../experiments/accuracy-dd-groups-20261030/accuracy_dd_groups.uncompiled.diff) · [Experiment](../experiments/accuracy-dd-groups-20261030/README.md) · [Pins](../experiments/accuracy-dd-groups-20261030/source-pins.json).',
 limits])
(ROOT/'handoffs'/'20261030-accuracy-dd-groups.md').write_text(handoff+'\n')

short=f"""# ZKP efficiency progress

Cycle0171 COMPLETE — {RUN}, checkpoint {NOW}.

**No measured proving improvement.** Current unpadded R14 LOW/LOW+h24 DD
grouping now passes48synthetic fixtures with all3score limbs,6lookups and
3helpers. Each evaluator matches840round values,9504folded values and864
ordered finals against an independent original-cube reference;10controls fire.
Initial mask-control coverage failure retained and fixed. Audit passes
{sum(ar['checks'].values())}checks. An uncompiled/unapplied Rust diff preserves the original
verifier polynomial and gates grouping to absent support tables.

At public T128-sized dimensions, the model removes28.78%expanded field
products (18.78%all-zero recovery fallback), including scalar costs.
These are counts, not timings. Tiny cases may regress. Native setup,
allocation/dispatch/reduction/cache and enclosing clocks remain unknown.
Main {main['wall_s']:.3f}s/{main['maxrss_kib']}KiB; audit {audit['wall_s']:.3f}s/{audit['maxrss_kib']}KiB; one CPU.

{measurement}
EightLIVEprimary records1150->1158 include current sumcheck/recentOctober
sources and newly assessed older cache-oblivious/shape-only FFT planning.
The nativeNTT already has two passes/fused gather; no extra pass deletion
established. Top3priorities remain verified high-endGPU resident workloads,
admitted context/fidelity, and exclusive phase/capacity clocks.

{next_step}
[Experiment](experiments/accuracy-dd-groups-20261030/README.md) ·
[Handoff](handoffs/20261030-accuracy-dd-groups.md) ·
[Dated report](progress/{RUN}.md).
Saved reports do not establish message delivery.
"""
(ROOT/'PROGRESS.md').write_text(short)
state=f"""# ZKP efficiency explorer — durable state

Cycle0171 COMPLETE: {RUN}.
Start19:41:23Z; checkpoint {NOW}; deadline20:01:23Z.
Next cycle no earlier2026-10-30T20:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** H103current accuracy-DD algebra now
covers18tables/14private terminals,3Rs limbs,6orderedlookups/3helpers,
source-derived score17..20. Both generic/grouped arms match48synthetic
fixtures:840round values,9504intermediatefolds,864orderedfinals per arm.
Independent original-cube schoolbook Fp2 reference;96literal count matches;
10controls reexecuted. Audit{sum(ar['checks'].values())}checks passes. Initial mask-control test
failed to distinguish onmask1; retained and corrected usingmask0. No
positive-arm mismatch. Legacy15table findings remain scoped/preserved.

Counted n19/span12 source-expanded products469514108->334407627(-28.78%);
allzero-recovery fallback381323556(-18.78%). n7/span4 only0.527%removed,
allfallback6.78%added. All scalar scaffold counted; nonfield/setup clones/
Arc/dispatch/reduction/cache/enclosing time unknown. CeilingN/(T-C+A)unknown.
Counts are not timing or profile admission. All18originalfolds/finals remain.

Uncompiled/unapplied accuracy_dd_groups.uncompiled.diff preserves original
verifier/extension poly byte-for-byte; explicit ght/gs absent-support guard.
Interface current argument_accuracy::szc_dd->SlotDef.groups->GroupedEqRounds.
Native masked/RNG/transcript/refusal/extension/PCS/privacy gates still owed.
No production modification/merge. Main/Claude owns review/integration.

Top3: verified high-endGPU resident1/2/4/8; admitted context/DD/fidelity;
exclusive native clocks/capacities. H103conditional4. NewH106priority5:
older recursive locality/shape-only NTT plans; native already two-pass/fused
gather, so only additional measured traffic can justify new transposes/plans.
105priorhypotheses preserved;106total. No additive scan-saving claim.

{next_step}
{measurement}
{historical}
EightLIVEsource records1150->1158. NewolderFrigo1999ideal-cache andFFTW2005
public-shapeplanning; recentStateSyncOct26/LongfellowOct22 and currentEffsc
Unreleasedwire screened. PDF403/license/repoCachemiss/compressedtype limits
retained; no inspectedcommit or reproduced author performance.
Finalmain{main['wall_s']:.6f}s/{main['maxrss_kib']}KiB; audit{audit['wall_s']:.6f}s/{audit['maxrss_kib']}KiB.
One nice19CPU,30sCPU/40salarm/45sparent/256MiBAS caps,64MiBestimate.
Only research outside runtime written; no production/Git/receipt/calibration/
gate/instruction/reviewer/build/GPU/install/foreignexecution/externalwrite/
message/purchase/escalation/merge/restart/liveness action.

[Experiment](experiments/accuracy-dd-groups-20261030/README.md) ·
[Handoff](handoffs/20261030-accuracy-dd-groups.md) ·
[Dated report](progress/{RUN}.md).
"""
(ROOT/'STATE.md').write_text(state)
(E/'completion.json').write_text(json.dumps(dict(status='COMPLETE',run_id=RUN,checkpoint_utc=NOW,next_cycle_not_before='2026-10-30T20:41:23Z',
 result='No measured proving improvement; actual accuracy-DD algebra/count projection and unapplied handoff.',
 new_full_stack_proofs=0,proved_positions=0),indent=2)+'\n')
print(json.dumps(dict(checkpoint=NOW,audit_checks=sum(ar['checks'].values()),reports=['STATE.md','PROGRESS.md','FINDINGS.md',f'progress/{RUN}.md','handoffs/20261030-accuracy-dd-groups.md'])))
