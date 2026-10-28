from pathlib import Path
import json,datetime,hashlib

HERE=Path(__file__).resolve().parent
BASE=HERE.parent.parent
RUN='20261020T181854Z-27090273'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((HERE/'result.json').read_text())
audit=json.loads((HERE/'validation-result.json').read_text())
forest=json.loads((HERE/'forest-result.json').read_text())
sources=json.loads((HERE/'source-records.json').read_text())
hyp=json.loads((HERE/'hypotheses.json').read_text())
assert result['status']==audit['status']==forest['status']=='PASS'
assert len(hyp)==22 and [x['rank'] for x in hyp]==list(range(1,23))
ledger_path=BASE/'sources.jsonl'
old=[json.loads(s) for s in ledger_path.read_text().splitlines()]
existing={(r.get('run_id'),r.get('url')) for r in old}
new=[r for r in sources if (r['run_id'],r['url']) not in existing]
with ledger_path.open('a') as f:
    for r in new:f.write(json.dumps(r,sort_keys=True)+'\n')
count=len(old)+len(new)
assert count==670
full=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,
          witness_s=None,proof_s=None,serialization_s=None,verification_s=None,
          startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None)
status_text='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, repeated resident-model pass or decode was performed. Larger workloads
remain allowed; attention can grow quadratically with context. The complete
private8B >=50 proved positions/s target on RTX5090 or another named high-endGPU
remains unachieved.
'''
historical='''Carried historical diagnostic, not rerun or independently reverified here:
non-DD8B T128,L32,one16-threadCPU pass,GPUoff; total478.737s =
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verify42.709s
+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown. This is not a high-endGPU result.
'''
next_local='''Next local: test a bounded reversible-subtree tile plus immutable frontier
under the prior36.022MiB selected-array budget, against an immutable native-field
tree and original ordered layer consumer. Charge tile rebuilds/frontier/prefix/
inactive fold tails and all source rereads. Check whether the existing fresh
per-attempt U8 reciprocal cache can remove last-layer inversion scratch without
uncounted source/lookup work. This is untested. Preserve full-column and naive
per-intermediate-mask negatives; do not claim a new private protocol.
'''
owner='''Owner next: actual GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DDcontext scaling and all-elevenFZC
compiler A/B under shared build/heavy locks. Keep fresh masking; count only
completed independently verified full-stack positions. No owner job launched here.
'''
findings='''
## Cycle0110 — reversible fraction tree: exact, full-column capacity negative (2026-10-20)

Run `20261020T181854Z-27090273`. **No proving speed improvement measured.**
Baseline: frozenR9 U8 helper data420.25/390.25MiB(nonDD/DD) at8B T128;
prior prospective adaptive consumer36.022216796875MiB selected arrays and
6.028/6.054x source leaves. No production work removed. Original-A, global
histogram, private recursion, fresh masks/CFS/PCS and native phase costs remain.

Parent N=NL*DR+NR*DL,D=DL*DR. Preserve right child, reconstruct DL=D/DR,
NL=(N-NR*DL)/DR. The tested natural-order strided layout is different from
OpenVM's bit-reversed coalesced layout. A consumer must not fold retained tree
storage because future layers need its right children. Both N,D and the original
ordered child MLEs match independent immutable native-Fp2 tree arithmetic.

For n leaves: build3(n-1)Fp2mults/(n-1)adds; individual restoration3(n-1)mults,
(n-1)subtracts/(n-1)inversions; batch restoration6(n-1)-3log2(n)mults,
(n-1)subtracts/log2(n)inversions, maxn/2 prefixE elements. No inverse-output or
copied-denominator array. At2^21leaves retained tree64MiB versus immutable
nearly128MiB, but batch-prefix16MiB and separate consumer capacity must be added.
q0..4 selected peaks128.0234375/96.015625/80.01171875/80/80MiB. All exceed prior
36.022MiB; even64MiB tree alone does. This demotes the whole-column plan at that
budget, not reversible subtrees generally. Assumes prefix release/backing reuse;
sourceowners/caches/histogram/masks/CFS/PCS/allocator/driver/transfer costs excluded.

Symbolic sequential-column8B T128:84columns including one global table;
source leaves51937536/48398592(nonDD/DD), avoids261128448/244613376 generations
versus the prior adaptive model. Build155812356/145195524 Fp2mults; batch
restoration311620005/290386395mults,1569/1551inversions,51937452/48398508subtracts.
Counts only, no instructions/time. Existing256-entry per-attempt inverse caching
is baseline work, not a new saving. Native array/profile/full-proof benefit
unknown. Unknown exclusive affected fraction f gives free-deletion ceiling
<=1/(1-f) before added costs. Falsify on binding/field/refusal/order drift,
omitted capacity/no real capacity cliff, or slower complete workload.

Main2838checks/42trees/306unmasked consumers/768control instances; sizes2..256,
looked affine U8, table multiplicities including zero and full-extension leaves;
zero/one/non-base challenges. Two build/restore cycles per tree without reread.
Zero denominator at every tested placement refuses even for numerator0.
Root-preserving swaps change original ordered MLEs; wrongright/parent/aliasedfold
controls fail the reference. These are research controls, not native refusals,
privacy gates, numeric Ids, masks, GKR/CFS/PCS/transcript or saved-proof verification.

Independent5745checks/21fixtures/174layers/348MSBMLEs,16pins,2090capacity events,
30rejected capacity shortcuts and10symbolic forest profiles. Its own tuple-field
convolution/Fermat inverse/immutable forward tree/MSBfold and allocation events
compute expected values. Earlier passing audit before forest addition retained.
Probe28.352250s/17768KiB; accounting0.162193s/11460KiB; audit0.642078s/15808KiB.
OneCPUworker/core0/nice19,59sCPU/alarm,512MiBAS; probe/audit60sparent. Estimated
64MiB probe/audit/32MiB accounting; IntelCoreUltra9 185H/WSL2. Seed20261020110.
No build/GPU/dependency installation/downloadedcode execution; no failed experiment.

15native LIVE queries/9source records appended661->670. OpenVM docs/CUDA show
inverse-based reversal; MITbody inspected, main date/commit alignment blocked by
history/API fetch failures. v2.0.1 phase peaks/pinned pools refreshed, year/full
commit unverified. ICICLE fullSHA6c77775961b0e4dc2be359feec1ac11536c18043 is
version-only, not a kernel diff; MITbody inspected, date year unverified.
ChimeraOct16 and sumcheck2026/587 refreshed. Newly directly assessed older
Twist/Shout(2025-01-22,revised2026-10-17) supplies one-hot lookup alternative,
not a tiny-table/private-PCS fit. Jolt MITbody read, algorithm commit uninspected.
Prior DeepThought2024/325 composition screen refreshed, not called new.
New author issue71 retracts contention-inflated GKR ranking and preserves a
byte-exact scan regression. No author performance reproduced. Exact URLs,
dates/licenses/SHA/scope and PDF403/GitHub fetch/IEEErobot blockers retained.

22ranked hypotheses maintained; top3 ownerGPU+verified resident1/2/4/8,DDscaling,
complete capacity/exclusive clocks. All-elevenFZC A/B remains ahead of protocol
redesign. Rank21 refined by exact reconstruction and selected-budget negative;
rank22 adds one-hot/increments screen. Rotation covers NTT/commitments,
batching/amortization,sumcheck/GKR,memory,lookup and composition. Next rotate
quantization/arithmetic underD32 and private input-consistency/composition.

'''+status_text+'\n'+historical+'\n'+next_local+'\n'+owner+'''
Only research excluding runtime written; no production/reviewer/instruction/
Git/GPU/install/externalwrites/messages/purchases/escalation/merge. R9N-r9-a/b,
DDprivacy gate,D32 and narrowD33/D34/D35 scopes remain. No mask/opening reuse or
changed native refusal/RNG/transcript timing authorized. Main/Claude reviews.
Saved reports do not establish external delivery or supervisor liveness.

[Experiment](experiments/reversible-fraction-tree-20261020/README.md),
[handoff](handoffs/20261020-reversible-fraction-tree.md).
'''
find_path=BASE/'FINDINGS.md'
if '## Cycle0110 —' not in find_path.read_text():
    with find_path.open('a') as f:f.write(findings)
progress='''# ZKP efficiency progress

Cycle0110 complete — `20261020T181854Z-27090273` — 2026-10-20UTC.

**No proving speed improvement measured.** Reversible fraction storage recovers
both components and matches306 unmasked consumers. The full-column plan is
demoted: at2^21leaves selected peak80–128MiB, above prior36.022MiB model, before
private proof costs. It avoids source regeneration but adds batched inversion
and hundreds of millions of modeled field multiplications. No native work removed.

Main2838checks; independent5745checks/174layers/348MSBMLEs/16pins,10count profiles
and30capacity controls pass. Probe28.352s/17768KiB; audit0.642s/15808KiB;
oneCPUworker/noGPU. Exact arithmetic/synthetic storage only, no private proof.

Searched OpenVM reversible CUDA/phase-memory release, ICICLE release/source,
sumcheck, ChimeraOct16, Twist/ShoutOct17, accumulation and author contention/
scan negatives:15LIVE queries/9records. Dates/commit/license/access limits saved;
no author speed reproduced.22ranked hypotheses; top3 GPU/resident,DDscaling,
complete capacity/clocks. Full-column negative preserved; subtree variant next.

'''+status_text+'''
Next local: bounded reversible subtrees/frontier and cached leaf-reciprocal
costs; owner: verified resident1/2/4/8,DDscaling,phase/capacity clocks,FZC A/B.
No private mask/opening reuse or native refusal/transcript change authorized.

[Experiment](experiments/reversible-fraction-tree-20261020/README.md),
[handoff](handoffs/20261020-reversible-fraction-tree.md),
[dated report](progress/20261020T181854Z-27090273.md).
Research-only writes. Saved reports do not establish external delivery.
'''
(BASE/'PROGRESS.md').write_text(progress)
dated_findings=findings.replace('](experiments/','](../experiments/').replace('](handoffs/','](../handoffs/')
(BASE/'progress'/f'{RUN}.md').write_text('# Cycle0110 — '+RUN+'\n\nCheckpointUTC '+now+'.\n'+dated_findings)
state='''# ZKP efficiency explorer — durable state

Cycle0110 COMPLETE: `20261020T181854Z-27090273`. CheckpointUTC '''+now+'''.
Deadline18:38:54UTC; next cycle no earlier than19:18:54UTC.
Evidence: experiments/reversible-fraction-tree-20261020/.
Required memory/agenda/project docs and latest0109 results read/snapshotted;
661-record starting source ledger indexed; prior findings/negatives preserved.
Ledger now670records. Only research excluding runtime written.

No proving speed improvement. Exact reversible storage passes2838checks,
42trees/306unmasked consumers/768controls, two build/restore cycles. Independent
5745checks/174layers/348MSBMLEs/16pins/2090capacity events/10forest profiles pass.
Native-Fp2 synthetic2..256 leaves, not native private GKR/CFS/PCS/transcript/proof.
Probe28.352250s/17768KiB; account0.162193s/11460KiB; audit0.642078s/15808KiB.
OneCPUworker/core0/nice19;59sCPU/alarm,512MiBAS,probe/audit60sparent;
estimated64MiB or32MiB accounting. IntelCoreUltra9 185H/WSL2. No build/GPU/install.

Full-column plan DEMOTED:64MiB tree+16MiB maximum batch prefix at2^21leaves;
selected consumer peaks128.023/96.016/80.012/80/80MiB(q0..4) versus prior36.022MiB.
Source/allocator/masks/CFS/PCS excluded; no fit/time claim. Frozen8B T128 symbolic
nonDD/DD forest reduces leaf generations313065984/293011968 to51937536/48398592,
but adds311620005/290386395 recoveryFp2mults,1569/1551inversions and
51937452/48398508subtracts besides build/consumer. Natural-order strided reads;
OpenVM's bit-reversed coalescing not ported. Never fold the retained right-child
buffer. ZeroD even at numerator0 and root-preserving wrong order controls pass;
native refusal/RNG/transcript order remains untouched and unvalidated here.

15LIVEqueries/9records661->670. OpenVM inverse/revert and phase peaks,ICICLE
version-only fullcommit,ChimeraOct16,sumcheck refreshed; new direct older
Twist/Shout Jan2025/Oct17revision and author zorch71 negative assessed.
No author gain reproduced; PDF403/history/API/commit/date/IEEErobot limits saved.
22hypotheses; top3 wholeGPU+verified resident1/2/4/8,DDcontext scaling,capacity/
exclusive clocks. All-elevenFZC native A/B ahead of redesign. Rank21 tested and
demoted by capacity; rank22 one-hot/increments added. Handoff:
handoffs/20261020-reversible-fraction-tree.md; main/Claude reviews,no merge.

'''+next_local+'\n'+owner+'\n'+status_text+'\n'+historical+'''
No production/reviewer/instruction/Git/GPU/install/external writes/messages/
purchases/escalation/merge. R9N-r9-a/b,DDprivacy gate,D32,narrowD33/D34/D35 remain.
No mask/opening reuse or weaker privacy authorized. Reports do not establish
delivery or supervisor liveness.
'''
(BASE/'STATE.md').write_text(state)
cycle=dict(status='COMPLETE',cycle='0110',run_id=RUN,checkpoint_utc=now,
           experiment_result=result,independent_audit=audit,
           forest_accounting_clock={k:v for k,v in forest.items() if k!='profiles'},
           source_records_appended=9,source_ledger_count=count,ranked_hypotheses=22,
           new_verified_full_stack=full,next_local=next_local,next_owner=owner)
(HERE/'cycle-result.json').write_text(json.dumps(cycle,indent=2)+'\n')
# Manifest excludes itself, logs and bulk startup archive; those have own pins.
paths=[p for p in HERE.iterdir() if p.is_file() and p.suffix in ['.py','.json','.md'] and p.name not in ['research-code-manifest.json','checkpoint-validation.json']]
manifest=[dict(path=p.name,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(paths)]
(HERE/'research-code-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(dict(checkpoint=now,status='COMPLETE',source_records=count,hypotheses=len(hyp),manifest_files=len(manifest))))
