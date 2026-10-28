"""Write this cycle's research reports from retained measurements."""
import datetime,json
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parent.parent
run='20261019T141854Z-0a847d64'
r=json.loads((H/'result.json').read_text());a=json.loads((H/'audit-shared-result.json').read_text());b=json.loads((H/'bench-result.json').read_text())
ranked=[
 dict(rank=1,hypothesis='Owner: whole-prover GPU D/A and completed resident-model passes',
      expected_impact='Broad recurring scope; GPU/end-to-end saving unknown, requires enclosing phase measurements.',
      prerequisites='Named device and current admitted profile; owner shared heavy locks; fixed-context 1/2/4/8 completed passes.',
      integration_cost='High: device arithmetic, lifetime/transfer/PCS and complete-proof clocks.',
      exactness='Same field, relations, degree, original folds/finals and refusal domain.',
      obligations='Fresh masks/openings per proof, no private setup reuse, independent verification and pipeline drain.',
      falsification='Enclosing regression, unresolved proof backlog, failed verification or privacy obligations.'),
 dict(rank=2,hypothesis='Owner: immutable public-setup residency',
      expected_impact='Only measured startup and recurring public work can be removed; slope/startup partition unknown.',
      prerequisites='Source-classified immutable setup and identity/lifetime binding; completed resident series.',
      integration_cost='Moderate to high; retained memory, identity checks and transfers must be charged.',
      exactness='Cache public deterministic data only; all witness/challenge/scalar material refreshes.',
      obligations='Fresh private randomness, original profile/digest checks, no additional openings.',
      falsification='Stale identity, higher peak memory, reused private material or no verified workload gain.'),
 dict(rank=3,hypothesis='New local question: typed affine pointer offsets instead of per-load public map indices',
      expected_impact='May remove some of634 logical map bytes/row while retaining shared code; no speed/DRAM forecast.',
      prerequisites='First prove raw/parameter/base address families differ by exact typed offsets; retain arbitrary scratch maps.',
      integration_cost='Small census then moderate emission/ABI changes if feasible; charge argument arithmetic and full stack.',
      exactness='Identical884 field primitives, runtime proof-local parameters,59 original tables/finals and degree4.',
      obligations='Public topology only; independent address-lineage audit, native-field differential and corrupt-map control.',
      falsification='Non-affine typed address family, hidden-value dependence, alias mismatch, no resource benefit or enclosing regression.'),
 dict(rank=4,hypothesis='Owner: D30 division dictionary and architecture comparisons',
      expected_impact='Potentially larger committed-plane/lookup scope; counted/unbuilt, no measured native improvement.',
      prerequisites='Separate profile and all D30 binding conditions, cap census and written-relation independent review.',
      integration_cost='High; layout, soundness, hiding and composition changes.',
      exactness='Exact division with every true-row dictionary slot constrained; D32 fidelity direction retained.',
      obligations='Fresh captures, rank/NL-1/blinding/joint gates, original D10 and privacy rulings.',
      falsification='Unconstrained slots, late multiplicities, cap overflow without refusal or failed proof/privacy/fidelity gates.')]
(H/'hypotheses.json').write_text(json.dumps(ranked,indent=2)+'\n')

readme=f'''# Shared native D helper templates — code-size result only

Cycle0082, `{run}`, 2026-10-19 UTC. **No speed improvement found.**
Shared public-topology helpers reduce compiled code but add index traffic;
their final shared-CPU row median is2.53% higher than the unique-group arm.
Variability prevents a runtime conclusion beyond no demonstrated gain.

`grouping.py::shared_plan/emit` normalizes19 groups of the same1,167-node
use-driven graph into10 templates. Two repeated templates serve six and five
instances. Those instances use immutable `u16` public address maps; eight
single-instance templates retain static addresses. Each row still executes
19 helper calls and884 logical field primitives:272add/209sub/331mul/72base.
Inputs remain118Fp2 endpoints,129Fp2 proof-local parameters,36canonical u64
base parameters; output five degree-four coefficients. No scheduling uses a
field value and no proof-local parameter is cached across proofs.

| Measured row scope | Scalar-call arm | Unique groups | Shared templates |
|---|---:|---:|---:|
| Reachable function code bytes |33,543|145,739|78,421|
| Static instruction lines |7,171|39,737|21,420|
| Row calls |884|19|19|
| Deepest static call-chain span, bytes |424|504|504|
| Logical requested row bytes |4,320|8,528|9,162|
| Final diagnostic row median, microseconds |3.7134|4.5428|4.6577|

Code excludes634 bytes of immutable candidate maps, which must be added for
a code-plus-map comparison. The reduction is46.19% of unique-group function
code, not a46.19% proof improvement. Scratch remains208bytes. Stack includes
return addresses, saved registers and leaf red zone below exported entry RSP;
it excludes the harness/enclosing stack and exported entry's return address.
Logical source requests are not executed spills, cache misses or DRAM bytes.
All59 original tables/folds/finals remain. Folds still add118Fp2reads,
59writes and59 each add/sub/mul outside these row clocks and byte totals.
Common planning, reduction and coefficient/message conversion also remain.

Six synthetic fixtures, two public scalar catalogs(TinyLlama1.1B andLlama3-8B),
N2/8/32, seed2026101982:780 coefficients,390 captured-Rust grid values,
78off-grid values,18 messages,354 original finals and six final relations
agree with independent Python clauses/direct-cube and captured complete Rust
D/catalog. Native field source is byte-identical to the pinned project field;
the captured catalog still has documented field/Shape/Layout substitutes.
Thirty-six zero bindings confirm value-independent runtime binding. Eight
native-path controls pass, including an emitted wrong-map entry that changes
only an initialized in-bounds parameter load. A separate1,455-check audit
replays exact template lineage, addresses, initialized crossing ownership and
assembly. Its six corrupt-source/input/output/map/bounds/dependency controls
all reject. Native source pins and carried evidence pins recheck.

The final benchmark verifies32 arbitrary synthetic canonical rows and one
parameter pack in all three arms, warms256 rows/arm and uses nine balanced
rotating triplets of8,192rows/sample. Only three of nine pairs favor shared
over unique. Final unique/shared median ratio0.975323; pair ratios span
0.8004–1.2953. These are shared-host cache-resident samples with artificial
noinline scalar adapters, not quiesced/p95, installed native sampler, whole-D,
GPU or proof measurements. `first-timing/` retains exploratory pre-control
samples separately; those are not the final pinned artifact or an A/B against
the later build. No statistical or hardware-cause claim is made.

Commands from the research directory, serially:

```bash
python3 experiments/dzc-shared-templates-20261019/run.py --native-field
python3 experiments/dzc-shared-templates-20261019/audit_shared.py
python3 experiments/dzc-shared-templates-20261019/bench.py
python3 experiments/dzc-shared-templates-20261019/validate.py
```

Main{r['wall_seconds']:.6f}s including compiler{r['compile_seconds']:.6f}s;
main/compiler RSS{r['rss_kib']:,}/{r['compiler_rss_kib']:,}KiB. Audit
{a['wall_seconds']:.6f}s/{a['rss_kib']:,}KiB. Benchmark including harness
compiler{b['wall_seconds']:.6f}s; child{b['child_wall_seconds']:.6f}s;
max child/compiler RSS{b['child_peak_rss_kib']:,}KiB. One nice19 CoreUltra9
185H CPU0, WSL2, installed rustc1.97.1/LLVM22.1.6, opt1/one codegen unit.
Each experiment59sCPU/wall and512MiBAS. Compilation includes all arms/control,
not isolated shared-template compile time. No Cargo, GPU, installs, foreign
code execution or production writes. Local research reference dependencies
and original captured Rust binary are retained and hash-pinned; this driver
uses those documented research-local references rather than the full prover.

Baseline/eliminated/added/ceiling: remove nine repeated compiled bodies only;
add map storage/loads, address arithmetic and integration. No field work was
removed. `new_total=old_total-affected_D+replacement_D+integration`. Carried
R6/b7 CPU8B T128/32blocks/one16-thread pass,GPUoff,total471.580s,proof
370.137s includes witness94.021/load17.408; seal101.279s;D44.833s;
receipt922,711,264B. Delete-ALL-D at zero cost bounds only that CPU diagnostic
at1.105058x(0.271428→0.299944 diagnostic positions/s). Candidate affects a
strict subset and has no end-to-end ceiling measured. Fresh verify34.587s
plus load11.599s; recheck32.311 plus9.903s. Serialization,startup fraction,
steady slope unisolated; sealing is not startup. No receipt was reverified
by this researcher. Separate T32 next-token clocks remain in target-accounting.

Six LIVE source records append442→448: new older global function-merger paper,
2023 LLVM parameterization patch and2025 talk; recent LLVM23.1.3 release;
refreshed zkLLMPoT v2 and zkIE. Exact primary URLs, actual dates, license and
commit scope plus fetch failures are in source-records. LLVM23 is not installed.
No foreign speedup is reproduced and public-activation proofs are not adopted.

Integration seam: pinned `SC_DZC` in `private_block/argument.rs:1551`, through
`zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`. Four-pointer research ABI
`driven(raw,params,bases,out)` is unchanged. Owner gates remain actual native
admission/challenge/alpha/g_u8 provenance, RNG/refusals, seeded bytes,
extension/mask rows, original PCS/finals, fresh verification/tamper and joint
privacy, with enclosing clocks. No additional opening or mask reuse.
Main/Claude reviews; nothing is merged or integrated. D30 remains separately
unbuilt and reviewed; D32's float-fidelity target and unresolved thresholds stand.

The runtime hypothesis is demoted. Next local bounded question: census whether
the repeated raw/parameter/base maps differ by exact typed pointer offsets,
while retaining arbitrary scratch maps. Stop on non-affine families; only
after feasibility consider removing per-load index reads. Owner whole-prover
GPU and completed fixed-context resident1/2/4/8 series remain higher priority.
Full ranking, prerequisites, costs and falsification: hypotheses.json.

New target proofs/passes/positions0/0/0,device none. Target context,steady and
total-workload rates,startup fraction,witness/proof/serialization/verification
clocks unmeasured. No long-context prefill,resident-pass series or decode.
Larger workloads remain allowed; attention can grow quadratically. Complete
private8B>=50 proved positions/s on5090/named high-endGPU remains unachieved.
Only research files written; runtime,production,Git,receipts,calibration,safety,
instructions and reviewer files untouched. Saved reports do not establish delivery.
'''
(H/'README.md').write_text(readme)
handoff='''# Shared D helper templates: retain code-size finding, no speed promotion

Cycle0082 `20261019T141854Z-0a847d64`,2026-10-19UTC.

Research-only patch is experiments/dzc-shared-templates-20261019/grouping.py
(`shared_plan`, `emit`), selected by run.py::emit_arm. Generated kernels.rs
exports `driven(raw:*const Fp2,params:*const Fp2,bases:*const u64,out:*mut Fp2)`.
118Fp2 endpoints,129 proof-local Fp2 parameters,36 canonical u64 parameters,
five coefficients. Native seam is GPU-lane private_block/argument.rs SC_DZC
at1551 and SumcheckRounds; source-pins binds the exact files. No production
patch or merge. Public topology/maps can be planned independently of values;
all runtime scalar material must be refreshed for each actual proof.

19 unique groups→10 template bodies, still19 calls and884 field primitives.
Reachable code145,739→78,421B(46.19% decrease), plus634B static maps; requested
row bytes8,528→9,162. Stack remains504B vs scalar424B. Shared median4.658us
vs unique4.543us, scalar3.713us; noisy nine triplets, only3/9 favor shared.
No speed improvement is established; do not integrate on code size alone.

Validation passes six synthetic fixtures/two scalar catalogs/N2,8,32/seed
2026101982:780 coefficients,390 grid/78 off-grid original-Rust evaluations,
18 messages,354 original finals,six final relations,36zero bindings,eight
native-path controls. Independent1,455-check lineage/map/initialization/
assembly/source audit and six controls pass. A compiled wrong-map control
changes a valid parameter load and fails equality, with no uninitialized read.
Original59 tables/folds/finals retained. Exact commands, compiler/hardware,
hashes and limits are in README,source-pins,hardware and validation artifacts.

This remains a synthetic coefficient prototype with documented capture
field/Shape/Layout substitutes and artificial noinline baseline adapters.
Actual native profiles,challenges,alpha,g_u8,seeded bytes,RNG,refusals,masks,
extensions,PCS/finals,fresh-process verification/tamper,joint-view privacy,
native/GPU compiler resources and whole-D/full-stack clocks are unresolved.
No masks/openings are reused and no private/public statement changes.

Delete-all-D ceiling1.105058x applies only to the carried8B CPU T128 diagnostic,
not this strict-subset prototype or GPU. Target receipts/passes/positions0.
Owner whole-prover GPU and completed resident-pass slope measurements outrank
further helper tuning. If this seam remains useful, first census typed affine
address shifts to reject or justify removing the634B index-read overhead.
'''
(R/'handoffs/20261019-dzc-shared-templates.md').write_text(handoff)
progress='''# ZKP efficiency progress

Cycle0082 — `20261019T141854Z-0a847d64`,2026-10-19UTC.

**No speed improvement found.** Sharing repeated D helper shapes cuts
grouped function code145.7→78.4KB, but adds634 logical bytes of index reads
per row and leaves the static stack span504B. Final shared-CPU row medians:
unique4.543us, shared4.658us; only3/9 pairs favor shared. This is a synthetic
coefficient prototype, not a proof or GPU benchmark. The runtime hypothesis
is demoted; the code-size finding is retained.

Six differential fixtures and eight native-path controls pass, including a
compiled wrong-map control. A separate1,455-check address/ownership/assembly
audit and six corruption controls pass. All59 original tables/folds/finals
remain; no mask or opening reuse. Each experiment uses one nice19 CoreUltra9
185H CPU0 and stays below59s/512MiB. No production changes or GPU work.

Six LIVE primary records append442→448: LLVM merging paper/patch/talk and
current release, plus zkLLMPoT and zkIE refreshes. Dates, licenses, commit
scope and fetch failures are retained; no external speedup is reproduced.

[Experiment](experiments/dzc-shared-templates-20261019/README.md),
[handoff](handoffs/20261019-dzc-shared-templates.md),
[dated report](progress/20261019T141854Z-0a847d64.md).
Seam: SC_DZC/SumcheckRounds. Next local check: whether exact typed pointer
offsets can replace public per-load map indices. Owner whole-prover GPU and
completed fixed-context resident1/2/4/8 passes remain higher priority.

Carried8B CPU T128/32blocks/one16-thread pass:total471.580s,proof370.137s
includes witness94.021/load17.408;seal101.279s,D44.833s;fresh verify34.587s
plus load11.599. Serialization,startup fraction and steady slope unisolated.
Delete-all-D bounds only this diagnostic at1.105058x. Researcher did not
reverify receipts. D32's float-fidelity target remains an owner obligation.

New target proofs/passes/positions0/0/0,device none. Target context,steady/
total rates,startup fraction and witness/proof/serialization/verification
clocks unmeasured. No prefill,resident series ordecode. Larger workloads
remain allowed; attention can grow quadratically. Complete private8B>=50
proved positions/s on5090/named high-endGPU remains unchanged and unachieved.
Saved reports do not establish message delivery.
'''
(R/'PROGRESS.md').write_text(progress)
(R/f'progress/{run}.md').write_text(readme+'\nFull ranked queue: '+json.dumps(ranked,indent=2)+'\n')
finding=f'''\n\n## Cycle0082 — 2026-10-19 — shared helper bodies reduce code, no speed gain

Run `{run}`. Shared native-field public-topology D helpers reduce19 compiled
group bodies to10, including6- and5-instance families. Still19calls and884
field primitives on the same1,167-node use-driven graph. Runtime inputs and
degree4 outputs remain unchanged. All59 original tables/folds/finals remain.

Reachable function code145,739→78,421B(46.19% reduction), plus634B static
public maps; instructions39,737→21,420; static call-chain span504→504B.
Requested row traffic8,528→9,162B vs scalar4,320B. Physical DRAM unknown.
Only compiled-code sharing is eliminated work; costs include maps/loads,
address arithmetic, frames and integration. No field work is removed.

Final nine balanced rotating triplets/8,192rows/sample give scalar/unique/
shared medians3.7134/4.5428/4.6577us;unique/shared ratio0.975323,3/9 favor
shared,pair ratios0.8004–1.2953. No speed improvement found. Shared-host
cache-resident32syntheticrows/oneparameterpack; artificial noinline scalar
adapters;not installedsampler,whole-D,GPU,quiesced,p95 orproof clocks.
Exploratory pre-control timing retained separately,not final-artifact A/B.

PASS sixfixtures/twopublicscalarcatalogs/N2,8,32/seed2026101982:
780coefficients,390captured-Rustgrid/78offgrid,18messages,354originalfinals,
sixrelations,36zerobindings,eightnative-pathcontrols. New compiledwrongmap
changes only initialized in-bounds parameterload and breaks equality.
Independent1,455-check template/address/initializedownership/assembly/source
audit passes six controls. Native field unchanged; capturedD/catalog still
uses documented field/Shape/Layoutsubstitutes. Actualnative admission,
challenges/alpha/g_u8,RNG/refusals,seededbytes,extensions/masks,PCS/finals,
freshverify/tamper,jointprivacy andGPU/fullproof remainowner gates.

Main{r['wall_seconds']:.6f}s incl.compiler{r['compile_seconds']:.6f}s;
RSS{r['rss_kib']:,}/compiler{r['compiler_rss_kib']:,}KiB. Audit{a['wall_seconds']:.6f}s/
{a['rss_kib']:,}KiB;bench+harnesscompile{b['wall_seconds']:.6f}s,child
{b['child_wall_seconds']:.6f}s,maxchild/compilerRSS{b['child_peak_rss_kib']:,}KiB.
Each59sCPU/wall/512MiBAS,one nice19 CoreUltra9 185H CPU0,WSL2,
rustc1.97.1/LLVM22.1.6,opt1/onecodegenunit. NoCargo/GPU/install/foreigncode.
[Experiment](experiments/dzc-shared-templates-20261019/README.md),
[unapplied handoff](handoffs/20261019-dzc-shared-templates.md).
Seam:SC_DZC/SumcheckRounds;Main/Claude reviews and integrates,no merge here.

Runtime template hypothesis demoted; preserve code-size-only finding. NEW
refined local question: do repeated raw/parameter/base addresses differ by
exact typed pointer offsets? Census first; stop on non-affine families.
If feasible, replace per-load index reads while retaining arbitrary scratch
maps and charge changed arguments/arithmetic/full stack. Falsify aliases,
value-dependent planning,extra field work,no resource benefit or enclosing
regression. Rank1OWNER whole-proverGPU D/A and verifiedresident1/2/4/8 slopes;
rank2OWNER immutablepublicsetup;rank3LOCAL typedoffset census;rank4OWNER D30
separateunbuiltprofile. Full criteria in hypotheses.json;D32fidelity stands.

Candidate end-to-end ceiling unknown. CarriedR6/b7CPU8B T128,32blocks,one
16-threadpass,GPUoff,total471.580s,proof370.137s incl.witness94.021/load
17.408s,seal101.279s,D44.833s,receipt922,711,264B. DeleteALLD atzero cost
bounds onlythatCPUdiagnostic1.105058x/0.299944diagnosticpositions/s vs0.271428.
Freshverify34.587+load11.599s;recheck32.311+load9.903s. Serialization,startup
fraction andsteady slope unisolated;seal isnotstartup. Four carriedD andfive
tokenowner evidencepins recheck;no receipt reverified byresearcher.

SixLIVE primaryrecords442→448: NEWolder
[globalfunctionmerger](https://arxiv.org/abs/2312.03214),
[LLVMconstantparameterpatch](https://lists.llvm.org/pipermail/llvm-commits/Week-of-Mon-20231016/1225745.html),
and2025talk; currentLLVM23.1.3 releaseOct6; knownzkLLMPoTv2Oct11 andzkIE
refreshed. Inspectedinlinepatchcommitbb9d1badcda28bbea37938644fbb8887e0381038
is preliminary2023patch,notHEAD/mergedstatus;actualLLVMlicenseinspected.
GitHubPR/zkIErelease/licenseInternalErrors andcommitCachemiss retained.
Noexternalimplementation/performance reproduced;LLVM23notinstalled.
Rotationnext:batching/amortization,publicsetup/lookup;retainGPUcommitments,
sumcheck/GKR,memory,quantization/arithmetic andproofcomposition.

Newtargetproofs/passes/positions0/0/0,devicenone. Targetcontext,steady/total
rates,startupfraction,witness/proof/serialization/verificationunmeasured.
No longprefill,residentseries ordecode;largerworkloadsallowed,attentionmay
growquadratically. Completeprivate8B>=50provedpositions/s on5090/named
high-endGPU unchanged/unachieved. Onlyresearchfileswritten;runtime,
production,Git,receipts,calibration,safety,instructions/reviewerfilesuntouched.
Savedreports do not establishdelivery.
'''
p=R/'FINDINGS.md'
if f'## Cycle0082 —' not in p.read_text():
    with p.open('a') as f:f.write(finding)
state=f'''# ZKP efficiency explorer — durable state

Cycle0082 COMPLETE: `{run}`,2026-10-19UTC.
Next cycle no earlier than15:18:54UTC; deadline this cycle14:38:54UTC.
[Dated report](progress/{run}.md).
Startup memory:experiments/dzc-shared-templates-20261019/startup/.

**Code-size result only; no speed improvement found.** Shared public helper
shapes replace19 unique bodies with10;still19calls/884field primitives on
same1,167-node DAG. Code145,739→78,421B,plus634B maps;instructions39,737→
21,420. Stack504→504B(scalar424). Logical row bytes8,528→9,162(scalar4,320);
physicalDRAMunknown. All59originaltables/folds/finals remain.

Finalnine balancedtriplets/8,192rows/sample/32syntheticrows/oneparameterpack:
scalar3.7134us,unique4.5428us,shared4.6577us. Ratio0.975323;3/9favor shared;
pairratios0.8004–1.2953. Sharedhost/noinlinebaseline,not native sampler,
whole-D,GPU,quiesced,p95 orproofclock. Runtime grouping remains demoted.

PASSsixfixtures/twoscalarcatalogs/N2,8,32/seed2026101982:780coefficients,
390Rustgrid/78offgrid,18messages,354originalfinals,sixrelations,36zerobindings,
eightnativecontrols incl.compiledwrongmap. Separate1,455-check address/
ownership/assembly/source audit andsixcontrols. Nativefieldunchanged;
capturedD/catalogsubstitutes andactualnative/profile/challenge/alpha/g_u8/
RNG/refusal/mask/PCS/proof/privacy gates remainexplicit. No extraopening/reuse.

Main{r['wall_seconds']:.6f}s incl.compile{r['compile_seconds']:.6f}s/RSS
{r['rss_kib']:,}/compiler{r['compiler_rss_kib']:,}KiB; audit{a['wall_seconds']:.6f}s;
benchincl.compile{b['wall_seconds']:.6f}s. One nice19 CoreUltra9 185HCPU0,
rustc1.97.1/LLVM22.1.6,opt1,onecodegenunit. Each59sCPU/wall/512MiBAS.
NoCargo/GPU/install/foreigncode orproduction changes.

Researchseam:grouping.py::shared_plan/emit→run.py::emit_arm→kernels.rs::driven
(raw,params,bases,out).118Fp2endpoints,129Fp2runtimeparams,36canonicalu64,
fivecoefficients;2,352Bparameterpack,208Bscratch,634Bpublicmaps. Original
folds add118reads/59writes/59eachadd/sub/mul. Handoff:
handoffs/20261019-dzc-shared-templates.md. Main/Claude owns review/integration.

Ranked queue (fullcriteria inexperimenthypotheses.json):
1. OWNERwhole-proverGPU D/A +completedverifiedresident1/2/4/8passes.
   Broadrecurringscope/highcost;measurealltraffic,serialization,drain,fresh
   verify. Exactfield/profile/masks/openings preserved. Falsify enclosingloss,
   backlog,verification/privacyfailure. GPU/candidateceilingunknown.
2. OWNERimmutablepublicsetupresidency. Removepublicworkonly;chargeidentity,
   peakmemory,lifetime/transfers. Startup/slopeunknown. Falsifystalesetup,
   private randomnessreuse or noverifiedgain.
3. NEWLOCALtypedaffineaddressoffsets. Census raw/param/base mapfamilies first;
   retainarbitraryscratchmaps. Potentially removes some634Bindexrequests,
   addspointerarguments/arithmetic;smallcensus/moderateemissioncost.
   Falsifynon-affinefamilies,changedaliases,secretplanning,noresourcebenefit
   or enclosingloss. No implementation/speed result for thisrefinement.
4. OWNERD30/architecture:separateunbuiltprofile/highsoundness,hiding and
   compositionreviewcost. D10privacyrulings andD32floatfidelitytargetstand.

NEXT: bounded independent census of exact typed pointer shifts across the
6- and5-instance families. Stop if source maps are non-affine; do not repeat
generic/shared timing without a changed cost. Owner GPU/full-resident work
remains first. Rotation batching/amortization,publicsetup/lookup;retain
sumcheck/GKR,memory,NTT/commitments,quantization andcomposition.

CarriedR6/b7CPU8BT128/32blocks/one16-threadpass,GPUoff,total471.580s,
proof370.137 incl.witness94.021/load17.408,seal101.279,D44.833,922,711,264B.
DeleteALLD ceiling1.105058x/0.299944diagnosticpositions/s vs0.271428 applies
only tothatCPUdiagnostic;candidate strictsubset,noenclosing gainmeasured.
Freshverify34.587+load11.599;recheck32.311+load9.903. Serialization,startup
fraction,steadyslopeunisolated;sealingisnotstartup. Carriedevidencepins
recheck,no receiptreverifiedhere. SeparateT32nexttoken retainedinaccounting.

SixLIVEprimaryrecords442→448:newolderfunctionmerger/LLVMpatch/talk,
recentLLVM23.1.3Oct6,refreshedzkLLMPoTv2Oct11 andzkIE. ActualLLVMlicense
andpreliminarypatchcommit inspected;releasecommit/zkIEHEADnotinspected.
GitHubfetchInternalError/Cachemiss saved. LLVM23notinstalled;noforeigngain
reproduced. Priorfindings/sourceprefixespreserved.

Newtargetproofs/passes/positions0/0/0,devicenone. Targetcontext,steady/total
rates,startupfraction,witness/proof/serialization/verificationunmeasured.
No prefill,residentseries ordecode. Largerworkloadsallowed;attentioncan
growquadratically. Completeprivate8B>=50provedpositions/s on5090/namedGPU
remainsunchanged/unachieved. Onlyresearchfileswritten;runtime/production/
Git/receipts/calibration/safety/instructions/reviewerfilesuntouched.
Savedreportsdonotestablishdelivery.

Checkpointwritten {datetime.datetime.now(datetime.timezone.utc).isoformat()}.
'''
(R/'STATE.md').write_text(state)
print('Reports and state checkpointed')
