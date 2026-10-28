"""Research-only checkpoint; writes no production, reviewer or runtime files."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal

resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
E=Path(__file__).resolve().parent;R=E.parents[1]
RUN='20261020T171854Z-0041295d';NOW=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((E/'result.json').read_text());audit=json.loads((E/'validation-result.json').read_text())
assert result['status']==audit['status']=='PASS'
assert len(json.loads((E/'hypotheses.json').read_text()))>=3

measurements="""New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, repeated resident-model pass or decode was performed. Larger workloads
remain allowed; attention work can increase quadratically with context. The
complete private 8B target of >=50 proved positions/s on RTX 5090 or another
named high-end GPU remains unachieved.
"""
historical="""Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verify42.709s
+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown. This is not a high-end GPU result.
"""
next_local="""Next local: test reversible fraction-tree storage against an independent
immutable native-field tree. Recover both N,D at every layer using preserved
right children, keep source order explicit, and count inversions/batch scratch,
leaf-buffer capacity and avoided rescans. Include zero denominator at zero
multiplicity and original ordered-A terminal checks. The OpenVM source is a
lead, not imported code or a private proof design. Do not revisit a full protocol
replacement until its private input-consistency/claim-reduction design is reviewable.
"""
next_owner="""Owner next: complete GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and the all-eleven
FZC compiler A/B under shared build/heavy locks. Retain fresh masking and count
only completed, independently verified full-stack receipts.
"""
costs="""The baseline is frozen R9 U8 helper data, carried as420.25MiB nonDD /
390.25MiB DD at8B T128. No native proof work was removed. A reviewed fraction-tree
replacement might eliminate those helpers, but adds every source scan, tree
operation, fold, original-A/table link, mask, CFS functional, PCS group, encoding
and transcript/refusal obligation. Existing per-attempt inverse caching is retained.

This ledger counts **semantic evaluation obligations, not actual PCS sites**.
For the unbatched candidate topology, every layer returns both N,D on both child
branches. At the leaves, looked-U8 numerators are public1; their denominators
depend on ordered original A. The single global256-entry table has private
histogram numerators and public denominators. T128 has166 looked-column branch
links +2 histogram links =168 unmerged original-A obligations. Actual native
Ids, mask pairs, extension rounds, CFS coefficients and opening groups remain
null. These obligations can be reduced only by a separately reviewed protocol,
not by equating equal counts or reusing a private opening.

If **all** private intermediate/leaf terminals each retain a fresh native pair
at the current T128 row width2^14, reserved BASE-field mask rows alone total
1527MiB nonDD /1509MiB DD. Formula: C *2rows *2^14words *8B. Even only168 leaf
sites would add42MiB under that same conditional rule. These are conditional
payload subcosts for a naive contract, not universal lower bounds or measured
peaks. Intermediate fractions are challenge-derived, so appending them to the
original pre-challenge A commitment is not an implementation. New commitment
timing/lifetimes and an integrated masked recursion need their own design.
This rejects the naive all-intermediate native-pair approach as a memory win;
it does not reject GKR generally or establish a net leaf-only saving.

The prior36.022MiB selected-array model still omits private protocol costs and
is not repriced as native memory. If f is the unknown exclusive affected time
fraction, even free deletion has speed ceiling<=1/(1-f), before added costs.
There is no numeric complete-GPU throughput prediction. Falsify on original
binding/exactness/refusal/RNG-order/privacy/soundness drift, omitted capacity,
no relevant device capacity cliff or slower complete workloads.
"""
evidence=f"""Main: {result['checks']}checks,105 complete tiny layer consumers,420 branch/component
point checks,834 tiny original-A affine-expression links and4 zero-table-lift
cases, up through the native T128 row width2^14. Seventy-seven control instances
cover11 families. Every cubic row, parent claim chain and original MLE terminal
matches independent Boolean-basis arithmetic. Challenges include0/1 and non-base
Goldilocks Fp2. Unmasked arithmetic only; synthetic leaf sizes2..64, depths1..6.

Independent audit: {audit['checks']}checks; all834 descriptors are reconstructed by a
restricted interpreter of the pinned Rust lookups_at source and its frozen
shift constants, then matched in original order across10 public count fixtures.
It independently checks834 tiny affine links,126 MSB half-fold values, four
saved ledgers and all14 source pins. Three in-memory native descriptor mutations
preserve counts but change the binding and are detected. No external code ran.
The symbolic plane names are not numeric native Ids or captured native claims.
Fixtures use w32/fE9 and frozen requantization shifts; they are not real trained
export captures, and exclude the newer LOW fidelity proposal.

Adjacent children2j+b map from LSB row challenges rho to native MSB
reverse(rho)||b. Merging with an internally supplied eta gives reverse(rho)||eta;
the next consumer's LSB parent point is eta||rho. Eta is only an unmasked
arithmetic fixture, not an approved new native transcript draw. Reversing the
whole point, moving the branch to the front or swapping original sites fails.
Native terminal-extension/mask axes are outside this data-axis adapter.
The table lift requires the product of(1-high_coordinate) over zero-pad axes;
omitting that factor fails. Roots alone still permit wrong ordered-source swaps.

Probe {result['elapsed_s']:.6f}s /{result['maxrss_KiB']}KiB RSS;
audit {audit['elapsed_s']:.6f}s /{audit['maxrss_KiB']}KiB.
One worker, first allowed core0, nice19,59sCPU/alarm,60sparent,512MiB address
space; estimated64MiB. Intel Core Ultra9 185H /WSL2; no GPU, native build or
dependency install. Seed20261020109; independent audit uses deterministic
source interpretation and saved fixtures. These are diagnostic research clocks.
The first audit failed because its parser searched a comment after stripping
comments; exact logs and script are retained in failed-audit-source-boundary/.
The corrected brace-boundary parser passes. Earlier successful stages and the
refinement to a unique count-preserving site permutation are retained.
"""
sources="""Ten native LIVE queries;11 primary source/disposition records appended650->661.
New [OpenVM SWIRL implementation](https://github.com/openvm-org/stark-backend/blob/main/docs/cuda-backend/gkr-prover.md)
and [input-consistency documentation](https://github.com/openvm-org/stark-backend/blob/main/docs/interactions.md)
separate tree checks from original trace expressions and PCS/WHIR. The inspected
CUDA revert excerpt motivates the new reversible-storage question; its generic
revealed roots/claims cannot be published by this private construction. Main's
MIT terms were read; source/update/full-commit alignment is unverified. Release
v2.0.1 advertises pinned host pools and phase peaks, but month/day render without
year and commit fetches fail. No latest-version/date inference or speed adoption.

New older [Virgo++](https://eprint.iacr.org/2020/1247), received2020-10-09 /
revised2021-05-19, targets unlayered circuit padding; that benefit is not shown
for this already layered tree. Full primary PDF403; author repo license body /
history cache misses retained, MIT only advertised there. Prior LogUp-GKR,
ZK-sumcheck2017 and streaming-ZK2024 assessments are refreshed, not called new.
[Chimera](https://eprint.iacr.org/2026/1388)'s October16 revision and resettable
randomness October8 revision keep whole-proof clocks and fresh masks in scope.
Boolean-GKR primary abstract withdraws an earlier Keccak end-to-end comparison
after a circuit-size error; no author speed was used. Dates, exact URLs, license,
fetch/commit limits and claim/reproduction scope are in source-records.json.

Twenty-one ranked hypotheses retained: top3 whole-GPU+verified resident1/2/4/8,
DD context scaling after T128 null, and actual capacity/exclusive phase clocks.
All-eleven FZC compiler A/B stays ahead of protocol redesign. Rank7 is refined
by this mask-budget negative; rank21 adds reversible storage with inverse and
capacity costs. Rotation covered sumcheck/GKR, memory and composition; next
rotate batching/amortization and NTT/commitments, retaining lookup/softmax and
quantization/arithmetic. Source counts are not proving progress.
"""
boundaries="""Only research excluding runtime written; no production/reviewer/instruction/
Git/GPU/install/external writes/messages/purchases/escalation or merge. R9N-r9-a/b,
DD privacy gate, D32 and narrow D33/D34/D35 scopes remain. Main/Claude reviews
integration. Saved reports do not establish message delivery or supervisor liveness.
"""

readme=f"""# Private fraction-tree site budget — cycle0109

Run `{RUN}`,2026-10-20UTC. **No proving speed improvement measured.**
The useful result is a rejection of naive per-intermediate native masking and
an exact ordered-source/data-point adapter prerequisite. No native private proof.

{costs}
| 8B fixture | Ordered U8 columns | Tree layers | Private semantic terminals | Unmerged A leaf obligations |
|---|---:|---:|---:|---:|
| T128 nonDD |83|1569|6108|168|
| T128 DD |83|1551|6036|168|
| T512 counted only nonDD |85|1805|7048|172|
| T512 counted only DD |85|1761|6872|172|

Each has one global U8 table. T512 is unregistered counted geometry only.
No actual large arrays, native claims, commitments, GKR/CFS/PCS or proof verified.

## Evidence and reproduction

{evidence}
```
python3 experiments/private-fraction-site-ledger-20261020/run_bounded.py probe.py
python3 experiments/private-fraction-site-ledger-20261020/run_bounded.py validate.py
```

`ledger.py` supplies columns/obligations and native_child_point/native_merged_point.
`probe.py` supplies the prospective top-down algebra; `validate.py` independently
interprets local Rust descriptors and uses tuple-field MSB half-folding. Source
pins, commands, hardware, four explicit ledgers and summaries are retained.

## Research disposition

{sources}
{measurements}
{historical}
{next_local}
{next_owner}
Handoff: [ordered sites and point adapter](../../handoffs/20261020-private-fraction-site-ledger.md).
{boundaries}
"""
(E/'README.md').write_text(readme)
handoff=f"""# Review-only: ordered U8 fraction-tree sites and native data-point mapping

Run `{RUN}`,2026-10-20UTC. **No native private proof or speed improvement.**

Patch location: `experiments/private-fraction-site-ledger-20261020/ledger.py`,
`probe.py`, `validate.py`; no production patch is ready. Interface:
`columns(fixture)` yields symbolic original Lk expressions in order;
`obligations(fixture)` yields(column,domain,ordinal,expression_hash,depth,branch,N/D)
with actual native sites/masks/groups null. `native_child_point(rho_lsb,b)` and
`native_merged_point(rho_lsb,eta)` yield reverse(rho)||b/eta. Only data axes map;
extension axes, real Ids, private claims and new transcript draws remain unbuilt.

Rust seams: frozen R9 private_block/layout.rs::lookups_at/Lk; shape.rs::claim_sites,
slots/totals; argument.rs::lk_tables/helper_sum/claim_point/build_claim/run_slot;
protocol.rs::audit_claims/write_h; zkp-core/mle.rs::eq_table_msb/eval_mle_ext and
sumcheck.rs::CfsMask. All are read-only source pinned in source-pins.json.
An owner adapter must resolve shaped numeric planes and the actual calibration,
keep original ordered expressions, source lifetimes, full table lift/pad rules,
fresh masks and denominator refusal/RNG/draw/absorb order. Never publish raw
tree roots, four evaluations or unmasked cubic rows from this arithmetic test.

{costs}
{evidence}
Every current obligation identity must survive any batching. A count-preserving
permutation is not a binding; the random merge needs a complete masked protocol
argument, fresh randomness, original-A input consistency, audited CFS functionals,
group counts and one-opening obligations. No existing mask pair/opening may be
reused. The source interpreter is not a native verifier or a soundness proof.
Any new profile changes the accepted privacy/soundness scope and needs review.

{next_local}
{next_owner}
Main/Claude reviews and integrates if appropriate; no merge in this lane.
"""
(R/'handoffs/20261020-private-fraction-site-ledger.md').write_text(handoff)

progress=f"""# ZKP efficiency progress

Cycle0109 complete — `{RUN}` — 2026-10-20UTC.

**No proving speed improvement measured.** The prospective lookup replacement
now has an ordered branch/component ledger and an exact data-point mapping.
For frozen8B T128, a naive native mask pair per private intermediate terminal
would retain1527/1509MiB(nonDD/DD) in mask rows alone, versus420.25/390.25MiB
of carried U8 helper data. This rejects that naive contract, not GKR generally.
Actual new private claims/CFS/PCS and net native memory/time remain unknown.

Main2715 checks; independent29703 checks. All834 ordered symbolic Rust lookup
descriptors and834 tiny original-A affine links match.105 unmasked layer
consumers/420 branch checks pass; wrong site/axis and three count-preserving
source mutations are detected. No numeric native Ids or private transcript built.
Probe4.376s/48,304KiB; audit1.987s/37,176KiB; one CPU worker/no GPU.
Initial audit parser failure is preserved; the corrected audit passes.

Searched OpenVM SWIRL/release/source, LogUp-GKR, Chimera October16 and older
Virgo++ plus ZK/PCS boundaries:10 LIVE queries/11 source records. No author
speed reproduced.21 ranked hypotheses retained; top3 owner GPU/resident,
DD scaling and capacity clocks; rank7 refined and reversible storage added.

{measurements}
Next local: reversible tree reconstruction/cost controls; owner: verified
resident1/2/4/8, DD scaling, phase/capacity clocks and all-eleven FZC A/B.

[Experiment](experiments/private-fraction-site-ledger-20261020/README.md),
[handoff](handoffs/20261020-private-fraction-site-ledger.md),
[dated report](progress/{RUN}.md).
Research-only writes; saved reports do not establish external delivery.
"""
(R/'PROGRESS.md').write_text(progress)
dated=f"""# Cycle0109 — 2026-10-20UTC

Run `{RUN}`. CheckpointUTC {NOW}. Deadline17:38:54UTC.

**No proving speed improvement measured.**

{progress.split('**No proving speed improvement measured.**',1)[1].split('[Experiment]',1)[0]}
{costs}
{historical}
Source manifest/search records and both successful results are retained with
the initial failed audit parser. No permission/network issue blocked local work;
primary PDF403 and GitHub source/commit/license cache misses remain explicit.
No bypass or external code execution. Next owner/device work is outside this
CPU-light research authority and requires its existing shared guard/heavy locks.

{next_local}
{next_owner}
{boundaries}
"""
(R/'progress'/f'{RUN}.md').write_text(dated)
finding=f"""\n## Cycle 0109 — ordered fraction-tree sites and native point mapping (2026-10-20)

Run `{RUN}`. **No proving speed improvement measured.**

{costs}
{evidence}
{sources}
{measurements}
{historical}
{next_local}
{next_owner}
{boundaries}
[Experiment](experiments/private-fraction-site-ledger-20261020/README.md),
[handoff](handoffs/20261020-private-fraction-site-ledger.md).
"""
if f'## Cycle 0109 —' not in (R/'FINDINGS.md').read_text():
    with (R/'FINDINGS.md').open('a') as f:f.write(finding)
state=f"""# ZKP efficiency explorer — durable state

Cycle0109 COMPLETE: `{RUN}`. CheckpointUTC {NOW}.
Deadline17:38:54UTC; next cycle no earlier than18:18:54UTC.
Evidence: experiments/private-fraction-site-ledger-20261020/.
Startup agenda/memory/project docs,650-record ledger/latest0108 read and
snapshotted. Prior findings/negative results preserved. Ledger now661records.

No proving speed improvement. Ordered semantic ledger covers all83/85 original
U8 columns plus one global table, both branches and N,D at every layer.
T128 private obligations6108/6036;168unmerged original-A leaf links. Not native
claim sites or minima. Fresh native pairs retained for every such terminal at
row width2^14 would cost1527/1509MiB mask payload alone; only leaves42MiB under
that conditional rule. Naive all-intermediate contract demoted. Actual new
sites/extensions/CFS/PCS/net memory/time unknown. Prior36.022MiB selected-array
result not native fit. Challenge-derived intermediates cannot just join original A.

Main2715checks/105consumers/420branch mappings/834tiny original-A links,
4lift cases; audit29703checks/834source descriptors/834links/126MSB values,
14pins/3count-preserving source mutations pass. Source interpreter uses symbolic
Ids and frozen w32/fE9/requant shifts, not captured trained exports. No native
private GKR/CFS/PCS/transcript/proof verifier. LSB rho maps to MSB reverse(rho)||b;
merge uses reverse(rho)||eta, next LSB eta||rho. Extension axes not mapped.
No mask/opening reuse, new refusal/retry or native RNG/draw change authorized.

OneCPUworker/core0/nice19;59sCPU/alarm,60sparent,512MiBAS,estimated64MiB.
Probe4.375987s/48304KiB; audit1.987379s/37176KiB. No build/GPU/dependencies.
Initial comment-boundary audit parser failure preserved, fixed audit passes.
10native LIVE queries/11records650->661; new OpenVM CUDA/revert/PCS boundary,
new older Virgo++ primary2020-10-09/revised2021-05-19; ChimeraOct16 refreshed.
No author gains reproduced; PDF403/GitHub fetch/date/license/commit limits saved.
21ranked hypotheses; top3 wholeGPU+resident1/2/4/8,DDscaling,capacityclocks.
All-elevenFZC A/B ahead of redesign. Rank7refined,rank21reversible storage added.
Handoff: handoffs/20261020-private-fraction-site-ledger.md; main/Claude reviews.

{next_local}
{next_owner}
{measurements}
{historical}
{boundaries}
"""
(R/'STATE.md').write_text(state)

cycle={'status':'COMPLETE','cycle':'0109','run_id':RUN,'checkpoint_utc':NOW,
    'new_verified_full_stack':result['full_stack'],'experiment_result':result,
    'independent_audit':audit,'source_records_appended':11,'source_ledger_count':661,
    'ranked_hypotheses':21,'next_local':next_local,'next_owner':next_owner}
(E/'cycle-result.json').write_text(json.dumps(cycle,indent=2)+'\n')
files=[p for p in E.rglob('*.py') if 'source' not in p.parts and 'startup' not in p.parts]
(E/'research-code-manifest.json').write_text(json.dumps([{'path':str(p.relative_to(E)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(files)],indent=2)+'\n')
print(json.dumps({'status':'CHECKPOINTED','run_id':RUN,'checkpoint_utc':NOW,'checks':result['checks'],'audit_checks':audit['checks']}))
