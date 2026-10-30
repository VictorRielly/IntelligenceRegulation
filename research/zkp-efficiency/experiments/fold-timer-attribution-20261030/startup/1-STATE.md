# ZKP efficiency explorer — durable state

Cycle 0158 COMPLETE: `20261030T064123Z-6637fd3d`.
Started2026-10-30T06:41:23Z; checkpoint2026-10-30T06:52:49.356272+00:00.
Deadline07:01:23Z; next cycle no earlier than07:41:23Z.
Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Direct explicit-limb packing passed
168 optimized Rust fixtures and 40 independently authored Python references.
In a nonempty four-vector helper, instrumented allocation requests fall from
five to one. At 3,517 rows, requested packing peak falls from 281,360 to
225,088 bytes; cumulative requested bytes fall from 450,176 to 225,088.
These measure a synthetic CPU host helper, not native GPU or proof performance.

Next: owner measurements of exclusive packing, allocation, GPU initialization,
mutex wait/hold, H2D, kernel, D2H, conversion and synchronization, reconciled
with an enclosing independently verified workload. `secs_fold` starts after
GPU initialization and mutex acquisition, so that phase alone misses waits.
Keep actual current groups and capacity in the profile. Park further packing
or staging variants if removable costs are negligible. No lock move is proposed
without contention, capacity and failure-order evidence.

Baseline helper was extracted verbatim from root dev_fold_rows/as_u64s_f2;
candidate writes identical explicit limbs into the reserved flat destination.
168fixtures compare458160limbs;120native scalar-fold cases pass.40Python
references match4000serialized limbs and1600bigint fold-output limbs.
11Rust/5Python negative-control families and49capacity plans pass.
Raw noncanonical representation tests do not admit invalid field values;
three synthetic tail columns are not generated PCS pads/privacy evidence.

Baseline/direct nonempty allocation requests:k+1/1; cumulative requested
bytes:32*k*rows/16*k*rows; packing peak:16*rows*(k+1)/16*k*rows.
Inputs,outputs/device/matrix,pads,allocator overhead/runtime are excluded.
Instrumented optimized1.75 helper results do not establish production
optimizer behavior,DRAM traffic,latency or native GPU/proving improvement.
Conditional historical T128A57 groups:72→15pack allocation requests.

Patch retains original assertion placement and unchecked length products;
the checked overflow planner is separate,not native profile admission.
No rawFp2 ABI cast,repr change,dependency/cache/mask/opening reuse.
Original max4 API remains. Native init/poison/allocation/refusal order,
async lifetimes,RNG/transcript/receipt bytes and privacy remain untested.
Ceiling:N/(T-C_pack_exclusive+A_added);perfect removal f<=1/(1-f),funknown.
Falsify on negligible packing,compiler elision,net regression or mismatch.

Global ranking:(1)complete verified high-endGPU workloads and resident
1/2/4/8passes;(2)admitted context/DD/fidelity;(3)exclusive phase/capacity.
All86prior hypotheses preserved;87tests86;88adds timer/mutex measurement
question. No new local packing/staging variant should outrank native clocks.
Four LIVE source records1045→1049. Rust specialization newly assessed;
ICICLE commit6c77775961b0e4dc2be359feec1ac11536c18043 inspected,
releaseyearunverified;October26GKR/October11zkLLMPoT refreshed. Exact
fetch blockers retained; no network bypass or foreign source execution.

Seed202610300641;oneCPUaffinity,nice19,onecodegenunit;40sCPU/45salarm/
50sparent/384MiBaddress-space cap per leaf. Compile memory estimate300MiB,
others96MiB. Auxiliary compiler thread countunmeasured;oneCPUat a time.
Clocks:compile: 1.829 s / 166,164 KiB maximum RSS; probe: 0.033 s / 7,608 KiB maximum RSS; audit: 0.033 s / 15,844 KiB maximum RSS. These are correctness execution,not proof benchmarks.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context: none; only conditional historical cost accounting uses T128.
Device: one affinity-pinned Intel Core Ultra 9 185H CPU worker; no accelerator.
Witness, proof, serialization, verification, startup and initial-prefill clocks,
startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model pass
series or decode ran. Larger workloads remain allowed; longer dense attention
can grow quadratically. Complete private 8B **>=50 proved tokens/s remains
unachieved**.

Carried CPU8B baseline,not rerun/reverified/newly counted:T128,32layers,
one16-thread pass,GPUoff,total478.737s,0.267370positions/s. prove_run
393.785s includes witness98.348s/load17.595s;preceding sealing84.824s
includes overlapping load27.151s/witness80.897s. Receipt922711264B;
verify42.709s+13.681sload. Serialization/startup fraction/steadyunknown.
Never sum nested/overlapping clocks.

Owner05:30MVP status reports recovery/reverification of existing classifier
receipts;D46safeguards,D47fundinghold,D48release direction do not amend
private8B target or research permissions. Re-review remains not privacy
acceptance. No supervisor/job liveness inferred or heavy job duplicated.
Startup memory/pins:experiments/direct-limb-packing-20261030/startup-index.json.

[Experiment](experiments/direct-limb-packing-20261030/README.md) ·
[Handoff](handoffs/20261030-direct-limb-packing.md) ·
[Dated report](progress/20261030T064123Z-6637fd3d.md).
Only research outside runtime written;no production/Git/receipts/calibration/
instructions/safety/reviewer changes,GPU/nativebuild/install/external
write/message/escalation/merge. Saved reports do not establish delivery.
