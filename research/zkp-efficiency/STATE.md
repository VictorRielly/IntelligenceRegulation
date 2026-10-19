# ZKP efficiency explorer — durable state

Cycle 0081 COMPLETE: `20261019T131854Z-168a653c`, 2026-10-19 UTC.
Next cycle no earlier than **14:18:54 UTC**.
[Dated report](progress/20261019T131854Z-168a653c.md).
Startup memory: experiments/dzc-helper-groups-20261019/startup/.

**Negative result: generic native-field D grouping does not improve observed
row timing.** Same use-driven 1,167-node DAG and 884 logical field primitives;
19 bounded groups reduce scalar call boundaries884→19 and compile in4.626792s.
Caller stack subtraction360→208B, but static deepest call-chain span424→504B
including group red zone and return addresses. Relevant code33,543→145,739B;
static instructions7,171→39,737. Logical requested row bytes4,320→8,528;
physicalDRAM unknown. Preserve this negative; do not promote caller-only wins.

Eight alternating pairs,8,192rows/sample,32 cache-resident arbitrary synthetic
rows and one synthetic parameter pack: median6.208298→6.525496us,baseline/
grouped ratio0.951391; seven pairs favor baseline. Shared CPU, no quiesced or
p95 claim. Baseline has artificial noinline Fp2 adapters; neither arm is the
installed sampler. No whole-D or enclosing proof speed measured.

PASS six synthetic fixtures,two public scalar catalogs,N2/8/32,seed2026101981:
780coefficients,390 captured-Rust grid/78off-grid values,18messages,
354originalfinals,sixrelations,36zero bindings,sevennative-path controls;
separate1,465-check initialization/ownership/traffic/assembly/source audit
with four controls. Native field unchanged; captured D/catalog still uses
field/Shape/Layout substitutes. Actual native admission/challenges/alpha/
g_u8/RNG/refusals/transcript/masks/PCS/proofs/privacy remain owner gates.
All59 original tables/folds/finals remain; no additional opening/mask reuse.

Interface: grouping.py::partition/emit and run.py::emit_arm → kernels.rs::driven
(raw,params,bases,out).118Fp2 raw,129Fp2parameters,36u64canonicalbaseparams,
fiveFp2coefficients;2,352-byte runtimepack;208-byte public scratch. Original
folds still charge118reads/59writes and59eachadd/sub/mul, outside row test.
Six live native source pins and five carried owner evidence pins unchanged.

Main7.215940s/RSS38,152KiB,compiler4.626792s/RSS131,768KiB;
audit0.122996s/RSS21,136KiB;bench incl.harnesscompile1.181911s,
child0.841757s/maxchildcompilerRSS123,564KiB. One nice19 CoreUltra9 185H CPU0,
WSL2,rustc1.97.1,opt1,onecodegenunit. Each59sCPU/wall/512MiBAS. No Cargo,
GPU,installs,foreigncode execution or production changes. Commands/pins/logs
and negative handoff: handoffs/20261019-dzc-helper-groups-negative.md.

Carried R6/b7 8B diagnostic:T128,32blocks,one16-threadCPU pass,GPUoff;
total471.580s,proof370.137s incl.witness94.021/load17.408s,seal101.279s;
D44.833s=9.507%,922,711,264B. DeletingALLD atzero cost bounds only that
CPUdiagnostic at1.105058x/0.299944diagnosticpositions/s vs0.271428.
Freshverify34.587+load11.599s;recheck32.311+load9.903s. Serialization,
startupfraction and steady slope unisolated;sealing is not startup.
No receipts reverified byresearcher. Distinct carried8B next-token T32:
proof191.7s/test230.5s,receipt471,285,072B;R3soundness maystand,reviewer
verify37.7/secondroute41.8s;trainedprivacy/hiddenlength/decode pending.

Ranked hypotheses:
1. OWNER whole-prover GPU D/A and completed fixed-context resident passes
   (1/2/4/8). Broad recurring scope/high integration cost. Measure all table/
   PCS traffic,serialization,drain and fresh verification; preserve profile,
   exactfield,mask/opening freshness. Falsify enclosing regression,backlog or
   privacy failure. No candidate GPU/end-to-end ceiling established.
2. OWNER public-setup residency. Eliminate immutable public setup only;charge
   identity checks,peakmemory,lifetime and transfers. Slope/startup partition
   unknown. Falsify stale setup,reusedprivate randomness or no verified gain.
3. NEW LOCAL shared helper templates. Census19groups→10normalizedshapes,
   with6-instance and5-instance families. Replace repeatedcode only;charge
   all public address maps,argument/return traffic,fullcallchain,compile/code
   size. Moderate incremental integration; no tested outlined implementation.
   Falsify changedslots/aliases,extra field work,value-dependent dispatch,
   compilebudget failure,noresource benefit or enclosing regression.
4. OWNER D30/architecture comparisons:separateunbuilt profile and substantial
   soundness/hiding/composition review. No D10 or currentprivacy override.

NEXT: bounded shared-template emission for the repeated group families,
independent address-map/oracle and whole-call-chain checks. Do not merely
repeat the19uniquegroup timing. Generic grouping is demoted. Whole-prover GPU
and complete resident measurements stay with owner/shared heavy locks.
Rotation next:lookup/softmax and quantization/arithmetic; retain sumcheck/GKR,
memory,batching,NTT/commitments and composition.

Seven LIVE records435→442: newComFuse(Aug4),NVIDIAfusion(Jul10),older
LLVMoutlining(Sep27,2017);refreshedStateSync(Oct10knownsincecycle51),v1.1.1
actualBSLlicense/release,Plonky3source/rc2 andolderarkworks. Commit/source
fetchInternalErrors retained;noforeigncommit inspected/performance reproduced.
Source recorder first assumed legacyid fields;KeyError beforeappend,then
fixed. All435prior records preserved byte-for-byte;all442parse.

New target proofs/passes/positions **0/0/0**,device none. Targetcontext,
steady/totalrates,startupfraction,witness/proof/serialization/verification
unmeasured. No prefill,residentseries ordecode. Largerworkloads allowed;
attention maygrowquadratically. Completeprivate8B >=50provedpositions/s on
5090/namedhigh-endGPU remains unchanged/unachieved. Onlyresearchfileswritten;
runtime/production/Git/receipts/calibration/safety/instructions/reviewerfiles
untouched. Savedreports do not establishdelivery.

Checkpoint written 2026-10-19T13:30:17.742981+00:00; final validation recorded separately.
