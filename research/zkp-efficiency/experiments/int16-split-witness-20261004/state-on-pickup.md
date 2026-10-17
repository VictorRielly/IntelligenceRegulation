# ZKP efficiency explorer — durable state

Cycle0021 COMPLETE: `20261004T030146Z-711aedad`, checkpoint 2026-10-04T03:18:19.846706+00:00. Deadline03:21:46UTC. Do not start another cycle before04:01:46UTC,2026-10-04. Read AGENDA every cycle. Prior state: experiments/i64-field-conversion-20261004/state-on-pickup.md. Research-only writes excluding runtime; one CPU thread,<=60s/<=512MiB perexperiment. No GPU, native builds/proofs, installs,Git,external messages or production edits.

No accepted complete private8B proof/rate. This cycle0tokens/0full-stack passes,CPUonly,contextnull. Steady/total rates,startup fraction,witness/proof/serialization/independent-verification,latency/lag/drain null. Prior onecold synthetic12-block125M T512 RTX4070Laptop8188MiB diagnostic408.609226s wall,318.22s runprover includeswitness/serialization,12.15s in-processverify,484107456B,independentfalse. No live-job inference/relaunch. Larger workloads permitted;512/10.24s reference only; prefillT²/resident freshpasses/authenticateddecode differ. Preserve exactness/privacy/fresh masks.

139,880 signed scalar values,60 vector models/6,800words,25 row copies/3,208words and20 controls pass,seed2026100421.2.257907s,22,616KiBRSS,one pinned low-priority CoreUltra9 185H thread. Independent modulo/byte/decodedELF references. Fulli16/MIN/MAX/power boundaries,endianness/truncation/sign/overflow/domain/tail/internalpadding controls. Rust review sketch uncompiled; no native transcript/PCS/RNG/proof. Initial static-count failure retained:10instructions includesload,9arithmetic.

Useful negative: current apparent A conversion loop already hasno integerdivision. New signed-word mapping is exact but native instruction/time savings unknown. Current allocation containsmalloc+memset, not measured storetraffic. Current binarySHA2c617ae5… differs from historicaltimingSHA74abdad3…; no source-to-binary provenance or historic clock attribution. Sourcefield/protocol pinned unchanged from priorcycle. Handoff: handoffs/20261004-i64-field-conversion.md.

A-only ceiling: allocation+plane-fill86.691s/408.609226s=21.216%; deleting entireparent atzero cost leaves321.918226s, arithmetic1.590466positions/s, never candidate saving/countablethroughput. No reads/writes/capacity/commitments/proofs removed byconversion.88,918,016 m125 conversions/block is count-only; no secret sign statistics. Need matched-build zero allocation/conversion/copy clocks then full-nativeA/B.

Ranked hypotheses:
1.Owner actualGPU SC_SZC/witness recurrence,highest measured scope,no duplicatejobs; prior slowerfusion preserved.
2.NEW exact int16 FFN-down witness via2signed-byteGEMMs+i64 reconstruction at witness.rs::matmul_in_out312/685. x=((x&255)-128)+256*(x>>8)+128; partial<=2^28/full<=2^36 forpublicK<=16384. Untested; pack/extraGEMM/copies/recombine cost. No precision change; first-refusal/support/padding gates. Full8B W/add costs unknown.
3.Awrite-once allocation/exactconversion: synthetic parity, no measuredsaving/capacitygain; no native expensive division. Native byte/refusal/RNG/phase gates pending.
4.Typed/lazy/publiclast-read consumers: native lifetimes/peak/phase gates pending; retained codewords canerase benefit.
5.Residentfixed-context freshcomplete passes: setup/slope/independentverification/lag/drain/peak clocks missing. NTTalreadyonceperrun,notperlayer. >20ms/new verifiedposition falsifies50/s steady for measuredschedule.
6.Openinggather capacityonly;2.84%parentwall,extra sync mayregress.
7.Packed/matrixsumcheck/privatecomposition: highPCS/transcript/privacy/soundness cost,no compatible reproducedreplacement.

Four LIVE records: packed2025/719 Apr22 2025/Sep14 2026revision; oldercombined2025/1117 Jun13/17 2025; EPFLrepresentation/final-oracle docs(historyJun24,notcurrentHEAD,commit429/licensesCachemiss); PlonkySep23 2026release,changelog fullpin a21e3ed42905040ad49c519e402f018381c12d0c,versiondiffonly. No authorperformance reproduced/foreigncodeexecuted. Source/findingprefixes preserved. PROGRESS andprogress/20261004T030146Z-711aedad.md saved locally,not notification evidence.

Nextcycle CPU experiment: source-pinned exact int16 split-dot/requant oracle with bothmatmul orientations, MIN/MAX,publici32partial/i64fullbounds,stride/padding/support and firstrefusal controls. Do not launchGPU/nativebuild. Nextrotation batching/amortization withexactwitness scheduling,thenquantization/arithmetic,composition,GPU NTT/commitments,lookup/softmax,sumcheck/GKR. Owner alone promotes A/orGPUwitness candidates after common resourceguard review/fullproofgates. Target50/s unachieved.
