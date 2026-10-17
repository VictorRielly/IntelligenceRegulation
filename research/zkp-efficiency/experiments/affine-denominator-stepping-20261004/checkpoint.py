"""Finalize cycle0034 reports; only research-directory files are written."""
import datetime,hashlib,json
from pathlib import Path

HERE=Path(__file__).resolve().parent; ROOT=HERE.parent.parent
RUN='20261004T185034Z-0cf2c35e'

def main():
    result=json.loads((HERE/'result.json').read_text())
    assert result['status']=='pass' and result['counts']['prior_baseline_census_checks']==48
    assert result['control_count']==11
    checkpoint=datetime.datetime.now(datetime.timezone.utc).isoformat()
    payload=json.loads((HERE/'source-records.json').read_text())
    # Preserve exact prior prefixes; never overwrite a prior finding/source.
    oldsources=(HERE/'snapshots/research__zkp-efficiency__sources.jsonl').read_bytes()
    oldfindings=(HERE/'snapshots/research__zkp-efficiency__FINDINGS.md').read_bytes()
    assert (ROOT/'sources.jsonl').read_bytes().startswith(oldsources)
    assert (ROOT/'FINDINGS.md').read_bytes().startswith(oldfindings)
    existing=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
    ids={x.get('id') for x in existing}
    records=[]
    for r in payload['records']:
        r['recorded_at_utc']=checkpoint
        if r['id'] not in ids:records.append(r)
    # Tool reported an error from a clicked commit but not its full URL.
    for issue in payload['access_issues']:
        if issue['url'].endswith('/commit/99d3591'):
            issue.update(url='https://github.com/microsoft/vega-prover/pull/147',action='click commit link82 (99d3591); full requested URL was not returned')
    (HERE/'source-records.json').write_text(json.dumps(payload,indent=2)+'\n')
    (HERE/'search-log.json').write_text(json.dumps({'access_date':'2026-10-04','run_id':RUN,'method':'native LIVE web search',
                                                  'queries':payload['queries'],'access_issues':payload['access_issues'],
                                                  'records':len(records),'no_bypass':True,'foreign_code_executed':False},indent=2)+'\n')
    with (ROOT/'sources.jsonl').open('a') as f:
        for r in records:f.write(json.dumps(r,sort_keys=True)+'\n')
    elapsed=result['elapsed_seconds'];rss=result['peak_rss_kib']
    metrics='Accepted independently verified complete private8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; passes:0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag and pipeline drain are unmeasured. No long-context prefill, resident-model passes or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are allowed; attention can grow quadratically with context. Fresh masks, privacy and full coverage remain required.'
    next_action='Next LOCAL: chunked wide Fp2 dot-product accumulation against independent integer-mod-p reference; prove maximum-value batch bounds and test carry/overflow/zero/ragged/flush failures, charging carry/reduction/scratch costs. OWNER: isolate native denominator/helper/bracket/weight/fold/recovery and both witness/down clocks, then shared-lock masked/frozen/fresh independent-verifier complete-stack A/B. No heavy job is queued.'
    report=f'''# ZKP efficiency progress

Cycle0034 — `{RUN}`, checkpoint{checkpoint}.

**No proving speed improvement measured. Row stepping is demoted.** 128 synthetic complete-clause fixtures/768 schedules pass independent original-cube/final-MLE checks and11 negative controls. Final{elapsed:.6f}s/{rss:,}KiB RSS; one pinned low-priority CPU thread,59s/512MiB caps. Forty-eight accounting checks match the previous baseline.

Compared with the compiled plan, illustrated n23/ls3/padded/release stepping removes1.272% of counted scan/fold base multiplications but increases API operations1.325%, adds per-row setup and480B logical scratch per part. Full Fp2 products stay. Counts/synthetic validation establish no native runtime or complete-proof ceiling; GPU/compiler/spill and enclosing costs are unknown.

Five LIVE primary source records saved: newly assessed older Vega with September2026 revision and July implementation bounds, plus qualified SumCATS/NVIDIA/hardware-locality refreshes. Exact dates/licenses/fetch failures retained; no remote commit diff or performance reproduced. [Experiment](experiments/affine-denominator-stepping-20261004/README.md) · [Owner disposition](handoffs/20261004-affine-denominator-stepping.md). Native seam: helper_sum/SC_SZC definition and grouped row/sample loops; immutable shared closure currently lacks per-part row-state hooks. No native patch/build/GPU/merge.

{metrics}

{next_action}

Reports saved locally do not establish external notification delivery.
'''
    (ROOT/'PROGRESS.md').write_text(report)
    (ROOT/'progress').mkdir(exist_ok=True)
    (ROOT/'progress'/f'{RUN}.md').write_text(report)
    finding=f'''\n\n## Cycle0034 — row-local denominators pass algebra but worsen API count (2026-10-04)

Run `{RUN}`, checkpoint{checkpoint}. AGENDA, durable state/findings/all182 prior source records/latest experiment results and required project memory read/snapshotted; early STATE checkpoint saved before the experiment. Research-only writes excluding runtime. One-thread bounded CPU work; no native build/GPU/install/Git/production/foreign-code execution/external write/message action.

128 source-derived complete SC_SZC fixtures/768 release/debug chunk schedules pass1,152 independent original-cube samples against6,912 candidate samples,20,736 direct-MLE finals,5,376 row-counter checks,48 previous-baseline census entries,160 general lookup rows and3,798 direct denominators. Eleven algebra/lifecycle negative controls fire.1,098 group recoveries and630 zero-factor fallbacks occurred. Final{elapsed:.6f}s/{rss:,}KiB RSS, seed2026100434, pinned nice19 Core Ultra9 185H thread;59s wall/CPU/512MiB AS caps. n0..3,ls2/3,padded/unpadded,odd/even helpers,full/base/zero/Boolean values,chunks1/3/7,explicit-debug/release sample1; general empty/multiple/alias/zero/negative/non-unit terms. Zero denominators checked only algebraically. Native honest witnesses, extensions, mask/RNG/transcript/PCS/refusal/privacy parity unexecuted.

Baseline cycle0033 compiled Unit/Neg/Scale plan reevaluates affine denominators per bracket. Candidate prepares CURRENT-row origin and slope, advancing over EVERY sample including skipped1 and resetting per row/round/chunk. It preserves all helper products, clauses, padded domains and source indices; no masks or relation weakened. Differential source patch:stepping.py RowPlan/SteppedTerms and row_rounds.py hooks. Shared copied scheduler is qualified by the separate tuple-field expanded original-cube oracle. Initial passing result/source retained; final run added the48 cross-cycle count checks.

NEW negative: illustrative n23/ls3/padded/release removes83,886,072 mul_base but adds482,344,902 Fp2 adds, removes293,601,252 subs and leaves2,478,833,399 full multiplies unchanged. Lowered base-mul count falls1.271860%; total API operations INCREASE1.324854%. Debug explicitly sampling1 still increasesAPI0.292969%; unpadded n20/ls2 release increases2.425874%. Setup is two affine dispatch passes per row/round,480B logical origin/slope per part,566,230,980 logical reads/754,974,630 writes in the illustrated release census. Accesses may be registers/cache, not measured DRAM. Native allocation/compiler/occupancy/spill/phase costs unknown. Row stepping demoted; reduced multiplication count alone does not support integration.

Expected complete ceilingN/(T-Cold_den+Crow_setup+Cstep+Cscratch+Cdispatch) unmeasured because accepted8B T/denominator clocks are missing. Tables/interpolation/native Eq/data folds and weight products are charged unchanged; setupEqs/inverses/recovery/reduction/masks/witness/PCS/transfers/serialization/verification excluded. Falsify any complete original/native sample/final/helper/order/support/pad/refusal/RNG/transcript/extension/receipt/privacy mismatch, memory failure or enclosing regression. No runtime ceiling follows from1.27% counted arithmetic.

Ranked queue:1 owner GPU SC_SZC+recurring witness (largest measured remaining single-block scope; high CUDA/memory/native privacy integration);2 owner exact full-K split-int16 down (packing/i64/requant/workspace and isolated share unknown);3 compiled denominators pending native compiler/phase gates (low/moderate plan/dispatch costs);4 NEW exact delayed modular reduction in terminal Fp2 weighted sums (prove >u128 accumulation bounds and charge wider carries/flush/reduction/scratch before any speed claim);5 symbolic Eq/public causal-mask descriptors (memory benefit with full index/support/terminal gates, causal predicate includes padded heads);6 fresh fixed-context resident complete-pass startup/slope/lag/drain/verify sweep (20ms recurring/new position falsifies50/s for that schedule);7 row stepping demoted on API/scratch tradeoff;8 Vega/binary-field/SWIRL/Fold-DCS architecture filter (high PCS/PIOP/state/privacy/whole-proof soundness migration). Detailed prerequisites/costs/exactness/falsification in experiment README. Previous fusion/compiler/small-phase/LRU/hash-prefix/reconstruction/privacy negatives preserved.

Five LIVE qualified records appended: new older Vega paper received2025-11-14/revised2026-09-05; Vega MIT/history/conformance/July15 bounds; SumCATS setup regression refresh; NVIDIA2026-07-15 binary-field scope; June15 matched-hardware locality. Vega's cached July15 history is not verified currentHEAD; Feb25 delayed-reduction commit only exposed, fetch failed. No remote commit diff inspected. Current main complete MIT license inspected for Vega; SumCATS nested README MIT excerpt does not establish additions/third-party scope. API/code/license/commit Cache miss/Internal Error URLs/actions retained. No author performance reproduced or downloaded code executed; binary-field rates are not Goldilocks2 or private full-model rates. Vega rerandomizable preprocessing adds no mask/opening reuse permission.

Native seam: owner's argument.rs894/1724/1782 helper/definition/bracket; grouped.rs86/110 part/row/sample loops; GroupPoly at argument.rs76 immutableFn+Send+Sync. Any row adapter must create scratch separately per part; shared mutable closure state is unsuitable. No production patch or merge. [Owner disposition](handoffs/20261004-affine-denominator-stepping.md) · [experiment](experiments/affine-denominator-stepping-20261004/README.md).

{metrics}

Historical synthetic12block125M/T512 RTX4070Laptop diagnostic remains408.609226swall/318.22combinedrunprover/12.15inprocessverify/484107456B/fresh independentfalse. LaterCLI lacks terminal result after recordedreboot; stale state is not liveness. No new model-scale/GPU clock. {next_action}

Rotation next:arithmetic/reduction -> proof composition -> GPU NTT/commitments -> lookup/softmax -> sumcheck/GKR -> memory traffic/batching. Reports saved locally do not establish delivery.\n'''
    if f'## Cycle0034 —' not in (ROOT/'FINDINGS.md').read_text():
        with (ROOT/'FINDINGS.md').open('a') as f:f.write(finding)
    state=f'''# ZKP efficiency explorer — durable state

Cycle0034 COMPLETE: `{RUN}`, checkpoint{checkpoint}; deadline2026-10-04T19:10:34Z. Next cycle no earlier than2026-10-04T19:50:34Z. Read AGENDA every cycle. Prior memory/source prefixes, current project memory/reports/native pins retained in experiments/affine-denominator-stepping-20261004/snapshots/. Research-only excluding runtime; one-thread <=59s/512MiB; no native/build/GPU/install/Git/foreign-code/production/external-message action.

{metrics}

Row-local denominator stepping passes128 complete-clause fixtures/768 schedules,1,152 independent original-cube expected samples/6,912 candidates,20,736 direct-MLE finals,5,376 row counters,48 prior baseline census entries,160 general rows/3,798 denominators and11 controls.1,098 recoveries/630 zero-factor fallbacks. Final{elapsed:.6f}s/{rss:,}KiB RSS, seed2026100434, one pinned nice19 Core Ultra9 185H CPU thread. Native mask/RNG/transcript/extension/PCS/refusal/privacy unexecuted.

DEMOTED cost tradeoff: against compiled plan, illustrative n23/ls3/padded/release removes1.271860% counted scan/fold base multiplications but increasesAPI1.324854%, leaves fullFp2 products and adds480B logical scratch per part/row setup. Exact counts/accesses inresult/README. Counts are neither instructions/time nor end-to-end ceilings. Native compiler/phase/occupancy/spill/enclosing gain unknown; ceilingN/(T-Cold_den+Crow_setup+Cstep+Cscratch+Cdispatch) unmeasured. All old negatives and initial passing result/source preserved.

Ranked:1ownerGPU SC_SZC+witness;2exact full-K int16down;3compiled denominators pendingnative;4NEW wide delayed reduction;5symbolicEq/publiccausalmask;6fresh resident complete-pass startup/slope/drain/verify;7demotedrowstepping;8Vega/binaryfield/SWIRL/Fold-DCSarchitecture. Costs/prerequisites/falsification inREADME/FINDINGS. FiveLIVEprimaryrecords appended,{len(existing)+len(records)}total. Newly assessed olderVega revisedSep5 2026;MIT currentmain inspected. No remotecommitdiff/authorperformance reproduced; code/commit/license/packageerrors retained. All fresh masks/privacy/state/whole-proof soundness obligations remain.

{next_action}

Native row seamargument.rs894/1724/1782 andgrouped.rs86/110,immutableGroupPoly76 needs per-part scratchadapter; noRustpatch. Nextarithmeticseamfield.rs55/100/158+weighted groupedaccumulator. Handoff handoffs/20261004-affine-denominator-stepping.md; PROGRESS/progress/{RUN}.md saved. Historicalsynthetic12block125M/T5124070Laptop remains408.609226wall/318.22combinedrunprover/12.15inprocessverify/484107456B/freshindependentfalse. LaterCLI lacks terminalresult; stale state notliveness. No externaldeliveryrecord claimed.
'''
    (ROOT/'STATE.md').write_text(state)
    (HERE/'checkpoint-meta.json').write_text(json.dumps({'run_id':RUN,'checkpoint_utc':checkpoint,'completed':True,'source_records_appended':len(records),
                                                       'prior_source_prefix_sha256':hashlib.sha256(oldsources).hexdigest(),
                                                       'prior_findings_prefix_sha256':hashlib.sha256(oldfindings).hexdigest()},indent=2)+'\n')
    print(json.dumps({'completed':True,'checkpoint_utc':checkpoint,'new_source_records':len(records),'source_records_total':len(existing)+len(records)}))

if __name__=='__main__':main()
