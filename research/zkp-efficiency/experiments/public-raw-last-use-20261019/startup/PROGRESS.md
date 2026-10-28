# ZKP efficiency progress

Cycle 0087 complete — `20261019T191854Z-6444ea2f` — 2026-10-19 UTC.

**No speed improvement measured.** Direct signed-byte padding passes 432
synthetic matrix cases and three exhaustive byte sweeps. Main/audit: 5,602 /
2,725 assertions, 1,728 prevalidation and 942 wrong-output controls, plus 864
independent corruption controls. Validation took 0.298 / 0.087 seconds, with
25,924 / 19,196 KiB peaks, on one low-priority Core Ultra 9 185H CPU thread.

The unbuilt Rust proposal avoids nine decode vectors totaling 218,112,000
bytes per 8B layer load. Its largest temporary is 56 MiB. **Full-loader
modeled peak reduction: zero**, because later public record hashing dominates
all carried cases. Actual allocation and timing benefits remain unmeasured.
All 18 source/evidence pins match; 14 match the frozen R8 manifest.

Carried owner CPU diagnostic: T128, 32 blocks, one 16-thread pass, GPU off;
478.737 seconds total (0.267370 positions/s). Prove_run 393.785 includes
witness hand-over 98.348; sealing takes 84.824. Loads are nested/overlapped.
Fresh verification takes 42.709 seconds plus initial load 13.681. Startup
fraction, steady rate and isolated serialization remain unmeasured. The
researcher did not reverify that receipt.

New verified proofs/passes/positions: **0/0/0**, device none. No proof context,
prefill, resident series or decode ran. New steady/total rates, startup
fraction and witness/proof/serialization/verification clocks are unmeasured.
The private 8B / >=50 proved positions/s GPU target remains unachieved.

Seam: validated Array.bytes to private pad_matrix_bytes. Native gates and
exclusive clocks are owed. Next local: raw-array release before record
hashing. Owner whole-prover GPU and verified resident workloads remain first.
Seven LIVE sources recorded: FluxZK, MoMA, Impeller, Chimera and ICICLE, with
date/license/access limits. No external performance reproduced.

[Experiment](experiments/direct-signed-byte-padding-20261019/README.md),
[handoff](handoffs/20261019-direct-signed-byte-padding.md),
[dated report](progress/20261019T191854Z-6444ea2f.md).
Only research changed; saved reports do not establish message delivery.
