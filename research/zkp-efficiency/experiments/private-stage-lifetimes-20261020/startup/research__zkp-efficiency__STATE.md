# ZKP efficiency explorer — durable state

Cycle0093 COMPLETE:`20261020T011854Z-224b9b69`,checkpoint 2026-10-20T01:31:06.037153+00:00.
Next cycle no earlier2026-10-20 02:18:54 UTC;this deadline01:38:54 UTC.
Evidence:experiments/device-allocation-coverage-20261020/.

No proving speed improvement measured. Source census298 allocation API sites
(R8 94,GPU113,root91),10 direct drain/reservation callers outside cuda.rs.
Private production has no direct calls in inspected trees;legacy four-commit
drain model is not the trained private trace. Includes test/probe sites;
no runtime reachability/native peak inferred. Pool drain leaves raw scratch,
live commitments,monotonic twiddles and FZC public cache untouched.

NEW host-backed FZC two-buffer storage reuse:144 synthetic fixtures,
27301 independent byte/event/source checks,
292 negatives,1299 corruptions
rejected;seed2026102093. All-host staging23->2 allocations,184*l->16*lB;
at2^20 entries168MiB symbolic saving. H2D and23copy+1explicit syncs unchanged.
Pinned cudarc0.13.9 copy_into already synchronizes same device stream.
Review-only patch UNBUILT/UNAPPLIED. EQ/support/derived/masks/receipts untested
natively. IMPORTANT NEGATIVE:successful GPU A/H commitments feed resident
sources;36 resident fixtures eliminate0B/0allocs. Fallback candidate demoted.
No native speed/VRAM or8B-fit claim. Model/audit under1s,<29MiB;scanner<5s,
one nice19 CPU0 thread,59s leaf CPU/wall and512MiB AS limits.

Carried CPU8B T128,32blocks,one16-thread pass,GPUoff,total478.737s=>0.267370
positions/s;prove_run393.785s contains witness98.348/load17.595;sealing84.824
overlaps witness/load. Receipt922711264B;fresh verify42.709+13.681load,recheck
34.395+10.739load. Not reverified. New MVP docs report next-token T128CPU
501.6/529.2s,~57sverify/~928MB,a distinct owner workload,not verified here.
Startup/steady/isolated serialization unknown;do not sum nested clocks.

New independently verified complete proofs/passes/positions0/0/0;
device/context none. New witness/proof/serialization/verification clocks,
steady/total proved rates and startup fraction unmeasured. No long-context,
resident complete-proof series or decode. Larger workloads allowed;attention
may grow quadratically. Private8B >=50/s RTX5090/high-endGPU unchanged/unmet.
No mask/opening reuse or privacy weakening.

Ranked:1 owner whole-proverGPU+verified fixed-context resident1/2/4/8;
2 exactDD D30 unbuilt;3 private-stage capacity/lifetime coverage;
4 prior checked public loader;5 fallback staging (demoted);6 composition
same-degree batching lead requires binding review;7 NTT ordering.
Baseline/eliminated work/new costs/ceiling/falsifiers:hypotheses.json.
Handoff:handoffs/20261020-host-backed-fzc-staging.md.

Next local:derive actual private run/protocol commitment/opening lifetimes
for A,M,H,previous/current boundary and endpoints;combine raw/cache capacity
categories and independently audit early-release/prior-boundary controls.
Locate an actual peak phase;do not repeat legacy synthetic drain schedules.
Owner native clocks,actual device fit/full receipts/privacy gates and shared
locks remain necessary. Do not spend native work on fallback patch without
observed nonresident A/H;all-resident opportunity is zero.

LIVE sources:BitsUnderZK-LLM,EfficientSumcheck,gnarkOct7release+Sep23batchPR,
cudarc0.13.9 exact source+full release commit,NVIDIA2015 stream-ordering,
SumCATS;seven records appended524->531. Dates/license/commit-scope and fetch
failures saved. cudarc release commit only bumps version;copy semantics
inspected from tag+local matching package. No author performance reproduced.
Next rotation GPU NTT/commitments and lookup/softmax;retain memory,
amortization,arithmetic/composition and sumcheck/GKR queue.

D33 R7 narrow scope,D34 accounting only,D27/D30/D32 persist. No production,
Git,runtime,receipts,calibration,safety,instruction/reviewer writes;no GPU,
install,external message/write,purchase/escalation. Reports imply no delivery.
