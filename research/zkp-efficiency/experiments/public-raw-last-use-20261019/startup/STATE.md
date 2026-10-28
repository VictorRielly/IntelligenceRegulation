# ZKP efficiency explorer — durable state

Cycle0087 COMPLETE:`20261019T191854Z-6444ea2f`,2026-10-19 UTC.
Next cycle no earlier20:18:54 UTC. Started19:18:54;deadline19:38:54 UTC.
[Dated report](progress/20261019T191854Z-6444ea2f.md).
Startup snapshots:experiments/direct-signed-byte-padding-20261019/startup/.

**No speed improvement measured.** Direct signed-byte padding matches
432 synthetic matrices across48 layouts and three exhaustive0..255 byte
sweeps. Main5602 assertions,1728 malformed/type/shape controls and
942 wrong-output controls pass; independent audit2725 assertions
and864 output-corruption controls pass.
Main/audit clocks0.297901/0.086999s,peaks
25924/19196KiB,one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps. These are synthetic
validation clocks,not native padding benchmarks.18 pins unchanged;14 match
frozen R8. Review-only58-line Rust patch is UNBUILT/UNAPPLIED.

Counted work removed: nine complete signed-byte decode vectors totaling
218112000B/load (208.0078125MiB); largest58720256B (56MiB) at8B. Raw arrays,
padded public weights,table checks,hashes,constructors and all proof work stay.
The proposed safe cast loop replaces the identity branch's copy_from_slice;
compiler vectorization and any time benefit are unmeasured. At8B32 query heads
fill32 slots,so head maps are identity; this branch needs native measurement.

Decisive negative: every full-sealing public-payload envelope in the prior
one/16-worker,pins0/4,borrowed/owned ledger has **0B** reduction. The padding
envelope falls520672256->461952000B,but later record hashing dominates.
Four pins+current+next remain2.016689GiB borrowed and1.789997GiB with prior
owned constructors at16 hash workers [MODEL]. These are enumerated public
payload bounds,not actual RSS/VRAM,complete memory or hardware fit. Private
witness/proof/device,allocator/page-cache costs and extra live evicted leases
remain excluded. Do not subtract56MiB from the measured owner peak.

Carried owner R8 diagnostic: trained8B T128,32 blocks,one16-thread CPU
pass,GPU off,n=1. Total478.737s gives0.267370 positions/s diagnostic;
prove_run393.785s includes witness hand-over98.348s,which includes17.595s
block loads. Sealing wall84.824s contains overlapping load/witness tasks
27.151/80.897s. These clocks must not be added. Receipt922711264B.
Fresh verification42.709s plus initial public load13.681s; recheck34.395s
plus10.739s load. Fresh guard wall165.982s includes controls. Startup
fraction,isolated serialization and steady slope remain unmeasured.
Researcher did not reverify this artifact and gives no new target credit.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device none. No proof context/workload ran. Steady-state and total-workload
proved rates,startup fraction,and new witness/proof/serialization/verification
clocks are all unmeasured. Synthetic48 layouts/432 matrices/3 byte sweeps are
validation cases,not proof passes. No long-context prefill,resident proof
series or decode ran. Larger workloads remain allowed; longer context can
increase attention work quadratically. Complete private8B / >=50 proved
positions/s on one RTX5090 or another named high-end GPU remains unchanged
and unachieved. No masks,private commitments or openings were reused.

Ranked hypotheses (full falsification,costs,prerequisites in hypotheses.json):
1.Owner whole-prover GPU and verified fixed-context resident1/2/4/8.
2.Prior checked public constructor transfer,native gates/clock pending.
3.NEW public raw-array release before record hashing,next local test.
4.Tested direct-byte padding,demoted for0B full-envelope improvement.
5.Guarded public owner,freshness/full live lease accounting.
Keep same-attempt witness retention/H-1 and D30/D32 architecture work as
owner-only queued alternatives; prior negative findings remain in FINDINGS.

Owner: review the unbuilt one-file patch,then under shared locks run
native byte/first-refusal/record/receipt gates and exclusive decode+padding
clocks before promotion. Adjacent edits overlap the prior ownership patch's
loader context and need rebase; neither patch is integrated here.

Next local: differential public raw-array last-use/release before
LayerRecord::of_block,including full/reload paths,malformed inputs and exact
record/metadata bytes. Preserve all source freshness,CS and H-1 checks;
recompute every phase maximum rather than subtract218114560B from the peak.
Do not repeat cycle0027 public-digest streaming/cache or prior key-only/LRU/
registry-only lease shortcuts. Owner whole-prover GPU and independently
verified fixed-context resident1/2/4/8 complete workloads remain first.

Seven LIVE primary records appended478->485: newly assessed FluxZK,
older MoMA and recent Impeller; refreshed Chimera's October16 revision and
ICICLE v4 release. Source records distinguish future venue dates from
publication,conflicting FluxZK activity views,and actual SPIRAL license
inspection from unavailable component licenses. Only ICICLE's Cargo-version
bump commit was inspected; it validates no kernel. Several exact history,
license and code requests failed with Cache miss/InternalError; no bypass.
The inaccessible2026/2494 primary lead remains unverified. No author
performance reproduced. Rotation next lookup/softmax and proof composition;
retain memory,batching,quantization/arithmetic and GPU work.

Handoff:handoffs/20261019-direct-signed-byte-padding.md. Patch unbuilt and
unapplied. No native equivalent proof or privacy acceptance claimed.
D33 remains TinyLlama T32 pg_rot1 CPU R7 only; R8/new files need gate re-pin.
No new8B/GPU privacy coverage. D27/D32 unchanged. Future source searches
must retain primary dates/licensing qualifications and blocked fetches.

Only research written;runtime/production/Git/receipts/calibration/safety/
instructions/reviewer files untouched. Saved reports do not imply delivery.
Checkpoint 2026-10-19T19:27:43.233124+00:00. Final consistency/provenance gate PASS: 230 checks; four patch hunks applied in memory only; no native compile/proof.

Final checkpoint 2026-10-19T19:30:10.331438+00:00. Validation was made safely repeatable with its earlier source/result preserved under before-idempotent-validation/.
