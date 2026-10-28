# ZKP efficiency explorer — durable state

Cycle0088 COMPLETE:`20261019T201854Z-ec298e23`,2026-10-19 UTC.
Next cycle no earlier21:18:54 UTC. Started20:18:54;deadline20:38:54 UTC.
[Dated report](progress/20261019T201854Z-ec298e23.md).
Startup snapshots:experiments/public-raw-last-use-20261019/startup/.

**No speed improvement measured.** Explicit public raw-array release after
construction matches78 accepted synthetic full/reload paths across48 fixtures;
18 denied RoPE-mismatch paths preserve their modeled refusal. Main
10453 assertions and6720 mutation-path controls pass. Independent audit
10110 assertions,6720 first-error checks and1404 output/metadata corruption
controls pass. Main/audit clocks7.809640/0.273545s,
peaks40304/34256KiB,one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps. These are validation
clocks,not native loader benchmarks.18 pins unchanged;14 match frozen R8.
The21-line standalone Rust diff is **UNBUILT/UNAPPLIED**.

[MODEL] At8B T128,the11 raw source payloads total218114560B
(208.010254MiB). Moving their release before record hashing reduces the
borrowed-constructor sealing envelope772177408->705199616B with1 hash
worker (63.875MiB),or948346368->730231808B with16 workers (208.010254MiB).
The latter current+next+four distinct pinned blocks envelope falls
2.016689->1.813554GiB. These are conservative enumerated public payloads,
not actual RSS/VRAM,complete memory or proof speed. With prior checked-move
and direct-byte proposals,the16-worker/four-pin envelope becomes1.586862GiB;
all three patches remain unintegrated. Native decode+move instead reaches
1.618387GiB because padding takes over. Recompute phase maxima; savings
are not additive. Private witness/proof/device,allocator/page cache,JSON,
thread stacks and extra evicted live leases are excluded.

Decisive negative: every reload envelope has0B peak reduction. It skips record
hashing and the unchanged constructor/padding phase wins. Merely copying
SHA fields releases nothing;78 controls detect this.78 early-drop controls
refuse use-after-release;78 changed-source reload comparisons differ from
the sealed digest surrogate,so keeping the caller's real digest gate matters.

Carried owner R8 diagnostic: trained8B T128,32 blocks,one16-thread CPU
pass,GPU off,n=1. Total478.737s =>0.267370 positions/s diagnostic;
prove_run393.785s includes witness hand-over98.348s,including17.595s
block-load tasks. Sealing wall84.824s contains overlapping load/witness
tasks27.151/80.897s. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial public load13.681s; recheck34.395s plus
10.739s load. Fresh guard wall165.982s includes controls. Startup fraction,
isolated serialization and steady slope remain unmeasured. Researcher did
not reverify the receipt; no new target credit.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device none; no proof context or workload ran. Steady-state and total-workload
proved rates, startup fraction, and new witness/proof/serialization/verification
clocks are unmeasured. Synthetic cases are validation paths, not proof passes.
No long-context prefill, resident proof series or decode ran. Longer workloads
remain allowed; dense attention can grow quadratically with context.
The complete private8B / >=50 proved positions/s target on one RTX5090 or a
named high-end GPU remains unchanged and unachieved. No masks, private
commitments or openings were reused.

Ranked queue (costs,prerequisites,exactness/privacy/falsifiers in hypotheses.json):
1.Owner whole-prover GPU and verified fixed-context resident1/2/4/8.
2.Prior checked public constructor transfer,native gates/clocks pending.
3.Tested public raw postconstructor release,sealing capacity only.
4.NEW split matrix9 last-use before constructors,next local test.
5.Direct-byte padding alone,demoted for0B full-loader peak change.
6.Guarded public owner with freshness and complete live lease accounting.

Owner: review the one-method diff,then under shared build/heavy locks
run native full/reload malformed/first-refusal/record/receipt gates and
exclusive allocation+HWM clocks. No integration or merge occurred here.
Whole-prover GPU and independently verified fixed-context resident1/2/4/8
workloads remain first. Next local: split last-use of9 raw matrices after
aw/fw padding and before constructors,retaining exp/act through their own
reads; recompute full/reload timelines and preserve all source freshness,
CS and H-1 checks. This addresses the reload/constructor negative.
Do not repeat cycle0027's public digest streaming/cache or key-only/LRU/
registry-only lease shortcuts.

Eight LIVE primary records appended485->493. Newly assessed older
Jolt PR881 supplies a streaming/materialization lead (merged2025-08-19;
exact code/merge fetches failed,so no inspected commit). Atlas full text
makes extra-pass/staging costs explicit; its actual custom ICME license,
served history and empty release page were checked. New Zippel lead has
verified October16 metadata/abstract on the official index; landing/PDF
failed. Composition/sublinear-space conditions and October11 zkLLMPoT
covered-operator scope were refreshed. Rust's official drop-scope contract
supports the release boundary,but proves no allocator/RSS benefit.
No foreign code executed or author performance reproduced. A guessed
repository404,exact commit InternalErrors,and blocked ePrint pages are
retained in search-log.md. Next rotation memory traffic and batching;
retain GPU NTT/commitments,sumcheck/GKR,lookup/softmax,quantization/arithmetic
and proof composition. Licensing/date/coverage qualifications remain binding.

Handoff:handoffs/20261019-public-raw-last-use.md. Patch unbuilt and unapplied.
D33 remains trained TinyLlama T32 pg_rot1 CPU R7 only; R8/new files
need gate re-pin,and8B/GPU do not inherit that acceptance. D30 is an unbuilt
construction; D27 soundness and D32 fidelity thresholds remain binding.
Public buffer release authorizes no P3 weight/private opening cache.
Only research written;runtime/production/Git/receipts/calibration/safety/
instructions/reviewer files untouched. No installs,builds,GPU jobs,external
writes/messages,purchases or escalation. Saved reports do not imply delivery.
Checkpoint 2026-10-19T20:28:11.334785+00:00. Final consistency/provenance gate PASS: 261 checks,18 unchanged source/evidence pins,14 frozen R8 manifest matches;two patch hunks applied in memory only. No native compile/proof. Final checkpoint 2026-10-19T20:28:11.449367+00:00.
