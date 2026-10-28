# ZKP efficiency explorer — durable state

Cycle0113 COMPLETE: `20261020T211854Z-71297104`. Checkpoint UTC 2026-10-20T21:30:19.165784+00:00.
Started21:18:54UTC; deadline21:38:54UTC. Next cycle no earlier than22:18:54UTC.
Evidence: `experiments/public-layer-dd-caps-20261020/`. Early checkpoint and prior state retained. Source ledger692->702;26ranked hypotheses retain prior negatives.
Final artifact audit:173checks PASS; all692 original source records and prior findings prefix byte-preserved; agenda and15source pins unchanged. Finished UTC 2026-10-20T21:31:19.954709+00:00.

No proving improvement measured. Existing public b7 exponent schedule30x2/1x3/1x4, used only as HIGH/S12 sensitivity, gives T512uniform25,701,646,336 -> per-layer25,575,817,216 A+H words: additional0.489576% saving versus uniform /4.435215% versus direct. Selected dictionary peak stays768MiB; cumulative requests24,576->23,616MiB do not imply HWM. T128 per-layer still+9.232756%; public hybrid31direct+1cap64 saves0.017486% words but adds697,952 conditional body bytes. No runtime optimizer or profile admitted.

Every DD layer keeps6extra A/Hsites and12*row-width fresh mask words,3extraPCSgroups,1slot,+2Mrows. Cap changesmainrounds andCFScoefficients, notclaimmasks.32DDlayers add48/96MiB A/Hmaskwords atT128/T512; b7per-layer onlysaves24baseCFSdraws overuniform. Wire counts includePCSgroups/Mrows/slots andmatchnativeR9T128delta235008B, butHIGHisnotimplemented; newschedulemetadata anddegree/groupassumptions unvalidated. Otherowners/PCS/witness/looked/histogram/pools/driver/transfers andwholedeviceHWMunmeasured.

53,836checks/120syntheticrows/10controls PASS; independent8,915checks/20,480publicentries at90digits/3,360positions/4,096allocationevents/15pins/9controls PASS. Probe1.777999s/18,720KiB; audit0.021773s/18,000KiB. OneCPUworker/nice19/firstallowedcore;59sCPU+alarm/60sparent,512MiBAS,64MiBestimate. IntelCoreUltra9 185H/WSL2. No experimentfailed; previoussuccessfulauditbeforeMbudgetcheck preserved.

9nativeLIVEqueries/10primaryrecords. CurrentChimera/ICICLEandNTTcapacity/layout,cq/rings refreshed. NewlyscreenedolderMARLUT three-partyMPC/distributedZK is incompatible as directnative replacement. PDF403andtwoLICENSEcachemissesrecordedwithoutbypass; labels distinguishedfromMITbodyinspection. ICICLEtagcommit6c77775961b0e4dc2be359feec1ac11536c18043inspected; fullreleaseyearnotverified. Noauthorspeedreproduced.

Top3: wholeGPU+verifiedfixed-contextresident1/2/4/8; DDcontext/fidelity; completephase/capacityclocks. All-elevenFZC A/B4; publiccap/mode5refined. Newdyadicpaddingfeasibility26. Priorreversibletiles/masking/capacitynegativespreserved. Nextrotatepubliclookupinputconsistency/composition, thenfullGPUevidence/NTTfreshness.

Next local: Test a public dyadic dictionary partition against the proposed cap256: 156 distinct public outputs could occupy 128+16+8+4 slots per attention row instead of 256. First use synthetic direct-versus-sharded tuple/divmod checks and count every additional slot, fresh mask pair, PCS group, histogram and row-Sum binding. Check the no-lift premise for every shard; small shards may erase the gain. This is an untested new-profile idea, not authorization to alter native D30 or its privacy requirements. Actual HIGH/S12 tables must come from the owner fidelity lane before promotion.

Owner priorities remain whole-prover high-end GPU phase/capacity clocks and independently verified fixed-context resident 1/2/4/8 workloads, DD context/fidelity scaling, and the all-eleven FZC compiler A/B under shared heavy/build locks. No such job was launched here.

Review handoff `handoffs/20261020-public-layer-dd-caps.md`; researchinterfaces inprobe.py/audit.py. No native patch or merge.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode ran. Synthetic rows use lengths 32/128/512; counted layouts use T128/T512, 32 heads, head dimension 128 and 32 sequential layers. These are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private 8B >=50 proved positions/s target on an RTX 5090 or another named high-end GPU remains unachieved.

Historical CPU diagnostic, carried without rerun/reverification: non-DD 8B T128, 32 layers, one 16-thread CPU pass, GPU off; total 478.737 s = 0.267370 positions/s. prove_run 393.785 s includes witness 98.348 s and load 17.595 s; seal 84.824 s contains overlapping subwork. Receipt 922,711,264 B; fresh verify 42.709 s + public load 13.681 s; recheck 34.395 s + load 10.739 s. Isolated serialization, startup fraction and steady slope remain unknown. This is not a high-end GPU result.

Only research excluding runtime was written. No production, reviewer, instruction, calibration, Git, receipt or safety-gate edits; no GPU/build/install, external writes/messages, purchases or escalation. Fresh masks/openings and D30 N-r9-a (row Sum/slot17/Ht), N-r9-b (M_dd in A before lookup challenges), the DD privacy gate, D32 and narrow D33/D34/D35 scopes remain. Main/Claude reviews and integrates; no merge. Saved reports do not establish external delivery or supervisor liveness.
