# ZKP efficiency explorer — durable state

Cycle0094 COMPLETE `20261020T021854Z-e084e681`, checkpoint 2026-10-20T02:30:25.208578+00:00.
Deadline02:38:54UTC; next cycle no earlier2026-10-20 03:18:54UTC.
Evidence:experiments/private-stage-lifetimes-20261020/.

No proving speed improvement found. Source-pinned private-run schedule:
M/A/H drop immediately after their sole opening; boundary waits for BOTH
adjacent claims and opens in consumer stage. No earlier logical release.
M50x4096 encoded payload is CPU only. Pooled drop returns idle backing.
182348 independent authored source/dependency/interval/byte checks,
330 negatives;6 traces,36 capacity cases,36 toy byte fixtures;
seed2026102094. No native proof/security review implied.

NEW output-only GPU residency eviction demoted. AtR8 8B T128,32blocks,row2^14:
resident persistent-owner subset4568.75->4545.625MiB;chunked930.527344->
925.330078MiB (~0.56%). These omit transient/scratch/idle/cache/driver costs,
not nativeVRAM/fit/time. Resident drop23.125MiB becomes idle,0pooled freed;
chunked4.625MiB becomes idle,only0.572266MiB raw could directly free.
Original host owner,pads,salts/tree and single opening must persist;restore
needs exact encoding and measured copies/completion. No native patch/build.

CORRECTION:DD D30 ownerR9 is no longer wholly unbuilt. Read-only owner log:
85pass/1ignored/519filtered,including genericDD proof test and countedT128.
8B T128 A/H3405/3790->3283/3634 (-3.86% words),not20.82%T512 anchor.
Not rerun;no independently reviewed full-stackDD time/privacy inferred.

Carried CPU8B T128,32blocks,one16-thread pass,GPUoff,total478.737s=>0.267370
positions/s;prove_run393.785s contains witness98.348/load17.595;sealing84.824
overlaps witness/load. Receipt922711264B;fresh verify42.709+13.681load,
recheck34.395+10.739load. Not reverified. Startup/steady/serialization unknown.
Newer CPU next-token501.6/529.2s owner workloads remain distinct.
New independently verified full-stack proofs/passes/positions0/0/0;
token context/device none;new witness/proof/serialization/verify clocks,
steady/total rates/startup fraction unmeasured. No long-context,resident
complete passes or decode. Larger workloads allowed;attention can growT^2.
Private8B >=50/s RTX5090/high-endGPU target unchanged/unmet.

Ranked:1owner whole-proverGPU+verified resident1/2/4/8;2DD ownerprototype;
3actual phase/capacity coverage;4prior publicloader;5output residency(demoted);
6release-only(rejected);7NTTordering/composition. Full obligations in hypotheses.json.
Next local:derive H-commit transient and FZC/DZC raw-scratch lifetimes alongside
these owner intervals;include chunked deferred openings,all raw/cache capacity
and independent overlap controls. Native actual peak phase still unknown.
Do not repeat release-only or all-resident fallback staging;do not recommend
output eviction without an actual capacity cliff. Owner locks/native counters,
fullreceipt verification/privacy gates remain necessary.

LIVE531->538:NEWSlackSwap(Oct9simulation),NEWoldvDNN(Oct15,2016),ICICLE,
SP1recentrelease/orderdiff,zkLLMPoT,NTT/sumcheck,archivedzkLLM. Exact URLs,
verified/unknown dates,scopedlicenses/full vs unresolvedcommits and failures
saved. No foreign code executed or performance reproduced. Next rotation
sumcheck/GKR,quantization/arithmetic,composition,amortization;retainNTT,
lookup/softmax,memory. Handoff:handoffs/20261020-private-stage-lifetimes.md.
Onlyresearch(excludingruntime) changed;no native/GPU/Git/install/external
messages/writes/purchases/escalation. D27/D32/D33/R7/D34 scopes preserved.
No masks/openings reuse or weakenedprivacy. Reports imply no delivery.
