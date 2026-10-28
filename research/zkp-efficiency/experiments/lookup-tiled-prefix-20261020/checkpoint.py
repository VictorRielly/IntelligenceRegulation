from pathlib import Path
import datetime,hashlib,json

HERE=Path(__file__).resolve().parent;ROOT=HERE.parent.parent
run='20261020T151854Z-beab78ce';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
probe=json.loads((HERE/'result.json').read_text());audit=json.loads((HERE/'validation-result.json').read_text())
models=json.loads((HERE/'model-result.json').read_text())
assert probe['status']==audit['status']=='PASS'
def plan(dd,cap=None,q=0,T=128):
    f=next(x for x in models if x['model']=='8B' and x['T']==T and x['dd']==dd)
    return next(x for x in f['plans'] if x['mode']=='column' and x['cached_depth']==16 and x['fold_cap_bytes']==cap and (cap is not None or x['prefix_rounds']==q))
table='| Schedule, frozen R9 8B T128 | Modeled MiB | Tree nodes, nonDD / DD | Leaves, nonDD / DD |\n|---|---:|---:|---:|\n'
for name,cap,q in [('Prior owned reference',None,0),('Fixed one streamed round',None,1),('Adaptive 32MiB destination cap',32*2**20,4),('Adaptive 16MiB destination cap',16*2**20,4),('Adaptive 8MiB destination cap',8*2**20,4)]:
    a=plan(False,cap,q);b=plan(True,cap,q)
    table+=f"| {name} | {a['modeled_peak_bytes']/2**20:.6f} | {a['tree_work_ratio']:.6f}x / {b['tree_work_ratio']:.6f}x | {a['leaf_ratio']:.6f}x / {b['leaf_ratio']:.6f}x |\n"
full='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; increasing context can increase attention work quadratically.
Private 8B >=50 proved positions/s on RTX 5090 or another named high-end GPU
remains unachieved.
'''
historical='''Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verification
42.709s + public load13.681s; recheck34.395s + load10.739s. Startup fraction,
isolated serialization and steady slope unknown. This is not a high-end GPU result.
'''
next_local='''Next local: port this consumer to exact native Goldilocks Fp2 arithmetic
with a synthetic ordered U8 reader using the same per-attempt denominator
cache/refusal rules. Differentially check every original helper term, all
sample rows and terminal MLEs, including zero denominators at zero multiplicity.
Keep source arrays immutable; never cache inverse results across challenges.
'''
next_owner='''Next owner: complete GPU phase/capacity clocks and verified fixed-context
resident1/2/4/8 workloads, DD context scaling and all-eleven FZC compiler A/B
under shared locks. Count only independently verified complete receipts and
retain fresh masks. Main/Claude reviews any integration; no merge here.
'''
body=f'''Cycle0107 — `{run}` — 2026-10-20 UTC.
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

{table}

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

Final probe: {probe['checks']} checks, {probe['layer_consumers']} tiny consumers,
{len(probe['negative_controls'])} controls. Independent audit: {audit['cost_schedules']} randomized
cost schedules, {audit['cost_mutations']} cost mutations, {audit['independent_original_MLE_cases']} original Boolean-basis
cases, causal scan-boundary checks and{audit['verified_pins']} unchanged source pins.
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
accelerator not invoked. Probe {probe['elapsed_s']:.6f}s /{probe['maxrss_KiB']}KiB;
independent audit {audit['elapsed_s']:.6f}s /{audit['maxrss_KiB']}KiB.
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

{full}
{historical}
{next_local}
{next_owner}
Only research excluding runtime written. No production/Git/build/GPU/install/
external writes/messages/purchases/escalation. Saved reports do not establish
external delivery.
'''
(HERE/'README.md').write_text('# Budget-adaptive tiled lookup prefix\n\n'+body)
findings=ROOT/'FINDINGS.md'
marker=f'## Cycle 0107 — budget-adaptive tiled lookup prefix (2026-10-20)'
assert marker not in findings.read_text()
with findings.open('a') as f:f.write('\n'+marker+'\n\n'+body+'\n[Experiment](experiments/lookup-tiled-prefix-20261020/README.md), [handoff](handoffs/20261020-lookup-tiled-prefix.md).\n')
short=f'''# ZKP efficiency progress

Cycle0107 complete — `{run}` — 2026-10-20 UTC.

**No proving speed improvement measured.** Budget-adaptive streaming lowers
the selected frozenR9 8B T128 lookup-array model from68.030 to36.022MiB.
Only nine leaf-layer services rescan; tree-node/fold counts stay unchanged,
while original leaf reads rise6.4–6.9%. Streaming every uncached layer instead
raises treework3.87->5.74x nonDD; the adaptive schedule avoids that penalty.
These are prospective consumer arrays/costs, not native proof memory or time.

Completed {probe['checks']} checks/{probe['layer_consumers']} tiny consumers/{len(probe['negative_controls'])} controls; independent
{audit['cost_schedules']} cost schedules/{audit['cost_mutations']} mutations/{audit['independent_original_MLE_cases']} original-MLE cases/{audit['verified_pins']} pins pass.
Synthetic F65537 only, no private GKR/CFS/PCS. One thread;
probe {probe['elapsed_s']:.3f}s/{probe['maxrss_KiB']}KiB, audit {audit['elapsed_s']:.3f}s/{audit['maxrss_KiB']}KiB.
Eleven LIVE queries/eight primary records: Plonky3 implementation/release,
Chimera October16 revision and newly screened2012 GPU GKR residency method.
Author gains not reproduced; version/license/date/fetch scope recorded.

{full}
{historical}
Blockers: complete GPU phase/capacity evidence; reviewed private consumer,
ordered original-A links and terminal binding. Latest fidelity layouts are
excluded from these frozenR9 counts. Next local: native Fp2/U8 denominator
reader differential oracle. Next owner: verified resident1/2/4/8, DD context
scaling and all-eleven FZC compiler A/B under shared locks.

[Experiment](experiments/lookup-tiled-prefix-20261020/README.md),
[handoff](handoffs/20261020-lookup-tiled-prefix.md),
[dated report](progress/{run}.md).
Research-only writes; saved reports do not establish external delivery.
'''
(ROOT/'PROGRESS.md').write_text(short)
(ROOT/'progress'/f'{run}.md').write_text(short.replace('# ZKP efficiency progress','# ZKP efficiency cycle0107 — 2026-10-20',1))
state=f'''# ZKP efficiency explorer — durable state

Cycle0107 COMPLETE: `{run}`. CheckpointUTC {now}.
Deadline15:38:54UTC; next cycle no earlier than16:18:54UTC.
Evidence: experiments/lookup-tiled-prefix-20261020/. Prior memory/docs preserved
in startup; AGENDA, ledger, latest0106 results and current project context read.

No proving speed improvement measured. Budget-adaptive32MiB destination cap
reduces selected R9 8B T128 arrays68.030->36.022MiB. Nine leaf-layer services
add18,874,368 reads (+6.416/+6.885% nonDD/DD), tree-node/fold counts unchanged.
Fixed-q1 has same peak but5.740/5.770x treework vs3.870/3.885x baseline.
Adaptive16MiB gives20.018MiB at4.052/4.080x treework. No net memory/time/fit
claim; all private GKR/CFS/PCS/native backing/source costs still excluded.
Counted-onlyT512 cap32 gives36.022MiB but substantial source/rebuild cost;
cap8 misses with qmax4 and is explicitly false. No T512 profile admitted.

Final probe{probe['checks']}checks/{probe['layer_consumers']}tiny consumers/{len(probe['negative_controls'])}controls;
independent{audit['cost_schedules']}cost schedules/{audit['cost_mutations']}mutations/{audit['independent_original_MLE_cases']}original-MLE
cases/causal scan checks/{audit['verified_pins']}pins. F65537 only. All original rows,
terminals/MLEs match independent reference; factorized equality/0/1 exact.
One thread/nice19/first allowed core/59sCPU+alarm/60sparent/512MiBAS;
estimate64MiB. Probe{probe['elapsed_s']:.6f}s/{probe['maxrss_KiB']}KiB;
audit{audit['elapsed_s']:.6f}s/{audit['maxrss_KiB']}KiB. Initial direct-equality
version retained; final successful refinements, no failed experiment.

ElevenLIVEqueries/eightrecords631->639. New older2012 GPU GKR two-layer
residency/transfer filter; Plonky3 docs/source/release alignment caveats and
fetch failures explicit. Full release SHAfe5e46d755b8a7d9069778361e21b33e5978b377
inspected, Cargo-version change only. Apache2.0 text inspected; no external
code run or author gains reproduced. ChimeraOct16 primary date refreshed.

Twenty ranked hypotheses retained; top3 wholeGPU+resident1/2/4/8, DDcontext
scaling, actual capacity/exclusive clocks. Rank7 materially refined to
public-budget adaptive streaming. FZC compiler A/B remains ahead. Handoff:
handoffs/20261020-lookup-tiled-prefix.md. Main/Claude reviews; no nativepatch.

{next_local}
{next_owner}
{full}
{historical}
R9N-r9-a/b, DD privacy gate, D32 and narrow D33/D34/D35 remain. LOW fidelity
proposal excluded. Only research excluding runtime written; no production/
Git/build/GPU/install/external writes/messages/purchases/escalation.
Reports do not establish external delivery.
'''
(ROOT/'STATE.md').write_text(state)
handoff=f'''# Budget-adaptive tiled lookup prefix — research handoff

Cycle0107 / `{run}`. Candidate for main/Claude review; no merge or native
patch. Evidence: [experiment](../experiments/lookup-tiled-prefix-20261020/README.md).

Selected R9 T128 top16 per-column model68.030->36.022MiB at unchanged
tree-node/fold counts and6.4–6.9% extra original leaf reads. Stream only the
nine oversized leaf-layer services for a32MiB destination cap. Fixed q1
over all uncached layers is dominated. Counts omit original private A/model,
other proof owners, new masking/CFS/PCS, backing and transfers; no native fit
or throughput established. All clocks/proved positions remain unmeasured/0.

Research implementation is `experiments/lookup-tiled-prefix-20261020/tiled.py`.
`consumer(factory, row_count, point, q, lambda, field, stats)` yields a complete
cubic row, accepts the next global challenge via `send`, and finally returns
the terminal and four original-MLE evaluations. Factory reopens the immutable
ordered source. Exactly q+1 full source scans; each early message is computed
with preceding challenges only. Materialize four residual planes after q
challenges, preserving independent MLE products and terminal provenance.
`model(..., fold_cap_bytes=...)` chooses minimum q per public layer, at most4;
`fold_cap_satisfied` is false for a clipped budget. Budget is array capacity,
not complete device memory. Cached children are copied, never consumed.

Potential Rust interface after protocol design:
```rust
// Prospective research interface, not implemented or compiled.
trait OrderedFractionSource<F> {{
    fn len(&self) -> usize;
    fn scan(&self, emit: &mut dyn FnMut(F, F)) -> Result<(), Error>;
}}
// sample_round(known_prefix) -> cubic message;
// bind_global_challenge(r), then materialize_residual at a public cut.
```
Connect only through a separately reviewed replacement for frozenR9
`protocol.rs::u8_denominator_inverses/helper_inverses_u8/write_h`,
`shape.rs::lookups_per_position/claim_sites`, `layout.rs::lookups_at`,
`argument.rs::helper_sum/SC_TAB`. Exact source pins in source-pins.json.
The native U8 inverse cache already exists; rediscovering it is not a speedup.

Validation: {probe['checks']} checks/225 tiny consumers/{len(probe['negative_controls'])} controls; independent240
cost schedules/1680 mutations/70 original-MLE cases and causal scan checks.
All9 frozen/source pins unchanged. Commands/seeds/hardware/logs retained.
Unmasked F65537 only; native Goldilocks Fp2/masks/transcript/refusals/receipts
are untested. Control source drift is detected by the original oracle;
the prototype supplies no cryptographic source authentication.

Every root/intermediate remains private. Preserve one committed global
histogram,83 ordered U8 links atT128 (85 atcountedT512), every original
denominator refusal and exact multiplicity. Root equality alone does not bind
sites. A reviewed private GKR, masked terminal linkage to original A, actual
claim/PCS-site accounting, one-opening composition, whole-run soundness and
joint-view privacy are prerequisites. No public roots, guessed challenges,
mask/opening reuse or per-challenge inverse reuse. Preserve R9N-r9-a/b and
D32/D33/D34/D35; latest LOW fidelity proposal is outside these counts.

Owner validation before integration: actual capacity and complete phase
clocks; native original-MLE/round/transcript/refusal parity, independently
verified full receipts and current privacy gates under shared locks. Reject
if source storage/reloads or new proof owners erase the capacity benefit,
the device was not capacity-limited, any binding fails or total workload
regresses. No numeric end-to-end ceiling without exclusive fraction f;
even free affected-work deletion is bounded by1/(1-f).

{next_local}
{next_owner}
'''
(ROOT/'handoffs'/'20261020-lookup-tiled-prefix.md').write_text(handoff)
manifest=[]
for path in sorted(HERE.glob('*.py')):
    manifest.append(dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bytes=path.stat().st_size))
(HERE/'research-code-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(HERE/'cycle-result.json').write_text(json.dumps(dict(cycle='0107',run_id=run,checkpoint_utc=now,status='COMPLETE',probe=probe,audit=audit,selected_adaptive_nonDD=plan(False,32*2**20,4),selected_adaptive_DD=plan(True,32*2**20,4),new_source_records=8,hypotheses=20,new_full_stack_proofs=0),indent=2)+'\n')
print(json.dumps(dict(status='checkpointed',utc=now,probe_checks=probe['checks'],audit_checks=audit['checks'],reports=['STATE.md','PROGRESS.md',f'progress/{run}.md','FINDINGS.md','handoffs/20261020-lookup-tiled-prefix.md'])))
