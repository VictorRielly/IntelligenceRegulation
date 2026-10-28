# ZKP efficiency explorer — durable state

Cycle0091 COMPLETE:`20261019T231854Z-28e6b36b`,2026-10-19 UTC. Checkpoint 2026-10-19T23:27:05.586443+00:00.
Next cycle no earlier2026-10-20 00:18:54 UTC;deadline was23:38:54 UTC.
Startup snapshots and full findings/source read index:
experiments/vec-allocation-scopes-20261019/.

**No speed improvement measured.** Original Vec decode API/System allocator,
scalar native pad analogue,Rust1.90 opt0/3:no custom decoded Drop/black_box.
80 regions,8 geometries,5 variants. Largest reduced proxy419200->304384B
live requested peak,decode172160->57344B;36 allocations/482848B volume
unchanged. Direct-byte27allocs,reference negative460288B,clone negative
45allocs/475648B. Outputs byte-equal. Independent audit1389 checks,720
corruptions,240 event mutations,32 masquerades. Seed2026101991. Opt0/3
compile0.568761/0.781899s,136832/138848KiB;probe0.026704/0.005584s,
8744/8556KiB;audit0.856544s,18316KiB. Nice19,CPU0,CoreUltra9 185H,WSL2;
probe1thread,compiler helpers unobserved/one CPU affinity and codegen unit.
Every leaf59s CPU/wall,512MiB AS. Actual production/Rayon/RSS/VRAM/clocks
unknown. No production compile/proof. Prior scope patch copied,unbuilt/unapplied.

[MODEL,carried]8B T128 pad638116864->520672256B(112.003906MiB),standalone
borrowed full/reload loader peak saving0B. Prior moves+post release+four
distinct pins/current+next1.727765560->1.618386745GiB. Direct-byte composition
lower1.586862GiB model. Models exclude private proof/witness/device/allocator/
cache/slack and are not complete-model fit or elapsed measurements.

Carried R8 diagnostic only:8B T128,32 blocks,one16-thread CPU pass,GPU off,
total478.737s=>0.267370positions/s. Prove_run393.785s includes witness98.348s
and its17.595s loads;sealing84.824s overlaps27.151s load/80.897s witness.
Commit121.32s/31% summed block walls. Receipt922711264B;fresh verify42.709s
+13.681s load,recheck34.395s+10.739s load;guard165.982s includes controls.
Researcher did not reverify. All-load deletion bound1.103104x CPU only,
much broader than candidate. Startup,steady slope,isolated serialization unknown.

New independently verified full-stack proofs/passes/positions **0/0/0**;
device/context none. New witness/proof/serialization/verification clocks,
steady/total proved rates,startup fraction unmeasured. No long-context prefill,
resident proof series or decode ran. Larger workloads allowed;attention may
grow quadratically. Target complete private8B >=50positions/s RTX5090 or
named high-end GPU unchanged/unachieved. No masks/private openings reused.

Ranked hypotheses:1 owner whole-prover GPU+verified fixed-context resident
1/2/4/8;2 NEW device-pool simultaneous live+idle capacity;3 checked public
constructor transfer;4 tested scopes;5 split raw release;6 postconstructor
release;7 direct bytes;8 guarded public owner. Details/costs/falsifiers:
experiments/vec-allocation-scopes-20261019/hypotheses.json.

Next local:pin cuda.rs pool_take,pool_take_min,pool_put,commit_zk_chunked
and build a bounded public request/event census. Exact and best-fit reuse
ALREADY exist;64 cached buffers bound count,not bytes;cumulative counters
are not peak live+idle. Compare independent live-capacity oracle using
mixed-size/tail/returned-buffer/one-shot-allocation-failure negatives. First
derive actual public call sizes;do not invent a stage trace or call private
content reusable. Measure no GPU here. Owner owes device timing,full-write-
before-read/stream completion,CPU/GPU bytes/refusal/privacy gates under locks.
Falsify on no avoidable retention/drain,loss of useful reuse,or overhead.
No repeat of completed loader/digest-only/LRU/registry-only microvariants.

LIVE literature:Rust allocator/System,Chimera Oct16,GPU NTT/Goldilocks,
Plonky release/RNG and older Huerta register-file scheduling. Sources/date/
license/commit scope and fetch/cache errors recorded;no author performance
reproduced or foreign code executed. Next rotation lookup/softmax and
memory/batching;retain NTT,SC/GKR,quantization/arithmetic,composition.

D33 only accepted TinyLlama T32 pg_rot1 CPU R7;R8/8B/GPU/next-token need
their scope/re-pin.D27/D32,D30 unbuilt bind. Only research written;
runtime/,production,Git,receipts,calibration,safety,instructions/reviewer
files untouched. No GPU/install/external write/message/purchase/escalation.
Saved reports imply no delivery. Handoff:handoffs/20261019-vec-allocation-scopes.md.

Freshness checkpoint 2026-10-19T23:29:44.252978+00:00: first final gate failed because owner MVP_STATUS
changed at23:25UTC. Updated text was read and preserved separately in
final-MVP_STATUS.md/direction-update.diff;initial startup snapshot remains.
Owner reports next-token-stage gate evidence,not a new privacy acceptance;
22-layer R8 re-pin pending. No new8B/GPU throughput evidence. Research result,
target and narrow D33 scope unchanged. Failed05-validate log retained;final
validator checks the reviewed new document pins. LIVE source ledger507->517
(10primary records);all inspected implementation commit IDs null because no
commit diff opened. No external author result reproduced.

Final checkpoint 2026-10-19T23:30:19.251633+00:00:provenance/consistency gate PASS,230 checks,
10 unchanged source/evidence pins,9 current direction pins (one owner status
update reviewed). Initial failed freshness gate retained;second failed gate
was an overly narrow report-wording assertion (handoff said "Limits:"),now
corrected. Neither failure was an experiment failure. Event/byte audit and
Rust opt0/3 observations remain passing. Static atomic log32768B;report size
corrected before closing. No native integration or new full-stack proof.
