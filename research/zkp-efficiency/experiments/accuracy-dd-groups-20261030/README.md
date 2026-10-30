# Actual accuracy-DD equality groups — cycle0171

Run 20261030T194123Z-776cb104. Started19:41:23Z; checkpoint 2026-10-30T19:52:08.359539+00:00; deadline20:01:23Z.

**No measured proving improvement.** H103 now has an exact arithmetic
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


| Source-expanded product census | Generic | Grouped | Count change |
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


Review artifact accuracy_dd_groups.uncompiled.diff and candidate source
are **uncompiled and unapplied**. The patch adds three equality-group
descriptors and a separately captured source-derived bracket closure. The
original verifier/extension polynomial is byte-identical, checked by hash.
An explicit ght/gs support-absent guard retains the generic path for other
support cases. Proposed interface: ordered original tables plus3group
descriptors and (group,values)->Fp2 through SlotDef.groups to existing
GroupedEqRounds. Clone/setup costs are additional and unmeasured. No
subgroup values leave the prover. Native maskers, extension, openings,
fresh entropy, hosted multiplicities and current privacy gates remain owed.


Ranked queue:1complete independently verified high-endGPU resident1/2/4/8
workloads;2admitted context/DD/fidelity scaling with quadratic attention;
3exclusive native phase/capacity evidence;H103conditional priority4.
All105 prior hypothesis dictionaries remain, with an added H103 refinement.
NewH106(priority5) screens recursive locality/public-shape NTT planning.
Native4096-element shared tiles already run two passes and fuse sampled-column
gather; no free materialization/pass deletion remains established. Only a new
critical-traffic census could justify transposes/planning costs. CPU ideal-cache
asymptotics do not establish GPU sector/coalescing/occupancy behavior.


Final main 5.460890s / 24592KiB RSS; standalone
audit 5.263358s / 20364KiB. Python3.10.12, seed20261030171,
one nice19 CPU affinity;30s CPU/40s alarm/45s parent timeout/256MiB address-space
caps,64MiB memory estimate. No native build or GPU ran. Commands:
python3 -B experiments/accuracy-dd-groups-20261030/run_bounded.py experiment
and the same launcher with audit. Each experiment stayed below60s and512MiB.


Standalone audit passes 11337checks, including16source pins, all saved folds/rounds/finals and reexecuted controls. Both references are locally authored, not an outside reviewer.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**; passes: **0**. Device: **one CPU affinity on Intel
Core Ultra9 185H; no GPU**. Witness, proof, serialization, verification, startup
and initial-prefill clocks, startup fraction, proof latency/bytes, steady-state
and total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
attention may grow quadratically. Complete private8B **>=50 proved tokens/s on
RTX5090 or another named high-end GPU remains unachieved**. No mask, pad or
private-opening reuse, changed relation, or weaker privacy is proposed.


Historical older-profile CPU8B diagnostic carried only, not rerun,
reverified or newly counted: T128/L32, one16-thread GPU-off pass, total478.737s
(0.267370/s). Prove393.785s includes witness98.348s/load17.595s; seal84.824s
overlaps load27.151s/witness80.897s. Receipt922711264B; verify42.709s plus
load13.681s. Nested clocks are not summed; exclusive serialization, startup
fraction and steady slope remain unknown. This is not current-profile or
high-end GPU throughput evidence.


Eight LIVE primary-source records appended1150->1158, including newly
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


Next local experiment: pin the native CFS masked-round and extension wrapper,
then replay source-derived generic/grouped messages and synthetic draw counts
with the same independently authored reference. Preserve host first-round
evaluation on inconsistent witnesses. This still cannot replace native proof
verification. Next owner action: review the unapplied diff, run release-mode
LOW/LOW+h24 DD masked-byte/RNG/transcript/refusal/final/PCS gates, then measure
exclusive scan/scalar/slot/enclosing clocks under current shared build/heavy
locks. Do not duplicate the owned R14 freeze/review or classifier jobs.


Only research outside runtime/ was written. No production source, Git
metadata, receipts, calibration, safety gates, instructions or reviewer files
were modified. No build, GPU job, installation, downloaded script execution,
external write/message, purchase, privilege escalation, merge, duplicate
researcher or supervisor-liveness action. Main/Claude reviews and integrates.
Saved reports do not imply a user message was delivered.


[Source pins](source-pins.json) · [Counts](cost-census.json) · [Handoff](../../handoffs/20261030-accuracy-dd-groups.md).
