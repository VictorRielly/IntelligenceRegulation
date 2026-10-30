# ZKP efficiency explorer — durable state

Cycle0163 COMPLETE: `20261030T114123Z-38ad9454`.
Started2026-10-30T11:41:23Z;checkpoint2026-10-30T11:54:17.656204+00:00;deadline12:01:23Z.
Next cycle no earlier than12:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Tested public cohort admission with
216 metadata cases/2160 numbers,20 small Rust Vec probes,159 budget boundaries,
4560 assertions/55 controls.22 native metadata bodies copied unchanged;
SC_SZC inventory source-screened in Legacy/LowH24 argument files,not executed
native define. Both evaluators truncate without shrinking; A/H/M retain data
through all slots and open/drop afterward. Initial independent Python DD oracle
omitted a TABLE helper; native row mismatch caught it,corrected,failed evidence
retained. Prior allocation,pool,lifetime and batching negatives preserved.

R13 H24 T128 metadata:A4577/H4390,SC_SZC28 Fp2 tables at2^19 entries=224MiB
per proof. Single-block systematic commitment-data+table lower bounds for
cohorts1/2/4:1.322388/2.644775/5.289551GiB. Adding CPU Store::Host encoding
payloads gives5.738464/11.476929/22.953857GiB. These exclude witnesses,model,
other blocks,boundaries,constructor/open scratch,pads,salts,trees,remaining
M/CFS,proof/serialization,NTT,pools/oversizing/allocator/driver and quarantine.
They do NOT establish CPU or GPU fit; CPU encoded storage is not VRAM.

Synthetic two-proof counterexample: counting half-length arrays as freed
undercounts112MiB and falsely admits proof2. Correct gate retains capacity
until every recorded last-use event completes; idle pool capacity still counts
and reuse increments generation. Commitments remain until trusted downstream
opening completion. Unknown reserve refuses. Trusted tags/events are not
authentication; no cryptographic,privacy or native-error result established.

Baseline: serial separate proofs. Eliminated work:0 field operations/0 fresh
masking; potential dispatch/launch/barrier savings unmeasured. Added:distinct
live PCS/witness/table sets,routing,events,reserves,failure isolation,drain.
Ceiling unknown N/(T-C_dispatch_critical+A_admit); necessary50/s condition
T-C_dispatch_critical+A_admit<=N/50. Falsify on omitted owners/reserves,
length-vs-capacity error,early/stale completion or added costs exceeding
measured exclusive savings. Native integration is owner review only.

Rank1:complete independently verified high-end-GPU fixed-context resident
1/2/4/8 workloads,exclusive phases,startup/drain,actual capacity,all failures.
Rank2:admitted context/DD/fidelity scaling. Rank3:exclusive phase/capacity
evidence. H95 tested/refined; NEW H96 reserves whole lifecycle peaks before
witness/commit construction. No further toy batch variants. If native data
remains absent,next bounded local screen pins constructor scratch and compares
two-proof public phase envelopes with simultaneous commit/quarantine controls;
no invented schedule timings or actual-fit claim. Prior95 hypotheses retained.

New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: one CPU affinity on Intel Core Ultra 9
185H, no GPU. Witness / proof / serialization / verification / startup /
initial-prefill clocks, startup fraction, proof latency/bytes, steady-state and
total-workload proved-token rates: **unmeasured**. No long-context prefill,
resident-model proof passes or decode ran. Metadata contexts17/32/64/127/128/
256/512 and synthetic cohort counts1/2/4 are not model runs or proved passes.
Larger workloads remain allowed; increased context can increase attention
quadratically. Complete private8B **>=50 proved tokens/s remains unachieved**.
No masks, pads, openings or private values reused for amortization.

Historical CPU8B baseline carried,not rerun/reverified/counted:T128/L32,
one16-thread CPU pass,GPUoff,total478.737s=0.267370positions/s. prove_run
393.785s includes witness98.348/load17.595s. Sealing84.824s overlaps
load27.151/witness80.897s. Receipt922711264B;verify42.709+13.681s load.
Startup fraction,serialization,steady slope unknown;do not sum nested clocks.
R18 classifier3B batch/singles1418/1453s is a different scope,not8B/GPU evidence.

LIVE sources:zkDuelOct26,MegaZK,gnarkrelease,CUDA/Rust docs;newly assessed
older STAlloc2025 primary paper(v2Nov25),implementation commit
3a9f97ff4896c46ffb65b229ba7347358b400387. Apache2 headers inspected,full
license body blocked/third-party notices unaudited. Eight records append to
1079 prior sources;unknown dates/license/pins and exact403/cache misses kept.
No author performance reproduced. Rotation next:lookup/softmax,NTT/commitments;
retain memory/batching,sumcheck/GKR,quantization/arithmetic,composition.

Resource:oneCPU affinity,nice19,30sCPU/40salarm/45sparent,384MiB AS;
compile estimate300MiB,audit64MiB. Rustc1.75.0;one codegen unit,compiler helper
thread count unobserved. Finalcompile1.278s/158376KiB;audit0.171s/18228KiB.
Correctness process clocks only;no native/dependency build or GPU.

[Experiment](experiments/public-cohort-admission-20261030/README.md) ·
[Handoff](handoffs/20261030-public-cohort-admission.md) ·
[Dated report](progress/20261030T114123Z-38ad9454.md).
Only research outside runtime written. No production/Git/receipts/calibration/
safety/instructions/reviewer edits,installs,foreign-code execution,external
write/message,purchase,escalation,merge or liveness claim. Saved reports do
not establish delivery. Main agent/Claude reviews any integration.

Closing direction re-read: MVP_STATUS draft-version naming and DECISIONS C-9/security-owner/v3 text-check notes changed during this cycle. Exact diffs and current hashes retained; classifier privacy acceptance remains pending. No target or local experiment conclusion changed. Initial final-audit stop on document drift retained; this was an owner-document update, not a proof or experiment failure.

Final evidence audit PASS: 183 provenance/accounting checks, 10 unchanged native source pins, all 1,079 prior source records and prior FINDINGS bytes preserved; eight new source records. Closing checker schema assumptions were corrected for historical records and explicit current-cycle accounting; failed closing attempts retained. Final checkpoint 2026-10-30T11:56:44.181953+00:00.
