# Initial checkpoint writer retained as provenance. Final readable reports
# were polished afterwards; do not rerun this writer over those final reports.
import json,datetime,hashlib
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parent.parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
run='20261029T045649Z-6e004a83'
report=f'''# ZKP efficiency progress

Cycle0135 complete — `{run}`, 2026-10-29 UTC.

**No native proving improvement found.** A new split-coset encoder preserves
the tested hiding polynomial and every output column. At n16384/r4/q256 it
removes65,536forwardbutterflies but only2.3238%of countedencoderfieldmul after
addedscaling; more reads/layout costs remain. q=n increases multiplication
work. This is a conditional CUDA candidate, below whole-proverGPU work.

21,424smallchecks plus114,688geometry-matched outputchecks pass;15retained
synthetic native conformance rows agree.13wrongcontrol families caught.
Small/large checks0.610/1.181s,17,308/43,100KiBRSS,oneCoreUltra9 185HCPUworker.
Audit101checksPASS. No native/CUDA build or model run, no fresh proof verified.

Nine LIVE primary records added882->891; dates/licenses/commit-fetch limits
and blocked fulltexts retained. New older decomposition work supplies layout
cost methodology; author gains not reproduced. All51priorhypotheses preserved;
new split-coset candidate52. Main/Claude reviews/integrates; no merge.

New verified full-stack proofs/passes/positions:**0/0/0**. Actual model
context/accelerator:**none**. Witness/proof/serialization/verification,
startup/initial-prefill duration/fraction, prooflatency/bytes, steady-state and
total-workload rates:**unmeasured**. No longprefill,residentproofseries or decode.
Private8B>=50provedtokens/s remains unachieved; larger workloads allowed,
longer attention can grow quadratically. Historical CPU reports reread only.

Owner next: exclusive encoder/enclosing clocks and actual eligible incidence
before an adapter; verified whole-GPU/resident1/2/4/8 remains higherpriority.
Local next: inspect final-claim evaluation lifetimes for a sumcheck/GKR seam,
then independent orderedFp2/originalcube checks with freshpoint/pad/tail controls.

[Experiment](experiments/ntt-coset-layout-20261029/README.md) ·
[Handoff](handoffs/20261029-split-coset-hiding-rows.md) ·
[Sources](experiments/ntt-coset-layout-20261029/sources-cycle.json).
Checkpoint:{now}. Reports do not imply notification delivery or supervisor liveness.
'''
(R/'PROGRESS.md').write_text(report)
(R/'progress'/f'{run}.md').write_text(report.replace('(experiments/','(../experiments/').replace('(handoffs/','(../handoffs/'))
finding=f'''

## Cycle0135 — low-degree split cosets: exact model, modest arithmetic and scratch tradeoff (2026-10-29)

Run`{run}`; checkpoint{now}. Requiredmemory/project/latestresults read,
wholefile startup snapshots and earlySTATE retained. All882prior sourcerecords
parsed, active instructions/current measurements inspected. No ownerlane
duplicated. **No native proving improvement found.**

New question: can r shorter transforms replace the hiding encoder's expanded
forward? For N=r*n,a_s=h*omega_N^s,A_s=a_s^n, reduce g moduloX^n-A_s;
transform c[t]=(f[t]+(A_s-1)*sum_l g[t+l*n]*A_s^l)*a_s^t with rootomega_n,
store at logicalk=s+r*j. This uses lowdegree restriction, distinct from the
prior general mapped4step model. All columns of the same fresh one-proof
maskedpolynomial remain. No crossproof mask/privateevaluation cache allowed.

21,424smallchecks pass:186fixtures,n2..64,r2/4/8,q0..(r-1)n,h7/11,20,104
outputs match direct inverseDFT+separateHorner and materializedradix2;
744Lagrangepoints,15retainedsyntheticnativefullrows/digests,256columnbyte
checks across7rows/chunks1/2/3/7.13wrongcontrol families detect scale/root/
coset/fold/pad/order/highpad/truncation/duplicate/row/stride/stalechunk/private
cache mistakes;6algebrafixture refusals are not native domaincoverage.
q>n needs fullfold; minimaln8/q9 fails truncation. GeneralPythonpass does not
authorize broadeningnativeadmission; shortpath must retainfallback.

Separate independentknown sparsef/g recurrence validates all114,688outputs
at n4096/8192/16384,r4,q256,h7. These are rowNTTlengths,not modelcontexts.
Seed202610290135,onepinnednice19CoreUltra9 185HCPUworker;small0.610484s/
17,308KiBRSS,larger1.181438s/43,100KiB.40sCPU/45salarm/256MiBAS/64MiBestimate,
55sparent. Audit101checksPASS,0.005721s/18,316KiB;8source/vectorpinsunchanged,
18sourcefragmentchecks. No native/GPU/externalcode/build/model/proof run.

Countmodelguardq<=n assumes publicpowersprepared and skips absentpad terms.
Baselineinverse+compactpadscale+expandedforward intact. r4 butterflysaving4n
but netmul savingn-3q: n16384/q256672000->656384(-2.3238%),adds1278464->1147904.
Added49152coefficientreads,512padreads,48896powerreads (logicalwords,notDRAM).
Atq=n mul688128->720896(+4.7619%),negativefor broadmul-savingclaim.
Publictable generation,A_s-1,index/barrier/register/occupancy costs unmeasured.
Naiveinputscratch16640->65536words/row(+391168B);customfirstloadrequired to
avoid that growth,mayrepeat earlier scatteredloadnegative. Naturalrestore
copy costs16NlogicalB/row if needed; directstride/gather untested. At n4096
forwardcould be onebatchedP1insteadoftwo groups;at8192/16384 both keep2.
ExistingpublicpowsstorageN and processtwidddlecache already present.
Eliminatednativeworkzero;nofreshmask/commit/opening/proofphase removed.

Seam:trained-1b cuda.rs encode_rows_view_zk[_gather]/ntt_rows[_view],
kernels.cu k_ntt_p1/p2*,corePCS encode_row_zk. ActualpinnedGPUproducer already
usesindependentpad contributions; oldmainbranchedq>n finding not repeated
as newbug. Interface.md is designonly;no compiled/appliedCUDA/Rustpatch.
All originalrefusal/RNG/transcript/PCS/receipt/hiding/fidelity obligations owed.
CeilingNpositions/(T-Cremoved+Aadded);unknownexclusivef allows onlyfreeentire
affectedphase deletion1/(1-f). Operationpercentages are not time/rate.
Falsifyanyparity/refusal/lifetime/privacy failure,absenteligiblecalls or slower/
overcapacitycompleteverifiedworkload. No numeric50/sforecast.

NineLIVEprimaryrecords882->891:cuPQCcurrentfeatures/Aug28release,p<2^62
excludesGoldilocks;newolderHiFAreceivedJun26/revisedSep8/acceptedOct6,
publishedDec2025 andundatedHardcaml4step methodology;GPU-NTT2025publication
May14andcurrenthistory/license;QingmingCUDAmapped/standardcontract;
LightZKlabSep28announcement/ACM403;newzisk-zorchJul9layoutattributionissue/
closingPRCachemiss. GPU-NTTfullhistoryobservedSHAd03c5eaeadaa780d153496afcb3b6a9b79a13a63,
diff/pinnedlicenseCachemiss;mainApache2bodyinspected. Dates/licenses/commits
strictlyqualified;sourcesuntrusted/noembeddedinstructionfollowed. Author
gains notreproduced. All51priorhypothesesunchanged,candidate52added;top3
wholeGPU/verifiedfixedcontextresident1/2/4/8,DD/fidelitycontextscaling,
completeexclusivephase/capacityclocks. Testedlowerglobalrank because it is
a new useful prerequisite within localCPUauthority;ownerheavywork staysfirst.

R8/R9public CPUreports reread,no receipt rerun/reverification. Clarifiedprior
terseclockwording:proofblockload17.595s versussealingload27.151s;sealing
84.824s precedes prove_run393.785s and includes overlappingload/witness80.897
subtimers. Total478.737s=0.267370positions/s,T128/L32/one16threadCPU/GPUoff;
witnessinsideprove98.348s,receipt922711264B,verify42.709s+load13.681s.
Startupboundary/fraction,isolatedserialization andsteady slope stillunknown.
Historic CPU diagnostic doesnotestablish admittedfidelity/private8BGPUtarget.

New independentlyverifiedfullstackproofs/passes/positions0/0/0. Actualmodel
context/acceleratornone;witness/proof/serialization/verification/startup/
prefill/fraction/latency/bytes/steady/totalrates unmeasured. Nolongprefill,
residentseries ordecode. Largerworkloads allowed,attentioncan bequadratic;
completeprivate8B>=50/sunachieved. D44/D45/R14scope do notamendresearchtarget.

Ownernext:measureexclusiveinverse/prepare/forward/gather/hashandenclosing
clocks,actualincidenceandcapacity beforeadapter;then fullnative/privacygates
undersharedlocks. Noheavyjobqueued. Localnext:sumcheck/GKRfinalclaimtable
lifetimes andorderedFp2originalcube oracle,freshpoint/pad/tailcontrols.
Handoff:handoffs/20261029-split-coset-hiding-rows.md. Onlyresearchoutside
runtimewritten;no prohibitedproduction/Git/receipt/calibration/safety/
instruction/reviewer edits,build/GPU/install/externalwrite/message/purchase/
escalation. Savedreports do not implydelivery/liveness.
'''
with (R/'FINDINGS.md').open('a') as f:f.write(finding)
state=f'''# ZKP efficiency explorer — durable state

Cycle0135 COMPLETE: `{run}`.
Start2026-10-29 04:56:49UTC; checkpoint{now}.
Deadline05:16:49UTC. Next cycle no earlier than05:56:49UTC.

No native proving improvement found. New split-coset hiding-row model passes
21,424smallchecks +114,688largeroutputchecks;15retainedsyntheticnativefullrows
agree.13wrongcontrolfamilies and6algebrafixture refusals retained.
186tinyfixtures n2..64/r2/4/8/q0..(r-1)n/h7/11;744Lagrangepoints;
larger n4096/8192/16384,r4/q256. These are NTTlengths,notmodelcontexts.

Key result: use X^n=A_s on each coset; transform folded ncoefficients and
map outputj to logicalk=s+r*j. q>n needs fullpadfold or nativefallback.
Sameoneprooffreshmaskedpolynomial evaluated everywhere; no crossproofreuse.
r4 removes4nforwardbutterflies but only n-3q netfieldmul. n16384/q256:
672000->656384(-2.3238%) before publicpreparation/layout costs;49152extra
coefficientreads,512padreads,48896powerreads. q=n MOREmul(+4.7619%).
Naivescratch+391168B/row;customfirstload/gather required and may repeat
scatteredreadnegative. n>=8192 stilltwoforwardkernelgroups. Noelapsedgain.

One nice19 CPU0 CoreUltra9 185Hworker;small0.610484s/17,308KiBRSS;
larger1.181438s/43,100KiB. Each40sCPU/45salarm/256MiBAS/64MiBestimate,
parent55s. Audit101checksPASS/0.005721s/18,316KiB,8source/vectorpinsunchanged.
No nativebuild/GPU/model/proof/privacytest. Interface design only,no nativepatch.

Seam:trained-1b cuda.rs encode_rows_view_zk[_gather],ntt_rows[_view],
kernels.cu k_ntt_p1/p2*,corePCS encode_row_zk. Preservelogicalcolumns/bytes,
chunkpad offsets/duplicategathers/all guards/freshmasks/salts/openings.
CurrentpinnedGPUpadproducer additive;prioroldmainq>n negative remains.
CeilingNpositions/(T-Cremoved+Aadded),unknownexclusivecosts. Reject any
parity/refusal/lifetime/privacy mismatch or no enclosingverifiedgain.

All51priorhypotheses preservedunchanged;new52conditionalcosetsplit. Top3:
wholeproverGPU/independentlyverifiedfixedcontextresident1/2/4/8;
DD/fidelitycontextscaling;completeexclusivephase/capacityclocks.
NineLIVEprimaryrecords882->891;newolderHiFA/Hardcaml andzisk-zorch issue,
currentcuPQC/GPU-NTT/Qingming/LightZK. cuPQCp<2^62excludesGoldilocks.
Authorgainsnotreproduced;dates/licenses/commit-fetch blockers qualified.
CurrentD44/D45andR14 soundness scope do notamendthisresearchtarget.

NextOWNER:exclusiveinverse/prepare/expandedforward/gather/hash/enclosing
clocksandactualeligibleincidence/capacity beforeadapter. WholeGPU/resident
completeworkloads havehigherpriority;allcurrentsharedlocks/gates apply.
No job queued. NextLOCAL:sumcheck/GKRrotation;inspect final-claim table
lifetimes/callers for repeated immutable-table evaluations versus freshpoint
work,then smallindependentorderedFp2/originalcube oracle withpoint/pad/tail
controls. Check previous terminal/lookup negatives before choosing adapter.

Experiment: experiments/ntt-coset-layout-20261029/README.md.
Handoff: handoffs/20261029-split-coset-hiding-rows.md.
Datedreport: progress/{run}.md.

Newverifiedfullstackproofs/passes/positions0/0/0. Modelcontext/acceleratornone.
Witness/proof/serialization/verification,startup/initialprefill/fraction,
latency/bytes,steady/totalratesunmeasured. Nolongprefill,residentseries/decode.
Completeprivate8B>=50provedtokens/s on5090/namedhighendGPU unachieved.
Largerworkloadsallowed;longerattentioncan growquadratically.

HistoricalCPUdiagnostic rereadonly,notrerun/reverified:8B T128/L32,one16thread
CPU/GPUoff,total478.737s=0.267370positions/s,prove_run393.785s inclwitness
98.348s andblockload17.595s. Sealing84.824s precedesprove_run,contains
overlappingload27.151s/witness80.897s. Prior terse'sealoverlaps' applies to
its subtimers,not overlapwithprove_run. Receipt922711264B;verify42.709+load
13.681s. Startupfraction/isolatedserialization/steady slope unknown.

Onlyresearchoutsideruntimewritten;no production/Git/receipt/calibration/
safety/instruction/reviewer edits,build/GPU/install/externalwrite/message/
purchase/escalation. Main/Claude reviews/integrates;nomerge. Reportsdo not
implymessage delivery orsupervisorliveness.
'''
(R/'STATE.md').write_text(state)
(H/'completion.json').write_text(json.dumps(dict(status='complete',run_id=run,cycle='0135',checkpoint_utc=now,deadline_utc='2026-10-29T05:16:49+00:00',next_cycle_not_before_utc='2026-10-29T05:56:49+00:00',new_proofs=0,new_native_improvement=False),indent=2)+'\n')
print(json.dumps(dict(checkpoint=now,report=str(R/'progress'/f'{run}.md'))))
