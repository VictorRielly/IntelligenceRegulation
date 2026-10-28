"""Readable final reports; preserve all findings predating this cycle."""
from pathlib import Path
import datetime,json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RUN='20261020T121854Z-ee6ad7b9';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
progress=f'''# ZKP efficiency progress

Cycle 0104 complete — `{RUN}` — 2026-10-20 UTC.

**No proving speed improvement measured.** For the frozen R9 8B T128
fixture, rebuilding one lookup fraction column at a time needs about
128 MiB of modeled arithmetic storage, versus 2.88–3.10 GiB materialized,
with nearly twice the fraction-tree construction work and twice the leaf
generation. An 85 MiB top-cache plan needs about 6.68 times the internal
work. These counts exclude proof scratch, masks, commitments and A/model
storage. Neither net savings nor actual proof memory fit is established.

Completed: 959 probe checks, 116 tiny cases and nine controls; an independent
audit passed 5641 checks, 1500 cost mutations, 1000 tiny column services and
30 mixed-height roots. Five native source pins are unchanged. A wrong-site
permutation preserves a fractional root, so ordered leaf binding remains
essential. One thread: probe 0.066202 s / 16,284 KiB RSS; audit 0.165969 s /
14,980 KiB. An initial singleton reporting failure and its correction are
retained. Eleven LIVE queries produced eight primary records, including
newly screened older Virgo. No author performance was reproduced. Fetch,
date, license and short-commit limitations are explicit.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context/device: none. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload
rates: **unmeasured**. No long prefill, resident passes or decode. Private
8B >=50 proved tokens/s on an RTX 5090 or another named high-end GPU remains
unachieved. Larger workloads are allowed; attention can grow quadratically.
The census excludes the newer LOW fidelity proposal. Current R9/DD privacy,
D32 fidelity, D33 artifact scope and D34 constraints remain.

Next local: per-column checkpoint/rebuild choices under an explicit GKR
layer-consumer contract. Owner priorities remain full GPU phase/capacity
clocks, verified fixed-context resident 1/2/4/8 passes and the all-eleven FZC
compiler A/B. Unknown: the private GKR/CFS/PCS design and complete GPU costs.

[Experiment](experiments/lookup-forest-schedules-20261020/README.md),
[handoff](handoffs/20261020-lookup-forest-schedules.md),
[dated report](progress/{RUN}.md).
Saved reports do not establish external message delivery.
'''
(ROOT/'PROGRESS.md').write_text(progress)
(ROOT/'progress'/f'{RUN}.md').write_text(progress+f'\nCheckpointed at {now}.\n')
state=f'''# ZKP efficiency explorer — durable state

Cycle 0104 COMPLETE: `{RUN}`.
Checkpoint: {now}. Deadline: 2026-10-20 12:38:54 UTC.
Next cycle no earlier than 2026-10-20 13:18:54 UTC.
Evidence: experiments/lookup-forest-schedules-20261020/.
Prior durable memory and required documents are preserved under startup/.
AGENDA, current target/status/decisions/coordination, owner R11 cost report,
the source ledger and latest cycle0103 census were read.

No proving speed improvement measured. Frozen R9 w32/fE9, 8B T128 non-DD/DD:
full fraction forest 3170.016/2954.016 MiB versus U8 helper data 420.25/390.25
MiB. One-column rebuild has a 128.006 MiB arithmetic upper bound at nearly
2x fraction-tree construction work and 2x leaf generation. Top-12 caching:
84.766 MiB at 6.676/6.677x internal work and 8.663x leaves. Roots only:
64.005 MiB at 18.663x work. These ratios are not native H or proving time.
COUNTED ONLY T512: one-column 512.006 MiB; top-12 277.266 MiB at 9.275/8.884x
work. No T512 profile/proof admitted. Excludes A/model, other H/M, GKR folds,
scratch, masks/CFS/PCS, encoded trees, transfers and launches. Net bytes and
actual fit remain unknown. All roots/intermediates stay private. Keep one
global histogram and every ordered A link (83 at T128, 85 at T512). Exact
new mask/claim/PCS sites are unknown/null. A wrong-site permutation preserves
the fraction root: ordered binding is indispensable. Prior negative results,
including unmasked-root disclosure and weak leaf binding, remain intact.

Validation: 959 probe checks / 116 tiny cases / nine controls; independent
5641 audit checks / 1500 cost mutations / 1000 tiny column services / 30
mixed-height roots / five unchanged source pins. Synthetic F65537 only,
without native GKR/refusal/CFS/receipt/privacy validation. One CPU thread,
core0, nice19; probe 0.066202 s / 16284 KiB; audit 0.165969 s / 14980 KiB.
Caps: 59 s CPU/alarm, 60 s parent, 512 MiB AS; estimate 64 MiB. An initial
singleton work-ratio division by zero was corrected to null, retaining the
failure/code/log. No native build or GPU job.

Twenty ranked hypotheses retained. Top three: full high-end GPU phase
coverage plus verified fixed-context resident 1/2/4/8 passes; DD scaling
at larger contexts after the T128 null; actual capacity and exclusive versus
enclosing phase clocks. All-eleven FZC compiler A/B remains ahead of protocol
redesign. Rank7 now includes the measured scope of this lifetime/work study.
Eleven LIVE queries, eight primary records, 605->613. New older Virgo and
zorch floor-width negative; other sources are explicit refreshes. Chimera's
October16 revision verified. No author performance reproduced. Dates, license
and fetch limits retained. 53d8dfb is reported short metadata, not an inspected
commit. No verified latest release.

Next LOCAL: bounded per-column checkpoint/rebuild frontier under an explicit
layer-consumer contract. Include complete served arrays, fold/scratch
lifetimes and regeneration work; independent tiny topology and wrong-site,
multiplicity and zero-denominator controls. Layer service is not whole masked
GKR. Next OWNER: full GPU phase/capacity clocks and verified fixed-context
resident 1/2/4/8; all-eleven FZC compiler A/B first. Main/Claude reviews any
integration. Handoff: handoffs/20261020-lookup-forest-schedules.md. No merge.

Carried CPU non-DD 8B T128/L32, one 16-thread pass, GPU off: total 478.737 s
=0.267370 positions/s. prove_run 393.785 s encloses witness 98.348 s and
load 17.595 s; seal 84.824 s overlaps accounting. Receipt 922711264 B; fresh
verify 42.709+load13.681 s; recheck 34.395+load10.739 s. Not rerun/reverified.
Startup fraction, steady slope and isolated serialization unknown. New
independently verified full-stack proofs/passes/positions: 0/0/0; actual
model context/device: none. All new witness/proof/serialization/verification
clocks, startup/fraction, steady and total rates: UNMEASURED. No long prefill,
resident pass or decode. Private 8B >=50/s on an RTX5090 or another named
high-end GPU remains unachieved. Larger workloads allowed; attention can
grow quadratically. New LOW fidelity profile is outside the frozen R9 census.
R9 N-r9-a/b, DD privacy gate, D32/D33/D34 scopes retained. Only research
excluding runtime written; no production, Git, build, GPU, install, external
writes/messages, purchases or escalation. Reports do not imply delivery.
'''
(ROOT/'STATE.md').write_text(state)
finding=f'''
## Cycle 0104 — private fraction-forest lifetime and recomputation (2026-10-20)

Run `{RUN}`. **No proving speed improvement measured.** Refined rank7:
can a mixed-height forest avoid the prior materialized-storage negative
without ignoring recomputation? Ten frozen R9 w32/fE9 public fixtures retain
one global histogram and all ordered U8 columns. They exclude the newer LOW
fidelity proposal. The owner R11 report separates counted sizes from modeled
time; none of those proposals is a new proof or privacy acceptance.

At 8B T128 non-DD/DD, materialized fraction storage is 3170.016/2954.016 MiB,
versus U8 helper data 420.25/390.25 MiB. One initial root reduction followed
by one-column full reconstruction uses at most 128.006 MiB of arithmetic
arrays, with nearly 2x fraction-tree internal work and 2x leaf generation.
Retaining top12 depths gives 84.766 MiB at 6.676/6.677x internal work and
8.663x leaves; roots only gives 64.005 MiB but 18.663x work and 20.663x leaves.
Top16 gives 390.016 MiB at 2.870/2.885x work. At COUNTED ONLY T512, one-column
needs 512.006 MiB; top12 needs 277.266 MiB at 9.275/8.884x work. No T512
profile/proof admitted. Symbolic large arrays were never allocated. Ratios
compare constructing one fraction forest, not the native H writer or proving.
Bounds exclude A/model, other H/M, GKR folds/scratch, masks/CFS/PCS, commitment
encoding/trees, transfers and launches. Net memory/time/actual fit is unknown.

`plan(sizes,b)` counts retained top caches, one service array and DFS frontier.
`serve` reduces blocks for each lower layer; tiny tests retain output copies
for comparison. Their RSS is not a production streaming-memory measurement.
The 84 private root pairs / 83 original ordered A links at T128 are semantic
obligations, not 84 public messages or 83 required PCS openings. Actual new
mask/claim/PCS site counts are null until the protocol is designed. Preserve
one histogram committed before challenges and all denominator refusals.
Wrong-site permutation preserves a fractional root while changing ordered
leaf binding. Prior unmasked-root and weak-binding negatives remain binding.

Probe: 959 checks, 116 tiny cases, nine controls. Independent audit: 5641
checks, 1500 cost mutations, 1000 tiny column services, 30 mixed-height direct-
inverse roots and five unchanged native source pins. Synthetic F65537, not
native Fp2. Controls include dropped multiplicity, duplicated histogram,
zero denominator with zero multiplicity, degenerate(0,0), fresh challenges
and fixed-floor stacking. Initial singleton construction had zero internal
nodes, causing a reporting division by zero; corrected to null, with source
and failure retained. No production defect inferred. One thread/core0,
nice19; 59 s CPU/alarm, 60 s parent, 512 MiB AS, 64 MiB estimate. Probe
0.066202 s/16284 KiB; audit 0.165969 s/14980 KiB. No native Rust/GKR,
transcript, refusal, receipt, CFS or privacy validation.

Eleven LIVE queries yielded eight primary records, appended 605->613. Newly
screened older Virgo2019/1482: received 2019-12-24, revised 2020-07-16, paper
CC BY. Masked GKR plus terminal delegation is not native compatibility.
Refreshed Chimera (July7 / October16 revision), StateSync (October10),
LogUp-GKR and Sparrow (October11 received / October14 approved,2024).
New zorch issue362 (July2) reports fixed-floor stacking and runtime RAM blowup;
author evidence only. SP1 issue112 (June17 / closureJune18) includes later
corrections to fusion/padding diagnoses. Repository README states Apache2;
license/raw/source/commit/release fetches failed as recorded. Short53d8dfb
is reported metadata only; no inspected SHA or verified latest release.
No external code executed or author performance reproduced. The rotating
queue retains NTT/commitments, sumcheck/GKR, lookups/softmax, memory,
amortization, quantization/arithmetic and composition. Owner priorities stay
full GPU clocks/resident work, DD scaling, actual capacity and FZC compiler A/B.

Baseline: recurring original U8 helpers. Hypothetically eliminated work is
gross U8 H data/processing only under a reviewed replacement. Added costs:
all fraction construction/recomputation, leaf generation, ordered A links,
one histogram, refusals, reductions, fresh masks/CFS/PCS, transfers and
launches. With affected exclusive time fraction f unknown, even free deletion
has ceiling <=1/(1-f). Counts cannot supply f or a GPU rate. Falsify on changed
binding/exactness/refusal/privacy/soundness or added complete-proof cost
exceeding avoided work. Actual seam: frozen R9 shape lookup/helper/site counts,
layout::lookups_at, argument::helper_sum/SC_TAB and protocol::u8_denominator_
inverses/write_h/H commit. Research interface only; no Rust patch ready.
Main/Claude reviews and integrates any future candidate.

Carried CPU non-DD 8B T128/L32, one16-thread pass, GPU off: total478.737 s
=0.267370 positions/s; prove_run393.785 s encloses witness98.348/load17.595;
seal84.824 s overlaps. Receipt922711264 B; fresh verify42.709+load13.681 s,
recheck34.395+load10.739 s. Not rerun/reverified. Startup fraction, isolated
serialization and steady slope unknown. New independently verified full-stack
proofs/passes/positions0/0/0; actual model context/device none; all new proof
clocks, startup/fraction, steady/total rates unmeasured. No long prefill,
resident passes or decode. Private8B>=50/s remains unachieved. Larger workloads
allowed; attention can grow quadratically. R9 N-r9-a/b, DD privacy gate,
D32 fidelity, D33's frozen-R7 scope and D34 remain. Only research excluding
runtime written; no production/Git/build/GPU/install/external writes/messages/
purchases/escalation. Reports do not establish external delivery.

[Experiment](experiments/lookup-forest-schedules-20261020/README.md),
[handoff](handoffs/20261020-lookup-forest-schedules.md). Next local: per-column
checkpoint/rebuild frontier under an explicit layer-consumer contract before
selecting storage or protocol. Next owner: full GPU phase/capacity clocks,
verified resident1/2/4/8 and all-eleven FZC compiler A/B under shared locks.
'''
old=(ROOT/'FINDINGS.md').read_text();prefix=(HERE/'startup/FINDINGS.md').read_text()
assert old.startswith(prefix) and old[len(prefix):].count('## Cycle 0104')==1
(ROOT/'FINDINGS.md').write_text(prefix+finding)
manifest=json.loads((HERE/'research-code-manifest.json').read_text())
b=Path(__file__).read_bytes();manifest.append(dict(path='polish_reports.py',sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(HERE/'research-code-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
cycle=json.loads((HERE/'cycle-result.json').read_text());cycle['final_checkpoint_utc']=now
(HERE/'cycle-result.json').write_text(json.dumps(cycle,indent=2)+'\n')
print('Final reports refreshed; prior findings preserved.')
