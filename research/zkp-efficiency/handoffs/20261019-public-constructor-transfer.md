# Review handoff: public constructor moves, unbuilt proposal

Cycle0086 — `20261019T181854Z-f5bd1f03` — 2026-10-19 UTC.

**No speed improvement measured.** Checked public ownership transfer matches
48 synthetic layouts and preserves tested refusal/encoding outcomes. Native
R8 source shows12 vector clones totalling243410944B per8B T128 load that an
owned constructor could avoid. The512B inline activation copy remains.
No native code was modified, built or proved; proposed patch is unbuilt.

Main PASS 7074 assertions / 2200 rejected mutations;
independent audit PASS 1871 assertions /624 output-corruption controls.
Main/audit 12.308901/0.152414s, peaks
30416/26828KiB, one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s/512MiB caps. These are synthetic validation clocks,
not a native constructor benchmark.18 pins unchanged;14 match frozen R8.

The previous pins4+current/next1.360168GiB ledger excluded loader temporaries.
This cycle counts raw/padded/owned buffers, decode/maps, optional RoPE reserve
and full sealing record hash scratch. Enumerated public-payload envelope with
four distinct pins+current+next load, accounting for16 native hash workers:
**2.016689GiB borrowed ->1.789997GiB moved** [MODEL]. One-worker ledger:
1.852619->1.625927GiB. Not actual RSS/VRAM, complete memory or hardware fit;
private witness/proof/device/allocator/page-cache costs remain excluded.
Evicted live leases from prior findings must still be charged separately.

Carried owner R8 CPU 8B diagnostic: T128,32 blocks,one16-thread pass,
GPU off,n=1. Total478.737s (128/478.737=0.267370 positions/s diagnostic),
prove_run393.785s includes witness hand-over98.348s, itself including17.595s
block loads. Sealing wall84.824s includes overlapping27.151s load tasks and
80.897s witness tasks. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial load13.681s; recheck34.395s plus10.739s load.
Fresh guard wall165.982s includes controls. Startup fraction, isolated
serialization and steady slope are unmeasured. Researcher did not reverify
a receipt; no new target credit. Owner RSS6.69GiB/cgroup9.76GiB includes
existing allocations; do not add this public ledger to those peaks.

New independently verified complete-stack proofs/passes/positions: **0/0/0**;
device none. Target steady-state/total-workload rates, startup fraction and
witness/proof/serialization/verification clocks: all unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic48
fixtures are constructor cases, not proof passes. Larger workloads remain
allowed; attention work can grow quadratically with context. Complete private
8B / >=50 proved positions/s on one RTX5090 or a named high-end GPU is
unchanged and unachieved. No fresh masks, private commitments or openings
were reused or changed.

Owner: review the unbuilt two-file patch, then run locked native constructor
byte/refusal/parity gates and isolate allocation/copy clocks before any claim.
Whole-prover GPU and independently verified fixed-context resident1/2/4/8
workloads stay first. Next local: differential direct signed-byte padding
from Array.bytes versus i8s()+pad_matrix (all256 byte values, interleaved
query-head slots, strides, malformed lengths and zero-pad controls). Account
for whether removing58720256B decode scratch changes the dominant full-loader
peak; do not repeat cycle0027's completed public-digest streaming/cache study.


Patch: ../experiments/public-constructor-transfer-20261019/review-only-owned-constructors.patch
(UNBUILT, UNAPPLIED, not merged). Frozen R8 source hashes in source-pins.json.
Seam private_block.rs: AttentionPublic::new_shaped at521 and
FeedForwardPublic::new_shaped at658; trained_block.rs: load_layer_mode at921,
aw/fw at1037..1046. Full record scratch trained_statement.rs:474..497.

Interface proposal adds crate-private new_shaped_owned functions taking Vec
weights/RoPE/exp; each calls existing check_words, then moves into the same
private fields. FFN act remains &[i16] -> [i16;256] after the same check.
Loader destructures aw/fw and hands vectors across once. Borrowed entry
points remain available. Native check_words, at-use rechecks, source
SHA/digest/table/calibration admission, CS1/3/4/6/8/9 and H-1 stay unchanged.

Owner acceptance before integration: inspect and compile in owned lane under
shared locks; differential constructor bytes and refusal order at toy/rung,
ragged multi-KV and trained shapes; seeded complete receipts and all tamper/
source-change controls; separate-process verifier; actual allocation/copy
and current/next/lease peaks. Re-pin any changed privacy-gate source. No speed
or privacy acceptance follows from this Python model or uncompiled patch.
No production write or merge was made by this researcher.
