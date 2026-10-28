# ZKP efficiency progress

Cycle 0086 complete — `20261019T181854Z-f5bd1f03` — 2026-10-19 UTC.

**No speed improvement measured.** Checked ownership transfer could avoid
12 public-vector copies (243,410,944 bytes per 8B T128 load). The 512-byte
inline activation copy remains. All 48 synthetic layouts and 2,200 refusal
mutations pass; the independent audit passes 624 corruption controls. The
Rust proposal is unbuilt and unapplied.

The old four-pin estimate omitted loader temporaries. The revised public
payload model includes raw, padded and owned buffers plus parallel record
hashing: 2.016689 GiB with borrowed copies versus 1.789997 GiB with moves,
for four distinct pins plus current/next loading and 16 native hash workers.
This allocation-free count excludes private/proof/device, allocator and
page-cache costs; it establishes neither actual peak nor hardware fit.

Validation: 7,074 main / 1,871 audit assertions;
12.309 / 0.152 seconds, peaks 30,416 / 26,828 KiB,
one low-priority CPU thread. All 18 source pins match; 14 match the R8 manifest.
Both earlier failures and the inline-copy model refinement are preserved.

Carried R8 CPU diagnostic: T128, 32 blocks, one 16-thread pass, GPU off;
478.737 seconds total (0.267370 positions/s). Prove_run 393.785 seconds
includes witness hand-over 98.348, including loads 17.595; sealing wall 84.824
includes overlapping witness/load tasks of 80.897/27.151. Fresh verification
42.709 seconds plus initial load 13.681. These clocks are not additive.
Startup fraction, isolated serialization and steady rate remain unmeasured.
The researcher did not reverify this receipt.

New verified proofs/passes/positions: **0/0/0**, device none. No proof context
or pass workload ran; steady/total rates, startup fraction and new witness,
proof, serialization and verification clocks are unmeasured. No prefill,
resident proof series or decode ran. The complete private 8B / >=50 proved
positions/s GPU target remains unchanged and unachieved.

Seam: load_layer_mode to checked owned public constructors. Next: owner
native byte/refusal/proof gates and exclusive copy clocks; local direct
signed-byte padding oracle. Whole-prover GPU and verified resident workloads
remain first. Seven LIVE source records appended (471 to 478); exact Expander
code/diff access was blocked. No external performance was reproduced.

[Experiment](experiments/public-constructor-transfer-20261019/README.md),
[handoff](handoffs/20261019-public-constructor-transfer.md),
[dated report](progress/20261019T181854Z-f5bd1f03.md).
Only research files changed. Saved reports do not establish message delivery.
