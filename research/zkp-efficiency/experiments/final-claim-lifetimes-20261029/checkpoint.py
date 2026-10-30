from pathlib import Path
import datetime,hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RUN='20261029T055649Z-74b83633'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((HERE/'result.json').read_text())
audit=json.loads((HERE/'audit-result.json').read_text())
assert result['status']==audit['status']=='PASS'
assert len(json.loads((HERE/'hypotheses.json').read_text()))==54
target={'new_completed_independently_verified_full_stack_proofs':0,'new_passes':0,
        'new_proved_positions':0,'model_context':None,'model_accelerator':None,
        'research_device':'one Intel Core Ultra9 185H CPU0 worker, nice19',
        'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,
        'startup_s':None,'initial_prefill_s':None,'startup_fraction':None,
        'proof_latency_s':None,'proof_bytes':None,'steady_state_positions_s':None,
        'total_workload_positions_s':None,'long_context_prefill':False,
        'resident_model_proof_series':False,'decode':False,'target_achieved':False,
        'target':'complete private8B >=50 proved tokens/s on RTX5090 or named high-end GPU',
        'larger_workloads_allowed':True,'attention_quadratic_growth_caveat':True}
(HERE/'target-accounting.json').write_text(json.dumps(target,indent=2)+'\n')
report=f'''# Cycle 0136 — public terminal weights, distinct private masks

Run `{RUN}`. Started2026-10-29 05:56:49UTC; deadline06:16:49UTC.
Checkpoint: {now}. **No native proving improvement measured.**

Completed the AGENDA, STATE/FINDINGS/source ledger/latest result and required
project-document reads, an early STATE checkpoint, LIVE primary search, a
bounded differential model, native source/count audit and an unapplied handoff.
Prior documents and results were saved under the experiment startup directory.
Current classifierR15 and R12b soundness work do not supply private8BGPU rates.
No owned native implementation/build lane was duplicated.

Source inspection rejects the initial main-table-final recomputation idea:
the prover already uses the returned folded `finals`. The verifier's public
`eval_mle_ext` is separate. The new tested question concerns repeated public
equality weights in `mask_eval`, while every fresh private mask pair is read
separately. SC_TAB's3A+3H sites share one full ordered tail at the same fresh
slot point. Shape enforcesDom::Tab atlog_cols; A/Hrow widths agree.

Model: **{result['checks']}checks /102fixtures /13wrong-control families PASS**.
Independent original-cube/schoolbookFp2 oracle covers small logs0..8, width
relations, full-extension/Boolean/zero-first points, fixed/flipped coordinates,
offsets, four commitment kinds and two extension families. Independent MSBfold
checks cover six SC_TAB pairs at row logs8/13/14. Raw masks, ordered synthetic
extension terminals and their bytes agree. These row sizes are not model
contexts or proved positions. Wrong controls preserve evidence against stale
private result reuse, length-only keys, wrong tail/c0/width/pair/real-imag rows,
point maps, terminal order, extension family and missing later zero extension.
No native mask/refusal/transcript/PCS/capture/privacy or complete-proof test.

Counts atN16384: Eq builds6→1, constructorFp2mul196596→32766; five Eq and
reversed-point allocations avoided. All196608 base-row reads/mul_base calls
and six U products remain. Key/dispatch/exact comparisons/point copy are added.
Point payload224B; one262144B Eq vector stays live through extension work, where
the prior per-site temporary was dead. Actual whole-prover peak delta unknown.
This is current-slot public challenge-weight reuse, not mask reuse. The
SC_TAB-only Rust adapter is generated, source-pinned and applied in memory
by the audit; it is uncompiled and unapplied to native source.

Model clock{result['elapsed_s']:.6f}s/{result['peak_rss_kib']}KiB RSS;
source/count/patch audit{audit['checks']}checks,{audit['elapsed_s']:.6f}s/
{audit['peak_rss_kib']}KiB. One nice19 pinnedCPU0 CoreUltra9 185H worker;
seed202610290136;40sCPU/45salarm/50sparent/256MiBAS/96MiBestimate.
Commands, pins, fixture dimensions and raw logs are retained. No build or GPU.

Historical R4TinyLlamaT128/L22 parent phase, reread only: SC_TAB extension
0.69s/prove_run153.072s CPU,0.55s/135.809s RTX4070Laptop-assisted. Even free
deletion of that ENTIRE phase gives≤1.004528x/1.004066x on those diagnostics.
Candidate removes only Eq preparation within the phase; mask dots and all
extension/CFS work remain. Thus demote the SC_TAB-only scope for end-to-end
impact. Those bounds cannot transfer to8B or a high-endGPU. Actual target
ceilingNpositions/(T-Cexclusive_removed+Aadded) remains unknown. Falsify on
any parity/refusal/point/order/c0/width/site/extension/RNG/transcript/PCS/receipt/
privacy mismatch, no exclusive gain, peak failure or slower enclosing proof.

Ranked queue: all52prior entries unchanged,54total.
1. Owner whole-prover named high-endGPU and independently verified fixed-context
   resident1/2/4/8 workloads. Preserve witness, fresh masks, transfers,
   serialization/drain and verification; current fit/privacy/locks prerequisite.
2. Owner DD-context/fidelity scaling after the retained T128 null result;
   longer attention can be quadratic; actual admitted profile and clocks owed.
3. Exclusive phase/capacity telemetry before assigning local kernel gains.
53. NEW tested SC_TAB public-tail weights, limited parent scope; parked pending
    exclusive clocks and native golden/refusal/privacy/receipt gates.
54. NEW detailed older subset-claim combining circuit assessment: high protocol
    and private wrapping cost; native original-input/ordered-claim incidence
    and comparison against existingPCSgrouping required. No implementation gain.

LIVE search:20retained batches;10records appended891→901. New Akita caller/
terminal tracker and book pages, refreshed StateSyncGKR October26 revision and
release1.2.1, Vega/extended-sumcheck/Thaler references, and newly detailed
2023author-thesis subset-claim method beyond cycle0109's abstract-only screen.
Virgo++ itself was already known. No author speed reproduced. Actual current
StateSync license body isBSL1.1; Akita only hasMIT/Apache repository declarations
here. Two full commit coordinates were observed in links; both diff fetches
failed, so neither is an inspected code pin. StaleAugustAkita history is not
presentHEAD freshness. Exactdates/URLs/license scopes/Cachemiss/429 records
retained. Canonical primary PDF remained accessible after its landing429.
Source text was untrusted data; no embedded instructions/scripts executed.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context/accelerator: none. Witness/proof/serialization/verification,
startup/initialprefill/fraction, latency/bytes and steady/total workload rates:
unmeasured. No longprefill, resident proof series or decode. Private8B≥50/s
onRTX5090/named high-endGPU remains unachieved. Larger workloads remain allowed.

Historical CPU8B result carried only, not rerun/reverified:T128/L32/one16-thread
CPU pass/GPUoff,total478.737s=0.267370positions/s;prove_run393.785s includes
witness98.348s and blockload17.595s. Sealing84.824s precedes prove_run and its
load27.151s/witness80.897s subtimers overlap internally. Receipt922711264B;
verify42.709s+load13.681s. Isolatedserialization/startupfraction/steady slope
unknown. These historical diagnostics are not newly counted proof tokens.

Next OWNER: Eq/row-dot/extension/enclosing clocks and actual tail incidence
before any adapter build under current shared build/heavy locks. Whole-GPU
verified resident workloads retain priority. Next LOCAL: lookup/softmax rotation;
read wide-Fp2/fused-MAC negatives, then assess three-product paired-mask dots
only if the exact current role is uncovered. Charge fresh public preparation,
all private row loads/additions, carries/reductions and mask/privacy obligations.
No heavy job queued. Main/Claude reviews/integrates; no merge.

[Experiment](../experiments/final-claim-lifetimes-20261029/README.md) ·
[Handoff](../handoffs/20261029-sc-tab-mask-tail-weights.md).
Only research outside runtime written. No production/Git/receipt/calibration/
safety/instruction/reviewer mutation; no GPU/build/install/external write/
message/purchase/escalation. Saved reports do not imply delivery or liveness.
'''
(ROOT/'progress'/f'{RUN}.md').write_text(report)
findings=ROOT/'FINDINGS.md'
old=(HERE/'startup/research__zkp-efficiency__FINDINGS.md').read_text()
assert findings.read_text()==old
entry=report.replace('# Cycle 0136 — public terminal weights, distinct private masks',
                     '## Cycle 0136 — terminal weights share public work; enclosing scope is small',1)
with findings.open('a') as f: f.write('\n\n'+entry)
progress=f'''# ZKP efficiency progress

Cycle0136 complete — `{RUN}`, 2026-10-29UTC.

**No native proving improvement found.** A source-backed CPU model shares one
public equality table across SC_TAB's six separate private mask pairs. At row
length16384, constructor multiplications fall196596→32766; private mask reads
are unchanged. Key handling and longer scratch lifetime add costs.

1,042checks/102syntheticfixtures/13wrong-control families pass. Model1.528s,
41,284KiB on one CoreUltra9 185H worker; source/count/patch audit75checks passes.
An SC_TAB-only Rust patch is saved, uncompiled/unapplied. No native/GPU run.

The retained TinyLlamaT128 GPU-assisted run spent0.55s of135.809s prove_run
in the entire affected extension phase. Even free whole-phase deletion gives
only≈0.41% speedup there; actual savings are smaller. No8B timing transfer.
Whole-prover GPU and verified resident workloads remain higher priority.

10LIVEprimary records added891→901;54ranked hypotheses retain all52prior entries.
Owner next: exclusive Eq/row-dot/extension/enclosing clocks and actual incidence.
Local next: review prior arithmetic negatives before a paired-mask dot study.

New verified full-stack proofs/passes/positions: **0/0/0**. Actual model
context/accelerator:none. Witness/proof/serialization/verification, startup/
prefill/fraction, latency/bytes, steady-state and total-workload rates:
**unmeasured**. No longprefill, resident proof series or decode. Private8B
≥50provedtokens/s remains unachieved. Larger workloads allowed; attention
can grow quadratically.

[Experiment](experiments/final-claim-lifetimes-20261029/README.md) ·
[Handoff](handoffs/20261029-sc-tab-mask-tail-weights.md) ·
[Dated report](progress/{RUN}.md).
Checkpoint:{now}. Saved reports do not imply message delivery or liveness.
'''
(ROOT/'PROGRESS.md').write_text(progress)
state=f'''# ZKP efficiency explorer — durable state

Cycle0136 COMPLETE: `{RUN}`.
Started2026-10-29 05:56:49UTC; checkpoint{now}; deadline06:16:49UTC.
Next cycle no earlier than2026-10-29 06:56:49UTC.

No native proving gain. Prover already retains main-table finals: that
recomputation hypothesis is rejected. New public-tail equality model passes
1042checks/102fixtures/13wrong-control families, independent original-cube and
MSBfoldFp2 reference. Large synthetic rows8192/16384; these are not contexts.

SC_TAB has3A+3H fresh reserved pairs, same orderedrho[0..log_cols] tail.
Cache one public point and Eq table for one extension closure; read every
distinct private pair separately. AtN16384 constructorFp2mul196596→32766,
fiveEq/reversed-point vectors removed. Unchanged196608base row reads/mul_base
calls and sixUproducts. Added key/copy/comparison/dispatch; Eq262144B stays
live during extension(), actual peak unknown. No cross-proof cache/mask reuse.

HistoricalR4TinyLlamaT128/L22,notrerun/reverified:GPU-assistedSC_TABextension
0.55s/prove_run135.809s; even free entire phase≤1.004066x. ActualEq-only
saving smaller. CPU0.69s/153.072s≤1.004528x. No8B/high-endGPU transfer.
Target ceilingNpositions/(T-Cremoved+Aadded),exclusive costs unknown.

Model1.528105s/41284KiB; source/count/patch audit75checks,0.004654s/15884KiB.
One nice19 CPU0 CoreUltra9 185H worker;40sCPU/45salarm/50sparent/256MiBAS,
96MiBestimate. No nativebuild/GPU/model/proof/privacy test. Eight native pins.
SC_TAB-only unapplied Rust patch and handoff saved; all other slots fallback.
Owner native golden/RNG/transcript/refusal/PCS/capture/privacy/receipt gates owed.

All52prior hypotheses unchanged;53public-tailweights and54older subset-claim
combining circuit added. Top3: whole-prover high-endGPU/verified resident1/2/4/8;
DD/fidelity context scaling; complete exclusive phase/capacity clocks.
20LIVEprimary batches;10sources appended891→901. StateSyncv2/v1.2.1 refreshed;
newAkita terminal ownership and detailed2023thesis claim-combining assessment.
UnderlyingVirgo++ alreadyknown. No author gains reproduced; licenses, exact
dates, observed/uninspected commits, stalehistory and fetch429/cachemiss saved.
CurrentR12b/classifierR15 work does not amend this8B research target.

Next OWNER: exclusiveEq/row-dot/extension/enclosing clocks and real tail
incidence before promotion; wholeGPUverified resident workloads first, current
shared build/heavy locks and all gates. No nativejob queued.
Next LOCAL: lookup/softmax rotation; read prior wide-Fp2/fused-MAC negatives;
assess a three-product paired-mask dot only if that exact role is uncovered.
Compare source-lowered products/additions/private loads/carries/preparation,
then independentFp2 extreme/random/tail/offset/width/extension controls.

Experiment:experiments/final-claim-lifetimes-20261029/README.md.
Handoff:handoffs/20261029-sc-tab-mask-tail-weights.md.
Datedreport:progress/{RUN}.md.

New verified full-stack proofs/passes/positions0/0/0. Actualmodelcontext/
accelerator:none. Witness/proof/serialization/verification,startup/prefill/
fraction,latency/bytes,steady/total rates:unmeasured. No longprefill,resident
proofseries,decode. Private8B>=50provedtokens/s onRTX5090/namedhigh-endGPU
unachieved. Larger workloads allowed; attention can grow quadratically.

HistoricalCPU8BT128/L32 one16threadpass,GPUoff:total478.737s=0.267370/s;
prove_run393.785s includeswitness98.348s/blockload17.595s. Sealing84.824s
precedesprove_run; itsload27.151s/witness80.897s overlap internally. Receipt
922711264B;verify42.709s+load13.681s. Notrerun/reverified; startupfraction,
isolatedserialization and steady slopeunknown. No newly counted tokens.

Onlyresearch outside runtimewritten. No production/Git/receipt/calibration/
safety/instruction/reviewer edits,build/GPU/install/externalwrite/message/
purchase/escalation. Main/Claude reviews/integrates; no merge. Savedreports
do not imply delivery or supervisorliveness. Earlystate and prior findings kept.
'''
(ROOT/'STATE.md').write_text(state)
(HERE/'commands.json').write_text(json.dumps({'prepare':['python3','experiments/final-claim-lifetimes-20261029/prepare_adapter.py'],
 'experiment':['python3','experiments/final-claim-lifetimes-20261029/run_bounded.py','probe.py'],
 'source_audit':['python3','experiments/final-claim-lifetimes-20261029/run_bounded.py','audit.py'],
 'checkpoint':['python3','experiments/final-claim-lifetimes-20261029/checkpoint.py'],
 'workdir':str(ROOT)},indent=2)+'\n')
(HERE/'completion.json').write_text(json.dumps({'status':'complete','cycle':'0136','run_id':RUN,
 'checkpoint_utc':now,'deadline_utc':'2026-10-29T06:16:49+00:00',
 'next_cycle_not_before_utc':'2026-10-29T06:56:49+00:00','new_proofs':0,'new_native_improvement':False},indent=2)+'\n')
print(json.dumps({'checkpoint':now,'findings_appended':True,'sources':901,'hypotheses':54,'native_improvement':False}))
