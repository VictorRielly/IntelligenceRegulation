# ZKP efficiency explorer — durable state

Cycle 0072 COMPLETE: `20261018T012105Z-ac328993`.
Checkpoint: 2026-10-18T01:31:05.310030+00:00.
Next cycle no earlier than 2026-10-18 02:21:05 UTC.

AGENDA/current target, project/durable memory and latest three experiment
results consulted. Starting377 sources parsed;6 LIVE records appended,383 total,
original prefix preserved. Startup originals/hashes:
experiments/ntt-root-decomposition-20261018/startup/.
Full report: progress/20261018T012105Z-ac328993.md.
No native proving speedup found.

NEW native order64 late-root compression: k=l+2^(s-6)h, w64=2^39.
Host-compiled native primitives/action PASS280,366 checks/18controls;
131,070 roots/actions through log16 both directions,14,016shift checks,
4,096sampled higher-stage actions. Direct DFT/Lagrange hiding rows q>n,
counters/pad skips/prefix/control gates pass. Independent serial tiledDIT/
inverseDIF/swizzle/bit-reversed pad audit1,452checks incl256Horner samples.
Main3.353462s inclcompile,RSS29,436KiB/compiler24,980KiB;
audit6.312016s/24,344KiB. One CoreUltra9 185H CPU0,nice19,seed2026101872,
audit+1; each59s/512MiB AS. No CUDA/PTX/native-proof/RNG/privacy theorem.
Initial PASS retained; zero-only/schedule controls refined, no arithmetic change.

Both-direction root capacitylog16 1,048,560->32,736B;log20
16,777,200->524,256B. SAME generalproducts as prior sparse-shift candidate;
+285,727/+6,602,783 shifts per transform. Larger sizes counted/sampled only.
No measuredmemory/traffic/runtime saving. Probe/nativehosttables remain;
publicuploads alreadycached; late generallogicalreads unchanged. GenericOT
stage20 nearlydoubles generalproducts despite smallertables: demoted.
Hybridonlylargeststages counted as owneroption, not deviceimplemented.
Keep root/direction identity, monotonic publiccache, skippedpad stages,
coset/scale/order/pruned routes, originalfreshmasks/profile/security. All previous
lookupjointmask/offcube/singleton/D-C/wrapping/history and slowernativefusion
negatives retained. Unappliedhandoff:
handoffs/20261018-native-root-compression.md.

Carried functionalR5b8B T128: onecold32block CPU pass,16threads,GPUoff,
shared n1,freshverify/11controls. App606.598/process606.728291s;
diagnostic total0.211013/0.210968positions/s. Seal105.287s=17.356965%
is phasefraction, not isolatedstartup. Seal load36.570/witness103.349s overlap.
Inclusiveprove501.126s includes122.694witnessrebuild/21.176reload; serialization
unisolated. Freshload14.126+check43.902s;reload18.459withincheck,
arithmeticremainder25.443. Verifierprocess186.088255s includescontrols.
Receipt922,711,264B;RSS6.55/cgroup8.47GiB. IndependentreviewR5 accepts R5b
soundness/T64/T128arithmetic and reverifies128/11controls; notprivacyacceptance.
Publicationmarkerrace r5_A assignedR6, not proofsoundnessfailure. Fullstartup,
prefill,steadyslope,latency,lag/drain unknown. OldT32baseline retained.

OwnerGPUround2 no enclosinggain: cold173 vs prior159s; warm185includes spin.
NEW round3 actual warmF-slot28.25/29.83ms incl6.0–6.8build versus34.7prior;
kernels23.02ms at2^20;modulecache0.01–0.02s. Trained54equalities/seededbytes
all4shapes pass01:19,peak3173MiB,requiredGPU. P4/0x20thermalpolicy persists;
no settingschanged. CLIbuilt01:22; default/warm enclosingstacks+freshverify
queued atfinalread, no resultcaptured. No duplicatejob. Logicalplanbytes are
not measuredDRAM. Newowner source/statussnapshot/hash retained separately.

Ranked hypotheses:
1. OWNER whole-prover GPU arithmetic and sustained usefulwork. Charge integer
   dependencies,registers,memory,warmup,hostextension,transfers/drain. Reject
   gatefailure or no enclosinggain. Complete8B50/s unmeasured.
2. OWNER immutablepublicresidency and fixedcontextfresh-passslopes. Charge
   startup/witness/serialization/verification/lag/drain/identity/RAM. Existing
   typedwitnessreplay budget/privacy findingsapply. Reject stale/backlogged
   work or recurring>20ms/newposition for50/s. No privateopening/maskreuse.
3. TESTED publicrootcompression. Low adaptercost,32xwordcapacity opportunity,
   manynewshifts and unknowncachegain. Nativeconstructor/allroutes/byte/RNG
   gatesrequired. CeilingN/(Ttotal-Caffected+Cnew)unknown. Reject mismatch,
   privacy/refusal/peakregression or no enclosinggain.
4. Factoredlookup/pendingfolds: logicalread savings only; fullnewGKR/PCS/link/
   masking/jointprivacycosts high. Keep allprior negatives.
5. GenericOT/newPCS: addedgeneralproducts demoted, backendmigration costly;
   olderconvolutionfusion has no matching hiding-encode seam.

Nextlocal: read ownerround3 enclosingverdict first, then source-captured
operationaudit of derivedF-slot tables versus originalclosure. Charge build/
foldwork and base-round0 eligibility, compare earliercubic/CSEnegatives;
if resolved already, audit accounting rather than duplicate implementation.
Ownerrootnext: actualNTTcache/phaseprofile, largeststage-only guardedA/B after
fullgates. Rustseam gpu/cuda.rs::stage_major/ensure_twiddles; CUDA rootactions
in DIT/DIF/pad/gather/pruned kernels. Owner/Claude reviews/integrates.
Rotationnext sumcheck/GKR+arithmetic; retainNTT/commitments,memory,lookups/
softmax,batching/amortization,quantization andproofcomposition.

LIVE: Kim2020OT,NEWolderShivdikar2022convolutionfusion,NEWCGLASep24,2026
FPGA/smallfieldscope,currentCUDArepo actualcache/source/release,GoldilocksNTT
L2qualification,ICICLErelease refresh. Dates/licenses/commit scopes/errors
recorded. No foreigncode executed.6records appended,383total.

New target proofs/passes/positions0/0/0. Targetsteady/totalrates,startupfraction,
witness/proof/serialization/verificationclocks unmeasuredthiscycle; device none.
No residentrepeats,longprefill ordecode. Largerworkloadsallowedwithfreshmasks;
attentioncan growquadratically,decodeneedsprovedstate. >=50/scompleteprivate8B
high-endGPUtargetunchanged/unachieved. Production/runtime/Git/receipts/
calibration/safety/instructions/reviewerfilesuntouched; noinstalls,GPU/heavyjobs,
externalwrites/messages/escalation. Savedreports do notestablish delivery.
