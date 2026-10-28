# Review handoff — public raw last use

Run `20261019T201854Z-ec298e23`. **UNBUILT/UNAPPLIED; no measured speed improvement.**

Interface/patch: [21-line standalone diff](../experiments/public-raw-last-use-20261019/review-only-raw-last-use.patch)
in frozen R8 `hashline/src/private_block/trained_block.rs::load_layer_mode`,
after `BlockPublic::new`,before source_tensors parsing/LayerRecord::of_block.
Moves11 raw public Arrays into drop; two existing Copy SHA fields are read
before moving. Array has no user Drop implementation; its fields are public
loader bytes/shape/digest metadata. Constructors own copied vectors. All
validation/generation/constructor call order remains as before in the diff.

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

Baseline/eliminated work/added costs: R8 retains all11 raw Array values
through record hashing,after public constructors copied their data. The
proposal moves their destruction to immediately after BlockPublic::new and
captures the two Copy SHA fields before the move. It removes no IO,hash,
table generator,support check,constructor,witness or proof operation. The
same frees occur earlier; tuple movement and allocator/critical-path effects
are unmeasured. All-load zero-cost deletion leaves433.991s,at most1.103104x
and0.294937 positions/s on the carried CPU diagnostic. This is an overbroad
bound,not this candidate's saving,and gives no high-end GPU rate.

Independent destination-indexing reconstructs signed padded words,all public
word/table SHA256s,source-tensor sorting,manifest/member/per-layer metadata,
and absent/equal/opted-in RoPE branches. Source mutations cover dtype,shape,
exact lengths,SHA,generator failures,metadata and paired first errors.
The model does not execute Rust IO concurrency,constructor checks,refusal
strings,CS/H-1 or proofs. Block SHA256 and JSON framing are explicit
surrogates,not native BLAKE3/record wire/receipt equivalence.

Falsify if native bytes/records/first refusal/receipt change,a live borrow
survives the drop,the allocation is already released,another phase erases
the useful actual peak decrease,or moved frees regress elapsed time.

Review/validation owed: native compile on the owner source; compare full and
reload padded bytes/actual word and table SHA256s,BlockPublic digest,record
and manifest/calibration fields; malformed/paired source and table first
refusals; reload changed-source digest refusal; fresh-process receipt plus
existing CS/H-1/privacy gates. Keep identical source/profile/calibration pins.
Only then measure per-phase live allocations,HWM and enclosing elapsed time,
under shared build/heavy locks. A21-line patch is not evidence of compiler,
allocator,receipt or privacy equivalence. Native production not edited here.
If combined with owned constructors/direct bytes,rebase each proposal and
rerun gates; the ledger explicitly shows non-additive phase maxima.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device none; no proof context or workload ran. Steady-state and total-workload
proved rates, startup fraction, and new witness/proof/serialization/verification
clocks are unmeasured. Synthetic cases are validation paths, not proof passes.
No long-context prefill, resident proof series or decode ran. Longer workloads
remain allowed; dense attention can grow quadratically with context.
The complete private8B / >=50 proved positions/s target on one RTX5090 or a
named high-end GPU remains unchanged and unachieved. No masks, private
commitments or openings were reused.

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

D33 remains trained TinyLlama T32 pg_rot1 CPU R7 only; R8/new files
need gate re-pin,and8B/GPU do not inherit that acceptance. D30 is an unbuilt
construction; D27 soundness and D32 fidelity thresholds remain binding.
Public buffer release authorizes no P3 weight/private opening cache.
Only research written;runtime/production/Git/receipts/calibration/safety/
instructions/reviewer files untouched. No installs,builds,GPU jobs,external
writes/messages,purchases or escalation. Saved reports do not imply delivery.
