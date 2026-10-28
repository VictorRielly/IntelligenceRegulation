"""Save reports in the authorized research lane only."""
from pathlib import Path
import datetime,json
E=Path(__file__).resolve().parent;R=E.parents[1]
RUN='20261020T231854Z-2da27679'
p=json.loads((E/'result.json').read_text());a=json.loads((E/'validation-result.json').read_text());c=json.loads((E/'census-result.json').read_text())
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
scope='''New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: Intel Core Ultra 9 185H CPU, one worker, no GPU.
Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction,
steady-state and total-workload proved rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Counted T32/T64/T128, L1/L2/L32,
1/2/4/8-pass schedules and 192 tiny encoded rows are synthetic diagnostics, not proved positions.
Larger workloads remain allowed; attention can grow quadratically with context.
The complete private 8B >=50 proved tokens/s target on RTX 5090 or another named high-end GPU remains unachieved.'''
historical='''Historical CPU diagnostic carried without rerun/reverification: non-DD 8B T128,
32 layers, one 16-thread CPU pass, GPU off; total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s and load 17.595 s. Seal 84.824 s contains
overlapping subwork; do not add those clocks. Receipt 922,711,264 B; fresh verify
42.709 s + public load 13.681 s; recheck 34.395 s + load 10.739 s. Isolated serialization,
startup fraction and steady slope are unknown. This is not a high-end GPU baseline.'''
next_action='''Next local: inspect inverse-size scaling in actual private PCS commit/open kernels,
count repeated fixed public inversions separately from per-row multiplies and CPU/GPU
batch boundaries, then test a public scale table against independent Fermat inverses
and direct DFT. Preserve a negative if the count ceiling is negligible; launch no build/GPU.
Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident 1/2/4/8 workloads, DD fidelity/context scaling and the
all-eleven FZC compiler A/B under shared heavy/build locks. No such job ran here.'''
finding=f'''

## Cycle 0115 — public coset leases after the NTT cache negative (2026-10-20)

Run `{RUN}`; checkpoint {now}. **No proving improvement measured.**
Agenda, mandatory durable memory, 709-record ledger, latest 0114 results and project
instructions/status/decisions/active coordination were read/scanned and pinned.
Early and midcycle state checkpoints preserved; prior findings and negatives retained.

Question refined: does public PCS preparation still recur across fixed-context resident
proofs? GPU NTT roots/twiddles are already process-resident and monotonically growing;
the earlier cycle 0084 negative is confirmed in active/R9 sources. CPU NTT construction
is shared across all blocks in a run, not per block. Opening-index plans depend on current
transcript challenges; shape-only reuse is invalid. A different repeated object exists:
public coset powers at every hiding commitment, separately uploaded and, for deferred
GPU commitments, retained by ZkReenc. M builds its own CPU powers too.

Source-backed T128/L32 skeleton: 2 endpoints + 31 boundaries + 64 A/H hiding offers,
plus 32 CPU M commitments. Conditional on all main offers taking the GPU path,
public powers uploads 48.5 -> 0.5 MiB for one cached pass and 388 -> 0.5 MiB for eight
synthetic passes; host power builds 129/258/516/1032 -> 1. One-pass public loop words
6,488,064 -> 65,536. Every private pad/salt/mask/proof remains fresh. Salt generation
207,618,048 B per trace is unchanged; pad count sum(rows*q) not numerically censused.
No production work actually eliminated. These are incidence counts, not observed launches,
traffic, actual memory or time. Active GPU and reviewed R9 profiles are separately pinned;
no combined GPU admission or T512 profile assumed.

Selected deferred device public-powers peak 2.5 -> 0.5 MiB; fully resident peak unchanged
at 0.5 MiB. Add 0.5 MiB idle device retention and a separate 0.5 MiB host owner. These
exclude private data/pads, masks, PCS buffers, pooled/idle/driver and all other owners.
Evict-between-passes requires eight uploads. Immutable growth charges old+new overlap;
the 32+64 B control peaks at 96 B and eviction preserves outstanding leases.

Baseline/eliminated/added/ceiling: replace only repeated public powers generation/uploads,
adding full public identity, immutable lease/view lifetime handling, actual-size coset
validation and retained/growth capacity. CPU source loop includes a multiplication per
entry; this is not a compiled instruction count. Unknown exclusive affected fraction f
gives even free-deletion ceiling 1/(1-f). Resident workload slope and startup are unknown;
amortization cannot exceed context/recurring. Falsify on changed values/refusals/column
order/RNG consumption, stale identity, bad async lifetime, meaningful retained-capacity
regression, or no enclosing improvement. Cache is low priority pending exclusive clocks.

Probe {p['checks']} assertions, {p['synthetic_rows']} synthetic rows, {p['encoded_positions']}
encoded positions and 15 control families PASS. Cache-on/off matches independent quadratic
interpolation/Horner. Independent explicit polynomial construction/evaluation and separate
live-lease oracle pass {a['checks']:,} checks, {a['capacity_events']:,} events, 145 schedules
and 21 source/prior pins; no producer imports. Census {c['checks']} checks/22 source
fragments PASS. Growth from a valid nn16 to invalid nn32 coset refuses; h=0 helper behavior
preserved without profile admission. Zero/one/monomial/field-edge rows, fresh pads/salts,
device/context/representation keys, immutable growth and eviction are covered. No native
leaf hashes/transcript/refusal/privacy gate or saved-proof verification was run.

Probe {p['wall_seconds']:.6f} s/{p['rss_kib']:,} KiB RSS; census {c['wall_seconds']:.6f} s/
{c['rss_kib']:,} KiB; independent audit {a['elapsed_s']:.6f} s/{a['maxrss_KiB']:,} KiB.
One worker, nice19, first allowed core; 59s CPU/alarm, 60s parent, 512MiB AS.
Initial 64MiB memory estimate was low for census/audit; corrected estimate 128MiB,
still well below cap. Initial passing results retained before tightening identity controls
and adding degenerate fixtures. Wrong source/module and prior audit filenames corrected
without touching prior artifacts. No native build, GPU or downloaded-code execution.

Six LIVE queries/nine primary records appended 709 -> 718. ICICLE official domain contract
(version3.0, updated2025-08-06), v4 release/full version-only commit/MIT body and October16
Chimera refreshed. Known hardware-comparison/on-the-fly GPU work retained. Newly screened
older OpenNTT paper received2024-10-24/revised2024-11-13 and FPGA artifact/MIT body were
absent from starting ledger; not a CUDA plug-in. PDF403, guessed v4 docs path inaccessible
and pinned ICICLE LICENSE cache miss recorded. MainMIT body inspected, release year and
OpenNTT commit/update date unverified. No author speed reproduced.29 ranked hypotheses
preserve all prior negatives; top4 unchanged, rank28 tested/refined, OpenNTT rank29 added.

{scope}

{historical}

Integration seam: R9 core pcs::coset_powers/commit_zk_owned_with_tag,
mask_commit_tagged and device ZkReenc/dev_commit_zk_from. Larger cached host slices
cannot be passed whole because current GPU entry asserts pows.len()==nn. Exact prefix
views/lease signatures, raw capacity accounting and async completion require owner review.
No native patch/merge. D30 N-r9-a/b, DD privacy gate, D32 and narrow D33/D34/D35 remain.

{next_action}

Only research excluding runtime written; no production/reviewer/instruction/calibration/
Git/receipt edits, native build/GPU/install/external writes/messages/purchases/escalation.
Saved reports do not establish delivery or supervisor liveness. Main/Claude integrates.
[Experiment](experiments/public-ntt-cache-incidence-20261020/README.md),
[handoff](handoffs/20261020-public-coset-lease.md).
'''
with (R/'FINDINGS.md').open('a') as f:f.write(finding)
short=f'''# ZKP efficiency progress

Cycle 0115 complete — `{RUN}` — 2026-10-20 UTC.

**No proving speedup measured.** GPU NTT twiddles are already cached. A tested immutable
public coset owner could reduce counted powers uploads from 48.5 to 0.5 MiB per first
T128/L32 pass, and selected deferred public capacity from 2.5 to 0.5 MiB. It retains
0.5 MiB at idle. These are conditional source/synthetic counts; native time and GPU
admission are unknown. Fresh private pads, salts and masks remain per proof.

192 synthetic rows and an independent audit of 92,531 checks / 50,240 capacity events
pass. Six LIVE queries / nine primary records; 29 ranked hypotheses retained.

{scope}

Next: count fixed public inverse-size scaling versus per-row work; owner whole-GPU
clocks and independently verified resident 1/2/4/8 workloads remain the priority.
[Experiment](experiments/public-ntt-cache-incidence-20261020/README.md),
[dated report](progress/{RUN}.md), [handoff](handoffs/20261020-public-coset-lease.md).
Saved files do not establish external delivery.
'''
(R/'PROGRESS.md').write_text(short)
dated=f'''# Cycle 0115 — {RUN}

Checkpoint UTC {now}. Started 23:18:54 UTC; deadline 23:38:54 UTC.
Next cycle no earlier than 2026-10-21 00:18:54 UTC.
'''+finding.split('## Cycle 0115',1)[1].split('\n',1)[1]
(R/'progress'/f'{RUN}.md').write_text(dated)
state=f'''# ZKP efficiency explorer — durable state

Cycle0115 COMPLETE: `{RUN}`. Checkpoint UTC {now}.
Started23:18:54UTC; deadline23:38:54UTC. Next cycle no earlier than2026-10-21T00:18:54UTC.
Early/midcycle checkpoints, prior state and source pins retained in
`experiments/public-ntt-cache-incidence-20261020/`.

**No proving improvement measured.** Device NTT twiddles already process-resident;
root/twiddle caching removes no upload. A different immutable public coset owner
passes 192-row differential/reference tests. Conditional T128/L32 public powers:
97 GPU hiding offers +32 CPU M builds, uploads48.5->0.5MiB first pass,388->0.5MiB
over8trace passes; CPU builds129->1. Selected deferred device powers2.5->0.5MiB,
resident peak unchanged, plus0.5MiB idle device and0.5MiB host retention. Counts only;
no native launches, traffic, actual HWM, admission or elapsed saving. Every private
pad/salt/mask stays fresh. Active GPU/R9 profiles separately pinned; no T512 admission.

Probe286checks/192rows/7392encodedpositions/15controls PASS; census1442checks/145traces/
22fragments; independent92531checks/50240capacityevents/21pins PASS. Probe0.393082s,
census0.211661s,audit0.830058s; maximum RSS84740KiB. OneCPUworker/nice19/core0,
59sCPU+alarm/60sparent/512MiBAS; revised128MiBcensus+audit/64MiBprobe estimate.
Initial passing artifacts retained before stronger identity/degenerate controls.

Source ledger709->718:6LIVEqueries/9primaryrecords. ICICLE domain/cache, release/full
version-only commit/MIT and ChimeraOct16 refreshed; new olderOpenNTT FPGA methodology
screened (MITbody read,PDF403,commit/date unknown). No author runtime reproduced.
29ranked hypotheses preserve earlier negatives. Top4 owner priorities unchanged;
coset reuse rank28 needs exclusive clocks before promotion; OpenNTT rank29.

{next_action}

Handoff `handoffs/20261020-public-coset-lease.md`: exact nn prefix views, immutable
device/context leases, growth/eviction, refusal preservation and async completion
remain native obligations. Main/Claude reviews/integrates; no native patch/merge.

{scope}

{historical}

No production, reviewer, calibration, instruction, receipt, Git or runtime edits;
no build/GPU/install/downloaded-code/externalwrite/message/purchase/escalation.
D30 N-r9-a/b, DDprivacygate, D32 and narrow D33/D34/D35 remain. Saved reports do not
establish message delivery or supervisor liveness. Final artifact audit follows.
'''
(R/'STATE.md').write_text(state)
full=dict(proofs=0,passes=0,positions=0,context_length=None,accelerator=None,
          research_device=p['cpu'],witness_s=None,proof_s=None,serialization_s=None,
          verification_s=None,startup_s=None,startup_fraction=None,
          steady_state_proved_positions_per_s=None,total_workload_proved_positions_per_s=None,
          long_context_prefill=False,resident_model_proofs=False,decode=False)
(E/'target-accounting.json').write_text(json.dumps(dict(full_stack=full,
    historical_cpu_diagnostic='Carried R8 non-DD8B T128/L32 one16-threadCPU pass total478.737s; not rerun/reverified',
    startup_model='T_R=S+R*C+drain; rate ceiling context/C; S,C,drain unmeasured',
    cache_model_ceiling='1/(1-f) even for free deletion; exclusivef unknown and added costs remain',
    target_achieved=False),indent=2)+'\n')
print(json.dumps(dict(status='SAVED',run_id=RUN,sources=718,ranked_hypotheses=29,full_stack=full)))
