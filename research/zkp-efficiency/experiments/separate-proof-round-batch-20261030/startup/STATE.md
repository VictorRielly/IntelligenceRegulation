# ZKP efficiency explorer — durable state

Cycle 0161 COMPLETE: `20261030T094123Z-ce04cf1a`.
Started 2026-10-30T09:41:23Z; checkpoint 2026-10-30T09:55:42.646672+00:00.
Deadline 10:01:23Z; next cycle no earlier than 10:41:23Z. Read AGENDA.md EVERY cycle.

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

Ranked queue:1 complete verified high-end GPUresident workloads; 2 admitted
context/DD/fidelity scaling; 3 exclusive native phase/capacity evidence.
All 93 prior hypotheses preserved; 93 tested/refined; 94 adds separate-transcript
round batching. No masks/private values/challenges reused or source changed.

Owner priority: complete independently verified high-end GPU workloads at
fixed context with resident 1/2/4/8 passes, startup/drain, exclusive phases,
actual capacity and all failure/exclusion accounting. Local next experiment,
if those clocks remain unavailable: two/four independent synthetic Fp2 round
evaluators with separate transcript/challenge/site ownership, differential
scalar reference and swapped-proof/early-reuse controls. Existing
`cuda.rs::dev_zerocheck_blocks` takes one transcript; `nb` is no multi-proof
API. No GPU/native build is proposed without owner locks and materiality.

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

LIVE primary search refreshed zkDuel,gnarkPR1828/October7release,
p3-sumcheckHVZK,composableIORs,BatchZK and ICICLE; vSQL2017's repeated-circuit
algebra was newly assessed. Nine source records append to 1,061 prior records.
Exact access/publication/update dates, licenses, inspected commit scope and
fetch blockers are in source-records.jsonl. No foreign code executed or
author performance reproduced. zkDuel's related repo was already assessed;
its expanded full-text inspection is a refresh. gnark release pin
e974abb44722dd201a7f1949baeabca0fef5866e rechecked; constituent implementation
commit cache-missed. License declarations and actual body inspection differ.

Resource envelope: one CPU affinity, nice 19, 30 s CPU / 40 s alarm / 45 s parent,
384 MiB address cap; compile estimate 300 MiB, audit 64 MiB. Compile 0.569 s / 153,356 KiB;
final audit harness 0.418 s / 31,164 KiB (correctness execution,not proof timing).
Initial compile inner-attribute failure and corrected rung geometry inputs
are retained. The first matching algorithms did not authenticate input
geometry; the final 144 registry rows check all seven axes against the pinned
registry plus query width. 8B counts were unaffected by that correction.

[Experiment](experiments/slot-batching-census-20261030/README.md) · [Integration boundary](experiments/slot-batching-census-20261030/INTEGRATION.md) · [Dated report](progress/20261030T094123Z-ce04cf1a.md).

Only research outside runtime written; no production/Git/receipt/calibration/
safety/instruction/reviewer edit, native build, GPU, installation, downloaded
script execution, external write/message, spending, escalation or merge.
Main/Claude reviews any future integration. Saved reports establish neither
message delivery nor supervisor/job liveness.
