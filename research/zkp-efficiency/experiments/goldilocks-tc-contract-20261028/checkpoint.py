"""Write authorized research reports and append-only durable ledgers."""
from pathlib import Path
import datetime
import json

HERE=Path(__file__).resolve().parent;BASE=HERE.parents[1]
RUN='20261028T235649Z-d1bc0725';EXP=HERE.name
d=json.loads((HERE/'result.json').read_text());a=json.loads((HERE/'audit-result.json').read_text())
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
new=json.loads((HERE/'sources-cycle.json').read_text())
prior=(HERE/'startup/sources.jsonl').read_bytes();ledger=(BASE/'sources.jsonl').read_bytes()
assert ledger.startswith(prior)
if ledger==prior:
    assert prior.endswith(b'\n')
    with (BASE/'sources.jsonl').open('a') as f:
        for row in new:f.write(json.dumps(row,sort_keys=True)+'\n')
else:
    assert [json.loads(x) for x in ledger[len(prior):].splitlines()]==new
assert len((BASE/'sources.jsonl').read_text().splitlines())==849

metrics='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. Witness, proof, serialization,
verification, startup/initial-prefill clocks, startup fraction, proof latency
and bytes, steady-state and total-workload rates: **unmeasured**. No long
prefill, resident-model proof series or decode ran. Larger workloads remain
allowed; attention can grow quadratically. Private 8B at >=50 proved tokens/s
on RTX 5090 or a named high-end GPU remains unachieved.'''

progress=f'''# ZKP efficiency progress

Cycle 0130 complete — `{RUN}`, 2026-10-28/29 UTC.

**No proving speedup measured.** The stock Tensor Core NTT driver selects a
<=62-bit reducer, so it cannot replace the native Goldilocks NTT. A general
multiplier helper works in isolation; replacing it alone still fails the
unsupported lazy butterfly. Canonical dot16 inputs need 132 bits, so dropping
top carries also fails. These are porting negatives, not upstream defects.

A new carry-aware reducer contract and matrix scaling/order bridge pass
**{d['checks']:,} synthetic checks**, including 12,441 products, 18 radix2
fixtures, 35 dot16 fixtures, four matrix16 fixtures and 54 controls. Checking
took {d['elapsed_seconds']:.6f} s / {d['max_rss_kib']:,} KiB RSS on one Core Ultra 9
185H CPU thread. The CUDA sketch is uncompiled/unapplied. No GPU or native
proof ran. Separate source/provenance audit: {a['checks']} checks, seven native
pins unchanged. No native transcript, PCS, receipt or privacy acceptance.

Nine primary-source records appended (849 total); all 44 prior hypotheses
retained, two refined and two added. Current releases, the new Tensor NTT
source and older Montgomery arithmetic were screened; fetch limits retained.

{metrics}

Next owner action: exclusive NTT/enclosing clocks before a native adapter and
its full gates, then verified resident workloads. Next local action: inspect
R12b's recurring public checkpoint/table validation and test an immutable,
fully parameter-bound public derivation against mutation controls. Owner's
17–18 s/load note is Shieldstral3B; it is not an 8B timing. No heavy job queued.

[Experiment](experiments/{EXP}/README.md) ·
[Handoff](handoffs/20261028-goldilocks-tc-contract.md) ·
[Dated report](progress/{RUN}.md).
Research outside runtime only; main/Claude reviews/integrates, no merge.
Saved reports do not establish delivery or supervisor liveness.

Checkpoint UTC: {now}.
'''
(BASE/'PROGRESS.md').write_text(progress)

detail=f'''# Cycle 0130 — Goldilocks Tensor Core arithmetic contract

Run `{RUN}`. Started 2026-10-28 23:56:49 UTC;
deadline 2026-10-29 00:16:49 UTC. Checkpoint {now}.

Completed current AGENDA, STATE, FINDINGS, all840 prior source records,
latest cycle0129 results, project CLAUDE/START_HERE/MVP/target/decisions and
active coordination reads; full startup snapshots and early STATE retained.
No owner lane or researcher duplicated. Current R12b/R-C2 scope and D44
guard-swap window acknowledged; they do not supply private8B GPU throughput.

**Result: no native improvement measured.** Supplied Tensor NTT driver at
immutable `6f407daa8a4cef96331511ae86b922b520d7aa33` selects friendly
reduction. Its template says64 while actual test modulus is61bits. Both
friendly constructors reject Goldilocks. General fixed-multiplier equations
agree with bigint on12,441 pairs; this does not establish a64bit fullNTT.
Unsupported lazy2N bypass fails even at0/0/1. Canonical P-1 dot16 needs132bits
and topcarry15; u128 truncation and omitted intermediate carry controls fail.
These are invalid-port controls, not an upstream bug assertion.

Locally authored adapter: eight overlappingu32 t words, fixed-width carry
packing into lo/hi/top, native-form reduce128, then subtract top<<32 since
2^128=-2^32. Source matrix scale is removed with fixed inverseEPS=2^32-1.
Four16point matrix fixtures map source bit-reversed row exponents to natural
DFT outputs. Source-derived dot16 bound2,138,022,000<2^31; same bound formula
at32exceeds signed32 and needs a fresh design. No MMA lane/transpose execution.

Final model {d['checks']} checks / {d['elapsed_seconds']:.6f}s / {d['max_rss_kib']}KiBRSS;
18n2..64radix2 fixtures,35dot16,4matrix16,54negative controls plus5guard cases.
Independent bigint products/direct original-inputDFTs/dots, not candidate
arithmetic in the reference. Both locally authored. Seed202610280130;
one pinned nice19 CoreUltra9 185H worker,64MiB estimate/256MiBAS/40sCPU/45salarm.
Four adaptive versions retained, no repeated benchmark samples. Source audit
{a['checks']}checks/{a['elapsed_seconds']:.6f}s/{a['max_rss_kib']}KiBRSS; seven native
pins unchanged. Model/audit clocks are checking only. Commands, hashes,
dimensions, references and terminal exit0 records are in the experiment.

Baseline: current native Goldilocks radix2 row NTT/encoder. Removed native
work: zero. Candidate removes only a generic product from its own top-carry
model. Added costs: eight carry/pack steps, reduce128/subtraction/fixed-scale
product,8digit packing,64MMA/matrix,transpose,preprocessing and unknown
register/shared/scratch/launch costs. The general scalar helper needs2high+
1low products/16Btwiddle parameters versus native1high+1low/8B; no replacement
recommendation. Inverse/coset/hidingpad/chunk/opening semantics remain.

End-to-end ceiling: exclusive affected fractionf is unknown; even free entire
NTT deletion<=1/(1-f), before added costs. No numeric8BGPU forecast. Falsify
on carry/canonical/root/order/inverse/coset/q>n/ragged/pad/refusal/RNG/transcript/
PCS/receipt/privacy mismatch, absent incidence or enclosing/capacity regression.

Ranked queue (all44prior retained;46total):
1. Owner whole-prover high-endGPU plus independently verified fixed-context
   resident1/2/4/8. Fresh masks, recurring witness/transfers/serialization and
   drain/verification mandatory; actualfit/profile/currentlocks prerequisite.
   Unknown ceiling; failedfit/coverage or ratebelowtarget rejects schedule.
2. Owner DD/fidelity context scaling. PriorT128 null result retained; admitted
   geometry/refusal/whole-workload gates needed. Unknown rate until measured.
3. Complete exclusive phase/capacity clocks. Nested construction/destruction,
   errors/cleanup and profiler overhead count; incomplete scopes or negligible
   removable critical-path time reject a causal saving.
44. Refined tested stockTensorNTT compatibility negative; no guard bypass.
45. New tested carry/scaling contract; owner clocks and full native gates
   prerequisite to larger adapter. Sketch uncompiled and unapplied.
46. New R12b public tied-table residency question. Checkpoint::open streams
   full public7.7GB then rederive authenticates131072x3072BF16 rows. Owner note
   17–18s/load is unreproduced3B evidence, not8B cost/startup fraction. Only a
   fully bound immutable public derivation could be amortized; parameters,
   model/profile/rotation/refusals and consumed bytes must remain bound.
   Path/mtime/size/inode caches alone cannot suffice. Actualcapacity,copy and
   validationcosts unknown. Stale/mutated acceptance or regression falsifies.

Nine LIVE primary records appended840->849; two search batches and14retained
followups. New immutable TensorNTT modular/NTT headers, supplied driver,
current history/commit. Apache2.0 SPDX inspected;406/339numbered header lines
retained. Rendered-text hashes are not rawGitblob hashes. Immutable arithmetic
helper and ancillary headers/directories Cachemiss; main helper unpinned.
Paper DOI inaccessible. Older Bos/Montgomery2017 new to this ledger; ePrint
receivedOct31 versus Cambridge onlineOct25 are different events; PDF403,
Cambridge openCachemiss retained. ICICLEv4, GPU-NTT noreleases, Plonky3v0.9rc2,
known2026sumcheck and olderGoldilocksroottrick refreshed. Release year omitted
by primary page remains unknown. No author timing or foreign code executed.
Rotation retains GPUcommitments,sumcheck/GKR,lookup/softmax,memorytraffic,
batching/amortization,quantization/arithmetic and proofcomposition.

Interface/sketch: `experiments/{EXP}/candidate-reducer.cuh.txt`.
Future separate reduction_type plus native k_ntt_p1/p2 and
cuda.rs::encode_rows_view_zk[_gather]. Complete inverse/coset/pad/root/output,
compiler/register/memory,masked/transcript/nextRNG/refusal/PCS/privacy and fresh
independent receipts remain outstanding. Owner measures first under current
shared heavy/build locks. No full native patch or heavy job queued.
[Handoff](../handoffs/20261028-goldilocks-tc-contract.md).

{metrics}

Historical diagnostic carried only, not rerun/reverified: nonDD8B T128/L32,
one16thread CPU pass,GPUoff; total478.737s=0.267370positions/s.
prove_run393.785s includes witness98.348s/load17.595s; seal84.824s overlaps.
Receipt922711264B; freshverify42.709s+load13.681s. Isolated serialization,
startup fraction and steady slope unknown. Not a new counted proof or8BGPU
privacy/performance acceptance.

Next LOCAL: inspect prior public-loader/cache findings and R12b derivation
inputs/refusal order; bounded synthetic mutable-public-file and changed-parameter
controls versus a fullybound immutable-derived object. No further carry-only
refinements before native phase evidence. Next OWNER: exclusiveNTT/enclosing
clocks, adapter only ifmaterial, then full gates and verified resident1/2/4/8.
Onlyresearchoutside runtime written. No production/Git/receipt/calibration/
instruction/reviewer/gate mutation,build,GPU,install,externalwrite/message,
purchase or escalation. Main/Claude reviews/integrates; no merge. Saved reports
do not establish delivery or liveness.
'''
(BASE/'progress'/f'{RUN}.md').write_text(detail)

finding=f'''\n\n## Cycle 0130 — Goldilocks Tensor NTT port boundary; no proving gain

Run `{RUN}`; checkpoint {now}.
Required memory/project/latest-result reads and early STATE retained in
`experiments/{EXP}/startup/`. No owner lane duplicated.

Stock supplied Tensor Core NTT driver selects a friendly <=62bit reducer;
template64 does not mean a64bit prime (its test modulus is61bits). Immutable
commit6f407daa8a4cef96331511ae86b922b520d7aa33 inspected. General multiplier
arithmetic passes12441pairs; swapping it into lazy2N butterfly still fails.
Canonical P-1 dot16 requires132bits/top15; truncating128 or intermediate
carries fails. Unsupported-port negatives, not upstream defect claims.

New authored carry/scaling contract: eight overlappingu32words pack by
explicitcarry into lo/hi/top, reduce128, subtract top<<32 (2^128=-2^32),
then multiplyEPS to remove matrix2^128factor. Fourmatrix16 fixtures explicitly
map bit-reversed row exponents to natural outputs. Dot16 combinedword bound
2138022000<2^31; sameformulaat32overflows signed32, so no casualradix doubling.
No GPU M M A/WMMA/lane/transposition/compiler evidence.

Model {d['checks']}synthetic checks,18n2..64radix2fixtures,35dot16,4matrix16,
54controlinstances plus5guards. Independent bigint/original-input DFT/dot
references; bothauthoredlocally. Seed202610280130; final {d['elapsed_seconds']:.6f}s /
{d['max_rss_kib']}KiBRSS ononepinnednice19CoreUltra9 185Hworker,40sCPU/45salarm,
256MiBAS/64MiBestimate. Fouradaptiveversionsretained,no benchmark repetitions.
Separate source/provenance audit {a['checks']}checks/{a['elapsed_seconds']:.6f}s/
{a['max_rss_kib']}KiB; sevennativepinsunchanged. No nativebuild/execution/proof.

Baseline specialized nativeGoldilocksNTT. Nativeworkremoved:none. Research
topcarry product simplification only. Addedcarry/pack/reduction/scaling,
8digits/64MMApermatrix/transposes/precompute/register/shared/scratch costs
unknown. Generalhelperaddsonehighproduct/doublestwiddleparameterbytes versus
native; no substitutionrecommendation. IfexclusiveNTTfunknown,freedeletion
ceiling<=1/(1-f)beforecosts. Falsifyonanyfield/carry/layout/root/inverse/coset/
q>n/pad/refusal/RNG/transcript/PCS/receipt/privacy mismatch,absentincidence or
enclosingverifiedworkload/capacityregression. No numeric8BGPUforecast.

All44priorhypotheses retained;1/44refined,45/46added. Top3unchanged:
wholeproverGPU/verifiedfixedcontextresident1/2/4/8; DD/fidelitycontextscaling;
completeexclusivephase/capacityclocks. NewR12bpublicderivedtable residency
lead followsowner17-18s/load7.7GBShieldstral3Bnote,not8Bmeasurement. Inspect
priorloaderworkthen testfullyboundimmutablepublicobject against mutation/
staleparameter controls; path/size/mtime/inode cachealone insufficient.
CurrentR12b/RC2fixscopeandD44guardwindowdo notamendresearchtarget.

Nineprimaryrecordsappended840->849;2LIVEsearchbatches+14retainedfollowups.
Immutablemodular/NTT406/339numberedrenderedlines,notrawGitblobhashes;
Apache2.0SPDXinspected. GeneralhelperdependencyimmutableCachemiss retained;
currentmainhelperunpin,DOIinaccessible. NewlyreadolderBos/Montgomery2017
abstract/searchexcerpt; PDF403/CambridgeCachemiss limits. CurrentICICLE,
GPU-NTTnoreleases,Plonky3release,familiar2026sumcheck/olderroottrickrefreshes
qualified; omittedreleaseyearsunknown. Noauthorperformancereproduced.

Seam: separateGoldilocksreduction_type andnativekernels.cu k_ntt_p1/p2 via
cuda.rs::encode_rows_view_zk[_gather]. Researchcandidate-reducer.cuh.txt
uncompiled/unapplied. OwnerexclusiveNTT/enclosingclocksfirst; ifmaterial,
native/devicegolden/masked/nextRNG/refusal/PCS/privacy andindependentfull
receiptgatesundersharedlocks. Noheavyjobqueued. Handoff:
`handoffs/20261028-goldilocks-tc-contract.md`.

{metrics}

HistoricalCPUdiagnosticcarriedonlywithscopeindatedreport. Onlyresearch
outsideruntimewritten; no production/Git/reviewer/instruction/receipt/
calibration/gatemutation,build/GPU/install/externalmessagesorwrites/purchase/
escalation. Main/Claude reviewsandintegrates,no merge. Savedreportsnotdelivery.
'''
old=(HERE/'startup/FINDINGS.md').read_bytes();current=(BASE/'FINDINGS.md').read_bytes()
assert current.startswith(old)
if current==old:
    with (BASE/'FINDINGS.md').open('a') as f:f.write(finding)
else:assert '## Cycle 0130' in current[len(old):].decode()

(BASE/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle 0130 COMPLETE: `{RUN}`.
Started 2026-10-28 23:56:49 UTC; deadline 2026-10-29 00:16:49 UTC.
Next cycle no earlier than 2026-10-29 00:56:49 UTC.
Checkpoint {now}.
Prior memory,840sources/44hypotheses/latestcycle0129results and required
project documents preserved in `experiments/{EXP}/startup/`.

No native proving gain. Stock Tensor NTTdriver usesfriendly<=62bit reduction;
template64's actual testmodulus61bit. Generalmultiplierpassalone doesnot
makegeneral64NTT. Unsupportedlazy2Nbypassand128bitdottruncationfail; canonical
P-1dot16needs132bits/top15. Sourceguardpreventsunsupporteduse,notupstreambug.

New carry/scalingcontract passes{d['checks']}checks:12441products,18n2..64radix2,
35dot16,4matrix16,54controlinstancesplus5guards. Explicitu32carrypack;
reduce128 then gl_sub(top<<32), finalEPSunscale. Sourcebitreverse rowmapping
checked againstoriginal-inputDFT. Dot16tbound2138022000<2^31; sameformulaat32
exceeds signed32. No lane/MMA/WMMA/transposition/nativecompileevidence.

Model{d['elapsed_seconds']:.6f}s/{d['max_rss_kib']}KiBRSS; audit{a['checks']}checks/
{a['elapsed_seconds']:.6f}s/{a['max_rss_kib']}KiB. Onepinnednice19CoreUltra9 185H
worker;40sCPU/45salarm,256MiBAS,64MiBestimate. Fouradaptiveversions/codehashes/
commands retained; no benchmarkrepetitions. Sevennativepinsunchanged.
Sketchuncompiled/unapplied. Fullnativepad/inverse/coset/q>n/chunk/root/order,
maskedRNG/transcript/PCS/refusal/receipt/privacy gates remain outstanding.

All44priorhypotheses retained,46total;1/44refined,45/46added. Top3unchanged:
wholeproverGPU/verifiedresidentworkloads; DD/fidelitycontextscaling;
completeexclusivephase/capacityclocks. Nineprimaryrecordsappended,849total;
2LIVEsearchbatches+14retainedfollowups. Immutable6f407daa8a4cef96331511ae86b922b520d7aa33
modular/NTTheaders/driverselectedsectionsinspected. Renderedtext hashesnot
rawGitblobs. Apache2SPDXinspected. ImmutablearithmetichelperCachemiss;main
helperunpin. DOIinaccessible,olderMontgomeryPDF403/CambridgeCachemiss retained.
Currentreleases/knownsumcheck/olderroottechniquerefreshed. Noauthorbenchmark
orforeigncodeexecution. CurrentD44guardwindowrecognized,noheavyjobhere.

Next LOCAL: readpreviouspublic-loader/cachefindings andR12b
tied_tables/derive.rs inputs/refusalorder; boundedsyntheticmutablepublicfile
andchangedparameter controls for fullyboundimmutablepublicderivedobject.
Owner7.7GB/17-18sloadnote isShieldstral3B,not8Bcost/startupfraction. No path/
mtime/size/inode cachealone; privateweights/masks/openings notassumedreusable.
No morecarry-onlyrefinementsbefore exclusiveNTT/enclosingphase measurements.
Next OWNER: exclusiveNTT/wholeproofclocks; adapterifmaterialwithnativegolden/
masked/nextRNG/refusal/PCS/privacy/independentreceiptsunderactualsharedlocks,
thenverifiedfixedcontextresident1/2/4/8. Noheavyjobqueued.
Handoff `handoffs/20261028-goldilocks-tc-contract.md`.

Newindependentlyverifiedfullstackproofs/passes/positions0/0/0. Modelcontext/
acceleratornone. Witness/proof/serialization/verification/startup/prefill,
startupfraction,latency/bytes,steady/totalratesunmeasured. Nolongprefill,
residentproofseriesordecode. Largerworkloadsallowed;attentioncanbequadratic.
Private8B>=50provedtokens/sRTX5090/anothernamedhighendGPUremainsunachieved.

Historicaldiagnosticonly,notrerun/reverified:nonDD8BT128/L32,one16threadCPU
pass,GPUoff,total478.737s=0.267370positions/s.prove_run393.785sincludes
witness98.348s/load17.595s;seal84.824soverlaps.Receipt922711264B;
freshverify42.709s+load13.681s.Startupfraction,isolatedserialization,
steadyslopeunknown. NoGPUspeed/privacyacceptancefromthisCPUdiagnostic.

Onlyresearchoutsideruntimewritten.Noproduction/Git/reviewer/instruction/
receipt/calibration/gatemutation,build,GPU,install,externalwrite/message,
purchaseorescalation.Main/Claude reviews/integrates;nomerge.Savedreports
donotestablishdeliveryorsupervisorliveness.
''')
print(json.dumps(dict(checkpoint_utc=now,sources=849,hypotheses=46,cycle='0130',reports=['STATE.md','PROGRESS.md','progress/'+RUN+'.md','FINDINGS.md'])))
