"""Finalize research-only durable state; no production mutations."""
from pathlib import Path
import json,datetime,hashlib,platform,os
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RUN='20261020T121854Z-ee6ad7b9';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((HERE/'result.json').read_text());validation=json.loads((HERE/'validation-result.json').read_text())
hyp=json.loads((ROOT/'experiments/lookup-helper-census-20261020/hypotheses.json').read_text())
r=hyp[6]
r.update(title='REFINED tested mixed-height private U8 forest: per-column rebuild versus cached-depth recomputation',
 baseline='Frozen R9 normwindow32/fE9/cap32: 8B T128 U8 H data420.25/390.25MiB nonDD/DD; full fraction forest3170.016/2954.016MiB. Different from newer LOW fidelity counts.',
 eliminated_work='Only hypothetical gross original U8 helper data/processing under a new reviewed protocol. None removed from native proving in this experiment.',
 added_costs='One-column reconstruction nearly2x fraction-tree internal work and2x leaf generations. Top12 cache6.676/6.677x internal work,8.663x leaves. All ordered A links,one histogram,refusals,GKR folds,masks/CFS/PCS,transfers and launches remain.',
 prerequisites='Owner actual fullGPU phase/capacity clocks; explicit layer-consumer and new masked/versioned GKR protocol. Keep one global histogram committed before challenges and every original ordered A column. DD privacy gate and current soundness/fidelity constraints remain.',
 integration_cost='High protocol redesign. Research plan/serve interface only; no Rust patch ready. Higher-priority all-eleven FZC compiler A/B remains ahead.',
 exactness='959 probechecks/116 tiny cases/9controls; independent5641 auditchecks,1500 costmutations,1000 tinycolumn services,30 mixedheight rootchecks,5 unchanged sourcepins. F65537 oracle only; no native GKR/refusal/CFS/receipt test.',
 privacy_soundness='Every root/intermediate stays private; root-only binding fails wrong-site permutation. Actual GKR mask/claim/PCS sites unknown,not replaced by semanticroot counts. No reused masks/openings/inverse cache across attempts. Preserve R9N-r9-a/b,D32/D33/D34 scopes.',
 compatibility='FrozenR9 shape lookup/helper/site counts,layout::lookups_at,argument::helper_sum/SC_TAB,protocol::u8_denominator_inverses/write_h/Hcommit. CPU integer ledger only.',
 end_to_end_ceiling='No measured speedup or net capacity claim. T128 onecolumn arithmetic upper128.006MiB; top12 upper84.766MiB. Excludes A/H/M,GKR scratch and masks/PCS. Unknown affected exclusive fractionf; even free deletion<=1/(1-f). No GPU rate projection.',
 falsification='Reject any ordered binding,histogram,denominator-refusal,exactness,privacy or soundness mismatch; or added complete-proof work exceeds avoided cost. Roots-only memory plan already has18.663x construction work atT128 and is not free.')
(HERE/'hypotheses.json').write_text(json.dumps(hyp,indent=2)+'\n')
report=f'''# ZKP efficiency progress

Cycle 0104 complete — `{RUN}` — 2026-10-20 UTC.

**No proving speed improvement measured.** A bounded schedule census found
that the frozen R9 8B T128 fraction forest can be serviced one column at a
time with about128MiB arithmetic storage, versus2.88–3.10GiB materialized,
at nearly2x fraction-tree construction work and2x leaf generation. A smaller
85MiB top-cache plan needs about6.68x internal work. These are partial
arithmetic counts; proof scratch, masks, commitments and A/model storage are
unpriced. No net memory saving or actual proof fit is established.

Completed:959 probechecks/116 tiny cases/9controls; independent5641 audit
checks/1500 costmutations/1000 tiny column services/30 mixed-height roots;
five native-source pins unchanged. Wrong-site permutation preserves a root,
so ordered leaf binding cannot be omitted. One thread, probe0.066202s /
16,284KiB; audit0.165969s /14,980KiB. Initial singleton reporting failure and
correction retained. Eleven LIVE queries, eight primary records including
newly screened older Virgo; no author performance reproduced. Fetch errors,
date/license limits and unverified short-commit metadata are explicit.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context/device: none. New witness/proof/serialization/verification,
startup duration/fraction and steady/total rates: **unmeasured**. No long
prefill, resident passes or decode. Private8B>=50 proved tokens/s on5090/
another named high-end GPU remains unachieved. Larger workloads allowed;
attention can grow quadratically. Census excludes the newer fidelity LOW
profile; R9/DD privacy and current D32/D33/D34 scopes remain.

Next local: per-column checkpoint/rebuild frontier under an explicit GKR
layer-consumer contract. Next owner: fullGPU phase/capacity clocks, verified
fixed-context resident1/2/4/8 passes, all-eleven FZC compiler A/B. Blocked/
unknown: private GKR/CFS/PCS design and fullGPU measurements.

[Experiment](experiments/lookup-forest-schedules-20261020/README.md),
[handoff](handoffs/20261020-lookup-forest-schedules.md),
[dated report](progress/{RUN}.md).
Saved reports do not establish external message delivery.
'''
(ROOT/'PROGRESS.md').write_text(report)
(ROOT/'progress'/f'{RUN}.md').write_text(report+f'\nRecorded at {now}.\n')
findings=f'''
## Cycle 0104 — private fraction-forest lifetime and recomputation (2026-10-20)

Run `{RUN}`. **No proving speed improvement measured.** Refined rank7:
can a mixed-height column forest avoid the prior materialized-storage negative
without unpriced recomputation? Ten frozenR9 w32/fE9 publicfixtures keep one
global histogram and all original ordered U8 columns; not newer fidelityLOW.
Read ownerR11 ACTIVATION_COST: its sizes are counts and time is a model;
it is not a new soundness/privacy admission. Larger workloads allowed.

8BT128 nonDD/DD fullfraction forest3170.016/2954.016MiB, helperdata420.25/
390.25MiB. Initial root reduction followed by one-column full rebuild gives
128.006MiB arithmetic upper bound, nearly2x internalnode construction and
2x leaves. Retain top12 depths:84.766MiB,6.676/6.677x internalwork and8.663x
leaves. Roots-only:64.005MiB but18.663x work and20.663x leaves; reject any
description of this as free streaming. Top16:390.016MiB,2.870/2.885x work.
At COUNTED ONLY T512, onecolumn512.006MiB before scratch; top12 gives277.266MiB
at9.275/8.884x work. No trainedT512 profile/proof admitted. Symbolic arrays
were never allocated. Work ratios compare one fraction-tree construction,
not nativeH/proof elapsed; memory excludesA/model,otherH/M,GKRfolds/scratch,
masks/CFS/PCS,encoding/trees,transfers/launches. Actual netbytes/time/fit unknown.

plan(sizes,cached_depth) counts retained top caches, one service array and
DFS frontier. serve independently reduces blocks for each requested lower
layer; tiny testharness retains output copies solely for differential checks.
Semantic obligations84 private rootpairs/83 orderedA links T128 are not84
publicmessages/83requiredPCSopenings. Actual new GKRmask/claim/PCS sites remain
null until a reviewed construction exists. Original denominator refusals and
one histogram binding cannot be removed; weak-root and unmaskedroot negatives
stand. Any future scheme preserves exact attention+FFN and current privacy.

Probe959checks,116 tinycases,9controls; audit5641checks,1500 alteredcosts,
1000 tinycolumn services,30mixedheight direct-inverse rootchecks,5 unchanged
sourcepins. FieldF65537,notnativeFp2. A wrongsite permutation preserves the
root but changes orderedleaf binding. Controls include omittedmultiplicity,
duplicatedhistogram,zeromultiplicity denominator,degenerate(0,0),freshchallenge
inversecache and fixedfloor stacking. Initial singletonconstruction has0
internalnodes, causing reportingratio divisionbyzero; corrected tonull with
source/failure retained. No production defect inferred. OneCPUthread/core0,
nice19;59sCPU/alarm,60sparent,512MiBAS,64MiBestimate. Probe0.066202s/16284KiB;
audit0.165969s/14980KiB. No nativeRust/GKR/transcript/refusal/PCS/privacy test.

ElevenLIVEqueries/eightprimaryrecords appended605->613. Newlyscreenedolder
Virgo2019/1482:received2019-12-24,revision2020-07-16,CCBYpaper; maskedGKR+
terminaldelegation is notnativecompatibility. RefreshedChimeraJuly7/October16,
StateSyncOctober10,LogUp-GKR2023/2025,SparrowOctober11/approval14,2024.
Newzorchissue362July2 reports fixedfloorstack runtimeRAM regression (author
only). SP1issue112June17/closureJune18 contains corrections to stalefusion/
paddingdiagnoses; do notcopy its earlyclaims. RepoREADME statesApache2;
license/raw/source/commit/releasefetches failed as recorded. Short53d8dfb
reportedmetadata only,no inspectedSHA or verifiedlatestrelease. No external
code executed or authorperformance reproduced. Otherqueuedcategories retained:
GPU NTT/commitments,sumcheck/GKR,lookups/softmax,memory,amortization,
quantization/arithmetic,composition; highestownerpriorities unchanged.

Baseline: recurring U8H helpers. Hypothetical removedwork: grossU8H data/
processing only. Addedwork: all fractionconstruction/recomputation/leaflinks,
oneglobalhistogram,refusals,freshmask/CFS/PCS/reduction/transfer/launchcosts.
Unknown exclusive affected fractionf gives free-deletion ceiling<=1/(1-f);
bytes/workcounts do not supply f or GPUrate. Falsify on exactness/binding/
refusal/privacy/soundness failure or newwholeproofcost exceeding avoidedwork.
Seam remains frozenR9shape/lookups/hplanes/claimsites,layout::lookups_at,
argument::helper_sum/SC_TAB andprotocol::u8_denominator_inverses/write_h/Hcommit.
Research-onlyinterface; noRustpatch ready. Main/Claude reviews and integrates.

CarriedCPU nonDD8BT128/L32,one16threadpass,GPUoff total478.737s=0.267370/s;
prove_run393.785s includeswitness98.348s/load17.595s;seal84.824s overlaps.
Receipt922711264B;freshverify42.709+load13.681s,recheck34.395+load10.739s.
Notrerun/reverified;startup/isolatedserialization/steady slopeunknown. New
independentlyverified fullstackproofs/passes/positions0/0/0;actualcontext/
device none; allnewproofclocks/startupfraction/steady-totalratesunmeasured.
No longprefill/residentpasses/decode. Private8B>=50/s remainsunachieved;
attentioncan growquadratically. R9N-r9-a/b,DDprivacygate,D32fidelity,D33's
narrowfrozenR7scope andD34 remain. Onlyresearch excludingruntimewritten.

[Experiment](experiments/lookup-forest-schedules-20261020/README.md),
[handoff](handoffs/20261020-lookup-forest-schedules.md). Nextlocal: per-column
checkpoint/rebuild frontier under explicit layerconsumer contract, before
choosingstorage or protocol. Owner: fullGPU phase/capacityclocks,verified
resident1/2/4/8 andall-elevenFZCcompilerA/B under sharedlocks. No build/GPU/
install/Git/externalwrites/messages/purchases/escalation. Reports do not
establish externaldelivery.
'''
with (ROOT/'FINDINGS.md').open('a') as f:f.write(findings)
state=f'''# ZKP efficiency explorer — durable state

Cycle 0104 COMPLETE: `{RUN}`.
Checkpoint: {now}. Deadline:2026-10-20 12:38:54 UTC.
Next cycle no earlier than2026-10-20 13:18:54 UTC.
Evidence:experiments/lookup-forest-schedules-20261020/.
Prior durable memory and required documents preserved under startup/.
AGENDA/currenttarget/currentownerstatus/R11cost and latestcensus read.

No proving speed improvement measured. FrozenR9w32/fE9 8BT128 nonDD/DD:
full fractionforest3170.016/2954.016MiB versusU8helperdata420.25/390.25MiB.
Onecolumnrebuild128.006MiB arithmetic upper at nearly2x fractiontree
construction/2xleaves. Top12cache84.766MiB at6.676/6.677xwork/8.663xleaves;
rootsonly64.005MiB at18.663xwork. Ratios are not nativeH/proof time. At
COUNTEDONLYT512 onecolumn512.006MiB,top12cache277.266MiB at9.275/8.884xwork.
NoT512profile/proof admission. ExcludesA/model,otherH/M,GKRfold/scratch,
masks/CFS/PCS,encodedtrees/transfers/launches; no netbytes/actualfit claim.
All private roots/cache values remain private,one originalglobalhistogram,
83orderedA linksT128 (85T512). Exactnewmask/claim/PCS sites unknown/null.
Wrongsite permutationpreservesfractionroot; orderedbindingindispensable.
Prior unmaskedroot/weakleaf/frozenfuturepair and othernegativefindings stand.

959probechecks/116tinycases/9controls;5641auditchecks/1500costmutations/
1000tinyservices/30mixedheight roots/5unchangedsourcepins. SyntheticF65537,
notnativeGKR/refusal/CFS/receipt/privacy. OneCPUthread/core0,nice19;
probe0.066202s/16284KiB,audit0.165969s/14980KiB;59sCPU/alarm,60sparent,
512MiBAS,64MiBestimate. Initialsingletonworkratio divisionbyzero corrected
tonull; failingcode/log/commandretained. No nativebuild orGPU.

Twenty ranked hypotheses retained. Topthree: completehighendGPUphasecoverage
and independentlyverified fixedcontextresident1/2/4/8; DDlargercontext
scaling afterT128null; actualcapacity/exclusiveandenclosing clocks. All-eleven
FZCcompilerA/B remains ahead ofprotocolredesign. Rank7 materiallyrefined
with the lifetime/work tradeoff. ElevenLIVEqueries/eightprimaryrecords
605->613; newolderVirgo andzorchfloorwidthnegative,otherrefreshesexplicit.
ChimeraOctober16revisionverified; noauthorperformance reproduced. Dates/
license/fetchlimits retained.53d8dfb isuninspectedshortmetadata;no latestrelease.

Next LOCAL: bounded per-column checkpoint/rebuild frontier under an explicit
layer-consumer contract: include complete served arrays,fold/scratch liveness
and regeneration work; independent tiny topology and wrongsite/multiplicity/
zero-denominator controls. Do not equate layer service with whole maskedGKR.
Next OWNER: completeGPU phase/capacityclocks and verifiedfixedcontextresident
1/2/4/8;all-elevenFZCcompilerA/B first. Main/Claude reviews/handoffs;
handoff:handoffs/20261020-lookup-forest-schedules.md. No merge here.

CarriedCPU nonDD8BT128/L32 one16threadpass GPUoff:total478.737s=0.267370/s;
prove_run393.785s encloseswitness98.348/load17.595;seal84.824soverlaps.
Receipt922711264B;freshverify42.709+load13.681,recheck34.395+load10.739s.
Notrerun/reverified;startupfraction/steady slope/isolatedserializationunknown.
New independentlyverifiedfullstackproofs/passes/positions0/0/0;actualmodel
context/device none. Allnewwitness/proof/serialization/verifyclocks,startup/
fraction,steady/totalrates UNMEASURED. No longprefill,residentpass ordecode.
Private8B>=50/s on5090/anothernamedhighendGPU remainsunachieved. Larger
workloads allowed; attention maygrowquadratically. NewerLOWfidelityprofile
outsidefrozenR9census;R9N-r9-a/b,DDprivacygate,D32/D33/D34scopesretained.
Onlyresearch excludingruntimewritten;no production/Git/build/GPU/install/
externalwrites/messages/purchases/escalation. Reportsdo not implydelivery.
'''
(ROOT/'STATE.md').write_text(state)
hardware=json.loads((HERE/'hardware.json').read_text());hardware['cpu_model']='Intel(R) Core(TM) Ultra 9 185H';hardware['estimated_experiment_memory_MiB']=64
(HERE/'hardware.json').write_text(json.dumps(hardware,indent=2)+'\n')
manifest=[]
for name in ['schedule.py','reference.py','probe.py','validate.py','run_bounded.py','record_sources.py','checkpoint.py','README.md']:
 b=(HERE/name).read_bytes();manifest.append(dict(path=name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(HERE/'research-code-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
cycle=dict(cycle='0104',run_id=RUN,status='complete',completed_utc=now,
 result=result,validation=validation,hypotheses=len(hyp),source_records_before=605,source_records_after=613,
 next_cycle_not_before='2026-10-20T13:18:54Z',handoff='handoffs/20261020-lookup-forest-schedules.md')
(HERE/'cycle-result.json').write_text(json.dumps(cycle,indent=2)+'\n')
print(json.dumps(dict(status='checkpointed',cycle='0104',probe_checks=result['checks'],audit_checks=validation['checks'],hypotheses=len(hyp))))
