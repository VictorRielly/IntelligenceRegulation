from pathlib import Path
import json,datetime,hashlib
base=Path.cwd();ex=base/'experiments/support-scan-capability-20261029';run='20261029T025649Z-b1039010'
r=json.loads((ex/'result.json').read_text());a=json.loads((ex/'audit-result.json').read_text());now=datetime.datetime.now(datetime.timezone.utc).isoformat()
finding=f'''

## Cycle 0133 — support evidence needs actual immutable ownership (2026-10-29)

Run `{run}`; checkpoint {now}. AGENDA, durable state/findings,
all865 prior source records, latest experiment and required project direction
read; early checkpoint02:57:59UTC. Snapshots and eight native source pins in
`experiments/support-scan-capability-20261029/`. **No native proving speedup
measured.** Only research outside runtime written; no native build/GPU/model
execution, dependency install, Git, external write/message or escalation.

The source comment “every word” is an overbroad cost description: current
weights_vanish_off_support already reads only off-support words in parallel,
then runs the original dense row-major loop only to identify first refusal.
Five attention and four FFN calls occur at constructors/CS1/CS4 paths. At
D4096/F14336/Q32/KV8/head128, padD4096/F16384/H32, T128, only three FFN
padding regions are read: 25,165,824logicalB/block/check (24MiB), not the
243,277,824B padded i8 payload. Attention reads0weightbytes. A32layer extra
sweep is805,306,368logicalB. Existing optimization already avoids89.66% of
payload reads, but34,818row visits/61,440inner support metadata tests remain.
These are source counts, not actualDRAM/time/capacity/proof improvements.
Streaming CacheBlocks::fit_the_shape already checks geometry, not all blocks.
Static alternative/nested sites do not establish actual call multiplicity.

Synthetic immutable-owner/same-support reuse passes **23,112checks**, across
32fixtures and11,040single-byte mutations. Independent dense reference uses
forward logical-head mapping, not the inverse predicate of the candidate.
9,014negative-control checks include correctly accepted differential cases;
they are not native refusal counts. Width/hidden/tokens/f_e/DD, malformed
length/table, exp order, act[128], sourcealias, first refusal order and an
equal-length/equal-cardinality changed head permutation are covered. A
caller-supplied shape-only certificate with changed padded bytes demonstrably
accepts invalid data. Python fields are forgeable: this models a contract,
not an unforgeable capability or a Rust correctness proof. Native messages,
all arithmetic/RNG/transcript/PCS/receipts/privacy remain untested.

Checking:6.332390s/18,228KiBRSS; seed202610290133; one pinnedCPU0 nice19
CoreUltra9 185Hworker, CPU40s/alarm45s/AS256MiB/estimate64MiB. Independent
source/cost audit201checks PASS,0.008458s/15,236KiB;8pins unchanged.48
abstract owner/check schedules retain firstscan of every owner. Recreating
a wrapper per entry saveszero. Actual reload/eviction creates a new owner
and cannot borrow a previous certificate's authority.

Conditional seam: private child-module SupportChecked<'a> borrows the actual
immutable BlockPublic after original validation. Its private evidence binds
role/extents/exactD/Q/Fsupport. Thread it across actual repeated witness/
sealing/protocol calls. Keep original per-entry lengths/table/DD/profile/
provenance/digest/order obligations and fallback on support mismatch. No
private masks/pads/salts/challenges/openings reused; noP3cache authority.
Baseline scans become firstscan+key/lifetime checks+unchanged otherchecks.
Complete ceiling N/(T-C+A), with exclusive removable supportC and addedA
unknown. Prior all-loader bound does not apply to recurrence outside loading.
Falsify any byte/refusal/order/support/owner/binding/RNG/transcript/receipt/
privacy mismatch, insufficient same-owner recurrence or no enclosinggain.
Park native implementation pending clocks. [Handoff](handoffs/20261029-support-checked-borrow.md).

All49prior hypotheses preserved;7/28 refined;50support and51newSeptember
semantic debloating added. Top3 remain whole-prover GPU plus independently
verified fixed-context resident1/2/4/8;DD/fidelitycontext scaling;complete
exclusive phase/capacityclocks. New primary2609.10149 requires surviving
cumulative acyclic provenance and modular guards; its GitHub README points
to a separate Figshare artifact rather than source in that repository.
Readme caveats include synthetic models and drivers recording failures
without failing exit. No native constraint deletion or author gain reproduced.
MegaZK2026 and olderRefinedRust assessed;MTU,SumCATS,instructionwall refreshed.
Eight qualified LIVE records appended865→873; accessdate/publicationprecision/
license limitations and Cachemiss blockers retained. No sourceHEAD inferred.

At final reread decisions changed: tokenR14 soundness review accepted at
03:05UTC. Its scope does not accept private8BGPU or amend the target. D44's
installed guard and D45's classifier obligations remain. No owner work or
heavyjob duplicated; savedreports do not imply delivery/liveness.

New independently verified fullstack proofs/passes/positions0/0/0. Actual
modelcontext/accelerator none. Witness/proof/serialization/verification,
startup/prefill/fraction/latency/bytes/steady/totalrates unmeasured. No long
prefill,residentproofseries or decode. Larger workloads remain allowed and
attention can grow quadratically. Private8B>=50provedtokens/s unachieved.
NextOWNER: actual support/table/hash/witness/proof and enclosing exclusive
clocks with same-owner call incidence, then CS1/CS4/H1 and full native gates
if material. NextLOCAL: tiny finite-field backward-transfer/wrap and cumulative
acyclic-provenance controls for new semantic method before any native mapping.
No mandatory norm/range/support constraint is removed.
'''
with (base/'FINDINGS.md').open('a') as f:f.write(finding)
progress=f'''# ZKP efficiency progress

Cycle0133 complete — `{run}`, 2026-10-29 UTC.

**No native proving speedup measured.** The current validator already reads
only off-support weights. At the inspected8B shape that is24MiB per block
check, allFFN padding; attention reads0weightbytes. One extra32layer sweep
is768MiB logical reads, not measuredDRAM or elapsedtime.

The synthetic immutable-owner contract passes23,112checks across32fixtures
and11,040single-byte mutations; independent source/cost audit201checks pass.
It demonstrates why a shape-only certificate is unsafe. A checked immutable
borrow could avoid repeated support scans; every new owner still needs its
firstscan, and a new wrapper per entry saveszero. Table/refusal/provenance
checks remain. Native lifetime review and exclusive phase clocks are required.
Checking used one CPUworker,6.332390s/18,228KiBRSS; no native build/GPU/proof.

Eight LIVE primarysource records added,865→873. New September semantic
debloating, its separate artifact, MegaZK and olderRefinedRust assessed;
author performance not reproduced. All49prior hypotheses retained;51total.
Top3: wholeGPU/resident workloads,DD/fidelitycontext scaling,exclusiveclocks.

New verified fullstackproofs/passes/positions: **0/0/0**. Modelcontext/device:
**none**. Witness/proof/serialization/verification,startup/prefill/fraction,
latency/bytes,steady/totalrates: **unmeasured**. No longprefill,residentproof
series or decode. Private8B>=50provedtokens/s remains unachieved.

Ownernext: measure repeated same-owner supportchecks and enclosing fraction
before implementation. Localnext: independently test finitefield guard and
cumulative provenance obligations of the new method. No native gates removed.
R14 soundness acceptance at03:05 does not change private8BGPU target.

[Experiment](experiments/support-scan-capability-20261029/README.md) ·
[Handoff](handoffs/20261029-support-checked-borrow.md) ·
[Dated report](progress/{run}.md).
Research-only writes outside runtime. Reports do not imply message delivery
or supervisorliveness. CheckpointUTC:{now}.
'''
(base/'PROGRESS.md').write_text(progress)
dated=f'''# Cycle0133 progress — {run}

Started2026-10-29T02:56:49UTC; checkpoint{now}; deadline03:16:49UTC.
Next cycle no earlier03:56:49UTC. One bounded cycle only.

{finding.split('## Cycle 0133',1)[1].split(chr(10),1)[1]}

Historical diagnostic only, not rerun or reverified: non-DD8B T128/L32,
one16threadCPU pass,GPUoff,total478.737s=0.267370positions/s. prove_run
393.785s includes witness98.348s/load17.595s; seal84.824s overlaps, so these
are not additive exclusiveclocks. Receipt922,711,264B; freshverify42.709s
plus load13.681s. Isolatedserialization,startupfraction and steadyslope
remain unknown. This is not an accepted private8BGPU throughputresult.

Reproduction: `python3 run.py` and `python3 audit.py` in
`experiments/support-scan-capability-20261029/`; seed202610290133.
Commands, source/artifactpins, completeproofclocknulls, sourcequeries and
qualified source records retained there. Experiment README has full baseline,
eliminatedwork,addedcosts,prerequisites,ceiling and falsification conditions.

Ranked queue retains all49 prior items; only7/28 refined and50/51 added.
1. Whole-prover GPU plus fixed-context verified resident1/2/4/8 workloads:
   highest recurring scope; native owner, fit/privacy/sourcepins and shared
   locks required; full steady slope and totalworkload clocks still absent.
2. DD/fidelity contextscaling: preserve T128 measurednull; largerT has
   different quadratic attention and count/capacity obligations. No kernel
   forecast or profile/precision change accepted here.
3. Complete exclusive phase/capacity clocks: prerequisite for rational
   optimizationranking; telemetry must preserve control flow/secret privacy.
50. Tested publicsupport evidence: moderate typedborrow APIcost, conditional
   24MiB per repeatedblockcheck; actual removedcriticalpath unknown.
51. New semanticcheckremoval: high nativeIR/protocol integration cost; first
   validate tinyfield guards,original acceptedwitnessset and cumulative
   acyclicproof evidence. No nativecheck removed or code run.

Primarysources searched: sounddebloating(arxiv2609.10149,Sep9),itsGithub
README andFigshareartifact(Sep10),MegaZK(ICS2026README),RefinedRust(June2024),
MTU(Jul2025/revOct2025),instructionwall(Aug13,2026),SumCATS(DATE2026).
Repo history/license/release requests with Cachemiss retained; no author
speed reproduced and no implementationcommit established. Metadata-license
classification is distinct from code/dependencylicense review.
'''
(base/'progress'/f'{run}.md').write_text(dated)
state=f'''# ZKP efficiency explorer — durable state

Cycle0133 COMPLETE: `{run}`.
Start2026-10-29 02:56:49UTC; checkpoint{now}.
Deadline03:16:49UTC. Nextcycle no earlier03:56:49UTC.

No native proving speedup measured. Current weights_vanish_off_support
already reads only off-support entries, not every weight as its comment
suggests. At inspected8B D4096/F14336/Q32/KV8/head128,padF16384,T128:
24MiB/blockcheck, allthreeFFNpaddingregions;attention0weightreads.
Oneextra32layersweep768MiBlogicalreads,notDRAM/time/capacity improvement.
34,818rows/61,440inner metadata tests remain. Static sites are not runtime
call counts; streaming fit_the_shape already checks geometry only.

Synthetic same-owner/same-support contract passes23,112checks,32fixtures,
11,040singlebytemutations.9,014negativecontrolchecks include accepted
differentials,notnative refusals. Independent dense forwardheadmap oracle.
Caller-supplied shapeonly support certificate with changedbytes is unsafe.
Python fields are forgeable;not a Rust securitycapability. Native design is
a private borrowed checkedview of actualimmutableBlockPublic, firstcheck
retained,alllength/table/DD/profile/provenance/digest/order checks still live.
Fallback on support mismatch. Newowner/reload retains firstscan;wrapper
rebuilt perevent saveszero. No masks/openings reused;noP3cache authority.

Checking6.332390s/18,228KiB; independent source/cost audit201checks,
0.008458s/15,236KiB. Seed202610290133,oneCPU0nice19CoreUltra9 185Hthread,
CPU40s/alarm45s/AS256MiB/estimated64MiB. Eightnativepins unchanged.
Native exactmessages/arithmetic/RNG/transcript/PCS/receipts/privacy untested.

All49prior hypotheses retained;7/28refined;50support and51semanticdebloating
added. Top3 whole-proverGPU+verifiedfixed-context resident1/2/4/8;
DD/fidelitycontextscaling;completeexclusivephase/capacityclocks.
EightLIVEprimarysources appended865→873. NewSeptember2609.10149 with
cumulativeacyclicprovenance/modularguards; actualartifact separateFigshare.
MegaZK2026 and olderRefinedRust assessed; knownMTU/SumCATS/instructionwall
refreshed. No author gains/code reproduced; Cachemisses/license/date/commit
limits recorded. TokenR14 soundnessreview accepted03:05UTC on finalreread;
no private8BGPU acceptance or targetchange. D44/D45 remain.

NextOWNER: measure exclusive support/dynamictable/constructor/hash/witness/
proof/enclosing clocks and actualsameowner repeatedincidence. Only if
material,reviewtypedborrowCS1/CS4/H1semantics and run native fullgolden,
refusal,RNG/transcript,independentreceipt/privacygates under currentlocks.
No heavyjob queued;park support implementation without clocks.
NextLOCAL: inspect newpaper's finitefield backwardtransfer/wrapguards and
cumulative acyclicprovenance on tiny independently enumerated relations.
Do not delete mandatorynorm/range/support constraints or import artifacts
without code/license inspection. No protocol/profilechange authorized.

Experiment: experiments/support-scan-capability-20261029/README.md.
Handoff: handoffs/20261029-support-checked-borrow.md.
Datedreport: progress/{run}.md.

Newverifiedfullstackproofs/passes/positions0/0/0. Actualmodelcontext/device
none. Witness/proof/serialization/verification,startup/prefill/fraction,
latency/bytes and steady/totalrates unmeasured. No longprefill,residentproof
series or decode. Largerworkloads allowed;attention can growquadratically.
Private8B>=50provedtokens/s onRTX5090 or namedhighendGPU unachieved.

HistoricalCPU diagnostic only,not rerun/reverified: nonDD8B T128/L32,
one16threadCPU pass,GPUoff,total478.737s=0.267370positions/s;prove_run
393.785s includes witness98.348s/load17.595s;seal84.824s overlaps.
Receipt922,711,264B,freshverify42.709s+load13.681s. Startupfraction,
isolatedserialization and steadyslope unknown. No nativeGPUforecast.

Onlyresearch outside runtime written;no production/Git/receipts/calibration/
safety/reviewer/instruction edits,no nativebuild/GPU/install/foreignexecution/
externalwrite/message/purchase/escalation. Main/Claude reviews/integrates;
nomerge. Savedreports do not imply notificationdelivery/supervisorliveness.
'''
(base/'STATE.md').write_text(state)
projectdocs=[]
for row in json.loads((ex/'startup-manifest.json').read_text()):
 if 'zkp-efficiency' in row['path']:continue
 p=Path(row['path']);b=p.read_bytes();sha=hashlib.sha256(b).hexdigest()
 projectdocs.append(dict(path=str(p),startup_sha256=row['sha256'],current_sha256=sha,changed=sha!=row['sha256']))
 if sha!=row['sha256']:(ex/('final-'+p.name)).write_bytes(b)
(ex/'final-direction-check.json').write_text(json.dumps(projectdocs,indent=2)+'\n')
(ex/'completion.json').write_text(json.dumps(dict(run_id=run,checkpoint_utc=now,status='complete bounded cycle; target unachieved',sources=873,hypotheses=51),indent=2)+'\n')
print(now,'reports checkpointed')
